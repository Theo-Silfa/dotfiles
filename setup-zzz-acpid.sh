#!/usr/bin/env bash
# Switch the suspend path back to zzz + acpid.
#
# Counterpart to setup-elogind.sh; the two scripts toggle between:
#   zzz mode    - acpid handles lid/sleep/power events and calls zzz,
#                 which runs the CPU hooks in /etc/zzz.d
#   elogind mode - elogind handles those events itself and runs the
#                 hook in /etc/elogind/system-sleep
#
# This script:
# - installs the zzz suspend/resume hooks (copy, no symlinks)
# - installs the passwordless sudoers rule for zzz/reboot/poweroff
# - installs/enables acpid
# - makes elogind ignore the ACPI events acpid now handles (lid switch,
#   suspend key, power key) via a logind.conf.d drop-in, so the two
#   never double-suspend or double-shutdown
# - removes the elogind system-sleep hook (one mechanism at a time;
#   `loginctl suspend` still suspends, but without the CPU offlining)
#
# elogind itself stays enabled - it is still needed for session/seat
# management. Only its ACPI event handling is turned off.
#
# Usage: sudo bash setup-zzz-acpid.sh   (from the repo root)
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

HOOK_SRC="$(cd "$(dirname "$0")/zzz" && pwd)"
SUSPEND_DIR=/etc/zzz.d/suspend
RESUME_DIR=/etc/zzz.d/resume

if [[ ! -f "$HOOK_SRC/suspend/10-macbook-cpu-offline" || ! -f "$HOOK_SRC/resume/10-macbook-cpu-online" ]]; then
  echo "Hook scripts not found under $HOOK_SRC - run from the repo root." >&2
  exit 1
fi

# --- 1. zzz hooks (copy, no symlinks) ------------------------------------
install -d "$SUSPEND_DIR" "$RESUME_DIR"
install -m 755 "$HOOK_SRC/suspend/10-macbook-cpu-offline" "$SUSPEND_DIR/10-macbook-cpu-offline"
install -m 755 "$HOOK_SRC/resume/10-macbook-cpu-online"   "$RESUME_DIR/10-macbook-cpu-online"
echo "Installed hooks:"
ls -l "$SUSPEND_DIR/10-macbook-cpu-offline" "$RESUME_DIR/10-macbook-cpu-online"

# --- 2. passwordless sudo: zzz / reboot / poweroff ------------------------
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
  echo "Installed sudoers rule ($SUDOERS_FILE):"
  cat "$SUDOERS_FILE"
else
  rm -f "$SUDOERS_TMP"
  echo "ERROR: generated sudoers rule failed visudo validation; not installed." >&2
  exit 1
fi

# --- 3. acpid --------------------------------------------------------------
# Void's default /etc/acpi/handler.sh calls zzz on lid close and the sleep
# button, and shuts down on the power button.
if ! xbps-query acpid >/dev/null 2>&1; then
  xbps-install -Sy acpid
fi
if [[ -d /etc/sv/acpid && ! -e /var/service/acpid ]]; then
  ln -s /etc/sv/acpid /var/service/
fi
echo "acpid installed and enabled"

# --- 4. elogind: ignore events acpid handles ------------------------------
# With both enabled, elogind suspends on lid close before zzz is called,
# and zzz then suspends the just-resumed system again (double suspend);
# the power button would race poweroff against shutdown. So elogind
# ignores the lid switch, suspend key and power key - exactly the events
# Void's handler.sh acts on. Hibernate key handling is left with elogind
# (handler.sh does not act on it).
LOGIND_DROPIN_DIR=/etc/elogind/logind.conf.d
LOGIND_DROPIN="$LOGIND_DROPIN_DIR/50-zzz-acpid.conf"

install -d "$LOGIND_DROPIN_DIR"
cat > "$LOGIND_DROPIN" <<'EOF'
# zzz + acpid mode: acpid's handler.sh acts on these events
# (lid close / sleep button -> zzz, power button -> shutdown),
# so elogind must ignore them. Removed by setup-elogind.sh.
[Login]
HandleLidSwitch=ignore
HandleSuspendKey=ignore
HandlePowerKey=ignore
EOF
echo "Installed elogind drop-in: $LOGIND_DROPIN"

# Apply the new configuration to the running elogind.
sv restart elogind 2>/dev/null || echo "Note: could not restart elogind; the drop-in applies on next boot."

# --- 5. remove the elogind sleep hook --------------------------------------
rm -f /etc/elogind/system-sleep/10-macbook-cpu
echo "Removed elogind system-sleep hook (zzz hooks are the single mechanism now)"

echo
echo "Done. In zzz mode, suspend with:"
echo "  sudo -n /usr/bin/zzz          # or close the lid / press the sleep button"
echo "Verify after waking:"
echo "  cat /sys/devices/system/cpu/online   # should be 0-7"
echo "  journalctl -t zzz-macbook-cpu -b     # hook log lines"
echo "  grep -r . /etc/elogind/logind.conf.d/ # should show the ignore drop-in"
