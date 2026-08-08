#!/usr/bin/env python3
"""Split REGISTER.md into one file per series, per its own stated rule.

The rule is in the file: "One file until it passes about 800 lines, then one
file per series under `register/`, with this file becoming the index." It is at
1,655 lines.

⚠ IT ALSO RESOLVES A DUPLICATE NUMBER. Two different findings were both called
`I.11` — an island that advertised once and could never be raided, and an island
that stopped while reporting healthy — so three citations across the repository
pointed at an ambiguous target. The OLDER keeps the number; the newer becomes
the next free one. Renumbering the older would have invalidated citations that
were correct when they were written.

Everything is moved verbatim. The index is generated from the headings, so it
cannot drift from what is actually in the files.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "REGISTER.md"
OUT = ROOT / "register"

# The newer of the two, which gives up the number.
RENUMBER = ("I.11", "I.24", "the island advertised once")

WORLD = OUT / "FINDINGS_ABOUT_THE_WORLD.md"
WORK = OUT / "FINDINGS_ABOUT_THE_WORK.md"

HEADING = re.compile(r"^## ([DI])\.(\d+): (.*)$")


def entries(lines):
    """[(series, number, title, [lines])] in file order."""
    out = []
    for i, line in enumerate(lines):
        m = HEADING.match(line.rstrip("\n"))
        if m:
            out.append([m.group(1), int(m.group(2)), m.group(3), i])
    found = []
    for n, (series, num, title, start) in enumerate(out):
        end = out[n + 1][3] if n + 1 < len(out) else len(lines)
        found.append((series, num, title, lines[start:end]))
    return found


def main():
    text = SRC.read_text()
    lines = text.splitlines(keepends=True)

    found = entries(lines)
    if not found:
        sys.exit("no entries found")

    # The preamble is everything before the first entry, minus the stale
    # mid-document series banners, which the split makes meaningless.
    first = next(i for i, l in enumerate(lines) if HEADING.match(l.rstrip("\n")))
    preamble = "".join(lines[:first])

    # Resolve the duplicate: the LAST occurrence in file order is the older one
    # (the file is newest-first), so the FIRST occurrence gives up the number.
    old_id, new_id, marker = RENUMBER
    series, num = old_id.split(".")
    dupes = [e for e in found if f"{e[0]}.{e[1]}" == old_id]
    if len(dupes) == 2:
        renumbered = []
        done = False
        for e in found:
            if not done and f"{e[0]}.{e[1]}" == old_id and marker in e[2]:
                body = "".join(e[3])
                body = body.replace(f"## {old_id}:", f"## {new_id}:", 1)
                note = (
                    f"\n> ⚠ **RENUMBERED FROM `{old_id}` ON 2026-08-08.** Two different "
                    f"findings carried that number: this one and the island that stopped "
                    f"while reporting healthy. Three citations across the repository "
                    f"pointed at an ambiguous target. The older entry keeps `{old_id}`, "
                    f"because renumbering it would have invalidated citations that were "
                    f"correct when they were written.\n"
                )
                head, rest = body.split("\n", 1)
                body = head + "\n" + note + rest
                new_series, new_num = new_id.split(".")
                renumbered.append((new_series, int(new_num), e[2], [body]))
                done = True
            else:
                renumbered.append(e)
        found = renumbered
        print(f"renumbered {old_id} -> {new_id} ({marker}...)", file=sys.stderr)
    elif len(dupes) > 2:
        sys.exit(f"{old_id} appears {len(dupes)} times, refusing to guess")

    OUT.mkdir(exist_ok=True)

    for path, want, title, blurb in [
        (WORLD, "D", "Findings about the world", "What this repository's simulated world turned out to be like. Every entry is something the code or the fleet did that nobody predicted."),
        (WORK, "I", "Findings about the work", "How the work itself went wrong. Every entry is a mistake that was paid for once, written down so it is not paid for twice."),
    ]:
        mine = [e for e in found if e[0] == want]
        mine.sort(key=lambda e: -e[1])
        body = "".join("".join(e[3]).rstrip() + "\n\n" for e in mine)
        path.write_text(
            f"# {title}\n\n{blurb}\n\n"
            f"⚠ **Every entry carries an ELI5 section. No exceptions.** `CHARTER.md` rule 10.\n"
            f"The index, and the rule itself, are in [`../REGISTER.md`](../REGISTER.md).\n\n"
            f"---\n\n{body}"
        )
        print(f"{path.name}: {len(mine)} entries, {len(path.read_text().splitlines())} lines", file=sys.stderr)

    index = ["\n## The entries\n\n"]
    for path, want, label in [(WORK, "I", "work"), (WORLD, "D", "world")]:
        mine = sorted([e for e in found if e[0] == want], key=lambda e: -e[1])
        index.append(f"### `{want}` — findings about the {label}\n\n")
        index.append(f"In [`register/{path.name}`](register/{path.name}), newest first.\n\n")
        index.append("| | |\n|---|---|\n")
        for series, num, title, _ in mine:
            anchor = re.sub(r"[^a-z0-9 -]", "", f"{series}{num} {title}".lower()).replace(" ", "-")
            index.append(f"| [`{series}.{num}`](register/{path.name}#{anchor}) | {title} |\n")
        index.append("\n")

    SRC.write_text(preamble.rstrip() + "\n" + "".join(index))
    print(f"REGISTER.md is now {len(SRC.read_text().splitlines())} lines", file=sys.stderr)


if __name__ == "__main__":
    main()
