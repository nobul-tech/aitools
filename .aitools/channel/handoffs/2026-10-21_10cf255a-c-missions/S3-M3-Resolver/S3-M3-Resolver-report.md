# S3-M3-Resolver report: native resolver keyed by machine id (re-key batch 2)

**Intent**: **Purpose**: Record what mission S3-M3-Resolver shipped (re-key design batch 2), the resolver interface the batch 3-5 missions build on, how it was verified, and what is left open. **Scope**: scripts/aitools-profile.sh, scripts/aitools-profile.ps1, scripts/aitools-json.ps1 (Get-JNode only), tests/profile/test-profile.sh on PR #86. NOT aitools-lib.*, setup-user-config.*, scripts/aitools* (later batches). **Audience**: S3-M3Lead, the batch 3-5 missions, the reviewer, Jose.

## Summary

- PR: https://github.com/nobul-tech/aitools/pull/86 (`feature/m3-rekey`).
- Commits: b70fc64 "Key machine profiles by machine id in the native resolver (re-key batch 2)"; 3ce5850 "Fix resolver review findings and two parity gaps (re-key batch 2)".
- Source: commander decisions 1, 3 and 5; re-key design sections (a)-(d), (f), (j) and batch 2 of (h); Review3 #82 M1 (resolver side), M2, minor 4; S3-M3Lead's relay of two S3-M3-B8c parity findings (`~` paths, UTF-16 files).
- Tests: test-profile.sh 689 passed, 0 failed, under bash 5 and /bin/bash 3.2, with bash/PowerShell output and written bytes identical.
- CI is red on test-config.sh (4 cases, not my files): see open question 1.

## Interface

`aitools-profile.sh <command> [options]` (macOS/Linux) and `aitools-profile.ps1` (Windows) take the same commands and options and print the same bytes.

### Profile shape (revision 2.2)

- `profiles.<machine id, lower-cased>`: `alias` (human-readable name), optional `name` / `company`, `machine` {`id` (repeats the key), `hostname`, `hostnames`, `os`, `arch`, `shell`}, `toolExceptions`.
- `profiles["environment:<name>"]` for an environment without a stable id (claude-code-web).
- Legacy (revision 2.1) entries keyed by alias are still read. An entry is id-keyed when its key equals its `machine.id` ignoring case, or starts with `environment:`.
- Key lookups ignore case (implemented explicitly, ASCII). `alias` lookups are case-sensitive.

### Output fields (resolve, derive-config, exception-get; also exception-set)

