# S3-H-Cursor-Review re-verify: PR #87 after 1a4e31e and 118a79c

**Verdict: no blocking findings.**

B1 is fixed, and I verified the fix against Cursor's own parser and its shipped picomatch. N1-N4 and N6-N8 are fixed. N5 is fixed in bash. In PS1 the outcome is right but the new detection branch does not fire on pwsh 7.6 (macOS), so it is a new non-blocking item (R1). Three non-blocking items remain (R1-R3).

Reviewer: S3-H-Cursor-Review, 2026-10-22. HEAD reviewed: `118a79c` on `feature/harness-cursor-rules`. Review diff: `git diff 822f6ae HEAD -- scripts/setup-user-cursor.sh scripts/setup-user-cursor.ps1`.

## Status of the first-review findings

| # | Status | Evidence |
|---|--------|----------|
| B1 globs anchored at `$HOME` | **Fixed** | Mutation run: config-file-safety becomes `fileGlobbed ["**/scripts/**",...,"**/CLAUDE.md",...]` and relay-outbound becomes `["**/.aitools/channel/relay.md",...]` (Cursor `cr`/`Sc` model). Cursor.app's own `node_modules/picomatch` `isMatch(path, glob, {dot:true})` on paths relative to HOME gives `**/scripts/**` vs `repos/aitools/scripts/setup-user-cursor.sh` true, `scripts/**` false, `**/.claude/rules/**`, `**/.aitools/channel/relay.md`, `**/src/**/*.{ts,tsx}` all true. |
| N1 column-0 list | Fixed | `col0.mdc: fileGlobbed ["**/scripts/**"]` (it was manuallyAttached) |
| N2 inline comma split | Fixed | `brace.mdc: ["**/src/**/*.{ts,tsx}"]`, `flow.mdc: ["**/a/**","**/b/**"]` |
| N3 `---` inside frontmatter | Fixed (warn) | `[warn] descdash.mdc: Cursor would not see alwaysApply in its frontmatter (a --- inside a frontmatter value?) -- fix the source rule in ~/.aitools/rules`. Body dash-run shrink (`\|-------\|` becomes `\|----\|`) is unchanged; it is cosmetic and accepted. |
| N4 dry-run OK row after failure | Fixed | Test `drydup: ERROR row` passes. Code: `.sh` and `.ps1`, `"$_DT_FAILED failed (dry run)"` |
| N5 dangling symlink | Fixed in bash; PS1 outcome right by another path | Bash: `[error] Failed: broken.md: dangling symlink in ~/.aitools/rules` plus `ERROR\|cursor rules\|1 failed`. PS1: see R1. |
| N6 unreadable dir | Fixed | Bash `[ ! -r ] \|\| [ ! -x ]` gives `ERROR\|cursor rules\|cannot read harness rules`, the same row as PS1. Test `unreadable: ERROR row` passes. |
| N7 raw U+FEFF | Fixed | `grep -n -P "[^\x00-\x7F]" scripts/setup-user-cursor.ps1` hits only header lines 1-2 (em dashes, pre-existing). Code now uses `[char]0xFEFF`. |
| N8 case-insensitive names | Fixed | bash `lower_name` (tr) lists, PS1 `HashSet` with `OrdinalIgnoreCase`. The test is skipped on this case-insensitive APFS (expected). |

The contract change (sources are only `*.md`, and `*.bak.*` is skipped) matches in both scripts and in the same order: hidden, then `.bak.`, then not-`.md` (info log), then dangling link, then directory. My mutation run logged `Ignoring non-rule file in harness rules: native.mdc` and `notes.txt`. `old.md.bak.<ts>` was skipped silently, as the contract says.

## Non-blocking (new)

**R1. The PS1 dangling-symlink branch never fires on pwsh 7.6.3 (macOS).** `setup-user-cursor.ps1:481`:

```
if ($entry.LinkType -and -not (Test-Path -LiteralPath $entry.FullName)) { $ruleBroken += $entry.Name; continue }
```

On a dangling link, pwsh reports `LinkType: [SymbolicLink]`, `Test-Path: True`, `Test-Path -PathType Leaf: True`, `File.Exists: True`, and `Test-Path` on `.Target` gives False (`.scratch/session-hcrev/probe2.ps1`, `probe3.ps1`). So the link goes on as a source. `ReadAllText` then throws `MethodInvocationException`, and the existing read-failure path logs `Failed: broken.md: cannot read ...` and records `failed`. The ERROR row and exit 1 match bash, but the message differs and the new branch is dead code there. Windows behaviour is unknown.

Suggested fix: test the target, for example `-not (Test-Path -LiteralPath $entry.ResolveLinkTarget($true).FullName)`, or `$entry.Target`. Add a PS1 case to the probe if feasible.

