Look at the currently staged git changes and create a commit with a well-formed conventional commit message.

Steps:
1. Run `git diff --staged` to see all staged changes.
2. Run `git status` to see which files are staged.
3. Analyze the changes and determine:
   - **type**: one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
   - **scope** (optional): the area of the codebase affected (e.g. a module, component, or config file name)
   - **description**: a concise imperative-mood summary (≤72 chars total for the subject line)
   - **breaking change**: if any, add `!` after the type/scope and a `BREAKING CHANGE:` footer
4. If there are no staged changes, tell the user and stop.
5. Commit using the conventional commit format:

```
<type>(<scope>): <description>

[optional body — only if the why or context is non-obvious]

[optional footers, e.g. BREAKING CHANGE: ...]
```

Pass the commit message via a heredoc so formatting is preserved:
```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>
EOF
)"
```
Do **not** add files that are not staged.
Do **not** add a `Co-Authored-By` trailer unless the user asks.
Do **not** ask for confirmation — just commit.
After committing, show the one-line result from `git log --oneline -1`.
