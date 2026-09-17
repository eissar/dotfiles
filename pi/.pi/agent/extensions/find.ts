import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Container, Input, SelectList, Text, type SelectItem } from "@earendil-works/pi-tui";

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

interface Candidate {
  id: string;
  label: string;
  haystack: string;
}

const MAX_ITEMS = 1000;
const PREVIEW = 100;

export default function (pi: ExtensionAPI) {
  pi.registerCommand("find", {
    description: "Search earlier messages and jump to a match",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/find requires interactive TUI mode", "error");
        return;
      }

      const candidates: Candidate[] = [];

      for (const entry of ctx.sessionManager.getEntries()) {
        if (entry.type !== "message") continue;

        const message = (entry as any).message;
        const text = entryText(message);
        if (!text.trim()) continue;

        const role = message?.role ?? "message";
        const preview = text.replace(/\s+/g, " ").trim().slice(0, PREVIEW);

        candidates.push({
          id: entry.id,
          label: `${role}: ${preview}`,
          haystack: `${role} ${text}`.toLowerCase(),
        });

        if (candidates.length >= MAX_ITEMS) break;
      }

      if (candidates.length === 0) {
        ctx.ui.notify("No messages in this session", "info");
        return;
      }

      const chosenId = await ctx.ui.custom<string | null>((tui, theme, _kb, done) => {
        const listTheme = {
          selectedPrefix: (text: string) => theme.fg("accent", text),
          selectedText: (text: string) => theme.fg("accent", text),
          description: (text: string) => theme.fg("muted", text),
          scrollInfo: (text: string) => theme.fg("dim", text),
          noMatch: (text: string) => theme.fg("warning", text),
        };
        const VISIBLE = 12;

        const container = new Container();
        const header = new Text("");
        const input = new Input({ placeholder: "Type to filter..." });
        const listHolder = new Container();
        const footer = new Text(theme.fg("dim", "type filter • ↑↓ navigate • enter jump • esc cancel"));

        container.addChild(header);
        container.addChild(input);
        container.addChild(listHolder);
        container.addChild(footer);

        let selectList: SelectList;
        let visibleCount = candidates.length;
        let selectedIndex = 0;

        // SelectList only filters on `value.startsWith(...)`, which cannot do
        // substring search over message text. So we filter ourselves and hand
        // it the already-narrowed set on every keystroke.
        const rebuild = () => {
          const tokens = input.getValue().toLowerCase().split(/\s+/).filter(Boolean);
          const matched = tokens.length === 0
            ? candidates
            : candidates.filter((c) => tokens.every((t) => c.haystack.includes(t)));

          visibleCount = matched.length;

          const items: SelectItem[] = matched.map((c) => ({ value: c.id, label: c.label }));
          selectList = new SelectList(items, VISIBLE, listTheme);
          selectList.setSelectedIndex(selectedIndex);
          selectList.onSelect = (item) => done(item.value);
          selectList.onCancel = () => done(null);
          selectList.onSelectionChange = () => {
            selectedIndex = matched.findIndex((c) => c.id === (selectList.getSelectedItem()?.value ?? ""));
            if (selectedIndex < 0) selectedIndex = 0;
          };

          listHolder.clear();
          if (matched.length === 0) {
            listHolder.addChild(new Text(theme.fg("warning", "  No matching messages")));
          } else {
            listHolder.addChild(selectList);
          }

          header.setText(
            theme.fg("accent", theme.bold("Find in session")) +
              "  " +
              theme.fg("dim", `${visibleCount}/${candidates.length} message(s)`),
          );
        };

        rebuild();

        return {
          render(width: number) {
            return container.render(width);
          },
          invalidate() {
            container.invalidate();
          },
          handleInput(data: string) {
            // With an empty filter there is nothing to edit, so let enter/esc
            // fall through to the list. Otherwise they belong to the list too.
            if (data === "\r" || data === "\n" || data === "\x1b") {
              selectList?.handleInput(data);
            } else {
              const before = input.getValue();
              input.handleInput(data);
              if (input.getValue() !== before) {
                selectedIndex = 0;
                rebuild();
              }
            }
            tui.requestRender();
          },
        };
      });

      if (chosenId === null || chosenId === undefined) return;

      // navigateTree moves the leaf, so continuing from here branches.
      const { cancelled } = await ctx.navigateTree(chosenId);
      if (!cancelled) ctx.ui.notify("Moved to match", "info");
    },
  });
}
