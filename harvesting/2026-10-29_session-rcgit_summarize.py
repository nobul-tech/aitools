#!/usr/bin/env python3
"""Summarize dumped PR json+diff: state, checks, reviews, files, target-file hunks."""
import json, re, sys
from collections import Counter

D = "/Users/new-jose/repos/aitools/.scratch/session-rcgit/prs"
TARGETS = [
    r"^\.claude/rules/managed-file-deployment\.md$", r"^\.cursor/rules/managed-file-deployment\.mdc$",
    r"^reference/harness\.md$", r"^\.claude/rules/aitools-workspace\.md$",
    r"^reference/managed-file-deployment\.md$", r"^\.claude/rules/deploy-paths\.md$",
    r"^\.cursor/rules/deploy-paths\.mdc$", r"^shared/cursor-rules/user-rules\.md$",
    r"^reference/user-repo\.md$", r"^registries/glossary\.json$",
    r"^\.cursor/rules/cursor-rule-parity\.mdc$", r"^reference/cursor-practices\.md$",
    r"^\.claude/rules/interactive-menus\.md$", r"^\.cursor/rules/interactive-menus\.mdc$",
    r"^scripts/setup-user-claude\.", r"^scripts/setup-user-cursor\.", r"^scripts/deploy-harness\.",
    r"^scripts/build-deploy\.sh$", r"^scripts/check-pre-push\.", r"^scripts/aitools-lib\.",
    r"^scripts/aitools$", r"^scripts/aitools\.ps1$", r"^scripts/aitools-install\.",
    r"^scripts/setup-user-settings\.", r"^plans/tool-support-and-machine-profile\.md$",
    r"^registries/incidents\.json$", r"^RELEASE_NOTES\.md$", r"^reference/tool-support-decision-tree\.md$",
    r"^reference/smoke-test-pattern-detail\.md$", r"^reference/script-standards-detail\.md$",
]
def is_target(p):
    return any(re.search(t, p) for t in TARGETS)

def hunks(diff_text):
    res = {}
    cur = None
    for line in diff_text.splitlines():
        m = re.match(r"^diff --git a/(\S+) b/(\S+)", line)
        if m:
            cur = m.group(2); res.setdefault(cur, []); continue
        m = re.match(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@ ?(.*)", line)
        if m and cur:
            res[cur].append({"old": f"{m.group(1)},{m.group(2) or 1}", "new": f"{m.group(3)},{m.group(4) or 1}", "ctx": m.group(5)[:70], "add": 0, "del": 0, "sample": []})
            continue
        if cur and res.get(cur) and line[:1] in "+-" and not line.startswith(("+++", "---")):
            h = res[cur][-1]
            if line[0] == "+": h["add"] += 1
            else: h["del"] += 1
            if len(h["sample"]) < 2 and line[1:].strip():
                h["sample"].append(line[:110])
    return res

for n in range(int(sys.argv[1]), int(sys.argv[2]) + 1):
    j = json.load(open(f"{D}/pr-{n}.json"))
    diff = open(f"{D}/pr-{n}.diff").read()
    print("=" * 100)
    print(f"#{n} {j['title']}\n state={j['state']} base={j['baseRefName']} head={j['headRefName']} {j['headRefOid'][:7]} mergeable={j['mergeable']} mss={j['mergeStateStatus']}")
    c = Counter((x.get('conclusion') or x.get('state') or x.get('status')) for x in j['statusCheckRollup'])
    print(" checks:", dict(c))
    print(" commits:", [(x['oid'][:7], x['messageHeadline'][:60]) for x in j['commits']])
    for r in j['reviews']:
        body = r['body'] or ''
        v = [l for l in body.splitlines() if re.search(r"(?i)verdict|blocking|changes needed|approve|major|must", l)][:6]
        print(f" REVIEW {r['state']} {r.get('submittedAt')} len={len(body)} first={body.splitlines()[0][:100] if body else ''}")
        for l in v: print("    |", l[:200])
    for cm in j['comments']:
        body = cm['body'] or ''
        v = [l for l in body.splitlines() if re.search(r"(?i)verdict|blocking|changes needed|approve|major|must", l)][:6]
        print(f" COMMENT {cm.get('createdAt')} len={len(body)} first={body.splitlines()[0][:100] if body else ''}")
        for l in v: print("    |", l[:200])
    files = [f['path'] for f in j['files']]
    print(f" files ({len(files)}):", ", ".join(files))
    hs = hunks(diff)
    for p in files:
        if is_target(p):
            print(f"  TARGET {p}")
            for h in hs.get(p, []):
                print(f"     @@ -{h['old']} +{h['new']} +{h['add']}/-{h['del']} [{h['ctx']}]")
                for s in h['sample']: print("        ", s)
