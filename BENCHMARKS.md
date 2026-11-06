# PS5 AI Studio benchmarks

## Image generation sample — 2026-11-05

Tests used the Studio API route on the PS5 host, a fixed prompt and seed, and 384×384 output. The ComfyUI queue was checked empty before each run. The first two runs were sequential warm-path tests. Measurements are one run each; they are a current reference, not statistical performance claims.

Prompt: `A red fox in a quiet snowy forest at dawn, natural cinematic light, detailed fur, 35mm photograph.`  
Negative prompt: empty. Seed: `20261105`. CFG: 1.0.

| Model / profile | Steps and adapter | ComfyUI execution | Studio API wall time | Output |
|---|---|---:|---:|---|
| Krea2 Turbo Q3 GGUF | 8 steps, no LoRA | 59.10 s | 60.30 s | 217,805 bytes, saved |
| Krea2 Turbo Q3 GGUF | official 4-step Turbo LoRA | 32.71 s | 34.21 s | 223,351 bytes, saved |
| Krea2 SickRealism safetensors | 8 steps, no LoRA | 112.38 s | Not captured: Termalin request timed out while waiting | 229,005 bytes, saved |
| Krea2 SickRealism safetensors | 3-step Turbo + HMNSFW AIO at 0.8 | 35.21 s | 36.30 s | 104,973 bytes, saved |

Settings and memory samples:

- Q3 8-step: 384×384, Euler / simple, no custom or Turbo LoRA. Available RAM 8.23 → 7.08 GiB; graphics-pool free 3.90 → 2.30 GiB. Swap-free decreased by about 48 MiB.
- Q3 4-step: same prompt, seed and dimensions; Euler / simple; adapter `krea2_turbo_4step_rank_64_lora_comfyui.safetensors`. Available RAM 7.10 → 6.58 GiB; graphics-pool free 2.30 → 2.24 GiB. Swap-free decreased by about 45 MiB.
- SickRealism 8-step: 384×384, ER SDE / beta, same prompt and seed, no LoRA. ComfyUI logged 112.38 s and saved the image. The external Termalin command timed out before returning the API job response, so no API wall time or before-sample is claimed.
- SickRealism LoRA chain: 256×256, Euler / simple, same prompt and seed. Custom `Krea2_HMNSFW_AIO.safetensors` at 0.8 was applied before `krea2_turbo_3step_rank_64_lora_comfyui.safetensors`. Available RAM before run was 7.28 GiB; graphics-pool free was 2.84 GiB.

The Q3 4-step run's API wall time was 43.3% below the 8-step run in this sequential sample. Image quality was not evaluated; the step profiles differ, so this is not a quality-equivalent speedup. The SickRealism chain result is a successful integration test, not a quality comparison.

## Text Studio CPU sample — 2026-11-05

Model: Qwen2.5-VL 3B Q4_K_M, context 2048, six CPU threads, zero GPU layers. Same text prompt was run with the vision projector enabled and disabled. The model was unloaded after each run and the SickRealism selection was restored. llama.cpp's per-request timing logs were used for token rates.

Prompt: `Write a short, clear paragraph explaining why a fixed random seed helps compare two image-generation settings. Use about 80 words.`

| Vision projector | Load wall | Available RAM after load | First text | Studio chat wall | Prompt eval | Output eval |
|---|---:|---:|---:|---:|---:|---:|
| `none` | 4.15 s | 5.24 GiB | 0.214 s | 4.96 s | 221.81 tok/s (45 tokens) | 21.51 tok/s (103 tokens) |
| auto, run 1 | ~8.4 s from llama log | 3.84 GiB | 35.712 s | 39.68 s | 1.26 tok/s (45 tokens) | 21.19 tok/s (85 tokens) |
| explicit projector, repeat | 5.89 s | 3.94 GiB | 42.778 s | 47.06 s | 1.05 tok/s (45 tokens) | 21.16 tok/s (92 tokens) |

The no-projector run used 630 output characters. Projector runs produced 484 and 572 characters. Output length and prompt prefill speed varied, so compare these as small observations, not a stable causal estimate. Both projector runs showed very slow text prompt evaluation while generation speed stayed near 21 tok/s; no-projector prompt evaluation was much faster in its one sample. The UI already offers `Geen mmproj` for models with a vision projector. For text-only work, select it to avoid loading the 1.34 GB projector; retain the projector when sending images.

