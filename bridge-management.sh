#!/bin/bash

# Print authorship disclaimer in orange
echo -e "\e[33mBridge Management script version 0.2.3"
echo "Author: Emerald Onion"
echo "Author's website: https://emeraldonion.org/"
echo "Script's website: https://github.com/emeraldonion/bridge-management"
echo "License: Creative Commons Public Domain. This script is free for use, modification, and distribution."
echo -e "For more information about the license, visit https://creativecommons.org/publicdomain/zero/1.0/\e[0m"


# Function to install Tor and obfs4proxy if they are not installed
install_dependencies() {
    echo
    echo "Checking for Tor installation..."
    if ! command -v tor > /dev/null; then
        echo "Tor not found, installing..."
        echo
        apt update && apt install gpg -y
        echo "Adding Tor Project repository..."
        echo "deb [signed-by=/usr/share/keyrings/tor-archive-keyring.gpg] https://deb.torproject.org/torproject.org $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/tor.list
        wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg >/dev/null
        apt update
        apt install tor -y
    else
        echo "Tor is already installed. Version: $(tor --version)"
        echo
    fi

    echo "Checking for obfs4proxy installation..."
    if [ ! -f /usr/bin/obfs4proxy ]; then
        echo "obfs4proxy not found, installing..."
        echo
        apt update && apt install obfs4proxy -y
    else
        echo "obfs4proxy is already installed."
        echo
    fi

    # Configure obfs4proxy to bind on privileged ports
    echo "Configuring obfs4proxy to bind on privileged ports..."
    sudo setcap cap_net_bind_service=+ep /usr/bin/obfs4proxy

    # Check and create systemd service directories if they don't exist
    for SERVICE in tor@.service tor@default.service; do
        DIR="/etc/systemd/system/${SERVICE}.d"
        if [ ! -d "$DIR" ]; then
            sudo mkdir "$DIR"
        fi
    done

    # Check and update systemd configuration if necessary
    OVERRIDE_CONF="[Service]\nNoNewPrivileges=no"
    for SERVICE in tor@.service tor@default.service; do
        OVERRIDE_FILE="/etc/systemd/system/${SERVICE}.d/override.conf"
        if ! grep -q "NoNewPrivileges=no" "$OVERRIDE_FILE" 2>/dev/null; then
            echo -e "$OVERRIDE_CONF" | sudo tee "$OVERRIDE_FILE"
        fi
    done

    sudo systemctl daemon-reload
    sudo service tor restart
}

