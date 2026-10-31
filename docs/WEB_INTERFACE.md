# Linux web interface — first milestone

This first milestone adds a dependency-free Node.js dashboard for the PS5's separate Ubuntu Linux installation.

## Run

```bash
npm run check
npm start
```

Open http://127.0.0.1:8787 on the Linux desktop.

## Scope

- Loopback-only HTTP listener.
- Read-only health and diagnostics API.
- CPU, kernel, RAM/swap, AMDGPU VRAM/GTT and TTM values.
- Detection of Ollama, llama.cpp and stable-diffusion.cpp binaries/processes.
- Responsive overview and diagnostics views.

## Security and limitations

The service does not expose shell execution, arbitrary file access, model downloads, process control or LAN access. Model and image management are intentionally not presented as functional controls yet. The next milestone should add authenticated API sessions, configured model roots, safe process supervision and separate text/image runtime adapters.

The dashboard reads Linux host data only. It does not call or modify the native Prospero application.