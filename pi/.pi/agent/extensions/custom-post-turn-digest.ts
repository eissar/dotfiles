/**
 * Post-turn digest: reports generation TPS plus provider-specific extras in one
 * transcript entry:
 *   - openai-codex: current Codex quota pace and reset times
 *   - openrouter: per-turn LLM call count, cost, tokens (cache/reasoning split),
 *     model slugs, and true upstream router names tapped from the response
 *     stream itself via a scoped fetch wrapper registered on the provider
 *     (OpenRouter sends `provider` on every SSE chunk; no extra requests).
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { openAICompletionsApi } from "@earendil-works/pi-ai";
import { Box, Text } from "@earendil-works/pi-tui";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

interface RateWindow {
	usedPercent: number;
	windowSeconds: number;
	resetAfterSeconds: number;
	resetAt: number;
}

interface TurnTpsInfo {
	tps: number;
	durationSeconds: number;
	totalTokens?: number;
	requests?: number;
	cachePct?: number;
	reasoning?: number;
}

interface DigestData {
	tpsInfo?: TurnTpsInfo;
	windows?: RateWindow[];
	planType?: string;
	or?: OpenRouterDigest;
	timestamp: number;
}

interface OpenRouterDigest {
	calls: number;
	input: number;
	output: number;
	cacheRead: number;
	reasoning?: number;
	cost?: number;
	models: string[];
	routers: string[];
}

// Per-stream metadata tapped from OpenRouter's SSE body, keyed by the
// generation id (matches AssistantMessage.responseId).
interface OrCallMeta {
	router?: string;
	cost?: number;
}
const orTapped = new Map<string, OrCallMeta>();

// Scoped fetch for the openrouter provider only: taps the SSE stream
// (router name on every chunk, usage/cost on the final chunk) while
// forwarding every byte untouched to pi's OpenAI client.
const tapFetch: typeof fetch = async (url, init) => {
	const res = await fetch(url, init);
	if (!res.ok || !res.body) return res;

	const decoder = new TextDecoder();
	let lineBuf = "";
	const meta: OrCallMeta = {};
	let recorded = false;

	const tap = new TransformStream<Uint8Array, Uint8Array>({
		transform(chunk, ctrl) {
			ctrl.enqueue(chunk);
			if (recorded) return;
			lineBuf += decoder.decode(chunk, { stream: true });
			let nl: number;
			while ((nl = lineBuf.indexOf("\n")) >= 0) {
				const line = lineBuf.slice(0, nl).trim();
				lineBuf = lineBuf.slice(nl + 1);
				if (!line.startsWith("data: ")) continue;
				const data = line.slice(6);
				if (data === "[DONE]") { recorded = true; break; }
				try {
					const json = JSON.parse(data) as {
						id?: string;
						provider?: string;
						usage?: { cost?: number };
					};
					if (typeof json.provider === "string") meta.router = json.provider;
					if (json.usage && typeof json.usage.cost === "number") meta.cost = json.usage.cost;
					if (json.id && (meta.router !== undefined || meta.cost !== undefined)) {
						orTapped.set(json.id, meta);
						if (meta.cost !== undefined) recorded = true; // final chunk seen
					}
				} catch { /* keepalives / split frames */ }
			}
		},
	});

	return new Response(res.body.pipeThrough(tap), {
		status: res.status,
		statusText: res.statusText,
		headers: res.headers,
	});
};

function windowLabel(window: RateWindow): string {
	return window.windowSeconds >= 86400
		? `${Math.round(window.windowSeconds / 86400)}d`
		: `${Math.round(window.windowSeconds / 3600)}h`;
}

function paceMultiplier(window: RateWindow): string {
	const elapsed = Math.max(1, window.windowSeconds - window.resetAfterSeconds);
	const pace = window.windowSeconds > 0
		? (window.usedPercent * window.windowSeconds) / (elapsed * 100)
		: 0;
	return `${pace.toFixed(2)}×`;
}

