# PS5 AI Studio Linux

A standalone Linux desktop/server edition of PS5 AI Studio. This repository is intentionally separate from [PS5-AI-Studio](https://github.com/Senniet/PS5-AI-Studio), which targets the native PlayStation 5 title.

## Goals
- Reuse platform-neutral product concepts and browser UI ideas where practical.
- Run on standard Linux with AMDGPU/RADV/Vulkan, while retaining CPU fallback.
- Keep text inference and image generation as separate, explicitly managed runtimes.
- Support local GGUF model discovery, downloads, fit estimates, logs and diagnostics.
- Provide a browser-based management UI and OpenAI-compatible text API.
- Never import PS5-only SDKs, title IDs, payload deployment, or console-specific paths.

## Platform boundaries

| Concern | PS5 AI Studio | PS5 AI Studio Linux |
|---|---|---|
| Runtime | Native PS5 title | Linux processes/services |
| GPU | PS5_Vulkan / PS5 RADV port | System Vulkan loader + Mesa RADV |
| Text engine | PS5-patched llama.cpp | Upstream llama.cpp / GGML Vulkan |
| Image engine | PS5-patched stable-diffusion.cpp | Linux stable-diffusion.cpp / GGML Vulkan |
| Storage | PS5 title/data paths | XDG data/config/state directories |
| Deployment | PPSA99731 / console FTP | Linux packages/scripts/systemd |
| Hardware | PS5 SoC | Linux CPU/GPU/RAM/storage |

## Current status
The Linux repository was created empty. This first commit establishes the platform contract, host diagnostics and dependency bootstrap. It does **not** yet contain the PS5 web UI or inference engines. Those will be ported deliberately after the Linux runtime contract and tests are in place.

## Quick start
On Ubuntu 24.04/26.04 or a compatible Debian-based distribution:

```bash
git clone https://github.com/Senniet/PS5-AI-Studio-Linux.git
cd PS5-AI-Studio-Linux
bash scripts/check-linux-host.sh
sudo bash scripts/bootstrap-ubuntu.sh
bash scripts/detect-gpu.sh
```

The bootstrap installs build tools and Vulkan development/runtime utilities. It does not download model weights, compile engines, change GPU drivers, or modify system services.

## Planned layout
```text
apps/server/                 Linux management/API service
apps/web/                    Browser UI
runtime/text/                llama.cpp integration
runtime/image/               stable-diffusion.cpp integration
platform/linux/              paths, process control, hardware probes
scripts/                     host setup and diagnostics
tests/smoke/                  smoke tests
docs/                         architecture and porting notes
```

## Security
The management API must default to loopback binding. LAN access must be an explicit setting, with authentication before exposing model, filesystem or process controls. Do not port the unauthenticated PS5 management listener unchanged.

## License and attribution
The PS5 project is GPL-3.0-or-later and incorporates upstream projects with their own licenses. Before copying source files, patches, assets or dependencies, preserve their notices and verify compatibility. This repository's initial scripts and documentation are provided under GPL-3.0-or-later; see [LICENSE](LICENSE).
