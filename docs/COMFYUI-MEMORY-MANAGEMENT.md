# ComfyUI model memory management

PS5 AI Studio uses ComfyUI as a persistent workflow service for Krea 2 and other ComfyUI workflows. The service intentionally remains running between generations, but model weights must not remain resident after the user has finished with the image engine.

## Runtime visibility

`GET /api/runtime` includes a `comfy` snapshot alongside the standalone runtime state. It reports ComfyUI PID/RSS, queue state, GPU pool usage/free bytes, and model weight files that are still open by the ComfyUI process. This prevents the standalone `image.state` value from being mistaken for ComfyUI model residency.

## Explicit release

`POST /api/runtime/image/unload` calls ComfyUI's `/free` endpoint with `unload_models: true` and `free_memory: true`. It first verifies that both the running and pending queues are empty. If work is queued or running, it returns HTTP 409 and does not interrupt it. The ComfyUI service is not restarted. The response includes before/after GPU usage and whether memory release was confirmed.

The Image Studio button **Geheugen vrijgeven** invokes this endpoint. It is enabled whenever ComfyUI is reachable, even if the standalone image runtime reports `stopped`.

## Model switching

Loading a different image model first releases ComfyUI model residency, but only after validating the selected model and required assets. A busy ComfyUI queue blocks the switch rather than interrupting another workflow. The existing Qwen prompt-optimization path continues to use its own GPU exclusivity and ComfyUI release checks.

## Why release is explicit

Krea 2 users may generate several images in sequence. Automatically unloading after every successful generation would force expensive model reloads between images. The user therefore releases memory when finished; model switches also release stale residency automatically.
