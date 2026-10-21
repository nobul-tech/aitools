# S5-Profile implementation plan: one resolver, one config writer, runtime-resolved deploy/

**Intent**: **Purpose**: Give the executing agents verbatim, batched edits (3 files or
fewer per batch) that make profile.json the source of truth, config.json a derived file
with one writer, and machine and dotprofile resolution deterministic and logged.
**Scope**: Code batches B1-B8 with old/new text, the error-handling audit for each batch,
and the test plan. NOT the protected-document drafts (in `S5-Profile-drafts/reference/`,
`S5-Profile-drafts/shared/`, and the report). NOT hook lifecycle (M6). NOT the
build-deploy hook preflight or embed loops (S3-Nine). **Audience**: Session Commander
360aa8f3-8 and the per-batch sub-agents it launches (plan-execution.md pattern).

Base: working tree of branch `fix/issue-9-manifest-driven-preflight` (origin/main 51a34d8
plus the S3-Nine build-deploy hunks at lines 66-107 and the hooks header comments).
Every `old` block below was copied from that tree. **Land after S3-Nine merges**, then
re-check each `old` block exists exactly once (it is the edit's precondition).

Sub-agent rule block: inject `reference/plan-execution-detail.md` "Sub-agent prompt
template" verbatim into every batch prompt (lib and build-deploy batches require it).

---

## B0 -- immediate remediation for this Mac (commander, today, no code)

RCA option (d). The agent cannot do this (config.json is outside its write access).

```bash
cp ~/.aitools/config.json ~/.aitools/config.json.bak.20261020T000000Z
node -e 'const fs=require("fs"),f=process.argv[1];const c=JSON.parse(fs.readFileSync(f,"utf8"));c.machineAlias="new-mac";fs.writeFileSync(f,JSON.stringify(c,null,2)+"\n")' ~/.aitools/config.json
aitools
```

Expect in `~/.aitools/logs/deploy.log`: `Profile interpolation: name=Jose company=nobul-tech`.
Known limit until B5: the dotprofile `deploy/setup-user-claude.*` then bakes `nobul-tech`,
which is wrong for `laptop` (Nobul) -- the deploy/ cross-machine defect is fixed in B5.
Optional and not needed after B2: `sudo scutil --set HostName nobul-mac` (system setting,
commander's call). The new resolver also reads `LocalHostName`, which is `nobul-mac` here
(tested: resolves `new-mac` via=hostname with today's config, no alias).

---

## Approval gate before B1 (protected content)

Present together, approve once (intent-writing "Consolidated presentation"):
the intent headers of `aitools-profile.js`, `setup-user-config.sh/.ps1`, the two lib
blocks, the `meta.intent` of config.json and profile.json, and the protected doc drafts
(report section "Draft file list"). Sub-agents receive approved text verbatim.

---

## B1 -- the resolver (2 files)

1. **Create** `scripts/aitools-profile.js` = `S5-Profile-drafts/scripts/aitools-profile.js`
   (verbatim). `git update-index --chmod=+x scripts/aitools-profile.js` if created on Windows.
2. **Edit** `scripts/profile-check.js` -- machine matching moves to the resolver (fixes
   NO_MACHINE_MATCH firing when a valid alias is set; RCA finding).

old:
```js
// --- v2 validation ---
const issues = [];
const machineAlias = config.machineAlias || '';
const hostname = os.hostname().split('.')[0];
```
new:
```js
// --- v2 validation ---
const { resolveMachine } = require('./aitools-profile.js');
const issues = [];
const machineAlias = config.machineAlias || '';
```

old:
```js
    // Check for hostname match
    let matchedAlias = '';
    for (const [alias, prof] of Object.entries(profile.profiles)) {
        if (prof.machine && prof.machine.hostname && prof.machine.hostname.split('.')[0] === hostname) {
            matchedAlias = alias;
            break;
        }
    }
    if (!matchedAlias) {
        issues.push({ code: 'NO_MACHINE_MATCH', message: 'No profile matches this machine (hostname: ' + hostname + ')', fix: 'prompt' });
    }
```
new:
```js
    // One resolver decides (alias, machine.id, environment, hostname); no first-profile fallback
    const resolved = resolveMachine(profile, { configAlias: machineAlias });
    if (!resolved.alias) {
        issues.push({ code: 'NO_MACHINE_MATCH', message: resolved.errors.join('; ') || 'No profile matches this machine', fix: 'prompt' });
    } else if (resolved.via === 'hostname') {
        issues.push({ code: 'MACHINE_NOT_REGISTERED', message: 'Profile "' + resolved.alias + '" matched by hostname only -- run aitools user init to register this machine', fix: 'prompt' });
    }
    for (const w of resolved.warnings) {
        if (!/matched by hostname only/.test(w)) issues.push({ code: 'PROFILE_WARNING', message: w, fix: 'prompt' });
    }
```

old:
```js
// Build result
const matchedAlias = (() => {
    if (!profile.profiles) return '';
    for (const [alias, prof] of Object.entries(profile.profiles)) {
        if (prof.machine && prof.machine.hostname && prof.machine.hostname.split('.')[0] === hostname) {
            return alias;
        }
    }
    return '';
})();

const status = issues.length === 0 ? 'ok' : 'warn';

output({
    status: status,
    version: 2,
    profilePath: profilePath,
    machineAlias: machineAlias || matchedAlias,
    machineMatched: !!matchedAlias,
    issues: issues
});
```
new:
```js
// Build result
const final = (profile.profiles && Object.keys(profile.profiles).length > 0)
    ? resolveMachine(profile, { configAlias: machineAlias })
    : { alias: '', via: 'none' };
const status = issues.length === 0 ? 'ok' : 'warn';

output({
    status: status,
    version: 2,
    profilePath: profilePath,
    machineAlias: final.alias,
    machineVia: final.via,
    machineMatched: !!final.alias,
    issues: issues
});
```

**Error-handling audit B1**: resolver never uses empty catch (every catch returns a
reason or exits 2 with a message); `spawnSync` results checked (`status`, stdout);
`readJson` distinguishes ENOENT from parse errors (config-file-safety.md). `register`
validates its output file before reporting. profile-check keeps exit 0 + JSON contract.
**Verify**: `node --check scripts/aitools-profile.js`; `node --check scripts/profile-check.js`;
`bash .scratch/.../S5-Profile/tests/test-resolver.sh` (all T0-T10 as recorded in the report);
`node scripts/profile-check.js` on this Mac -> `machineMatched: true` and no NO_MACHINE_MATCH.

---

## B2 -- lib wrappers + shared JSON validator (2 files; sub-agent required: lib change)

1. `scripts/aitools-lib.sh`: insert `S5-Profile-drafts/scripts/aitools-lib.sh.profile-block.sh`
   (without its first two DRAFT comment lines) directly after the `read_config_key()`
   function; then append `validate_json_config()` **moved verbatim** from
   `scripts/aitools-install.sh` (function `validate_json_config`) after `backup_file()`.
   Header "Provides:" line: add `resolve_user_repo_path, resolve_machine_profile,
   validate_json_config`.
2. `scripts/aitools-lib.ps1`: insert `S5-Profile-drafts/scripts/aitools-lib.ps1.profile-block.ps1`
   after `function ReadConfigKey`; move `function ValidateJsonConfig` verbatim from
   `scripts/aitools-install.ps1` after `function Backup-File`. Header: add
   `Resolve-UserRepoPath, Resolve-MachineProfile, ValidateJsonConfig`.

(The installers keep their own copies until B3 removes them; a later definition wins,
so B2 alone changes no behavior.)

**Error-handling audit B2**: `|| rc=$?` captures node exit codes (no bare `|| true`);
every tagged `error` line goes to `log_error` and rc>=2 pairs with `write_summary ERROR`;
PS1 `Remove-Item -ErrorAction SilentlyContinue` is followed by a `Test-Path` check on the
next line; `ConvertFrom-Json` inside try/catch that logs; `Get-Command node -ErrorAction
SilentlyContinue` is a command-existence check with explicit fallback (exempt).
**Verify**: `bash -n scripts/aitools-lib.sh`; PS1 ParseFile on `aitools-lib.ps1`;
`tests/test-lib-wrappers.sh` and `tests/run-ps1-test.sh` pointed at the edited libs
(same results as recorded: bash and PS1 both report `alias=new-mac via=alias company=nobul-tech`).

---

## B3 -- the single config writer (3 files)

1. **Create** `scripts/setup-user-config.sh` = draft (verbatim; chmod +x).
2. **Create** `scripts/setup-user-config.ps1` = draft (verbatim).
3. **Edit** `scripts/aitools-install.sh`:
   a. delete the `validate_json_config()` definition (moved to the lib in B2; keep the
      two comment lines above it only if they still describe something);
   b. replace Step 5's body -- from the line `# Managed fields: version, reposPath, repoPath; googleDrives only when drives were`
      through the closing `fi` of `elif [ ! -f "$CONFIG_FILE" ]; then ... else ... fi`
      (the block ending `write_summary WARN "aitools config" "not updated (no node)"` / `fi`) -- with:

```bash
# config.json has one writer: setup-user-config.sh (bootstrap keys from this
# installer + values derived from profile.json). It degrades without node.
CONFIG_WRITER="$SCRIPT_DIR/setup-user-config.sh"
if [ ! -f "$CONFIG_WRITER" ]; then
    log_error "Failed: setup-user-config.sh not found next to the installer -- config.json not written"
    write_summary ERROR "aitools config" "writer missing"
else
    writer_args=(--repos-path "$REPOS_PATH_NATIVE" --repo-path "$AITOOLS_NATIVE" --drives-json "$DRIVES_JSON")
    if $DRY_RUN; then writer_args+=(--dry-run); fi
    writer_rc=0
    # The writer logs and summarizes its own outcome; rc is recorded for this step
    bash "$CONFIG_WRITER" "${writer_args[@]}" || writer_rc=$?
    if [ "$writer_rc" -ne 0 ]; then
        log_error "Step 5: setup-user-config.sh failed (exit $writer_rc) -- see $(display_path "$LOG_FILE")"
    fi
fi
```
   Also delete the now-unused `REPOS_PATH_JSON` / `AITOOLS_JSON` lines and the Step 21
   `DEPLOY_SCRIPTS=` value gains `setup-user-config.sh` as its **first** entry:
   old `DEPLOY_SCRIPTS="setup-user-claude.sh setup-user-cursor.sh` -> new
   `DEPLOY_SCRIPTS="setup-user-config.sh setup-user-claude.sh setup-user-cursor.sh`.

   B3b (separate 1-file batch): the same change in `scripts/aitools-install.ps1` --
   delete `function ValidateJsonConfig`, and replace Step 5 from
   `# Managed fields: version, reposPath, repoPath; googleDrives only when drives were`
   through the end of the `if ($DryRun) { ... } else { ... }` block with:

```powershell
# config.json has one writer: setup-user-config.ps1 (bootstrap keys from this
# installer + values derived from profile.json).
$configWriter = Join-Path $PSScriptRoot "setup-user-config.ps1"
if (-not (Test-Path $configWriter)) {
    LogError "Failed: setup-user-config.ps1 not found next to the installer -- config.json not written"
    Write-Summary "ERROR" "aitools config" "writer missing"
} else {
    $drivesJson = ConvertTo-Json -InputObject @($drives | ForEach-Object { [ordered]@{ path = $_.path; account = $_.account; label = $_.label } }) -Depth 5 -Compress
    if (-not $drivesJson) { $drivesJson = "[]" }
    $writerArgs = @{ ReposPath = $resolvedReposPath; RepoPath = $aitoolsRepo; DrivesJson = $drivesJson }
    if ($DryRun) { $writerArgs["DryRun"] = $true }
    & $configWriter @writerArgs
    if ($LASTEXITCODE -ne 0) { LogError "Step 5: setup-user-config.ps1 failed (exit $LASTEXITCODE) -- see $script:logFile" }
}
```
   and add `setup-user-config.ps1` first in the PS1 Step 21 deploy list.
   Step 21 runs child scripts **in-process** behind a guard (`aitools-install.ps1:92-119`,
   per review M11): the writer call must copy that guard -- reset `$global:LASTEXITCODE = 0`
   before `& $configWriter @writerArgs`, wrap the call in try/catch that `LogError`s, and
   emit `Write-Summary "ERROR" "aitools config" ...` on failure. The executing agent reads
   lines 92-119 and mirrors them verbatim.

**Error-handling audit B3**: writer: every node call `|| VAR=$?` then checked; merge
failure leaves the file untouched (`rm -f "$CONFIG_TMP"` is targeted cleanup, allowed);
`read -d ''` `|| true` has the comment and the `-z "$CONFIG_MERGE_JS"` result check;
every `log_error` on a write path pairs with `write_summary ERROR`; three outcomes
created/updated/verified plus recovered. PS1 writer: `-ErrorAction Stop` inside try/catch;
`Get-Command ... SilentlyContinue` is an existence check.
**Verify**: `bash -n`, PS1 ParseFile; `tests/test-writer.sh` S1-S6 (recorded results in
the report); dry run: `bash scripts/aitools-install.sh --dry-run` in an isolated HOME
(smoke-test-pattern: redirect to a log, check exit code).

---

## B4 -- setup-user-claude dev path uses the resolver (2 files)

`scripts/setup-user-claude.sh`

old (from `CONFIG="$HOME/.aitools/config.json"` through the interpolation `fi`):
```bash
CONFIG="$HOME/.aitools/config.json"

CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

# Ensure ~/.claude/ exists
mkdir -p "$CLAUDE_DIR"

# --- Resolve template source ---
# Priority: user repo claude/CLAUDE.md > shared/claude-shared.md
SOURCE_PATH=""
SOURCE_LABEL=""

if [ -f "$CONFIG" ] && command -v node &>/dev/null; then
    USER_REPO_PATH=$(node -e "
try {
    const cfg = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    if (cfg.userRepoPath) console.log(cfg.userRepoPath);
} catch (e) { if (e.code !== 'ENOENT') console.error('Warning: could not read config: ' + e.message); }
" "$CONFIG" 2>/dev/null)

    if [ -n "$USER_REPO_PATH" ] && [ -f "$USER_REPO_PATH/claude/CLAUDE.md" ]; then
        SOURCE_PATH="$USER_REPO_PATH/claude/CLAUDE.md"
        SOURCE_LABEL="user repo"
    fi
fi
```
new:
```bash
CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

# Ensure ~/.claude/ exists
mkdir -p "$CLAUDE_DIR"

# --- BEGIN profile resolution (extracted by build-deploy) ---
# One resolver for the dotprofile and this machine's profile (aitools-lib ->
# aitools-profile.js). A miss is logged as ERROR and never filled with another
# machine's values. rc: 0 resolved, 1 shared-only (no dotprofile), 2 logged error.
USER_REPO_PATH=""
USER_REPO_RC=0
resolve_user_repo_path || USER_REPO_RC=$?
PROFILE_RC=0
resolve_machine_profile || PROFILE_RC=$?
USER_REPO_DISPLAY=""
if [ "$USER_REPO_RC" -eq 0 ]; then
    USER_REPO_DISPLAY=$(printf '%s' "$USER_REPO_PATH" | perl -pe 's/^\Q$ENV{HOME}\E(?=\/|$)/~/')
fi
# --- END profile resolution (extracted by build-deploy) ---

# --- Resolve template source ---
# Priority: user repo claude/CLAUDE.md > shared/claude-shared.md
SOURCE_PATH=""
SOURCE_LABEL=""
if [ -n "$USER_REPO_PATH" ] && [ -f "$USER_REPO_PATH/claude/CLAUDE.md" ]; then
    SOURCE_PATH="$USER_REPO_PATH/claude/CLAUDE.md"
    SOURCE_LABEL="user repo"
fi
```

old (the interpolation block, from `# --- Profile interpolation ---` through its closing `fi`):
```bash
# --- Profile interpolation ---
# Read profile.json and replace {{PLACEHOLDER}} tokens.
# Reuses the same pattern as build-deploy.sh (lines 58-100).
PROFILE_NAME=""
PROFILE_COMPANY=""
IDENTITY_GIT_NAME=""
IDENTITY_GIT_EMAIL=""

if [ -f "$CONFIG" ] && command -v node &>/dev/null; then
```
... (the whole node block, unchanged lines omitted here; the sub-agent replaces through) ...
```bash
else
    log_warn "Profile not available -- {{PLACEHOLDER}} tokens will not be resolved"
    write_summary WARN "claude.md" "template tokens unresolved"
fi
```
new:
```bash
# --- BEGIN profile interpolation (extracted by build-deploy) ---
# Values come from resolve_machine_profile above. Empty values leave their token
# in place (visible, not silently blank).
interpolate_token() {
    local token="$1" value="$2"
    [ -n "$value" ] || return 0
    SHARED_CONTENT=$(TOKEN="$token" VALUE="$value" perl -0777 -pe 's/\Q{{$ENV{TOKEN}}}\E/$ENV{VALUE}/g' <<< "$SHARED_CONTENT")
}
interpolate_token "PROFILE_NAME" "$PROFILE_NAME"
interpolate_token "PROFILE_COMPANY" "$PROFILE_COMPANY"
interpolate_token "IDENTITY_GIT_NAME" "$IDENTITY_GIT_NAME"
interpolate_token "IDENTITY_GIT_EMAIL" "$IDENTITY_GIT_EMAIL"
interpolate_token "USER_REPO_PATH" "$USER_REPO_DISPLAY"
if [ "$PROFILE_RC" -eq 0 ]; then
    log "Profile interpolation: alias=$MACHINE_ALIAS via=$MACHINE_VIA name=$PROFILE_NAME company=$PROFILE_COMPANY"
else
    log_warn "Profile not resolved (rc=$PROFILE_RC) -- machine-specific {{PLACEHOLDER}} tokens left unresolved"
    write_summary WARN "claude.md" "template tokens unresolved"
fi
# --- END profile interpolation (extracted by build-deploy) ---
```
(Perl substitution replaces bash `${var//pat/rep}`: bash 5.2 `patsub_replacement`
treats `&` in the replacement as the match, which corrupts values containing `&`.)

Footer -- old:
```bash
- Machine: $(uname -s) $(uname -m) ($(hostname -s 2>/dev/null || hostname))
```
new:
```bash
- Machine: $(uname -s) $(uname -m) ($(hostname -s 2>/dev/null || hostname); profile ${MACHINE_ALIAS:-unresolved})
```
`adopt_claude_md` reverse substitution -- old (the whole existing block):
```bash
    if [ -n "${PROFILE_NAME:-}" ]; then
        content=$(printf '%s' "$content" | perl -pe "
            s/\\Q${PROFILE_NAME}\\E/{{PROFILE_NAME}}/g;
            s/\\Q${PROFILE_COMPANY}\\E/{{PROFILE_COMPANY}}/g;
            s/\\Q${IDENTITY_GIT_NAME}\\E/{{IDENTITY_GIT_NAME}}/g;
            s/\\Q${IDENTITY_GIT_EMAIL}\\E/{{IDENTITY_GIT_EMAIL}}/g;
        ")
    fi
```
new (values reach perl through the environment, so `/`, `@` and `$` in values cannot
break or alter the program -- review H6 reproduced exit 255 with a path value; also
fixes INCIDENT I-b: an `@` in the email was interpolated as a perl array):
```bash
    reverse_token() {
        local token="$1" value="$2"
        [ -n "$value" ] || return 0
        content=$(TOKEN="$token" VALUE="$value" perl -pe 's/\Q$ENV{VALUE}\E/{{$ENV{TOKEN}}}/g' <<< "$content")
    }
    reverse_token "USER_REPO_PATH" "${USER_REPO_DISPLAY:-}"
    reverse_token "IDENTITY_GIT_EMAIL" "${IDENTITY_GIT_EMAIL:-}"
    reverse_token "PROFILE_COMPANY" "${PROFILE_COMPANY:-}"
    reverse_token "IDENTITY_GIT_NAME" "${IDENTITY_GIT_NAME:-}"
    reverse_token "PROFILE_NAME" "${PROFILE_NAME:-}"
```
(Order: longest/most specific first. When `IDENTITY_GIT_NAME` equals `PROFILE_NAME`
-- "Jose" here -- the first one applied wins, which matches today's behaviour: today the
NAME line runs first, so all occurrences become `{{PROFILE_NAME}}`. Keep NAME after
GIT_NAME only if the commander wants `{{IDENTITY_GIT_NAME}}` to win; open question 11.)

`scripts/setup-user-claude.ps1`: same structure. Replace lines from `# --- Resolve template
source ---` through the interpolation `}` (ending `Write-Summary "WARN" "claude.md" "template tokens unresolved"` / `}`) with:
```powershell
# --- BEGIN profile resolution (extracted by build-deploy) ---
$userRepoRc = Resolve-UserRepoPath
$userRepoPath = if ($userRepoRc -eq 0) { $script:UserRepoPath } else { "" }
$profileRc = Resolve-MachineProfile
$userRepoDisplay = ""
if ($userRepoPath) {
    $userRepoDisplay = $userRepoPath
    $up = $env:USERPROFILE
    if ($up -and ($userRepoDisplay -eq $up -or $userRepoDisplay.StartsWith($up + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))) {
        $userRepoDisplay = '%USERPROFILE%' + $userRepoDisplay.Substring($env:USERPROFILE.Length)
    }
}
# --- END profile resolution (extracted by build-deploy) ---

# --- Resolve template source ---
# Priority: user repo claude/CLAUDE.md > shared/claude-shared.md
$sourcePath = ""
$sourceLabel = ""
if ($userRepoPath) {
    $userClaudeMd = Join-Path $userRepoPath "claude\CLAUDE.md"
    if (Test-Path $userClaudeMd) { $sourcePath = $userClaudeMd; $sourceLabel = "user repo" }
}
if (-not $sourcePath) {
    if (Test-Path $SharedPath) {
        $sourcePath = $SharedPath
        $sourceLabel = "shared template"
    } else {
        LogError "No template found. Checked user repo and $SharedPath"
        exit 1
    }
}
Log "Template source: $sourcePath ($sourceLabel)"

# --- Read template content ---
try {
    $sharedContent = Get-Content -Path $sourcePath -Raw -ErrorAction Stop
} catch {
    LogError "Cannot read template: $sourcePath ($_)"
    exit 1
}
if (-not $sharedContent) {
    LogError "Template is empty: $sourcePath"
    exit 1
}

# --- BEGIN profile interpolation (extracted by build-deploy) ---
$tokens = [ordered]@{
    "PROFILE_NAME" = $script:ProfileName; "PROFILE_COMPANY" = $script:ProfileCompany
    "IDENTITY_GIT_NAME" = $script:IdentityGitName; "IDENTITY_GIT_EMAIL" = $script:IdentityGitEmail
    "USER_REPO_PATH" = $userRepoDisplay
}
foreach ($t in $tokens.Keys) {
    if ($tokens[$t]) { $sharedContent = $sharedContent.Replace("{{$t}}", [string]$tokens[$t]) }
}
if ($profileRc -eq 0) {
    Log "Profile interpolation: alias=$($script:MachineAlias) via=$($script:MachineVia) name=$($script:ProfileName) company=$($script:ProfileCompany)"
} else {
    LogWarn "Profile not resolved (rc=$profileRc) -- machine-specific {{PLACEHOLDER}} tokens left unresolved"
    Write-Summary "WARN" "claude.md" "template tokens unresolved"
}
# --- END profile interpolation (extracted by build-deploy) ---
```
(`String.Replace` is literal; the old `-replace` treated `$` in values as regex groups.)
PS1 footer: `- Machine: $osInfo ($hostname; profile $(if ($script:MachineAlias) { $script:MachineAlias } else { 'unresolved' }))`.
`Adopt-ClaudeMd`: add the `{{USER_REPO_PATH}}` reverse substitution guarded by `if ($userRepoDisplay)`.
Remove `$configFile` from setup-user-claude.ps1 only if no other line uses it (grep first).

**Error-handling audit B4**: resolver rc captured with `|| VAR=$?` (comment present);
no `2>/dev/null` remains in the block; perl substitution fed by env vars (no shell
interpolation into the regex); empty values skip substitution.
**Verify**: `bash -n`; ParseFile; isolated-HOME run `bash scripts/setup-user-claude.sh --dry-run`
-> deploy.log shows `machine profile: alias=new-mac via=...` and `Profile interpolation: alias=new-mac ... company=nobul-tech`;
with the new-mac hostname changed and no alias: ERROR + summary ERROR, and the dry-run
preview keeps `{{PROFILE_COMPANY}}` (never `Nobul`).

---

## B5 -- build-deploy: dotprofile from the entry point, profile resolved at runtime (1 file; sub-agent required)

Targets only the user-rules/DEPLOY_DIR block, the profile-interpolation block, and the
`setup-user-claude.{sh,ps1}` generation sections. Does not touch lines 66-107 (S3-Nine
preflight) or any hook embed loop.

### B5.1 dotprofile location

old:
```bash
CONFIG="$HOME/.aitools/config.json"
if [ -f "$CONFIG" ] && command -v node &>/dev/null; then
    _urp=$(node -e "
try {
    const cfg = JSON.parse(require('fs').readFileSync(process.argv[1], 'utf8'));
    if (cfg.userRepoPath) console.log(cfg.userRepoPath);
} catch(e) {}
" "$CONFIG" 2>/dev/null) || true  # node failure is non-fatal; _urp stays empty
    if [ -n "$_urp" ] && [ -d "$_urp/claude/rules" ]; then
```
new:
```bash
# Dotprofile location: exported by the aitools entry point (resolve_user_repo_path /
# Resolve-UserRepoPath, forward-slash form); a standalone run asks the same resolver.
# node is guaranteed here (preflight above exits without it).
_urp="${AITOOLS_USER_REPO_PATH:-}"
_urp_via="env"
if [ -z "$_urp" ]; then
    _urp_via="resolver"
    _urp_rc=0
    # rc 1 = no dotprofile yet (expected before user init); rc 2 = resolver error.
    # Either way build-deploy skips (exit 0 below) rather than failing: a failing
    # prebuild would stop `aitools` before setup-user-config, the one step that can
    # repair config.json (review H3 -- bootstrap deadlock).
    _urp=$(node "$SCRIPTS_DIR/aitools-profile.js" user-repo-path --format mixed) || _urp_rc=$?
    if [ "$_urp_rc" -ge 2 ]; then
        blog_warn "Dotprofile resolver failed (exit $_urp_rc) -- skipping deploy build; run 'aitools' (setup-user-config repairs config.json) or: node scripts/aitools-profile.js user-repo-path --json"
    fi
    if [ "$_urp_rc" -ne 0 ]; then _urp=""; fi
fi
if [ -n "$_urp" ]; then
    blog "Dotprofile: $_urp (via $_urp_via)"
    if [ -d "$_urp/claude/rules" ]; then
```
and old (closing of that block):
```bash
            USER_RULE_COUNT=$((USER_RULE_COUNT + 1))
        done
    fi
fi
```
new: unchanged text (the `if [ -n "$_urp" ]` replaces the old outer `if [ -f "$CONFIG" ] ...`,
so the two closing `fi` still balance). The sub-agent must confirm `bash -n` passes.
The existing DEPLOY_DIR block right after it (`if [ -n "${_urp:-}" ] && [ -d "$_urp" ]; then ... else blog_warn ... exit 0; fi`)
is kept unchanged: an empty `_urp` already means "skip the build, exit 0".

### B5.2 profile snapshot replaces build-time interpolation

old: the block from `# --- Profile interpolation ---` through
`blog "Cursor CLI prefs: vimMode=$CURSOR_CLI_VIMMODE model=$CURSOR_CLI_MODEL"`
(includes the hardcoded `PROFILE_NAME="Jose"` / `PROFILE_COMPANY="Nobul"` /
`IDENTITY_GIT_EMAIL="jose@nobul.tech"` defaults and the four `CLAUDE_SHARED_CONTENT//` lines).
new:
```bash
# --- Profile snapshot (resolved per machine at RUNTIME, not here) ---
# deploy/ is committed once and used by every machine of this user, so no machine's
# values are interpolated at build time. The generated setup-user-claude.* embed the
# resolver (aitools-profile.js) and this snapshot, and resolve on the target machine
# (live profile.json when the dotprofile is present there, else this snapshot).
CURSOR_CLI_VIMMODE=false
CURSOR_CLI_MODEL="auto"
PROFILE_SNAPSHOT='{"version":2,"identity":{},"cursor":{},"profiles":{}}'
if [ -f "$_urp/profile.json" ]; then
    _snap_rc=0
    PROFILE_SNAPSHOT=$(node "$SCRIPTS_DIR/aitools-profile.js" snapshot --profile "$_urp/profile.json") || _snap_rc=$?
    if [ "$_snap_rc" -ne 0 ] || [ -z "$PROFILE_SNAPSHOT" ]; then
        blog_error "profile.json unreadable: $_urp/profile.json (exit $_snap_rc) -- fix it before building deploy/"
        exit 1
    fi
    _cursor_rc=0
    _cursor_vals=$(node -e '
        const s = JSON.parse(process.argv[1]); const c = (s.cursor && s.cursor.cli) || {};
        console.log(typeof c.vimMode === "boolean" ? String(c.vimMode) : "false");
        console.log(typeof c.model === "string" && /^[A-Za-z0-9._-]+$/.test(c.model) ? c.model : "auto");
    ' "$PROFILE_SNAPSHOT") || _cursor_rc=$?
    if [ "$_cursor_rc" -ne 0 ]; then
        blog_error "Could not read cursor.cli from the profile snapshot (exit $_cursor_rc)"
        exit 1
    fi
    CURSOR_CLI_VIMMODE=$(printf '%s\n' "$_cursor_vals" | perl -ne 'print if $. == 1' | tr -d '\n')
    CURSOR_CLI_MODEL=$(printf '%s\n' "$_cursor_vals" | perl -ne 'print if $. == 2' | tr -d '\n')
else
    blog_warn "No profile.json in $_urp -- deploy scripts embed an empty profile snapshot"
fi
# Template: the dotprofile's claude/CLAUDE.md wins, as on the dev path (setup-user-claude).
TEMPLATE_LABEL="shared/claude-shared.md"
if [ -f "$_urp/claude/CLAUDE.md" ]; then
    CLAUDE_SHARED_CONTENT=$(cat "$_urp/claude/CLAUDE.md")
    TEMPLATE_LABEL="dotprofile claude/CLAUDE.md"
fi
# Embedding guard: the PS1 here-string ends at a line starting with '@, and the lib
# inliners (inline_lib_bash / inline_lib_ps1) replace any line naming the libs --
# either would corrupt the embedded resolver (review H1, reproduced).
if grep -nE "^'@|aitools-lib\.ps1|source.*aitools-lib\.sh" "$SCRIPTS_DIR/aitools-profile.js"; then
    blog_error "aitools-profile.js cannot be embedded: a line above starts with '@ or names a shared lib file"
    exit 1
fi
blog "Template: $TEMPLATE_LABEL (tokens resolved at runtime)"
blog "Cursor CLI prefs: vimMode=$CURSOR_CLI_VIMMODE model=$CURSOR_CLI_MODEL"
```
(Removes `eval` of node output, which expanded `$(...)` inside profile values.)

### B5.3 generated deploy/setup-user-claude.sh

old:
```bash
    cat <<'BLOCK'

# --- Auto-detect machine info ---
OS_NAME=$(uname -s)
ARCH=$(uname -m)
HOSTNAME=$(hostname -s 2>/dev/null || hostname)
SHELL_NAME=$(basename "${SHELL:-/bin/bash}")

CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

mkdir -p "$CLAUDE_DIR"
log "Ensuring $CLAUDE_DIR exists"

# --- Embedded shared preferences (from shared/claude-shared.md) ---
BLOCK
    echo 'read -r -d "" SHARED_CONTENT <<'"'"'__EMBEDDED_CLAUDE_SHARED__'"'"' || true'
    echo "$CLAUDE_SHARED_CONTENT"
    echo '__EMBEDDED_CLAUDE_SHARED__'
    cat <<'BLOCK'

# --- Build content ---
NEW_CONTENT="${SHARED_CONTENT}

## Machine-Specific

- Machine: ${OS_NAME} ${ARCH} (${HOSTNAME})
- Shell: ${SHELL_NAME}"
```
new:
```bash
    cat <<'BLOCK'

# --- Auto-detect machine info ---
OS_NAME=$(uname -s)
ARCH=$(uname -m)
HOSTNAME=$(hostname -s 2>/dev/null || hostname)
SHELL_NAME=$(basename "${SHELL:-/bin/bash}")

CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

mkdir -p "$CLAUDE_DIR"
log "Ensuring $CLAUDE_DIR exists"

# --- Embedded resolver + profile snapshot (resolved on this machine, now) ---
_EMBED_DIR=$(mktemp -d)
_cleanup_embed() { rm -rf "$_EMBED_DIR"; }
trap _cleanup_embed EXIT
BLOCK
    echo "cat > \"\$_EMBED_DIR/aitools-profile.js\" <<'__EMBEDDED_PROFILE_JS__'"
    cat "$SCRIPTS_DIR/aitools-profile.js"
    echo '__EMBEDDED_PROFILE_JS__'
    echo "cat > \"\$_EMBED_DIR/profile.json\" <<'__EMBEDDED_PROFILE_SNAPSHOT__'"
    printf '%s\n' "$PROFILE_SNAPSHOT"
    echo '__EMBEDDED_PROFILE_SNAPSHOT__'
    cat <<'BLOCK'
export AITOOLS_PROFILE_JS="$_EMBED_DIR/aitools-profile.js"
# The live profile wins when this machine has the dotprofile; else the build snapshot.
_live_rc=0
resolve_user_repo_path || _live_rc=$?
if [ "$_live_rc" -ne 0 ] || [ ! -f "$USER_REPO_PATH/profile.json" ]; then
    export AITOOLS_PROFILE_FILE="$_EMBED_DIR/profile.json"
    log "Profile source: embedded build-time snapshot"
else
    log "Profile source: live $(display_path "$USER_REPO_PATH/profile.json")"
fi

# --- Embedded template (tokens resolved below) ---
BLOCK
    echo 'read -r -d "" SHARED_CONTENT <<'"'"'__EMBEDDED_CLAUDE_SHARED__'"'"' || true'
    echo "$CLAUDE_SHARED_CONTENT"
    echo '__EMBEDDED_CLAUDE_SHARED__'
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^# --- BEGIN profile resolution' '^# --- END profile resolution'
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^# --- BEGIN profile interpolation' '^# --- END profile interpolation'
    cat <<'BLOCK'

# --- Build content ---
NEW_CONTENT="${SHARED_CONTENT}

## Machine-Specific

- Machine: ${OS_NAME} ${ARCH} (${HOSTNAME}; profile ${MACHINE_ALIAS:-unresolved})
- Shell: ${SHELL_NAME}"
```
And in the write heredoc further down (the second occurrence -- this line appears twice
in build-deploy.sh; anchor on the preceding `cat > "$CLAUDE_MD" << CLAUDE_EOF` line plus
the blank and `## Machine-Specific` lines), old `- Machine: ${OS_NAME} ${ARCH} (${HOSTNAME})` -> new
`- Machine: ${OS_NAME} ${ARCH} (${HOSTNAME}; profile ${MACHINE_ALIAS:-unresolved})`.

Rules temp dir: old
```bash
RULES_SRC=$(mktemp -d)
_cleanup_rules() { rm -rf "$RULES_SRC"; }
trap _cleanup_rules EXIT
```
new (one trap owns cleanup; the rules dir lives inside the embed dir):
```bash
RULES_SRC="$_EMBED_DIR/rules"
mkdir -p "$RULES_SRC"
```
and old
```bash
# Clean up temp source dir
rm -rf "$RULES_SRC"
trap - EXIT
```
new:
```bash
# Temp sources are removed by _cleanup_embed (EXIT trap)
```

### B5.4 generated deploy/setup-user-claude.ps1

old:
```bash
# --- Embedded shared preferences (from shared/claude-shared.md) ---
$sharedContent = @'
BLOCK
    echo "$CLAUDE_SHARED_CONTENT"
    cat <<'BLOCK'
'@
```
new:
```bash
# --- Embedded resolver + profile snapshot (resolved on this machine, now) ---
$embedDir = Join-Path ([System.IO.Path]::GetTempPath()) ("aitools-embed-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $embedDir -Force | Out-Null
$embeddedProfileJs = @'
BLOCK
    cat "$SCRIPTS_DIR/aitools-profile.js"
    cat <<'BLOCK'
'@
$embeddedSnapshot = @'
BLOCK
    printf '%s\n' "$PROFILE_SNAPSHOT"
    cat <<'BLOCK'
'@
[IO.File]::WriteAllText((Join-Path $embedDir "aitools-profile.js"), $embeddedProfileJs, [System.Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $embedDir "profile.json"), $embeddedSnapshot, [System.Text.UTF8Encoding]::new($false))
$env:AITOOLS_PROFILE_JS = Join-Path $embedDir "aitools-profile.js"
$liveRc = Resolve-UserRepoPath
if ($liveRc -ne 0 -or -not (Test-Path (Join-Path $script:UserRepoPath "profile.json"))) {
    $env:AITOOLS_PROFILE_FILE = Join-Path $embedDir "profile.json"
    Log "Profile source: embedded build-time snapshot"
} else {
    Log "Profile source: live $(Join-Path $script:UserRepoPath 'profile.json')"
}

# --- Embedded template (tokens resolved below) ---
$sharedContent = @'
BLOCK
    echo "$CLAUDE_SHARED_CONTENT"
    cat <<'BLOCK'
'@
BLOCK
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^# --- BEGIN profile resolution' '^# --- END profile resolution' --crlf
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^# --- BEGIN profile interpolation' '^# --- END profile interpolation' --crlf
    cat <<'BLOCK'
```
(the PS1 generation pipes through the existing CRLF/`inline_lib_ps1` handling of that
section -- the sub-agent must keep whatever trailing pipe the section already has), and the
PS1 footer line `- Machine: $osInfo ($hostname)` -> `- Machine: $osInfo ($hostname; profile $(if ($script:MachineAlias) { $script:MachineAlias } else { 'unresolved' }))`.
Add at the PS1 exit (before the extracted exit block): `Remove-Item -LiteralPath $embedDir -Recurse -Force -ErrorAction SilentlyContinue` followed by
`if (Test-Path -LiteralPath $embedDir) { LogWarn "Could not remove $embedDir" }`.

**Error-handling audit B5**: all node calls `|| rc=$?` + checked; build fails loud on a
corrupt profile (no "build never fails" silent defaults); the old `2>/dev/null) || true`
config read is gone; `grep -q "^'@"` guards the here-string; PS1 `Remove-Item
SilentlyContinue` followed by `Test-Path`. Removes hardcoded personal defaults.
**Verify** (never run build-deploy against the real dotprofile from an agent -- it
`rm -rf`s `<dotprofile>/deploy`): run as one prefixed command,
`HOME=<isolated> AITOOLS_USER_REPO_PATH=<isolated copy of the dotprofile> bash scripts/build-deploy.sh`
-- never `export` the variable in a shell that later runs checks (review H5); then `bash -n` and ParseFile
every generated file; run the generated `deploy/setup-user-claude.sh --dry-run` in the
isolated HOME: logs `Profile source: live ...` and `alias=new-mac`; delete the isolated
dotprofile copy's profile.json and set `AITOOLS_PROFILE_FILE` unset: logs
`Profile source: embedded build-time snapshot`. `grep -c "Company: Nobul" deploy/*` = 0.

---

## B6 -- scripts/aitools (1 file)

1. Deploy lists (`deploy_configs`): prepend `setup-user-config.ps1` to the string starting
   `local deploy_scripts="setup-user-claude.ps1` and `setup-user-config.sh` to the one
   starting `local deploy_scripts="setup-user-claude.sh` (`local deploy_scripts=` alone occurs
   4 times; the other two are the self-update regex lines and stay unchanged).
2. Before Step 2 build-deploy, old:
```bash
# Pull user repo (quiet, non-blocking — stale local data is better than failing)
if raw=$(read_config_key "$config" "userRepoPath"); then
    user_repo_path=$(to_native_path "$raw")
    if [ -d "$user_repo_path/.git" ]; then
```
new:
```bash
# Pull user repo (quiet, non-blocking — stale local data is better than failing)
# One dotprofile answer for this run; exported for build-deploy (which does not
# source aitools-lib). Forward slashes: valid in Git Bash, node and PowerShell.
_urp_rc=0
resolve_user_repo_path || _urp_rc=$?   # 1 = no dotprofile yet (expected); 2 = logged error
if [ "$_urp_rc" -eq 0 ]; then
    user_repo_path="$USER_REPO_PATH"
    if command -v cygpath >/dev/null 2>&1; then
        export AITOOLS_USER_REPO_PATH="$(cygpath -m "$user_repo_path")"
    else
        export AITOOLS_USER_REPO_PATH="$user_repo_path"
    fi
    if [ -d "$user_repo_path/.git" ]; then
```
3. `check_profile`: route its messages through `log_warn` + `write_summary WARN "profile" "<code>"`
   + `write_summary ACTION "" "Run: aitools user init"` instead of raw `printf`, and call it
   **before** `deploy_configs` in both the no-args and install paths (move the two
   `check_profile interactive` calls above `deploy_configs` / the installer call).
4. `user init` -- replace the Path 1 hostname block (`# Detect machineAlias from profile.json by hostname match` ... its `fi`),
   the Path 2 "Check if machine profile needs adding" block, the Path 3 profile creation
   node block, and the final "Write userRepoPath and machineAlias to config" node block
   with calls to two new functions (defined near `migrate_profile_v1_to_v2`):

```bash
# choose_machine_profile <profile.json> <suggested-alias> -- interactive pick of this
# machine's profile. Sets machine_alias (empty on skip). Options are identical in
# aitools.ps1 (interactive-menus.md parity): numbered aliases, [n]ew, [s]kip.
choose_machine_profile() {
    local pf="$1" suggested="$2" aliases=() a i choice
    while IFS= read -r a; do [ -n "$a" ] && aliases+=("$a"); done < <(node -e '
        const p = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
        for (const a of Object.keys(p.profiles || {})) console.log(a);
    ' "$pf")
    machine_alias=""
    if [ "${#aliases[@]}" -eq 0 ]; then
        log_error "machine profile: could not list profiles in $(display_path "$pf")"
        write_summary ERROR "machine profile" "profile list unreadable"
        return 1
    fi
    # Use the repo's TTY helpers (aitools-lib tty_interactive / read_tty_choice) for the
    # interactivity test and the reads below; the sub-agent replaces `[ ! -c /dev/tty ]`
    # and `read -r choice < /dev/tty` with them (review M5) after reading their contracts.
    if [ ! -c /dev/tty ] || [ "${AITOOLS_FORCE:-}" = "1" ]; then
        log_error "No machine profile matches this machine and no terminal to ask -- run 'aitools user init' interactively"
        write_summary ERROR "machine profile" "no machine match"
        write_summary ACTION "" "Run: aitools user init (interactive)"
        return 1
    fi
    printf 'Which profile is this machine?\n' > /dev/tty
    i=1
    for a in "${aliases[@]}"; do
        if [ "$a" = "$suggested" ]; then printf '  [%d] %s (hostname match)\n' "$i" "$a" > /dev/tty
        else printf '  [%d] %s\n' "$i" "$a" > /dev/tty; fi
        i=$((i + 1))
    done
    printf '  [n] new profile for this machine\n  [s] skip\nChoice: ' > /dev/tty
    read -r choice < /dev/tty
    case "$choice" in
        [sS]|"") log_warn "machine profile: skipped -- deploys will report no machine match"; return 1 ;;
        [nN])
            printf 'New alias (e.g., laptop, workstation): ' > /dev/tty
            read -r machine_alias < /dev/tty ;;
        *)
            if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#aliases[@]}" ]; then
                machine_alias="${aliases[$((choice - 1))]}"
            else
                log_warn "machine profile: invalid choice '$choice' -- skipped"; return 1
            fi ;;
    esac
    [ -n "$machine_alias" ]
}

# register_machine_profile <dotprofile-dir> <alias> [name] [company] -- record this
# machine (hashed machine.id, hostname, os, arch, shell) under <alias> in profile.json:
# aitools-profile.js register -> temp -> validate_json_config -> backup_file -> mv,
# then commit (and best-effort push) the dotprofile change.
register_machine_profile() {
    local dir="$1" alias="$2" name="${3:-}" company="${4:-}" pf tmp out rc=0
    pf="$dir/profile.json"; tmp="$pf.tmp.$$"
    local args=(register --profile "$pf" --alias "$alias" --out "$tmp" --shell "$(basename "${SHELL:-/bin/bash}")" --environment "$AITOOLS_ENVIRONMENT")
    [ -n "$name" ] && args+=(--name "$name")
    [ -n "$company" ] && args+=(--company "$company")
    [ -f "$pf" ] || args+=(--create --github-user "$gh_user" --email "${prof_email:-}")
    out=$(node "$repo_path/scripts/aitools-profile.js" "${args[@]}" 2>&1) || rc=$?
    if [ "$rc" -ne 0 ]; then
        rm -f "$tmp"
        log_error "machine profile: register $alias failed (exit $rc): $out"
        write_summary ERROR "machine profile" "register failed"
        return 1
    fi
    case "$out" in
        *'"result":"unchanged"'*) rm -f "$tmp"; log_ok "machine profile: $alias already registered to this machine"; return 0 ;;
    esac
    if ! validate_json_config "$tmp" version profiles; then
        rm -f "$tmp"; write_summary ERROR "machine profile" "register validation failed"; return 1
    fi
    backup_file "$pf"
    if ! mv "$tmp" "$pf"; then
        rm -f "$tmp"; log_error "machine profile: could not replace $(display_path "$pf")"
        write_summary ERROR "machine profile" "write failed"; return 1
    fi
    log_ok "machine profile: registered this machine as '$alias' ($out)"
    local git_out git_rc=0
    git_out=$(git -C "$dir" add profile.json 2>&1) || git_rc=$?
    if [ "$git_rc" -eq 0 ]; then
        git_out=$(git -C "$dir" commit -m "Register machine profile: $alias" 2>&1) || git_rc=$?
    fi
    if [ "$git_rc" -ne 0 ]; then
        log_warn "machine profile: dotprofile commit failed -- commit profile.json by hand"; log_detail "git: $git_out"; return 0
    fi
    git_rc=0
    git_out=$(git -C "$dir" push 2>&1) || git_rc=$?
    if [ "$git_rc" -ne 0 ]; then log_warn "machine profile: push failed -- run git push in $(display_path "$dir")"; log_detail "git: $git_out"; fi
    return 0
}
```

   Path 1 new body (replaces the hostname-detect block):
```bash
                # Resolve this machine's profile; ask when nothing decisive matches (RCA fix a)
                if command -v node &>/dev/null && [ -f "$user_repo_dir/profile.json" ]; then
                    resolve_rc=0
                    resolve_out=$(AITOOLS_USER_REPO_PATH="$user_repo_dir" node "$repo_path/scripts/aitools-profile.js" \
                        resolve --config "$config" --environment "$AITOOLS_ENVIRONMENT" --format tagged) || resolve_rc=$?
                    machine_alias=$(printf '%s\n' "$resolve_out" | perl -ne 'print $1 if /^alias\t(.+)$/')
                    machine_via=$(printf '%s\n' "$resolve_out" | perl -ne 'print $1 if /^via\t(.+)$/')
                    log "machine profile: resolve rc=$resolve_rc alias=${machine_alias:-none} via=${machine_via:-none}"
                    if [ -z "$machine_alias" ] || [ "$machine_via" = "hostname" ]; then
                        choose_machine_profile "$user_repo_dir/profile.json" "$machine_alias" || machine_alias=""
                    fi
                    if [ -n "$machine_alias" ]; then
                        register_machine_profile "$user_repo_dir" "$machine_alias" || true  # failure logged + summarized inside
                    fi
                fi
```
   Path 2: after clone + v1 check, run the same Path 1 body (it handles "new" through
   `choose_machine_profile` [n], with name/company prompts kept from today's Path 2 and
   passed to `register_machine_profile`). Path 3: after the existing prompts, call
   `register_machine_profile "$user_repo_dir" "${machine_alias:-default}" "$prof_name" "$prof_company"`
   in place of the inline `node -e` profile writer (the `--create` branch writes identity).

   Config write, old: the block from `# Write userRepoPath and machineAlias to config` through
   its `fi` (ends `echo "Config updated: machineAlias = $machine_alias"` / `fi` / `fi`). new:
```bash
            # config.json has one writer (setup-user-config.sh)
            writer_rc=0
            bash "$repo_path/scripts/setup-user-config.sh" --github-user "$gh_user" \
                --user-repo-path "$user_repo_dir" ${machine_alias:+--machine-alias "$machine_alias"} || writer_rc=$?
            if [ "$writer_rc" -ne 0 ]; then
                log_error "user init: setup-user-config.sh failed (exit $writer_rc) -- see $LOG_DISPLAY"
            fi
```
   (On Windows Git Bash the `aitools` bash entry dispatches `.ps1` scripts; route this call
   through the same `uname -s` dispatch used for `hook_setup` just below it.)

**Error-handling audit B6**: `|| true` on `register_machine_profile` has the comment and
the function logs/summarizes internally; every node/git call captures rc; `rm -f "$tmp"`
targeted cleanup; menu uses `/dev/tty` (interactive-menus.md); non-terminal path errors
with ACTION instead of guessing.
**Verify**: `bash -n scripts/aitools`; isolated HOME: `aitools user init` against a copy of
the dotprofile (gh mocked by setting `gh_user` input at the prompt) -- Path 1 with no
match prompts, writes machine.id `sha256:1f634eecaf97fa63` under `new-mac`, commits in the
copy, and config.json gains `machineAlias: new-mac`; second run logs `already registered`.

## B7 -- scripts/aitools.ps1 (1 file)

Mirror of B6: `Choose-MachineProfile` (same options/order, `[Console]::WriteLine` /
`[Console]::ReadLine()`), `Register-MachineProfile` (node register -> temp ->
`ValidateJsonConfig` -> `Backup-File` -> `Move-Item -ErrorAction Stop` in try/catch, git
commit/push with captured output), Path 1/2/3 changes, config write via
`& (Join-Path $repoPath "scripts\setup-user-config.ps1") -GithubUser $ghUser -UserRepoPath $userRepoDir -MachineAlias $machineAlias`,
deploy list prepend, `Invoke-ProfileCheck` through `LogWarn`/`Write-Summary` and moved
before deploy, and before the build-deploy bash call:
```powershell
# aitools.ps1 runs in the user's own session (aitools-install.ps1 shim uses &), so an
# exported variable would outlive this run and steer later build-deploy calls (e.g.
# check-pre-push step 7) into the real dotprofile (review H5). Scope it to the call.
$prevUrp = $env:AITOOLS_USER_REPO_PATH
try {
    $urpRc = Resolve-UserRepoPath
    if ($urpRc -eq 0) { $env:AITOOLS_USER_REPO_PATH = ($script:UserRepoPath -replace '\\', '/') }
    else { $env:AITOOLS_USER_REPO_PATH = $null }
    # ... existing build-deploy bash invocation, unchanged ...
} finally {
    $env:AITOOLS_USER_REPO_PATH = $prevUrp
}
```
Same scoping for `AITOOLS_PROFILE_JS` / `AITOOLS_PROFILE_FILE` in the generated PS1
deploy scripts (B5.4): save at start, restore in a `finally` around the body (review M4).
The executing agent reads aitools.ps1 lines 81-260 and 870-1160 first (this plan quotes
only 880-940 and 1130-1164) and writes verbatim old/new for review before applying.
**Verify**: ParseFile; on the workstation (Windows): `aitools user init` registers
`workstation` with a MachineGuid-derived id (first empirical check of the Windows id path;
until then it is `UNVERIFIED` in aitools-profile.js).

## B8 -- remaining consumers use the resolver (3-file chunks)

Replace each `USER_REPO_PATH=$(read_config_key "$HOME/.aitools/config.json" "userRepoPath") || true`
(and PS1 `ReadConfigKey ... "userRepoPath"`) with
```bash
USER_REPO_PATH=""
resolve_user_repo_path || true  # rc 1 = shared-only (expected), rc 2 already logged; USER_REPO_PATH checked below
```
```powershell
$null = Resolve-UserRepoPath; $userRepoPath = $script:UserRepoPath   # rc 1 = shared-only; 2 already logged
```
- B8a: setup-user-settings.sh/.ps1, setup-user-skills.sh
- B8b: setup-user-skills.ps1, setup-user-cursor.sh/.ps1 (the cursor node block reads
  `cfg.userRepoPath` itself -- pass `$USER_REPO_PATH` as an argument instead)
- B8c: check-lib.sh/.ps1 (`resolve_config`), `scripts/ait-harvest.py`
  (`read_text(encoding="utf-8-sig")` so a BOM config does not silently disable archiving).
- setup-user-hooks.sh/.ps1: **defer to M6** (hook lifecycle owner) -- same one-line change.
- **Coordinate with the check-pre-push owner (S3-Nine scope, not in this plan's file list):**
  step 7 must pass `AITOOLS_USER_REPO_PATH=<its temp dotprofile copy>` explicitly and unset
  `AITOOLS_PROFILE_FILE` / `AITOOLS_MACHINE_ALIAS` (review H5), and its trigger regex
  (`check-pre-push.sh:112`, `.ps1:115`) must include `scripts/aitools-profile.js` (review M7).
- build-deploy's generated settings/skills PS1 blocks (`build-deploy.sh:1075, 1181`) still read
  config.json directly; switch them in B8 too (review L8).
Then `bash scripts/build-deploy.sh` in an isolated HOME (see B5 verify) because these
scripts are extracted into deploy/.

## Test plan summary

| Layer | How | Where |
|---|---|---|
| Resolver unit | `tests/test-resolver.sh` (T0-T10) | macOS, run in this session |
| Bash wrappers | `tests/test-lib-wrappers.sh` (W1-W4) | macOS, run |
| PS1 wrappers | `tests/run-ps1-test.sh` (P1-P2, pwsh on macOS) | macOS, run |
| Writer | `tests/test-writer.sh` (S1-S6) | macOS, run |
| PS1 parse | `tests/parse-ps1.ps1` | macOS, run (0 errors) |
| PS1 writer functional | run setup-user-config.ps1 with isolated USERPROFILE | Windows workstation: not run (OS guard blocks macOS) |
| Windows id | `node scripts/aitools-profile.js machine-id` | Windows: UNVERIFIED |
| Linux id | same, plus `AITOOLS_ENVIRONMENT=claude-code-web` profile match | Linux / Claude Code web: not run |
| deploy/ runtime | B5 verify steps, isolated HOME + dotprofile copy | macOS, after B5 |
| Cross-machine | deploy/ built on new-mac, run on laptop: `company=Nobul` (laptop override) | laptop, after B5 |
