import http from "node:http";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../web");
const HOST = "127.0.0.1";
const PORT = Number(process.env.PORT || 8787);
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
  const found = { ollama: false, llamaCpp: false, stableDiffusion: false };
  try {
    for (const entry of fs.readdirSync("/proc")) {
      if (!/^\d+$/.test(entry)) continue;
      let cmd = "";
      try { cmd = fs.readFileSync(`/proc/${entry}/cmdline`, "utf8").replaceAll("\0", " "); } catch { continue; }
      if (cmd.includes("ollama serve")) found.ollama = true;
      if (cmd.includes("llama-server")) found.llamaCpp = true;
      if (cmd.includes("sd-server")) found.stableDiffusion = true;
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
      ollama: { installed: true, running: processes.ollama, endpoint: "http://127.0.0.1:11434" },
      llamaCpp: { installed: fs.existsSync(llama), running: processes.llamaCpp, binary: llama },
      stableDiffusion: { installed: fs.existsSync(sd), running: processes.stableDiffusion, binary: sd }
    },
    timestamp: new Date().toISOString()
  };
}
function send(res, status, body, type = "application/json; charset=utf-8") {
  res.writeHead(status, { "Content-Type": type, "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" });
  res.end(type.startsWith("application/json") ? JSON.stringify(body) : body);
}
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${HOST}:${PORT}`);
  if (req.method === "GET" && url.pathname === "/api/health") return send(res, 200, { ok: true, service: "PS5 AI Studio Linux" });
  if (req.method === "GET" && url.pathname === "/api/diagnostics") return send(res, 200, diagnostics());
  if (req.method !== "GET") return send(res, 405, { error: "Method not allowed" });
  const requested = url.pathname === "/" ? "/index.html" : decodeURIComponent(url.pathname);
  const file = path.resolve(ROOT, `.${requested}`);
  if (!file.startsWith(ROOT + path.sep) && file !== ROOT) return send(res, 403, { error: "Forbidden" });
  try {
    const body = fs.readFileSync(file);
    send(res, 200, body, MIME[path.extname(file)] || "application/octet-stream");
  } catch { send(res, 404, { error: "Not found" }); }
});
server.listen(PORT, HOST, () => console.log(`PS5 AI Studio Linux web UI: http://${HOST}:${PORT}`));