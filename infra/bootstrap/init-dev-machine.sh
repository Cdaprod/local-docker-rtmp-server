#!/usr/bin/env bash
set -euo pipefail

echo "[*] Initializing Cdaprod Dev Machine"

# Install tools if needed
sudo apt-get update
sudo apt-get install -y nftables docker docker-compose

# Set up hosts
sudo ./infra/hosts/link-hosts.sh

# Apply firewall
sudo ./infra/firewall/apply-firewall.sh

echo "[✓] Dev machine initialized"