---
description: Encode MakeMKV rips from ~/Rippy/@imports into ~/Rippy/movies or ~/Rippy/tv-shows using your HandBrake custom presets
argument-hint: "[mkv-path | folder-name-in-@imports]"
allowed-tools: Bash(HandBrakeCLI:*), Bash(find:*), Bash(ls:*), Bash(mkdir:*), Bash(python3:*), Bash(du:*)
---

Encode a ripped MKV from `~/Rippy/@imports` using HandBrake and your custom presets.

## Constants

- **Presets file**: `$HOME/Library/Containers/fr.handbrake.HandBrake/Data/Library/Application Support/HandBrake/UserPresets.json`
- **Imports base**: `$HOME/Rippy/@imports`
- **Movies output**: `$HOME/Rippy/movies`
- **TV output**: `$HOME/Rippy/tv-shows`

## Step 1 — Check HandBrakeCLI is available

Run:
```bash
HandBrakeCLI --version
```

If it fails with "command not found", stop and tell the user: `HandBrakeCLI is not installed. Install it with: brew install handbrake`

## Step 2 — Find source file(s)

Parse `$ARGUMENTS`:

- **Full path to a `.mkv` file** — use it directly as the single source
- **A folder name or partial path** — find `.mkv` files under `~/Rippy/@imports/<argument>/` recursively
- **No argument** — find all `.mkv` files under `~/Rippy/@imports/` recursively:

```bash
find "$HOME/Rippy/@imports" -name "*.mkv" | sort
```

If multiple files are found, display them as a numbered list and ask the user which to encode. Allow multiple selections (comma-separated). If only one file exists, confirm it and proceed.

## Step 3 — Detect content type and derive output path

For each selected source file, inspect its path to determine content type and build the output path:

**TV Show** — path contains a `SeasonXX` component (e.g. `…/Show Name (YEAR)/Season01/show - s01e01.mkv`):
- Content type: TV
- Output: `$HOME/Rippy/tv-shows/<Show Name (YEAR)>/<SeasonXX>/<filename>.mkv`

**Movie** — no `SeasonXX` in path (e.g. `…/Movie Name (YEAR)/Movie Name (YEAR).mkv`):
- Content type: Movie
- Output: `$HOME/Rippy/movies/<Movie Name (YEAR)>/<filename>.mkv`

The output filename is always identical to the input filename (already named with Plex conventions from the rip step). Only the base directory changes from `@imports` to `movies` or `tv-shows`.

Display the detected type and output path to the user and confirm before proceeding.

## Step 4 — Display available presets and get selection

Parse the presets file to extract your custom presets:

```bash
python3 -c "
import json, sys
with open('$HOME/Library/Containers/fr.handbrake.HandBrake/Data/Library/Application Support/HandBrake/UserPresets.json') as f:
    data = json.load(f)

def find_folder(items, name):
    for item in items:
        if item.get('PresetName') == name:
            return item
        found = find_folder(item.get('ChildrenArray', []), name)
        if found:
            return found
    return None

my = find_folder(data['PresetList'], 'My Presets')
if my:
    for i, p in enumerate(my.get('ChildrenArray', [])):
        enc = p.get('VideoEncoder','?')
        rf  = p.get('VideoQualitySlider','?')
        w   = p.get('PictureWidth','?')
        h   = p.get('PictureHeight','?')
        print(f'{i})  {p[\"PresetName\"]}  [{enc}  RF={rf}  {w}x{h}]')
"
```

Display the output as a numbered list and ask: **Which preset would you like to use?**

## Step 5 — Create output directory and encode

For each file to encode:

1. Create the output directory:
```bash
mkdir -p "<output_dir>"
```

2. Run HandBrakeCLI **in the background** (encodes can take 1–4 hours). Use `run_in_background: true`:

```bash
HandBrakeCLI \
  --preset-import-file "$HOME/Library/Containers/fr.handbrake.HandBrake/Data/Library/Application Support/HandBrake/UserPresets.json" \
  --preset "My Presets/<SelectedPresetName>" \
  -i "<input_path>" \
  -o "<output_path>"
```

If multiple files are selected, encode them **sequentially** — start the next only after the previous completes.

## Step 6 — Monitor progress

Use the Monitor tool to stream output from the background process. HandBrakeCLI outputs progress lines like:

```
Encoding: task 1 of 1, 23.45 % (98.76 fps, avg 87.34 fps, ETA 01h14m22s)
```

Filter for and display:
- Lines containing `%` — show percentage and ETA
- Lines containing `error` or `Error` — surface immediately
- Final line `Encode done!` — signals completion

## Step 7 — Report result

After each encode completes:
- Run `du -sh "<output_path>"` and report the final file size
- Compare to source size (`du -sh "<input_path>"`) to show the compression ratio
- Report the full output path

If the encode fails (non-zero exit), report the last error line from the output and suggest re-running just that file.
