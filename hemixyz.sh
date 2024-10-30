#!/bin/bash

printHeader() {
    echo -e "\e[36m   ___       _      _                       \e[0m"
    echo -e "\e[36m  / _ \\     | |    (_)                      \e[0m"
    echo -e "\e[36m | | | |_  _| |     _ _ __ ___   ___  _ __  \e[0m"
    echo -e "\e[36m | | | \\ \\/ / |    | | '_ ' _ \\ / _ \\| '_ \\ \e[0m"
    echo -e "\e[36m | |_| |>  <| |____| | | | | | | (_) | | | |\e[0m"
    echo -e "\e[36m  \\___//_/\\_\\______|_|_| |_| |_|\\___/|_| |_|\e[0m"
    echo -e "\e[36m                                            \e[0m"
    echo -e "\e[36m                                            \e[0m"
    echo -e "\e[36m  https://github.com/0xlimon\e[0m"
    echo -e "\e[36m******************************************************\e[0m"
}

printHeader

sleep 3


ARCH=$(uname -m)

show() {
    echo -e "\033[1;35m$1\033[0m"
}

show_menu() {
    clear
    show "=== Hemi Network Wallet Management ==="
    echo "1) Create new wallet(s)"
    echo "2) Import existing wallet(s)"
    echo "3) View existing wallets"
    echo "4) Restart all services"
    echo "5) Update Hemi Network"
    echo "6) Update Fee for All Miners"
    echo "7) Remove All Services"
    echo "8) Exit"
    echo
    read -p "Please select an option (1-8): " choice
}

create_new_wallets() {
    read -p "How many wallets do you want to create? " wallet_count
    echo

    if ! [[ "$wallet_count" =~ ^[0-9]+$ ]]; then
        show "Invalid input. Please enter a valid number."
        read -p "Press Enter to continue..."
        return
    fi

    highest_num=0
    for service in $(systemctl list-units --type=service | grep hemi- | awk '{print $1}'); do
        num=$(echo $service | grep -o '[0-9]\+' | head -1)
        if [ -n "$num" ] && [ "$num" -gt "$highest_num" ]; then
            highest_num=$num
        fi
    done

    start_num=$((highest_num + 1))

    for (( i=0; i<$wallet_count; i++ )); do
        current_num=$((start_num + i))
        show "Creating wallet $((i+1)) (Service #$current_num)..."
        
        if ! ./keygen -secp256k1 -json -net="testnet" > ~/popm-address-$current_num.json; then
            show "Failed to generate wallet $((i+1))."
            continue
        fi
        
        priv_key=$(jq -r '.private_key' ~/popm-address-$current_num.json)
        pubkey_hash=$(jq -r '.pubkey_hash' ~/popm-address-$current_num.json)

        show "Wallet $((i+1)) details:"
        cat ~/popm-address-$current_num.json
        echo
        
        show "Join: https://discord.gg/hemixyz"
        show "Request faucet from faucet channel to this address: $pubkey_hash"
        echo
        read -p "Have you requested faucet for wallet $((i+1))? (y/N): " faucet_requested
        
        if [[ "$faucet_requested" =~ ^[Yy]$ ]]; then
            read -p "Enter static fee for wallet $((i+1)) (numerical only, recommended: 100-200): " static_fee
            
            if ! [[ "$static_fee" =~ ^[0-9]+$ ]]; then
                show "Invalid fee. Please enter a numerical value. Skipping wallet $((i+1))."
                continue
            fi
            echo

            if ! sudo tee /etc/systemd/system/hemi-$current_num.service > /dev/null <<EOF
[Unit]
Description=Hemi Network popmd Service - Wallet $current_num
After=network.target

[Service]
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/popmd
Environment="POPM_BTC_PRIVKEY=$priv_key"
Environment="POPM_STATIC_FEE=$static_fee"
Environment="POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
            then
                show "Failed to create service file for wallet $((i+1))"
                continue
            fi

            if ! sudo systemctl daemon-reload; then
                show "Failed to reload systemd for wallet $((i+1))"
                continue
            fi

            if ! sudo systemctl enable hemi-$current_num.service; then
                show "Failed to enable service for wallet $((i+1))"
                continue
            fi

            if ! sudo systemctl start hemi-$current_num.service; then
                show "Failed to start service for wallet $((i+1))"
                continue
            fi

            show "Service hemi-$current_num.service is successfully started for wallet $((i+1))"
            

            if systemctl is-active --quiet hemi-$current_num.service; then
                show "Service is running successfully"
            else
                show "Warning: Service may not be running properly"
            fi
        else
            show "Skipping service creation for wallet $((i+1))."
        fi
        echo
    done
    
    show "Wallet creation process completed"
    read -p "Press Enter to continue..."
}

