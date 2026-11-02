---
name: git-commit
description: Commit staged git changes with a well-formed Conventional Commit message. Opens the message in nvim for review before committing. Use when the user asks to commit staged changes, create a commit, or run git commit.
---

# Git Commit

Look at the currently staged git changes and create a commit with a well-formed Conventional Commit message.

## Workflow

1. Run `git diff --staged` to see all staged changes.
2. Run `git status` to see which files are staged.
3. Analyze the changes and generate a Conventional Commit message:
   - **type**: one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
   - **scope** (optional): the area of the codebase affected, such as a module, component, or config file name
   - **description**: a concise imperative-mood summary, with a subject line of 72 characters or fewer
   - **breaking change**: if any, add `!` after the type or scope and include a `BREAKING CHANGE:` footer
4. If there are no staged changes, tell the user and stop.
5. Write the commit message to `/tmp/opencode/commit-msg.txt`
6. Open the file in `nvim` for the user to review and edit
7. After `nvim` closes, check if the file was modified:
   - If saved: commit using the message with `git commit -F /tmp/opencode/commit-msg.txt`
   - If not saved: abort and tell the user no commit was made
8. After committing, show the one-line result from `git log --oneline -1`

## Helper Script

A bash script is provided at `git-commit.sh` to handle the nvim workflow. The AI assistant generates the commit message, writes it to `/tmp/opencode/commit-msg.txt`, then calls:

```bash
bash /home/dtd/.config/opencode/skills/git-commit/git-commit.sh
```

Or with message as argument:

```bash
bash /home/dtd/.config/opencode/skills/git-commit/git-commit.sh "feat: add new feature"
```

The script:
- Opens the message file in nvim for review
- Commits only if the file has content after nvim closes
- Validates conventional commit format with prompting for non-matching messages
