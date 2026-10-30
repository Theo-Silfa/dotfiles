# dotfiles

Personal dotfiles.

- `bashrc` -> `~/.bashrc`
- `tmux/tmux.conf` -> `~/.config/tmux/tmux.conf`
- `mango/config.conf` -> `~/.config/mango/config.conf` (mangowm)
- `void-setup.sh` - full system bootstrap (packages, services, GRUB, configs)
- `configure-network.sh` - switch to NetworkManager

Noctalia is installed from the [universalrepo](https://docs.noctalia.dev/noctalia/getting-started/installation/) XBPS repository.

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