# Function to list existing bridges and their obfs4 lines
list_existing_bridges() {
    echo "Checking for existing bridges..."
    for instance_dir in /var/lib/tor-instances/*/; do
        if [ -d "$instance_dir" ]; then
            bridge_name=$(basename "$instance_dir")
            pt_state_file="$instance_dir/pt_state/obfs4_bridgeline.txt"
            torrc_file="/etc/tor/instances/$bridge_name/torrc"
            fingerprint_file="$instance_dir/fingerprint"

            if [ -f "$pt_state_file" ] && [ -f "$torrc_file" ] && [ -f "$fingerprint_file" ]; then
		echo
		echo "Found bridge: $bridge_name"

                # Extracting only the first (IPv4) socket (IP address and port) from torrc
                socket=$(grep "ServerTransportListenAddr obfs4" "$torrc_file" | head -1 | awk '{print $3}')

                # Extracting fingerprint
		fingerprint=$(cat "$fingerprint_file" | awk '{print $2}')

                # Extracting only the cert from obfs4_bridgeline.txt
                cert=$(grep "cert=" "$pt_state_file" | cut -d ' ' -f6-)

                # Constructing and printing the completed obfs4 line
                completed_obfs4_line="obfs4 $socket $fingerprint $cert"
		echo "Completed bridge line for Tor Browser:"
                echo -e "\e[32m$completed_obfs4_line\e[0m"  # Print obfs4 line in green
		
		# Print file locations
		echo "Bridge $bridge_name file locations:"
		echo "Configuration: $torrc_file"
		echo "Notice log: ${instance_dir}logs/notice.log"
		echo "Obfs4 bridge line: ${instance_dir}pt_state/obfs4_bridgeline.txt"
		echo "Fingerprint: ${instance_dir}fingerprint"
		echo

            else
                echo "Required files not found for $bridge_name"
            fi
        fi
    done
}

# Function to manage bridges
manage_bridges() {
    while true; do
        echo
	echo "Select an action:"
        echo -e "\e[34m1. Add a new bridge\e[0m"
        echo -e "\e[34m2. Delete an existing bridge\e[0m"
        echo -e "\e[34m3. List existing bridges\e[0m"
        echo -e "\e[34m4. Exit\e[0m"
	read -p "Enter your choice (1/2/3/4): " action_choice

        case $action_choice in
            1)
                configure_bridge
                display_bridge_info
                print_torrc_info
                ;;
            2)
                if [ -d /var/lib/tor-instances/ ]; then
                    echo "Available bridges:"
                    ls /var/lib/tor-instances/
                    read -p "Enter the name of the bridge to delete: " bridge_to_delete
                    read -p "Are you sure you want to delete $bridge_to_delete? [y/N]: " confirm_delete
                    if [[ $confirm_delete =~ ^[Yy]$ ]]; then
                        echo "Stopping the Tor service for $bridge_to_delete. This may take up to 30 seconds..."
                        systemctl stop "tor@$bridge_to_delete"
                        rm -rf "/var/lib/tor-instances/$bridge_to_delete"
                        rm -rf "/etc/tor/instances/$bridge_to_delete"
                        echo "Bridge $bridge_to_delete deleted."
                    fi
                else
                    echo "No existing bridges to delete."
                fi
                ;;
            3)
                list_existing_bridges
                ;;
            4)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid option, please try again."
                ;;
        esac
    done
}

# Function to configure the bridge
configure_bridge() {
    echo  # Adding a line break before the message
    echo "Please enter the following information for your bridge:"
    read -p "Bridge Name: " bridge_name
    read -p "Bridge IPv4 Address: " bridge_ip4
    read -p "Bridge IPv6 Address (or 'none'): " bridge_ip6
    read -p "Bridge obfs4 Port: " bridge_port
    read -p "Bridge Owner's Contact Email: " bridge_email
    read -p "Bridge Distribution (https/moat/email/telegram/settings/none/any): " bridge_distribution

    bridge_distribution=${bridge_distribution,,}  # convert to lowercase
    valid_distributions="https moat email telegram settings none any"
    if [[ ! $valid_distributions =~ $bridge_distribution ]]; then
        echo "Invalid distribution type. Defaulting to 'none'."
        bridge_distribution="none"
    fi

    tor-instance-create "$bridge_name"
    config_file="/etc/tor/instances/$bridge_name/torrc"

    # Derive the user and group from the bridge name
    tor_user="_tor-${bridge_name}"
    tor_group="_tor-${bridge_name}"

    # Create and set permissions for the log directory
    log_dir="/var/lib/tor-instances/$bridge_name/logs"
    if [ ! -d "$log_dir" ]; then
        sudo mkdir -p "$log_dir"
        sudo chown "$tor_user":"$tor_group" "$log_dir"
        sudo chmod 700 "$log_dir"
    fi

    # Checking and formatting the IPv6 address
    if [[ "$bridge_ip6" != "none" ]]; then
        if [[ "$bridge_ip6" != \[*\]* ]]; then
            bridge_ip6="[$bridge_ip6]"
        fi
    fi

    {
        echo "# Relay General"
        echo "SocksPort auto"
        echo "AssumeReachable 1"
        echo "Exitpolicy reject *:*"
        echo "Nickname $bridge_name"
        echo "ContactInfo $bridge_email"
        echo "HeartBeatPeriod 30 minutes"
        echo "ConnDirectionStatistics 1"
        echo "ExtraInfoStatistics 1"
        echo "Log notice file $log_dir/notice.log"
        echo "# Bridge General"
        echo "BridgeRelay 1"
        echo "BridgeDistribution $bridge_distribution"
        echo "ServerTransportPlugin obfs4 exec /usr/bin/obfs4proxy"
        echo "ExtORPort auto"
        echo "# Bridge IPv4"
        echo "Address $bridge_ip4"
        echo "OutboundBindAddress $bridge_ip4"
        echo "ORPort $bridge_ip4:auto"
        echo "ServerTransportListenAddr obfs4 $bridge_ip4:$bridge_port"
        if [ "$bridge_ip6" != "none" ]; then
            echo "# Bridge IPv6"
            echo "Address $bridge_ip6"
            echo "OutboundBindAddress $bridge_ip6"
            echo "ORPort $bridge_ip6:auto"
            echo "ServerTransportListenAddr obfs4 $bridge_ip6:$bridge_port"
        fi
    } > "$config_file"

    systemctl restart "tor@$bridge_name"
    echo "Bridge configuration complete."
}

# Function to display the bridge information
display_bridge_info() {
    echo 
    echo "Fetching bridge information for bridge: $bridge_name..."
    sleep 5  # Wait for the logs to populate

    # File paths
    torrc_file="/etc/tor/instances/$bridge_name/torrc"
    log_file="/var/lib/tor-instances/$bridge_name/logs/notice.log"
    pt_state_file="/var/lib/tor-instances/$bridge_name/pt_state/obfs4_bridgeline.txt"
    fingerprint_file="/var/lib/tor-instances/$bridge_name/fingerprint"

    # Extracting socket (IP address and port) from torrc
    socket=$(grep "ServerTransportListenAddr obfs4" "$torrc_file" | head -1 | awk '{print $3}')

    # Extracting fingerprint
    fingerprint=$(cat "$fingerprint_file" | awk '{print $2}')

    # Extracting only the cert from obfs4_bridgeline.txt
    cert=$(grep "cert=" "$pt_state_file" | cut -d ' ' -f6-)

    # Constructing and printing the completed obfs4 line
    obfs4_line="obfs4 $socket $fingerprint $cert"
    echo "Completed bridge line for Tor Browser:"
    echo -e "\e[32m$obfs4_line\e[0m"  # Print obfs4 line in green

    # Print file locations
    echo "Bridge $bridge_name file locations:"
    echo "Configuration: $torrc_file"
    echo "Notice log: $log_file"
    echo "Obfs4 bride line: $pt_state_file"
    echo "Fingerprint: $fingerprint_file"
}

# Function to print the torrc file location and content
print_torrc_info() {
    config_file="/etc/tor/instances/$bridge_name/torrc"
    echo 
    echo "Configuration file location: $config_file"
    echo -e "\e[32m$(cat $config_file)\e[0m"  # Print content of torrc in green
}

# Main script execution
install_dependencies
list_existing_bridges
manage_bridges
configure_bridge
display_bridge_info
print_torrc_info
