#!/usr/bin/env python3
"""Summarise PR friction signals for PRs 50-116 from dumped gh JSON."""
import json, glob, os, re

d = "/Users/new-jose/repos/aitools/.scratch/session-fricprs/data"
prs = []
for f in sorted(glob.glob(os.path.join(d, "pr-*.json")), key=lambda p: int(re.findall(r"\d+", os.path.basename(p))[0])):
    with open(f) as fh:
        prs.append(json.load(fh))

VERDICT = re.compile(r"(changes needed|needs changes|request(ed)? changes|needs amendments|NEEDS|BLOCK|do not merge|not ready|FAIL)", re.I)
APPROVE = re.compile(r"(approve|LGTM|ready to merge|verdict: *pass|PASS)", re.I)
DRAFT = re.compile(r"\bdraft", re.I)

for p in prs:
    n = p["number"]
    merged = p.get("mergedAt")
    base = p["baseRefName"]
    comments = p.get("comments") or []
    reviews = p.get("reviews") or []
    commits = p.get("commits") or []
    body = p.get("body") or ""
    events = []
    for c in comments:
        events.append(("comment", c.get("createdAt"), (c.get("body") or "")))
    for r in reviews:
        events.append(("review:" + (r.get("state") or ""), r.get("submittedAt"), (r.get("body") or "")))
    events.sort(key=lambda e: e[1] or "")
    after_merge = [e for e in events if merged and e[1] and e[1] > merged]
    neg = [e for e in events if VERDICT.search(e[2][:600])]
    neg_before = [e for e in neg if merged and e[1] and e[1] <= merged]
    last_commit = max((c.get("committedDate") or "" for c in commits), default="")
    files = [x["path"] for x in (p.get("files") or [])]
    checks = p.get("statusCheckRollup") or []
    concl = {}
    for ch in checks:
        k = (ch.get("conclusion") or ch.get("state") or ch.get("status") or "?")
        concl[k] = concl.get(k, 0) + 1
    print("=" * 100)
    print(f"#{n} [{p['state']}] base={base} head={p['headRefName']} created={p['createdAt']} merged={merged}")
    print(f"  title: {p['title']}")
    print(f"  commits={len(commits)} last_commit={last_commit} files={len(files)} checks={concl}")
    print(f"  body draft mentions={len(DRAFT.findall(body))} comments={len(comments)} reviews={len(reviews)} after_merge={len(after_merge)}")
    if base != "main":
        print("  !! base is not main")
    for e in neg_before:
        print(f"  NEG-before-merge {e[0]} {e[1]}: {e[2][:300].replace(chr(10),' ')}")
    for e in after_merge:
        print(f"  AFTER-MERGE {e[0]} {e[1]}: {e[2][:300].replace(chr(10),' ')}")
    if not merged:
        for e in events[-3:]:
            print(f"  LAST {e[0]} {e[1]}: {e[2][:300].replace(chr(10),' ')}")
