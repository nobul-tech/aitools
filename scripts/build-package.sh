#!/usr/bin/env bash
# build-package.sh -- build aitools packages: macOS .pkg, Windows .intunewin, Ubuntu .deb
#
# A parallel, package-based distribution of aitools for a fleet. Contract:
# BP-1..BP-20 in .aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/
# S3-BuildPkg/S3-BuildPkg-decisions.md; plan: plans/build-package/. The payload
# is the public aitools tree at a pinned git ref (BP-1), never the dotprofile
# deploy/. This script never calls build-deploy.sh (BP-2).
#
# VERSION 1.0 SCAFFOLDING (batch B0): argument parsing, validation, host
# detection, the --dry-run plan, summary rows and the exit footer are real.
# Staging and the three package builds are stubs that log an ERROR and exit 1:
# stage = batch B2, pkg = B8, intune = B9, deb = B10
# (plans/build-package/implementation-plan.md).
#
# Safe to re-run: writes only under --out (nothing yet in v1.0) and the log
#   directory; installs nothing; never touches the dotprofile.
# Platform: macOS, Linux and Windows (Git Bash). A bash-only build script like
#   build-deploy.sh: no .ps1 twin and no OS guard (exemption row pending
#   approval P-1 in .claude/rules/cross-platform.md). A kind builds only on its
#   native host with its native tool (BP-4); `all` reports the other kinds as
#   OK "n/a (<host>)".
# Tools: pkgbuild + productbuild (macOS, OS-provided), IntuneWinAppUtil.exe
#   (Windows; /tool-eval and the Phase 2 gate pending, P-4), dpkg-deb (Ubuntu,
#   OS-provided). Nothing is installed here; managed tools: /tool-registry skill.
# Logging: ~/.aitools/logs/deploy.log via logging_init (BP-16). Summary rows
#   under the tool name "build-package"; the panel is shown when the caller
#   did not set AITOOLS_SUMMARY_FILE.
#
# Usage: build-package.sh <command> [options]
#   Commands:
#     stage    stage the payload: git archive at --ref, MANIFEST, BUILD-INFO (BP-1)
#     pkg      macOS unmanaged .pkg for Intune and Jamf (pkgbuild, productbuild)
#     intune   Windows Win32 apps A (system) and B (user), .intunewin (IntuneWinAppUtil.exe)
#     deb      Ubuntu 22.04/24.04 .deb, Architecture all (dpkg-deb)
#     all      stage, then every kind this host can build; the others report n/a
#   Options:
#     --ref <git-ref>       payload source (default: HEAD)
#     --version <X.Y.Z>     release version (digits only); required for pkg, intune, deb, all
#     --out <dir>           output directory (default: ${TMPDIR:-/tmp}/aitools-build-package/out)
#     --intune-tool <path>  IntuneWinAppUtil.exe to use (default: found on PATH)
#     --dry-run             log the plan of actions; build nothing (also AITOOLS_DRY_RUN=1)
#     --help, -h            show this help
# Exit: 0 done (warnings possible); 1 errors (bad arguments, a requested kind
#   this host cannot build, a step not built or not implemented). Never 2,
#   which means a user abort (D-TS13).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/aitools-lib.sh"
logging_init "build-package"

# --- OS handling ---
# No OS guard: this build script runs on macOS, Linux and Windows Git Bash
# (header). What this host can build is detected per kind (detect_kind).
HOST="$AITOOLS_PLATFORM"   # macos | linux | windows | unknown

TOOL="build-package"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PKG_ID="tech.nobul.aitools"   # BP-17
ALL_KINDS="pkg intune deb"
# Tracked paths copied into the payload when present at the ref (BP-1).
PAYLOAD_PATHS="scripts shared reference registries .claude/rules .claude/skills .claude/hooks"
TMP_BASE="${TMPDIR:-/tmp}"
TMP_BASE="${TMP_BASE%/}"

usage() {
    # The header comment (line 2 to the first non-comment line), "# " removed.
    perl -ne 'next if $. == 1; last unless /^#/; s/^# ?//; print' "$SCRIPT_DIR/build-package.sh"
}

# usage_brief -- the "Usage:" block of the header only (for argument errors).
usage_brief() {
    perl -ne 'next if $. == 1; last unless /^#/; $u = 1 if /^# Usage:/; next unless $u; s/^# ?//; print' "$SCRIPT_DIR/build-package.sh"
}

# short TEXT -- a summary detail of at most 30 characters (script-standards).
short() {
    local s="$1"
    if [ "${#s}" -gt 30 ]; then s="${s:0:27}..."; fi
    printf '%s' "$s"
}

