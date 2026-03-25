#!/usr/bin/env bash
# harvest-session.sh — Claude Code SessionEnd hook
# Classifies session scratch contents, harvests artifacts, cleans up,
# audits the harvesting/ directory, marks session complete in harness DB,
# and exports DB to JSON for git carry-forward.
#
# Design decisions:
#   - Silent exit on errors (hook must never break Claude Code)
#   - Only harvests if project has a harvesting/ directory
#   - Classification by file extension (code/scripts -> artifact, logs/msgs -> ephemeral)
#   - Pure-bash JSON parsing (jq not guaranteed in hook environment)
#   - Manifest updates via node (already required by aitools)
#   - SQLite session end + export is additive (OBSERVE mode, never blocks)
#   - harness-db.py stderr is NOT suppressed — safety warnings must surface
#   - No rm -rf of session dirs (30-file-loss fix, session Z1IhGrcgGO, 2026-03-21)

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# --- Pure-bash JSON field extraction ---
json_field() {
    local json="$1" key="$2"
    local val
    val=$(printf '%s' "$json" \
        | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
        | head -1 \
        | sed 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"//' \
        | sed 's/"$//')
    printf '%s' "$val"
}

SESSION_ID=$(json_field "$INPUT" "session_id")
CWD=$(json_field "$INPUT" "cwd")

# Session ID prefix for filenames (first 10 chars, matching scratch dir suffix)
SESSION_PREFIX=""
if [ -n "$SESSION_ID" ]; then
    SESSION_PREFIX=$(printf '%s' "$SESSION_ID" | cut -c1-10)
fi

# Find project root
PROJECT_ROOT=$(cd "$CWD" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || echo "$CWD")
SCRATCH_DIR="$PROJECT_ROOT/.scratch"

# --- Find session scratch dir ---
# Try session_id-based dir first (new pattern), then .current-session (legacy)
SESSION_DIR=""
if [ -n "$SESSION_PREFIX" ] && [ -d "$SCRATCH_DIR/session-$SESSION_PREFIX" ]; then
    SESSION_DIR="$SCRATCH_DIR/session-$SESSION_PREFIX"
elif [ -f "$SCRATCH_DIR/.current-session" ]; then
    SESSION_DIR=$(cat "$SCRATCH_DIR/.current-session" 2>/dev/null || echo "")
fi

# If no session dir or it doesn't exist, nothing to do
if [ -z "$SESSION_DIR" ] || [ ! -d "$SESSION_DIR" ]; then
    # Still mark session as ended in DB even if no scratch dir
    _mark_session_end=true
else
    _mark_session_end=false
fi

# --- Check if project supports harvesting ---
HARVESTING_DIR="$PROJECT_ROOT/harvesting"
HAS_HARVESTING=false
if [ -d "$HARVESTING_DIR" ]; then
    HAS_HARVESTING=true
fi

# --- Handoff destination ---
HANDOFFS_DIR="$PROJECT_ROOT/.aitools/channel/handoffs"

# --- Classify and process session dir contents ---
TODAY=$(date -u +%Y-%m-%d)
HARVESTED=0
DELETED=0

if [ -n "$SESSION_DIR" ] && [ -d "$SESSION_DIR" ]; then
    for file in "$SESSION_DIR"/*; do
        [ -f "$file" ] || continue
        filename=$(basename "$file")

        # Classification by extension and name
        is_ephemeral=true
        case "$filename" in
            commit-msg*|*.log|*.tmp)
                is_ephemeral=true
                ;;
            *.py|*.sh|*.ps1|*.js|*.ts|*.go|*.rs|*.pl)
                is_ephemeral=false
                ;;
            *.json)
                # JSON: config/lock files are ephemeral, structured data is artifact
                case "$filename" in
                    package-lock*|node_modules*|*.config.json|tsconfig*) is_ephemeral=true ;;
                    *) is_ephemeral=false ;;
                esac
                ;;
            *.md)
                # Markdown: logs are ephemeral, research/analysis is artifact
                case "$filename" in
                    *log*|*output*|*dump*) is_ephemeral=true ;;
                    *) is_ephemeral=false ;;
                esac
                ;;
            *.yaml|*.yml|*.toml|*.csv|*.sql|*.html|*.txt)
                is_ephemeral=false
                ;;
            *)
                # Unknown extension: harvest with warning rather than silently delete
                is_ephemeral=false
                ;;
        esac

        if $is_ephemeral; then
            DELETED=$((DELETED + 1))
            continue
        fi

        # --- Route non-ephemeral files ---

        # Handoff files go to .aitools/channel/handoffs/ (dedicated location)
        is_handoff=false
        case "$filename" in
            handoff*) is_handoff=true ;;
        esac

        if $is_handoff; then
            # Auto-create handoffs dir if it doesn't exist
            if [ ! -d "$HANDOFFS_DIR" ]; then
                mkdir -p "$HANDOFFS_DIR" 2>/dev/null || true
            fi
        fi
        if $is_handoff && [ -d "$HANDOFFS_DIR" ]; then
            # Handoff: copy to handoffs/ with session ID
            handoff_dest="${HANDOFFS_DIR}/${TODAY}_session-${SESSION_PREFIX}_${filename}"
            cp "$file" "$handoff_dest" 2>/dev/null || true
            HARVESTED=$((HARVESTED + 1))
            continue
        fi

        # Auto-create harvesting/ on first harvest (F2 from issue #54)
        if ! $HAS_HARVESTING; then
            mkdir -p "$HARVESTING_DIR" 2>/dev/null
            if [ -d "$HARVESTING_DIR" ]; then
                HAS_HARVESTING=true
            fi
            # Create minimal manifest
            if command -v node >/dev/null 2>&1; then
                MANIFEST="$HARVESTING_DIR/harvest-manifest.json"
                node -e "
const fs = require('fs');
const f = process.argv[1];
if (!fs.existsSync(f)) {
    fs.writeFileSync(f, JSON.stringify({ meta: { schemaVersion: '1.0', lastAudit: null }, artifacts: {} }, null, 2) + '\n');
}
" "$MANIFEST" 2>/dev/null || true
            fi
            printf '[harvest] Created harvesting/ directory in %s\n' "$PROJECT_ROOT" >&2
        fi

        if $HAS_HARVESTING; then
            # Harvest: copy to harvesting/ with date + session ID prefix
            session_tag=""
            if [ -n "$SESSION_PREFIX" ]; then
                session_tag="session-${SESSION_PREFIX}_"
            fi
            dest_name="${TODAY}_${session_tag}${filename}"
            dest_path="$HARVESTING_DIR/$dest_name"

            # Avoid overwrites
            if [ -f "$dest_path" ]; then
                counter=1
                while [ -f "${HARVESTING_DIR}/${TODAY}_${counter}_${session_tag}${filename}" ]; do
                    counter=$((counter + 1))
                done
                dest_name="${TODAY}_${counter}_${session_tag}${filename}"
                dest_path="$HARVESTING_DIR/$dest_name"
            fi

            cp "$file" "$dest_path"

            # Update manifest if node is available
            MANIFEST="$HARVESTING_DIR/harvest-manifest.json"
            if command -v node >/dev/null 2>&1; then
                # Derive session reference
                session_ref=""
                if [ -n "$CWD" ]; then
                    project_name=$(basename "$PROJECT_ROOT")
                    session_ref="${project_name}/${TODAY}_${SESSION_PREFIX}"
                fi

                node -e "
const fs = require('fs');
const f = process.argv[1];
const name = process.argv[2];
const session = process.argv[3];
const desc = process.argv[4];
const today = process.argv[5];

let manifest = { meta: { schemaVersion: '1.0', lastAudit: null }, artifacts: {} };
try { manifest = JSON.parse(fs.readFileSync(f, 'utf8')); } catch {}

manifest.artifacts[name] = {
    harvested: today,
    session: session,
    description: 'Auto-harvested from session scratch',
    type: 'code',
    language: null,
    status: 'harvested',
    promotedTo: null,
    pruneAfter: new Date(Date.now() + 30*24*60*60*1000).toISOString().split('T')[0]
};

// Detect language from extension
const ext = name.split('.').pop();
const langMap = { py: 'python', sh: 'bash', ps1: 'powershell', js: 'javascript', ts: 'typescript', go: 'go', rs: 'rust', pl: 'perl', md: 'markdown' };
if (langMap[ext]) manifest.artifacts[name].language = langMap[ext];

fs.writeFileSync(f, JSON.stringify(manifest, null, 2) + '\n');
" "$MANIFEST" "$dest_name" "$session_ref" "$filename" "$TODAY" 2>/dev/null || true
            fi

            HARVESTED=$((HARVESTED + 1))
        fi
    done
fi

# --- Report harvest results (F4 from issue #54) ---
if [ "$HARVESTED" -gt 0 ] || [ "$DELETED" -gt 0 ]; then
    printf '[harvest] Session %s: %d artifacts harvested, %d ephemeral skipped\n' \
        "${SESSION_PREFIX:-unknown}" "$HARVESTED" "$DELETED" >&2
fi

# --- Clear session pointer (leave session dir intact) ---
# Previously rm -rf'd $SESSION_DIR here, but if harvest partially failed
# or classification missed files, they became unrecoverable (see 30-file
# loss incident, session Z1IhGrcgGO, 2026-03-21). Session dirs accumulate
# in .scratch/ and are logged as stale by scratch-init.sh on next session.
rm -f "$SCRATCH_DIR/.current-session"

# --- Audit harvesting/ (prune stale) ---
if $HAS_HARVESTING && command -v node >/dev/null 2>&1; then
    MANIFEST="$HARVESTING_DIR/harvest-manifest.json"
    if [ -f "$MANIFEST" ]; then
        node -e "
const fs = require('fs');
const path = require('path');
const f = process.argv[1];
const dir = process.argv[2];

let manifest;
try { manifest = JSON.parse(fs.readFileSync(f, 'utf8')); } catch { process.exit(0); }

const today = new Date();
let pruned = 0;

for (const [name, entry] of Object.entries(manifest.artifacts)) {
    if (entry.status === 'promoted' || entry.status === 'pruned') continue;

    // Check prune date
    if (entry.pruneAfter) {
        const pruneDate = new Date(entry.pruneAfter);
        if (today > pruneDate) {
            // Check git references before pruning
            const { execSync } = require('child_process');
            let refs = 0;
            try {
                const out = execSync('git log --all --oneline -- ' + path.join(dir, name), { encoding: 'utf8', timeout: 5000 });
                refs = out.trim().split('\n').filter(l => l).length;
            } catch {}

            if (refs === 0) {
                // Mark as pruned in manifest but do NOT delete the file.
                // Previous auto-deletion destroyed artifacts before review.
                // Files accumulate in harvesting/ for manual cleanup.
                entry.status = 'pruned';
                pruned++;
            } else {
                // Has references — promote to candidate
                entry.status = 'candidate';
            }
        }
    }
}

manifest.meta.lastAudit = today.toISOString().split('T')[0];
fs.writeFileSync(f, JSON.stringify(manifest, null, 2) + '\n');
" "$MANIFEST" "$HARVESTING_DIR" 2>/dev/null || true
    fi
fi

# --- Mark session complete in harness SQLite DB (OBSERVE mode) ---
# Additive: if harness-db.py is missing or fails, harvest still succeeds.
if [ -n "$SESSION_ID" ]; then
    PYTHON=""
    if command -v python3 > /dev/null 2>&1; then
        PYTHON="python3"
    elif command -v python > /dev/null 2>&1; then
        PYTHON="python"
    fi

    if [ -n "$PYTHON" ]; then
        HELPER=""
        if [ -f "$PROJECT_ROOT/scripts/harness-db.py" ]; then
            HELPER="$PROJECT_ROOT/scripts/harness-db.py"
        elif [ -f "$HOME/repos/aitools/scripts/harness-db.py" ]; then
            HELPER="$HOME/repos/aitools/scripts/harness-db.py"
        fi

        if [ -n "$HELPER" ] && "$PYTHON" -c "import sqlite3" 2>/dev/null; then
            # Mark session as ended
            # Let stderr through (warnings visible to Claude), but don't block on failure
            "$PYTHON" "$HELPER" session end --id "$SESSION_ID" || true
            # Export DB to JSON for git carry-forward
            # stderr warnings (e.g. overwrite-smaller-file safety check) must be visible
            "$PYTHON" "$HELPER" export --format json --session "$SESSION_ID" || true
            printf '[harness-db] Session %s ended, JSON exported\n' "$SESSION_ID" >&2
        fi
    fi
fi

exit 0
