# Known issues and audit findings — 2026-11-05

## Network exposure needs an owner decision

Observed listeners:

- Studio web/API: `0.0.0.0:8787`.
- ComfyUI: `192.168.2.210:8790`.
- Ollama: `*:11434`.

The Studio server validates the Host against local interface addresses and rejects mismatched Origin headers. I found no authentication middleware in the inspected request path. Its health and model endpoints respond without a credential from localhost. Ollama's `/api/tags` also responded without authentication. ComfyUI's queue and system stats endpoints responded without authentication.

The host does not have `ufw` or `nft` commands, so this session could not verify the firewall or determine whether these ports are reachable beyond the local network. No network settings were changed because the intended access boundary (local-only vs LAN access) is not documented. The all-interface Ollama listener is the highest-priority item to review; if Studio does not rely on remote Ollama clients, bind it to localhost and verify the service after that change.

## Runtime and benchmark caveats

- The SickRealism 8-step benchmark image was produced, but the Termalin SSH request timed out before returning the Studio job response. The ComfyUI log and output metadata confirm success and 112.38 s execution; API wall time was not captured.
- Current image benchmark profiles have one run each. The 4-step Turbo-LoRA profile is faster in the measured sample, but image quality was not evaluated.
- The SickRealism LoRA-chain test confirms API acceptance, chaining and output saving, but does not assess image quality.
- Text Studio projector A/B has one no-projector run and two projector runs. Prefill times differ greatly; cache and memory conditions were not controlled enough to claim a causal speedup.
- ComfyUI emits many `Signal ... time stamps may be invalid` lines during generation. Tested jobs still completed and produced valid PNGs; investigate if this appears alongside a failed or corrupted generation.
- Swap use stayed around 2.3–2.6 GiB over the session. Capture a settled idle sample before treating that as normal baseline.

## Resolved in current working tree

Krea2 candidate detection now checks Safetensors header/tensor structure and rejects out-of-range or overlapping tensor regions, while accepting both paired LoRA and LoKr formats. Four currently installed metadata-tagged Krea2 adapters passed the check. See `OPTIMIZATION-LOG.md`.

## Unresolved scope

- Verify actual firewall/router exposure for ports 8787, 8790 and 11434.
- Confirm whether the user intends to access Ollama directly from another LAN device.
- Run repeated cold/warm benchmark samples and Text Studio throughput tests.


## Text-only GGUF startup failure — 2026-11-05

The installed `Qwen3.8-27B-Uncensored-draft-Q8_0.gguf` causes llama-server 0.7.0-dev build 11845 to segfault during model load on this host, before HTTP readiness. Kernel journal reports `libggml-base.so.0.27.0`, fault address 0x10. Core dumps are disabled and `coredumpctl` is unavailable, so exact root cause (model compatibility vs runtime defect) is unconfirmed. Do not use this GGUF through Studio until investigated. A smaller Qwen3.5 9B Q4 is present but its conservative 2048-context estimate is too close to the 4 GiB host reserve for the current safe smoke procedure. Installed Ollama qwen2.5-coder:7b passed one bounded CPU-only smoke request; see `BENCHMARKS.md`.


### Qwen3.8 GGUF is a draft-head fragment, not a full base model

Read the GGUF header using the repository's `gguf_dump.py` (metadata/tensor-header parsing only; no model inference). Despite its filename and `general.type=model`, the file contains only 18 tensors, all for `blk.64` plus output/token embeddings. Metadata says `general.name=Abl 27b`, `general.size_label=3.0B`, `qwen35.block_count=65`, and `qwen35.nextn_predict_layers=1`. The local llama.cpp Qwen35 implementation describes MTP as an extra decoder block and asserts MTP-specific tensors. This strongly suggests the file is an MTP/draft component, not a standalone 27B base model; it is not safe to expose as an ordinary chat GGUF. This is a likely explanation for the loader crash, but not proven without a core dump or a known compatible base-model pairing. Avoid loading it as a standalone model.

## Draft/MTP GGUF standalone loading guard — 2026-11-05

