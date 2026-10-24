---
name: message-me
description: Send the user a short message. Use when asked to "text me", "notify me", or to alert the user when a long task finishes.
---

# message-me

Send the user a message via proton-cli. The recipient address is stored privately in `~/.config/textme/recipient`; substitute it inline, never print it.

```bash
proton mail messages send --to "$(<~/.config/textme/recipient)" --subject "Note" --body "Build finished: 0 errors" --no-signature >/dev/null && echo sent
```

Body from stdin: `--body -`.

## Rules
- Use the command exactly as above, including `>/dev/null` (keeps the output to a single confirmation line).
- Never `cat`, `echo`, or otherwise reveal the contents of `~/.config/textme/recipient`.
- A subject is required (use "Note" or a 1–3 word subject). Keep the body short (under ~300 chars), plain text, no markdown.
- Don't send secrets, credentials, or large logs. Summarize instead.
- Only text when the user asked for it or opted in to notifications.
- On failure, tell the user to run `proton account login` themselves.
