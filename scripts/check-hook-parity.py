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
# Optional 4th arg: build-deploy.sh. Its preflight + embed lists must also be
# manifest-driven, and NO manifest-listed hook filename may appear literally in
# the script (the hardcoded preflight list drifted -- issue #9). Full-line
# comments (^\s*#) are ignored, and names match as whole tokens only, so a
# comment that mentions a hook, or a longer name containing a hook name, does
# not trip the check.
#
# Usage:  check-hook-parity.py <manifest.json> <setup-user-hooks.sh> <setup-user-hooks.ps1> [<build-deploy.sh>]
# Exit 0 + a one-line OK summary on stdout if the invariant holds; exit 1 + the diff if not.
import json
import re
import sys
from typing import Any, List, Optional, Set


def strip_full_line_comments(text: str) -> str:
    """Drop lines whose first non-blank character is '#' (shell comments)."""
    kept: List[str] = [ln for ln in text.splitlines() if not re.match(r"^\s*#", ln)]
    return "\n".join(kept)


def literal_names(text: str, names: Set[str]) -> List[str]:
    """Return the names that occur in text as whole tokens (not inside a longer name)."""
    found: List[str] = []
    for name in sorted(names):
        pattern: str = r"(?<![\w.-])" + re.escape(name) + r"(?![\w.-])"
        if re.search(pattern, text):
            found.append(name)
    return found


def main() -> int:
    if len(sys.argv) not in (4, 5):
        print("usage: check-hook-parity.py <manifest> <sh_setup> <ps1_setup> [<build_deploy>]")
        return 2
    manifest_path, sh_path, ps1_path = sys.argv[1], sys.argv[2], sys.argv[3]
    bd_path: Optional[str] = sys.argv[4] if len(sys.argv) == 5 else None
    try:
        with open(manifest_path, encoding="utf-8") as f:
            mdata: Any = json.load(f)
        manifest: Set[str] = {h["file"] for h in mdata["hooks"]}
        deploy_files: Set[str] = set(mdata.get("deploy", []))
        with open(sh_path, encoding="utf-8") as f:
            sh = f.read()
        with open(ps1_path, encoding="utf-8") as f:
            ps1 = f.read()
        bd: Optional[str] = None
        if bd_path:
            with open(bd_path, encoding="utf-8") as f:
                bd = f.read()
    # TypeError/AttributeError: manifest has the wrong shape (e.g. top level or
    # hooks entries not objects, or a non-hashable 'file' value) -- report it
    # rather than crash with a traceback.
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
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

    # build-deploy.sh (optional): preflight + embed must be manifest-driven and
    # contain zero literal hook filenames (the drift vector of issue #9).
    if bd is not None:
        bd_code: str = strip_full_line_comments(bd)
        if "hooks-manifest.json" not in bd_code:
            issues.append("build-deploy: does not read hooks-manifest.json (outside comments)")
        bd_hard: List[str] = literal_names(bd_code, manifest | deploy_files)
        if bd_hard:
            issues.append("build-deploy: hardcoded hook filename(s) resurfaced [" + ",".join(bd_hard) + "]")

    if issues:
        print("; ".join(issues))
        return 1
    scope = "bash + ps1" if bd is None else "bash + ps1 + build-deploy"
    print("%s generate hook lists from manifest (%d hooks)" % (scope, len(manifest)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
