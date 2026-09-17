import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Session entries store message content in a few shapes depending on role.
// Flatten to plain text so we can search it uniformly.
function entryText(message: any): string {
  const content = message?.content;
  if (typeof content === "string") return content;

  const parts: string[] = [];
  if (Array.isArray(content)) {
    for (const block of content) {
      if (block?.type === "text" && typeof block.text === "string") {
        parts.push(block.text);
      }
    }
  }

  // bash executions carry the command outside `content`
  if (typeof message?.command === "string") parts.push(message.command);

  return parts.join("\n");
}

const MAX_MATCHES = 50;
const PREVIEW = 80;

export default function (pi: ExtensionAPI) {
  pi.registerCommand("find", {
    description: "Search earlier messages and jump to a match",
    handler: async (args, ctx) => {
      const query = args.trim().toLowerCase();
      if (!query) {
        ctx.ui.notify("Usage: /find <text>", "warning");
        return;
      }

      const matches: { id: string; label: string }[] = [];

      for (const entry of ctx.sessionManager.getEntries()) {
        if (entry.type !== "message") continue;

        const message = (entry as any).message;
        const text = entryText(message);
        if (!text.toLowerCase().includes(query)) continue;

        const role = message?.role ?? "message";
        const preview = text.replace(/\s+/g, " ").trim().slice(0, PREVIEW);
        matches.push({ id: entry.id, label: `${role}: ${preview}` });

        if (matches.length >= MAX_MATCHES) break;
      }

      if (matches.length === 0) {
        ctx.ui.notify(`No matches for "${args.trim()}"`, "info");
        return;
      }

      const choice = await ctx.ui.select(
        `${matches.length} match(es) for "${args.trim()}"`,
        matches.map((m) => m.label),
      );
      if (choice === undefined) return;

      const index = matches.findIndex((m) => m.label === choice);
      if (index === -1) return;

      // navigateTree moves the leaf, so continuing from here branches.
      const { cancelled } = await ctx.navigateTree(matches[index].id);
      if (!cancelled) ctx.ui.notify(`Moved to match ${index + 1}`, "info");
    },
  });
}
