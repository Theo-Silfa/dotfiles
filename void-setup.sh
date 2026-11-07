#!/usr/bin/env bash
# Void Linux post-install bootstrap script
# Usage: sudo ./void-setup.sh
# Packages are installed as root; user configs are set up as the invoking user.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo: sudo $0" >&2
  exit 1
fi

TARGET_USER="${SUDO_USER:-}"
if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
  echo "Run via sudo from your normal user account so configs go to your home." >&2
  exit 1
fi
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

# Packages to install - extend this list as needed
PACKAGES=(
  git
  curl
  neovim
  btop
  fzf
  tmux
  cargo
  tree-sitter-cli
  mangowc
  ghostty
  bash-completion
  wl-clipboard
  # Intel essentials (sway wiki, "Intel users")
  intel-ucode          # needs the nonfree repo
  mesa-vulkan-intel
  intel-media-driver
  libva-intel-driver
  intel-gpu-tools
  # graphics drivers and firmware
  mesa-dri
  linux-firmware-intel
  linux-firmware-amd
  # session: system bus, seat/session management (elogind)
  dbus
  # autostarts
  dex
  # network
  NetworkManager
  # power plans, battery
  upower
  tlp
  tlp-pd
  # authorization for tlp-pd and brillo pkexec
  polkit
  # audio
  pipewire
  # shell
  noctalia
  # for fans to work properly
  mbpfan
  # for keyboard backlight
  brillo
)

NVIM_REPO="https://github.com/Theo-Silfa/init.lua.git"
NVIM_BRANCH="upgrade-to-v0.12"
DOTFILES_REPO="https://github.com/Theo-Silfa/dotfiles.git"

log() { printf '\n==> %s\n' "$*"; }
as_user() { sudo -u "$TARGET_USER" -H "$@"; }

# ---------- root: system packages ----------
log "Updating xbps itself"
xbps-install -Suy xbps

log "Enabling nonfree repository (needed for intel-ucode)"
xbps-install -Sy void-repo-nonfree

log "Enabling Noctalia repository (universalrepo)"
echo 'repository=https://universalrepo.pages.dev/void' > /etc/xbps.d/10-universalrepository.conf
xbps-install -S

log "Updating system"
xbps-install -Suy

log "Installing packages: ${PACKAGES[*]}"
xbps-install -y "${PACKAGES[@]}"

log "Cleaning package cache and orphans"
xbps-remove -Ooy || true

# ---------- root: runit services and groups ----------
SERVICES=(
  dbus
  elogind
  polkitd
  NetworkManager
  tlp
  tlp-pd
  mbpfan
)

log "Enabling runit services: ${SERVICES[*]}"
for svc in "${SERVICES[@]}"; do
  if [[ ! -d "/etc/sv/$svc" ]]; then
    echo "Warning: /etc/sv/$svc not found, skipping" >&2
  elif [[ -e "/var/service/$svc" ]]; then
    echo "$svc already enabled"
  else
    ln -s "/etc/sv/$svc" /var/service/
  fi
done

log "Installing elogind sleep hooks (run from repo root after this script)"
bash "$(dirname "$0")/setup-elogind.sh" || echo "Warning: elogind hook setup failed" >&2

log "Installing brillo polkit policy (keyboard backlight without root)"
POLICY_SRC="$(dirname "$0")/polkit/brillo.policy"
if [[ -f "$POLICY_SRC" ]]; then
  install -Dm 644 "$POLICY_SRC" /usr/share/polkit-1/actions/com.gitlab.CameronNemo.brillo.policy
else
  echo "Warning: $POLICY_SRC not found (repo checkout needed); the Void brillo package ships the same policy anyway" >&2
fi

# ---------- root: autostarts ----------
ln -s /usr/share/applications/pipewire.desktop /etc/xdg/autostart

# ---------- root: GRUB kernel parameters ----------
GRUB_PARAMS=(
  radeon.si_support=1
  amdgpu.si_support=0
  radeon.cik_support=1
  amdgpu.cik_support=0
  intel_iommu=on
  iommu=pt
)
GRUB_FILE=/etc/default/grub

