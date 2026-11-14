"""File incident #174 in registries/incidents.json (format kept: indent 2, UTF-8, ensure_ascii False, trailing newline).
Usage: python file-174.py <incidents.json>"""
import json
import sys

path = sys.argv[1]
raw = open(path, "rb").read()
d = json.loads(raw.decode("utf-8"))
if (json.dumps(d, indent=2, ensure_ascii=False) + "\n").encode("utf-8") != raw:
    sys.exit("round trip not byte-identical; refusing to write")
ids = [i["id"] for i in d["incidents"] + d["closed"]]
new_id = max(ids) + 1
if new_id != 174:
    sys.exit(f"next id is {new_id}, not 174; re-check")

entry = {
    "id": 174,
    "title": "Log writers outside aitools-lib (aitools-install.ps1/.sh log overrides, aitools-profile.sh/.ps1 log overrides, check-lib.sh/.ps1 checks.log and checks.jsonl writers) append to the log file unguarded, so a locked or unwritable log can abort the installer, the profile resolver or a check script instead of being swallowed",
    "status": "open",
    "severity": "high",
    "affected": [
        "scripts/aitools-install.ps1",
        "scripts/aitools-install.sh",
        "scripts/aitools-profile.ps1",
        "scripts/aitools-profile.sh",
        "scripts/check-lib.ps1",
        "scripts/check-lib.sh"
    ],
    "linked": "Branch fix/m5-lib commit 4cb0b46 (mission M5-L1, not merged on 2026-11-14) makes aitools-lib's own deploy.log writes fail-safe through Add-AitLibLogText / _aitlib_log_append; this incident is the rest",
    "referenceFile": None,
    "observation": "Read on branch docs/m5-docs (origin/main 592c5b3 plus docs commits; none of these files changed). (1) scripts/aitools-install.ps1, the install log override block, function Log: `Add-Content -Path $logFile -Value $line`, no try/catch; the relay sync step also pipes child output with `$out | Add-Content -Path $logFile`. (2) scripts/aitools-install.sh (set -euo pipefail), the install log override block, function log: `printf ... | tee -a \"$LOG_FILE\"`; the relay sync step redirects `>>\"$LOG_FILE\" 2>&1` inside an if. (3) scripts/aitools-profile.sh (set -euo pipefail), function log: `printf '%s\\n' \"$line\" >> \"$LOG_FILE\"`. (4) scripts/aitools-profile.ps1, function Log: `[IO.File]::AppendAllText($resolvedLog, ...)`, unguarded, and the script's `trap` turns any escaped exception into exit 2. (5) scripts/check-lib.sh, check_log_init, _check_log_step and print_summary: `>> \"$_CHECK_LOG\"` / `>> \"$_CHECK_JSONL\"`. (6) scripts/check-lib.ps1, CheckLogInit, CheckLogStep and PrintSummary: `Add-Content -Path $script:CheckLog` / `$script:CheckJsonl`; check-pre-commit.ps1 sets `$ErrorActionPreference = \"Stop\"`, so there a failed Add-Content is terminating. Every one of these files loads aitools-lib first (aitools-install.ps1 and check-lib.ps1 dot-source aitools-lib.ps1; aitools-install.sh, aitools-profile.sh and check-lib.sh source aitools-lib.sh; aitools-profile.ps1 dot-sources it before defining Log). Not reproduced: the effects below are read from the code, not observed.",
    "expected": "reference/logging.md section 5 'Format', Fail-safe bullet: \"A failed log write is swallowed (the only sanctioned silent-suppression in the harness), because a broken log must not break the operation it records.\" Also .claude/rules/script-standards.md 'Error and warning tracking' / 'Error handling requirements' (the suppression must be deliberate, not an accident of the writer).",
    "impact": "When deploy.log or checks.log/checks.jsonl cannot be written (locked by another process on Windows, a full disk, a read-only or missing log directory, a permission change), the operation that is being logged fails instead: aitools-install.sh and aitools-profile.sh exit through set -e at the first log line (the installer runs first on a new machine, before anything else can report); aitools-profile.ps1 exits 2 through its trap, which its callers (the lib's resolver wrappers, setup-user-claude/-settings/-cursor, user init) treat as a resolver error; check-pre-commit.ps1 stops at the first step line; aitools-install.ps1 prints a non-terminating error per log line and continues, so the console fills with errors while deploy.log loses the record. The lib itself is fail-safe once fix/m5-lib merges, so the same condition behaves differently depending on which writer logs the line.",
    "discoveryContext": "Reported by mission M5-L1 (fix/m5-lib, commit 4cb0b46) to M5-Fixes, filed by M5-D2 on 2026-11-14 (session 87795dc3, mission M5-Fixes item: file one incident). Audited on docs/m5-docs: reference/logging.md section 5; scripts/aitools-install.ps1 function Log and the relay sync step; scripts/aitools-install.sh function log; scripts/aitools-profile.sh function log; scripts/aitools-profile.ps1 function Log and its trap; scripts/check-lib.sh check_log_init, _check_log_step, print_summary; scripts/check-lib.ps1 CheckLogInit, CheckLogStep, PrintSummary; $ErrorActionPreference settings in check-pre-commit.ps1; origin/fix/m5-lib scripts/aitools-lib.ps1 Add-AitLibLogText and scripts/aitools-lib.sh _aitlib_log_append.",
    "discipline": None,
    "frameworks": None,
    "suggestedResolution": "After fix/m5-lib merges: route each writer through the lib's fail-safe append (Add-AitLibLogText / _aitlib_log_append), which every affected file can reach because each loads aitools-lib first. Options: (a) the installer and aitools-profile overrides keep their own console behaviour (Write-Host / stderr, JSONL record) but write the file line through the lib helper; (b) check-lib gets a small guarded twin for checks.log/checks.jsonl (same contract: try/catch or `2>/dev/null || :` with a comment, one warning per run at most), since the lib helper targets $logFile / $LOG_FILE; (c) the relay sync child-output appends in both installers go through the same helper. Add a test per writer: an unwritable log file (read-only file, or a directory in its place) must not change the exit code. Artifacts: the six scripts above, tests/logging (sh and ps1), reference/logging.md section 5 (name the helpers).",
    "rootCause": None,
    "correctiveAction": None,
    "preventionLayer": None,
    "created": "2026-11-14",
    "updated": "2026-11-14"
}
d["incidents"].append(entry)
d["meta"]["lastUpdated"] = "2026-11-14"
with open(path, "wb") as fh:
    fh.write((json.dumps(d, indent=2, ensure_ascii=False) + "\n").encode("utf-8"))
print("filed", new_id, "open", len(d["incidents"]), "closed", len(d["closed"]))
