# NovaOS

Arch-based Linux with a KDE Plasma 6 desktop that looks like Windows 11 and borrows
macOS conveniences (Spotlight-style search, hot corners, Quick Look, gestures).
*"NovaOS" is a placeholder name.*

## Layout

| Path | What |
|---|---|
| `iso/` | archiso profile (from releng). `symlinks.list` holds the airootfs symlinks; `packages.nvidia` is optional |
| `theme/` | Global Theme + layout script, `/etc/xdg` defaults, `/etc/skel`, wallpaper and logo (original SVGs) |
| `plasmoids/` | Windows 11-style Start menu plasmoid (skeleton) |
| `apps/` | Rust apps: `quicklook`, `winlayer` (Cargo workspace) and `welcome` (Tauri 2), all stubs |
| `calamares/` | Installer branding + how to add Calamares |
| `scripts/` | `build-iso.sh` (Linux), `build-iso.ps1` (Windows → WSL), `test-vm.ps1` (VirtualBox) |

## Build the ISO (Windows host)

```powershell
.\scripts\build-iso.ps1            # add -Nvidia for the NVIDIA open drivers
```

Runs `scripts/build-iso.sh` as root in the `archlinux` WSL distro. The work dir is
`/var/tmp/novaos-build` on the WSL disk (`D:\WSL\Arch\ext4.vhdx`), and the ISO lands in `out\`.
The Fluent icon and KDE themes (GPL-3.0, vinceliuice) are fetched at pinned commits during the build.

Inside Linux directly: `sudo bash scripts/build-iso.sh`.

## Test in VirtualBox

```powershell
.\scripts\test-vm.ps1
```

Recreates the `NovaOS-Test` VM in `D:\VirtualBox\VMs` (EFI, 4 CPUs, 6 GB RAM, 128 MB VRAM,
VMSVGA, 40 GB VDI) with the newest ISO attached and boots it.

## Desktop defaults

- One floating bottom panel: start button and pinned apps centered, tray and clock on the right.
- Fluent (rounded, light) Plasma style, window decorations, Kvantum and icons; Inter font.
- KRunner on **Meta+Space** (Spotlight), free-floating; typing on the desktop opens it.
- Top-left hot corner opens **Overview**. Touchpad gestures are KWin Wayland's built-in ones.
- The live session auto-logs in as `nova` (no password, passwordless sudo).

No Microsoft or Apple logos, fonts, icons or wallpapers are used.
