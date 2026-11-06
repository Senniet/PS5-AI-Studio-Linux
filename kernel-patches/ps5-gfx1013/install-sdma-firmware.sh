#!/usr/bin/env bash
set -euo pipefail
FIRMWARE="/lib/firmware/amdgpu"
STATE="/var/lib/ps5-rocm-gfx1013-backup-path"
die(){ echo "ERROR: $*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || die "Run as root: sudo $0"
[[ -f "$STATE" ]] || die "Run install.sh first; no rollback state exists"
BACKUP="$(cat "$STATE")"
[[ -d "$BACKUP" ]] || die "Backup directory missing: $BACKUP"
for f in cyan_skillfish2_sdma.bin.zst cyan_skillfish2_sdma1.bin.zst navi12_sdma.bin.zst navi12_sdma1.bin.zst; do
  [[ -f "$FIRMWARE/$f" ]] || die "Missing firmware: $FIRMWARE/$f"
done
[[ ! -f "$BACKUP/sdma-firmware-swapped" ]] || die "Navi12 SDMA firmware is already staged"
for f in cyan_skillfish2_sdma.bin.zst cyan_skillfish2_sdma1.bin.zst; do
  [[ -f "$BACKUP/$f" ]] || cp -a "$FIRMWARE/$f" "$BACKUP/"
done
cmp -s "$FIRMWARE/cyan_skillfish2_sdma.bin.zst" "$FIRMWARE/navi12_sdma.bin.zst" && die "SDMA0 already matches Navi12; refusing to create a misleading rollback backup"
cmp -s "$FIRMWARE/cyan_skillfish2_sdma1.bin.zst" "$FIRMWARE/navi12_sdma1.bin.zst" && die "SDMA1 already matches Navi12; refusing to create a misleading rollback backup"
cp -a "$FIRMWARE/navi12_sdma.bin.zst" "$FIRMWARE/cyan_skillfish2_sdma.bin.zst"
cp -a "$FIRMWARE/navi12_sdma1.bin.zst" "$FIRMWARE/cyan_skillfish2_sdma1.bin.zst"
cmp -s "$FIRMWARE/cyan_skillfish2_sdma.bin.zst" "$FIRMWARE/navi12_sdma.bin.zst" || die "SDMA0 firmware verification failed"
cmp -s "$FIRMWARE/cyan_skillfish2_sdma1.bin.zst" "$FIRMWARE/navi12_sdma1.bin.zst" || die "SDMA1 firmware verification failed"
touch "$BACKUP/sdma-firmware-swapped"
sync
echo "Navi12 SDMA 5.0 firmware staged for both Cyan Skillfish engines."
echo "The driver loads firmware at module init; reboot the patched kernel again: sudo /boot/efi/kexec-ps5-rocm.sh"
echo "Rollback restores the original Cyan Skillfish firmware from: $BACKUP"
