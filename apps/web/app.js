const $ = (id) => document.getElementById(id);
const fmt = (bytes) => bytes == null ? "—" : `${(bytes / 1073741824).toFixed(2)} GiB`;
const pct = (used, total) => total > 0 ? Math.max(0, Math.min(100, used / total * 100)) : 0;
const setMeter = (id, value) => { const el = $(id); if (el) el.style.width = `${value}%`; };
const status = (id, running, installed) => {
  const el = $(id);
  el.textContent = running ? "Actief" : installed ? "Beschikbaar" : "Niet gevonden";
  el.className = `runtime-state ${running ? "is-running" : installed ? "is-ready" : "is-missing"}`;
};
let models = [];
let messages = [];
let busy = false;
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
async function loadModels() {
  const grid = $("models-grid");
  try {
    const response = await fetch("/api/models", { cache: "no-store" });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
    models = data.models || [];
    const select = $("chat-model");
    const previous = select.value;
    select.replaceChildren();
    for (const model of models) {
      const option = document.createElement("option");
      option.value = model.name;
      option.textContent = model.name;
      select.append(option);
    }
    if (models.some((model) => model.name === previous)) select.value = previous;
    grid.replaceChildren();
    if (!models.length) {
      const empty = document.createElement("div");
      empty.className = "empty-state";
      empty.textContent = "Geen Ollama-modellen gevonden. Download hierboven een model.";
      grid.append(empty);
      return;
    }
    for (const model of models) {
      const card = document.createElement("article");
      card.className = "model-card";
      const head = document.createElement("div");
      head.className = "model-card-head";
      const title = document.createElement("strong");
      title.textContent = model.name;
      const state = document.createElement("span");
      state.className = `model-running ${model.running ? "is-running" : ""}`;
      state.textContent = model.running ? "In gebruik" : "Op schijf";
      head.append(title, state);
      const meta = document.createElement("p");
      meta.textContent = `${model.parameters} parameters · ${model.quantization} · ${fmt(model.size)}`;
      const footer = document.createElement("div");
      footer.className = "model-card-footer";
      const family = document.createElement("span");
      family.className = "model-family";
      family.textContent = model.family;
      const remove = document.createElement("button");
      remove.type = "button";
      remove.className = "delete-model";
      remove.textContent = "Verwijderen";
      remove.disabled = model.running;
      remove.title = model.running ? "Stop het model eerst in Ollama" : "Verwijder dit model van de schijf";
      remove.addEventListener("click", () => deleteModel(model.name));
      footer.append(family, remove);
      card.append(head, meta, footer);
      grid.append(card);
    }
  } catch (error) {
    grid.replaceChildren();
    const message = document.createElement("div");
    message.className = "empty-state";
    message.textContent = `Modellen niet beschikbaar: ${error.message}`;
    grid.append(message);
  }
}
let pullController = null;
function setPullProgress(status, percent, size) {
  $("pull-progress-wrap").hidden = false;
  $("pull-status").textContent = status;
  $("pull-percent").textContent = percent == null ? "—" : `${Math.round(percent)}%`;
  $("pull-progress").value = percent ?? 0;
  $("pull-size").textContent = size || " ";
}
async function pullModel(event) {
  event.preventDefault();
  if (pullController) return;
  const name = $("model-name").value.trim();
  if (!name) return;
  pullController = new AbortController();
  $("pull-model").disabled = true;
  $("cancel-pull").hidden = false;
  $("model-name").disabled = true;
  setPullProgress("Download starten…", 0, "Ollama kan een onderbroken download later hervatten.");
  try {
    const response = await fetch("/api/models/pull", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name }),
      signal: pullController.signal
    });
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.error || `HTTP ${response.status}`);
    }
    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";
      for (const line of lines) {
        if (!line.trim()) continue;
        const item = JSON.parse(line);
        const percent = item.total > 0 ? item.completed / item.total * 100 : null;
        const size = item.total > 0 ? `${fmt(item.completed)} / ${fmt(item.total)}` : "";
        setPullProgress(item.status || "Downloaden…", percent, size);
        if (item.error) throw new Error(item.error);
      }
    }
    if (buffer.trim()) {
      const item = JSON.parse(buffer);
      if (item.error) throw new Error(item.error);
      setPullProgress(item.status || "Download voltooid", 100, "Model is beschikbaar.");
    }
    $("model-name").value = "";
    setPullProgress("Download voltooid", 100, "Model staat in je lokale bibliotheek.");
    await loadModels();
  } catch (error) {
    if (error.name === "AbortError") {
      setPullProgress("Download onderbroken", null, "Ollama bewaart voortgang en hervat bij een volgende poging.");
    } else {
      setPullProgress(`Download mislukt: ${error.message}`, null, "");
    }
  } finally {
    pullController = null;
    $("pull-model").disabled = false;
    $("cancel-pull").hidden = true;
    $("model-name").disabled = false;
  }
}
async function deleteModel(name) {
  if (!confirm(`Weet je zeker dat je model "${name}" volledig van de PS5 wilt verwijderen? Dit verwijdert de lokale modelbestanden.`)) return;
  try {
    const response = await fetch("/api/models", {
      method: "DELETE",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name })
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
    await loadModels();
  } catch (error) {
    alert(`Model verwijderen is niet gelukt: ${error.message}`);
  }
}
async function loadImageModels() {
  const grid = $("image-models-grid");
  try {
    const response = await fetch("/api/image/models", { cache: "no-store" });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
    $("image-model-directory").textContent = data.directory;
    grid.replaceChildren();
    if (!data.models?.length) {
      const empty = document.createElement("div");
      empty.className = "empty-state";
      const icon = document.createElement("div");
      icon.className = "empty-icon";
      icon.textContent = "✳";
      const title = document.createElement("h3");
      title.textContent = "Nog geen beeldcheckpoint gevonden";
      const text = document.createElement("p");
      text.textContent = "Zet een SDXL .safetensors- of .ckpt-bestand in de checkpointmap om de image-engine te kunnen configureren.";
      empty.append(icon, title, text);
      grid.append(empty);
      return;
    }
    for (const model of data.models) {
      const card = document.createElement("article");
      card.className = "model-card";
      const title = document.createElement("strong");
      title.textContent = model.name;
      const meta = document.createElement("p");
      meta.textContent = `${model.format.toUpperCase()} · ${fmt(model.size)} · gewijzigd ${new Date(model.modified).toLocaleDateString("nl-NL")}`;
      const location = document.createElement("code");
      location.className = "image-model-path";
      location.textContent = model.path;
      card.append(title, meta, location);
      grid.append(card);
    }
  } catch (error) {
    grid.replaceChildren();
    const message = document.createElement("div");
    message.className = "empty-state";
    message.textContent = `Beeldmodellen niet beschikbaar: ${error.message}`;
    grid.append(message);
  }
}
function renderMessages() {
  const container = $("chat-messages");
  container.replaceChildren();
  if (!messages.length) {
    const empty = document.createElement("div");
    empty.className = "chat-empty";
    const icon = document.createElement("div");
    icon.className = "empty-icon";
    icon.textContent = "✦";
    const title = document.createElement("h3");
    title.textContent = "Waar kan ik je mee helpen?";
    const text = document.createElement("p");
    text.textContent = "Je berichten blijven op deze Linux-host en worden verwerkt door het geselecteerde lokale model.";
    empty.append(icon, title, text);
    container.append(empty);
    return;
  }
  for (const message of messages) {
    const row = document.createElement("div");
    row.className = `chat-message ${message.role}`;
    const label = document.createElement("span");
    label.className = "message-label";
    label.textContent = message.role === "user" ? "JIJ" : "AI";
    const body = document.createElement("div");
    body.className = "message-content";
    body.textContent = message.content;
    row.append(label, body);
    container.append(row);
  }
  container.scrollTop = container.scrollHeight;
}
async function sendMessage(event) {
  event.preventDefault();
  if (busy) return;
  const input = $("chat-input");
  const content = input.value.trim();
  const model = $("chat-model").value;
  if (!content || !model) return;
  messages.push({ role: "user", content });
  input.value = "";
  renderMessages();
  busy = true;
  $("send-chat").disabled = true;
  $("send-chat").textContent = "Bezig…";
  try {
    const response = await fetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model, messages: messages.slice(-24) })
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || `HTTP ${response.status}`);
    messages.push({ role: "assistant", content: data.message?.content || "(Leeg antwoord)" });
  } catch (error) {
    messages.push({ role: "assistant", content: `Fout: ${error.message}` });
  } finally {
    busy = false;
    $("send-chat").disabled = false;
    $("send-chat").innerHTML = 'Versturen <span>↑</span>';
    renderMessages();
    input.focus();
  }
}
document.querySelectorAll(".nav-item").forEach((button) => button.addEventListener("click", () => {
  document.querySelectorAll(".nav-item").forEach((item) => item.classList.toggle("active", item === button));
  document.querySelectorAll(".view").forEach((view) => view.classList.toggle("active", view.id === `view-${button.dataset.view}`));
  $("page-title").textContent = button.textContent.trim();
}));
$("refresh").addEventListener("click", refresh);
$("reload-models").addEventListener("click", loadModels);
$("reload-image-models").addEventListener("click", loadImageModels);
$("model-pull-form").addEventListener("submit", pullModel);
$("cancel-pull").addEventListener("click", () => pullController?.abort());
$("chat-form").addEventListener("submit", sendMessage);
$("chat-input").addEventListener("keydown", (event) => {
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault();
    $("chat-form").requestSubmit();
  }
});
refresh();
loadModels();
loadImageModels();
setInterval(refresh, 60000);