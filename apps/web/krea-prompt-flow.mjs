export const KREA_PROMPT_MODES = Object.freeze(["automatic", "approve", "manual"]);

export function getKreaPromptFlow(mode, optimizationEnabled, skipOnce = false) {
  const selectedMode = KREA_PROMPT_MODES.includes(mode) ? mode : "automatic";
  if (skipOnce) return { mode: selectedMode, kind: "generate-original", optimize: false, review: false };
  if (!optimizationEnabled) return selectedMode === "automatic"
    ? { mode: selectedMode, kind: "generate-original", optimize: false, review: false }
    : { mode: selectedMode, kind: "review-original", optimize: false, review: true };
  return selectedMode === "automatic"
    ? { mode: selectedMode, kind: "optimize-and-generate", optimize: true, review: false }
    : { mode: selectedMode, kind: "optimize-and-review", optimize: true, review: true };
}

export function createKreaPromptReview(originalPrompt, optimized, mode) {
  const original = String(originalPrompt || "").trim();
  const normalizedMode = KREA_PROMPT_MODES.includes(mode) ? mode : "automatic";
  const meta = {
    provider: ["openrouter", "qwen", "original"].includes(optimized?.provider) ? optimized.provider : "original",
    model: typeof optimized?.model === "string" ? optimized.model.slice(0, 160) : null,
    fallback: optimized?.fallback === true,
    warning: typeof optimized?.warning === "string" ? optimized.warning.slice(0, 360) : null
  };
  const prompt = typeof optimized?.prompt === "string" && optimized.prompt.trim() ? optimized.prompt.trim() : original;
  return { originalPrompt: original, prompt, meta, mode: normalizedMode, edited: false, restoredOriginal: prompt === original && meta.provider === "original" };
}

export function restoreKreaPromptReview(review) {
  if (!review) return null;
  return {
    ...review,
    prompt: review.originalPrompt,
    meta: { provider: "original", model: null, fallback: false, warning: "De oorspronkelijke prompt is hersteld." },
    edited: false,
    restoredOriginal: true
  };
}

export function chooseKreaPrompt(review, prompt = review?.prompt) {
  if (!review) throw new Error("Er is geen prompt ter beoordeling.");
  const selected = String(prompt || "").trim();
  if (!selected || selected.length > 6000) throw new Error("Prompt moet 1 tot 6000 tekens bevatten.");
  const original = selected === review.originalPrompt;
  return {
    prompt: selected,
    originalPrompt: review.originalPrompt,
    provider: original ? "original" : review.meta.provider,
    model: original ? null : review.meta.model,
    fallback: original ? review.meta.fallback : review.meta.fallback,
    warning: review.meta.warning,
    promptSource: original ? "original" : "optimized",
    mode: review.mode,
    edited: review.mode === "manual" && selected !== review.prompt
  };
}

export function chooseOriginalKreaPrompt(originalPrompt, mode = "automatic", warning = null) {
  const original = String(originalPrompt || "").trim();
  if (!original || original.length > 6000) throw new Error("Prompt moet 1 tot 6000 tekens bevatten.");
  return { prompt: original, originalPrompt: original, provider: "original", model: null, fallback: false, warning, promptSource: "original", mode: KREA_PROMPT_MODES.includes(mode) ? mode : "automatic", edited: false };
}