#!/usr/bin/env bash
# check-pre-commit.sh -- automated pre-commit checklist for aitools
# Usage: bash scripts/check-pre-commit.sh [--fix]
# --fix: auto-fix line endings, exec bits, and build freshness
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
        log_error "This script is for macOS/Linux. On Windows, use check-pre-commit.ps1."
        exit 1 ;;
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
        if grep -rl $'\r' "$f" >/dev/null 2>&1; then
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
    step_warn "7" "Install cmd consistency" "verify against reference/tool-registry.md"
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
# 13. Deploy template logic sync
# ---------------------------------------------------------------------------
HAS_SETUP_USER=false
HAS_BUILD_DEPLOY=false
for f in $STAGED_FILES; do
    case "$f" in
        scripts/setup-user-claude.*|scripts/setup-user-cursor.*|scripts/setup-user-mcp.*|scripts/setup-user-hooks.*)
            HAS_SETUP_USER=true ;;
        scripts/build-deploy.sh)
            HAS_BUILD_DEPLOY=true ;;
    esac
done

if [ "$HAS_SETUP_USER" = true ] && [ "$HAS_BUILD_DEPLOY" = false ]; then
    step_warn "13" "Deploy template sync" "scripts/setup-user-* changed without build-deploy.sh -- verify deploy template is up to date"
elif [ "$HAS_SETUP_USER" = true ]; then
    step_pass "13" "Deploy template sync" "both scripts/ and build-deploy.sh modified"
else
    step_skip "13" "Deploy template sync" "no setup-user-* scripts modified"
fi

# ---------------------------------------------------------------------------
# 14. Build prerequisite framework
# ---------------------------------------------------------------------------
PREREQ_FAIL=false

# Check: any script using 'cargo install' must call Check-BuildPrereqs or check_build_prereqs
for script in "$REPO_ROOT"/scripts/setup-*.ps1; do
    [ -f "$script" ] || continue
    if grep -q 'cargo install' "$script" 2>/dev/null; then
        if ! grep -q 'Check-BuildPrereqs\|Diagnose-BuildFailure' "$script" 2>/dev/null; then
            echo "      $(basename "$script") uses 'cargo install' without build prereq framework"
            PREREQ_FAIL=true
        fi
    fi
done
for script in "$REPO_ROOT"/scripts/setup-*.sh; do
    [ -f "$script" ] || continue
    if grep -q 'cargo install' "$script" 2>/dev/null; then
        if ! grep -q 'check_build_prereqs\|diagnose_build_failure' "$script" 2>/dev/null; then
            echo "      $(basename "$script") uses 'cargo install' without build prereq framework"
            PREREQ_FAIL=true
        fi
    fi
done

if $PREREQ_FAIL; then
    step_fail "14" "Build prereq framework" \
        "setup scripts with source builds missing prereq checks -- see script-standards.md"
else
    step_pass "14" "Build prereq framework"
fi

# Step 15: Deprecated summary terms
echo ""
echo "${BOLD}--- Step 15: Deprecated summary terms ---${RESET}"
hits=$(grep -rn 'write_summary.*"unchanged"' scripts/ --include='*.sh' | grep -v '^scripts/check-' || true)
hits_ps1=$(grep -rn 'Write-Summary.*"unchanged"' scripts/ --include='*.ps1' | grep -v '^scripts/check-' || true)
all_hits="${hits}${hits:+$'\n'}${hits_ps1}"
all_hits=$(echo "$all_hits" | sed '/^$/d')
if [ -n "$all_hits" ]; then
    step_fail "15" "Deprecated summary terms" "found 'unchanged' in write_summary calls (use 'verified')"
    echo "$all_hits"
else
    step_pass "15" "Deprecated summary terms" "no deprecated terms found"
fi

# Step 16: Capability bypass — direct @reference/ to governed JSON in rules/CLAUDE.md
echo ""
echo "${BOLD}--- Step 16: Capability bypass audit ---${RESET}"
# Governed JSON files that require skill access (capability-based security, Dennis & Van Horn 1966)
# @reference/ prefix loads file into context, bypassing the governing skill
# Scope: .claude/rules/, CLAUDE.md, and any @-referenced files in CLAUDE.md
# See .claude/rules/governed-data-access.md for the principle
hits=$(grep -rnE '@?(reference|registries)/[a-z0-9-]*\.json' .claude/rules/ CLAUDE.md \
    | perl -ne 'print if /glossary\.json|framework-registry\.json|incidents\.json|tool-registry\.json/' \
    | grep -v '^.*:.*|.*|.*|.*|' || true)
if [ -n "$hits" ]; then
    step_fail "16" "Capability bypass audit" "rules/CLAUDE.md load governed JSON directly (use governing skill)"
    echo "$hits"
else
    step_pass "16" "Capability bypass audit" "no direct governed JSON references in rules/CLAUDE.md"
fi

# Step 17: Hook portability audit — known-bad patterns in all-platform hooks
# Hooks run bash on ALL platforms. These patterns break on one platform:
#   stat -f ... || stat -c ...  (broken fallback chain, see cross-platform.md)
#   find -printf                (GNU-only, crashes on macOS BSD find)
#   grep -P                    (Perl regex, not on macOS BSD grep)
#   date -d                    (GNU-only, macOS uses date -j)
#   readlink -f                (GNU-only, macOS needs realpath)
# Each pattern is OK if guarded by uname -s dispatch.

