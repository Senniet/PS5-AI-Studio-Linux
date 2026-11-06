#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL="${FFMPEG_STATIC_URL:-https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz}"
DEST="$ROOT/runtimes/video-tools/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$DEST"
curl -fL --retry 3 --connect-timeout 20 "$URL" -o "$TMP/ffmpeg.tar.xz"
tar -xJf "$TMP/ffmpeg.tar.xz" -C "$TMP"
FFMPEG="$(find "$TMP" -type f -name ffmpeg -perm -111 -print -quit)"
FFPROBE="$(find "$TMP" -type f -name ffprobe -perm -111 -print -quit)"
test -n "$FFMPEG" && test -n "$FFPROBE"
install -m 0755 "$FFMPEG" "$DEST/ffmpeg"
install -m 0755 "$FFPROBE" "$DEST/ffprobe"
"$DEST/ffmpeg" -version | head -n 3
"$DEST/ffprobe" -version | head -n 2