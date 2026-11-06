# Session handoff — PS5 AI Studio Linux
Updated: 2026-11-05 (Europe/Amsterdam)

## Project
- Name: PS5 AI Studio Linux
- Host: `ps5-linux` (Termalin connection, full policy)
- Location: `/home/michel/PS5-AI-Studio-Linux`
- Studio: `http://192.168.2.210:8787`
- ComfyUI: `http://192.168.2.210:8790`

## Goal
Continue the PS5-specific audit, optimization, benchmarking and reliability work for the local AI Studio, preserving the current PS5 runtime and recording findings in this project.

## Recovered state
- Existing session history is not available as a Codex thread on this host. The project documentation is the source of truth.
- Read `PROGRESS.md`, `OPTIMIZATION-LOG.md`, `KNOWN-ISSUES.md`, `BENCHMARKS.md`, `HARDWARE-BASELINE.md` and `KREA2-PS5-STATUS.md`.
- Working tree has extensive pre-existing modifications and untracked files. Do not reset, clean, or overwrite these.
- Studio API v0.6.0 and ComfyUI services report active.
- Studio `/api/health` returned OK. ComfyUI queue at the configured LAN address is empty; `/system_stats` responded with ComfyUI 0.43.0. Localhost:8790 is not its bind address.
- No kernel, driver, ROCm, model, boot, firewall, or network settings were changed in this resumed session.

## Implemented and documented before this session
- Safetensors boundary/shape/overlap checks and paired LoRA/LoKr structure validation are in the current backend working tree. Details and rollback backup are in `OPTIMIZATION-LOG.md`.
- Image and Text Studio samples, hardware baseline, and known risks are documented in `BENCHMARKS.md`, `HARDWARE-BASELINE.md`, and `KNOWN-ISSUES.md`.
- Krea2-specific runtime decisions and experiments are in `KREA2-PS5-STATUS.md`.

## Verified in this resumed session
- Termalin connection to ps5-linux works.
- Services active; Studio health succeeds; ComfyUI queue empty and system stats endpoint responds at 192.168.2.210:8790.

## Open items
- Intended network access boundary and router/firewall exposure for 8787, 8790, and 11434 remain unknown. Do not alter binds/firewall until clarified.
- Controlled repeat Text Studio projector benchmarks, then a safe text-only GGUF test.
- GPU-offload comparison only after a memory plan.
- Settled swap/memory sample.
- Continue API/download/file-validation and frontend error-handling audit.
- Image-quality evaluation separate from timing.
- See `KNOWN-ISSUES.md` and the next-actions section of `PROGRESS.md`.

## Exact next action
The cache-disabled comparison is complete and documented. Next, use `/api/models` memory estimates to select the safest installed genuinely text-only GGUF candidate, evaluate its context-2048 CPU-only memory budget against the 4 GiB host reserve, then run one bounded smoke chat only if the preflight has adequate headroom. Keep the Qwen2.5-VL projector comparison as descriptive only; the earlier slow prefill outlier remains unexplained. Before any listener/firewall change, obtain the intended access boundary.

## Connections/configuration
Use the existing Termalin host `ps5-linux`; do not require the inaccessible Windows Codex history. Services run as user systemd units `ps5-ai-studio-linux.service` and `ps5-ai-studio-comfyui.service`.

## 2026-11-05 continuation — download reliability/security

- Fixed Civitai arbitrary URL trust: exact source allowlist, mandatory version ID, canonical official-domain URLs. Live invalid request returned HTTP 400 without creating a queue item.
- Aligned .pt/.pth queue creation, resume and UI capability; shared backend validator added.
- Tests: 13 download fixtures and 9 GGUF fixtures pass; npm run check and git diff --check pass. Both services active, Studio health OK, ComfyUI queue empty.
- Backup: apps/server/server.mjs.pre-civitai-url-guard-20261105-110810 (plus prior resume checkpoint apps/server/server.mjs.pre-download-resume-ext-20261105-110627).

## Exact next action
Continue reviewing upload validation (especially GGUF structural checks) and frontend download-queue error recovery. Reproduce defects before changing code. Keep network/firewall exposure unchanged.

## 2026-11-05 continuation — upload and queue error handling

- Added fixed 24-byte GGUF header validation at upload, catalog display, and text load. Invalid uploads are rejected and their temporary file removed. 24-byte zero-byte-content probe named .gguf returned HTTP 400; no destination or partial file remained. Seven installed headers parsed as valid, and the draft guard still flags the 18/65 file.
- Download queue API errors now render visibly and suggest the existing Refresh control.
- Verification: 13 download and 12 GGUF assertions; npm run check; syntax checks; git diff --check. Studio/ComfyUI active, API health good, queue empty, runtimes stopped.
- Backup: apps/server/server.mjs.pre-gguf-upload-header-20261105-111044.

## Exact next action
Determine whether to extend the existing GGUF parsing path to validate tensor-directory counts, names, shapes and file bounds. Keep the current header guard as a partial screen; do not represent it as full integrity verification. Then cover queue API failure behavior if a browser harness is available.

## 2026-11-05 continuation — full GGUF structure gate

- Added apps/server/validate_gguf.py using the installed gguf reader. Upload and text load validate full tensor directories, counts, names/types, dimensions, alignment, bounds and overlap before installation/process launch. Catalog retains the lightweight header/draft checks.
- Read-only scan of all 11 GGUFs: all parsed counts matched and tensor data ranges were inside file bounds. Fixture suite: 3 tests (valid, truncation, overlap), all pass. Live synthetic valid upload returned 201 and was removed; truncated payload returned 422 and left no partial; draft load returned 422 with no inference process.
- Initial upload fixture found a redundant close; fixed and reverified. Other checks pass: 13 download, 12 GGUF classification, npm run check, git diff --check. Services active, API healthy, ComfyUI queue empty, runtimes stopped.
- Dependency: gguf package from runtimes/comfy-rocm-venv/bin/python; verified on ps5-linux. Structural validation does not certify architecture compatibility or base-model completeness.
- Backup: apps/server/server.mjs.pre-gguf-structure-validator-20261105-111603; fix checkpoint: apps/server/server.mjs.pre-gguf-upload-close-fix-20261105-111851.

## Next action
Continue PS5 Studio work with browser-level verification of queue error recovery if a suitable harness is available, then select the next safe optimization based on the remaining measured bottlenecks. Preserve network boundaries and the dirty worktree.

## Handoff note — browser verification

Computer Use was attempted for the queue UI but its approval timed out before screenshot capture. No browser form was submitted or data changed. The queue UI behavior has syntax validation only; verify in a browser when a working harness is available. Continue the PS5 AI Studio audit with network exposure unchanged.

## 2026-11-05 continuation — cache GGUF integrity scans

- Measured full structure scan: ~5.6–9.3 s for large text models; ~0.03–0.05 s for small files.
- Added bounded in-process cache keyed on dev/inode/size/mtime-ns/ctime-ns, with post-scan fingerprint verification and concurrent scan coalescing. Failures are not cached; successful upload scans are reused after atomic rename.
- Live draft API check after restart: 9.396 s uncached and 0.022 s repeated (about 99.8% lower latency), still HTTP 422; no inference started.
- Seven cache fixtures and all previous tests/checks pass. Both services active, health OK, queue empty.
- Cache is in-memory only; after service restart the first access to existing large GGUF pays the full scan.
- Backup before this edit: apps/server/server.mjs.pre-gguf-validation-cache-20261105-113526.

## Next action
Measure the local /api/models listing path and fix only a confirmed bottleneck; then continue the application and performance audit. Keep changes reversible and maintain the handoff.

## 2026-11-05 continuation — complete GGUF path coverage

- Extended full structure validation to completed GGUF downloads before install, Image Studio GGUF load, and direct Krea2 GGUF API before workflow/runtime side effects. Invalid downloaded parts are discarded. Earlier upload/text paths remain covered.
- Tests/checks pass: 7 cache assertions, 13 download, 12 header/classifier, 3 tensor structure tests, npm run check and git diff --check. Both services active, Studio health OK, ComfyUI queue empty, runtimes stopped.
- No upstream download or ComfyUI generation was initiated for these final route additions. Backup for download guard: apps/server/server.mjs.pre-gguf-download-validation-20261105-113833; image/Krea guard: apps/server/server.mjs.pre-image-gguf-structure-guard-20261105-114006.
- Local endpoint samples found no meaningful read API bottleneck: diagnostics 9.7ms, queue 2.2ms, image models 48.4ms, tasks 0.8ms. Recorded in BENCHMARKS.md.

