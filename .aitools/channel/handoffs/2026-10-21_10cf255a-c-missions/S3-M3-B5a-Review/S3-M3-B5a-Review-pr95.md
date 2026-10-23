# S3-M3-B5a-Review: independent review of PR #95

Reviewer: S3-M3-B5a-Review (level 3, delegated by S3-M3-B5a), 2026-10-22, macOS.
Scope: the PR's own commits c421511 and 266a1ba (`scripts/build-deploy.sh`,
`scripts/check-pre-push.sh` / `.ps1` step 7, the deploy-paths.md draft). The stacked
PRs (#83, #90, #91, #92) were not reviewed. I got no author report; everything below
is from the code, the PR body and my own probes.

## Verdict: approve-equivalent

No blockers, no majors. The core claims hold under my own probes: no build-time
interpolation, each machine gets its own values from the live dotprofile and from the
embedded snapshot, `deploy/` matches `scripts/` for claude per machine, the embeds survive
hostile rule names and content, bash 3.2 works, and the step 7 smoke run passes against
a copy of the real dotprofile. Four minor findings are worth fixing. m1 and m2 are cheap,
and m1 corrects a claim in the PR body. They can land in this PR or right after it.
(Posted as `--comment`. Reviewers never approve.)

## Findings

### m1: a build failure after the reset still deletes the committed deploy/

`scripts/build-deploy.sh:550` runs `rm -rf "$DEPLOY_DIR"`. Input checks still run after
that line:

- the cursor-default substitution check (`:748-758`, `:789-799`)
- every `extract_between` sentinel check (`:347-350`)
- the post-build invariants (`:1557-1564`, PS1 validation `:1600-1627`)

The PR body says "a failing build keeps the committed `deploy/`". That is only true for
the checks before `:550`.

Evidence (`.scratch/session-B5aRev/probe.sh`, last block). I built into a copy of the
fixture dotprofile that already had a full deploy/, using a copy of `scripts/` in which
`let modelId = 'auto';` had become `let modelId = 'auto' ;`:

```
rc=1 deploy files before=      42 after=       2
[build-deploy] [error] setup-user-cursor.sh: the profile preferences defaults (...) were not found exactly once -- update build-deploy.sh
```

The dotprofile working tree is left with 40 committed files deleted. `git checkout --
deploy` recovers them.

Fix, either of:
- move the two cursor extract+subst steps above `:550`;
- better, generate into `$BUILD_TMP/deploy` and replace `$DEPLOY_DIR` only after the
  post-build checks pass. That also covers sentinel and invariant failures.

### m2: the step 7 smoke run never tests the embedded snapshot path

The smoke run (`check-pre-push.sh:178-197`, `.ps1:196-215`) always runs with
`AITOOLS_USER_REPO_PATH=<copy>` and a config.json that points at the copy. Every run
therefore takes the **live** branch:

```
pre-push 7 smoke setup-user-claude.sh: ... Profile source: live /var/folders/.../dot/profile.json
```

That line is from my run of the real `check-pre-push.sh`, in deploy.log. The endpoint
path is the new runtime behaviour this PR adds for machines without the dotprofile:
embedded snapshot, embedded template and embedded rules. A broken embed there would
still pass step 7.

The claude check is `grep -q 'Profile source:'` (`check-pre-push.sh:194`, `.ps1:212`).
It also accepts `Profile source: none (...)`, which is the line printed when the
snapshot is missing.

Fix: add one more claude `--dry-run` / `-DryRun` with no `AITOOLS_USER_REPO_PATH` and
an isolated config.json of `{}`. It passes only with `Profile source: embedded
build-time snapshot`. Keep sh and ps1 identical.

### m3: deploy/ and scripts/ differ when the dotprofile is present but incomplete

The fallbacks fire per item, not on "this machine has no dotprofile":

- **Rules fallback** (`build-deploy.sh:616-624`, `.ps1` `:700-709`). It fires when
  `RULES_SRC` is empty. That also happens when the machine has the dotprofile but no
  `claude/rules/`.
- **Template fallback** (`:610`, `.ps1` `:694`). The embedded path is passed as the
  "shared" template. With a dotprofile that lacks `claude/CLAUDE.md`, `scripts/` uses
  `shared/claude-shared.md`. `deploy/` uses the build-time dotprofile template and logs
  it as "(shared template)".

Evidence (`probe.sh`, fixture dotprofile with `claude/rules/` removed, then with
`claude/CLAUDE.md` removed):

```
== dotprofile present but no claude/rules (scripts/ vs deploy/)
    scripts rules deployed:
    deploy rules deployed: a.md|b c.md|it's.md|z.md|
== dotprofile present but no claude/CLAUDE.md (scripts/ vs deploy/)
    scripts rc=0 template: Template source: .../scripts/../shared/claude-shared.md (shared template)
    deploy rc=0 template: Template source: .../aitools-embed.Dp3MRz/claude/CLAUDE.md (shared template)
```

deploy-paths.md asks for "equivalent results". On a machine whose user deleted all their
rules, deploy/ brings back the build-time rules every run.

Fix, either of:
- gate both fallbacks on `[ -z "$_DP_PATH" ]` / `-not $aitoolsDpPath`;
- or record the difference as intended in the deploy-paths draft.

The snapshot fallback when the dotprofile has no `profile.json` (`:600-604`) has the same
shape. It is lower risk, because the resolver treats an `AITOOLS_PROFILE_FILE` snapshot
as read-only (`aitools-profile.sh:805`).

### m4: PowerShell cleanup on early exit can use try/finally

The PR says an early `exit` leaves the PS temp dir behind because "PowerShell has no EXIT
trap". That is true, but `finally` does run on `exit`, both in-process and under
`-File`. It also runs when `exit` is called from a lib function, which is how the
`[x]abort` exit 2 path works (`aitools-lib.ps1:654`).

Evidence (`.scratch/session-B5aRev/fin.ps1` / `fin-run.ps1`, pwsh 7, macOS):

```
$ pwsh -NoProfile -File fin-run.ps1      # in-process & call
body start / in function, exit 2 / FINALLY RAN
in-process call: LASTEXITCODE=2 FIN_TEST=restored
$ pwsh -NoProfile -File fin.ps1          # direct -File
body start / in function, exit 2 / FINALLY RAN   (exit code 2)
```

The PS embed block also runs before the OS guard and the PS 7 version guard. Each of
those exits (PS 5.1, wrong OS), every early `exit 1` in the claude body
(`setup-user-claude.ps1:33,40,58,117,129,134,370`), and a user abort currently leave a
dir behind. When the script is invoked in-process they also leave
`AITOOLS_PROFILE_PS1` / `AITOOLS_PROFILE_FILE` set.

Fix: emit `try {` after the embed block and `} finally { Remove-AitoolsEmbed }` around
the rest of the body. That works inside the generated part; `scripts/` does not change.
`try` creates no scope, so the functions stay script-scoped.

I did not run this on Windows.

### n1: the deploy-paths draft leaves two "3 scripts" references

Edit 1 of the draft changes "Three script pairs" to "One script pair". It does not
touch:
- the later heading "When changing setup logic in any of the 3 scripts above"
  (deploy-paths.md:71);
- step 5, which points at pre-commit step 13. `check-pre-commit.sh:267` still lists
  `setup-user-claude.*` / `setup-user-cursor.*` as duplicated templates, so it will now
  warn even though a rebuild is all they need.

Suggest one more draft edit, and a follow-up for step 13.

### n2: the resolver dependency scan only knows two spellings

`build-deploy.sh:380` matches `"$SCRIPT_DIR/<f>"` and `:388` matches
`Join-Path $PSScriptRoot "<f>"`. Both match how the resolver loads its files today
(`aitools-profile.sh:45,107`; `aitools-profile.ps1:46,111`). `${SCRIPT_DIR}/x` or
`Join-Path -Path $PSScriptRoot -ChildPath x` would slip past the scan and fail on an
endpoint. This is acceptable as a heuristic; a comment naming the accepted forms would
help.

### n3: "pure extract" is slightly overstated for setup-user-claude.ps1

The generated `param()` is hand-written (`build-deploy.sh:657-661`). It has a different
default (`""` instead of `..\shared\claude-shared.md`, which is intended), but a new
parameter added in `scripts/setup-user-claude.ps1` would not reach deploy/. The header
comment block is hand-written as well. Worth one line in the deploy-paths draft.

### n4: the generated claude script resolves the dotprofile twice

The generated block calls `resolve_user_repo_path` (`:591`). The extracted body calls
it again (`setup-user-claude.sh:72`), and the PS1 version does the same, so the
resolver's detail lines appear twice in deploy.log. This is already covered by the PR's
follow-up (a shared marker pair).

### Question (unknown, outside this PR)

`aitools-profile.ps1:244` and `:294` use `$HOME`, PowerShell's automatic variable, to
find config.json and `~/repos`. The lib runs the resolver in-process (`& $ps1`,
`aitools-lib.ps1:135`). On macOS, `$HOME` is fixed at process start: an in-process run
of a generated .ps1 with only `$env:HOME` / `$env:USERPROFILE` changed resolved the
**real** dotprofile (read-only; nothing was written, see "Safety" below). I do not know
whether `$HOME` on Windows pwsh 7 follows `$env:USERPROFILE` in a child `pwsh -File`.

If it does not, the `.ps1` step 7 smoke run reads the real `~/.aitools/config.json`.
Writes are not at risk: the dotprofile is pinned to the copy by
`AITOOLS_USER_REPO_PATH`, and the run is `-DryRun`. The machine alias, however, could
come from the real config.

Suggested answer: check it on Windows during the Windows pass. If `$HOME` ignores
USERPROFILE, the resolver should prefer `$env:USERPROFILE` on Windows, as the lib
already does at `aitools-lib.ps1:687`.

## Verified clean

All runs were under an isolated HOME with fixture dotprofiles in
`.scratch/session-B5aRev/fx/`. The build was run only as
`env -u AITOOLS_PROFILE_FILE -u AITOOLS_MACHINE_ALIAS -u AITOOLS_SUMMARY_FILE HOME=<isolated> AITOOLS_USER_REPO_PATH=<fixture> bash scripts/build-deploy.sh`.

**The fixture**
- Two profiles: m1 (`id-m1`, name `One & $HOME \1`, Co1) and m2 (`id-m2`, Two, Co2).
- An identity block and `cursor.cli`.
- A `claude/CLAUDE.md` with all five tokens and a `## Code Style` heading.
- Four rules:
  - `a.md`;
  - `b c.md`, containing `$(touch /tmp/b5arev-pwned)`, backticks and `${HOME}`;
  - `it's.md`, whose first line is `'@`;
  - `z.md`, with no trailing newline.

**`probe.sh`: 17 ok / 0 fail under bash 5, and 17/0 with `/bin/bash` 3.2 running the generated and `scripts/` scripts**
- The build exits 0. `bash -n` is clean on all 21 generated .sh files. The build's own
  pwsh ParseFile pass is clean on all .ps1 files.
- The lib is inlined once per script. The resolver consumers hold a second copy, inside
  the embed heredoc, as designed.
- The aitool-ops SKILL.md line "Hooks cannot source `aitools-lib.sh`" is now deployed
  verbatim (H1 fix confirmed). Every `scripts/setup-*.sh` has exactly one lib-loading
  line, so first-match-only changes nothing else.
- **Cross-machine, with the dotprofile:**
  - For m1 and m2, `deploy/setup-user-claude.sh` and `scripts/setup-user-claude.sh` give
    byte-identical CLAUDE.md files, identical rules trees, identical summaries and rc 0.
  - The m1 name `One & $HOME \1` comes through literally (no `eval` expansion).
  - The temp dirs are removed.
- **Endpoint without the dotprofile** (deploy/ copied elsewhere, config `{}`):
  - m1 and m2 each resolve from the embedded snapshot.
  - Neither machine's CLAUDE.md holds the other's values.
  - An unregistered machine (m9) gets identity values only and `ERROR|machine profile|no machine match`, rc 1.
  - All four rules deploy and match the source, including `'@`, the quote, the space and
    the `$()` text. Nothing was executed.
- **Other cases:**
  - An explicit template argument still wins over the embedded fallback.
  - Settings and cursor `--dry-run` on the endpoint: no "resolver missing".
  - A caller-set `AITOOLS_PROFILE_SH` (a stub that exits 2) wins and gives the rc 3 rows
    `ERROR|dotprofile|resolver failed` and `ERROR|claude.md|not deployed: dotprofile unresolved`.

**`probe2.sh`: standalone build modes**
- **Resolver mode** (no `AITOOLS_USER_REPO_PATH`, config.json points at a copy): logs
  `Dotprofile: ... (via resolver)`. The output is byte-identical to the env-mode build.
- **No dotprofile:** skip, exit 0.
- **Corrupt config.json:** skip, exit 0. The resolver treats a corrupt config.json as a
  warning (deploy.log detail), which is its contract.

**`ps-probe.ps1`: generated .ps1 under pwsh 7 on macOS** (guard-stripped copies, `AITOOLS_PROFILE_TEST_ANY_OS=1`)
- The claude endpoint for m1 and m2 resolves from the snapshot, with the right values
  and no cross-machine values.
- m9 gets identity values, the ERROR row and the ACTION row.
- The rules with a quote, `'@` and a space match the source.
- The temp dirs are removed. With the dotprofile, the log shows
  `Profile source: live .../profile.json`.

**Real `scripts/check-pre-push.sh` from the worktree**
- Step 7 FAILs with "stale", the known pre-existing case. No dry-run problem is
  reported; the deploy.log smoke lines show claude `Profile source: live <temp copy>` and
  all three scripts `COMPLETED successfully`.
- Steps 2, 3, 4, 9 and 10 PASS.

**By reading**
- The bash heredoc is quoted, and its delimiter is checked after CRLF normalisation.
- The PS here-string `|` prefix is removed once per line (`(?m)^\|`).
- `printf %q` quotes rule names.
- The EXIT trap is the only trap. No `scripts/` consumer or the lib sets another EXIT
  trap (`grep "trap "`).
- The `.ps1` step 7 restores the environment for all nine overridden variables in
  `finally`.
- H5: `env -u` on the build in sh; `SetEnvironmentVariable($n, $null)` in ps1.
- M7: the trigger regex includes the resolver files.
- The skipped-build check works because the copy's deploy/ is removed first.

**Safety**
- The real dotprofile's `deploy/setup-user-claude.sh` mtime (14:46 local, before this
  review) and `profile.json` mtime (2026-10-21 21:55) were unchanged after all my runs.
- Its `git log` is unchanged (HEAD db37f89).
- The real `~/.aitools/config.json` and `~/.claude/CLAUDE.md` mtimes predate this review.

## Not run

- **Windows:** the generated .ps1 end to end (USERPROFILE, backslash paths), `check-pre-push.ps1` step 7, and build-deploy under Git Bash.
- **The m4 try/finally inside a generated script:** I only proved it in a standalone `fin.ps1`.
- **`aitools` / `aitools.ps1` end to end.**
- **The stacked PRs' code**, beyond what the generated scripts exercised.
- **Repo test suites** (`tests/profile`, `tests/logging`, managed-files): I did not re-run them.

## Probe files (not committed)

`.scratch/session-B5aRev/`: `probe.sh`, `probe2.sh`, `ps-probe.ps1`, `fin.ps1`,
`fin-run.ps1`, `prepush.log`, and the fixtures under `fx/`.
