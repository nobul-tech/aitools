#!/usr/bin/env bash
# check-post-push.sh -- automated post-push checklist for aitools
# Usage: bash scripts/check-post-push.sh
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

EXTENSIVE=true

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
    if [ -z "$USER_REPO_PATH" ] || [ ! -d "$USER_REPO_PATH" ]; then
        step_warn "5" "Session archive readiness" "hook present but userRepoPath missing -- run aitools user init"
    else
        sessions_dir="$USER_REPO_PATH/sessions"
        if [ ! -d "$sessions_dir" ]; then
            step_warn "5" "Session archive readiness" "hook configured but sessions/ dir missing -- hook may have never fired"
        else
            # Check for .jsonl files and recency
            # Use find + stat (macOS) or find + stat (Linux) — find -printf is GNU-only
            newest=""
            while IFS= read -r -d '' jf; do
                mtime=$(get_mtime "$jf")
                if [ -z "$newest" ] || [ "$mtime" -gt "$newest" ]; then
                    newest="$mtime"
                fi
            done < <(find "$sessions_dir" -name '*.jsonl' -type f -print0 2>/dev/null || true)
            if [ -z "$newest" ]; then
                step_warn "5" "Session archive readiness" "sessions/ exists but has no .jsonl files -- hook may be failing silently"
            else
                # Check if newest file is within last 7 days (604800 seconds)
                now=$(date +%s)
                age=$(( now - newest ))
                if [ "$age" -gt 604800 ]; then
                    days_ago=$(( age / 86400 ))
                    step_warn "5" "Session archive readiness" "last archive is ${days_ago}d old -- hook may have stopped working"
                else
                    file_count=$(find "$sessions_dir" -name '*.jsonl' -type f 2>/dev/null | wc -l | tr -d ' ')
                    step_pass "5" "Session archive readiness" "${file_count} archives, last within 7d"
                fi
            fi
        fi
    fi
else
    step_skip "5" "Session archive readiness" "SessionEnd hook not configured"
fi

# ===================================================================
# Steps 6+
# ===================================================================

echo ""
echo "${BOLD}--- Extended checks ---${RESET}"
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
        if ! pwsh -NoProfile -Command "
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
tool_sections=$(grep -c '^## ' "$REPO_ROOT/reference/tool-registry.md" 2>/dev/null || echo 0)
lifecycle_fields=$(grep -c '^\- \*\*Platform Status' "$REPO_ROOT/reference/tool-registry.md" 2>/dev/null || echo 0)
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
    "reference/tool-registry.md" \
    "reference/tool-evaluation-criteria.md" \
    "reference/tool-evaluation-playbook.md" \
    "reference/tool-versions.json" \
    "CLAUDE.md" \
    "shared/claude-shared.md" \
    "ROADMAP.md" \
    "reference/claude-code-maintenance.md" \
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
    if grep -rl $'\r' "$f" >/dev/null 2>&1; then
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
            mtime=$(get_mtime "$plan_path")
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
        # Skip if header says "sole owner" (check first 15 lines, matching PS1 TotalCount 15)
        if ! head -15 "$f" | grep -qi 'sole owner'; then
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
registry_version=$(grep -E 'Current version' "$REPO_ROOT/reference/claude-code-maintenance.md" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "unknown")
if [ "$cc_version" = "unknown" ]; then
    step_skip "20" "CC version-dep review" "claude CLI not found"
elif echo "$cc_version" | grep -q "$registry_version"; then
    step_pass "20" "CC version-dep review" "v$registry_version"
else
    step_warn "20" "CC version-dep review" "CLI: $cc_version vs registry: $registry_version"
fi

# ---------------------------------------------------------------------------
# 21. Tool version freshness
# ---------------------------------------------------------------------------
versions_json="$REPO_ROOT/reference/tool-versions.json"
if [ ! -f "$versions_json" ]; then
    step_skip "21" "Tool version freshness" "tool-versions.json not found"
elif ! command -v python3 >/dev/null 2>&1; then
    step_skip "21" "Tool version freshness" "python3 not available"
