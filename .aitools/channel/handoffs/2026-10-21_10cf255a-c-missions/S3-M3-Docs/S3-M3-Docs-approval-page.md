# S3-M3-Docs approval page: M3 protected-file drafts (B9, B10, re-key batch 8)

**Intent**: **Purpose**: Put every protected-document change M3 needs in front of the
commander in one pass, as exact old -> new drafts that match the code as shipped (PRs
#80, #83, #86, #89, #90-#92, #95), with a recommendation and a dependency per row.
**Scope**: The 17 rows below and their drafts in `S3-M3-Docs-drafts/`. NOT any write to
a protected file or to the live dotprofile (nothing here is applied). NOT code changes.
NOT rows outside M3 (R1-R12, R15-R17, R21, R24-R25 belong to other missions).
**Audience**: Jose (approves), Session Commander 10cf255a-c and S3-M3Lead (route), the
apply mission (writes approved text verbatim).

S3-M3-Docs, 2026-10-22. Worktree `docs/m3-protected-drafts` from origin/main 15cc56a.
Approval covers the exact text only. Each draft file names its code citations
(branch:file:line). "VERIFY after #86 batch 5" marks text that describes user init
behaviour S3-M3-UserInit has not shipped yet: approve the text now, and the apply
mission checks it against batch 5 before writing.

## Summary

1. 17 rows: 12 re-adjust approved rows (R13, R14, R18, R19 x2, R20, R22 x3, R23 x2) to
   the code as shipped; 5 are new (decision record, glossary, tool-adopt line, decision
   tree, script-standards-detail + logging.md).
2. 3 rows depend on #86 batch 5 (rows 3, 4, 6): user init's `--claim`, duplicate-alias
   confirm, `migrate` call, scaffold commit, `--machine-id` caller.
3. Live dotprofile facts that change B10 (row 4): no profile has `machine.id`, so
   `migrate` alone re-keys nothing; today's user init cannot register nobul-mac (register
   refuses `--alias nobul-mac` with exit 4 and asks for `--claim`); `profile.json` has
   another session's uncommitted change, which user init's commit would sweep in.
4. One live-template repair is drafted (row 10, edit 2: `nobul-{{PROFILE_NAME}}` ->
   `nobul-jose`).
5. Suggested approval order = table order. Every recommendation is "approve" unless the
   row says otherwise.
6. Independent check (S3-M3-Docs-Check, `S3-M3-Docs-Check-findings.md`): all 41 OLD
   blocks match their targets exactly once; 1 blocker, 4 major, 16 minor findings on
   behaviour claims, all applied to the drafts below (blocker F1: `--alias <new>`
   without a terminal does not yet work on an existing profile.json -- now marked
   VERIFY after batch 5).

## Rows

| # | File | Section | Reason | Draft | Depends on | Recommendation |
|---|------|---------|--------|-------|------------|----------------|
| 1 | `plans/tool-support-and-machine-profile.md` | Machine identity bullet; P-Q12 row; 3 new bullets; P-Q6 row (optional) | Commander decisions 1, 5, 6, 7 (2026-10-22) not yet recorded | `S3-M3-Docs-drafts/plans/tool-support-and-machine-profile.md.edit.txt` | -- | Approve edits 1-3; edit 4 optional (approve: it records your own note) |
| 2 | `registries/glossary.json` (via `/glossary`) | "machine alias", "machine profile" definitions | Decision 5: alias is a label, profiles keyed by id | `S3-M3-Docs-drafts/registries/glossary.json.edit.txt` | #86 merged | Approve |
| 3 | `reference/user-repo.md` | Full rewrite (R18; intent unchanged from the approved text) | R18 + decision 5 + code as shipped | `S3-M3-Docs-drafts/reference/user-repo.md` (diff vs the reviewed S3-Profile base below) | #86 (incl. **batch 5**: Registration and Migration bullets marked VERIFY), #83, #95 | Approve; apply after #86 merges |
| 4 | dotprofile `profile.json` | Add `meta` (schemaRevision 2.2 + intent) | R23 / B10, re-derived from the live file (X17) | `S3-M3-Docs-drafts/dotprofile/profile.json.edit.txt` | **batch 5** (`--claim` to register nobul-mac), #86 merged and pulled on both machines | Approve the text; apply in B10 after this Mac registers |
| 5 | `setup-user-config.sh` / `.ps1` config.json `meta.intent.scope` | `CONFIG_INTENT_JSON` / `$configIntentJson` | R23 (config.json half): `machineId` added | `S3-M3-Docs-drafts/scripts/setup-user-config.sh.edit.txt` edit 3 | lands on #86 | Approve (rewrites each config.json once, with a backup) |
| 6 | `setup-user-config.sh` / `.ps1` | Header `Intent:` | R22: `--machine-id` / `-MachineId` | `S3-M3-Docs-drafts/scripts/setup-user-config.sh.edit.txt` edits 1-2 | lands on #86; **batch 5** (user init passes `--machine-id`; today `--machine-alias`) | Approve |
| 7 | `aitools-profile.sh` / `.ps1` | Header `Intent:` | R22: `migrate` writes profile.json; consumers after #95 | `S3-M3-Docs-drafts/scripts/aitools-profile.sh.edit.txt` | 1a: lands on #86; 1b: #95 | Approve |
| 8 | `aitools-lib.sh` / `.ps1` | New relay-section `Intent:` | R22 lib section intents (new section in #86) | `S3-M3-Docs-drafts/scripts/aitools-lib.sh.edit.txt` | lands on #86 | Approve |
| 9 | `.claude/rules/managed-file-deployment.md` | "Content sources" (2 bullets); "Updating this table" | R13 + S3-M3-Claude INCIDENT (first-profile fallback removed) | `S3-M3-Docs-drafts/dot-claude/rules/managed-file-deployment.md.edit.txt` | #83, #95 | Approve |
| 10 | `.cursor/rules/managed-file-deployment.mdc` | Same 2 places | R14 mirror of row 9 | `S3-M3-Docs-drafts/dot-cursor/rules/managed-file-deployment.mdc.edit.txt` | with row 9 | Approve |
| 11 | `reference/tool-support-decision-tree.md` | D-TS4; 7; 7.2 (2 rows); 8 Location, Engine, Writer, Carry-forward; Changes at landing | S3-M3-LibFix tree draft + decision 5 | `S3-M3-Docs-drafts/reference/tool-support-decision-tree.md.edit.txt` | #80, #86 | Approve |
| 12 | `shared/claude-shared.md` | Cross-Platform Awareness (+2 lines) | R19 | `S3-M3-Docs-drafts/shared/claude-shared.md.edit.txt` | #83 (`{{USER_REPO_PATH}}` token) | Approve |
| 13 | dotprofile `claude/CLAUDE.md` | Same 2 lines (R19); lines 42-43 repair | R19 template sync; S3-M3-Claude INCIDENT (adopt corruption) | `S3-M3-Docs-drafts/dotprofile/claude/CLAUDE.md.edit.txt` | #83 | Approve both edits |
| 14 | `.claude/rules/deploy-paths.md` | Duplication table; auto-embedded list; heading; step 2 | R20, superseded by S3-M3-B5a's draft (adopted unchanged) | `S3-M3-Docs-drafts/dot-claude/rules/deploy-paths.md.edit.txt` | #95 | Approve (replaces the approved R20 text, which named aitools-profile.js) |
| 15 | `reference/script-standards-detail.md` | Contents rows; Usage (JSONL override); Function definition; Summary coverage | S3-M3-Install / LibKey / ConfigKey INCIDENTs; keydesign j | `S3-M3-Docs-drafts/reference/script-standards-detail.md.edit.txt` | edits 1, 3, 4: #86; edit 2: #86 + the installer call-site follow-up | Approve |
| 16 | `reference/logging.md` | deploy.jsonl row; new section 7 "Library-style tools" | keydesign j finding 1 (INCIDENT) | `S3-M3-Docs-drafts/reference/logging.md.edit.txt` | #86 | Approve |
| 17 | `shared/skills/tool-adopt/SKILL.md` | Cross-References lines 211, 216 | Re-key design section d | `S3-M3-Docs-drafts/shared/skills/tool-adopt/SKILL.md.edit.txt` | row 3 landed | Approve (may not need approval: T-Q8) |

Rows depending on #86 batch 5: **3, 4, 6**.

## Open questions (each with a suggested answer)

1. **Org in the templates**: both CLAUDE.md templates link `nobul-jose/aitools`, but the
   repo is `nobul-tech/aitools`. Suggested: change both to `nobul-tech/aitools` in a
   separate edit after this batch (row 13 edit 2 only repairs the corruption).
2. **The live dotprofile's pending `effortLevel` change** (another session): suggested,
   whoever made it commits or reverts it before B10, so registration commits only its own
   change.
3. **Scaffolded profile.json has no `meta.intent`** (`register --create` writes only
   `meta.schemaRevision`): suggested, batch 5 or a follow-up writes the approved row-4
   intent in the scaffold, so new dotprofiles carry it.
4. **`--alias` rename of a duplicate**: none needed now; the resolver warns on every run.

## INCIDENT markers (not filed)

- INCIDENT: user init's `ui_commit` (origin/feature/m3-rekey:scripts/aitools:345-356)
  commits `profile.json` without the dirty-before check the resolver's `commit_profile`
  has (scripts/aitools-profile.sh:950-972), so a hand edit already in `profile.json` is
  committed under "Register machine profile: ...". The live dotprofile is in that state
  now.
- INCIDENT: the S3-M3-ConfigKey and S3-M3-Resolver reports disagree on whether today's
  user init re-keys a 2.1 profile. Code: the via=id path calls `register`
  (scripts/aitools:426-431), and register re-keys this machine's own 2.1 profile
  (aitools-profile.sh:1281-1298, 1363-1365); it does not run `migrate` for the other
  profiles. So the Resolver report is right for this machine's profile. The
  setup-user-config ACTION `Run: aitools user init (re-keys machine profiles by machine
  id)` fires only for this machine's own 2.1 profile (via=id + migrate warning,
  aitools-profile.sh:693-694), which today's user init already re-keys; the ConfigKey
  merge condition ("#86 must not merge before batch 5" for this reason) looks
  overstated. Other machines' 2.1 profiles need `migrate` (batch 5). Suggested: S3-M3Lead
  re-checks the merge condition with S3-M3-UserInit.
- INCIDENT: scaffolded profile.json carries no `meta.intent` (open question 3).
- INCIDENT (checker): the legacy v1 -> v2 migration in `aitools user init` writes
  config.json `machineAlias` with node and creates alias-keyed profiles without
  `machine.id` (origin/feature/m3-rekey:scripts/aitools:121-242; aitools.ps1:130,
  224-230), bypassing the single config writer and the resolver.
- INCIDENT (checker): stale comments say the entry points export
  `AITOOLS_USER_REPO_PATH` (origin/feature/m3-b5-build-deploy:scripts/build-deploy.sh:173-174;
  origin/feature/m3-rekey:scripts/aitools-profile.sh:16-18); none does. Row 7 fixes the
  resolver header; build-deploy.sh needs a code fix.
- INCIDENT (checker): for a profile.json that was dirty before `exception-set`, the
  wrappers add ACTION "run git push in <dir>" although nothing was committed
  (aitools-lib.sh:443-447, .ps1:371-376); their headers still describe exit 3 as
  "matched by hostname only or not at all" (aitools-lib.sh:413-414, .ps1:345-346).
- INCIDENT (checker): `aitools user init --alias <new>` without a terminal fails on an
  existing profile.json (scripts/aitools:290-315, 422-436), so P-Q12 / commander
  decision 1 are not met until batch 5.

## Drafts

### Row 1 -- plans/tool-support-and-machine-profile.md

