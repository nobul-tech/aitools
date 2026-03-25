# Investigation: Lost AARs and Missing Session Archives

**Date**: 2026-03-21
**Investigators**: Two S2 subagents (Explore agents a8f90f9e, a457569039)
**Spot-checks**: 4 claims verified by S3

## Investigation 1: Lost S2 AAR Files (March 16)

**Status: Resolved. Fix deployed. AARs unrecoverable.**

- Deployed harvest-session.sh is IDENTICAL to source (diff confirmed)
- The .json classification bug has been fixed — JSON files are now correctly
  classified as artifacts (harvested) not ephemeral (deleted)
- The 2 lost AAR files are unrecoverable from disk
- The running estimate documents: "Bug fixed, proposals were acted on but raw
  AARs unrecoverable"
- No action needed

## Investigation 2: Missing Session Archives (March 18-20)

**Status: Recoverable. Sessions exist locally. Never committed.**

### Key finding: same session ID, different sizes

- Archived: `2026-03-17_e059186f.jsonl` — 4.2 MB (snapshot as of March 17 07:09)
- Local: `e059186f-...-.jsonl` — 11.4 MB (last modified March 19 09:50)

Same session continued producing work after the archive snapshot was taken.
The session spanned March 17-19 and produced commits v0.62.3 through v0.62.6.
The archive captured only the March 17 portion.

### Untracked session files in dotprofile repo

| Project | File | Size | Date |
|---------|------|------|------|
| customers | 2026-03-20_12aa4cc2.jsonl | 5.5 MB | Mar 20 |
| grizzlies | 2026-03-20_362962ff.jsonl | 3.2 MB | Mar 20 |
| grizzlies | 2026-03-20_e8a4bc06.jsonl | 810 KB | Mar 20 |
| marlins | 2026-03-19_c76111cb.jsonl | 9.5 MB | Mar 19 |
| marse | 2026-03-18_ab0eb977.jsonl | 1.7 MB | Mar 18 |

Total: 33.1 MB untracked. These were copied by the hook but never committed.

### Hook analysis

session-archive.sh is deployed, functional, and identical to source. It is
**copy-only** — it does NOT auto-commit or auto-push. Decision #1 in the
planning brief specifies auto-commit/push should be added, but this hasn't
been implemented yet.

### Root cause

The hook works correctly. The gap is in the commit workflow:
1. Hook copies transcript to dotprofile repo (working)
2. User must manually commit and push (not happening reliably)
3. Decision #1 proposes fixing this with auto-commit/push at SessionEnd

### Recovery actions needed

1. Commit the 5 untracked session files in dotprofile repo
2. The aitools session from March 18-19 (11.4 MB local) should be
   manually archived — the March 17 snapshot only captured 4.2 MB of
   an 11.4 MB session

## Spot-check results

| Claim | Source | Verified? |
|-------|--------|-----------|
| Deployed = source harvest-session.sh | S2-1, S2-2 | YES — diff empty |
| Local e059186f session is 11 MB | S2-1 | YES — 11,414,612 bytes |
| Dotprofile has untracked sessions | S2-1, S2-2 | YES — git status confirmed |
| Archived e059186f is 4.2 MB | S2-2 | YES — 4,364,796 bytes |

## Discrepancy between S2 reports

S2-2 reported session e059186f local file as 4.2 MB (3592 lines).
S2-1 reported it as 11 MB. Actual: 11.4 MB. S2-2 was wrong on the size
(may have read the archived copy instead of the local one). Finding: this
is why spot-checking matters — delegation duty fulfilled.
