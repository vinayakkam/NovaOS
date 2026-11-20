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
#   TIMEZONE   live-session timezone        (default: Asia/Kolkata)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$REPO/out}"
WORK_ROOT="${WORK_ROOT:-/var/tmp/novaos-build}"
NVIDIA="${NVIDIA:-0}"
KEEP_WORK="${KEEP_WORK:-0}"
TIMEZONE="${TIMEZONE:-Asia/Kolkata}"

# Pinned upstream commit. Bump deliberately.
TWILIGHT_REPO="${TWILIGHT_REPO:-https://github.com/vinayakkam/twilight-desktop.git}"
TWILIGHT_REF="${TWILIGHT_REF:-32bf10521f80c6b022171fc1bc5102b730c70b15}"           # MIT: wallpaper + Konsole theme

PROFILE="$WORK_ROOT/profile"
AIR="$PROFILE/airootfs"
SRC="$WORK_ROOT/src"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
die() { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run as root (WSL: wsl -d archlinux -u root -- bash scripts/build-iso.sh)"
for c in mkarchiso git rsync rsvg-convert runuser makepkg repo-add; do
    command -v "$c" >/dev/null || die "missing '$c' (pacman -S --needed archiso git rsync librsvg base-devel)"
done

log "Preparing work dir $WORK_ROOT"
# An interrupted pacstrap can leave /proc, /sys, /dev bind-mounted inside the work dir;
# never rm -rf through them.
if findmnt -rn -o TARGET | grep -q "^$WORK_ROOT/"; then
    findmnt -rn -o TARGET | grep "^$WORK_ROOT/" | sort -r | xargs -r -n1 umount -R
    findmnt -rn -o TARGET | grep -q "^$WORK_ROOT/" && die "stale mounts under $WORK_ROOT; unmount them first"
fi
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

[[ -f "/usr/share/zoneinfo/$TIMEZONE" ]] || die "unknown TIMEZONE '$TIMEZONE'"
ln -sfn "/usr/share/zoneinfo/$TIMEZONE" "$AIR/etc/localtime"
echo "  timezone: $TIMEZONE"

if [[ "$NVIDIA" == 1 ]]; then
    log "Adding NVIDIA open drivers"
    cat "$REPO/iso/packages.nvidia" >> "$PROFILE/packages.x86_64"
fi
rm -f "$PROFILE/packages.nvidia"

log "Building NovaOS local packages (packages/*/PKGBUILD -> build-time [novaos] repo)"
# makepkg refuses to run as root, so it runs as 'nobody' in its own scratch dirs.
# Built packages are cached by name-version-release.
LOCALREPO="$WORK_ROOT/repo"
MK="$WORK_ROOT/makepkg"
mkdir -p "$LOCALREPO" "$MK/src" "$MK/home" "$MK/work"
for pb in "$REPO"/packages/*/PKGBUILD; do
    [[ -f "$pb" ]] || continue
    id=$(cd "$(dirname "$pb")" && bash -c 'source <(sed "s/\r$//" PKGBUILD); echo "$pkgname-$pkgver-$pkgrel"')
    if compgen -G "$LOCALREPO/$id-*.pkg.tar.zst" >/dev/null; then
        echo "  $id (cached)"
        continue
    fi
    echo "  building $id"
    w="$MK/work/$(basename "$(dirname "$pb")")"
    rm -rf "$w"; mkdir -p "$w"
    sed 's/\r$//' "$pb" > "$w/PKGBUILD"
    chown -R nobody "$MK" "$LOCALREPO"
    (cd "$w" && runuser -u nobody -- env HOME="$MK/home" SRCDEST="$MK/src" PKGDEST="$LOCALREPO" \
        makepkg --force --nodeps --noconfirm --noprogressbar >/dev/null) || die "makepkg failed for $id"
done
rm -f "$LOCALREPO"/novaos.db* "$LOCALREPO"/novaos.files*
repo-add -q "$LOCALREPO/novaos.db.tar.gz" "$LOCALREPO"/*.pkg.tar.zst
# Only the build's pacman.conf sees this repo; the live system keeps the stock one.
printf '\n[novaos]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$LOCALREPO" >> "$PROFILE/pacman.conf"

log "Fetching pinned upstream sources"
fetch() {  # fetch <name> <url> <commit>
    local dir="$SRC/$1"
    if [[ ! -d "$dir/.git" ]]; then
        git init -q "$dir"
        git -C "$dir" remote add origin "$2"
    fi
    git -C "$dir" remote set-url origin "$2"
    git -C "$dir" fetch -q --depth 1 origin "$3"
    git -C "$dir" checkout -q --force FETCH_HEAD
    git -C "$dir" clean -qfdx
    echo "  $1 @ $(git -C "$dir" rev-parse --short HEAD)"
}
fetch twilight-desktop "$TWILIGHT_REPO" "$TWILIGHT_REF"
TW="$SRC/twilight-desktop/home"

log "Installing NovaOS icon theme (original artwork, generated by theme/icons/generate.mjs)"
[[ -f "$REPO/theme/icons/NovaOS/index.theme" ]] || die "run: node theme/icons/generate.mjs"
mkdir -p "$AIR/usr/share/icons"
rsync -a --delete --no-owner --no-group "$REPO/theme/icons/NovaOS/" "$AIR/usr/share/icons/NovaOS/"

log "Staging NovaOS Twilight theme (Plasma)"
mkdir -p "$AIR/usr/share/plasma/look-and-feel"
rsync -a --no-owner --no-group "$REPO/theme/look-and-feel/" "$AIR/usr/share/plasma/look-and-feel/"
mkdir -p "$AIR/etc/xdg" "$AIR/etc/skel" "$AIR/usr/share/color-schemes"
rsync -a --no-owner --no-group "$REPO/theme/xdg/" "$AIR/etc/xdg/"
rsync -a --no-owner --no-group "$REPO/theme/skel/" "$AIR/etc/skel/"
install -m644 "$REPO/theme/colors/Twilight.colors" "$AIR/usr/share/color-schemes/Twilight.colors"
# kdeglobals = full Twilight colour scheme + our overrides (KConfig merges repeated groups,
# later keys win). Apps read colours from kdeglobals, not from the scheme name.
cat "$REPO/theme/colors/Twilight.colors" "$REPO/theme/xdg/kdeglobals" > "$AIR/etc/xdg/kdeglobals"

# Konsole colours/profile and the Denali wallpaper come from twilight-desktop
install -Dm644 "$TW/.local/share/konsole/Twilight.colorscheme" "$AIR/usr/share/konsole/Twilight.colorscheme"
install -Dm644 "$TW/.local/share/konsole/Twilight.profile"     "$AIR/usr/share/konsole/Twilight.profile"
DENALI="$TW/.local/share/twilight/wallpapers/denali-wonder-lake.jpg"
[[ -f "$DENALI" ]] || die "Denali wallpaper missing from twilight-desktop"
install -Dm644 "$DENALI" "$AIR/usr/share/wallpapers/Twilight/contents/images/2560x1440.jpg"
cat > "$AIR/usr/share/wallpapers/Twilight/metadata.json" <<'EOF'
{
    "KPackageStructure": "Wallpaper/Images",
    "KPlugin": {
        "Authors": [{ "Name": "US National Park Service (public domain)" }],
        "Id": "Twilight",
        "License": "Public Domain",
        "Name": "Denali, Wonder Lake"
    }
}
EOF

log "Staging login (SDDM) and logout screens"
install -d "$AIR/usr/share/sddm/themes"
rsync -a --no-owner --no-group "$REPO/theme/sddm/novaos/" "$AIR/usr/share/sddm/themes/novaos/"
install -m644 "$DENALI" "$AIR/usr/share/sddm/themes/novaos/background.jpg"
install -d "$AIR/usr/share/novaos/logout" "$AIR/usr/share/novaos/lockscreen"
install -m644 "$REPO"/theme/logout/*.qml "$AIR/usr/share/novaos/logout/"
install -m644 "$REPO"/theme/lockscreen/*.qml "$AIR/usr/share/novaos/lockscreen/"

log "Installing NovaOS Settings"
install -Dm644 "$REPO/apps/settings/Main.qml" "$AIR/usr/share/novaos/settings/Main.qml"
install -Dm755 "$REPO/apps/settings/novaos-settings" "$AIR/usr/local/bin/novaos-settings"
install -Dm755 "$REPO/apps/settings/novaos-settings-helper" "$AIR/usr/local/bin/novaos-settings-helper"
install -Dm644 "$REPO/apps/settings/org.novaos.settings.desktop" "$AIR/usr/share/applications/org.novaos.settings.desktop"
echo "0.1" > "$AIR/usr/share/novaos/version"

log "Installing NovaOS Task Manager and terminal greeting"
install -Dm644 "$REPO/apps/taskmanager/Main.qml" "$AIR/usr/share/novaos/taskmanager/Main.qml"
install -Dm755 "$REPO/apps/taskmanager/novaos-taskmanager" "$AIR/usr/local/bin/novaos-taskmanager"
install -Dm644 "$REPO/apps/taskmanager/org.novaos.taskmanager.desktop" "$AIR/usr/share/applications/org.novaos.taskmanager.desktop"
install -Dm644 "$REPO/theme/terminal/fastfetch.jsonc" "$AIR/usr/share/novaos/terminal/fastfetch.jsonc"
install -Dm644 "$REPO/theme/terminal/novaos-logo.txt" "$AIR/usr/share/novaos/terminal/novaos-logo.txt"
install -Dm755 "$REPO/theme/terminal/novaos-shell" "$AIR/usr/local/bin/novaos-shell"
install -Dm644 "$REPO/theme/terminal/NovaOS.profile" "$AIR/usr/share/konsole/NovaOS.profile"

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
rsvg-convert -w 256 -h 256 "$REPO/theme/branding/novaos-logo.svg" -o "$AIR/usr/share/pixmaps/novaos-avatar.png"

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