else
    ver21_warns=0
    ver21_ok=0
    ver21_skip=0
    ver21_details=""
    while IFS='|' read -r v21_status v21_tool v21_msg; do
        case "$v21_status" in
            OK)   ver21_ok=$((ver21_ok + 1)) ;;
            SKIP) ver21_skip=$((ver21_skip + 1))
                  ver21_details="${ver21_details}      SKIP ${v21_tool}: ${v21_msg}\n" ;;
            WARN) ver21_warns=$((ver21_warns + 1))
                  ver21_details="${ver21_details}      WARN ${v21_tool}: ${v21_msg}\n" ;;
        esac
    done < <(python3 - "$versions_json" <<'PYEOF'
import json, sys, subprocess, datetime
with open(sys.argv[1]) as f:
    data = json.load(f)
today = datetime.date.today()
TOOL_CMDS = {
    'vercel-cli':       ['vercel', '--version'],
    'cursor-agent-cli': ['agent', '--version'],
    'node':             ['node', '--version'],
    'pandoc':           ['pandoc', '--version'],
    'pwsh':             ['pwsh', '--version'],
    'rust-cargo':       ['cargo', '--version'],
    'typst':            ['typst', '--version'],
    'gh-cli':           ['gh', '--version'],
    'modal-cli':        ['modal', '--version'],
    'python':           ['python3', '--version'],
    'uv':               ['uv', '--version'],
    'go':               ['go', 'version'],
    'datadog-pup':      ['pup', 'version'],
}
for key, val in data['tools'].items():
    if 'maintenanceFile' in val:
        continue  # covered by step 20
    elif 'pinned' in val:
        last_reviewed = val.get('lastReviewed')
        if not last_reviewed:
            print(f"WARN|{key}|lastReviewed not set")
        else:
            reviewed = datetime.date.fromisoformat(last_reviewed)
            days = (today - reviewed).days
            if days > 30:
                print(f"WARN|{key}|lastReviewed {last_reviewed} ({days}d ago, >30d)")
            else:
                print(f"OK|{key}|")
    else:
        macos_ver = (val.get('macos') or {}).get('lastVerifiedVersion')
        if not macos_ver:
            print(f"SKIP|{key}|no macOS version in manifest")
            continue
        cmd = TOOL_CMDS.get(key)
        if not cmd:
            print(f"SKIP|{key}|no version command defined")
            continue
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            out = (r.stdout or r.stderr).strip().split('\n')[0]
            if macos_ver in out:
                print(f"OK|{key}|")
            else:
                print(f"WARN|{key}|installed='{out}' manifest='{macos_ver}'")
        except FileNotFoundError:
            print(f"SKIP|{key}|not installed (manifest: {macos_ver})")
        except subprocess.TimeoutExpired:
            print(f"WARN|{key}|version check timed out (manifest: {macos_ver})")
PYEOF
    )
    [ -n "$ver21_details" ] && printf "%b" "$ver21_details"
    if [ "$ver21_warns" -eq 0 ]; then
        step_pass "21" "Tool version freshness" "${ver21_ok} OK, ${ver21_skip} skipped"
    else
        step_warn "21" "Tool version freshness" "$ver21_warns tool(s) out of date; ${ver21_ok} OK, ${ver21_skip} skipped"
    fi
fi

# ---------------------------------------------------------------------------
# Step 22: Logging hygiene audit
# ---------------------------------------------------------------------------
step22_fail=0

# 22a: Winget output filtering -- check that no setup-*.ps1 has unfiltered
#      winget Split/ForEach logging (single-line ForEach without a filter guard)
bad_winget_files=""
for ps1 in "$REPO_ROOT"/scripts/setup-*.ps1; do
    [ -f "$ps1" ] || continue
    # Bad pattern: single-line ForEach piping wingetOutput Split to Log without filter
    if perl -0777 -ne 'exit 0 if /\$wingetOutput\.Trim\(\)\.Split\([^)]+\)\s*\|\s*ForEach-Object\s*\{\s*Log\s+\$_\.TrimEnd\(\)\s*\}/; exit 1' "$ps1"; then
        bad_winget_files="$bad_winget_files $(basename "$ps1")"
    fi
done
if [ -n "$bad_winget_files" ]; then
    step_fail "22a" "Winget output filtering" "unfiltered logging in:$bad_winget_files"
    step22_fail=1
else
    step_pass "22a" "Winget output filtering" "all setup-*.ps1 filter winget progress chars"
fi

