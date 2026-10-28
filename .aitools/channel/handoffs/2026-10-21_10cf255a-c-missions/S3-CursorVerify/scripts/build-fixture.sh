#!/usr/bin/env bash
# build-fixture.sh -- S3-CursorVerify fixture: an aitools clone at a ref plus
# fixture rules/skills, a fixture dotprofile, and an isolated HOME.
# Never touches the real HOME. Bash 3.2 compatible.
#
# Usage:
#   build-fixture.sh build  <ROOT> <AITOOLS_REF>   # phase 1 (fresh; ROOT must not exist)
#   build-fixture.sh retire <ROOT>                 # phase 2: remove the fx-retire* sources, commit
#
# Layout under ROOT (absolute):
#   ROOT/aitools     git clone of /Users/new-jose/repos/aitools at AITOOLS_REF + fixture commit
#   ROOT/dotprofile  git repo: claude/rules, claude/skills, profile.json
#   ROOT/home        isolated HOME: .aitools/config.json (repoPath, reposPath, userRepoPath),
#                    .cursor/rules/user-own.mdc, .cursor/skills/user-skill/SKILL.md
set -euo pipefail

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '[%s] [build-fixture] [info] %s\n' "$(ts)" "$*"; }
die() { printf '[%s] [build-fixture] [error] %s\n' "$(ts)" "$*" >&2; exit 1; }

