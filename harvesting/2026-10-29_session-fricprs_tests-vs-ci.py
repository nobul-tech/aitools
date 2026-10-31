#!/usr/bin/env python3
"""For each PR 50-116: tests/ files added, whether check.yml touched, and test paths referenced in check.yml."""
import json, glob, os, re
d = "/Users/new-jose/repos/aitools/.scratch/session-fricprs/data"
ci = open("/Users/new-jose/repos/aitools/.github/workflows/check.yml").read()
for f in sorted(glob.glob(os.path.join(d, "pr-*.json")), key=lambda p: int(re.findall(r"\d+", os.path.basename(p))[0])):
    p = json.load(open(f))
    files = [x["path"] for x in (p.get("files") or [])]
    tests = sorted({os.path.dirname(x) for x in files if x.startswith("tests/")})
    touches_ci = any(x.startswith(".github/") for x in files)
    prot = [x for x in files if x.startswith(".claude/rules/") or x == "CLAUDE.md" or x.startswith("reference/") or x.startswith("registries/") or x.startswith(".cursor/rules/") or x == "shared/claude-shared.md"]
    missing = [t for t in tests if t not in ci]
    if tests or touches_ci or prot:
        print(f"#{p['number']} {p['state']} tests={tests} ci_touched={touches_ci} tests_not_in_main_ci={missing} protected={len(prot)}")
