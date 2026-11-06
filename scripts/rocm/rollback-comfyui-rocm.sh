#!/usr/bin/env bash
# Restore the original CPU ComfyUI user service; the ROCm venv remains available.
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_FILE="$HOME/.local/state/ps5-ai-studio/comfy-rocm-unit-backup-path"
UNIT_FILE="$HOME/.config/systemd/user/ps5-ai-studio-comfyui.service"
[[ -f "$STATE_FILE" ]] || { echo "No ComfyUI service backup state found" >&2; exit 2; }
BACKUP="$(cat "$STATE_FILE")"
[[ -f "$BACKUP/ps5-ai-studio-comfyui.service" ]] || { echo "Missing service backup in $BACKUP" >&2; exit 2; }
systemctl --user stop ps5-ai-studio-comfyui.service >/dev/null 2>&1 || true
cp -a "$BACKUP/ps5-ai-studio-comfyui.service" "$UNIT_FILE"
systemctl --user daemon-reload
systemctl --user start ps5-ai-studio-comfyui.service
echo "Restored original CPU ComfyUI service. ROCm venv remains at $PROJECT_ROOT/runtimes/comfy-rocm-venv"
