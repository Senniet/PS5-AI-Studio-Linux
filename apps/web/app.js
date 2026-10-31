const $ = (id) => document.getElementById(id);
const fmt = (bytes) => bytes == null ? "—" : `${(bytes / 1073741824).toFixed(2)} GiB`;
const pct = (used, total) => total > 0 ? Math.max(0, Math.min(100, used / total * 100)) : 0;
const setMeter = (id, value) => { const el = $(id); if (el) el.style.width = `${value}%`; };
const status = (id, running, installed) => {
  const el = $(id);
  el.textContent = running ? "Actief" : installed ? "Beschikbaar" : "Niet gevonden";
  el.className = `runtime-state ${running ? "is-running" : installed ? "is-ready" : "is-missing"}`;
};
function uptime(seconds) {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor(seconds % 86400 / 3600);
  return days ? `${days} d ${hours} u` : `${hours} uur`;
}
async function refresh() {
  $("refresh").classList.add("spinning");
  try {
    const response = await fetch("/api/diagnostics", { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const d = await response.json();
    $("host-name").textContent = d.host.hostname;
    $("kernel").textContent = d.host.release;
    $("os-detail").textContent = `${d.host.platform} · ${d.host.cpus} threads`;
    $("cpu-count").textContent = `${d.host.cpus} threads`;
    $("cpu-detail").textContent = d.host.cpuModel;
    $("ram-used").textContent = fmt(d.memory.used);
    $("ram-detail").textContent = `${fmt(d.memory.available)} beschikbaar van ${fmt(d.memory.total)}`;
    setMeter("ram-meter", pct(d.memory.used, d.memory.total));
    $("gtt-total").textContent = fmt(d.gpu.gtt);
    $("gtt-detail").textContent = `${fmt(d.gpu.gttUsed)} in gebruik · ${fmt(d.gpu.vram)} VRAM`;
    setMeter("gtt-meter", pct(d.gpu.gttUsed, d.gpu.gtt));
    status("ollama-state", d.runtimes.ollama.running, d.runtimes.ollama.installed);
    status("llama-state", d.runtimes.llamaCpp.running, d.runtimes.llamaCpp.installed);
    status("sd-state", d.runtimes.stableDiffusion.running, d.runtimes.stableDiffusion.installed);
    $("diag-cpu-model").textContent = d.host.cpuModel;
    $("diag-cpu-count").textContent = d.host.cpus;
    $("diag-kernel").textContent = d.host.release;
    $("diag-uptime").textContent = uptime(d.host.uptime);
    $("diag-ram-total").textContent = fmt(d.memory.total);
    $("diag-ram-used").textContent = fmt(d.memory.used);
    $("diag-ram-free").textContent = fmt(d.memory.available);
    $("diag-swap").textContent = fmt(d.memory.swapFree);
    $("diag-gpu").textContent = d.gpu.name;
    $("diag-vram").textContent = fmt(d.gpu.vram);
    $("diag-gtt").textContent = fmt(d.gpu.gtt);
    $("diag-gtt-used").textContent = fmt(d.gpu.gttUsed);
    $("diag-ttm").textContent = d.gpu.ttmPages?.toLocaleString("nl-NL") ?? "—";
    $("diag-pool").textContent = d.gpu.pagePool?.toLocaleString("nl-NL") ?? "—";
    const time = new Date(d.timestamp).toLocaleTimeString("nl-NL", { hour: "2-digit", minute: "2-digit", second: "2-digit" });
    $("updated-at").textContent = `Bijgewerkt om ${time}`;
    $("last-update").textContent = `Laatst bijgewerkt ${time}`;
  } catch (error) {
    $("last-update").textContent = "Verbinding mislukt";
    console.error("Diagnostics refresh failed:", error);
  } finally {
    $("refresh").classList.remove("spinning");
  }
}
document.querySelectorAll(".nav-item").forEach((button) => button.addEventListener("click", () => {
  document.querySelectorAll(".nav-item").forEach((item) => item.classList.toggle("active", item === button));
  document.querySelectorAll(".view").forEach((view) => view.classList.toggle("active", view.id === `view-${button.dataset.view}`));
  $("page-title").textContent = button.textContent.trim();
}));
$("refresh").addEventListener("click", refresh);
refresh();
setInterval(refresh, 60000);