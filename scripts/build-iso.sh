#!/usr/bin/env bash
# Build the NovaOS live ISO.
#
# Runs as root on Arch Linux (WSL "archlinux" distro or the CI container).
# Needs: archiso git rsync librsvg   (pacman -S --needed archiso git rsync librsvg)
#
# Environment:
#   OUT_DIR    where the .iso lands          (default: <repo>/out)
#   WORK_ROOT  scratch dir, keep on a Linux fs (default: /var/tmp/novaos-build)
#   NVIDIA=1   also install packages from iso/packages.nvidia
#   KEEP_WORK=1  keep mkarchiso's work dir (faster debugging, ~10 GB)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO/out}"
WORK_ROOT="${WORK_ROOT:-/var/tmp/novaos-build}"
NVIDIA="${NVIDIA:-0}"
KEEP_WORK="${KEEP_WORK:-0}"

# Pinned upstream theme commits (GPL-3.0, github.com/vinceliuice). Bump deliberately.
FLUENT_ICONS_REF="${FLUENT_ICONS_REF:-c8a244f571ef8fb47812bdc9dbce76546cedce69}"
FLUENT_KDE_REF="${FLUENT_KDE_REF:-44794f29c89de994b0179aebabd2f5776c90d236}"

PROFILE="$WORK_ROOT/profile"
AIR="$PROFILE/airootfs"
SRC="$WORK_ROOT/src"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run as root (WSL: wsl -d archlinux -u root -- bash scripts/build-iso.sh)"
for c in mkarchiso git rsync rsvg-convert runuser; do
    command -v "$c" >/dev/null || die "missing '$c' (pacman -S --needed archiso git rsync librsvg)"
done

log "Preparing work dir $WORK_ROOT"
rm -rf "$PROFILE" "$WORK_ROOT/work" "$WORK_ROOT/fluent-kde-home"
mkdir -p "$PROFILE" "$SRC" "$OUT_DIR"
chmod 755 "$WORK_ROOT"

log "Copying archiso profile"
rsync -a --delete "$REPO/iso/" "$PROFILE/"
# Files coming from NTFS (/mnt/d) arrive as 0777; normalise. profiledef.sh sets special modes.
find "$PROFILE" -type d -exec chmod 755 {} +
find "$PROFILE" -type f -exec chmod 644 {} +
# Strip any CRLF that slipped in from Windows editors
find "$PROFILE" -type f \( -name '*.sh' -o -name '*.conf' -o -name '*.cfg' -o -name '*.service' \
     -o -name 'packages.*' -o -path '*/usr/local/bin/*' -o -path '*/sudoers.d/*' \) -exec sed -i 's/\r$//' {} +

log "Recreating symlinks from iso/symlinks.list"
grep -vE '^[[:space:]]*(#|$)' "$REPO/iso/symlinks.list" | sed 's/\r$//' | while read -r link target; do
    mkdir -p "$AIR$(dirname "$link")"
    ln -sfn "$target" "$AIR$link"
done
rm -f "$PROFILE/symlinks.list"

if [[ "$NVIDIA" == 1 ]]; then
    log "Adding NVIDIA open drivers"
    cat "$REPO/iso/packages.nvidia" >> "$PROFILE/packages.x86_64"
fi
rm -f "$PROFILE/packages.nvidia"

log "Fetching Fluent themes (pinned)"
fetch() {  # fetch <repo> <commit>
    local dir="$SRC/$1"
    if [[ ! -d "$dir/.git" ]]; then
        git init -q "$dir"
        git -C "$dir" remote add origin "https://github.com/vinceliuice/$1.git"
    fi
    git -C "$dir" fetch -q --depth 1 origin "$2"
    git -C "$dir" checkout -q --force FETCH_HEAD
    echo "  $1 @ $(git -C "$dir" rev-parse --short HEAD)"
}
fetch Fluent-icon-theme "$FLUENT_ICONS_REF"
fetch Fluent-kde "$FLUENT_KDE_REF"