# 22b: Cloud MCP in setup-user-mcp -- verify both source scripts define
#      show_cloud_mcp_status / Show-CloudMcpStatus and call it in exit section
step22b_fail=0
# Bash: check exit section calls show_cloud_mcp_status
mcp_exit_bash=$(sed -n '/BEGIN exit/,/END exit/p' "$REPO_ROOT/scripts/setup-user-mcp.sh")
if ! echo "$mcp_exit_bash" | grep -q 'show_cloud_mcp_status'; then
    step22b_fail=1
    echo "      FAIL: scripts/setup-user-mcp.sh missing show_cloud_mcp_status in exit section"
fi
# PS1: check exit section calls Show-CloudMcpStatus
mcp_exit_ps1=$(sed -n '/BEGIN exit/,/END exit/p' "$REPO_ROOT/scripts/setup-user-mcp.ps1")
if ! echo "$mcp_exit_ps1" | grep -q 'Show-CloudMcpStatus'; then
    step22b_fail=1
    echo "      FAIL: scripts/setup-user-mcp.ps1 missing Show-CloudMcpStatus in exit section"
fi
if [ "$step22b_fail" -eq 0 ]; then
    step_pass "22b" "Cloud MCP in setup-user-mcp" "both source scripts call show_cloud_mcp_status in exit"
else
    step_fail "22b" "Cloud MCP in setup-user-mcp" "missing from one or both source scripts"
    step22_fail=1
fi

# ---------------------------------------------------------------------------
# 23. Script standards compliance (extensive only)
# ---------------------------------------------------------------------------
if $EXTENSIVE; then
    if [ -f "$REPO_ROOT/scripts/check-script-compliance.sh" ]; then
        echo ""
        echo "${BOLD}--- Step 23: Script standards compliance ---${RESET}"
        if bash "$REPO_ROOT/scripts/check-script-compliance.sh"; then
            step_pass "23" "Script standards compliance" "all checks passed"
        else
            step_fail "23" "Script standards compliance" "one or more checks failed"
        fi
    else
        step_skip "23" "Script standards compliance" "check-script-compliance.sh not found"
    fi
fi

# ---------------------------------------------------------------------------
# 24. Summary panel DETAIL support (extensive only)
# ---------------------------------------------------------------------------
if $EXTENSIVE; then
    step24_ok=true
    # Verify show_summary in aitools-lib.sh handles DETAIL category
    if ! grep -q 'DETAIL' scripts/aitools-lib.sh 2>/dev/null; then
        step24_ok=false
    fi
    # Verify Show-Summary in aitools-lib.ps1 handles DETAIL category
    if ! grep -q 'DETAIL' scripts/aitools-lib.ps1 2>/dev/null; then
        step24_ok=false
    fi
    # Verify write_summary accepts DETAIL (check for documentation or usage)
    detail_usage=$(grep -r 'write_summary DETAIL\|Write-Summary.*DETAIL' scripts/ 2>/dev/null | grep -v '^\s*#' || true)
    if [ -z "$detail_usage" ]; then
        step24_ok=false
    fi

    if $step24_ok; then
        step_pass "24" "Summary panel DETAIL support" "DETAIL category in lib + scripts"
    else
        step_fail "24" "Summary panel DETAIL support" "DETAIL not fully implemented"
    fi
fi

# ---------------------------------------------------------------------------
# 25. CLI tools table sync
# ---------------------------------------------------------------------------
# Extract direct invocation commands from tool-registry.md
# Lines like: - **Invocation:** `go` (direct)
registry_cmds=$(perl -ne 'print "$1\n" if /\*\*Invocation:\*\*\s*`([^`]+)`.*\(direct\)/' \
    "$REPO_ROOT/reference/tool-registry.md" | sort -u)
# Fallback: if no matches, skip
if [ -z "$registry_cmds" ]; then
    step_skip "25" "CLI tools table sync" "could not parse registry invocations"
else
    # Extract commands from shared/claude-shared.md table
    # Lines like: | Go | `go` |
    shared_cmds=$(perl -ne 'print "$1\n" if /^\|[^|]+\|\s*`([^`]+)`/' \
        "$REPO_ROOT/shared/claude-shared.md" \
        | perl -pe 's/ \(.*?\)//' | sort -u)
    missing=""
    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        if ! echo "$shared_cmds" | grep -qxF "$cmd"; then
            missing="$missing $cmd"
        fi
    done <<< "$registry_cmds"
    if [ -z "$missing" ]; then
        step_pass "25" "CLI tools table sync" "shared/claude-shared.md matches registry"
    else
        step_warn "25" "CLI tools table sync" "missing from Managed CLI Tools:$missing"
    fi
