# PS5 AI Studio Linux — technical optimization plan

Updated: 2026-11-06

## Latest operational status (2026-11-06)
The PS5 rebooted during a standalone stable-diffusion.cpp Vulkan Krea 2 smoke test. The test did not produce its expected PNG and is recorded as interrupted/unverified; no OOM or Vulkan root cause is confirmed. After reboot, the Studio and ComfyUI user services are active and `npm run check` passes. Do not rerun the same Vulkan profile without first reviewing memory headroom and host/kernel health. Full details: `docs/2026-11-06-LIVE-STATE.md`.

## Objective
Improve practical speed, memory use, reliability and capability on the installed PS5 (AMD Oberon/gfx1013) while preserving the working system and keeping changes reversible.

## Guardrails
- Measure on the actual host; do not infer compatibility from generic AMD guidance.
- Preserve the existing dirty working tree and user/model data.
- Back up files before code/config changes; change one major variable at a time.
- Do not alter kernel, Mesa, ROCm, PyTorch, boot, firewall or listener configuration without a concrete case and recovery plan.
- Do not interrupt active image/text jobs. Check queue/runtime state before experiments.
- Keep measured performance separate from quality conclusions.

## Phases and acceptance
1. **Inventory and baseline** — capture hardware/runtime, app architecture, installed models/nodes/services and risks. Acceptance: current baseline and live service state documented.
2. **Benchmark and bottleneck analysis** — repeat image and text profiles with fixed settings; separate cold/warm/cache effects and capture RAM/GTT/swap. Acceptance: reproducible measurements with outputs/log evidence.
3. **Targeted optimization** — select the highest-value verified bottleneck; backup, implement one reversible change, run focused syntax/integration checks and PS5 validation. Keep only if reliability or measured outcome improves.
4. **Krea2 / ComfyUI** — verify GGUF and Safetensors routes, adapter compatibility/chaining, dynamic discovery, memory guards, output quality, and model reuse.
5. **Text Studio** — compare projector and text-only models, CPU/GPU layer settings, context/KV-cache options, startup and generation throughput within memory budget.
6. **Application reliability/security** — audit API validation, downloads/files, job lifecycle, frontend error recovery and network exposure. Do not change access boundaries until intended reachability is known.
7. **Expansion and final verification** — classify video/audio/vision capabilities by feasibility; retest Studio, ComfyUI, Text and Image Studio; record remaining issues and rollback paths.

## Current phase
Phase 6, application reliability. The cache-disabled llama.cpp projector comparison, bounded Ollama CPU smoke, and read-only Text Studio integration audit are complete. The draft-only Qwen3.8 GGUF is now conservatively blocked in the Studio catalog and load route; evidence and heuristic limits are recorded in KNOWN-ISSUES.md and OPTIMIZATION-LOG.md. Continue the file-transfer/API validation audit without changing network exposure.

## Next action
The active ComfyUI service is now confirmed on the isolated ROCm/HIP gfx1013 venv; Krea 2 generation history and the reproducible Q3/Sickrealism results are documented. Image loader selection guards are fixture- and API-verified. Continue the ComfyUI workflow/API and task-reporting audit, clarify stale model-template requirements, and use existing benchmark evidence before deciding on another inference run. Keep network exposure and the dirty tree unchanged.