| Field | Values |
|---|---|
| `key` | the profiles key that matched ("" when none) |
| `alias` | the entry's `alias` field, else its key (legacy entries: the key, so existing readers of `alias` keep working) |
| `via` | `override`, `environment`, `id`, `config`, `alias`, `hostname`, `none` |
| `owner` | `this`, `other`, `unregistered` (no machine.id), `unknown` (has a machine.id, but this machine's id cannot be detected; `via=config` counts as `this`), `absent` (no match) |
| `legacy` | `true` when the matched entry is still keyed by alias |

`resolve` line order: alias, via, key, owner, legacy, environment, machineId, hostname, profileFile, userRepoPath, userRepoVia, name, company, gitName, gitEmail, github, then `warn` / `error` lines.

`derive-config` adds `derived.machineId` (the matched key, only for this machine's id-keyed profile) next to `derived.machineAlias` (the alias: display value, and the legacy cache for step 4L). Neither is set for an `AITOOLS_MACHINE_ALIAS` override or a hostname match.

### Resolution order

1. `--alias A` / `AITOOLS_MACHINE_ALIAS`: a key (ignoring case), else an `alias` field. Unknown = error; an alias on two entries = error listing the keys (select by key).
2. claude-code-web: key `environment:claude-code-web`; legacy fallback: the entry whose `machine.environment` matches (warns: migrate).
3. `profiles[<this id>]`; legacy fallback: an alias-keyed entry whose `machine.id` equals this id (warns `profile "X" is keyed by alias -- run: aitools-profile migrate ...`). Id on two entries = error.
4. config.json `machineId`, only when this machine's id cannot be detected (`via=config`).
4L. config.json `machineAlias` naming an alias-keyed entry with no `machine.id` (or another machine's id = ignored with a warning). Skipped when config.json has `machineId`.
5. Hostname (`via=hostname`, warns). 6. None: error, identity values only.

Warnings added: alias on two machines (every resolve of that alias), stored hostname differs from the live one on a `via=id` match (the only clone signal; register clears it by updating `machine.hostname`), config machineId disagreeing with the id match, a key that disagrees with its `machine.id`.

`exception-get` returns only this machine's decisions: when `owner` is not `this`, a stored entry is ignored (`found false`) with a warning.

config.json paths: a leading `~` in `userRepoPath` / `reposPath` expands to HOME in both resolvers. A UTF-16 config.json or profile.json is invalid in both, message `<file> is UTF-16 encoded, not UTF-8 -- save it as UTF-8` (config: a warning, resolution continues without it; profile: an error).

### Commands that write

| Command | Writes | Notes |
|---|---|---|
| `register --profile F --out TMP [--alias A] [--claim KEY] [--allow-duplicate-alias] [--name N] [--company C] [--shell S] [--environment E] [--create --github-user U --email E]` | only `--out` (the caller validates, backs up, moves, commits) | writes only this machine's key; output `result` (created, updated, unchanged, refused, failed), `key`, `alias`, `owner`, `ownerKey`, `claimed`, `machineId`, `hostname` |
| `migrate [--profile F] [--dry-run]` | profile.json in place | output `result` (migrated, unchanged, dry-run, refused, failed), `profileFile`, `renamed` ("old -> new, ..."), `unclaimed`, `committed`, `pushed`; commit message "Migrate machine profiles to id keys" |
| `exception-set` | profile.json in place | only when `owner=this` and `via` is `id`, `environment` or `override` |

`register` rules:
- Alias: `--alias`, else the entry's current alias, else the short hostname.
- An alias-keyed entry whose `machine.id` is this machine's is claimed: re-keyed under this id (position kept), `alias` = old key unless `--alias`.
- An alias-keyed entry without `machine.id` is claimed only with `--claim KEY` (batch 5 passes it after the user picks KEY at a terminal; design c). `--claim` of an entry with another machine's id or an environment: exit 4; unknown KEY, or this machine already has a profile: exit 2.
- An alias (field or key, ignoring case) used by any other entry: refused, exit 4, `owner`/`ownerKey` of that entry; for an unregistered entry the message suggests `--claim KEY`. With `--allow-duplicate-alias`: written, warning `alias "A" is used by N machines (keys)`. The other entry is never touched. Keeping an alias this profile already has (a duplicate confirmed earlier) is not refused.
- Aliases shaped like a machine id are refused.
- An id-keyed entry and an alias-keyed entry with this id: exit 2 (legacy duplicate).
- `machine.id` is written as the lower-cased key; an existing value differing only in case is kept. `machine.hostname` is set to the live short hostname unless it or `machine.hostnames` already matches.
- migrate refuses (exit 2, nothing written) a legacy entry whose key is id-shaped but disagrees with its `machine.id`.
- `--create` scaffold: `version 2`, `meta.schemaRevision "2.2"`, identity, `profiles.<id>`.

### Exit codes

0 ok; 1 nothing found; 2 error (bad input, invalid JSON, ambiguous match, one id on two profiles); 3 refused (exception-set without this machine's profile; register with no machine id; a write to an `AITOOLS_PROFILE_FILE` snapshot); 4 refused (register: alias used by another profile). 2 is never a user abort here; callers map it (D-TS13).

### Test hooks

`--machine-id-value ID` / `--hostname-value NAME` (and `AITOOLS_PROFILE_TEST_MACHINE_ID` / `_HOSTNAME`); new: `--machine-id-value none` = no detectable id.

## Changes beyond the interface

- Logging (design j): temp-file removal is checked in both shells (`remove_tmp` / `Remove-TempFile`, warning on failure); a rejected push (`rejected`, `non-fast-forward`, `fetch first`) advises `git pull --rebase`, then `git push`; push runs with `GIT_SSH_COMMAND="ssh -o BatchMode=yes"` unless the user set one; the OS guard exits 1; header and `--help` document exits 0-4 and the library-style logging contract.
- aitools-json.ps1: `Get-JNode` matches path segments case-sensitively, like perl `nav` (open question 1 of batch 1).
- The `Intent:` blocks of both resolver files are unchanged (protected). A header line notes that `migrate` also writes profile.json; the intent wording is drafted below.

## Verification (macOS, isolated HOME, injected ids)

- `bash -n`; pwsh parser on both .ps1 files: clean.
- test-profile.sh: 689 passed, 0 failed (was 418), bash 5 and `AITOOLS_TEST_BASH=/bin/bash` (3.2). Every case checks bash/pwsh exit, output and written bytes.
- Review-fix cases: reg-noclaim, reg-claim-foreign / -missing, reg-dup-rerun(-same), reg-hostname, reg-alias-case, reg-alias-idshape, idk-exc-get-other, idk-owner-unknown, idk-mismatch(-migrate); parity: urp-tilde(-repos), urp-utf16, rm-utf16-profile.
- New cases: idk-* (id-key resolve, JSON fields, override by alias / key / unregistered, none, clone signal, hostname on another id, upper-case key, config machineId used / ignored / stale, derive-config machineId, duplicate alias warn / lookup error / by key, exception-set and -get on an id key, refused override and via=config), reg-* (claim, new id, alias rename, exit 4 on id-keyed and legacy entries, duplicate flag, legacy duplicate exit 2, no id exit 3, hostname default alias), mig-* (dry-run, migrated with exact bytes, commit and push, backup, resolve afterwards, unchanged rerun, duplicate id, snapshot refusal), exc-* (legacy entry warns migrate, override to own / other profile).
- test-lib.sh: 40 passed, 0 failed.
- test-config.sh: 85 passed, 4 failed (c1, c2, c3, c8) -- see open question 1.
- check-pre-commit: FAIL steps 6 and 20 (known; none of my files lack +x). WARN step 11: uncommitted changes in the live dotprofile /Users/new-jose/repos/aitools-nobul-jose -- not mine (every test and probe used an isolated HOME); worth a look. check-pre-push: FAIL step 7 (known).

## Review outcome

- Reviewer: S3-M3-Resolver-Review (independent, level 3). Review: https://github.com/nobul-tech/aitools/pull/86#pullrequestreview-5621307144 ; file S3-M3-Resolver-Review-pr86-batch2.md (this directory).
- Verdict on b70fc64: request changes -- 0 blockers, 4 majors, 8 minors, 5 nits.
- Fixed in 3ce5850: M2 (rerun after confirmed duplicate), M3 (`--claim` instead of claiming through `--alias`), M4 (hostname refresh + fix in the warning), minors 1-6, minor 7 (header pointer dropped; intent wording still awaits approval), minor 8 (tests for all of these), nits 2, 4, 5.
- Not fixed: M1 (test-config.sh / CI red -- not my files; open question 1); nit 1 (write-failure messages are worded by each runtime); nit 3 (Set-JValue still matches case-insensitively; harmless for the resolver, which always writes actual keys).

## Not run

- Windows, Linux (CI covers Linux), Git Bash.
- The live dotprofile was not read or written; no migrate on real data.
- scripts/aitools user init (batch 5) against the new register: by reading, its current calls keep working (it passes the resolved alias back; register re-keys a legacy entry with this id). Running user init from this branch on the live dotprofile would therefore re-key this Mac's entry -- the design says to migrate only after main has the reader.

## Drafts for approval (protected: intent statements)

aitools-profile.sh and .ps1, `Intent:` paragraph:
- old: `NOT a writer of profile.json except the \`register\` subcommand, which writes to a temp file the caller validates, backs up and moves, and the \`exception-set\` subcommand, the only writer of toolExceptions, which writes in place (temp, validate, backup, move) and commits and pushes profile.json.`
- new: `NOT a writer of profile.json except the \`register\` subcommand, which writes to a temp file the caller validates, backs up and moves, the \`exception-set\` subcommand, the only writer of toolExceptions, and the \`migrate\` subcommand, which re-keys profiles by machine id; those two write in place (temp, validate, backup, move) and commit and push profile.json.`

## Open questions (with suggested answers)

1. **test-config.sh fails 4 cases (CI red on #86; review M1).** Its fixture is a legacy entry with `machine.id`, so derive-config returns the design's "run migrate" warning and setup-user-config writes WARN rows. Suggested: the batch 4 owner (setup-user-config.* / test-config.sh) re-keys the fixture by id and treats the migrate warning as an ACTION ("run aitools-profile migrate") rather than a row WARN. I did not touch those files (PR #79 ownership). Batch 4 should land on this branch before #86 merges.
2. **Batch 5 must pass `--claim KEY`** when the user picks an unclaimed profile at the terminal; today's UI passes `--alias KEY`, which now exits 4 for such a profile. Suggested: batch 5 maps exit 4 + `owner unregistered` to that menu path.
3. **exception-set refuses an override that names another or unregistered profile, and via=config.** Suggested: keep (design b, "writes refuse an override whose entry is not profiles[<this id>]").

## INCIDENT markers (not filed)

- `INCIDENT:` the resolver's library-style logging contract (warnings returned, caller logs at level) is still undocumented in reference/logging.md and the script-standards-detail.md exemptions table (design j finding 1; protected files).
- `INCIDENT:` (reviewer) no rule says each pushed batch keeps CI green, or says when it is deliberately red.
- `INCIDENT:` (reviewer) setup-user-config turns every advisory resolver warning into a row-level WARN; the library-tool contract does not separate advisory warnings (ACTION) from row-level ones.
- `INCIDENT:` PowerShell variable names ignore case: `foreach ($e in $E)` silently overwrote the collection in Invoke-Migrate (found by the parity tests, fixed). No harness rule warns about it (related to Review3's lib-globals incident).

## WRITE_BLOCKED

None. (Two Bash calls were refused by standing-order-guard for `&&` / `;`; the commands were moved into scratch scripts, the prescribed pattern.)
