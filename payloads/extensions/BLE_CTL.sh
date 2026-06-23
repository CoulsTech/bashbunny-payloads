#!/bin/bash

# Title: BLE_CTL Extension
# Description: Bluetooth Low Energy control for EBYTE E104-BT52 modules
# Author: CoulsTech
# Version: 1.0
# Category: Extension

# Extension variables
BLE_DEVICE="/dev/ttyACM0"
BLE_BAUD="115200"
BLE_TIMEOUT="5"
BLE_BUFFER_SIZE="1024"

# Function to send BLE command
ble_send() {
    local command="$1"
    local data="$2"
    
    # Send command to BLE device
    echo -ne "$command$data\r\n" > "$BLE_DEVICE"
    
    # Wait for response
    sleep 0.1
    
    # Read response
    local response=$(timeout "$BLE_TIMEOUT" cat "$BLE_DEVICE" 2>/dev/null)
    echo "$response"
}

# Function to configure BLE module
ble_configure() {
    local role="$1"
    local config="$2"
    
    case "$role" in
        "slave")
            ble_send "AT+ROLE=0" ""
            ;;
        "master")
            ble_send "AT+ROLE=1" ""
            ;;
        "observer")
            ble_send "AT+ROLE=2" ""
            ;;
        *)
            echo "Invalid role. Use: slave, master, or observer"
            return 1
            ;;
    esac
    
    # Apply configuration
    ble_send "$config" ""
}

# Function to set BLE transmit power
ble_set_power() {
    local power="$1"
    ble_send "AT+PWR=$power" ""
}

# Function to set BLE MTU
ble_set_mtu() {
    local mtu="$1"
    ble_send "AT+MTU=$mtu" ""
}

# Function to set BLE UUID
ble_set_uuid() {
    local uuid="$1"
    ble_send "AT+UUIDSVR=$uuid" ""
}

# Function to set BLE name
ble_set_name() {
    local name="$1"
    ble_send "AT+NAME=$name" ""
}

# Function to set BLE scan parameters
ble_set_scan() {
    local scan_enable="$1"
    local scan_interval="$2"
    local scan_window="$3"
    
    ble_send "AT+SCAN=$scan_enable" ""
    ble_send "AT+SCANINTV=$scan_interval" ""
    ble_send "AT+SCANWND=$scan_window" ""
}

# Function to set BLE connection parameters
ble_set_connection() {
    local conn_interval="$1"
    local conn_latency="$2"
    local supervision_timeout="$3"
    
    ble_send "AT+CONINTV=$conn_interval" ""
    ble_send "AT+CONNLAT=$conn_latency" ""
    ble_send "AT+CONNTIMEOUT=$supervision_timeout" ""
}

# Function to set BLE advertising parameters
ble_set_advertising() {
    local adv_interval_min="$1"
    local adv_interval_max="$2"
    local adv_type="$3"
    
    ble_send "AT+ADVINTV=$adv_interval_min" ""
    ble_send "AT+ADVINTV=$adv_interval_max" ""
    ble_send "AT+ADVTYPE=$adv_type" ""
}

# Function to set BLE data transmission mode
ble_set_transmission_mode() {
    local mode="$1"  # 0 = non-transparent, 1 = transparent
    ble_send "AT+TRANMD=$mode" ""
}

# Function to set BLE authentication
ble_set_auth() {
    local password="$1"
    ble_send "AT+AUTH=$password" ""
}

# Function to set BLE sleep mode
ble_set_sleep() {
    local sleep_mode="$1"  # 0 = off, 1 = on
    ble_send "AT+ONSLEEP=$sleep_mode" ""
}

# Function to enter sleep mode
ble_enter_sleep() {
    ble_send "AT+SLEEP" ""
}

# Function to get BLE version
ble_get_version() {
    ble_send "AT+VER" ""
}

# Function to get BLE MAC address
ble_get_mac() {
    ble_send "AT+MAC" ""
}

# Function to get BLE connection info
ble_get_connection_info() {
    ble_send "AT+CONINFO=0" ""
}

