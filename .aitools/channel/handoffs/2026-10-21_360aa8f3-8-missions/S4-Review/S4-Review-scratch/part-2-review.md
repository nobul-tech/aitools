## 2. Adversarial review of `reference/tool-support-decision-tree.md` (revision 2)

**Coverage.** I launched three reviewers with different lenses.
- **S4-Review-C** (ambiguity, duplication, vocabulary) completed. Its full table is in `S4-Review-C-review.md`.
- **S4-Review-A** (correctness vs rules) and **S4-Review-B** (cross-platform and bootstrap) wrote nothing. B left only `S4-Review-B-scratch/probe.sh`. The session restarted while they were running; the scratchpad was reset at the same time.

I covered A's and B's lenses only with targeted checks (S4-1..S4-9 below):
- read the existing helpers, the installer exports and the `write_summary` promotion;
- read the M3 lib block for bash 3.2 safety;
- grepped the M3 drafts for exit-2 use.

**The tree has not had a full correctness or Windows-execution pass. Recommend re-running A and B on `S4-Review-drafts/reference/tool-support-decision-tree.md` (rev 3) before the gate.**

### Fixed in the S4 copy (rev 3)

| ID | Sev | Section | Finding | Fix |
|---|---|---|---|---|
| C-01 | blocker | §8 | Two toolExceptions shapes, circular ownership | Merged shape; user-repo.md owns it (section 1 X1) |
| C-02 | blocker | §8, §7.2 | Writer refuses after registration (assumes config alias, "first profile" fallback) | via-based rule (X3) |
| C-03 | major | M3 user-repo.md | `method` examples are install kinds | registry method id or `unknown` |
| C-04 | major | M3 user-repo.md | "non-managed install" collides with governed "managed tool" | wording replaced in shape |
| C-05 | major | §3 KEEP | ACTION→log_warn→OK promoted to WARN, defeating D-TS10 | carry-forward ACTION exempt; WARN `(kept, not saved)` on failure |
| C-06 | major | §3, rule item 6 | D-TS10/11/12 pending but written as settled | rows marked "(pending)"; rule item 6 qualified |
| C-07 | major | glossary | "no post-check" contradicts version check | glossary draft fixed |
| C-09 | major | rule, glossary, FW, /tool-adopt | channel list restated 4× | rule and glossary point to the reference (FW and /tool-adopt still to fix, below) |
| C-10 | major | rule item 4 | `[i]nstall alongside` missing | rule copy fixed |
| C-11 | major | T1 | specificity tie undefined; ambiguity misreported | specificity = count of explicit matching dimensions; own detail `two methods for <platform>` + ACTION |
| C-12 | major | rule vs §9 | MUST without migration clause | rule copy: unmigrated scripts get fixes only; other changes migrate via /tool-adopt |
| C-13 | major | rule, §9 hook | "setup script" includes `setup-user-*` (and M3's new `setup-user-config`) | "tool setup script = named by `lifecycle.setupScript`" in rule and hook |
| C-15..C-17 | major | M3 glossary | identity / alias / "derived" collisions | renames + disambiguation (X10) |
| C-18 | major | §6 | `verified` field vs governed outcome | §6 defines the field's meaning (N-Q4) |
| C-19 | minor | §7.1 | generator and unverified known paths | generator emits only verified entries |
| C-20 | minor | §3 PREREQ | `not provided by claude-code-web` = 31 chars | `not in <env> image` |
| C-21, C-34 | minor | §8 | `environment` unused; `by` undefined | dropped / `decidedBy` = script base name |
| C-23 | minor | §7 | "adopt" claim inaccurate | reworded |
| C-24, C-25, C-35 | minor | interactive-menus | keep vs skip persistence; abort is future behaviour; third menu out of scope | merged copy |
| C-26, C-27 | minor | §2, rule | "Standard 4" cites the wrong file; "#12" ambiguous | cite script-standards-detail; "GitHub issue #12" |
| C-31, C-32 | minor | intents | rule purpose overstates; reference scope misses §7.5, /audit, hook | both intents redrafted (protected: need approval) |

### Not fixed in a copy: edits the M2 author must make to sibling drafts

These are recorded, not drafted, because the files are M2's and the fixes are mechanical.
- **C-08 (major).** `/tool-registry`, `/tool-adopt` and `/tool-eval` restate §6 and contradict it in three ways:
  - they say `kind` is required everywhere;
  - they say `update` or `autoUpdates` is required;
  - they say one preferred method "per environment".

  Replace each restatement with "every field in the reference 'Tool registry schema 1.1', validated by its conformance checks 1-6".
- **C-09, rest.** In the framework doc and `/tool-adopt` step 3, point to "Update channels".
- **C-14 (major).** Govern "detection signature" for the registry field, kept separate from the hook-layer term `detection`. This is a glossary item and needs a decision.
- **C-22.** In `/tool-adopt` and `/tool-eval`, replace "exception rule" / "exception to the decision tree" with "deviation from the decision tree".
- **C-28.** In the skills, cite sections by title, not by number.
- **C-29, C-30.** Glossary (done).
- **C-33.** In the framework doc, move the DRAFT banner above the intent block.

### S4-Review's own findings (correctness and cross-platform lenses, partial)

| ID | Sev | Section | Finding | Evidence | Disposition |
|---|---|---|---|---|---|
| S4-1 | major | §8 reader | Calling the M3 wrapper from a tool script would promote OK rows to WARN through resolver warnings | `aitools-lib.sh` `write_summary` lines 344-353 (WARNINGS>0 → WARN); profile block `log_warn` lines 88, 112 | fixed (X5) |
| S4-2 | major | §8 engine | perl/`ConvertFrom-Json` engine conflicts with M3's single node module, and `ConvertTo-Json` would rewrite a shared git file | M3 plan B1/B2; X4 | fixed: `exception-get/set` subcommands (new batch X-B1) |
| S4-3 | minor | §7.5 | "installers pass AITOOLS_FORCE" is wrong: the entry points export it | `scripts/aitools:307, :1577`; installers only read it (`aitools-install.sh:180`, `.ps1:87`) | fixed |
| S4-4 | minor | §7.5 / menus | Exit 2 = abort collides with lib return code 2 = error | profile block lines 57, 95, 131 | rule line added (X8) |
| S4-5 | minor | §8 PS1 | Exception reader must decode node output via a temp file | cross-platform.md "PowerShell pipeline encoding" | fixed |
| S4-6 | minor | §10 | No tests for a refused write, a missing store, the reader staying silent for preferred tools, or dry run with a pty | -- | 5 rows added |
| S4-7 | info | §7 | bash 3.2 rule: the M3 lib block complies | profile block read in full | none |
| S4-8 | info | §1, §7.2 | Cited helpers exist | `tty_interactive`, `read_tty_choice`, `Test-InteractiveConsole`, `Read-ConsoleChoice`, `Write-EnvironmentSkip`, `Refresh-Path`, `check_build_prereqs`, `diagnose_build_failure` (grep) | none |
| S4-9 | minor | §5 | macOS can use case-sensitive APFS volumes, so "case-insensitive on macOS" path matching can match the wrong path there | general platform fact; unknown whether any of Jose's machines use one | flag only; propose "case-insensitive on Windows; on macOS case-insensitive unless the volume is case-sensitive" for reviewer B |

**Prior-review fixes that landed (spot-check).** These rev-2 claims are present in the text:
- D-01: `rc=0; tool_support_run … || rc=$?` (§7.6);
- D-02: five removal guards (§7.3);
- A-04: EVALUATING leaf;
- C-04: PATH-resolved path, `versionedPath`;
- D-07: entry points in §7.5.

I did not re-verify the other ~45 dispositions. That was A's job.
