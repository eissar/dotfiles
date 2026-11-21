---
name: ctags-context-aggregate
description: Scout step for baked-context subagents. Given a task, write a Perl program whose stdout is the verbatim context for that task, chosen from ctags declaration listings. Use when invoked by baked-context-toolfree-subagent, or when asked to "aggregate context" for a task.
---

# ctags-context-aggregate

Input: a task, plus any paths the user named. Output: a single fenced `perl` block whose stdout is the full, verbatim context for the task. On abort, the output is an abort report instead.

Choose context from ctags listings and narrow `rg` matches. Leave reading source files to the Perl program.

## Fatal preconditions

Abort early on any of these. Stop, and reply with a report of the current state: which step, what failed, and what you found so far.

- An extension that matters to the task has no ctags parser (`NONE`).
- `gh` is unavailable while you check upstream support.
- `ctags`, `git` or `perl` is missing or fails.

## Steps

1. Languages. List tracked files with `git ls-files`, leaving out vendored, minified and generated files. Pass the list to `ctags --print-language -L -` and summarize it by extension and language, with a count and a sample path for each.
2. Upstream support. For each relevant `NONE` extension, use `gh` to search the master branch of https://github.com/universal-ctags/ctags (`parsers/`, `optlib/`, `peg/`) for that language. Then abort. The report includes:
   - extensions, file counts and sample paths
   - `ctags --version`
   - the upstream parser path and the date of the commit that added it, or "not found in parsers/, optlib/, peg/"
   - a suggested remedy: build a newer ctags, add a `.ctags.d/` regex, or use `rg` for that language

   Files with irrelevant `NONE` extensions can still be included by path.
3. Declarations. Pass the same filtered file list to `ctags -L - -x --sort=no --_xformat='%F:%n %C'` and cap line length with `cut -c1-240`. Add `--fields=+ne` and `%{end}` when you need start and end lines.
4. Select. Choose whole files, line ranges, declarations by start and end line, and the output of read-only commands (`ctags`, `rg`, `git log`, `git show`).
5. Write the program.
   - Start with `use strict; use warnings FATAL => 'all';`.
   - Read files and run commands when the program runs. Leave file contents out of the program text.
   - Before each section, print a header: `=== <path>:<a>-<b>` (for whole files, `1-<last line>`) or `=== $ <cmd>`.
   - Print only headers and verbatim content.
6. Validate without reading the content. Write the program to a `mktemp` file and check it with `perl -c`. Then run it and show only the headers, each with its section's line count. Confirm every intended section is present, non-empty and a sensible size. Fix only on failure. Delete the temp file afterwards.

## Reply

Only the fenced `perl` block, or the abort report.