# Function to disconnect BLE connection
ble_disconnect() {
    ble_send "AT+DISCON=0" ""
}

# Function to set BLE bonding
ble_set_bonding() {
    local mac_address="$1"
    ble_send "AT+BONDMAC=$mac_address" ""
}

# Function to delete BLE bond
ble_delete_bond() {
    local mac_address="$1"
    ble_send "AT+BONDDEL=$mac_address" ""
}

# Function to set BLE log message
ble_set_log() {
    local log_enable="$1"  # 0 = off, 1 = on
    ble_send "AT+LOGMSG=$log_enable" ""
}

# Function to set BLE scan response
ble_set_scan_response() {
    local scan_response="$1"
    ble_send "AT+SCANRSP=$scan_response" ""
}

# Function to set BLE advertising data
ble_set_advertising_data() {
    local adv_data="$1"
    ble_send "AT+ADVDATA=$adv_data" ""
}

# Function to set BLE service UUID
ble_set_service_uuid() {
    local service_uuid="$1"
    ble_send "AT+UUIDSVR128=$service_uuid" ""
}

# Function to set BLE characteristic UUID
ble_set_characteristic_uuid() {
    local char_uuid="$1"
    ble_send "AT+UUIDSLAVE=$char_uuid" ""
}

# Function to set BLE notification
ble_set_notification() {
    local notification="$1"  # 0 = off, 1 = on
    ble_send "AT+NOTIFY=$notification" ""
}

# Function to send data via BLE
ble_send_data() {
    local data="$1"
    echo -ne "$data" > "$BLE_DEVICE"
}

# Function to receive data via BLE
ble_receive_data() {
    local timeout="$1"
    timeout "$timeout" cat "$BLE_DEVICE" 2>/dev/null
}

# Main function to process BLE commands
ble_ctl() {
    local command="$1"
    local data="$2"
    
    case "$command" in
        "CONFIGURE")
            ble_configure "$data"
            ;;
        "POWER")
            ble_set_power "$data"
            ;;
        "MTU")
            ble_set_mtu "$data"
            ;;
        "UUID")
            ble_set_uuid "$data"
            ;;
        "NAME")
            ble_set_name "$data"
            ;;
        "SCAN")
            ble_set_scan "$data"
            ;;
        "CONNECTION")
            ble_set_connection "$data"
            ;;
        "ADVERTISING")
            ble_set_advertising "$data"
            ;;
        "TRANSMISSION")
            ble_set_transmission_mode "$data"
            ;;
        "AUTH")
            ble_set_auth "$data"
            ;;
        "SLEEP")
            ble_set_sleep "$data"
            ;;
        "ENTER_SLEEP")
            ble_enter_sleep
            ;;
        "VERSION")
            ble_get_version
            ;;
        "MAC")
            ble_get_mac
            ;;
        "CONNECTION_INFO")
            ble_get_connection_info
            ;;
        "DISCONNECT")
            ble_disconnect
            ;;
        "BOND")
            ble_set_bonding "$data"
            ;;
        "DELETE_BOND")
            ble_delete_bond "$data"
            ;;
        "LOG")
            ble_set_log "$data"
            ;;
        "SCAN_RESPONSE")
            ble_set_scan_response "$data"
            ;;
        "ADVERTISING_DATA")
            ble_set_advertising_data "$data"
            ;;
        "SERVICE_UUID")
            ble_set_service_uuid "$data"
            ;;
        "CHARACTERISTIC_UUID")
            ble_set_characteristic_uuid "$data"
            ;;
        "NOTIFICATION")
            ble_set_notification "$data"
            ;;
        "SEND")
            ble_send_data "$data"
            ;;
        "RECEIVE")
            ble_receive_data "$data"
            ;;
        *)
            echo "Unknown command: $command"
            return 1
            ;;
    esac
}

# Extension entry point
case "$1" in
    "BLE_CTL")
        ble_ctl "$2" "$3"
        ;;
    *)
        echo "Usage: BLE_CTL {Command} {Data}"
        exit 1
        ;;
esac