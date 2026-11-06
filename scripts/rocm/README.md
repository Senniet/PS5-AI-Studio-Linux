# gfx1013 ROCm build scripts

These scripts build a separate ROCm/PyTorch stack for the retail PS5 APU. They do not install packages into the host OS and do not replace the existing Vulkan image engine.

## Default research layout

The scripts default to `$HOME/rocm-ps5-research`. Override with environment variables if the source/build trees are elsewhere:

- `ROCM_RESEARCH_ROOT`: research workspace
- `ROCM_ROOT`: extracted ROCm user-space root (default: `$ROCM_RESEARCH_ROOT/rocm-root/usr`)
- `ROCM_BUILD_VENV`: Python build venv (default: `$ROCM_RESEARCH_ROOT/torch-build-venv`)
- `ROCBLAS_INSTALL_ROOT`: custom gfx1013 rocBLAS install prefix
- `ROCM_WHEEL_DIR`: output wheel directory
- `MAX_JOBS`: parallel build jobs (default 2 to protect the PS5's shared-memory APU)

Expected source directories:

- `pytorch-2.10.0`
- `torchvision-0.25.0`
- `torchaudio-2.10.0`

All sources must match the selected PyTorch 2.10 release family. PyTorch 2.10.0 is paired with Torchvision 0.25.0 and Torchaudio 2.10.0.

## Build order

1. Extract the ROCm 7.1.5 packages under `rocm-root/usr`.
2. Build and install a rocBLAS/Tensile library targeting `gfx1013` into `rocblas-install`. For a fresh workspace, first configure and build with upstream `rmake.py`:
   ```bash
   ./scripts/rocm/configure-rocblas.sh
   ```
   Then install the configured tree (or resume an existing build) with:
   ```bash
   ./scripts/rocm/build-rocblas.sh
   ```
   This also installs the custom library into the isolated ROCm root with a stock-library/Tensile backup. Then rebuild the GEMM smoke binary against that installed library:
   ```bash
   ./scripts/build-rocblas-smoke.sh
   ```
   Both scripts expect the ROCm 7.1.5 source checkout. The PyTorch script deliberately refuses to continue without this custom library.
3. Build the PyTorch wheel:
   ```bash
   ./scripts/rocm/build-pytorch.sh
   ```
   The script runs the official AMD HIPify step first, then configures Python 3.14 development headers and ROCm 7.1.5 before compiling for `gfx1013`. The isolated Python development headers are unpacked under `python-dev-root`; no host Python packages are installed.
4. Install that wheel into the isolated build venv so companion libraries compile against the exact custom PyTorch:
   ```bash
   ./scripts/rocm/install-torch-wheel-to-build-venv.sh
   ```
5. Build the matching companion wheels:
   ```bash
   ./scripts/rocm/build-torchvision.sh
   ./scripts/rocm/build-torchaudio.sh
   ```

The resulting wheels are written to `$ROCM_RESEARCH_ROOT/wheels`.

After the patched kernel is active and the wheels are installed into the build venv, run the GPU validation harness:

```bash
./scripts/rocm/test-torch-gfx1013.sh quick   # 5 allocation/reuse cycles
./scripts/rocm/test-torch-gfx1013.sh tlb     # 30 cycles, SDMA disabled
./scripts/rocm/test-torch-gfx1013.sh sdma    # 30 cycles, only after Navi12 SDMA firmware is staged
```

The harness checks rocBLAS GEMM, MIOpen Conv2d, HIP INT8 GEMM, ComfyKitchen INT8 ConvRot and W4A4 ConvRot (when ComfyKitchen is installed), Torchvision NMS, optional Torchaudio resampling, pinned transfers and repeated allocation/cache cleanup. It refuses to run unless the patched PS5 KFD module and gfx1013 runtime are visible.

## Important build details

- GPU target is `gfx1013`; do not set `HSA_OVERRIDE_GFX_VERSION`.
- The extracted ROCm root is not installed at `/opt/rocm`; the scripts set explicit HIP include, library, LLVM and device-library paths.
- The packaged `hipcc` needs `HIPCC_COMPILE_FLAGS_APPEND` and `HIPCC_LINK_FLAGS_APPEND` for this nonstandard root.
- Host C/C++ compilation uses ROCm LLVM 20.
- PyTorch is built with ROCm/MIOpen enabled and CUDA, distributed, RCCL, FBGEMM, MKL, MKLDNN and unsupported attention backends disabled.
- Torchvision uses `FORCE_CUDA=1` so HIP operators are built even before the patched PS5 kernel is booted and the GPU becomes available to PyTorch.
- Build parallelism defaults to two jobs to avoid exhausting the PS5's shared system/GPU memory.

## Runtime environment

For initial tests and first ComfyUI runs, use:

```bash
HSA_ENABLE_SDMA=0
GPU_PINNED_MIN_XFER_SIZE=16384
TORCH_BLAS_PREFER_HIPBLASLT=0
```

The SDMA firmware replacement is a separate step after the KFD TLB workaround passes. The prepared ComfyUI ROCm service template is `packaging/systemd/ps5-ai-studio-comfyui-rocm.service`; it is not installed or activated automatically.

## Krea 2 on gfx1013

The local Krea2 Sickrealism checkpoint is loaded through ComfyUI's Krea2 model path, not the native stable-diffusion.cpp engine:

- UNet: `krea2Sickrealism_v40_3292927.safetensors`
- Text encoder: `qwen3vl_4b_int8_convrot.safetensors`
- VAE: `qwen_image_vae.safetensors`

The dedicated UI blueprint is `runtimes/ComfyUI/blueprints/PS5 Krea2 Sickrealism (GPU).json`. The API smoke workflow and runner are `scripts/rocm/krea2-gpu-smoke-api.json` and `scripts/rocm/test-krea2-gpu.sh`. The smoke runner starts at 512×512; the UI blueprint defaults to 768×768.

The ROCm service template uses `--disable-dynamic-vram --lowvram --force-fp16 --reserve-vram 1.0`. The GPU reports roughly 7.2 GiB, so the large checkpoint and Qwen3-VL encoder cannot both stay resident with useful activation memory. Low-VRAM offload is intentional: tensor math must still run on HIP when layers are active.

ComfyKitchen's specialized HIP manifest does not include gfx1013. Its eager PyTorch path is therefore the selected compatibility route. The GPU validation harness tests both W4A4 ConvRot and INT8 ConvRot on HIP. If the Qwen3-VL INT8 operation is not implemented by the installed PyTorch HIP build, `scripts/rocm/patch-comfy-kitchen-gfx1013.py` adds an isolated FP32 HIP GEMM fallback inside the ROCm venv; it never changes the CPU venv.

## Safety

Do not replace the existing CPU-only ComfyUI packages or remove its `--cpu` flag until:

1. the patched PS5 kernel module has been booted;
2. the one-cycle and 30-cycle HIP tests pass with SDMA disabled;
3. PyTorch reports `torch.version.hip` and `torch.cuda.is_available()` correctly;
4. a matrix multiply and MIOpen convolution produce correct results;
5. ComfyUI completes a small Krea 2 image generation without memory corruption or kernel errors.

After the build-venv GPU tests pass, prepare the separate ComfyUI environment with `./scripts/create-comfy-rocm-venv.sh prepare-only`. This clones the current CPU venv and installs all three custom wheels; it never modifies the existing CPU venv. Once the patched driver is active, `./scripts/create-comfy-rocm-venv.sh validate-only` runs the GPU and ComfyKitchen quantization tests and writes the ready marker. Only then, `./scripts/rocm/activate-comfyui-rocm.sh --apply` backs up the current user unit and switches ComfyUI to the tested ROCm venv. If startup or its API health check fails, it restores the previous CPU unit automatically. `rollback-comfyui-rocm.sh` provides a manual restore path.

See [the full PS5 gfx1013 status and test plan](../../docs/ROCM_GFX1013.md).
