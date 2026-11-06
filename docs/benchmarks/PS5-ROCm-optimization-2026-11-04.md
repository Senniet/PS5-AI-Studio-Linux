# PS5 ROCm / Krea 2 optimisation log — 2026-11-04

## Hardware and runtime

- Console GPU: AMD Oberon, GFX1013, PCI `1002:13fb`.
- Kernel: `7.3.0-PinkSoup`.
- GPU compute units currently exposed: 36 / 40 (`active_cu_number 36`).
- GPU devfreq maximum: 2.23 GHz. The ComfyUI queue watcher switches to `performance` during work and `simple_ondemand` when idle.
- ROCm/HIP: 7.1.52801; PyTorch `2.10.0+ps5gfx1013`.
- ComfyUI: 0.43.0, Python 3.14.4, `--enable-dynamic-vram --force-fp16 --fp16-intermediates --reserve-vram 0.5`.
- Current service environment has `GPU_PINNED_MIN_XFER_SIZE=16384`, `TORCH_BLAS_PREFER_HIPBLASLT=0`, `MIOPEN_DEBUG_GCN_ASM_KERNELS=0`, and `HSA_ENABLE_SDMA=1` (drop-in `~/.config/systemd/user/ps5-ai-studio-comfyui.service.d/20-rocm-sdma.conf`).

## SDMA firmware and test results

- Navi12 SDMA firmware was installed under the Cyan Skillfish 2 firmware names. The original firmware backup is `/var/backups/ps5-sdma-firmware-20261104-173304`.
- Firmware installation happened before the current kernel boot. Both SDMA engines completed explicit HSA async-copy tests, including 16 MiB transfers, with correct completion and data integrity.
- Reference PyTorch 128 MiB copy benchmark, repeated twice:
  - SDMA off: 7,416 and 7,436 MiB/s.
  - SDMA on: 7,611 and 7,608 MiB/s.
  - Approximately 2.5% improvement for this copy microbenchmark.
- Krea2 512x512, 8-step A/B (different seeds, 3 runs per arm):
  - Off: 105.050, 102.691, 100.617 s; median 102.691 s.
  - On: 119.749, 101.204, 99.521 s; median 101.204 s.
  - Median difference ~1.45% in favour of SDMA on; not a large or conclusive inference speedup. The first on-run was an outlier.
- Decision: keep SDMA enabled for ComfyUI for now. Do not claim a 20% Krea2 speedup; that figure came from a different BC-250 workload/benchmark.
- A later in-process gfx1013/MIOpen correctness test passed 26/26 operations. Kernel page-fault count remained zero.

## Krea 2 model-path tests

### Controlled 4-step Turbo GGUF + official step LoRA

- API route, model `Krea-2-Turbo-Q3_K_M-3.91bpw.gguf`, Q4 text encoder, `krea2_turbo_4step_rank_64_lora_comfyui.safetensors`.
- 512x512, 4 steps, CFG 1.0, Euler/simple, LoRA strength 1.0.
- Full API time: **44.25 s**; ComfyUI execution time: **40.45 s**.
- Output: 363,092 bytes; pixel stddev 53.09; 82,891 unique colours. Valid nonblank 512x512 PNG.
- This is the fastest controlled Krea2 route so far. Compared with the 8-step Turbo GGUF run (117.7 s), it is about 2.66x faster in these tests. This is not a pure step-count comparison because the 4-step run reused the loaded Q4 text encoder and had a different model/cache state.
- Official 4-step LoRA instructions recommend 4–6 steps, CFG 1.0, Euler/simple, strength 1.0. 2-step LoRA is a preview/draft option; 7+ steps without a step LoRA is the native Turbo quality path.

### Controlled 2-step Turbo GGUF + preview LoRA

- Same Turbo GGUF model and Q4 encoder, `krea2_turbo_2step_rank_64_lora_comfyui.safetensors`, 512x512, 2 steps.
- Full API time: **58.986 s**; ComfyUI execution time: **42.57 s**. The Turbo-GGUF memory guard is 2.0 GiB; free GPU memory was 2.28 GiB, so ComfyUI was not restarted. This was a same-process follow-up run after the 4-step test.
- Output: 358,569 bytes; pixel stddev 49.80; 91,615 unique colours. Valid nonblank 512x512 PNG.
- It was not faster than the 4-step run: ComfyUI execution was 42.57 s versus 40.45 s for 4-step. The full API time also included a longer request/queue overhead. Keep 2-step as a preview candidate, not the default.

