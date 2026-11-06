#!/usr/bin/env python3
"""Apply a gfx1013-only FP32 HIP fallback to ComfyKitchen INT8 linear ops.

The patch is intentionally limited to the separate ROCm ComfyUI venv. It is
only needed if PyTorch's HIP INT8 GEMM is unavailable on the PS5 GPU.
"""
from pathlib import Path
import sys

project = Path(__file__).resolve().parents[2]
venv = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else project / "runtimes/comfy-rocm-venv"
candidates = list(venv.glob("lib/python*/site-packages/comfy_kitchen/backends/eager/quantization.py"))
if len(candidates) != 1:
    raise SystemExit(f"Expected one ComfyKitchen eager quantization.py under {venv}; found {len(candidates)}")
path = candidates[0]
source = path.read_text()
marker = "PS5_GFX1013_FP32_INT8_FALLBACK"
if marker in source:
    print("Already patched:", path)
    raise SystemExit(0)
needle = "    result = _int8_matmul_accumulate(x_8, weight.T.contiguous())"
replacement = """    # PS5_GFX1013_FP32_INT8_FALLBACK
    # gfx1013 does not have a validated ComfyKitchen INT8 GEMM kernel.
    # Keep the tensors on the HIP device and accumulate with ROCm FP32 GEMM.
    weight_t = weight.T.contiguous()
    if x_8.device.type == "cuda" and torch.version.hip is not None:
        result = torch.matmul(x_8.to(torch.float32), weight_t.to(torch.float32))
    else:
        result = _int8_matmul_accumulate(x_8, weight_t)"""
if source.count(needle) != 1:
    raise SystemExit(f"Expected one INT8 linear dispatch point in {path}; refusing to patch")
backup = path.with_suffix(path.suffix + ".ps5-backup")
if not backup.exists():
    backup.write_text(source)
path.write_text(source.replace(needle, replacement, 1))
print("Applied gfx1013 HIP INT8 fallback in:", path)