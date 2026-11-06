# PS5 gfx1013 ROCm / ComfyUI GPU path

This document tracks the separate ROCm path for the retail PS5 APU. The existing Vulkan image engine and the current CPU ComfyUI service remain intact until the ROCm path passes its GPU tests.

## Hardware and detection

- GPU: AMD Custom Zen 2 / Cyan Skillfish, PCI ID `1002:13fb`
- ROCm target: `gfx1013`
- Isolated ROCm user-space tree: `/home/michel/rocm-ps5-research/rocm-root/usr`
- The current stock driver enumerates one HIP device as `gfx1013`; `rocminfo` exposes about 7.2 GiB of HSA GPU-accessible memory.
- DRM sysfs reports only 512 MiB local VRAM and about 7.05 GiB GTT/shared memory. The 7.2 GiB HSA figure is therefore **not dedicated VRAM**; the PS5 APU is relying heavily on shared system memory.
- Device enumeration is **not** proof that compute is stable. The PS5 KFD TLB patch must be loaded before GEMM, convolution, allocation-reuse or model-generation tests.

## Root-cause approach

The current upstream BC-250 investigation identifies stale compute-TLB entries after GPU memory unmap as the root cause behind several previously misattributed failures. The ported PS5 kernel patch rebuilds the HWS runlist on unmap for PCI ID `13fb`. A separate TTM NULL-page guard protects cleanup after partially populated buffer objects.

The optional SDMA firmware replacement is staged separately. First GPU tests must run with `HSA_ENABLE_SDMA=0`; only after those pass should the Navi12 SDMA 5.0 firmware be staged and tested.

Historical ComfyUI workarounds such as `bc250_conv_fix.py` and no-op `torch.cuda.empty_cache()` patches are **not enabled**. Re-test native MIOpen convolution and cache cleanup after the KFD patch before applying those workarounds.

## Selected software versions

| Component | Target |
|---|---|
| ROCm core user space | 7.1.5 |
| PyTorch | 2.10.0, custom build for gfx1013 |
| Torchvision | 0.25.0, built against the custom PyTorch |
| Torchaudio | 2.10.0, built against the custom PyTorch |
| GPU architecture | gfx1013 |
| Python | 3.14.4 |

The extracted ROCm tree contains the 7.1.5 core toolchain. A few missing companion development packages were unpacked into this isolated tree from the available Ubuntu ROCm 7.1.0/7.1.1 packages so CMake can resolve their headers and targets. Their runtime ABI compatibility still needs to be confirmed by the GPU smoke tests. No system-wide ROCm packages were installed.

The original CPU ComfyUI virtual environment remains intact and is retained as the rollback option. The active user service now runs the separate `comfy-rocm-venv`; do not remove or modify the CPU venv.

## Build scripts

- `kernel-patches/ps5-gfx1013/build-module.sh`
- `scripts/rocm/configure-rocblas.sh`
- `scripts/rocm/build-rocblas.sh`
- `scripts/install-rocm-rocblas-gfx1013.sh` and `scripts/rollback-rocm-rocblas-gfx1013.sh`
- `scripts/build-rocblas-smoke.sh`
- `scripts/enable-ps5-rocm-gpu.sh` (deprecated; live unload is blocked by a persistent amdgpu reference and the script now exits safely)
- `kernel-patches/ps5-gfx1013/install.sh` (stages the patched module for boot-time loading and preserves the stock kernel/initramfs)
- `scripts/rocm/build-pytorch.sh`
- `scripts/rocm/install-torch-wheel-to-build-venv.sh`
- `scripts/rocm/build-torchvision.sh`
- `scripts/rocm/build-torchaudio.sh`
- `scripts/rocm/test-torch-gfx1013.sh` and `test-torch-gfx1013.py`
- `scripts/create-comfy-rocm-venv.sh` (supports `prepare-only`, `validate-only` and `full`; CPU venv remains untouched)
- `scripts/rocm/patch-comfy-kitchen-gfx1013.py` (optional HIP FP32 fallback for the Qwen3-VL INT8 path if HIP INT8 GEMM is unavailable)
- `scripts/rocm/activate-comfyui-rocm.sh` and `rollback-comfyui-rocm.sh`
- `scripts/rocm/test-krea2-gpu.sh` and `scripts/rocm/krea2-gpu-smoke-api.json`

