# S3-Incidents report (mission INCIDENTS, Session Commander 10cf255a-c, 2026-10-21)

1. Filed #87-#145 in registries/incidents.json: 59 entries (42 from the S3-Ledger batch, 17 new), 10 high, 27 medium, 22 low.
2. Applied the PR #57 review fixes: 30 `linked` set to null; citations re-checked on db4b3c5; #113 kept.
3. Closed #80, #81 and #82, fixed by PR #56 (bd42ba5). An independent checker verified all three. #82's note names the sed observe regression (#144 / PR #60).
4. Applied the affected updates for #21, #55, #59 and #76, and the #51 recurrence note. Merged two of the listed findings into #95/#76 and #98 instead of filing them twice.
5. PR https://github.com/nobul-tech/aitools/pull/65. Registry: 138 open/planned, 7 closed, ids 1-145 contiguous.

**PR:** https://github.com/nobul-tech/aitools/pull/65 · **Branch:** docs/incidents-87-plus-apply (commit 4433930 + this report)

## Files changed
- `registries/incidents.json`
- `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Incidents/`: `S3-Incidents-final-batch.json`, `S3-Incidents-review.md` (one row per id, dedupe table), `S3-Incidents-Check-report.md`, this report.

## Verification
- Scratch validators (`python3 -I`): `build_batch.py` (keys, enums, contiguous ids, no clash), `apply_batch.py --write` (byte-for-byte round-trip guard), `validate.py` → `entries 138 closed 7 max 145 unique True contiguous True bad-shape []`.
- Probes on db4b3c5, isolated HOME:
  - build-deploy: exit 0, 42 files. The embedded delegation-duty-guard.sh is 2,209 lines vs 215 in the source. No stale-hook removal in the generated scripts.
  - Guard: `/opt/homebrew/bin/pwsh -Command 'a; b'` exits 2, while `sed -i` exits 0 (observe).
  - Secret pattern: `token = abc` does not match, while `Path tokens:` does.
  - The Session Commander's merge-revert-test.sh output was read (deploy.log: "Auto-deployed: sample.md (no local edits detected)").
- S3-Incidents-Check: 33/33 citations hold. #80 and #81 are FIXED, and #82 is FIXED as stated.
- check-pre-commit: 6 PASS, 1 FAIL. The FAIL is step 6, which is pre-existing and now filed as #133.
- check-pre-push: 5 PASS, 1 FAIL. The FAIL is step 3: its 7 hits are probe strings quoted inside #134, which is the #134 false positive itself.

## Not run
- Windows / PS1 execution.
- The S5-Profile H1/H6 repros.
- #144: the reviewer verdicts are not in the repo. The claim rests on the commander's brief, and its consequence was verified.

## WRITE_BLOCKED
- None. One Bash call (an `until ...; do sleep` loop) was blocked by standing-order-guard (';'). I used Monitor instead, which is not a write.

## INCIDENT markers (not filed)
- `INCIDENT:` scripts/setup-user-skills.sh:195-200 reverse-discovery prompt uses bare `read -r choice < /dev/tty` gated on `[ -c /dev/tty ]` (the #81 pattern; missed by PR #56). Other bare reads: scripts/aitools:108, :157, :957, :1058-1066, :1118-1128, :1181; scripts/relay-outbound-prompt.sh:77 (EOF guarding by callers unchecked). May fall under GitHub #29; unknown.
- `INCIDENT:` the checker noted that a user-created hook adopted to the dotprofile (setup-user-hooks.sh:247-251) is never deployed by any path. Whether that is intended under SD-2 is unknown.

## Open questions (with suggested answers)
1. Closed entries for #80-#82 carry an extra `correctiveAction` field. Keep it? Suggested: yes, and add it to the /incident skill's closing procedure when #84 is fixed.
2. #98 absorbed the hook-splice finding and stays medium (the hook still works; it just runs the whole lib). Raise it to high? Suggested: no, unless MDM deploys are in active use.
3. #144 rests on reviewer verdicts that aren't in the repo. Should future reviewers post `gh pr review --request-changes`? Suggested: yes, as #144 proposes.

## Delegates used
- S3-Incidents-Check (general-purpose, not isolated, read-only verifier). Its report was spot-verified: I had independently confirmed #129, #130, #134, #136 and #138 with my own reads and probes. I adopted its two precision notes.
