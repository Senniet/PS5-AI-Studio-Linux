#!/usr/bin/env bash
set -euo pipefail
VENV=/home/michel/PS5-AI-Studio-Linux/runtimes/comfy-rocm-venv
PY="$VENV/bin/python"
[[ -x "$PY" ]] || { echo "PyTorch environment not found: $PY"; exit 1; }
export HSA_ENABLE_SDMA=1
export GPU_PINNED_MIN_XFER_SIZE=16384
export TORCH_BLAS_PREFER_HIPBLASLT=0
timeout --signal=TERM --kill-after=5s 60s "$PY" -u - <<'PY'
import torch, time
print("torch", torch.__version__, "HIP", torch.version.hip)
assert torch.cuda.is_available(), "ROCm device unavailable"
print("GPU", torch.cuda.get_device_name(0))
for size_mb in (4, 16, 64):
    n = size_mb * 1024 * 1024
    src = torch.empty(n, dtype=torch.uint8, pin_memory=True)
    dst = torch.empty(n, dtype=torch.uint8, device="cuda")
    back = torch.empty(n, dtype=torch.uint8, pin_memory=True)
    src.fill_(0x5A)
    torch.cuda.synchronize()
    t0 = time.perf_counter()
    for _ in range(3):
        dst.copy_(src, non_blocking=True)
        torch.cuda.synchronize()
    h2d = (time.perf_counter() - t0) / 3
    t0 = time.perf_counter()
    for _ in range(3):
        back.copy_(dst, non_blocking=True)
        torch.cuda.synchronize()
    d2h = (time.perf_counter() - t0) / 3
    if not torch.equal(src, back):
        raise RuntimeError(f"DATA MISMATCH at {size_mb} MiB")
    print(f"{size_mb:>2} MiB: H2D {h2d*1000:.2f} ms ({size_mb/h2d:.0f} MiB/s), D2H {d2h*1000:.2f} ms ({size_mb/d2h:.0f} MiB/s) — PASS", flush=True)
print("SDMA firmware transfer test passed.")
PY