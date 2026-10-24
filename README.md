# dotfiles

Personal dotfiles.

- `sway/config` -> `~/.config/sway/config`
- `bashrc` -> `~/.bashrc`
- `tmux/tmux.conf` -> `~/.config/tmux/tmux.conf`

## Void Linux setup

On a fresh Void install, run from your normal user account:

```
curl -LO https://raw.githubusercontent.com/Theo-Silfa/dotfiles/main/void-setup.sh
sudo bash void-setup.sh
```

## Network

`configure-network.sh` switches to NetworkManager and turns off dhcpcd and wpa_supplicant:

```
curl -LO https://raw.githubusercontent.com/Theo-Silfa/dotfiles/main/configure-network.sh
sudo bash configure-network.sh
```

Then run `nmtui` (or `nmcli`) to configure Wi-Fi.
