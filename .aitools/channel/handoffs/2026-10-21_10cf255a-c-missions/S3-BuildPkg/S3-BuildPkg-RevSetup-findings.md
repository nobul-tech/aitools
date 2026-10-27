# S3-BuildPkg-RevSetup: the setup-user-* scripts under a package run by an MDM agent for a fleet user

Author: S3-BuildPkg-RevSetup (level 2, code reviewer for S3-BuildPkg). Date: 2026-10-26.
Read-only review. No code changed, nothing committed, no setup script run.

## 0. Summary (5 lines)

1. All 8 script pairs write only per-user targets under `$HOME` / `$env:USERPROFILE` (plus `$PROFILE` and `~/.claude.json` through `claude mcp add`). None resolves a console user, none checks who owns `$HOME`, and none writes anything machine-wide.
2. Run as root or SYSTEM, they either configure the wrong account and still report OK (HOME=/var/root, `C:\Windows\system32\config\systemprofile`), or, with HOME pointed at the user, leave root-owned `~/.claude`, `~/.aitools` and `~/.cursor` that later break Claude Code and the dev path. Every setup-user-* script must run as the console user: a user-context Win32 app on Windows, `launchctl asuser` plus `sudo -u -H` on macOS, a per-user step on Ubuntu VMs, and the script as it is in a root container.
3. A fleet user with no dotprofile gets a technically complete but Jose-personal setup: a CLAUDE.md with literal `{{PROFILE_NAME}}` tokens and nobul-jose URLs, all 18 harness hooks (standing-order-guard in enforce mode), Jose's three MCP servers and all harness skills. There is no settings.json sync, and config.json fails on its first run unless the package passes `--repos-path` / `--repo-path`.
4. Recurring non-interactive runs overwrite local edits (F6) in every managed file. Backups are kept, but shell and cli-config.json back up on every run, even when nothing changes, so 20 daily runs rotate away the useful backups. The Cursor model is forced back to Auto on every run.
5. 31 remediations follow (2 critical, 6 high). Open PRs fix 5 of them: #110/#100 (fleet Cursor gets aitools project rules), #109 (two), #112, #103. Four defects confirmed in the code, one of them reproduced by a probe, have no PR: a `$SHELL` unbound crash (the probe), `.bash_profile` shadowing Ubuntu's `.profile`, the missing settings.json backup in hooks, and hooks that execute a cwd repo's `scripts/ait-harvest.py`.

## 1. Method and sources

Read in full: the mission packet, the S3-BuildPkg brief, all user/project rules in context, `reference/user-repo.md` (1-233),
and the 16 files:
`/Users/new-jose/repos/aitools/scripts/setup-user-{claude,config,cursor,hooks,mcp,settings,shell,skills}.{sh,ps1}` (5,494 lines, `wc -l`).
Read in part (to answer behaviour questions): `scripts/aitools-lib.sh` (40-339, 880-959, 1340-1379, 1760-1890; grep for 2437-2649),
`scripts/aitools-lib.ps1` (`Refresh-Path` 2652, `Backup-Dir` 817), `scripts/aitools-profile.sh` (410-473),
`shared/hooks/hooks-manifest.json`, `shared/hooks/session-archive.sh` (40-74), `shared/hooks/session-catchup.sh` (38-57),
`shared/claude-shared.md` (headings, tokens, lines 29-30).
PRs: `gh pr view` + `gh pr diff` for #98, #100, #103, #109, #110, #112, #113, #114, #115, #116 (saved under
`/Users/new-jose/repos/aitools/.scratch/session-rvsetup/pr-*.txt|.diff`). `gh pr list` shows the open PRs touching setup-user-*:
#98, #103, #109, #110, #112, #113, #114, #115, #116 (#100 touches deploy-harness only, it is the base of #110).
Reused with citation: `S3-MdmPkg/S3-MdmPkg-report.md` (L11, L88-90, L105, L184), `S3-FanPlan/S3-FanPlan-Claude-findings.md`
(section 8 items 4-5), `S3-FanPlan/S3-FanPlan-Misc-findings.md` (3.2).
One probe (scratch, touches no files): `.scratch/session-rvsetup/shell-unset-probe.sh`, which reproduces
setup-user-claude.sh:178 with SHELL unset under `set -u`. Result: `line 6: SHELL: unbound variable`, exit 1.

Not verified in this session (marked "unverified" where used): Jamf/Intune environment variables (HOME, SHELL) for root
scripts; Claude Code machine-wide managed settings paths; Ubuntu `/etc/skel` contents; Windows behaviour of any .ps1.

Line numbers are on origin/main as checked out on 2026-10-26 (HEAD 5976553).

## 2. Overview table