### 3-step LoRA on Sickrealism (cold run)

- API route, Sickrealism safetensors, Q4 text encoder, `krea2_turbo_3step_rank_64_lora_comfyui.safetensors`.
- 512x512, 3 steps, CFG 1.0, Euler/simple.
- Full API time: **110.565 s**; output 396,233 bytes. The model/encoder were cold and DynamicVRAM staged 6.58 GB, so this is not comparable to the warm 4-step Turbo GGUF run.
- Sickrealism v4.0's published recommendation is ER SDE/Beta, 8 steps, CFG 1, no negative prompt. The step-distill LoRAs are trained for Krea 2 Turbo; the Turbo GGUF + 4-step route is the better validated pairing.

### Turbo GGUF + Q4 text encoder

- Model: `Krea-2-Turbo-Q3_K_M-3.91bpw.gguf` (6.26 GB).
- Text encoder: `Qwen3VL-4B-Instruct-Q4_K_M.gguf` (2.50 GB).
- 512x512, 8 steps, CFG 1.0, Euler/simple.
- Completed successfully in 117.7 s (ComfyUI execution time).
- Output: 360,035 bytes; pixel stddev 54.84; 92,291 unique colours.
- ComfyUI-GGUF enabled `.kquant_triton_backend`; model was partially loaded (about 5,007 MB resident, 1,151 MB offloaded). This route works but was not faster than the best warm Sickrealism measurements.
- Official Krea 2 Turbo is an 8-step distilled model; fewer steps are not automatically better. The ByteShape Humming backend reports ~1.6x faster than GGUF but its published compatibility is Linux + NVIDIA only, so it is not a viable direct install on PS5 ROCm.

### Sickrealism safetensors + Q4 text encoder

- Default API path, 512x512, 8 steps, seed 20261131.
- ComfyUI execution time: 143.33 s on a cold model load.
- Output `PS5_AI_Studio_Krea2_00056_.png`: 410,662 bytes; pixel stddev 51.84; 95,613 unique colours.
- The Q4 text encoder was dynamically staged; the diffusion model was staged at about 6.58 GB. This was a cold run and should not be compared directly to warm Sickrealism runs (about 100–103 s in earlier tests).
- A transient Tctl peak of 90.75 C was observed during this run; it fell to ~86.75 C and then ~82 C. Fan target was 80 C. Do not raise clocks or reduce memory reserve without monitoring thermals.
- The warning `Can't find mmproj file ... Qwen-Image-Edit will be broken` is specific to the separate Qwen-Image-Edit path; Krea2 text encoding and generation proceeded.

## Reliability change

- Before this change, restarting ComfyUI also coincided with a stop/start of `ps5-ai-studio-linux.service`, which caused in-flight API polling to lose its connection and erased the in-memory Krea2 job map.
- Removed `Wants=ps5-ai-studio-linux.service` from `~/.config/systemd/user/ps5-ai-studio-comfyui.service`; retained `After=ps5-ai-studio-linux.service`. Both services are independently enabled under `default.target`, so API startup remains ordered but ComfyUI restarts should no longer pull the API down.
- Backup: `~/.config/systemd/user/ps5-ai-studio-comfyui.service.pre-independent-api-20261104-215331`.
- `systemctl --user daemon-reload` completed. Verified with an idle-queue ComfyUI restart: API PID remained `12468` before and after, both services stayed active, and GPU free memory returned to 7.05 GiB.

## Triton / GGUF backend investigation