SRC_REPO="/Users/new-jose/repos/aitools"
mode="${1:-}"; ROOT="${2:-}"
[ -n "$mode" ] && [ -n "$ROOT" ] || die "usage: build-fixture.sh build|retire <ROOT> [REF]"
case "$ROOT" in /*) ;; *) die "ROOT must be absolute: $ROOT" ;; esac
case "$ROOT" in "$HOME"|"$HOME/") die "ROOT must not be the real HOME" ;; esac

gitc() { git -C "$1" -c user.name="S3-CursorVerify" -c user.email="noreply@anthropic.com" "${@:2}"; }

put() { # put FILE CONTENT...
    mkdir -p "$(dirname "$1")"
    printf '%s\n' "${@:2}" > "$1"
}

skill() { # skill DIR NAME DESC
    put "$1/SKILL.md" "---" "name: $2" "description: $3" "---" "" "# $2" "" "Fixture skill from $3."
}

if [ "$mode" = "build" ]; then
    REF="${3:-}"; [ -n "$REF" ] || die "build needs AITOOLS_REF"
    [ ! -e "$ROOT" ] || die "ROOT exists: $ROOT"
    mkdir -p "$ROOT"
    A="$ROOT/aitools"; D="$ROOT/dotprofile"; H="$ROOT/home"

    SHA=$(git -C "$SRC_REPO" rev-parse --verify "$REF^{commit}") || die "cannot resolve $REF in $SRC_REPO"
    log "cloning $SRC_REPO at $REF ($SHA)"
    git clone --quiet --no-hardlinks "$SRC_REPO" "$A"
    # the clone's origin/* are the source's LOCAL branches; fetch its remote-tracking refs too
    gitc "$A" fetch --quiet "$SRC_REPO" "+refs/remotes/origin/*:refs/remotes/src-origin/*"
    gitc "$A" checkout --quiet --detach "$SHA"

    # --- aitools fixture rules (shared + project) ---
    put "$A/shared/rules/fx-shared.md"   "## fx-shared" "" "Fixture shared rule."
    put "$A/.claude/rules/fx-project.md" "## fx-project (this repo)" "" "Fixture project rule."
    put "$A/shared/rules/fx-dup.md"      "## fx-dup" "" "Fixture dup rule: SHARED copy (must win)."
    put "$A/.claude/rules/fx-dup2.md"    "## fx-dup2" "" "Fixture dup2 rule: AITOOLS copy (must win over dotprofile)."
    put "$A/shared/rules/fx-[br].md"     "## fx-[br]" "" "Fixture bracket-name rule."
    put "$A/shared/rules/fx-retire.md"   "## fx-retire" "" "Fixture rule retired in phase 2."
    put "$A/shared/rules/fx-retire2.md"  "## fx-retire2" "" "Fixture rule retired in phase 2 (user edits its .mdc first)."
    # --- aitools fixture skills ---
    skill "$A/shared/skills/fx-skill-a" fx-skill-a "aitools shared/skills"
    put   "$A/shared/skills/fx-skill-a/scripts/run.sh" "#!/usr/bin/env bash" "echo fx"
    chmod +x "$A/shared/skills/fx-skill-a/scripts/run.sh"
    skill "$A/.claude/skills/fx-skill-b" fx-skill-b "aitools .claude/skills"
    skill "$A/shared/skills/fx-dupskill" fx-dupskill "aitools shared/skills (must win)"
    skill "$A/.claude/skills/fx-dupskill" fx-dupskill "aitools .claude/skills (duplicate, skipped)"
    skill "$A/.claude/skills/fx-dupskill2" fx-dupskill2 "aitools .claude/skills (must win over dotprofile)"
    skill "$A/shared/skills/fx-[br]ack" "fx-[br]ack" "aitools shared/skills bracket name"
    skill "$A/shared/skills/fx-retire-skill" fx-retire-skill "aitools shared/skills (retired in phase 2)"
    gitc "$A" add -A shared/rules .claude/rules shared/skills .claude/skills
    gitc "$A" commit --quiet -m "fixture: rules and skills"

    # --- dotprofile ---
    mkdir -p "$D"
    git init --quiet "$D"
    put "$D/claude/rules/fx-dot.md"     "## fx-dot" "" "Fixture dotprofile rule."
    put "$D/claude/rules/fx-dup.md"     "## fx-dup" "" "Fixture dup rule: DOTPROFILE copy (must lose)."
    put "$D/claude/rules/fx-dup2.md"    "## fx-dup2" "" "Fixture dup2 rule: DOTPROFILE copy (must lose)."
    put "$D/claude/rules/FX-Upper.MD"   "## FX-Upper" "" "Fixture upper-case extension rule."
    skill "$D/claude/skills/fx-dot-skill" fx-dot-skill "dotprofile claude/skills"
    skill "$D/claude/skills/fx-dupskill"  fx-dupskill "dotprofile (duplicate, skipped)"
    skill "$D/claude/skills/fx-dupskill2" fx-dupskill2 "dotprofile (duplicate, skipped)"
    put "$D/profile.json" '{' '  "version": "2.1",' '  "identity": { "name": "Fixture", "email": "fixture@example.invalid" },' '  "cursor": { "cli": {} },' '  "profiles": {}' '}'
    gitc "$D" add -A
    gitc "$D" commit --quiet -m "fixture dotprofile"

    # --- isolated HOME ---
    mkdir -p "$H/.aitools" "$H/.cursor/rules" "$H/.cursor/skills/user-skill"
    put "$H/.aitools/config.json" '{' "  \"reposPath\": \"$ROOT\"," "  \"repoPath\": \"$A\"," "  \"userRepoPath\": \"$D\"" '}'
    put "$H/.cursor/rules/user-own.mdc" "---" "description: user's own rule" "alwaysApply: true" "---" "" "User-authored Cursor rule. Must never be touched."
    put "$H/.cursor/skills/user-skill/SKILL.md" "---" "name: user-skill" "description: user's own skill" "---" "" "User-authored skill. Must never be touched."
    log "built: $ROOT (aitools $(gitc "$A" rev-parse --short HEAD))"
    exit 0
fi

if [ "$mode" = "retire" ]; then
    A="$ROOT/aitools"
    [ -d "$A/.git" ] || die "no fixture at $ROOT"
    gitc "$A" rm --quiet -r shared/rules/fx-retire.md shared/rules/fx-retire2.md shared/skills/fx-retire-skill
    gitc "$A" commit --quiet -m "fixture: retire fx-retire, fx-retire2, fx-retire-skill"
    log "retired sources committed in $A"
    exit 0
fi

die "unknown mode: $mode"
