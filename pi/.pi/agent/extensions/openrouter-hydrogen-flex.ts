import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { appendFileSync } from "node:fs";

// "openrouter/hydrogen-flex" is a pi-side alias: send it to OpenRouter as
// google/gemini-4-hydrogen pinned to the flex service tier (no fallback to standard).
const ALIAS = "hydrogen-flex";
const UPSTREAM = "google/gemini-4-hydrogen";
const LOG = `${process.env.HOME}/.pi/agent/hydrogen-flex-violations.log`;

export default function (pi: ExtensionAPI) {
  pi.on("before_provider_request", (event) => {
    const payload = event.payload as Record<string, unknown> | undefined;
    if (!payload || payload.model !== ALIAS) return payload;
    return {
      ...payload,
      model: UPSTREAM,
      service_tier: "flex",
      // Only the flex endpoint, never fall back to standard/priority.
      provider: {
        ...((payload.provider as Record<string, unknown>) ?? {}),
        only: ["google-ai-studio/flex"],
        allow_fallbacks: false,
      },
    };
  });

  // OpenRouter reports the tier that actually served the request in the final
  // stream chunk (the one carrying `usage`). If it's anything but flex, kill the session.
  pi.on("provider_stream_event", (event, ctx) => {
    if (event.provider !== "openrouter" || ctx.model?.id !== ALIAS) return;
    const data = event.data as { service_tier?: unknown; id?: string; provider?: string } | undefined;
    if (!data || data.service_tier === undefined || data.service_tier === "flex") return;

    const msg = `hydrogen-flex served at tier "${String(data.service_tier)}" (gen ${data.id ?? "?"}, ${data.provider ?? "?"}), killing session`;
    try {
      appendFileSync(LOG, `${new Date().toISOString()} ${ctx.sessionManager?.getSessionId?.() ?? "?"} ${msg}\n`);
    } catch {}
    try { ctx.ui?.notify?.(msg, "error"); } catch {}
    console.error(`[openrouter-hydrogen-flex] ${msg}`);
    ctx.abort();
    ctx.shutdown();
  });
}
