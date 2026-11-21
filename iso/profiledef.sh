#!/usr/bin/env bash
# shellcheck disable=SC2034
# TwilightOS archiso profile (derived from archiso's releng profile).

iso_name="twilightos"
iso_label="TWILIGHTOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="TwilightOS Project"
iso_application="TwilightOS Live"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# zstd builds much faster than releng's xz at a ~10% size cost; switch to xz for releases.
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')
# Read the live image from the boot medium instead of copying ~2.5 GB of it into RAM.
kernel_params_x86_64="copytoram=n"
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/sudoers.d/10-twilightos-live"]="0:0:440"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/twilightos-live-user"]="0:0:755"
  ["/usr/local/bin/twilightos-sync-shell"]="0:0:755"
  ["/usr/local/bin/twilightos-memreport"]="0:0:755"
  ["/usr/local/bin/twilightos-settings"]="0:0:755"
  ["/usr/local/bin/twilightos-settings-helper"]="0:0:755"
  ["/usr/local/bin/twilightos-taskmanager"]="0:0:755"
  ["/usr/local/bin/twilightos-shell"]="0:0:755"
  ["/usr/local/bin/twilightos-session-trim"]="0:0:755"
)
