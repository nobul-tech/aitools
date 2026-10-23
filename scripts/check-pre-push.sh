#!/usr/bin/env bash
# check-pre-push.sh -- automated pre-push checklist for aitools
# Usage: bash scripts/check-pre-push.sh
# Read-only -- no --fix mode (all checks are verification or reminders)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/check-lib.sh
source "$SCRIPT_DIR/check-lib.sh"
# shellcheck source=scripts/init-logging.sh
source "$SCRIPT_DIR/init-logging.sh"

# OS guard: use .ps1 on Windows
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use check-pre-push.ps1."
        exit 1 ;;
esac

resolve_config
check_log_init "pre-push"

cd "$REPO_ROOT"

echo ""
echo "${BOLD}=== PRE-PUSH CHECKLIST ===${RESET}"
echo ""

# Commits in this push
COMMITS=$(git log --oneline origin/main..HEAD 2>/dev/null || true)
COMMIT_COUNT=0
if [ -n "$COMMITS" ]; then
    COMMIT_COUNT=$(echo "$COMMITS" | wc -l | tr -d ' ')
fi

if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo "No unpushed commits found."
    step_skip "1-10" "All steps" "nothing to push"
    print_summary
    exit 0
fi

# Files changed in this push
PUSH_FILES=$(git log --name-only --pretty=format: origin/main..HEAD 2>/dev/null | sort -u | grep -v '^$' || true)

# ---------------------------------------------------------------------------
# 1. Pre-commit passed
# ---------------------------------------------------------------------------
step_warn "1" "Pre-commit passed" "confirm pre-commit checklist was run for each commit"

# ---------------------------------------------------------------------------
# 2. No scratch/sensitive files
# ---------------------------------------------------------------------------
# scratch.<ext> is limited to throwaway extensions so the user rule
# shared/rules/scratch.md is not flagged (2026-10-21; keep in sync with .ps1).
blocklist_pattern='(chat\.txt|\.tmp$|\.env$|credentials|\.secret|scratch\.(txt|sh|ps1|py|js|log|out|json)$|temp\.|TODO\.txt)'
bad_files=$(echo "$PUSH_FILES" | grep -iE "$blocklist_pattern" || true)
if [ -z "$bad_files" ]; then
    step_pass "2" "No scratch/sensitive files"
else
    step_fail "2" "No scratch/sensitive files" "found: $(echo "$bad_files" | tr '\n' ' ')"
fi

# ---------------------------------------------------------------------------
# 3. Secret scan
# ---------------------------------------------------------------------------
push_diff=$(git diff origin/main..HEAD 2>/dev/null || true)
secret_pattern='(password|secret|api_key|api-key|apikey|token|bearer|private_key|AWS_ACCESS|ANTHROPIC_API)[\s]*[=:]'
secrets_found=$(echo "$push_diff" | grep -iE "^\+.*$secret_pattern" || true)
if [ -z "$secrets_found" ]; then
    step_pass "3" "Secret scan"
else
    match_count=$(echo "$secrets_found" | wc -l | tr -d ' ')
    step_fail "3" "Secret scan" "$match_count suspicious line(s) -- review git diff origin/main..HEAD"
fi

# ---------------------------------------------------------------------------
# 4. No WIP commits
# ---------------------------------------------------------------------------
wip_commits=$(echo "$COMMITS" | grep -iE '^[a-f0-9]+ (WIP|fixup!|squash!|TODO)' || true)
if [ -z "$wip_commits" ]; then
    step_pass "4" "No WIP commits"
else
    step_fail "4" "No WIP commits" "found: $(echo "$wip_commits" | head -3 | tr '\n' '; ')"
fi

# ---------------------------------------------------------------------------
# 5. Release notes current
# ---------------------------------------------------------------------------
non_docs_push=$(echo "$PUSH_FILES" | grep -vE '\.(md|mdc)$' || true)
rn_in_diff=$(echo "$PUSH_FILES" | grep -q 'RELEASE_NOTES.md' && echo "yes" || echo "no")
if [ -z "$non_docs_push" ]; then
    step_skip "5" "Release notes current" "docs-only push"
elif [ "$rn_in_diff" = "yes" ]; then
    step_pass "5" "Release notes current"
else
    step_warn "5" "Release notes current" "non-docs changes without RELEASE_NOTES.md"
fi

# ---------------------------------------------------------------------------
# 6. Roadmap reflects reality
# ---------------------------------------------------------------------------
step_warn "6" "Roadmap reflects reality" "check if push completes or starts a roadmap item"

