#!/usr/bin/env bash
# Install zzz suspend/resume hooks (MacBookPro11,5 CPU-resume workaround)
# and passwordless sudo rules for suspend/reboot/poweroff.
#
# Hooks are copied into /etc/zzz.d - no symlinks, so the installed hooks
# keep working even if this repo checkout is moved or deleted.
#
# Usage: sudo bash setup-zzz-hooks.sh   (from the repo root)
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo: sudo $0" >&2
  exit 1
fi

# The sudoers rule is written for the user who invoked sudo.
TARGET_USER="${SUDO_USER:-}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
  echo "Run via sudo from your normal user account." >&2
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

# --- Passwordless sudo: suspend / reboot / poweroff ----------------------
# One line; "" after each command means it may only be run WITHOUT
# arguments (so e.g. `zzz -n` or `reboot now` still need a password).
# The file is named 'zzz' so it sorts after the installer's 'wheel' file
# in sudoers.d; sudo uses last-match-wins, so NOPASSWD wins for these
# exact commands only.
SUDOERS_FILE=/etc/sudoers.d/zzz
SUDOERS_TMP="$SUDOERS_FILE.tmp"

cat > "$SUDOERS_TMP" <<EOF
$TARGET_USER ALL=(root) NOPASSWD: /usr/bin/zzz "", /usr/bin/reboot "", /usr/bin/poweroff ""
EOF

chown root:root "$SUDOERS_TMP"
chmod 440 "$SUDOERS_TMP"

# Only install if it parses; otherwise leave any existing rule untouched.
if visudo -cf "$SUDOERS_TMP" > /dev/null; then
  mv "$SUDOERS_TMP" "$SUDOERS_FILE"
  echo
  echo "Installed sudoers rule ($SUDOERS_FILE):"
  cat "$SUDOERS_FILE"
else
  rm -f "$SUDOERS_TMP"
  echo "ERROR: generated sudoers rule failed visudo validation; not installed." >&2
  exit 1
fi

echo
echo "Quick check:"
echo "  sudo -n -l | tail -5    # should list NOPASSWD: the three commands"
echo "  sudo zzz -n             # dry run (password needed: -n arg is not in the rule)"
echo "  cat /sys/devices/system/cpu/online   # should still be 0-7"
echo
echo "Real test:"
echo "  sudo -n /usr/bin/zzz    # suspends with no password; power button to wake"
echo "  cat /sys/devices/system/cpu/online   # should be 0-7"
