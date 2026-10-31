#!/usr/bin/env bash
# Re-check review citations against the main checkout (scratch, read-only).
set -uo pipefail
R=/Users/new-jose/repos/aitools
S=$R/scripts
H=$R/shared/hooks
chk() { printf '\n=== %s\n' "$1"; shift; "$@" 2>&1 | head -n 12; }

chk "BD trap leak 320/1706" grep -n "trap " $S/build-deploy.sh
chk "BD AITOOLS_USER_REPO_PATH 188-218" grep -n 'DEPLOY_DIR_FINAL=\|AITOOLS_USER_REPO_PATH' $S/build-deploy.sh
chk "BD node skip exit 0 86-89" sed -n '84,92p' $S/build-deploy.sh
chk "BD pwsh optional 2279" grep -n 'PS1 validation' $S/build-deploy.sh
chk "BD chmod 2288" grep -n 'chmod +x' $S/build-deploy.sh
chk "BD rm -rf swap 2298" grep -n 'rm -rf "\$DEPLOY_DIR_FINAL"\|mv .*DEPLOY_DIR_FINAL' $S/build-deploy.sh
chk "BD resolver lib twice 436-437" grep -n 'RESOLVER_SH_FILES=\|RESOLVER_PS1_FILES=' $S/build-deploy.sh
chk "BD uncommitted warn 1771" grep -n -i 'uncommitted' $S/build-deploy.sh
chk "BD version stamp" grep -n -c 'BUILD-INFO\|rev-parse HEAD' $S/build-deploy.sh
chk "BD size gate" grep -n '200000\|200,000' $S/build-deploy.sh
chk "BD win pwsh parse 2>/dev/null 2232-2239" sed -n '2230,2242p' $S/build-deploy.sh
chk "DH add_source git 181-192" sed -n '178,194p' $S/deploy-harness.sh
chk "DH HARNESS_DIR 79" grep -n 'HARNESS_DIR=' $S/deploy-harness.sh
chk "DH ps1 HARNESS 78" grep -n 'USERPROFILE' $S/deploy-harness.ps1
chk "DH ps1 rev-parse LASTEXITCODE 160-176" sed -n '158,178p' $S/deploy-harness.ps1
chk "DH config.json not generated 104-114" sed -n '100,116p' $S/deploy-harness.sh
chk "DH skip-config on main" grep -n -c 'skip-config' $S/deploy-harness.sh
chk "INST unknown option 47-51,76" sed -n '44,56p' $S/aitools-install.sh
chk "INST exit 0 help 76" sed -n '70,78p' $S/aitools-install.sh
chk "INST Step21 list 831-842" sed -n '829,842p' $S/aitools-install.sh
chk "SYNC deploy_configs list 1151" sed -n '1149,1153p' $S/aitools
chk "SYNC deploy-harness on main" grep -n -c 'deploy-harness' $S/aitools $S/aitools-install.sh
chk "INST node@22 619" grep -n 'node@22' $S/aitools-install.sh
chk "INST lib source 14" sed -n '12,16p' $S/aitools-install.sh
chk "INST touch summary 211-216" sed -n '209,217p' $S/aitools-install.sh
chk "INST mkdir aitools 334" grep -n 'mkdir -p.*\.aitools' $S/aitools-install.sh
chk "INST MDM deploy count sh" grep -c 'skipping (MDM deploy)' $S/aitools-install.sh
chk "INST MDM deploy count ps1" grep -c 'skipping (MDM deploy)' $S/aitools-install.ps1
chk "UI create dotprofile ans=y 811" grep -n 'ans="y"' $S/aitools
chk "UI gh repo create" grep -n 'gh repo create' $S/aitools $S/aitools.ps1
chk "PS stamp -replace" grep -n "\-replace '\^" $S/aitools.ps1
chk "PS git bash path 1989" grep -n 'Git\\bin\\bash.exe' $S/aitools.ps1
chk "SYNC git pull 2006 2037" grep -n 'git pull\|GIT_TERMINAL_PROMPT' $S/aitools
chk "AITOOLS_DEPLOY" grep -rn 'AITOOLS_DEPLOY\b' $S
chk "BOOT ps1 powershell 48" grep -n '& powershell' $S/bootstrap.ps1
chk "BOOT sh brew install 32-35" grep -n 'install.sh\|NONINTERACTIVE' $S/bootstrap.sh
chk "BOOT sh installer result 76-80" sed -n '74,82p' $S/bootstrap.sh
chk "LIB log dir 72" sed -n '70,74p' $S/aitools-lib.sh
chk "LIB console user grep" grep -rln -E '/dev/console|SUDO_USER|ConsoleUser' $S $H
chk "LIB Test-IsAdmin callers" grep -rn 'Test-IsAdmin' $S
chk "LIB install_via helpers" grep -rn 'install_via_brew\|install_via_apt\|as_root' $S
chk "LIB env block 41-52" sed -n '41,53p' $S/aitools-lib.sh
chk "LIB distro detect" grep -rn 'os-release\|VERSION_ID' $S
chk "LIB HKCU PATH 2794 2907" grep -n 'SetEnvironmentVariable' $S/aitools-lib.ps1 $S/setup-modal.ps1
chk "LIB logging_init mkdir 662" sed -n '658,666p' $S/aitools-lib.sh
chk "LIB log append 682-699" sed -n '682,700p' $S/aitools-lib.sh
chk "LIB ps1 AppendAllText" grep -n 'AppendAllText' $S/aitools-lib.ps1
chk "LIB rotate only deploy.log 663" grep -n '_rotate_log ' $S/aitools-lib.sh
chk "LIB sync_managed_json auto-adopt 2546-2555" sed -n '2544,2556p' $S/aitools-lib.sh
chk "LIB backup_dir *.md 925-928" sed -n '921,930p' $S/aitools-lib.sh
chk "LIB sync mktemp 2449-2450" sed -n '2447,2451p' $S/aitools-lib.sh
chk "PROF first profile docs" grep -rn 'then first profile' $R/.claude/rules $R/reference
chk "PROF no machine error 763" grep -n 'no profile matches' $S/aitools-profile.sh
chk "PROF environment claude-code-web literal" grep -c 'environment:claude-code-web' $S/aitools-profile.sh
chk "SU claude SHELL 178" sed -n '176,179p' $S/setup-user-claude.sh
chk "SU shell bash_profile 39-40" sed -n '38,41p' $S/setup-user-shell.sh
chk "SU shell backup 68" sed -n '66,69p' $S/setup-user-shell.sh
chk "SU shell dry-run" grep -c 'DRY_RUN' $S/setup-user-shell.sh $S/setup-user-shell.ps1
chk "SU hooks settings backup" grep -n 'backup_file\|Backup-File' $S/setup-user-hooks.sh $S/setup-user-hooks.ps1
chk "SU hooks write 383" sed -n '380,385p' $S/setup-user-hooks.sh
chk "SU hooks userRepoPath 70" grep -n 'read_config_key\|ReadConfigKey' $S/setup-user-hooks.sh $S/setup-user-hooks.ps1
chk "HOOK ait-harvest cwd" grep -n 'PROJECT_ROOT/scripts/ait-harvest\|ait-harvest.py' $H/session-archive.sh $H/session-catchup.sh
chk "SU cursor backup 179-181" sed -n '177,186p' $S/setup-user-cursor.sh
chk "SU cursor model reset 263-274" sed -n '262,275p' $S/setup-user-cursor.sh
chk "SU cursor rg brew 85-108" grep -n 'brew install\|Homebrew not found' $S/setup-user-cursor.sh
chk "SU cursor fanout ~/.aitools/rules" grep -n 'aitools/rules' $S/setup-user-cursor.sh
chk "SU mcp ps1 exit 33-41" sed -n '31,42p' $S/setup-user-mcp.ps1
chk "SU mcp npx -y" grep -n 'chrome-devtools-mcp' $S/setup-user-mcp.sh $S/setup-user-mcp.ps1
chk "SU config ps1 HOME 113" sed -n '112,114p' $S/setup-user-config.ps1
chk "SU config bootstrap 298-330" grep -n 'missing bootstrap' $S/setup-user-config.sh $S/setup-user-config.ps1
chk "SU settings no dotprofile 76-78" grep -n 'no dotprofile' $S/setup-user-settings.sh
chk "SU PS7 guards" grep -ln 'PSVersion.Major -lt 7\|requires PowerShell 7' $S/setup-user-*.ps1 $S/aitools-lib.ps1
chk "SU tracked bak" git -C $R ls-files 'shared/hooks/*.bak.*'
chk "TOOLS winget --scope" grep -rn -- '--scope' $S/setup-*.ps1 $S/aitools-install.ps1 $S/bootstrap.ps1
chk "TOOLS winget no --exact go typst" grep -n 'winget install\|winget upgrade' $S/setup-go.ps1 $S/setup-typst.ps1
chk "TOOLS sudo gh pandoc" grep -n 'sudo ' $S/setup-gh-cli.sh $S/setup-pandoc.sh
chk "TOOLS sudo rm go 104" grep -n 'sudo rm\|sudo port' $S/setup-go.sh $S/setup-pandoc.sh
chk "TOOLS typst linux" grep -n 'uname\|IS_LINUX\|apt' $S/setup-typst.sh
chk "TOOLS uv homebrew-only" grep -n 'Homebrew-only\|Homebrew not found' $S/setup-uv.sh $S/setup-go.sh
chk "TOOLS datadog cargo" grep -n 'cargo install' $S/setup-datadog.sh
chk "TOOLS modal pip" grep -n 'pip install' $S/setup-modal.sh
chk "TOOLS cimcp remove/disable" grep -n 'agent mcp' $S/setup-cursor-ide-mcp.sh $S/setup-cursor-ide-mcp.ps1
chk "TOOLS cimcp node exit 51-53" sed -n '50,56p' $S/setup-cursor-ide-mcp.sh
chk "TOOLS gh wget 48" sed -n '46,53p' $S/setup-gh-cli.sh
chk "TOOLS node linux warn 635" sed -n '633,639p' $S/aitools-install.sh
chk "INTUNE old URLs in repo" grep -rln 'intune/intune-service' $R/reference $R/.claude $R/plans $R/shared
chk "POSTPUSH step7 build-deploy" grep -n 'build-deploy.sh' $S/check-post-push.sh