The expected workspace layout, build order and GPU validation sequence are documented in `scripts/rocm/README.md`.

### HIP compiler environment

The extracted ROCm tree is not installed at `/opt/rocm`, so the packaged `hipcc` needs explicit paths:

```bash
export ROCM_PATH="$ROCM" HIP_PATH="$ROCM"
export HIP_CLANG_PATH="$ROCM/lib/rocm/llvm/bin"
export HIP_INCLUDE_PATH="$ROCM/include"
export HIP_LIB_PATH="$ROCM/lib/x86_64-linux-gnu"
export HIPCC_COMPILE_FLAGS_APPEND="--rocm-device-lib-path=$ROCM/lib/rocm/llvm/lib/clang/20/amdgcn/bitcode -I$ROCM/include"
export HIPCC_LINK_FLAGS_APPEND="-L$ROCM/lib/x86_64-linux-gnu -lamdhip64 -Wl,-rpath,$ROCM/lib/x86_64-linux-gnu"
```

The custom rocBLAS/Tensile build for gfx1013 is complete and installed into both the isolated `rocblas-install` prefix and the extracted ROCm root. The installed `librocblas.so.5.1` and `TensileLibrary_lazy_gfx1013.dat` hashes match the custom build. The installer preserved the previous ROCm files for rollback.

PyTorch's CMake configuration now resolves HIP 7.1.5, MIOpen, rocBLAS, the companion ROCm packages, Python 3.14 development headers and the ROCm profiling library. The official PyTorch AMD HIPify step is part of the build script. The custom PyTorch 2.10.0+ps5gfx1013 wheel and Torchvision 0.25.0+ps5gfx1013 wheel have now been built and installed into the isolated `comfy-rocm-venv`. The optional Torchaudio wheel is not available yet; the ComfyUI image-generation runtime can operate without it.

## Krea 2 model path

The local model files are present and visible to the running ComfyUI API:

- Diffusion model: `krea2Sickrealism_v40_3292927.safetensors` (7.02 GiB; 942 tensors; metadata identifies `INT4_W4A4_ConvRot`, with 256 quantized matrix layers).
- Text encoder: `qwen3vl_4b_int8_convrot.safetensors` (4.52 GiB; 1,219 tensors; 253 quantization metadata tensors).
- VAE: `qwen_image_vae.safetensors` (0.24 GiB; 194 tensors).

The ComfyUI model paths map the image checkpoint folder to `diffusion_models` and the local encoder folder to `text_encoders`. The live CPU ComfyUI API lists all three exact model files. All nine nodes in the dedicated Krea 2 API smoke workflow were checked against the live `/object_info` schemas; no required inputs are missing and no unknown inputs were found. This confirms model discovery and workflow schema compatibility, not successful model loading or generation.

The ComfyKitchen HIP kernel manifest does not list `gfx1013`, so its specialized HIP kernels must not be assumed to work on this PS5. The intended path is its eager PyTorch fallback: ConvRot W4A4 uses PyTorch matrix operations on the tensor device, which should dispatch to HIP when the tensors are on the PS5 GPU. The INT8 Qwen3-VL path is explicitly tested; if PyTorch HIP INT8 GEMM is unavailable, the optional patch uses FP32 GEMM through HIP rather than moving the calculation to CPU.

The Krea 2 checkpoint is about 7.54 GB (about 7.02 GiB) and the INT8 text encoder about 4.85 GB (about 4.52 GiB). The original 7.05 GiB GTT pool was shared with system RAM and required staged/offloaded weights. Since 2026-11-06, the PS5 boots with `ttm.pages_limit=4063232` (15.5 GiB allocator limit); the live ComfyUI startup reported 15,872 MB total VRAM after this change. The active ROCm service uses `--enable-dynamic-vram --fp8_e4m3fn-text-enc --force-fp16 --fp16-intermediates --reserve-vram 0.5`, allowing ComfyUI to manage residency dynamically while keeping a modest 0.5 GiB reserve. The physical unified-memory limit still applies: a larger GTT allocator limit does not create additional physical RAM, so model weights, activations and Linux still compete for the same memory.