**R2. A YAML comment inside a `paths:` list ends the list.** `.sh:413` and `.ps1:427` stop `in_paths` at `  # a comment`. Items after it pass through raw and un-anchored (`  - after-comment/**`), and Cursor's `cr` also drops them (its `a` resets on the comment line). Reproduced with `mix.md`. No repo rule has comments in `paths:`. Suggested fix: skip `^\s*#` lines while `in_paths`.

**R3. Small parity difference in the misparse check.** Bash runs `cursor_rule_check` on every non-empty deployed file. PS1 runs `Test-CursorRuleParse` only when the file starts with `---`. On a file with no frontmatter, bash logs an extra WARN on top of the ERROR. The outcome is identical (an ERROR row), so this is cosmetic.

**R4. Observation, a design trade-off and not a defect.** `**/` anchoring makes aitools project rules attach in any repo under HOME (`**/scripts/**` vs `repos/other/scripts/a.sh` gives true). That is option 1 from the first review and was chosen deliberately. It is in the converter's header comment, and S3-Harness/the commander should know it.

## What I verified, and how

- **Test suite:** `bash tests/rules-fanout-cursor/test-rules-fanout-cursor.sh` gave `76 passed, 0 failed, 1 skipped` (`SKIP dupcase (case-insensitive file system holds one file)`).
  - The new `resolve:` cases use a homemade glob model (`glob_match`), not Cursor's matcher. I cross-checked the same globs with Cursor.app's picomatch (above). The results agree.
- **Syntax:** `bash -n scripts/setup-user-cursor.sh` OK. pwsh `Parser::ParseFile` gave "PS1 parse OK".
- **Mutation run, adapted to the contract** (`.scratch/session-hcrev/seed-adv2.sh`, isolated HOME `home2`):
  - Sources: the 8 earlier `.md` adversarial inputs, the repo's config-file-safety.md and relay-outbound.md, a dangling `broken.md`, `mix.md` (absolute, `./`-relative, quoted `**/`, a comment in the list, preset `alwaysApply: true`), plus `notes.txt`, `old.md.bak.<ts>` and `native.mdc`.
  - Result: exit 1; `ERROR|cursor rules|1 failed`; 9 added; the broken link failed.
  - Cursor-parse (`cursor-parse.js`, Cursor's `lr`/`cr`/`Sc`/`ur` copied verbatim):

  ```
  brace.mdc: fileGlobbed ["**/src/**/*.{ts,tsx}"]
  col0.mdc: fileGlobbed ["**/scripts/**"]
  config-file-safety.mdc: fileGlobbed ["**/scripts/**","**/deploy/**","**/shared/**","**/reference/**","**/plans/**","**/rfcs/**","**/.claude/rules/**","**/.cursor/rules/**","**/CLAUDE.md","**/RELEASE_NOTES.md","**/ROADMAP.md","**/README.md"]
  dashes.mdc: global
  descdash.mdc: agentFetched | fm={"description":"before"}   (WARN logged)
  flow.mdc: fileGlobbed ["**/a/**","**/b/**"]
  mix.mdc: global | globs ["/abs/**","**/rel/**","**/keep/**"]   (after-comment item lost, R2)
  relay-outbound.mdc: fileGlobbed ["**/.aitools/channel/relay.md","**/scripts/relay-outbound-prompt.sh",...]
  unclosed.mdc: global
  ```
- **Parity of the new converter code** (`.scratch/session-hcrev/parity2.sh`): bash `cursor_rule_from_md` and PS1 `ConvertTo-CursorRule` (through the PR's `convert-rule.ps1`) give byte-identical output on all 9 adversarial inputs, plus a CRLF+BOM variant of `mix.md`: `PARITY OK` on 10 of 10.
  - `Test-CursorRuleParse` (PS1) flags only `descdash.mdc`, the same as bash `cursor_rule_check`.
  - The PS1 listing classification matches bash for every entry except the dangling link (R1).
- **Code read:** the `.sh`/`.ps1` step 4 diffs side by side.
  - Anchor rules are identical: trim, unquote, keep `**`, `/`, `**/`, `X:\`, `\\`, strip `./`.
  - Brace-aware flow split, dry-run ERROR row, preserved check and duplicate check all match.
  - Bash 3.2: no associative arrays or `mapfile`; `tr` lowercasing.
- **Research/draft:** both now mention the anchoring (`grep -c -E "rL|aL\(|anchor"` returns 4 in the research file and 5 in the draft `tool-ops-cursor.md`). Not re-read in full.

## What I did not verify

- Windows: PS1 end to end, and how a dangling symlink behaves there (R1).
- The Cursor CLI's glob anchoring (still unknown, as in the first review).
- That the IDE's `QJ.xF` is exactly picomatch. The signature `(path, glob, {dot:true})` and the bundled `node_modules/picomatch` are consistent with that, but I did not confirm it.
- A live canary (the CLI is unauthenticated).
- `build-deploy.sh` / MDM.
