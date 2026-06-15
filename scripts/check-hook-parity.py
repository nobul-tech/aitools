#!/usr/bin/env python3
# check-hook-parity.py -- Hook-registration parity audit (check-post-push step 32).
# Every hook in shared/hooks/hooks-manifest.json must be registered in BOTH
# setup-user-hooks.sh (node block: mergeHookEntry) and setup-user-hooks.ps1
# (MergeHookEntry). Closes the bash<->PS1 drift that left scratch-init/harvest
# unregistered on Windows (RCA, plans/harvest-archive-resilience.md §5).
#
# Set comparison (order-independent) done entirely in Python so the audit does not
# depend on perl-in-shell quoting or platform sort ordering (the prior inline
# perl + Sort-Object/`sort` approach produced false mismatches).
#
# Usage:  check-hook-parity.py <manifest.json> <setup-user-hooks.sh> <setup-user-hooks.ps1>
# Exit 0 + a one-line OK summary on stdout if parity holds; exit 1 + the diff if not.
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
            sh = set(re.findall(r"mergeHookEntry\('[^']*',\s*'([\w.-]+)'", f.read()))
        with open(ps1_path, encoding="utf-8") as f:
            ps1 = set(re.findall(r'MergeHookEntry\s+"[^"]*"\s+"([\w.-]+)"', f.read()))
    except (OSError, ValueError, KeyError) as exc:
        print("parity audit error: %s" % exc)
        return 1

    issues = []
    if manifest ^ sh:
        issues.append("bash!=manifest [" + ",".join(sorted(manifest ^ sh)) + "]")
    if manifest ^ ps1:
        issues.append("ps1!=manifest [" + ",".join(sorted(manifest ^ ps1)) + "]")
    if issues:
        print("; ".join(issues))
        return 1
    print("bash + ps1 match manifest (%d hooks)" % len(manifest))
    return 0


if __name__ == "__main__":
    sys.exit(main())
