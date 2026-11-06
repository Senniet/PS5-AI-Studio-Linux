# Krea 2 / Sickrealism PS5 optimization results — 2026-11-04

## Test setup

- Hardware: PS5 Oberon / gfx1013, PinkSoup kernel 7.3.0, 36 CUs active.
- Runtime: PyTorch 2.10.0+ps5gfx1013 / ROCm 7.1.
- Model: Sickrealism v4.0 safetensors, Qwen3-VL 4B Q4_K_M GGUF encoder, Qwen-Image VAE.
- `PS5UnloadTextEncoder` releases the text encoder after prompt encoding.
- Resolution: 512×512, same fox prompt and seed `20261104` for comparisons.
- GPU governor: `performance` while the ComfyUI queue is active (2.23 GHz), `simple_ondemand` while idle.
- The original 2026-11-04 benchmark profile used `HSA_ENABLE_SDMA=1`; later PS5-specific measurements selected `HSA_ENABLE_SDMA=0`. The active service uses 0 (see the later end-to-end A/B section).

## Measured generation times

| Mode | Wall time | Notes |
|---|---:|---|
| Standard 8 steps, cold | 143.44 s | First actual API generation after model/runtime startup |
| Standard 8 steps, warm | 106.55 s | Same loaded model |
| Standard 4 steps, warm | 54.47 s | Good natural-looking result; best tested speed/quality balance |
| Standard 2 steps, warm | 28.85 s | Fastest raw preview, visibly softer/painterly |
| Turbo 3-step LoRA, warm | 54.46 s | Similar runtime to standard 4; alternate texture/look, experimental on Sickrealism |
| Turbo 2-step LoRA preview, warm | 36.28 s | More coherent/sharp than standard 2-step, but still preview-only |
| Turbo 4-step LoRA, warm | 68.44 s | Slower than standard 4 on Sickrealism; not exposed in UI |

All jobs completed successfully, produced non-empty PNGs, and used the same ComfyUI process (PID 20259); no ComfyUI restart occurred between sequential generations.

## Current UI behavior

The Krea2 panel now exposes:

- Standard mode: use the Steps selector (8, 6, 4, 2).
- Turbo 3-step LoRA: alternative look, approximately the same time as standard 4 steps; experimental on Sickrealism.
- Turbo 2-step LoRA: fast preview; more coherent than standard 2 steps, but not recommended for final images.

The default remains standard 8 steps. The Steps selector is disabled when a Turbo LoRA profile is selected. Turbo LoRAs are disabled when the alternate Q3_K_M GGUF model is selected; this PS5 profile only enables them for the Sickrealism safetensors route.

The 4-step LoRA was downloaded and tested but is not offered because it was slower than standard 4-step sampling on this Sickrealism checkpoint. Its file and license are retained for future testing against the exact Krea2 Turbo base model.

## Memory-policy measurement

During active inference, AMDGPU sysfs GTT free memory fell to roughly 0.35 GB while ROCm/HSA still reported about 2.4–2.8 GB free. After the job completed, both HSA and sysfs returned to about 3.0–3.1 GB free. The low sysfs value occurred during an active job; the API refuses overlapping jobs, so this did not cause a ComfyUI restart between jobs.

The API now reports ROCm/HSA global free memory as the primary GPU-pool metric, keeps the 2.6 GiB safety threshold, and exposes PyTorch allocator free and sysfs GTT free as diagnostics. `torch_vram_free` can be very low because PyTorch has reserved allocator blocks; it is not the same as globally free GPU memory.

## Model files and licensing

The 2-, 3-, and 4-step Turbo LoRAs are installed under the PS5 AI Studio `models/image/loras` path. Their Hugging Face README, NOTICE and LICENSE files are retained under `PS5-AI-Studio-Linux/licenses/`.

These adapters were trained for Krea2 Turbo; the Sickrealism v4.0 results are experimental compatibility tests, not a claim of official support. Use standard 4 or 8 steps for final images unless the Turbo result is visually preferred.

## Next hardware tuning

A reversible helper is staged at `scripts/rocm/ps5-hardware-tuning.sh`. It can enable:

- CPU boost frequencies (up to the exposed 3.5 GHz table; schedutil remains dynamic)
- `amdgpu.ps5_cu_unlock=3` (attempt 40 CUs; silicon-dependent and experimental)
- `ttm.pages_limit=2097152` (8 GiB GTT ceiling; the current 7.05 GiB cap is almost the size of the 7.54 GB checkpoint)

When ready, run with sudo:

```bash
sudo bash ~/PS5-AI-Studio-Linux/scripts/rocm/ps5-hardware-tuning.sh enable-recommended
```

Then reboot once and re-check CU count, GTT size, temperatures and generation times. Roll back with:

```bash
sudo bash ~/PS5-AI-Studio-Linux/scripts/rocm/ps5-hardware-tuning.sh disable-recommended
```

## Follow-up: official Turbo Q3 + DynamicVRAM loader (2026-11-04 evening)

### Loader comparison

The PS5 AI Studio Q3 GGUF route originally used `UnetLoaderGGUF`. The maintained GGUF extension also provides `UnetLoaderGGUFDynamicVRAM`, which wraps the model in ComfyUI's DynamicVRAM/AIMDO path. A separate API test showed:

