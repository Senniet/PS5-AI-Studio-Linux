#!/usr/bin/env bash
set -euo pipefail
RESEARCH_ROOT="${ROCM_RESEARCH_ROOT:-$HOME/rocm-ps5-research}"
VENV="${ROCM_BUILD_VENV:-$RESEARCH_ROOT/torch-build-venv}"
ROCM="${ROCM_ROOT:-$RESEARCH_ROOT/rocm-root/usr}"
ROCblasInstall="${ROCBLAS_INSTALL_ROOT:-$RESEARCH_ROOT/rocblas-install}"
WHEELS="${ROCM_WHEEL_DIR:-$RESEARCH_ROOT/wheels}"
shopt -s nullglob
candidates=("$WHEELS"/torch-2.10.0+ps5gfx1013*.whl)
[[ ${#candidates[@]} -eq 1 ]] || { echo "Expected exactly one custom PyTorch wheel; found ${#candidates[@]}" >&2; exit 2; }
export PATH="$VENV/bin:$ROCM/bin:$ROCM/lib/rocm/llvm/bin:$PATH"
export LD_LIBRARY_PATH="$RESEARCH_ROOT/runtime-libs/usr/lib/x86_64-linux-gnu:$ROCblasInstall/lib:$ROCM/lib/rocm/llvm/lib:$ROCM/lib/x86_64-linux-gnu:$ROCM/lib:$ROCM/lib/rocm/lib:${LD_LIBRARY_PATH:-}"
export ROCM_PATH="$ROCM" ROCM_HOME="$ROCM" HIP_PATH="$ROCM"
unset LD_PRELOAD
"$VENV/bin/pip" install --force-reinstall --no-deps "${candidates[0]}"
"$VENV/bin/python" - <<'PY'
import torch
assert torch.version.hip is not None, f"Wheel is not a ROCm build: {torch.__version__}"
assert torch.cuda.is_available(), "The patched ROCm wheel cannot enumerate the PS5 GPU"
props = torch.cuda.get_device_properties(0)
print("Installed custom PyTorch:", torch.__version__)
print("HIP runtime version:", torch.version.hip)
print("GPU visible without LD_PRELOAD:", torch.cuda.is_available())
print("GPU:", props.name)
print("VRAM:", round(props.total_memory / 1024**3, 2), "GiB")
PY