# S3-MF-NoMachine-Review: PR #98 (`--no-machine` / `-NoMachine`)

Reviewer: S3-MF-NoMachine-Review (independent; launched by S3-MF-NoMachine). Date: 2026-10-22.
Branch reviewed: `feature/mf-config-no-machine` (worktree `.claude/worktrees/mf-nomach`), diff `origin/main...HEAD`
(3 files: `scripts/setup-user-config.sh`, `scripts/setup-user-config.ps1`, `tests/profile/test-config.sh`).

## Verdict: approve (no blockers)

0 blocker, 0 major, 3 minor, 4 nit.

The flag does what M3-FINISH item 2 asks: with `--no-machine`, an unregistered machine
("no profile matches this machine", "profile.json has no machine profiles") gives no
ERROR row, no ACTION row and exit 0; every other field is written; `machineId` /
`machineAlias` are preserved (never set, never deleted); one info line says registration
is left to the caller; `--no-machine` with `--machine-id` or `--machine-alias` is
`ERROR|aitools config|bad arguments`, exit 1, nothing written. The PR #86 contract is
kept (exit 0/1, never 2; no prompts; dry-run unchanged; at most one ACTION).
Runs without the flag behave as before: the bash `derive_warn` split into
`derive_warn` + `derive_warn_machine` (setup-user-config.sh:200-227) routes every message
exactly as the main version did (origin/main setup-user-config.sh:174-189, compared
branch by branch), the PS1 change only inserts a guarded `elseif` (ps1:206), and all
pre-existing cases (c1-c21) still pass with byte-identical config.json and summary rows.

## Test results (run by the reviewer, macOS Darwin arm64)

| Command | Result |
|---|---|
| `bash -n` (bash 5 and `/bin/bash` 3.2) on setup-user-config.sh; `/bin/bash -n` on test-config.sh | clean |
| pwsh parser on setup-user-config.ps1 | clean |
| `bash tests/profile/test-config.sh` (pwsh parity) | **258 passed, 0 failed** |
| `AITOOLS_TEST_BASH=/bin/bash bash tests/profile/test-config.sh --bash-only` | **167 passed, 0 failed** |
| `bash tests/profile/test-user-init.sh` | **200 passed, 0 failed** |
| Reviewer probe cases P1-P9 (the test harness, both writers, isolated HOME) | 27 passed, 1 "failed" (P1: expected by design, see m1) |

All results match the PR body. Logs: `.scratch/session-mfnmrev/{test-config,test-config-bash32,test-user-init,probe}.log` in the worktree (not tracked).

Probe cases (each runs bash and pwsh, compares config.json bytes and summary rows; all parity checks passed):

| Probe | Fixture, args | Result |
|---|---|---|
| P1 | v2 profile.json with no `profiles` key, `--no-machine` | exit 1; `ERROR|profile.json|invalid (see log)` + ACTION (m1) |
| P2 | two profiles share this hostname, `--no-machine` | exit 1; `ERROR|machine profile|no machine match` + ACTION (still reported, as documented) |
| P3 | two profiles share this machine.id, `--no-machine` | exit 1; same rows as P2 |
| P4 | unmatched machine, `--no-machine --dry-run` | exit 0; `OK|aitools config|dry-run: would update`; config untouched |
| P5 | unmatched, config.json with machineAlias only | exit 0; no WARN, no ERROR, no ACTION |
| P6 | `AITOOLS_ENVIRONMENT=claude-code-web` | not testable on macOS (lib: "claude-code-web on Linux only -- environment is local"); web path **unknown** empirically (m3) |
| P7 | registered machine (id match), `--no-machine` | exit 0; machineId not written, stale machineAlias "new-mac" kept (flag honoured; caller-misuse risk, m2) |
| P8 | `AITOOLS_MACHINE_ALIAS=nosuch`, `--no-machine` | exit 1; override error still reported as `no machine match` |
| P9 | `--no-machine --machine-id ""` | exit 0, accepted (empty value = not passed, as for `--machine-id ""` today); parity holds |

## Findings

### Minor

**m1. A v2 profile.json without a `profiles` object is still "invalid profile.json" under `--no-machine`.**
The resolver emits one message for two states, "profile.json is not v2 or has no profiles"
(scripts/aitools-profile.sh:636-637), and the writer classes it as `PROFILE_BAD`
(setup-user-config.sh:242, ps1:233), so P1 gives `ERROR|profile.json|invalid (see log)`,
an ACTION and exit 1 even with the flag. `"profiles": {}` is silenced (c22c), `profiles`
absent is not. Reachability is low: `register --create` (scripts/aitools:486) writes a
profile, so only a hand-edited file gets here. Suggested fix: either (a) say in the
header/usage that a profile.json without a `profiles` object counts as invalid, or
(b) in a resolver PR, split the message ("is not v2" vs "has no profiles") and silence
the second with the flag. (a) is enough for this PR.

