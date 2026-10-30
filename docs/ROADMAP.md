# Linux porting roadmap

## Phase 0 — repository and platform contract
- [x] Establish a separate Linux repository and identity.
- [x] Document PS5/Linux boundaries and runtime principles.
- [x] Add safe host diagnostics and dependency bootstrap.
- [ ] Confirm target Linux machine, distribution, GPU and available RAM/VRAM.

## Phase 1 — Linux foundation
- [ ] Add CMake/Ninja project and CI source checks.
- [ ] Implement XDG paths, structured logging and config.
- [ ] Implement hardware diagnostics (CPU, RAM, disks, Vulkan devices).
- [ ] Add process supervisor with lifecycle tests.
- [ ] Add loopback-only API with authentication model.

## Phase 2 — text inference
- [ ] Pin upstream llama.cpp.
- [ ] Build CPU backend first, then GGML Vulkan.
- [ ] Add model discovery, metadata and safe download/resume.
- [ ] Add memory/context fit estimator based on host RAM and GPU heaps.
- [ ] Add OpenAI-compatible chat endpoint and streaming tests.

## Phase 3 — image generation
- [ ] Pin stable-diffusion.cpp and its matching GGML revision.
- [ ] Build Vulkan backend independently.
- [ ] Add separate image checkpoint/LoRA/ControlNet catalog.
- [ ] Add async jobs, cancellation, progress and output gallery.
- [ ] Add explicit text/image GPU memory handoff.

## Phase 4 — product UI
- [ ] Port the browser UI from PS5 AI Studio, replacing platform-specific API calls.
- [ ] Add Linux dashboard, model library, settings, diagnostics and logs.
- [ ] Add responsive desktop/tablet layout and accessibility checks.
- [ ] Add secure LAN access and API token management.

## Phase 5 — packaging and release
- [ ] Add Ubuntu/Debian build and install scripts.
- [ ] Add opt-in systemd user service and clean uninstall.
- [ ] Add AppImage/deb packaging after runtime paths stabilize.
- [ ] Run clean-machine smoke tests and GPU validation.
- [ ] Publish versioned releases with checksums.

## Non-goals
No PS5 title IDs, native console UI SDK, ShadowMountPlus, FTP deployment, PS5 payloads or console-specific memory assumptions. No automatic host GPU driver/kernel changes. No unauthenticated internet-facing management interface.
