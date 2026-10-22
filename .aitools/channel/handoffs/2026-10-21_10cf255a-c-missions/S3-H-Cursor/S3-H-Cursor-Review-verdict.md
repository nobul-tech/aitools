# S3-H-Cursor-Review verdict: PR #87 (Cursor rules fan-out)

**Verdict: CHANGES REQUESTED** (1 blocking finding, 8 non-blocking).
Reviewer: S3-H-Cursor-Review (independent, level 3), 2026-10-22. Branch reviewed: `feature/harness-cursor-rules` at the worktree `/Users/new-jose/repos/aitools/.claude/worktrees/h-cursor`.

The plumbing is sound: the location, the `.mdc` requirement, the return-value handling, the abort path, dry run, `--force`, the duplicate handling and the tests all hold up. The blocking problem is semantic. The `paths:` to `globs:` conversion gives globs that Cursor resolves relative to `$HOME`, not to the workspace. So every path-scoped rule that is fanned out never auto-attaches.

## Blocking

### B1. Converted `globs:` are anchored at `$HOME`, so path-scoped rules never auto-attach

- **Where:** `scripts/setup-user-cursor.sh:382-383` (`cursor_rule_from_md`, `paths:` becomes `globs:`) and `scripts/setup-user-cursor.ps1:389` (`ConvertTo-CursorRule`). The design claim is in the research file, section D2: "rewrite it as `globs:` plus the same list and `alwaysApply: false` (A3 row 2, 'Auto-attached when a matching file is in context')".
- **Evidence (Cursor IDE 3.13.10, per `defaults read .../Cursor.app/Contents/Info.plist CFBundleShortVersionString`), from `/Applications/Cursor.app/Contents/Resources/app/extensions/cursor-agent-exec/dist/main.js`, verbatim:**
  - `function rL(e){...for(let e=r.length-2;e>=0;e--)if(".cursor"===r[e]&&"rules"===r[e+1]){const t=r.slice(0,e);return 0===t.length?tL:t.join(tL)}return n}`. This returns the directory that owns `.cursor/rules`. For `~/.cursor/rules/x.mdc` that directory is `$HOME`.
  - `function aL(e,t){...if("fileGlobbed"===n){const t=e.type?.type.value.globs??[],n=nL(rL(e.fullPath)),s=iL(r,n)?r.slice(n.length+1):void 0;return t.some(e=>{const t=(0,qF.oL)(e);return(0,eL.Z1)(t)?(0,QJ.xF)(r,t,{dot:!0}):!!s&&(0,QJ.xF)(s,t,{dot:!0})})}`. A relative glob is matched against the read path **relative to that owner directory**.
  - `eL.Z1` is module 90066 `r`: `function r(e){return!!e.startsWith("/")||!!/^[a-zA-Z]:[\\/]/.test(e)||!!e.startsWith("\\\\")}` (is-absolute).
  - The caller is the read-file attach path: `for(const s of e)for(const e of t){if(!oL(e,n))continue;if(!e.fullPath)continue;if(!aL(e,s))continue;...`.
