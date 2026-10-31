# Linux web interface — first milestone

This milestone adds a dependency-free Node.js dashboard and a first local text-chat path for the PS5's separate Ubuntu Linux installation.

## Run

```bash
npm run check
npm start
```

Open http://127.0.0.1:8787 on the Linux desktop. The optional user service template is in `packaging/systemd/ps5-ai-studio-linux.service`.

## Implemented

- Loopback-only HTTP listener.
- Read-only health and diagnostics API.
- CPU, kernel, RAM/swap, AMDGPU VRAM/GTT and TTM values.
- Detection of Ollama, standalone llama.cpp and stable-diffusion.cpp binaries/processes.
- Responsive overview and hardware diagnostics views.
- Installed Ollama model list, including family, parameter size, quantization and disk size.
- Local chat through Ollama's `/api/chat` endpoint.
- Chat requests are restricted to installed model names and user/assistant messages; context is initially capped at 4096 tokens and output at 1024 tokens.
- Dashboard refreshes hardware diagnostics once per minute.

## Smoke test on PS5

- Ubuntu 26.04.1, kernel 7.3.0-PinkSoup, AMD Oberon/RADV.
- Ollama model `qwen3:8b-16k`, Q4_K_M, loaded with 100% GPU offload.
- Local chat request returned the expected `OK.` response.
- Context reported by Ollama: 4096 tokens.
- During the loaded test, GTT use was about 5.49 GiB; Linux still reported about 7.05 GiB available RAM and no swap use.
- This is a functional smoke test, not a performance benchmark.

## Security and limitations

The service does not expose shell execution, arbitrary file access, model downloads, process control or LAN access. It binds to 127.0.0.1 only. Chat is currently non-streaming and uses Ollama; standalone llama.cpp and image generation are not yet wired into the UI. Model and image download/management are not implemented yet.

The dashboard reads Linux host data only. It does not call or modify the native Prospero application.