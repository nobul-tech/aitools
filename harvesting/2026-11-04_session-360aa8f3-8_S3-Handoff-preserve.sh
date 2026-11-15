#!/usr/bin/env bash
# S3-Handoff-preserve.sh -- copy (never move) mission work products from session
# scratch to the tracked handoff missions dir. Skips fake-HOME run dirs, logs,
# raw scan dumps, registry snapshots, and build trees. Scratch/throwaway.
set -euo pipefail

SRC=/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8
DST=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_360aa8f3-8-missions

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '[%s] [S3-Handoff-preserve] [info] %s\n' "$(ts)" "$*"; }

mkdir -p "$DST"

# Whole-dir copies (small, all reusable)
for m in S2-Host S2-Split S5-Tools; do
    cp -R "$SRC/missions/$m" "$DST/$m"
    log "copied $m (whole)"
done

# S2-Layout: everything except the 1.25 MB raw scan dump
mkdir -p "$DST/S2-Layout"
for f in "$SRC/missions/S2-Layout"/*; do
    base=$(basename "$f")
    if [ "$base" = "s2b-scan.out" ]; then
        log "skip S2-Layout/$base (raw scan dump, regenerable via s2b-scan.sh)"
        continue
    fi
    cp -R "$f" "$DST/S2-Layout/$base"
done
log "copied S2-Layout"

# S4-Review: everything except the incidents.json snapshot
mkdir -p "$DST/S4-Review"
for f in "$SRC/missions/S4-Review"/*; do
    base=$(basename "$f")
    if [ "$base" = "S4-Review-scratch" ]; then
        mkdir -p "$DST/S4-Review/S4-Review-scratch"
        for g in "$f"/*; do
            gb=$(basename "$g")
            if [ "$gb" = "incidents-main.json" ]; then
                log "skip S4-Review-scratch/$gb (snapshot of registries/incidents.json)"
                continue
            fi
            cp -R "$g" "$DST/S4-Review/S4-Review-scratch/$gb"
        done
        continue
    fi
    cp -R "$f" "$DST/S4-Review/$base"
done
log "copied S4-Review"

# S5-Profile: reports, plan, drafts, test scripts; skip run*/ fake-HOME dirs
mkdir -p "$DST/S5-Profile/tests/review"
cp "$SRC/missions/S5-Profile"/S5-Profile-*.md "$DST/S5-Profile/"
cp -R "$SRC/missions/S5-Profile/S5-Profile-drafts" "$DST/S5-Profile/S5-Profile-drafts"
for f in "$SRC/missions/S5-Profile/tests"/*; do
    [ -f "$f" ] && cp "$f" "$DST/S5-Profile/tests/"
done
for f in "$SRC/missions/S5-Profile/tests/review"/*; do
    [ -f "$f" ] && cp "$f" "$DST/S5-Profile/tests/review/"
done
cp -R "$SRC/missions/S5-Profile/tests/review/psroot" "$DST/S5-Profile/tests/review/psroot"
log "copied S5-Profile (run*/ fake-HOME dirs skipped)"

# S3-Nine: empty (logs/, scripts/ empty) -- record, do not copy
mkdir -p "$DST/S3-Nine"
printf 'S3-Nine produced no files (missions/S3-Nine/logs and scripts were empty at handoff time, 2026-10-21).\n' > "$DST/S3-Nine/EMPTY.txt"
log "S3-Nine empty; wrote EMPTY.txt marker"

# Session-level incident draft + small recon provenance
cp "$SRC/incidents-draft-74-86.json" "$DST/incidents-draft-74-86.json"
mkdir -p "$DST/recon"
cp "$SRC/recon/local-issue9.patch" "$DST/recon/"
cp "$SRC/recon/manifest-remote.json" "$DST/recon/"
log "copied incidents-draft-74-86.json and recon provenance (patch, manifest)"

log "done"
