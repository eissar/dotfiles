import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { fuzzyFilter } from "@earendil-works/pi-tui";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;

    ctx.ui.addAutocompleteProvider((current) => ({
      triggerCharacters: [...new Set([...(current.triggerCharacters ?? []), "@"])],
      async getSuggestions(lines, cursorLine, cursorCol, options) {
        const before = (lines[cursorLine] ?? "").slice(0, cursorCol);
        const match = before.match(/(?:^|\s)@@([^\s@]*)$/);
        if (!match) return current.getSuggestions(lines, cursorLine, cursorCol, options);

        const models = ctx.modelRegistry.getAvailable();
        const matches = fuzzyFilter(models, match[1], (model) =>
          `${model.provider}/${model.id} ${model.name}`,
        );
        return {
          prefix: `@@${match[1]}`,
          items: matches.slice(0, 50).map((model) => ({
            value: `@@${model.provider}/${model.id}`,
            label: `@@${model.provider}/${model.id}`,
            description: model.name,
          })),
        };
      },
      applyCompletion(lines, cursorLine, cursorCol, item, prefix) {
        if (!prefix.startsWith("@@")) {
          return current.applyCompletion(lines, cursorLine, cursorCol, item, prefix);
        }
        const updated = [...lines];
        const line = updated[cursorLine] ?? "";
        const start = cursorCol - prefix.length;
        const insertion = `${item.value.replace(/^@@/, "")} `;
        updated[cursorLine] = line.slice(0, start) + insertion + line.slice(cursorCol);
        return { lines: updated, cursorLine, cursorCol: start + insertion.length };
      },
      shouldTriggerFileCompletion(lines, cursorLine, cursorCol) {
        const before = (lines[cursorLine] ?? "").slice(0, cursorCol);
        if (/(?:^|\s)@@[^\s@]*$/.test(before)) return false;
        return current.shouldTriggerFileCompletion?.(lines, cursorLine, cursorCol) ?? true;
      },
    }));
  });
}