if [[ -f "$GRUB_FILE" ]]; then
  log "Adding kernel parameters to $GRUB_FILE"
  [[ -e "$GRUB_FILE.bak" ]] || cp "$GRUB_FILE" "$GRUB_FILE.bak"
  grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE" \
    || echo 'GRUB_CMDLINE_LINUX_DEFAULT=""' >> "$GRUB_FILE"
  for param in "${GRUB_PARAMS[@]}"; do
    key="${param%%=*}"
    # drop any existing value for this key, then append the desired one
    sed -i -E "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/(\"| )${key//./\\.}=[^\" ]*/\1/g" "$GRUB_FILE"
    sed -i -E "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"$/ ${param}\"/" "$GRUB_FILE"
  done
  # tidy up whitespace
  sed -i -E '/^GRUB_CMDLINE_LINUX_DEFAULT=/ { s/  +/ /g; s/=" /="/; s/ "$/"/ }' "$GRUB_FILE"
  grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_FILE"

  log "Regenerating GRUB config"
  if command -v update-grub >/dev/null 2>&1; then
    update-grub
  else
    grub-mkconfig -o /boot/grub/grub.cfg
  fi
else
  echo "Warning: $GRUB_FILE not found, skipping kernel parameters" >&2
fi

# ---------- root: pipewire-pulse interface ----------
mkdir -p /etc/pipewire/pipewire.conf.d
ln -s /usr/share/examples/pipewire/20-pipewire-pulse.conf /etc/pipewire/pipewire.conf.d/

# ---------- user: dotfiles ----------

log "Installing tmux plugin manager (tpm) for $TARGET_USER"
TPM_DIR="$TARGET_HOME/.tmux/plugins/tpm"
if [[ -d "$TPM_DIR/.git" ]]; then
  as_user git -C "$TPM_DIR" pull --ff-only
else
  as_user mkdir -p "$TARGET_HOME/.tmux/plugins"
  as_user git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

log "Setting up neovim config for $TARGET_USER"
NVIM_DIR="$TARGET_HOME/.config/nvim"
if [[ -d "$NVIM_DIR/.git" ]]; then
  as_user git -C "$NVIM_DIR" fetch origin "$NVIM_BRANCH"
  as_user git -C "$NVIM_DIR" checkout "$NVIM_BRANCH"
  as_user git -C "$NVIM_DIR" pull --ff-only origin "$NVIM_BRANCH"
elif [[ -e "$NVIM_DIR" ]]; then
  BACKUP="$NVIM_DIR.bak.$(date +%s)"
  echo "Existing $NVIM_DIR found, moving to $BACKUP"
  as_user mv "$NVIM_DIR" "$BACKUP"
  as_user git clone --branch "$NVIM_BRANCH" "$NVIM_REPO" "$NVIM_DIR"
else
  as_user git clone --branch "$NVIM_BRANCH" "$NVIM_REPO" "$NVIM_DIR"
fi

log "Setting up dotfiles for $TARGET_USER"
DOTFILES_DIR="$TARGET_HOME/.dotfiles"
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  as_user git -C "$DOTFILES_DIR" pull --ff-only
else
  as_user git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

log "Linking mango config"
MANGO_CONF="$TARGET_HOME/.config/mango/config.conf"
as_user mkdir -p "$TARGET_HOME/.config/mango"
if [[ -e "$MANGO_CONF" && ! -L "$MANGO_CONF" ]]; then
  as_user mv "$MANGO_CONF" "$MANGO_CONF.bak.$(date +%s)"
fi
as_user ln -sfn "$DOTFILES_DIR/mango/config.conf" "$MANGO_CONF"

log "Linking tmux config"
TMUX_CONF="$TARGET_HOME/.config/tmux/tmux.conf"
as_user mkdir -p "$TARGET_HOME/.config/tmux"
if [[ -e "$TMUX_CONF" && ! -L "$TMUX_CONF" ]]; then
  as_user mv "$TMUX_CONF" "$TMUX_CONF.bak.$(date +%s)"
fi
as_user ln -sfn "$DOTFILES_DIR/tmux/tmux.conf" "$TMUX_CONF"

log "Linking bashrc"
BASHRC="$TARGET_HOME/.bashrc"
if [[ -e "$BASHRC" && ! -L "$BASHRC" ]]; then
  as_user mv "$BASHRC" "$BASHRC.bak.$(date +%s)"
fi
as_user ln -sfn "$DOTFILES_DIR/bashrc" "$BASHRC"

log "Done."
