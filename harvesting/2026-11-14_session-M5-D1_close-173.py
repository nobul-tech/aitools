"""Close incident #173 and amend closed #172 with the PR #144 follow-up (/incident skill, "Closing an incident").

Usage: python close-173.py <worktree root>
Prints the before/after entries. Fails (exit 1) if #173 is not open or #172 is not closed.
"""
import json
import sys
from pathlib import Path

TODAY = "2026-11-14"  # UTC date of the change
p = Path(sys.argv[1]) / "registries" / "incidents.json"
d = json.loads(p.read_text(encoding="utf-8"))

open173 = [i for i in d["incidents"] if i["id"] == 173]
closed172 = [i for i in d["closed"] if i["id"] == 172]
if len(open173) != 1 or len(closed172) != 1:
    print(f"unexpected state: open173={len(open173)} closed172={len(closed172)}")
    sys.exit(1)
old = open173[0]

new173 = {
    "id": 173,
    "title": old["title"],
    "closedIn": "PR #144 (fix/console-and-profile, merge c66d4b1); release version unknown, pending a RELEASE_NOTES entry for #144",
    "closedDate": TODAY,
    "correctiveAction": (
        "PR #144 (merge c66d4b12c97daa0b8ca5241a9a7c72c301579a44, merged 2026-11-14): aitools-install.ps1 and "
        "aitools-install.sh Step 7 only run setup-user-shell; the inline profile code is gone. setup-user-shell.ps1 "
        "owns a second marked block (`# >>> aitools shell integration >>>` ... `# <<< aitools shell integration <<<`), "
        "replaced in place by Update-MarkedBlock (line-based, no regex replacement string). A profile whose blocks "
        "are current is not written and not backed up; every write calls Backup-File first and is parse-checked. "
        "Remove-LegacyIntegration migrates the legacy `# aitools shell integration` / `# ai-tooling shell integration` "
        "lines by known line shapes only (dot-source of aliases.ps1, `function aitools {...}`, `function hh {...}`) and "
        "removes at most one blank line above each, so a user line after `function hh {...}` is kept. Verified: "
        "tests/setup-user-shell/test-setup-user-shell.ps1 cases `legacy: user line right after function hh kept (#173)`, "
        "`re-run: profile byte-identical after the 2nd and 3rd run`, `re-run: no write, so no backup taken`, in the "
        "Windows CI job (step `setup-user-shell PowerShell profile block tests (PowerShell, native)`), green on main "
        "592c5b3 (https://github.com/nobul-tech/aitools/actions/runs/43557171983); 37/0/0 on Windows 11 on 2026-11-14 "
        "(mission M5-D1)."
    ),
    "rootCause": (
        "Two scripts wrote $PROFILE: setup-user-shell.ps1 (PATH block) and aitools-install.ps1 Step 7, which wrote the "
        "integration lines inline with a start marker and no end marker. With no end marker, Step 7 found the old block "
        "as 'the marker and every following non-blank line', and it took that upgrade path whenever the marker was "
        "present, with no Backup-File. It wrote $PROFILE directly, so no test could target it (PR #144 body), and the "
        "bash Step 7, which leaves an existing block alone, diverged unnoticed."
    ),
    "preventionLayer": (
        "Prevention: one owner of $PROFILE (aitools-install Step 7 only runs setup-user-shell). Detection: "
        "tests/setup-user-shell .ps1 suite in the Windows CI job, .sh suite in the macOS (bash 5 and /bin/bash 3.2) "
        "and Linux CI jobs."
    ),
    "updated": TODAY,
}

c172 = closed172[0]
before172 = json.dumps(c172, indent=2, ensure_ascii=False)
c172["correctiveAction"] = c172["correctiveAction"].replace(
    "v0.76.1 (branch fix/setup-user-shell-replace):",
    "v0.76.1 (PR #143, branch fix/setup-user-shell-replace, merge 941e64a):", 1,
) + (
    " Follow-up PR #144 (fix/console-and-profile, merge c66d4b12c97daa0b8ca5241a9a7c72c301579a44, 2026-11-14): "
    "after #143 a profile already multiplied (64 blocks) still reported OK; setup-user-shell.ps1 now collapses "
    "duplicate blocks to one at the first block's position, removes stray marker lines, and reports damage it does "
    "not repair (parse errors, stray `_aitoolsLocalBin` lines) as WARN `profile damage left in place` plus an ACTION "
    "naming the newest clean `<profile>.bak.<UTC>`; tests/setup-user-shell 8 -> 37 checks (.ps1) and a new .sh suite."
)
c172["preventionLayer"] = (
    "Detection (pre-write parse check and damage report in setup-user-shell.ps1; tests/setup-user-shell .ps1 suite "
    "in the Windows CI job, .sh suite in the macOS and Linux CI jobs)"
)
c172["updated"] = TODAY

d["incidents"] = [i for i in d["incidents"] if i["id"] != 173]
d["closed"].append(new173)
d["meta"]["lastUpdated"] = TODAY

p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
check = json.loads(p.read_text(encoding="utf-8"))
assert not [i for i in check["incidents"] if i["id"] == 173]
assert [i for i in check["closed"] if i["id"] == 173]
print("#172 before:\n" + before172)
print("#172 after:\n" + json.dumps(c172, indent=2, ensure_ascii=False))
print("#173 closed entry:\n" + json.dumps(new173, indent=2, ensure_ascii=False))
print("open:", len(check["incidents"]), "closed:", len(check["closed"]))