# ---------------------------------------------------------------------------
# 7. deploy/ matches source
# ---------------------------------------------------------------------------
# Generated deploy scripts live in the dotprofile repo (deploy-paths.md; aitools/deploy/
# is frozen). When a deploy-relevant source changes (setup scripts, the build script,
# aitools-lib -- inlined into every deploy script --, the profile resolver and its JSON
# engine -- embedded in the resolver-consuming deploy scripts (M3 B5, review M7) -- or
# shared/), rebuild from this branch into a temporary copy of the dotprofile's committed
# tree and compare its deploy/. Then smoke-run the generated resolver consumers
# (--dry-run, isolated HOME): a deploy script that cannot find its resolver fails here,
# not on an endpoint (B8a INCIDENT). The smoke run lives here, not in build-deploy, so
# build-deploy stays a pure generator that never executes what it generates.
# The build gets the temp copy through AITOOLS_USER_REPO_PATH (build-deploy's
# entry-point input) and no AITOOLS_PROFILE_FILE / AITOOLS_MACHINE_ALIAS from this
# shell (review H5): an exported value would otherwise point the build, which deletes
# and rebuilds <dotprofile>/deploy, at the real dotprofile.
deploy_sources=$(echo "$PUSH_FILES" | grep -E '^(scripts/(setup-.*|build-deploy|aitools-lib|aitools-profile)\.(sh|ps1)$|scripts/aitools-json\.(pl|ps1)$|shared/)' || true)
if [ -z "$deploy_sources" ]; then
    step_skip "7" "deploy/ matches source" "no deploy-relevant source changes"
elif [ -z "$USER_REPO_PATH" ] || [ ! -e "$USER_REPO_PATH/.git" ]; then
    step_skip "7" "deploy/ matches source" "userRepoPath not configured -- dotprofile deploy/ not verified"
elif ! command -v node &>/dev/null; then
    step_warn "7" "deploy/ matches source" "node not found -- dotprofile deploy/ not verified"
else
    d7_tmp=$(mktemp -d)
    mkdir -p "$d7_tmp/home/.aitools" "$d7_tmp/dot" "$d7_tmp/committed"
    d7_rc=0
    d7_out=$( {
        git -C "$USER_REPO_PATH" archive -o "$d7_tmp/dot.tar" HEAD &&
        tar -xf "$d7_tmp/dot.tar" -C "$d7_tmp/dot" &&
        tar -xf "$d7_tmp/dot.tar" -C "$d7_tmp/committed" &&
        rm -rf "$d7_tmp/dot/deploy" &&
        node -e '
const fs = require("fs");
let c = {};
try { c = JSON.parse(fs.readFileSync(process.argv[1], "utf8").replace(/^﻿/, "")); }
catch (e) { if (e.code !== "ENOENT") { console.error("config.json unreadable: " + e.message); process.exit(1); } }
c.repoPath = process.argv[3]; c.userRepoPath = process.argv[4];
fs.writeFileSync(process.argv[2], JSON.stringify(c, null, 2) + "\n");
' "$CONFIG_FILE" "$d7_tmp/home/.aitools/config.json" "$REPO_ROOT" "$d7_tmp/dot" &&
        env -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE \
            HOME="$d7_tmp/home" AITOOLS_USER_REPO_PATH="$d7_tmp/dot" bash "$REPO_ROOT/scripts/build-deploy.sh"
    } 2>&1 ) || d7_rc=$?
    if [ "$d7_rc" -ne 0 ]; then
        while IFS= read -r d7_line; do
            if [ -n "$d7_line" ]; then log_detail "pre-push 7 build: $d7_line"; fi
        done <<< "$d7_out"
        step_fail "7" "deploy/ matches source" "rebuild into a dotprofile copy failed (exit $d7_rc) -- see deploy.log"
    elif [ ! -d "$d7_tmp/dot/deploy" ]; then
        # The copy's committed deploy/ was removed before the build, and build-deploy
        # exits 0 without building when it finds no dotprofile.
        while IFS= read -r d7_line; do
            if [ -n "$d7_line" ]; then log_detail "pre-push 7 build: $d7_line"; fi
        done <<< "$d7_out"
        step_fail "7" "deploy/ matches source" "build-deploy built nothing into the dotprofile copy -- see deploy.log"
    else
        d7_problems=""
        # diff -rq exit codes: 0 identical, 1 differences (listed), 2 trouble.
        d7_diff_rc=0
        d7_diff=$(diff -rq "$d7_tmp/committed/deploy" "$d7_tmp/dot/deploy" 2>&1) || d7_diff_rc=$?
        if [ "$d7_diff_rc" -eq 1 ]; then
            d7_files=$(printf '%s\n' "$d7_diff" | perl -ne 'print "$1 " if m{/deploy/(\S+) and } || m{/deploy: (\S+)}')
            d7_problems="dotprofile deploy/ is stale (${d7_files% }) -- run build-deploy.sh and commit in $USER_REPO_PATH"
        elif [ "$d7_diff_rc" -ne 0 ]; then
            log_detail "pre-push 7 diff: $d7_diff"
            d7_problems="could not compare deploy/ (diff exit $d7_diff_rc) -- see deploy.log"
        fi
        # Smoke run of the fresh build's resolver consumers. Exit 0/1 is a run (1 = a
        # counted error such as this machine having no profile); 2+ is a crash or a
        # syntax error. "resolver missing" in the output or the run summary is the
        # B8a failure. The claude script must also report its profile source.
        d7_smoke=""
        for d7_s in setup-user-claude.sh setup-user-settings.sh setup-user-cursor.sh; do
            d7_sum="$d7_tmp/smoke-summary"
            : > "$d7_sum"
            d7_s_rc=0
            d7_s_out=$(env -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 \
                HOME="$d7_tmp/home" AITOOLS_LOG_DIR="$d7_tmp/logs" AITOOLS_USER_REPO_PATH="$d7_tmp/dot" \
                AITOOLS_SUMMARY_FILE="$d7_sum" \
                bash "$d7_tmp/dot/deploy/$d7_s" --dry-run < /dev/null 2>&1) || d7_s_rc=$?
            while IFS= read -r d7_line; do
                if [ -n "$d7_line" ]; then log_detail "pre-push 7 smoke $d7_s: $d7_line"; fi
            done <<< "$d7_s_out"
            if [ "$d7_s_rc" -gt 1 ]; then
                d7_smoke="$d7_smoke $d7_s(exit $d7_s_rc)"
            elif printf '%s\n' "$d7_s_out" | grep -q 'resolver missing' || grep -q 'resolver missing' "$d7_sum"; then
                d7_smoke="$d7_smoke $d7_s(resolver missing)"
            elif [ "$d7_s" = "setup-user-claude.sh" ] && [ -f "$d7_tmp/dot/profile.json" ] \
                && ! printf '%s\n' "$d7_s_out" | grep -q 'Profile source: live'; then
                d7_smoke="$d7_smoke $d7_s(live profile not used)"
            fi
        done
        # The endpoint path (review m2): the same claude script on a machine without
        # the dotprofile (empty config.json, no AITOOLS_USER_REPO_PATH) must resolve
        # from the embedded build-time snapshot.
        if [ -f "$d7_tmp/dot/profile.json" ]; then
            mkdir -p "$d7_tmp/endpoint/.aitools"
            printf '{}\n' > "$d7_tmp/endpoint/.aitools/config.json"
            : > "$d7_sum"
            d7_s_rc=0
            d7_s_out=$(env -u AITOOLS_USER_REPO_PATH -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_PROFILE_SH -u AITOOLS_PROFILE_PS1 \
                HOME="$d7_tmp/endpoint" AITOOLS_LOG_DIR="$d7_tmp/logs" AITOOLS_SUMMARY_FILE="$d7_sum" \
                bash "$d7_tmp/dot/deploy/setup-user-claude.sh" --dry-run < /dev/null 2>&1) || d7_s_rc=$?
            while IFS= read -r d7_line; do
                if [ -n "$d7_line" ]; then log_detail "pre-push 7 smoke endpoint setup-user-claude.sh: $d7_line"; fi
            done <<< "$d7_s_out"
            if [ "$d7_s_rc" -gt 1 ]; then
                d7_smoke="$d7_smoke endpoint:setup-user-claude.sh(exit $d7_s_rc)"
            elif ! printf '%s\n' "$d7_s_out" | grep -q 'Profile source: embedded build-time snapshot'; then
                d7_smoke="$d7_smoke endpoint:setup-user-claude.sh(snapshot not used)"
            fi
        fi
        if [ -n "$d7_smoke" ]; then
            d7_problems="${d7_problems:+$d7_problems; }generated deploy scripts failed a dry run:$d7_smoke -- see deploy.log"
        fi
        if [ -z "$d7_problems" ]; then
            step_pass "7" "deploy/ matches source" "dotprofile deploy/ matches a fresh build; resolver consumers dry-run clean"
        else
            step_fail "7" "deploy/ matches source" "$d7_problems"
        fi
    fi
    rm -rf "$d7_tmp"
