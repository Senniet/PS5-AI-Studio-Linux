#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MNN_ROOT="${MNN_ROOT:-$HOME/ai-runtimes/MNN}"
BUILD_DIR="${MNN_BUILD_DIR:-$MNN_ROOT/build-ps5}"
INSTALL_DIR="${MNN_INSTALL_DIR:-$MNN_ROOT/install}"
JOBS="${JOBS:-8}"
if [[ ! -f "$MNN_ROOT/CMakeLists.txt" ]]; then
  echo "MNN source ontbreekt: $MNN_ROOT" >&2
  echo "Clone eerst https://github.com/alibaba/MNN.git --recursive" >&2
  exit 1
fi
cmake -S "$MNN_ROOT" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
  -DMNN_VULKAN=ON \
  -DMNN_SEP_BUILD=ON \
  -DMNN_BUILD_CONVERTER=ON \
  -DMNN_BUILD_SHARED_LIBS=ON \
  -DMNN_BUILD_DEMO=OFF \
  -DMNN_BUILD_TEST=OFF \
  -DMNN_BUILD_TOOLS=ON \
  -DMNN_OPENCL=OFF
cmake --build "$BUILD_DIR" --parallel "$JOBS"
cmake --install "$BUILD_DIR"
test -f "$BUILD_DIR/MNNConvert"
test -f "$BUILD_DIR/source/backend/vulkan/libMNN_Vulkan.so"
echo "MNN Vulkan + MNNConvert gereed: $BUILD_DIR"