# --help wins over everything else and writes nothing but the log line.
for arg in "$@"; do
    case "$arg" in
        --help|-h) usage; exit 0 ;;
    esac
done

# Standalone run: own summary file, shown before the exit footer.
OWN_SUMMARY=false
if [ -z "${AITOOLS_SUMMARY_FILE:-}" ]; then
    if AITOOLS_SUMMARY_FILE=$(mktemp "$TMP_BASE/build-package-summary.XXXXXX"); then
        export AITOOLS_SUMMARY_FILE
        OWN_SUMMARY=true
        trap 'rm -f "$AITOOLS_SUMMARY_FILE"' EXIT
    else
        AITOOLS_SUMMARY_FILE=""
        log_warn "Could not create a summary file in $TMP_BASE -- no summary panel"
    fi
fi

# =========================================================================
# 1. Arguments
# =========================================================================
COMMAND=""
REF="HEAD"
VERSION=""
OUT=""
INTUNE_TOOL=""
DRY_RUN=false
BAD_ARGS=false
if [ "${AITOOLS_DRY_RUN:-}" = "1" ]; then DRY_RUN=true; fi

bad_arg() {
    log_error "$1 (see --help)"
    BAD_ARGS=true
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --ref|--version|--out|--intune-tool)
            opt="$1"
            val="${2:-}"
            case "$val" in
                ""|--*)
                    bad_arg "Option $opt needs a value"
                    shift
                    continue ;;
            esac
            case "$opt" in
                --ref)         REF="$val" ;;
                --version)     VERSION="$val" ;;
                --out)         OUT="$val" ;;
                --intune-tool) INTUNE_TOOL="$val" ;;
            esac
            shift ;;
        -*) bad_arg "Unknown option: $1" ;;
        stage|pkg|intune|deb|all)
            if [ -n "$COMMAND" ]; then
                bad_arg "One command only (got $COMMAND and $1)"
            else
                COMMAND="$1"
            fi ;;
        *) bad_arg "Unknown command: $1" ;;
    esac
    shift
done

if ! $BAD_ARGS && [ -z "$COMMAND" ]; then
    bad_arg "No command given (stage, pkg, intune, deb or all)"
fi

# =========================================================================
# 2. Validation (every problem is reported, then the run stops)
# =========================================================================
COMMIT=""
VERSION_RE='^[0-9]+\.[0-9]+\.[0-9]+$'
if [ -n "$VERSION" ]; then
    if ! [[ "$VERSION" =~ $VERSION_RE ]]; then
        bad_arg "--version '$VERSION' is not X.Y.Z (digits only, no 'v' prefix)"
    fi
elif [ -n "$COMMAND" ] && [ "$COMMAND" != "stage" ]; then
    bad_arg "--version <X.Y.Z> is required for '$COMMAND'"
fi

if [ -z "$OUT" ]; then OUT="$TMP_BASE/aitools-build-package/out"; fi
if [ -e "$OUT" ] && [ ! -d "$OUT" ]; then
    bad_arg "--out $(display_path "$OUT") exists and is not a directory"
fi

if [ -n "$INTUNE_TOOL" ] && [ ! -f "$INTUNE_TOOL" ]; then
    bad_arg "--intune-tool $INTUNE_TOOL: file not found"
fi

# The ref must name a commit in this repo (read-only check, also in a dry run).
# Command-existence check with explicit fallback (the else branch).
if command -v git >/dev/null 2>&1; then
    if ! COMMIT=$(git -C "$REPO_DIR" rev-parse --verify --quiet "${REF}^{commit}" 2>&1); then
        log_error "--ref '$REF' is not a commit in $(display_path "$REPO_DIR")${COMMIT:+: $COMMIT}"
        BAD_ARGS=true
        COMMIT=""
    fi
else
    log_error "git not found -- the payload is a git archive of --ref (BP-1)"
    BAD_ARGS=true
fi

if $BAD_ARGS; then
    usage_brief >&2
    write_summary ERROR "$TOOL" "bad arguments"
fi