The known Qwen3.8-27B-Uncensored-draft-Q8_0.gguf now remains visible in the library but is marked non-loadable: it declares 65 blocks and contains only 18 tensors. The UI omits it from chat selectors and the server rejects direct text-load requests with HTTP 422 before process spawn. A fixture check covers the GGUF header and conservative two-tensors-per-block threshold.

This is not a full model integrity check. A model passing the threshold can still be truncated, corrupt, unsupported or incompatible; unknown layer/tensor-count metadata is allowed. Full tensor-directory validation and validation for other incomplete catalog files remain open.

## Download/API reliability fixes — 2026-11-05

- Civitai arbitrary-URL fetch issue fixed: source allowlist and required version ID; URLs are reconstructed on civitai.com or civitai.red. A live request using a localhost URL was rejected with 400 without queuing work.
- .pt/.pth downloads are now resumable in both server and frontend.
- Browser-level verification of queue error rendering remains pending because the desktop UI harness timed out. Studio listens on `0.0.0.0:8787` and has no application authentication. Host firewall tools are unavailable, so effective network exposure is unknown. No network policy was changed.
- The native video upload now applies its byte cap to actual streamed bytes. See the 2026-11-05 continuation below.

## GGUF upload/catalog header and queue error display — 2026-11-05

Invalid fixed GGUF headers are rejected on upload, marked non-loadable in the catalog, and blocked before text runtime launch. Queue API failures now display an inline error instead of leaving stale queue rows. The header check is not full GGUF tensor-directory validation; truncated tensor data or internally inconsistent offsets still need separate review.

## GGUF validation status update — 2026-11-05

The earlier fixed-header-only limitation has been partly closed: upload and text load now also parse the full GGUF tensor directory through the installed gguf Python reader and reject malformed/truncated/overlapping tensor data. The catalog keeps a lightweight header screen. This still does not prove architecture compatibility or full base-model completeness; the draft classifier remains a separate heuristic. Browser-level testing of queue error rendering remains open.

## 2026-11-05 — handoff status after reliability continuation

- Core code and live API verifications are complete as documented above.
- Browser-level queue-error verification was attempted, but the Computer Use helper returned “Computer Use app approval timed out” before a screenshot was provided. No form was submitted and no browser data was changed. The UI code change remains syntax-checked only.
- Continue with browser UI verification if a working harness is available; otherwise continue the measured PS5 performance/reliability audit without changing the network boundary.

## Structure scan cache — 2026-11-05

Successful GGUF structural scans are cached in-process using device/inode/size/mtime-ns/ctime-ns and re-stat after parsing. Concurrent requests share the same pending scan. Only successful results are cached, with a 256-entry bound. Measured repeat draft API check fell from 9.396 s on the uncached scan to 0.022 s on the unchanged file (about 99.8% lower latency), while still rejecting the fragment with 422 and starting no inference process. Cache resets on service restart. Tests: 7 cache assertions plus all prior checks pass.

## GGUF path coverage — 2026-11-05

Structural validation now runs before GGUF upload installation, download installation, text loading, Image Studio loading, and direct Krea 2 GGUF requests. The standalone MTP classifier remains separate because a draft can be structurally valid yet incomplete as a base model. No external download or ComfyUI generation was initiated for the latest route coverage; full route smoke coverage across all these paths remains limited to upload/text live checks plus static/code/fixture checks.

## 2026-11-05 — current service and queue observations

After the upload guard restart, the PS5 AI Studio user service is active and health returns version 0.6.0. ComfyUI is active under `ps5-ai-studio-comfyui.service`. The queue contains an existing failed Civitai download with HTTP 401 and 0 bytes received; no Civitai API key is configured, and the task was not retried or removed. Download errors now distinguish a fresh request from a resume and point 401/403 errors to API-key/access settings.


## 2026-11-05 — model upload byte caps

Actual streamed-byte limits now cover the native video model upload (80 GiB), ComfyUI video model upload (40 GiB), and model upload (100 GiB). The two video routes also verify declared content length when provided.

## 2026-11-05 — listener exposure confirmed, firewall unknown