import_existing_wallets() {
    read -p "How many wallets do you want to import? " wallet_count
    echo


    if ! [[ "$wallet_count" =~ ^[0-9]+$ ]]; then
        show "Invalid input. Please enter a valid number."
        read -p "Press Enter to continue..."
        return
    fi


    highest_num=0
    for service in $(systemctl list-units --type=service | grep hemi- | awk '{print $1}'); do
        num=$(echo $service | grep -o '[0-9]\+' | head -1)
        if [ -n "$num" ] && [ "$num" -gt "$highest_num" ]; then
            highest_num=$num
        fi
    done


    start_num=$((highest_num + 1))

    for (( i=0; i<$wallet_count; i++ )); do
        current_num=$((start_num + i))
        show "Importing wallet $((i+1)) (Service #$current_num)..."
        read -p "Enter private key for wallet $((i+1)): " priv_key
        

        if [ -z "$priv_key" ]; then
            show "Private key cannot be empty. Skipping wallet $((i+1))."
            continue
        fi

        read -p "Enter static fee for wallet $((i+1)) (numerical only, recommended: 100-200): " static_fee
        

        if ! [[ "$static_fee" =~ ^[0-9]+$ ]]; then
            show "Invalid fee. Please enter a numerical value. Skipping wallet $((i+1))."
            continue
        fi
        echo


        if ! sudo tee /etc/systemd/system/hemi-$current_num.service > /dev/null <<EOF
[Unit]
Description=Hemi Network popmd Service - Wallet $current_num
After=network.target

[Service]
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/popmd
Environment="POPM_BTC_PRIVKEY=$priv_key"
Environment="POPM_STATIC_FEE=$static_fee"
Environment="POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
        then
            show "Failed to create service file for wallet $((i+1))"
            continue
        fi


        if ! sudo systemctl daemon-reload; then
            show "Failed to reload systemd for wallet $((i+1))"
            continue
        fi

        if ! sudo systemctl enable hemi-$current_num.service; then
            show "Failed to enable service for wallet $((i+1))"
            continue
        fi

        if ! sudo systemctl start hemi-$current_num.service; then
            show "Failed to start service for wallet $((i+1))"
            continue
        fi

        show "Service hemi-$current_num.service is successfully started for wallet $((i+1))"
        

        if systemctl is-active --quiet hemi-$current_num.service; then
            show "Service is running successfully"
        else
            show "Warning: Service may not be running properly"
        fi
        echo
    done
    
    show "Import process completed"
    read -p "Press Enter to continue..."
}

view_existing_wallets() {
    systemctl list-units --type=service | grep hemi-
    read -p "Press Enter to continue..."
}

restart_all_services() {
    show "Restarting all Hemi Network services..."
    local services=$(systemctl list-units --type=service | grep hemi- | awk '{print $1}')
    
    if [ -z "$services" ]; then
        show "No Hemi services found."
        read -p "Press Enter to continue..."
        return
    fi

    for service in $services; do
        show "Restarting $service..."
        sudo systemctl restart $service
        sleep 2
        if systemctl is-active --quiet $service; then
            show "$service restarted successfully"
        else
            show "Failed to restart $service"
        fi
    done
    
    show "All services have been restarted."
    read -p "Press Enter to continue..."
}

