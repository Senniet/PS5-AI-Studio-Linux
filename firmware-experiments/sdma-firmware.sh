#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FW_DIR=/lib/firmware/amdgpu
BACKUP_POINTER="$DIR/last_backup_dir"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root: sudo bash $0 install|rollback" >&2
  exit 1
fi

case "$MODE" in
  install)
    [[ -x "$(command -v update-initramfs || true)" ]] || { echo "update-initramfs not found"; exit 1; }
    [[ ! -e "$BACKUP_POINTER" ]] || { echo "Backup pointer already exists: $(cat "$BACKUP_POINTER"). Roll back first."; exit 1; }
    for n in navi12_sdma navi12_sdma1; do
      src="$DIR/$n.bin.zst"
      [[ -s "$src" ]] || { echo "Missing $src"; exit 1; }
      zstd -t "$src" >/dev/null
      size="$(zstd -dc "$src" | wc -c)"
      [[ "$size" -eq 33792 ]] || { echo "$n has unexpected decompressed size: $size"; exit 1; }
    done
    for n in cyan_skillfish2_sdma cyan_skillfish2_sdma1; do
      [[ -s "$FW_DIR/$n.bin.zst" ]] || { echo "Current firmware missing: $FW_DIR/$n.bin.zst"; exit 1; }
    done
    backup="/var/backups/ps5-sdma-firmware-$(date +%Y%m%d-%H%M%S)"
    install -d -m 0755 "$backup"
    cp -a "$FW_DIR/cyan_skillfish2_sdma.bin.zst" "$backup/"
    cp -a "$FW_DIR/cyan_skillfish2_sdma1.bin.zst" "$backup/"
    printf '%s\n' "$backup" > "$BACKUP_POINTER"
    chmod 0644 "$BACKUP_POINTER"
    install -m 0644 "$DIR/navi12_sdma.bin.zst" "$FW_DIR/cyan_skillfish2_sdma.bin.zst"
    install -m 0644 "$DIR/navi12_sdma1.bin.zst" "$FW_DIR/cyan_skillfish2_sdma1.bin.zst"
    update-initramfs -u -k all
    echo
    echo "Installed Navi12 SDMA firmware under the Cyan Skillfish filenames."
    echo "Backup: $backup"
    echo "HSA_ENABLE_SDMA is deliberately still disabled in ComfyUI."
    echo "Reboot required. After reboot, run: bash $DIR/test-sdma.sh"
    ;;
  rollback)
    [[ -s "$BACKUP_POINTER" ]] || { echo "No backup pointer found at $BACKUP_POINTER"; exit 1; }
    backup="$(cat "$BACKUP_POINTER")"
    [[ -s "$backup/cyan_skillfish2_sdma.bin.zst" && -s "$backup/cyan_skillfish2_sdma1.bin.zst" ]] || { echo "Backup files missing in $backup"; exit 1; }
    install -m 0644 "$backup/cyan_skillfish2_sdma.bin.zst" "$FW_DIR/cyan_skillfish2_sdma.bin.zst"
    install -m 0644 "$backup/cyan_skillfish2_sdma1.bin.zst" "$FW_DIR/cyan_skillfish2_sdma1.bin.zst"
    update-initramfs -u -k all
    rm -f "$BACKUP_POINTER"
    echo "Original Cyan Skillfish SDMA firmware restored."
    echo "Reboot required."
    ;;
  *)
    echo "Usage: sudo bash $0 install|rollback" >&2
    exit 2
    ;;
esac