File: `S3-M3-Docs-drafts/plans/tool-support-and-machine-profile.md.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- protected file plans/tool-support-and-machine-profile.md
(the gate decision record). Edits 1-2 are the re-key design's wording drafts
(S3-M3-Register-keydesign.md section i), exact against main 15cc56a. Edit 3 records
commander decisions 5-7 of 2026-10-22 (S3-M3Lead-plan.md section 2), which are not in
the record yet. Edit 4 is optional. Not applied.

The table rows record the commander's answers; edits 2 and 4 append to an answer
rather than rewrite it, so the 2026-10-21 answer stays readable.

================================================================
Edit 1 -- "Decisions that change the drafts", Machine identity bullet (line 23-25)
================================================================
OLD:
- **Machine identity**: raw machine ids (P-Q2); resolver is native `scripts/aitools-profile.sh/.ps1`

NEW:
- **Machine identity**: raw machine ids (P-Q2), and machine profiles are keyed by them: `profiles.<machineId>` (lower-cased), human-readable name in the profile's `alias` field, tool exceptions at `profiles.<machineId>.toolExceptions`; legacy alias-keyed profiles are still read and re-keyed by `aitools-profile migrate` (commander, 2026-10-22); resolver is native `scripts/aitools-profile.sh/.ps1`

(Only the first line of the bullet changes; "(P-Q3), not JavaScript; one scutil
command ..." continues unchanged on the next lines.)

================================================================
Edit 2 -- table row P-Q12, Decision column
================================================================
OLD:
| P-Q12 | Non-blocking | Non-interactive registration: add aitools user init --alias <A>? | Add --alias |  |

NEW:
| P-Q12 | Non-blocking | Non-interactive registration: add aitools user init --alias <A>? | Add --alias (sets the alias field of this machine's id-keyed profile; an alias used by another machine's profile is refused without a terminal, and needs an interactive confirm otherwise -- commander, 2026-10-22) |  |

================================================================
Edit 3 -- new bullets at the end of "Decisions that change the drafts"
(after "- **Re-run the correctness (A) review as an independent delegate** (E-independence).")
================================================================
OLD:
- **Re-run the correctness (A) review as an independent delegate** (E-independence).

NEW:
- **Re-run the correctness (A) review as an independent delegate** (E-independence).
- **Registration never overwrites another machine** (commander, 2026-10-22): `aitools user init --alias <new>` without a terminal creates this machine's profile; an alias used by another machine's profile is refused unless the run is interactive and the user confirms.
- **`aitools user init` scaffolds a missing profile.json** (identity + this machine's profile under its id), commits and pushes it (commander, 2026-10-22).
- **config.json is generated from profile.json by deploy-harness**, which calls `setup-user-config.sh/.ps1`, the single writer (commander, 2026-10-22).

(Source: S3-M3Lead-plan.md section 2, decisions 1, 6 and 7. Decision 2 is still
PENDING there and is not recorded. Decision 5 is edit 1.)

================================================================
Edit 4 (optional) -- table row P-Q6, Decision column
================================================================
OLD:
| P-Q6 | Non-blocking | Move googleDrives into profile.json now? | Later, under profiles.<alias>.googleDrives | later, but it should be under profiles.machineid or whatever.google drives and it should store the path and the name of the drive or whatever we can pull |

NEW:
| P-Q6 | Non-blocking | Move googleDrives into profile.json now? | Later, under profiles.<alias>.googleDrives (now `profiles.<machineId>.googleDrives`, the commander's note; commander, 2026-10-22) | later, but it should be under profiles.machineid or whatever.google drives and it should store the path and the name of the drive or whatever we can pull |
````

### Row 2 -- registries/glossary.json (via /glossary)

File: `S3-M3-Docs-drafts/registries/glossary.json.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- governed glossary entries (registries/glossary.json,
written only through the /glossary skill; protected). Two modified terms. No term is
added or removed, so .claude/rules/glossary.md (the word list) does not change. Not
applied.

Process followed (/glossary): both terms are already governed (glossary.md lines 75-77);
this is a definition change driven by commander decision 5 (2026-10-22); "alias" (base
artifact) stays distinct, as the current definition already says.

================================================================
Term "machine alias" (glossary.json, terms["machine alias"])
================================================================
OLD definition:
"The key of a machine profile (for example nobul-mac). Chosen or registered at aitools user init (non-interactively with --alias) and cached per machine in ~/.aitools/config.json machineAlias, which is re-derived on every run. Not the base artifact 'alias' (a shell alias file)."

NEW definition:
"The human-readable name of a machine profile (its 'alias' field, for example nobul-mac). Since profile.json revision 2.2 it is a label, not the key: machine profiles are keyed by machine id. Chosen at aitools user init (non-interactively with --alias), selectable with --alias or AITOOLS_MACHINE_ALIAS, and written to ~/.aitools/config.json machineAlias as a display value. In a revision 2.1 profile.json the alias was the key. Not the base artifact 'alias' (a shell alias file)."

OLD source: "reference/user-repo.md (after M3); decision P-Q12 (plans/tool-support-and-machine-profile.md)"
NEW source: "reference/user-repo.md \"Profile Schema\"; decisions P-Q12 and commander decision 5 of 2026-10-22 (plans/tool-support-and-machine-profile.md)"

================================================================
Term "machine profile" (glossary.json, terms["machine profile"])
================================================================
OLD definition:
"A field inside the profile (profile.json): one entry of its 'profiles' object, keyed by machine alias, holding one machine's (or one hosted environment's) per-machine overrides of identity name/company, machine id, and tool exceptions. Chosen on every run by the machine resolver (scripts/aitools-profile.sh/.ps1); never another machine's profile as a fallback. Not a separate file and not a shell profile (.zshrc, PowerShell $PROFILE)."

NEW definition:
"A field inside the profile (profile.json): one entry of its 'profiles' object, keyed by machine id (environment:<name> for a hosted environment without one), holding one machine's (or one hosted environment's) machine alias, per-machine overrides of identity name/company, machine id, and tool exceptions. Chosen on every run by the machine resolver (scripts/aitools-profile.sh/.ps1); never another machine's profile as a fallback. Not a separate file and not a shell profile (.zshrc, PowerShell $PROFILE)."

Source unchanged, plus "; commander decision 5 of 2026-10-22".