Scope: **U** = per-user (needs the console user's HOME, and files owned by that user). **M** = machine-wide. Every target below is U.

| Script | Targets written (paths) | Owner model | Hard deps (exit 1 if missing) | Soft deps (WARN/skip) | Needs dotprofile? | F6 on recurring run |
|---|---|---|---|---|---|---|
| claude | `~/.claude/CLAUDE.md`; `~/.claude/rules/*.md` (from dotprofile only); `CLAUDE.md.bak.*`, `rules.bak.*/`; adopt -> dotprofile `claude/CLAUDE.md`, `claude/rules/*` | CLAUDE.md sole owner; rules additive | bash+perl / pwsh 7 (ps1 L37); aitools-lib + aitools-profile resolver | scutil (macOS footer); git (adopt push) | No: falls back to `shared/claude-shared.md`, tokens unresolved | overwrite, backup 20 |
| config | `~/.aitools/config.json` (+ `.tmp.$$`, `.bak.*`) | merge on managed keys | perl, aitools-profile.sh, aitools-json.pl (sh L128-139); pwsh 7 + aitools-json.ps1 (ps1) | -- | No, but `reposPath`/`repoPath` must be passed on first run (sh L299-330) | managed keys rewritten; others kept |
| cursor | `~/.cursor/cli-config.json`; `~/.cursor/rules/*.mdc`; `~/.local/bin/agent` symlink (sh); Cursor CLI + ripgrep installs (per-user) | cli-config merge; rules additive | -- (every step soft) | brew (sh rg), winget (ps1 rg), curl/irm + network (Cursor installer), node (sh merge only), perl (sh rule conversion), `~/.aitools/rules` (deploy-harness) | No (defaults vimMode=false, model=auto) | model forced to Auto; .mdc overwritten |
| hooks | `~/.claude/hooks/*` (18 hooks + deploy helpers); `~/.claude/settings.json` `hooks` key; adopt -> aitools `shared/hooks/<f>` or `scripts/<f>` | hooks dir: managed per file; settings.json merge on `hooks` | node (sh L45-49); manifest + `shared/hooks` + `scripts/` next to the script (sh L53-62, L124-130) | config.json `userRepoPath` (sh L70) | No | hook files overwritten; settings.json written with no backup |
| mcp | `~/.claude.json` (via `claude mcp add --scope user`) | remove + add per server | claude CLI, node (sh L47-60; ps1 L33-45) | network (npx at Claude Code runtime) | No | server re-added if it differs |
| settings | `~/.claude/settings.json` (all but `hooks`); dotprofile `profile.json` (legacy migration, auto-adopt) | profile mirror (sync_managed_json) | node (sh L51-55) | -- | **Yes**, else WARN no-op (sh L76-81) | per-leaf overwrite from profile |
| shell | `~/.bash_profile` (sh L39-40); `$PROFILE` (ps1 L33) | marked block | perl, mktemp | brew (at login) | No | block replaced; backup every run |
| skills | `~/.claude/skills/<n>/SKILL.md`, `~/.cursor/skills/<n>/SKILL.md`; adopt -> dotprofile `claude/skills/` or aitools `shared/skills/` | managed per file | `shared/skills` next to the script (sh L41-43) | resolver | No | SKILL.md overwritten |

Machine-wide writes: none. Registry writes: none (only `Refresh-Path` reads HKCU and HKLM PATH: aitools-lib.ps1:2652-2662).

## 3. Per-script detail

### 3.1 setup-user-claude (.sh 442 lines, .ps1 474)

1. **Targets.** `CLAUDE_DIR="$HOME/.claude"` (sh:55-56) / `Join-Path $env:USERPROFILE ".claude"` (ps1:47-48). CLAUDE.md goes through `deploy_managed_file` with an adopt target in the dotprofile, `claude_md_adopt_filter` (sh:243-247, ps1:259-262). Rules come only from `<dotprofile>/claude/rules` (sh:290-293, ps1:308-314), with `backup_dir` before writing (sh:335, ps1:363). The private merge-adopt commit+push block (sh:370-389, ps1:400-422) is removed by #103 (it moves into the library). All targets are U.
2. **Dependencies.** The lib resolver (`resolve_user_repo_path`, `resolve_machine_profile`: sh:71-90) runs `aitools-profile.sh` next to the lib (aitools-lib.sh:172, 202-207). Interpolation and the adopt filter use perl (sh:155-159, 190-212). The footer hostname comes from `/usr/sbin/scutil` (sh:99-103); #112 replaces it with `AITLIB_MACHINE_HOSTNAME`. The footer shell comes from `$SHELL` (sh:178). The ps1 needs pwsh 7 (ps1:37-41) and `Get-CimInstance` (ps1:165). config.json keys are read through the resolver: `userRepoPath`, `reposPath`, `githubUser` (aitools-profile.sh:441-457), and the machine keys. The template sits at `$SCRIPT_DIR/../shared/claude-shared.md` (sh:46-48), so the package must keep the `scripts/` + `shared/` layout. No node is needed. Network is needed only for an adopt push.
3. **Root/SYSTEM, no TTY, container.** As root on macOS (HOME=/var/root, unverified for Jamf) it deploys to root's home. With HOME overridden to the user's home, `mkdir -p "$CLAUDE_DIR"` (sh:59) creates a root-owned `~/.claude`, and Claude Code then cannot write `~/.claude/projects` etc. On Windows as SYSTEM, `$env:USERPROFILE` is the systemprofile. With no TTY, `deploy_managed_file` takes SOURCE (aitools-lib.sh:1868, 1633-1653). **Container (root, HOME=/root): it crashes if `SHELL` is unset**. sh:178 expands `$(basename "$SHELL")` under `set -u` (sh:16), and the probe reproduces "SHELL: unbound variable", exit 1. It exits before any claude.md row, so no summary row is written. Whether Claude Code web, `docker exec` and Jamf set SHELL is unknown.
4. **Personalisation.** Dotprofile `claude/CLAUDE.md` and rules come first, then `shared/claude-shared.md` (sh:117-133). With no dotprofile, `PROFILE_RC=1`: the tokens stay literal (sh:155-159 leave a token whose value is empty), and the run writes `WARN|claude.md|template tokens unresolved` (sh:167-168), on every run, on every fleet machine. The shared template still contains Jose-specific text, for example `nobul-jose/aitools` issue links (claude-shared.md:29-30). No rules are deployed (sh:426). It works end to end: validation needs `## Machine-Specific` and `## Coaching|## Code Style|## Tool` (sh:256-263), and the shared template has `## Code Style Defaults`. The `~/.aitools/rules` fan-out into `~/.claude/rules` is being planned by S3-FanPlan (`S3-FanPlan-Claude-findings.md`), so this script is not edited here.
5. **Recurring runs.** Non-interactive means overwrite, with a `CLAUDE.md.bak.<ts>` (20 kept, aitools-lib.sh:890-916). The footer depends on the run context: the hostname, and `$SHELL` (sh:177-178). If an MDM run and a dev run see a different `$SHELL`, each one rewrites CLAUDE.md (ping-pong `updated`). How sudo/Jamf set SHELL is unknown. Idempotent otherwise: `verified` when the content is equal (aitools-lib.sh:1863-1866).

### 3.2 setup-user-config (.sh 393, .ps1 390)

1. **Targets.** `CONFIG_FILE="$HOME/.aitools/config.json"` (sh:111-112), `Join-Path $HOME ".aitools"` (ps1:113). The ps1 uses `$HOME` while every other ps1 uses `$env:USERPROFILE`, so a wrapper that overrides USERPROFILE to target a user splits config.json from the rest. Write path: temp file, validate, `backup_file`, `mv` (sh:290-345). Scope U.
2. **Dependencies.** perl, `aitools-profile.sh` and `aitools-json.pl` next to the script (sh:113-139). The ps1 needs `aitools-profile.ps1` and `aitools-json.ps1` (ps1:119-128) and has no PS 7 guard of its own. No node (header L16). Bootstrap keys `version`, `reposPath` and `repoPath` must be present after the merge, or it writes `ERROR|aitools config|missing bootstrap values`, exit 1 (sh:298-330). They come only from `--repos-path` / `--repo-path` or an existing config.json (sh:263-264).
3. **Root, no TTY, container.** Root writes root's `~/.aitools`, or a root-owned `~/.aitools` when HOME is overridden. That breaks every later user run, because `logging_init` writes `~/.aitools/logs` (aitools-lib.sh:72). It never prompts (header L34). In a container it works if the flags are passed.
4. **Personalisation.** Derived keys come from the dotprofile `profile.json`. With none, the derivation returns rc 1, it logs "writing bootstrap keys only", and the run is OK (sh:215). A fleet package must decide what `repoPath` means: the payload directory, or nothing. Consumers include hh, check-lib and ait-harvest (meta.intent audience, sh:227).
5. **Recurring runs.** Idempotent: `verified` with no write when unchanged (sh:311-333). Unmanaged keys are kept in order. A backup is taken only when the file is written.

### 3.3 setup-user-cursor (.sh 668, .ps1 654)

1. **Targets.** `~/.cursor/cli-config.json` (sh:58-59, ps1:48-49). `~/.cursor/rules/<name>.mdc` (sh:389-390, 568; ps1:383-384, 560). The `~/.local/bin/agent -> cursor-agent` symlink (sh:159-163). Installs: ripgrep via `brew install` (sh:85-88) or `winget install BurntSushi.ripgrep.MSVC` (ps1:81); the Cursor CLI via `curl https://cursor.com/install | bash` (sh:135) or `irm ... | iex` (ps1:129). All per-user: the Cursor installer and the symlink use the running user's home.
2. **Dependencies.** brew is the only ripgrep path on macOS **and Linux**. On Ubuntu without brew it is `WARN ripgrep missing (Homebrew not found)` (sh:105-108). There is no apt branch, against D-ENV0 "library helpers chosen by capability" (cross-platform.md). The installers need network. node is needed for the .sh cli-config merge only (sh:185); the .ps1 merge is pure PowerShell. perl is needed for the rule conversion (sh:404-471). The fan-out reads `~/.aitools/rules`, written by deploy-harness: when that is absent the row is `OK n/a` (sh:476-478). Dotprofile `profile.json` `cursor.cli` comes through the resolver (sh:198-233).
3. **Root, no TTY, container.** As root, Cursor CLI and ripgrep install for root, and brew refuses to run as root (MdmPkg report L89, not re-verified). With HOME overridden, `~/.cursor` and `~/.local/bin/agent` end up root-owned. As SYSTEM, winget is not normally on SYSTEM's PATH (unknown here; see MdmPkg Intune notes), `irm|iex` installs into the systemprofile, and `Refresh-Path` reads SYSTEM's HKCU PATH (aitools-lib.ps1:2652-2654), so the user's PATH is never seen. A missing TTY is fine: no prompts outside `deploy_managed_file`. In a container: brew missing gives WARN; the Cursor installer may be blocked by the network policy (unknown); a missing node gives `log_warn` **with no summary row** (sh:185-187, already noted as a follow-up in #109, not fixed).
4. **Personalisation.** Defaults are `vimMode=false` and `modelId='auto'` (sh:213-214). **The fleet gets aitools' project rules.** Until #110 lands, step 4 fans out every `~/.aitools/rules/*.md` (sh:486-510), which includes the aitools repo's own `.claude/rules` (26 rules in the #110 integration run, PR #110 body). They load as always-apply rules in every Cursor workspace under `$HOME`. #110 (on #100) restricts the fan-out to the `shared` and `dotprofile` sources.
5. **Recurring runs.** `backup_file "$CLI_CONFIG"` runs on every run, before the comparison (sh:179-181, ps1:209-211), so the 20-backup rotation is consumed by no-op runs. `config.model` is reset to Auto and `hasChangedDefaultModel=true` on every run when the profile says auto (sh:263-274, ps1:255-265), which reverts a user's model choice: F6 on a JSON field. A corrupt cli-config or a clobber gives ERROR unless `--force` (sh:291-296). The .mdc files are overwritten non-interactively. `mkdir -p "$CURSOR_DIR"` runs even in a dry run (sh:183). `backup_dir "$CURSOR_RULES_DIR"` (sh:517) is a no-op, because `backup_dir` counts only `*.md` (aitools-lib.sh:925-928) and the directory holds `.mdc`. Per-file backups still come from `deploy_managed_file`.

### 3.4 setup-user-hooks (.sh 481, .ps1 444)

1. **Targets.** `~/.claude/hooks/<file>` for every manifest hook and deploy helper (sh:158-183, ps1:123-144). Stale hooks and their backups are deleted (sh:191-205). In `~/.claude/settings.json` the `hooks` key is merged (sh:255-423, ps1:222-430). Each hook command embeds the absolute home path: `'bash "' + path.join(home, '.claude', 'hooks', r.file) + '"'` with `home = process.env.HOME || process.env.USERPROFILE` (sh:269-277, ps1:333-334). The adopt target for each hook is the **aitools source file** `shared/hooks/<f>` or `scripts/<f>` (sh:166, ps1:132).
2. **Dependencies.** node is hard (sh:45-49). **The .ps1 does not use node** for the merge, so the platforms differ. The manifest and sources come from `$SCRIPT_DIR/..` (sh:53-57, 79-88): the package must ship `shared/hooks`, the deploy helpers from `scripts/`, and the manifest. config.json `userRepoPath` is read directly with `read_config_key` (sh:70, ps1:58), not through the one resolver used by the other scripts (SD-7). At runtime the hooks need bash (Git Bash on Windows), python3 (session-archive.sh:47-58, session-catchup.sh:38-41, which exit 0 with a log line when it is missing) and git.
3. **Root, no TTY, container.** As root with HOME=/var/root, settings.json points at root's hooks. With HOME overridden, the paths are correct but the files are root-owned, so a later user-run interactive adopt or merge fails. As SYSTEM, the systemprofile. With no TTY, the reverse-discovery adopt prompt is skipped (sh:224, 243-245) and hook files are overwritten. A container works, given node.
4. **Personalisation.** None: every user gets all 18 hooks (hooks-manifest.json:9-26). That includes Jose's harness governance: `standing-order-guard.sh` (enforce mode, hook-rollout.md table), `block-explore-agent.sh`, `block-claude-code-guide.sh`, the failure-mode Stop hooks, `dashboard-serve.sh` and `harness-db-*`. A dotprofile copy of a manifest hook is ignored (sh:131-136, SD-2).
5. **Recurring runs.** Hook files are overwritten non-interactively (per-file backups from the library). **settings.json is written with no `backup_file`** (sh:383, ps1:376; grep shows no backup call in either script), against config-file-safety.md "JSON config files: caller MUST call backup_file". A user's own hook entry whose command contains a managed file name as a substring is rewritten (`h.command.includes(hookId)`, sh:306-316). Idempotent: `unchanged` compares sorted keys (sh:378-382).
6. **Security (deployed content, not these 16 files).** `session-archive.sh:61-64` and `session-catchup.sh:43-46` run `$PROJECT_ROOT/scripts/ait-harvest.py` from **the git repo the session runs in** before the deployed copy. For a fleet user, any cloned repo that contains `scripts/ait-harvest.py` runs its code on every SessionStart and SessionEnd, outside Claude Code's project-trust prompt.

### 3.5 setup-user-mcp (.sh 263, .ps1 237)

1. **Target.** User-scope MCP registration through `claude mcp add --scope user` (sh:133, ps1:105). That is `~/.claude.json` of the account whose home `claude` resolves (inferred; the script does not name the file). Scope U.
2. **Dependencies.** The claude CLI and node are hard (sh:47-60). The .ps1 exits 1 on both **with no summary row** (ps1:33-36, 39-41) where the .sh writes ERROR rows (sh:49, 56): a parity and summary-coverage deviation. At runtime: `npx chrome-devtools-mcp@latest` (unpinned, npm network), `https://mcp.vercel.com` and `https://mcp.webflow.com/mcp`.
3. **Root, no TTY, container.** Under root or SYSTEM, `claude` is usually not on PATH, because the native install is per-user (inferred), so the script exits 1. The Claude Code web branch is headless with no sandbox (sh:63-66, D-CHR2). **Cursor cloud** gets `AITOOLS_ENVIRONMENT=local`, so chrome-devtools runs non-headless with no display. The environment list is closed (brief "Operational learning"), so a value needs a decision.
4. **Personalisation.** None. The three servers are hardcoded (sh:150-199), so the fleet gets Jose's vercel and webflow.
5. **Recurring runs.** A server whose `claude mcp list` text differs from the expected string is removed and added again on every run (sh:157-165). If the add then fails, the server stays removed (sh:128-139). The .ps1 expected string `cmd /c npx chrome-devtools-mcp@latest --isolated` (ps1:130) is compared with an add that passes `... chrome-devtools-mcp@latest -- --isolated` (ps1:128). Whether `claude mcp list` prints the `--` is unknown. If it does, chrome-devtools is re-added on every Windows run. The rule table says `npx -y` for both (managed-file-deployment.md table); both scripts omit `-y` in the local branch (sh:68, ps1:128).

### 3.6 setup-user-settings (.sh 160, .ps1 148)

1. **Targets.** `~/.claude/settings.json`, everything except `hooks` (sh:57, 135; ps1:47, 122). Writes to the dotprofile: `profile.json` legacy migration (sh:104-130) and auto-adopt of live-only leaves (rule interactive-menus.md "Profile mirror"; `sync_managed_json` backs up both files, aitools-lib.sh:2648-2649). Scope U.
2. **Dependencies.** node is hard (sh:51-55, ps1:41-45), also for the ps1 (`node -e`, ps1:78, 105). The dotprofile is required.
3. **Root, no TTY, container.** As root it writes root's settings, or root-owned user files. Non-interactive means per-leaf overwrite, while live-only leaves auto-adopt into the dotprofile `profile.json`, writing the dotprofile from an MDM run, possibly as root. A container works, given node and a dotprofile.
4. **Personalisation.** **No dotprofile means no sync**: `WARN|claude settings|not synced: no dotprofile` (sh:76-78) on every run on every fleet machine, and no permissions or deny rules are deployed. A fleet policy needs another source (section 5, R9).
5. **Recurring runs.** Per-leaf overwrite from `profile.json`; backups through the lib.

### 3.7 setup-user-shell (.sh 145, .ps1 111)

1. **Targets.** `PROFILE="${AITOOLS_PROFILE_DIR:-$HOME}/.bash_profile"` (sh:39-40). `$PROFILE` or `AITOOLS_PROFILE_PATH` (ps1:33): CurrentUserCurrentHost of the PowerShell host that runs it. Block markers at sh:42-43. Not through `deploy_managed_file`: no review menu. Scope U.
2. **Dependencies.** perl and mktemp (sh:48, 82-102). The ps1 has no PS 7 guard, and the lib has none either (aitools-lib.ps1 has only `Resolve-AitoolsPlatform` at L56). Run by Windows PowerShell 5.1 (`powershell.exe`, the usual Intune host, unverified), it writes the WindowsPowerShell profile, which pwsh never loads.
3. **Root, no TTY, container.** As root it writes `/var/root/.bash_profile` (macOS) or `/root/.bash_profile`. **On Ubuntu**, creating `~/.bash_profile` when only `~/.profile` exists makes bash login shells stop reading `~/.profile` (bash(1) INVOCATION: the first of `.bash_profile`, `.bash_login`, `.profile` that exists; Ubuntu's skel `.profile` adding `~/.local/bin` and sourcing `.bashrc` is from knowledge, not verified this session). The block does not source `~/.profile`, so the user loses `.bashrc` in login shells. This also applies to `/root` in containers. On macOS, login shells default to zsh, which reads `~/.zprofile`, not `~/.bash_profile`, so the block never reaches zsh users. Jose's own shell is zsh (CLAUDE.md "Machine-Specific").
4. **Personalisation.** None (the block is identical for everyone, sh:52-65).
5. **Recurring runs.** **The file is rewritten and backed up on every run**: `backup_file` comes before the comparison (sh:68), and perl always writes (sh:100-101). The row is always `refreshed`, never `verified` (sh:117-119). Edits inside the block are lost (by design). **No dry-run support** in either language: no `--dry-run` / `AITOOLS_DRY_RUN` handling, so it writes during `aitools --dry-run` (grep: no DRY_RUN in setup-user-shell.*). The write is not atomic (perl `open >`, sh:100).

### 3.8 setup-user-skills (.sh 250, .ps1 234)

1. **Targets.** `~/.claude/skills/<n>/SKILL.md` and `~/.cursor/skills/<n>/SKILL.md` (sh:67-69, 103-153). Only `SKILL.md` is deployed (sh:124), so any other file in a skill directory never reaches the user (today only `tests/expected-behaviors.md` files exist: `find shared/skills`). The adopt target is the file read: the dotprofile copy, or `shared/skills/<n>/SKILL.md` **in the aitools tree** (sh:122-124). Scope U.
2. **Dependencies.** `shared/skills` next to the script (sh:41-43), and the resolver. No node.
3. **Root, no TTY, container.** As for hooks. The reverse-discovery prompt is skipped with no TTY (sh:207, 226-227).
4. **Personalisation.** Dotprofile skills win over shared ones (sh:108-113). A fleet user gets every harness skill (delegate, handoff, mission-control, ...).
5. **Recurring runs.** Overwrite. The .ps1 rows on a resolver error (`skills`, `skipped`) differ from the .sh (A-22); #109 fixes it.

## 4. Cross-cutting findings

### 4.1 Run context (the core packaging problem)

- No script resolves the console user or checks the owner of `$HOME`. `grep -rln -E "chown|SUDO_USER|/dev/console|ConsoleUser|logname" scripts/` returns nothing (also MdmPkg report L88).
- Every bash script keys on `$HOME` (lib log dir aitools-lib.sh:72). On Windows, every ps1 except config (`$HOME`) and shell (`$PROFILE`) keys on `$env:USERPROFILE`.
- A safe model:
  - **macOS** (Jamf, Intune unmanaged PKG): machine-wide payload plus prerequisites as root in the postinstall. Then run the setup-user-* list as the console user with `launchctl asuser <uid> sudo -u <user> -H` (MdmPkg L105). If no user is logged in, defer: a LaunchAgent at next login, or an Intune/Jamf user-context policy.
  - **Windows**: a SYSTEM Win32 app for the prerequisites, and a dependent User-context Win32 app that runs the setup-user-* list with `pwsh.exe -NoProfile -ExecutionPolicy Bypass -File` (MdmPkg L12).
  - **Ubuntu VM** (deb or tarball, postinst as root): there is no single user. Use a per-user step: a `/etc/profile.d` or XDG-autostart first-login hook, or a user-invoked `aitools-user-setup`.
  - **Containers** (Claude Code web; root, HOME=/root): run directly. Root is the user.
- **A guard in the lib** (`logging_init` or a new `require_user_context`) protects every script: if `EUID=0` and `$HOME` is not owned by uid 0 (bash `[ -O "$HOME" ]`), log_error and exit 1 before any write. The ps1 twin: refuse when the identity is SYSTEM (`S-1-5-18`).

### 4.2 Fleet personalisation without a dotprofile

| Script | What a fleet user gets today | Works end to end? |
|---|---|---|
| claude | shared template with literal `{{...}}` tokens and Jose-specific text; WARN every run; no rules | yes (WARN) |
| config | ERROR "missing bootstrap values" unless the package passes `--repos-path` / `--repo-path` | **no** without flags |
| cursor | defaults; all `~/.aitools/rules` incl. aitools project rules (until #110) | yes |
| hooks | all 18 Jose harness hooks | yes, if node |
| mcp | chrome-devtools, vercel, webflow | yes, if claude + node |
| settings | nothing; WARN every run | no-op |
| shell | the same PATH block | yes (Ubuntu side effect) |
| skills | every shared skill | yes |

The resolver has an `AITOOLS_USER_REPO_PATH` env override (aitools-profile.sh:429-433). A package could point it at a package-shipped **org profile**, a read-only "dotprofile" holding `profile.json`, `claude/CLAUDE.md` and `claude/rules`. But adopt and merge then target that directory, and N-Q2 commits and pushes dotprofile adopts (#103). The package would need adopt disabled, plus a distinction between an "org profile" (read-only) and the user's dotprofile. That needs a decision (Q2).

### 4.3 Recurring runs (Q5 / F6)

Every `deploy_managed_file` target is overwritten non-interactively, with a backup (aitools-lib.sh:1633-1653, 1868). MdmPkg suggests yes for managed files, with backups (MdmPkg L184). Additional facts for that decision:

- Backups churn on no-op runs in shell (sh:68) and cursor cli-config (sh:180). At 20 kept, a daily MDM run keeps only 20 days, even when nothing changed.
- Files that are partly the user's own are touched every run: `.bash_profile` (block only), cli-config.json `model` (always reset), and settings.json `hooks` (substring match).
- `--force` must not be passed by the package. In cursor and hooks it also clobbers corrupt or lost-key JSON (cursor.sh:291-302, hooks.sh:364-372).

## 5. Remediations

Severity follows incident-governance.md. "PR" = an open PR that already fixes it.

| # | Where (file:function/line) | Severity | Fix direction | PR |
|---|---|---|---|---|
| R1 | all 16 scripts; lib `logging_init` | critical | Package runs setup-user-* as the console user (4.1); add a lib guard that refuses root/SYSTEM writing a home it does not own | none |
| R2 | setup-user-claude.sh:178 (footer `$(basename "$SHELL")`) | high | `${SHELL:-}` with a fallback (`unknown`); probe-confirmed crash, no summary row | none (#112 touches only the hostname) |
| R3 | setup-user-config.sh:298-330 / .ps1:300-328 (bootstrap check) | high | Package passes `--repos-path` / `--repo-path` (decide the `repoPath` meaning for a package) or the writer gains a package default | none |
| R4 | setup-user-shell.sh:39-40, 80-102 | high | On Linux, write the block into `~/.profile`, or create `~/.bash_profile` that sources `~/.profile` first; on macOS also `~/.zprofile`; or machine-wide `/etc/paths.d` / `/etc/profile.d` from the package | none |
| R5 | session-archive.sh:61-64, session-catchup.sh:43-46 (deployed by setup-user-hooks) | critical (security, fleet) | Run only the deployed `~/.claude/hooks/ait-harvest.py` (or the configured aitools repoPath), never the cwd repo's copy | none |
| R6 | hooks-manifest.json; setup-user-mcp.sh:150-199; shared/claude-shared.md; shared/skills | high | A fleet tier: manifest/skill/MCP entries tagged `fleet` vs `harness`, a neutral org template; commander decision (Q1) | none |
| R7 | setup-user-cursor.sh:486-582 / .ps1:476-577 (step 4 fan-out) | high | Fan out user-level rules only | **#110** (needs #100) |
| R8 | setup-user-hooks.sh:166 / .ps1:132; setup-user-skills.sh:124 / .ps1:118 (adopt targets in the payload) | medium | When running from a package (a distribution marker, e.g. `AITOOLS_DISTRIBUTION=package`), pass `""` as adopt target | none |
| R9 | setup-user-settings.sh:76-78 / .ps1:62-64 | high | Fleet policy source: Claude Code machine-wide managed settings (verify paths with chrome-devtools before use) or a read-only org profile; no WARN every run on fleet machines | none |
| R10 | setup-user-hooks.sh:383 / .ps1:376 (settings.json write) | medium | `backup_file "$SETTINGS_FILE"` / `Backup-File` before the write (config-file-safety.md) | none |
| R11 | setup-user-cursor.sh:185-187 | medium | `write_summary WARN "cursor cli" "node not found"` (summary coverage) | none (noted in #109 follow-ups) |
| R12 | setup-user-cursor.sh:85-109 | medium | ripgrep on Ubuntu via a lib capability helper (`install_via_apt`, D-ENV0), or as a package prerequisite | none |
| R13 | setup-user-mcp.ps1:33-36, 39-41 | medium | `Write-Summary ERROR "claude mcp" ...` before exit (parity with .sh:49, 56) | none |
| R14 | setup-user-mcp.sh:119-145 / .ps1:88-118 | medium | Add before remove, or restore on a failed add; pin chrome-devtools-mcp to a version for a fleet | none |
| R15 | setup-user-mcp.sh:63-69; lib environment block (aitools-lib.sh:41-52) | medium | New environment value for Cursor cloud (e.g. `cursor-cloud`), decision required (brief) | none |
| R16 | setup-user-shell.sh:68, 82-102 / .ps1:57, 69-83; setup-user-cursor.sh:179-181 / .ps1:209-211 | medium | Compare first, back up and write only on change; report `verified` | none |
| R17 | setup-user-cursor.sh:263-274 / .ps1:255-265 | medium | Manage `model` only when the profile sets it, or set it only when absent (Q3) | none |
| R18 | setup-user-shell.sh / .ps1 (whole file) | low | Honour `--dry-run` / `-DryRun` / `AITOOLS_DRY_RUN` like the other scripts | none |
| R19 | setup-user-cursor.sh:183 | low | Guard `mkdir -p` with the dry-run check (as ps1:214-219) | none |
| R20 | setup-user-config.ps1:113 | low | Use `$env:USERPROFILE` like the other ps1 (or all use one lib variable) | none |
| R21 | setup-user-hooks.sh:70 / .ps1:58 | low | Use `resolve_user_repo_path` / `Resolve-UserRepoPath` (SD-7 single resolver) | none |
| R22 | setup-user-{config,cursor,hooks,mcp,settings,shell,skills}.ps1 | low | PS 7 guard in the lib (only setup-user-claude.ps1:37-41 has one); the package invokes `pwsh.exe`, never `powershell.exe` | none |
| R23 | setup-user-cursor.sh:517 via aitools-lib.sh:925-928 (`backup_dir` counts `*.md`) | low | Count every regular file (or take a pattern), so `.mdc` directories are backed up | none |
| R24 | `shared/hooks/standing-order-guard.sh.bak.2026-06-21T203334Z`, `shared/hooks/harness-db-sessionstart.sh.bak.2026-06-21T203304Z` (tracked, `git ls-files`) | low | `git rm`, `.gitignore` `*.bak.*`, and exclude `*.bak.*` from the package payload | none |
| R25 | setup-user-skills.ps1:48-52 (A-22 rows) | low | `.sh` rows on a resolver error | **#109** |
| R26 | setup-user-cursor.sh/.ps1 resolver-error row (A-23), cli-config dry-run rows (A-26) | low | as #109 | **#109** |
| R27 | setup-user-claude.sh:370-389 / .ps1:400-422 (private commit+push; ps1 commits without pathspec) | medium | library helper `dotprofile_commit_push` | **#103** |
| R28 | setup-user-claude.sh:98-109, 216-238 / .ps1:171-175, 230-254 (hostname source, dry-run rows) | low | `AITLIB_MACHINE_HOSTNAME`; dry-run rows | **#112** |
| R29 | setup-user-claude.sh:360-366 / .ps1:392-396 (no `*)` branch); .ps1:320/326/354/427 (`Get-ChildItem -ErrorAction Stop` with no try) | low | as S3-FanPlan-Claude-findings section 8 items 4-5 | none (FanPlan owns the file) |
| R30 | setup-user-skills.sh:124 / .ps1:110-118 (SKILL.md only) | low | Deploy the whole skill directory when skills gain supporting files | none |
| R31 | setup-user-hooks.sh:269-277 (home path baked into settings.json) | low | Covered by R1; optionally write `$HOME`-relative commands if Claude Code expands them (unknown) | none |

PRs #98, #113, #114, #115 and #116 change setup-user-config/-claude for the user-init and relay contracts (the `--no-machine` flag, A-10/A-11, relay rows). From their bodies, none changes run context, targets or the fleet fallback, so none fixes or conflicts with R1-R31 (`pr-98.txt`, `pr-114.txt`; #113/#115/#116 are stacked on #98/#103, per their FILES lists).

## 6. INCIDENT markers (not filed)

- INCIDENT: setup-user-claude.sh:178 expands `$SHELL` under `set -u`. With SHELL unset (containers, some agents) the script exits 1 with no claude.md summary row (probe output above). Spec: script-standards.md "Every code path ... must call write_summary". High.
- INCIDENT: session-archive.sh:61-64 and session-catchup.sh:43-46 run the current git repo's `scripts/ait-harvest.py` on SessionEnd/SessionStart. Any repo can execute code through user-level hooks. Critical for a fleet, medium for Jose's machines. No spec covers which code a hook may run.
- INCIDENT: setup-user-hooks.sh:383 / .ps1:376 write `~/.claude/settings.json` without `backup_file` / `Backup-File`. Spec: config-file-safety.md "Backup before overwrite" (JSON: the caller MUST call backup_file). Medium.
- INCIDENT: setup-user-shell.sh creates `~/.bash_profile` on Linux, where it shadows `~/.profile` for login shells. The block does not source `~/.profile`. Spec: cross-platform.md "first-class" platforms; bash(1) INVOCATION. High on Ubuntu.
- INCIDENT: setup-user-shell.sh/.ps1 have no dry-run handling, so they write during `aitools --dry-run`. Every other setup-user-* script honours `AITOOLS_DRY_RUN`. Low.
- INCIDENT: setup-user-shell.sh:68 and setup-user-cursor.sh:180 back up on every run, even when nothing changes, so the 20-backup rotation (config-file-safety.md "Retention") holds only no-op copies after 20 runs. Medium for recurring MDM runs.
- INCIDENT: setup-user-cursor.sh:185-187: node missing gives a log_warn with no summary row (summary coverage; also #109 follow-up). Medium.
- INCIDENT: setup-user-mcp.ps1:33-36, 39-41 exit 1 with no summary row, while the .sh writes ERROR rows. Parity (cross-platform.md) and summary coverage. Medium.
- INCIDENT: setup-user-cursor.sh:85-109 installs ripgrep only through Homebrew on Linux. Spec: cross-platform.md D-ENV0 (divergence in library helpers chosen by capability). Medium.
- INCIDENT: `backup_dir` (aitools-lib.sh:925-928) backs up only directories that contain `*.md`, so `~/.cursor/rules` (`.mdc`) is never directory-backed-up (setup-user-cursor.sh:517). Spec: config-file-safety.md "Directory deployment" step 2. Low.
- INCIDENT: two `.bak.*` files are tracked in `shared/hooks/` (`git ls-files` output above), so backups of adopt writes into the aitools tree reach git and any package payload. Low.
- INCIDENT: setup-user-hooks.sh:70 / .ps1:58 read config.json `userRepoPath` directly instead of the resolver, against SD-7 (one dotprofile resolver, used by claude, cursor, settings and skills). Low.
- INCIDENT: setup-user-config.ps1:113 uses `$HOME` while the other seven ps1 use `$env:USERPROFILE`. Low.
- INCIDENT: there is no spec for which run context (user, root or SYSTEM) each setup-user-* script needs, and no guard. This is a governance ambiguity, already raised by MdmPkg (report L195); restated with per-script evidence in section 3.
- INCIDENT: the managed-file-deployment.md table gives `npx -y chrome-devtools-mcp@latest --isolated` for local, but setup-user-mcp.sh:68 and .ps1:128 omit `-y`. Spec drift, low.

## 7. Open questions (with suggested answers)

1. **Q1: which hooks, skills, MCP servers and CLAUDE.md text are fleet content?** *Suggested:* add a `tier` field (`fleet` | `harness`) to hooks-manifest.json and to the skill and MCP lists. The package deploys `fleet` only. Ship a neutral `shared/claude-fleet.md` template with no Jose-specific links. The standing-order-guard and failure-mode hooks stay `harness`.
2. **Q2: where does fleet policy (permissions, deny, model) come from without a dotprofile?** *Suggested:* use the Claude Code machine-wide managed settings file, written by the package as root. Verify the paths in official docs with chrome-devtools first (not verified here). setup-user-settings stays a per-user dotprofile sync and writes OK `n/a (no dotprofile)` instead of WARN when the distribution is a package.
3. **Q3 (Q5 detail): should recurring runs reset user-owned JSON fields (the Cursor model)?** *Suggested:* no. Manage a field only when the profile sets it explicitly. Keep overwriting whole managed files (CLAUDE.md, rules, hooks, skills) with backups, as MdmPkg suggests.
4. **Q4: what is `repoPath` in a package install?** *Suggested:* the read-only payload directory (e.g. `/opt/aitools`, `C:\Program Files\aitools`). `reposPath` defaults to `~/repos`. Adopt targets are disabled for that path (R8).
5. **Q5: PATH management in a package.** *Suggested:* machine-wide (`/etc/paths.d/aitools` on macOS, `/etc/profile.d/aitools.sh` on Ubuntu) from the package. setup-user-shell is kept for the dev path and fixed per R4.
6. **Q6: one Ubuntu package for 22.04 and 24.04?** These scripts give no reason to split. They depend only on bash, perl, node and python3, with no release-specific paths. *Suggested:* one package (prerequisite versions are RevTools/PkgLinux territory).

## 8. WRITE_BLOCKED

None.

## 9. Delegates used

None. I read all 16 files myself, so no level-3 delegates were launched.