fi

# ---------------------------------------------------------------------------
# 26. Deploy scripts list sync
# ---------------------------------------------------------------------------
# Extract unique script basenames from build-deploy.sh blog lines
# Lines like: blog "Copying deploy/setup-go.sh" or blog "Generating deploy/setup-user-claude.ps1"
build_script="$REPO_ROOT/scripts/build-deploy.sh"
if [ ! -f "$build_script" ]; then
    step_skip "26" "Deploy scripts list sync" "build-deploy.sh not found"
else
    # Get unique base script names (without .sh/.ps1 extension)
    deploy_bases=$(perl -ne 'print "$1\n" if m{blog "(?:Copying|Generating) deploy/(\S+)"}' \
        "$build_script" | perl -pe 's/\.sh$//; s/\.ps1$//' | sort -u)
    # Read CLAUDE.md deploy line
    # grep may not match; || true prevents set -e abort
    claude_deploy=$(grep 'build-deploy.sh.*generates' "$REPO_ROOT/CLAUDE.md" || true)
    if [ -z "$claude_deploy" ]; then
        step_skip "26" "Deploy scripts list sync" "could not find deploy reference in CLAUDE.md"
    else
        missing_deploy=""
        while IFS= read -r base; do
            [ -z "$base" ] && continue
            # Check if the base name appears in CLAUDE.md (full name or abbreviated -suffix)
            if ! echo "$claude_deploy" | grep -qF "$base"; then
                short=$(echo "$base" | perl -pe 's/^setup-//')
                if ! echo "$claude_deploy" | grep -qF -- "-$short"; then
                    if ! echo "$claude_deploy" | grep -qF "$short"; then
                        missing_deploy="$missing_deploy $base"
                    fi
                fi
            fi
        done <<< "$deploy_bases"
        if [ -z "$missing_deploy" ]; then
            step_pass "26" "Deploy scripts list sync" "CLAUDE.md lists all deploy scripts"
        else
            step_warn "26" "Deploy scripts list sync" "missing from CLAUDE.md:$missing_deploy"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# 27. Build prerequisites installed
# ---------------------------------------------------------------------------
if command -v cargo >/dev/null 2>&1; then
    PREREQ_MISSING=false
    if [ "$(uname -m)" = "x86_64" ] && ! command -v nasm >/dev/null 2>&1; then
        echo "      Missing: NASM -- brew install nasm / apt-get install nasm"
        PREREQ_MISSING=true
    fi
    if ! command -v cmake >/dev/null 2>&1; then
        echo "      Missing: CMake -- brew install cmake / apt-get install cmake"
        PREREQ_MISSING=true
    fi
    if $PREREQ_MISSING; then
        step_warn "27" "Build prerequisites installed" "some build tools missing (see above)"
    else
        step_pass "27" "Build prerequisites installed"
    fi
else
    step_skip "27" "Build prerequisites installed" "cargo not installed"
fi

# ---------------------------------------------------------------------------
# 28. Deploy state integrity
# ---------------------------------------------------------------------------
deploy_state_dir="$HOME/.aitools/deploy-state"
manifest_path="$deploy_state_dir/manifest.json"
if [ -f "$manifest_path" ]; then
    # node parses manifest and checks shadow files exist; output = missing keys
    shadow_check=$(node -e "
        const fs = require('fs');
        const m = JSON.parse(fs.readFileSync('$manifest_path','utf8'));
        const f = m.files || {};
        const missing = [];
        for (const k of Object.keys(f)) {
            const s = '$deploy_state_dir/shadows/' + k;
            if (!fs.existsSync(s)) missing.push(k);
        }
        if (missing.length) console.log(missing.join('; '));
    " 2>/dev/null) || true
    if [ -n "$shadow_check" ]; then
        step_warn "28" "Deploy state integrity" "missing shadows: $shadow_check"
    else
        step_pass "28" "Deploy state integrity" "manifest and shadows consistent"
    fi
else
    step_skip "28" "Deploy state integrity" "no deploy state yet"
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