- **Effect:** `scripts/**` in `~/.cursor/rules/config-file-safety.mdc` matches `~/scripts/...` only, never `~/repos/aitools/scripts/...`. Every `paths:` in the repo today is project-relative: 9 files in `.claude/rules` (web-sources, managed-file-deployment, tool-evaluation, documentation-standards, tool-lifecycle, hook-rollout, deploy-paths, config-file-safety, relay-outbound) and `shared/rules/hook-lifecycle.md` (`grep -rn -A1 "^paths:"`). The PR's own isolated run reports "The 9 `paths:`-scoped rules became `globs:` with `alwaysApply: false`". In the IDE, all of them are dead for auto-attach. The 49 tests pass because they check the frontmatter text, not how Cursor resolves it.
- **Not verified:** the CLI (`agent`). Its bundle has no client-side glob matcher: `grep -c "glob pattern(s) for applicable files"` on the CLI `index.js` returns 0, and no `".cursor"===...&&"rules"===` owner-dir function turned up. So the CLI's anchoring is **unknown**. Matching may happen server-side.
- **Suggested fix (the commander or author picks one; each needs a test that asserts the resolved behaviour, not just the text):**
  1. Rewrite each relative glob as `**/<glob>` (`scripts/**` becomes `**/scripts/**`, `CLAUDE.md` becomes `**/CLAUDE.md`). The rules then attach in any workspace under `$HOME`. That is broader than Claude Code's project scope, so an aitools rule would attach on `scripts/` in other repos too.
  2. Map `paths:`-scoped rules to `alwaysApply: true`. Simple and always loaded, but it costs context in every chat.
  3. Emit a `description:` (for example from the rule's first heading) with no globs, so Cursor treats the rule as `agentFetched` and the agent pulls it in when relevant.
  4. Keep the project-scoped rules out of the user-level fan-out and deploy them to `<repo>/.cursor/rules` instead. That is a contract change, so it goes to S3-Harness.
  Whichever option is chosen, add the `rL`/`aL` evidence to `S3-H-Cursor-research.md` section B and to the draft `reference/tool-ops-cursor.md`.

## Non-blocking

N1. **Column-0 YAML list loses the scope without any warning.** `paths:\n- scripts/**` is valid YAML. The converter (`setup-user-cursor.sh:383`, `^\s+-\s`) passes it through after `globs:`. Cursor's `cr` also needs leading whitespace (`/^\s+-\s+(.*)$/`), so `globs` becomes `[]` and the rule is `manuallyAttached`. It is never applied, and the script still reports `added`. I reproduced this (see Mutation run). Suggested fix: normalize list items to `  - ` in the converter. No repo rule uses this form today.

N2. **Inline globs are split on commas.** Cursor's `Sc` does `e.split(",")` on a string value. So `paths: src/**/*.{ts,tsx}` becomes `["src/**/*.{ts","tsx}"]`, and `paths: ["a/**", "b/**"]` becomes `["[\"a/**\"","\"b/**\"]"]` (reproduced). Suggested fix: convert an inline value to a block list, expanding a flow sequence. No repo rule uses this form today.

N3. **Cursor splits the whole file on `---` (`t.split("---").filter(Boolean)`), and the converter does not guard against that:**
  - A frontmatter value that contains `---` corrupts the frontmatter. `description: before --- after` gives `fm={"description":"before"}`, and `globs`/`alwaysApply` move into the body (reproduced).
  - Dash runs in the body shrink, because `filter(Boolean)` drops the empty pieces: `|-------|------|` becomes `|----|---|` and `------` becomes `---`. This is cosmetic.
  Suggested fix: validate each converted file with Cursor's semantics (the `cr` logic is about 1 KB), and `log_warn` when a converted `.mdc` resolves to `manuallyAttached` or when its parsed frontmatter loses keys. The current post-write validation (`setup-user-cursor.sh:518`) checks only the first line.

N4. **Dry run reports OK even when a failure was logged.** `setup-user-cursor.sh:486-488` and `.ps1:498-499` write `OK|cursor rules|dry run (no files written)` even when a duplicate or a conversion failure was logged with `log_error` in the same dry run. `write_summary` promotes OK only on WARNINGS (`aitools-lib.sh` `write_summary`). The exit code is 1, but the summary row says OK. Suggested fix: when `_DT_FAILED > 0`, write `ERROR | N failed (dry run)`.

N5. **A broken symlink is skipped silently in bash but fails in PS1.** `setup-user-cursor.sh:404` `[ -e "$rule_src" ] || continue` drops a dangling symlink with no log line. In my mutation run, `broken.md` produced no line at all. PS1 lists the entry and fails it in `ReadAllText`, which gives an ERROR row. That is a parity gap and a silent skip in reusable code (script-standards, "Error handling requirements"). Suggested fix: `log_error` plus a `failed` record on a dangling link in bash.

N6. **An unreadable source directory gives different outcomes.** PS1 writes `ERROR|cursor rules|cannot read harness rules` (`.ps1:412-418`). Bash has an unexpanded glob there, so `[ -e ]` is false and it reports `OK | n/a (no harness rules)`. Suggested fix: in bash, check `[ -r "$HARNESS_RULES_DIR" ] && [ -x "$HARNESS_RULES_DIR" ]` and write the same ERROR row.

N7. **There is a non-ASCII literal in PS1 code.** `setup-user-cursor.ps1:375` `$Text -replace "^<U+FEFF>", ""` embeds a raw BOM character (`grep -n -P "[^\x00-\x7F]"`). cross-platform.md "ASCII preference for PS1 executable code" applies. Suggested fix: `-replace '^﻿', ''`. Functionally the line is redundant anyway: `ReadAllText` with an encoding already strips the BOM preamble.

N8. **Duplicate detection is case-sensitive, but the default file systems are not.** On APFS and NTFS, `Foo.md` and `foo.mdc` map to `Foo.mdc` and `foo.mdc`. These are different strings, so the duplicate check (`case` / `List.Contains`) misses them, but they are the same file on disk. The two would overwrite each other on every run. This is an edge case. Suggested fix: compare lowercased names.

Observations (not this PR's defects; for S3-Harness or the commander):
- O1. The contract fans **project** rules out (aitools `.claude/rules`, many titled "(this repo)") into a **user-level** Cursor location. The `alwaysApply: true` ones (17 by the author's count) load in every Cursor chat in every workspace under `$HOME`, not only in aitools. This comes from the S3-Harness contract, not from this code. B1 option 4 touches it.
- O2. When a harness rule is removed, the `.mdc` it produced stays in `~/.cursor/rules` as "preserved unmanaged" and stays loaded. That follows the additive pattern in config-file-safety.md, but nothing retires it.
- O3. The IDE loader also reads `CLAUDE.md`/`CLAUDE.local.md` in every ancestor when third-party extensibility is enabled (`a&&t.push("CLAUDE.md","CLAUDE.local.md"),t.push("AGENTS.md")`). It does not read `.claude/rules`: `grep -c '".claude","rules"\|.claude/rules'` returns 0 in both bundles. So the fan-out does not duplicate rules Cursor already loads.

## What I verified, and how

- **Tests, run myself:** `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` gave `49 passed, 0 failed, 0 skipped` (macOS, pwsh present). The output matches the PR claim.
- **Syntax:** `bash -n scripts/setup-user-cursor.sh` gave no output (OK). The pwsh `Parser::ParseFile` on `setup-user-cursor.ps1` gave "PS1 parse OK".
- **Mutation run**, isolated HOME `.scratch/session-hcrev/home`, script `.scratch/session-hcrev/seed-adv.sh`. The real setup-user-cursor.sh ran with stub `rg`/`agent`, and its output was parsed with Cursor's own `lr`/`cr`/`Sc`/`ur` logic, copied verbatim from the CLI `index.js` into `.scratch/session-hcrev/cursor-parse.js`. Summary: `OK|cursor rules|7 added` (8 sources; the dangling `broken.md` was skipped with no log line). Parse result, verbatim:
  ```
  brace.mdc: fileGlobbed ["src/**/*.{ts","tsx}"]
  col0.mdc: manuallyAttached | fm={"globs":[],"alwaysApply":false}
  config-file-safety.mdc: fileGlobbed ["scripts/**","deploy/**",...,"CLAUDE.md","RELEASE_NOTES.md","ROADMAP.md","README.md"]
  dashes.mdc: global | body="## T\n\n| a | b |\n|----|---|\n\n---\n\nend"
  descdash.mdc: agentFetched | fm={"description":"before"} | body="after\nglobs:\n  - x/**\nalwaysApply: false\n---\nDesc body"
  flow.mdc: fileGlobbed ["[\"a/**\"","\"b/**\"]"]
  unclosed.mdc: global | body="---\npaths:\n  - y/**\nno close"
  ```
- **Research claims checked against the bundles** (Perl `index`/`substr` context grep, `.scratch/session-hcrev/ctx.pl`):
  - B2 is confirmed in the CLI `index.js`. `loadRulesFromDirAndAncestors` loops `join(o,".cursor","rules")` and then `dirname` until the root. `loadRulesFromDirectory` uses `includeGlobs:["**/*.mdc"]`.
  - B3 is confirmed in the IDE `main.js`: `loadRulesFromDirAndAncestors` appears 3 times and `includeGlobs:["**/*.mdc"]` 2 times.
  - B4 is confirmed: `function cr(e){const t=e.trimStart();if(!t.startsWith("---"))return null;const n=t.split("---").filter(Boolean);...` and `function ur(e)` map to global / fileGlobbed / agentFetched / manuallyAttached as the research states.
  - The research's location conclusion (`~/.cursor/rules`, `.mdc`, workspaces under `$HOME` only) holds. The research is silent on glob anchoring, and that gap is B1.
- **An item the author reports as fine, read myself:** "Every return value is handled at the call site. Abort is exit 2 (lib)". The case/switch covers `created|updated|verified|skipped|failed`, `accept & adopt` and the default (`.sh` and `.ps1` step 4). `_managed_abort` in `aitools-lib.sh` does `log_error "Aborted by user"; exit 2`. The `while ... done <<< "$RULE_SOURCES"` loop runs in the current shell, so exit 2 ends the script. `deploy_managed_file` honors `DRY_RUN` and normalizes trailing newlines (`aitools-lib.sh` `deploy_managed_file`), and `Deploy-ManagedFile` matches (`-replace '[\r\n]+$'`, `if ($DryRun)`). So the trailing-newline stripping by `$(...)` in bash is harmless. Confirmed.
- **Bash 3.2:** I found no associative arrays, `mapfile`, `${x,,}` or `;&` in step 4. Here-strings and `case` with embedded newlines are 3.2-safe.
- **The `backup_dir` no-op** for an all-`.mdc` directory is confirmed (`aitools-lib.sh` `backup_dir`: `find ... -name '*.md'`, return 0 on zero). Per-file `.bak.<ts>` backups still happen. I agree with the author's proposed incident.

## What I did not verify

- The CLI's glob anchoring (unknown, see B1).
- The live Cursor behaviour. There was no canary, because the CLI is not authenticated (`agent -p` gives "Authentication required", per the operational learning). I did not try `agent login`.
- The cited docs (cursor.com/help/customization/rules.md, cursor.com/docs/rules.md). I did not re-read them through chrome-devtools; I verified the code instead.
- PS1 end to end on Windows. Only the parser, plus the author's converter parity test under pwsh on macOS.
- `build-deploy.sh` and the MDM extraction (S3-H-MDM's scope).
- The protected-file drafts (`tool-ops.json.cursor-entry.json`, `tool-ops-cursor.md`): read for context only, not reviewed line by line. Whichever B1 fix is chosen should also update the format section of `tool-ops-cursor.md`.

## INCIDENT markers (not filed)

- INCIDENT: The rules fan-out contract (S3-Harness brief, "Shared contract") does not say how Claude Code `paths:` scoping maps to each tool's scoping semantics. Claude Code paths are project-relative. Cursor user rule globs are relative to the directory that owns `.cursor/rules` (`$HOME`). Without that, a consumer can convert correctly as text and still lose the behaviour. Suggested resolution: add a "scoping translation" clause to the contract and to `reference/tool-ops-cursor.md`.
- INCIDENT: (the author already proposed it, and I confirm it) `backup_dir` / `Backup-Dir` count only `*.md`, so a directory of `.mdc` (or any other type) gets no directory backup, contrary to config-file-safety.md "Directory deployment (additive pattern)" step 2.
