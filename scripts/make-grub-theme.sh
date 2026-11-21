#!/usr/bin/env bash
# Generate the TwilightOS GRUB theme into <outdir>.
#   make-grub-theme.sh <outdir> <wallpaper.jpg> <logo.svg> <theme.txt>
# Needs: rsvg-convert (librsvg), grub-mkfont (grub), the Inter font (inter-font).
set -euo pipefail
out=$1 wallpaper=$2 logo=$3 themetxt=$4
mkdir -p "$out"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

install -m644 "$themetxt" "$out/theme.txt"

# --- background: the wallpaper, darkened towards the bottom so the menu reads well
cp "$wallpaper" "$tmp/wallpaper.jpg"
cat > "$tmp/bg.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <linearGradient id="veil" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#0d1428" stop-opacity=".45"/>
      <stop offset=".45" stop-color="#0d1428" stop-opacity=".62"/>
      <stop offset="1" stop-color="#0d1428" stop-opacity=".9"/>
    </linearGradient>
  </defs>
  <image xlink:href="wallpaper.jpg" x="0" y="0" width="1920" height="1080" preserveAspectRatio="xMidYMid slice"/>
  <rect width="1920" height="1080" fill="url(#veil)"/>
</svg>
EOF
(cd "$tmp" && rsvg-convert -w 1920 -h 1080 bg.svg -o "$out/background.png")

# --- logo
rsvg-convert -w 80 -h 80 "$logo" -o "$out/logo.png"

# --- 9-slice pixmaps: one rounded rectangle, cut into corners / edges / centre by
#     rendering it through nine viewBoxes (no image editor needed)
slices() {  # slices <prefix> <fill> <fill-opacity> <stroke> <radius>
    local prefix=$1 fill=$2 op=$3 stroke=$4 r=$5 s=64
    cat > "$tmp/$prefix.svg.in" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="WIDTH" height="HEIGHT" viewBox="VIEWBOX" preserveAspectRatio="none">
  <rect x="0.5" y="0.5" width="$((s - 1))" height="$((s - 1))" rx="$r" fill="$fill" fill-opacity="$op" stroke="$stroke" stroke-opacity=".18"/>
</svg>
EOF
    local m=$((s - r))
    # name   x   y   w   h
    while read -r name x y w h; do
        sed -e "s/WIDTH/$w/" -e "s/HEIGHT/$h/" -e "s/VIEWBOX/$x $y $w $h/" "$tmp/$prefix.svg.in" > "$tmp/$prefix-$name.svg"
        rsvg-convert -w "$w" -h "$h" "$tmp/$prefix-$name.svg" -o "$out/${prefix}_$name.png"
    done <<EOF
nw 0 0 $r $r
n $r 0 $((m - r)) $r
ne $m 0 $r $r
w 0 $r $r $((m - r))
c $r $r $((m - r)) $((m - r))
e $m $r $r $((m - r))
sw 0 $m $r $r
s $r $m $((m - r)) $r
se $m $m $r $r
EOF
}
slices menu   "#0d1428" ".55" "#ffffff" 18     # glass panel behind the menu
slices select "#f2683a" ".92" "#f3b651" 12     # accent pill on the selected entry

# --- fonts (GRUB needs its own bitmap format)
inter=$(fc-match -f '%{file}' 'Inter:style=Regular' 2>/dev/null || true)
[[ -f "$inter" ]] || inter=$(ls /usr/share/fonts/inter/*.ttf /usr/share/fonts/inter/*.otf 2>/dev/null | head -n1)
[[ -f "$inter" ]] || { echo "Inter font not found (pacman -S inter-font)" >&2; exit 1; }
for size in 14 16 18; do grub-mkfont -n "Inter Regular" -s "$size" -o "$out/inter-regular-$size.pf2" "$inter" 2>/dev/null; done
for size in 18 32; do grub-mkfont -b -n "Inter Bold" -s "$size" -o "$out/inter-bold-$size.pf2" "$inter" 2>/dev/null; done

echo "  GRUB theme: $(ls "$out" | wc -l) files in $out"
