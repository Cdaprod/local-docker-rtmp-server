#!/usr/bin/env bash

set -euo pipefail

HOSTS_SRC="$(dirname "$0")/hosts.local.template"
HOSTS_DST="/etc/hosts"
BACKUP_PATH="/etc/hosts.backup"

if [[ $EUID -ne 0 ]]; then
  echo "[!] Please run as root: sudo $0"
  exit 1
fi

echo "[+] Backing up current hosts file to $BACKUP_PATH"
cp "$HOSTS_DST" "$BACKUP_PATH"

echo "[+] Appending custom entries from $HOSTS_SRC"
grep -vFf <(grep -oP '^\s*\d+\.\d+\.\d+' "$HOSTS_SRC") "$HOSTS_DST" > /tmp/hosts.updated
cat "$HOSTS_SRC" >> /tmp/hosts.updated

mv /tmp/hosts.updated "$HOSTS_DST"
echo "[+] Updated /etc/hosts:"
grep cdaprod "$HOSTS_DST"