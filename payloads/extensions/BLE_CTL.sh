#!/bin/bash  
# Title: BLE_CTL Extension
# Description: BLE control for EBYTE E104-BT52 UART modules
# Author: CoulsTech
# Version: 0.4
# Category: Extension
# Usage: BLE_CTL <command> [args...]  

: "${BLE_CTL_DEVICE:=/dev/ttyS1}"
: "${BLE_CTL_BAUD:=115200}"
: "${BLE_CTL_TIMEOUT:=2}"
: "${BLE_CTL_LOCK:=/tmp/ble_ctl.lock}"
: "${BLE_CTL_SCAN_CACHE:=/tmp/ble_ctl_scan.bin}"
: "${BLE_CTL_ESCAPE_BEFORE_AT:=1}"  

ble_ctl_init() {
    [ -e "$BLE_CTL_DEVICE" ] || {
        echo "BLE_CTL: device not found: $BLE_CTL_DEVICE" >&2
        return 1
    }  
    
    stty -F "$BLE_CTL_DEVICE" "$BLE_CTL_BAUD" cs8 -cstopb -parenb -echo -ixon -icanon -opost 2>/dev/null
}  

ble_ctl_lock() {
    exec 200>"$BLE_CTL_LOCK"
    flock -x 200
}  

ble_ctl_unlock() {
    flock -u 200
}  

ble_ctl_read_response() {
    local timeout_sec="${1:-$BLE_CTL_TIMEOUT}"  
    timeout "$timeout_sec" cat "$BLE_CTL_DEVICE" 2>/dev/null
}  

ble_ctl_at() {
    local command="$1"
    local timeout_sec="${2:-$BLE_CTL_TIMEOUT}"
    local response  
    
    [ -n "$command" ] || {
        echo "BLE_CTL: missing AT command" >&2
        return 1
    }  
    
    ble_ctl_lock
    ble_ctl_init || {
        ble_ctl_unlock
        return 1
    }  
    
    if [ "$BLE_CTL_ESCAPE_BEFORE_AT" = "1" ]; then
        printf '+++' > "$BLE_CTL_DEVICE"
        sleep 1
        ble_ctl_read_response 1 >/dev/null
    fi  
    
    printf '%s\r\n' "$command" > "$BLE_CTL_DEVICE"
    response="$(ble_ctl_read_response "$timeout_sec")"
    ble_ctl_unlock  
    
    printf '%s' "$response"
    printf '%s' "$response" | grep -q '+ERR=' && return 1
    return 0
}  

ble_ctl_at_hex16_le() {
    local command="$1"
    local value="$2"
    local timeout_sec="${3:-$BLE_CTL_TIMEOUT}"
    local high
    local low
    local response  
    
    case "$value" in
        [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
            high="${value%??}"
            low="${value#??}"
            ;;
        *)
            echo "BLE_CTL: $command requires a 16-bit hex UUID, for example FFF0" >&2
            return 1
            ;;
    esac  
    
    ble_ctl_lock
    ble_ctl_init || {
        ble_ctl_unlock
        return 1
    }  
    
    if [ "$BLE_CTL_ESCAPE_BEFORE_AT" = "1" ]; then
        printf '+++' > "$BLE_CTL_DEVICE"
        sleep 1
        ble_ctl_read_response 1 >/dev/null
    fi  
    
    printf '%s=' "$command" > "$BLE_CTL_DEVICE"
    printf '%b%b' "\\x$low" "\\x$high" > "$BLE_CTL_DEVICE"
    response="$(ble_ctl_read_response "$timeout_sec")"
    ble_ctl_unlock  
    
    printf '%s' "$response"
    printf '%s' "$response" | grep -q '+ERR' && return 1
    return 0
}  

ble_ctl_data() {
    ble_ctl_lock
    ble_ctl_init || {
        ble_ctl_unlock
        return 1
    }  
    
    printf '%s' "$*" > "$BLE_CTL_DEVICE"
    ble_ctl_unlock
}  

ble_ctl_config_mode() {
    ble_ctl_lock
    ble_ctl_init || {
        ble_ctl_unlock
        return 1
    }  
    
    printf '+++' > "$BLE_CTL_DEVICE"
    ble_ctl_read_response "$BLE_CTL_TIMEOUT"
    ble_ctl_unlock
}  

ble_ctl_role() {
    case "$1" in
        slave|SLAVE|peripheral|PERIPHERAL|0) ble_ctl_at "AT+ROLE=0" ;;
        master|MASTER|central|CENTRAL|1) ble_ctl_at "AT+ROLE=1" ;;
        observer|OBSERVER|scan|SCAN|2) ble_ctl_at "AT+ROLE=2" ;;
        mixed|MIXED|both|BOTH|3) ble_ctl_at "AT+ROLE=3" ;;
        *)
            echo "Usage: BLE_CTL ROLE slave|master|observer|mixed" >&2
            return 1
            ;;
    esac
}  

