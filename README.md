# dotfiles

Personal dotfiles.

- `bashrc` -> `~/.bashrc`
- `tmux/tmux.conf` -> `~/.config/tmux/tmux.conf`
- `mango/config.conf` -> `~/.config/mango/config.conf` (mangowm)
- `ghostty/config` -> `~/.config/ghostty/config`
- `noctalia/config.toml` -> `~/.config/noctalia/config.toml`
- `noctalia/settings.toml` -> `~/.local/state/noctalia/settings.toml`
- `void-setup.sh` - full system bootstrap (packages, services, GRUB, configs)
- `configure-network.sh` - switch to NetworkManager
- `elogind/` - elogind system-sleep hook copied into place by `void-setup.sh`
- `mango/config.conf` binds keyboard backlight keys to `brillo`

Noctalia is installed from the [universalrepo](https://docs.noctalia.dev/noctalia/getting-started/installation/) XBPS repository.

The setup script backs up existing non-symlink Noctalia files before linking.
GUI changes write through the settings symlink into the repository's
`noctalia/settings.toml`; review those changes before committing.
The separate config and state paths follow
[Noctalia's configuration layout](https://docs.noctalia.dev/noctalia/configuration/).

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

The hook also selects `deep` (S3) in `/sys/power/mem_sleep` before suspend,
restoring the behaviour of the old zzz suspend hook; without it, suspend
follows the kernel's default mode, which may be s2idle.

Suspend goes through elogind (`loginctl suspend`, lid close, the Noctalia
button), which runs hooks in `/etc/elogind/system-sleep/` with `pre`/`post`
and the operation as arguments ([elogind docs](https://github.com/elogind/elogind)).

`void-setup.sh` installs the elogind package, enables its service, and copies
the hook from the prepared `~/.dotfiles` checkout to
`/etc/elogind/system-sleep/10-macbook-cpu` as a root-owned executable.
The hook is copied, not symlinked. No separate elogind setup script is needed.
After setup, reboot and verify your session with `loginctl session-status`.

Then test a real suspend (UI button and lid close); `cat /sys/devices/system/cpu/online`
should show `0-7` after waking. State is kept in `/run` (tmpfs), so it
cannot go stale across reboots.

## Toggling between elogind and zzz+acpid suspend

Two scripts toggle the suspend path; both keep elogind running for
session/seat management, only the ACPI event handling and sleep hooks
change. Each undoes the other.

- `sudo bash setup-zzz-acpid.sh` - back to the zzz path: installs the
  `zzz/` hooks into `/etc/zzz.d`, the passwordless sudoers rule for
  `zzz`/`reboot`/`poweroff`, and acpid. Void's default
  `/etc/acpi/handler.sh` then calls `zzz` on lid close and the sleep
  button, and shuts down on the power button. elogind is told to ignore
  those events via a `logind.conf.d` drop-in, because elogind and acpid
  both acting on them causes double suspends, and the elogind
  system-sleep hook is removed. In this mode `loginctl suspend` still
  suspends, but without the CPU offlining - use `sudo zzz` or the lid.
- `sudo bash setup-elogind.sh` - back to elogind: reinstalls the
  elogind system-sleep hook, removes the `logind.conf.d` drop-in,
  disables acpid (does not remove the package), and removes the zzz
  hooks and sudoers rule.