## Next action
Continue the PS5 application audit with another concrete reliability or measured performance issue. Keep network exposure unchanged and preserve the dirty worktree.

## 2026-11-05 — bound native video model uploads

- Found that `/api/video/native/models/upload` enforced its 80 GiB maximum only from `Content-Length`; a chunked request could omit that header and stream without an actual byte cap.
- Added `apps/server/upload-stream-guard.mjs` and connected it to the route. The stream now aborts above 80 GiB, removes the incomplete target through the existing error path, and rejects a received-byte count that differs from a declared length.
- Added `scripts/test-upload-stream-guard.mjs`: 3 assertions cover exact-limit acceptance, over-limit HTTP 413 semantics, and invalid limit rejection. All GGUF/download fixtures, Python structural fixtures, `npm run check`, and `git diff --check` pass.
- Live smoke test on the normal Studio user service: 1 KiB chunked upload returned HTTP 201; DELETE returned 200 and the temporary file was confirmed absent. `systemctl --user` service is active and `/api/health` reports version 0.6.0. A backup checkpoint is `apps/server/server.mjs.pre-video-upload-stream-limit-20261105-120500`.
- Initial observation corrected below: the Studio API had one pre-existing failed Civitai download; ComfyUI uses a different user-unit name.

Next: continue the reliability audit, starting with the inactive ComfyUI service and the existing market-download 401 without removing or retrying user queue data.

## 2026-11-05 — clarify download authorization failures

- Inspected the existing failed queue item read-only: source `civitai-red`, HTTP 401, 0 of 590,058,832 bytes received. The sanitized settings API reports that no Civitai API key is configured. The item remains untouched and was not retried; configure an authorized key in Studio settings if this download is intended.
- Fixed the HTTP error wording to say “downloaden” for a fresh request and “hervatten” only when resuming from a nonzero offset; 401/403 now include a generic API-key/access hint. `scripts/test-download-validation.mjs` now has 16 assertions and passes. App syntax and diff checks pass; Studio user service restarted and health is OK.
- Correction to the service observation above: ComfyUI is active under the user unit `ps5-ai-studio-comfyui.service`; its `/system_stats` endpoint is reachable. The earlier inactive result queried the wrong unit name.

Next: continue the audit without retrying the credential-gated download or changing credentials. Preserve the queue and installed files.

## 2026-11-05 — enforce streamed limits on both video model upload routes

- Extended the shared upload-byte guard to `/api/video/models/upload` (40 GiB maximum), alongside `/api/video/native/models/upload` (80 GiB). Both now count streamed bytes and reject a declared-length mismatch; the existing 100 GiB text/image model upload already counts actual bytes.
- Live chunked upload to the ComfyUI video route returned HTTP 201 for 1 KiB; the exact temporary file was verified and removed. Native video chunked upload also returned 201 and was deleted through its API.
- Verification passed after the change: upload stream guard 3 assertions; download validation 16; GGUF cache 7; GGUF loadability 12; Python structure fixture 3; `npm run check`; `git diff --check`. Studio and ComfyUI user-services active; Studio health OK.
- Backups: `apps/server/server.mjs.pre-video-upload-stream-limit-20261105-120500` and `apps/server/server.mjs.pre-comfy-video-upload-stream-limit-20261105-122000`.

Next: continue reviewing remaining upload and file-write routes for actual-byte limits, path containment, and safe cleanup. Preserve the user queue and all model data.

## 2026-11-05 — listener exposure confirmed, firewall unknown

Read-only audit confirms Studio listens on `0.0.0.0:8787`. The server rejects mismatched browser Origin headers, but has no application authentication and accepts requests without an Origin header; Origin validation is not authentication. `ufw`, `nft`, and `iptables` are unavailable to this session, so host firewall policy could not be verified. No listener or firewall settings were changed, per the existing network-boundary constraint. This remains an explicit security decision before exposing the host to untrusted networks.

Next: continue read-only audit of the remaining server upload, queue, and runtime paths. Keep network exposure unchanged; do not retry the credential-gated Civitai item.

## 2026-11-05 — video API timing check

Five local requests each: `/api/video/native/models` median 2.5 ms (2.1–13.3 ms), 2,324-byte response; `/api/video/status` median 80.8 ms (76.8–110.0 ms), 218 bytes. No material bottleneck appeared, so no code change. Full samples are in `BENCHMARKS.md`.

## 2026-11-05 — bound external model download streams

- External downloads previously compared the final file size only after the response body had been fully written. Added per-chunk byte accounting: known-size items cannot exceed their expected size; unknown-size items are capped at 80 GiB for video categories and 100 GiB otherwise. The cap is additionally limited by bytes currently free plus the existing partial-file size.
- A chunk that crosses the cap is rejected before it is written and its partial file is removed. Downloads whose known size exceeds current available capacity fail before making the upstream request. Existing resumable partials remain in place for other errors.
- Added tests for exact cap, over-limit and safe-integer overflow; download validation fixture now has 19 assertions. All GGUF/download/upload fixtures, Python structure tests, `npm run check`, and `git diff --check` pass. Both Studio/ComfyUI user-services active and health OK. No external download was initiated.
- Backup: `apps/server/server.mjs.pre-download-byte-bound-20261105-123000`.

Next: keep auditing server input and persistence paths; retain the existing failed Civitai queue entry and do not retry it without credentials.

## 2026-11-05 — block scratch symlink reads and writes

- Confirmed that `/api/files` followed a pre-existing symlink and could overwrite a file outside the scratch directory. The canary test demonstrated this before the fix; the temporary canary and link were removed afterward.
- Added `openRegularFileNoFollow` and used it for scratch reads and writes. Symlinks and non-regular files now return HTTP 403. Normal API create/read/delete still returns 201/200/200. Regression smoke tests returned 403 for both symlink POST and GET, with the outside canary unchanged.
- Added `scripts/test-safe-file-ops.mjs` (4 assertions). All upload/download/GGUF fixtures, Python structure tests, syntax checks, and `git diff --check` pass. Studio health OK and user-service active.
- Backup: `apps/server/server.mjs.pre-scratch-symlink-guard-20261105-124000`.

Next: continue applying the filesystem audit to other routes that read or write user-controlled filenames; keep installed model data and queue history intact.

## 2026-11-05 — extend no-follow protection across file APIs

- Reused the no-follow file helpers for conversation list/get/create, gallery prompt-metadata reads, pose metadata update/read, and pose image reads, in addition to scratch file read/write. These routes no longer follow a final-component symlink to an outside file.
- Live conversation API round-trip returned POST/GET/DELETE 200. A symlink POST returned 403 and left its outside canary unchanged; the conversation listing still returned 200. Scratch API normal round-trip and symlink GET/POST probes also pass with 403 on symlinks.
- Safe-file fixture now has 6 assertions. All other GGUF, download and upload fixtures, Python structure tests, app syntax, and diff checks pass. Studio health OK.
- Backup: `apps/server/server.mjs.pre-metadata-symlink-guards-20261105-130000`.

Next: continue the static audit of remaining output and inference file paths; keep data and the queue intact.

## 2026-11-05 — protect remaining output reads from symlinks

- Extended no-follow reads to gallery images, video files, and pose-sidecar metadata. Upscale input selection now uses `lstat` and rejects symlink inputs before launching the runtime.
- Live probes with symlinks in gallery-image, gallery-metadata, and video-output paths all returned 404; the outside canary stayed unchanged. `/api/poses` returned 200.
- Full test suite passes: 7 cache, 19 download, 12 GGUF loadability, 3 Python structure, 3 upload-byte-limit and 6 safe-file assertions; `npm run check`; `git diff --check`. Both services active; Studio health OK.
- Backup: `apps/server/server.mjs.pre-output-symlink-guards-20261105-131000`.

Next: continue reviewing runtime output writes and the persistent download queue; keep all existing user data intact.

## 2026-11-05 — validate persistent download queue records

- Added startup normalization for persisted queue records. It checks source, category, repo/version metadata, relative file name, expected model directory, exact `.part` path, status, checksum and byte counters. Stored URLs are rebuilt from validated Hugging Face/Civitai fields instead of trusted. Invalid records become visible blocked error entries with no URL or filesystem paths.
- Queue persistence now writes a random exclusive no-follow temporary file, syncs it, then atomically renames it. Download part files are checked as regular files and opened with `O_NOFOLLOW`; invalid restored items cannot resume or delete arbitrary paths.
- Restart integration preserved all 8 real queue items: 7 done, 1 existing HTTP 401 error, 0 blocked. The failed item was not retried. A symlink canary on the former fixed temp path survived an API persistence action unchanged.
- Added `scripts/test-download-record-validation.mjs` (7 assertions). Existing cache/download/GGUF/upload/symlink tests and Python structure tests pass; app checks pass.
- Backup: `apps/server/server.mjs.pre-download-queue-restore-guard-20261105-133000`.

