"""Structural self-check of RFC 0011 and its plan: S-n refs, clause refs, cited repo paths.

Usage: check-rfc-plan.py <repo root> <rfc.md> <plan.md>
"""
import os
import re
import sys

root, rfc_path, plan_path = sys.argv[1:4]
rfc = open(rfc_path, encoding="utf-8").read()
plan = open(plan_path, encoding="utf-8").read()

defined_s = set(re.findall(r"^\| (S-\d+) \|", rfc, re.M))
used_s = set(re.findall(r"\b(S-\d+)\b", rfc + plan))
print("S-n used but not defined:", sorted(used_s - defined_s, key=lambda s: int(s[2:])))
print("S-n defined but never cited outside the table:",
      sorted(s for s in defined_s if len(re.findall(rf"\b{s}\b", rfc + plan)) < 2))

clauses = set(re.findall(r"^(\d+\.\d+\.\d+)\. ", rfc, re.M)) | set(re.findall(r"^### (\d+\.\d+) ", rfc, re.M))
used_clauses = set(re.findall(r"(?<![\w.])(3\.\d+(?:\.\d+)?)(?![\w.]*\d)", rfc + plan))
print("clause refs not found:", sorted(c for c in used_clauses if c not in clauses))

paths = set(re.findall(r"`((?:scripts|shared|reference|rfcs|plans|tests|registries|\.claude|\.github|\.aitools)/[^`\s<>*|]+)`", rfc + plan))
missing = sorted(p for p in paths if not os.path.exists(os.path.join(root, p.rstrip("/"))))
print("cited paths that do not exist (should all be new files the plan creates):")
for p in missing:
    print("  ", p)
