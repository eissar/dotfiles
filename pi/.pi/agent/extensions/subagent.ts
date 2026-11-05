import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { getSupportedThinkingLevels, StringEnum } from "@earendil-works/pi-ai";
import { ModelRuntime, createAgentSession, DefaultResourceLoader, SessionManager, SettingsManager, DEFAULT_MAX_BYTES, DEFAULT_MAX_LINES, getAgentDir, getMarkdownTheme, truncateHead } from "@earendil-works/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

import type { AgentMessage, AgentToolUpdateCallback, ThinkingLevel } from "@earendil-works/pi-agent-core";
import type { Api, Model, Usage } from "@earendil-works/pi-ai";
import type { ExtensionAPI, ExtensionToolContext } from "@earendil-works/pi-coding-agent";

interface ModelRegistryView { getAll(): Model<Api>[] }
const DEFAULT_CHILD_MODEL = "anthropic/claude-haiku-5-5";
const CHILD_TOOLS = ["read", "bash", "edit", "write"] as const;
type ChildTool = typeof CHILD_TOOLS[number];
interface RunConfig { cwd: string; model?: string; thinking?: ThinkingLevel; tools?: ChildTool[] }
function resolveChildTools(value: unknown): ChildTool[] {
    if (value === undefined) return ["read"];
    if (!Array.isArray(value) || value.some(tool => !CHILD_TOOLS.includes(tool as ChildTool))) {
        throw new Error("Child tools must contain only read, bash, edit, or write.");
    }
    return [...new Set(value)] as ChildTool[];
}
type ChildMetadata = RunConfig;
interface UsageStats extends Usage { turns: number }
interface ToolActivity {
    id: string; name: string; args: Record<string, unknown>;
    status: "running" | "done" | "error";
}
interface SubagentResult {
    task: string; label?: string; resumed: boolean; timeoutMs?: number;
    status: "running" | "done" | "failed" | "timeout" | "aborted";
    messages: AgentMessage[]; toolActivity: ToolActivity[];
    partialText: string; usage: UsageStats;
    model?: string; thinking?: ThinkingLevel; stopReason?: string;
    errorMessage?: string; sessionFile?: string; sessionId?: string;
}
interface SubagentDetails { result: SubagentResult }
type DisplayItem =
    | { type: "text"; text: string }
    | { type: "toolCall"; name: string; args: Record<string, unknown> }
    | { type: "toolResult"; name: string; text: string; isError: boolean };

function isRecord(value: unknown): value is Record<string, unknown> {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}
function isThinkingLevel(value: unknown): value is ThinkingLevel {
    return typeof value === "string" && THINKING_LEVEL_SET.has(value);
}

const CHILD_SYSTEM_GUIDANCE = "Work independently on the delegated task. If you cannot proceed reliably without clarification, a decision, or missing information, stop and return the precise question or blocker to your supervisor. Do not guess or wait. Your supervisor can resume this session with an answer.";
const COLLAPSED_ITEM_COUNT = 10;
const CHILD_METADATA_SUFFIX = ".subagent.json";
const THINKING_LEVELS = [
    "off",
    "minimal",
    "low",
    "medium",
    "high",
    "xhigh",
    "max"
] as const satisfies readonly ThinkingLevel[];
const THINKING_LEVEL_SET = new Set<string>(THINKING_LEVELS);
const EMPTY_USAGE = (): UsageStats =>({
        input: 0,
        output: 0,
        cacheRead: 0,
        cacheWrite: 0,
        totalTokens: 0,
        cost: {
            input: 0,
            output: 0,
            cacheRead: 0,
            cacheWrite: 0,
            total: 0
        },
        turns: 0
    });
