#!/bin/bash

# Title: BLE_CTL Extension
# Description: Bluetooth Low Energy control for EBYTE E104-BT52 modules
# Author: CoulsTech
# Version: 1.2
# Category: Extension

BLE_DEVICE="/dev/ttyS1"
BLE_TIMEOUT="5"
BLE_LOCK="/tmp/ble.lock"

ble_lock() {
    exec 200>"$BLE_LOCK"
    flock -x 200
}

ble_unlock() {
    flock -u 200
}

ble_send() {
    local command="$1"
    local data="$2"

    ble_lock

    echo -n -e "${command}${data}" > "$BLE_DEVICE"

    sleep 1

    timeout "$BLE_TIMEOUT" cat "$BLE_DEVICE" 2>/dev/null

    ble_unlock
}

ble_monitor() {
    while true; do
        timeout 1 cat "$BLE_DEVICE" 2>/dev/null
    done
}

# --- new low-level helpers ---

ble_reset() {
    ble_send "AT+RESET" ""
}

ble_set_role() {
    ble_send "AT+ROLE=" "$1"
}

ble_observer() {
    ble_set_role "2"
    sleep 1
    ble_reset
}

ble_capture() {
    local outfile="${1:-/tmp/bt.bin}"
    local duration="${2:-15}"

    ble_observer

    timeout "$duration" cat "$BLE_DEVICE" > "$outfile" 2>/dev/null
}

ble_scan_strings() {
    strings "${1:-/tmp/bt.bin}" | sort | uniq -c | sort -nr
}

ble_wait_present() {
    local needle="$1"

    ble_observer

    while true; do
        timeout 5 cat "$BLE_DEVICE" > /tmp/bt_observation 2>/dev/null

        if grep -qao "$needle" /tmp/bt_observation; then
            return 0
        fi

        sleep 1
    done
}

ble_wait_not_present() {
    local needle="$1"

    ble_observer

    while true; do
        timeout 5 cat "$BLE_DEVICE" > /tmp/bt_observation 2>/dev/null

        if ! grep -qao "$needle" /tmp/bt_observation; then
            return 0
        fi

        sleep 1
    done
}

ble_configure() {
    local role="$1"

    case "$role" in
        slave)
            ble_set_role 0
            ;;
        master)
            ble_set_role 1
            ;;
        observer)
            ble_observer
            ;;
        *)
            echo "Invalid role. Use: slave, master, observer"
            return 1
            ;;
    esac
}

ble_set_power() {
    ble_send "AT+PWR=" "$1"
}

ble_set_mtu() {
    ble_send "AT+MTU=" "$1"
}

ble_set_uuid() {
    ble_send "AT+UUIDSVR=" "$1"
}

ble_set_name() {
    ble_send "AT+NAME=" "$1"
}

ble_set_scan() {
    local scan_enable="$1"
    local scan_interval="$2"
    local scan_window="$3"

    [ -n "$scan_enable" ] && ble_send "AT+SCAN=" "$scan_enable"
    [ -n "$scan_interval" ] && ble_send "AT+SCANINTV=" "$scan_interval"
    [ -n "$scan_window" ] && ble_send "AT+SCANWND=" "$scan_window"
}

ble_set_connection() {
    local conn_interval="$1"
    local conn_latency="$2"
    local supervision_timeout="$3"

    [ -n "$conn_interval" ] && ble_send "AT+CONINTV=" "$conn_interval"
    [ -n "$conn_latency" ] && ble_send "AT+CONNLAT=" "$conn_latency"
    [ -n "$supervision_timeout" ] && ble_send "AT+CONNTIMEOUT=" "$supervision_timeout"
}

ble_set_advertising() {
    local adv_interval="$1"
    local adv_type="$2"

    [ -n "$adv_interval" ] && ble_send "AT+ADVINTV=" "$adv_interval"
    [ -n "$adv_type" ] && ble_send "AT+ADVTYPE=" "$adv_type"
}

ble_set_transmission_mode() {
    ble_send "AT+TRANMD=" "$1"
}

ble_set_auth() {
    ble_send "AT+AUTH=" "$1"
}

ble_set_sleep() {
    ble_send "AT+ONSLEEP=" "$1"
}

ble_enter_sleep() {
    ble_send "AT+SLEEP" ""
}