- ComfyUI-GGUF logs `enabled K-quant backend .kquant_triton_backend`, but that message only confirms import/registration, not that the accelerated route is selected for every layer.
- The current local backend's launch selector is explicitly gated on `torch.cuda.get_device_capability(device) == (8, 6)` (RTX 3060/Ampere tuning). It supports Q3_K/Q4_K/Q5_K/Q6_K, but not Q2_K. The Krea2 Q3_K_M model reports 80 Q3_K tensors and 143 Q2_K tensors. Thus the backend may not be active on GFX1013 at all, and even a port would not accelerate the Q2_K tensors without additional work.
- ComfyUI startup explicitly reports `comfy-kitchen` Triton unavailable because `No module named 'triton'`. AMD's ROCm 7.1.0 wheel is Triton 3.4.0 for CPython 3.12, whereas this PS5 venv is Python 3.14 with a custom PyTorch 2.10.0+ps5gfx1013 build. Do not install a generic PyPI/NVIDIA Triton wheel into this environment. A compatible ROCm Triton build for Python 3.14 and gfx1013 would need to be built and tested separately.
- Important environment issue: `comfy-rocm-venv/bin/pip` has a shebang pointing to the separate CPU `comfy-venv/bin/python` (PyTorch 2.11.0+cpu). The actual ComfyUI service runs `comfy-rocm-venv/bin/python` with PyTorch 2.10.0+ps5gfx1013. Do not use the `comfy-rocm-venv/bin/pip` launcher for package changes until it is repaired; it currently targets the CPU venv. A guarded repair script is staged at `scripts/rocm/repair-rocm-pip.sh`; it was syntax-checked but not executed. No packages were installed or changed.
- AMD documents Triton on ROCm, but GFX1013/Oberon is not in the normal public target list; RDNA2 support is partial. Do not simply remove the `(8, 6)` gate: first inspect `torch.cuda.get_device_capability()` on this exact build, then run a minimal Triton correctness test and a Q3_K decode A/B on the PS5.
- ComfyUI's ROCm Triton INT8/FP8 backend has published speedups on gfx1100/gfx1201/gfx1151, but those results do not establish support or speedup on this PS5 GFX1013 device.

## Next high-value work

1. When the ComfyUI queue is idle, verify that restarting ComfyUI no longer restarts the API service. Then repeat one warm Sickrealism API run with Q4 encoder and compare to the warm int8 encoder baseline.
2. The kernel exposes `amdgpu.ps5_cu_unlock`; current value is 0 and 36 CUs are active. The kernel patch includes a non-unlocking probe mode `amdgpu.ps5_cu_unlock=4` and activation mode `=3`. This is a potential ~11.1% theoretical CU increase (36 to 40), but requires a kexec/reboot and must be tested carefully for artifacts/stability. No CU unlock has been applied.
3. CPU boost is currently off (`/sys/devices/system/cpu/cpufreq/boost=0`). The PinkSoup PS5 kernel's boost path can lock clocks at max and is not a safe assumption for sustained AI gains; do not enable blindly.
4. Fan target is 80 C (`/sys/bus/platform/devices/ps5-fan/target_temp`). A lower target could improve sustained thermals but needs a privileged write and will increase fan noise. No fan setting was changed.
5. Do not change the 0.5 GB VRAM reserve or enable experimental precision flags without an A/B benchmark; previous fp16-unet, fp16-vae and fp16-text-encoder tests were slower or unstable.

## Reference links

- Official Krea 2 inference/settings: https://github.com/krea-ai/krea-2
- ComfyUI Krea 2 workflow: https://github.com/Comfy-Org/docs/blob/main/tutorials/image/krea/krea-2.mdx
- ByteShape Krea 2 Turbo GGUF: https://huggingface.co/byteshape/Krea-2-Turbo-GGUF
- Krea 2 Turbo 4-step LoRA settings: https://huggingface.co/lvladikov/Krea2-Turbo-Distill-4step-LoRA
- Krea 2 Turbo 2-step LoRA settings: https://huggingface.co/lvladikov/Krea2-Turbo-Distill-2step-LoRA
- Krea 2 Turbo 3-step LoRA: https://huggingface.co/lvladikov/Krea2-Turbo-Distill-3step-LoRA
- ByteShape Humming compatibility (NVIDIA-only): https://huggingface.co/byteshape/Krea-2-Turbo-Humming
- AMD ROCm 7.1 Triton install notes: https://rocm.docs.amd.com/projects/radeon-ryzen/en/docs-7.1/docs/install/installrad/native_linux/install-pytorch.html
- PS5 kernel patch repository: https://github.com/rmuxnet/ps5-linux-patches-1
