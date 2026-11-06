#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MNN_ROOT="${MNN_ROOT:-$HOME/ai-runtimes/MNN}"
MNN_BUILD_DIR="${MNN_BUILD_DIR:-$MNN_ROOT/build-ps5}"
MNN_INSTALL_DIR="${MNN_INSTALL_DIR:-$MNN_ROOT/install}"
DATA_ROOT="${PS5_AI_STUDIO_DATA:-$HOME/.local/share/ps5-ai-studio}"
MODEL_DIR="$DATA_ROOT/models/image/enhancers/retinexformer"
RUNTIME_DIR="$ROOT/runtimes/retinexformer"
PYTHON="${RETINEX_PYTHON:-$ROOT/runtimes/comfy-venv/bin/python}"
if [[ ! -x "$PYTHON" ]]; then PYTHON="$(command -v python3)"; fi
WEIGHTS="$MODEL_DIR/LOL_v1.pth"
mkdir -p "$MODEL_DIR" "$RUNTIME_DIR/bin" "$RUNTIME_DIR/lib"
if [[ ! -f "$WEIGHTS" ]]; then
  if "$PYTHON" -c "import gdown" >/dev/null 2>&1; then
    "$PYTHON" -m gdown 1xDwQtTCj3tlAVCTJgYrzonBGVwqeOhKu -O "$WEIGHTS" --continue
  elif command -v gdown >/dev/null 2>&1; then
    gdown 1xDwQtTCj3tlAVCTJgYrzonBGVwqeOhKu -O "$WEIGHTS" --continue
  else
    echo "LOL_v1.pth ontbreekt. Installeer gdown in de PS5 AI Studio-venv." >&2
    echo "gdown 1xDwQtTCj3tlAVCTJgYrzonBGVwqeOhKu -O '$WEIGHTS'" >&2
    exit 1
  fi
fi
test -f "$MNN_INSTALL_DIR/include/MNN/Interpreter.hpp"
test -x "$MNN_BUILD_DIR/MNNConvert"
test -f "$MNN_BUILD_DIR/source/backend/vulkan/libMNN_Vulkan.so"
"$PYTHON" -c "import torch, onnx, einops, numpy, PIL" || {
  echo "Python mist torch/onnx/einops/numpy/Pillow. Gebruik de PS5 AI Studio-venv." >&2; exit 1;
}
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
"$PYTHON" "$ROOT/scripts/retinexformer/export_onnx.py" --weights "$WEIGHTS" --output "$WORK"
for tile in 128 256 512; do
  "$MNN_BUILD_DIR/MNNConvert" -f ONNX \
    --modelFile "$WORK/retinexformer_${tile}.onnx" \
    --MNNModel "$MODEL_DIR/retinexformer-lol-v1-${tile}.mnn" \
    --bizCode Retinexformer --keepInputFormat
done
cp "$MNN_INSTALL_DIR/lib/libMNN.so" "$RUNTIME_DIR/lib/"
cp "$MNN_BUILD_DIR/source/backend/vulkan/libMNN_Vulkan.so" "$RUNTIME_DIR/lib/"
g++ -std=c++17 -O3 -DNDEBUG \
  -I"$MNN_INSTALL_DIR/include" \
  "$ROOT/apps/server/retinexformer_mnn.cpp" \
  -L"$MNN_BUILD_DIR/source/backend/vulkan" -L"$MNN_INSTALL_DIR/lib" \
  -Wl,-rpath,'$ORIGIN/../lib' \
  -Wl,--no-as-needed -lMNN_Vulkan -Wl,--as-needed -lMNN \
  -o "$RUNTIME_DIR/bin/retinexformer-mnn"
cp "$ROOT/scripts/retinexformer/LICENSE.txt" "$MODEL_DIR/LICENSE.txt"
cat > "$MODEL_DIR/model-info.json" <<'JSON'
{
  "name": "Retinexformer LOL-v1",
  "source": "https://github.com/caiyuanhao1998/Retinexformer",
  "license": "MIT",
  "runtime": "MNN Vulkan",
  "precision": "FP32",
  "tiles": [128, 256, 512],
  "purpose": "Low-light image enhancement"
}
JSON
if [[ "${RUN_TESTS:-1}" != "0" ]]; then
  "$PYTHON" "$ROOT/scripts/test-retinexformer-runtime.py" --weights "$WEIGHTS" --models "$MODEL_DIR" --runner "$RUNTIME_DIR/bin/retinexformer-mnn" --python "$PYTHON"
fi
echo "Retinexformer MNN Vulkan-runtime gereed."
echo "Modellen: $MODEL_DIR"
echo "Runner: $RUNTIME_DIR/bin/retinexformer-mnn"