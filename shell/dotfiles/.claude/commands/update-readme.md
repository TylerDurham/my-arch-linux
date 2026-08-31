---
description: Sync the README to reflect the current state of the repo
argument-hint: "[<hint about what changed>]"
allowed-tools: Read, Edit, Write, Bash(find:*), Bash(ls:*), Bash(git log:*), Bash(git diff:*), Bash(git branch:*), Bash(git status:*), Bash(grep:*)
---

## Arguments

Parse `$ARGUMENTS`:
- Everything provided is a **hint** describing what changed or what area to focus on (optional).
  If omitted, do a general sync of the full README.

## Context

Gather before editing:

- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -20`
- Changed files (vs main/master): !`git diff origin/master...HEAD --name-only 2>/dev/null || git diff origin/main...HEAD --name-only 2>/dev/null`
- Repo root contents: !`ls -1`

Then:
1. Read the existing README (find it with `find . -maxdepth 2 -name "README*" | head -1`).
2. If a `.claude/commands/` directory exists, list its files to get the current command set.
3. If a `bin/` or `.local/share/my/bin/` directory exists, list its files to get the current CLI utilities.

## Steps

### 1 — Identify what's stale or missing

Cross-reference the README against the actual repo state:

- **Claude Code commands table**: compare listed commands against files in `.claude/commands/`. Add missing entries; remove entries whose files no longer exist; update descriptions that no longer match the file's `description:` frontmatter field.
- **File/directory tables** (tmux, shell, bin, lib, etc.): compare listed files against what actually exists on disk. Remove entries for deleted files; add entries for new files that belong in the table.
- **Project layout tree**: update any paths or filenames that have changed.
- **Other sections**: apply the user's hint (if provided) to identify any other areas needing updates.

Do not rewrite sections that are accurate. Touch only what is stale or missing.

### 2 — Edit the README

Apply all identified changes in a single Edit pass. Preserve the existing style, tone, and formatting — do not rewrite sections that are already accurate.

- Table entries: keep column alignment consistent with the existing table style.
- Descriptions: match the brevity and voice of existing entries (short, imperative or noun-phrase, no trailing period).
- Do not add new sections unless the repo clearly has a major feature area with no coverage.

### 3 — Report

After editing, print a short bullet list of what changed (added, removed, or updated). Keep it to one line per change.
