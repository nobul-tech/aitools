**Verdict: REQUEST CHANGES** (posted as a comment: GitHub refuses request-changes on own-account PRs). 0 blocker, 4 major, 8 minor, 5 nit.

# S3-M3-Resolver-Review: PR #86, commit b70fc64 (re-key batch 2, native resolver keyed by machine id)

**Intent**: **Purpose**: Independent review of commit b70fc64 for correctness, design compliance, bash/PowerShell parity and script-standards compliance. **Scope**: scripts/aitools-profile.sh, scripts/aitools-profile.ps1, scripts/aitools-json.ps1, tests/profile/test-profile.sh at b70fc64. NOT batch 1 (rename op). NOT scripts/aitools*, aitools-lib.*, setup-user-config.* (later batches). **Audience**: S3-M3-Resolver (fixes), S3-M3Lead, Jose.

Reviewer: S3-M3-Resolver-Review (level 3). Sources: re-key design (S3-M3-Register-keydesign.md) sections a-d, f, j, h batch 2; S3-M3Lead-plan.md section 2 (decisions 1, 3, 5); Review3 #82 M1, M2, minor 4; S3-M3-JsonRename-report.md op contract.

## How this was checked

- Read all four files at b70fc64 in full, the commit message, and `origin/main:scripts/aitools-profile.sh` (for legacy compatibility).
- Suites (macOS, isolated HOME): `test-profile.sh` 622/0 (bash 5 + pwsh), 448/0 (`/bin/bash` 3.2, `--bash-only`); `test-lib.sh` 40/0; `test-config.sh` **85/4** (c1, c2, c3, c8).
- CI run 39859094088 on this head: **linux FAIL, macos FAIL** (both in "Config writer tests", the same 4 cases), windows pass.
- About 35 probes in `.scratch/session-Resolv/review/probe1-4.sh`. Each runs the bash and the pwsh resolver on identical copies in a temp HOME, with ids injected through `--machine-id-value` / `--hostname-value`. It compares stdout and the written bytes. probe1 was also run under `/bin/bash` 3.2. Probe M2 runs the **origin/main** resolver (`git archive`) on a file this commit migrated.
- Parity: every probe printed identical stdout and identical written bytes in both shells, under bash 5 and 3.2. The only differences are the write-failure messages (n1) and the invalid-JSON parser text, which was already different before this commit and is normalised by the tests.
- Not run: Windows, Linux, claude-code-web (the environment is forced to `local` off Linux), the live dotprofile (not touched).

## Major

### M1. CI is red: test-config.sh fails 4 cases on this head (linux and macos)
- **Observed.** CI run 39859094088 fails on linux and macos. Locally the result is 85/4: c1-fresh, c2-verified, c3-upgrade and c8-dry-run expect `OK|aitools config|...` and get `WARN|aitools config|...`. The fixture is a legacy profile with machine.id. derive-config now returns `warn profile "nobul-mac" is keyed by alias -- run: aitools-profile migrate` (probe E10), and setup-user-config turns any resolver warning into a WARN row.
- **Expected.** Each commit on the stack keeps CI green, or the PR says it is deliberately red until a named commit lands. The commit message reports "Known: test-config.sh 85/4" but does not say CI is red. Two things depend on this. Users: once merged, every run on both machines shows "aitools config" as WARN until the live migrate (design f puts the migrate *after* the merge). The PR itself cannot merge in this state.
- **Fix.** Batch 4 (ConfigKey) must land on `feature/m3-rekey` before the PR leaves draft. Alternatively, update the test-config fixtures now (id-keyed fixture plus one legacy case that expects WARN), since test-config.sh is the test of a consumer this batch changed. Also decide (lead or commander) whether the "run migrate" advisory should be a WARN row in setup-user-config at all in the window between merge and migrate. Suggestion: yes, but as one ACTION row, not a WARN on the config row.

