#!/usr/bin/env bash

echo "=========================================="
echo "🚀 Welcome to forge-secure-deploy setup! "
echo "=========================================="
echo "This script will generate your deploy.toml configuration file."
echo ""

if [ -f "deploy.toml" ]; then
    read -p "⚠️  A deploy.toml already exists. Overwrite? (y/n): " overwrite
    if [[ "$overwrite" != "y" ]]; then
        echo "Setup aborted. Existing deploy.toml kept."
        exit 0
    fi
fi

echo ""
echo "--- Keystore Configuration ---"
echo "Foundry recommends using encrypted keystores instead of raw private keys."
read -p "? What Foundry keystore name do you use for Testnets? (e.g. devWallet): " testnet_keystore
testnet_keystore=${testnet_keystore:-devWallet}

read -p "? What Foundry keystore name do you use for Mainnets? (e.g. coldWallet): " mainnet_keystore
mainnet_keystore=${mainnet_keystore:-coldWallet}

echo ""
echo "--- Address Configuration ---"
read -p "? Enter your Sepolia deployer address (0x...): " sepolia_address
sepolia_address=${sepolia_address:-0x0000000000000000000000000000000000000000}

read -p "? Enter your Mainnet deployer address (0x...): " mainnet_address
mainnet_address=${mainnet_address:-0x0000000000000000000000000000000000000000}

echo ""
echo "Generating deploy.toml..."

cat <<EOF > deploy.toml
[accounts]
local        = "anvil"
sepolia      = "$testnet_keystore"
mainnet      = "$mainnet_keystore"

[addresses]
local        = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
sepolia      = "$sepolia_address"
mainnet      = "$mainnet_address"

[rpc]
local        = "http://127.0.0.1:8545"
sepolia      = "\${SEPOLIA_RPC_URL}"
mainnet      = "\${MAINNET_RPC_URL}"
EOF

echo "✅ deploy.toml successfully generated!"
echo "Make sure to set your RPC environment variables before broadcasting."
echo "=========================================="
