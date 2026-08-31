---
description: Add an ASCII banner + description header to a file
argument-hint: <file-path>
allowed-tools: Read, Edit, Bash(figlet *), Bash(toilet *)
---

Generate a stylish ASCII banner header comment for the file at `$ARGUMENTS`.

## Steps

1. Read the file to understand what it does.

2. Derive a short title (1–3 words) for the banner — usually the filename stem or the primary export/function name.

3. Try to generate the banner:
   - Run `figlet -f slant "<title>"` — use the output if it succeeds.
   - Else run `toilet -f future "<title>"` — use the output if it succeeds.
   - Else hand-craft a block-letter ASCII banner using standard `#` characters.
   - Never wrap the banner in a box (no ┌─┐│└─┘ characters).

4. Write a concise description block (3–6 lines) beneath the banner explaining:
   - What the file does
   - Key inputs / outputs or public API
   - Usage example (if applicable)

5. Comment the entire header using the file's native comment syntax (`#` for shell/Python, `//` for JS/TS/C, `--` for SQL/Lua, etc.).

6. Prepend the header to the file, followed by a blank line, then the original content. Do not alter any existing code.

Output only the file edit — no explanatory text.
