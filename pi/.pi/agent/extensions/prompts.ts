import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("prompts", {
    description: "Pick and paste a prompt from ~/.config/pi/prompts.txt",
    handler: async (_args, ctx) => {
      if (ctx.mode !== "tui") {
        ctx.ui.notify("/prompts requires interactive TUI mode", "error");
        return;
      }

      const file = join(homedir(), ".config/pi/prompts.txt");
      let contents: string;
      try {
        contents = await readFile(file, "utf8");
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        ctx.ui.notify(`Could not read ${file}: ${message}`, "error");
        return;
      }

      const prompts = contents
        .split(/^---[\t ]*\r?$/m)
        .map((prompt) => prompt.trim())
        .filter(Boolean);

      if (prompts.length === 0) {
        ctx.ui.notify(`No prompts in ${file}. Separate prompts with a line containing ---.`, "info");
        return;
      }

      // Number the titles so identical first lines still identify distinct prompts.
      const labels = prompts.map((prompt, index) => `${index + 1}. ${prompt.split(/\r?\n/)[0]}`);
      const selected = await ctx.ui.select("Prompt >", labels);
      if (selected === undefined) return;

      const index = labels.indexOf(selected);
      if (index !== -1) {
        const padded = prompts[index] + "\n".repeat(11);
        ctx.ui.pasteToEditor(padded);
      }
    },
  });
}
