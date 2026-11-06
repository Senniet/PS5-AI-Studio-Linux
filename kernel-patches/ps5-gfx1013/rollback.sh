#!/usr/bin/env bash
set -euo pipefail
KERNEL="7.3.0-PinkSoup"
BOOT="/boot/efi"
FIRMWARE="/lib/firmware/amdgpu"
CONF="/etc/modprobe.d/ps5-rocm-gfx1013.conf"
STATE="/var/lib/ps5-rocm-gfx1013-backup-path"
MODULE_DEST="/lib/modules/$KERNEL/updates/amdgpu.ko"
[[ $EUID -eq 0 ]] || { echo "Run as root: sudo $0" >&2; exit 1; }
[[ -f "$STATE" ]] || { echo "No PS5 ROCm backup state found" >&2; exit 1; }
BACKUP="$(cat "$STATE")"
[[ -d "$BACKUP" ]] || { echo "Backup directory missing: $BACKUP" >&2; exit 1; }

for f in cyan_skillfish2_sdma.bin.zst cyan_skillfish2_sdma1.bin.zst; do
  [[ -f "$BACKUP/$f" ]] && cp -a "$BACKUP/$f" "$FIRMWARE/$f"
done
if [[ -f "$BACKUP/ps5-rocm-gfx1013.conf" ]]; then
  cp -a "$BACKUP/ps5-rocm-gfx1013.conf" "$CONF"
else
  rm -f "$CONF"
fi
if [[ -f "$BACKUP/amdgpu.ko" ]]; then
  mkdir -p "$(dirname "$MODULE_DEST")"
  install -D -m 0644 "$BACKUP/amdgpu.ko" "$MODULE_DEST"
else
  rm -f "$MODULE_DEST"
fi
depmod -a "$KERNEL"
rm -f "$BOOT/cmdline.ps5-rocm.txt" "$BOOT/kexec-ps5-rocm.sh" "$BOOT/kexec-fallback-7.1.7.sh"
rm -f "$STATE"
sync
echo "PS5 ROCm workaround rolled back. Original firmware/config/module restored where backups existed."
echo "Stock kernel and initramfs were never overwritten. Use: sudo $BOOT/kexec.sh"
echo "Backup retained for inspection: $BACKUP"