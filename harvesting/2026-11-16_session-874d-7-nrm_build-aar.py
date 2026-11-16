#!/usr/bin/env python3
"""build-aar.py -- verify the defect table against RFC 0011 and write the AAR.

Usage: python3 build-aar.py <rfc path> <aar output path>
Fails (exit 1) when an old text is not found exactly once in its stated lines.
"""
import json
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from defects import D  # noqa: E402

RFC, OUT = sys.argv[1], sys.argv[2]
lines = Path(RFC).read_text(encoding="utf-8").split("\n")
errors = []
obs, pros = [], []
sev_rank = {"high": 0, "medium": 1, "low": 2}
D_sorted = sorted(D, key=lambda x: (x["lines"][0], sev_rank[x["sev"]]))

for i, x in enumerate(D_sorted, 1):
    a, b = x["lines"]
    span = "\n".join(lines[a - 1:b])
    old = span if x["old"] == "<LINE>" else x["old"]
    new = x["new"].replace("<LINE>", span)
    if span.count(old) != 1:
        errors.append(f"line {a}-{b}: old text found {span.count(old)} times: {old[:60]!r}")
    loc = f"{RFC}:{a}" if a == b else f"{RFC}:{a}-{b}"
    lineref = f"line {a}" if a == b else f"lines {a}-{b}"
    obs.append({
        "id": f"OBS-{i}",
        "type": "observation",
        "text": f"{lineref} [{x['char']}]: {x['text']}",
        "evidence": f"{lineref}, verbatim: " + (old if len(old) <= 160 else old[:160] + " [...] (full text in PRO-" + str(i) + ")"),
        "severity": x["sev"],
        "incident": False,
        "source": {"kind": "artifact", "location": loc},
    })
    pros.append({
        "id": f"PRO-{i}",
        "type": "proposal",
        "text": f"Fix the defect of OBS-{i}",
        "what": f"{lineref}: {old} -> {new}",
        "why": x["why"],
        "barrier_analysis": x["barrier"],
        "affected": [f"RFC 0011 {lineref}"],
        "observation_refs": [f"OBS-{i}"],
        "disposition": "proposed",
    })

n = len(obs)
others = [
    ("Other lens (874d-8-consistency): line 167 cites S-24 for the rule that quote is REQUIRED when source.kind is commander; S-24 (line 624) is about credentials in quotes, not about when a quote is required.",
     "line 167: quote          the source text verbatim; REQUIRED when source.kind is commander (S-24)", 167),
    ("Other lens (874d-8-consistency): line 112 defines the session scratch directory as <repo>/.scratch/session-<session id>/ (the full id), while the /scratch skill says the directory name uses the first 10 characters of the session id.",
     "line 112: - **Session scratch directory:** `<repo>/.scratch/session-<session id>/` of the top-level session.; /Users/new-jose/repos/aitools/shared/skills/scratch/SKILL.md lines 30-33", 112),
    ("Other lens (874d-8-consistency): the running-estimate column of the 3.1.2 table gives objectives 'the session's, + status' (line 130) while 3.5.2 gives '+ status, how, refs, deliverables' (line 432).",
     "line 130 and line 432", 130),
    ("Other lens (874d-9-implementer-read): 'report a blocker at once' (3.2.3, 3.4.6, D-DEL9) names no channel; a background delegate's only sanctioned report is its hand-back, which ends its run. The RFC does not say whether SendMessage to the delegating agent is the channel.",
     "lines 276, 390, 403, 581", 276),
    ("Other lens (874d-9-implementer-read): a delegate confined by worktree isolation (3.3.8, 3.4.8) cannot write <session scratch dir>/<mission name>-aar.json, which 3.4.7 requires when a file is requested.",
     "lines 373, 405, 410", 405),
    ("The v1.3 history entry (line 42) states 'The normative language was reviewed line by line.'; this review found the defects listed in OBS-1 to OBS-%d, so the next version entry should record the revision rather than the review." % n,
     "line 42: 3.3.1a). The normative language was reviewed line by line.", 42),
    ("ISO/IEC/IEEE 29148 was not read: it is a paid standard, and its ISO Online Browsing Platform preview (https://www.iso.org/obp/ui/en/#iso:std:iso-iec-ieee:29148:ed-2:v1:en, opened 2026-11-16) requires agreeing to ISO's Terms of Use first, which this delegate did not do on the commander's behalf. The 29148 characteristics were applied as named in OBJ-2; no 29148 wording is quoted in this AAR.",
     "chrome-devtools page text: 'Before you continue I have read and agree to the Terms of Use governing access to content on this platform'", 0),
]
for j, (t, ev, ln) in enumerate(others, n + 1):
    obs.append({
        "id": f"OBS-{j}", "type": "observation", "text": t, "evidence": ev,
        "severity": "low", "incident": False,
        "source": {"kind": "artifact" if ln else "web",
                   "location": f"{RFC}:{ln}" if ln else "https://www.iso.org/obp/ui/en/#iso:std:iso-iec-ieee:29148:ed-2:v1:en"},
    })

aar = json.loads(Path(Path(__file__).parent / "aar-head.json").read_text(encoding="utf-8"))
iso_id = obs[-1]["id"]
for o in aar["objectives"]:
    o["observation_refs"] = [iso_id if r == "OBS-ISO" else r for r in o["observation_refs"]]
aar["observations"] = obs
aar["proposals"] = pros
# keep key order of the RFC (3.4.2)
order = ["provenance", "objectives", "ambiguities", "assumptions", "deviations",
         "observations", "operational_learning", "proposals", "rfis"]
aar = {k: aar[k] for k in order}

if errors:
    print("ERRORS:")
    for e in errors:
        print("  " + e)
    sys.exit(1)

body = json.dumps(aar, ensure_ascii=False, separators=(",", ":"))
# one item per line keeps the file readable without indentation cost
body = body.replace('},{"id"', '},\n{"id"').replace('":[{"id"', '":[\n{"id"')
Path(OUT).write_text(body + "\n", encoding="utf-8")
json.loads(Path(OUT).read_text(encoding="utf-8"))
c = Counter(x["sev"] for x in D)
print(f"defects: {len(D)}  high={c['high']} medium={c['medium']} low={c['low']}  other-notes={len(others)}")
print(f"written: {OUT}")
