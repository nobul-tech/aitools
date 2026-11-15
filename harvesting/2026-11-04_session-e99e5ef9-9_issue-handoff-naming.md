## Incident: handoff files use three naming schemes, so SessionStart announces a stale handoff

**Severity:** high (silent wrong behavior). Every SessionStart in aitools since 2026-10-20 has pointed agents at a June handoff and never announced the current one.

**Detection:** found on 2026-10-31 (session e99e5ef9) while documenting the harvest hooks for `reference/artifact-harvesting.md` (gap G4). Investigated with `/investigate`.

### Observation

`.aitools/channel/handoffs/` on main holds files named three ways:

| Pattern | Files | Written by |
|---|---|---|
| `<date>_<id10>.md` | `2026-10-21_360aa8f3-8.md`, `2026-10-22_10cf255a-c.md` | `/handoff` skill (its documented path since ee1b92b, 2026-10-27; used since c8573ed) |
| `<date>_session-<id>.md` | `2026-03-23_session-KHGOmVeNNM.md`, `2026-03-24_session-RnTOD5XJFi.md` | by hand, March (00776fe) |
| `<date>_session-<id10>_<name>` | `2026-06-20_session-46ee1c2b-1_handoff-verification.md`, `2026-06-21_session-46ee1c2b-1_handoff-verification.md` | the harvester's scratch routing (`harvest_scratch()` in `scripts/ait-harvest.py`, ported from `harvest-session.sh` in 00776fe) |
| `handoff-<id10>.md` | `handoff-2d439e32-3.md` (b504c43, 2026-03-28), `handoff-46ee1c2b-1.md` (d7a2d10, 2026-06-21) | by hand / agents |

`shared/hooks/scratch-init.sh` discovers handoffs with the glob `"$HANDOFFS_DIR"/handoff*` and announces the last match. This session's banner:

```
Handoff available: handoff-46ee1c2b-1.md (2 total in /Users/new-jose/repos/aitools/.aitools/channel/handoffs)
```

There are 9 handoff files. The newest, `2026-10-22_10cf255a-c.md`, written exactly where the `/handoff` skill says to write it, is never announced.

Also:
- Both routed `handoff-verification.md` copies are byte-identical (11223 bytes), so the same scratch file was routed twice, on two days (the re-harvest bug, G2 in `reference/artifact-harvesting.md`).
- That file is the `/handoff` Verifier's report, not a handoff. It was routed only because its name starts with `handoff`.

### Expected

`/handoff` skill: "Path: `.aitools/channel/handoffs/<UTC date>_<session-prefix>.md`" and "SessionStart discovery: when a session starts, it should check for available handoffs and announce their presence." The discovery should announce the handoffs the skill writes, newest first.

### Timeline

- 2026-03-18 7bc69ad: `/handoff` skill added. Handoffs go to `plans/<briefing>/handoff-<date>_<prefix>.md`; `.aitools/channel/handoffs/<date>_<prefix>.md` is named as the future canonical path.
- 2026-03-24 00776fe (issues #53/#54): **in one commit**, the harvester starts routing scratch `handoff*` files to `<date>_session-<id10>_<name>`, and `scratch-init.sh` gains discovery with the glob `handoff*`. The discovery matches neither the router's output in the same commit nor the skill's canonical name.
- 2026-03-28 to 2026-06-21: agents write `handoff-<id>.md` by hand. Those are the only names discovery matches, so it appears to work.
- 2026-10-20 / 2026-10-26: handoffs written per the skill (`<date>_<id10>.md`). Not discovered.
- 2026-10-27 ee1b92b: skill text makes the channel path canonical and documents the router's naming. `scratch-init.sh` is not updated.

### RCA

**Immediate cause:** the `scratch-init.sh` discovery glob `handoff*` matches only one of the three name schemes in use, and not the one the `/handoff` skill prescribes.

**Contributing factors:**
1. (prevention) No single spec for a handoff file name. The skill, the router and the discovery hook each encode their own pattern, and "session-prefix" is undefined (with or without `session-`, 8 or 10 characters).
2. (detection) No test pairs a writer with the reader. `tests/hooks/test-sessionstart-harness-db.sh` seeds `handoff-test.md`, the one name the glob matches, so it passes.
3. (audit) When the skill's canonical path changed (ee1b92b), nothing flagged the hook that reads that directory.
4. Routing by file-name prefix also catches files that are not handoffs (`handoff-verification.md`).

**Root cause:** handoff naming is a cross-component contract (writer: `/handoff` skill and harvester; reader: `scratch-init.sh`) with no single owner and no contract test.

**Recommended corrective action (structural):**
- One naming rule, stated in the `/handoff` skill and implemented once: `<UTC date>_<session id>[_<name>].md`.
- `scratch-init.sh` discovers every top-level `*.md` in `handoffs/` and announces the newest by mtime.
- A test that writes a handoff the way the skill and the router do, then asserts `scratch-init.sh` announces it.
- Optionally rename the four legacy files to the canonical pattern.

**Verification:** with the fix, the SessionStart banner in aitools announces `2026-10-22_10cf255a-c.md` (the newest) and counts all handoff files.

**Recurrence risk:** high until a test pairs writer and reader.

### Remediation in progress

The discovery fix and the contract test are part of the harvest-hook fix commit on main (session e99e5ef9, 2026-10-31). Renaming the legacy files and settling one naming rule in the `/handoff` skill stay open here.
