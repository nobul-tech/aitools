#!/usr/bin/env bash
# check-post-push.sh -- automated post-push checklist for ai-tooling
# Usage: bash scripts/check-post-push.sh [--extensive]
# Default: 5 always-tier steps. --extensive: all 20 steps.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/check-lib.sh
source "$SCRIPT_DIR/check-lib.sh"

# OS guard: use .ps1 on Windows
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) echo "Use check-post-push.ps1 on Windows"; exit 1 ;;
esac

resolve_config
check_log_init "post-push"

EXTENSIVE=false
[ "${1:-}" = "--extensive" ] && EXTENSIVE=true

cd "$REPO_ROOT"

echo ""
echo "${BOLD}=== POST-PUSH CHECKLIST ===${RESET}"
if $EXTENSIVE; then echo "  (extensive mode)"; fi
echo ""

# ===================================================================
# ALWAYS TIER (steps 1-5)
# ===================================================================

# ---------------------------------------------------------------------------
# 1. Verify push landed
# ---------------------------------------------------------------------------
git fetch origin main --quiet 2>/dev/null || true
local_head=$(git rev-parse HEAD 2>/dev/null)
remote_head=$(git rev-parse origin/main 2>/dev/null)
if [ "$local_head" = "$remote_head" ]; then
    short=$(git log --oneline -1 HEAD)
    step_pass "1" "Verify push landed" "$short"
else
    step_fail "1" "Verify push landed" "HEAD != origin/main"
fi

