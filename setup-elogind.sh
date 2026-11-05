#!/usr/bin/env bash
# Migrate to elogind + loginctl.
#
# - Installs the elogind system-sleep hook (MacBookPro11,5 CPU-resume
#   workaround): copy into /etc/elogind/system-sleep, no symlinks.
# - Installs/enables elogind, disables turnstiled/seatd/acpid.
# - Removes the old zzz hooks and the zzz sudoers rule (loginctl power
#   actions need no sudo).
# - Removes the turnstile and seatd packages and related settings
#   (_seatd group membership).
#
# Usage: sudo bash setup-elogind.sh   (from the repo root)
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

HOOK_SRC="$(cd "$(dirname "$0")/elogind" && pwd)"
HOOK_DIR=/etc/elogind/system-sleep
HOOK=10-macbook-cpu

if [[ ! -f "$HOOK_SRC/system-sleep/$HOOK" ]]; then
  echo "Hook script not found under $HOOK_SRC - run from the repo root." >&2
  exit 1
fi

# --- 1. elogind sleep hook (copy, no symlinks) --------------------------
install -d "$HOOK_DIR"
install -m 755 "$HOOK_SRC/system-sleep/$HOOK" "$HOOK_DIR/$HOOK"
echo "Installed hook: $HOOK_DIR/$HOOK"

# --- 2. install/enable elogind -------------------------------------------
if ! xbps-query elogind >/dev/null 2>&1; then
  xbps-install -Sy elogind
fi
if [[ -d /etc/sv/elogind && ! -e /var/service/elogind ]]; then
  ln -s /etc/sv/elogind /var/service/
fi
echo "elogind installed and enabled"

# --- 3. disable services elogind replaces --------------------------------
# turnstiled + seatd: being replaced by elogind.
# acpid: its handler only calls zzz on lid/sleep button; elogind handles
# those events itself, and keeping both causes a double suspend.
for svc in turnstiled seatd acpid; do
  if [[ -e "/var/service/$svc" || -L "/var/service/$svc" ]]; then
    rm -f "/var/service/$svc"
    echo "Disabled service: $svc"
  fi
done

# --- 4. remove old zzz hooks and sudoers rule -----------------------------
rm -f /etc/zzz.d/suspend/10-macbook-cpu-offline \
      /etc/zzz.d/resume/10-macbook-cpu-online \
      /etc/sudoers.d/zzz
echo "Removed old zzz hooks and sudoers rule (loginctl needs no sudo)"

# --- 5. remove turnstile and seatd packages ------------------------------
if getent group _seatd >/dev/null 2>&1; then
  gpasswd -d "$TARGET_USER" _seatd >/dev/null 2>&1 || true
  echo "Removed $TARGET_USER from the _seatd group"
fi

TO_REMOVE=()
for pkg in turnstile seatd; do
  xbps-query "$pkg" >/dev/null 2>&1 && TO_REMOVE+=("$pkg")
done
if ((${#TO_REMOVE[@]})); then
  echo "Removing packages: ${TO_REMOVE[*]}"
  if ! xbps-remove -Ry "${TO_REMOVE[@]}"; then
    echo "WARNING: package removal failed - check reverse dependencies:" >&2
    for pkg in "${TO_REMOVE[@]}"; do
      xbps-query -X "$pkg" >&2 || true
    done
    echo "Resolve the above, then re-run this script." >&2
  fi
fi

echo
echo "Done. Remaining manual steps:"
echo "  1. Remove the [shell.session.power] overrides from your"
echo "     ~/.config/noctalia/*.toml so Noctalia uses loginctl again:"
echo "       noctalia config export | grep -A5 session.power   # verify"
echo "  2. If your graphical session was launched through turnstile"
echo "     (turnstile-run / turnstile user services), switch to launching"
echo "     mango under a PAM login session, e.g. from a tty:"
echo "       dbus-run-session mango"
echo "     (elogind provides XDG_RUNTIME_DIR and the seat at login)"
echo "  3. Reboot."
echo "  4. Verify after login:"
echo "       loginctl            # session listed, should show Active=yes"
echo "       echo \$XDG_RUNTIME_DIR   # /run/user/\$(id -u)"
echo "  5. Test suspend (UI button and lid close):"
echo "       loginctl suspend; cat /sys/devices/system/cpu/online  # 0-7"
echo "     Wake should be ~6-7s as before."
