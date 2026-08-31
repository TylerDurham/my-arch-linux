---
description: Create a well-formed GitHub issue for the current repo using gh
argument-hint: "<description> [--label <label>] [--assignee <user>]"
allowed-tools: Bash(gh issue create:*), Bash(gh repo view:*), Bash(git log:*), Bash(git branch:*), Bash(git status:*)
---

## Arguments

Parse `$ARGUMENTS` as follows:
- Extract any `--label <value>` flags and collect them as labels (may repeat)
- Extract any `--assignee <value>` flag
- Everything remaining is the **issue description** provided by the user

If no description is provided, ask the user for one before proceeding.

## Context

- Current repo: !`gh repo view --json nameWithOwner -q .nameWithOwner`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`
- Working tree status: !`git status --short`

## Your task

Using the description and context above, create a GitHub issue.

### Step 1 — Determine issue type

Pick one: `bug` | `feat` | `chore` | `docs` | `refactor` | `perf`

Infer from the description. If the description mentions something broken, prefer `bug`. If it's a new capability, prefer `feat`.

### Step 2 — Draft the issue

**Title**: `<type>(<scope>): <concise imperative summary>` — ≤72 chars, no trailing period.
- Derive `scope` from the description or recent commits (omit if too broad).

**Body** — structured markdown:

```
## Summary

<1-3 sentence explanation of what this issue is about and why it matters>

## Details

<for bugs: steps to reproduce, expected vs actual behavior>
<for feats: proposed behavior, acceptance criteria as a checklist>
<for chores/docs/refactor: what needs doing and why>

## Acceptance criteria

- [ ] <specific, testable criterion>
- [ ] <...>
```

### Step 3 — Create the issue

Run `gh issue create` passing title and body via heredoc. Append `--label` and `--assignee` flags only if provided by the user.

```bash
gh issue create \
  --title "<title>" \
  --body "$(cat <<'EOF'
<body>
EOF
)" [--label <label>] [--assignee <user>]
```

After creating, output the issue URL on a single line. Do not add any other commentary.
