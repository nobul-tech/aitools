#!/usr/bin/env python3
"""Second pass: blocks/anchors the first parser skipped."""
from pathlib import Path

REPO = Path("/Users/new-jose/repos/aitools")
checks = [
    ("scripts/setup-user-claude.sh", 'else\n    log_warn "Profile not available -- {{PLACEHOLDER}} tokens will not be resolved"\n    write_summary WARN "claude.md" "template tokens unresolved"\nfi'),
    ("scripts/build-deploy.sh", "            USER_RULE_COUNT=$((USER_RULE_COUNT + 1))\n        done\n    fi\nfi"),
    ("scripts/build-deploy.sh", 'RULES_SRC=$(mktemp -d)\n_cleanup_rules() { rm -rf "$RULES_SRC"; }\ntrap _cleanup_rules EXIT'),
    ("scripts/build-deploy.sh", '# Clean up temp source dir\nrm -rf "$RULES_SRC"\ntrap - EXIT'),
    ("scripts/build-deploy.sh", "- Machine: ${OS_NAME} ${ARCH} (${HOSTNAME})"),
    ("scripts/build-deploy.sh", "# --- Profile interpolation ---"),
    ("scripts/build-deploy.sh", 'blog "Cursor CLI prefs: vimMode=$CURSOR_CLI_VIMMODE model=$CURSOR_CLI_MODEL"'),
    ("scripts/build-deploy.sh", "- Machine: $osInfo ($hostname)"),
    ("scripts/build-deploy.sh", "extract_between"),
    ("scripts/aitools-install.sh", "# Managed fields: version, reposPath, repoPath; googleDrives only when drives were"),
    ("scripts/aitools-install.ps1", "# Managed fields: version, reposPath, repoPath; googleDrives only when drives were"),
    ("scripts/aitools-install.sh", 'write_summary WARN "aitools config" "not updated (no node)"'),
    ("scripts/aitools-install.sh", 'DEPLOY_SCRIPTS="setup-user-claude.sh setup-user-cursor.sh'),
    ("scripts/aitools-install.sh", "validate_json_config()"),
    ("scripts/aitools-install.ps1", "function ValidateJsonConfig"),
    ("scripts/aitools-install.sh", "REPOS_PATH_JSON"),
    ("scripts/aitools-install.sh", "AITOOLS_JSON"),
    ("scripts/aitools", "local deploy_scripts="),
    ("scripts/aitools", "# Detect machineAlias from profile.json by hostname match"),
    ("scripts/aitools", "# Write userRepoPath and machineAlias to config"),
    ("scripts/aitools", "check_profile interactive"),
    ("scripts/aitools", "migrate_profile_v1_to_v2"),
    ("scripts/aitools-lib.sh", "read_config_key()"),
    ("scripts/aitools-lib.sh", "backup_file()"),
    ("scripts/aitools-lib.ps1", "function ReadConfigKey"),
    ("scripts/aitools-lib.ps1", "function Backup-File"),
    ("scripts/setup-user-claude.ps1", "# --- Resolve template source ---"),
    ("scripts/setup-user-claude.ps1", 'Write-Summary "WARN" "claude.md" "template tokens unresolved"'),
    ("scripts/setup-user-claude.ps1", "$configFile"),
    ("scripts/setup-user-claude.sh", 'if [ -n "${PROFILE_NAME:-}" ]'),
    ("scripts/setup-user-claude.sh", "adopt_claude_md"),
]
for f, s in checks:
    t = (REPO / f).read_text()
    print(f"{t.count(s):3d}  {f}  {s.splitlines()[0][:80]!r}")
