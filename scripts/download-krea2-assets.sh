#!/usr/bin/env bash
# Fetch only the missing Krea 2 companion assets for the existing Sickrealism DiT.
set -Eeuo pipefail
BASE="/home/michel/.local/share/ps5-ai-studio/models/image"
CLIP="$BASE/clip"
VAE="$BASE/vae"
mkdir -p "$CLIP" "$VAE"

download_verified(){
  local url="$1" dest="$2" sha="$3" tmp="${2}.part"
  if [[ -f "$dest" ]] && echo "$sha  $dest" | sha256sum -c - >/dev/null 2>&1; then
    echo "Already verified: $dest"
    return 0
  fi
  echo "Downloading $(basename "$dest")"
  curl -fL --retry 5 --retry-delay 2 --connect-timeout 30 --continue-at - "$url" -o "$tmp"
  echo "$sha  $tmp" | sha256sum -c -
  mv -f "$tmp" "$dest"
  echo "Verified: $dest"
}

download_verified \
  "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/text_encoders/qwen3vl_4b_int8_convrot.safetensors" \
  "$CLIP/qwen3vl_4b_int8_convrot.safetensors" \
  "32de113cbf8282b02cbff0794b637b9d6676da09314a1db5a30bcea9bf4ee01c"

download_verified \
  "https://huggingface.co/Comfy-Org/Krea-2/resolve/main/vae/qwen_image_vae.safetensors" \
  "$VAE/qwen_image_vae.safetensors" \
  "a70580f0213e67967ee9c95f05bb400e8fb08307e017a924bf3441223e023d1f"

echo "Krea 2 companion assets downloaded and SHA-256 verified."