Code cited: origin/feature/m3-rekey:scripts/aitools-profile.sh:25-30 (keys and the
alias field), :495-528 (id-keyed vs legacy), :1219-1431 (register writes only this
machine's key).
````

### Row 3 -- reference/user-repo.md (R18)

Full new file: `S3-M3-Docs-drafts/reference/user-repo.md`. Shown here as a diff
against the S3-Profile base (the R18 text reviewed and landed as a draft by PR #78:
`S3-Profile/S3-Profile-drafts/reference/user-repo.md`). Against main the file is a
full rewrite (main has no intent, Resolution or Config v3 sections).

````diff
diff --git a/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Profile/S3-Profile-drafts/reference/user-repo.md b/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-M3-Docs/S3-M3-Docs-drafts/reference/user-repo.md
index 6bbafb2..e8ae6a5 100644
--- a/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Profile/S3-Profile-drafts/reference/user-repo.md
+++ b/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-M3-Docs/S3-M3-Docs-drafts/reference/user-repo.md
@@ -2,10 +2,10 @@
 
-> DRAFT (S3-Profile, 2026-10-21) for row R18: the approved S4-Review draft with its
-> "(unchanged from the current file)" placeholders filled from main 507a6e1 and the
-> later decisions applied (P-Q2 raw ids, P-Q3 native resolver + JSON engines, P-Q5 one
-> macOS hostname source, P-Q12 --alias, N-Q2 dotprofile writes commit and push, a
-> node-free config writer). Lands as reference/user-repo.md with M3 B9 (docs once the
-> code they describe exists: lib wrappers B2, installer wiring B3b, user init B6/B7,
-> runtime deploy B5). The intent text is the approved one with `aitools-profile.js`
-> replaced by `aitools-profile.sh` / `aitools-profile.ps1` (P-Q3).
+> DRAFT (S3-M3-Docs, 2026-10-22) for row R18. Base: the S3-Profile draft
+> (`.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-Profile/S3-Profile-drafts/reference/user-repo.md`),
+> adjusted for machine profiles keyed by machine id (commander decision 5, 2026-10-22;
+> re-key design S3-M3-Register-keydesign.md section i) and checked against the code as
+> shipped on PR #86 (resolver, lib, config writer), #83 (setup-user-claude) and #95
+> (build-deploy). Lines marked `VERIFY after #86 batch 5` describe user init behaviour
+> that batch 5 (S3-M3-UserInit) is still implementing. The intent statement is the
+> approved one, unchanged. Remove this banner when the file lands.
 
@@ -44,8 +44,11 @@ which implement the same commands, options and output (P-Q3; parity tested by
 (`@scripts/aitools-lib.ps1`), or run `aitools-profile.sh user-repo-path` directly.
-`build-deploy.sh` receives the result from the entry point as `AITOOLS_USER_REPO_PATH`
-(forward-slash form); on macOS/Linux a standalone run asks `aitools-profile.sh` itself.
+`build-deploy.sh` takes the dotprofile from `AITOOLS_USER_REPO_PATH` when the caller
+sets it (check-pre-push step 7 does); otherwise it asks `resolve_user_repo_path` in a
+child bash. The `aitools` entry points do not export it yet (S3-M3-B5a open question 1).
 
-Path forms: config.json stores the native OS form; the exported `AITOOLS_USER_REPO_PATH`
-uses forward slashes (`C:/...` on Windows), valid in Git Bash, PowerShell and node
-(`@reference/logging.md` §2). `aitools-profile.ps1 --path-form mixed` prints that form.
+Path forms: config.json stores the native OS form; a leading `~` in its `userRepoPath`
+or `reposPath` is expanded to the home directory by both resolvers. The exported
+`AITOOLS_USER_REPO_PATH` uses forward slashes (`C:/...` on Windows), valid in Git Bash,
+PowerShell and node (`@reference/logging.md` §2). `aitools-profile.ps1 --path-form mixed`
+prints that form.
 
@@ -54,3 +57,5 @@ layout (LF, no BOM), so every writer of the shared `profile.json` produces the s
 bytes. The bash side uses `scripts/aitools-json.pl` (core perl, no modules); the
-PowerShell side uses `scripts/aitools-json.ps1`.
+PowerShell side uses `scripts/aitools-json.ps1`. A UTF-16 config.json or profile.json is
+rejected with `<file> is UTF-16 encoded, not UTF-8 -- save it as UTF-8` (config.json: a
+warning, resolution continues without it; profile.json: an error).
 
@@ -71,9 +76,12 @@ aitools-<username>/
 
-## Profile Schema (v2, revision 2.1)
+## Profile Schema (v2, revision 2.2)
 
 `profile.json` holds every user-specific and user-customizable value, including every
-machine the user has. It stays `"version": 2`: revision 2.1 only adds optional fields,
-because aitools releases before this revision treat any version other than 2 as v1 and
-offer a destructive migration. Removing a field that older releases read (for example a
-profile's `company`) waits until every machine runs revision-2.1 code.
+machine the user has. It stays `"version": 2`: aitools releases before revision 2.1
+treat any version other than 2 as v1 and offer a destructive migration. Revision 2.1
+added optional fields (`meta`, `identity.name` / `company`, `machine.id`,
+`toolExceptions`); revision 2.2 keys each machine profile by its machine id and adds the
+`alias` field. Removing a field that older releases read (a profile's `company`, or
+`machine.id` inside an id-keyed profile) waits until every machine runs revision-2.2
+code.
 
@@ -83,7 +91,7 @@ profile's `company`) waits until every machine runs revision-2.1 code.
   "meta": {
-    "schemaRevision": "2.1",
+    "schemaRevision": "2.2",
     "intent": {
-      "purpose": "Source of truth for one user's identity, tool preferences and machine inventory, shared across the user's machines through git",
-      "scope": "identity, claude.settings, cursor.cli, overrides, and one profile per machine (machine.id, hostname, per-machine name/company overrides, toolExceptions). NOT per-machine bootstrap pointers (~/.aitools/config.json). NOT secrets or credentials. NOT session transcripts (sessions/)",
-      "audience": "aitools-profile.sh/.ps1 (resolver; the only writer of machine entries and toolExceptions), setup-user-config, aitools user init, setup-user-settings, setup-user-claude, setup-user-cursor, build-deploy.sh, and the tool setup scripts through the tool exception helpers"
+      "purpose": "Source of truth for one user's identity, tool preferences and machine profiles, shared across the user's machines through git",
+      "scope": "identity, claude.settings, cursor.cli, overrides, and one machine profile per machine, keyed by its machine id (environment:<name> for a hosted environment), with its alias, machine facts, per-machine name/company overrides and toolExceptions. NOT per-machine bootstrap pointers (~/.aitools/config.json). NOT secrets or credentials. NOT session transcripts (sessions/)",
+      "audience": "aitools-profile.sh/.ps1 (the resolver; the only writer of machine profiles and toolExceptions: register, migrate, exception-set), aitools user init, setup-user-config, setup-user-settings, setup-user-claude, setup-user-cursor, build-deploy.sh, and the tool setup scripts through the tool exception helpers"
     }
@@ -100,3 +108,4 @@ profile's `company`) waits until every machine runs revision-2.1 code.
   "profiles": {
-    "<alias>": {
+    "<machine id, lower-cased>": {
+      "alias": "<human-readable machine name, e.g. nobul-mac>",
       "name": "<optional override of identity.name>",
@@ -104,5 +113,4 @@ profile's `company`) waits until every machine runs revision-2.1 code.
       "machine": {
-        "id": "<the platform's stable machine id, raw>",
-        "environment": "claude-code-web",
-        "hostname": "<hostname when registered>",
+        "id": "<the same machine id: repeats the key>",
+        "hostname": "<short hostname at registration>",
         "hostnames": ["<optional extra names>"],
@@ -126,2 +134,6 @@ profile's `company`) waits until every machine runs revision-2.1 code.
       }
+    },
+    "environment:claude-code-web": {
+      "alias": "web",
+      "machine": { "environment": "claude-code-web", "os": "linux", "arch": "x64" }
     }
@@ -133,3 +145,4 @@ profile's `company`) waits until every machine runs revision-2.1 code.
 - **`identity`** -- shared across all machines. `name` and `company` (2.1) are the
-  defaults for every profile; a profile's own `name`/`company` overrides them.
+  defaults for every profile; a profile's own `name`/`company` overrides them. Without
+  `identity.name` the resolver uses `identity.git.name`.
 - **`cursor`** -- Cursor CLI preferences. Read by `setup-user-cursor`.
@@ -140,4 +153,14 @@ profile's `company`) waits until every machine runs revision-2.1 code.
   only; mirrors the `overrides` section of the tool registry (`/tool-registry` skill).
-- **`profiles`** -- keyed by alias. One per machine (or per environment, e.g. a Claude
-  Code web profile with `machine.environment: "claude-code-web"`).
+- **`profiles`** (2.2) -- one machine profile per machine, keyed by the raw machine id,
+  lower-cased; `machine.id` repeats the key until every machine runs 2.2 code. A hosted
+  environment without a stable id uses the key `environment:<name>`, e.g.
+  `environment:claude-code-web` (no platform id contains `:`). Key lookups ignore case.
+  A profile is id-keyed when its key equals its `machine.id` (ignoring case) or starts
+  with `environment:`; any other profile is a 2.1 profile keyed by alias ("legacy"),
+  which is still read and is re-keyed by `migrate` (see "Migration to id keys").
+- **`alias`** (2.2) -- the machine profile's human-readable name (governed term
+  "machine alias"), shown in logs and in the CLAUDE.md footer, and selectable with
+  `--alias` / `AITOOLS_MACHINE_ALIAS`. It is a label, not the key: letters, digits, `_`
+  and `-`, starting with a letter or digit, and never shaped like a machine id.
+  `alias` lookups are case-sensitive. A legacy profile without `alias` uses its key.
 - **`machine.id`** (2.1) -- the platform's stable id, stored raw (P-Q2): macOS
@@ -151,13 +174,18 @@ profile's `company`) waits until every machine runs revision-2.1 code.
   ephemeral) and use `machine.environment`.
-- **`machine.hostname`** -- informational and a legacy match key only.
+- **`machine.hostname`** -- the short hostname at registration. It selects a profile
+  only as the legacy fallback (resolution step 5); on an id match a different live
+  hostname is reported (a rename, or a clone that shares the id). Registration updates
+  it unless it or `machine.hostnames` already matches.
 - **`toolExceptions`** (2.1) -- per-machine `[k]eep` decisions of the tool support
-  decision tree. The shape is fixed here; when an entry is written, read and
-  matched is `@reference/tool-support-decision-tree.md` section 8. Entries are
-  read and written only through `aitools-profile.sh` / `.ps1` (`exception-get` /
-  `exception-set`, wrapped by `tool_exception_get` / `tool_exception_record` and
-  `Get-ToolException` / `Set-ToolException`). `exception-set` writes in place
-  (temp -> validate -> backup -> move), then commits only `profile.json` and pushes
-  (N-Q2). `detected.platform` uses the `$AITOOLS_PLATFORM` values (`macos`, `linux`,
-  `windows`), not `machine.os` (`darwin`, `linux`, `win32`). Distinct from top-level
-  `overrides`: an exception keeps a whole install; an override changes a setting.
+  decision tree, at `profiles.<machineId>.toolExceptions.<slug>`. The shape is fixed
+  here; when an entry is written, read and matched is
+  `@reference/tool-support-decision-tree.md` section 8. Entries are read and written
+  only through `aitools-profile.sh` / `.ps1` (`exception-get` / `exception-set`,
+  wrapped by `tool_exception_get` / `tool_exception_record` and `Get-ToolException` /
+  `Set-ToolException`), and only in this machine's own profile. `exception-set` writes
+  in place (temp -> validate -> backup -> move), then commits only `profile.json` and
+  pushes (N-Q2). `detected.platform` uses the `$AITOOLS_PLATFORM` values (`macos`,
+  `linux`, `windows`), not `machine.os` (`darwin`, `linux`, `win32`). Distinct from
+  top-level `overrides`: an exception keeps a whole install; an override changes a
+  setting.
 - **v1 migration** -- v1 (flat schema) is detected by the absence of `"version": 2`;
@@ -171,3 +199,3 @@ profile's `company`) waits until every machine runs revision-2.1 code.
 
-1. `AITOOLS_USER_REPO_PATH` (explicit; set by the entry point for build-deploy, and by tests). Missing directory = error.
+1. `AITOOLS_USER_REPO_PATH` (explicit; set by tests and by check-pre-push step 7 for build-deploy). Missing directory = error.
 2. `--user-repo-path` argument (user init's choice). Missing directory = error.
@@ -185,22 +213,44 @@ wins; every result carries `via`:
 |---|---|---|---|
-| 1 | Override alias (`AITOOLS_MACHINE_ALIAS`, or `--alias` / user init's `--machine-alias`) | `override` | unknown alias = error |
-| 2 | Environment `claude-code-web`: the one profile with that `machine.environment` | `environment` | two such profiles = error |
-| 3 | `machine.id` equals this machine's id | `id` | id on two profiles = error |
-| 4 | config.json `machineAlias` | `alias` | unknown alias = warning, continue |
-| 5 | Hostname: text before the first dot, trimmed, ASCII lower-cased. One source per platform (P-Q5): macOS `scutil --get LocalHostName` (the kernel hostname comes from DNS/DHCP and is never used), Windows `COMPUTERNAME`, Linux `uname -n` | `hostname` (warning: register) | two matches = error |
+| 1 | Override (`AITOOLS_MACHINE_ALIAS`, or `--alias`): a profiles key (ignoring case), else a profile whose `alias` field matches | `override` | unknown = error; one alias on two profiles = error that lists their keys (select by key) |
+| 2 | Environment `claude-code-web`: key `environment:claude-code-web` (2.1 fallback: the one profile whose `machine.environment` is `claude-code-web`; warns: migrate) | `environment` | two 2.1 environment profiles = error |
+| 3 | `profiles[<this machine's id>]` (2.1 fallback: a profile whose `machine.id` equals this id; warns: migrate) | `id` | id on two profiles = error |
+| 4 | config.json `machineId`, only when this machine's id cannot be detected | `config` | unknown key = warning, continue |
+| 4L | 2.1 cache: config.json `machineAlias` naming an alias-keyed profile (skipped when config.json has `machineId`; ignored with a warning when that profile has another machine's id) | `alias` | unknown alias = warning, continue |
+| 5 | Hostname: text before the first dot, trimmed, ASCII lower-cased, against `machine.hostname` / `machine.hostnames`. One source per platform (P-Q5): macOS `scutil --get LocalHostName` (the kernel hostname comes from DNS/DHCP and is never used), Windows `COMPUTERNAME`, Linux `uname -n` | `hostname` (warning: register) | two matches = error |
 | 6 | None | `none` | **error**; no other profile's values are used |
 
-Warnings: a profile selected by steps 1 or 4 that has no `machine.id` asks for
-registration; a profile whose `machine.id` belongs to another machine is reported; a
-config alias that disagrees with the id match is reported (the id wins).
+Every result also reports `key` (the profiles key that matched), `alias` (its `alias`
+field, else its key), `owner` (`this`, `other`, `unregistered` = no `machine.id`,
+`unknown` = it has a `machine.id` but this machine's id cannot be detected, `absent` =
+no match) and `legacy` (`true` for a profile still keyed by alias). A match is not the
+same as "this machine's profile": writers of per-machine data require `owner` = `this`.
+
+Warnings: a 2.1 profile matched by id or environment asks for `migrate`; a profile
+selected by an override or the cache that has no `machine.id` asks for registration; a
+profile registered to another machine is reported; an alias used by two profiles is
+reported on every resolve of that alias; on an id match, a stored hostname that differs
+from the live one is reported (renamed machine, or a clone sharing the id -- the only
+clone signal); a config `machineId` or `machineAlias` that disagrees with the id match
+is reported (the id wins); a key that disagrees with its own `machine.id` is reported.
 
 On `none`, consumers still receive identity-level values (identity name, company, git);
-machine-specific tokens stay unresolved and the run reports `write_summary ERROR
-"machine profile" "no machine match"` plus `ACTION Run: aitools user init`.
+machine-specific tokens stay unresolved and the run reports ERROR `machine profile`
+`no machine match` (from setup-user-config and from each consumer) and an ACTION to run
+`aitools user init`.
 
-Every consumer logs one line, e.g. `machine profile: alias=nobul-mac via=id company=nobul-tech hosts=nobul-mac id=<IOPlatformUUID>`.
+Every consumer logs one detail line, e.g. `machine profile: alias=nobul-mac via=id
+key=<id> owner=this legacy=false company=nobul-tech host=nobul-mac id=<IOPlatformUUID>`.
 
 Exit codes of `aitools-profile`: 0 resolved, 1 nothing found (expected states, e.g.
-before `aitools user init`), 2 error, 3 refused (`exception-set` only). A setup script
-never passes 2 through as its own exit code (exit 2 means a user abort, D-TS13).
+before `aitools user init`), 2 error, 3 refused (`exception-set` without a profile
+registered to this machine; `register` without a detectable machine id; any write to an
+`AITOOLS_PROFILE_FILE` snapshot), 4 refused (`register`: the alias is used by another
+profile, or `--claim` names another machine's profile). The lib wrappers never return 2: they map 2, 3 and 4 to their own codes
+(`@scripts/aitools-lib.sh` "Resolver exit codes"). A setup script never passes 2 through
+as its own exit code (exit 2 means a user abort, D-TS13).
+
+Logging contract: the resolver is a library-style tool (`@reference/logging.md`
+"Library-style tools"). It returns every warning and error as a `warn` / `error` output
+line and logs it at `detail`; the caller logs each at its level and owns the summary
+rows.
 
@@ -208,9 +258,71 @@ never passes 2 through as its own exit code (exit 2 means a user abort, D-TS13).
 
-Path 1 (repo present), Path 2 (clone) and Path 3 (new repo) all resolve first. When the
-result is `none` or `hostname`, user init asks (numbered aliases, `[n]ew`, `[s]kip`;
-identical in bash and PowerShell), or takes `--alias <A>` without a terminal (P-Q12);
-then `aitools-profile register` writes `machine.id`, `hostname`, `os`, `arch`, `shell`
-into that profile (temp file -> validation -> backup -> move), and user init commits
-and pushes the dotprofile (N-Q2). Without a terminal and without `--alias` it reports
-ERROR + ACTION and does not guess.
+`aitools-profile register` writes only this machine's profile -- `profiles[<this id>]`,
+or `profiles["environment:<name>"]` on Claude Code web -- to a temp file (`--out`); it
+never writes, renames or deletes another machine's profile. user init validates the
+temp file, backs up `profile.json`, moves it into place, then commits only
+`profile.json` and pushes best-effort (N-Q2). The fields written: `alias`,
+`machine.id` (the lower-cased key), `machine.hostname` (unless it or `hostnames` already
+matches), `os`, `arch`, `shell`; `name` / `company` only when neither the profile nor
+`identity` has one.
+
+- **Alias**: `--alias`, else the profile's current alias, else the short hostname.
+- **This machine's 2.1 profile** (alias-keyed, `machine.id` = this id) is re-keyed under
+  this id in the same write (position kept; `alias` = the old key unless `--alias`).
+- **A new id** creates the profile: `aitools user init --alias <new>` registers this
+  machine without a terminal (P-Q12; commander decision 1). `VERIFY after #86 batch 5`
+  (today this works only on Path 3; with an existing profile.json, user init first
+  resolves `--alias` as an override, an unknown alias does not resolve, and without a
+  terminal the run ends with ERROR `machine profile` `not registered`).
+- **An alias already used by another profile** (its alias or key, ignoring case) is
+  refused with exit 4 and that profile's `owner` / `ownerKey`. Interactive user init
+  may ask the user to confirm and then pass `--allow-duplicate-alias`; the other
+  profile is not touched and every resolve of that alias then warns (when the two
+  aliases are identical; one that differs only in case does not warn). `VERIFY after #86
+  batch 5` (the confirm prompt).
+- **A 2.1 profile with no `machine.id`** (unclaimed) is moved under this id only with
+  `--claim <key>`, which user init passes after the user picks that profile at a
+  terminal. `--claim` of another machine's profile is refused (exit 4). `VERIFY after
+  #86 batch 5` (today's menu passes `--alias <key>`, which register refuses with exit 4
+  and the hint `--claim <key>`).
+- **No detectable machine id** (not Claude Code web): refused, exit 3 -- a machine
+  profile is keyed by the id.
+- **Without a terminal and without `--alias`**: ERROR `machine profile` `not
+  registered` + ACTION `Run: aitools user init --alias <alias>`; nothing is guessed.
+- **No profile.json** (user init Path 1 without one, Path 3 new repo): `register
+  --create` scaffolds `version 2`, `meta.schemaRevision "2.2"`, `identity` and this
+  machine's profile; user init commits and pushes it (commander decision 6). `VERIFY
+  after #86 batch 5` (today Paths 1 and 2 skip registration when profile.json is
+  missing; Path 3 scaffolds it and commits it in its initial commit).
+
+The interactive menu lists every profile (numbered), `[n]ew`, `[s]kip`, identically in
+bash and PowerShell. `VERIFY after #86 batch 5` (the menu is to show each profile's
+alias and owner).
+
+### Migration to id keys (`aitools-profile migrate`)
+
+`aitools-profile.sh` / `.ps1 migrate [--profile F] [--dry-run]` re-keys every 2.1
+profile that has a `machine.id` to that id, lower-cased, and every 2.1 profile with
+`machine.environment` to `environment:<name>`; `alias` is set to the old key when the
+profile has none. Positions and contents are otherwise unchanged. Profiles with neither
+stay as they are and are reported as unclaimed (registration claims them). Two profiles
+that would get one key, or an id-shaped key that disagrees with its `machine.id`, are
+an error and nothing is written. Write path: temp -> validate (every re-keyed profile's
+key = its `machine.id`) -> backup -> move, then commit only `profile.json` ("Migrate
+machine profiles to id keys") and push. Outcomes: `migrated`, `unchanged`, `dry-run`,
+`refused` (an `AITOOLS_PROFILE_FILE` snapshot), `failed`. It is the one command that
+changes profiles other than this machine's: a mechanical rename of keys, never of their
+contents.
+
+`aitools user init` runs `migrate` when 2.1 profiles exist. `VERIFY after #86 batch 5`.
+
+No flag day for the resolver: a resolver that predates revision 2.2 still matches an
+id-keyed profile through its `machine.id` (step 3) or its hostname, with one extra
+warning. This does not hold for setup-user-claude before PR #83: it looks up
+`profiles[config machineAlias]`, then the node hostname, then the first profile, so
+after a migrate it can take another machine's values. Migrate the live dotprofile only
+after #86 and #83 are merged to main and pulled on every machine.
+
+A commit is skipped when `profile.json` already had uncommitted changes before the
+write (register through user init excepted): the file is written, a warning asks the
+user to review and commit it by hand.
 
@@ -219,3 +331,5 @@ ERROR + ACTION and does not guess.
 `~/.aitools/config.json` is per machine, untracked, and **derived**: its only writer is
-`setup-user-config.sh` / `setup-user-config.ps1`. Do not edit it by hand.
+`setup-user-config.sh` / `setup-user-config.ps1`. Do not edit it by hand. (Known
+exception, to be removed: the legacy v1 -> v2 profile migration in `aitools user init`
+still writes `machineAlias` into config.json itself.)
 
@@ -229,2 +343,3 @@ ERROR + ACTION and does not guess.
   "userRepoPath": "/Users/pepe/repos/aitools-nobul-jose",
+  "machineId": "aaaaaaaa-1111-2222-3333-444444444444",
   "machineAlias": "nobul-mac",
@@ -243,5 +358,6 @@ ERROR + ACTION and does not guess.
 | `googleDrives` | detected | installer Step 4 (kept when nothing is detected) | `aitools install` |
-| `githubUser` | derived | `--github-user`, else `profile.json identity.github` | user init / every sync |
+| `githubUser` | derived | `--github-user`, else `profile.json identity.github`, else the current config.json value | user init / every sync |
 | `userRepoPath` | derived | "Which dotprofile" (not saved when it came from `AITOOLS_USER_REPO_PATH`) | every run |
-| `machineAlias` | derived | "Which machine profile" (cached result; not saved from `AITOOLS_MACHINE_ALIAS`) | every run |
+| `machineId` | derived | "Which machine profile": the matched key, only for this machine's id-keyed profile; read back only when live id detection fails (step 4). Removed when the derivation yields an alias but no id (a 2.1 alias-keyed profile, or another machine's profile); kept when nothing is derived | every run |
+| `machineAlias` | derived | the matched profile's alias: display only, kept for one release for readers of 2.1 code; the cache for a 2.1 alias-keyed profile (step 4L). Not saved from `AITOOLS_MACHINE_ALIAS` or a hostname match | every run |
 | `meta` | self-description | writer | -- |
@@ -249,8 +365,15 @@ ERROR + ACTION and does not guess.
 Callers: installer Step 5 (bootstrap values), `aitools user init` (GitHub user,
-dotprofile path, chosen alias), and the first entry of every `aitools` deploy list
-(re-derivation). Write path: read-then-merge (every other key kept in place) -> temp ->
-validate -> `backup_file` -> move; outcomes created / updated / verified (no write) /
-recovered (invalid JSON rebuilt from salvaged keys, WARN). The writer needs no node
-(P-Q3). Resolver warnings about the cached config.json are corrected by the write and
-logged as info; warnings that need the user add an ACTION.
+dotprofile path, chosen profile: `--machine-id <key>` / `-MachineId <key>`; the old
+`--machine-alias` / `-MachineAlias` is accepted for one release, both together = ERROR
+`bad arguments`; `VERIFY after #86 batch 5`: today user init passes `--machine-alias
+<alias>`), and the first entry of every `aitools` deploy list (re-derivation).
+deploy-harness calls it too once PR #88 merges. Write path: read-then-merge (every other
+key kept in place) -> temp -> validate -> `backup_file` -> move; outcomes created /
+updated / verified (no write) / recovered (invalid JSON rebuilt from salvaged keys,
+WARN). The writer needs no node (P-Q3) and never prompts; exit 0 done (warnings
+possible) or 1, never 2. Resolver warnings about the cached config.json are corrected
+by the write and logged as info. Advice that needs the user is one ACTION row, written
+after the config row with one counted `log_warn`: `Run: aitools user init (registers
+this machine)`, `(re-keys machine profiles by machine id)` or `(updates this machine's
+profile)`, in that precedence.
 
@@ -311,12 +434,31 @@ Setup scripts read CLAUDE.md templates in priority order -- on the dev path
 
-Tokens, resolved **at run time on the target machine** by the resolver:
-`{{PROFILE_NAME}}`, `{{PROFILE_COMPANY}}`, `{{IDENTITY_GIT_NAME}}`, `{{IDENTITY_GIT_EMAIL}}`,
-`{{USER_REPO_PATH}}` (display form: `~/...` on macOS/Linux, `%USERPROFILE%\...` on Windows).
-An empty value leaves its token in place. The generated deploy scripts embed the resolver
-and a snapshot of `profile.json` (`aitools-profile snapshot`, without `claude.settings`);
-they use the live `profile.json` when the dotprofile exists on the machine and the
-snapshot otherwise, so one committed deploy/ is correct for every machine.
-
-The deployed `~/.claude/CLAUDE.md` ends with a `## Machine-Specific` footer: OS, arch,
-hostname, the resolved profile alias, and shell.
+A dotprofile that cannot be resolved (a resolver error, not "no dotprofile") deploys
+nothing: ERROR `claude.md` `not deployed: dotprofile unresolved`, so the shared
+template never replaces the personal CLAUDE.md.
+
+Tokens, resolved **at run time on the target machine** from the
+`resolve_machine_profile` / `Resolve-MachineProfile` results (never another machine's
+values): `{{PROFILE_NAME}}`, `{{PROFILE_COMPANY}}`, `{{IDENTITY_GIT_NAME}}`,
+`{{IDENTITY_GIT_EMAIL}}`, `{{USER_REPO_PATH}}` (display form: `~/...` on macOS/Linux,
+`%USERPROFILE%\...` on Windows). Substitution is one pass and literal (`&`, `$`, `\1` in
+a value stay as written; a value containing token text is not substituted again). An
+empty value leaves its token in place. On `[a]ccept & adopt` the adopt filter strips the
+footer and turns values back into tokens in one pass, longest value first; for equal
+text `{{PROFILE_NAME}}` wins (P-Q13).
+
+The generated deploy scripts (`setup-user-claude`, `setup-user-settings`,
+`setup-user-cursor`) embed the resolver (`aitools-profile`, `aitools-lib`,
+`aitools-json`, `.sh` and `.ps1`), write it to a temp directory when they run, and
+point `AITOOLS_PROFILE_SH` / `AITOOLS_PROFILE_PS1` at it. `setup-user-claude` also
+embeds the build-time template, rules and a snapshot of `profile.json` (`aitools-json.pl
+snapshot`: version, identity, cursor, profiles; no `claude.settings`) and uses the live
+dotprofile when it exists on the machine and the embedded copies otherwise;
+`setup-user-cursor` falls back to the build-time `cursor.cli` values;
+`setup-user-settings` skips the sync without a dotprofile. So one committed deploy/ is
+correct for every machine.
+
+The deployed `~/.claude/CLAUDE.md` ends with a `## Machine-Specific` footer:
+`- Machine: <OS> <arch> (<hostname>; profile <alias, or unresolved>)` and `- Shell:
+<shell>`. The hostname uses the resolver's source and form. The PowerShell footer has no
+arch yet (PR #83 follow-up n3).
 
@@ -336,3 +478,5 @@ Setup scripts deploy user-level Claude Code rules from `<userRepoPath>/claude/ru
 
-**Build-time embedding**: `build-deploy.sh` reads user rules at build time and embeds them in deploy scripts via heredocs. If no rules exist at build time, deploy scripts skip rules deployment.
+**Build-time embedding**: `build-deploy.sh` embeds the dotprofile's rules at build time
+as the fallback for a machine without the dotprofile; a machine with the dotprofile
+deploys its own `claude/rules/`. If no rules exist at build time, the fallback is empty.
 
@@ -360,3 +504,3 @@ User repos hold personal data only. This boundary is intentional:
 |---------|-------------|
-| `aitools user init` | Set up or clone the dotprofile, register this machine's profile, write config.json via setup-user-config |
+| `aitools user init [--alias <alias>]` | Set up or clone the dotprofile, register this machine's profile (re-keying 2.1 profiles; `VERIFY after #86 batch 5`: today only this machine's own 2.1 profile that already has its `machine.id`), write config.json via setup-user-config |
 | `aitools sessions list [project]` | List archived sessions |
@@ -375,2 +519,8 @@ directory -- `sessions move` only changes where the archive copy lives.
 
+### Cloned machines share one profile
+
+Cloned Linux images (and Windows clones that were not sysprepped) share a machine id, so
+they share one id-keyed profile; this cannot be detected from the id. The hostname
+warning on an id match is the only signal.
+
 ### Resolver parity limits
````

### Row 4 -- dotprofile profile.json meta (R23 / B10)

File: `S3-M3-Docs-drafts/dotprofile/profile.json.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- dotprofile profile.json meta (row R23 / batch B10;
protected: an intent statement). Re-derived from the LIVE file (X17), read-only:
/Users/new-jose/repos/aitools-nobul-jose/profile.json (dotprofile HEAD db37f89;
profile.json unchanged since bce27bb) plus one
uncommitted change by another session (claude.settings.modelSettings.claude-opus-5-5
.effortLevel "medium" -> "high"; not ours, left alone). Not applied.

What the live file holds today (read 2026-10-22):
- version 2; NO meta; identity {github nobul-jose, email jose@nobul.tech, git {Jose,
  jose@nobul.tech}} -- no identity.name / identity.company; cursor.cli {vimMode true,
  model auto}; claude.settings (13 keys); NO overrides key.
- profiles, all keyed by alias (revision 2.0 shape), none with machine.id:
  laptop {name Jose, company Nobul, machine {hostname Joses-MBP, darwin, arm64, zsh}},
  nobul-mac {name Jose, company nobul-tech, machine {hostname nobul-mac, darwin, arm64,
  bash}}, workstation {name pepe, company nobul.tech, machine {hostname NewcoPC, win32,
  x64, pwsh}}.

Why the S4-Review / S5-Profile drafts are not copied: they predate bce27bb (X17), name
aitools-profile.js (P-Q3), say "keyed by alias", and list "overrides", which the live
file does not have (kept in scope as optional: the schema defines it).

Consequences for B10 (facts from the shipped code, for the apply mission):
1. `migrate` re-keys only profiles that have machine.id
   (origin/feature/m3-rekey:scripts/aitools-profile.sh:1469-1481). The live file has
   none, so `migrate` alone changes nothing: all three are "unclaimed". nobul-mac is
   re-keyed when this Mac registers and claims it (`register --claim nobul-mac`,
   sh:1301-1320); laptop and workstation stay alias-keyed until their machines register.
2. Today's user init (pre-batch-5) on the live file: resolve matches nobul-mac by
   hostname; picking it passes `--alias nobul-mac`, which register refuses with exit 4
   ("alias ... used by profile nobul-mac, which is not registered ... --claim",
   sh:1339-1351). Registration of the live file needs batch 5's `--claim`.
   VERIFY after #86 batch 5.
3. No resolver command writes meta.intent: `register --create` writes only
   meta.schemaRevision "2.2" (sh:1242) and `migrate` writes no meta. So the meta block
   below is a hand edit in B10 (backup first, commit, push -- N-Q2), after the
   registration above.
4. profile.json is dirty right now. The resolver's commit_profile refuses to commit a
   profile.json that had uncommitted changes before its write (sh:950-958, 969-972);
   user init's ui_commit does not check and would commit the other session's change
   under "Register machine profile: ..." (scripts/aitools:345-356). Commit or revert the
   pending effortLevel change before B10.
5. P-Q1 (approved): add identity.name "Jose" and identity.company "nobul-tech"; keep the
   per-profile Nobul / nobul.tech / pepe values until all machines run 2.1+ code.

================================================================
Edit -- add "meta" as the second top-level key (after "version")
================================================================
OLD:
{
  "version": 2,
  "identity": {

NEW:
{
  "version": 2,
  "meta": {
    "schemaRevision": "2.2",
    "intent": {
      "purpose": "Source of truth for one user's identity, tool preferences and machine profiles, shared across the user's machines through git",
      "scope": "identity, claude.settings, cursor.cli, overrides, and one machine profile per machine, keyed by its machine id (environment:<name> for a hosted environment), with its alias, machine facts, per-machine name/company overrides and toolExceptions. NOT per-machine bootstrap pointers (~/.aitools/config.json). NOT secrets or credentials. NOT session transcripts (sessions/)",
      "audience": "aitools-profile.sh/.ps1 (the resolver; the only writer of machine profiles and toolExceptions: register, migrate, exception-set), aitools user init, setup-user-config, setup-user-settings, setup-user-claude, setup-user-cursor, build-deploy.sh, and the tool setup scripts through the tool exception helpers"
    }
  },
  "identity": {

Notes:
- "schemaRevision": "2.2" is true only once at least one profile is id-keyed; until
  this Mac registers, the file is a 2.0/2.1 mix. Suggested: write meta in the same B10
  commit as the nobul-mac claim.
- The same intent text is in the R18 draft's example (reference/user-repo.md "Profile
  Schema"), so the reference and the live file agree. Approve them as one text.
- setup-user-settings also writes profile.json (claude.settings, on adopt); it is in the
  audience, and "only writer of machine profiles and toolExceptions" stays true -- with
  one known exception, not named in the intent: the legacy v1 -> v2 migration in
  `aitools user init` (origin/feature/m3-rekey:scripts/aitools:121-242) writes
  alias-keyed profiles itself (S3-M3-Docs-Check F4; INCIDENT in the approval page). It
  only runs on a v1 file, which the live dotprofile is not.
````

### Rows 5 and 6 -- setup-user-config.sh/.ps1 intents and config.json meta.intent

File: `S3-M3-Docs-drafts/scripts/setup-user-config.sh.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- intent statements in scripts/setup-user-config.sh
and scripts/setup-user-config.ps1 (rows R22 code intent + R23 config.json meta.intent).
Source: S3-M3-ConfigKey-report.md "Drafts for approval" 1-3, made exact against
origin/feature/m3-rekey (1c89444). Not applied; the apply mission pushes it to PR #86
(or its successor) -- these files are owned by the re-key PR.

Timing for edits 1-2: "callers ... pass --machine-id" is true only after batch 5;
today user init passes --machine-alias (origin/feature/m3-rekey:scripts/aitools:1296,
1302; aitools.ps1:1261). Apply edits 1-2 with batch 5 (VERIFY after #86 batch 5).

Effect: edit 3 changes meta.intent.scope, so every machine's config.json is rewritten
once (with a backup) on its next run: meta differs, so the outcome is "updated".

================================================================
Edit 1 -- setup-user-config.sh header, lines 4-9
================================================================
OLD:
# Intent: Build this machine's ~/.aitools/config.json from two inputs -- the
# bootstrap values its callers pass (repos path, aitools repo path, detected
# Google Drives) and the values derived from the dotprofile's profile.json by
# aitools-profile.sh (dotprofile path, GitHub user, machine alias and how it was
# chosen). NOT a writer of profile.json (machine registration is `aitools user
# init`). NOT an interactive prompt (callers prompt, then pass --machine-alias).

NEW:
# Intent: Build this machine's ~/.aitools/config.json from two inputs -- the
# bootstrap values its callers pass (repos path, aitools repo path, detected
# Google Drives) and the values derived from the dotprofile's profile.json by
# aitools-profile.sh (dotprofile path, GitHub user, this machine's profile key --
# machineId -- with its display alias, and how they were chosen). NOT a writer of
# profile.json (machine registration is `aitools user init`). NOT an interactive
# prompt (callers prompt, then pass --machine-id).

================================================================
Edit 2 -- setup-user-config.ps1 header, lines 3-8
================================================================
OLD:
# Intent: Build this machine's ~/.aitools/config.json from two inputs -- the
# bootstrap values its callers pass (repos path, aitools repo path, detected
# Google Drives) and the values derived from the dotprofile's profile.json by
# aitools-profile.ps1 (dotprofile path, GitHub user, machine alias and how it was
# chosen). NOT a writer of profile.json (machine registration is `aitools user
# init`). NOT an interactive prompt (callers prompt, then pass -MachineAlias).

NEW:
# Intent: Build this machine's ~/.aitools/config.json from two inputs -- the
# bootstrap values its callers pass (repos path, aitools repo path, detected
# Google Drives) and the values derived from the dotprofile's profile.json by
# aitools-profile.ps1 (dotprofile path, GitHub user, this machine's profile key --
# machineId -- with its display alias, and how they were chosen). NOT a writer of
# profile.json (machine registration is `aitools user init`). NOT an interactive
# prompt (callers prompt, then pass -MachineId).

The "Consumed by" sentence (sh:10-11, ps1:9-10) is unchanged; deploy-harness is added
by mission HARNESS when PR #88 merges (it calls the writer:
origin/feature/harness-deploy-harness:scripts/deploy-harness.sh:99-112).

================================================================
Edit 3 -- config.json meta.intent (R23), identical text in both files:
setup-user-config.sh:227 CONFIG_INTENT_JSON and setup-user-config.ps1:233 $configIntentJson
================================================================
OLD (the "scope" value only):
"scope":"Bootstrap pointers (reposPath, repoPath), detected googleDrives, and values derived from profile.json (githubUser, userRepoPath, machineAlias). NOT identity or preferences (profile.json). NOT hand-edited: setup-user-config is the only writer"

NEW:
"scope":"Bootstrap pointers (reposPath, repoPath), detected googleDrives, and values derived from profile.json (githubUser, userRepoPath, machineId, and machineAlias as a display value). NOT identity or preferences (profile.json). NOT hand-edited: setup-user-config is the only writer"

"purpose" and "audience" are unchanged.
````

### Row 7 -- aitools-profile.sh/.ps1 intent

File: `S3-M3-Docs-drafts/scripts/aitools-profile.sh.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- intent statements in scripts/aitools-profile.sh and
scripts/aitools-profile.ps1 (row R22: code intents). Source: S3-M3-Resolver-report.md
"Drafts for approval" (migrate), plus the consumer list after PR #95. Exact against
origin/feature/m3-rekey (1c89444). Not applied (owned by the re-key PR #86).

After applying, delete the interim header lines that point at this approval
(sh:22-24, ps1:20-22, "Writers: `migrate` also writes profile.json ... awaits
commander approval.").

================================================================
Edit 1a -- migrate (S3-M3-Resolver draft), both files
aitools-profile.sh:9-13 / aitools-profile.ps1:8-12
================================================================
OLD:
# (setup-user-config.sh/.ps1 is the only writer). NOT a writer of profile.json
# except the `register` subcommand, which writes to a temp file the caller
# validates, backs up and moves, and the `exception-set` subcommand, the only
# writer of toolExceptions, which writes in place (temp, validate, backup, move)
# and commits and pushes profile.json. NOT the settings.json sync

NEW:
# (setup-user-config.sh/.ps1 is the only writer). NOT a writer of profile.json
# except the `register` subcommand, which writes to a temp file the caller
# validates, backs up and moves, the `exception-set` subcommand, the only writer
# of toolExceptions, and the `migrate` subcommand, which re-keys profiles by
# machine id; those two write in place (temp, validate, backup, move) and commit
# and push profile.json. NOT the settings.json sync

(Code: register writes only --out, sh:1418; exception-set and migrate write in place
and call commit_profile, sh:1128-1132 and sh:1540-1545.)

================================================================
Edit 1b -- consumers after PR #95 (depends on #95 merged)
aitools-profile.sh:16-19 (also drops the claim that the entry point exports
AITOOLS_USER_REPO_PATH: no entry point does -- S3-M3-Docs-Check F16; build-deploy
reads the variable when a caller sets it, else asks resolve_user_repo_path, which on
Windows runs aitools-profile.ps1 through pwsh)
================================================================
OLD:
# tool_exception_record, setup-user-config.sh, build-deploy.sh (on macOS/Linux;
# under Git Bash on Windows it uses the AITOOLS_USER_REPO_PATH the entry point
# exports), aitools `user init`, and the generated deploy/setup-user-claude.sh
# (embedded copy).

NEW:
# tool_exception_record, setup-user-config.sh, build-deploy.sh (through
# resolve_user_repo_path, unless its caller sets AITOOLS_USER_REPO_PATH), aitools
# `user init`, and the generated deploy/setup-user-claude.sh,
# setup-user-settings.sh and setup-user-cursor.sh (embedded copies).

aitools-profile.ps1:15-16
OLD:
# Set-ToolException, setup-user-config.ps1, aitools.ps1 `user init`, and the
# generated deploy/setup-user-claude.ps1 (embedded copy).

NEW:
# Set-ToolException, setup-user-config.ps1, aitools.ps1 `user init`, and the
# generated deploy/setup-user-claude.ps1, setup-user-settings.ps1 and
# setup-user-cursor.ps1 (embedded copies).

(Code: origin/feature/m3-b5-build-deploy:scripts/build-deploy.sh embeds the resolver
into the claude, settings and cursor deploy scripts; S3-M3-B5a-report.md item 3.)
````

### Row 8 -- aitools-lib.sh/.ps1 relay section intent

File: `S3-M3-Docs-drafts/scripts/aitools-lib.sh.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- section intent for the child-log relay section of
scripts/aitools-lib.sh and scripts/aitools-lib.ps1 (new intent statement; row R22 lib
section intents). Source: S3-M3-LibKey-report.md "Protected-file drafts awaiting
approval", wording kept, consumer names checked. Not applied (owned by PR #86).

Where: aitools-lib.sh, immediately after the header line
"# log helpers", PR #89, so installers and deploy-harness share one copy)" (sh:468);
aitools-lib.ps1, immediately after the same header line (ps1:398).

NEW (insert, both files):
# Intent: give every parent script (installers, deploy-harness) one way to run a
# child setup script and keep its log in deploy.jsonl: show the child's console
# lines, mirror each structured line to deploy.jsonl with JSON escaping, and count
# the child's warnings and errors. NOT a copier of the child's lines to deploy.log
# (the child writes its own; the relay logs one error for a failed child) and NOT a
# writer of summary rows (the child writes its own; Invoke-ChildRelayed adds one
# ERROR row only for a throw, when given a summary tool name). Consumed by:
# aitools-install.sh/.ps1 (after the follow-up that removes their own copies),
# deploy-harness.sh/.ps1.

(S3-M3-LibKey's wording, with two corrections from S3-M3-Docs-Check F15: the relay
does log_error to deploy.log for a failed child (aitools-lib.sh:595-617, ps1:518-527),
and the throw row needs SUMMARYTOOL (ps1:519).)

Facts behind it (origin/feature/m3-rekey:scripts/aitools-lib.sh): jsonl_record :531-540
(escaping via _aitlib_json_esc :495-503), relay_child_log :569-576, run_child_relayed
:589-621; counters AITLIB_CHILD_WARNINGS / AITLIB_CHILD_ERRORS. The installers still
define their own relay_child_log / Write-JsonlRecord (PR #89) and shadow the lib's copy
until that follow-up (S3-M3-LibKey-report.md "Relay helpers").
````

### Row 9 -- .claude/rules/managed-file-deployment.md (R13)

File: `S3-M3-Docs-drafts/dot-claude/rules/managed-file-deployment.md.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- protected file .claude/rules/managed-file-deployment.md
Row R13 (approved 2026-10-21 as S4-Review's 2 edits), re-derived against main 15cc56a
and the code as shipped. Not applied.

Why the approved text changed:
- Edit 1: the approved text named aitools-profile.js (superseded by P-Q3) and
  config.json machineAlias as step 4 (superseded by id keys, commander decision 5).
  The "Template interpolation" bullet also said "at deploy time", which is no longer
  true for deploy/ (#95 resolves at run time on the target machine).
- Edit 2: the approved "old" text ("Deployment pattern updates") is no longer on main;
  main already points at tool-lifecycle.md "Onboarding checklist", which the approved
  R2 rewrite removes. The approved destination (/tool-adopt step 5) exists on main
  (shared/skills/tool-adopt/SKILL.md "5. Onboarding checklist", item "deployment types
  table for a new file type").

Code cited:
- origin/feature/m3-rekey:scripts/aitools-profile.sh:476-488 (resolution order),
  :631-765 (resolve_machine); :763 (no match = error)
- origin/feature/m3-b4-setup-user-claude:scripts/setup-user-claude.sh:65-91 (wrapper
  results only; no alias / hostname / first-profile fallback), :149-163 (interpolation)
- origin/feature/m3-b5-build-deploy:scripts/build-deploy.sh:233-238 (no build-time
  interpolation; resolved on the target machine)

Depends on: #83 and #95 merged (the "first profile" fallback is still on main in
scripts/setup-user-claude.sh and build-deploy.sh until then).

================================================================
Edit 1 -- section "Content sources"
================================================================
OLD:
- **Template interpolation**: `{{PLACEHOLDER}}` tokens in CLAUDE.md replaced with `profile.json` values at deploy time
- **Machine profile selection**: `config.json` `machineAlias` → `profile.json` `profiles[alias]`. Fallback: hostname match, then first profile

NEW:
- **Template interpolation**: `{{PLACEHOLDER}}` tokens in CLAUDE.md replaced with this machine's profile values when the setup script runs on that machine (dev path and generated deploy/ scripts alike)
- **Machine profile selection**: one resolver (`aitools-profile.sh` / `.ps1`, through `resolve_machine_profile` / `Resolve-MachineProfile`): override → environment → `profiles[<machine id>]` → config.json `machineId` (only when the id cannot be detected) → config.json `machineAlias` (2.1 profiles only) → hostname (warns) → no match = ERROR, never another machine's profile. Order and failure behaviour: `@reference/user-repo.md` "Resolution"

================================================================
Edit 2 -- section "Updating this table"
================================================================
OLD:
the `/incident` skill if there are implementation gaps. See
`@.claude/rules/tool-lifecycle.md` "Onboarding checklist" (deployment types
table, protected).

NEW:
the `/incident` skill if there are implementation gaps. Tool onboarding checks
this table through `/tool-adopt` step 5 ("deployment types table for a new file
type").
````

### Row 10 -- .cursor/rules/managed-file-deployment.mdc (R14 mirror)

File: `S3-M3-Docs-drafts/dot-cursor/rules/managed-file-deployment.mdc.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- protected file .cursor/rules/managed-file-deployment.mdc
Row R14 (mirror of R13). The same two edits as
dot-claude/rules/managed-file-deployment.md.edit.txt, against the mirror's own lines
on main 15cc56a. Not applied. Apply together with R13.

================================================================
Edit 1 -- "Content sources" bullets (mirror lines 30-31)
================================================================
OLD:
- **Template interpolation**: `{{PLACEHOLDER}}` tokens in CLAUDE.md replaced with `profile.json` values at deploy time
- **Machine profile selection**: `config.json` `machineAlias` → `profile.json` `profiles[alias]`. Fallback: hostname match, then first profile

NEW:
- **Template interpolation**: `{{PLACEHOLDER}}` tokens in CLAUDE.md replaced with this machine's profile values when the setup script runs on that machine (dev path and generated deploy/ scripts alike)
- **Machine profile selection**: one resolver (`aitools-profile.sh` / `.ps1`, through `resolve_machine_profile` / `Resolve-MachineProfile`): override → environment → `profiles[<machine id>]` → config.json `machineId` (only when the id cannot be detected) → config.json `machineAlias` (2.1 profiles only) → hostname (warns) → no match = ERROR, never another machine's profile. Order and failure behaviour: `@reference/user-repo.md` "Resolution"

================================================================
Edit 2 -- "Updating this table" sentence (mirror line 59)
================================================================
OLD:
the `/incident` skill if there are implementation gaps. See `@.claude/rules/tool-lifecycle.md` "Onboarding checklist" (deployment types table, protected).

NEW:
the `/incident` skill if there are implementation gaps. Tool onboarding checks this table through `/tool-adopt` step 5 ("deployment types table for a new file type").
````

### Row 11 -- reference/tool-support-decision-tree.md

File: `S3-M3-Docs-drafts/reference/tool-support-decision-tree.md.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- protected file reference/tool-support-decision-tree.md
(landed on main by PR #78; line numbers are main 15cc56a). Not applied.

Two sources, merged into one ordered list of exact old -> new edits:
- S3-M3-LibFix-tree-draft.md (5 passages): the PR #80 result-name contract (AITLIB_ /
  $script:AitLib). Line numbers there were taken on the PR #78 tip; they are the same
  on main.
- The re-key (commander decision 5, 2026-10-22): profiles keyed by machine id, the
  `owner` field, exit 4, and the exception-set refusals as shipped.

Code cited (origin/feature/m3-rekey, 1c89444):
- scripts/aitools-lib.sh:371-402 tool_exception_get (AITLIB_TOOL_EXC_FOUND / _PLATFORM /
  _METHOD / _PATH / _DECIDED_AT; returns 0 or 1; resolver warnings at detail)
- scripts/aitools-lib.ps1:307-335 Get-ToolException (hashtable or $null)
- scripts/aitools-lib.sh:404-464 tool_exception_record (AITLIB_TOOL_EXC_RESULT,
  AITLIB_TOOL_EXC_PUSHED; returns 0, 1, 3)
- scripts/aitools-lib.sh:314-369 resolve_machine_profile (AITLIB_MACHINE_ALIAS, _VIA,
  _KEY, _OWNER, _LEGACY, _HOSTNAME)
- scripts/aitools-profile.sh:900-941 exception-get (only owner=this counts),
  :1021-1135 exception-set (refusals :1044-1074; dry run :1085-1087; commit :1132),
  :943-1005 commit_profile (dirty check :969-972; BatchMode :990-993; rejected push
  :996-999)
- scripts/aitools-profile.sh:31-38 exit codes 0-4; :1137-1191 derive-config
  (machineId only for this machine's id-keyed profile :1180-1184)

Depends on: #80 and #86 merged (the AITLIB_ names and id keys are on those branches).

================================================================
Edit 1 -- section 1, decision row D-TS4 (line 56)
================================================================
OLD:
| D-TS4 | `[k]eep` remembered per machine in `profiles.<alias>.toolExceptions` (shape in `@reference/user-repo.md`; semantics in section 8) | same |
NEW:
| D-TS4 | `[k]eep` remembered per machine in `profiles.<machineId>.toolExceptions` (shape in `@reference/user-repo.md`; semantics in section 8; machine profiles keyed by machine id since commander decision 5, 2026-10-22) | same |

================================================================
Edit 2 -- section 7 introduction, globals list (lines 309-310) [LibFix 1]
================================================================
OLD:
(`tool_method_menu`), `TOOL_EXC_PLATFORM` / `TOOL_EXC_METHOD` /
`TOOL_EXC_PATH` / `TOOL_EXC_DECIDED_AT` (`tool_exception_get`), `TOOL_VER`
NEW:
(`tool_method_menu`), `AITLIB_TOOL_EXC_FOUND` / `AITLIB_TOOL_EXC_PLATFORM` /
`AITLIB_TOOL_EXC_METHOD` / `AITLIB_TOOL_EXC_PATH` / `AITLIB_TOOL_EXC_DECIDED_AT`
(`tool_exception_get`; the `AITLIB_` prefix is the aitools-lib result-name
contract, PR #80), `TOOL_VER`

================================================================
Edit 3 -- section 7.2 table, row tool_exception_get (line 399) [LibFix 2]
================================================================
OLD:
| `tool_exception_get` | `Get-ToolException` | slug | prints `<platform>|<method>|<path>|<decidedAt>` or nothing; 1 store unavailable (one warn; treated as no exception). Wraps `aitools-profile.sh` / `.ps1 exception-get` (section 8) |
NEW:
| `tool_exception_get` | `Get-ToolException` | slug | sets `AITLIB_TOOL_EXC_FOUND` (true/false) and `AITLIB_TOOL_EXC_PLATFORM` / `_METHOD` / `_PATH` / `_DECIDED_AT`; PS1 returns `@{Found; Platform; Method; Path; DecidedAt}` or `$null`; 1 store unavailable (one warn; treated as no exception). Wraps `aitools-profile.sh` / `.ps1 exception-get` (section 8) |

================================================================
Edit 4 -- section 7.2 table, row tool_exception_record (line 400)
================================================================
OLD:
| `tool_exception_record` | `Set-ToolException` | slug, method, path, version | 0 written (committed and pushed, or a commit/push warning) / 1 failed / 3 refused: no dotprofile, or the machine profile matched by hostname only or not at all. Wraps `aitools-profile.sh` / `.ps1 exception-set` (its exit 2 maps to 1: no lib helper returns 2) |
NEW:
| `tool_exception_record` | `Set-ToolException` | slug, method, path, version | 0 written (committed and pushed, or a commit/push warning) or nothing to write (`unchanged`, `dry-run`) / 1 failed / 3 refused: no dotprofile, or no machine profile registered to this machine (section 8 Writer). Sets `AITLIB_TOOL_EXC_RESULT` / `AITLIB_TOOL_EXC_PUSHED` (PS1 `$script:AitLibToolExcResult` / `AitLibToolExcPushed`). Wraps `aitools-profile.sh` / `.ps1 exception-set` (its exit 2 and 4 map to 1: no lib helper returns 2) |

================================================================
Edit 5 -- section 8, Location (lines 564-569) [LibFix 3 + re-key]
================================================================
OLD:
**Location**: `profiles.<alias>.toolExceptions.<slug>` in the dotprofile
`profile.json`, where `<alias>` is the machine profile chosen by the machine
resolver (`resolve_machine_profile` / `Resolve-MachineProfile`; result in
`MACHINE_ALIAS` / `MACHINE_VIA`) -- not read from `config.json` `machineAlias`,
which is only the resolver's cached result. Distinct from top-level `overrides`:
an exception keeps a whole install; an override changes a setting.
NEW:
**Location**: `profiles.<machineId>.toolExceptions.<slug>` in the dotprofile
`profile.json`, inside this machine's own machine profile: the one the machine
resolver (`resolve_machine_profile` / `Resolve-MachineProfile`; result in
`AITLIB_MACHINE_KEY` / `AITLIB_MACHINE_VIA` / `AITLIB_MACHINE_OWNER`, PowerShell
`$script:AitLibMachineKey` / `$script:AitLibMachineVia` /
`$script:AitLibMachineOwner`) matched with owner `this` -- not read from
`config.json` `machineId` / `machineAlias`, which are only the resolver's cached
results. A 2.1 profile keyed by alias whose `machine.id` is this machine's counts as
this machine's (it warns: migrate). Distinct from top-level `overrides`: an
exception keeps a whole install; an override changes a setting.

================================================================
Edit 6 -- section 8, Engine bullet, last sentence (lines 605-606)
================================================================
OLD:
  `tests/profile/test-profile.sh`. Exit codes: 0 ok, 1 not found, 2 error,
  3 refused.
NEW:
  `tests/profile/test-profile.sh`. Exit codes: 0 ok, 1 not found, 2 error,
  3 refused, 4 refused (`register` only: the alias is used by another profile, or
  `--claim` names another machine's profile).
  `exception-get` returns only this machine's decisions: an entry in a profile
  whose owner is not `this` is ignored with a warning (`found false`).

================================================================
Edit 7 -- section 8, Writer bullet (lines 616-628) [LibFix 4 + 5 + re-key]
================================================================
OLD:
- **Writer**: `tool_exception_record` / `Set-ToolException`, only after `[k]eep`,
  never in dry run or non-interactive runs (`exception-set` also refuses to
  write under `AITOOLS_DRY_RUN=1`). Allowed when `MACHINE_VIA` is `id`,
  `environment` or `override`, and `alias` only when this machine has no id
  (a registered profile resolves `via=id`, so `alias` on a machine with an id
  means the profile is unregistered or registered to another machine, whose
  later runs would honour the exception). Refused (exit 3 -> return 3,
  `log_warn` + ACTION `run aitools user init to remember tool choices`) in every
  other case: `hostname`, `none`, `alias` on a machine with an id, no
  dotprofile, or a profile read from `AITOOLS_PROFILE_FILE` (the read-only
  snapshot in generated deploy scripts). The resolver's `derive-config` never
  caches a hostname match as config.json `machineAlias`, so a hostname match
  cannot turn into `via=alias` on the next run (PR #76 review M1).
NEW:
- **Writer**: `tool_exception_record` / `Set-ToolException`, only after `[k]eep`,
  never in dry run or non-interactive runs (`exception-set` also writes nothing
  under `AITOOLS_DRY_RUN=1` and reports `dry-run`). `exception-set` resolves the
  machine profile itself (the same order as `resolve`, so the same result as
  `AITLIB_MACHINE_VIA` / `AITLIB_MACHINE_OWNER`) and writes only when that profile is
  this machine's (`owner` = `this`) and its via is `id`, `environment` or
  `override`. Refused (exit 3 ->
  return 3, `log_warn` + ACTION `run aitools user init to remember tool choices`)
  in every other case: `hostname`, `config` (this machine's id could not be
  detected), `alias` (the 2.1 config cache), `none`, an override naming another
  machine's or an unregistered profile, no dotprofile, or a profile read from
  `AITOOLS_PROFILE_FILE` (the read-only snapshot in generated deploy scripts).
  The resolver's `derive-config` never caches a hostname match in config.json, and
  caches `machineId` only for this machine's id-keyed profile (PR #76 review M1).
  The writer sets `AITLIB_TOOL_EXC_RESULT` (created, updated, unchanged, dry-run,
  refused, failed) and `AITLIB_TOOL_EXC_PUSHED`; unchanged and dry-run write
  nothing and do not warn.

================================================================
Edit 8 -- section 8, Carry-forward bullet (lines 629-634)
================================================================
OLD:
- **Carry-forward (N-Q2)**: `exception-set` commits only `profile.json` in the
  dotprofile (other staged or modified files are left alone) and pushes it
  (`GIT_TERMINAL_PROMPT=0`, so a push never waits for credentials). On a machine
  without a git identity it commits as the profile's `identity.git`. A failed
  commit or push is a warning: the file is written, KEEP reports WARN
  `<ver> (kept, not pushed)` + ACTION `run git push in <userRepoPath>`.
NEW:
- **Carry-forward (N-Q2)**: `exception-set` commits only `profile.json` in the
  dotprofile (other staged or modified files are left alone) and pushes it
  (`GIT_TERMINAL_PROMPT=0`, and `GIT_SSH_COMMAND="ssh -o BatchMode=yes"` unless
  the user set one, so a push never waits for credentials). On a machine without
  a git identity it commits as the profile's `identity.git`. A `profile.json`
  that already had uncommitted changes before the write is written but not
  committed (a warning asks for a manual commit; the wrapper currently also adds
  the push ACTION below, although nothing was committed -- INCIDENT, S3-M3-Docs
  approval page). A failed commit or push is a
  warning: the file is written, KEEP reports WARN `<ver> (kept, not pushed)` +
  ACTION `run git push in <userRepoPath>`; a rejected push (the remote is ahead)
  advises `git pull --rebase`, then `git push`.

================================================================
Edit 9 -- "Changes at landing" table, new last row (after line 738)
================================================================
OLD:
| PR #76 review M1 (stricter than rev 5; for commander confirmation) | Section 8 Writer: `via=alias` allowed only on a machine without an id; hostname matches are never cached as `machineAlias` |
NEW:
| PR #76 review M1 (stricter than rev 5; for commander confirmation) | Section 8 Writer: `via=alias` allowed only on a machine without an id; hostname matches are never cached as `machineAlias` |
| Commander decision 5, 2026-10-22 (machine profiles keyed by machine id) and the PR #80 result-name contract | D-TS4 row, sections 7 and 7.2 (`AITLIB_` result names), section 8 Location, Engine (exit 4; only this machine's decisions), Writer (owner `this` required; `via=alias` and `via=config` now always refused, superseding the PR #76 M1 row above), Carry-forward (dirty-file and push details) |

================================================================
Not changed (checked): section 8 Reader bullet (lines 607-615) matches the code
(warnings at detail; return 1 with one log_warn; Get-ToolException in-process,
aitools-lib.ps1:139-168).
````

### Row 12 -- shared/claude-shared.md (R19)

File: `S3-M3-Docs-drafts/shared/claude-shared.md.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- protected file shared/claude-shared.md
Row R19 (approved 2026-10-21, S5-Profile edit file). Text unchanged from the approved
draft except one clause: "for my identity and every machine" -> "for my identity and
every machine (machine profiles keyed by machine id)" (commander decision 5). Not
applied. The same edit goes into <dotprofile>/claude/CLAUDE.md (deploy-paths.md
"Template sync"): see dotprofile/claude/CLAUDE.md.edit.txt.

Code cited:
- {{USER_REPO_PATH}} is a template token only from PR #83:
  origin/feature/m3-b4-setup-user-claude:scripts/setup-user-claude.sh:110-113 (display
  form ~/...), :155-159 (substitution); setup-user-claude.ps1:92-94 (%USERPROFILE%\...),
  :145-148. On main (15cc56a) the token is not substituted.
- resolve_user_repo_path / Resolve-UserRepoPath: origin/feature/m3-rekey:
  scripts/aitools-lib.sh:286, scripts/aitools-lib.ps1:218.
- setup-user-config is the only writer of config.json:
  origin/feature/m3-rekey:scripts/setup-user-config.sh:2-11.

Depends on: #83 merged (else the line shows the raw token). Behaviour to know: on a
machine with no dotprofile the token has no value and stays as `{{USER_REPO_PATH}}`
(an empty value leaves its token in place, setup-user-claude.sh:150-154).

Section: ## Cross-Platform Awareness

OLD:
- Projects live in git repos under `~/repos/` (macOS) / `%USERPROFILE%\repos\` (Windows)
- Google Drive paths are auto-discovered by `aitools install` and stored in `~/.aitools/config.json` (`googleDrives` array) -- do not hardcode them

NEW:
- Projects live in git repos under `~/repos/` (macOS) / `%USERPROFILE%\repos\` (Windows)
- My dotprofile repo (profile.json, personal CLAUDE.md template, rules, session archives) is `{{USER_REPO_PATH}}` on this machine -- convention `<reposPath>/aitools-<github-user>`. Code finds it with `resolve_user_repo_path` / `Resolve-UserRepoPath` (aitools-lib); never hardcode it
- `profile.json` in the dotprofile is the source of truth for my identity and every machine (machine profiles keyed by machine id); `~/.aitools/config.json` is derived from it by `setup-user-config` -- change `profile.json`, never edit config.json by hand
- Google Drive paths are auto-discovered by `aitools install` and stored in `~/.aitools/config.json` (`googleDrives` array) -- do not hardcode them
````

### Row 13 -- dotprofile claude/CLAUDE.md (R19 + repair)

File: `S3-M3-Docs-drafts/dotprofile/claude/CLAUDE.md.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- protected file <dotprofile>/claude/CLAUDE.md
(/Users/new-jose/repos/aitools-nobul-jose/claude/CLAUDE.md). Read-only here: the live
dotprofile has another session's uncommitted changes (git status: deploy/*, profile.json,
sessions/.DS_Store; claude/CLAUDE.md itself is clean). Not applied. The apply mission
commits and pushes it to the dotprofile main (N-Q2).

Two edits.

================================================================
Edit 1 -- R19 (template sync with shared/claude-shared.md), section ## Cross-Platform Awareness, lines 50-51
================================================================
OLD:
- Projects live in git repos under `~/repos/` (macOS) / `%USERPROFILE%\repos\` (Windows)
- Google Drive paths are auto-discovered by `aitools install` and stored in `~/.aitools/config.json` (`googleDrives` array) -- do not hardcode them

NEW:
- Projects live in git repos under `~/repos/` (macOS) / `%USERPROFILE%\repos\` (Windows)
- My dotprofile repo (profile.json, personal CLAUDE.md template, rules, session archives) is `{{USER_REPO_PATH}}` on this machine -- convention `<reposPath>/aitools-<github-user>`. Code finds it with `resolve_user_repo_path` / `Resolve-UserRepoPath` (aitools-lib); never hardcode it
- `profile.json` in the dotprofile is the source of truth for my identity and every machine (machine profiles keyed by machine id); `~/.aitools/config.json` is derived from it by `setup-user-config` -- change `profile.json`, never edit config.json by hand
- Google Drive paths are auto-discovered by `aitools install` and stored in `~/.aitools/config.json` (`googleDrives` array) -- do not hardcode them

================================================================
Edit 2 -- repair of an adopt corruption (S3-M3-Claude INCIDENT; reviewer finding), lines 42-43
================================================================
Cause: the pre-#83 adopt filter reverse-tokenized "Jose" inside "nobul-Jose" (fixed
going forward in a87ffce: one pass, longest value first -- but a value inside a longer
literal is still tokenized; "Jose" in "nobul-Jose" would be tokenized again on the next
adopt). The repair therefore uses the lower-case GitHub user `nobul-jose`, which is what
shared/claude-shared.md:29-30 says and which the case-sensitive filter never matches
(origin/feature/m3-b4-setup-user-claude:scripts/setup-user-claude.sh:196-212).
Note: the aitools repo now lives at nobul-tech/aitools (every PR in this mission uses
`gh ... -R nobul-tech/aitools`); github.com/nobul-jose/aitools is what both templates
say today. Changing the org is a separate decision (open question in the approval page).

OLD:
- Tool governance lives in [`nobul-{{PROFILE_NAME}}/aitools`](https://github.com/nobul-{{PROFILE_NAME}}/aitools) -- pre-approved tools, evaluation framework, and lifecycle phases documented there
- When working outside aitools: open an issue on `nobul-{{PROFILE_NAME}}/aitools` via `gh` (see [RFC 0001](https://github.com/nobul-{{PROFILE_NAME}}/aitools/blob/main/rfcs/RFC-0001-workspace-tool-requests.md))

NEW:
- Tool governance lives in [`nobul-jose/aitools`](https://github.com/nobul-jose/aitools) -- pre-approved tools, evaluation framework, and lifecycle phases documented there
- When working outside aitools: open an issue on `nobul-jose/aitools` via `gh` (see [RFC 0001](https://github.com/nobul-jose/aitools/blob/main/rfcs/RFC-0001-workspace-tool-requests.md))
````

### Row 14 -- .claude/rules/deploy-paths.md (R20)

File: `S3-M3-Docs-drafts/dot-claude/rules/deploy-paths.md.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- protected file .claude/rules/deploy-paths.md
Row R20. Reconciliation: this is S3-M3-B5a's draft
(origin/feature/m3-b5-build-deploy:.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-M3-B5a/S3-M3-B5a-drafts/dot-claude/rules/deploy-paths.md.edit.txt,
commit 266a1ba, n1 wording fix ff6e7dd) adopted with one change: edit 1's last
paragraph now says only setup-user-claude resolves the machine profile (settings and
cursor resolve only the dotprofile: m3-b5:scripts/setup-user-settings.sh:67,
setup-user-cursor.sh:190, setup-user-claude.sh:84; S3-M3-Docs-Check F11). It supersedes the R20 text
approved 2026-10-21 (S5-Profile-report.md section 5, line 158), which:
- named scripts/aitools-profile.js (superseded by P-Q3: native aitools-profile.sh/.ps1);
- described BEGIN/END "profile resolution" / "profile interpolation" sentinels that were
  never added (S3-M3-Claude INCIDENT: `git grep -i "profile resolution" -- scripts` is
  empty);
- kept setup-user-claude in the duplication table, while #95 makes it a pure extract.
The approved R20 note "add generated/tool-specs to 'What IS auto-embedded' when X-B4
lands" still applies later; X-B4 has not landed, so it is not in this draft.

Every OLD block below was checked verbatim against .claude/rules/deploy-paths.md on
main 15cc56a.

Code cited (origin/feature/m3-b5-build-deploy:scripts/build-deploy.sh):
- :170-215 dotprofile from AITOOLS_USER_REPO_PATH, else resolve_user_repo_path in a
  child bash; config.json not read
- :233-249 template fallback = dotprofile claude/CLAUDE.md else shared/claude-shared.md,
  tokens resolved at runtime
- :251-306 profile.json snapshot via `perl aitools-json.pl snapshot`; cursor.cli
  fallback values
- :421-539 embedded fallbacks (template, profile snapshot, rules) and resolver copies
- :572-608, :661-702 generated source block: live dotprofile wins, else embedded snapshot
check-pre-push.sh step 7 (same branch): temp dotprofile through AITOOLS_USER_REPO_PATH,
dry-run smoke of the generated resolver consumers (S3-M3-B5a-report.md "Step 7").

Depends on: #95 merged (and #90-#92, which #95 contains).

================================================================
Edit 1 -- section "Scripts with deploy templates (duplication risk)"
================================================================
OLD:
Three script pairs have **duplicated setup logic** between `scripts/` and
`build-deploy.sh`. Fixing a bug in one requires manually porting to the other.
Running `build-deploy.sh` does NOT auto-fix stale template logic — it faithfully
reproduces whatever is hardcoded in the template.

| Script | What's duplicated |
|--------|-------------------|
| `setup-user-claude.sh/.ps1` | Template interpolation, footer generation |
| `setup-user-cursor.sh/.ps1` | CLI config merge logic (Node.js/PS1) |
| `setup-user-hooks.sh/.ps1` | Hook-script embedding + REGS_JSON injection (build-time self-containment; the settings.json hooks merge itself is extracted, not duplicated) |

`setup-user-mcp.sh/.ps1` and `setup-user-settings.sh/.ps1` are **pure extract**
(body markers + `inline_lib_*`) — no duplicated logic. The settings.json merge
formerly duplicated in `setup-user-mcp` was removed in the settings-sync refactor
(`sync_managed_json` now owns settings.json), progress toward the I6 structural fix.

NEW:
One script pair has **duplicated setup logic** between `scripts/` and
`build-deploy.sh`. Fixing a bug in it requires manually porting to the other.
Running `build-deploy.sh` does NOT auto-fix stale template logic — it faithfully
reproduces whatever is hardcoded in the template.

| Script | What's duplicated |
|--------|-------------------|
| `setup-user-hooks.sh/.ps1` | Hook-script embedding + REGS_JSON injection (build-time self-containment; the settings.json hooks merge itself is extracted, not duplicated) |

These pairs are **pure extract** (body markers + `inline_lib_*`) — no duplicated
logic:
- `setup-user-mcp.sh/.ps1` and `setup-user-settings.sh/.ps1`. The settings.json
  merge formerly duplicated in `setup-user-mcp` was removed in the settings-sync
  refactor (`sync_managed_json` now owns settings.json).
- `setup-user-claude.sh/.ps1` (M3 B5): template interpolation, footer, managed-file
  deploy and rules logic are extracted from `scripts/`. `build-deploy.sh` adds only
  the profile/template source block (the live dotprofile on the machine wins, else
  the embedded build-time copies) and the rules fallback.
- `setup-user-cursor.sh/.ps1` (M3 B5): the whole cursor body is extracted; only the
  two preference defaults in the profile preferences block are replaced with the
  build-time `profile.json` `cursor.cli` values (the fallback when the machine has
  no dotprofile).

Every resolver-consuming deploy script (`setup-user-claude`, `-settings`,
`-cursor`) resolves the dotprofile (`setup-user-claude` also this machine's
profile) when it runs, never at build time: no machine's values are interpolated
into `deploy/`.

================================================================
Edit 2 -- list "What IS auto-embedded (safe — single source of truth)"
================================================================
OLD:
**What IS auto-embedded** (safe — single source of truth):
- `shared/hooks/*.sh` → read via `cat` at build time
- `shared/skills/*.md` → read via `cat` at build time
- `@shared/claude-shared.md` → read via `cat` at build time
- `<userRepoPath>/claude/rules/*.md` → read via `cat` at build time

NEW:
**What IS auto-embedded** (safe — single source of truth):
- `shared/hooks/*.sh` → read via `cat` at build time
- `shared/skills/*.md` → read via `cat` at build time
- `<userRepoPath>/claude/CLAUDE.md` (else `@shared/claude-shared.md`) → read at
  build time, tokens left in place (the fallback template; resolved at runtime)
- `<userRepoPath>/profile.json` → its snapshot (`aitools-json.pl snapshot`:
  version, identity, cursor, profiles), the fallback when the machine has no
  dotprofile
- `<userRepoPath>/claude/rules/*.md` → read at build time (the fallback rules)
- `scripts/aitools-profile.sh/.ps1`, `scripts/aitools-lib.sh/.ps1`,
  `scripts/aitools-json.pl/.ps1` → copied at build time into the resolver-consuming
  deploy scripts and written to a temp dir at runtime (`AITOOLS_PROFILE_SH` /
  `AITOOLS_PROFILE_PS1`); a file the resolver loads that the embed does not carry
  fails the build

`check-pre-push` step 7 rebuilds into a temp copy of the dotprofile and dry-runs
the generated resolver consumers, so a deploy script that cannot find its resolver
fails the push, not an endpoint.

================================================================
Edit 2b -- heading after the auto-embedded list (review n1)
================================================================
OLD:
**When changing setup logic in any of the 3 scripts above**:

NEW:
**When changing setup logic in the script above** (`setup-user-hooks`):

(Follow-up, not a rule edit: check-pre-commit step 13 still lists
setup-user-claude and setup-user-cursor as duplicated templates and will warn
needlessly when they change.)

================================================================
Edit 3 -- section "When changing `scripts/setup-*.sh/.ps1`", step 2
================================================================
OLD:
2. Run `bash scripts/build-deploy.sh` to regenerate the `<userRepoPath>/deploy/` counterpart

NEW:
2. Run `bash scripts/build-deploy.sh` to regenerate the `<userRepoPath>/deploy/` counterpart
   (it takes the dotprofile from `AITOOLS_USER_REPO_PATH`, else from the resolver;
   an agent runs it only under an isolated `HOME` with a copy of the dotprofile:
   it deletes and rebuilds `<dotprofile>/deploy/`)
````

### Row 15 -- reference/script-standards-detail.md

File: `S3-M3-Docs-drafts/reference/script-standards-detail.md.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- reference/script-standards-detail.md (treated as
protected: the severity guide named by D-TS11, and its exemptions table says
"Protected"). Four edits, exact against main 15cc56a. Not applied.

Coexistence with row R16 (approved, not yet applied; S3-Gate-drafts/reference/
script-standards-detail.md.edit.txt): R16 edits the Contents table (adds rows after
"Environment skip row"), "Severity categories", the last line of "Severity decision
guide", "ACTION items", "Governed summary outcomes" and "Exit footer". The edits below
anchor elsewhere (Contents table: after the "Summary writer" row; "Usage";
"Function definition"; "Summary coverage rule"), so either batch can land first.

Sources: S3-M3-Install-report.md INCIDENT + open question 1 and S3-M3-LibKey-report.md
INCIDENT (JSONL escaping); S3-M3-ConfigKey-report.md INCIDENT (write_summary OK -> WARN);
S3-M3-Register-keydesign.md section j finding 1 (library-style tools).

================================================================
Edit 1 -- "Shared library" > "Contents" table: add rows after the "Summary writer" row
================================================================
OLD:
| Summary writer | `write_summary` | `Write-Summary` | 3-arg append to summary file |
NEW:
| Summary writer | `write_summary` | `Write-Summary` | 3-arg append to summary file; an OK row becomes WARN once the script has counted a warning ("Function definition") |
| Dotprofile and machine profile | `resolve_user_repo_path`, `resolve_machine_profile` (results `AITLIB_*`) | `Resolve-UserRepoPath`, `Resolve-MachineProfile` (results `$script:AitLib*`) | Wrappers around the native resolver `aitools-profile.sh` / `.ps1` (`@reference/user-repo.md` "Resolution"); never return 2 |
| Tool exceptions | `tool_exception_get`, `tool_exception_record` | `Get-ToolException`, `Set-ToolException` | Reader and writer of `toolExceptions` (`@reference/tool-support-decision-tree.md` section 8) |
| JSONL record and child relay | `jsonl_record`, `relay_child_log`, `run_child_relayed` | `Write-JsonlRecord`, `Send-ChildLog`, `Invoke-ChildRelayed` | One escaped `deploy.jsonl` record; run a child setup script, show its lines, mirror them to `deploy.jsonl`, count its warnings and errors |

(Code: origin/feature/m3-rekey:scripts/aitools-lib.sh:286, :333, :378, :419, :531, :569,
:589; aitools-lib.ps1:218, :263, :312, :350, :449, :489, :510.)

================================================================
Edit 2 -- "Usage": the installer JSONL override examples
================================================================
Why: the documented bash override printf's the raw message into a JSON string, so a
message with `"` or `\` writes an invalid deploy.jsonl line (S3-M3-Install INCIDENT:
scripts/aitools-install.sh at 9462ed0:136-137 copied it). The lib now has an escaping
writer, jsonl_record / Write-JsonlRecord (aitools-lib.sh:488-540: backslash, quote, tab
and newline escaped, other control characters dropped; ps1:449).
Depends on: #86 merged AND the installer call-site follow-up (S3-M3-LibKey-report.md
"Call-site change": the installers delete their own jsonl_write / relay copies and call
the lib's). Until then the installers' own escaped jsonl_write (PR #89) is what runs;
apply this edit with that follow-up.

OLD:
Bash (`scripts/aitools-install.sh`):
```bash
source "$SCRIPT_DIR/aitools-lib.sh"
logging_init "aitools-install"
# Override: JSONL dual-format (human-readable + structured JSON)
log() {
    local level="${2:-info}"
    local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '[%s] [%s] [%s] %s\n' "$ts" "$SCRIPT_NAME" "$level" "$1" | tee -a "$LOG_FILE"
    printf '{"ts":"%s","host":"%s","os":"%s","script":"%s","run_id":"%s","level":"%s","msg":"%s"}\n' \
        "$ts" "$HOST_NAME" "$OS_NAME" "$SCRIPT_NAME" "$RUN_ID" "$level" "$1" >> "$LOG_JSONL"
}
log_ok()    { log "$1" "ok"; }
log_error() { log "$1" "error"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "$1" "warn"; WARNINGS=$((WARNINGS + 1)); }
```

PowerShell (`scripts/aitools-install.ps1`):
```powershell
# Override: JSONL dual-format (human-readable + structured JSON)
function Log($msg, $level = "info") {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] [$level] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
    $json = @{ ts=$ts; host=$hostName; os=$osName; script=$scriptName; run_id=$runId; level=$level; msg=$msg } | ConvertTo-Json -Compress
    Add-Content -Path $logJsonl -Value $json
}
function LogOk($msg)    { Log $msg "ok" }
function LogError($msg) { Log $msg "error"; $script:errors++ }
function LogWarn($msg)  { Log $msg "warn"; $script:warnings++ }
```

NEW:
Bash (`scripts/aitools-install.sh`):
```bash
source "$SCRIPT_DIR/aitools-lib.sh"
logging_init "aitools-install"
# Override: JSONL dual-format (human-readable + structured JSON).
# jsonl_record (aitools-lib) JSON-escapes every field; never printf a raw
# message into a JSON string.
log() {
    local level="${2:-info}"
    local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '[%s] [%s] [%s] %s\n' "$ts" "$SCRIPT_NAME" "$level" "$1" | tee -a "$LOG_FILE"
    jsonl_record "$ts" "$SCRIPT_NAME" "$level" "$1"
}
log_ok()    { log "$1" "ok"; }
log_error() { log "$1" "error"; ERRORS=$((ERRORS + 1)); }
log_warn()  { log "$1" "warn"; WARNINGS=$((WARNINGS + 1)); }
```

PowerShell (`scripts/aitools-install.ps1`):
```powershell
# Override: JSONL dual-format (human-readable + structured JSON).
# Write-JsonlRecord (aitools-lib) escapes every field and appends with LF.
function Log($msg, $level = "info") {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $line = "[$ts] [$scriptName] [$level] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
    Write-JsonlRecord $ts $scriptName $level $msg
}
function LogOk($msg)    { Log $msg "ok" }
function LogError($msg) { Log $msg "error"; $script:errors++ }
function LogWarn($msg)  { Log $msg "warn"; $script:warnings++ }
```

A child setup script logs through the lib's `log`, which writes no JSONL. A parent that
wants the child's lines in `deploy.jsonl` runs it with `run_child_relayed` /
`Invoke-ChildRelayed`, which also counts the child's warnings into the parent's
`WARNINGS` (the child's exit footer is relayed, not counted).

================================================================
Edit 3 -- "End-of-run summary" > "Function definition"
================================================================
Why: S3-M3-ConfigKey INCIDENT -- the guide pairs every ACTION with a log_warn but never
says write_summary turns OK into WARN once a warning is counted, so a script must order
its rows by hand (setup-user-config.sh:367-379 does, with a comment).
Code: origin/feature/m3-rekey:scripts/aitools-lib.sh:860-869 (write_summary),
aitools-lib.ps1:752-761 (Write-Summary).

OLD:
The canonical `write_summary` / `Write-Summary` definition lives in
`scripts/aitools-lib.sh` / `.ps1`. All scripts source the lib -- no inline copies.
NEW:
The canonical `write_summary` / `Write-Summary` definition lives in
`scripts/aitools-lib.sh` / `.ps1`. All scripts source the lib -- no inline copies.

`write_summary OK` writes `WARN` instead when the script has already counted a warning
(`WARNINGS` > 0 / `$script:warnings` > 0): the row reports the script's state so far,
not only its own step. Order rows so that this is true. A warning that concerns a step
is logged before that step's row; an advisory ACTION that does not concern the step
(and its paired `log_warn`) is written after the step's OK row. Example:
`setup-user-config` writes its `aitools config` row first, then the one
`Run: aitools user init (...)` ACTION with its `log_warn`.

================================================================
Edit 4 -- "Summary coverage rule": library-style tools
================================================================
Why: S3-M3-Register-keydesign.md section j finding 1 -- aitools-profile.sh/.ps1 write no
summary rows and no exit footer by design (their callers own both), which this rule does
not allow for. Not added to the "Exemptions table": that table lists error-suppression
exemptions, which this is not.

OLD:
Every code path through a setup script -- success, partial failure, and full failure --
must produce at least one `write_summary` call. A tool that fails to install must appear
in the end-of-run panel as ERROR or WARN, not be silently absent.
NEW:
Every code path through a setup script -- success, partial failure, and full failure --
must produce at least one `write_summary` call. A tool that fails to install must appear
in the end-of-run panel as ERROR or WARN, not be silently absent.

Library-style tools (`scripts/aitools-profile.sh` / `.ps1`) are not setup scripts: they
write no summary rows and no exit footer, and return their warnings and errors to the
caller, which logs them at level and writes the rows (`@reference/logging.md`
"Library-style tools").
````

### Row 16 -- reference/logging.md

File: `S3-M3-Docs-drafts/reference/logging.md.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- reference/logging.md (has an intent statement; the
new section stays inside it: "the decided standard", not the helper API). Two edits,
exact against main 15cc56a. Not applied.

Source: S3-M3-Register-keydesign.md section j finding 1 (INCIDENT: no contract for
library-style tools), repeated by S3-M3-Resolver-report.md INCIDENT; the resolver now
states the contract in its header (origin/feature/m3-rekey:scripts/aitools-profile.sh:39-43,
aitools-profile.ps1:37-41).

Code cited (origin/feature/m3-rekey):
- scripts/aitools-profile.sh:70-79 (console log lines to stderr, deploy.log unchanged),
  :247-266 (add_warn / add_err / finish: warn and error output lines, each also logged at
  detail), :81-85 (OS guard is the only log_error)
- scripts/aitools-lib.sh:150-227 (_aitlib_profile_run copies the resolver's stderr to
  deploy.log as detail lines), :296, :307, :356, :363 (the wrappers log warnings at
  detail and errors at error), setup-user-config.sh (routes advisory vs real warnings,
  S3-M3-ConfigKey-report.md "Warning routing")
- deploy.jsonl writers: aitools-install.sh/.ps1 (PR #89 relay, until the follow-up) and
  aitools-lib.sh:526-540 jsonl_record / aitools-lib.ps1:449 Write-JsonlRecord

================================================================
Edit 1 -- section 3 table: add the deploy.jsonl row (after the deploy.log row)
================================================================
OLD:
| `deploy.log` | setup scripts (via `aitools-lib` `logging_init`/`Initialize-Logging`) |
NEW:
| `deploy.log` | setup scripts (via `aitools-lib` `logging_init`/`Initialize-Logging`) |
| `deploy.jsonl` | the installers' `log` override and the child relay (`jsonl_record` / `Write-JsonlRecord`, `run_child_relayed` / `Invoke-ChildRelayed` in `aitools-lib`; the installers use their own copies until the call-site follow-up); one JSON record per line, fields `ts, host, os, script, run_id, level, msg` |

================================================================
Edit 2 -- new section 7, after "### 6. Setup-vs-check separation preserved" and its paragraph
(anchor: insert before the line "## Migration status")
================================================================
OLD:
## Migration status
NEW:
### 7. Library-style tools return diagnostics; callers log them at level

A library-style tool is a script that other scripts call for data:
`scripts/aitools-profile.sh` / `.ps1` today. Its contract:

- **Data** goes to stdout only (`key<TAB>value` lines, or one JSON object with
  `--json`).
- **Diagnostics** are returned, not logged at level: every warning and error is an
  output line (`warn<TAB>...`, `error<TAB>...`) and is also written to `deploy.log` at
  `detail`. Its console log lines go to stderr, so they never mix with data.
- **Summary rows, counters and the exit footer belong to the caller.** The tool writes
  no `write_summary` row and touches none of its caller's counters (its own counters,
  raised only by its OS guard and lib helpers such as `backup_file`, end with its
  process).
- **The caller** logs each returned line at its level -- `warn` with `log_warn`
  (counted), `error` with `log_error` (counted) -- unless the caller documents why a
  class of warnings is handled another way. Documented exceptions today: the
  `aitools-lib` wrappers log resolver warnings at `detail`, because
  `setup-user-config`, the first script of every run, reports them once; and
  `setup-user-config` logs warnings that its own write corrects as `info`, and turns
  advice the user must act on into one ACTION with one counted `log_warn`.
- **Exit codes** are the tool's own (documented in its header and `--help`). A caller
  never passes them through as its own exit code (exit 2 from a setup script means a
  user abort, D-TS13).

## Migration status
````

### Row 17 -- shared/skills/tool-adopt/SKILL.md

File: `S3-M3-Docs-drafts/shared/skills/tool-adopt/SKILL.md.edit.txt`

````text
DRAFT (S3-M3-Docs, 2026-10-22) -- shared/skills/tool-adopt/SKILL.md, section
"Cross-References (aitools repo paths)". Not an intent statement; under T-Q8 ("none
[of the project skills] should be protected") this edit may not need approval -- it is
in the batch because the re-key design names it (batch 8). Not applied.

Edit 1 (line 216, re-key design section d):
OLD:
- Profile exceptions contract (after M2/M3): `reference/user-repo.md` (`profiles.<alias>.toolExceptions`)
NEW:
- Profile exceptions contract: `reference/user-repo.md` (`profiles.<machineId>.toolExceptions`)

Edit 2 (line 211, optional; the tree landed on main with PR #78):
OLD:
- Decision tree (after M2): `reference/tool-support-decision-tree.md`
NEW:
- Decision tree: `reference/tool-support-decision-tree.md`

Depends on: R18 landed (user-repo.md must say profiles.<machineId> first).
````
