# dotfiles

Personal dotfiles.

- `bashrc` -> `~/.bashrc`
- `tmux/tmux.conf` -> `~/.config/tmux/tmux.conf`
- `mango/config.conf` -> `~/.config/mango/config.conf` (mangowm)
- `void-setup.sh` - full system bootstrap (packages, services, GRUB, configs)
- `configure-network.sh` - switch to NetworkManager
- `setup-elogind.sh` - migrate to elogind/loginctl: sleep hook, services, turnstile/seatd removal
- `elogind/` - elogind system-sleep hook installed by `setup-elogind.sh`
- `mango/config.conf` binds keyboard backlight keys to `brillo`

`void-setup.sh` uses the polkit policy shipped by Void's `brillo` package.
It reinstalls the package if the policy is missing, without maintaining a
separate policy copy in this repository. Keyboard bindings remain plain
`brillo` commands.

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

## elogind sleep hook (MacBookPro11,5)

Without this workaround, resuming from S3/deep suspend stalls ~20-30s
inside secondary-CPU bring-up during early resume. The elogind system-sleep
hook offlines the currently online secondary CPUs before suspend and brings
them back after resume, which keeps wake time at ~6-7s. Only CPUs recorded
in the state file are restored; CPU0 and deliberately-offlined CPUs are
never touched.

Suspend goes through elogind (`loginctl suspend`, lid close, the Noctalia
button), which runs hooks in `/etc/elogind/system-sleep/` with `pre`/`post`
and the operation as arguments ([elogind docs](https://github.com/elogind/elogind)).

Install / migrate (from a repo checkout, run as root; copies files, no
symlinks; also enables elogind and removes turnstile, seatd and acpid):

```
sudo bash setup-elogind.sh
```

The script also removes the old zzz hooks and sudoers rule. After it:
remove the `[shell.session.power]` overrides from
`~/.config/noctalia/*.toml` (Noctalia auto-detects `loginctl` again),
reboot, and verify with `loginctl` that your session shows `Active=yes`.

Then test a real suspend (UI button and lid close); `cat /sys/devices/system/cpu/online`
should show `0-7` after waking. State is kept in `/run` (tmpfs), so it
cannot go stale across reboots.
