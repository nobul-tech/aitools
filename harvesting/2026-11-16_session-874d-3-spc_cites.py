#!/usr/bin/env python3
"""For each decision D874d-1..53, list the lines of each target file that cite it.

Expands short forms: "D874d-22, -28", "D874d-19, -23, -34", "D874d-51, -52", "D874d-16 to -20".
Writes cites.txt (per-decision line numbers) and prints the uncited decisions per file.
"""
import re, pathlib

d = pathlib.Path(__file__).parent / "data"
FILES = {
    "rfc": "/Users/new-jose/repos/aitools/rfcs/RFC-0011-structured-reports.md",
    "plan": "/Users/new-jose/repos/aitools/plans/structured-reports/implementation-plan.md",
    "brief": "/Users/new-jose/repos/aitools/.scratch/session-dbd05b0c-2365-4159-9976-bc64a2af874d/874d-2-structured-reports-brief.json",
}
pat = re.compile(r"D874d-(\d+)((?:\s*(?:,|and|to)\s*-\d+)*)")
res = {k: {n: [] for n in range(1, 54)} for k in FILES}
for k, path in FILES.items():
    for ln, line in enumerate(pathlib.Path(path).read_text(encoding="utf-8").splitlines(), 1):
        for m in pat.finditer(line):
            nums = [int(m.group(1))]
            tail = m.group(2)
            prev = nums[0]
            for sep, n in re.findall(r"(,|and|to)\s*-(\d+)", tail):
                n = int(n)
                if sep == "to":
                    nums.extend(range(prev + 1, n + 1))
                else:
                    nums.append(n)
                prev = n
            for n in nums:
                if 1 <= n <= 53 and ln not in res[k][n]:
                    res[k][n].append(ln)
out = []
for n in range(1, 54):
    out.append(f"D874d-{n:<3} " + "  ".join(f"{k}:{res[k][n]}" for k in FILES))
(d / "cites.txt").write_text("\n".join(out) + "\n", encoding="utf-8")
for k in FILES:
    print(k, "uncited:", [n for n in range(1, 54) if not res[k][n]])