ble_get_version() {
    ble_send "AT+VER?" ""
}

ble_get_mac() {
    ble_send "AT+MAC?" ""
}

ble_get_connection_info() {
    ble_send "AT+CONINFO=0" ""
}

ble_disconnect() {
    ble_send "AT+DISCON=0" ""
}

ble_set_bonding() {
    ble_send "AT+BONDMAC=" "$1"
}

ble_delete_bond() {
    ble_send "AT+BONDDEL=" "$1"
}

ble_set_log() {
    ble_send "AT+LOGMSG=" "$1"
}

ble_set_scan_response() {
    ble_send "AT+SCANRSP=" "$1"
}

ble_set_advertising_data() {
    ble_send "AT+ADVDATA=" "$1"
}

ble_set_service_uuid() {
    ble_send "AT+UUIDSVR128=" "$1"
}

ble_set_characteristic_uuid() {
    ble_send "AT+UUIDSLAVE=" "$1"
}

ble_set_notification() {
    ble_send "AT+NOTIFY=" "$1"
}

ble_send_data() {
    ble_lock
    echo -n -e "$1" > "$BLE_DEVICE"
    ble_unlock
}

ble_receive_data() {
    timeout "${1:-5}" cat "$BLE_DEVICE" 2>/dev/null
}

ble_ctl() {
    local command="$1"
    shift

    case "$command" in
        CONFIGURE)
            ble_configure "$@"
            ;;
        POWER)
            ble_set_power "$1"
            ;;
        MTU)
            ble_set_mtu "$1"
            ;;
        UUID)
            ble_set_uuid "$1"
            ;;
        NAME)
            ble_set_name "$*"
            ;;
        SCAN)
            ble_set_scan "$@"
            ;;
        CONNECTION)
            ble_set_connection "$@"
            ;;
        ADVERTISING)
            ble_set_advertising "$@"
            ;;
        TRANSMISSION)
            ble_set_transmission_mode "$1"
            ;;
        AUTH)
            ble_set_auth "$1"
            ;;
        SLEEP)
            ble_set_sleep "$1"
            ;;
        ENTER_SLEEP)
            ble_enter_sleep
            ;;
        VERSION)
            ble_get_version
            ;;
        MAC)
            ble_get_mac
            ;;
        CONNECTION_INFO)
            ble_get_connection_info
            ;;
        DISCONNECT)
            ble_disconnect
            ;;
        BOND)
            ble_set_bonding "$1"
            ;;
        DELETE_BOND)
            ble_delete_bond "$1"
            ;;
        LOG)
            ble_set_log "$1"
            ;;
        SCAN_RESPONSE)
            ble_set_scan_response "$1"
            ;;
        ADVERTISING_DATA)
            ble_set_advertising_data "$1"
            ;;
        SERVICE_UUID)
            ble_set_service_uuid "$1"
            ;;
        CHARACTERISTIC_UUID)
            ble_set_characteristic_uuid "$1"
            ;;
        NOTIFICATION)
            ble_set_notification "$1"
            ;;
        SEND)
            ble_send_data "$*"
            ;;
        RECEIVE)
            ble_receive_data "$1"
            ;;
        MONITOR)
            ble_monitor
            ;;
        OBSERVER)
            ble_observer
            ;;
        CAPTURE)
            ble_capture "$@"
            ;;
        SCAN_STRINGS)
            ble_scan_strings "$1"
            ;;
        WAIT_PRESENT)
            ble_wait_present "$1"
            ;;
        WAIT_NOT_PRESENT)
            ble_wait_not_present "$1"
            ;;
        RESET)
            ble_reset
            ;;
        ROLE)
            ble_set_role "$1"
            ;;
        *)
            echo "Unknown command: $command"
            echo
            echo "Examples:"
            echo "  BLE_CTL VERSION"
            echo "  BLE_CTL ROLE 2"
            echo "  BLE_CTL OBSERVER"
            echo "  BLE_CTL CAPTURE /tmp/bt.bin 30"
            echo "  BLE_CTL SCAN_STRINGS /tmp/bt.bin"
            echo "  BLE_CTL WAIT_PRESENT BB2"
            echo "  BLE_CTL WAIT_NOT_PRESENT BB2"
            echo "  BLE_CTL MONITOR"
            return 1
            ;;
    esac
}

ble_ctl "$@"