# =========================================================================
# 3. Host capability per kind (BP-4: native host + native tool)
# =========================================================================
# detect_kind KIND -- sets KIND_OK (true|false), KIND_WHY (reason when false)
# and KIND_TOOL (the tool path when true). Each `command -v` below is a
# command-existence check whose fallback is the "not found" branch.
detect_kind() {
    KIND_OK=false
    KIND_WHY=""
    KIND_TOOL=""
    case "$1" in
        pkg)
            if [ "$HOST" != "macos" ]; then
                KIND_WHY="builds on macOS only (BP-4)"
            elif ! command -v pkgbuild >/dev/null 2>&1; then
                KIND_WHY="pkgbuild not found"
            elif ! command -v productbuild >/dev/null 2>&1; then
                KIND_WHY="productbuild not found"
            else
                KIND_OK=true
                KIND_TOOL="$(command -v pkgbuild)"
            fi ;;
        intune)
            if [ "$HOST" != "windows" ]; then
                KIND_WHY="builds on Windows only (BP-4; IntuneWinAppUtil needs .NET Framework)"
                if [ -n "$INTUNE_TOOL" ]; then log "intune: --intune-tool ignored on $HOST"; fi
            elif [ -n "$INTUNE_TOOL" ]; then
                KIND_OK=true
                KIND_TOOL="$INTUNE_TOOL"
            elif command -v IntuneWinAppUtil.exe >/dev/null 2>&1; then
                KIND_OK=true
                KIND_TOOL="$(command -v IntuneWinAppUtil.exe)"
            elif command -v IntuneWinAppUtil >/dev/null 2>&1; then
                KIND_OK=true
                KIND_TOOL="$(command -v IntuneWinAppUtil)"
            else
                KIND_WHY="IntuneWinAppUtil.exe not found (PATH or --intune-tool)"
            fi ;;
        deb)
            if [ "$HOST" != "linux" ]; then
                KIND_WHY="builds on Ubuntu only (BP-4)"
            elif ! command -v dpkg-deb >/dev/null 2>&1; then
                KIND_WHY="dpkg-deb not found"
            else
                KIND_OK=true
                KIND_TOOL="$(command -v dpkg-deb)"
            fi ;;
    esac
}

# =========================================================================
# 4. Steps. Each prints its plan in a dry run; the real work is a stub.
# =========================================================================
plan() { log "[DRY RUN] $1"; }

not_implemented() {  # KIND BATCH
    log_error "$1: not implemented in v1.0 scaffolding (batch $2, plans/build-package/implementation-plan.md)"
    write_summary ERROR "$TOOL" "$(short "$1: not implemented")"
    return 1
}

STAGE_DIR=""

stage_payload() {
    STAGE_DIR="$OUT/stage"
    if ! $DRY_RUN; then
        not_implemented stage B2
        return 1
    fi
    local short_commit="${COMMIT:0:12}" p present="" absent=""
    for p in $PAYLOAD_PATHS; do
        # 2>/dev/null: cat-file -e reports a path absent at the ref on stderr;
        # the exit status is the answer and is checked here.
        if git -C "$REPO_DIR" cat-file -e "$COMMIT:$p" 2>/dev/null; then
            present="${present:+$present }$p"
        else
            absent="${absent:+$absent }$p"
        fi
    done
    plan "stage: 1. resolve --ref $REF -> commit $short_commit"
    plan "stage: 2. git archive $short_commit -- $present -> $(display_path "$STAGE_DIR/repo") (tracked files only)"
    if [ -n "$absent" ]; then plan "stage:    not at this ref (skipped): $absent"; fi
    plan "stage: 3. write MANIFEST (git ls-files at $short_commit for those paths)"
    plan "stage: 4. write BUILD-INFO (version=${VERSION:-none} commit=$short_commit date=<UTC ...Z> kind=<kind>) and VERSION"
    plan "stage: 5. hygiene: no ._* AppleDouble files, no extended attributes (COPYFILE_DISABLE=1)"
    plan "stage: 6. verify: no personal data -- no dotprofile, no deploy/ (BP-1)"
    return 0
}

build_pkg() {
    if ! $DRY_RUN; then
        not_implemented pkg B8
        return 1
    fi
    local root="$OUT/pkg/root" asd="/Library/Application Support/aitools"
    plan "pkg: 1. lay out $(display_path "$root"): $asd/{VERSION,repo/,bin/aitools-pkg-run.sh,aitools.app} + /Library/LaunchAgents/$PKG_ID.firstrun.plist (BP-7)"
    plan "pkg: 2. stub app $PKG_ID: CFBundleShortVersionString = CFBundleVersion = $VERSION (BP-12, BP-15)"
    plan "pkg: 3. scripts: packaging/macos/postinstall (root: payload, VERSION, console user, launchctl asuser; BP-7)"
    plan "pkg: 4. pkgbuild --root <root> --identifier $PKG_ID --version $VERSION --install-location / --scripts <scripts> (BP-17)"
    plan "pkg: 5. productbuild --package <component.pkg> -> $(display_path "$OUT")/aitools-$VERSION.pkg"
    plan "pkg: 6. gates: pkgutil --payload-files has no '/._'; PackageInfo identifier/version; stub version = $VERSION; pkgutil --check-signature exits 1 (unsigned, BP-20)"
    log "pkg: tool $(display_path "$KIND_TOOL")"
    return 0
}

