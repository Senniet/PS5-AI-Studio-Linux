#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MNN_ROOT="${MNN_ROOT:-$HOME/ai-runtimes/MNN}"
MNN_BUILD_DIR="${MNN_BUILD_DIR:-$MNN_ROOT/build-ps5}"
MNN_INSTALL_DIR="${MNN_INSTALL_DIR:-$MNN_ROOT/install}"
DATA_ROOT="${PS5_AI_STUDIO_DATA:-$HOME/.local/share/ps5-ai-studio}"
MODEL_DIR="$DATA_ROOT/models/image/enhancers/gfpgan"
YUNET_SOURCE="$DATA_ROOT/models/image/detectors/yunet/face_detection_yunet_2023mar.onnx"
RUNTIME_DIR="$ROOT/runtimes/face-restoration"
SOURCE_ONNX="$MODEL_DIR/gfpgan14-fp16.onnx"
mkdir -p "$MODEL_DIR" "$RUNTIME_DIR/bin"
test -f "$YUNET_SOURCE"
test -x "$MNN_BUILD_DIR/MNNConvert"
test -f "$MNN_BUILD_DIR/source/backend/vulkan/libMNN_Vulkan.so"
test -f "$MNN_INSTALL_DIR/include/MNN/Interpreter.hpp"
PYTHON="$ROOT/runtimes/comfy-venv/bin/python"
"$PYTHON" -c "import cv2, numpy, PIL"
cp "$MNN_INSTALL_DIR/lib/libMNN.so" "$RUNTIME_DIR/"
cp "$MNN_BUILD_DIR/source/backend/vulkan/libMNN_Vulkan.so" "$RUNTIME_DIR/"
if [[ ! -s "$SOURCE_ONNX" ]]; then
  curl -fL --retry 3 'https://huggingface.co/sidkonduru/gfpgan-v1.4-onnx/resolve/main/gfpgan14-fp16.onnx' -o "$SOURCE_ONNX"
fi
"$MNN_BUILD_DIR/MNNConvert" -f ONNX --modelFile "$SOURCE_ONNX" --MNNModel "$MODEL_DIR/gfpgan-v1.4.mnn" --fp16
cp "$YUNET_SOURCE" "$MODEL_DIR/yunet-face-detection.onnx"
g++ -std=c++17 -O3 -DNDEBUG -I"$MNN_INSTALL_DIR/include" \
  "$ROOT/apps/server/gfpgan_mnn.cpp" \
  -L"$RUNTIME_DIR" \
  -Wl,-rpath,'$ORIGIN/..' \
  -Wl,--no-as-needed -lMNN_Vulkan -lMNN -Wl,--as-needed -pthread -ldl \
  -o "$RUNTIME_DIR/bin/gfpgan-mnn"
cat > "$MODEL_DIR/model-info.json" <<'JSON'
{
  "name": "GFPGAN v1.4",
  "source": "https://huggingface.co/sidkonduru/gfpgan-v1.4-onnx",
  "license": "Apache-2.0",
  "runtime": "MNN Vulkan FP32",
  "input": "512x512 RGB face crop, float32 [-1,1]",
  "detector": "YuNet 2023mar (MIT)",
  "purpose": "Optional face restoration; may reconstruct facial detail"
}
JSON
chmod 755 "$RUNTIME_DIR/bin/gfpgan-mnn" "$ROOT/apps/server/gfpgan_face_restore.py"
echo "GFPGAN MNN/Vulkan runtime built: $RUNTIME_DIR/bin/gfpgan-mnn"
