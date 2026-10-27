NON-BLOCKING

## Independent review of PR #101 (S3-H2-DraftsM3-Review, 2026-10-22)

Reviewer: S3-H2-DraftsM3-Review, delegated by S3-H2-DraftsM3. I did not write this PR. Base: the PR's merge-base is origin/main 8a9dcb5, which is also the current origin/main tip. "Approved text" means the #96 drafts on origin/main under `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-M3-Docs/`.

### Verdict

No blocking finding. Every protected-file change is either the approved text verbatim, or a deletion the approval terms allow (the banner, `VERIFY after #86 batch 5` notes whose behaviour ships on main, and clauses main's code disproves). The PR adds no wording the commander did not approve. Four landed sentences are still inexact on main (F1-F4). Each is a sentence the commander approved, and each already has corrected wording in the PR's re-approval draft (edits D, E, G, H, I). They can be fixed after merge, through re-approval.

### Method

- Rows 1, 9, 10, 11, 15, 16, 17: a scratch Perl script took each approved `.edit.txt`, applied every OLD -> NEW to the origin/main file (each OLD matched exactly once) and diffed the result with the PR branch file. Row 15 was run with edit 2 skipped.
- Row 2: compared the JSON of registries/glossary.json (main vs PR) against the approved strings.
- Row 3: diffed the approved full file with the PR's file, then classified each difference against the code on main.
- Re-approval drafts: counted each OLD block in the landed file and read every cited code line on origin/main.

### Results per row

| Row | File | Result |
|---|---|---|
| 1 | plans/tool-support-and-machine-profile.md | Identical to approved edits 1-4 applied to main |
| 2 | registries/glossary.json | Parses. Both definitions and the "machine alias" source match exactly. "machine profile" source = main's source + "; commander decision 5 of 2026-10-22", as approved. No other term or top-level key changed |
| 3 | reference/user-repo.md | Deletions only, 113-line diff (classified below) |
| 9 | .claude/rules/managed-file-deployment.md | Identical |
| 10 | .cursor/rules/managed-file-deployment.mdc | Identical; same NEW text as row 9 (parity holds for both edits) |
| 11 | reference/tool-support-decision-tree.md | Identical to edits 1-9 |
| 15 | reference/script-standards-detail.md | Identical to edits 1, 3, 4; edit 2 not applied |
| 16 | reference/logging.md | Identical |
| 17 | shared/skills/tool-adopt/SKILL.md | Identical to edits 1-2 |

Governed JSON paths: no rule or reference in the PR names a new one. The per-file counts of `registries/*.json` names match main. The only hits are pre-existing: decision-tree line 327 and the plan's gate table.

### Row 3 deletions, classified

| # | Deleted text (approved draft) | Class | Evidence (origin/main) |
|---|---|---|---|
| D0 | The `> DRAFT (S3-M3-Docs ...)` banner | (a) banner the draft says to remove | approved file lines 3-11: "Remove this banner when the file lands" |
| D1 | "The `aitools` entry points do not export it yet (S3-M3-B5a open question 1)." | (c) disproved | scripts/aitools:2049-2055; scripts/aitools.ps1:1999-2007 |
| D2 | VERIFY + "today this works only on Path 3 ..." (`--alias <new>` without a terminal) | (b) ships | scripts/aitools:676-679 (want -> ui_register alias), :486 |
| D3 | VERIFY (the confirm prompt) | (b) ships | scripts/aitools:498-514; aitools.ps1:1091ff |
| D4 | VERIFY + "today's menu passes `--alias <key>` ..." | (b) ships | scripts/aitools:479, 709-710 (`--claim`) |
| D5 | VERIFY + "today Paths 1 and 2 skip registration ..." | (b) ships | scripts/aitools:655-656, 962, 991 (commit=true), 550-551 |
| D6 | "(numbered)" | (c) disproved: only unowned profiles are numbered | scripts/aitools:411-421 |
| D6b | VERIFY "(the menu is to show each profile's alias and owner)" | (b) ships | scripts/aitools:412-421 (label = alias; other/unknown marked) |
| D7 | VERIFY after "user init runs `migrate`" | (b) ships | scripts/aitools:671 |
| D8 | "(register through user init excepted)" | (c) disproved: user init refuses to write | scripts/aitools:657-669 |
| D9 | "(Known exception ...: the legacy v1 -> v2 profile migration ... still writes `machineAlias` into config.json itself.)" | (c) disproved | scripts/aitools:732-733; the only write in the v1 node step is the temp profile file, :778 |
| D10 | VERIFY + "today user init passes `--machine-alias <alias>`" | (b) ships | scripts/aitools:1021, 1027 |
| D11 | CLI table VERIFY + "today only this machine's own 2.1 profile ..." | (b) ships | scripts/aitools:671 (ui_migrate -> resolver migrate) |

No difference falls in class (d). No word was added.

### Findings

| id | row | file | quote | evidence | severity | suggested fix |
|---|---|---|---|---|---|---|
| F1 | 3 | reference/user-repo.md:313-314 | "its only writer is `setup-user-config.sh` / `setup-user-config.ps1`" | scripts/aitools:1445-1469 (node `writeFileSync` on config.json, :1457); scripts/aitools.ps1:444-457 (:456) | medium, non-blocking. Approved text, inexact before D9 as well; D9 followed the approval terms | Re-approval draft edit H (already drafted); INCIDENT below |
| F2 | 3 | reference/user-repo.md:307-309 | "A commit is skipped when `profile.json` already had uncommitted changes before the write: the file is written, a warning asks the / user ..." | True for migrate/exception-set (aitools-profile.sh:1125-1132, 1537-1545, 969-970). False for user init, which refuses to write (scripts/aitools:657-669). The ragged line wrap comes from D8 | low | Re-approval edit G (already drafted); rewrap there |
| F3 | 3 | reference/user-repo.md:274-275 | "ERROR `machine profile` `not registered` + ACTION `Run: aitools user init --alias <alias>`" | Actual: "not registered (no terminal)" / "Run: aitools user init --alias <name> (or on a terminal)" (scripts/aitools:404-405; aitools.ps1:1004-1005) | low | Re-approval edit D (already drafted) |
| F4 | 3 | reference/user-repo.md:276, 349 | "(user init Path 1 without one, Path 3 new repo)"; "deploy-harness calls it too once PR #88 merges" | Path 2 also scaffolds (scripts/aitools:990-991). deploy-harness calls the writer on main (scripts/deploy-harness.sh:99-109); c8bfb09 is an ancestor of origin/main | low | Re-approval edits E and I (already drafted) |
| F5 | 3 | reference/user-repo.md:298 | "`aitools user init` runs `migrate` when 2.1 profiles exist." | It runs `migrate` on every clean profile.json (a no-op when none are 2.1). It never runs it when profile.json has uncommitted edits (scripts/aitools:657-671) | low; not in the re-approval draft | Optional: add to the re-approval draft, e.g. "... runs `migrate` on every run whose profile.json has no uncommitted changes (a no-op when every profile is id-keyed)." |
| F6 | re-approval draft | S3-H2-DraftsM3-drafts/reference/user-repo.md.edit.txt, edit F | "The interactive menu lists every profile by its alias" | The menu prints no line for a profile whose owner is `this` (no `this` branch: scripts/aitools:413-424; aitools.ps1:1013-1022). It is reached only when nothing matched by id, so in practice "every profile" holds | low | Optional: "lists every profile not already this machine's, by its alias" |
| F7 | 15 | (record) | Edit 2 held | The reason (installer call-site follow-up; installers still define their own jsonl_write / Write-JsonlRecord: scripts/aitools-install.sh:135, aitools-install.ps1:65, both confirmed) is recorded only in the PR body, not in a tracked file | low | Add one line to the S3-H2-DraftsM3 folder or a follow-up issue, so the hold is findable after merge |
| F8 | 9/10 | .cursor/rules/managed-file-deployment.mdc | (missing row) | .claude/rules/managed-file-deployment.md:48 has the deploy-harness row; the .mdc does not. Pre-existing, outside these rows, and already listed in the PR's Follow-ups | low | Separate parity edit (protected; needs approval) |

### Claims spot-checked and confirmed on origin/main

- Rows 9/10 resolution order (override -> environment -> id -> config machineId -> machineAlias (2.1) -> hostname -> none = error): aitools-profile.sh:478-488. `resolve_machine_profile` aitools-lib.sh:333, `Resolve-MachineProfile` aitools-lib.ps1:263. `/tool-adopt` step 5 "deployment types table for a new file type": SKILL.md:150, 159. `@reference/user-repo.md` "Resolution": landed heading line 185.
- Row 11: `AITLIB_TOOL_EXC_FOUND/_PLATFORM/_METHOD/_PATH/_DECIDED_AT` (aitools-lib.sh:379-398). PS1 `@{Found; Platform; Method; Path; DecidedAt}` (aitools-lib.ps1:325-331). `AITLIB_TOOL_EXC_RESULT/_PUSHED` and `$script:AitLibToolExcResult/Pushed` (aitools-lib.sh:420-459; ps1:351-366). Exit 2/4 -> 1 (aitools-lib.sh:458-462). Exit 4 = register refused (aitools-profile.sh:35, 134). exception-get ignores another owner's entry with a warning (:919). BatchMode (:990-992). Dirty-before check (:969-970). Rejected push advises pull --rebase (:998). Dry run (:1086).
- Row 15: Contents names at aitools-lib.sh:286, 333, 378, 419, 531, 569, 589 and ps1:218, 263, 312, 350, 449, 489, 510, exactly as cited. write_summary OK -> WARN when WARNINGS > 0 (aitools-lib.sh:863-866).
- Row 16: installers still use their own copies (aitools-install.sh:135, 153; aitools-install.ps1:65, 76). jsonl field order ts, host, os, script, run_id, level, msg (aitools-lib.sh:527-535).
- Row 2: config.json machineAlias is display-only (setup-user-config.sh:20-23). AITOOLS_MACHINE_ALIAS is an override (aitools-profile.sh:478; scripts/aitools:673-676).
- Row 1: deploy-harness calls the single writer (deploy-harness.sh:96-109). `--alias <new>` without a terminal registers (scripts/aitools:676-679). Scaffold, commit and push (:655-656, 550-551).

### Re-approval drafts

- user-repo.md.edit.txt: all 10 OLD blocks (A-I; E has two) occur exactly once in the landed file. Every cited line is real and says what the draft claims: scripts/aitools:403-405, 492-496, 655-656, 657-669, 732-733, 746-750, 819, 828-875, 1445-1469, 2049-2055; aitools.ps1:444-457, 1004, 1086-1088, 1999-2007; deploy-harness.sh:99-112; c8bfb09 merged. Small offset: edit F cites aitools.ps1:1004-1019; the menu loop is at 1010-1022.
- glossary.json.edit.txt: confirmed. The "profile" term (PR glossary.json line 426) still says "keyed by machine alias".

### Not run

No scripts or checks were run (review only). Pre-commit/pre-push results come from the PR body; I did not re-run them.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
