#!/usr/bin/env python3
"""Detail checks on glossary and framework registry (read-only audit helper)."""
import json
from pathlib import Path

R = Path("/Users/new-jose/repos/aitools/registries")
g = json.loads((R / "glossary.json").read_text(encoding="utf-8"))
print("glossary facets keys:", list(g["facets"].keys()))
print("terms type:", type(g["terms"]).__name__)
t = g["terms"]
keys = list(t.keys()) if isinstance(t, dict) else [x.get("term") for x in t]
print("term field sets:", sorted({k for v in (t.values() if isinstance(t, dict) else t) for k in v.keys()}))
rule = Path("/Users/new-jose/repos/aitools/.claude/rules/glossary.md").read_text(encoding="utf-8")
rule_terms = set()
sec = None
for ln in rule.splitlines():
    if ln.startswith("### "):
        sec = ln[4:].strip()
        continue
    if sec in ("Terms", "Scope modifiers", "Base artifacts") and ln.strip() and not ln.startswith("#"):
        rule_terms.add(ln.strip())
jterms = set(keys) | set(g["facets"].get("scopeModifiers", {}).keys()) | set(g["facets"].get("baseArtifacts", {}).keys())
print("in JSON not in rule:", sorted(jterms - rule_terms))
print("in rule not in JSON:", sorted(rule_terms - jterms))
f = json.loads((R / "framework-registry.json").read_text(encoding="utf-8"))
for fr in f["frameworks"]:
    print("fw:", fr.get("name"), "| lastUpdated:", fr.get("lastUpdated"), "| ref:", fr.get("referenceFile"))
for p in f["pending"]:
    print("pending:", p.get("name"), "| ref:", p.get("referenceFile"))