| Test | Resolution | Steps | Loader | Wall time |
|---|---:|---:|---|---:|
| Turbo Q3, standard | 384x384 | 8 | DynamicVRAM | 50.09 s |
| Turbo Q3, standard | 384x384 | 8 | Legacy/static GGUF | 75.17 s |

These were separate runs with different cache states, so this is indicative rather than a strict cold/cold A/B. DynamicVRAM also used materially less GPU allocator memory in the observed run.

### Integrated PS5 AI Studio tests

The Q3 Turbo route in `apps/server/server.mjs` now uses `UnetLoaderGGUFDynamicVRAM`; the Sickrealism safetensors route remains on the normal `UNETLoader` and was not changed. The status endpoint now verifies that the dynamic GGUF loader exists.

| Test | Resolution | Steps | Profile | Wall time |
|---|---:|---:|---|---:|
| First standard Turbo run after ComfyUI restart | 512x512 | 8 | Q3, DynamicVRAM, no LoRA | ~78 s |
| Same prompt, warm repeat | 512x512 | 8 | Q3, DynamicVRAM, no LoRA | 61.59 s |
| New prompt, warm model | 512x512 | 8 | Q3, DynamicVRAM, no LoRA | 57.79 s |
| Turbo 4-step LoRA | 512x512 | 4 | Q3, DynamicVRAM | 40.45 s |
| Turbo 2-step LoRA preview | 512x512 | 2 | Q3, DynamicVRAM | 42.57 s |
| New prompt from 1.84 GiB free HSA pool | 512x512 | 8 | Q3, DynamicVRAM | ~59 s, successful |

The `execution_cached` messages confirm that the warm repeat reused cached model/encoder/VAE components. The new-prompt test still succeeded without restarting ComfyUI, so prompt encoding can be repeated under the lower Q3 memory guard.

### Q3-specific memory guard

The general Sickrealism minimum free GPU pool remains 2.6 GiB. For the Q3 GGUF + DynamicVRAM route only, the minimum was experimentally reduced to 1.8 GiB; the host-RAM guard remains 4 GiB. A 512x512 / 8-step new-prompt generation started with 1.84 GiB HSA free and completed successfully, with 5.85 GiB host RAM available afterwards. If the HSA pool drops below 1.8 GiB, the API still uses its safe ComfyUI restart path. This is an experimental PS5-specific threshold; monitor for OOM or increased swap before treating it as final.

### Current code/UI changes

- Q3 Turbo API graph uses `UnetLoaderGGUFDynamicVRAM`.
- Krea 2 status checks for the dynamic GGUF loader.
- Q3 Turbo memory threshold: 1.8 GiB; Sickrealism remains 2.6 GiB; host memory minimum remains 4 GiB.
- Krea 2 UI notes now show the measured 512x512 Turbo timings above.
- No kernel parameters, initramfs, ROCm libraries, or ComfyUI startup flags were changed in this follow-up.

## PS5-specific SDMA A/B (2026-11-04 late session)

### Firmware identification

The installed files `/lib/firmware/amdgpu/cyan_skillfish2_sdma.bin.zst` and
`cyan_skillfish2_sdma1.bin.zst` are byte-identical to the local
`navi12_sdma.bin.zst` / `navi12_sdma1.bin.zst` files (SHA256 respectively
`61417eb4adb0010a1d80be386c690a0cc4d1022d8988316668667912292db1bd` and
`1b97d9b3a9fd80e17e3af8c1bff625f847b5e945473fa33faa9fe4fbb11b761d`). Their
uncompressed size is 33,792 bytes and the firmware header reports version
`0x2c`, the Navi12 SDMA firmware. This is not the original Cyan Skillfish
`0x34` firmware. The swap is outside AMD support; the local BC-250 research
notes document why it was made and its known caveats.

### Copy microbenchmark

A 128 MiB pinned-host/device copy test with data checksums and `torch.cuda.synchronize()`
was run in separate processes, alternating SDMA settings. On this PS5 Oberon:

| Setting | H2D median | D2H median | Approx. throughput |
|---|---:|---:|---:|
| `HSA_ENABLE_SDMA=0` | 2.089 ms | 2.173 ms | 59.8 / 57.5 GiB/s |
| `HSA_ENABLE_SDMA=1` | 10.449 ms | 10.448 ms | 12.0 / 12.0 GiB/s |

The checksums matched in every process. This differs from the BC-250 reference
measurements, so do not generalize between the BC-250 board and this PS5.

### End-to-end Krea2 A/B

The same Q3 Turbo DynamicVRAM route was tested at 512x512 / 8 steps, and the
4-step LoRA route at 512x512. The 1-setting results are the earlier HSA=1 runs;
HSA=0 was tested after restarting ComfyUI with the corresponding service
override. These are small-sample timings, but both cold and warm runs favored
SDMA off on this PS5:

| Profile | SDMA on | SDMA off |
|---|---:|---:|
| Standard 8-step, first run | ~78.0 s | 73.44 s |
| Standard 8-step, warm | 57.79–61.59 s | ~50.0 s |
| 4-step Turbo LoRA, warm | 40.45 s | ~36.0 s |

