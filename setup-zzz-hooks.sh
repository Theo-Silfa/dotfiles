#!/usr/bin/env bash
# Install zzz suspend/resume hooks (MacBookPro11,5 CPU-resume workaround).
# Copies the hook scripts into /etc/zzz.d - no symlinks, so the installed
# hooks keep working even if this repo checkout is moved or deleted.
# Usage: sudo bash setup-zzz-hooks.sh   (from the repo root)
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo: sudo $0" >&2
  exit 1
fi

HOOK_SRC="$(cd "$(dirname "$0")/zzz" && pwd)"
SUSPEND_DIR=/etc/zzz.d/suspend
RESUME_DIR=/etc/zzz.d/resume

if [[ ! -f "$HOOK_SRC/suspend/10-macbook-cpu-offline" || ! -f "$HOOK_SRC/resume/10-macbook-cpu-online" ]]; then
  echo "Hook scripts not found under $HOOK_SRC - run from the repo root." >&2
  exit 1
fi

install -d "$SUSPEND_DIR" "$RESUME_DIR"

# install(1) = copy + set mode; overwrite in place on re-runs.
install -m 755 "$HOOK_SRC/suspend/10-macbook-cpu-offline" "$SUSPEND_DIR/10-macbook-cpu-offline"
install -m 755 "$HOOK_SRC/resume/10-macbook-cpu-online"   "$RESUME_DIR/10-macbook-cpu-online"

echo "Installed hooks:"
ls -l "$SUSPEND_DIR/10-macbook-cpu-offline" "$RESUME_DIR/10-macbook-cpu-online"

echo
echo "Quick check (does not suspend):"
echo "  sudo zzz -n        # dry run: hooks run, 5s pause, resume hooks run"
echo "  cat /sys/devices/system/cpu/online   # should still be 0-7"
echo
echo "Real test:"
echo "  sudo zzz            # press power button to wake"
echo "  cat /sys/devices/system/cpu/online   # should be 0-7"
