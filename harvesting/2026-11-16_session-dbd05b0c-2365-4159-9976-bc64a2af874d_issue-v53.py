"""Build issue #180 body v5.3 from v5.2: the corrections approved by the commander (R874d-38).

Usage: issue-v53.py <issue json dump> <out body file>
Each replacement must match exactly once, or the script exits 1 and writes nothing.
"""
import json
import sys

src, out = sys.argv[1], sys.argv[2]
body = json.load(open(src, encoding="utf-8"))["body"]

EDITS = [
    (
        "**Body version.** v5.2 (2026-11-16, session dbd05b0c), from the commander's prompt of 00:01:19Z (L2442).",
        "**Body version.** v5.3 (2026-11-16, session dbd05b0c), from the commander's prompt of 01:10:39Z (L3394), "
        "answer \"38) yes\" to R874d-38: two corrections, each marked *Corrected in v5.3*. Section 3 adds `fact` to the "
        "item types (D874d-43), and section 4 corrects the observation on a delegate's `.meta.json`. Nothing else "
        "changed: the decisions of L3394 are not recorded in this version.\n\n"
        "v5.2 (2026-11-16, session dbd05b0c), from the commander's prompt of 00:01:19Z (L2442).",
    ),
    (
        "type           objective | deviation | observation | ambiguity | assumption | decision |\n"
        "               operational_learning | proposal | rfi\n",
        "type           objective | deviation | observation | ambiguity | assumption | fact |\n"
        "               decision | operational_learning | proposal | rfi\n"
        "               (fact: a session-DB type kept by D874d-43; no document node lists facts,\n"
        "               D874d-32. Corrected in v5.3: v5.2 left it out)\n",
    ),
    (
        "One observation: the `.meta.json` that links a mission name to its agentId was created when delegate "
        "874d-1-aar-doctrine finished (20:55:18Z), not at launch, so it is no help while a delegate runs.",
        "*Corrected in v5.3:* a third way is the delegate's `subagents/agent-<agentId>.meta.json`, whose "
        "`description` starts with its mission name: it exists while the delegate runs. Observed for the four "
        "background verifiers 874d-3 to 874d-6 (2026-11-16): their files were dated at launch, while they ran. "
        "v5.2 said the file was created only when a delegate finished; that was wrong, inferred from a file time "
        "that is rewritten at finish.",
    ),
]

for old, new in EDITS:
    n = body.count(old)
    if n != 1:
        print(f"FAIL: expected 1 match, found {n}: {old[:70]!r}", file=sys.stderr)
        sys.exit(1)
    body = body.replace(old, new)

with open(out, "w", encoding="utf-8") as f:
    f.write(body)
print("ok:", len(EDITS), "edits;", len(body), "chars")