The active service override is now `HSA_ENABLE_SDMA=0`. Restore
`HSA_ENABLE_SDMA=1` by replacing the override content with
`[Service]` / `Environment=HSA_ENABLE_SDMA=1`, then run
`systemctl --user daemon-reload` and restart ComfyUI. The previous 1-setting
file is retained as `20-rocm-sdma.conf.pre-sdma0-test`.

This is a PS5-specific measured choice, not a universal ROCm recommendation.
The HSA=0 blit path uses GPU compute resources, so monitor it under longer
sustained generation and concurrent workloads.

## K-quant acceleration research (2026-11-04 late session)

### ROCm Triton 3.6.0 isolated test — not enabled

Downloaded the official PyTorch `triton_rocm-3.6.0+git8fedd49b-cp314` wheel and installed it only under `/home/michel/triton-rocm-test` (not into the ComfyUI venv). With the PS5 Python 3.14 headers supplied from the local `python-dev-root`, Triton imports and reports `GPUTarget(backend='hip', arch='gfx1013', warp_size=32)`. It compiles an HSACO for gfx1013, but even a minimal constant-fill kernel leaves the output tensor unchanged (all zeros). Pointer-conversion and launch-API experiments did not correct this. **Do not add this test path to ComfyUI's PYTHONPATH and do not enable the bundled K-quant Triton backend on the PS5.** The isolated wheel and test files are retained for future debugging.

The bundled `kquant_triton_backend.py` is also explicitly gated to NVIDIA SM 8.6; it does not currently select gfx1013. A working ROCm kernel and a validated gfx1013 backend would both be required before it could accelerate Q3_K layers.

### INT8 GEMM check

`torch._int_mm` still fails with `HIPBLAS_STATUS_INVALID_VALUE`; hipBLASLt reports the missing
`TensileLibrary_lazy_gfx1013.dat` under its own `hipblaslt/library` path. A separate rocBLAS `TensileLibrary_lazy_gfx1013.dat` exists under `rocblas/library`, but it is a different library format/location and must not be copied into hipBLASLt. FP16 1024x1024 matmul completed at about 1.69 ms in the same quick test. No INT8 or Triton kernel was enabled in the production ComfyUI environment.

## Follow-up: warm Krea 2 Turbo measurements on 2026-11-05

After the Studio/runtime validation work, a controlled Q3 DynamicVRAM + 4-step Turbo-LoRA run used the same 512x512 prompt, seed `20261105`, sampler and scheduler as the saved reference. The prompt text is retained only in local output metadata and is not copied here.

| Run | Resolution | API wall time | ComfyUI time | Notes |
|---|---:|---:|---:|---|
| Cold | 512x512 | not captured | 66.05 s | First run after no Krea model was resident; model initialization took about 14.5 s and sampling about 28.5 s |
| Warm repeat | 512x512 | 30.19 s | 28.32 s | Same prompt, seed, model, LoRA and settings; output completed |
| Warm repeat after switching 2-step and standard 8-step profiles | 512x512 | 36.23 s | 33.21 s | Same prompt, seed, 4-step Turbo profile; output completed |
| Warm smaller resolution | 384x384 | 21.19 s | 20.42 s | Same prompt, seed, model, LoRA, steps, sampler and scheduler; output completed |
| Cold 384x384 after ComfyUI restart | 384x384 | 51.75 s | not captured | Restored 0.5 GiB reserve; new seed; output completed |
| Warm 384x384 repeat after restart | 384x384 | 24.18 s | not captured | Same profile and prompt, new seed; output completed |
| Warm 2-step Turbo | 512x512 | 59.98 s | 43.26 s | Same prompt/seed and Q3 model; completed, but slower than 4-step on this run |
| Warm standard 8-step | 512x512 | 54.59 s | 54.04 s | Same prompt/seed and Q3 model; no Turbo LoRA |

Across the two warm 384x384 runs, API wall time was 21.19–24.18 s (mean 22.69 s), about 32% faster than the two warm 512x512 4-step runs (mean 33.21 s). One cold 384x384 run after ComfyUI restart took 51.75 s. Across the two 512x512 repeats, API wall time ranged from 30.19 to 36.23 s. It produces fewer pixels; visual quality was not scored, so this is recorded as a faster preview/work size rather than a quality-equivalent replacement. The 2-step Turbo run took about twice as long as warm 4-step at 512x512, despite halving the step count; on this profile it is not a speed preset and should be used only when its appearance is preferred. Standard 8-step at 512x512 completed in 54.59 s API / 54.04 s ComfyUI, about 1.8x the 4-step Turbo wall time in these single-run comparisons. Current CPU governor is `schedutil`, CPU boost is off, and the available scaling maximum is 3.2 GHz. A reversible CPU-boost A/B was not possible in the non-interactive SSH session because `sudo` requires a terminal; no power setting was changed.

Both runtimes remain active, Krea reports ready on ROCm/HIP gfx1013, the Comfy queue is empty, and Studio reports no active tasks after the measurements. CPU boost remains at its original value (`0`).

### Measured quick-preview preset

