# Calamares installer

`branding/twilightos/` is copied to `/usr/share/calamares/branding/twilightos/` in the ISO
(`build-iso.sh` also drops the logo in as `logo.svg`).

Calamares itself is **not in the official Arch repos**, so the first ISO ships without it.
Two ways to add it:

1. **Chaotic-AUR (prebuilt, easiest).** Add to `iso/pacman.conf`:

   ```ini
   [chaotic-aur]
   Include = /etc/pacman.d/chaotic-mirrorlist
   ```

   On the build host (WSL Arch / CI container), import their key and install
   `chaotic-keyring` + `chaotic-mirrorlist` first (see https://aur.chaotic.cx). Then add
   `calamares` to `iso/packages.x86_64`.

2. **Own local repo.** Build `calamares` from the AUR with `makepkg` once, put the
   package in a local repo (`repo-add`) and reference it from `iso/pacman.conf` with
   `Server = file:///path/to/repo`. Gives full control, needs rebuilding on Qt bumps.

Still TODO once Calamares is in: `settings.conf` and module configs (partition with btrfs
subvolumes for Snapper, users, bootloader), and a `shellprocess` step that disables
`twilightos-live-user.service`, removes `/etc/sudoers.d/10-twilightos-live` and
`/etc/sddm.conf.d/10-twilightos.conf` on the installed system.
