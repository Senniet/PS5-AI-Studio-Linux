# PS5 Oberon / gfx1013 SDMA validation — 2026-11-04

## Firmware

The two installed `cyan_skillfish2_sdma*.bin.zst` files have SHA256 hashes matching the Navi12 SDMA firmware blobs staged for this experiment:

- `cyan_skillfish2_sdma.bin.zst`: `61417eb4adb0010a1d80be386c690a0cc4d1022d8988316668667912292db1bd`
- `cyan_skillfish2_sdma1.bin.zst`: `1b97d9b3a9fd80e17e3af8c1bff625f847b5e945473fa33faa9fe4fbb11b761d`

Original firmware backup: `/var/backups/ps5-sdma-firmware-20261104-173304`.

The AMDGPU module is not in this system's initramfs, so the firmware is read from `/lib/firmware/amdgpu` during normal driver initialization. No initramfs rebuild is needed for this firmware swap.

## Validation

- Explicit HSA copies forced onto SDMA0 and SDMA1 completed with correct data and completion signals.
- The reference 128 MiB PyTorch H2D benchmark was run in alternating SDMA-off/on order. On this PS5, SDMA-on measured about 7.61 GiB/s versus 7.42 GiB/s with SDMA off (about +2.5%). The BC-250 report of +20% is not reproduced on this retail PS5.
- Krea2 512x512 / 8-step warm runs from the earlier direct ComfyUI smoke workflow (not the production API pipeline; the actual API timings are documented separately):
  - SDMA off: 102.691 s, 100.617 s (mean 101.654 s)
  - SDMA on: 101.204 s, 99.521 s (mean 100.363 s)
  - Warm-run difference: about 1.3% faster with SDMA on. The first SDMA-on run (119.749 s) was cold after restarting ComfyUI and is excluded from the warm comparison.
- All Krea2 outputs were non-empty and had normal image statistics.

The earlier pinned-memory `test-sdma.sh` is a transfer sanity test, not an apples-to-apples comparison with the reference benchmark. Its results should not be used to conclude that SDMA is slower.

## Correctness checks

- gfx1013 MIOpen conv2d reproduction: 0/26 incorrect outputs; maximum observed relative error was below `5e-4`.
- Repeated `torch.cuda.empty_cache()` regression: 8/8 cycles passed; relative errors remained below `4e-4`.
- No new GPU page faults were logged.
- Therefore the BC-250-specific conv2d replacement and no-empty-cache workaround were not installed on this PS5.

## Active configuration after tests

- `HSA_ENABLE_SDMA=1` is now retained in `~/.config/systemd/user/ps5-ai-studio-comfyui.service.d/20-rocm-sdma.conf`.
- `GPU_PINNED_MIN_XFER_SIZE=16384` remains set.
- `TORCH_BLAS_PREFER_HIPBLASLT=0` remains set.
- ComfyUI API returned HTTP 200; Ollama and ComfyUI were active after tests.
- GPU governor remains queue-driven: `performance` while ComfyUI has work, `simple_ondemand` when idle.

## Next high-value PS5-specific optimizations

The current PinkSoup kernel supports `amdgpu.ps5_cu_unlock=3`, but the active value is still `0` (36 CUs). The original PS5 can sometimes enable 40 CUs; this is silicon-dependent and may cause artefacts. The CPU boost table is also available (3.3/3.4/3.5 GHz) but currently disabled (`boost=0`, CPU max 3.2 GHz).

A reversible helper was staged at `scripts/rocm/ps5-hardware-tuning.sh`. Run with sudo when ready:

```bash
sudo bash ~/PS5-AI-Studio-Linux/scripts/rocm/ps5-hardware-tuning.sh enable-recommended
```

This installs a persistent CPU-boost service and adds the 40-CU parameter to the loader and kexec command lines, with backups. Reboot is required for the CU unlock. Roll back with:

```bash
sudo bash ~/PS5-AI-Studio-Linux/scripts/rocm/ps5-hardware-tuning.sh disable-recommended
```

The optional 8 GiB GTT ceiling (`ttm.pages_limit=2097152`) is available separately but was not enabled because no speed gain has been demonstrated yet.

## Memory metric clarification

During an active Krea2 job, sysfs GTT free briefly fell to about 0.35 GB while ROCm/HSA reported about 2.77 GB free. After the job completed, both returned to roughly 3.1 GB free. The API rejects overlapping jobs, so the low in-job sysfs reading did not cause a restart between jobs. The API status now uses HSA global free memory as the primary metric, retains the 2.6 GiB guard, and reports PyTorch allocator and sysfs values separately. `torch_vram_free` is allocator-cache headroom, not global free VRAM.

For the actual Krea2 API (Qwen Q4 encoder + Sickrealism v4.0), see `docs/KREA2-OPTIMIZATION-RESULTS-20261104.md` for the measured 2/3/4/8-step comparisons.