Added a non-default Krea panel button that selects the Q3 Turbo checkpoint, 384x384 and the 4-step Turbo LoRA together. Its warm runtime measured 21.19 s through Studio / 20.42 s in ComfyUI on this PS5. Selecting a Turbo profile now also synchronizes the disabled step selector to the actual Turbo step count and restores the user's prior standard-step value when Turbo is turned off. The default model and generation settings remain unchanged.


After the last profile-switching rerun, HSA reported 2.18 GiB globally free, the host had 6.08 GiB available, and swap had 5.71 GiB free; Studio still had zero active tasks and ComfyUI queues were empty. The ComfyUI model remained staged. The sidecar showed a 1.35 GB host-offload string, but code review later found this value was hard-coded and not measured for this run; do not treat it as live telemetry. No memory-policy or boot setting was changed. This makes the proposed 8 GiB TTM/kernel change a separate reboot-gated experiment; it was not applied.

An immediate identical 512x512 / seed `20261105` / 4-step Turbo request afterward returned in 3.17 s API and 0.00 s ComfyUI. ComfyUI logged the prompt as executed in 0.00 s, and its PNG SHA256 exactly matched the preceding output, so this was a graph/output cache hit rather than another inference run. It is excluded from the timing table and documents that exact repeated requests can reuse cached output.


## Follow-up: reserve-vram A/B and telemetry correction (2026-11-05)

- Backed up the user service and SDMA drop-in to `docs/benchmarks/krea2-reserve-20261105T142142Z-before-025/`, temporarily overrode `--reserve-vram 0.5` with `0.25`, restarted ComfyUI, and tested 512x512 Q3 4-step with two different seeds.
- At 0.25 GiB reserve: cold 512 run 57.69 s API / 56.47 s ComfyUI; warm run 30.42 s API / 29.87 s ComfyUI. Warm time was effectively unchanged from the 0.5 GiB runs. After the warm run HSA free fell to 1.65 GiB, below the existing 1.8 GiB Q3 guard; host available was 4.70 GiB. The setting was rejected.
- Removed the temporary override and restarted ComfyUI on the original 0.5 GiB reserve. It is now active at that setting; immediately after restart HSA free was 7.05 GiB and host available 12.66 GiB. No persistent service, kernel, or boot setting was changed.
- A code audit found `model_offload` in Krea sidecars was hard-coded to “1347.84 MB” for Q3 outputs. Changed new sidecars to `model_offload: null`; old output metadata was left untouched. A real 384x384 PS5 job after the Studio restart completed in 51.75 s API and produced a sidecar with `model_offload: null`; the warm same-profile run completed in 24.18 s and also has null telemetry.
- The 0.5 GiB baseline’s 384x384 warm runs were 21.19 and 24.18 s; cold after restart 51.75 s. After the second warm job HSA free was 1.40 GiB, below the guard, so ComfyUI was restarted once more to clear staged model memory. Final state is ready and idle.

## Memory-guard and restart-path review (2026-11-05)

The Q3 preflight requires at least 4 GiB host RAM and 1.8 GiB global HSA free. Below the GPU threshold it checks the queue and asks ComfyUI `/free` to unload models and reset execution caches. It waits for HSA memory to recover, then verifies the queue again. Only if `/free` fails to recover the threshold does it recheck the queue and use the systemd restart fallback; it then refreshes Krea memory status and returns 503 if the threshold is still not met. Since external ComfyUI workflows can start during earlier model validation, the route now checks the queue a second time immediately before an automatic memory restart. Queue status must include valid running and pending arrays; malformed status fails closed. The Comfy job fixture now covers busy, empty and malformed states (23 assertions total).

The second check narrows the race window, but an external Comfy workflow could still be enqueued between that final check and the systemd restart. No listener or network exposure was changed. Live state after the patch: Studio and ComfyUI active, Krea ROCm profile ready, HSA free 7.05 GiB, zero Studio active tasks and empty Comfy queue.

The one-click fast-preview control was also exercised with a DOM-state harness: it selects Q3 GGUF, 384x384, and 4-step Turbo together, updates the disabled step selector, and emits the success notice. `npm run check`, live static/API checks, the 23-assertion Comfy fixture, and `git diff --check` pass.


## Non-restarting HSA recovery validation (2026-11-05)

- A direct idle `/free` probe unloaded ComfyUI models and reset its executor: HSA free rose from 2.18 to 6.72 GiB in about one second, while ComfyUI PID 41972 remained unchanged.
- Tested Studio’s integrated recovery from an actual low-memory state: before the third Q3 384x384 request, HSA free was 1.40 GiB (<1.8 guard), host available 4.24 GiB (>=4 guard), and the queue was empty. Studio accepted the request in 0.66 s; `/free` restored enough headroom and the request completed in 46.08 s. ComfyUI PID remained 41972; HSA afterward was 2.18 GiB, host available 4.98 GiB.
- This avoids a service restart but still incurs a cold model load for the following image. The restart path remains as fallback. New output metadata had `model_offload: null`.

## 2026-11-05 — gfx1013 async offload and fp16 accumulation A/B