Next: continue the file-write audit for settings/preset and runtime-generated outputs, then check the queue UI behavior if a reliable browser harness is available.

## 2026-11-05 — harden settings, presets, and runtime output writes

- Replaced server-side direct `writeFile` calls with no-follow file-handle writes. Settings and image presets use unique exclusive temp files, `fsync`, and atomic rename. Settings, queue, and preset reads now reject final-component symlinks.
- The API settings round-trip saved the existing context unchanged and did not expose the Civitai key. A temporary preset was created with HTTP 201, deleted with HTTP 200, and the original preset count was restored.
- Existing runtime-generated image/video/metadata and temporary files now use no-follow writes. Generation itself was not launched.
- Safe-file fixture now has 7 assertions; queue-record fixture has 7. Full regression tests and syntax/diff checks pass. Both services active; health OK; queue remains 8 items (7 done, one preserved 401 error), zero blocked.
- Backup: `apps/server/server.mjs.pre-atomic-settings-output-writes-20261105-134000`; settings/preset read guard checkpoint: `apps/server/server.mjs.pre-preset-read-nofollow-20261105-135000`.

Next: continue remaining runtime-input/output audit; browser-level queue UI verification is still pending because the prior desktop harness timed out. Keep network exposure unchanged.

## 2026-11-05 — queue persistence timing and permissions

Ten no-op queue actions measured 11.87 ms median (10.02–28.34 ms) including atomic persistence; no meaningful throughput issue was indicated relative to the 800 ms progress interval. Queue, settings, and preset JSON files all remain mode 0600. Details are in `BENCHMARKS.md`.

## 2026-11-05 — finish runtime file-path and malformed URL pass

- Audited server read/write/open/stream call sites. The remaining server `writeFile` calls now use no-follow handles; configuration and presets use atomic replace. User-facing image/video/pose reads and conversation/preset/settings/queue reads reject final-component symlinks. Upload streams use exclusive creation; downloads use no-follow part-file streams.
- Added one path decoder that converts malformed percent-encoding to HTTP 400 instead of bubbling a URIError into HTTP 500. Live probes on `/api/files`, gallery metadata, Krea job, video job, and gallery image routes all returned 400 for `%ZZ`.
- Settings save preserved the current context and did not expose the Civitai key. Temporary preset create/delete restored the original preset count. Queue still has 8 entries and its 401 item was not retried.
- Queue persistence no-op timing: 11.87 ms median (10.02–28.34 ms), no material cost versus 800 ms download progress cadence. Queue/settings/preset JSON files remain mode 0600.
- Backup: `apps/server/server.mjs.pre-malformed-url-400-20261105-140000`.

Next: continue the remaining native runtime input/model-path audit and try browser-level queue verification if a harness is available. Preserve network exposure and queue data.

## 2026-11-05 — reject symlinked native video profile components

- The fixed native-video profile check used `existsSync/statSync`, so symlink placeholders could mark missing model files as ready. It now uses the shared regular-file `lstat` check; symlinks do not contribute to readiness or model size.
- Live Wan 2.2 probe temporarily placed symlinks at its two known missing file paths. The API correctly remained `ready=false` and listed both files as missing; the catalog exposed zero symlink entries. Temporary links and the outside canary were removed.
- App syntax and diff checks pass; full regression run is listed below. Backup: `apps/server/server.mjs.pre-video-profile-symlink-guard-20261105-141000`.

Next: continue auditing runtime selections and status paths; keep model data and queue untouched.

## 2026-11-05 — validate text mmproj files before runtime changes

- Text model loading now requires an mmproj candidate to be a regular non-symlink file, have a valid GGUF header, and pass the full tensor-structure validator before any runtime is stopped or spawned. Symlink mmproj entries are excluded from candidate discovery.
- The installed Qwen2.5-VL mmproj was checked read-only: 1,338,428,128 bytes, 519 tensors, complete file bounds, structurally valid. No model was loaded.
- Live request using a temporary in-directory symlink as explicit mmproj returned HTTP 400; text runtime state was unchanged (stopped). The link and canary were removed.
- Backup: `apps/server/server.mjs.pre-mmproj-structure-guard-20261105-142000`.

Next: continue auditing runtime selection and status routes, then try browser-level queue verification if the desktop harness is usable.

## 2026-11-05 — validate text runtime overrides before stopping runtimes

- Added `validateTextRuntimeOptions` ahead of model discovery, GGUF scans, and runtime stop calls. It constrains threads to 1–16, validates GPU-layer syntax and cache types, clamps context, and rejects non-string mmproj selections.
- Live API probes with invalid cache type, thread argument, and mmproj type all returned HTTP 400. `/api/runtime` was identical before and after; no runtime was stopped or spawned.
- Added `scripts/test-runtime-selection-validation.mjs` (10 assertions). Full fixtures and app checks pass.
- Backup: `apps/server/server.mjs.pre-runtime-option-validation-20261105-143000`.

Next: continue checking image/video runtime overrides and status routes for validation-before-side-effects.


## 2026-11-05 — image loader validates selections before runtime stops

- Moved upscale/text/video/image stop calls below validation of ControlNet, IP-Adapter, CLIP Vision, VAE, ControlNet compatibility, and the required IP-Adapter/CLIP Vision pair.
- Added explicit HTTP 404 checks for every requested optional asset; previously a missing IP-Adapter, CLIP Vision, or VAE could be silently ignored.
- Live API probes: missing ControlNet/IP-Adapter/CLIP Vision/VAE each returned 404; unpaired real IP-Adapter or CLIP Vision selections each returned 400. Runtime state before/after was byte-for-byte equivalent; no model runtime started.
- `npm run check`, runtime-selection (10), safe-file-ops (7), download validation (19), download-record (7), GGUF loadability (12), GGUF cache (7), upload guard (3), and `git diff --check` passed. Both user services are active; Studio health is OK.
- `scripts/test-gguf-structure.py` could not run in the host Python: `numpy` is not installed (`ModuleNotFoundError`). No package was installed.
- Backup: `apps/server/server.mjs.pre-image-loader-validation-order-20261105-120300`.

Next: continue auditing ComfyUI image/video load paths and queue/status behavior; rerun the Python GGUF fixture when its declared Python dependencies are available.


## 2026-11-05 — image selection fixture and native video preflight

- Extracted image asset selection checks into `validateImageRuntimeSelections`; the fixture now covers defaults, valid selections, all four missing asset types, adapter pairing, and malformed request bodies (20 assertions total).
- Live native-video preflight rejects an unknown profile (404) and incomplete Wan 2.2 stack (409) without runtime changes. The installed Wan 2.1 stack is complete; an accidental valid-profile probe returned ready, so I immediately unloaded that probe-started server. No generation was run; all four runtimes are now stopped, matching the pre-probe state.
- Both user services remain active and Studio health is OK.

Next: continue ComfyUI image/video route and queue/status audit; do not load a complete video profile again unless a real runtime load is explicitly part of the next chosen experiment.


## 2026-11-05 — full regression rerun and queue status snapshot

- The earlier Python test limitation was resolved by running `scripts/test-gguf-structure.py` under `runtimes/comfy-rocm-venv/bin/python`, the validator environment configured by the server. All 3 Python structural tests pass.
- Full regression suite passes: npm syntax check; runtime selection 20; safe file ops 7; download validation 19; persisted download validation 7; GGUF loadability 12; GGUF validation cache 7; upload byte guard 3; Python GGUF structure 3; `git diff --check`.
- Read-only queue/task audit: 8 preserved records (7 done, 1 error), no active transfer, task summary reports 1 error and 0 active. Four runtimes stopped after cleanup of the video loader probe; both user services active; Studio health OK.

Next: continue read-only audit of route/task reporting and ComfyUI workflow handling; no valid-profile video load until there is an actual need to test generation end-to-end.


## 2026-11-05 — ROCm runtime and Krea workflow documentation audit

