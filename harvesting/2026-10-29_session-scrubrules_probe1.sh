#!/usr/bin/env bash
# probe1: verify rule claims against code (read-only)
set -uo pipefail
R=/Users/new-jose/repos/aitools
cd "$R"
sec() { printf '\n===== %s =====\n' "$1"; }

sec "skills present"
ls shared/skills .claude/skills 2>&1

sec "check-post-push step headers"
grep -nE '^(# ?)?(=+ )?Step [0-9]+|step_start|StepStart|STEP [0-9]+|^# [0-9]+\.' scripts/check-post-push.sh | head -80

sec "check-pre-commit step headers"
grep -nE 'Step [0-9]+|step_start|STEP [0-9]+' scripts/check-pre-commit.sh | head -80

sec "check-pre-push step headers"
grep -nE 'Step [0-9]+|step_start|STEP [0-9]+' scripts/check-pre-push.sh | head -60

sec "git checkout HEAD -- deploy in entry points"
grep -n 'checkout HEAD' scripts/aitools scripts/aitools.ps1 scripts/hh.sh scripts/hh.ps1

sec "standing-order-guard MODE vars"
grep -nE 'MODE_[A-Z]+=|violation "' shared/hooks/standing-order-guard.sh | head -60

sec "delegation-duty-guard MODE"
grep -nE 'MODE_[A-Z]+=' shared/hooks/delegation-duty-guard.sh

sec "shared/rules"
ls shared/rules 2>&1

sec "deploy-state usage"
grep -rln 'deploy-state' scripts shared | head -30

sec "aitools-workspace dirs"
ls -d .aitools/scratch .aitools/harvesting harvesting .scratch .aitools/channel/running-estimate.json 2>&1

sec "env API"
grep -nE 'is_claude_code_web|Test-ClaudeCodeWeb|write_environment_skip|Write-EnvironmentSkip|BEGIN aitools environment block|AITOOLS_ENVIRONMENT=|cursor-cloud|cursor_cloud|install_via_brew|install_via_apt' scripts/aitools-lib.sh scripts/aitools-lib.ps1 | head -40

sec "lib function existence"
for f in display_path read_config_key backup_dir emit_merge_details check_build_prereqs diagnose_build_failure ensure_tool_on_path invoke_ai deploy_tracker_record review_json_fields prompt_json_field_review sync_managed_json prompt_diff_review adopt_claude_md resolve_machine_profile validate_json_config backup_file deploy_managed_file logging_init; do
  printf '%s: ' "$f"; grep -cE "^${f}\(\)|^function ${f}|^${f} \(\)" scripts/aitools-lib.sh
done
for f in ReadConfigKey Backup-Dir ConvertPSObjectToHashtable Emit-MergeDetails Check-BuildPrereqs Diagnose-BuildFailure Invoke-AI Record-DeployOutcome Review-JsonFields Prompt-JsonFieldReview Sync-ManagedJson Prompt-DiffReview Resolve-MachineProfile ValidateJsonConfig Backup-File Deploy-ManagedFile Initialize-Logging Write-EnvironmentSkip Test-ClaudeCodeWeb; do
  printf '%s: ' "$f"; grep -ciE "^function ${f}\b" scripts/aitools-lib.ps1
done

sec "validate_json_config / ValidateJsonConfig locations"
grep -lE 'validate_json_config|ValidateJsonConfig' scripts/*.sh scripts/*.ps1

sec "inline node validation in setup-user-hooks / mcp"
grep -nE '_missing|Validation failed' scripts/setup-user-hooks.sh scripts/setup-user-mcp.sh scripts/setup-user-mcp.ps1 | head

sec "backup retention"
grep -nE 'keep|20|prune' scripts/aitools-lib.sh | grep -iE 'backup|prune|keep' | head -20

sec "TOOL_CMDS / toolCmds"
grep -nE 'TOOL_CMDS|toolCmds' scripts/check-post-push.sh scripts/check-post-push.ps1 | head

sec "build-deploy per-tool copy blocks"
grep -nE 'setup-(perl|typst|go|uv|modal)' scripts/build-deploy.sh | head -20

sec "CLAUDE.md lines and deploy list"
wc -l CLAUDE.md
grep -nE 'Deploy using MDM|setup-perl|Channel exception|Key Decisions' CLAUDE.md

sec "RELEASE_NOTES headers"
grep -nE '^## v' RELEASE_NOTES.md | head -8

sec "ROADMAP sections"
grep -nE '^## ' ROADMAP.md | head; grep -n 'I6' ROADMAP.md | head -5

sec "plans exist"
ls plans/governance-and-compliance-framework.md plans/build-package/design.md plans/build-package/implementation-plan.md reference/plan-execution-detail.md reference/smoke-test-pattern-detail.md reference/cursor-practices.md shared/cursor-rules/user-rules.md registries 2>&1

sec "rules line counts"
wc -l .claude/rules/*.md

sec "session-archive line 68"
sed -n '60,75p' shared/hooks/session-archive.sh