- Confirmed ComfyUI already enables async weight offload by default on the PS5's HIP/AMD path: startup reports `Using async weight offloading with 2 streams`. No change was needed.
- Backed up the effective user service and existing drop-ins under `docs/benchmarks/krea2-fast-fp16accum-20261105T155500Z-before/`.
- Tested the optional `--fast fp16_accumulation` flag on the actual PS5 using Studio's guarded Krea2 Q3 Turbo route at 384x384, 4-step Turbo. Default warm baseline: 21.36 s API / 20.42 s ComfyUI. Temporary-flag cold run: 55.53 s API / 54.46 s ComfyUI; warm run: 20.48 s API / 19.95 s ComfyUI. The warm difference was 0.47 s (about 2.3%) in a single sample, too small to establish a real gain; prompt and seed differed from the earlier baseline. Cold time includes model initialization and was not compared as a steady-state result.
- Rejected the flag as inconclusive. Removed the temporary drop-in, restarted ComfyUI, and verified the live ExecStart no longer contains the flag and `--reserve-vram 0.5` is restored. Current default AMD async offload remains 2 streams.
- After the warm treatment run HSA free was 1.40 GiB, below the 1.8 GiB Q3 guard; Studio had no active jobs and the Comfy queue was empty. No further run was forced below the guard. The previous model cache was cleared by the restore restart; no kernel, boot, listener, or memory-guard setting changed.

## 2026-11-05 — CPU profile and disk-backed staging A/B

- Read-only CPU profile of two guarded Q3 Turbo 384x384/4-step runs under the default service: cold 49.03 s API with 44.15 CPU-seconds (0.90 average logical core); warm 20.48 s API with 21.14 CPU-seconds (1.03 average logical core). PyTorch reports 16 intra-op / 16 inter-op threads on 16 logical CPUs. CPU scheduling does not appear to saturate the machine during this workload, so no OMP thread limit was applied.
- ComfyUI's installed source shows `--force-non-blocking` only overrides the normal backend decision. On the active HIP device, `device_supports_non_blocking(cuda:0)` already returns true; adding the flag would not change the Krea Q3 transfer path, so it was not tested as a mutation.
- Backed up the service and current SDMA drop-in at `docs/benchmarks/krea2-fast-disk-20261105T161000Z-before/`. Tested `--fast-disk` on the real Q3 GGUF route using the same prompt, resolution, step count and Turbo LoRA. Two cold API times were 46.63 and 47.71 s (mean 47.17 s); warm was 20.64 s. The same-prompt default control after restoration was 47.50 s cold / 20.40 s warm; preceding same-prompt default samples were 49.03/20.48 s. ComfyUI warm execution was 20.08 s with fast-disk versus 19.88 s on the restored default control. The apparent ~2.3% average cold difference is small; warm was slightly slower, and free HSA/host memory was effectively unchanged (1.40/4.39 GiB with flag; 1.40/4.38 GiB default after warm).
- Rejected `--fast-disk` as not demonstrably beneficial for Krea generation or memory. Removed the temporary drop-in and restarted; active ExecStart is back to the original flags and 0.5 GiB VRAM reserve. Service is active and Krea-ready, Studio tasks=0 and Comfy queue empty. HSA free is 1.40 GiB (<1.8 GiB Q3 guard), so the next Studio generation will use the supported recovery path before enqueueing.

Next: inspect the Krea GGUF dynamic staging and cache lifecycle for a change that avoids repeated model cold loads without violating the existing HSA guard. Keep 0.5 GiB reserve and 1.8 GiB guard; CPU boost remains unchanged because sudo is non-interactive.

## 2026-11-05 — try VRAM release without resetting executor cache

- Backed up ComfyUI `server.py` to `docs/benchmarks/krea2-free-cache-without-unload-20261105T162500Z-before/server.py` and temporarily changed `/free` to honor an explicit `unload_models:false` value. This allowed `{unload_models:false,free_memory:true}` to reclaim VRAM without calling `unload_all_models()`.
- On the live PS5, with Q3 HSA at 1.40 GiB and the queue idle, the variant raised HSA free to 6.72 GiB in 1.02 s. The next guarded Krea request still took 45.62 s API / 44.51 s ComfyUI (cold), so retaining model objects this way did not preserve a warm execution path.
- Reverted the ComfyUI endpoint source to the backup, passed `py_compile`, restarted ComfyUI, and confirmed Studio/Krea ready with HSA 7.05 GiB and zero active tasks/queue items. No modified ComfyUI endpoint code remains.
- The experiment did not improve repeated generation speed and the endpoint change was removed. Next investigate whether unloading models while preserving ComfyUI's executor/node cache can avoid architecture/model reconstruction without leaving VRAM allocated.

## 2026-11-05 — cache-preserving low-HSA recovery integrated

