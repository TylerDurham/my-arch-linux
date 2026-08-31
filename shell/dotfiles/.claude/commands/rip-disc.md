---
description: Rip Blu-ray / 4K UHD discs with MakeMKV — list titles and rip interactively into ~/Rippy/@imports
argument-hint: "[disc-number]"
allowed-tools: Bash(/Applications/MakeMKV.app/Contents/MacOS/makemkvcon:*), Bash(mkdir:*), Bash(mv:*), Bash(find:*), Bash(ls:*), Bash(awk:*), Bash(grep:*), Bash(printf:*), Bash(du:*)
---

Interactively list and rip Blu-ray or 4K UHD discs using MakeMKV's CLI.

## Constants

- **MakeMKV CLI**: `/Applications/MakeMKV.app/Contents/MacOS/makemkvcon`
- **Output base**: `$HOME/Rippy/@imports`

## Step 1 — Determine disc number

Parse `$ARGUMENTS`. If the first token is a digit (0–9), use it as the disc number; otherwise default to `0`. The MakeMKV device identifier is `disc:<N>`.

## Step 2 — Scan the disc

Run makemkvcon in machine-readable mode to gather title info:

```bash
/Applications/MakeMKV.app/Contents/MacOS/makemkvcon -r info disc:<N>
```

If the output contains no `TINFO:` lines or includes an error message like "disc is not available" or "failed to open disc", tell the user no disc was detected in drive <N> and stop.

## Step 3 — Parse and display title list

From the `-r info` output, parse `TINFO:<id>,<code>,<type>,"<value>"` lines. Relevant field codes:

| Code | Meaning |
|------|---------|
| 11   | Duration (`H:MM:SS` or `HH:MM:SS`) |
| 10   | Size in bytes |
| 27   | Default output filename (e.g. `title_t00.mkv`) |
| 28   | Chapter count |

Convert sizes to GB (bytes ÷ 1,073,741,824, one decimal place).

Display a table to the user:

```
#   Duration    Size      Chapters
--  ----------  --------  --------
0   2:22:14     47.3 GB   28         ← likely main feature
1   0:04:12     1.2 GB    3
2   0:01:48     0.5 GB    1
```

Mark the title with the longest duration as "← likely main feature".

## Step 4 — Gather rip details from the user

Ask the user for the following. Collect all answers before proceeding:

1. **Which title(s) to rip?** — comma-separated IDs (e.g. `0` for main feature, `0,1,2` for several)
2. **Movie or TV Show?**
3. **Title name** — the movie or show name as it should appear in the folder (e.g. `Dune Part Two`)
4. **Release year** (four digits)
5. *(TV only)* **Season number** — integer, will be zero-padded to 2 digits
6. *(TV only)* **Starting episode number** — integer; increments by one for each additional selected title

## Step 5 — Create output directory

Build the output path (expand `$HOME` to the literal home directory):

**Movie**
```
$HOME/Rippy/@imports/Title Name (YEAR)/
```

**TV Show**
```
$HOME/Rippy/@imports/Show Name (YEAR)/SeasonXX/
```
where `XX` is the zero-padded season number (e.g. `Season01`, `Season03`).

Run:
```bash
mkdir -p "<output_dir>"
```

Confirm the directory exists before ripping.

## Step 6 — Rip each selected title

For each selected title ID, rip it to the output directory. Rips can take 30–90 minutes, so run **in the background** (`run_in_background: true`) and use the Monitor tool to stream progress.

```bash
/Applications/MakeMKV.app/Contents/MacOS/makemkvcon mkv disc:<N> <title_id> "<output_dir>"
```

While monitoring, parse these output line types:
- `PRGV:<current>,<total>,<max>` — show progress as `<current>/<max>` and a percentage
- `MSG:<code>,<flags>,<count>,"<message>"` — surface any warnings or errors to the user
- A clean exit (status 0) means success; non-zero means failure

If multiple titles are selected, rip them **sequentially** (start the next only after the previous completes).

## Step 7 — Rename output file

After each rip, find the generated `title_t*.mkv` file in the output directory:

```bash
find "<output_dir>" -maxdepth 1 -name "title_t*.mkv"
```

Rename it to the final name:

**Movie**:
```
Title Name (YEAR).mkv
```

**TV episode** (Plex naming convention):
```
Show Name (YEAR) - sXXeYY.mkv
```
- `XX` = zero-padded season (e.g. `s01`, `s03`) — lowercase `s`
- `YY` = zero-padded episode, starting at the user-supplied episode number and incrementing by one per title — lowercase `e`

Run:
```bash
mv "<output_dir>/title_t<NN>.mkv" "<output_dir>/<final_name>.mkv"
```

## Step 8 — Report result

For each ripped title, report:
- Final file path
- File size (run `du -sh "<file>"`)

If any title failed, report the error clearly and suggest re-running just that title.