- Live user service is `ps5-ai-studio-comfyui.service`, using the isolated `runtimes/comfy-rocm-venv/bin/python` on port 8790 with DynamicVRAM. `/api/krea2/status` reports ComfyUI 0.43.0, PyTorch `2.10.0+ps5gfx1013`, HIP/gfx1013 ready, Krea nodes and required assets present. Startup logs report ROCm 7.1 and the `comfy_kitchen` HIP ConvRot backend.
- Existing PNGs and sidecars confirm earlier Krea Sickrealism safetensors and Q3 GGUF Turbo outputs on HIP. Newest Sickrealism record: 256×256, 3 steps; recent Turbo records: 384×384, 4 steps. Existing comparative timing/memory measurements remain in `docs/KREA2-OPTIMIZATION-RESULTS-20261104.md`. No inference was queued during this audit.
- Audited both checked-in API workflows against live `/object_info`: all node classes and required fields exist. The official-FP8 Turbo template references a model absent from the installed PS5 catalog; clarified that the usable installed Turbo path is Studio’s Q3 GGUF DynamicVRAM route.
- Updated `workflows/KREA2.md` and `PLAN.md`; marked old CPU-only ROCm bring-up notes as historical. Startup still has a ComfyUI-Manager “PyTorch is not installed” message despite live HIP status, now tracked in `KNOWN-ISSUES.md`.
- Full code regression suite remains green from the prior run; both Studio services are active and all runtimes are stopped.

Next: continue reviewing Krea2 route preconditions and ComfyUI task/status error reporting, distinguishing documented readiness from live completed-generation evidence.


## 2026-11-05 — Krea 2 default resolution preflight

- Found that omitted width/height were nominally defaulted to 384, then rejected because the later validation compared the defaults against `NaN`. Extracted `validateKrea2Dimensions`, call it immediately after prompt validation, and preserve the 384×384 default while rejecting non-square/out-of-range/non-64-aligned dimensions before queue, memory recovery or ComfyUI calls.
- Added fixture coverage; runtime-selection fixture now passes 28 assertions. A live 384×512 request returned HTTP 400 with no queue or runtime changes. A valid generation was not submitted.
- Full regression suite passed: Node syntax; runtime validation 28; safe-file 7; download validation 19; persisted queue records 7; GGUF loadability 12; GGUF cache 7; upload cap 3; Python GGUF structure 3; diff whitespace check. Both user services active and Studio health OK.
- Backup: `apps/server/server.mjs.pre-krea-dimension-default-20261105-122000`.

Next: continue checking Krea 2 preflight model/LoRA coupling and the ComfyUI error-to-job-state path; keep testing rejected requests without enqueuing inference.


## 2026-11-05 — synchronize ComfyUI ROCm status across project docs

- Updated README, ComfyUI bridge guide, Architecture, Web Interface, Video Studio, and parity notes: the active ComfyUI service uses `comfy-rocm-venv` with ROCm/HIP gfx1013 and validated Krea 2 image generation. Native video remains on the separate stable-diffusion.cpp Vulkan engine. Removed obsolete CPU-only/not-enabled descriptions.
- The current readiness and prior output evidence are described with route-specific limits; no claim is made that every ComfyUI graph or video workflow is GPU-validated.
- Created dated `.pre-rocm-live-status-20261105-123000` documentation backups before editing.
- `git diff --check` passes; application syntax and full fixture suite passed after the Krea dimensions change.

Next: continue Krea2 LoRA/model preflight and ComfyUI job-state review.


## 2026-11-05 — Krea LoRA symlink guard

- Krea 2 user LoRA selection now accepts only a regular file before parsing Safetensors metadata; this matches the symlink-free model catalog. Explicit LoRA selection is checked before the Turbo/Sickrealism step compatibility check.
- Live API probe used a temporary link to a known-good Krea LoRA. It returned HTTP 400 for invalid LoRA metadata selection; temporary link was removed; Studio runtime, Studio download queue, and ComfyUI queue were unchanged.
- Full regression suite passes: runtime validation 28; safe file operations 7; download validation 19; persisted download validation 7; GGUF loadability 12; GGUF cache 7; upload byte guard 3; Python GGUF structure 3; `npm run check`; `git diff --check`. Both user services are active, all runtimes stopped, queue has 8 records with no active transfer.
- Backup: `apps/server/server.mjs.pre-krea-lora-nofollow-20261105-123200` and validation-order snapshot `apps/server/server.mjs.pre-krea-lora-validation-order-20261105-123300`.

Next: continue read-only Krea job completion/error reporting audit and persisted queue/task consistency checks.


## 2026-11-05 — Krea completion and partial-output error states

- Krea job polling now marks a completed ComfyUI history entry with no output image as an explicit error instead of leaving it queued/running. Terminal ComfyUI errors are honored even if a partial image output exists. Transient status-fetch/output-fetch failures remain retryable unless the output itself is invalid.
- Added `apps/server/comfy-job-status.mjs` and `scripts/test-comfy-job-status.mjs` (6 assertions) for successful output, completed-without-output, failed-with-partial-output, and nonterminal cases.
- Full suite passes: runtime selection 28; Comfy job status 6; safe file ops 7; download validation 19; persisted queue records 7; GGUF loadability 12; GGUF cache 7; upload byte guard 3; Python GGUF structure 3; app syntax and `git diff --check`.
- Studio and ComfyUI user services are active; all four native runtimes are stopped; ComfyUI queue is empty; the Studio queue remains 8 records with no active transfer.
- Backup: `apps/server/server.mjs.pre-krea-completion-state-20261105-123500` and partial-output ordering snapshot `apps/server/server.mjs.pre-krea-partial-output-error-20261105-123700`.

Next: continue ComfyUI job-state/API error handling audit and verify the UI presents terminal errors without requiring a destructive queue action.


## 2026-11-05 — confirm ComfyUI cancellation before changing job state

- Krea cancellation now returns HTTP 503 when ComfyUI queue status cannot be read and HTTP 502 when ComfyUI rejects interrupt/removal. Studio sets `cancelled` only after a successful ComfyUI response.
- Added queue/action result fixture coverage; `scripts/test-comfy-job-status.mjs` now passes 9 assertions, including no-output completion, partial-output failure, queue unavailable and cancel action rejected. Frontend polling already stops on terminal `error` and shows the returned message.
- Full regression suite passes again (runtime 28, Comfy status/cancel 9, safe file 7, download validation 19, record validation 7, GGUF loadability 12, GGUF cache 7, upload guard 3, Python structure 3, syntax and diff check).
- Studio and ComfyUI services active; four native runtimes stopped; Studio queue has 8 saved items, none active; ComfyUI queue empty.
- Backup: `apps/server/server.mjs.pre-krea-cancel-http-check-20261105-123900`.

Next: continue the remaining ComfyUI route/error audit with read-only checks and keep terminal job outcomes and user-visible messages aligned.


## 2026-11-05 — include Krea jobs in the task dashboard

- `/api/tasks` now includes queued/running Krea 2 jobs and terminal Krea errors, with model, resolution/step or error detail and an Images target. This also makes Krea failures contribute to the shared `errors` count. Completed/cancelled jobs stay out of the active task list.
- Added `kreaJobTask` fixtures to `scripts/test-comfy-job-status.mjs`; job-state/cancel/task tests now pass 12 assertions.
- Full regression suite is green after restart. Both user services active; all runtimes stopped; ComfyUI queue empty; eight Studio download records preserved, no active transfer.
- Backup: `apps/server/server.mjs.pre-krea-task-summary-20261105-124100`.

Next: continue the remaining ComfyUI task/error reporting checks and inspect the current documented queue error without retrying or deleting it.


## 2026-11-05 — include terminal video and Enhance errors in task summary

- The shared task dashboard now retains queued/running/error states for Krea, native/Comfy video, and Enhance jobs. Error details are shown directly; completed and cancelled jobs are omitted. Errors from those jobs now contribute to the shared count.
- `taskStateVisible` fixture added; Comfy job/status/cancel/task tests pass 15 assertions. Full regression suite passes after restart.
- Live task summary remains one error and zero active: the existing failed Civitai item is preserved; there is no active Studio download or ComfyUI workflow. No retry or deletion was issued. Both user services are active; all native runtimes stopped.
- Backup: `apps/server/server.mjs.pre-task-terminal-errors-20261105-124300`.

Next: continue with static/live API consistency checks around task detail and job lifecycle; preserve the existing Civitai error record.


## 2026-11-05 — reconcile shared task error count with media jobs