- Replaced the first low-memory recovery attempt in Studio with ComfyUI `/free` `{unload_models:true,free_memory:false}`. This unloads GPU residency but preserves the PromptExecutor/node cache. The route waits for HSA to reach the existing Q3 threshold (1.8 GiB), rechecks the queue before any full-reset fallback, then retains the existing `{unload_models:true,free_memory:true}` and systemd-restart fallbacks. The 4 GiB host guard, 1.8 GiB Q3 guard and 0.5 GiB Comfy reserve are unchanged.
- Confirmed with two real PS5 cycles from HSA 1.40 GiB: route recovery generations completed in 28.12 s API / 26.55 s Comfy and 25.75 s API / 24.22 s Comfy, compared with 45.62 s API / 44.51 s Comfy after full executor reset. Each saved about 18–20 s; Comfy PID stayed unchanged. Following warm generations were 20.25 s API / 19.51 s Comfy. A separate manual unload-only probe recovered HSA to 6.31 GiB and produced a 25.49 s API / 24.94 s Comfy follow-up.
- The no-unload alternative `{unload_models:false,free_memory:true}` was rejected: it recovered HSA 1.40→6.72 GiB in 1.02 s, but next generation stayed cold at 45.62/44.51 s. Its temporary ComfyUI source patch was restored from `docs/benchmarks/krea2-free-cache-without-unload-20261105T162500Z-before/server.py`.
- Backed up Studio source and lifecycle fixture before the retained route change at `docs/benchmarks/krea2-cache-preserving-memory-recovery-20261105T164000Z-before/`.
- Verification: `npm run check`; runtime selection 28 assertions; Comfy jobs/cancel/tasks 23; safe file ops 7; download validation 19; download record validation 7; GGUF loadability 12; GGUF validation cache 7; upload stream guard 3; GGUF structure 3 (run with the Comfy ROCm Python venv); targeted `git diff --check`; live Krea generation and idle health checks all passed.
- Final service state: Studio and ComfyUI active; Krea ready on HIP/gfx1013; Studio active tasks=0; queue empty; HSA free 2.18 GiB, host available 5.94 GiB. No temporary fast-disk, fp16-accumulation or Comfy endpoint patch remains.

## 2026-11-05 — attention backend compatibility check

- Active standard backend on gfx1013 was confirmed as ComfyUI sub-quadratic attention. A real `--use-split-cross-attention` A/B completed the Comfy graph but Studio rejected the 509-byte 384x384 PNG. Pillow verified it was a uniform black image (all RGB extrema 0, stddev 0). Rejected the candidate, removed its temporary service drop-in, restored sub-quadratic attention, and restarted ComfyUI.
- Standard-attention control generation then completed through Studio in 47.83 s and produced a valid 384x384 PNG (184,995 bytes; channel stddev 62.75/63.94/67.06). No split-attention flag remains.
- Runtime probes show `comfy_kitchen.int8_attention_is_available(gfx1013)=False` and `sol_attn_is_available(gfx1013)=False`; the installed Q3 GGUF has no attention/custom metadata keys. Do not try `--use-ck-attention` or force `sol_attn` on this runtime.
- `GPU_PINNED_MIN_XFER_SIZE=16384` is configured in the service and ROCm setup docs, but no source consumer was found in the active Comfy/AIMDO/PyTorch source or the inspected shared-library strings. No A/B was run and the value was left unchanged pending identification of its consumer.

## 2026-11-05 — cache-preserving recovery verification status

The cache-preserving first recovery phase remains active with full-reset and systemd restart fallbacks. After the low-memory A/B, the next warm jobs stayed near 20 s; the repeated low-memory cycle again completed in 25.75 s API / 24.22 s Comfy. Keep HSA minimum 1.8 GiB and reserve 0.5 GiB.

## 2026-11-05 — 512x512 Q3 guard coverage

- Standard sub-quadratic attention, Q3 Turbo4, 512x512 through the Studio route completed in 31.60 s API; output was a valid 300,836-byte PNG. HSA fell from 2.18 to 1.90 GiB, still above the 1.8 GiB threshold. No second 512 job was queued at this narrow margin.

## 2026-11-05 — pinned-memory audit and async-offload stream A/B

- Confirmed the PS5 ROCm device reports `is_integrated=1`; importing the active ComfyUI runtime reports `DISABLE_PINNED_MEMORY=True`, `MAX_PINNED_MEMORY=-1`, and zero pinned bytes. ComfyUI therefore does not pin host tensors on this shared-memory GPU. `GPU_PINNED_MIN_XFER_SIZE=16384` has no consumer in active Comfy/AIMDO/PyTorch source or inspected binary strings and cannot tune this disabled path. Kept the environment value unchanged.
- Tested the supported `--async-offload 3` option against the default two streams using the same 384x384 Q3 Turbo4 prompt, resolution and workflow; distinct seeds avoided identical-output cache hits. 2-stream warm samples: 21.10 s and 25.94 s (mean 23.52 s). 3-stream warm samples: 21.12 s and 27.45 s (mean 24.29 s, 3.3% slower). The first generation after restart was 46.13 s at 2 streams and 49.66 s at 3 streams; treat cold timing as noisy, but it showed no gain. Every output was a valid 384x384 PNG.
- Rejected 3 streams due to no repeatable warm benefit and higher observed variance. Removed the temporary `90-async-offload-test.conf`; restored the original service command and verified Comfy startup reports `Using async weight offloading with 2 streams`. Backup of original unit/drop-in: `docs/benchmarks/krea2-async-offload-3-stream-20261105T1627Z-before/`.
- Final live state: Studio and ComfyUI active; Krea ready on gfx1013; Studio tasks=0; Comfy queue empty; HSA free 2.18 GiB, host available 5.44 GiB; reserve remains 0.5 GiB and Q3 guard 1.8 GiB. No 3-stream test drop-in remains.

Next: audit the DynamicVRAM weight-staging and GGUF loader cache lifecycle for a warm-path improvement that does not hold more HSA memory resident.