function modelMap(registry: ModelRegistryView): Map<string, Model<Api>> {
    return new Map(registry.getAll().map((model)=>[
            `${model.provider}/${model.id}`,
            model
        ]));
}
function compactModelCatalog(registry: ModelRegistryView) {
    return {
        explicitModelRequired: false,
        defaultModel: DEFAULT_CHILD_MODEL,
        defaultTools: ["read"],
        models: registry.getAll().map(model => ({
            id: `${model.provider}/${model.id}`,
            thinkingLevels: getSupportedThinkingLevels(model),
        })),
        note: "Default model: anthropic/claude-haiku-5-5; default tools: [read]. Explicit model IDs must be exact. No fallback. Resume retains saved model and tools. Credentials and availability are not checked.",
    };
}
function metadataPath(sessionFile: string): string {
    return `${sessionFile}${CHILD_METADATA_SUFFIX}`;
}
function writeChildMetadata(sessionFile: string, metadata: ChildMetadata): void {
    const destination = metadataPath(sessionFile);
    const temporary = `${destination}.${process.pid}.${Math.random().toString(36).slice(2)}.tmp`;
    try {
        fs.writeFileSync(temporary, `${JSON.stringify(metadata, null, 2)}\n`, {
            encoding: "utf8",
            mode: 0o600
        });
        fs.renameSync(temporary, destination);
    } finally{
        try {
            if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
        } catch  {}
    }
}
function readChildMetadata(sessionFile: string): ChildMetadata {
    const file = metadataPath(sessionFile);
    let parsed: unknown;
    try {
        parsed = JSON.parse(fs.readFileSync(file, "utf8"));
    } catch  {
        throw new Error(`Subagent runtime metadata not found or invalid: ${file}`);
    }
    if (!isRecord(parsed)) throw new Error(`Invalid subagent runtime metadata: ${file}`);
    const value = parsed;
    if (typeof value.cwd !== "string") {
        throw new Error(`Invalid subagent runtime metadata: ${file}`);
    }
    if (value.thinking !== undefined && !isThinkingLevel(value.thinking)) {
        throw new Error(`Invalid thinking level in subagent runtime metadata: ${file}`);
    }
    return {
        cwd: value.cwd,
        model: typeof value.model === "string" ? value.model : undefined,
        thinking: isThinkingLevel(value.thinking) ? value.thinking : undefined,
        tools: resolveChildTools(value.tools)
    };
}
function expandHome(input: string): string {
    if (input === "~") return os.homedir();
    if (input.startsWith("~/") || input.startsWith("~\\")) return path.join(os.homedir(), input.slice(2));
    return input;
}
function resolveResumePath(input: string): string {
    const expanded = expandHome(input.trim());
    if (!path.isAbsolute(expanded) || path.extname(expanded) !== ".jsonl") {
        throw new Error("`resume` must be the exact absolute JSONL path returned by an earlier subagent call.");
    }
    const resolved = path.resolve(expanded);
    if (!fs.existsSync(resolved) || !fs.statSync(resolved).isFile()) {
        throw new Error(`Subagent session not found: ${resolved}`);
    }
    return resolved;
}
function addUsage(total: UsageStats, usage: Usage): void {
    total.input += usage.input || 0;
    total.output += usage.output || 0;
    total.cacheRead += usage.cacheRead || 0;
    total.cacheWrite += usage.cacheWrite || 0;
    total.totalTokens = usage.totalTokens || total.totalTokens;
    total.cost.input += usage.cost?.input || 0;
    total.cost.output += usage.cost?.output || 0;
    total.cost.cacheRead += usage.cost?.cacheRead || 0;
    total.cost.cacheWrite += usage.cost?.cacheWrite || 0;
    total.cost.total += usage.cost?.total || 0;
}
function getFinalOutput(result: SubagentResult): string {
    if (result.partialText.trim()) return result.partialText.trim();
    for(let i = result.messages.length - 1; i >= 0; i--){
        const message = result.messages[i];
        if (message?.role !== "assistant") continue;
        const text = message.content.filter((part)=>part.type === "text").map((part)=>part.text).join("\n").trim();
        if (text) return text;
    }
    return result.partialText.trim();
}
function statusOf(result: SubagentResult): SubagentResult["status"] {
    return result.status;
}
function resultOutput(result: SubagentResult): string {
    const parts = [];
    if (result.errorMessage) parts.push(`Error: ${result.errorMessage}`);
    const output = getFinalOutput(result);
    if (output) parts.push(output);
    return parts.join("\n\n") || "(no output)";
}
function truncateResult(output: string, sessionFile?: string): string {
    const truncated = truncateHead(output, {
        maxBytes: DEFAULT_MAX_BYTES,
        maxLines: DEFAULT_MAX_LINES
    });
    if (!truncated.truncated) return output;
    const sessionHint = sessionFile ? ` Read the last assistant message in the child session JSONL at ${sessionFile} if the complete response is needed.` : " The complete response may be available in the child session JSONL.";
    return `${truncated.content}\n\n[Output truncated: ${truncated.outputLines} of ${truncated.totalLines} lines, ${truncated.outputBytes} of ${truncated.totalBytes} bytes.]${sessionHint}`;
}
function envelope(result: SubagentResult): string {
    const fields = [];
    if (result.label) fields.push(`label=${result.label}`);
    fields.push(`status=${statusOf(result)}`);
    if (result.sessionFile) fields.push(`session=${result.sessionFile}`);
    return `[${fields.join(" ")}]`;
}
function modelFacingResult(result: SubagentResult): string {
    return `${envelope(result)}\n${truncateResult(resultOutput(result), result.sessionFile)}`;
}
// Native sessions share the parent's provider runtime, but not its conversation.
async function runChild(config: RunConfig, task: string, label: string | undefined, timeoutMs: number | undefined, resumePath: string | undefined, signal: AbortSignal | undefined, onUpdate: AgentToolUpdateCallback<SubagentDetails> | undefined, ctx: ExtensionToolContext): Promise<SubagentResult> {
    // Pi 1.3 exposes its runtime through the registry facade at runtime.
    // Narrow this compatibility boundary rather than casting the entire context.
    const registryValue: unknown = ctx?.modelRegistry;
    const runtime = isRecord(registryValue) ? registryValue.runtime : undefined;
    if (!ctx || !(runtime instanceof ModelRuntime)) throw new Error("Parent Pi model runtime is unavailable.");
    signal?.throwIfAborted();
    const agentDir = getAgentDir();
    const runId = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    const sessionDir = path.join(agentDir, "sessions", "subagent", runId);
    const registry = ctx.modelRegistry;
    const model = config.model ? modelMap(registry).get(config.model) : undefined;
    if (!model) throw new Error("A fresh or resumed child must have a recorded, registered model with an exact provider/id.");
    config.model = `${model.provider}/${model.id}`;
    if (config.thinking && !getSupportedThinkingLevels(model).includes(config.thinking)) {
        throw new Error(`Thinking level "${config.thinking}" is unsupported by "${config.model}".`);
    }

    const disk = SettingsManager.create(config.cwd, agentDir);
    const settingsErrors = disk.drainErrors();
    if (settingsErrors.length) throw new Error(`Cannot load child settings: ${settingsErrors.map(entry => entry.error.message).join("; ")}`);
    const settings = SettingsManager.inMemory({
        ...disk.getSettings(),
        packages: [], extensions: [], skills: [], prompts: [], themes: [],
        cacheWarming: "off", enableSkillCommands: false,
    });
    const loader = new DefaultResourceLoader({
        cwd: config.cwd, agentDir, settingsManager: settings,
        noExtensions: true, noSkills: true, noPromptTemplates: true, noThemes: true,
        appendSystemPromptOverride: inherited => [...inherited, CHILD_SYSTEM_GUIDANCE],
    });
    await loader.reload();
    signal?.throwIfAborted();
    const sessionManager = resumePath
        ? SessionManager.open(resumePath, path.dirname(resumePath), config.cwd)
        : SessionManager.create(config.cwd, sessionDir);
    const { session } = await createAgentSession({
        cwd: config.cwd, agentDir, modelRuntime: runtime, model,
        thinkingLevel: config.thinking, tools: resolveChildTools(config.tools),
        settingsManager: settings, resourceLoader: loader, sessionManager,
    });
    const result: SubagentResult = {
        task, label, resumed: Boolean(resumePath), timeoutMs, status: "running",
        messages: [], toolActivity: [], partialText: "",
        usage: EMPTY_USAGE(), model: config.model, thinking: session.thinkingLevel,
        sessionFile: session.sessionManager.getSessionFile() ?? undefined, sessionId: session.sessionId,
    };
    let timer: ReturnType<typeof setTimeout> | undefined;
    let timedOut = false, aborted = false;
    let abortPromise: Promise<void> | undefined;
    const stop = () => {
        abortPromise ??= session.abort();
        // Observe immediately; await again during cleanup.
        abortPromise.catch(() => {});
    };
    const onAbort = () => { if (!timedOut) { aborted = true; stop(); } };
    const emitUpdate = () => onUpdate?.({
        content: [{ type: "text", text: result.partialText || getFinalOutput(result) || "(running...)" }],
        details: { result },
    });
    const unsubscribe = session.subscribe(event => {
        if (event.type === "message_start" && event.message?.role === "assistant") {
            result.partialText = "";
            result.usage.turns++;
        } else if (event.type === "message_update") {
            const delta = event.assistantMessageEvent;
            if (delta?.type === "text_delta") result.partialText += delta.delta;
        } else if (event.type === "message_end") {
            result.messages.push(event.message);
            if (event.message.role === "assistant") {
                result.partialText = "";
                if (event.message.usage) addUsage(result.usage, event.message.usage);
                result.stopReason = event.message.stopReason;
                result.errorMessage = event.message.errorMessage;
            }
        } else if (event.type === "tool_execution_start") {
            result.toolActivity.push({ id: event.toolCallId, name: event.toolName, args: event.args ?? {}, status: "running" });
        } else if (event.type === "tool_execution_end") {
            const tool = result.toolActivity.find(tool => tool.id === event.toolCallId);
            if (tool) tool.status = event.isError ? "error" : "done";
        } else return;
        emitUpdate();
    });
    try {
        let bindError: string | undefined;
        await session.bindExtensions({ mode: "print", onError: error => { bindError ??= error.error; } });
        if (bindError) throw new Error(`Child extension startup failed: ${bindError}`);
        const active = session.getActiveToolNames();
        const expected = resolveChildTools(config.tools);
        if (active.length !== expected.length || active.some(name => !expected.includes(name as ChildTool))) {
            throw new Error(`Child tools differ from requested tools: ${expected.join(", ")}`);
        }
        if (!result.sessionFile) throw new Error("Child session file is unavailable.");
        if (!resumePath) writeChildMetadata(result.sessionFile, {
            cwd: config.cwd, model: config.model,
            thinking: session.thinkingLevel, tools: resolveChildTools(config.tools),
        });
        signal?.throwIfAborted();
        signal?.addEventListener("abort", onAbort, { once: true });
        if (timeoutMs) timer = setTimeout(() => {
            if (!aborted) { timedOut = true; stop(); }
        }, timeoutMs);
        await session.prompt(task, { expandPromptTemplates: false });
        result.status = result.stopReason === "error" ? "failed" : result.stopReason === "aborted" ? "aborted" : "done";
    } catch (error) {
        result.status = "failed";
        if (!timedOut && !aborted) result.errorMessage = error instanceof Error ? error.message : String(error);
    } finally {
        if (timer) clearTimeout(timer);
        signal?.removeEventListener("abort", onAbort);
        try { if (abortPromise) await abortPromise; }
        finally { unsubscribe(); session.dispose(); }
    }
    if (timedOut) result.status = "timeout";
    else if (aborted || signal?.aborted) result.status = "aborted";
    return result;
}
function formatTokens(count: number): string {
    if (count < 1000) return String(count);
    if (count < 10000) return `${(count / 1000).toFixed(1)}k`;
    if (count < 1000000) return `${Math.round(count / 1000)}k`;
    return `${(count / 1000000).toFixed(1)}M`;
}
function formatTimeout(timeoutMs: number | undefined): string {
    if (timeoutMs === undefined) return "";
    if (timeoutMs < 1000) return `${timeoutMs}ms`;
    if (timeoutMs < 60_000) {
        const seconds = Math.round(timeoutMs / 100) / 10;
        return seconds >= 60 ? "1m" : `${seconds}s`;
    }
    if (timeoutMs < 3_600_000) {
        let minutes = Math.floor(timeoutMs / 60_000);
        let seconds = Math.round(timeoutMs % 60_000 / 1000);
        if (seconds === 60) {
            minutes++;
            seconds = 0;
        }
        return seconds ? `${minutes}m ${seconds}s` : `${minutes}m`;
    }
    let hours = Math.floor(timeoutMs / 3_600_000);
    let minutes = Math.round(timeoutMs % 3_600_000 / 60_000);
    if (minutes === 60) {
        hours++;
        minutes = 0;
    }
    return minutes ? `${hours}h ${minutes}m` : `${hours}h`;
}
function timeoutBadge(timeoutMs: number | undefined): string {
    const formatted = formatTimeout(timeoutMs);
    return formatted ? `[⏱ ${formatted}]` : "";
}
function usageText(result: SubagentResult): string {
    const parts = [];
    if (result.usage.turns) parts.push(`${result.usage.turns} turn${result.usage.turns === 1 ? "" : "s"}`);
    if (result.usage.input) parts.push(`↑${formatTokens(result.usage.input)}`);
    if (result.usage.output) parts.push(`↓${formatTokens(result.usage.output)}`);
    if (result.usage.cacheRead) parts.push(`R${formatTokens(result.usage.cacheRead)}`);
    if (result.usage.cacheWrite) parts.push(`W${formatTokens(result.usage.cacheWrite)}`);
    if (result.usage.cost.total) parts.push(`$${result.usage.cost.total.toFixed(4)}`);
    if (result.usage.totalTokens) parts.push(`ctx:${formatTokens(result.usage.totalTokens)}`);
    if (result.model) parts.push(result.model);
    if (result.thinking) parts.push(result.thinking);
    return parts.join(" ");
}
function displayItems(result: SubagentResult): DisplayItem[] {
    const items: DisplayItem[] = [];
    for (const message of result.messages){
        if (message.role === "assistant") {
            for (const part of message.content){
                if (part.type === "text" && part.text.trim()) items.push({
                    type: "text",
                    text: part.text
                });
                if (part.type === "toolCall") items.push({
                    type: "toolCall",
                    name: part.name,
                    args: part.arguments
                });
            }
        } else if (message.role === "toolResult") {
            const text = message.content.filter((part)=>part.type === "text").map((part)=>part.text).join("\n");
            items.push({
                type: "toolResult",
                name: message.toolName,
                text,
                isError: message.isError
            });
        }
    }
    if (result.partialText) items.push({
        type: "text",
        text: result.partialText
    });
    return items;
}
function formatToolCall(name: string, args: Record<string, unknown>): string {
    if (name === "bash" && typeof args.command === "string") return `$ ${args.command.split("\n")[0]}`;
    const target = args.path ?? args.pattern ?? args.query;
    return target === undefined ? name : `${name} ${String(target)}`;
}
function compactItem(item: DisplayItem): string {
    if (item.type === "toolCall") return `→ ${formatToolCall(item.name, item.args)}`;
    if (item.type === "toolResult") {
        const first = item.text.trim().split("\n")[0] || "(no output)";
        return `← ${item.name}${item.isError ? " failed" : ""}: ${first.slice(0, 160)}`;
    }
    return item.text.split("\n").slice(0, 3).join("\n");
}
const SubagentParams = Type.Object({
    task: Type.String({
        minLength: 1,
        description: "Self-contained assignment for a fresh child, or the next instruction for a resumed child."
    }),
    label: Type.Optional(Type.String({
        minLength: 1,
        maxLength: 64,
        pattern: "^[A-Za-z0-9._:-]+$",
        description: "Short correlation label returned with the result."
    })),
    model: Type.Optional(Type.String({
        minLength: 1,
        description: "Fresh child only. Defaults to anthropic/claude-haiku-5-5. Explicit IDs must be exact registered provider/id values; no fallback."
    })),
    thinking: Type.Optional(StringEnum(THINKING_LEVELS, {
        description: "Fresh child only. Must be supported by the selected model. Omit to use the child settings default clamped to model capabilities."
    })),
    cwd: Type.Optional(Type.String({
        minLength: 1,
        description: "Working directory for a fresh child. Defaults to the parent cwd."
    })),
    tools: Type.Optional(Type.Array(StringEnum(CHILD_TOOLS), {
        description: "Fresh child only. Defaults to [read]. Allowed: read, bash, edit, write. [] disables tools. Saved for resume. Parent OS permissions; cwd is not confinement.",
    })),
    timeoutMs: Type.Optional(Type.Integer({
        minimum: 1,
        description: "Execution checkpoint in milliseconds, starting after session setup. On expiry, requests cooperative cancellation and waits for the session to become idle before returning available output and a resume path. Not a hard wall-clock limit: tools must honor cancellation."
    })),
    resume: Type.Optional(Type.String({
        minLength: 1,
        description: "Exact absolute child session JSONL path. Cannot combine with model, thinking, cwd, or tools. Retains saved tools; older metadata defaults to read."
    }))
});
const SUBAGENT_GUIDELINES = [
    "Fresh children default to anthropic/claude-haiku-5-5. Explicit models require exact registered provider/id values. Never provide model with resume.",
    "Default tools are [read]. For implementation grant tools [read, bash, edit, write]. Parent OS permissions apply; cwd is not confinement. Never pass tools with resume.",
    "Give subagent a self-contained task with relevant context, constraints, and the required output.",
    "Issue independent subagent calls together to run them concurrently; partition write work so children do not edit the same files.",
    "Treat subagent.timeoutMs as a supervision checkpoint, not merely a runtime limit; set it to when control should return for progress review. After a timeout: (1) resume the same session only to request a concise progress report covering completed work, current step, blockers, and proposed next action; do not ask it to continue in that turn; (2) once the report returns, decide whether to resume the child and steer any further work based on that report.",
    "Prefer subagent.resume whenever the child's accumulated context remains useful, including for answers, corrections, or follow-up."
];
export default function subagentExtension(pi: ExtensionAPI): void {
    pi.registerTool({
        name: "subagent_models",
        label: "Subagent Models",
        description: "List registered models and thinking levels. Default child model is anthropic/claude-haiku-5-5. Credentials and availability are not checked. No child starts.",
        promptSnippet: "List model and thinking values accepted by subagent",
        parameters: Type.Object({}),
        async execute (_toolCallId, _params, _signal, _onUpdate, ctx) {
            const catalog = compactModelCatalog(ctx.modelRegistry);
            return {
                content: [
                    {
                        type: "text",
                        text: JSON.stringify(catalog)
                    }
                ],
                details: catalog
            };
        }
    });
    pi.registerTool<typeof SubagentParams, SubagentDetails>({
        name: "subagent",
        label: "Subagent",
        description: "Run a task in an isolated conversation, not an OS sandbox. Defaults: model anthropic/claude-haiku-5-5, tools [read]. Fresh children may select read, bash, edit, write. Resume retains saved configuration. Return output and a persistent session path.",
        promptSnippet: "Run a task in a separate resumable Pi session",
        promptGuidelines: SUBAGENT_GUIDELINES,
        parameters: SubagentParams,
        async execute (_toolCallId, params, signal, onUpdate, ctx) {
            if (!params.task.trim()) throw new Error("Subagent task must not be blank.");
            let resumePath: string | undefined;
            let config: RunConfig;
            if (params.resume) {
                if (params.model !== undefined || params.thinking !== undefined || params.cwd !== undefined || params.tools !== undefined) {
                    throw new Error("A resumed subagent accepts only task, resume, label, and timeoutMs. Start a fresh child to change runtime configuration.");
                }
                resumePath = resolveResumePath(params.resume);
                const saved = readChildMetadata(resumePath);
                if (!saved.model) {
                    throw new Error("The resumed session does not record a model. Start a fresh child with an explicit model.");
                }
                config = saved;
            } else {
                if (params.model !== undefined && !params.model.trim()) throw new Error("Explicit model must not be blank.");
                config = {
                    cwd: path.resolve(params.cwd ?? ctx.cwd),
                    model: params.model?.trim() ?? DEFAULT_CHILD_MODEL,
                    thinking: params.thinking,
                    tools: resolveChildTools(params.tools)
                };
            }
            const result = await runChild(config, params.task, params.label, params.timeoutMs, resumePath, signal, onUpdate, ctx);
            return {
                content: [
                    {
                        type: "text",
                        text: modelFacingResult(result)
                    }
                ],
                details: {
                    result
                },
                usage: result.usage
            };
        },
        renderCall (args, theme) {
            const preview = args.task.length > 72 ? `${args.task.slice(0, 72)}…` : args.task;
            const identity = args.label ?? (args.resume ? "resume" : "child");
            const timeout = timeoutBadge(typeof args.timeoutMs === "number" ? args.timeoutMs : undefined);
            return new Text(`${theme.fg("toolTitle", theme.bold("subagent "))}${theme.fg("accent", identity)}${timeout ? ` ${theme.fg("dim", timeout)}` : ""}\n  ${theme.fg("dim", preview)}`, 0, 0);
        },
        renderResult (toolResult, { expanded }, theme) {
            const details = toolResult.details;
            if (!details?.result) {
                const content = toolResult.content[0];
                return new Text(content?.type === "text" ? content.text : "(no output)", 0, 0);
            }
            const result = details.result;
            const status = statusOf(result);
            const success = status === "done";
            const icon = status === "running" ? theme.fg("warning", "⏳") : success ? theme.fg("success", "✓") : theme.fg(status === "timeout" ? "warning" : "error", "✗");
            const title = result.label ?? (result.resumed ? "resumed child" : "child");
            const items = displayItems(result);
            const timeout = timeoutBadge(result.timeoutMs);
            if (!expanded) {
                const recent = items.slice(-COLLAPSED_ITEM_COUNT);
                let text = `${icon} ${theme.fg("toolTitle", theme.bold(title))}${timeout ? ` ${theme.fg("dim", timeout)}` : ""} ${theme.fg(success ? "success" : "warning", status)}`;
                if (items.length > recent.length) text += `\n${theme.fg("muted", `… ${items.length - recent.length} earlier items`)}`;
                for (const item of recent)text += `\n${theme.fg(item.type === "toolResult" && item.isError ? "error" : "dim", compactItem(item))}`;
                for (const activity of result.toolActivity.filter((item)=>item.status === "running")){
                    text += `\n${theme.fg("warning", `⚙ ${formatToolCall(activity.name, activity.args)}`)}`;
                }
                const stats = usageText(result);
                if (stats) text += `\n${theme.fg("dim", stats)}`;
                if (result.sessionFile) text += `\n${theme.fg("dim", `session: ${result.sessionFile}`)}`;
                return new Text(text, 0, 0);
            }
            const container = new Container();
            container.addChild(new Text(`${icon} ${theme.fg("toolTitle", theme.bold(title))}${timeout ? ` ${theme.fg("dim", timeout)}` : ""} ${theme.fg(success ? "success" : "warning", status)}`, 0, 0));
            container.addChild(new Spacer(1));
            container.addChild(new Text(theme.fg("muted", "── Task ──"), 0, 0));
            container.addChild(new Text(result.task, 0, 0));
            container.addChild(new Spacer(1));
            container.addChild(new Text(theme.fg("muted", "── Activity ──"), 0, 0));
            for (const item of items){
                if (item.type === "text") continue;
                container.addChild(new Text(theme.fg(item.type === "toolResult" && item.isError ? "error" : "dim", compactItem(item)), 0, 0));
            }
            container.addChild(new Spacer(1));
            container.addChild(new Text(theme.fg("muted", "── Result ──"), 0, 0));
            container.addChild(new Markdown(resultOutput(result), 0, 0, getMarkdownTheme()));
            const stats = usageText(result);
            if (stats) container.addChild(new Text(theme.fg("dim", stats), 0, 0));
            if (result.sessionFile) container.addChild(new Text(theme.fg("dim", `session: ${result.sessionFile}`), 0, 0));
            return container;
        }
    });
}
