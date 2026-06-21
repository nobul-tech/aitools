#!/usr/bin/env python3
# check-hook-parity.py -- Hook-registration parity audit (check-post-push step 32).
#
# Hook deployment + registration are now GENERATED from hooks-manifest.json in
# both setup-user-hooks.sh (node merge block loops over the manifest) and
# setup-user-hooks.ps1 (foreach over $regs). Parity holds BY CONSTRUCTION -- the
# single source is the manifest. This audit therefore verifies the invariant that
# both scripts stay manifest-driven and that NO hardcoded per-hook registration
# list has resurfaced (the recurring drift class: RCA .scratch investigation
# 2026-06-20; issue #7 / plan §5).
#
# Usage:  check-hook-parity.py <manifest.json> <setup-user-hooks.sh> <setup-user-hooks.ps1>
# Exit 0 + a one-line OK summary on stdout if the invariant holds; exit 1 + the diff if not.
import json
import re
import sys


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: check-hook-parity.py <manifest> <sh_setup> <ps1_setup>")
        return 2
    manifest_path, sh_path, ps1_path = sys.argv[1], sys.argv[2], sys.argv[3]
    try:
        with open(manifest_path, encoding="utf-8") as f:
            manifest = {h["file"] for h in json.load(f)["hooks"]}
        with open(sh_path, encoding="utf-8") as f:
            sh = f.read()
        with open(ps1_path, encoding="utf-8") as f:
            ps1 = f.read()
    except (OSError, ValueError, KeyError) as exc:
        print("parity audit error: %s" % exc)
        return 1

    issues = []
    if not manifest:
        issues.append("manifest has no hooks")

    # Both setup scripts must GENERATE registrations from the manifest (loop),
    # not maintain a hardcoded per-hook list.
    if "hooks-manifest.json" not in sh:
        issues.append("bash: does not read hooks-manifest.json")
    if "for (const r of regs)" not in sh:
        issues.append("bash: no manifest-driven registration loop")
    if "hooks-manifest.json" not in ps1:
        issues.append("ps1: does not read hooks-manifest.json")
    if "foreach ($r in $regs)" not in ps1:
        issues.append("ps1: no manifest-driven registration loop")

    # Guard: a hardcoded per-hook registration list must NOT resurface (that is
    # the drift vector this refactor removed).
    sh_hard = set(re.findall(r"mergeHookEntry\('[^']*',\s*'([\w.-]+)'", sh))
    ps1_hard = set(re.findall(r'MergeHookEntry\s+"[^"]*"\s+"([\w.-]+)"', ps1))
    if sh_hard:
        issues.append("bash: hardcoded mergeHookEntry calls resurfaced [" + ",".join(sorted(sh_hard)) + "]")
    if ps1_hard:
        issues.append("ps1: hardcoded MergeHookEntry calls resurfaced [" + ",".join(sorted(ps1_hard)) + "]")

    if issues:
        print("; ".join(issues))
        return 1
    print("bash + ps1 generate registrations from manifest (%d hooks)" % len(manifest))
    return 0


if __name__ == "__main__":
    sys.exit(main())