**m2. The "caller" warning class matches by substring, so it also silences two "real" warnings.**
setup-user-config.sh:204-209 / ps1:206-207 send every warning that contains
`run: aitools user init` or `run: aitools-profile migrate` to detail. That includes the
clone hint "profile ... was registered with hostname ..., this machine is ... -- renamed
(run: aitools user init to update it), or a clone that shares machine id"
(aitools-profile.sh:618) and "matched by hostname only (legacy) -- run: aitools user init"
(aitools-profile.sh:756). The writer does not check that the machine is actually
unregistered (P7: a registered machine with the flag keeps a stale machineAlias and
loses these warnings). User init should only pass the flag for an unregistered machine,
where :618 cannot fire (it needs `via=id`), so this is a misuse risk, not a live bug.
Suggested fix: keep `log_warn` / `LogWarn` (counted, no NEED_* flag) for the clone
message (`*"or a clone that shares machine id"*`) under `--no-machine`, or add one line
to the header and `--help`: "pass only when this machine is not registered".

**m3. Registration-related warnings that do not name a command still count under `--no-machine`.**
By code reading (not run: P6 cannot run on macOS): "no profile has machine.environment
\"claude-code-web\"" (aitools-profile.sh:682), "config.json machineAlias ... not in
profiles" (:736) and "config.json machineId ... not in profiles -- ignored" (:719) stay
`log_warn` (setup-user-config.sh:210-211, ps1:214-215), so an unregistered machine in
those states gets `WARN|aitools config|updated` from the writer. That is not an ERROR or
ACTION, so the requirement holds, but the run shows a second, machine-related warning
next to user init's own. Suggested fix: none needed for merge; if the commander wants
a quiet writer, route :682/:719/:736 to detail under the flag too (follow-up).

### Nit

**n1. Runner guidance: compute the flag where user init decides "not registered".**
scripts/aitools:998-1002 is the "this machine without a profile" outcome;
:1010-1017 then clears `machine_key` for owner `config` (registered, id undetectable)
and for another machine's key. If S3-MF-Runner tests `machine_key` empty at the writer
call (:1026-1028), owner `config` would get `--no-machine` too (harmless for
config.json, since the cached values are kept either way, but it silences m2-class
advice). Suggested fix for Runner: set a `no_machine=true` at :998 and pass the flag
from that; the "not this machine's" branch (:1013-1016) can also set it, since user
init already writes its own ERROR row there.

**n2. Ambiguous matches keep the pre-existing row text.** P2/P3/P8 report
`ERROR|machine profile|no machine match` + `ACTION||Run: aitools user init (profiles: a, b)`
(setup-user-config.sh:275-276, ps1:269-270) for "hostname matches more than one
profile", "machine.id ... on more than one profile" and an unknown override. That is
the documented contract ("still reported") and pre-existing wording, not a regression;
noting only that user init will show its own error next to it in those cases.

**n3. The derivation info line prints values that `--no-machine` will not write.**
setup-user-config.sh:265 / ps1:259 log `machineId=<derived> machineAlias=<derived>`
before the flag clears them (sh:329-332, ps1:319-322). Suggested fix: append
` (not written: --no-machine)` when the flag is set, or leave it (deploy.log only).

**n4. Test gaps that the probes filled.** No committed case for an ambiguous match with
the flag (P2/P3), the flag with `--dry-run` (P4), or a profile.json without `profiles`
(P1). The behaviour is right in P2-P4; suggest adding P2 and P4 as c22k / c22l so the
"still reported" and "dry-run unchanged" claims in the PR body are pinned by tests.

## Checked and fine

- Bash/PS1 parity: same flag semantics, same rows and exit codes in all 10 c22 cases and
  all 9 probes; info/detail lines differ only in the flag spelling (documented).
- bash 3.2: `{ ...; }` grouping at sh:116 and the new functions parse and run under
  `/bin/bash` 3.2 (167 passed).
- Error accounting: suppressed resolver errors use `log_detail` / `LogDetail` (not
  counted); every other error still goes through `log_error` / `LogError` (counted); the
  section-1 skip requires `NM_UNREG && ! NM_OTHER_ERR` (sh:272, ps1:266), so a mixed run
  still reports.
- `write_summary` on every path: the silenced path still writes the config row
  (`OK|aitools config|updated|created|verified`), and bad arguments write an ERROR row.
- config-file-safety: read-then-merge, backup and validation paths untouched; preserved
  keys documented in both headers (sh:25-26, ps1:24-25).
- PS1 `$profileBad` -> `$script:ProfileBad` is required (set inside a function) and
  correct.
- Protected files: none touched; `grep` for `machine-id|MachineId|machine-alias` in
  reference/, .claude/rules/ and plans/tool-support-and-machine-profile.md finds nothing,
  so no doc draft is owed.

## INCIDENT markers

None. m1-m3 are minor design gaps in a new flag, tracked here for the author.