- Queued/running/error states are now visible for Krea 2, video and Enhance tasks; terminal error details feed the same dashboard count. Completed/cancelled entries remain hidden.
- Live queue/task comparison matches: 8 persisted download records, one Civitai 401 error at 0 bytes, zero active downloads, one dashboard error, no ComfyUI jobs, and all native runtimes stopped. The failed item was not retried or removed.
- Full suite passes, including Comfy job status/cancel/task 15 assertions and runtime selection 28 assertions; all other fixture counts and Python GGUF structure tests pass. Both user services are active and `/api/health` is OK.
- Backup: `apps/server/server.mjs.pre-task-terminal-errors-20261105-124300`.

Next: continue checking lifecycle transitions and task-summary consistency for any remaining job types, preserving the Civitai record and model data.


## 2026-11-05 — target Comfy video cancellation at its own job

- `/api/video/cancel` no longer interrupts arbitrary ComfyUI work when no video job exists. It selects only an active ComfyUI video job, deletes its prompt if queued or interrupts if running, and marks it cancelled only after ComfyUI confirms. Queue read/action failures leave job state unchanged.
- Added active-Comfy-video selection fixture coverage; Comfy job/status/cancel/task fixture now passes 17 assertions. Live idle-cancel probe returns 409 and leaves ComfyUI queue and Studio runtimes unchanged.
- First probe ran before the patched Studio process had restarted and hit the old route; the ComfyUI queue was empty and no job was affected. After restart the intended 409 behavior was verified.
- Full suite passes again; both services active, native runtimes stopped, 8 Studio queue records preserved, 1 existing task error, no active ComfyUI jobs.
- Backup: `apps/server/server.mjs.pre-video-cancel-targeting-20261105-124500`.

Next: continue final route-by-route lifecycle review and ensure no remaining cancellation endpoint changes task state after an unsuccessful backend response.


## 2026-11-05 — Krea 2 Turbo speed optimization, first controlled PS5 pass

- Active step: compare the warm Q3 DynamicVRAM Krea 2 Turbo route at fixed prompt/seed on PS5 gfx1013, then surface measured speed guidance in the Krea panel.
- Results: 512x512 4-step Turbo completed in 30.19 s API / 28.32 s ComfyUI; 384x384 4-step Turbo completed in 21.19 s / 20.42 s (~29.8% faster; one run per size); 512x512 2-step Turbo completed in 59.98 s / 43.26 s and was slower than 4-step. First cold 512x512 4-step took 66.05 s, including ~14.5 s model initialization.
- Updated the Q3 Turbo UI measurement text so 4-step shows the new 512/384 warm times and 2-step is not presented as faster. JavaScript syntax and targeted diff checks pass.
- No visual quality scoring was done. 384x384 is documented as a faster, lower-pixel preview/work size, not a quality-equivalent replacement. All three runs completed and generated output.
- CPU boost A/B remains pending: `schedutil`, boost=0, max 3.2GHz. The SSH command’s non-interactive `sudo` returned “A terminal is required to authenticate”; no system setting changed. Recovery snapshot is `/tmp/ps5-krea2-cpuboost-20261105T140248Z.txt`.
- Both Studio and ComfyUI user services remain active; Krea ROCm/HIP gfx1013 ready; no active task or Comfy queue job. Existing Civitai 401 download error remains preserved.

Next: validate static UI serving and record exact outcomes; after that, investigate whether a safe, permissioned interactive CPU-boost A/B is available. If interactive sudo becomes available, test only the reversible CPU boost toggle against the saved baseline and restore `boost=0` if it does not improve warm timings.

## 2026-11-05 — standard-step comparison and live UI validation

- Same-session Q3 512x512 standard 8-step completed in 54.59 s API / 54.04 s ComfyUI, compared with 30.19 s API for warm 4-step Turbo and 59.98 s API for 2-step Turbo.
- Static serving checked through the live Studio process: `/api/health` returned 200 and `/app.js` returned 200 with the revised timing notes present. `node --check apps/web/app.js` and targeted `git diff --check` passed.
- Studio and ComfyUI services active; Krea reports ready; queue empty; no Studio tasks active. CPU boost remains `0`.

Next: continue performance research around model initialization/offload costs and see whether an interactive, reversible CPU boost A/B can be safely run. Do not change boot parameters or persist power settings.


## 2026-11-05 — add measured fast-preview workflow

- Added a Krea panel action to select Q3 Turbo + 384x384 + 4-step Turbo-LoRA in one click. This uses the measured warm route (21.19 s API / 20.42 s ComfyUI) and does not change defaults.
- The Turbo step selector now displays the actual 4/2 step count while disabled and restores the selected standard-step count when Turbo is switched off.
- Replaced stale Krea panel timing text with current PS5 timings and clarified that 384x384 image quality was not scored. Kept the note that fully GPU-resident execution is unproven.
- Source checks pass: `node --check`, `git diff --check`, HTML parsing with 419 unique IDs. Live HTTP verification follows.

## 2026-11-05 — repeatability and memory follow-up

- Repeated the 512x512 warm Q3 4-step Turbo fixed-prompt/seed run after switching through 2-step and standard 8-step profiles: 36.23 s API / 33.21 s ComfyUI, versus the earlier 30.19 s / 28.32 s. Current observed range is 30.2–36.2 s API across two runs.
- 384x384 4-step Turbo measured once at 21.19 s API / 20.42 s ComfyUI (~36% faster than the mean 512x512 result; fewer pixels, quality not evaluated).
- Post-run status: HSA free 2.18 GiB, host available 6.08 GiB, swap free 5.71 GiB; model still staged with ~1.35 GB host offload. No TTM/reserve/kernel change. This supports more investigation but not a claim that an 8 GiB GTT reboot change is safe/beneficial.
- Added the non-default one-click Q3 Turbo 384x384 4-step preset and current run-time notes. `npm run check`, HTTP API/static checks, Turbo step/restore test, HTML ID check and targeted diff checks pass. Both services remain active; no active task or Comfy job.

Next: inspect whether the current DynamicVRAM staging/offload has a safe user-space tuning opportunity; keep CPU boost and TTM boot experiments pending until an interactive authorized terminal is available.

- An immediate identical 512x512 / seed 20261105 / 4-step Turbo request returned in 3.17 s API / 0.00 s ComfyUI. ComfyUI logged 0.00 s execution and the PNG SHA256 matched the prior output exactly; classified as cache reuse and excluded from inference timing.

## 2026-11-05 — VRAM reserve A/B rejected; fix offload metadata

- Tested temporary `--reserve-vram 0.25` against original 0.5, with a saved recovery snapshot at `docs/benchmarks/krea2-reserve-20261105T142142Z-before-025/`. The 0.25 cold 512x512 run was 57.69 s API / 56.47 s ComfyUI; warm was 30.42 / 29.87 s. Warm speed was effectively unchanged, while HSA free fell to 1.65 GiB (<1.8 GiB guard), so 0.25 was rejected and removed.
- Original 0.5 reserve restored; ComfyUI restarted and returned ready with 7.05 GiB HSA free. One later 384 warm run under 0.5 left only 1.40 GiB free, so ComfyUI was restarted again to clear staged model memory. Current services are active, ready and idle.
- Fixed Krea output metadata: `model_offload` was a hard-coded 1347.84 MB string, not live telemetry. New outputs now store null. Verified on real cold/warm 384 PS5 jobs (51.75 s cold, 24.18 s warm), both with null metadata. Historical sidecars unchanged.
- 384 Turbo 4-step warm samples now span 21.19–24.18 s; cold after restart 51.75 s. Quality not scored.

Next: investigate whether the Krea preflight/recovery behavior around HSA below 1.8 GiB and ComfyUI staged-model memory is correct; do not lower its guard. Keep `--reserve-vram 0.5`.

## 2026-11-05 — guard the memory recovery restart

- Reviewed the Q3 preflight: host RAM minimum 4 GiB; Q3 HSA minimum 1.8 GiB; below threshold, Studio restarts ComfyUI, waits for `/system_stats`, refreshes status, then rejects if still below the guard.
- Added a fail-closed Comfy queue check immediately before the automatic memory restart, since initial prompt/model validation can take time. Queue helper accepts only valid running/pending arrays; busy or malformed state skips restart. Fixture expanded to 23 assertions and passes.
- `npm run check`, quick-preset interaction test and targeted diff check pass. Studio/ComfyUI active, Krea ready, HSA free 7.05 GiB, no active Studio task or Comfy queue job.
- Remaining race: an external ComfyUI request could enqueue after the final check but before systemd restart. No listener/network changes were made.

Next: continue safe performance work around model staging and CPU boost when an interactive sudo terminal is available. Keep the 1.8 GiB guard and 0.5 GiB reserve.

