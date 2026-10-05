/**
 * Tests for the queue-submit extension.
 * Run: node --test /home/eissar/dotfiles/pi/.pi/agent/tests/queue-submit.test.ts
 *
 * Uses a mocked ExtensionAPI to exercise the registered `input` handler:
 * return values (handled/continue) and sendUserMessage payload/options.
 */
import test from "node:test";
import assert from "node:assert/strict";
import queueFollowUpOnEnter, {
	shouldQueueOnEnter,
} from "../extensions/queue-submit.ts";

/** Minimal mocked ExtensionAPI capturing the input handler and sendUserMessage calls. */
function mockPi() {
	const calls = [];
	let inputHandler;
	const pi = {
		on(event, handler) {
			if (event === "input") inputHandler = handler;
		},
		sendUserMessage(content, options) {
			calls.push({ content, options });
		},
	};
	queueFollowUpOnEnter(pi);
	assert.ok(inputHandler, "extension must register an input handler");
	return { calls, inputHandler };
}

const handled = { action: "handled" };
const continue_ = { action: "continue" };

test("queues typed Enter while steering: handled + followUp re-dispatch", async () => {
	const { calls, inputHandler } = mockPi();
	const result = await inputHandler({
		type: "input",
		text: "now also add tests",
		source: "interactive",
		streamingBehavior: "steer",
	});
	assert.deepEqual(result, handled);
	assert.equal(calls.length, 1);
	assert.equal(calls[0].content, "now also add tests");
	assert.deepEqual(calls[0].options, {
		deliverAs: "followUp",
		expandPromptTemplates: true,
	});
});

test("idle Enter passes through untouched", async () => {
	const { calls, inputHandler } = mockPi();
	const result = await inputHandler({
		type: "input",
		text: "hello",
		source: "interactive",
		streamingBehavior: undefined,
	});
	assert.deepEqual(result, continue_);
	assert.equal(calls.length, 0);
});

test("Alt+Enter (followUp) passes through untouched", async () => {
	const { calls, inputHandler } = mockPi();
	const result = await inputHandler({
		type: "input",
		text: "queued",
		source: "interactive",
		streamingBehavior: "followUp",
	});
	assert.deepEqual(result, continue_);
	assert.equal(calls.length, 0);
});

test("extension-sourced steer passes through (no recursion)", async () => {
	const { calls, inputHandler } = mockPi();
	const result = await inputHandler({
		type: "input",
		text: "redispatched",
		source: "extension",
		streamingBehavior: "followUp",
	});
	assert.deepEqual(result, continue_);
	assert.equal(calls.length, 0);
});

test("images are forwarded via content array", async () => {
	const { calls, inputHandler } = mockPi();
	const image = { type: "image", data: "aGk=", mimeType: "image/png" };
	const result = await inputHandler({
		type: "input",
		text: "what is this?",
		images: [image],
		source: "interactive",
		streamingBehavior: "steer",
	});
	assert.deepEqual(result, handled);
	assert.deepEqual(calls[0].content, [
		{ type: "text", text: "what is this?" },
		image,
	]);
	assert.deepEqual(calls[0].options, {
		deliverAs: "followUp",
		expandPromptTemplates: true,
	});
});

test("predicate: only interactive+steer qualifies", () => {
	assert.equal(
		shouldQueueOnEnter({ source: "interactive", streamingBehavior: "steer" }),
		true,
	);
	assert.equal(
		shouldQueueOnEnter({ source: "interactive", streamingBehavior: "followUp" }),
		false,
	);
	assert.equal(
		shouldQueueOnEnter({ source: "interactive", streamingBehavior: undefined }),
		false,
	);
	assert.equal(
		shouldQueueOnEnter({ source: "rpc", streamingBehavior: "steer" }),
		false,
	);
});
