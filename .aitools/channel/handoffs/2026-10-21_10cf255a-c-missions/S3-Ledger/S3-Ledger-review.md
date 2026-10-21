# S3-Ledger review: incident batch #87-#128 (draft for commander approval)

**Mission:** LEDGER (S3-Ledger, Session Commander 10cf255a-c) · **Date:** 2026-10-21 · **Baseline:** origin/main c8573ed

`registries/incidents.json` is **not modified**. This folder holds the drafts:

- `S3-Ledger-incidents-batch.json`: 42 entries (#87-#128), ready to append to the `incidents` array in this order.
- `S3-Ledger-affected-updates.json`: `affected` changes (old → new, with reasons) for #21, #55, #59 and #76, plus one optional note for #51.

## Registry state (step 1)

- `registries/incidents.json` on c8573ed has 2,027 lines. Read with offset/limit in full. A python3 count gives 82 open, 4 closed (13, 14, 52, 53), 86 ids, max **86**, no duplicates, no gaps. The **next id is #87**.
- With the batch appended (simulated in memory): 128 unique ids, max 128, no gaps, about 3,080 lines, valid JSON.

## Id crosswalk

- S4 draft ids **#87-#112 are unchanged.**
- S4 draft **#113 ("Standard 4" cited as a rule section) is dropped** (see the dropped list).
- **Id #113 is reused** for the first new entry. That keeps the registry free of gaps. If you would rather keep #113 unassigned, see open question 1.
- New entries are #113-#128. They come in S2-Layout §7 order, then G17.

## Batch table

Source: **S4** = `S4-Review-incidents-draft.json`; **S2-n** = S2-Layout report §7 finding n; **G17-n** = handoff G17 item n (S3-Handoff-V). Every cited file:line was re-checked on c8573ed.

| Id | Title (short) | Sev | Source | Dedupe / edit note |
|---|---|---|---|---|
| 87 | Setup-script exit 2 (abort) treated as a failure; installer continues | high | S4 | Line refs added (installer :154-173, entry points :1604-1616 / ps1 :1495-1509) |
| 88 | setup-datadog.sh deletes any non-Homebrew pup after Homebrew install | high | S4 | Expected rewritten: F1 is met, D-TS3 is not. D-TS3 is recorded only in a draft |
| 89 | Tool scripts ignore AITOOLS_DRY_RUN; `--dry-run` mutates the machine | high | S4 | Confirmed: validate_and_run has no dry-run gate. `sudo rm -rf` is at setup-go.sh:104 (`$CLEANUP_TARGET`), not a literal `/usr/local/go` |
| 90 | Registry detection holds prose or commands; platformStatus off-enum | medium | S4 | Enum cited (criteria :96-107); "D1" → D-TS1 (draft-recorded) |
| 91 | Installer Step 8 OK for any node; node@22 keg-only, node = 26.3.1 | medium | S4 | Live values re-checked 2026-10-21 (node@22 22.22.3 keg-only; node v26.3.1) |
| 92 | setup-perl.sh requires Homebrew; registry prefers system perl | medium | S4 | Line refs added |
| 93 | framework-registry 'Tool operations' lists removed reference/tool-ops.json | **low** (was medium) | S4 | Narrowed: the "missing decision-tree artifacts" half is dropped because those artifacts are drafts only. Same class as #59/#115; PR-a fixes :183 |
| 94 | managed-file-deployment.md + .mdc cite a section that exists only in tool-lifecycle.mdc | medium | S4 | Affected corrected: interactive-menus.mdc out (no evidence); managed-file-deployment.mdc:57 and tool-lifecycle.md in. False "Dotprofile priority only in .mdc" claim removed |
| 95 | build-deploy.sh hardcodes Jose/Nobul/email defaults, used silently | high | S4 | "C1" (undefined in mission files) → SD-7 (approved) |
| 96 | MDM embeds claude-shared.md; dev path prefers dotprofile template | medium | S4 | Line refs added |
| 97 | user init writes config/profile without backup; profile catch swallows | medium | S4 | PS1 also checked: no Backup-File |
| 98 | inline_lib_* replace more than the dot-source line | medium | S4 | Title/observation made precise: PS1 matches any mention; bash matches `source.*aitools-lib.sh` |
| 99 | adopt_claude_md perl program built from shell values (@, /) | medium | S4 | Line refs; repro not re-run (cited S5-Profile-A H6) |
| 100 | Empty catch blocks in entry points and hh.ps1 | medium | S4 | All 10 sites re-verified |
| 101 | UNVERIFIED: user init writes MSYS-form userRepoPath on Git Bash | medium | S4 | Call chain traced (:973 → :977 → :1211); still UNVERIFIED on Windows |
| 102 | sources-of-truth omits skills and tool-registry.md; post-push step 10 lists it | low | S4 | Line refs added (sh :224-238, ps1 :264-274) |
| 103 | "Max 30 chars (compliance-checked)" has no check | low | S4 | Confirmed: the only 30-comparison is unrelated |
| 104 | Intent statements missing from rules, references, setup scripts, libs | low | S4 | "D9 / C6": C6 undefined, dropped; cites intent-writing SKILL:32-33 + D-TS9 (draft) |
| 105 | /tool-registry required fields absent from 16 of 18 entries | low | S4 | Corrected: no entry has `maintenance` |
| 106 | One evaluation file for 18 tools despite the tool-evaluation.md gate | low | S4 | — |
| 107 | setup-user-cursor installs ripgrep without a registry entry | low | S4 | Line refs added |
| 108 | cross-platform.md names nonexistent install_via_brew/apt | low | S4 | — |
| 109 | build-deploy.sh `eval "$PROFILE_VALS"` executes `$(...)` | low | S4 | — |
| 110 | Token interpolation corrupts `&` (bash 5.2) or `$` (PS1) | low | S4 | Noted: macOS /bin/bash 3.2 is not affected |
| 111 | ait-harvest.py reads config.json without BOM handling | low | S4 | Line refs added |
| 112 | cross-platform.md says C:\repos\ instead of %USERPROFILE%\repos | low | S4 | — |
| 113 | No check detects a skill name at more than one level; dotprofile silently wins | medium | S2-1 | Rescoped: the live hazard (9 untracked copies) was **resolved** 2026-10-21. The structural gap remains. Severity high → medium. Related #80 |
| 114 | check-post-push.ps1 reads removed reference/tool-versions.json (step 10 FAIL, 21 SKIP) | high | S2-2 | New. An instance of #115, kept separate because it is a functional check failure. Not covered by #59 (scripts, not skills) |
| 115 | No check verifies cited repo paths exist (34 stale registry refs in 17 files) | high | S2-3 | New. Umbrella detection gap; #59, #70, #84, #93, #114 are instances |
| 116 | Pre-commit step 16: PS1 misses registries/; tool-ops/tool-versions ignored; claimed scope not implemented | medium | S2-4 | New. Distinct from #50 (rules citing paths); this is the detector |
| 117 | dashboard-serve.sh silent with a hardcoded clone path; 6 hooks fall back to $HOME/repos/aitools | medium | S2-5 | tool-ops-session-audit.sh excluded (covered by #70) |
| 118 | MDM path omits dotprofile skills | medium | S2-6 | Skills half only. Hook half covered by #1 (no backup/review) and SD-2 (shared/hooks only) |
| 119 | setup-user-skills never prunes retired/renamed skills | medium | S2-7 | New |
| 120 | setup-user-skills deploys only SKILL.md and writes through symlinks into ~/.agents | medium | S2-8 | New |
| 121 | Shell rc `source` line never rewritten once the marker exists (latent) | medium | S2-9 | New. PS1 profile not checked |
| 122 | /incident next-id read truncates at 2,000 lines and ignores `closed` | medium | S2-10 | New (procedure); #84 is the path. Fix in the same PR-a |
| 123 | aitool-ops/aitool-eval trigger rules are project rules that never load outside aitools | medium | S2-11 | New. Related #24 (missing triggers); here they exist at the wrong level |
| 124 | No framework governs artifact placement | medium | S2-12 | New (governance ambiguity) |
| 125 | ~/.aitools/bin refreshed only by install; aitools/hh.sh orphans | low | S2-14 | New |
| 126 | incident-governance.md describes hooks absent from hooks-manifest.json | low | S2-15 | New |
| 127 | cursor user-rules.md describes a removed clipboard copy | low | S2-17 | New |
| 128 | /handoff does not warn about nested .claude/ drafts becoming live skills | medium | G17-1 | New. Related #113 |

Count: 26 from S4, 15 from S2-Layout, 1 from G17 = 42. Severity: 6 high, 21 medium, 15 low.

## Dropped (no new entry), with the incident that covers each

| Finding | Disposition | Covered by / reason |
|---|---|---|
| S4 #113 "Standard 4 cited as a rule section" | dropped | No live artifact makes the miscitation. `grep "Standard 4"` over .claude, shared, reference and plans finds only `reference/script-standards-detail.md:562` and plan citations of "Standard 3". The miscitation exists only in drafts (S5-Tools-drafts `dot-claude/rules/tool-lifecycle.md`, the decision-tree draft), which S4 already corrected in its copy. Fix at the gate as draft errata |
| S2-13 prefix inversion `aitools-` vs `aitool-` | routed to `/glossary` | A terminological ambiguity (incident-governance.md "Ambiguity routing"), not an incident |
| S2-16 tool-versions.json has no governing skill | folded into #21 | Same three-layer gap. See the #21 update |
| S2-18 RFC 0001 issues go to nobul-Jose/aitools, remote is nobul-tech | duplicate of #58 | #58 covers shared/claude-shared.md:29-30 and the dotprofile CLAUDE.md |
| S2-6 hook half (MDM `cat >` hooks, dotprofile hooks ignored) | covered | #1 (no backup or review on hook deploy); ignoring dotprofile hooks is the approved SD-2 state |
| S2-5 tool-ops-session-audit.sh hardcoded path | covered | #70 ("also ignores repoPath in ~/.aitools/config.json") |
| S2 trailing note "#59 incomplete" | affected update | See the #59 update (also removes the 5 reference/framework-*.md files, now fixed) |
| G17-2 `/delegate` not deployed; delegation.md not in ~/.claude/rules | dropped: resolved | Re-checked 2026-10-21: `ls ~/.claude/skills` lists `delegate`, and `ls ~/.claude/rules` lists `delegation.md` |
| G17-3 Grep tool sometimes not provisioned to delegates | recurrence of #51 | Optional observation note for #51 in the updates file. Confirmed again this session: S3-Ledger has no Grep or Glob tool, and bash `grep` ran unblocked |
| G17-4 S4 §5.2 cites PR creation times as merge times | dropped: draft errata | A factual error in a provenance report, not a harness deficiency. The handoff D.1 carries the correct mergedAt (02:54:28Z / 02:54:43Z / 02:56:00Z). Correct it on the review page |

## Affected-list extensions (summary; full text in the updates file)

| Id | Change | Why |
|---|---|---|
| 21 | − reference/tool-versions.json; + registries/tool-registry.json, registries/tool-versions.json, check-post-push.sh/.ps1 | File moved in v0.69.0. Checks still parse the md (steps 9, 10, 25). Folds S2-16 |
| 55 | + setup-pandoc.sh, setup-rust.sh, setup-vercelcli.sh, setup-go.ps1, setup-datadog.sh | Each removes before the replacement is verified (lines cited). F1 |
| 59 | − 5 reference/framework-*.md (fixed); + /frameworks, /audit, /tool-ops (+tests), /intent-audit, /optimize-plan, setup-bash.sh/.ps1, 3 .mdc mirrors, 2 reference files | Grep on c8573ed |
| 76 | + .claude/rules/managed-file-deployment.md:37, .cursor/.mdc:29, reference/managed-file-deployment.md:236 | Same "then first profile" endorsement |
| 51 (optional) | observation note only | G17-3 recurrence; the hook-block half no longer reproduces |

## Field-quality notes

- Every entry has all 19 required fields with valid enums (checked by the build script). No entry has an empty `affected`.
- Several S4 `expected` fields cited "commander decisions" D1, D3 and D9. They are D-TS1, D-TS3 and D-TS9, recorded as commander decisions (session 360aa8f3-8, 2026-10-20) **only in the draft** `reference/tool-support-decision-tree.md` §1. The entries now say so. C1 and C6 have no definition in the preserved mission files. C1 is replaced by SD-7 (approved, handoff D.3); C6 is removed.
- `referenceFile` is null for all 42 entries. None went through the full discovery cycle (steps 4-6).

## Not done

- No fix to any incident; no write to `registries/incidents.json`; no `/incident` skill path fix (#84 belongs to LAYOUT PR-a).
- Not re-run: S5-Profile reproductions behind #98 (H1) and #99 (H6); a Windows run for #101 and #114; the PS1 shell-profile block for #121.
