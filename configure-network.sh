#!/usr/bin/env bash
# Switch networking to NetworkManager.
# Usage: sudo ./configure-network.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo: sudo $0" >&2
  exit 1
fi

TARGET_USER="${SUDO_USER:-}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
  echo "Run via sudo from your normal user account." >&2
  exit 1
fi

log() { printf '\n==> %s\n' "$*"; }

log "Adding $TARGET_USER to the network group"
usermod -aG network "$TARGET_USER"

log "Enabling NetworkManager"
[[ -e /var/service/NetworkManager ]] || ln -s /etc/sv/NetworkManager /var/service/

log "Disabling dhcpcd"
rm -f /var/service/dhcpcd

log "Disabling wpa_supplicant"
rm -f /var/service/wpa_supplicant

log "NetworkManager is now the network manager."
log "Log out and back in (or reboot) for the network group to apply."
log "To configure Wi-Fi, run: nmtui   (or use nmcli)"
