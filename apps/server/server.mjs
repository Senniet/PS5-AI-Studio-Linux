import http from "node:http";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../web");
const HOST = "127.0.0.1";
const PORT = Number(process.env.PORT || 8787);
const OLLAMA = "http://127.0.0.1:11434";
const MIME = { ".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".svg": "image/svg+xml" };

function readNumber(file) {
  try { return Number(fs.readFileSync(file, "utf8").trim()); } catch { return null; }
}
function memInfo() {
  const values = {};
  try {
    for (const line of fs.readFileSync("/proc/meminfo", "utf8").split("\n")) {
      const match = line.match(/^(MemTotal|MemAvailable|SwapTotal|SwapFree):\s+(\d+)/);
      if (match) values[match[1]] = Number(match[2]) * 1024;
    }
  } catch {}
  return {
    total: values.MemTotal ?? os.totalmem(),
    available: values.MemAvailable ?? os.freemem(),
    swapTotal: values.SwapTotal ?? 0,
    swapFree: values.SwapFree ?? 0
  };
}
function gpuInfo() {
  const base = "/sys/class/drm/card0/device";
  const vram = readNumber(path.join(base, "mem_info_vram_total"));
  const gtt = readNumber(path.join(base, "mem_info_gtt_total"));
  const gttUsed = readNumber(path.join(base, "mem_info_gtt_used"));
  const ttm = readNumber("/sys/module/ttm/parameters/pages_limit");
  const pagePool = readNumber("/sys/module/ttm/parameters/page_pool_size");
  let name = "GPU niet gedetecteerd";
  try {
    const uevent = fs.readFileSync(path.join(base, "uevent"), "utf8");
    const pci = uevent.match(/PCI_ID=([0-9a-fA-F:]+)/)?.[1];
    if (pci?.toLowerCase() === "1002:13fb") name = "AMD Custom Zen 2 (Oberon)";
    else if (pci) name = `AMD GPU (${pci})`;
  } catch {}
  return { name, vram, gtt, gttUsed, ttmPages: ttm, pagePool };
}
function runningProcesses() {
  const home = os.homedir();
  const llamaBinary = path.join(home, "llama.cpp/build/bin/llama-server");
  const sdBinary = path.join(home, "ai-runtimes/stable-diffusion.cpp/build-vulkan/bin/sd-server");
  const found = { ollama: false, llamaCpp: false, stableDiffusion: false };
  try {
    for (const entry of fs.readdirSync("/proc")) {
      if (!/^\d+$/.test(entry)) continue;
      let cmd = "";
      try { cmd = fs.readFileSync(`/proc/${entry}/cmdline`, "utf8").replaceAll("\0", " "); } catch { continue; }
      if (cmd.includes("ollama serve")) found.ollama = true;
      if (cmd.includes(llamaBinary)) found.llamaCpp = true;
      if (cmd.includes(sdBinary)) found.stableDiffusion = true;
    }
  } catch {}
  return found;
}
function diagnostics() {
  const mem = memInfo();
  const gpu = gpuInfo();
  const processes = runningProcesses();
  const home = os.homedir();
  const llama = path.join(home, "llama.cpp/build/bin/llama-server");
  const sd = path.join(home, "ai-runtimes/stable-diffusion.cpp/build-vulkan/bin/sd-server");
  return {
    host: { hostname: os.hostname(), platform: os.platform(), release: os.release(), uptime: os.uptime(), cpus: os.cpus().length, cpuModel: os.cpus()[0]?.model || "Unknown" },
    memory: { ...mem, used: mem.total - mem.available },
    gpu,
    runtimes: {
      ollama: { installed: fs.existsSync("/usr/local/bin/ollama") || processes.ollama, running: processes.ollama, endpoint: OLLAMA },
      llamaCpp: { installed: fs.existsSync(llama), running: processes.llamaCpp, binary: llama },
      stableDiffusion: { installed: fs.existsSync(sd), running: processes.stableDiffusion, binary: sd }
    },
    timestamp: new Date().toISOString()
  };
}
async function readJson(req, maxBytes = 1_000_000) {
  const chunks = [];
  let size = 0;
  let tooLarge = false;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > maxBytes) tooLarge = true;
    else chunks.push(chunk);
  }
  if (tooLarge) throw Object.assign(new Error("Request body too large"), { status: 413 });
  try { return JSON.parse(Buffer.concat(chunks).toString("utf8")); }
  catch { throw Object.assign(new Error("Invalid JSON"), { status: 400 }); }
}
async function getModels() {
  const response = await fetch(`${OLLAMA}/api/tags`, { signal: AbortSignal.timeout(4000) });
  if (!response.ok) throw new Error(`Ollama returned HTTP ${response.status}`);
  const data = await response.json();
  return (data.models || []).map((model) => ({
    name: model.name,
    size: model.size,
    family: model.details?.family || "unknown",
    parameters: model.details?.parameter_size || "—",
    quantization: model.details?.quantization_level || "—"
  }));
}
function send(res, status, body, type = "application/json; charset=utf-8") {
  res.writeHead(status, { "Content-Type": type, "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" });
  res.end(type.startsWith("application/json") ? JSON.stringify(body) : body);
}
const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${HOST}:${PORT}`);
    if (req.method === "GET" && url.pathname === "/api/health") return send(res, 200, { ok: true, service: "PS5 AI Studio Linux" });
    if (req.method === "GET" && url.pathname === "/api/diagnostics") return send(res, 200, diagnostics());
    if (req.method === "GET" && url.pathname === "/api/models") {
      try { return send(res, 200, { models: await getModels() }); }
      catch (error) { return send(res, 503, { error: "Ollama is niet bereikbaar", detail: error.message }); }
    }
    if (req.method === "POST" && url.pathname === "/api/chat") {
      const body = await readJson(req);
      if (!body || typeof body.model !== "string" || !Array.isArray(body.messages) || body.messages.length < 1 || body.messages.length > 24) {
        return send(res, 400, { error: "Ongeldig chatverzoek" });
      }
      const models = await getModels();
      if (!models.some((model) => model.name === body.model)) return send(res, 400, { error: "Model is niet beschikbaar" });
      const messages = body.messages.map((message) => {
        if (!message || !["user", "assistant"].includes(message.role) || typeof message.content !== "string" || message.content.length > 20000) {
          throw Object.assign(new Error("Ongeldig bericht"), { status: 400 });
        }
        return { role: message.role, content: message.content };
      });
      const response = await fetch(`${OLLAMA}/api/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ model: body.model, messages, stream: false, options: { num_ctx: 4096, num_predict: 1024 } })
      });
      if (!response.ok) return send(res, 502, { error: `Ollama chat fout: HTTP ${response.status}` });
      const result = await response.json();
      return send(res, 200, { message: result.message, done: result.done });
    }
    if (req.method !== "GET") return send(res, 405, { error: "Method not allowed" });
    let requested;
    try { requested = url.pathname === "/" ? "/index.html" : decodeURIComponent(url.pathname); }
    catch { return send(res, 400, { error: "Invalid URL path" }); }
    const file = path.resolve(ROOT, `.${requested}`);
    if (!file.startsWith(ROOT + path.sep) && file !== ROOT) return send(res, 403, { error: "Forbidden" });
    try {
      const body = fs.readFileSync(file);
      send(res, 200, body, MIME[path.extname(file)] || "application/octet-stream");
    } catch { send(res, 404, { error: "Not found" }); }
  } catch (error) {
    if (!res.headersSent) send(res, error.status || 500, { error: error.message || "Internal server error" });
    else res.destroy();
  }
});
server.listen(PORT, HOST, () => console.log(`PS5 AI Studio Linux web UI: http://${HOST}:${PORT}`));