#!/usr/bin/env bash
# Create a separate ROCm ComfyUI venv; the existing CPU venv is never modified.
set -euo pipefail
PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
RESEARCH_ROOT="${ROCM_RESEARCH_ROOT:-$HOME/rocm-ps5-research}"
SOURCE_VENV="$PROJECT_ROOT/runtimes/comfy-venv"
DEST_VENV="$PROJECT_ROOT/runtimes/comfy-rocm-venv"
ROCM="${ROCM_ROOT:-$RESEARCH_ROOT/rocm-root/usr}"
ROCblasInstall="${ROCBLAS_INSTALL_ROOT:-$RESEARCH_ROOT/rocblas-install}"
WHEELS="${ROCM_WHEEL_DIR:-$RESEARCH_ROOT/wheels}"
READY="$PROJECT_ROOT/build/comfy-rocm-venv-ready"
MODE="${1:-full}"

die(){ echo "ERROR: $*" >&2; exit 1; }
[[ "$MODE" == "full" || "$MODE" == "prepare-only" || "$MODE" == "validate-only" ]] || die "Usage: $0 [full|prepare-only|validate-only]"
[[ -x "$SOURCE_VENV/bin/python" ]] || die "Source ComfyUI venv missing: $SOURCE_VENV"
[[ -f "$ROCblasInstall/lib/librocblas.so.5.1" ]] || die "Custom rocBLAS install missing"
[[ -f "$ROCM/lib/x86_64-linux-gnu/librocblas.so.5.1" ]] || die "gfx1013 rocBLAS not installed in isolated ROCm root"
[[ -f "$ROCM/lib/rocblas/library/TensileLibrary_lazy_gfx1013.dat" ]] || die "gfx1013 Tensile data missing from isolated ROCm root"

shopt -s nullglob
TORCH_WHEELS=("$WHEELS"/torch-2.10.0+ps5gfx1013*.whl)
VISION_WHEELS=("$WHEELS"/torchvision-0.25.0+ps5gfx1013*.whl)
AUDIO_WHEELS=("$WHEELS"/torchaudio-2.10.0+ps5gfx1013*.whl)
[[ ${#TORCH_WHEELS[@]} -eq 1 ]] || die "Expected exactly one custom PyTorch 2.10.0 wheel"
[[ ${#VISION_WHEELS[@]} -eq 1 ]] || die "Expected exactly one custom Torchvision 0.25.0 wheel"
[[ ${#AUDIO_WHEELS[@]} -le 1 ]] || die "Expected at most one custom Torchaudio 2.10.0 wheel"

export ROCM_PATH="$ROCM" ROCM_HOME="$ROCM" HIP_PATH="$ROCM"
export LD_LIBRARY_PATH="$RESEARCH_ROOT/runtime-libs/usr/lib/x86_64-linux-gnu:$ROCblasInstall/lib:$ROCM/lib/x86_64-linux-gnu:$ROCM/lib/rocm/llvm/lib:$ROCM/lib:$ROCM/lib/rocm/lib:${LD_LIBRARY_PATH:-}"
rm -f "$READY"
if [[ "$MODE" == "validate-only" && ! -x "$DEST_VENV/bin/python" ]]; then
  die "ROCm ComfyUI venv is missing: $DEST_VENV"
fi

if [[ "$MODE" != "validate-only" ]]; then
  if [[ ! -x "$DEST_VENV/bin/python" ]]; then
    echo "Cloning the current ComfyUI environment to a separate ROCm venv."
    cp -a "$SOURCE_VENV" "$DEST_VENV"
  fi

  "$DEST_VENV/bin/python" -m pip uninstall -y torch torchvision torchaudio triton >/dev/null 2>&1 || true
  INSTALL_WHEELS=("${TORCH_WHEELS[0]}" "${VISION_WHEELS[0]}")
  if [[ ${#AUDIO_WHEELS[@]} -eq 1 ]]; then
    INSTALL_WHEELS+=("${AUDIO_WHEELS[0]}")
  else
    echo "Torchaudio wheel not available; skipping optional audio support for the image-generation runtime."
  fi
  "$DEST_VENV/bin/python" -m pip install --no-deps "${INSTALL_WHEELS[@]}"
fi

if [[ "$MODE" == "prepare-only" ]]; then export PS5_ROCM_PREPARE_ONLY=1; fi
"$DEST_VENV/bin/python" - <<'PY'
import torch, torchvision
try:
    import torchaudio
except ImportError:
    torchaudio = None
assert torch.version.hip is not None, f"Expected ROCm PyTorch, got {torch.__version__}"
print("PyTorch:", torch.__version__, "HIP:", torch.version.hip)
print("Torchvision:", torchvision.__version__)
print("Torchaudio:", torchaudio.__version__ if torchaudio is not None else "optional audio package not installed")
print("GPU available:", torch.cuda.is_available())
if not torch.cuda.is_available():
    if __import__("os").environ.get("PS5_ROCM_PREPARE_ONLY") == "1":
        print("GPU validation deferred; this is a prepare-only install.")
    else:
        raise SystemExit("The patched PS5 GPU is not visible to PyTorch; keep using the CPU ComfyUI service")
else:
    print("GPU:", torch.cuda.get_device_name(0))
PY

if [[ "$MODE" == "prepare-only" ]]; then
  echo "ROCm ComfyUI venv installed; GPU validation is still pending."
  echo "The CPU venv remains unchanged. Do not activate this service yet."
  exit 0
fi

ROCM_TEST_VENV="$DEST_VENV" "$PROJECT_ROOT/scripts/rocm/test-torch-gfx1013.sh" quick
mkdir -p "$(dirname "$READY")"
{
  echo "venv=$DEST_VENV"
  echo "torch=$( "$DEST_VENV/bin/python" -c 'import torch; print(torch.__version__)' )"
  echo "created=$(date -Is)"
} > "$READY"
echo "Separate ROCm ComfyUI venv is ready: $DEST_VENV"
echo "The existing CPU venv remains unchanged: $SOURCE_VENV"
