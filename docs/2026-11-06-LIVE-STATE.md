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
- Local branch: `linux-main`; local HEAD at inspection: `b23128fc8b4481db3579c14f1702c867b1e9f519`.
- The local history contains 147 commits from a local root commit that is not present in the GitHub repository.
- GitHub currently has `main` and `feature/linux-web-dashboard`; there is no remote `linux-main` branch.
- The local working tree has 12 modified tracked files and 298 untracked paths at inspection. Many untracked paths are timestamped `.pre-*` safety snapshots; they are not intended as normal Git source files.
- `npm run check` passes. GitHub publication must use an explicit snapshot/branch strategy; do not force-push the unrelated local history over the existing GitHub branches.

## Backup scope

The project archive should preserve the local Git history and current working tree, including uncommitted source and documentation. Runtime environments, model assets and generated outputs are kept as local runtime state and may make the archive substantially larger; list any exclusions explicitly in the archive manifest. Never include API keys, credentials, `.env` files or private SSH material.