A dedicated ComfyUI blueprint has been prepared at:

`runtimes/ComfyUI/blueprints/PS5 Krea2 Sickrealism (GPU).json`

It uses the exact local checkpoint, Qwen3-VL INT8 ConvRot encoder and Qwen Image VAE, with a 768×768 starting resolution and the Krea2 sampler settings (8 steps, CFG 1, Euler/simple). The reproducible GPU smoke test defaults to 384×384 at 2 steps. 384×384/4-step and 512×512/4-step runs were stopped before completion when shared-memory/swap pressure approached the device limit; treat those higher-step settings as unvalidated on this device.


## Expanded PS5 GTT memory (2026-11-06)

- Kernel command line: `ttm.pages_limit=4063232` (15.5 GiB allocator limit).
- Runtime verification: `/sys/module/ttm/parameters/pages_limit` reports `4063232`; DRM GTT total reports `15139840000` bytes.
- ComfyUI startup after the kernel change reported `Total VRAM 15872 MB` and `12.15 GB free / 15.50 GB total`. This confirms that the image runtime sees the expanded GTT pool.
- The active user service already uses dynamic VRAM and a 0.5 GiB reserve. The packaged ROCm unit template is synchronized to those same settings so a future service activation does not silently restore the old 2.0 GiB reserve / disabled-dynamic-VRAM profile.
- No service restart was performed during this update; the text model remains untouched. ComfyUI will use the updated kernel memory pool on its next normal start.

## Verified Krea 2 GPU generation (2026-11-04)

The separate ROCm ComfyUI service has now completed end-to-end image generation on the PS5. The successful configuration is:

- Service: `comfy-rocm-venv`, port `8790`, systemd user unit `ps5-ai-studio-comfyui.service`.
- Launch flags: `--disable-dynamic-vram --fp8_e4m3fn-text-enc --force-fp16 --reserve-vram 2.0`.
- Qwen3-VL text encoder: `cuda:0`, `torch.float8_e4m3fn`.
- Krea2 diffusion model: partially resident on GPU; remaining weights are offloaded to host memory.
- VAE: `cuda:0`.
- Successful smoke outputs: `PS5_Krea2_GPU_smoke_00001_.png` (256×256), `PS5_Krea2_GPU_smoke_00002_.png` (256×256) and `PS5_Krea2_GPU_smoke_00003_.png` (384×384).
- The 384×384/2-step run completed in 169.36 seconds. 384×384/4-step and 512×512/4-step experiments were interrupted before completion because swap pressure approached the device limit; neither is a validated preset.

The smoke script now defaults to the proven 384×384 / 2-step profile. Increase resolution or steps only with memory monitoring. The service is left on the FP8 / 2.0 GiB reserve profile; the previous low-VRAM unit and original CPU unit are retained outside the active service for rollback.

## Runtime settings for first tests

Use these environment variables for the first GPU runs:

```bash
HSA_ENABLE_SDMA=0
GPU_PINNED_MIN_XFER_SIZE=16384
TORCH_BLAS_PREFER_HIPBLASLT=0
```

Do not enable SDMA before the KFD TLB workaround passes the one-cycle and 30-cycle HIP tests.

## Current state

