#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "$EUID" -ne 0 ]]; then echo "Run with sudo: sudo $0" >&2; exit 1; fi
[[ -r /etc/os-release ]] || { echo "Cannot identify Linux distribution." >&2; exit 1; }
. /etc/os-release
if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *debian* ]]; then
  echo "This bootstrap targets Ubuntu/Debian. Detected: ${PRETTY_NAME:-unknown}" >&2
  exit 1
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  build-essential git cmake ninja-build pkg-config ccache \
  clang lld python3 python3-venv python3-pip \
  curl wget ca-certificates unzip xz-utils \
  vulkan-tools libvulkan1 mesa-vulkan-drivers \
  libvulkan-dev glslc

echo
echo "Base Linux build dependencies installed."
echo "No GPU driver, kernel, service or model files were changed."
echo "Next: run ./scripts/check-linux-host.sh and ./scripts/detect-gpu.sh as your normal user."