build_intune() {
    if ! $DRY_RUN; then
        not_implemented intune B9
        return 1
    fi
    plan "intune: 1. app A (system) folder $(display_path "$OUT/intune/system"): packaging/windows/install-system.ps1 + payload (BP-7)"
    plan "intune: 2. IntuneWinAppUtil -c <system> -s install-system.ps1 -o <out>/intune -q -> aitools-system-$VERSION.intunewin"
    plan "intune: 3. app B (user) folder $(display_path "$OUT/intune/user"): packaging/windows/install-user.ps1 (BP-7, BP-14)"
    plan "intune: 4. IntuneWinAppUtil -c <user> -s install-user.ps1 -o <out>/intune -q -> aitools-user-$VERSION.intunewin"
    plan "intune: 5. copy packaging/windows/detect-user.ps1 next to the outputs (app B detection script, uploaded separately)"
    plan "intune: 6. detection to configure: A = HKLM\\SOFTWARE\\aitools Version = $VERSION; B = detect-user.ps1 (BP-15)"
    log "intune: tool $(display_path "$KIND_TOOL")"
    return 0
}

build_deb() {
    if ! $DRY_RUN; then
        not_implemented deb B10
        return 1
    fi
    local root="$OUT/deb/root"
    plan "deb: 1. lay out $(display_path "$root"): /opt/aitools/{repo/,VERSION}, /usr/bin/aitools-setup (BP-7)"
    plan "deb: 2. DEBIAN/control from packaging/linux/control.in (@VERSION@ = $VERSION; Architecture all; BP-8, BP-9)"
    plan "deb: 3. DEBIAN/postinst from packaging/linux/postinst (0755; files only, no per-user work)"
    plan "deb: 4. dpkg-deb --root-owner-group --build <root> $(display_path "$OUT")/aitools_${VERSION}_all.deb"
    plan "deb: 5. gates: dpkg-deb --field Package/Version/Architecture = aitools/$VERSION/all; no ._* files (BP-15)"
    log "deb: tool $(display_path "$KIND_TOOL")"
    return 0
}

# =========================================================================
# 5. Run
# =========================================================================
if ! $BAD_ARGS; then
    if $DRY_RUN; then log "[DRY RUN] Plan only -- nothing is staged or built"; fi
    log "Command: $COMMAND, host: $HOST, ref: $REF (${COMMIT:0:12}), version: ${VERSION:-none}, out: $(display_path "$OUT")"

    EXPLICIT=true
    KINDS=""
    case "$COMMAND" in
        stage) KINDS="" ;;
        all)   KINDS="$ALL_KINDS"; EXPLICIT=false ;;
        *)     KINDS="$COMMAND" ;;
    esac

    BUILDABLE=""
    for kind in $KINDS; do
        detect_kind "$kind"
        if $KIND_OK; then
            BUILDABLE="${BUILDABLE:+$BUILDABLE }$kind"
            log "$kind: buildable on $HOST ($(display_path "$KIND_TOOL"))"
        elif $EXPLICIT; then
            log_error "$kind: cannot build on this host ($HOST): $KIND_WHY"
            write_summary ERROR "$TOOL" "$(short "$kind: cannot build ($HOST)")"
        else
            log "$kind: n/a on $HOST: $KIND_WHY"
            write_summary OK "$TOOL" "$(short "$kind: n/a ($HOST)")"
        fi
    done

    if [ -n "$KINDS" ] && [ -z "$BUILDABLE" ] && $EXPLICIT; then
        log "Nothing to build -- staging skipped"
    elif stage_payload; then
        DONE="stage"
        for kind in $BUILDABLE; do
            detect_kind "$kind"
            if "build_$kind"; then
                DONE="$DONE, $kind"
            fi
        done
        if $DRY_RUN; then
            write_summary OK "$TOOL" "$(short "dry-run: $DONE")"
        fi
    else
        for kind in $BUILDABLE; do
            log_error "$kind: not built -- staging failed"
            write_summary ERROR "$TOOL" "$(short "$kind: not built (no stage)")"
        done
    fi
fi

# =========================================================================
# 6. Summary panel (standalone run) + exit footer
# =========================================================================
if $OWN_SUMMARY; then show_summary; fi

if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s)" "error"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    log "COMPLETED with $WARNINGS warning(s)" "warn"
    exit 0
else
    log "COMPLETED successfully" "ok"
    exit 0
fi
