#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${RIFE_RELEASE_TAG:-20221029}"
URL="https://github.com/nihui/rife-ncnn-vulkan/releases/download/${TAG}/rife-ncnn-vulkan-${TAG}-ubuntu.zip"
DEST="$ROOT/runtimes/rife-ncnn-vulkan"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$DEST/bin" "$DEST/models/rife-v4.6"
curl -fL --retry 3 --connect-timeout 20 "$URL" -o "$TMP/rife.zip"
BASE="rife-ncnn-vulkan-${TAG}-ubuntu"
unzip -p "$TMP/rife.zip" "$BASE/rife-ncnn-vulkan" > "$DEST/bin/rife-ncnn-vulkan"
for f in flownet.param flownet.bin; do
  unzip -p "$TMP/rife.zip" "$BASE/rife-v4.6/$f" > "$DEST/models/rife-v4.6/$f"
done
unzip -p "$TMP/rife.zip" "$BASE/LICENSE" > "$DEST/LICENSE"
unzip -p "$TMP/rife.zip" "$BASE/README.md" > "$DEST/UPSTREAM-README.md"
chmod 0755 "$DEST/bin/rife-ncnn-vulkan"
"$DEST/bin/rife-ncnn-vulkan" -h 2>&1 | head -n 4
echo "RIFE v4.6 installed: $DEST"