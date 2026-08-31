---
description: Stage and create a Conventional Commit (with optional issue close)
argument-hint: "<context> [issue-number]"
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*)
---

## Arguments

Parse `$ARGUMENTS` as follows:
- If the last whitespace-delimited token is a plain integer, treat it as the **issue number** and everything before it as the **context comment**.
- Otherwise the entire string is the **context comment** and there is no issue number.

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task

Using the diff above and the context comment provided by the user, craft and create a single Conventional Commit.

### Commit message rules

**Subject line** — `<type>(<scope>): <short description>`
- `type`: `feat` | `fix` | `docs` | `style` | `refactor` | `perf` | `test` | `chore` | `ci` | `build` | `revert`
- `scope`: derived from the changed files/module (omit if changes are too broad)
- Description: imperative mood, lowercase, no trailing period, ≤72 chars total

**Body** (optional) — one blank line after the subject, then a concise explanation of *why* if the diff alone doesn't make it obvious.

**Footer** — if an issue number was provided, append:
```
Closes #<issue-number>
```

**Co-author trailer** — always append:
```
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

### Staging and committing

Stage all modified and new tracked files, then create the commit. Pass the full message via a heredoc to preserve formatting:

```bash
git commit -m "$(cat <<'EOF'
<subject>

<body if needed>

<Closes #N if applicable>

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

Do not send any other text or messages — only the tool calls.
