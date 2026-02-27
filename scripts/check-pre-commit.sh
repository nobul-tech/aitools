#!/usr/bin/env bash
# check-pre-commit.sh -- automated pre-commit checklist for ai-tooling
# Usage: bash scripts/check-pre-commit.sh [--fix]
# --fix: auto-fix line endings, exec bits, and build freshness
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/check-lib.sh
source "$SCRIPT_DIR/check-lib.sh"

# OS guard: use .ps1 on Windows
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) echo "Use check-pre-commit.ps1 on Windows"; exit 1 ;;
esac

resolve_config
check_log_init "pre-commit"

FIX_MODE=false
[ "${1:-}" = "--fix" ] && FIX_MODE=true

cd "$REPO_ROOT"

echo ""
echo "${BOLD}=== PRE-COMMIT CHECKLIST ===${RESET}"
echo ""

# Collect staged files once
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR 2>/dev/null || true)

# ---------------------------------------------------------------------------
# 1. Git identity
# ---------------------------------------------------------------------------
git_name=$(git config user.name 2>/dev/null || true)
git_email=$(git config user.email 2>/dev/null || true)
if [ "$git_name" = "Jose" ] && [ "$git_email" = "jose@nobul.tech" ]; then
    step_pass "1" "Git identity"
else
    step_fail "1" "Git identity" "expected Jose <jose@nobul.tech>, got $git_name <$git_email>"
fi

# ---------------------------------------------------------------------------
# 2. Script syntax validation
# ---------------------------------------------------------------------------
staged_sh=$(echo "$STAGED_FILES" | grep '\.sh$' || true)
staged_ps1=$(echo "$STAGED_FILES" | grep '\.ps1$' || true)

if [ -z "$staged_sh" ] && [ -z "$staged_ps1" ]; then
    step_skip "2" "Script syntax (.sh)" "no scripts staged"
    step_skip "2" "Script syntax (.ps1)" "no scripts staged"
