"""Renumber decision and RFI ids in an issue body: D-<sid4>-<n> -> D<sid4>-<n>, RFI <sid4>-<n> -> R<sid4>-<n>.

Usage: renumber-ids.py <in.md> <out.md>
Leaves quoted commander text untouched (none of it contains these ids) and prints counts.
"""
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
counts = {}


def sub(pattern: str, repl: str, label: str) -> None:
    global text
    text, n = re.subn(pattern, repl, text)
    counts[label] = n


sub(r"\bD-874d-", "D874d-", "D-874d- -> D874d-")
sub(r"\bRFI 874d-", "R874d-", "RFI 874d- -> R874d-")
sub(r"\bRFI fa81-", "Rfa81-", "RFI fa81- -> Rfa81-")
sub(r"`D-<sid4>-<n>`", "`D<sid4>-<n>`", "`D-<sid4>-<n>`")
sub(r"`RFI <sid4>-<n>`", "`R<sid4>-<n>`", "`RFI <sid4>-<n>`")
sub(r"D-<sid4>-<n>", "D<sid4>-<n>", "D-<sid4>-<n> (plain)")
open(dst, "w", encoding="utf-8").write(text)
for k, v in counts.items():
    print(f"{v:4d}  {k}")