## 2026-11-05 — validate non-restarting GPU-memory recovery

- Direct ComfyUI `/free` probe at idle raised HSA free from 2.18 to 6.72 GiB in ~1 second; ComfyUI PID stayed 41972.
- End-to-end Studio recovery was tested from a real low-memory state: HSA free 1.40 GiB (<1.8 GiB Q3 guard), host available 4.24 GiB (>=4 GiB), queue empty. Studio accepted the third request in 0.66 s, `/free` reclaimed memory, and the 384x384 generation completed in 46.08 s. PID stayed 41972; HSA afterward 2.18 GiB, host available 4.98 GiB.
- Recovery now unloads model/cache first, rechecks queue, and keeps the systemd restart as fallback. Cold model load remains necessary, but ComfyUI downtime is avoided when `/free` succeeds.
- Updated the UI note from “runtime restart” to VRAM cache reclaim. Lifecycle fixture: 23 assertions; npm syntax, live API, real Krea recovery and diff checks pass.

Next: continue safe performance work around model staging; test CPU boost only when an interactive sudo terminal is available. Keep `reserve-vram=0.5` and the 1.8 GiB guard.

## 2026-11-05 — next Krea2 runtime candidate measured

- ComfyUI startup confirms gfx1013/HIP already uses AMD async weight offload with 2 streams by default. No change needed.
- A temporary `--fast fp16_accumulation` A/B was backed up, tested through guarded Studio generation at 384x384 / 4-step Q3 Turbo, then removed. Baseline warm 21.36 s API / 20.42 s Comfy; flag warm 20.48 s / 19.95 s (one run, ~2.3% Comfy improvement; inconclusive). Treatment cold was 55.53 s / 54.46 s, including model init. Do not retain the flag; user service is restored to normal args and `--reserve-vram 0.5`.
- After the warm trial HSA free fell to 1.40 GiB (<1.8 GiB guard); no more inference was forced. Restore restart cleared the staged cache. Current task/queue state was idle; verify final readiness after restart.
- Backup: `docs/benchmarks/krea2-fast-fp16accum-20261105T155500Z-before/`. Full numbers in `docs/KREA2-OPTIMIZATION-RESULTS-20261104.md`.

Next: continue Krea2 bottleneck work around model staging and CPU scheduling. Keep Q3 HSA guard 1.8 GiB and reserve 0.5 GiB; CPU boost remains unchanged because sudo is non-interactive.

## 2026-11-05 — CPU profile and fast-disk candidate rejected

- Default Krea2 Q3 Turbo 384x384/4-step CPU profile: cold 49.03 s API / 44.15 CPU-s (0.90 logical core average); warm 20.48 s / 21.14 CPU-s (1.03 core). PyTorch defaults to 16 intra-op and 16 inter-op threads. No CPU saturation observed; no thread setting changed.
- `device_supports_non_blocking(cuda:0)` on ROCm/HIP gfx1013 already returns true; `--force-non-blocking` would be a no-op for this transfer path and was not toggled.
- A/B `--fast-disk` on the same Q3 prompt/workflow: candidate cold API 46.63 and 47.71 s (mean 47.17), warm 20.64 s; restored-default control 47.50 cold / 20.40 warm, Comfy warm 19.88 s. HSA free after warm was 1.40 GiB either way; host avail ~4.39/4.38 GiB. Too small and inconsistent to retain. Backup `docs/benchmarks/krea2-fast-disk-20261105T161000Z-before/`.
- Removed fast-disk drop-in and restored original Comfy service args/reserve 0.5. Final status: Krea-ready, Studio active=0, Comfy queue empty, HSA free 1.40 GiB (<1.8 guard); next request should use `/free` recovery before queueing.

Next: audit GGUF dynamic staging/cache lifecycle for a safe improvement to repeat-job cold loads; do not lower the existing HSA guard or change CPU boost without interactive sudo.

## 2026-11-05 — cache-preserving VRAM recovery probe

- Temporary ComfyUI `/free` semantics patch (backup under `docs/benchmarks/krea2-free-cache-without-unload-20261105T162500Z-before/`) let `{unload_models:false,free_memory:true}` raise HSA from 1.40 to 6.72 GiB in 1.02 s without model unload.
- Next guarded Studio job nevertheless ran cold: 45.62 s API / 44.51 s ComfyUI. Reverted `server.py`, syntax-checked and restarted; no patch retained.
- New candidate: inspect whether `{unload_models:true,free_memory:false}` frees VRAM while retaining executor node cache, potentially avoiding loader reconstruction on the next same-profile Krea job. Keep existing queue checks and 1.8 GiB guard.

## 2026-11-05 — integrated cache-preserving low-memory recovery

- Studio now tries Comfy `/free` `{unload_models:true,free_memory:false}` first when Q3 HSA is below 1.8 GiB. It releases GPU residency while preserving PromptExecutor/node cache. It rechecks queue before the existing full-reset `/free` fallback, and retains the systemd restart fallback. Existing host 4 GiB / Q3 HSA 1.8 GiB guards and 0.5 GiB reserve are unchanged.
- Two real low-HSA Studio runs completed in 28.12 s API / 26.55 s Comfy and 25.75 s / 24.22 s, versus 45.62 s / 44.51 s for the earlier full executor reset. Each saved ~18–20 s; PID stable. Following warm runs measured 20.25 s /19.51 s. Manual unload-only probe gave 25.49/24.94.
- Rejected no-unload `{unload_models:false,free_memory:true}` variant: it reclaimed HSA to 6.72 GiB but next generation was still cold (45.62/44.51). Reverted its temporary Comfy `server.py` patch from `docs/benchmarks/krea2-free-cache-without-unload-20261105T162500Z-before/`.
- Backups for retained Studio change: `docs/benchmarks/krea2-cache-preserving-memory-recovery-20261105T164000Z-before/`.
- All checks passed: npm syntax; 28 runtime-selection, 23 Comfy lifecycle, 7 safe-file, 19 download validation, 7 download-record, 12 GGUF loadability, 7 GGUF cache, 3 upload-guard, and 3 GGUF structure assertions; targeted diff check; real PS5 recovery and service health.
- Final: both services active; Krea ROCm/HIP gfx1013 ready, active=0, queue empty, HSA free 2.18 GiB, host 5.94 GiB.

Next: inspect Comfy executor/model-patcher cache retention to see if the remaining ~5–11 s recovery initialization can be reduced. Keep the existing memory guards and reserve.

## 2026-11-05 — attention backend and transfer setting audit

- Rejected `--use-split-cross-attention` on real gfx1013: Comfy graph completed but produced a 509-byte black 384x384 image. Removed the temporary drop-in; default sub-quadratic restored. A default-attention control then passed: 47.83 s, 184,995-byte image with nonzero pixel variance.
- `comfy_kitchen` int8 and `sol_attn` availability probes both returned false on gfx1013; installed Q3 GGUF has no attention metadata. No other custom attention route is compatible in the current runtime.
- `GPU_PINNED_MIN_XFER_SIZE=16384` remains configured, but I found no active source/binary-string consumer in Comfy/AIMDO/PyTorch; left unchanged pending more precise origin.
- Active service SDMA is `HSA_ENABLE_SDMA=0`; the Krea result page now clarifies that its initial 2026-11-04 profile used 1 and the later PS5 A/B selected 0.

Next: trace DynamicVRAM/HostBuffer pin and copy policies, and identify the origin/semantics of `GPU_PINNED_MIN_XFER_SIZE`; change only after a controlled PS5 A/B.

## 2026-11-05 — 512x512 coverage and current resource state

- Standard-attention Q3 Turbo4 at 512x512 completed through Studio in 31.60 s API, valid 300,836-byte image. HSA ended at 1.90 GiB, just above the 1.8 GiB guard; did not enqueue another high-resolution run at this margin.
- Split-attention remains rejected (black image) and standard sub-quadratic is restored.

Final live check after 512x512: Studio/Comfy active, Krea ready, tasks/queue empty, HSA 1.90 GiB (guard 1.8), host available 5.68 GiB, reserve 0.5 GiB, SDMA=0; no experimental attention/fast-disk/fp16 flags remain.

## 2026-11-05 — pinning and async-offload optimization check

