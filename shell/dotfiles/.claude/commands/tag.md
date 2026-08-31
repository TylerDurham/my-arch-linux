Create an annotated git tag on the current HEAD commit using semantic versioning.

Arguments: $ARGUMENTS — expected format: `[major|minor|patch] [description]`

Steps:
1. Parse $ARGUMENTS:
   - If the first word is `major`, `minor`, or `patch` (case-insensitive), that is the **bump type**. Everything after it is the **description**.
   - If $ARGUMENTS is empty, the bump type defaults to `patch` and the description is empty.
   - If the first word is none of the above, treat the entire $ARGUMENTS as a **description** and default the bump type to `patch`.

2. Determine the next tag name:
   - Run `git tag | grep -E '^v[0-9]{2}\.[0-9]{3}\.[0-9]{3}$' | sort -V | tail -1` to get the most recent canonically-formatted tag.
   - If no tags exist, start from `v00.000.000` and apply the bump (so the first tag will be `v00.000.001` for patch, `v00.001.000` for minor, `v01.000.000` for major).
   - Parse the latest tag with this regex: `v(\d+)\.(\d+)\.(\d+)` → major, minor, patch as integers.
   - Apply the bump:
     - `major`: increment major by 1, set minor = 0, set patch = 0
     - `minor`: keep major, increment minor by 1, set patch = 0
     - `patch`: keep major and minor, increment patch by 1
   - Format the new tag as `v{major:02d}.{minor:03d}.{patch:03d}` (major zero-padded to 2 digits, minor and patch zero-padded to 3 digits).

3. Validate the computed tag name:
   - Must not already exist locally (`git tag -l <name>`) — if it does, tell the user and stop.

4. Run `git log --oneline -1` to show which commit will be tagged.

5. Create the annotated tag:

```bash
git tag -a "<tag-name>" -m "<description>"
```

6. Show confirmation: print the tag name, the commit it points to (`git rev-parse --short <tag-name>`), and the tag message.

Do **not** push the tag to the remote unless the user asks.
Do **not** ask for confirmation — just tag.
