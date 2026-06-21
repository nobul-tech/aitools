#!/usr/bin/env bash
set -euo pipefail
cd /Users/new-jose/repos/aitools

echo "=== syntax: bash ==="
bash -n scripts/aitools-lib.sh && echo "OK lib.sh"
bash -n scripts/setup-user-hooks.sh && echo "OK setup-user-hooks.sh"

echo ""
echo "=== syntax: pwsh ==="
pwsh -NoProfile -Command '$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile("scripts/aitools-lib.ps1",[ref]$null,[ref]$e);if($e){$e}else{"OK lib.ps1"}'
pwsh -NoProfile -Command '$e=$null;[void][System.Management.Automation.Language.Parser]::ParseFile("scripts/setup-user-hooks.ps1",[ref]$null,[ref]$e);if($e){$e}else{"OK setup-user-hooks.ps1"}'

echo ""
echo "=== functional: adopt_managed_file (dual target + backup rotation) ==="
T=.scratch/session-c46487f0-8/adopt-test
rm -rf "$T"; mkdir -p "$T/deployed" "$T/shared" "$T/dotprofile"

# Stub logging so we can source the lib standalone
SCRIPT_NAME=test; LOG_DIR="$T"; LOG_FILE="$T/x.log"
log()      { printf '%s\n' "$1"; }
log_ok()   { printf 'OK: %s\n' "$1"; }
log_error(){ printf 'ERR: %s\n' "$1"; }
log_warn() { printf 'WARN: %s\n' "$1"; }
display_path(){ printf '%s' "$1"; }

# Pull in just the two functions we need from the lib
source <(perl -0777 -ne 'print $1 if /(# -+\n# Backup a file.*?\nbackup_file\(\) \{.*?\n\})/s' scripts/aitools-lib.sh)
source <(perl -0777 -ne 'print $1 if /(ADOPT_TARGETS_WRITTEN=0\nadopt_managed_file\(\) \{.*?\n\})/s' scripts/aitools-lib.sh)

# Pre-seed existing targets so backups should be created
printf 'OLD shared\n'    > "$T/shared/hook.sh"
printf 'OLD dotprofile\n'> "$T/dotprofile/hook.sh"
# The adopted (deployed) file is the new content
printf 'NEW adopted content\n' > "$T/deployed/hook.sh"

adopt_managed_file "$T/deployed/hook.sh" "$T/shared/hook.sh" "$T/dotprofile/hook.sh"
echo "written count: $ADOPT_TARGETS_WRITTEN"

echo "--- shared now ---";    cat "$T/shared/hook.sh"
echo "--- dotprofile now ---";cat "$T/dotprofile/hook.sh"
echo "--- backups created ---"
ls -1 "$T/shared/" "$T/dotprofile/" | grep bak || echo "NONE (FAIL)"

echo ""
echo "=== assertions ==="
grep -q "NEW adopted" "$T/shared/hook.sh" && echo "OK shared overwritten" || echo "FAIL shared"
grep -q "NEW adopted" "$T/dotprofile/hook.sh" && echo "OK dotprofile overwritten" || echo "FAIL dotprofile"
ls "$T/shared/"hook.sh.bak.* >/dev/null 2>&1 && echo "OK shared backup" || echo "FAIL shared backup"
ls "$T/dotprofile/"hook.sh.bak.* >/dev/null 2>&1 && echo "OK dotprofile backup" || echo "FAIL dotprofile backup"

rm -rf "$T"
echo "cleaned"
