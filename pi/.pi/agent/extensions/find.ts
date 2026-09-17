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
  // Whether the transcript emits an OSC 133;A zone marker for this entry.
  // That is what scrollToPrompt can navigate to, so ordinals are counted
  // over marked entries only.
  marked: boolean;
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

      // Captured from the custom() factory so the jump can use the renderer
      // after the picker closes. The renderer is a Proxy over the live TUI.
      let tuiRef: any = null;

      const candidates: Candidate[] = [];

      for (const entry of ctx.sessionManager.getEntries()) {
        if (entry.type !== "message") continue;

        const message = (entry as any).message;
        const text = entryText(message);
        if (!text.trim()) continue;

        const role = message?.role ?? "message";
        const preview = text.replace(/\s+/g, " ").trim().slice(0, PREVIEW);

        // Mirror the transcript's marker rules:
        //   user-message.js      -> always emits OSC 133;A
        //   assistant-message.js -> emits it unless the message has tool calls
        //                           (the render early-returns on hasToolCalls)
        // Tool-calling assistant turns are therefore not addressable, which is
        // intentional: it keeps a zone from spanning tool output.
        const hasToolCalls = Array.isArray(message?.content) &&
          message.content.some((b: any) => b?.type === "toolCall");
        const marked = role === "user" || (role === "assistant" && !hasToolCalls);

        candidates.push({
          id: entry.id,
          label: `${role}: ${preview}`,
          haystack: `${role} ${text}`.toLowerCase(),
          marked,
        });

        if (candidates.length >= MAX_ITEMS) break;
      }

      if (candidates.length === 0) {
        ctx.ui.notify("No messages in this session", "info");
        return;
      }

      const chosenId = await ctx.ui.custom<string | null>((tui, theme, kb, done) => {
        tuiRef = tui;
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
        let matchedCount = candidates.length;

        const moveSelection = (delta: number) => {
          if (matchedCount === 0) return;
          selectedIndex = (selectedIndex + delta + matchedCount) % matchedCount;
          selectList?.setSelectedIndex(selectedIndex);
        };

        // SelectList only filters on `value.startsWith(...)`, which cannot do
        // substring search over message text. So we filter ourselves and hand
        // it the already-narrowed set on every keystroke.
        const rebuild = () => {
          const tokens = input.getValue().toLowerCase().split(/\s+/).filter(Boolean);
          const matched = tokens.length === 0
            ? candidates
            : candidates.filter((c) => tokens.every((t) => c.haystack.includes(t)));

          visibleCount = matched.length;
          matchedCount = matched.length;

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
            // SelectList resolves keys against the *global* keybinding manager,
            // which does not include the user's keybindings.json overrides (the
            // ctrl+p / ctrl+n remaps). Use the injected manager for selection
            // movement, and delegate confirm/cancel to SelectList so escape,
            // ctrl+c and enter keep their standard behavior.
            if (kb.matches(data, "tui.select.up")) {
              moveSelection(-1);
            } else if (kb.matches(data, "tui.select.down")) {
              moveSelection(1);
            } else if (
              kb.matches(data, "tui.select.confirm") ||
              kb.matches(data, "tui.select.cancel")
            ) {
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

      // Jump to the entry in the terminal without touching session state.
      // navigateTree would move the leaf and redraw the transcript for a new
      // branch, which is precisely what we are avoiding here.
      const target = candidates.find((c) => c.id === chosenId);

      // Ordinal among marker-emitting entries: what scrollToPrompt addresses.
      const ordinal = candidates.filter((c) => c.marked).findIndex((c) => c.id === chosenId);

      if (scrollToEntry(tuiRef, target?.marked ?? false, ordinal)) {
        ctx.ui.notify("Scrolled to match in transcript", "info");
        return;
      }

      // No scroll happened, so session state is untouched either way.
      ctx.ui.notify(
        target?.marked
          ? "Could not scroll (alt-screen TUI required). Transcript unchanged."
          : "This message has no zone marker (assistant replies with tool calls), so it cannot be targeted. Transcript unchanged.",
        "info",
      );
    },
  });
}

/**
 * Scroll the transcript viewport to a marker-emitting entry by ordinal.
 *
 * The alt-screen renderer exposes scrollToPrompt(direction), which scans the
 * rendered line buffer for OSC 133;A zone starts. Both user messages and
 * assistant replies without tool calls emit one, so `ordinal` must count over
 * exactly that set of entries.
 *
 * scrollToPrompt steps relative to the current viewport position, so we go to
 * the top first and then step forward `ordinal` times.
 *
 * scrollToPrompt is not part of the published TUI interface and does not exist
 * in regular (non-fullscreen) TUI mode, hence the feature detection.
 */
function scrollToEntry(tui: any, marked: boolean, ordinal: number): boolean {
  if (!tui || typeof tui.scrollToPrompt !== "function") return false;
  if (!marked || ordinal < 0) return false;

  try {
    if (typeof tui.scrollToTop === "function") tui.scrollToTop();
    for (let i = 0; i < ordinal; i += 1) {
      tui.scrollToPrompt(1);
    }
    return true;
  } catch {
    return false;
  }
}