log "Installing Fluent icon theme into airootfs"
mkdir -p "$AIR/usr/share/icons"
bash "$SRC/Fluent-icon-theme/install.sh" --dest "$AIR/usr/share/icons" >/dev/null

log "Installing Fluent KDE theme (rounded) into airootfs"
# Its installer writes to /usr/share when run as root, so run it as 'nobody' with a
# throw-away HOME and move the per-user output into the image's /usr/share.
STAGE="$WORK_ROOT/fluent-kde-home"
install -d -o nobody "$STAGE"
chmod -R a+rX "$SRC/Fluent-kde"
runuser -u nobody -- env HOME="$STAGE" bash "$SRC/Fluent-kde/install.sh" --round >/dev/null
mkdir -p "$AIR/usr/share/Kvantum"
rsync -a --no-owner --no-group "$STAGE/.local/share/" "$AIR/usr/share/"
rsync -a --no-owner --no-group "$STAGE/.config/Kvantum/" "$AIR/usr/share/Kvantum/"

log "Staging NovaOS theme"
rsync -a --no-owner --no-group "$REPO/theme/look-and-feel/" "$AIR/usr/share/plasma/look-and-feel/"
mkdir -p "$AIR/etc/xdg" "$AIR/etc/skel"
rsync -a --no-owner --no-group "$REPO/theme/xdg/" "$AIR/etc/xdg/"
rsync -a --no-owner --no-group "$REPO/theme/skel/" "$AIR/etc/skel/"
# kdeglobals = full FluentLight color scheme + our overrides (KConfig merges repeated groups,
# later keys win). Apps read colours from kdeglobals, not from the scheme name.
cat "$SRC/Fluent-kde/color-schemes/FluentLight.colors" "$REPO/theme/xdg/kdeglobals" > "$AIR/etc/xdg/kdeglobals"

WP="$AIR/usr/share/wallpapers/NovaOS"
install -d "$WP/contents/images"
install -m644 "$REPO/theme/wallpapers/NovaOS/metadata.json" "$WP/metadata.json"
for size in 1920x1080 2560x1440 3840x2160; do
    rsvg-convert -w "${size%x*}" -h "${size#*x}" "$REPO/theme/wallpapers/NovaOS/novaos-wallpaper.svg" \
        -o "$WP/contents/images/$size.png"
done
rsvg-convert -w 400 -h 225 "$REPO/theme/wallpapers/NovaOS/novaos-wallpaper.svg" -o "$WP/contents/screenshot.png"

install -Dm644 "$REPO/theme/branding/novaos-logo.svg" "$AIR/usr/share/icons/hicolor/scalable/apps/novaos-start.svg"
install -Dm644 "$REPO/theme/branding/novaos-logo.svg" "$AIR/usr/share/pixmaps/novaos-logo.svg"

log "Staging plasmoids and installer branding"
mkdir -p "$AIR/usr/share/plasma/plasmoids" "$AIR/usr/share/calamares/branding"
rsync -a --no-owner --no-group --exclude README.md "$REPO/plasmoids/" "$AIR/usr/share/plasma/plasmoids/"
rsync -a --no-owner --no-group "$REPO/calamares/branding/" "$AIR/usr/share/calamares/branding/"
install -m644 "$REPO/theme/branding/novaos-logo.svg" "$AIR/usr/share/calamares/branding/novaos/logo.svg"

# Everything staged above must be root-owned and world-readable in the image
chown -R root:root "$AIR/usr/share" "$AIR/etc/xdg" "$AIR/etc/skel"
chmod -R u+rwX,go+rX,go-w "$AIR/usr/share" "$AIR/etc/xdg" "$AIR/etc/skel"

log "Running mkarchiso (this takes a while)"
args=(-v -w "$WORK_ROOT/work" -o "$OUT_DIR")
[[ "$KEEP_WORK" == 1 ]] || args+=(-r)
mkarchiso "${args[@]}" "$PROFILE"

log "Done"
iso="$(ls -t "$OUT_DIR"/novaos-*.iso | head -n1)"
ls -lh "$iso"
(cd "$(dirname "$iso")" && sha256sum "$(basename "$iso")" | tee "$(basename "$iso").sha256")
