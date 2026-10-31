# PS5 AI Studio Linux

A standalone Linux edition of PS5 AI Studio for Ubuntu running directly on PS5 hardware. This repository is intentionally separate from [PS5-AI-Studio](https://github.com/Senniet/PS5-AI-Studio), which targets the native PlayStation 5 title.

## Current status

The Linux host has been validated on Ubuntu 26.04.1 with kernel 7.3.0-PinkSoup, AMD Oberon/RADV Vulkan, llama.cpp Vulkan and stable-diffusion.cpp Vulkan builds. A first read-only browser dashboard is now available with live CPU, RAM, GPU/TTM and runtime diagnostics.

The dashboard is intentionally local-only for this first milestone. It does not yet manage models, start or stop inference engines, download checkpoints, or expose the host to the LAN.

## Platform boundaries

| Concern | PS5 AI Studio | PS5 AI Studio Linux |
|---|---|---|
| Runtime | Native PS5 title | Linux processes/services |
| GPU | PS5_Vulkan / PS5 RADV port | System Vulkan loader + Mesa RADV |
| Text engine | PS5-patched llama.cpp | Upstream llama.cpp / GGML Vulkan |
| Image engine | PS5-patched stable-diffusion.cpp | Linux stable-diffusion.cpp / GGML Vulkan |
| Storage | PS5 title/data paths | XDG data/config/state directories |
| Deployment | PPSA99731 / console FTP | Linux packages/systemd |
| Hardware | PS5 SoC | Linux CPU/GPU/RAM/storage |

## Quick start

Requires Node.js 22 or newer:

```bash
npm run check
npm start
```

Open http://127.0.0.1:8787 on the Linux desktop. To install the user service, copy `packaging/systemd/ps5-ai-studio-linux.service` to `~/.config/systemd/user/`, then run `systemctl --user daemon-reload && systemctl --user enable --now ps5-ai-studio-linux.service`.

## Project layout

```text
apps/server/                 Linux diagnostics/API service
apps/web/                    Browser dashboard
runtime/text/                llama.cpp integration (planned)
runtime/image/               stable-diffusion.cpp integration (planned)
platform/linux/              XDG paths, process control and host probes (planned)
scripts/                     host setup and diagnostics
tests/                       smoke and integration tests (planned)
docs/                         architecture, hardware and runtime notes
packaging/systemd/            user service template
```

## Security

The first dashboard binds only to 127.0.0.1. It exposes read-only health and diagnostics endpoints; it does not expose arbitrary shell execution, unrestricted file access, model downloads or process control. LAN access must remain disabled until authenticated sessions, API authorization and path validation are implemented.

## License and attribution

The PS5 project is GPL-3.0-or-later and incorporates upstream projects with their own licenses. Preserve notices and verify compatibility before copying source files, patches, assets or dependencies.