### M2. A confirmed duplicate alias makes every later `register` of this machine fail with exit 4
- **Observed (probe P23, both shells, bash 3.2 too).** This machine's id-keyed entry has `alias nobul-mac`, and another machine's entry also has `alias nobul-mac`. That is the state `--allow-duplicate-alias` creates. Re-running `register --profile F --out O` with no `--alias`, or with `--alias nobul-mac`, gives:
  ```
  result  refused   owner other   ownerKey 0b1c2d3e-...
  error   alias "nobul-mac" is used by another machine's profile (0b1c2d3e-...) -- choose another alias, or confirm interactively (--allow-duplicate-alias)
  exit 4
  ```
- **Where.** aitools-profile.sh:1253-1275 and aitools-profile.ps1:1090-1104. The conflict scan runs even when the alias is unchanged (it is this entry's own existing alias).
- **Expected.** Design (c): after the confirm the duplicate is "allowed"; "every resolve then warns". The header says "Safe to re-run". Lead answer: "duplicate alias after confirm allowed, every resolve warns". Today a re-registration that only refreshes machine facts (`aitools user init` again, or a shell change) is refused, so the UI would have to re-confirm on every run.
- **Fix.** Refuse only when the alias *changes* to one another profile uses. Skip the conflict check when `src` is set and `alias == E_ALIAS[src]` (and `HASALIAS`), and keep the "used by N machines" warning. Add a test: register the duplicate, then re-register with no flag and expect exit 0 `unchanged`, plus the warning.

### M3. `register --alias X` claims an unclaimed legacy profile without a terminal, even one that plainly belongs to another machine
- **Observed (probe P3).** The profiles hold `"nobul-win": { "machine": { "hostname": "nobul-win", "os": "win32" } }` (no machine.id: the Windows box still runs main and never registered). On the Mac, `register --alias nobul-win` exits 0 with `claimed nobul-win` and writes:
  ```
  "3d4df2a5-...": {"machine":{"hostname":"nobul-win","os":"darwin","id":"3d4df2a5-...","arch":"arm64"},"alias":"nobul-win"}
  ```
  The entry is re-keyed under the Mac's id. Its os is overwritten (win32 -> darwin), and its hostname is kept (nobul-win). After that:
  - every Mac resolve warns that it was "registered with hostname nobul-win" (see M4);
  - main's resolver on the Windows box matches it by hostname, then reports it "registered to another machine";
  - main's `register` on Windows errors.

  That is the #82-M2 ping-pong again, through the unclaimed path.
- **Where.** aitools-profile.sh:1262-1266 and aitools-profile.ps1:1093-1096.
- **Expected.** Design (c), on the unclaimed legacy entry: "The interactive choose offers it ... **Without a terminal it is not claimed** (decision 2 switch)". The resolver cannot see a terminal, so the claim has to be an explicit, separately confirmed request. Decision 1's spirit is the same: never silently take what may be another machine's profile.
- **Fix (options).**
  - (a) Add a `--claim` flag that the UI passes only after its interactive choose. Without it, refuse with exit 4, `owner unregistered`, and a message naming the profile.
  - (b) At minimum, refuse the claim when the stored `machine.hostname`/`hostnames` or `machine.os` disagree with this machine. Allow it silently only when they match or are absent.

  Suggest (a), plus (b)'s check as a warning. Add tests for both.

### M4. The hostname-mismatch ("clone") warning cannot be cleared: register never refreshes `machine.hostname`
- **Observed (probes P1, h1).** The id-keyed entry has `hostname nobul-mac` and the live hostname is `renamed-mac`.
  - resolve and derive-config warn: `profile "nobul-mac" was registered with hostname "nobul-mac", this machine is "renamed-mac" -- renamed, or a clone that shares machine id ...?`
  - `register` then exits 0 with `updated`, and the stored hostname is still `nobul-mac`.
  - The next resolve warns again.

  derive-config carries the warning, so setup-user-config writes a WARN row on every run (the M1 mechanism), forever.
- **Where.** aitools-profile.sh:573-586 (warning), 1316-1317 (hostname written only when empty); aitools-profile.ps1:459-465, 1139.
- **Expected.** Design (a) asks for the warning. It is also the only clone signal, so it has to be actionable. Design (c): "the machine facts are refreshed". Renaming a Mac (System Settings > Sharing) or a new Migration-Assistant machine is common. The cause is a branch that was already there, but this commit turns it into a permanent warning.
- **Fix.** On `register` of this machine's own entry (`src` = own, not a claim), add the live short hostname to `machine.hostnames` when it is in neither field. Alternatively, replace `machine.hostname`; that is a commander/lead call. End the warning with the remedy: `-- run: aitools user init (records this hostname)`. Add a test: rename, register, resolve gives no warning.

## Minor

1. **exception-get returns another machine's tool decisions.**
   - **Observed (P2).** `exception-get --slug go` with an unknown id and hostname `joses-mbp` gives `via hostname`, `owner other`, `found true`, `method brew`, `path /x`: the laptop's keep decision.
   - **Where.** sh:864-900, ps1:686-721.
   - **Expected.** R18 "never another profile's values". Review3 #82-M2 effect: "its toolExceptions now apply to this machine". Design (d) says only that get "follows the same matched entry". The new `owner` field makes the case detectable, but no caller filters on it yet. This is common on a replacement Mac that keeps the old hostname.
   - **Fix.** When `owner != this`, return `found false` plus a warning ("decision recorded for another machine -- ignored"). Alternatively, make it an explicit contract for batch 3 (`tool_exception_get` treats `owner != this` as not found) and test it there. Suggest the resolver-side fix: it covers every caller.
2. **`owner other` when this machine's id is unknown.**
   - **Observed (P24).** With `--machine-id-value none --alias nobul-mac` (this machine's own id-keyed profile) the result is `owner other`.
   - **Observed (P11).** With id unknown, the cached legacy machineAlias matches a legacy entry that has a machine.id, and the result is `owner other`, with no warning.
   - **Where.** sh:527-531, ps1:419-422.
   - **Expected.** `other` means "registered to another machine" (design b, UI text "(registered to another machine)"). When the id is unknown, that is not known.
   - **Fix.** Add a value (e.g. `unknown`). Or return `this` when config.json `machineId` equals the key, and `unknown` otherwise. Document it in the header and --help.
3. **A key that disagrees with its machine.id is not reported, and migrate moves this machine's key onto another id.**
   - **Observed (P5).** The entry is `"<this id>": {"machine":{"id":"<other id>"}}`.
     - resolve gives `via id`, `owner other`, `legacy true`, with no warning.
     - `migrate --dry-run` reports `<this id> -> <other id>`.
   - **Where.** sh:494, 1383; ps1:402, 1204.
   - **Expected.** Design (a): "The validator treats `key != machine.id` as an error". Only a hand edit can produce this, but migrate would re-key an entry *onto another machine's id*.
   - **Fix.** For an entry whose key looks like an id (any non-env key that equals some id case-insensitively, or simply `kind legacy` matched by key at step 3), warn in resolve. migrate should refuse ("key X disagrees with machine.id Y -- fix by hand"), not rename.
4. **A backup failure is not returned as a `warn` line.**
   - **Where.** sh:1078, 1444; ps1:922, 1261. `backup_file` sets `BACKUP_FILE_OK=false` and log_warns to stderr.
   - **Observed.** The resolver never reads `BACKUP_FILE_OK`, so the caller never sees the warning, and the lib's WARNINGS counter is bumped inside a library-style tool.
   - **Expected.** The header's own logging contract: "every warning and error is returned as a `warn` / `error` line".
   - **Fix.** After `backup_file`, check `BACKUP_FILE_OK` and `add_warn "could not back up $PF -- proceeding without backup"`. Do the same in PowerShell (check the Backup-File result).
5. **Refusal wording.**
   - **Observed (P4, P9).** The entry is an unclaimed legacy profile with `owner unregistered`, yet exit 4 says `alias "nobul-win" is used by another machine's profile`. sh:1273, ps1:1102.
   - **Observed (web path).** The legacy-duplicate error prints `machine.id  is already registered`, because THIS_ID is empty on claude-code-web. sh:1240, 1243; ps1:1072, 1075.
   - **Fix.** Word the message by owner ("used by profile nobul-win, which is not registered to any machine"). On web, name `machine.environment`.
6. **Aliases that differ only in case are accepted.**
   - **Observed (P8).** `register --alias Laptop` succeeds while another machine has `laptop`.
   - **Where.** sh:1257, ps1:1092.
   - **Why it matters.** The conflict check compares alias fields case-sensitively but keys case-insensitively. Two machines named laptop/Laptop are the confusion decision 1 tries to prevent.
   - **Fix.** Compare `lc(alias)` on both sides in the conflict scan; keep the lookups as they are.
7. **Intent drift (protected).**
   - **Observed.** The intent statements still say "NOT a writer of profile.json except `register` ... and `exception-set`", and `migrate` now writes profile.json. The note at sh:22-24 / ps1:20-22 acknowledges this.
   - **Expected.** sources-of-truth.md: intent statements are protected.
   - **Fix.** The approved wording must land before the PR merges. Also drop the in-code pointer to a handoff report ("S3-M3-Resolver report"): it will not age well.
8. **Test gaps.** None of these has a case:
   - M2 (re-register after duplicate);
   - M3 (claim of a foreign-looking unclaimed entry);
   - M4 (register refreshes hostname);
   - minor 1 (exception-get with owner other);
   - minor 2 (owner with id unknown);
   - minor 3 (key/machine.id mismatch);
   - the migrate validation-failure path;
   - claude-code-web: `register` writing `environment:claude-code-web`, resolve of an `environment:*` key, exception-set via environment. These can run on the Linux CI runner, the way `rm-web` does.

## Nit

1. **Write-failure messages differ between shells.** bash says `cannot write ...: Permission denied` and pwsh says `Exception calling "WriteAllText" with "3" argument(s): ...` (probes E7, E8, E9; ps1:900-903, 1149-1151, 1241-1245). Use `$_.Exception.InnerException.Message`, or a fixed text, in both.
2. **migrate validation can skip the JSON check.** It checks the temp file only for the renamed non-env entries. When the only renames are env-key case changes, the temp file's JSON validity is never checked (sh:1425-1441, ps1:1247-1259). Add one `jcheck "$tmp"` / `$v.State` check up front.
3. **aitools-json.ps1 read and write disagree on case.** `Get-JNode` is now case-sensitive, but `Set-JValue` (aitools-json.ps1:105-118) still looks up `PSObject.Properties[$s]` case-insensitively. A hand-written `ToolExceptions` makes PowerShell overwrite it, while perl adds a sibling key. That is an edge case; note it in the header or make Set-JValue match.
4. **`register --alias <the machine id>` is accepted** (P20: `alias 3d4df2a5-...`). Consider refusing an alias that looks like an id, or equals any key.
5. **The PowerShell version guard exits 2** (ps1:66-69). The OS guard was moved to 1 per design j.5, and a wrong-runtime failure is the same class.

## Implementer's choices: verdicts

| Choice | Verdict |
|---|---|
| register claims (re-keys) a legacy entry whose machine.id is this machine's | Agree: it is this machine's own entry. Note: run on the live dotprofile from a branch build, it re-keys this machine's entry before the planned migrate. Design f calls that safe but untested; probe M2 confirms main still resolves via id. |
| register claims an unclaimed legacy entry named by `--alias` | Disagree: **M3** |
| exception-set refuses an override that is not this machine's, and refuses via=config | Agree (design b: "Writes refuse an override whose entry is not profiles[<this id>]"; an undetectable id cannot prove ownership) |
| owner rules when this machine's id is unknown | Partly: **minor 2** |
| hostname-mismatch warning on every via=id resolve | Design-mandated, but has no remedy today: **M4** |
| machine.id case kept when it differs only in case | Agree. Main compares `lc` on both sides (origin/main aitools-profile.sh:520), and it avoids churn. Probe M2: main resolves the migrated file via id. |
| `--machine-id-value none` test hook | Agree (documented in --help; a real id is never `none`) |
| "run migrate" warning makes test-config.sh report WARN rows | Disagree as shipped: **M1** (CI red) |

## Checked and fine

- **Resolution order and exit codes against design (b):**
  - override: key ignoring case, then alias, ambiguous = 2, unknown = 2;
  - environment key, then the legacy machine.environment entry;
  - step 3: id key or legacy machine.id, migrate warning, two entries = 2;
  - step 4: config machineId only when the id is undetectable, a stale one warns;
  - 4L: legacy cache only, skipped when config has machineId, another machine's ignored with a warning;
  - hostname: legacy, warns, two = 2;
  - none = 2, with identity-only values.

  register: 3 = no id, 4 = alias in use, 2 = duplicate id, 1 = missing without --create. Help and header list 0-4.
- **Legacy compatibility (probe M2).** After `migrate`, origin/main's bash and PowerShell resolvers resolve this Mac and the Windows id `via id`, `name Jose`. Main's exception-get finds the migrated toolExceptions. The only extra output is one warning ("config.json machineAlias ... disagrees ... machine.id wins"), as design (f) predicted. Main's derive-config then caches the id key as machineAlias, and the new code accepts that without warning (m2n).
- **register writes only this machine's key.** By construction, the edit ops touch only `profiles.<key>` and the rename of `src`. Tests reg-alias-dup / reg-legacy-taken assert that the other machine's profile is untouched. Only the claim path (M3) can take an entry that is not this machine's.
- **migrate safety.**
  - dry-run writes nothing;
  - two entries on one id: refused, nothing written (mig-dup);
  - invalid or v1 file: exit 2, nothing written (M4a/b);
  - snapshot: exit 3;
  - temp -> validate -> backup -> move, with the `.bak` present (M1);
  - commits only profile.json and pushes (mig-run);
  - a dirty profile.json is written but not committed, with a warning (M3);
  - unclaimed entries are reported and left as they are;
  - machine.id is kept inside every entry.
- **Logging (design j).** `remove_tmp` / `Remove-TempFile` are checked. A rejected push advises `git pull --rebase`. `GIT_SSH_COMMAND` BatchMode is set unless the user set it, and PowerShell restores it in `finally`. The OS guard exits 1. No new unchecked `2>/dev/null`, `|| true`, `SilentlyContinue` or empty catch (the remaining `Get-Command ... SilentlyContinue` are existence checks with a fallback).
- **Parity.** The PowerShell `$e`/`$E` collision was avoided (`$en` in Invoke-Migrate). No other case-colliding variable names in the changed functions. `ReferenceEquals` on `$src` mirrors the bash index test. Ordering and messages were identical in every probe except nit 1.
- **bash 3.2.** `local T_=()`, `${who[@]+...}`, `printf -v`, and the index lists split into words all pass the full suite and the probes under `/bin/bash` 3.2.

## INCIDENT markers (not filed)

- `INCIDENT:` the stack has no rule that each pushed batch keeps CI green, or that a deliberately red CI is declared. b70fc64 landed with the macos/linux CI red and the commit message did not call it a CI failure (M1).
- `INCIDENT:` setup-user-config turns every resolver `warn` line into a WARN on the "aitools config" row. Advisory warnings (migrate, hostname mismatch) therefore downgrade the row on every run. The library-style tool contract (design j finding 1) does not say which warnings are advisory (ACTION) and which are row-level (WARN).

## WRITE_BLOCKED

None.
