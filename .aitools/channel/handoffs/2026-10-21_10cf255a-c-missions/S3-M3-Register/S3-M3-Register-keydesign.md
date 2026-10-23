# S3-M3-Register-keydesign: machine profiles keyed by the raw machine id

**Intent**: **Purpose**: Design (no code) for re-keying profile.json machine profiles
from `profiles.<alias>` to `profiles.<machineId>`, covering schema, resolution,
registration, tool exceptions, config.json, migration, scaffold, implementation
batches, decision-record wording and the resolver logging audit. **Scope**: what the
resolver and its consumers must change, and in which order. NOT code. NOT the wording
written into protected files (section i holds drafts for commander approval).
**Audience**: S3-M3Lead (verifies), the implementation delegates, Session Commander
10cf255a-c, Jose.

Source of the change: commander decision 2026-10-22, relayed by S3-M3Lead (course
correction to mission S3-M3-Register). Supporting record: plans/tool-support-and-machine-profile.md
P-Q2 (raw ids) and P-Q6 (commander note: "it should be under profiles.machineid").
All file:line citations are at the current tip of `feature/m3-b6-user-init` (PR #82).
No code was written or committed by this mission (the guard work was stopped before any
commit).

## Summary

1. Key every machine profile by its raw machine id, lower-cased. The human-readable
   name moves into the profile as `alias`. `name` is already taken: it overrides
   `identity.name`.
2. Resolution: id-key lookup first, so `via=id` covers almost every run. `--alias` /
   `AITOOLS_MACHINE_ALIAS` stay as lookups by the `alias` field. Hostname is only a
   registration suggestion. config.json caches `machineId`, not an alias.
3. Registration only ever writes `profiles[<this id>]`. A new id creates the entry. An
   alias used by another id's entry is refused (exit 4) unless the run is interactive
   and the user confirms. Another id's entry is never rewritten.
4. No flag day: the code reads legacy alias-keyed profiles. `machine.id` stays inside
   each entry, so the code already deployed on both machines keeps matching through
   its step 3 after migration. A `migrate` subcommand re-keys entries, with a backup,
   then commits and pushes.
5. The work splits into 8 batches of at most 3 code files each. The resolver and the
   JSON engine go first; consumers follow behind the PR #80 lib contract.

## (a) profile.json schema (stays `"version": 2`; `meta.schemaRevision` "2.2")

`version` stays 2. Older releases treat any other version as v1 and offer a
destructive migration (R18 draft, "Profile Schema" preamble). Revision 2.2 only renames
keys and adds `alias`, so the version does not change.

```json
"profiles": {
  "aaaaaaaa-1111-2222-3333-444444444444": {
    "alias": "nobul-mac",
    "name": "<optional override of identity.name>",
    "company": "<optional override of identity.company>",
    "machine": {
      "id": "aaaaaaaa-1111-2222-3333-444444444444",
      "hostname": "nobul-mac",
      "hostnames": ["<optional>"],
      "os": "darwin", "arch": "arm64", "shell": "zsh"
    },
    "toolExceptions": { "<slug>": { "decision": "keep", "...": "unchanged shape" } }
  },
  "environment:claude-code-web": {
    "alias": "web",
    "machine": { "environment": "claude-code-web", "os": "linux", "arch": "x64" }
  }
}
```

- **Key.** The raw id (P-Q2), lower-cased on write: macOS `IOPlatformUUID`, Windows
  `MachineGuid`, Linux `/etc/machine-id`. Lookups are case-insensitive. macOS reports
  upper case and Windows lower case, and PowerShell property names are
  case-insensitive anyway (aitools-profile.ps1 header, lines 30-31). Lower-casing on
  write means bash and PowerShell produce identical bytes.
- **Environment profiles** (Claude Code web containers have no stable id) use the
  reserved key `environment:<name>`. No platform id contains `:`, so this key cannot
  collide with one.
- **Human-readable field: `alias`.** Recommended over `name` and `label`:
  - `name` already exists in every profile as the per-machine override of
    `identity.name` (aitools-profile.sh:455-463 `profile_values`; R18 draft line 88).
    Reusing it would collide with the person's display name in CLAUDE.md
    interpolation.
  - `alias` keeps the approved glossary term "machine alias" (plan G-terms), the
    `--alias` flag (P-Q12) and every log line (`alias=nobul-mac`) meaningful. Only
    its role changes: from key to label.
  - `label` would work, but it adds a new term and leaves "machine alias" undefined.
  - Glossary: the "machine alias" definition must say "a machine profile's
    human-readable name (the `alias` field), not its key". Route through `/glossary`
    (protected).
- **`machine.id` stays inside the entry** and equals the key. It is redundant on
  purpose. The resolver and setup-user-claude code already deployed from main match by
  `machine.id` (step 3) or by `machine.hostname`, not by the key. Keeping both fields
  is what makes the migration safe for old readers (section f). The validator treats
  `key != machine.id` as an error. Drop the redundancy only after every machine runs
  revision-2.2 code; that is the same rule R18 states for removing `company`.
- **Stays in `machine.*`**: `id`, `environment`, `hostname`, `hostnames`, `os`, `arch`,
  `shell`. None of these move.
- **Known limitation, unchanged from today.** Cloned Linux images share
  `/etc/machine-id` (aitools-profile.sh:284 comment), so two clones share one profile.
  Today that case is an error ("id on two profiles"). With id keys it cannot be
  detected. A hostname mismatch inside `profiles[<id>]` (stored hostname differs
  from the live one) becomes the only signal: report it as a warning.

## (b) Resolution order with id keys

| # | Step | via | On a miss |
|---|---|---|---|
| 1 | Override: `--alias A` / `AITOOLS_MACHINE_ALIAS`, looked up first as a key (case-insensitive), then as an `alias` field value | `override` | unknown = error (exit 2, unchanged); one alias on 2+ entries = error that lists the keys |
| 2 | Environment `claude-code-web`: key `environment:claude-code-web`; legacy fallback: the one entry whose `machine.environment` matches | `environment` | two = error |
| 3 | `profiles[<this id>]` (key lookup); legacy fallback: an alias-keyed entry whose `machine.id` equals this id (warns: run `aitools-profile migrate`) | `id` | id on two entries = error |
| 4 | config.json `machineId`, used only when this machine's id cannot be detected (ioreg/registry failure, sandbox) | `config` | unknown key = warning, continue |
| 4L | Legacy: config.json `machineAlias` names an alias-keyed entry without `machine.id` (commander decision 2 path) | `alias` | as today |
| 5 | Hostname match | `hostname` (warning) | two = error |
| 6 | None | `none` | error; identity-level values only (unchanged) |

- **`--alias` stays.** Suggested answer: keep it as a lookup by the `alias` field.
  Tests, build-deploy and `AITOOLS_MACHINE_ALIAS` users need a readable selector.
  Accepting a literal key as well covers duplicate aliases. Writes refuse an override
  whose entry is not `profiles[<this id>]` (exception-set already refuses non-id
  matches: aitools-profile.sh:814-826).
- **Hostname.** It never selects a profile for writes. In `resolve` it remains the
  legacy read fallback. Its main use becomes the registration suggestion. A hostname
  match on an entry keyed by another id is reported as `owner other` (below), which
  is the warning Review3 #82-M2 asked for.
- **Cached config.** Under id keys `via=alias` only exists for legacy entries (4L).
  Decision 2's one-line switch, owned by S3-M3-UserInit, keeps applying to 4L. Once
  migration is done, 4L stops matching anything and can be removed.
- **New output fields** on `resolve`, `derive-config` and `exception-get`:
  - `key`: the profiles key that matched.
  - `alias`: the field value. For legacy entries it is the key, so existing callers
    that read `alias` keep working.
  - `owner`: `this` / `other` / `unregistered` / `absent`.
  - `legacy`: `true` / `false`.

  `owner` is the "other machine" indicator the original mission asked for. It moves
  from a guard to an output field.

## (c) Registration (decision 1 restated for the id model)

- **Target.** `register` writes only `profiles[<this id>]`, or
  `profiles["environment:<env>"]` on claude-code-web. No other key is written,
  renamed or deleted. "Never silently overwrite another machine's id" holds by
  construction.
- **New id.** The entry is created, with `alias` from `--alias`, else the short
  hostname. This fixes Review3 #82-M1: `--alias <new>` without a terminal creates the
  profile, because the UI no longer asks the resolver to *resolve* an unknown alias
  first.
- **Existing entry for this id.** `--alias B` renames its `alias` field. The machine
  facts are refreshed, as today.
- **Alias in use by another id's entry.**
  - `register` refuses with **exit 4** and `result refused`, `owner other`,
    `ownerKey <that id>`.
  - Exit 4 is new and documented. It is not 2 (D-TS13: user abort) and not 3, which
    stays "refused: not registered" for exception-set. The UI can tell the two
    refusals apart.
  - `--allow-duplicate-alias` (passed by the UI only after an interactive confirm)
    lets this entry take the same alias. The other entry is not touched. Every
    resolve then warns `alias "X" is used by 2 machines (<id1>, <id2>)`, and an
    `--alias X` lookup becomes an error that lists the keys.
  - Alternative (not recommended): let the confirm retire the old entry. That
    rewrites another id's entry, which this decision forbids.
  - Suggested later work: a `retire --key K` subcommand for replaced hardware. It
    would be explicit, interactive, and never part of registration.
- **Legacy alias-keyed entry without `machine.id`** (unclaimed). The interactive
  choose offers it. Claiming it moves it, in one write, to `profiles[<this id>]`
  with `alias` set to the old key. The entry belongs to no id, so this does not break
  the rule. Without a terminal it is not claimed (decision 2 switch).
- **Legacy entry with another machine's `machine.id`.** It is never claimed. The UI
  shows it with "(registered to another machine)".
- **Machine id not detectable** (non-web). `register` refuses with exit 3
  (`no machine id`). There is no key to write under. Today the code writes a profile
  without an id (aitools-profile.sh:1001); that path goes away.
- **Unchanged.** The existing "this id is already on another alias entry" error
  (sh:1003-1013) becomes the legacy-duplicate check, and the result is the same:
  exit 2. The temp -> validate -> backup -> move path, commit only profile.json, and
  push best-effort (N-Q2) also stay as they are.

## (d) Tool exceptions

- Path: `profiles.<machineId>.toolExceptions.<slug>`. The entry shape does not change
  (R18 draft lines 99-112).
- `exception-set` writes only when the match is `via=id` on an id-keyed entry. The
  legacy cases:
  - A legacy alias-keyed entry with `machine.id == this id` (via=id, legacy=true):
    allow the write. The entry belongs to this machine, so blocking would only force
    a migrate first. Suggest allowing it and warning `run migrate`.
  - Every other via value keeps today's refusals (exit 3, sh:814-826).
- `exception-get` follows the same matched entry.
- `shared/skills/tool-adopt/SKILL.md:216` cites `profiles.<alias>.toolExceptions`. The
  docs batch updates that line.

## (e) config.json fields

| Field today | New | Why |
|---|---|---|
| `machineAlias` (derived, the cached profile key) | **`machineId`** (derived: the matched key; used only as step 4 when live id detection fails) | the key is the id now |
| -- | `machineAlias` kept one release as a derived, display-only value (the `alias` field), then removed | already-deployed readers (`setup-user-claude.sh:111`, `build-deploy.sh:214`, `profile-check.js:115`) read it; with id keys their `p.profiles[alias]` misses and they fall back to the hostname match, which still finds the entry |

Writer: setup-user-config.sh/.ps1 stays the single writer. deploy-harness (mission
HARNESS) calls it. Consumers, by file:line:

**Writers and derivers**
- scripts/setup-user-config.sh:20, 55, 149, 166, 184 (intent JSON), 208, 228, 251
- scripts/setup-user-config.ps1:8, 19, 28, 37 (`-MachineAlias` param), 62, 66, 76, 118 (`--alias`), 150, 170, 188, 205, 227, 250
- scripts/aitools-profile.sh:664, 699, 807, 897 (`derived.machineAlias`), 922-933
- scripts/aitools-profile.ps1:518, 550, 673, 775, 798-801

**Readers**
- scripts/setup-user-claude.sh:111-119 (node: `cfg.machineAlias`, `p.profiles[alias]`, hostname fallback, first-profile fallback)
- scripts/setup-user-claude.ps1:120-142 (same logic)
- scripts/build-deploy.sh:214-222 (same node logic, embedded)
- scripts/profile-check.js:115, 139, 150
- scripts/aitools-lib.sh:210-241 (`resolve_machine_profile`; renamed to `AITLIB_*` by #80 LibFix)
- scripts/aitools-lib.ps1:163-190 (`Resolve-MachineProfile`)

**User init and legacy v1 migration** (writes `profiles[alias]` and `cfg.machineAlias`)
- scripts/aitools:119-242 (v1 -> v2 node migration: 192, 220-221, 240)
- scripts/aitools:285-446 (ui_resolve / ui_choose / ui_register / ui_register_flow; 438 reads `profiles "$machine_alias"`)
- scripts/aitools:1149, 1180-1243, 1296, 1302
- scripts/aitools.ps1:130-230 (v1 migration: 182, 210-211, 224-230), 919, 1070, 1105-1196, 1261

**Tests (fixtures to update)**
- tests/profile/test-profile.sh:207, 234-244, 267-270, 324, 336, 579, 593, 603
- tests/profile/test-config.sh:97, 148, 169-234
- tests/profile/test-lib.sh:72, 91
- tests/managed-files/test-managed-files.sh:264

Not consumers (grep found no `machineAlias` or `profiles` reads): shared/hooks/*,
scripts/ait-harvest.py, scripts/check-lib.*. The env var `AITOOLS_MACHINE_ALIAS` keeps
its name and meaning (an alias lookup).

## (f) Migration (no flag day)

- **Readers accept both shapes, always.** An entry is id-keyed when its key equals
  its `machine.id` (case-insensitive) or starts with `environment:`. Any other entry
  is legacy alias-keyed and is resolved as today (steps 3-fallback and 4L).
- **`migrate` subcommand** (`aitools-profile.sh/.ps1 migrate --profile F [--dry-run]`):
  1. Every legacy entry with `machine.id` is renamed to its lower-cased id, with
     `alias` set to the old key. The entry's position is kept (needs a `rename` op in
     the JSON engines, batch 1). Content is otherwise unchanged.
  2. Every legacy entry with `machine.environment` becomes `environment:<env>`.
  3. Entries with neither stay as they are and are reported (unclaimed; registration
     claims them).
  4. Two entries with the same id = error, nothing written.
  5. Write path: temp -> validate (every key = its `machine.id`) -> `backup_file` ->
     move. Then commit only profile.json ("Migrate machine profiles to id keys") and
     push (N-Q2). Outcomes: `migrated` / `unchanged` / `failed`.
  6. This is a mechanical rename of keys, not a rewrite of another machine's data. It
     is the one place that touches entries other than this machine's.
- **Old code after migration** (what is deployed on main and on the Windows machine):
  - The resolver's step 3 matches `machine.id`, which is kept.
  - The node readers fall back to the `machine.hostname` match.
  - config `machineAlias` "nobul-mac" no longer names a key, so the old resolver
    warns "not in profiles" and continues to step 3.
  - Net: no ERROR, one extra warning until that machine updates.
- **When the live dotprofile migrates** (key `nobul-mac` on this Mac). Suggested:
  after the resolver batch merges to main *and* both machines have pulled it. Run
  `aitools user init` (which calls `migrate` when legacy entries exist), or
  `aitools-profile migrate` by hand, on either machine. It commits and pushes per
  N-Q2, and the other machine pulls the dotprofile. Do not migrate from a branch
  build: the Windows machine would read id keys with main's code. That is safe per
  the analysis above but untested.

## (g) Scaffold of a missing profile.json

- `aitools user init`, Path 1 (repo present, no profile.json) and Path 3 (new repo),
  calls `register --create`.
- It writes `{version 2, meta.schemaRevision "2.2", identity {github, email, name,
  company, git {name, email}}, profiles { "<this id>": { alias, machine {...} } }}`.
  The writer is already there (aitools-profile.sh:980-990 and the `.ps1` equivalent);
  only the key changes.
- The scaffold is committed and pushed (N-Q2). Path 3 today passes commit=false
  (scripts/aitools:1243) and commits in its own later step. The UI batch must make
  sure that the scaffold reaches the remote.
- Review3 INCIDENT: the Path 1 `claude/CLAUDE.md` scaffold commit has no identity
  fallback and uses `|| true` (scripts/aitools:1281-1286). Fix it in the same batch.

## (h) Implementation batches (<= 3 code files each, plus their test file)

| # | Batch | Code files | Test file | Depends on |
|---|---|---|---|---|
| 1 | JSON engine `rename` op (order-preserving) | scripts/aitools-json.pl, scripts/aitools-json.ps1 | tests/profile/test-profile.sh (engine cases) | -- |
| 2 | Resolver: id keys, legacy read, `owner`/`key`/`legacy` fields, register rules (exit 4, `--allow-duplicate-alias`), `migrate`, exception path, logging fixes (j) | scripts/aitools-profile.sh, scripts/aitools-profile.ps1 | tests/profile/test-profile.sh | 1 |
| 3 | Lib wrappers: expose key/owner (`AITLIB_MACHINE_KEY`, `AITLIB_MACHINE_OWNER`, `$script:AitLibMachineKey`, ...) | scripts/aitools-lib.sh, scripts/aitools-lib.ps1 (wrapper section) | tests/profile/test-lib.sh | 2, #80 LibFix contract |
| 4 | config.json: `machineId` (+ display `machineAlias` one release); `-MachineAlias` param becomes `-MachineId` / `--machine-id` (keep the old flag as accepted alias for one release) | scripts/setup-user-config.sh, scripts/setup-user-config.ps1 | tests/profile/test-config.sh | 2; coordinate with HARNESS (deploy-harness caller) |
| 5 | User init UI: choose shows aliases + owner, new-id create, confirm -> `--allow-duplicate-alias`, claim legacy, call `migrate`, scaffold commit, v1-migration writes id key | scripts/aitools, scripts/aitools.ps1 | (UI probes; no unit file today) | 2, 3, 4 |
| 6 | setup-user-claude: replace the node/PS alias lookup with `resolve_machine_profile` | scripts/setup-user-claude.sh, scripts/setup-user-claude.ps1 | tests/managed-files/test-managed-files.sh:264 fixture | 3 (S3-M3-Claude owns these files on #83: fold in there) |
| 7 | build-deploy embedded lookup + profile-check.js | scripts/build-deploy.sh, scripts/profile-check.js | -- | 3, 6 (S3-M3-B5 owns build-deploy.sh) |
| 8 | Docs (protected, approved text only): R18 user-repo.md, decision record, glossary "machine alias", tool-adopt SKILL.md:216 | -- | -- | 2 merged |

Batch 2 is the critical path. Batches 3 and 4 can run in parallel after 2, and batch
5 starts after 3 and 4.

## (i) Wording drafts (protected; for commander approval; not written to the repo)

**plans/tool-support-and-machine-profile.md, line 23**
- old: `- **Machine identity**: raw machine ids (P-Q2); resolver is native \`scripts/aitools-profile.sh/.ps1\``
- new: `- **Machine identity**: raw machine ids (P-Q2), and machine profiles are keyed by them: \`profiles.<machineId>\` (lower-cased), human-readable name in the profile's \`alias\` field, tool exceptions at \`profiles.<machineId>.toolExceptions\`; legacy alias-keyed profiles are still read and re-keyed by \`aitools-profile migrate\` (commander, 2026-10-22); resolver is native \`scripts/aitools-profile.sh/.ps1\``

**plans/tool-support-and-machine-profile.md, P-Q12 row, answer column**
- old: `Add --alias`
- new: `Add --alias (sets the alias field of this machine's id-keyed profile; an alias used by another machine's profile is refused without a terminal, and needs an interactive confirm otherwise -- commander, 2026-10-22)`

**R18 draft user-repo.md, line 87**
- old: `    "<alias>": {`
- new: `    "<machine id, lower-cased>": {` followed by a new line `      "alias": "<human-readable machine name, e.g. nobul-mac>",`

**R18 draft, lines 123-124**
- old: `- **\`profiles\`** -- keyed by alias. One per machine (or per environment, e.g. a Claude Code web profile with \`machine.environment: "claude-code-web"\`).`
- new: `- **\`profiles\`** (2.2) -- keyed by the raw machine id, lower-cased (\`machine.id\` repeats it until every machine runs 2.2 code); environment profiles use the key \`environment:<name>\`, e.g. \`environment:claude-code-web\`. \`alias\` is the human-readable name, shown in logs and selectable with \`--alias\` / \`AITOOLS_MACHINE_ALIAS\`. Profiles keyed by alias (2.1) are still read; \`aitools-profile migrate\` re-keys them.`

**R18 draft, lines 125-131.** The text there is stale against P-Q2, which chose raw
ids over hashing.
- old: `- **\`machine.id\`** (2.1) -- \`sha256:\` plus the first 16 hex digits of the HMAC-SHA256 ... Hashed so raw hardware ids are not committed. Written only by ...`
- new: `- **\`machine.id\`** (2.1) -- the platform's raw stable id (P-Q2): macOS \`IOPlatformUUID\` (ioreg), Windows \`HKLM\SOFTWARE\Microsoft\Cryptography\MachineGuid\` (UNVERIFIED), Linux \`/etc/machine-id\` then \`/var/lib/dbus/machine-id\`. Equals the profile's key (2.2). Written only by \`aitools user init\` (registration). Claude Code web profiles have no id (containers are ephemeral) and use \`machine.environment\`.`

**R18 draft, table lines 164-168**
- step 1 old: `Override alias (\`AITOOLS_MACHINE_ALIAS\`, or \`--machine-alias\` from user init)` -> new: `Override (\`AITOOLS_MACHINE_ALIAS\` or \`--alias\`): a profile key, else a profile whose \`alias\` field matches` ; on-a-miss new: `unknown = error; alias on two profiles = error`
- step 3 old: `\`machine.id\` equals this machine's hashed id` -> new: `\`profiles[<this machine's id>]\` (2.1 fallback: a profile whose \`machine.id\` equals it; warns: migrate)`
- step 4 old: `config.json \`machineAlias\`` / `alias` -> new: `config.json \`machineId\`, only when this machine's id cannot be detected` / `config` (2.1 fallback: \`machineAlias\` naming an alias-keyed profile, \`alias\`)`

**R18 draft, lines 171-173 (warnings)**: append `; each result reports \`owner\` (\`this\`, \`other\`, \`unregistered\`, \`absent\`) so user init can warn before suggesting another machine's profile; an alias used by two profiles is reported.`

**R18 draft, lines 183-188 (Registration)**
- old: `... then \`aitools-profile.js register\` writes \`machine.id\`, \`hostname\`, \`os\`, \`arch\`, \`shell\` into that profile (temp file -> validation -> backup -> move), commits the dotprofile and pushes best-effort. Without a terminal it reports ERROR + ACTION and does not guess.`
- new: `... then \`aitools-profile register\` writes this machine's profile, \`profiles[<this id>]\` (\`alias\`, \`machine.id\`, \`hostname\`, \`os\`, \`arch\`, \`shell\`; temp file -> validation -> backup -> move), commits only profile.json and pushes best-effort (N-Q2). It never writes another machine's profile. \`--alias <new>\` creates the profile without a terminal; an alias already used by another machine's profile is refused (exit 4) unless the run is interactive and the user confirms. A 2.1 profile with no \`machine.id\` can be claimed (moved under this id). Without a terminal and without \`--alias\` it reports ERROR + ACTION and does not guess. A missing profile.json is scaffolded (identity + this machine's profile), committed and pushed.`

**R18 draft, Config Schema line 203 and table row 219**
- old: `  "machineAlias": "nobul-mac",` -> new: `  "machineId": "aaaaaaaa-1111-2222-3333-444444444444",`
- old: `| \`machineAlias\` | derived | "Which machine profile" (cached result) | every run |`
- new: `| \`machineId\` | derived | "Which machine profile" (the matched key; read only when live id detection fails) | every run |` plus a note: `\`machineAlias\` is still written (display only) for one release, for readers of 2.1 code.`

**Glossary "machine alias"** (via `/glossary`): new definition: `The human-readable name of a machine profile (the profile's \`alias\` field, e.g. nobul-mac). Since revision 2.2 it is not the key: profiles are keyed by machine id.`

## (j) Resolver logging audit (decision 3), for batch 2

Contract as observed: the resolver is a library-style tool.
- Data goes to stdout as key/TAB/value lines.
- Diagnostics travel as `warn`/`error` lines in that output, plus `detail` lines in
  deploy.log (`finish`: aitools-profile.sh:199-214; `Complete-Command`: .ps1:124-143).
- Console log lines go to stderr (sh:48-54, ps1:49-55).
- It calls `write_summary` nowhere and raises the ERRORS/WARNINGS counters only
  through the OS guard. Rows and counters belong to the caller.

That contract is reasonable but undocumented: reference/logging.md has no section for
a tool that returns diagnostics instead of logging them at level.

Findings:
1. **Undocumented contract (doc).** Add a "Library-style tools" paragraph to
   reference/logging.md (protected). The tool logs every warning and error at
   `detail` and returns it in its output; the caller logs each one at its level and
   owns the summary rows. Also add the resolver to the script-standards-detail.md
   exemptions table (no exit footer, no summary rows; protected). Review3 #82-M2's
   "ui_resolve discards resolver warnings" (scripts/aitools:299-300 logs errors only,
   at detail) is the caller-side violation of this contract. Batch 5 must log every
   `warn` line as `log_warn` and every `error` line as `log_error`.
2. **Unchecked cleanup (USO no-silent-failures).**
   - aitools-profile.ps1:707: `Remove-Item -LiteralPath $tmp -Force -ErrorAction
     SilentlyContinue` (the `$removeTmp` block) has no result check. Add a
     `Test-Path` check and an `Add-Warn` on failure.
   - bash `rm -f "$tmp"` on the failure paths (sh:860, 864, 870, 881) is unchecked
     too. Same fix, in both shells.
3. **Wrong advice after a failed push** (Review3 #82 minor 4). sh:771-775 and the
   ps1 equivalent say "run git push" even after a non-fast-forward rejection. Detect
   `rejected`/`non-fast-forward` in the output and advise `git pull --rebase` then
   `git push`. `GIT_TERMINAL_PROMPT=0` does not stop SSH prompts: add
   `GIT_SSH_COMMAND="ssh -o BatchMode=yes"` unless the user already set it.
4. **Inconsistent register exit codes.**
   - A missing profile without `--create` exits 1 (sh:981), which is fine.
   - The id already on another entry exits 2 (sh:1010), which is fine.
   - Under the new model, add 3 (no id detectable) and 4 (alias used by another
     machine). Document all four in the header and in `--help`. Today the header and
     help list 0/1/2/3 only, with 3 limited to exception-set (sh:22-26, 99; ps1:20-24,
     106).
5. **Exit 2 means "error" here, but "user abort" in setup scripts (D-TS13).**
   - The resolver documents that callers must not pass 2 through (sh:25-26), and the
     #80 wrappers map 2 to 1.
   - Suggestion: keep 2. Renumbering would break the #80 contract for no
     user-visible gain.
   - The OS guard exits 2 (sh:60, ps1:67), while script-standards says exit 1. Change
     it to 1: a wrong-platform run is not a resolver error, and 1 matches every other
     script.
6. **`register` writes a profile without `machine.id` when detection fails** (sh:1001,
   ps1:866; only a warning). Under id keys this must become a refusal (exit 3), or the
   entry has no key.
7. **No deploy.jsonl lines.** The resolver writes deploy.log only. That matches
   aitools-lib, where only the installer's `log` override writes deploy.jsonl
   (Review3 #79 minor 1). No change in the resolver. The deploy.jsonl gap belongs to
   the installer and lib missions.
8. **Checked and fine.**
   - Every `2>&1` capture is followed by an rc check (jread/jlist/jtype/jsub/jcheck,
     sh:121-187).
   - `|| cur_name=""` carries a comment and an `-z` check (sh:757-758).
   - The PowerShell catch blocks all record or log (ps1:220, 309, 733, 757, 906, 911).
   - The `Get-Command ... SilentlyContinue` calls are command-existence checks with a
     fallback, which the rules exempt (ps1:581, 598).
   - Data never goes to the console: console log goes to stderr.

## Open questions (with suggested answers)

1. **Field name: `alias` or `label`?** Suggest `alias` (section a): it keeps the
   approved glossary term and the `--alias` flag, and it avoids the `name` collision.
2. **Duplicate alias after an interactive confirm: allow the duplicate, or block?**
   Suggest allowing it, with a warning on every resolve and an ambiguous
   `--alias` lookup becoming an error (section c). A `retire` subcommand later
   handles replaced hardware.
3. **config.json: replace `machineAlias` with `machineId` outright?** Suggest
   writing both for one release, `machineAlias` as display only, then dropping it
   once batches 6 and 7 have merged (section e).
4. **When to migrate the live dotprofile?** Suggest after batch 2 merges and both
   machines have pulled main, via `aitools user init` (section f).
5. **Allow `exception-set` on a legacy entry matched by id?** Suggest yes, with a
   migrate warning (section d).

## INCIDENT markers (not filed)

- `INCIDENT:` reference/logging.md has no contract for library-style tools that return
  diagnostics instead of logging them at level (section j, finding 1).
- `INCIDENT:` the R18 draft still describes hashed machine ids (lines 125-131), which
  contradicts P-Q2 (raw ids).
- `INCIDENT:` the alias-keyed lookups in setup-user-claude.sh:111-119, .ps1:120-142 and
  build-deploy.sh:214-222 fall back to "first profile" (`Object.values(p.profiles)[0]`).
  That gives this machine another machine's values silently, which contradicts R18
  "never another profile's values". Pre-existing; batches 6 and 7 remove it.

## WRITE_BLOCKED

None.
