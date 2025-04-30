#!/usr/bin/env bash
set -euo pipefail

RULES="./infra/firewall/rules.nft"

if [[ $EUID -ne 0 ]]; then
  echo "[!] Run as root: sudo $0"
  exit 1
fi

echo "[+] Applying nftables firewall rules..."
nft -f "$RULES"
nft list ruleset