Read-only audit confirms Studio listens on `0.0.0.0:8787`. The server rejects mismatched browser Origin headers, but has no application authentication and accepts requests without an Origin header; Origin validation is not authentication. `ufw`, `nft`, and `iptables` are unavailable to this session, so host firewall policy could not be verified. No listener or firewall settings were changed, per the existing network-boundary constraint. This remains an explicit security decision before exposing the host to untrusted networks.


## 2026-11-05 — external download stream cap

The download stream now enforces expected/free-space byte caps while receiving data. Unknown-size downloads are capped at 80 GiB for video and 100 GiB otherwise. The guard is fixture-tested; an external end-to-end download was intentionally not triggered.


## 2026-11-05 — scratch symlink protection

Scratch file read/write now opens the final component with `O_NOFOLLOW`. Symlink POST and GET probes return 403; normal scratch file API round-trip still passes.


## 2026-11-05 — broader no-follow coverage

No-follow file access now covers scratch files, conversations, gallery metadata, and pose metadata/images. A live symlink conversation write returned 403 without changing its outside canary.


## 2026-11-05 — output read guards

Gallery image, gallery metadata, video, and pose image/metadata paths now reject final-component symlinks. Upscale input selection rejects a symlink. Live canary probes pass.


## 2026-11-05 — download queue restore hardening

Persisted download records are validated and canonicalized before resume; stored URLs are rebuilt. Queue state is written through a unique exclusive no-follow temp file and rename. Current eight queue items survived restart unchanged in count and status.


## 2026-11-05 — persistent and generated file writes

Settings and presets now use atomic no-follow writes and no-follow reads. Server write sites use no-follow file handles. Settings save and preset create/delete API smoke tests pass; temporary preset was removed.


## 2026-11-05 — malformed path encodings

Malformed percent-encoding on request path segments now returns HTTP 400 across dynamic and static routes. Five representative API/UI paths passed live probes.


## 2026-11-05 — native video profile file checks

Native video profile readiness and size now accept only regular non-symlink files. Wan 2.2 symlink-placeholder probe stayed not-ready and left no test files.


## 2026-11-05 — mmproj integrity

Text-model loads now validate mmproj regular-file status, GGUF header and full structure before stopping/spawning runtimes. Installed Qwen2.5-VL mmproj passes validation; symlink load probe returns 400 without runtime changes.


## 2026-11-05 — validate text runtime overrides

Text loader now rejects invalid cache, GPU-layer, thread, and mmproj options before GGUF scans or stopping any runtime. Live malformed requests returned 400 and left runtime state unchanged.


## 2026-11-05 — ComfyUI Manager PyTorch detection differs from live HIP status

The active `ps5-ai-studio-comfyui.service` launches `runtimes/comfy-rocm-venv/bin/python`. Studio `/api/krea2/status` reports PyTorch `2.10.0+ps5gfx1013`, HIP/gfx1013 ready, and Krea 2 nodes/models present; the ComfyUI startup log also reports ROCm 7.1 and an available HIP `comfy_kitchen` backend. However, ComfyUI-Manager emits `[ERROR] PyTorch is not installed` during startup. Existing HIP output records prove earlier successful generations but predate the latest service start. Investigate whether Manager's detection failure affects Manager-only features; do not downgrade or switch the active environment based on this message alone.


## 2026-11-06 — standalone stable-diffusion.cpp Vulkan smoke test crashed host

A standalone `sd-cli` test was started against Vulkan0 with Krea 2 Turbo Q3_K_M, Qwen3VL 4B Q4_K_M, Wan 2.1 VAE, 512×512 and 8 steps. The Vulkan backend enumerated the PS5 Oberon/gfx1013 device and prepared the encoder and diffusion weights, but the PS5 crashed/rebooted before the command reported completion. The expected output PNG was absent after reboot.

**Status:** interrupted; no successful generation, timing or quality result. Do not classify the event as a confirmed OOM or confirmed Vulkan device-loss: the available post-reboot logs do not establish the root cause. The standalone Vulkan Krea 2 path remains unverified. Do not rerun the same profile automatically; inspect memory headroom and runtime/kernel health before any lower-risk follow-up.

After reboot, both `ps5-ai-studio-linux.service` and `ps5-ai-studio-comfyui.service` were active. The project syntax check `npm run check` passed. See `docs/2026-11-06-LIVE-STATE.md`.