During projector runs, available RAM after model load was about 3.8–3.9 GiB and swap-free decreased by 180–240 MiB. The no-projector run had 5.24 GiB available after load and essentially no additional swap use during its short chat. After unload, available RAM recovered to around 7 GiB.

This test was CPU-only and used a vision model even when its projector was disabled. Repeat with at least three runs per mode, controlled cache state, and a genuinely text-only GGUF before changing defaults. The Studio already has an explicit projector selector, so no code change was needed.

## Saved image outputs

Studio gallery images and JSON sidecars were saved:

- `/home/michel/.local/share/ps5-ai-studio/outputs/images/1793834076220-krea2-49fc247b.png`
- `/home/michel/.local/share/ps5-ai-studio/outputs/images/1793834143529-krea2-38effb9f.png`
- `/home/michel/.local/share/ps5-ai-studio/outputs/images/1793834316043-krea2-33024d75.png`
- `/home/michel/.local/share/ps5-ai-studio/outputs/images/1793835770426-krea2-284007cd.png`

The sidecars record model, seed, prompt, dimensions and adapter settings.

## Historical results

See `KREA2-PS5-STATUS.md` and `docs/KREA2-OPTIMIZATION-RESULTS-20261104.md` for earlier PS5 runs, including 512×512 Q3, SickRealism, SDMA A/B and DynamicVRAM/static loader comparisons. Those runs used different dates, cache states and sometimes different sampling parameters; do not merge them into the current sample as a single controlled series.

## Repeat image-generation sample — 2026-11-05

Follow-up samples used the same 384×384 prompt and settings as above, with unique seeds to avoid ComfyUI graph-cache hits. API wall time is reported. The first two runs with seed 20261105 were excluded from repeat statistics because identical repeated requests returned in ~2.2 s from cache. A run was treated as a real sample only when it completed, saved an output, and took more than 12 s.

| Profile | Seed | API wall | ComfyUI PID before → after | Output |
|---|---:|---:|---|---|
| Q3, 8 steps, no LoRA | 20261106 | 40.25 s | not recorded | `1793836524832-krea2-a1101f3b.png` (217,684 bytes) |
| Q3, 8 steps, no LoRA | 20261107 | 34.21 s | not recorded | `1793836559421-krea2-a02272f8.png` (216,131 bytes) |
| Q3, 8 steps, no LoRA | 20261108 | 78.80 s | 30959 → 14431 | `1793836761980-krea2-3e3cc280.png` (215,767 bytes) |
| Q3, 4 steps, Turbo LoRA | 20261106 | 26.24 s | 14431 → 14431 | `1793836788602-krea2-ee4ecad6.png` (219,322 bytes) |
| Q3, 4 steps, Turbo LoRA | 20261107 | 22.22 s | 14431 → 14431 | `1793836811195-krea2-f722b1a3.png` (222,759 bytes) |
| Q3, 4 steps, Turbo LoRA | 20261108 | 67.81 s | 14431 → 14829 | `1793836879369-krea2-f434cbc4.png` (222,608 bytes) |

The 78.80 s and 67.81 s runs crossed the 1.8 GiB free graphics-pool guard and caused the Studio API to restart the idle ComfyUI service before continuing. Both completed with empty queues and saved outputs. Their times include recovery/cold-start overhead and should not be mixed with uninterrupted warm-path timings. Graphics-pool free before/after the first guarded run was 1.34 → 2.28 GiB; for the last it was 1.24 → 2.18 GiB. The 20261107 Q3 run reached 1.34 GiB free after generation; the guarded restart occurred on the next request.

Among the three unique-seed runs, the median API wall was 40.25 s for 8-step Q3 and 26.24 s for 4-step Turbo LoRA. Each profile has only three observations and includes one restart/cold sample, so these are descriptive only. Queue was empty before and after each completed follow-up sample. RAM and swap varied during the batch; no quality comparison was performed.

## Isolated custom-adapter sample — 2026-11-05

To isolate the custom adapter from the Turbo LoRA, SickRealism was run at 256×256, 3 steps, with `Krea2_HMNSFW_AIO.safetensors` at 0.8 and `turboSteps=0`. The prompt matched the earlier SickRealism integration sample; the unique seed was 20261109.

| Profile | API wall | ComfyUI PID before → after | Graphics-pool free before → after | Output |
|---|---:|---|---:|---|
| SickRealism + HMNSFW AIO only | 87.09 s | 14829 → 15805 | 2.18 → 2.93 GiB | `1793837137707-krea2-9985e5b2.png` (107,115 bytes) |

