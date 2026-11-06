export function publicSettings(settings, env = process.env) {
  const safe = { ...settings };
  const civitaiConfigured = !!(safe.civitaiApiKey || env.CIVITAI_API_KEY);
  const openrouterConfigured = !!(safe.openrouterApiKey || env.OPENROUTER_API_KEY);
  delete safe.civitaiApiKey;
  delete safe.openrouterApiKey;
  safe.civitaiApiKeyConfigured = civitaiConfigured;
  safe.openrouterApiKeyConfigured = openrouterConfigured;
  return safe;
}
