#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMFY="$ROOT/runtimes/ComfyUI"
VENV="$ROOT/runtimes/comfy-rocm-venv"
PLUGIN="$COMFY/custom_nodes/seedvr2_videoupscaler"
MODEL_DIR="$COMFY/models/SEEDVR2"
PYTHON="$VENV/bin/python"

[[ -x "$PYTHON" ]] || { echo "Missing ROCm Python environment: $PYTHON" >&2; exit 1; }
[[ -d "$COMFY/custom_nodes" ]] || { echo "ComfyUI custom_nodes directory is missing." >&2; exit 1; }

export LD_LIBRARY_PATH="${HOME}/rocm-ps5-research/runtime-libs/usr/lib/x86_64-linux-gnu:${HOME}/rocm-ps5-research/rocblas-install/lib:${HOME}/rocm-ps5-research/rocm-root/usr/lib/rocm/llvm/lib:${HOME}/rocm-ps5-research/rocm-root/usr/lib/x86_64-linux-gnu:${HOME}/rocm-ps5-research/rocm-root/usr/lib:${HOME}/rocm-ps5-research/rocm-root/usr/lib/rocm/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# Keep pip launchers attached to this ROCm environment. Never replace its Torch build.
for launcher in "$VENV/bin/pip" "$VENV/bin/pip3" "$VENV/bin/pip3.14"; do
  if [[ -f "$launcher" ]]; then
    sed -i "1c\\#!$PYTHON" "$launcher"
  fi
done

"$PYTHON" - <<'PY'
import torch
if not torch.cuda.is_available() or not getattr(torch.version, "hip", None):
    raise SystemExit("Expected the existing PyTorch ROCm/HIP build; refusing to continue.")
print("Preserving", torch.__version__, "ROCm", torch.version.hip)
PY

if [[ ! -f "$PLUGIN/__init__.py" ]]; then
  git clone --depth 1 https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git "$PLUGIN"
fi

# These are the runtime imports needed by this plugin on the current PS5 build.
# --no-deps is intentional: do not let pip replace the custom ROCm Torch/TorchVision.
"$PYTHON" -m pip install --no-deps \
  'omegaconf==2.4.0' \
  'diffusers==0.42.1' \
  'rotary-embedding-torch==0.9.1' \
  'antlr4-python3-runtime==4.9.3' \
  'accelerate==1.15.0'

mkdir -p "$MODEL_DIR"
download_verified() {
  local url="$1" file="$2" expected="$3"
  if [[ -f "$file" ]]; then
    echo "$expected  $file" | sha256sum -c - >/dev/null && { echo "Verified existing $(basename "$file")"; return; }
    echo "Existing model has an unexpected hash; refusing to overwrite: $file" >&2
    exit 1
  fi
  local part="$file.part"
  curl -fL --retry 3 --retry-delay 3 --continue-at - "$url" -o "$part"
  echo "$expected  $part" | sha256sum -c -
  mv "$part" "$file"
}

download_verified \
  'https://huggingface.co/AInVFX/SeedVR2_comfyUI/resolve/main/seedvr2_ema_3b-Q4_K_M.gguf' \
  "$MODEL_DIR/seedvr2_ema_3b-Q4_K_M.gguf" \
  'e665e3909de1a8c88a69c609bca9d43ff5a134647face2ce4497640cc3597f0e'

download_verified \
  'https://huggingface.co/numz/SeedVR2_comfyUI/resolve/main/ema_vae_fp16.safetensors' \
  "$MODEL_DIR/ema_vae_fp16.safetensors" \
  '20678548f420d98d26f11442d3528f8b8c94e57ee046ef93dbb7633da8612ca1'

cd "$COMFY"
PYTHONPATH="$COMFY:$COMFY/custom_nodes${PYTHONPATH:+:$PYTHONPATH}" "$PYTHON" - <<'PY'
import torch, diffusers, omegaconf, rotary_embedding_torch
import seedvr2_videoupscaler
assert torch.cuda.is_available() and torch.version.hip
print("SeedVR2 plugin import OK ·", torch.__version__, "· ROCm", torch.version.hip)
print("diffusers", diffusers.__version__, "· OmegaConf", omegaconf.__version__)
PY

printf '\nSeedVR2 installed and verified.\n'
printf 'When ComfyUI is idle, activate it with: systemctl --user restart ps5-ai-studio-comfyui.service\n'