- [x] ROCm runtime enumerates PS5 gfx1013 on the stock driver (enumeration only).
- [x] HIP enumeration, rocBLAS GEMM and HIP GPU execution validated on gfx1013; the custom rocBLAS, HIP and HSA runtime libraries resolve correctly.
- [x] PS5 kernel module built and loaded for the active `7.3.0-PinkSoup` kernel, including KFD runlist TLB fix, PS5-gated PASID KIQ bypass and TTM NULL-page guard.
- [x] Custom rocBLAS/Tensile built and installed into the isolated ROCm root; stock files backed up for rollback.
- [x] PyTorch CMake configuration corrected and generated with ROCm/HIP and Python enabled.
- [x] PyTorch 2.10.0+ps5gfx1013 and Torchvision 0.25.0+ps5gfx1013 wheels built and installed into the separate `comfy-rocm-venv`.
- [x] PyTorch 2.10.0+ps5gfx1013 imports with HIP 7.1.52801; Torchvision, ComfyKitchen, safetensors, NumPy and Pillow import successfully. The GPU quick suite passes rocBLAS FP32 GEMM, MIOpen FP32 Conv2d, ComfyKitchen INT8/ConvRot W4A4 HIP fallback, torchvision GPU NMS, pinned transfers and allocation/free cycles.
- [ ] Optional Torchaudio 2.10.0 wheel (not required for image generation; current build skipped it).
- [x] Patched amdgpu module staged and loaded through the controlled kexec path. SDMA remains disabled for these tests (`HSA_ENABLE_SDMA=0`).
- [x] HIP GEMM, rocBLAS GEMM, MIOpen Conv2d, INT8, ConvRot W4A4, torchvision and allocation-reuse tests pass on the patched GPU.
- [x] Separate `comfy-rocm-venv` validated after the patched driver was loaded; original CPU venv remains unchanged.
- [x] Krea2 ComfyUI API workflow and dedicated UI blueprint prepared; all three exact model files are discoverable and the nine-node API workflow passes live node-schema validation.
- [x] Krea2 generated real images on the PS5 GPU. Verified 256×256/2 steps (123.46 s) and 384×384/2 steps (169.36 s), with Qwen3-VL FP8 on `cuda:0`, Krea2 partially on GPU with host offload, and VAE on `cuda:0`.
- [x] Active `ps5-ai-studio-comfyui.service` runs the ROCm venv on port 8790 with the validated FP8 text-encoder / 2.0 GiB reserve profile. The original CPU venv and unit backup are retained for rollback.

The detailed staged kernel install, fallback and rollback steps are in [the PS5 gfx1013 kernel patch README](../kernel-patches/ps5-gfx1013/README.md).

## PS5 AI Studio model-library integration

The Workflow Studio Krea 2 card now reads a live backend profile from `GET /api/krea2/status`:

- Detects the active `comfy-rocm-venv` ComfyUI process separately from generic HIP device detection.
- Reports the actual ROCm/HIP gfx1013 profile, FP8 Qwen3-VL encoder, VAE GPU placement and diffusion host-offload behavior.
- Reports the current unified GPU memory pool (total / used / free), host `MemAvailable`, and free swap.
- Exposes a machine-readable `memoryPolicy` with the tested and recommended 384×384 / 2-step preset and 2 GiB reserve.
- The UI distinguishes assets/GPU presence from a confirmed active ROCm service. It does not claim that all Krea2 weights are resident in VRAM.

The memory state is informational for the status card. Direct Krea 2 generation applies a hard preflight gate: at least 4 GiB `MemAvailable` and 2.6 GiB free unified GPU memory are required before queueing a job.

## Direct Krea 2 generation API

The Workflow Studio card now submits a fixed, validated ComfyUI API graph through the PS5 AI Studio server:

- `POST /api/krea2/generate`: accepts a prompt (up to 6000 characters), 256 or 384 square resolution, and optional nonnegative seed. It enforces 2 steps, CFG 1, Euler/simple and batch size 1.
- `GET /api/krea2/jobs/:id`: tracks ComfyUI queue/history and copies the finished PNG into the regular PS5 AI Studio image gallery, with a JSON sidecar containing prompt, seed, dimensions and model provenance.
- `POST /api/krea2/jobs/:id/cancel`: removes a queued job or interrupts it when it is the active ComfyUI job.
- UI exposes direct prompt entry, resolution and seed controls, status, cancellation, result preview and download.

The route rejects empty/oversized prompts, inactive ROCm profile, missing assets, low host RAM and low free unified GPU memory. The direct-generation endpoint was syntax-checked and the empty-prompt rejection was exercised. A complete direct-API generation smoke test passed: 384×384 / 2 steps completed in 128.39 seconds, returned a valid 384×384 PNG (246,892 bytes), wrote the JSON provenance sidecar, appeared in `/api/gallery`, and passed an HTTP gallery download round-trip. Both PS5 AI Studio and ComfyUI services remained active after completion. The run used host offload and substantial swap; keep the preflight memory guard and do not raise defaults without additional tests.