ble_ctl_configure() {
    ble_ctl_role "$1"
}  

ble_ctl_advertise() {
    local state="${1:-on}"  
    
    case "$state" in
        on|ON|enable|ENABLE|1) ble_ctl_at "AT+ADV=1" ;;
        off|OFF|disable|DISABLE|0) ble_ctl_at "AT+ADV=0" ;;
        ibeacon|IBEACON|2) ble_ctl_at "AT+ADV=2" ;;
        *)
            echo "Usage: BLE_CTL ADVERTISE on|off|ibeacon" >&2
            return 1
            ;;
    esac
}  

ble_ctl_adv_data() {
    local data="$*"  
    
    [ -n "$data" ] || {
        echo "Usage: BLE_CTL ADVERTISING_DATA <1-25 byte value>" >&2
        return 1
    }  
    
    if [ "${#data}" -gt 25 ]; then
        echo "BLE_CTL: advertising data must be 25 bytes or less" >&2
        return 1
    fi  
    
    ble_ctl_at "AT+ADVDAT=$data"
}  

ble_ctl_scan() {
    local duration="${1:-10}"  
    
    ble_ctl_role observer >/dev/null || return 1
    ble_ctl_at "AT+RESET" >/dev/null
    sleep 1  
    
    ble_ctl_lock
    ble_ctl_init || {
        ble_ctl_unlock
        return 1
    }
    
    timeout "$duration" cat "$BLE_CTL_DEVICE" > "$BLE_CTL_SCAN_CACHE" 2>/dev/null
    ble_ctl_unlock  
    
    strings "$BLE_CTL_SCAN_CACHE" | sort | uniq -c | sort -nr
}  

ble_ctl_monitor() {
    ble_ctl_init || return 1
    cat "$BLE_CTL_DEVICE"
}  

ble_ctl_rx() {
    local duration="${1:-5}"  
    
    ble_ctl_init || return 1
    timeout "$duration" cat "$BLE_CTL_DEVICE"
}  

ble_ctl_hex() {
    local duration="${1:-5}"  
    
    ble_ctl_init || return 1
    timeout "$duration" cat "$BLE_CTL_DEVICE" | hexdump -C
}  

ble_ctl_wait() {
    local mode="$1"
    local needle="$2"  
    
    [ -n "$needle" ] || {
        echo "Usage: BLE_CTL WAIT present|absent <text>" >&2
        return 1
    }  
    
    ble_ctl_role observer >/dev/null || return 1
    ble_ctl_at "AT+RESET" >/dev/null
    sleep 1  
    
    while true; do
        ble_ctl_lock
        ble_ctl_init || {
            ble_ctl_unlock
            return 1
        }
        
        timeout 5 cat "$BLE_CTL_DEVICE" > /tmp/ble_ctl_observation 2>/dev/null
        ble_ctl_unlock
        
        case "$mode" in
            present)
                grep -qao "$needle" /tmp/ble_ctl_observation && return 0
                ;;
            absent)
                grep -qao "$needle" /tmp/ble_ctl_observation || return 0
                ;;
            *)
                echo "Usage: BLE_CTL WAIT present|absent <text>" >&2
                return 1
                ;;
        esac
        
        sleep 1
    done
}  

ble_ctl_gatt_server() {
    local service_uuid="${1:-FFF0}"
    local read_uuid="${2:-FFF1}"
    local write_uuid="${3:-FFF2}"  
    
    ble_ctl_at "AT+ROLE=0" >/dev/null || return 1
    ble_ctl_at_hex16_le "AT+UUIDSVR" "$service_uuid" || return 1
    ble_ctl_at_hex16_le "AT+UUIDSLAVE" "$read_uuid" || return 1
    ble_ctl_at_hex16_le "AT+UUIDMAST" "$write_uuid" || return 1
    ble_ctl_at "AT+TRANMD=1" || return 1
    ble_ctl_at "AT+ADV=1" || return 1
    ble_ctl_at "AT+RESET"
}  

ble_ctl_gatt() {
    local subcommand="$1"
    shift || true  
    
    case "$subcommand" in
        SERVER|server|"")
            ble_ctl_gatt_server "$@"
            ;;
        *)
            echo "BLE_CTL: E104-BT52 only supports configuring its built-in UART GATT service" >&2
            echo "Usage: BLE_CTL GATT SERVER [service_uuid] [read_uuid] [write_uuid]" >&2
            return 1
            ;;
    esac
}  