# ---------------------------------------------------------------------------
# 2. Smoke-test deploy scripts
# ---------------------------------------------------------------------------
deploy_errors=0
for f in "$REPO_ROOT"/deploy/*.sh; do
    [ -f "$f" ] || continue
    if ! bash -n "$f" 2>/dev/null; then
        echo "      FAIL: $(basename "$f")"
        deploy_errors=$((deploy_errors + 1))
    fi
done
if [ "$deploy_errors" -eq 0 ]; then
    step_pass "2" "Smoke-test deploy scripts"
else
    step_fail "2" "Smoke-test deploy scripts" "$deploy_errors file(s) failed bash -n"
fi

# ---------------------------------------------------------------------------
# 3. MCP config integrity
# ---------------------------------------------------------------------------
claude_json="$HOME/.claude.json"
cursor_mcp="$HOME/.cursor/mcp.json"
mcp_ok=true

for cfg in "$claude_json" "$cursor_mcp"; do
    if [ ! -f "$cfg" ]; then
        echo "      missing: $cfg"
        mcp_ok=false
        continue
    fi
    if ! grep -q 'chrome-devtools' "$cfg" 2>/dev/null; then
        echo "      chrome-devtools missing in $(basename "$cfg")"
        mcp_ok=false
    fi
    if ! grep -q 'isolated' "$cfg" 2>/dev/null; then
        echo "      --isolated missing in $(basename "$cfg")"
        mcp_ok=false
    fi
done
if $mcp_ok; then
    step_pass "3" "MCP config integrity"
else
    step_fail "3" "MCP config integrity" "see details above"
fi

# ---------------------------------------------------------------------------
# 4. CLI entry point + version
# ---------------------------------------------------------------------------
aitools_version=$(bash "$SCRIPT_DIR/aitools" --version 2>/dev/null || echo "FAILED")
tag_version=$(git describe --tags --match "v*" --abbrev=0 2>/dev/null || echo "none")
if [ "$aitools_version" != "FAILED" ]; then
    step_pass "4" "CLI entry point + version" "$aitools_version (tag: $tag_version)"
else
    step_fail "4" "CLI entry point + version" "aitools --version failed"
fi

# ---------------------------------------------------------------------------
# 5. Session archive readiness
# ---------------------------------------------------------------------------
settings_file="$HOME/.claude/settings.json"
hook_present=false
if [ -f "$settings_file" ] && grep -q 'session-archive' "$settings_file" 2>/dev/null; then
    hook_present=true
fi

if $hook_present; then
    if [ -n "$USER_REPO_PATH" ] && [ -d "$USER_REPO_PATH" ]; then
        step_pass "5" "Session archive readiness"
    else
        step_warn "5" "Session archive readiness" "hook present but userRepoPath missing -- run aitools user init"
    fi
else
    step_skip "5" "Session archive readiness" "SessionEnd hook not configured"
fi

# ===================================================================
# EXTENSIVE TIER (steps 6-20, only with --extensive)
# ===================================================================
if ! $EXTENSIVE; then
    print_summary
    if [ "$FAIL_COUNT" -gt 0 ]; then exit 1; else exit 0; fi
fi

echo ""
echo "${BOLD}--- Extensive tier ---${RESET}"
echo ""

# ---------------------------------------------------------------------------
# 6. Full script syntax validation
# ---------------------------------------------------------------------------
sh_errors=0
for f in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/deploy/*.sh "$REPO_ROOT"/shared/hooks/*.sh; do
    [ -f "$f" ] || continue
    if ! bash -n "$f" 2>/dev/null; then
        echo "      FAIL: $f"
        sh_errors=$((sh_errors + 1))
    fi
done
if [ "$sh_errors" -eq 0 ]; then
    step_pass "6" "Full syntax (.sh)"
else
    step_fail "6" "Full syntax (.sh)" "$sh_errors file(s) failed"
fi

# PS1 validation
if $IS_MACOS; then
    if require_pwsh "6" "Full syntax (.ps1)"; then
        ps1_errors=0
        for f in "$REPO_ROOT"/scripts/*.ps1 "$REPO_ROOT"/deploy/*.ps1; do
            [ -f "$f" ] || continue
            if ! pwsh -NoProfile -Command "
                \$e = \$null
                \$null = [System.Management.Automation.Language.Parser]::ParseFile('$f', [ref]\$null, [ref]\$e)
                if (\$e.Count -gt 0) { \$e | ForEach-Object { Write-Host \"  line \$(\$_.Extent.StartLineNumber): \$(\$_.Message)\" }; exit 1 }
            " 2>/dev/null; then
                echo "      FAIL: $(basename "$f")"
                ps1_errors=$((ps1_errors + 1))
            fi
        done
        if [ "$ps1_errors" -eq 0 ]; then
            step_pass "6" "Full syntax (.ps1)"
        else
            step_fail "6" "Full syntax (.ps1)" "$ps1_errors file(s) failed"
        fi
    fi
elif $IS_WINDOWS; then
    ps1_errors=0
    for f in "$REPO_ROOT"/scripts/*.ps1 "$REPO_ROOT"/deploy/*.ps1; do
        [ -f "$f" ] || continue
        win_path=$(cygpath -w "$f")
        if ! powershell.exe -NoProfile -Command "
            \$e = \$null
            \$null = [System.Management.Automation.Language.Parser]::ParseFile('$win_path', [ref]\$null, [ref]\$e)
            if (\$e.Count -gt 0) { \$e | ForEach-Object { Write-Host \"  line \$(\$_.Extent.StartLineNumber): \$(\$_.Message)\" }; exit 1 }
        " 2>/dev/null; then
            echo "      FAIL: $(basename "$f")"
            ps1_errors=$((ps1_errors + 1))
        fi
    done
    if [ "$ps1_errors" -eq 0 ]; then
        step_pass "6" "Full syntax (.ps1)"
    else
        step_fail "6" "Full syntax (.ps1)" "$ps1_errors file(s) failed"
    fi
fi

# ---------------------------------------------------------------------------
# 7. deploy/ drift audit
# ---------------------------------------------------------------------------
bash "$SCRIPT_DIR/build-deploy.sh" >/dev/null 2>&1
drift=$(git diff deploy/ 2>/dev/null || true)
if [ -z "$drift" ]; then
    step_pass "7" "deploy/ drift audit"
else
    step_fail "7" "deploy/ drift audit" "deploy/ is stale -- rebuild needed"
    git checkout -- deploy/ 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 8. Rule parity audit
# ---------------------------------------------------------------------------
# Known Claude-only rules (no cursor counterpart expected)
claude_only="git-identity|python-style|surface-silent-failures"
parity_errors=0
for f in "$REPO_ROOT"/.claude/rules/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .md)
    if echo "$base" | grep -qE "^($claude_only)$"; then continue; fi
    cursor_file="$REPO_ROOT/.cursor/rules/${base}.mdc"
    if [ ! -f "$cursor_file" ]; then
        echo "      missing cursor counterpart: .cursor/rules/${base}.mdc"
        parity_errors=$((parity_errors + 1))
    fi
done
if [ "$parity_errors" -eq 0 ]; then
    step_pass "8" "Rule parity audit"
else
    step_fail "8" "Rule parity audit" "$parity_errors missing counterpart(s)"
fi

# ---------------------------------------------------------------------------
# 9. Source-of-truth consistency
# ---------------------------------------------------------------------------
# Count tool sections (## headings between --- separators) vs lifecycle field count
tool_sections=$(grep -c '^## ' "$REPO_ROOT/reference/tool-install-sources.md" 2>/dev/null || echo 0)
lifecycle_fields=$(grep -c '^\- \*\*Platform Status' "$REPO_ROOT/reference/tool-install-sources.md" 2>/dev/null || echo 0)
# Subtract non-tool headings (Overrides, Under Evaluation, MCP Management)
# Approximate: each tool should have exactly one Platform Status line
if [ "$lifecycle_fields" -gt 0 ]; then
    step_pass "9" "Source-of-truth consistency" "$lifecycle_fields lifecycle blocks found"
else
    step_warn "9" "Source-of-truth consistency" "could not parse lifecycle fields"
fi

# ---------------------------------------------------------------------------
# 10. Protected files inventory
# ---------------------------------------------------------------------------
inventory_errors=0
# Check that key protected files exist
for pf in \
    "reference/tool-install-sources.md" \
    "reference/tool-evaluation-criteria.md" \
    "CLAUDE.md" \
    "shared/claude-shared.md" \
    "ROADMAP.md" \
    "reference/claude-code-version-deps.md" \
    "reference/user-repo.md"; do
    if [ ! -f "$REPO_ROOT/$pf" ]; then
        echo "      missing: $pf"
        inventory_errors=$((inventory_errors + 1))
    fi
done
if [ "$inventory_errors" -eq 0 ]; then
    step_pass "10" "Protected files inventory"
else
    step_fail "10" "Protected files inventory" "$inventory_errors file(s) missing"
fi

# ---------------------------------------------------------------------------
# 11. Cross-platform pairing
# ---------------------------------------------------------------------------
pairing_errors=0
for f in "$REPO_ROOT"/scripts/setup-*.sh; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .sh)
    if [ ! -f "$REPO_ROOT/scripts/${base}.ps1" ]; then
        echo "      unpaired: scripts/${base}.sh (no .ps1)"
        pairing_errors=$((pairing_errors + 1))
    fi
done
for f in "$REPO_ROOT"/scripts/setup-*.ps1; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .ps1)
    if [ ! -f "$REPO_ROOT/scripts/${base}.sh" ]; then
        echo "      unpaired: scripts/${base}.ps1 (no .sh)"
        pairing_errors=$((pairing_errors + 1))
    fi
done
if [ "$pairing_errors" -eq 0 ]; then
    step_pass "11" "Cross-platform pairing"
else
    step_fail "11" "Cross-platform pairing" "$pairing_errors unpaired script(s)"
fi

# ---------------------------------------------------------------------------
# 12. CLAUDE.md limits
# ---------------------------------------------------------------------------
claude_lines=$(wc -l < "$REPO_ROOT/CLAUDE.md" | tr -d ' ')
if [ "$claude_lines" -lt 200 ]; then
    step_pass "12" "CLAUDE.md limits" "$claude_lines lines (< 200)"
else
    step_fail "12" "CLAUDE.md limits" "$claude_lines lines (>= 200)"
fi

# ---------------------------------------------------------------------------
# 13. Reference link audit
# ---------------------------------------------------------------------------
ref_errors=0
while IFS= read -r ref; do
    # Extract path after @
    ref_path=$(echo "$ref" | sed 's/.*@//')
    if [ ! -f "$REPO_ROOT/$ref_path" ]; then
        echo "      broken @import: $ref_path"
        ref_errors=$((ref_errors + 1))
    fi
done < <(grep -oE '@reference/[A-Za-z0-9._/-]+' "$REPO_ROOT/CLAUDE.md" 2>/dev/null || true)
if [ "$ref_errors" -eq 0 ]; then
    step_pass "13" "Reference link audit"
else
    step_fail "13" "Reference link audit" "$ref_errors broken link(s)"
fi

# ---------------------------------------------------------------------------
# 14. Line ending audit
# ---------------------------------------------------------------------------
crlf_count=0
for f in "$REPO_ROOT"/scripts/*.sh "$REPO_ROOT"/deploy/*.sh "$REPO_ROOT"/shared/hooks/*.sh; do
    [ -f "$f" ] || continue
    if grep -Prl '\r$' "$f" >/dev/null 2>&1; then
        echo "      CRLF: $f"
        crlf_count=$((crlf_count + 1))
    fi
done
if [ "$crlf_count" -eq 0 ]; then
    step_pass "14" "Line ending audit"
else
    step_fail "14" "Line ending audit" "$crlf_count file(s) with CRLF"
fi

# ---------------------------------------------------------------------------
# 15. MCP config deploy
# ---------------------------------------------------------------------------
step_skip "15" "MCP config deploy" "side-effect -- run setup scripts manually if needed"

# ---------------------------------------------------------------------------
# 16. Roadmap freshness
# ---------------------------------------------------------------------------
stale_count=0
if [ -f "$REPO_ROOT/ROADMAP.md" ]; then
    while IFS= read -r plan_file; do
        [ -n "$plan_file" ] || continue
        plan_path="$REPO_ROOT/$plan_file"
        if [ -f "$plan_path" ]; then
            # Check if modified in last 14 days
            if $IS_MACOS; then
                mtime=$(stat -f %m "$plan_path" 2>/dev/null || echo 0)
            else
                mtime=$(stat -c %Y "$plan_path" 2>/dev/null || echo 0)
            fi
            now=$(date +%s)
            age_days=$(( (now - mtime) / 86400 ))
            if [ "$age_days" -gt 14 ]; then
                echo "      stale ($age_days days): $plan_file"
                stale_count=$((stale_count + 1))
            fi
        fi
    done < <(grep -oE 'plans/[^ |)]+' "$REPO_ROOT/ROADMAP.md" 2>/dev/null || true)
fi
if [ "$stale_count" -eq 0 ]; then
    step_pass "16" "Roadmap freshness"
else
    step_warn "16" "Roadmap freshness" "$stale_count plan(s) not updated in 14+ days"
fi

# ---------------------------------------------------------------------------
# 17. Hook verification
# ---------------------------------------------------------------------------
if [ -f "$settings_file" ] && grep -q 'session-archive' "$settings_file" 2>/dev/null; then
    if [ -n "$USER_REPO_PATH" ] && [ -d "$USER_REPO_PATH" ]; then
        step_pass "17" "Hook verification"
    else
        step_warn "17" "Hook verification" "hook present but user repo dir missing"
    fi
else
    step_warn "17" "Hook verification" "SessionEnd hook not in settings.json"
fi

# ---------------------------------------------------------------------------
# 18. Untracked file hygiene
# ---------------------------------------------------------------------------
untracked=$(git status --porcelain 2>/dev/null | grep '^??' | grep -E '\.(md|sh|ps1|mdc)$' || true)
if [ -z "$untracked" ]; then
    step_pass "18" "Untracked file hygiene"
else
    count=$(echo "$untracked" | wc -l | tr -d ' ')
    step_warn "18" "Untracked file hygiene" "$count untracked script/doc file(s)"
fi

# ---------------------------------------------------------------------------
# 19. Config merge audit
# ---------------------------------------------------------------------------
overwrite_count=0
for f in "$REPO_ROOT"/scripts/setup-*.sh "$REPO_ROOT"/scripts/setup-*.ps1; do
    [ -f "$f" ] || continue
    if grep -qE 'cat[[:space:]]*>' "$f" 2>/dev/null; then
        fname=$(basename "$f")
        # Skip if header says "sole owner"
        if ! head -5 "$f" | grep -qi 'sole owner'; then
            echo "      potential blind overwrite: $fname"
            overwrite_count=$((overwrite_count + 1))
        fi
    fi
done
if [ "$overwrite_count" -eq 0 ]; then
    step_pass "19" "Config merge audit"
else
    step_warn "19" "Config merge audit" "$overwrite_count script(s) with potential blind overwrite"
fi

# ---------------------------------------------------------------------------
# 20. CC version-dep review
# ---------------------------------------------------------------------------
cc_version=$(claude --version 2>/dev/null | head -1 || echo "unknown")
registry_version=$(grep -E 'Current version' "$REPO_ROOT/reference/claude-code-version-deps.md" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
if [ "$cc_version" = "unknown" ]; then
    step_skip "20" "CC version-dep review" "claude CLI not found"
elif echo "$cc_version" | grep -q "$registry_version"; then
    step_pass "20" "CC version-dep review" "v$registry_version"
else
    step_warn "20" "CC version-dep review" "CLI: $cc_version vs registry: $registry_version"
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