fi

# ---------------------------------------------------------------------------
# 8. Commit count check
# ---------------------------------------------------------------------------
if [ "$COMMIT_COUNT" -gt 5 ]; then
    step_warn "8" "Commit count" "$COMMIT_COUNT commits -- review full list before pushing"
else
    step_pass "8" "Commit count" "$COMMIT_COUNT commit(s)"
fi

# ---------------------------------------------------------------------------
# 9. Branch hygiene
# ---------------------------------------------------------------------------
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
if [ "$current_branch" = "main" ]; then
    step_pass "9" "Branch hygiene" "pushing to main (OK for single-maintainer)"
else
    step_pass "9" "Branch hygiene" "branch: $current_branch"
fi

# ---------------------------------------------------------------------------
# 10. User repo push
# ---------------------------------------------------------------------------
if [ -n "$USER_REPO_PATH" ] && [ -d "$USER_REPO_PATH" ]; then
    unpushed=$(git -C "$USER_REPO_PATH" log --oneline origin/main..HEAD 2>/dev/null || true)
    if [ -n "$unpushed" ]; then
        count=$(echo "$unpushed" | wc -l | tr -d ' ')
        step_warn "10" "User repo push" "$count unpushed commit(s) in user repo"
    else
        step_pass "10" "User repo push"
    fi
else
    step_skip "10" "User repo push" "userRepoPath not configured"
fi

# ---------------------------------------------------------------------------
# Summary + exit
# ---------------------------------------------------------------------------
print_summary

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
else
    exit 0
fi