BLE_CTL() {
    local command="$1"
    shift || true  
    
    case "$command" in
        AT|RAW)
            ble_ctl_at "$*"
            ;;
        INIT)
            ble_ctl_init
            ;;
        CONFIG)
            ble_ctl_config_mode
            ;;
        CONFIGURE|ROLE)
            ble_ctl_role "$1"
            ;;
        NAME)
            ble_ctl_at "AT+NAME=$*"
            ;;
        ADVERTISE|ADV)
            ble_ctl_advertise "$1"
            ;;
        ADVERTISING_DATA|ADVDAT)
            ble_ctl_adv_data "$*"
            ;;
        ADVINTV)
            ble_ctl_at "AT+ADVINTV=$1"
            ;;
        POWER|PWR)
            ble_ctl_at "AT+PWR=$1"
            ;;
        MTU)
            ble_ctl_at "AT+MTU=$1"
            ;;
        TRANSMISSION|TRANMD)
            ble_ctl_at "AT+TRANMD=$1"
            ;;
        SERVICE_UUID|UUID)
            ble_ctl_at_hex16_le "AT+UUIDSVR" "$1"
            ;;
        SERVICE_UUID128|UUID128)
            ble_ctl_at "AT+UUIDSVR128=$1"
            ;;
        READ_UUID|CHARACTERISTIC_UUID|CHAR1)
            ble_ctl_at_hex16_le "AT+UUIDSLAVE" "$1"
            ;;
        WRITE_UUID|CHAR2)
            ble_ctl_at_hex16_le "AT+UUIDMAST" "$1"
            ;;
        AUTH)
            ble_ctl_at "AT+AUTH=$1"
            ;;
        UPAUTH)
            ble_ctl_at "AT+UPAUTH=$1"
            ;;
        LOG)
            ble_ctl_at "AT+LOGMSG=$1"
            ;;
        SCAN_ENABLE)
            ble_ctl_at "AT+SCAN=$1"
            ;;
        SCANINTV)
            ble_ctl_at "AT+SCANINTV=$1"
            ;;
        SCANWND)
            ble_ctl_at "AT+SCANWND=$1"
            ;;
        BOND)
            ble_ctl_at "AT+BONDMAC=$1"
            ;;
        DISCONNECT|DISCON)
            ble_ctl_at "AT+DISCON${1:+=$1}"
            ;;
        MAC)
            ble_ctl_at "AT+MAC?"
            ;;
        VERSION|VER)
            ble_ctl_at "AT+VER?"
            ;;
        CONNECTION_INFO|CONINFO)
            ble_ctl_at "AT+CONINFO?"
            ;;
        RESET)
            ble_ctl_at "AT+RESET"
            ;;
        RESTORE)
            ble_ctl_at "AT+RESTORE"
            ;;
        SLEEP)
            ble_ctl_at "AT+SLEEP"
            ;;
        SEND|TX)
            ble_ctl_data "$*"
            ;;
        RECEIVE|RX)
            ble_ctl_rx "$1"
            ;;
        SCAN)
            ble_ctl_scan "$1"
            ;;
        LIST)
            strings "$BLE_CTL_SCAN_CACHE" 2>/dev/null | sort | uniq
            ;;
        MONITOR|WATCH)
            ble_ctl_monitor
            ;;
        HEX)
            ble_ctl_hex "$1"
            ;;
        WAIT_PRESENT)
            ble_ctl_wait present "$1"
            ;;
        WAIT_NOT_PRESENT)
            ble_ctl_wait absent "$1"
            ;;
        WAIT)
            ble_ctl_wait "$@"
            ;;
        GATT)
            ble_ctl_gatt "$@"
            ;;
        HELP|help|-h|--help|"")
            echo "Usage: BLE_CTL <command> [args...]"
            echo "  GATT SERVER [service_uuid] [read_uuid] [write_uuid]"
            echo "  ROLE slave|master|observer|mixed"
            echo "  ADVERTISE on|off|ibeacon"
            echo "  NAME <name>"
            echo "  ADVERTISING_DATA <1-25 byte value>"
            echo "  SEND <data> | RECEIVE [sec]"
            echo "  SCAN [sec] | WAIT present|absent <text>"
            echo "  AT <raw AT command>"
            ;;
        *)
            echo "BLE_CTL: unknown command: $command" >&2
            BLE_CTL HELP >&2
            return 1
            ;;
    esac
}  

# Export all functions
export -f BLE_CTL
export -f ble_ctl_init ble_ctl_lock ble_ctl_unlock ble_ctl_read_response
export -f ble_ctl_at ble_ctl_at_hex16_le ble_ctl_data ble_ctl_config_mode ble_ctl_role
export -f ble_ctl_configure ble_ctl_advertise ble_ctl_adv_data ble_ctl_scan
export -f ble_ctl_monitor ble_ctl_rx ble_ctl_hex ble_ctl_wait
export -f ble_ctl_gatt_server ble_ctl_gatt

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    BLE_CTL "$@"
fi