Free graphics-pool memory was below the SickRealism guard before the request, so the API restarted idle ComfyUI before running. The time includes that cold-start/recovery overhead. The run completed, the gallery output exists, and the ComfyUI queue was empty afterward. The earlier 36.30 s SickRealism run included the 3-step Turbo LoRA as well as this custom adapter; timings are not directly comparable because startup/cache state differed. This single sample validates applying the custom adapter without Turbo; it does not establish a quality or performance benefit.

## Next benchmark work

- Repeat each image profile at least three times after a settled idle state, keeping cold-load and warm timings separate.
- Run the HMNSFW adapter by itself and verify further Krea2 LoRAs, including the installed LoKr, in a controlled comparison.
- Run Q3 at 512×512 and a second resolution only after recording pre-run GTT/RAM/swap and ensuring each model's memory guard passes without unexpected restarts.
- Cache-disabled Text Studio projector comparison and a bounded CPU-only Ollama text-only smoke are complete; see sections above. Next compare the Studio chat route with Ollama only after auditing whether this path is supported and how errors are surfaced.
- Evaluate output quality separately; generation time alone is not a quality result.


## Text Studio repeat check — 2026-11-05

Controlled API check using Qwen2.5-VL 3B Q4_K_M, 2048 context, six CPU threads, zero GPU layers, q8_0 K/V cache, and the same fixed text prompt recorded above. The model was loaded through `/api/runtime/text/load`; each mode was unloaded before switching. No image/text runtime was active before the run. The ComfyUI queue was empty.

| Projector | Trial | Load wall | Prompt eval (llama.cpp) | Generation eval | API chat wall | Available RAM after / peak low | Swap used |
|---|---:|---:|---:|---:|---:|---:|---:|
| none | 1 | 4.11 s | 198.02 tok/s (45 tokens) | 21.40 tok/s (64 tokens) | 3.19 s | 10.65 GiB | 0 |
| none | 2, prefix cache hit | same load | 1 token re-eval; 21.46 tok/s | 21.42 tok/s (85 tokens) | 3.98 s | 10.64 GiB | 0 |
| explicit mmproj f16 | 1 | 4.55 s | 214.42 tok/s (45 tokens) | 21.33 tok/s (115 tokens) | 5.57 s | 9.31 GiB | 0 |

RAM values are host `MemAvailable` sampled during each request; the projector run used about 1.34 GiB more resident/cache memory than the no-projector baseline. Swap stayed unused. The API's first SSE event arrived in 0.056–0.249 s on the no-projector trials and 0.224 s with projector; that is not the same metric as llama.cpp prompt prefill and is not labeled first generated text.

These trials do not support a claim that the projector itself speeds or slows text-only inference: prior recorded projector trials showed 1.05–1.26 prompt tok/s and 35–43 s first-text latency, while these current llama.cpp logs show 198–214 prompt tok/s and sub-6 s API walls. This large discrepancy remains unexplained. The repeated no-projector request also reused 44 of 45 prompt tokens from prefix cache, so it is not an independent prefill sample. The results establish current service operation and memory overhead, not a controlled performance conclusion. Next, repeat with llama.cpp prompt cache disabled or unique equivalent prompts, capture complete server timing per sample, and investigate the prior timing discrepancy before comparing modes.


## Controlled Text Studio projector comparison — prompt cache disabled — 2026-11-05

To investigate the prior 35–43 s projector prompt-evaluation observations, ran `llama-server` 0.7.0-dev build 11845 directly on loopback port 18081, with `--no-cache-prompt`. This avoided Studio request/session differences and prefix reuse. The model was restarted for each profile. Both used Qwen2.5-VL 3B Q4_K_M, context 2048, six CPU threads, zero GPU layers, q8_0 K/V cache, temperature 0.7, thinking disabled, and three distinct but equivalent 50-token prompts. No source/config changes were made.

| Profile | Load to ready | Prompt eval median (range) | Output eval median | API wall median (range) | First SSE event median |
|---|---:|---:|---:|---:|---:|
| No projector | 1.82 s | 215.72 tok/s (205.13–288.60) | 21.45 tok/s | 5.18 s (4.60–5.70) | 0.235 s |
| Explicit f16 projector | 2.41 s | 260.04 tok/s (219.08–290.11) | 21.42 tok/s | 5.56 s (4.23–5.69) | 0.194 s |

The projector reduced `MemAvailable` by a further ~1.31 GiB versus the no-projector model load. Swap remained unused. The six prompt evaluations processed 50 tokens each; no prefix-cache reuse was enabled. Output token counts varied from 88 to 118, so wall times are descriptive and not normalized quality comparisons.