else
    # Bash validation
    if [ -n "$staged_sh" ]; then
        sh_errors=0
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            if ! bash -n "$f" 2>/dev/null; then
                echo "      FAIL: $f"
                sh_errors=$((sh_errors + 1))
            fi
        done <<< "$staged_sh"
        if [ "$sh_errors" -eq 0 ]; then
            step_pass "2" "Script syntax (.sh)"
        else
            step_fail "2" "Script syntax (.sh)" "$sh_errors file(s) failed"
        fi
    else
        step_skip "2" "Script syntax (.sh)" "no .sh staged"
    fi

    # PS1 validation
    if [ -n "$staged_ps1" ]; then
        if $IS_MACOS; then
            if require_pwsh "2" "Script syntax (.ps1)"; then
                ps1_errors=0
                while IFS= read -r f; do
                    [ -n "$f" ] || continue
                    if ! pwsh -NoProfile -Command "
                        \$e = \$null
                        \$null = [System.Management.Automation.Language.Parser]::ParseFile('$REPO_ROOT/$f', [ref]\$null, [ref]\$e)
                        if (\$e.Count -gt 0) { \$e | ForEach-Object { Write-Host \"  line \$(\$_.Extent.StartLineNumber): \$(\$_.Message)\" }; exit 1 }
                    " 2>/dev/null; then
                        echo "      FAIL: $f"
                        ps1_errors=$((ps1_errors + 1))
                    fi
                done <<< "$staged_ps1"
                if [ "$ps1_errors" -eq 0 ]; then
                    step_pass "2" "Script syntax (.ps1)"
                else
                    step_fail "2" "Script syntax (.ps1)" "$ps1_errors file(s) failed"
                fi
            fi
        elif $IS_WINDOWS; then
            ps1_errors=0
            while IFS= read -r f; do
                [ -n "$f" ] || continue
                win_path=$(cygpath -w "$REPO_ROOT/$f")
                if ! powershell.exe -NoProfile -Command "
                    \$e = \$null
                    \$null = [System.Management.Automation.Language.Parser]::ParseFile('$win_path', [ref]\$null, [ref]\$e)
                    if (\$e.Count -gt 0) { \$e | ForEach-Object { Write-Host \"  line \$(\$_.Extent.StartLineNumber): \$(\$_.Message)\" }; exit 1 }
                " 2>/dev/null; then
                    echo "      FAIL: $f"
                    ps1_errors=$((ps1_errors + 1))
                fi
            done <<< "$staged_ps1"
            if [ "$ps1_errors" -eq 0 ]; then
                step_pass "2" "Script syntax (.ps1)"
            else
                step_fail "2" "Script syntax (.ps1)" "$ps1_errors file(s) failed"
            fi
        fi
    else
        step_skip "2" "Script syntax (.ps1)" "no .ps1 staged"
    fi
fi

# ---------------------------------------------------------------------------
# 3. Build freshness
# ---------------------------------------------------------------------------
build_needed=false
if echo "$STAGED_FILES" | grep -E '^(scripts/|shared/)' | grep -qvE 'README\.md$'; then
    build_needed=true
fi

if $build_needed; then
    if $FIX_MODE; then
        bash "$SCRIPT_DIR/build-deploy.sh" >/dev/null 2>&1
        git add deploy/ 2>/dev/null
        step_pass "3" "Build freshness" "(rebuilt + staged)"
    else
        step_warn "3" "Build freshness" "scripts/ or shared/ modified -- run with --fix"
    fi
else
    step_skip "3" "Build freshness" "no scripts/ or shared/ changes"
fi

# ---------------------------------------------------------------------------
# 4. Line endings
# ---------------------------------------------------------------------------
staged_sh_files=$(echo "$STAGED_FILES" | grep '\.sh$' || true)
if [ -z "$staged_sh_files" ]; then
    step_skip "4" "Line endings (.sh)" "no .sh staged"
else
    crlf_files=""
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        if grep -Prl '\r$' "$f" >/dev/null 2>&1; then
            crlf_files="$crlf_files $f"
        fi
    done <<< "$staged_sh_files"
    if [ -z "$crlf_files" ]; then
        step_pass "4" "Line endings (.sh)"
    elif $FIX_MODE; then
        for f in $crlf_files; do
            sed -i '' 's/\r$//' "$f"
            git add "$f"
        done
        step_pass "4" "Line endings (.sh)" "(fixed CRLF)"
    else
        step_fail "4" "Line endings (.sh)" "CRLF in:$crlf_files"
    fi
fi

# ---------------------------------------------------------------------------
# 5. Platform note
# ---------------------------------------------------------------------------
if [ -n "$staged_sh" ] || [ -n "$staged_ps1" ]; then
    step_warn "5" "Platform note" "include (tested: macOS) or (tested: Windows) in commit message"
else
    step_skip "5" "Platform note" "no scripts staged"
fi

# ---------------------------------------------------------------------------
# 6. Executable bit on .sh files
# ---------------------------------------------------------------------------
non_exec=$(git ls-files -s '*.sh' 2>/dev/null | grep -v '^100755' || true)
if [ -z "$non_exec" ]; then
    step_pass "6" "Executable bit (.sh)"
else
    bad_files=$(echo "$non_exec" | awk '{print $4}')
    if $FIX_MODE; then
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            git update-index --chmod=+x "$f"
        done <<< "$bad_files"
        step_pass "6" "Executable bit (.sh)" "(fixed)"
    else
        count=$(echo "$bad_files" | wc -l | tr -d ' ')
        step_fail "6" "Executable bit (.sh)" "$count file(s) missing +x"
    fi
fi

# ---------------------------------------------------------------------------
# 7. Install command consistency
# ---------------------------------------------------------------------------
setup_staged=$(echo "$STAGED_FILES" | grep -E '^scripts/setup-' || true)
if [ -z "$setup_staged" ]; then
    step_skip "7" "Install cmd consistency" "no setup-* staged"
else
    step_warn "7" "Install cmd consistency" "verify against reference/tool-install-sources.md"
fi

# ---------------------------------------------------------------------------
# 8. Config merge safety
# ---------------------------------------------------------------------------
setup_staged_all=$(echo "$STAGED_FILES" | grep -E '^scripts/setup-' || true)
if [ -z "$setup_staged_all" ]; then
    step_skip "8" "Config merge safety" "no setup scripts staged"
else
    # Check staged diffs for blind overwrite patterns
    overwrite_found=false
    diff_output=$(git diff --cached -- $setup_staged_all 2>/dev/null || true)
    if echo "$diff_output" | grep -qE '^\+.*cat[[:space:]]*>|^\+.*WriteAllText.*ConvertTo-Json'; then
        overwrite_found=true
    fi
    if $overwrite_found; then
        step_warn "8" "Config merge safety" "potential blind overwrite detected -- verify merge logic"
    else
        step_pass "8" "Config merge safety"
    fi
fi

# ---------------------------------------------------------------------------
# 9. Release notes
# ---------------------------------------------------------------------------
# Check if non-docs changes are staged (anything other than .md, .mdc files)
non_docs=$(echo "$STAGED_FILES" | grep -vE '\.(md|mdc)$' || true)
rn_staged=$(echo "$STAGED_FILES" | grep -q 'RELEASE_NOTES.md' && echo "yes" || echo "no")
if [ -z "$non_docs" ]; then
    step_skip "9" "Release notes" "docs-only changes"
elif [ "$rn_staged" = "yes" ]; then
    step_pass "9" "Release notes"
else
    step_warn "9" "Release notes" "non-docs changes without RELEASE_NOTES.md update"
fi

# ---------------------------------------------------------------------------
# 10. Deploy drift check
# ---------------------------------------------------------------------------
if $build_needed; then
    deploy_diff=$(git diff deploy/ 2>/dev/null || true)
    if [ -z "$deploy_diff" ]; then
        step_pass "10" "Deploy drift"
    else
        step_fail "10" "Deploy drift" "unstaged deploy/ changes remain"
    fi
else
    step_skip "10" "Deploy drift" "no build needed"
fi

# ---------------------------------------------------------------------------
# 11. User repo changes
# ---------------------------------------------------------------------------
if [ -n "$USER_REPO_PATH" ] && [ -d "$USER_REPO_PATH" ]; then
    user_dirty=$(git -C "$USER_REPO_PATH" status --porcelain 2>/dev/null || true)
    if [ -n "$user_dirty" ]; then
        step_warn "11" "User repo changes" "uncommitted changes in $USER_REPO_PATH"
    else
        step_pass "11" "User repo changes"
    fi
else
    step_skip "11" "User repo changes" "userRepoPath not configured"
fi

# ---------------------------------------------------------------------------
# 12. Template sync
# ---------------------------------------------------------------------------
if echo "$STAGED_FILES" | grep -q 'shared/claude-shared.md'; then
    step_warn "12" "Template sync" "update user repo template (<userRepoPath>/claude/CLAUDE.md)"
else
    step_skip "12" "Template sync" "shared/claude-shared.md not modified"
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
