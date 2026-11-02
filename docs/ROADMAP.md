# PS5 AI Studio Linux roadmap

Last updated: 2026-11-02

This roadmap reflects the running Linux application on the PS5 hardware, not the original native Prospero project.

## Completed foundation

- [x] Separate Linux repository and platform boundary from the native PS5 application.
- [x] Ubuntu host diagnostics, Vulkan/RADV detection and dependency/bootstrap scripts.
- [x] Node.js web/API service, responsive browser dashboard, model library, model shop, settings, diagnostics and logs.
- [x] llama.cpp text/vision chat with streaming, conversations, model discovery/downloads, GGUF metadata and KV-cache planning.
- [x] stable-diffusion.cpp image runtime with Vulkan image generation, image-to-image, masked inpainting, gallery and cancellable jobs.
- [x] Image asset library for checkpoints, VAE, LoRA, CLIP, ControlNet, IP-Adapter, CLIP Vision and upscalers.
- [x] Resumable downloads with queue persistence, duplicate-target protection, range validation and SHA-256 checks where available.
- [x] ComfyUI as an optional workflow service, with a PS5 AI Studio bridge for supported image operations.
- [x] Native Video Studio using stable-diffusion.cpp / ggml-Vulkan, dedicated video model folders, Wan 2.1 T2V 1.3B Q4 profile, async jobs, cancellation and local WebM gallery.
- [x] Real Wan 2.1 Vulkan smoke generation and separate GStreamer VP9/WebM concatenation test.

## Active development

- [ ] Validate complete multi-segment native video generation end-to-end at progressively longer durations.
- [ ] Implement temporal continuity between segments (final-frame handoff, latent continuation or a compatible video-extension model); do not treat simple concatenation as continuity.
- [ ] Add and validate a native image-to-video profile with all required companion models.
- [ ] Improve GPU memory preflight using measured peak memory, model component placement and resolution/frame estimates.
- [ ] Add robust video job recovery, artifact validation and failure cleanup.
- [ ] Validate video interpolation, video upscaling and audio generation/muxing before exposing them as ready features.

## Reliability and release work

- [ ] Add automated API and browser smoke tests alongside the existing syntax check.
- [ ] Exercise clean install, service restart, interrupted downloads and interrupted generation.
- [ ] Verify every model catalog entry, companion file, source license and expected file size.
- [ ] Add a documented release/install/update workflow and reproducible runtime build notes.
- [ ] Keep CI checks aligned with the current Node.js application and Linux shell scripts.

## Non-goals

- No native Prospero SDK, title IDs, console payloads, FTP deployment or native PS5 application changes.
- No automatic changes to the host GPU driver, kernel or boot-memory configuration.
- No unauthenticated public-internet exposure of the management UI or inference services.
