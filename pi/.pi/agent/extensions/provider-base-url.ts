import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

// Extension factory runs once at load, so provider URL overrides are applied
// before any turns start and do not need to be repeated per turn.
export default function (pi: ExtensionAPI) {
  // Map provider IDs to the environment variables that override their base URL.
  const BASE_URL_ENV: Record<string, string> = {
    openrouter: "OPENROUTER_BASE_URL",
    fireworks: "FIREWORKS_BASE_URL",
    cerebras: "CEREBRAS_BASE_URL",
  };

  for (const [provider, envKey] of Object.entries(BASE_URL_ENV)) {
    const url = process.env[envKey];
    if (!url) continue; // Unset -> leave the provider untouched.

    pi.registerProvider(provider, {
      baseUrl: url,
      // Deliberately omit `api` and `streamSimple`: this is a merge-only URL
      // override and must not change stream routing.
    })
    // The value is the base URL exactly as the provider expects it, including
    // any version segment (e.g. .../openrouter/api/v1). pi appends only
    // /chat/completions to this value, so a missing /v1 would 404.;
  }
}
