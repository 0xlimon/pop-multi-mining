#!/bin/bash

curl -s https://raw.githubusercontent.com/zunxbt/logo/main/logo.sh | bash

sleep 3

ARCH=$(uname -m)

show() {
    echo -e "\033[1;35m$1\033[0m"
}

if ! command -v jq &> /dev/null; then
    show "jq not found, installing..."
    sudo apt-get update
    sudo apt-get install -y jq > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        show "Failed to install jq. Please check your package manager."
        exit 1
    fi
fi

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

    show "Failed to fetch the latest version after 3 attempts. Please check your internet connection or GitHub API limits."
    exit 1
}

check_latest_version

download_required=true

if [ "$ARCH" == "x86_64" ]; then
    if [ -d "heminetwork_${LATEST_VERSION}_linux_amd64" ]; then
        show "Latest version for x86_64 is already downloaded. Skipping download."
        cd "heminetwork_${LATEST_VERSION}_linux_amd64" || { show "Failed to change directory."; exit 1; }
        download_required=false
    fi
elif [ "$ARCH" == "arm64" ]; then
    if [ -d "heminetwork_${LATEST_VERSION}_linux_arm64" ]; then
        show "Latest version for arm64 is already downloaded. Skipping download."
        cd "heminetwork_${LATEST_VERSION}_linux_arm64" || { show "Failed to change directory."; exit 1; }
        download_required=false
    fi
fi

if [ "$download_required" = true ]; then
    if [ "$ARCH" == "x86_64" ]; then
        show "Downloading for x86_64 architecture..."
        wget --quiet --show-progress "https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz" -O "heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz"
        if [ $? -ne 0 ]; then
            show "Failed to download for x86_64 architecture."
            exit 1
        fi
        tar -xzf "heminetwork_${LATEST_VERSION}_linux_amd64.tar.gz" > /dev/null
        cd "heminetwork_${LATEST_VERSION}_linux_amd64" || { show "Failed to change directory."; exit 1; }
    elif [ "$ARCH" == "arm64" ]; then
        show "Downloading for arm64 architecture..."
        wget --quiet --show-progress "https://github.com/hemilabs/heminetwork/releases/download/$LATEST_VERSION/heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz" -O "heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz"
        if [ $? -ne 0 ]; then
            show "Failed to download for arm64 architecture."
            exit 1
        fi
        tar -xzf "heminetwork_${LATEST_VERSION}_linux_arm64.tar.gz" > /dev/null
        cd "heminetwork_${LATEST_VERSION}_linux_arm64" || { show "Failed to change directory."; exit 1; }
    else
        show "Unsupported architecture: $ARCH"
        exit 1
    fi
else
    show "Skipping download as the latest version is already present."
fi

read -p "How many wallets do you want to create? " wallet_count
echo

output_file="wallets_info.json"
echo "[]" > $output_file 

for (( i=1; i<=$wallet_count; i++ )); do
    show "Creating wallet $i..."

    ./keygen -secp256k1 -json -net="testnet" > ~/popm-address-$i.json
    if [ $? -ne 0 ]; then
        show "Failed to generate wallet $i."
        exit 1
    fi
    
    priv_key=$(jq -r '.private_key' ~/popm-address-$i.json)
    pubkey_hash=$(jq -r '.pubkey_hash' ~/popm-address-$i.json)
    
    show "Wallet $i details:"
    cat ~/popm-address-$i.json
    echo
    
    jq ". += [{\"wallet_number\": $i, \"private_key\": \"$priv_key\", \"pubkey_hash\": \"$pubkey_hash\"}]" $output_file > tmp.json && mv tmp.json $output_file
    
    show "Join: https://discord.gg/hemixyz"
    show "Request faucet from faucet channel to this address: $pubkey_hash"
    echo
    read -p "Have you requested faucet for wallet $i? (y/N): " faucet_requested
    if [[ "$faucet_requested" =~ ^[Yy]$ ]]; then
        read -p "Enter static fee for wallet $i (numerical only, recommended: 100-200): " static_fee
        echo
    else
        show "Skipping wallet $i due to faucet not requested."
        continue
    fi

    show "Creating service for wallet $i..."

    sudo tee /etc/systemd/system/hemi-$i.service > /dev/null <<EOF
[Unit]
Description=Hemi Network popmd Service - Wallet $i
After=network.target

[Service]
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/popmd
Environment="POPM_BFG_REQUEST_TIMEOUT=60s"
Environment="POPM_BTC_PRIVKEY=$priv_key"
Environment="POPM_STATIC_FEE=$static_fee"
Environment="POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable hemi-$i.service
    sudo systemctl start hemi-$i.service
    show "Service hemi-$i.service is successfully started for wallet $i"
    echo
done

show "All wallets and services are created successfully. Check '$output_file' for wallet information."
