#!/usr/bin/env bash
# Switch the suspend path back to elogind.
#
# Counterpart to setup-zzz-acpid.sh; the two scripts toggle between:
#   elogind mode - elogind handles lid/sleep/power events itself and
#                 runs the hook in /etc/elogind/system-sleep
#   zzz mode     - acpid handles those events and calls zzz, which
#                 runs the CPU hooks in /etc/zzz.d
#
# This script:
# - reinstalls the elogind system-sleep hook (copy, no symlinks)
# - removes the logind.conf.d drop-in that made elogind ignore the
#   lid switch, suspend key and power key
# - disables acpid (its zzz calls are the old mechanism)
# - removes the zzz hooks and the zzz sudoers rule (loginctl power
#   actions need no sudo)
#
# elogind itself stays enabled for session/seat management; after this
# script it also handles ACPI events again. acpid is only disabled, not
# removed - run `sudo xbps-remove -R acpid` if you want it gone.
#
# Usage: sudo bash setup-elogind.sh   (from the repo root)
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo: sudo $0" >&2
  exit 1
fi

HOOK_SRC="$(cd "$(dirname "$0")/elogind" && pwd)"
HOOK_DIR=/etc/elogind/system-sleep
HOOK=10-macbook-cpu

if [[ ! -f "$HOOK_SRC/system-sleep/$HOOK" ]]; then
  echo "Hook script not found under $HOOK_SRC - run from the repo root." >&2
  exit 1
fi

# --- 1. elogind sleep hook (copy, no symlinks) -----------------------------
install -d "$HOOK_DIR"
install -m 755 "$HOOK_SRC/system-sleep/$HOOK" "$HOOK_DIR/$HOOK"
echo "Installed hook: $HOOK_DIR/$HOOK"

# --- 2. elogind handles ACPI events again ----------------------------------
rm -f /etc/elogind/logind.conf.d/50-zzz-acpid.conf
echo "Removed logind.conf.d drop-in (default event handling restored)"
sv restart elogind 2>/dev/null || echo "Note: could not restart elogind; defaults apply on next boot."

# --- 3. disable acpid --------------------------------------------------------
if [[ -e /var/service/acpid || -L /var/service/acpid ]]; then
  sv down acpid 2>/dev/null || true
  rm -f /var/service/acpid
  echo "Disabled service: acpid"
else
  echo "acpid already disabled"
fi

# --- 4. remove zzz hooks and sudoers rule ------------------------------------
rm -f /etc/zzz.d/suspend/10-macbook-cpu-offline \
      /etc/zzz.d/resume/10-macbook-cpu-online \
      /etc/sudoers.d/zzz
echo "Removed zzz hooks and sudoers rule (loginctl needs no sudo)"

if [[ ! -e /var/service/elogind && -d /etc/sv/elogind ]]; then
  ln -s /etc/sv/elogind /var/service/
fi
echo "elogind enabled"

echo
echo "Done. In elogind mode, suspend with:"
echo "  loginctl suspend       # or close the lid / press the sleep button / Noctalia button"
echo "Verify after waking:"
echo "  cat /sys/devices/system/cpu/online   # should be 0-7"
echo "  journalctl -t elogind-cpu-hook -b    # hook log lines"
echo "  cat /sys/power/mem_sleep             # deep should be selected ([deep])"
