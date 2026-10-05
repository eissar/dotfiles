/**
 * queue-submit — press Enter while streaming queues a follow-up instead of
 * steering. Idle Enter, Alt+Enter, and bash `!` mode are untouched.
 *
 * Mechanism: while streaming, Enter submits via prompt(steer), which emits
 * the `input` event with streamingBehavior "steer". The event result cannot
 * change the delivery mode, so the handler returns { action: "handled" } and
 * re-dispatches via pi.sendUserMessage(..., { deliverAs: "followUp",
 * expandPromptTemplates: true }) to keep command dispatch and template
 * expansion identical to the default flow.
 *
 * Note: pi.sendUserMessage is typed Promise<void> but returns void at runtime
 * (pi's wrapper is fire-and-forget with internal error handling), so it is
 * called without await.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** Decide whether an input event should be re-queued as a follow-up. */
export function shouldQueueOnEnter(event: {
	source: string;
	streamingBehavior?: "steer" | "followUp";
}): boolean {
	// Only typed Enter submissions that would steer. source "extension"
	// excludes our own re-dispatch (prevents recursion); "followUp" excludes
	// Alt+Enter; undefined means the agent is idle.
	return event.source === "interactive" && event.streamingBehavior === "steer";
}

export default function queueFollowUpOnEnter(pi: ExtensionAPI) {
	pi.on("input", async (event) => {
		if (!shouldQueueOnEnter(event)) {
			return { action: "continue" };
		}

		pi.sendUserMessage(
			event.images?.length
				? [{ type: "text" as const, text: event.text }, ...event.images]
				: event.text,
			{
				deliverAs: "followUp",
				expandPromptTemplates: true,
			},
		);

		// Suppress the original steer delivery; the follow-up is queued.
		return { action: "handled" };
	});
}
