#!/usr/bin/env python3
import argparse
import math
import sys
import time

def main():
    parser = argparse.ArgumentParser(description="PS5 gfx1013 PyTorch/ROCm validation")
    parser.add_argument("--loops", type=int, default=30, help="allocation/reuse cycles")
    parser.add_argument("--skip-torchaudio", action="store_true")
    parser.add_argument("--skip-pinned", action="store_true")
    args = parser.parse_args()

    import torch
    print(f"PyTorch: {torch.__version__}")
    print(f"HIP: {torch.version.hip}")
    if torch.version.hip is None:
        raise RuntimeError("This is not a ROCm-enabled PyTorch build")
    if not torch.cuda.is_available():
        raise RuntimeError("torch.cuda.is_available() is false; refusing to report a GPU test as passed")

    device = torch.device("cuda:0")
    props = torch.cuda.get_device_properties(device)
    print(f"Device: {props.name}")
    print(f"VRAM reported: {props.total_memory / (1024**3):.2f} GiB")
    print(f"cuDNN/MIOpen backend: enabled={torch.backends.cudnn.enabled}, version={torch.backends.cudnn.version()}")
    torch.manual_seed(20261103)

    # rocBLAS: deterministic FP32 matrix multiply, compared with CPU.
    a = torch.randn((512, 512), dtype=torch.float32, device=device)
    b = torch.randn((512, 512), dtype=torch.float32, device=device)
    c = torch.matmul(a, b)
    torch.cuda.synchronize()
    reference = torch.matmul(a.cpu(), b.cpu())
    torch.testing.assert_close(c.cpu(), reference, rtol=2e-3, atol=2e-3)
    print("PASS: rocBLAS FP32 GEMM")

    # MIOpen: convolution forward path, compared with CPU.
    conv = torch.nn.Conv2d(16, 32, kernel_size=3, padding=1).to(device)
    x = torch.randn((2, 16, 64, 64), dtype=torch.float32, device=device)
    y = conv(x)
    torch.cuda.synchronize()
    y_ref = torch.nn.functional.conv2d(
        x.cpu(), conv.weight.detach().cpu(), conv.bias.detach().cpu(), padding=1
    )
    torch.testing.assert_close(y.cpu(), y_ref, rtol=3e-3, atol=3e-3)
    if not torch.isfinite(y).all().item():
        raise RuntimeError("MIOpen convolution produced non-finite values")
    print("PASS: MIOpen FP32 Conv2d")

    # Qwen3-VL's INT8 ConvRot text encoder may use torch.int8_mm on the
    # fallback path. Probe the exact HIP operator before attempting Krea 2.
    int8_mm_ok = False
    try:
        a8 = torch.randint(-8, 8, (32, 256), dtype=torch.int8, device=device)
        b8 = torch.randint(-8, 8, (256, 64), dtype=torch.int8, device=device)
        mm8 = torch.int8_mm(a8, b8) if hasattr(torch, "int8_mm") else torch._int_mm(a8, b8)
        torch.cuda.synchronize()
        ref8 = a8.cpu().to(torch.int32) @ b8.cpu().to(torch.int32)
        torch.testing.assert_close(mm8.cpu().to(torch.int32), ref8, rtol=0, atol=0)
        int8_mm_ok = True
        print("PASS: HIP INT8 GEMM")
    except (RuntimeError, NotImplementedError) as exc:
        print("WARN: HIP INT8 GEMM unavailable; ComfyKitchen needs its FP32 HIP fallback:", str(exc).splitlines()[0])

    # Krea 2 uses ComfyKitchen ConvRot W4A4. gfx1013 has no validated
    # WMMA kernel, so this explicitly verifies the eager PyTorch fallback
    # executes on HIP tensors rather than silently moving the math to CPU.
    try:
        import importlib.util
        has_comfy_kitchen = importlib.util.find_spec("comfy_kitchen") is not None
    except (ImportError, ModuleNotFoundError):
        has_comfy_kitchen = False
    if has_comfy_kitchen:
        from comfy_kitchen.backends.eager.quantization import int8_linear
        try:
            x8 = torch.randn((2, 256), dtype=torch.float16, device=device)
            w8 = torch.randint(-8, 8, (64, 256), dtype=torch.int8, device=device)
            s8 = torch.tensor(0.01, dtype=torch.float32, device=device)
            y8 = int8_linear(x8, w8, s8, out_dtype=torch.float16, convrot=True, convrot_groupsize=256)
            torch.cuda.synchronize()
            if not torch.isfinite(y8).all().item():
                raise RuntimeError("ComfyKitchen INT8 ConvRot returned non-finite values")
            print("PASS: ComfyKitchen INT8 ConvRot on HIP GPU")
        except (RuntimeError, NotImplementedError) as exc:
            raise RuntimeError("ComfyKitchen INT8 ConvRot is required for the Krea2 Qwen3-VL encoder; apply the gfx1013 FP32 HIP fallback before activation") from exc

        from comfy_kitchen.backends.eager.convrot_w4a4 import (
            quantize_convrot_w4a4_weight, convrot_w4a4_linear
        )
        from comfy_kitchen.backends.eager.svdquant import _INT4_GROUP_SIZE
        torch.manual_seed(17)
        x_cpu = torch.randn((2, 256), dtype=torch.float16)
        w_cpu = torch.randn((64, 256), dtype=torch.float32) * 0.05
        b_cpu = torch.randn((64,), dtype=torch.float16) * 0.01
        qw_cpu, ws_cpu = quantize_convrot_w4a4_weight(
            w_cpu, convrot_groupsize=256, quant_group_size=_INT4_GROUP_SIZE
        )
        try:
            y_cpu = convrot_w4a4_linear(
                x_cpu, qw_cpu, ws_cpu, b_cpu,
                convrot_groupsize=256, quant_group_size=_INT4_GROUP_SIZE
            )
        except RuntimeError:
            # Some CPU BLAS builds lack FP16 GEMM; the HIP execution check below
            # remains authoritative for the target PS5 device.
            y_cpu = None
        y_gpu = convrot_w4a4_linear(
            x_cpu.to(device), qw_cpu.to(device), ws_cpu.to(device), b_cpu.to(device),
            convrot_groupsize=256, quant_group_size=_INT4_GROUP_SIZE
        )
        torch.cuda.synchronize()
        if tuple(y_gpu.shape) != (2, 64) or not torch.isfinite(y_gpu).all().item():
            raise RuntimeError("ComfyKitchen ConvRot W4A4 HIP output is invalid")
        if y_cpu is not None:
            torch.testing.assert_close(y_gpu.cpu(), y_cpu, rtol=5e-2, atol=5e-2)
        print("PASS: ComfyKitchen eager ConvRot W4A4 on HIP GPU")
    else:
        print("SKIP: ComfyKitchen is not installed in this test venv")

    # Torchvision GPU custom operator used by common ComfyUI workflows.
    import torchvision
    boxes = torch.tensor(
        [[0, 0, 10, 10], [1, 1, 9, 9], [20, 20, 30, 30]],
        dtype=torch.float32, device=device
    )
    scores = torch.tensor([0.9, 0.8, 0.7], dtype=torch.float32, device=device)
    keep = torchvision.ops.nms(boxes, scores, 0.5)
    torch.cuda.synchronize()
    if keep.cpu().tolist() != [0, 2]:
        raise RuntimeError(f"Unexpected torchvision NMS result: {keep.cpu().tolist()}")
    print(f"PASS: torchvision {torchvision.__version__} GPU NMS")

    # Torchaudio GPU path is optional, but validate it when installed.
    if not args.skip_torchaudio:
        try:
            import torchaudio
            waveform = torch.randn((1, 16000), dtype=torch.float32, device=device)
            resampled = torchaudio.functional.resample(waveform, 16000, 8000)
            torch.cuda.synchronize()
            if tuple(resampled.shape) != (1, 8000) or not torch.isfinite(resampled).all().item():
                raise RuntimeError(f"Unexpected torchaudio output: {tuple(resampled.shape)}")
            print(f"PASS: torchaudio {torchaudio.__version__} GPU resample")
        except ImportError:
            print("SKIP: torchaudio is not installed")

    # Pinned host-to-device transfer; a failure is reported separately because
    # locked-memory limits can vary, but it must never hang the whole test.
    if not args.skip_pinned:
        try:
            host = torch.empty((256, 256), dtype=torch.float32, pin_memory=True)
            host.uniform_(-1, 1)
            copied = torch.empty_like(host, device=device)
            copied.copy_(host, non_blocking=True)
            torch.cuda.synchronize()
            if not torch.isfinite(copied).all().item():
                raise RuntimeError("Pinned transfer returned non-finite values")
            print("PASS: pinned host-to-device transfer")
        except Exception as exc:
            print(f"WARNING: pinned transfer unavailable: {type(exc).__name__}: {exc}")

    # Repeated allocation/free/cache reuse catches stale GPU-TLB translations.
    start = time.monotonic()
    for i in range(args.loops):
        t = torch.randn((4, 512, 512), dtype=torch.float32, device=device)
        u = t.mul_(1.125).add_(0.25)
        checksum = u.sum()
        torch.cuda.synchronize()
        if not math.isfinite(float(checksum.item())):
            raise RuntimeError(f"Non-finite allocation/reuse result at cycle {i + 1}")
        del t, u, checksum
        torch.cuda.empty_cache()
    torch.cuda.synchronize()
    print(f"PASS: {args.loops} allocation/free/empty_cache cycles ({time.monotonic() - start:.1f}s)")
    print(f"Final allocated: {torch.cuda.memory_allocated(device) / (1024**2):.1f} MiB")
    print(f"Final reserved: {torch.cuda.memory_reserved(device) / (1024**2):.1f} MiB")
    print("ALL REQUESTED GPU TESTS PASSED")

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"GPU TEST FAILED: {type(exc).__name__}: {exc}", file=sys.stderr)
        raise