- Runtime confirms gfx1013/Oberon is integrated: `is_integrated=1`, `DISABLE_PINNED_MEMORY=True`, `MAX_PINNED_MEMORY=-1`, pinned bytes=0. `GPU_PINNED_MIN_XFER_SIZE=16384` has no active consumer and Comfy pinning is disabled; left the service environment untouched.
- A/B of async weight offload: default 2 streams warm runs 21.10/25.94 s (mean 23.52); candidate 3 streams 21.12/27.45 s (mean 24.29), no improvement. Cold post-restart runs were 46.13 s (2) and 49.66 s (3), both valid 384x384 images. Rejected 3 streams.
- Removed the temporary test drop-in; active ExecStart is restored, reserve=0.5 GiB, Comfy logs 2 streams. Backup: `docs/benchmarks/krea2-async-offload-3-stream-20261105T1627Z-before/`.
- Final: Studio/Comfy active, Krea ready, task/queue empty, HSA free 2.18 GiB, host available 5.44 GiB, guard=1.8 GiB. Next: inspect DynamicVRAM/loader warm cache without increasing HSA residency.

## 2026-11-05 — hipBLASLt and warm loader cache follow-up

- Keep `TORCH_BLAS_PREFER_HIPBLASLT=0`: installed hipBLASLt lacks a gfx1013 Tensile table, and a separate process with the preference at 1 emitted PyTorch's unsupported-architecture warning then correctly fell back to hipblas. A 512x512 FP16 matmul completed; Studio/service configuration was unchanged. PyTorch source confirms the variable selects a preferred BLAS backend: https://github.com/pytorch/pytorch/blob/main/aten/src/ATen/Context.h.
- GGUF DynamicVRAM uses mmap-backed `TensorFileSlice`; dynamic patchers store a loader factory in `cached_patcher_init`. The workflow explicitly releases Qwen after text encoding for HSA headroom. Recent warm logs show Qwen loaded only for the first run, while Krea2/VAE receive load requests on repeat jobs. Warm Comfy 20.50/24.94 s; API 21.10/25.94 s.
- Existing task summary had a separate prior Krea error (created 15:36:42Z) and the preserved Civitai HTTP 401. Neither came from the six current runs, whose PNG files all validated; active=0 and Comfy queue empty. Preserve the historic error records.
- Next: inspect model-patcher staging on Krea2/VAE transitions for avoidable work without retaining more HSA memory.

## 2026-11-05 — optional 256x256 Q3 Turbo concept preview

- Benchmarked same prompt/workflow through Studio: 384x384 warm 23.52/24.88 s API (mean 24.20); 256x256 warm 17.43/16.38 s (mean 16.91), ~30% lower warm wall time. First 256 after resolution switch took 27.00 s. All six latest 384/256 outputs are valid PNGs; image quality at 256 has not been scored.
- Added an optional one-click 256x256 Turbo4 concept preview; the original 384x384 preview and defaults are unchanged. `node --check`, static event/setting assertions and live served HTML/JS checks passed.
- Backups: `docs/benchmarks/krea2-256-draft-preset-20261105T1658Z-before/` and `docs/benchmarks/krea2-256-preview-measurements-20261105T1659Z-before/`.
- Final: Krea ready, tasks active=0, Comfy queue empty, host 6.19 GiB available, HSA 1.40 GiB (<1.8 guard). Next guarded Q3 generation will run cache-preserving memory recovery first. No additional generation queued.

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

 
## 2026-11-05 — Krea 2 OpenRouter prompt intelligence integrated

- Implemented POST /api/krea2/prompt-optimize and connected the Krea 2 Generate action to it. OpenRouter is the default provider; the Krea UI has an enable checkbox and a provider selector for OpenRouter or local Qwen Vision. Original prompt remains untouched in the editor and optimized prompt is previewed before it is submitted to the existing Krea2 generate route.
- OpenRouter supports the user's configured preset by slug (model: @preset/<slug>). When a preset slug is set, the request sends only the user prompt, preserving the preset system prompt, model selection/fallback chain, provider routing and sampling settings. If slug is empty, openrouter/free is used with the app's Krea prompt system message.
- Local fallback is the installed Qwen2.5-VL-3B-Instruct Q4_K_M model (text-only request), launched temporarily via llama.cpp on 127.0.0.1:8083, CPU-only, 4 threads, 2048 context. Memory guard: 5.5 GiB available before start and 4 GiB after load; process is terminated after response. Krea's Qwen3-VL 4B CLIP encoder and ROCm graph were not modified. If fallback fails, original prompt is used and generation can continue.
- API key stored in private settings file (0600), never returned by GET; optional preset slug stored separately. Empty API-key input preserves the saved key; explicit clear checkbox removes it. Blank Civitai key input also now preserves the existing Civitai key during settings saves.
- Live local Qwen test returned an improved prompt. Automatic OpenRouter-missing fallback also succeeded with Qwen. Both temporary processes exited; port 8083 closed; ComfyUI queue stayed empty; Krea ROCm remained ready.
- Settings API test confirmed preset slug persistence, API key redaction, explicit clearing, and retained Civitai key configuration. Unit tests: 21 optimizer assertions. Full suite passed: npm syntax, runtime selection 28, Comfy lifecycle 23, safe-file 7, download validation 19, download record 7, GGUF loadability 12, GGUF cache 7, upload guard 3, GGUF structure Python 3, prompt optimizer 21; git diff --check clean.
- Restarted only ps5-ai-studio-linux.service; both Studio and ComfyUI services remain active. No Krea image was generated during implementation; ComfyUI queue remained empty.
- Backup snapshot: docs/benchmarks/krea-prompt-router-20261105T185500Z-before/. Details: docs/KREA2-PROMPT-INTELLIGENCE.md.

Next: user supplies OpenRouter API key and optional preset slug in Settings; then verify a real OpenRouter inference against the selected preset and measure response latency.

## 2026-11-05 — Krea 2 prompt intelligence completion pass

- Closed the UI integration gap: `app.js` imports shared prompt-flow logic, so the page now loads it as an ES module and the server serves `.mjs` with `text/javascript`. Fixed the restore button label to match its actual review-field behavior and re-enabled the one-time-original button when a generation poll finishes.
- Expanded mocked OpenRouter/fallback/security checks from the earlier 21 to 85 optimizer assertions; added 57 prompt-flow/UI assertions. Covered mandatory ZDR/data-collection filters, preset merge, bounded retries, status errors/timeouts, malformed output, fallback order, key redaction, prompt-mode decisions, restore/edit/original selection, UI controls and static serving.
- `npm run check` and every `scripts/test-*.mjs` passed. GGUF structure fixture passed 3 tests using the existing `comfy-rocm-venv`. System Python initially lacked NumPy; no dependency was installed. `git diff --check` passed.
- No GPU image generation and no real OpenRouter request. No key is configured. Live Qwen was not re-run during this pass; the mocked path is covered, but post-change live-provider behavior remains unverified.
- Updated `docs/KREA2-PROMPT-INTELLIGENCE.md` with current flow, privacy semantics, implementation boundaries, verification and official OpenRouter references.
- Before this pass, backup: `docs/benchmarks/krea-prompt-intelligence-audit-20261105T1905Z-before/`. Project files are in `/home/michel/PS5-AI-Studio-Linux`.

Restarted only `ps5-ai-studio-linux.service`; ComfyUI stayed active. Live HTTP checks passed for health, module HTML, `.mjs` MIME and API-key redaction. Browser AX/screenshot verification showed Workflow Studio, Krea status, prompt, Automatic/Approve/Manual selector, provider, skip-once button, generation settings and quick-start controls; browser console had no errors. Krea status reported generationReady=true, active gfx1013 ROCm profile, Comfy queue 0 running/0 pending. No generation was started.


## 2026-11-05 — live OpenRouter key and Qwen fallback verification

- Confirmed the API key is configured through public boolean fields only; no key value was read or returned. A neutral prompt against the default `openrouter/free` reached OpenRouter and returned HTTP 429. Current request handling correctly fell back to local Qwen and returned an improved prompt in 6.55 seconds; the exact account/provider quota cause is unknown.
- The real fallback exposed a runtime-scope defect: `abortChild` was declared inside `try` but used in `finally`. Moved it to the surrounding function scope, added two source regression checks and reran the optimizer tests (86 assertions). The live fallback cleanup then completed: no `llama-server`, port 8083 closed.
- Full regression: 86 optimizer + 57 prompt-flow + existing Node fixtures (106 assertions) passed; GGUF structure fixture 3 passed; syntax and `git diff --check` passed. Krea remains ready on gfx1013, host RAM 7.12 GiB, Comfy queue empty. No GPU generation.
- OpenRouter documents free model request limits and possible provider-level limits; see the free models reference in `docs/KREA2-PROMPT-INTELLIGENCE.md`. No repeat retry was made after the 429.