echo "${BOLD}--- Step 17: Hook portability audit ---${RESET}"
hook_dir="$REPO_ROOT/shared/hooks"
hook_issues=""
if [ -d "$hook_dir" ]; then
    for hook in "$hook_dir"/*.sh; do
        [ -f "$hook" ] || continue
        name=$(basename "$hook")
        # Check for stat fallback chain: stat -f ... || stat -c ... on one line
        # This is ALWAYS wrong — see cross-platform.md "NEVER use the fallback chain"
        if perl -ne 'print if /stat\s+-f.*\|\|.*stat\s+-c/ && !/^\s*#/' "$hook" 2>/dev/null | grep -q .; then
            hook_issues="${hook_issues}  $name: stat fallback chain (NEVER use, see cross-platform.md)\n"
        fi
        # Check for stat -f NOT inside a uname -s guard (within 5 lines)
        # A guarded stat -f has uname within the preceding 5 lines
        if perl -e '
            open my $fh, "<", $ARGV[0] or exit 0;
            my @lines = <$fh>;
            for my $i (0..$#lines) {
                next if $lines[$i] =~ /^\s*#/;
                next unless $lines[$i] =~ /stat\s+-f\s+%/;
                next if $lines[$i] =~ /\|\|/;  # fallback chain caught above
                my $guarded = 0;
                for my $j (($i > 5 ? $i - 5 : 0) .. $i) {
                    $guarded = 1 if $lines[$j] =~ /uname/;
                }
                print "line " . ($i+1) . ": " . $lines[$i] unless $guarded;
            }
        ' "$hook" 2>/dev/null | grep -q .; then
            hook_issues="${hook_issues}  $name: unguarded stat -f (use uname -s dispatch)\n"
        fi
        # Check for find -printf
        if perl -ne 'print if /find\s.*-printf/ && !/^\s*#/' "$hook" 2>/dev/null | grep -q .; then
            hook_issues="${hook_issues}  $name: find -printf (GNU-only, use find + stat loop)\n"
        fi
        # Check for grep -P
        if perl -ne 'print if /grep\s+-[^\s]*P/ && !/^\s*#/' "$hook" 2>/dev/null | grep -q .; then
            hook_issues="${hook_issues}  $name: grep -P (use perl -ne or grep -E)\n"
        fi
        # Check for date -d NOT inside a uname -s guard (within 5 lines)
        if perl -e '
            open my $fh, "<", $ARGV[0] or exit 0;
            my @lines = <$fh>;
            for my $i (0..$#lines) {
                next if $lines[$i] =~ /^\s*#/;
                next unless $lines[$i] =~ /date\s+-d\s/;
                my $guarded = 0;
                for my $j (($i > 5 ? $i - 5 : 0) .. $i) {
                    $guarded = 1 if $lines[$j] =~ /uname/;
                }
                print "line " . ($i+1) . ": " . $lines[$i] unless $guarded;
            }
        ' "$hook" 2>/dev/null | grep -q .; then
            hook_issues="${hook_issues}  $name: unguarded date -d (use uname -s dispatch)\n"
        fi
    done
fi
if [ -n "$hook_issues" ]; then
    step_fail "17" "Hook portability audit" "platform-specific patterns found:\n$hook_issues"
else
    step_pass "17" "Hook portability audit" "all hooks portable"
fi

# ---------------------------------------------------------------------------
# 18. Python script syntax validation
# ---------------------------------------------------------------------------
py_staged=$(echo "$STAGED_FILES" | grep '\.py$' || true)
if [ -z "$STAGED_FILES" ]; then
    step_skip "18" "Script syntax (.py)" "no scripts staged"
elif [ -z "$py_staged" ]; then
    step_skip "18" "Script syntax (.py)" "no .py staged"
else
    PYTHON=""
    if command -v python3 >/dev/null 2>&1; then
        PYTHON="python3"
    elif command -v python >/dev/null 2>&1; then
        PYTHON="python"
    fi
    if [ -z "$PYTHON" ]; then
        step_skip "18" "Script syntax (.py)" "python3 not found"
    else
        py_errors=0
        while IFS= read -r f; do
            [ -f "$f" ] || continue
            if ! "$PYTHON" -m py_compile "$f" 2>/dev/null; then
                py_errors=$((py_errors + 1))
                printf '    FAIL: %s\n' "$f"
            fi
        done <<< "$py_staged"
        if [ "$py_errors" -eq 0 ]; then
            step_pass "18" "Script syntax (.py)"
        else
            step_fail "18" "Script syntax (.py)" "$py_errors file(s) failed"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 19. Harness DB schema file exists
# ---------------------------------------------------------------------------
if [ -f "$REPO_ROOT/reference/harness-db-schema.sql" ]; then
    step_pass "19" "Harness DB schema file" "reference/harness-db-schema.sql exists"
else
    step_fail "19" "Harness DB schema file" "reference/harness-db-schema.sql missing"
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
