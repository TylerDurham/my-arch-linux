---
description: Open a PR from the current branch using recent commits, then merge it
argument-hint: "[--base <branch>] [--draft]"
allowed-tools: Bash(git log:*), Bash(git branch:*), Bash(git status:*), Bash(git diff:*), Bash(git push:*), Bash(gh pr create:*), Bash(gh pr merge:*), Bash(gh pr view:*), Bash(gh repo view:*), Bash(grep:*), Bash(sed:*), Bash(tr:*)
---

## Arguments

Parse `$ARGUMENTS`:
- `--base <branch>` — target branch to merge into (default: `master`, fallback to `main` if master doesn't exist)
- `--draft` — create the PR as a draft (do not merge when draft)

## Context

- Repo: !`gh repo view --json nameWithOwner -q .nameWithOwner`
- Current branch: !`git branch --show-current`
- Base branch candidates: !`git branch -r | grep -E 'origin/(master|main)' | sed 's|origin/||' | tr -d ' '`
- Commits ahead of master: !`git log origin/master..HEAD --oneline 2>/dev/null || git log origin/main..HEAD --oneline 2>/dev/null`
- Full commit details: !`git log origin/master..HEAD --format="subject: %s%nbody: %b%n---" 2>/dev/null || git log origin/main..HEAD --format="subject: %s%nbody: %b%n---" 2>/dev/null`
- Diff stat: !`git diff origin/master...HEAD --stat 2>/dev/null || git diff origin/main...HEAD --stat 2>/dev/null`

## Steps

### 1 — Guard rails

- If the current branch is `master` or `main`, print an error and stop.
- If there are no commits ahead of the base branch, print an error and stop.
- Determine the base branch: use the `--base` argument if provided; otherwise prefer `master` if it exists on the remote, else `main`.

### 2 — Draft title and body from commit history

**Title**: Derive from the commits ahead of base:
- If there is a single commit, use its subject line verbatim (already conventional-commit formatted).
- If there are multiple commits, write a conventional-commit summary that captures the dominant type and scope across them (e.g. `refactor(tmux): ...`). ≤72 chars, imperative mood, no trailing period.

**Body** — structured markdown:

```
## Summary

<2-4 bullet points drawn from the commit subjects/bodies — what changed and why>

## Changes

<bullet list of notable files/areas touched, derived from the diff stat>

## Test plan

- [ ] Reload config and verify no errors
- [ ] <one or two scenario-specific checks inferred from the scope of changes>
```

### 3 — Create the PR

Push the branch first if it has no upstream:

```bash
git push -u origin HEAD
```

Then create the PR:

```bash
gh pr create \
  --base <base-branch> \
  --title "<title>" \
  --body "$(cat <<'EOF'
<body>
EOF
)" [--draft if --draft flag was passed]
```

Print the PR URL on its own line.

### 4 — Merge the PR (skip if `--draft`)

Wait briefly, then merge with squash and delete the remote branch:

```bash
gh pr merge --squash --delete-branch --auto
```

After merge, print: `Merged and branch deleted.`
Then remind the user to `git checkout master && git pull` locally.