update_hemi_network() {
    show "Checking for updates..."
    local CURRENT_VERSION=""
    local NEW_VERSION=""

    if [ -d "heminetwork_"*"_linux_"* ]; then
        CURRENT_VERSION=$(ls -d heminetwork_*_linux_* | cut -d'_' -f2)
    fi

    NEW_VERSION=$(curl -s https://api.github.com/repos/hemilabs/heminetwork/releases/latest | jq -r '.tag_name')

    if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
        show "You already have the latest version ($CURRENT_VERSION)"
        read -p "Do you want to force update? (y/N): " force_update
        if [[ ! "$force_update" =~ ^[Yy]$ ]]; then
            return
        fi
    fi

    show "Updating to version $NEW_VERSION..."

    local services=$(systemctl list-units --type=service | grep hemi- | awk '{print $1}')
    local working_dir=$(pwd)

    if [ -n "$services" ]; then
        show "Stopping all Hemi services..."
        for service in $services; do
            sudo systemctl stop $service
        done
    fi

    cd ..
    rm -rf heminetwork_*_linux_*

    if [ "$ARCH" == "x86_64" ]; then
        show "Downloading new version for x86_64..."
        wget --quiet --show-progress "https://github.com/hemilabs/heminetwork/releases/download/$NEW_VERSION/heminetwork_${NEW_VERSION}_linux_amd64.tar.gz"
        tar -xzf "heminetwork_${NEW_VERSION}_linux_amd64.tar.gz"
        rm "heminetwork_${NEW_VERSION}_linux_amd64.tar.gz"
        cd "heminetwork_${NEW_VERSION}_linux_amd64"
    elif [ "$ARCH" == "arm64" ]; then
        show "Downloading new version for arm64..."
        wget --quiet --show-progress "https://github.com/hemilabs/heminetwork/releases/download/$NEW_VERSION/heminetwork_${NEW_VERSION}_linux_arm64.tar.gz"
        tar -xzf "heminetwork_${NEW_VERSION}_linux_arm64.tar.gz"
        rm "heminetwork_${NEW_VERSION}_linux_arm64.tar.gz"
        cd "heminetwork_${NEW_VERSION}_linux_arm64"
    fi

    if [ -n "$services" ]; then
        show "Updating service configurations..."
        for service in $services; do
            sudo sed -i "s|WorkingDirectory=.*|WorkingDirectory=$(pwd)|" /etc/systemd/system/$service
            sudo sed -i "s|ExecStart=.*|ExecStart=$(pwd)/popmd|" /etc/systemd/system/$service
        done

        show "Restarting services..."
        sudo systemctl daemon-reload
        for service in $services; do
            sudo systemctl restart $service
            show "Restarted $service"
        done
    fi

    show "Update completed successfully!"
    read -p "Press Enter to continue..."
}

remove_all_services() {
    show "WARNING: This will remove all Hemi Network services and their configurations."
    read -p "Are you sure you want to continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return
    fi

    local services=$(systemctl list-units --type=service | grep hemi- | awk '{print $1}')
    
    if [ -z "$services" ]; then
        show "No Hemi services found."
        read -p "Press Enter to continue..."
        return
    fi

    show "Stopping and removing all Hemi services..."
    for service in $services; do
        show "Processing $service..."
        sudo systemctl stop $service
        sudo systemctl disable $service
        sudo rm /etc/systemd/system/$service
        show "Removed $service"
    done

    sudo systemctl daemon-reload
    show "All Hemi services have been removed."
    
    read -p "Do you want to remove all Hemi Network files as well? (y/N): " remove_files
    if [[ "$remove_files" =~ ^[Yy]$ ]]; then
        cd ..
        rm -rf heminetwork_*_linux_*
        show "All Hemi Network files have been removed."
    fi

    read -p "Press Enter to continue..."
}

update_fee_for_all_miners() {
    show "Updating Fee for All Miners"
    read -p "Enter new static fee for all miners (numerical only): " new_fee
    
    if ! [[ "$new_fee" =~ ^[0-9]+$ ]]; then
        show "Invalid input. Please enter a numerical value."
        read -p "Press Enter to continue..."
        return
    fi
    
    local services=$(systemctl list-units --type=service | grep hemi- | awk '{print $1}')
    
    if [ -z "$services" ]; then
        show "No Hemi services found."
        read -p "Press Enter to continue..."
        return
    fi
    
    for service in $services; do
        show "Updating fee for $service..."
        sudo sed -i "s/Environment=\"POPM_STATIC_FEE=.*/Environment=\"POPM_STATIC_FEE=$new_fee\"/" /etc/systemd/system/$service
        sudo systemctl daemon-reload
        sudo systemctl restart $service
    done
    
    show "Fee updated and services restarted for all miners."
    read -p "Press Enter to continue..."
}

check_dependencies() {
    if ! command -v jq &> /dev/null; then
        show "jq not found, installing..."
        sudo apt-get update
        sudo apt-get install -y jq > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            show "Failed to install jq."
            exit 1
        fi
    fi
}

check_latest_version() {
    for i in {1..3}; do
        LATEST_VERSION=$(curl -s https://api.github.com/repos/hemilabs/heminetwork/releases/latest | jq -r '.tag_name')
        if [ -n "$LATEST_VERSION" ]; then
            show "Latest version available: $LATEST_VERSION"
            return 0
        fi
        show "Attempt $i: Failed to fetch the latest version. Retrying..."
        sleep 2
    done
    show "Failed to fetch the latest version after 3 attempts."
    exit 1
}

main() {
    check_dependencies
    check_latest_version

    download_required=true

    if [ "$ARCH" == "x86_64" ]; then
        if [ -d "heminetwork_${LATEST_VERSION}_linux_amd64" ]; then
            cd "heminetwork_${LATEST_VERSION}_linux_amd64" || exit 1
            download_required=false
        fi
    elif [ "$ARCH" == "arm64" ]; then
        if [ -d "heminetwork_${LATEST_VERSION}_linux_arm64" ]; then
            cd "heminetwork_${LATEST_VERSION}_linux_arm64" || exit 1
            download_required=false
        fi
    fi

    if [ "$download_required" = true ]; then
        if [ "$ARCH" == "x86_64" ]; then
            show "Downloading for x86_64 architecture..."
            wget --quiet --show-progress "https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz"
            tar -xzf "heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz"
            rm "heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz"
            cd "heminetwork_${LATEST_VERSION}_linux_amd64" || exit 1
        elif [ "$ARCH" == "arm64" ]; then
            show "Downloading for arm64 architecture..."
            wget --quiet --show-progress "https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz"
            tar -xzf "heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz"
            rm "heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz"
            cd "heminetwork_${LATEST_VERSION}_linux_arm64" || exit 1
        else
            show "Unsupported architecture: $ARCH"
            exit 1
        fi
    fi

    while true; do
        show_menu
        case $choice in
            1) create_new_wallets ;;
            2) import_existing_wallets ;;
            3) view_existing_wallets ;;
            4) restart_all_services ;;
            5) update_hemi_network ;;
            6) update_fee_for_all_miners ;;
            7) remove_all_services ;;
            8) show "Exiting..."; exit 0 ;;
            *) show "Invalid option. Please try again." ;;
        esac
    done
}

main
