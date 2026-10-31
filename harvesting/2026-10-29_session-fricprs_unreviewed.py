#!/usr/bin/env python3
"""For PRs with any review/verdict comment: commits after the last verdict (head not re-reviewed), and merges before any verdict."""
import json, glob, os, re
d = "/Users/new-jose/repos/aitools/.scratch/session-fricprs/data"
V = re.compile(r"verdict|review", re.I)
for f in sorted(glob.glob(os.path.join(d, "pr-*.json")), key=lambda p: int(re.findall(r"\d+", os.path.basename(p))[0])):
    p = json.load(open(f))
    verdicts = [(r.get("submittedAt"), "review") for r in (p.get("reviews") or [])]
    verdicts += [(c.get("createdAt"), "comment") for c in (p.get("comments") or []) if re.search(r"(?i)verdict", (c.get("body") or "")[:400])]
    verdicts = sorted(v for v in verdicts if v[0])
    merged = p.get("mergedAt")
    if merged:
        verdicts_pre = [v for v in verdicts if v[0] <= merged]
    else:
        verdicts_pre = verdicts
    commits = sorted((c.get("committedDate"), c["oid"][:7], c.get("messageHeadline", "")) for c in (p.get("commits") or []))
    if not verdicts_pre:
        if merged and verdicts:
            print(f"#{p['number']} MERGED BEFORE ANY VERDICT (merged {merged}, first verdict {verdicts[0][0]})")
        continue
    last_v = verdicts_pre[-1][0]
    later = [c for c in commits if c[0] and c[0] > last_v and not c[2].lower().startswith("merge")]
    if later:
        state = "merged" if merged else p["state"].lower()
        print(f"#{p['number']} ({state}) commits after last verdict {last_v}: " + "; ".join(f"{c[1]} {c[2][:60]}" for c in later))
