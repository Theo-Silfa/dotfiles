# dotfiles

Personal dotfiles.

- `bashrc` -> `~/.bashrc`
- `tmux/tmux.conf` -> `~/.config/tmux/tmux.conf`
- `mango/config.conf` -> `~/.config/mango/config.conf` (mangowm)
- `void-setup.sh` - full system bootstrap (packages, services, GRUB, configs)
- `configure-network.sh` - switch to NetworkManager
- `setup-zzz-hooks.sh` - install zzz suspend/resume hooks (copies, no symlinks)
- `zzz/` - zzz hook scripts installed by `setup-zzz-hooks.sh`

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

## zzz suspend hooks (MacBookPro11,5)

Without this workaround, resuming from S3/deep suspend stalls ~20-30s
inside secondary-CPU bring-up during early resume. The hooks offline the
currently online secondary CPUs before suspend and bring them back after
resume, which keeps wake time at ~6-7s. Only CPUs recorded in the state
file are restored; CPU0 and deliberately-offlined CPUs are never touched.

Install (from a repo checkout, run as root; copies files, no symlinks):

```
sudo bash setup-zzz-hooks.sh
```

Then verify with a dry run (`sudo zzz -n`, no actual suspend) and check
that `cat /sys/devices/system/cpu/online` still shows `0-7`. The hooks
are installed to `/etc/zzz.d/suspend/` and `/etc/zzz.d/resume/`; re-run
the setup script to update them. State is kept in `/run` (tmpfs), so it
cannot go stale across reboots.