The earlier slow projector result did not reproduce under this controlled run. The current prompt-evaluation rates overlap and output generation rates are effectively the same. The reason for the earlier 1.05–1.26 tok/s prefill remains unverified; it may reflect a transient system/runtime condition or measurement-path difference. No speed gain from either mode is claimed. Direct llama-server testing also does not replace an end-to-end vision/image-input test.

After termination, Studio v0.6.0 remained healthy, both systemd services were active, the ComfyUI queue was empty, and all Studio runtimes were stopped.


## CPU-only text-only model smoke — Ollama — 2026-11-05

The Studio inventory had no small genuine text-only GGUF with a safe context-2048 CPU memory margin: Qwen3.5 9B Q4_K_M's 2048-context estimate left less than the 4 GiB reserve, while the smaller Qwen3.8-27B draft Q8 GGUF crashed llama-server in `libggml-base.so.0.27.0` before readiness. Ollama already had `qwen2.5-coder:7b` installed, so a bounded CPU-only smoke request was made through its local API with `num_gpu=0`, context 2048, max output 64 tokens and `keep_alive=0`.

- Outcome: valid response; 46 prompt tokens, 56 output tokens.
- Cold load: 15.97 s; prompt evaluation: 1.24 s; generation: 4.61 s (12.15 tok/s); total client wall: 21.83 s.
- MemAvailable: 12.56 GiB before, 8.04 GiB minimum observed; swap remained unused.
- Ollama unloaded the model after the request. Studio v0.6.0 remained healthy; ComfyUI queue stayed empty and both services remained active.

This establishes a working text-only CPU inference route on the host, not yet Studio Text UI integration or a fair speed comparison with Qwen2.5-VL. No model/runtime configuration was changed.

## GGUF structure-validation cache and model-catalog API — 2026-11-05

The full GGUF structure validator was timed read-only on each local model file before caching:

| File class | Observed validation time |
|---|---:|
| Small/tiny GGUFs | 0.030–0.049 s |
| Main text models | 5.562–9.259 s |

The MTP draft is structurally valid and takes about 9.1 s to parse, then remains rejected by the independent layer/tensor-count guard. After adding the stat-fingerprint cache, the live load API returned its expected 422 in 9.396 s on the first scan and 0.022 s on the repeated unchanged file. No model process was started. Cache uses device, inode, size, mtime-ns and ctime-ns; it is in-memory and capped at 256 successful/in-flight validations.

Separately timed six local GET /api/models?context=2048 requests with seven models in the catalog. Response size was 7,084 bytes each; wall times were 0.0847, 0.0404, 0.0276, 0.0280, 0.0274 and 0.0277 s (median 0.02785 s). The API catalog path is not a demonstrated bottleneck, so no change was made there. These local timings include the client-side JSON parse and are descriptive, not a broader load test.

## Local API read-path microbenchmarks — 2026-11-05

Five requests per endpoint from localhost, including response read and JSON decode:

| Endpoint | Median | Range | Response bytes |
|---|---:|---:|---:|
| /api/diagnostics | 9.7 ms | 8.5–37.1 ms | 1,142 |
| /api/market/queue | 2.2 ms | 2.1–2.4 ms | 5,491 |
| /api/image/models | 48.4 ms | 46.3–75.7 ms | 27,602 |
| /api/tasks | 0.8 ms | 0.8–3.4 ms | 304 |

These small idle-state local samples did not indicate a meaningful API bottleneck; no code change was made based on them. They are not LAN/browser latency measurements.
## Video API local timings — 2026-11-05

Five localhost GETs per route, including reading the full response body:

| Endpoint | Median | Range | Response bytes |
|---|---:|---:|---:|
| `/api/video/native/models` | 2.5 ms | 2.1–13.3 ms | 2,324 |
| `/api/video/status` | 80.8 ms | 76.8–110.0 ms | 218 |

The native model catalog is fast. Video status is dominated by its ComfyUI backend checks but stayed under 111 ms in this idle-state sample; no optimization was indicated. These are local request timings, not a load or LAN test.

## Queue persistence write timing — 2026-11-05

Ten no-op market-action requests against the retained failed item triggered atomic queue persistence without changing its status. API wall time median was 11.87 ms (range 10.02–28.34 ms). This is small relative to the 800 ms download-progress persistence interval; no persistence optimization was indicated. Current downloads, settings, and image-presets files all have mode 0600.
