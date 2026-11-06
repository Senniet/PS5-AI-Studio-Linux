# OpenAI-compatible API

PS5 AI Studio exposes an authenticated OpenAI-compatible API through its existing web server. The API uses the same GGUF model library, model loader, memory planning and single `llama.cpp` text runtime as the built-in AI Chat. It does not start a second model server.

## Connection

- Base URL: `http://192.168.2.210:8787/v1`
- Models: `GET /v1/models`
- Chat: `POST /v1/chat/completions`
- Authentication: `Authorization: Bearer <API key>`
- API key file on the PS5 Linux host: `~/.config/ps5-ai-studio-linux/api-token` (permissions `0600`)

Use the model ID returned by `/v1/models`, for example `ps5ai/Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf`. A request selecting a different model switches the AI Studio text runtime using its normal validation and memory checks. Requests without a model use the currently loaded text model.

## Example

```bash
API_KEY="$(cat ~/.config/ps5-ai-studio-linux/api-token)"
curl http://192.168.2.210:8787/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"ps5ai/Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf","messages":[{"role":"user","content":"Hello"}],"stream":true}'
```

Streaming and non-streaming chat completions are supported. Common generation parameters and tool/function declarations are forwarded to `llama.cpp`; actual tool execution depends on the selected model's chat template and the client that receives tool calls. The API is intended for trusted LAN clients; keep the key private and do not expose port 8787 directly to the public internet.
