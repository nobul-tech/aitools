#!/usr/bin/env python3
"""Check the #111 MDM deploy-paths draft OLD blocks against origin/main .md and .mdc."""
import re
import subprocess

R = "/Users/new-jose/repos/aitools"
draft = subprocess.run(["git", "-C", R, "show", "origin/feature/harness-mdm-followups:.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-H2-MDM/S3-H2-MDM-drafts/dot-claude/rules/deploy-paths.md.edit.txt"], capture_output=True, text=True, check=True).stdout
olds = re.findall(r"OLD:\n(.*?)\n\nNEW:", draft, re.S)


def norm(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip()


for path in [".claude/rules/deploy-paths.md", ".cursor/rules/deploy-paths.mdc"]:
    for ref in ["origin/main", "origin/feature/harness-mdm-followups"]:
        t = subprocess.run(["git", "-C", R, "show", f"{ref}:{path}"], capture_output=True, text=True, check=True).stdout.replace("\r\n", "\n")
        res = [f"Edit{i+1}: exact={t.count(o)} norm={norm(t).count(norm(o))}" for i, o in enumerate(olds)]
        print(path, ref, "; ".join(res))