## 2026-11-05 — hipBLASLt gfx1013 check and warm loader cache audit

- The service keeps `TORCH_BLAS_PREFER_HIPBLASLT=0`. The installed hipBLASLt library directory has no `TensileLibrary_lazy_gfx1013.dat`. A separate Python 3.14 ROCm process with the preference set to `1` emitted PyTorch's warning “Attempting to use hipBLASLt on an unsupported architecture! Overriding blas backend to hipblas”; its 512x512 FP16 matmul still completed correctly via fallback. No Studio setting changed and no full generation was spent on a backend that PyTorch disables itself.
- PyTorch's `Context.h` reads this variable as a preferred BLAS backend selector (source: https://github.com/pytorch/pytorch/blob/main/aten/src/ATen/Context.h), but gfx1013's runtime override makes it ineffective for the active PS5 build. Keep the value at 0.
- Loader inspection: ComfyUI-GGUF attaches mmap-backed `TensorFileSlice` metadata to dynamic GGUF tensor storage and sets `cached_patcher_init` on the dynamic patcher. The Studio graph's Qwen encoder is explicitly unloaded after encoding to protect HSA headroom. Logs from the latest controlled 2-stream run show one Qwen encoder load on the first job and none on warm repeats; Krea2/VAE still receive load requests. Warm Comfy times were 20.50 and 24.94 s (API 21.10 and 25.94 s), so further safe speed work should target inference/staging behavior rather than CPU thread limits or repeated text-encoder construction.
- The task dashboard contains an older Krea error created at 2026-11-05 15:36:42Z for a separate prompt; it predates these benchmarks. All six outputs generated in the current A/B passed Pillow PNG verification at 384x384. No tasks are active; the error record was preserved.
- Next: inspect the model patcher/DynamicVRAM transition at Krea2 and VAE boundaries for avoidable work; do not increase text-encoder/GPU residency unless it remains above the existing 1.8 GiB HSA floor.

## 2026-11-05 — 256x256 Q3 Turbo concept-preview shortcut

- Controlled same-prompt Q3 Turbo4 comparison through Studio: 384x384 warm API runs 23.52/24.88 s (mean 24.20); 256x256 warm runs 17.43/16.38 s (mean 16.91), about 30% less warm wall time. First 256x256 run after switching resolution took 27.00 s while dynamic staging/cache adjusted. Seeds differed to prevent an identical-output cache hit. All six latest images passed Pillow verification; 256 outputs were valid 108–113 KB PNGs.
- Added a separate one-click `Snelle concept-preview · Q3 Turbo · 256×256` button to the Krea panel. It selects the Q3 model, 256 square output and 4-step Turbo; the existing 384x384 preview and standard settings remain unchanged. UI help text reports the measured warm times and says 256 quality has not been scored.
- Verification: `node --check apps/web/app.js`; static wiring assertions confirmed the DOM id, event handler, 256 resolution and Turbo4; live Studio `/` and `/app.js` responses contained the new UI copy. No service restart was needed.
- Backup: `docs/benchmarks/krea2-256-draft-preset-20261105T1658Z-before/`; measurement-copy snapshot `docs/benchmarks/krea2-256-preview-measurements-20261105T1659Z-before/`.
- Final resource state after these runs: Krea ready, active tasks=0, Comfy queue empty, host available 6.19 GiB, HSA free 1.40 GiB (<1.8 GiB Q3 threshold). The next guarded Q3 request will first use the retained cache-preserving recovery; no further inference was queued at this margin.

## 2026-11-05 — Krea2 Studio UI refresh

- Reworked the Krea panel into a generation-first layout: runtime header, three live memory cards, collapsible technical/model details, separate prompt/settings blocks, measured 256/384 quick starts, persistent job status, result preview/download actions, and collapsed docs links. Existing Krea control IDs and generation workflow remain wired. Layout stacks cleanly at narrow widths.
- Live review on the PS5 Studio at 858×574 confirmed the updated panel and controls; both quick-start buttons remain present. Applied the 256×256 preset and verified it selects the Q3 model, concept resolution, and Turbo4 without starting a job.
- Improved low-memory truthfulness: at the current 1.4 GiB HSA free (<1.8 GiB Q3 threshold), the header now says “Klaar · GPU-herstel bij start” and the GPU metric gets warning styling. Backend cache-preserving memory recovery remains responsible for reclaiming headroom before Q3 work. Host available 6.1 GiB; reserve 0.5 GiB. No inference was queued.
- Verification: `node --check apps/web/app.js`; stdlib HTML parse found unique IDs and all expected controls; live HTTP checks verified the updated HTML/CSS/JS are served. Browser AX tree confirmed the warning label and all generation controls.
- Backup before the UI refresh: `docs/benchmarks/krea2-ui-refresh-20261105T1709Z-before/`. No service restart was needed. Historic 2 task errors remain from earlier Civitai/Krea tasks; active tasks and Comfy queue are 0.

Next: continue Krea2 performance investigations within the 1.8 GiB HSA guard; score 256px image quality before recommending that preset beyond concept work.

## 2026-11-05 — Krea2 usability pass

