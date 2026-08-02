#!/usr/bin/env python3
"""Escape-token scan for a Lean 4 development.

Looks for the ways a Lean development can appear to prove something without
the kernel actually establishing it: `sorry`, `admit`, bespoke `axiom`
declarations, `opaque` definitions, and the compiler/native escape hatches
(`native_decide`, `ofReduceBool`, `trustCompiler`).

Comments are stripped BEFORE searching. A plain grep is not good enough:
Wang's Erdos1002 development contains the docstring "The surviving literal
terms admit an exact disjoint partition", and a naive scan flags the English
word `admit` and fails a clean repository. Lean's nested block comments mean
this cannot be done with a regex alone.

Usage:  escape_scan.py <path> [<path> ...]
Exit 0 and print "escape scan clean" if nothing is found; exit 1 and list
every hit as file:line: token otherwise.
"""

import re
import sys
from pathlib import Path

TOKENS = [
    "sorry", "admit", "native_decide", "ofReduceBool", "trustCompiler",
]
# Declaration keywords are only forbidden at the start of a declaration.
DECL_KEYWORDS = ["axiom", "opaque"]

TOKEN_RE = re.compile(r"\b(" + "|".join(TOKENS) + r")\b")
DECL_RE = re.compile(r"^\s*(?:@\[[^\]]*\]\s*)?(?:private\s+|protected\s+|noncomputable\s+)*"
                     r"(" + "|".join(DECL_KEYWORDS) + r")\b")


def strip_comments(src: str) -> str:
    """Blank out Lean comments, preserving line structure and column count.

    Handles nested `/- ... -/`, doc comments `/-- ... -/`, and `--` line
    comments. String literals are respected so that a `--` inside a string
    does not start a comment, and their contents are blanked too: a `sorry`
    inside a string cannot make the kernel accept anything, so flagging it
    would be noise. Replaced characters become spaces, so reported line
    numbers stay exact.
    """
    out = list(src)
    i, n = 0, len(src)
    depth = 0
    in_string = False
    while i < n:
        c = src[i]
        nxt = src[i + 1] if i + 1 < n else ""
        if depth == 0 and not in_string and c == '"':
            in_string = True
            i += 1
            continue
        if in_string:
            if c == "\\":
                out[i] = " "
                if i + 1 < n and src[i + 1] != "\n":
                    out[i + 1] = " "
                i += 2
                continue
            if c == '"':
                in_string = False
            elif c != "\n":
                out[i] = " "
            i += 1
            continue
        if c == "/" and nxt == "-":
            depth += 1
            out[i] = out[i + 1] = " "
            i += 2
            continue
        if c == "-" and nxt == "/" and depth > 0:
            depth -= 1
            out[i] = out[i + 1] = " "
            i += 2
            continue
        if depth > 0:
            if c != "\n":
                out[i] = " "
            i += 1
            continue
        if c == "-" and nxt == "-":
            while i < n and src[i] != "\n":
                out[i] = " "
                i += 1
            continue
        i += 1
    return "".join(out)


def scan(path: Path):
    hits = []
    src = path.read_text(encoding="utf-8", errors="replace")
    for lineno, line in enumerate(strip_comments(src).splitlines(), 1):
        for m in TOKEN_RE.finditer(line):
            hits.append((path, lineno, m.group(1)))
        m = DECL_RE.match(line)
        if m:
            hits.append((path, lineno, m.group(1) + " (declaration)"))
    return hits


def main(argv):
    if len(argv) < 2:
        print("usage: escape_scan.py <path> [<path> ...]", file=sys.stderr)
        return 2
    files = []
    for arg in argv[1:]:
        p = Path(arg)
        if p.is_dir():
            files.extend(sorted(p.rglob("*.lean")))
        elif p.exists():
            files.append(p)
    if not files:
        print("escape scan: no .lean files found", file=sys.stderr)
        return 2
    hits = [h for f in files for h in scan(f)]
    for path, lineno, tok in hits:
        print(f"{path}:{lineno}: {tok}")
    if hits:
        print(f"escape scan FAILED: {len(hits)} hit(s) in {len(files)} file(s)")
        return 1
    print(f"escape scan clean: {len(files)} file(s), no escape tokens outside comments")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
