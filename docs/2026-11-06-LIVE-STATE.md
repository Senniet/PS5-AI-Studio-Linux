# PS5 AI Studio Linux — live-state and recovery note

**Snapshot:** 2026-11-06, after the PS5 Linux host rebooted following an interrupted Vulkan image-engine smoke test.

## Host and runtime state

- Host: `ps5-linux`; Ubuntu 26.04; PS5 Oberon APU, PCI ID `1002:13fb`, RADV `gfx1013`, 36 active CUs.
- Kernel: `7.3.0-PinkSoup`.
- The current boot completed successfully and the Termalin/desktop remote agent reconnected.
- Both user services are active after reboot:
  - `ps5-ai-studio-linux.service`
  - `ps5-ai-studio-comfyui.service`
- ComfyUI is running from the isolated `runtimes/comfy-rocm-venv` and uses the ROCm/HIP gfx1013 configuration. Its active options include DynamicVRAM, FP8 text-encoder mode, FP16 weights/intermediates and a 0.5 GiB reserve.
- The previous documented TTM configuration is `ttm.pages_limit=4063232` (~15.5 GiB allocator limit). This is an allocator ceiling, not additional physical memory.
- The project API syntax check (`npm run check`) passed after reboot.

## Vulkan Krea 2 smoke test — interrupted, not validated

A standalone `stable-diffusion.cpp` Vulkan smoke test was started using:

- Krea 2 Turbo Q3_K_M diffusion GGUF
- Qwen3VL 4B Q4_K_M encoder
- Wan 2.1 VAE
- Vulkan0 / PS5 Oberon
- 512×512, 8 steps, Euler, fixed seed

The CLI initialized Vulkan and prepared the encoder, diffusion weights and VAE. The PS5 then crashed/rebooted before the command returned a successful completion. The expected PNG was not present after reboot. Therefore:

- No successful image generation is claimed.
- No timing or quality result is recorded.
- The Vulkan Krea 2 route remains **unverified** on this build.
- Do not automatically rerun this full test. First inspect the stable-diffusion.cpp logs, current memory headroom and kernel/GPU health, then choose a lower-risk smoke profile.

The current boot's service checks show both application services active. The available post-reboot kernel log excerpt did not establish the exact cause of the previous crash; it must not be labelled as a proven OOM or Vulkan device-loss event.

## Git and publication state at this snapshot

- Local checkout: `/home/michel/PS5-AI-Studio-Linux`.
- Local branch: `linux-main`; the original inspection HEAD was `b23128fc8b4481db3579c14f1702c867b1e9f519`.
- The local `linux-main` history contains 147 commits from a local root commit that is not part of GitHub's existing history. The local history was not force-pushed or rewritten.
- The current working-tree snapshot was published through PR [#1](https://github.com/Senniet/PS5-AI-Studio-Linux/pull/1) and merged into GitHub `main` on 2026-11-06. Merge commit: `f93f26256bc38a59fada84c4c4a3f58d6ed6778f`.
- The published snapshot contains 187 text/source/documentation files. Local timestamped `.pre-*` safety snapshots, runtime environments/model caches, build outputs, firmware binary blobs and binary license PDFs were intentionally kept out of GitHub; they remain in the local backup archive.
- Validation after the sync: `npm run check`, `git diff --check`, all 13 `scripts/test-*.mjs` tests, and shell syntax checks passed. Two stale tests were aligned with the current ComfyUI model-release flow and prompt-safety rules.
- The ZIP backup preserves the local `.git` directory and its 147-commit history; this history remains distinct from the GitHub `main` history.

## Backup scope

The project archive includes the full project directory, local `.git` history, current working tree, timestamped safety snapshots, runtime checkouts/environments, bundled ComfyUI model assets and build outputs. It excludes credentials and private key material, cache/bytecode directories and logs. The separate user model/data/config directories under `~/.local/share/ps5-ai-studio` and `~/.config/ps5-ai-studio-linux` are outside the project and are not part of this archive. Never include API keys, credentials, `.env` files or private SSH material.