function resetLabel(window: RateWindow): string {
	const date = new Date(window.resetAt * 1000);
	const label = windowLabel(window);
	const time = label === "5h"
		? date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit", hour12: false })
		: date.toLocaleString([], { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit", hour12: false });
	return `${time} (${label})`;
}

function codexLine(windows: RateWindow[]): string {
	const usage = windows.map((window) =>
		`${windowLabel(window)} [${window.usedPercent}% · ${paceMultiplier(window)}]`
	).join(" | ");
	const resets = windows.map(resetLabel).join(" · ");
	return `${usage} | ↺ ${resets}`;
}

async function fetchCodexData(): Promise<{ windows: RateWindow[]; planType?: string } | undefined> {
	try {
		const authPath = join(homedir(), ".pi", "agent", "auth.json");
		const auth = JSON.parse(await readFile(authPath, "utf8"));
		const credentials = auth["openai-codex"];
		if (!credentials?.access) return undefined;

		const response = await fetch("https://chatgpt.com/backend-api/wham/usage", {
			headers: {
				Authorization: `Bearer ${credentials.access}`,
				"chatgpt-account-id": credentials.accountId || "",
				"User-Agent": "Mozilla/5.0 (pi-agent)",
			},
			signal: AbortSignal.timeout(6000),
		});
		if (!response.ok) return undefined;

		const payload = await response.json() as any;
		const rateLimit = payload?.rate_limit;
		if (!rateLimit) return undefined;
		const windows = [rateLimit.primary_window, rateLimit.secondary_window]
			.filter(Boolean)
			.map((window): RateWindow => ({
				usedPercent: window.used_percent ?? 0,
				windowSeconds: window.limit_window_seconds ?? 0,
				resetAfterSeconds: window.reset_after_seconds ?? 0,
				resetAt: window.reset_at ?? 0,
			}));
		return { windows, planType: payload.plan_type };
	} catch {
		return undefined;
	}
}

function formatDuration(seconds: number): string {
	if (seconds < 60) {
		return `${seconds.toFixed(1)}s`;
	}
	const mins = Math.floor(seconds / 60);
	const secs = Math.round(seconds % 60);
	return `${mins}m ${secs}s`;
}

function tpsLine(info: TurnTpsInfo): string {
	const timeStr = formatDuration(info.durationSeconds);
	let res = `${Math.round(info.tps)} tps in ${timeStr}`;

	const tokenDetails: string[] = [];
	if (info.totalTokens !== undefined && info.totalTokens > 0) {
		tokenDetails.push(`${(info.totalTokens / 1000).toFixed(1)}k`);
	}
	const metaDetails: string[] = [];
	if (info.cachePct !== undefined && info.cachePct > 0) {
		metaDetails.push(`cache ${info.cachePct}%`);
	}
	if (info.reasoning !== undefined && info.reasoning > 0) {
		metaDetails.push(`think ${(info.reasoning / 1000).toFixed(1)}k`);
	}
	if (metaDetails.length > 0) {
		tokenDetails.push(metaDetails.join(" · "));
	}

	if (tokenDetails.length > 0) {
		res += ` · (${tokenDetails.join(", ")})`;
	}
	if (info.requests !== undefined && info.requests > 1) {
		res += ` (${info.requests} reqs)`;
	}
	return `tps: ${res}`;
}

function orLine(or: OpenRouterDigest): string {
	const bits = [
		or.cost !== undefined ? `$${or.cost.toFixed(4)}` : undefined,
	].filter((b): b is string => b !== undefined);
	const tail = [
		or.routers.length ? or.routers.join(", ") : undefined,
	].filter(Boolean).join(" · ");
	return `${bits.join(" | ")}${tail ? (bits.length ? ` · ${tail}` : tail) : ""}`;
}

export default function (pi: ExtensionAPI) {
	// Override only the openrouter stream path; auth, models, retries stay
	// pi's own (re-registration merges, preserving the model catalog). Must
	// set api: the custom handler only routes when model.api === extension.api.
	const api = openAICompletionsApi();
	pi.registerProvider("openrouter", {
		api: "openai-completions",
		streamSimple: (model, context, options) =>
			api.stream(model, context, { ...options, fetch: tapFetch }),
	});

	let messageStart = 0;
	let messageChars = 0;
	let turnTokens = 0;
	let turnSeconds = 0;
	let turnRequests = 0;
	let turnInputTokens = 0;
	let turnCacheReadTokens = 0;
	let turnCacheWriteTokens = 0;
	let turnReasoningTokens = 0;

	// OpenRouter: per-call info for the current agent turn
	interface OrCall {
		model: string;
		responseId?: string;
		usage?: any;
	}
	let orCalls: OrCall[] = [];

	const isOpenRouter = (ctx: { model?: { provider?: string } }) =>
		ctx.model?.provider === "openrouter";

	const resetOr = () => {
		orCalls = [];
	};

	pi.registerEntryRenderer<DigestData>("custom-post-turn-digest", (entry, { expanded }, theme) => {
		const data = entry.data;
		if (!data) return new Text(theme.fg("dim", "Post-turn digest unavailable"), 0, 0);

		const lines: string[] = [];
		if (data.tpsInfo !== undefined) lines.push(tpsLine(data.tpsInfo));
		if (data.windows?.length) lines.push(`codex: ${codexLine(data.windows)}`);
		if (data.or) lines.push(`openrouter: ${orLine(data.or)}`);

		const box = new Box(0, 0);
		for (const line of lines) {
			box.addChild(new Text(theme.fg("dim", line), 0, 0));
		}
		if (expanded && data.planType) {
			box.addChild(new Text(theme.fg("dim", `Plan: ${data.planType} · ${new Date(data.timestamp).toLocaleTimeString()}`), 0, 0));
		}
		return box;
	});

	pi.on("agent_start", async () => {
		resetOr();
	});

	pi.on("message_start", async () => {
		messageStart = Date.now();
		messageChars = 0;
	});

	pi.on("message_update", async (event) => {
		const update = event.assistantMessageEvent;
		if (update?.type === "text_delta") messageChars += update.delta.length;
	});

	pi.on("message_end", async (event) => {
		const msg = event.message as {
			role?: string;
			provider?: string;
			model?: string;
			responseId?: string;
			usage?: any;
		};
		if (msg.role === "assistant") {
			turnRequests++;
		}

		if (msg.role === "assistant" && msg.provider === "openrouter" && msg.usage) {
			orCalls.push({ model: msg.model ?? "unknown", responseId: msg.responseId, usage: msg.usage });
		}

		if (msg.role === "assistant" && msg.usage) {
			if (typeof msg.usage.input === "number") turnInputTokens += msg.usage.input;
			if (typeof msg.usage.cacheRead === "number") turnCacheReadTokens += msg.usage.cacheRead;
			if (typeof msg.usage.cacheWrite === "number") turnCacheWriteTokens += msg.usage.cacheWrite;
			if (typeof msg.usage.reasoning === "number") turnReasoningTokens += msg.usage.reasoning;
		}

		if (!messageStart) return;
		const elapsed = (Date.now() - messageStart) / 1000;
		messageStart = 0;
		if (elapsed <= 0) return;

		const usage = (event.message as { usage?: { output?: number } }).usage;
		const outputTokens = usage?.output ?? messageChars / 4;
		if (outputTokens > 0) {
			turnTokens += outputTokens;
			turnSeconds += elapsed;
		}
	});

	pi.on("agent_settled", async (_event, ctx) => {
		const totalPromptTokens = turnInputTokens + turnCacheReadTokens + turnCacheWriteTokens;
		const tps = turnTokens > 0 && turnSeconds > 0 ? turnTokens / turnSeconds : undefined;
		const totalTokens = (totalPromptTokens + turnTokens) > 0 ? (totalPromptTokens + turnTokens) : undefined;
		const tpsInfo: TurnTpsInfo | undefined = tps !== undefined ? {
			tps,
			durationSeconds: turnSeconds,
			totalTokens,
			requests: turnRequests > 0 ? turnRequests : undefined,
			cachePct: totalPromptTokens > 0 ? Math.round((turnCacheReadTokens / totalPromptTokens) * 100) : undefined,
			reasoning: turnReasoningTokens > 0 ? turnReasoningTokens : undefined,
		} : undefined;
		const isCodex = ctx.model?.provider === "openai-codex";
		const codex = isCodex ? await fetchCodexData() : undefined;

		let or: OpenRouterDigest | undefined;
		if (isOpenRouter(ctx) && orCalls.length > 0) {
			const sum = (fn: (u: any) => number | undefined) => {
				const vals = orCalls.map((c) => fn(c.usage)).filter((v): v is number => typeof v === "number");
				return vals.length ? vals.reduce((a, b) => a + b, 0) : undefined;
			};

			// Router names + costs come from the stream tap; cost falls back to
			// pi-parsed usage when a tap didn't capture the final usage chunk.
			const metas = orCalls.map((c) => (c.responseId ? orTapped.get(c.responseId) : undefined));
			const routers = metas.map((m) => m?.router).filter((r): r is string => !!r);
			const tappedCosts = metas.map((m) => m?.cost);
			const allTapped = tappedCosts.every((c) => typeof c === "number");

			or = {
				calls: orCalls.length,
				input: sum((u) => u.input) ?? 0,
				output: sum((u) => u.output) ?? 0,
				cacheRead: sum((u) => u.cacheRead) ?? 0,
				reasoning: sum((u) => u.reasoning),
				cost: allTapped
					? tappedCosts.reduce((a, b) => a + (b ?? 0), 0)
					: sum((u) => u.cost?.total),
				models: [...new Set(orCalls.map((c) => c.model))],
				routers: [...new Set(routers)],
			};
		}

		if (tpsInfo !== undefined || codex || or) {
			pi.appendEntry<DigestData>("custom-post-turn-digest", {
				tpsInfo,
				windows: codex?.windows,
				planType: codex?.planType,
				or,
				timestamp: Date.now(),
			});
		}

		turnTokens = 0;
		turnSeconds = 0;
		turnRequests = 0;
		turnInputTokens = 0;
		turnCacheReadTokens = 0;
		turnCacheWriteTokens = 0;
		turnReasoningTokens = 0;
		messageStart = 0;
		messageChars = 0;
		resetOr();
		orTapped.clear();
	});
}
