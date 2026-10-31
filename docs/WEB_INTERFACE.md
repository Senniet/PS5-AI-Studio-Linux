# Linux web interface

The Linux-only web UI is served by a small dependency-free Node.js service.

## Network access

The service listens on `0.0.0.0:8787`, so it accepts IPv4 connections on all host interfaces. On the current PS5 Linux host (`192.168.2.210/24`), open:

`http://192.168.2.210:8787`

The browser prompts for HTTP Basic Authentication:
- Username: `admin`
- Password: stored privately on the host in `~/.config/ps5-ai-studio-linux/auth.env`

The credential file is mode 0600 in a mode 0700 directory and is not committed to Git. Configure a unique password of at least 24 characters. The service rejects startup when the password is missing or too short.

**Network security:** this development service uses HTTP, so Basic Authentication credentials and chat traffic are not encrypted in transit. Use it only on a trusted private LAN. Do not configure router port forwarding or expose port 8787 directly to the public internet. For remote access, use a VPN or put a TLS-terminating authenticated reverse proxy in front. The host currently has no UFW or nftables command installed; verify any upstream VLAN/router rules separately.

Ollama is a separate service. Its current systemd override sets `OLLAMA_HOST=0.0.0.0:11434`, which exposes the Ollama API independently of this web login. Do not assume the web UI's Basic Auth protects port 11434. Review whether other LAN clients rely on that direct Ollama access before changing it.

## Text model library

- List local Ollama models with size, family, quantization and loaded state.
- Download from the Ollama library with streamed per-layer progress.
- Cancel a download; Ollama documents that cancelled pulls resume from their previous progress on the next pull request.
- Delete a local model after confirmation; deleting a currently loaded model is blocked until it is stopped.
- Non-streaming local chat through Ollama.

## Image model library

Image checkpoints are scanned in:

`~/.local/share/ps5-ai-studio/models/image/checkpoints`

The scanner currently recognizes `.safetensors`, `.ckpt` and `.gguf` files and displays their sizes and modification dates. Separate directories are prepared for VAE, CLIP and LoRA assets. No image checkpoint was present on the PS5 during the 2026-10-31 scan, so image generation is not yet enabled or tested. The built `stable-diffusion.cpp` server supports local API routes for txt2img and img2img; integration follows after a compatible checkpoint is available.

## Security and service

- Basic Authentication on all routes.
- Bounded JSON body parsing, request timeouts and header limits.
- Static path traversal protection.
- Systemd user service with a private environment file.

Create `~/.config/ps5-ai-studio-linux/auth.env` with:

```ini
WEB_USER=admin
WEB_PASSWORD=use-a-long-random-secret-of-at-least-24-characters
```

Protect it:

```bash
chmod 700 ~/.config/ps5-ai-studio-linux
chmod 600 ~/.config/ps5-ai-studio-linux/auth.env
```

Then reload and restart the user service:

```bash
systemctl --user daemon-reload
systemctl --user restart ps5-ai-studio-linux.service
```

The service remains separate from the native Prospero application.