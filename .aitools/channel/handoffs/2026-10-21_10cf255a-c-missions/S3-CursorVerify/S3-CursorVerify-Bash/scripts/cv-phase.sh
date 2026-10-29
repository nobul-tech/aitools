#!/usr/bin/env bash
# cv-phase.sh -- S3-CursorVerify-Bash runner: one contract phase on one fixture ROOT.
#   cv-phase.sh ROOT OUTDIR PHASE [BASH_BIN]
# PHASE: P1 P2 P3 P3b P4 (P5 is driven by cv-pty.py). BASH_BIN defaults to `bash`.
# Never runs anything unless HOME for the scripts is ROOT/home under this scratch dir.
set -uo pipefail

SCRATCH="/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cv-sh"
REAL_HOME="/Users/new-jose"
ROOT="${1:?ROOT}"; OUTDIR="${2:?OUTDIR}"; PHASE="${3:?PHASE}"; BASH_BIN="${4:-bash}"
A="$ROOT/aitools"; H="$ROOT/home"; O="$OUTDIR/$PHASE"
FIX="/Users/new-jose/repos/aitools/.claude/worktrees/cverify/.scratch/session-cverify/build-fixture.sh"
GEN="$SCRATCH/cvgen.pl"

die() { printf '[%s] [cv-phase] [error] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; exit 3; }
info() { printf '[%s] [cv-phase] [info] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

# --- isolation guard ---
case "$ROOT" in "$SCRATCH"/*) ;; *) die "ROOT not under scratch: $ROOT" ;; esac
case "$H" in "$REAL_HOME"|"$REAL_HOME/") die "HOME would be the real HOME" ;; esac
[ "$H" != "$REAL_HOME" ] || die "HOME is real HOME"
[ -d "$H/.aitools" ] || die "no isolated HOME at $H"
[ -d "$A/.git" ] || die "no fixture clone at $A"

mkdir -p "$O/bin"
printf '#!/usr/bin/env bash\necho "ripgrep 14.1.0"\n' > "$O/bin/rg"
printf '#!/usr/bin/env bash\necho "2026.05.21-stub"\n' > "$O/bin/agent"
chmod +x "$O/bin/rg" "$O/bin/agent"
: > "$O/exit.txt"
LOG_START=0
if [ -f "$H/.aitools/logs/deploy.log" ]; then
    LOG_START=$(perl -ne 'END { print $. + 0 }' "$H/.aitools/logs/deploy.log")
fi

run() { # run NAME SCRIPT ARGS...
    local n="$1"; shift
    [ "$H" != "$REAL_HOME" ] || die "guard: real HOME"
    : > "$O/$n.summary"
    env -u AITOOLS_FORCE -u AITOOLS_DRY_RUN -u AITOOLS_LOG_DIR -u AITOOLS_USER_REPO_PATH \
        HOME="$H" USERPROFILE="$H" AITOOLS_SUMMARY_FILE="$O/$n.summary" PATH="$O/bin:$PATH" NO_COLOR=1 \
        "$BASH_BIN" "$@" < /dev/null > "$O/$n.out" 2>&1
    local rc=$?
    printf '%s\t%s\n' "$n" "$rc" >> "$O/exit.txt"
    info "$n exit $rc"
}

snap() { perl "$GEN" snap "$H" "$O/$1"; }

finish() {
    perl "$GEN" tree "$H" "$O/tree.txt"
    perl "$GEN" bakdirs "$H" "$O/bakdirs.txt"
    local s=""
    [ -f "$O/harness.summary" ] && s="$O/harness.summary"
    if [ -f "$O/cursor.summary" ]; then s="$s $O/cursor.summary"; fi
    # shellcheck disable=SC2086
    perl "$GEN" rows "$O/rows.txt" $s
    # only this phase's lines (the log is cumulative across phases)
    perl -ne "print if \$. > $LOG_START" "$H/.aitools/logs/deploy.log" > "$O/deploy.log.copy"
    cat "$O/exit.txt"
}

gitc() { git -C "$A" -c user.name="S3-CursorVerify-Bash" -c user.email="noreply@anthropic.com" "$@"; }

case "$PHASE" in
    P1|P2)
        snap snap-before.txt
        run harness "$A/scripts/deploy-harness.sh" --skip-config
        snap snap-mid.txt
        run cursor "$A/scripts/setup-user-cursor.sh"
        snap snap-after.txt
        finish ;;
    P3)
        perl -0777 -i -pe 's/\z/P3 edit: shared rule changed.\n/' "$A/shared/rules/fx-shared.md"
        perl -0777 -i -pe 's/\z/P3 edit: skill a changed.\n/' "$A/shared/skills/fx-skill-a/SKILL.md"
        gitc add shared/rules/fx-shared.md shared/skills/fx-skill-a/SKILL.md
        gitc commit --quiet -m "P3: edit fx-shared and fx-skill-a"
        gitc log --oneline -1 > "$O/commit.txt"
        snap snap-before.txt
        run harness "$A/scripts/deploy-harness.sh" --skip-config --dry-run
        snap snap-mid.txt
        run cursor "$A/scripts/setup-user-cursor.sh" --dry-run
        snap snap-after.txt
        finish ;;
    P3b)
        snap snap-before.txt
        run harness "$A/scripts/deploy-harness.sh" --skip-config
        snap snap-mid.txt
        run cursor "$A/scripts/setup-user-cursor.sh"
        snap snap-after.txt
        finish ;;
    P4)
        printf 'User line appended in P4.\n' >> "$H/.cursor/rules/fx-retire2.mdc"
        bash "$FIX" retire "$ROOT" > "$O/retire.out" 2>&1
        printf 'retire\t%s\n' "$?" >> "$O/exit.txt"
        snap snap-before.txt
        run harness "$A/scripts/deploy-harness.sh" --skip-config
        snap snap-mid.txt
        run cursor "$A/scripts/setup-user-cursor.sh"
        snap snap-after.txt
        finish ;;
    *) die "unknown phase $PHASE" ;;
esac
