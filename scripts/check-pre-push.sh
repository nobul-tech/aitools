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
blocklist_pattern='(chat\.txt|\.tmp$|\.env$|credentials|\.secret|scratch\.|temp\.|TODO\.txt)'
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
# Match only deploy-relevant sources: setup scripts, build script, and all shared/ content
scripts_shared_changed=$(echo "$PUSH_FILES" | grep -E '^(scripts/(setup-.*|build-deploy)\.(sh|ps1)$|shared/)' || true)
deploy_changed=$(echo "$PUSH_FILES" | grep -E '^deploy/' || true)
if [ -z "$scripts_shared_changed" ]; then
    step_skip "7" "deploy/ matches source" "no scripts/shared changes"
elif [ -n "$deploy_changed" ]; then
    step_pass "7" "deploy/ matches source"
else
    step_fail "7" "deploy/ matches source" "scripts/shared changed but deploy/ not updated"
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
