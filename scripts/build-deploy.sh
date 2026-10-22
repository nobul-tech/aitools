#!/usr/bin/env bash
# build-deploy.sh — Generates self-contained deploy/ scripts from scripts/ + shared/
#
# Output goes to deploy/ only. There is no separate build/ directory in this repo;
# CI and MDM both consume deploy/.
#
# Reads shared content files and embeds them into deploy versions of setup scripts.
# The deploy/ scripts have zero dependencies on the repo or Google Drive — they can
# be deployed to any endpoint via MDM (Jamf, Intune) or run manually.
#
# Relay → ~/.cursor/AGENTS.md: NOT embedded here. That step needs the live repo file
# `.aitools/channel/relay.md` and runs from `scripts/sync-relay-to-cursor-agents.py`
# during `aitools` / `aitools install` (see scripts/aitools deploy_configs).
#
# Usage: bash scripts/build-deploy.sh   (run from repo root)
#
# CROSS-PLATFORM NOTE: This script is intentionally bash-only (no .ps1 variant).
# It's a build step that produces platform-independent output (both .sh and .ps1
# deploy scripts). The result is committed to git, so both platforms get identical
# deploy/ contents. A parallel PS1 would double maintenance for no output difference.
# On Windows, aitools.ps1 invokes this via Git Bash (a prerequisite for Claude Code).
# See .claude/rules/cross-platform.md "Approved exceptions" for the exception record.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts"
DEPLOY_DIR="$REPO_ROOT/deploy"
SHARED_DIR="$REPO_ROOT/shared"

# Strawberry Perl text-mode fix: PERLIO=:perlio disables CRLF translation that
# causes double-CR (\r\r\n) in extract_between --crlf output. No-op for Git's
# bundled perl (already uses :unix:perlio). See reference/cross-platform-detail.md.
export PERLIO=:perlio

