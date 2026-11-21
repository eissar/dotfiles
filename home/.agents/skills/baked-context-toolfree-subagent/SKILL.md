---
name: baked-context-toolfree-subagent
description: Run a tool-free reasoning subagent whose task is pre-loaded ("baked") with verbatim repo context, composed in codemode so the context never enters the orchestrator. Use when asked to "use a baked context subagent", "bake context into a subagent", or to answer a task with model <M> over source/spec files.
---

# baked-context-toolfree-subagent

Goal: the orchestrator's context is the scarce resource. Source material goes straight into the reasoning subagent's context. The orchestrator sees only section headers, the reasoning session path and the answer.

## Fatal preconditions

Abort early on any of these. Stop where you are, leave temp files in place, and report the current state to the user: which step, what failed, temp file paths, and any scout report.

- The scout replies with an abort report instead of a `perl` block.
- The Perl program exits non-zero or writes to stderr.
- The reasoning subagent fails.

## Steps

Do steps 1–3 in a single codemode script.

1. Get the composition program.
   - Write the Perl program yourself when you can list the needed files:
     - Start with `use strict; use warnings FATAL => 'all';`.
     - Expand folders with `git ls-files <dir>` inside the program, leaving out vendored, minified and generated files. Include each file whole.
     - For a declaration range, take start and end lines from `ctags -x --fields=+ne --_xformat='%F:%n-%{end} %N' <files>` run now. An empty `%{end}` marks a one-line declaration; take its enclosing declaration's range.
     - Before each section, print `=== <path>:<a>-<b>` (for whole files, `1-<last line>`). Print only headers and verbatim content.
   - When the needed files are unknown, run a scout subagent with tools [read, bash] that follows `~/.agents/skills/ctags-context-aggregate/SKILL.md`. Give it the task.
2. Materialize.
   - Take the code from the scout's fenced `perl` block.
   - Create a `mktemp` file under `/tmp` and write the program to it with the write tool.
   - From the repo root, run `perl <file>` with stderr sent to a second `mktemp` file.
   - Stdout is the context. Keep it in a variable; never return or print it.
3. Reason. Run a subagent with the user's model `<M>` and `tools: []`. Its task is the user's task, a request to cite `file:symbol` or `file:line`, and then the context. On success, delete the temp files. Return the context headers, the reasoning session path and the answer.
4. Report to the user what was included (the headers) and the answer.

## Follow-ups

- `resume` the reasoning session for further questions.
- Check a cited claim with a narrow `rg` or a short line range instead of reading whole files.
