#!/usr/bin/env python3
"""Collect INCIDENT marker lines from the missions folder on origin/main, the main
checkout working tree (untracked included), and PR branches. Dedupe by (path, text).
Output: TSV  source-ref  path:line  text"""
import subprocess, os, re, sys

REPO = "/Users/new-jose/repos/aitools"
MD = ".aitools/channel/handoffs/2026-10-21_10cf255a-c-missions"
BRANCHES = ["feature/mf-config-no-machine", "docs/harness-approved-drafts", "feature/harness-rules-manifest",
            "docs/m3-approved-drafts", "docs/mf-incidents", "fix/mf-dotprofile-adopt-push", "docs/mf-audit",
            "docs/m3-approved-intents", "feature/harness-hookin", "fix/mf-audit-profile-json",
            "fix/mf-audit-consumers", "feature/harness-cursor-user-rules", "feature/harness-mdm-followups",
            "fix/mf-audit-claude-build", "fix/mf-lib-runner-result", "fix/mf-audit-config", "fix/mf-lib-relay",
            "fix/mf-installer-relay", "docs/m3-lead-plan"]
RX = re.compile(r"INCIDENT")

seen = {}
def add(ref, path, ln, text):
    key = (path, text.strip())
    if key in seen:
        return
    seen[key] = (ref, f"{path}:{ln}", text.strip())

def git_grep(ref):
    r = subprocess.run(["git", "-C", REPO, "grep", "-n", "INCIDENT", f"origin/{ref}" if ref != "main" else "origin/main", "--", MD],
                       capture_output=True, text=True)
    if r.returncode not in (0, 1):
        print(f"ERR {ref}: {r.stderr}", file=sys.stderr)
    for line in r.stdout.splitlines():
        _, path, ln, text = line.split(":", 3)
        yield path, ln, text

for path, ln, text in git_grep("main"):
    add("main", path, ln, text)
# working tree (untracked mission folders)
for root, _, files in os.walk(os.path.join(REPO, MD)):
    for f in files:
        if not f.endswith(".md"):
            continue
        p = os.path.join(root, f)
        rel = os.path.relpath(p, REPO)
        with open(p, encoding="utf-8", errors="replace") as fh:
            for i, t in enumerate(fh, 1):
                if RX.search(t):
                    add("worktree", rel, i, t)
for b in BRANCHES:
    for path, ln, text in git_grep(b):
        add(b, path, ln, text)

out = open("/Users/new-jose/repos/aitools/.scratch/session-rcledg/markers.tsv", "w")
for ref, loc, text in sorted(seen.values(), key=lambda x: x[1]):
    out.write(f"{ref}\t{loc}\t{text[:600]}\n")
out.close()
from collections import Counter
c = Counter(v[1].split(":")[0].split("/")[4] if len(v[1].split("/")) > 4 else v[1] for v in seen.values())
for k, n in sorted(c.items()):
    print(n, k)
print("total", len(seen))