- Made quick-start actions explicit: both preset cards expose their pressed/selected state to assistive technology and get a persistent selected treatment after use. A live status sentence tells the user which Q3 Turbo settings were filled, reminds them to review settings, and says generation starts only after pressing the primary button. Manual edits clear the selected preset and explain that custom settings are active.
- Tightened the action wording: cards now say they prefill settings; toast copy no longer implies that a generation was started. The primary “Genereer afbeelding” action remains at the end of the prompt/settings/preset flow, beside the current job status. Result actions stay directly below the preview. Added visible keyboard focus treatment to preset cards.
- Live browser verification: clicking the 256 concept preset selected Q3 Turbo, 256x256 and Turbo4; its pressed state became true and the persistent message described the configuration. No inference was started. The updated live page loaded without a service restart.
- Verification: `node --check apps/web/app.js`; `git diff --check`; live UI accessibility tree confirmed both presets, `aria-pressed`, status copy and generation button. Backup: `docs/benchmarks/krea2-usability-pass-20261105T1815Z-before/`.

Next: continue the Krea2 optimization roadmap; keep documenting the 256px quality caveat and memory recovery status in the interface.


## 2026-11-05 — stale Krea 2 generation indicator corrected

- User reported repeated “Krea 2 generation already running” while no image/task was visible. `/api/tasks` showed a tracked Krea job in `running`, but ComfyUI `/queue` had no running or pending entries. Refreshing its job history showed it had actually completed; the completed image (`1793910159334-krea2-046bab38.png`, 385,168 bytes) was imported into the Studio image gallery. The task list then reported active=0.
- Root cause: Studio retained the in-memory job state unless the browser continued polling that exact job ID. After a page interruption/reload, the duplicate-generation guard trusted the stale `running` state.
- Fix: added a deduplicated `refreshTrackedKreaJobs()` reconciler. `/api/tasks` refreshes active tracked Krea jobs against ComfyUI history/queue before showing them, and the generation route refreshes them before rejecting a new request. A truly running job remains protected; completed, failed, or disappeared jobs no longer block forever, and completed outputs are imported through the existing status path.
- Regressions: Comfy lifecycle/task assertions 25, prompt optimizer 107, prompt flow 57; `npm run check`, all Node fixture scripts, and `git diff --check` passed. Studio service restarted and is active; `/api/tasks` now reports no active Krea job; completed image is present in gallery.


## Follow-up: expanded GTT pool and current Krea 2 profile tests (2026-11-06)

The PS5 now boots with `ttm.pages_limit=4063232` (15.5 GiB allocator limit). ComfyUI 0.43.0 / PyTorch 2.10.0+ps5gfx1013 reports 15,872 MB total VRAM and the ROCm/HIP gfx1013 backend is active. The ComfyUI user service uses DynamicVRAM, FP8 Qwen text encoding, FP16 intermediates and a 0.5 GiB reserve. No text model was running during these image tests.

### SickRealism safetensors

- Model: `krea2Sickrealism_v40_3292927.safetensors`; Qwen3-VL Q4_K_M GGUF encoder; Qwen Image VAE.
- 512×512, 8 standard steps, ER SDE / Beta, CFG 1, seed `20261106`.
- Completed successfully in about 155 seconds cold, including model/encoder loading.
- Peak observed GTT use was about 9.0 GiB; system memory availability fell to about 2.5 GiB and swap use peaked around 2.4 GiB. It completed without OOM; memory recovered after completion.
- This remains the style-specific SickRealism profile; 8 standard steps are the preferred quality setting for this checkpoint.

### Krea 2 Turbo Q3 GGUF

- Model: `Krea-2-Turbo-Q3_K_M-3.91bpw.gguf`; official 4-step Turbo LoRA; Qwen3-VL Q4_K_M GGUF encoder; Qwen Image VAE.
- 512×512, 4-step Turbo, seed `20261106`: completed in about 65 seconds cold.
- 768×768, 4-step Turbo, seed `20261106`: completed in about 85 seconds cold.
- 768×768, 4-step Turbo warm repeat, seed `20261107`: completed in about 55 seconds.
- The 768×768 image was visually checked; it retained coherent automotive details, lighting and scene structure. Peak host `MemAvailable` was about 2.0 GiB and swap use stayed below 0.7 GiB. No OOM or queue failure occurred.
- Recommended Q3 Turbo detail preset: 768×768, 4-step Turbo LoRA. Faster preview remains 384×384, 4-step Turbo.

### Runtime observations and limits

- The larger TTM pool is visible to ComfyUI and allows the GPU memory pool to grow beyond the previous 7.05 GiB cap. It does not add physical RAM: GPU staging, CPU allocations and Linux still share the same unified memory.
- DynamicVRAM staged about 5.36 GiB of Q3 DiT weights and preloaded about 418 MiB of Turbo LoRA factors for the 768×768 run.
- The Q4 GGUF text encoder logs a missing `mmproj` warning and missing `visual.*` tensors. These are for image-input/Qwen-Image-Edit functionality; the text-only Krea 2 prompt-encoding path completed successfully. Do not treat this as a failed Krea text-encoding test.
- The Krea status API now exposes model-specific tested/recommended profiles. The Image Studio quick starts include a Q3 Turbo 768×768 detail profile in addition to the existing 256/384 previews.