Next: the local fallback is verified end to end. To use OpenRouter reliably, set a preset slug for an available model/provider; do not repeatedly retry `openrouter/free` while it is rate-limited.


## 2026-11-05 — OpenRouter 429 guidance and final regression

- Made rate-limit feedback actionable: HTTP 429 warns that OpenRouter limited the request, local Qwen was used, and the user can retry later or configure an available preset. HTTP 401 now points to checking the key. No automatic retry for 429.
- Updated tests to 87 optimizer assertions and 57 prompt-flow assertions. Full Node/Python fixture suite passed: existing Node tests 106 assertions and GGUF structure 3. `npm run check` and `git diff --check` clean.
- Restarted only Studio after tests. Key remains configured and redacted; Krea reports ready with active gfx1013 profile; Comfy queue 0/0; Qwen temporary service/port are closed. No additional OpenRouter call or image generation.
- OpenRouter documents free-model request limits and provider-specific limits; the current HTTP 429 cause is not known.


## 2026-11-05 — OpenRouter diagnostic and correct free ZDR catalog

- Added live Settings control “OpenRouter-verbinding testen” backed by GET `/api/v1/key`. Live browser check succeeded and showed 50/50 requests remaining without revealing the API key. This is an auth/account check and does not send a prompt or invoke inference.
- OpenRouter's general model list with `zdr=true` returned false positives for this route: provider endpoint details showed no ZDR endpoint and chat attempts returned 404. Replaced that picker source with `/api/v1/endpoints/zdr`; it currently yields one free text endpoint. Paid IDs are refused; default remains `openrouter/free`, saved model setting reset to that default, and preset still wins.
- Real prompt probes on Free Router and the one currently listed free ZDR model returned 429. Local Qwen fallback returned an improved prompt and exited cleanly. Do not retry repeatedly: actual free-provider capacity is currently limiting inference. Paid requests and privacy relaxation were not used.
- UI verified live: model selector offers default plus the single eligible free ZDR model, connection-check button reports status, no console errors. Full fixtures: optimizer 107, prompt flow 57, existing Node 106, GGUF Python 3; syntax and `git diff --check` pass. Krea ready, Comfy queue 0/0; no image generation.

Next: wait for free ZDR provider capacity or use a user-configured preset whose endpoints satisfy ZDR/data_collection constraints; paid inference remains unused.


## 2026-11-05 — 429 oorzaak vastgesteld en automatische ZDR-routering hersteld

- Live OpenRouter-keycheck slaagt; `/api/v1/key` had eerder 50/50 verzoeken beschikbaar. Eén gecontroleerde completions-probe met `openrouter/free` gaf HTTP 404: geen endpoint voldoet aan de ingestelde Zero Data Retention-policy. De actuele `/endpoints/zdr`-catalogus bevat één gratis tekstmodel dat `max_tokens` ondersteunt: `xingchen-agi/xing4.0-29b-a4b:free` via Phala.
- De gecontroleerde request naar dat model gaf HTTP 429 met `Provider returned error` en provider `Phala`. Dit is een provider-capaciteitslimiet, geen afgewezen API-key. De catalogus en response zijn gecontroleerd met `data_collection=deny` en `zdr=true`; geen betaalde modelaanvraag of privacyversoepeling.
- Aangepast: de automatische `openrouter/free`-keuze resolveert nu naar het eerste gratis, tekstgeschikte model uit de echte ZDR-endpointcatalogus. Preset en handmatig gekozen model blijven leidend. 429-classificatie bewaart alleen status en providernaam (geen prompt of ruwe response) en de gebruikerswaarschuwing noemt de daadwerkelijke providerlimiet. De bestaande automatische Qwen-fallback blijft actief. Selectorcopy verduidelijkt dat automatische keuze uit de ZDR-catalogus komt.
- End-to-end app-POST na Studio-restart gaf HTTP 200 en bruikbare geoptimaliseerde prompt via lokale Qwen; fallbackwaarschuwing meldde Phala 429. Runtime 10,4 s. De cloudaanbieder zelf blijft tijdelijk 429 geven; die upstream capaciteit kunnen we niet op de client afdwingen.
- Validatie: optimizer 108 assertions, prompt flow 57 assertions, `node --check` voor server/optimizer/UI en `git diff --check` geslaagd. Krea status generationReady=true. Geen Krea GPU/image-generatie gestart. Back-ups van de vijf aangepaste bron/testbestanden staan naast de bestanden met suffix `.pre-429-zdr-routing-<UTC timestamp>`.


## 2026-11-05 — OpenRouter working, ZDR paused at user's request

- User asked to temporarily drop ZDR. Removed request `provider.zdr`; retained `data_collection="deny"`, free-only routing/selection, API-key secrecy, fallback and prompt safeguards. The UI explicitly says ZDR is temporarily off and explains prompts leave the PS5; no zero-retention claim. Account-level guardrails may still require it.
- Replaced `/endpoints/zdr` selector with `/models` filtering: `:free`, zero prompt/completion price, text input/output, `max_tokens`. Live catalog: 12 free text models. Auto selection remains OpenRouter's `openrouter/free`.
- Direct real free-model probe succeeded via Cohere (HTTP 200, reported cost 0). Live app POST succeeded via OpenRouter using `cohere/north-mini-code:free`, returned a nonempty improved prompt, and did not fall back to Qwen. No paid request or Krea image generation.
- Tests: optimizer 107 assertions, prompt flow 57, syntax checks and `git diff --check` passed. Studio service restarted and remains active.


## 2026-11-05 — stale Krea 2 generation indicator corrected

- User reported repeated “Krea 2 generation already running” while no image/task was visible. `/api/tasks` showed a tracked Krea job in `running`, but ComfyUI `/queue` had no running or pending entries. Refreshing its job history showed it had actually completed; the completed image (`1793910159334-krea2-046bab38.png`, 385,168 bytes) was imported into the Studio image gallery. The task list then reported active=0.
- Root cause: Studio retained the in-memory job state unless the browser continued polling that exact job ID. After a page interruption/reload, the duplicate-generation guard trusted the stale `running` state.
- Fix: added a deduplicated `refreshTrackedKreaJobs()` reconciler. `/api/tasks` refreshes active tracked Krea jobs against ComfyUI history/queue before showing them, and the generation route refreshes them before rejecting a new request. A truly running job remains protected; completed, failed, or disappeared jobs no longer block forever, and completed outputs are imported through the existing status path.
- Regressions: Comfy lifecycle/task assertions 25, prompt optimizer 107, prompt flow 57; `npm run check`, all Node fixture scripts, and `git diff --check` passed. Studio service restarted and is active; `/api/tasks` now reports no active Krea job; completed image is present in gallery.


## 2026-11-05 — automatic prompt preview always visible

- Changed automatic mode to display the original and optimized prompts side by side after optimization. The improved prompt stays visible during GPU setup, generation, and completion; automatic mode continues without requiring an approval click. Manual/approve retain their existing review actions. The one-time original path remains available.
- Added a visual state label and hides review action buttons only for automatic preview to prevent accidental duplicate generation; prompt fields remain read-only in that mode.
- Prompt-flow checks: 60 assertions; optimizer checks: 107; JS syntax and `git diff --check` passed. Studio service restarted and is active.


## 2026-11-06 — Qwen3.5 memory planner follow-up

- Implemented exact GGUF per-block tensor inventory and Qwen3.5 hybrid cache accounting. Defiant 9B: 32 active blocks + 1 ignored MTP, 8 full attention, 24 recurrent; Q8_0/4096 gives 68.0 MiB KV + 50.2 MiB recurrent state.
- `n_gpu_layers=31` loaded and ran a 96-token smoke test (the token limit ended it during reasoning), but GTT free dropped to ~638 MiB, below the 700 MiB safety threshold. Reverted automatically to `n_gpu_layers=30`; final inference returned a complete answer and GTT free was ~876 MiB. Active model is running at 30; UI mapping is 28/32 active blocks on GPU + output, 4 active blocks on CPU, MTP ignored.
- Auto planner now uses tensor inventory, output weight, GPU-resident hybrid caches, 900 MiB measured Vulkan/workspace allowance and 700 MiB safety headroom. ComfyUI stayed stopped and was not interrupted.
- `npm run check`, `git diff --check`, GGUF loadability/cache, runtime-selection, and safe-file-ops fixtures passed. Backups use suffix `.pre-qwen35-hybrid-memory-20261106T175015Z`.