# --- Build logging (standalone -- does not source aitools-lib.sh) ---
SCRIPT_NAME="build-deploy"
blog()       { printf '[%s] [%s] [info] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1"; }
blog_ok()    { printf '[%s] [%s] [ok] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1"; }
blog_warn()  { printf '\033[33m[%s] [%s] [warn] %s\033[0m\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" >&2; }
blog_error() { printf '\033[31m[%s] [%s] [error] %s\033[0m\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SCRIPT_NAME" "$1" >&2; }

# Shared content files
CLAUDE_SHARED="$SHARED_DIR/claude-shared.md"

# Verify shared files exist
if [ ! -f "$CLAUDE_SHARED" ]; then
    blog_error "Required shared file not found: $CLAUDE_SHARED"
    exit 1
fi
# Verify at least one skill file exists in shared/skills/
_skill_count=0
for _skill_dir in "$SHARED_DIR/skills"/*/; do
    [ -d "$_skill_dir" ] || continue
    if [ -f "$_skill_dir/SKILL.md" ]; then
        _skill_count=$((_skill_count + 1))
    else
        blog_warn "Skill directory missing SKILL.md: $_skill_dir"
    fi
done
if [ "$_skill_count" -eq 0 ]; then
    blog_error "No skill files found in $SHARED_DIR/skills/"
    exit 1
fi
blog "Found $_skill_count skill(s) in shared/skills/"
# Hook + helper preflight: file list derived from hooks-manifest.json (single
# source of truth -- no hardcoded hook filenames in this script; see issue #9).
# Resolution mirrors the embed loops: shared/hooks/ first, then scripts/ (the
# manifest 'deploy' helpers may live in either).
HOOKS_MANIFEST="$SHARED_DIR/hooks/hooks-manifest.json"
if [ ! -f "$HOOKS_MANIFEST" ]; then
    blog_error "Required manifest not found: $HOOKS_MANIFEST"
    exit 1
fi
# node is required to build: manifest parsing here, the dotprofile lookup below,
# and the hook embed loops all shell out to node. A node-less machine has never
# been able to build (the dotprofile lookup needs node, so the build skipped);
# keep that a graceful skip (exit 0) so 'aitools' continues to the installer
# step that installs node. The silent-failure case this preflight closes is node
# PRESENT but the manifest unparseable -- that is handled (exit 1) just below.
if ! command -v node >/dev/null 2>&1; then
    blog_warn "node not found -- skipping deploy build (node is installed by 'aitools install')"
    exit 0
fi
_manifest_files=$(node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));console.log([...m.hooks.map(h=>h.file),...(m.deploy||[])].join("\n"))' "$HOOKS_MANIFEST") || {
    blog_error "Failed to parse $HOOKS_MANIFEST"
    exit 1
}
_hook_count=0
while IFS= read -r _hook_file; do
    [ -n "$_hook_file" ] || continue
    if [ ! -f "$SHARED_DIR/hooks/$_hook_file" ] && [ ! -f "$SCRIPTS_DIR/$_hook_file" ]; then
        blog_error "Manifest-listed hook file not found: $_hook_file (searched shared/hooks/ and scripts/)"
        exit 1
    fi
    _hook_count=$((_hook_count + 1))
done <<< "$_manifest_files"
blog "Preflight OK: $_hook_count hook/helper file(s) from hooks-manifest.json"

# Cursor AGENTS mirror (repo runtime — requires .aitools/channel/relay.md; not in deploy/)
if [ ! -f "$SCRIPTS_DIR/sync-relay-to-cursor-agents.py" ]; then
    blog_error "Required script not found: $SCRIPTS_DIR/sync-relay-to-cursor-agents.py"
    exit 1
fi
blog "Found sync-relay-to-cursor-agents.py (relay→AGENTS runs from aitools deploy, not from deploy/)"

# (Hook contents are NOT read into variables here -- the embed loops read each
# file directly from the hooks-manifest.json list. Keeping per-hook variables
# was dead code and a hardcoded list that drifted; see issue #9.)

# inline_lib_bash [BLOCK_FILE]: replaces the script's lib-loading line (the FIRST line
# that starts with `source` and names aitools-lib.sh) with the lib content, followed
# by BLOCK_FILE's content when one is given (stdin -> stdout). Only that one line is
# replaced: text embedded later in the script (skills, hooks, rules, the resolver
# block) that names the lib is left alone (review H1; before, a SKILL.md line
# "Hooks cannot source `aitools-lib.sh`" was replaced by the whole lib). A script
# with no lib-loading line fails the build.
# Uses perl for performance (single process vs ~2 subprocesses per line with while-read)
inline_lib_bash() {
    perl -e '
        open my $lib, "<", $ARGV[0] or die "Cannot open lib: $!";
        my $content = do { local $/; <$lib> };
        close $lib;
        if (defined $ARGV[1] && length $ARGV[1]) {
            $content .= "\n" unless $content =~ /\n\z/;
            open my $blk, "<", $ARGV[1] or die "Cannot open embed block: $!";
            $content .= do { local $/; <$blk> };
            close $blk;
        }
        my $done = 0;
        while (<STDIN>) {
            if (!$done && /^\s*source\s.*aitools-lib\.sh/) {
                print $content;
                $done = 1;
            } else {
                print;
            }
        }
        die "build-deploy: no line loads aitools-lib.sh -- nothing inlined\n" unless $done;
    ' "$SCRIPTS_DIR/aitools-lib.sh" "${1:-}"
}

# inline_lib_ps1 [BLOCK_FILE]: same for PowerShell -- the FIRST line that dot-sources
# aitools-lib.ps1 (starts with ". ").
# Uses perl for performance (single process vs ~2 subprocesses per line with while-read)
inline_lib_ps1() {
    perl -e '
        open my $lib, "<", $ARGV[0] or die "Cannot open lib: $!";
        my $content = do { local $/; <$lib> };
        close $lib;
        if (defined $ARGV[1] && length $ARGV[1]) {
            $content .= "\n" unless $content =~ /\n\z/;
            open my $blk, "<", $ARGV[1] or die "Cannot open embed block: $!";
            $content .= do { local $/; <$blk> };
            close $blk;
        }
        my $done = 0;
        while (<STDIN>) {
            if (!$done && /^\s*\.\s.*aitools-lib\.ps1/) {
                print $content;
                $done = 1;
            } else {
                print;
            }
        }
        die "build-deploy: no line dot-sources aitools-lib.ps1 -- nothing inlined\n" unless $done;
    ' "$SCRIPTS_DIR/aitools-lib.ps1" "${1:-}"
}

# --- Dotprofile: the build target and the source of the embedded user content ---
# build-deploy produces a PERSONALIZED, self-contained (MDM-ready) artifact into the
# user's dotprofile repo (aitools-<ghuser>/deploy/). The shared aitools/deploy/ is left
# untouched. The dotprofile comes from the entry point: `aitools` / `aitools.ps1`
# export AITOOLS_USER_REPO_PATH, and check-pre-push step 7 passes its temp copy that
# way. A standalone run asks the resolver every setup script uses
# (resolve_user_repo_path in aitools-lib.sh; SD-7) in a child bash, so this script
# keeps its own build logging: the child's console lines go to stderr and only the
# path comes back, on fd 3. config.json is not read here.
# No dotprofile (rc 1) or a resolver error (rc 3) skips the build with exit 0: a
# failing prebuild would stop `aitools` before setup-user-config, the one step that
# can repair config.json (review H3). The bootstrap flow runs build-deploy only after
# `aitools user init`, so a dotprofile exists by then.
_urp="${AITOOLS_USER_REPO_PATH:-}"
_urp_via="AITOOLS_USER_REPO_PATH"
if [ -z "$_urp" ]; then
    _urp_via="resolver"
    _urp_rc=0
    # AITOOLS_SUMMARY_FILE is dropped for the child: the setup scripts report a
    # dotprofile error in the run summary themselves; this build only warns.
    _urp=$(env -u AITOOLS_SUMMARY_FILE "${BASH:-bash}" -c '
set -euo pipefail
source "$1/aitools-lib.sh"
logging_init "build-deploy"
rc=0
resolve_user_repo_path || rc=$?
printf "%s" "$AITLIB_USER_REPO_PATH" >&3
exit "$rc"' build-deploy "$SCRIPTS_DIR" 3>&1 1>&2) || _urp_rc=$?
    case "$_urp_rc" in
        0) : ;;
        1) _urp="" ;;
        *) blog_warn "Dotprofile resolver failed (exit $_urp_rc; details in ~/.aitools/logs/deploy.log) -- skipping deploy build; run 'aitools' (setup-user-config repairs config.json)"
           exit 0 ;;
    esac
fi
if [ -z "$_urp" ]; then
    blog_warn "No dotprofile found. Run 'aitools user init' first -- skipping deploy build."
    exit 0
fi
if [ ! -d "$_urp" ]; then
    blog_warn "Dotprofile $_urp (from $_urp_via) is not a directory -- skipping deploy build."
    exit 0
fi
DEPLOY_DIR="$_urp/deploy"
blog "Dotprofile: $_urp (via $_urp_via)"
blog "Build target: $DEPLOY_DIR (dotprofile repo)"

# --- User rules (embedded as a fallback; see "Embedded dotprofile content") ---
USER_RULE_COUNT=0
declare -a USER_RULE_FILES=()
if [ -d "$_urp/claude/rules" ]; then
    for rf in "$_urp/claude/rules"/*.md; do
        [ -f "$rf" ] || continue
        USER_RULE_FILES+=("$rf")
        USER_RULE_COUNT=$((USER_RULE_COUNT + 1))
    done
fi
if [ "$USER_RULE_COUNT" -gt 0 ]; then
    blog "User rules: $USER_RULE_COUNT files from $_urp/claude/rules"
else
    blog "No user rules in the dotprofile -- the deploy scripts embed none (a machine with the dotprofile still uses its own claude/rules/)"
fi

# --- Embedded dotprofile content: fallbacks, resolved per machine at RUNTIME ---
# deploy/ is committed once and used by every machine of this user, so no machine's
# values are interpolated here (M3 B5: the cross-machine defect, decision 4). The
# generated setup-user-claude.* resolve this machine's profile when they run: from
# the live dotprofile on that machine when it has one (what scripts/ reads), else
# from the build-time template, profile snapshot and rules embedded below.
TEMPLATE_FILE="$CLAUDE_SHARED"
TEMPLATE_LABEL="shared/claude-shared.md"
if [ -f "$_urp/claude/CLAUDE.md" ]; then
    TEMPLATE_FILE="$_urp/claude/CLAUDE.md"
    TEMPLATE_LABEL="dotprofile claude/CLAUDE.md"
fi
if [ ! -s "$TEMPLATE_FILE" ]; then
    blog_error "CLAUDE.md template is empty or unreadable: $TEMPLATE_FILE"
    exit 1
fi
blog "Template fallback: $TEMPLATE_LABEL (tokens resolved at runtime)"

# JSON reads use the resolver's JSON engine (core perl, every platform), not node.
JSON_PL="$SCRIPTS_DIR/aitools-json.pl"
PROFILE_JSON="$_urp/profile.json"
PROFILE_SNAPSHOT=""
# Cursor CLI preferences are user-level (profile.json cursor.cli), not per machine.
# They are the fallback values in the generated setup-user-cursor.*; a machine with
# the dotprofile reads its live profile.json, as scripts/ does.
CURSOR_CLI_VIMMODE=false
CURSOR_CLI_MODEL="auto"
if [ -f "$PROFILE_JSON" ]; then
    _pj_rc=0
    _pj_msg=$(perl "$JSON_PL" check "$PROFILE_JSON" 2>&1) || _pj_rc=$?
    if [ "$_pj_rc" -ne 0 ]; then
        blog_error "profile.json unreadable: $PROFILE_JSON (${_pj_msg:-engine exit $_pj_rc}) -- fix it before building deploy/"
        exit 1
    fi
    _pj_rc=0
    PROFILE_SNAPSHOT=$(perl "$JSON_PL" snapshot "$PROFILE_JSON") || _pj_rc=$?
    if [ "$_pj_rc" -ne 0 ] || [ -z "$PROFILE_SNAPSHOT" ]; then
        blog_error "Could not snapshot $PROFILE_JSON (engine exit $_pj_rc)"
        exit 1
    fi
    # type: exit 1 = absent or null (keep the default); other non-zero = engine error
    _pj_rc=0
    _pj_type=$(perl "$JSON_PL" type "$PROFILE_JSON" cursor cli vimMode) || _pj_rc=$?
    if [ "$_pj_rc" -eq 0 ] && [ "$_pj_type" = "boolean" ]; then
        CURSOR_CLI_VIMMODE=$(perl "$JSON_PL" get "$PROFILE_JSON" cursor cli vimMode) || {
            blog_error "Could not read cursor.cli.vimMode from $PROFILE_JSON"
            exit 1
        }
    elif [ "$_pj_rc" -gt 1 ]; then
        blog_error "Could not read cursor.cli.vimMode from $PROFILE_JSON (engine exit $_pj_rc)"
        exit 1
    fi
    _pj_rc=0
    _pj_type=$(perl "$JSON_PL" type "$PROFILE_JSON" cursor cli model) || _pj_rc=$?
    if [ "$_pj_rc" -eq 0 ] && [ "$_pj_type" = "string" ]; then
        _pj_model=$(perl "$JSON_PL" get "$PROFILE_JSON" cursor cli model) || {
            blog_error "Could not read cursor.cli.model from $PROFILE_JSON"
            exit 1
        }
        # The value becomes code (a JS and a PowerShell string literal): only a
        # plain model id is embedded.
        if printf '%s' "$_pj_model" | perl -ne 'exit(/\A[A-Za-z0-9._-]+\z/ ? 0 : 1)'; then
            CURSOR_CLI_MODEL="$_pj_model"
        else
            blog_warn "cursor.cli.model in $PROFILE_JSON is not a plain model id (letters, digits, . _ -) -- the deploy fallback stays 'auto'"
        fi
    elif [ "$_pj_rc" -gt 1 ]; then
        blog_error "Could not read cursor.cli.model from $PROFILE_JSON (engine exit $_pj_rc)"
        exit 1
    fi
    blog "Profile snapshot: $PROFILE_JSON (fallback for machines without the dotprofile)"
else
    blog_warn "No profile.json in $_urp -- the deploy scripts embed no profile snapshot"
fi
blog "Cursor CLI fallback prefs: vimMode=$CURSOR_CLI_VIMMODE model=$CURSOR_CLI_MODEL"

# Build scratch: embed blocks and pre-processed bodies (removed on exit)
if ! BUILD_TMP=$(mktemp -d "${TMPDIR:-/tmp}/build-deploy.XXXXXX"); then
    blog_error "mktemp -d failed -- cannot build deploy/"
    exit 1
fi
_cleanup_build_tmp() { rm -rf "$BUILD_TMP"; }
trap _cleanup_build_tmp EXIT

GENERATED=0

# Header for generated files
HEADER_COMMENT_BASH="# Generated by scripts/build-deploy.sh — do not edit directly."
HEADER_COMMENT_PS1="# Generated by scripts/build-deploy.sh — do not edit directly."

# ============================================================
# Sentinel-based extraction helper (Perl)
# ============================================================
# Extracts lines between two sentinel markers (exclusive of markers themselves).
# Uses Perl flip-flop operator for clean range extraction.
# Usage: extract_between FILE START_REGEX END_REGEX [--crlf]
#   --crlf: convert LF output to CRLF (for PS1 deploy scripts)
extract_between() {
    local file="$1" start="$2" end="$3" crlf="${4:-}"
    local result
    # Use m!...! as Perl regex delimiter to avoid conflicts with / in sentinels
    if [ "$crlf" = "--crlf" ]; then
        result=$(perl -ne '
            s/\r\n?$/\n/;
            if (m!'"$start"'! .. m!'"$end"'!) {
                next if m!'"$start"'! || m!'"$end"'!;
                s/\n$/\r\n/; print;
            }' "$file")
    else
        result=$(perl -ne '
            if (m!'"$start"'! .. m!'"$end"'!) {
                print unless m!'"$start"'! || m!'"$end"'!;
            }' "$file")
    fi
    if [ -z "$result" ]; then
        blog_error "Extraction failed: sentinels not found in $(basename "$file") (start: $start, end: $end)"
        exit 1
    fi
    printf '%s\n' "$result"
}

# ============================================================
# Embedded profile resolver (M3 B5; B8a INCIDENT)
# ============================================================
# Generated setup-user-claude/-settings/-cursor call the lib's resolver wrappers
# (resolve_user_repo_path, resolve_machine_profile). Those run aitools-profile.sh/.ps1
# as their own program, which loads aitools-lib and the JSON engine from its own
# directory. Each of those generated scripts therefore carries build-time COPIES of
# the three files (read from scripts/ here, so a resolver change flows through on
# the next build) and writes them to a private temp dir at runtime; the lib's lookup
# override (AITOOLS_PROFILE_SH / AITOOLS_PROFILE_PS1, PR #80) points at it.
# The block goes right after the inlined lib (inline_lib_* BLOCK_FILE): after the
# PowerShell param() and the lib, before any resolver call, and outside the inliner's
# pattern scan.
#   bash: one quoted heredoc per file; a file holding the delimiter line fails the build.
#   PowerShell: one here-string per file, every line prefixed with "|", so no line can
#   end the here-string ('@ at line start, review H1); the prefix and CRs are removed
#   when the file is written.
EMBED_EOF="__AITOOLS_EMBED_EOF__"
EMBED_MARKER="# --- Embedded profile resolver (generated by build-deploy.sh; M3 B5) ---"
RESOLVER_SH_FILES="aitools-profile.sh aitools-lib.sh aitools-json.pl"
RESOLVER_PS1_FILES="aitools-profile.ps1 aitools-lib.ps1 aitools-json.ps1"

# The resolver must not load a file the embed does not carry: every
# "$SCRIPT_DIR/<file>" (bash) and Join-Path $PSScriptRoot "<file>" (PowerShell) it
# names must be in the lists above (a future resolver change fails here, not on an
# endpoint).
_deps=$(perl -ne 'print "$1\n" while /\$SCRIPT_DIR\/([A-Za-z0-9._-]+)/g' "$SCRIPTS_DIR/aitools-profile.sh" | sort -u)
for _dep in $_deps; do
    case " $RESOLVER_SH_FILES " in
        *" $_dep "*) : ;;
        *) blog_error "aitools-profile.sh loads $_dep, which build-deploy does not embed -- add it to RESOLVER_SH_FILES"
           exit 1 ;;
    esac
done
_deps=$(perl -ne 'print "$1\n" while /Join-Path \$PSScriptRoot "([A-Za-z0-9._-]+)"/g' "$SCRIPTS_DIR/aitools-profile.ps1" | sort -u)
for _dep in $_deps; do
    case " $RESOLVER_PS1_FILES " in
        *" $_dep "*) : ;;
        *) blog_error "aitools-profile.ps1 loads $_dep, which build-deploy does not embed -- add it to RESOLVER_PS1_FILES"
           exit 1 ;;
    esac
done

# embed_file_bash REL SRC -- bash code that writes SRC's text (CRLF -> LF, one final
# newline) to "$_AITOOLS_EMBED_DIR/REL". REL is shell-quoted (printf %q).
embed_file_bash() {
    local rel="$1" src="$2"
    if perl -0777 -pe 's/\r\n/\n/g' "$src" | grep -qxF "$EMBED_EOF"; then
        blog_error "Cannot embed $src: it contains the heredoc delimiter line $EMBED_EOF"
        exit 1
    fi
    printf '    if [ -z "$_AITOOLS_EMBED_ERR" ] && ! cat > "$_AITOOLS_EMBED_DIR"/%s <<'"'"'%s'"'"'\n' "$(printf '%q' "$rel")" "$EMBED_EOF"
    perl -0777 -pe 's/\r\n/\n/g; s/\n?\z/\n/' "$src"
    printf '%s\n' "$EMBED_EOF"
    printf '    then _AITOOLS_EMBED_ERR="could not write an embedded file in $_AITOOLS_EMBED_DIR"; fi\n'
}

# embed_file_ps1 REL SRC -- PowerShell here-string entry $aitoolsEmbedFiles['REL']
embed_file_ps1() {
    local rel_q
    rel_q=$(printf '%s' "$1" | perl -pe "s/'/''/g")
    printf "\$aitoolsEmbedFiles['%s'] = @'\n" "$rel_q"
    perl -ne 's/\r?\n\z//; print "|$_\n"' "$2"
    printf "'@\n"
}

# write_resolver_block_bash OUT [claude] -- the bash embed block; "claude" adds the
# dotprofile fallbacks (template, profile snapshot, rules).
write_resolver_block_bash() {
    local out="$1" with_claude="${2:-}" f i
    {
        printf '%s\n' "$EMBED_MARKER"
        cat <<'BLOCK'
# Build-time copies of scripts/aitools-profile.sh, aitools-lib.sh and aitools-json.pl
# (the resolver runs as its own bash process and loads its lib and JSON engine from
# its own directory), written to a private temp dir; the lib's resolver lookup points
# there (AITOOLS_PROFILE_SH; a value the caller set wins). This runs before
# logging_init, so it uses no log helper: a failure is kept in _AITOOLS_EMBED_ERR and
# printed to stderr, and the resolver wrappers then report "resolver missing"
# (log_error + ERROR row). The EXIT trap removes the temp dir.
_AITOOLS_EMBED_DIR=""
_AITOOLS_EMBED_ERR=""
_aitools_embed_cleanup() { if [ -n "$_AITOOLS_EMBED_DIR" ]; then rm -rf "$_AITOOLS_EMBED_DIR"; fi; }
trap _aitools_embed_cleanup EXIT
if ! _AITOOLS_EMBED_DIR=$(mktemp -d "${TMPDIR:-/tmp}/aitools-embed.XXXXXX"); then
    _AITOOLS_EMBED_DIR=""
    _AITOOLS_EMBED_ERR="mktemp -d failed"
elif ! mkdir -p "$_AITOOLS_EMBED_DIR/claude" "$_AITOOLS_EMBED_DIR/shared" "$_AITOOLS_EMBED_DIR/rules"; then
    _AITOOLS_EMBED_ERR="mkdir failed in $_AITOOLS_EMBED_DIR"
fi
BLOCK
        for f in $RESOLVER_SH_FILES; do
            embed_file_bash "$f" "$SCRIPTS_DIR/$f"
        done
        if [ "$with_claude" = "claude" ]; then
            printf '# Dotprofile content at build time: fallbacks for a machine without the dotprofile\n'
            embed_file_bash "claude/CLAUDE.md" "$TEMPLATE_FILE"
            embed_file_bash "shared/claude-shared.md" "$CLAUDE_SHARED"
            if [ -n "$PROFILE_SNAPSHOT" ]; then
                embed_file_bash "profile.json" "$BUILD_TMP/profile-snapshot.json"
            fi
            for i in $(seq 0 $((USER_RULE_COUNT - 1))); do
                [ "$USER_RULE_COUNT" -gt 0 ] || break
                embed_file_bash "rules/$(basename "${USER_RULE_FILES[$i]}")" "${USER_RULE_FILES[$i]}"
            done
        fi
        cat <<'BLOCK'
if [ -z "$_AITOOLS_EMBED_ERR" ]; then
    if [ -z "${AITOOLS_PROFILE_SH:-}" ]; then export AITOOLS_PROFILE_SH="$_AITOOLS_EMBED_DIR/aitools-profile.sh"; fi
else
    printf 'aitools: embedded profile resolver not written (%s)\n' "$_AITOOLS_EMBED_ERR" >&2
fi
# --- End of embedded profile resolver ---
BLOCK
    } > "$out"
}

# write_resolver_block_ps1 OUT [claude] -- the PowerShell embed block (same content)
write_resolver_block_ps1() {
    local out="$1" with_claude="${2:-}" f i
    {
        printf '%s\n' "$EMBED_MARKER"
        cat <<'BLOCK'
# Build-time copies of scripts/aitools-profile.ps1, aitools-lib.ps1 and aitools-json.ps1
# (the resolver dot-sources its lib and JSON helpers from its own directory), written
# to a private temp dir; the lib's resolver lookup points there (AITOOLS_PROFILE_PS1;
# a value the caller set wins). Every embedded line carries a "|" prefix so no line
# can end its here-string; the prefix and CRs are removed when the file is written.
# This runs before Initialize-Logging, so a failure is kept in $aitoolsEmbedError and
# written to stderr; the resolver wrappers then report "resolver missing" (LogError +
# ERROR row). Remove-AitoolsEmbed (called before the exit footer) deletes the temp dir
# and restores the environment; an early exit leaves the temp dir behind (PowerShell
# has no EXIT trap; it holds only these build-time copies).
$aitoolsEmbedDir = Join-Path ([System.IO.Path]::GetTempPath()) ("aitools-embed-" + [guid]::NewGuid().ToString("N"))
$aitoolsEmbedError = ""
$aitoolsEmbedPrevProfilePs1 = $env:AITOOLS_PROFILE_PS1
$aitoolsEmbedPrevProfileFile = $env:AITOOLS_PROFILE_FILE
$aitoolsEmbedFiles = [ordered]@{}
BLOCK
        for f in $RESOLVER_PS1_FILES; do
            embed_file_ps1 "$f" "$SCRIPTS_DIR/$f"
        done
        if [ "$with_claude" = "claude" ]; then
            printf '# Dotprofile content at build time: fallbacks for a machine without the dotprofile\n'
            embed_file_ps1 "claude/CLAUDE.md" "$TEMPLATE_FILE"
            embed_file_ps1 "shared/claude-shared.md" "$CLAUDE_SHARED"
            if [ -n "$PROFILE_SNAPSHOT" ]; then
                embed_file_ps1 "profile.json" "$BUILD_TMP/profile-snapshot.json"
            fi
            for i in $(seq 0 $((USER_RULE_COUNT - 1))); do
                [ "$USER_RULE_COUNT" -gt 0 ] || break
                embed_file_ps1 "rules/$(basename "${USER_RULE_FILES[$i]}")" "${USER_RULE_FILES[$i]}"
            done
        fi
        cat <<'BLOCK'
try {
    foreach ($aitoolsEmbedName in $aitoolsEmbedFiles.Keys) {
        $aitoolsEmbedPath = Join-Path $aitoolsEmbedDir $aitoolsEmbedName
        $aitoolsEmbedParent = Split-Path -Parent $aitoolsEmbedPath
        if (-not (Test-Path -LiteralPath $aitoolsEmbedParent)) {
            New-Item -ItemType Directory -Path $aitoolsEmbedParent -Force -ErrorAction Stop | Out-Null
        }
        $aitoolsEmbedText = $aitoolsEmbedFiles[$aitoolsEmbedName] -replace "`r", ''
        if ($aitoolsEmbedText) { $aitoolsEmbedText = ($aitoolsEmbedText -replace '(?m)^\|', '') + "`n" }
        [System.IO.File]::WriteAllText($aitoolsEmbedPath, $aitoolsEmbedText, [System.Text.UTF8Encoding]::new($false))
    }
    if (-not $env:AITOOLS_PROFILE_PS1) { $env:AITOOLS_PROFILE_PS1 = Join-Path $aitoolsEmbedDir "aitools-profile.ps1" }
} catch {
    $aitoolsEmbedError = "$_"
    [Console]::Error.WriteLine("aitools: embedded profile resolver not written ($aitoolsEmbedError)")
}
function Remove-AitoolsEmbed {
    if (Test-Path -LiteralPath $script:aitoolsEmbedDir) {
        Remove-Item -LiteralPath $script:aitoolsEmbedDir -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $script:aitoolsEmbedDir) { LogWarn "Could not remove the embedded resolver temp dir $($script:aitoolsEmbedDir)" }
    }
    $env:AITOOLS_PROFILE_PS1 = $script:aitoolsEmbedPrevProfilePs1
    $env:AITOOLS_PROFILE_FILE = $script:aitoolsEmbedPrevProfileFile
}
# --- End of embedded profile resolver ---
BLOCK
    } > "$out"
}

if [ -n "$PROFILE_SNAPSHOT" ]; then
    printf '%s\n' "$PROFILE_SNAPSHOT" > "$BUILD_TMP/profile-snapshot.json"
fi
write_resolver_block_bash "$BUILD_TMP/resolver.sh.blk"
write_resolver_block_bash "$BUILD_TMP/resolver-claude.sh.blk" claude
write_resolver_block_ps1 "$BUILD_TMP/resolver.ps1.blk"
write_resolver_block_ps1 "$BUILD_TMP/resolver-claude.ps1.blk" claude
blog "Embedded resolver: $RESOLVER_SH_FILES / $RESOLVER_PS1_FILES (from scripts/)"

# PowerShell cleanup line emitted before each exit footer that embeds the resolver
EMBED_CLEANUP_PS1='Remove-AitoolsEmbed   # embedded resolver temp dir + environment (build-deploy, M3 B5)'

# Build into a staging dir; it replaces <dotprofile>/deploy only at the very end, so
# a build that fails anywhere (inputs, extraction, PS1 validation) leaves the
# committed deploy/ in place (review m1).
DEPLOY_DIR_FINAL="$DEPLOY_DIR"
DEPLOY_DIR="$BUILD_TMP/deploy"
mkdir -p "$DEPLOY_DIR"

# ============================================================
# 1. deploy/setup-user-claude.sh
# ============================================================
blog "Generating deploy/setup-user-claude.sh"

# Pure extract from scripts/setup-user-claude.sh (template interpolation, footer,
# managed-file deploy, rules logic: no duplicated logic, I6), plus two generated
# parts: the profile/template source on this machine (before the body) and the
# rules fallback (between the rules source selection and the rules logic).
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    cat <<'BLOCK'
# setup-user-claude.sh -- Creates user-level ~/.claude/CLAUDE.md and deploys user rules
# Self-contained (MDM-ready): the profile resolver and build-time copies of the
# dotprofile's CLAUDE.md template, profile snapshot and rules are embedded below.
# This machine's profile is resolved when the script runs, never at build time. On a
# machine with the dotprofile, its live template, profile.json and rules are used
# (as by scripts/setup-user-claude.sh); the embedded copies are the fallback.
# Safe to re-run.
#
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md (additive deploy from the rules source)
# Preserved: ~/.claude/rules/ files not in the rules source

set -euo pipefail

BLOCK
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^# --- BEGIN preamble' '^# --- END preamble'
    cat <<'BLOCK'

# --- Profile and template source on this machine (generated by build-deploy.sh) ---
# The live dotprofile on this machine wins (what scripts/setup-user-claude.sh reads);
# the build-time copies embedded above are the fallback. A dotprofile error ends the
# run here with the outcome setup-user-claude.sh gives it (same rows, exit 1).
if [ -n "$_AITOOLS_EMBED_ERR" ]; then log_detail "embedded profile resolver not written: $_AITOOLS_EMBED_ERR"; fi
_DP_RC=0
resolve_user_repo_path || _DP_RC=$?   # 1 = no dotprofile on this machine; 3 = logged error + ERROR row
if [ "$_DP_RC" -eq 3 ]; then
    log_error "CLAUDE.md and rules not deployed: the dotprofile could not be resolved"
    write_summary ERROR "claude.md" "not deployed: dotprofile unresolved"
    exit 1
fi
_DP_PATH="$AITLIB_USER_REPO_PATH"
if [ -n "${AITOOLS_PROFILE_FILE:-}" ]; then
    log "Profile source: AITOOLS_PROFILE_FILE ($(display_path "$AITOOLS_PROFILE_FILE"))"
elif [ -n "$_DP_PATH" ] && [ -f "$_DP_PATH/profile.json" ]; then
    log "Profile source: live $(display_path "$_DP_PATH/profile.json")"
elif [ "$_DP_RC" -ne 0 ] && [ -n "$_AITOOLS_EMBED_DIR" ] && [ -f "$_AITOOLS_EMBED_DIR/profile.json" ]; then
    export AITOOLS_PROFILE_FILE="$_AITOOLS_EMBED_DIR/profile.json"
    log "Profile source: embedded build-time snapshot (no dotprofile on this machine)"
else
    log "Profile source: none (no profile.json in this machine's dotprofile, or none embedded at build time)"
fi
# Template fallback, passed the way scripts/ takes one (the first non-flag argument).
# With a dotprofile on this machine the body reads its claude/CLAUDE.md and falls
# back, as scripts/ does, to shared/claude-shared.md (embedded copy). Without one,
# the build-time dotprofile template is used (review m3).
if [ -n "$_AITOOLS_EMBED_DIR" ]; then
    if [ "$_DP_RC" -eq 0 ]; then
        set -- "$@" "$_AITOOLS_EMBED_DIR/shared/claude-shared.md"
    else
        set -- "$@" "$_AITOOLS_EMBED_DIR/claude/CLAUDE.md"
        log "Template fallback: embedded build-time copy (no dotprofile on this machine)"
    fi
fi
BLOCK
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^# --- END preamble' '^# --- BEGIN rules deployment'
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^# --- BEGIN rules deployment' '^# --- BEGIN rules deploy logic'
    if [ "$USER_RULE_COUNT" -gt 0 ]; then
        cat <<'BLOCK'
# --- Rules fallback (generated by build-deploy.sh): the build-time copy when this
# machine has no dotprofile (a dotprofile without claude/rules/ deploys none, as
# scripts/ does; review m3) ---
if [ "$_DP_RC" -ne 0 ] && [ -z "$RULES_SRC" ] && [ -n "$_AITOOLS_EMBED_DIR" ] && [ -d "$_AITOOLS_EMBED_DIR/rules" ]; then
    RULES_SRC="$_AITOOLS_EMBED_DIR/rules"
    log "Rules source: embedded build-time copy (no dotprofile on this machine)"
fi
BLOCK
    fi
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^# --- BEGIN rules deploy logic' '^# --- END rules deploy logic'
    extract_between "$SCRIPTS_DIR/setup-user-claude.sh" \
        '^# --- BEGIN exit' '^# --- END exit'
} | inline_lib_bash "$BUILD_TMP/resolver-claude.sh.blk" > "$DEPLOY_DIR/setup-user-claude.sh"

chmod +x "$DEPLOY_DIR/setup-user-claude.sh"
GENERATED=$((GENERATED + 1))

# ============================================================
# 2. deploy/setup-user-claude.ps1
# ============================================================
blog "Generating deploy/setup-user-claude.ps1"

# Pure extract from scripts/setup-user-claude.ps1, plus the same two generated parts
# as the .sh (parity).
{
    echo "$HEADER_COMMENT_PS1"
    cat <<'BLOCK'
# setup-user-claude.ps1 -- Creates user-level ~/.claude/CLAUDE.md and deploys user rules
# Self-contained (MDM-ready): the profile resolver and build-time copies of the
# dotprofile's CLAUDE.md template, profile snapshot and rules are embedded below.
# This machine's profile is resolved when the script runs, never at build time. On a
# machine with the dotprofile, its live template, profile.json and rules are used
# (as by scripts/setup-user-claude.ps1); the embedded copies are the fallback.
# Safe to re-run.
#
# Managed: ~/.claude/CLAUDE.md (sole owner, overwrite)
# Managed: ~/.claude/rules/*.md (additive deploy from the rules source)
# Preserved: ~/.claude/rules/ files not in the rules source

param(
    [string]$SharedPath = "",
    [switch]$DryRun,
    [switch]$Force
)

BLOCK
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^# --- BEGIN preamble' '^# --- END preamble' --crlf
    cat <<'BLOCK'

# --- Profile and template source on this machine (generated by build-deploy.sh) ---
# The live dotprofile on this machine wins (what scripts/setup-user-claude.ps1 reads);
# the build-time copies embedded above are the fallback. A dotprofile error ends the
# run here with the outcome setup-user-claude.ps1 gives it (same rows, exit 1).
if ($aitoolsEmbedError) { LogDetail "embedded profile resolver not written: $aitoolsEmbedError" }
$aitoolsDpRc = Resolve-UserRepoPath   # 1 = no dotprofile on this machine; 3 = logged error + ERROR row
if ($aitoolsDpRc -eq 3) {
    LogError "CLAUDE.md and rules not deployed: the dotprofile could not be resolved"
    Write-Summary "ERROR" "claude.md" "not deployed: dotprofile unresolved"
    Remove-AitoolsEmbed
    exit 1
}
$aitoolsDpPath = $script:AitLibUserRepoPath
$aitoolsSnapshot = Join-Path $aitoolsEmbedDir "profile.json"
if ($env:AITOOLS_PROFILE_FILE) {
    Log "Profile source: AITOOLS_PROFILE_FILE ($($env:AITOOLS_PROFILE_FILE))"
} elseif ($aitoolsDpPath -and (Test-Path -LiteralPath (Join-Path $aitoolsDpPath "profile.json"))) {
    Log "Profile source: live $(Join-Path $aitoolsDpPath 'profile.json')"
} elseif ($aitoolsDpRc -ne 0 -and (Test-Path -LiteralPath $aitoolsSnapshot)) {
    $env:AITOOLS_PROFILE_FILE = $aitoolsSnapshot
    Log "Profile source: embedded build-time snapshot (no dotprofile on this machine)"
} else {
    Log "Profile source: none (no profile.json in this machine's dotprofile, or none embedded at build time)"
}
# Template fallback, passed the way scripts/ takes one (-SharedPath). With a dotprofile
# on this machine the body reads its claude/CLAUDE.md and falls back, as scripts/
# does, to shared/claude-shared.md (embedded copy). Without one, the build-time
# dotprofile template is used (review m3).
if (-not $SharedPath) {
    if ($aitoolsDpRc -eq 0) {
        $SharedPath = Join-Path (Join-Path $aitoolsEmbedDir "shared") "claude-shared.md"
    } else {
        $SharedPath = Join-Path (Join-Path $aitoolsEmbedDir "claude") "CLAUDE.md"
        Log "Template fallback: embedded build-time copy (no dotprofile on this machine)"
    }
}
BLOCK
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^# --- END preamble' '^# --- BEGIN rules deployment' --crlf
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^# --- BEGIN rules deployment' '^# --- BEGIN rules deploy logic' --crlf
    if [ "$USER_RULE_COUNT" -gt 0 ]; then
        cat <<'BLOCK'
# --- Rules fallback (generated by build-deploy.sh): the build-time copy when this
# machine has no dotprofile (a dotprofile without claude/rules/ deploys none, as
# scripts/ does; review m3) ---
$aitoolsEmbedRules = Join-Path $aitoolsEmbedDir "rules"
if ($aitoolsDpRc -ne 0 -and -not $rulesSrc -and (Test-Path -LiteralPath $aitoolsEmbedRules)) {
    $rulesSrc = $aitoolsEmbedRules
    Log "Rules source: embedded build-time copy (no dotprofile on this machine)"
}
BLOCK
    fi
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^# --- BEGIN rules deploy logic' '^# --- END rules deploy logic' --crlf
    printf '%s\n' "$EMBED_CLEANUP_PS1"
    extract_between "$SCRIPTS_DIR/setup-user-claude.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 "$BUILD_TMP/resolver-claude.ps1.blk" > "$DEPLOY_DIR/setup-user-claude.ps1"

GENERATED=$((GENERATED + 1))

# ============================================================
# 3. deploy/setup-user-cursor.sh
# ============================================================
blog "Generating deploy/setup-user-cursor.sh"

# The cursor body is extracted whole (the profile preferences block included, so a
# machine with the dotprofile reads its live profile.json cursor.cli, as scripts/
# does). Only the block's two default values are replaced with the build-time
# profile values (the fallback for a machine without the dotprofile).
# subst_cursor_defaults FILE BEGIN_RE END_RE VIM_OLD VIM_NEW MODEL_OLD MODEL_NEW:
# replace, inside the BEGIN..END block, the line VIM_OLD with VIM_NEW and MODEL_OLD
# with MODEL_NEW (whole lines, leading spaces kept); exit 3 unless each is replaced
# exactly once.
subst_cursor_defaults() {
    perl -e '
        my ($file, $b, $e, $vo, $vn, $mo, $mn) = @ARGV;
        open my $fh, "<", $file or die "Cannot open $file: $!";
        my ($nv, $nm) = (0, 0);
        while (my $l = <$fh>) {
            if ($l =~ /$b/ .. $l =~ /$e/) {
                if ($l =~ /^(\s*)\Q$vo\E(\r?\n)\z/) { $l = "$1$vn$2"; $nv++ }
                elsif ($l =~ /^(\s*)\Q$mo\E(\r?\n)\z/) { $l = "$1$mn$2"; $nm++ }
            }
            print $l;
        }
        exit(($nv == 1 && $nm == 1) ? 0 : 3);
    ' "$@"
}
_cursor_rc=0
extract_between "$SCRIPTS_DIR/setup-user-cursor.sh" \
    '^# --- BEGIN cursor body' '^# --- END cursor body' > "$BUILD_TMP/cursor-body.sh"
subst_cursor_defaults "$BUILD_TMP/cursor-body.sh" '^// --- BEGIN profile preferences' '^// --- END profile preferences' \
    "let vimMode = false;" "let vimMode = $CURSOR_CLI_VIMMODE;   // build-time fallback (profile.json cursor.cli)" \
    "let modelId = 'auto';" "let modelId = '$CURSOR_CLI_MODEL';   // build-time fallback (profile.json cursor.cli)" \
    > "$BUILD_TMP/cursor-body-fallback.sh" || _cursor_rc=$?
if [ "$_cursor_rc" -ne 0 ]; then
    blog_error "setup-user-cursor.sh: the profile preferences defaults (let vimMode = false; / let modelId = 'auto';) were not found exactly once -- update build-deploy.sh"
    exit 1
fi

{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    cat <<'BLOCK'
# setup-user-cursor.sh — Sets up Cursor CLI + dependencies on macOS/Linux
# Self-contained (MDM-ready): the profile resolver is embedded below; the cursor.cli
# preferences come from this machine's dotprofile when it has one, else from the
# build-time values. Safe to re-run — checks each step and skips what's already done.
#
# Does three things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Merges preferences into ~/.cursor/cli-config.json (preserves CLI-managed fields)

BLOCK
    cat "$BUILD_TMP/cursor-body-fallback.sh"
    # Exit footer
    extract_between "$SCRIPTS_DIR/setup-user-cursor.sh" \
        '^# --- BEGIN exit' '^# --- END exit'
} | inline_lib_bash "$BUILD_TMP/resolver.sh.blk" > "$DEPLOY_DIR/setup-user-cursor.sh"

chmod +x "$DEPLOY_DIR/setup-user-cursor.sh"
GENERATED=$((GENERATED + 1))

# ============================================================
# 4. deploy/setup-user-cursor.ps1
# ============================================================
blog "Generating deploy/setup-user-cursor.ps1"

_cursor_rc=0
extract_between "$SCRIPTS_DIR/setup-user-cursor.ps1" \
    '^# --- BEGIN cursor body' '^# --- END cursor body' --crlf > "$BUILD_TMP/cursor-body.ps1"
subst_cursor_defaults "$BUILD_TMP/cursor-body.ps1" '^# --- BEGIN profile preferences' '^# --- END profile preferences' \
    '$vimMode = $false' "\$vimMode = \$$CURSOR_CLI_VIMMODE   # build-time fallback (profile.json cursor.cli)" \
    '$modelId = "auto"' "\$modelId = \"$CURSOR_CLI_MODEL\"   # build-time fallback (profile.json cursor.cli)" \
    > "$BUILD_TMP/cursor-body-fallback.ps1" || _cursor_rc=$?
if [ "$_cursor_rc" -ne 0 ]; then
    blog_error "setup-user-cursor.ps1: the profile preferences defaults (\$vimMode = \$false / \$modelId = \"auto\") were not found exactly once -- update build-deploy.sh"
    exit 1
fi

{
    echo "$HEADER_COMMENT_PS1"
    cat <<'BLOCK'
# setup-user-cursor.ps1 — Sets up Cursor CLI + dependencies on Windows
# Self-contained (MDM-ready): the profile resolver is embedded below; the cursor.cli
# preferences come from this machine's dotprofile when it has one, else from the
# build-time values. Safe to re-run — checks each step and skips what's already done.
#
# Does three things:
#   1. Installs ripgrep (rg) if not already present (required by Cursor CLI)
#   2. Installs Cursor CLI (agent command) if not already present
#   3. Merges preferences into ~/.cursor/cli-config.json (preserves CLI-managed fields)
#
# Managed fields: version, editor.vimMode, permissions, model, hasChangedDefaultModel
# Preserved: authInfo, privacyCache, network, statsigBootstrap, maxMode, all other fields

BLOCK
    cat "$BUILD_TMP/cursor-body-fallback.ps1"
    printf '%s\r\n' "$EMBED_CLEANUP_PS1"
    # Exit footer
    extract_between "$SCRIPTS_DIR/setup-user-cursor.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 "$BUILD_TMP/resolver.ps1.blk" > "$DEPLOY_DIR/setup-user-cursor.ps1"

GENERATED=$((GENERATED + 1))

# ============================================================
# 5-6. deploy/setup-cursor-ide-mcp.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-cursor-ide-mcp.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    # Strip the shebang from source and inline lib
    tail -n +2 "$SCRIPTS_DIR/setup-cursor-ide-mcp.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-cursor-ide-mcp.sh"
chmod +x "$DEPLOY_DIR/setup-cursor-ide-mcp.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-cursor-ide-mcp.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-cursor-ide-mcp.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-cursor-ide-mcp.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 7-8. deploy/setup-vercelcli.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-vercelcli.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-vercelcli.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-vercelcli.sh"
chmod +x "$DEPLOY_DIR/setup-vercelcli.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-vercelcli.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-vercelcli.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-vercelcli.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 9-10. deploy/setup-pandoc.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-pandoc.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-pandoc.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-pandoc.sh"
chmod +x "$DEPLOY_DIR/setup-pandoc.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-pandoc.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-pandoc.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-pandoc.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 11-12. deploy/setup-rust.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-rust.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-rust.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-rust.sh"
chmod +x "$DEPLOY_DIR/setup-rust.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-rust.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-rust.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-rust.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 13-14. deploy/setup-typst.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-typst.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-typst.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-typst.sh"
chmod +x "$DEPLOY_DIR/setup-typst.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-typst.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-typst.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-typst.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 15-16. deploy/setup-gh-cli.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-gh-cli.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-gh-cli.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-gh-cli.sh"
chmod +x "$DEPLOY_DIR/setup-gh-cli.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-gh-cli.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-gh-cli.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-gh-cli.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 17-18. deploy/setup-python.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-python.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-python.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-python.sh"
chmod +x "$DEPLOY_DIR/setup-python.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-python.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-python.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-python.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 19-20. deploy/setup-uv.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-uv.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-uv.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-uv.sh"
chmod +x "$DEPLOY_DIR/setup-uv.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-uv.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-uv.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-uv.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 21-22. deploy/setup-modal.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-modal.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-modal.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-modal.sh"
chmod +x "$DEPLOY_DIR/setup-modal.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-modal.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-modal.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-modal.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 23-24. deploy/setup-go.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-go.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-go.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-go.sh"
chmod +x "$DEPLOY_DIR/setup-go.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-go.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-go.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-go.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 25-26. deploy/setup-datadog.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-datadog.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-datadog.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-datadog.sh"
chmod +x "$DEPLOY_DIR/setup-datadog.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-datadog.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-datadog.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-datadog.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 27-28. deploy/setup-perl.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-perl.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-perl.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-perl.sh"
chmod +x "$DEPLOY_DIR/setup-perl.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-perl.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-perl.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-perl.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 29-30. deploy/setup-bash.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-bash.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-bash.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-bash.sh"
chmod +x "$DEPLOY_DIR/setup-bash.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-bash.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-bash.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-bash.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# deploy/setup-google-chrome.sh and .ps1 (copy as-is)
# ============================================================
blog "Copying deploy/setup-google-chrome.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-google-chrome.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-google-chrome.sh"
chmod +x "$DEPLOY_DIR/setup-google-chrome.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-google-chrome.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-google-chrome.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-google-chrome.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# deploy/setup-user-shell.sh and .ps1 (copy as-is) -- login-profile PATH block
# ============================================================
blog "Copying deploy/setup-user-shell.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    tail -n +2 "$SCRIPTS_DIR/setup-user-shell.sh" | inline_lib_bash
} > "$DEPLOY_DIR/setup-user-shell.sh"
chmod +x "$DEPLOY_DIR/setup-user-shell.sh"
GENERATED=$((GENERATED + 1))

blog "Copying deploy/setup-user-shell.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    cat "$SCRIPTS_DIR/setup-user-shell.ps1" | inline_lib_ps1
} > "$DEPLOY_DIR/setup-user-shell.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 31-32. deploy/setup-user-mcp.sh and .ps1 (MCP only, skills moved to setup-user-skills)
# ============================================================

blog "Generating deploy/setup-user-mcp.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    extract_between "$SCRIPTS_DIR/setup-user-mcp.sh" \
        '^# --- BEGIN mcp body' '^# --- END mcp body'
    extract_between "$SCRIPTS_DIR/setup-user-mcp.sh" \
        '^# --- BEGIN exit' '^# --- END exit'
} | inline_lib_bash > "$DEPLOY_DIR/setup-user-mcp.sh"
chmod +x "$DEPLOY_DIR/setup-user-mcp.sh"
GENERATED=$((GENERATED + 1))

blog "Generating deploy/setup-user-mcp.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    extract_between "$SCRIPTS_DIR/setup-user-mcp.ps1" \
        '^# --- BEGIN mcp body' '^# --- END mcp body' --crlf
    extract_between "$SCRIPTS_DIR/setup-user-mcp.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 > "$DEPLOY_DIR/setup-user-mcp.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# deploy/setup-user-settings.sh and .ps1 (settings.json <-> profile.json sync)
# ============================================================
# Self-contained via inline_lib_* (sync_managed_json + prompt_json_field_review) and
# the embedded profile resolver. Finds profile.json at runtime through the one
# dotprofile resolver (resolve_user_repo_path / Resolve-UserRepoPath, SD-7) -- no
# build-time value embedding (adopt writes back to the live profile.json, so there
# is no snapshot fallback; without a dotprofile the sync is skipped, as on scripts/).
blog "Generating deploy/setup-user-settings.sh"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    extract_between "$SCRIPTS_DIR/setup-user-settings.sh" \
        '^# --- BEGIN settings body' '^# --- END settings body'
    extract_between "$SCRIPTS_DIR/setup-user-settings.sh" \
        '^# --- BEGIN exit' '^# --- END exit'
} | inline_lib_bash "$BUILD_TMP/resolver.sh.blk" > "$DEPLOY_DIR/setup-user-settings.sh"
chmod +x "$DEPLOY_DIR/setup-user-settings.sh"
GENERATED=$((GENERATED + 1))

blog "Generating deploy/setup-user-settings.ps1"
{
    echo "$HEADER_COMMENT_PS1"
    extract_between "$SCRIPTS_DIR/setup-user-settings.ps1" \
        '^# --- BEGIN settings body' '^# --- END settings body' --crlf
    printf '%s\r\n' "$EMBED_CLEANUP_PS1"
    extract_between "$SCRIPTS_DIR/setup-user-settings.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 "$BUILD_TMP/resolver.ps1.blk" > "$DEPLOY_DIR/setup-user-settings.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 31-32. deploy/setup-user-skills.sh and .ps1 (with dynamically embedded skills)
# ============================================================
# The scripts/ versions discover skills from shared/skills/ at runtime.
# The deploy/ versions embed all SKILL.md content at build time for self-contained deployment.

blog "Generating deploy/setup-user-skills.sh (with embedded skills)"
{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    # Extract boilerplate (flag parsing, lib, OS guard, DRY_RUN)
    extract_between "$SCRIPTS_DIR/setup-user-skills.sh" \
        '^# --- BEGIN skills body' '^# --- BEGIN skill discovery'

    # Emit self-contained skills deployment using heredocs
    cat <<'SKILLS_HEADER'

# --- Deploy skills (embedded at build time) ---

SKILLS_DEST="$HOME/.claude/skills"
SKILLS_DEST_CURSOR="$HOME/.cursor/skills"
ALL_SKILL_DESTS="$SKILLS_DEST $SKILLS_DEST_CURSOR"

SKILLS_HEADER
    # Emit helper function for diff-reviewed embedded skill deployment.
    # Takes a content FILE path (not a string) to avoid bash 3.2
    # parsing issues with $(cat <<'EOF') command substitution.
    cat <<'DEPLOY_SKILL_FUNC'
deploy_embedded_skill() {
    local skill_name="$1"
    local dest_base="$2"
    local tool_name="$3"
    local content_file="$4"

    local dest_dir="$dest_base/$skill_name"
    local dest="$dest_dir/SKILL.md"

    # No adopt target: the file read here is the build-time embed, not a repo
    # file (contract default #9), so adopt and merge are not offered.
    deploy_managed_file "$(cat "$content_file")" "$dest" "$tool_name" "$skill_name" ""

    case "$MANAGED_FILE_RESULT" in
        created|updated|verified|skipped|failed|"accept & adopt")
            # The tracker records the outcome (failed -> ERROR row).
            ;;
    esac
    deploy_tracker_record "$MANAGED_FILE_RESULT" "$tool_name" "$skill_name"
}

DEPLOY_SKILL_FUNC

    # Dynamically discover and embed all skills from shared/skills/
    _embedded_skills=""
    echo '_skill_tmp=$(mktemp -d)'
    for _skill_dir in "$SHARED_DIR/skills"/*/; do
        [ -d "$_skill_dir" ] || continue
        _sname=$(basename "$_skill_dir")
        _sfile="$_skill_dir/SKILL.md"
        [ -f "$_sfile" ] || continue
        _heredoc_marker="__SKILL_$(echo "$_sname" | tr '[:lower:]-' '[:upper:]_')__"
        echo "cat > \"\$_skill_tmp/${_sname}.md\" <<'${_heredoc_marker}'"
        cat "$_sfile"
        echo "${_heredoc_marker}"
        echo ''
        _embedded_skills="$_embedded_skills $_sname"
    done
    _embedded_skills="${_embedded_skills# }"

    # Deploy to ~/.claude/skills/ (Claude Code)
    echo 'log "Deploying skills to $SKILLS_DEST..."'
    echo 'ERRORS_BEFORE_CLAUDE_SKILLS=$ERRORS'
    echo 'deploy_tracker_init'
    for _sname in $_embedded_skills; do
        echo "deploy_embedded_skill \"$_sname\" \"\$SKILLS_DEST\" \"claude skills\" \"\$_skill_tmp/${_sname}.md\""
    done
    echo 'if [ "$ERRORS" -eq "$ERRORS_BEFORE_CLAUDE_SKILLS" ]; then'
    echo '    deploy_tracker_summary "claude skills"'
    echo 'else'
    echo '    write_summary ERROR "claude skills" "deploy failed"'
    echo 'fi'
    echo ''

    # Deploy to ~/.cursor/skills/ (Cursor Agent CLI)
    echo 'log "Deploying skills to $SKILLS_DEST_CURSOR..."'
    echo 'ERRORS_BEFORE_CURSOR_SKILLS=$ERRORS'
    echo 'deploy_tracker_init'
    for _sname in $_embedded_skills; do
        echo "deploy_embedded_skill \"$_sname\" \"\$SKILLS_DEST_CURSOR\" \"cursor skills\" \"\$_skill_tmp/${_sname}.md\""
    done
    echo 'if [ "$ERRORS" -eq "$ERRORS_BEFORE_CURSOR_SKILLS" ]; then'
    echo '    deploy_tracker_summary "cursor skills"'
    echo 'else'
    echo '    write_summary ERROR "cursor skills" "deploy failed"'
    echo 'fi'
    echo ''
    echo 'rm -rf "$_skill_tmp"'
    echo ''

    # Emit exit footer from source
    extract_between "$SCRIPTS_DIR/setup-user-skills.sh" \
        '^# --- BEGIN exit' '^# --- END exit'
} | inline_lib_bash > "$DEPLOY_DIR/setup-user-skills.sh"
chmod +x "$DEPLOY_DIR/setup-user-skills.sh"
GENERATED=$((GENERATED + 1))

blog "Generating deploy/setup-user-skills.ps1 (with embedded skills)"
{
    echo "$HEADER_COMMENT_PS1"
    # Extract boilerplate (param, lib, OS guard, DRY_RUN)
    extract_between "$SCRIPTS_DIR/setup-user-skills.ps1" \
        '^# --- BEGIN skills body' '^# --- BEGIN skill discovery' --crlf

    # Emit self-contained skills deployment using PS1 here-strings
    cat <<'SKILLS_PS1_HEADER'

# --- Deploy skills (embedded at build time) ---

$skillsDest = Join-Path (Join-Path $env:USERPROFILE ".claude") "skills"
$skillsDestCursor = Join-Path (Join-Path $env:USERPROFILE ".cursor") "skills"
$allSkillDests = @($skillsDest, $skillsDestCursor)

SKILLS_PS1_HEADER
    # Emit helper function for diff-reviewed embedded skill deployment
    cat <<'DEPLOY_SKILL_PS1_FUNC'
function Deploy-EmbeddedSkill {
    param([string]$SkillName, [string]$DestBase, [string]$ToolName, [string]$Content)

    $destDir = Join-Path $DestBase $SkillName
    $dest = Join-Path $destDir "SKILL.md"

    # No adopt target: the content here is the build-time embed, not a repo
    # file (contract default #9), so adopt and merge are not offered.
    $skillResult = Deploy-ManagedFile -Content $Content -DestPath $dest -ToolName $ToolName -ItemName $SkillName -AdoptPath ""

    if ($skillResult -in @("created", "updated", "verified", "skipped", "failed", "accept & adopt")) {
        # The tracker records the outcome (failed -> ERROR row).
    }
    Record-DeployOutcome -Outcome $skillResult -ToolName $ToolName -ItemName $SkillName
}

DEPLOY_SKILL_PS1_FUNC

    # Dynamically discover and embed all skills from shared/skills/
    _embedded_skills=""
    for _skill_dir in "$SHARED_DIR/skills"/*/; do
        [ -d "$_skill_dir" ] || continue
        _sname=$(basename "$_skill_dir")
        _sfile="$_skill_dir/SKILL.md"
        [ -f "$_sfile" ] || continue
        # PS1 variable name: convert dashes to underscores
        _varname=$(echo "$_sname" | tr '-' '_')
        echo "\$skill_${_varname} = @'"
        cat "$_sfile"
        echo "'@"
        echo ''
        _embedded_skills="$_embedded_skills ${_sname}|${_varname}"
    done
    _embedded_skills="${_embedded_skills# }"

    # Deploy to ~/.claude/skills/ (Claude Code)
    echo 'Log "Deploying skills to $skillsDest..."'
    echo '$errorsBeforeClaudeSkills = $errors'
    echo 'Initialize-DeployTracker'
    for _pair in $_embedded_skills; do
        _sname="${_pair%%|*}"
        _varname="${_pair##*|}"
        echo "Deploy-EmbeddedSkill \"$_sname\" \$skillsDest \"claude skills\" \$skill_${_varname}"
    done
    echo 'if ($errors -eq $errorsBeforeClaudeSkills) {'
    echo '    Write-DeployTrackerSummary -ToolName "claude skills"'
    echo '} else {'
    echo '    Write-Summary "ERROR" "claude skills" "deploy failed"'
    echo '}'
    echo ''

    # Deploy to ~/.cursor/skills/ (Cursor Agent CLI)
    echo 'Log "Deploying skills to $skillsDestCursor..."'
    echo '$errorsBeforeCursorSkills = $errors'
    echo 'Initialize-DeployTracker'
    for _pair in $_embedded_skills; do
        _sname="${_pair%%|*}"
        _varname="${_pair##*|}"
        echo "Deploy-EmbeddedSkill \"$_sname\" \$skillsDestCursor \"cursor skills\" \$skill_${_varname}"
    done
    echo 'if ($errors -eq $errorsBeforeCursorSkills) {'
    echo '    Write-DeployTrackerSummary -ToolName "cursor skills"'
    echo '} else {'
    echo '    Write-Summary "ERROR" "cursor skills" "deploy failed"'
    echo '}'
    echo ''

    # Emit exit footer from source (CRLF for PS1)
    extract_between "$SCRIPTS_DIR/setup-user-skills.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 > "$DEPLOY_DIR/setup-user-skills.ps1"
GENERATED=$((GENERATED + 1))

# ============================================================
# 15. deploy/setup-user-hooks.sh (extracted from scripts/ + embedded hooks)
# ============================================================
blog "Generating deploy/setup-user-hooks.sh (extracted + embedded hooks)"

{
    echo '#!/usr/bin/env bash'
    echo "$HEADER_COMMENT_BASH"
    cat <<'BLOCK'
# setup-user-hooks.sh -- Deploys Claude Code hooks to ~/.claude/settings.json
# Self-contained: hook scripts are embedded below. No repo needed.
# Safe to re-run -- merges the `hooks` key without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, hooks.SessionStart, hooks.PreToolUse, hooks.PostToolUse, hooks.Stop
# Preserved: permissions, enabledPlugins, all other fields (prefs synced by setup-user-settings)
#
# Hooks deployed: every hook registered in shared/hooks/hooks-manifest.json
# at build time (embedded below), plus its deploy-only helper scripts.

BLOCK
    # Extract: set -euo pipefail, flag parsing, logging, OS guard, DRY_RUN, require node
    extract_between "$SCRIPTS_DIR/setup-user-hooks.sh" \
        '^# --- BEGIN hooks body' '^# --- BEGIN hook deployment'

    # REPLACE: hook deployment (deploy embeds scripts via heredoc instead of cp from repo)
    cat <<'BLOCK'
# --- Deploy embedded hook scripts to ~/.claude/hooks/ (generated from manifest) ---
HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"

if [ "$DRY_RUN" = "true" ]; then
    log "[DRY RUN] Would deploy hooks to $HOOKS_DIR"
else
BLOCK
    # Embed each hook + helper from the manifest (single source of truth).
    # Heredoc per file with a unique delimiter derived from the filename.
    _MANIFEST="$SHARED_DIR/hooks/hooks-manifest.json"
    while IFS= read -r _hookfile; do
        [ -n "$_hookfile" ] || continue
        if [ -f "$SHARED_DIR/hooks/$_hookfile" ]; then
            _src="$SHARED_DIR/hooks/$_hookfile"
        elif [ -f "$SCRIPTS_DIR/$_hookfile" ]; then
            _src="$SCRIPTS_DIR/$_hookfile"
        else
            # Unreachable after the manifest preflight; fail loudly (never skip)
            # so a future edit to one side cannot reintroduce a silent drop.
            # exit leaves the { } | inline_lib_bash subshell; pipefail + set -e
            # then abort the build.
            blog_error "Hook source not found for embed: $_hookfile"
            exit 1
        fi
        _delim="__EMB_$(echo "$_hookfile" | tr 'a-z.-' 'A-Z__')__"
        echo "cat > \"\$HOOKS_DIR/$_hookfile\" <<'${_delim}'"
        cat "$_src"
        # Guarantee the delimiter lands on its own line even when the source hook
        # lacks a trailing newline (POSIX-incomplete file) -- otherwise the heredoc
        # never closes and the generated script is unparseable.
        [ -n "$(tail -c1 "$_src")" ] && echo ""
        echo "$_delim"
    done < <(node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));console.log([...m.hooks.map(h=>h.file),...((m.deploy)||[])].join("\n"))' "$_MANIFEST")
    cat <<'BLOCK'

    for _hf in "$HOOKS_DIR"/*.sh; do
        [ -f "$_hf" ] || continue
        chmod +x "$_hf"
        log_ok "Deployed hook: $_hf"
    done
fi
BLOCK
    # Embed REGS_JSON (registration list) at build time from the manifest, so the
    # self-contained deploy script needs no manifest at runtime. The node merge
    # block reads it from argv -- identical to the dev path.
    _REGS=$(node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));console.log(JSON.stringify(m.hooks.map(h=>({event:h.event,file:h.file,matcher:h.matcher||""}))))' "$SHARED_DIR/hooks/hooks-manifest.json")
    echo ""
    echo "# Registration list embedded from hooks-manifest.json at build time."
    echo "REGS_JSON='$_REGS'"
    echo ""

    # Extract: merge section (settings.json hooks merge, mergeHookEntry, clobber,
    # validation) + case statement. Prefs are no longer handled here -- they are
    # profile-sourced and synced by setup-user-settings.
    extract_between "$SCRIPTS_DIR/setup-user-hooks.sh" \
        '^# --- END hook deployment' '^# --- END hooks body'

    # Extract: exit footer
    extract_between "$SCRIPTS_DIR/setup-user-hooks.sh" \
        '^# --- BEGIN exit' '^# --- END exit'
} | inline_lib_bash > "$DEPLOY_DIR/setup-user-hooks.sh"

chmod +x "$DEPLOY_DIR/setup-user-hooks.sh"
GENERATED=$((GENERATED + 1))

# ============================================================
# 16. deploy/setup-user-hooks.ps1 (extracted from scripts/ + embedded hooks)
# ============================================================
blog "Generating deploy/setup-user-hooks.ps1 (extracted + embedded hooks)"

{
    echo "$HEADER_COMMENT_PS1"
    cat <<'BLOCK'
# setup-user-hooks.ps1 -- Deploys Claude Code hooks to ~/.claude/settings.json
# Self-contained: hook scripts are embedded below. No repo needed.
# Safe to re-run -- merges the `hooks` key without clobbering existing settings.
#
# Managed fields: hooks.SessionEnd, hooks.SessionStart, hooks.PreToolUse, hooks.PostToolUse, hooks.Stop
# Preserved: permissions, enabledPlugins, all other fields (prefs synced by setup-user-settings)
#
# Hooks deployed: every hook registered in shared/hooks/hooks-manifest.json
# at build time (embedded below), plus its deploy-only helper scripts.
#
# Note: Hook scripts are bash-only (Claude Code hooks always run in bash on
# both platforms). This PS1 script only deploys the hook configuration.

BLOCK
    # Extract: param(), logging, OS guard, ConvertPSObjectToHashtable, DRY_RUN
    extract_between "$SCRIPTS_DIR/setup-user-hooks.ps1" \
        '^# --- BEGIN hooks body' '^# --- BEGIN hook deployment' --crlf

    # REPLACE: hook deployment (deploy embeds scripts via here-string + manifest-driven $regs)
    printf '# --- Deploy embedded hook scripts to ~/.claude/hooks/ (generated from manifest) ---\r\n'
    printf '$claudeDir = Join-Path $env:USERPROFILE ".claude"\r\n'
    printf '$hooksDir = Join-Path $claudeDir "hooks"\r\n'
    printf 'if (-not (Test-Path $hooksDir)) { New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null }\r\n'
    printf '\r\n'
    printf '$hookFiles = @{}\r\n'
    # Embed each hook + helper from the manifest (single source of truth).
    _PS_MANIFEST="$SHARED_DIR/hooks/hooks-manifest.json"
    while IFS= read -r _hookfile; do
        [ -n "$_hookfile" ] || continue
        if [ -f "$SHARED_DIR/hooks/$_hookfile" ]; then
            _src="$SHARED_DIR/hooks/$_hookfile"
        elif [ -f "$SCRIPTS_DIR/$_hookfile" ]; then
            _src="$SCRIPTS_DIR/$_hookfile"
        else
            # Unreachable after the manifest preflight; fail loudly (never skip)
            # so a future edit to one side cannot reintroduce a silent drop.
            # exit leaves the { } pipeline subshell; pipefail + set -e then abort
            # the build.
            blog_error "Hook source not found for PS1 embed: $_hookfile"
            exit 1
        fi
        printf '$hookFiles["%s"] = @'"'"'\r\n' "$_hookfile"
        perl -pe 's/\r?\n$/\r\n/' "$_src"
        # Guarantee the here-string terminator ('@) lands on its own line even when
        # the source hook lacks a trailing newline.
        [ -n "$(tail -c1 "$_src")" ] && printf '\r\n'
        printf ''"'"'@\r\n'
        printf '\r\n'
    done < <(node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));console.log([...m.hooks.map(h=>h.file),...((m.deploy)||[])].join("\n"))' "$_PS_MANIFEST")
    printf 'if ($DryRun) {\r\n'
    printf '    Log "[DRY RUN] Would deploy hooks to ~/.claude/hooks/"\r\n'
    printf '} else {\r\n'
    printf '    foreach ($hName in $hookFiles.Keys) {\r\n'
    printf '        $hDest = Join-Path $hooksDir $hName\r\n'
    printf '        $hResolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($hDest)\r\n'
    printf '        [System.IO.File]::WriteAllText($hResolved, $hookFiles[$hName], [System.Text.UTF8Encoding]::new($false))\r\n'
    printf '        LogOk "Deployed hook: $hDest"\r\n'
    printf '    }\r\n'
    printf '}\r\n'
    printf '\r\n'
    # Embed $regs (registration list) at build time from the manifest, so the
    # self-contained deploy script needs no manifest at runtime.
    printf '# Registration list embedded from hooks-manifest.json at build time.\r\n'
    printf '$regs = @(\r\n'
    while IFS= read -r _line; do
        [ -n "$_line" ] || continue
        printf '%s\r\n' "$_line"
    done < <(node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));for(const h of m.hooks){console.log("    [pscustomobject]@{ event = \""+h.event+"\"; file = \""+h.file+"\"; matcher = \""+(h.matcher||"")+"\" }")}' "$SHARED_DIR/hooks/hooks-manifest.json")
    printf ')\r\n'

    printf '\r\n'

    # Extract: merge section (settings.json hooks merge, MergeHookEntry, clobber,
    # validation). Prefs are no longer handled here -- they are profile-sourced
    # and synced by setup-user-settings.
    extract_between "$SCRIPTS_DIR/setup-user-hooks.ps1" \
        '^# --- END hook deployment' '^# --- END hooks body' --crlf

    # Extract: exit footer
    extract_between "$SCRIPTS_DIR/setup-user-hooks.ps1" \
        '^# --- BEGIN exit' '^# --- END exit' --crlf
} | inline_lib_ps1 > "$DEPLOY_DIR/setup-user-hooks.ps1"

GENERATED=$((GENERATED + 1))

# ============================================================
# Post-build: the embedded resolver is in every script that calls it, once
# ============================================================
# A generation invariant, not a run: the generated scripts are smoke-run by
# check-pre-push step 7 (keeps this script a pure generator).
for _emb in setup-user-claude.sh setup-user-claude.ps1 setup-user-settings.sh setup-user-settings.ps1 \
    setup-user-cursor.sh setup-user-cursor.ps1; do
    _emb_count=$(EMB_MARK="$EMBED_MARKER" perl -ne '$n++ if /^\Q$ENV{EMB_MARK}\E\r?$/; END { print $n + 0 }' "$DEPLOY_DIR/$_emb")
    if [ "$_emb_count" != "1" ]; then
        blog_error "deploy/$_emb holds the embedded profile resolver $_emb_count time(s), expected 1 (the line naming aitools-lib must appear exactly once in its source)"
        exit 1
    fi
done
blog_ok "Embedded profile resolver present once in each resolver-consuming deploy script"

# ============================================================
# Post-build: Validate PS1 syntax (Windows only)
# ============================================================
# On Windows (Git Bash), validate all generated .ps1 files with ParseFile.
# Catches encoding issues and syntax errors at build time rather than install time.
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        blog "Validating generated PS1 scripts..."
        PS1_ERRORS=0
        for ps1_file in "$DEPLOY_DIR"/*.ps1; do
            [ -f "$ps1_file" ] || continue
            ps1_name=$(basename "$ps1_file")
            if ! pwsh -NoProfile -Command "
                \$e = \$null
                \$null = [System.Management.Automation.Language.Parser]::ParseFile('$(cygpath -w "$ps1_file")', [ref]\$null, [ref]\$e)
                if (\$e.Count -gt 0) {
                    foreach (\$err in \$e) { Write-Host \"  line \$(\$err.Extent.StartLineNumber): \$(\$err.Message)\" }
                    exit 1
                }
            " 2>/dev/null; then
                blog_error "$ps1_name has parse errors on this PowerShell version"
                PS1_ERRORS=$((PS1_ERRORS + 1))
            fi
        done
        if [ "$PS1_ERRORS" -gt 0 ]; then
            blog_error "$PS1_ERRORS PS1 file(s) failed validation"
            exit 1
        else
            blog_ok "All PS1 files passed validation"
        fi
        ;;
    *)
        # macOS/Linux: Validate PS1 via pwsh (managed tool)
        if command -v pwsh &>/dev/null; then
            blog "Validating generated PS1 scripts via pwsh..."
            PS1_ERRORS=0
            for ps1_file in "$DEPLOY_DIR"/*.ps1; do
                [ -f "$ps1_file" ] || continue
                ps1_name=$(basename "$ps1_file")
                errors_output=$(pwsh -NoProfile -Command "
                    \$e = \$null
                    \$null = [System.Management.Automation.Language.Parser]::ParseFile('$ps1_file', [ref]\$null, [ref]\$e)
                    if (\$e.Count -gt 0) {
                        foreach (\$err in \$e) { Write-Host \"  line \$(\$err.Extent.StartLineNumber): \$(\$err.Message)\" }
                        exit 1
                    }
                " 2>&1) || {
                    blog_error "$ps1_name has parse errors:"
                    echo "$errors_output"
                    PS1_ERRORS=$((PS1_ERRORS + 1))
                }
            done
            if [ "$PS1_ERRORS" -gt 0 ]; then
                blog_error "$PS1_ERRORS PS1 file(s) failed validation"
                exit 1
            else
                blog_ok "All PS1 files passed validation (pwsh)"
            fi
        else
            blog_warn "pwsh not found -- PS1 validation skipped (install: brew install powershell/tap/powershell)"
        fi
        ;;
esac

# ============================================================
# Post-build: Fix file permissions and line endings
# ============================================================
# 1. Ensure all .sh files are executable on disk (Write tool creates 100644)
chmod +x "$DEPLOY_DIR"/*.sh 2>/dev/null || true
blog_ok "Set +x on all .sh files in deploy/"

# 2. Convert deploy/*.ps1 to CRLF (.gitattributes requires eol=crlf)
#    build-deploy.sh writes LF; without this, git sees them as modified.
#    PERLIO=:perlio (set at top) prevents Strawberry Perl text-mode double-CR.
perl -pi -e 's/(?<!\r)\n/\r\n/' "$DEPLOY_DIR"/*.ps1
blog_ok "Converted deploy/*.ps1 to CRLF"

# Swap the staged build in
if ! rm -rf "$DEPLOY_DIR_FINAL"; then
    blog_error "Could not remove $DEPLOY_DIR_FINAL -- deploy/ not replaced"
    exit 1
fi
if ! mv "$DEPLOY_DIR" "$DEPLOY_DIR_FINAL"; then
    blog_error "Could not move the build into $DEPLOY_DIR_FINAL"
    exit 1
fi
DEPLOY_DIR="$DEPLOY_DIR_FINAL"

blog_ok "Build complete: $GENERATED scripts generated in deploy/"
ls -la "$DEPLOY_DIR/"
blog "Scripts are self-contained and ready for MDM deployment"
