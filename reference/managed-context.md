# Managed context

**Intent**: **Purpose**: Explain, with ASCII diagrams, how aitools builds and
maintains the user-scope context files that agents load as instructions
(the user `CLAUDE.md` above all, and the Cursor `AGENTS.md` relay mirror),
from the shared template and the dotprofile template to the file on disk,
including every diff an agent or the commander sees along the way, on
macOS, Linux and Windows. **Scope**: User-scope context files: their
sources, rendering, review, adopt-back and delivery paths. NOT the rules and
skills fan-outs (`@reference/artifact-manifests.md`). NOT JSON
configuration (`@reference/managed-configuration.md`). NOT project-scope
context (a repo's own `CLAUDE.md`, `.claude/rules/`, `.cursor/rules/`,
which no setup script writes). NOT what the templates say (the templates
themselves). **Audience**: Agents and maintainers editing
`shared/claude-shared.md`, a dotprofile `claude/CLAUDE.md`,
`scripts/setup-user-claude.sh/.ps1`, `scripts/sync-relay-to-cursor-agents.py`
or `build-deploy.sh`, and the commander deciding what to do at a CLAUDE.md
review menu.

Version 1.0, 2026-11-07, Session Commander f500b663-7. A version, not a
draft (D-DEL5). Describes `main` at `ab3bc22`. Paths: `~` is `$HOME` on
macOS/Linux and `%USERPROFILE%` on Windows; section 9 lists both forms.
v1.1, 2026-11-15: warnings and errors named by the `aitools-lib` helpers of
`@reference/logging.md` section 8 (legend below).

Legend for the diagrams: `ERROR "<what>"` (or `ERROR "<tool>" "<what>"`) is
one error, recorded with `write_error` (WHAT the failed step, REASON why it
failed); `WARN "<text>"`
is one warning (`write_warn`, or `log_warn`, which names the script);
`WARN + ACTION` is one `write_action` (one warning and one ACTION). `OK`,
`DETAIL` and `ACTION` rows are `write_summary` records.

## 1. What is managed, and for which tool

```
  CONTEXT FILE (user scope)            LOADED BY               WRITTEN BY                  SOURCE
  -------------------------            ---------               ----------                  ------
  ~/.claude/CLAUDE.md                  Claude Code, every      setup-user-claude           dotprofile claude/CLAUDE.md,
                                       session, every repo     (deploy_managed_file)       else shared/claude-shared.md
  ~/.claude/rules/*.md                 Claude Code             setup-user-claude fan-out   ~/.aitools/rules  (see
  ~/.claude/skills/<n>/**                                                                  artifact-manifests.md)
  ~/.cursor/rules/*.mdc                Cursor IDE + CLI        setup-user-cursor fan-out   ~/.aitools/rules
  ~/.cursor/skills/<n>/**              Cursor                  setup-user-cursor fan-out   ~/.aitools/skills
  ~/.cursor/AGENTS.md                  NOBODY (see 2)          sync-relay-to-cursor-       <aitools>/.aitools/channel/
                                                               agents.py (direct write)    relay.md
  Cursor Settings > Rules              Cursor (account-        a person, by hand           shared/cursor-rules/
  ("User Rules")                       stored, not a file)                                 user-rules.md
```

Cursor never sees `~/.claude/CLAUDE.md`: the Cursor agent CLI does not read
it, and Cursor's rules loader reads `CLAUDE.md` only as `<dir>/CLAUDE.md` in
the workspace and its ancestors, and only with third-party extensibility on
(`@reference/tool-ops-cursor.md` "Loading behaviour",
`@reference/cursor-practices.md`). Cursor's user-scope instructions come
from the fanned-out `~/.cursor/rules/*.mdc` and the hand-pasted User Rules.

## 2. Are we doing anything for AGENTS.md?

One thing, and it does not reach any agent today:

```
  <aitools>/.aitools/channel/relay.md            (tracked; the agent relay channel)
        |
        |  scripts/sync-relay-to-cursor-agents.py
        |    run by: `aitools` (end of deploy_configs, after the setup scripts)
        |            `aitools install` Step 22
        |    needs python3 (or `py -3` on Windows); missing -> WARN, skipped
        |    failure -> WARN "(non-fatal)"
        v
  ~/.cursor/AGENTS.md
     everything ABOVE the line "## Agent relay channel" is kept as is
     everything from that line down is replaced by:
        "## Agent relay channel" + a canonical-source note + relay.md with its
        "# Agent Relay Channel" title removed and every heading demoted one level
     no such line -> the relay section is appended (stderr warning)
```

- **Not a managed file.** The script writes the target directly: no
  `deploy_managed_file`, no backup, no review menu, no adopt. A dry run
  (`aitools --dry-run`) writes a unified diff of old vs new into
  `deploy.log` instead of writing the file. (`.aitools/channel/relay.md` says the deploy goes through
  `deploy_managed_file`; the code does not.)
- **Not read.** Cursor's rules loader reads `<workspace or ancestor>/AGENTS.md`,
  so for a workspace under `~` it would read `~/AGENTS.md`, not
  `~/.cursor/AGENTS.md` (`@reference/tool-ops-cursor.md` "Known gaps").
- **Not on the MDM or package paths**: the relay file lives in the repo's
  `.aitools/`, which `deploy/` and the package payload do not carry (row
  OK `relay sync` `n/a (package)`; `.claude/rules/deploy-paths.md`
  "Equivalence" item 6).
- **Nothing for Claude Code.** aitools writes no `AGENTS.md` for Claude
  Code; its user-scope context is `~/.claude/CLAUDE.md` plus
  `~/.claude/rules/`. Whether Claude Code would read an `AGENTS.md` is not
  recorded in `@reference/tool-ops-claude-code.md`.

## 3. The user CLAUDE.md pipeline

`scripts/setup-user-claude.sh` (macOS/Linux) and `setup-user-claude.ps1`
(Windows), step 2 of `deploy_configs` (`aitools`) and installer Step 9.

```
  (1) RESOLVE ---------------------------------------------------------------
      resolve_user_repo_path / Resolve-UserRepoPath  (one resolver, SD-7)
         rc 0  dotprofile found ............... USER_REPO_PATH set
         rc 1  no dotprofile .................. shared-only mode (expected)
         rc 3  resolver error ................. ERROR "claude.md" "not deployed:
                                                dotprofile unresolved" (REASON
                                                the resolver's error line),
                                                exit 1
                                                (never falls back to the shared
                                                 template over a personal one)
      resolve_machine_profile / Resolve-MachineProfile
         rc 0  this machine's profile ......... name, company, alias, hostname
         rc 1  no dotprofile .................. tokens stay unresolved (WARN)
         rc 3  no machine match ............... identity-level values only
                                                (resolve_machine_profile
                                                 records its own ERROR, REASON
                                                 the resolver's error line,
                                                 and one ACTION)
                                  |
  (2) PICK THE TEMPLATE ----------v-------------------------------------------
      <dotprofile>/claude/CLAUDE.md exists? --yes--> SOURCE = dotprofile template
                    | no                            ("user repo")
                    v
      shared/claude-shared.md (or the path given --> SOURCE = shared template
      as the first non-flag argument)               ("shared template")
                    | missing
                    v
      ERROR "no template found", exit 1
                                  |
  (3) RENDER ---------------------v-------------------------------------------
      empty template ............................ ERROR "template empty", exit 1
      {{PROFILE_NAME}} {{PROFILE_COMPANY}} {{IDENTITY_GIT_NAME}}
      {{IDENTITY_GIT_EMAIL}} {{USER_REPO_PATH}}  -> values (one pass; literal;
                                                    an empty value leaves the
                                                    token visible)
      + "\n\n## Machine-Specific\n\n- Machine: ...\n- Shell: ..."   (footer, 3.2)
                                  |
                                  v   SOURCE (rendered)
  (4) COMPARE AND WRITE: deploy_managed_file / Deploy-ManagedFile ------------
      ~/.claude/CLAUDE.md absent .............. created
      same as SOURCE (trailing newlines
        normalised) ........................... verified (nothing written)
      differs ................................. review (section 4)
                                  |
  (5) VALIDATE (after created / updated / accept & adopt) --------------------
      non-empty; has "## Machine-Specific"; has a template body heading
      ("## Coaching", "## Code Style" or "## Tool...")  else ERROR
      "validation failed" (REASON the check that failed)
      rows: OK claude.md created | updated | verified | "accepted to profile";
            WARN "skipped (user review)"; ERROR "deploy failed" (REASON the
            write, AI merge or filter error)
```

### 3.1 Tokens, rendered per platform

```
  TOKEN                   VALUE FROM                    macOS / Linux example        Windows example
  -----                   ----------                    ---------------------        ---------------
  {{PROFILE_NAME}}        machine profile (resolver)    Jose                         Jose
  {{PROFILE_COMPANY}}     machine profile               nobul.tech                   nobul.tech
  {{IDENTITY_GIT_NAME}}   profile.json identity         Jose                         Jose
  {{IDENTITY_GIT_EMAIL}}  profile.json identity         jose@nobul.tech              jose@nobul.tech
  {{USER_REPO_PATH}}      the resolved dotprofile,      ~/repos/aitools-nobul-jose   %USERPROFILE%\repos\
                          home shortened                                             aitools-nobul-jose
```

The template is the same on every platform; only `{{USER_REPO_PATH}}`
renders differently (`~/...` from `$HOME`, `%USERPROFILE%\...` from
`$env:USERPROFILE`, matched case-insensitively). bash substitutes in perl
with values passed through the environment, PowerShell with
`[regex]::Replace` and a literal evaluator, so `&`, `$`, `@` and `/` in a
value are never special.

### 3.2 The footer, per platform

```
  macOS / Linux (setup-user-claude.sh)          Windows (setup-user-claude.ps1)
  ------------------------------------          -------------------------------
  ## Machine-Specific                           ## Machine-Specific

  - Machine: Darwin arm64 (nobul-mac;           - Machine: Microsoft Windows 11 Pro
    profile nobul-mac)                            (<host>; profile <alias>)
  - Shell: zsh                                  - Shell: bash (Claude Code requires
                                                  Git Bash on Windows)

  Machine: `uname -s` `uname -m`                Machine: Win32_OperatingSystem Caption
                                                (CIM; "Windows" if that fails)
  host: resolver's hostname (macOS              host: resolver's hostname (COMPUTERNAME,
    `scutil --get LocalHostName`, else            short, lower-case)
    `uname -n`; short, lower-case)
  profile: machine alias, else "unresolved"     profile: the same
  Shell: basename of $SHELL                     Shell: fixed text
```

The footer is part of SOURCE. It is never in a template, and the adopt
filter removes it before anything is written back (4.3).

## 4. Diffs

Three different comparisons exist. Only the first is automatic.

```
  (A) deploy-time   rendered SOURCE  vs  ~/.claude/CLAUDE.md     every run, by deploy_managed_file
  (B) adopt-back    ~/.claude/CLAUDE.md -> filter -> template    only on [a] or [m]
  (C) template      shared/claude-shared.md vs dotprofile        never automatic (4.5)
                    claude/CLAUDE.md
```

### 4.1 The deploy-time diff (A), as shown at the review menu

```
  [REVIEW] ~/.claude/CLAUDE.md differs from source.

    red - = only on this machine   green + = only in the repo

  --- this machine  ~/.claude/CLAUDE.md
  +++ repo          ~/repos/aitools-nobul-jose/claude/CLAUDE.md     <- the adopt target;
  @@ -12,3 +12,4 @@                                                   blank when there is
   ...                                                                 none (shared template)
  -a line you edited in ~/.claude/CLAUDE.md
  +the line as the template renders it
```

- **What is compared**: LOCAL (`~/.claude/CLAUDE.md`) against the rendered
  SOURCE (template + token values + footer), both with trailing newlines
  normalised. The diff is LOCAL -> SOURCE: `-` lines exist only on this
  machine, `+` lines only in what the template renders.
- **How**: `git diff --no-index` with pinned options (`-U3`, Myers,
  `--indent-heuristic`, no colour, no external diff, `--text`), its own
  header lines dropped and replaced by the two labelled lines above.
  Identical logic in `Prompt-DiffReview` on Windows.
- **Size**: more than 40 lines -> the first 30 are shown, then
  `... (N more lines -- full diff in deploy log)`. The whole diff is always
  written to `deploy.log` as `[detail] diff CLAUDE.md: <line>` records.
- **Colour**: red/green only on an interactive terminal, off with
  `NO_COLOR` or `TERM=dumb`; the log never gets colour.
- **No git**: `(diff unavailable -- see deploy log)`, the menu still works.
- **Rendered values make diffs**: a token value that changed in
  `profile.json` (a new company, a renamed dotprofile) shows as a diff on
  every machine at its next run; a changed hostname or machine alias shows
  as a footer diff on that machine only.

### 4.2 The menu, and what each choice does, by template source

```
                         SOURCE = DOTPROFILE TEMPLATE         SOURCE = SHARED TEMPLATE
                         (<dotprofile>/claude/CLAUDE.md)      (shared/claude-shared.md)
  ----------------       ------------------------------       ------------------------
  adopt target           <dotprofile>/claude/CLAUDE.md        no dotprofile: none
                                                              dotprofile without a
                                                              claude/CLAUDE.md:
                                                              <dotprofile>/claude/CLAUDE.md
                                                              (adopting CREATES it)
  menu                   [o] [a] [m] [s] [x]                  none: [o] [s] [x]
                                                              dotprofile: [o] [a] [m] [s] [x]

  [o]verwrite            LOCAL <- SOURCE (backup kept)        LOCAL <- SOURCE (backup kept)
  [a]ccept & adopt       LOCAL kept; LOCAL -> filter ->       (when offered) as left: the
                         dotprofile template; committed       dotprofile gets a template
                         and pushed (dotprofile_commit_push)  built from your LOCAL
  [m]erge & adopt        AI merge of SOURCE and LOCAL ->      (when offered) as left
                         LOCAL and -> filter -> template;
                         committed and pushed
  [s]kip                 nothing written; WARN;               the same
                         asked again next run
  [x]abort               nothing written; setup-user-claude   the same
                         exits 2 (the run continues with
                         the next script: interactive-menus.md)

  shared/claude-shared.md is NEVER an adopt target: a change to the shared
  template goes through a PR to aitools.
```

After `[a]` or `[m]` the dotprofile template, the rendered SOURCE and LOCAL
agree, so the next run verifies the file and asks nothing.

### 4.3 The adopt filter (B), step by step

`claude_md_adopt_filter` (bash) / `$claudeMdAdoptFilter` (PowerShell), passed
to `deploy_managed_file` as its adopt filter:

```
  ~/.claude/CLAUDE.md (LOCAL, or the AI merge)
     |
     |  1. cut at the first line starting "## Machine-Specific"; drop trailing
     |     blank lines                              (the footer never reaches
     |                                               a template)
     |  2. reverse-tokenise this machine's values, LONGEST FIRST, in one pass:
     |       "~/repos/aitools-nobul-jose"   -> {{USER_REPO_PATH}}
     |       "jose@nobul.tech"              -> {{IDENTITY_GIT_EMAIL}}
     |       "nobul.tech"                   -> {{PROFILE_COMPANY}}
     |       "Jose"                         -> {{PROFILE_NAME}}
     |     longest first: "nobul.tech" inside "jose@nobul.tech" never breaks the
     |     e-mail's token; equal values keep the first token in the order
     |     USER_REPO_PATH, PROFILE_NAME, PROFILE_COMPANY, IDENTITY_GIT_NAME,
     |     IDENTITY_GIT_EMAIL, so "Jose" becomes {{PROFILE_NAME}}, not
     |     {{IDENTITY_GIT_NAME}} (P-Q13); empty values are never substituted
     v
  <dotprofile>/claude/CLAUDE.md   (backed up first; restored if any write
                                   or the filter fails; an empty filter
                                   result is a failure)
     |
     v
  dotprofile_commit_push: git add + commit of that one file (pathspec, other
  dotprofile changes untouched), push without prompting
     committed-pushed  OK
     unchanged         nothing to commit
     commit-failed     WARN + ACTION "commit and push ..."
     push-failed       WARN + ACTION "git pull --rebase, then git push ..."
```

On Windows the same filter turns `%USERPROFILE%\repos\aitools-nobul-jose`
back into `{{USER_REPO_PATH}}`, so a template adopted on Windows and one
adopted on macOS hold the same token.

**Known limit**: any other text that happens to equal a token value is
tokenised too (a sentence that names the company becomes
`{{PROFILE_COMPANY}}`). That is harmless on the next render but shows in
the template's git diff; review the commit.

### 4.4 Non-interactive runs, `--force`, dry run

```
  no terminal (MDM, CI, piped)  -> overwrite, WARN "local edits overwritten
                                   (non-interactive run, backup kept): ...";
                                   no adopt, no AI merge
  EOF at the prompt             -> WARN, overwrite
  aitools --force / -Force,     -> overwrite, logged at info "... (--force)":
  AITOOLS_FORCE=1                  a step the user asked for, not a warning
                                   (@reference/logging.md 8.3)
  aitools --dry-run             -> no diff shown and nothing written: the log
                                   gives the template source, line counts and
                                   "Content unchanged" / "Content differs --
                                   would overwrite" / "would create"; row OK
                                   "verified" / "dry-run: would update" /
                                   "dry-run: would create"
```

A local edit to `~/.claude/CLAUDE.md` therefore survives only an
interactive `[s]kip` or an adopt. Every unattended run puts the template
back (the previous file is kept as `CLAUDE.md.bak.<timestamp>`, at most 20).

### 4.5 Template vs template (C): shared and dotprofile drift

```
  aitools repo                                     dotprofile repo
  shared/claude-shared.md  <---- kept in sync ---->  claude/CLAUDE.md
  (fallback, MDM source when                        (primary; wins whenever it
   no dotprofile; fleet default)                     exists on the machine)

  automatic diff ............. none
  guard ...................... check-pre-commit step 12 "Template sync": WARN
                               "update user repo template" whenever
                               shared/claude-shared.md is staged
  rule ....................... .claude/rules/deploy-paths.md "Template sync";
                               a Managed CLI Tools row added to one must be
                               added to the other (shared/rules/tool-lifecycle.md
                               "Dotprofile priority")
```

The two are expected to differ in personal content (the dotprofile carries
the commander's identity, coaching items, standing orders); what must stay
aligned is the shared structure and the managed-tool rows. To see the
drift, compare them yourself:

```
  macOS / Linux (bash, from the aitools clone)
    git diff --no-index -- shared/claude-shared.md ~/repos/aitools-<user>/claude/CLAUDE.md

  Windows (PowerShell, from the aitools clone)
    git diff --no-index -- shared/claude-shared.md "$env:USERPROFILE\repos\aitools-<user>\claude\CLAUDE.md"
```

Both templates hold tokens, not values, so this diff shows content
differences only, never machine values.

## 5. Delivery paths

```
                 DEV (aitools / aitools install)   MDM (<dotprofile>/deploy/)         PACKAGE (build-package)
  template       live dotprofile claude/CLAUDE.md, live dotprofile template when    neutral fleet template, or
                 else shared/claude-shared.md      the endpoint has the dotprofile;   n/a (no dotprofile);
                                                   else the copy EMBEDDED at build    never another user's
                                                   time (dotprofile template, else
                                                   the shared one)
  profile        live profile.json (resolver)      live profile.json, else the        live dotprofile only
                                                   embedded profile.json snapshot
  adopt          yes, to the dotprofile            yes when the endpoint has a        no (read-only payload,
                                                   live dotprofile                    non-interactive)
  review menu    interactive terminal only         normally non-interactive ->        non-interactive ->
                                                   overwrite                          overwrite
  AGENTS.md      relay mirror written              not written                        not written
  mirror
```

No machine's values are interpolated at build time: `deploy/` carries
templates with tokens, and each endpoint renders its own
(`.claude/rules/deploy-paths.md` "Scripts with deploy templates").

## 6. Failure handling

```
  dotprofile resolver error (rc 3)   ERROR, exit 1, CLAUDE.md untouched
  no template / unreadable / empty   ERROR, exit 1, untouched
  interpolation failed               ERROR, exit 1, untouched
  write, AI merge or filter fails    the library restores every snapshot it took
                                     (LOCAL and the adopt target); one ERROR
                                     "deploy failed", REASON the write, AI
                                     merge or filter error; nothing
                                     half-written
  post-write validation fails        ERROR "validation failed", REASON the
                                     check that failed (the file stays, the
                                     next run reviews it again)
  a dangling symlink at the path     failed: never written through
  a live symlink at the path         read and written through (dotfile managers)
```

## 7. Editing the right file

```
  you want to change...                       edit                                  then
  ---------------------                       ----                                  ----
  your user CLAUDE.md on every machine        <dotprofile>/claude/CLAUDE.md         commit + push the dotprofile;
                                              (keep {{TOKENS}} for per-machine      each machine picks it up at its
                                               values)                              next `aitools`
  the fleet default (no-dotprofile users)     shared/claude-shared.md               PR to aitools; mirror shared
                                                                                    structure into the dotprofile
                                                                                    template (4.5)
  one machine only                            not supported: the next unattended    keep it in the template under
                                              run overwrites ~/.claude/CLAUDE.md    a heading that names the machine
  something you already typed into            run `aitools` interactively and       the adopt filter writes the
  ~/.claude/CLAUDE.md                         choose [a] at the CLAUDE.md review    dotprofile template and pushes it
  Cursor's user-level instructions            shared/cursor-rules/user-rules.md,    or a shared rule (fanned out to
                                              then paste into Cursor Settings       ~/.cursor/rules/*.mdc)
  the relay text agents should see            .aitools/channel/relay.md             commit (channel exception);
                                                                                    `aitools` rewrites the mirror
```

## 8. Rule of thumb for agents

- Never edit `~/.claude/CLAUDE.md` (or `%USERPROFILE%\.claude\CLAUDE.md`)
  directly to change behaviour: it is a rendered copy and the next
  unattended run overwrites it.
- Never run `setup-user-claude` against the real `HOME` from an agent;
  propagation is the commander's `aitools` run
  (`shared/rules/tool-lifecycle.md` "Rebuild + propagate").
- When the commander reports "my CLAUDE.md change disappeared", check
  `deploy.log` for `local edits overwritten (non-interactive run, backup
  kept): ~/.claude/CLAUDE.md` / `Diff in ~/.claude/CLAUDE.md -- overwriting
  (--force)` and the `CLAUDE.md.bak.<timestamp>`
  beside it.

## 9. Paths

```
  WHAT                          macOS / Linux                         Windows
  ----                          -------------                         -------
  user CLAUDE.md                ~/.claude/CLAUDE.md                   %USERPROFILE%\.claude\CLAUDE.md
  its backups                   ~/.claude/CLAUDE.md.bak.<TS>          %USERPROFILE%\.claude\CLAUDE.md.bak.<TS>
  dotprofile template           ~/repos/aitools-<user>/claude/        %USERPROFILE%\repos\aitools-<user>\
                                CLAUDE.md                             claude\CLAUDE.md
  shared template               ~/repos/aitools/shared/               %USERPROFILE%\repos\aitools\shared\
                                claude-shared.md                      claude-shared.md
  profile.json                  ~/repos/aitools-<user>/profile.json   %USERPROFILE%\repos\aitools-<user>\profile.json
  config.json (userRepoPath)    ~/.aitools/config.json                %USERPROFILE%\.aitools\config.json
  deploy log (diff records)     ~/.aitools/logs/deploy.log            %USERPROFILE%\.aitools\logs\deploy.log
  Cursor AGENTS.md mirror       ~/.cursor/AGENTS.md                   %USERPROFILE%\.cursor\AGENTS.md
  relay source                  ~/repos/aitools/.aitools/channel/     %USERPROFILE%\repos\aitools\.aitools\
                                relay.md                              channel\relay.md
  writer                        scripts/setup-user-claude.sh          scripts/setup-user-claude.ps1
                                (bash; Linux = same as macOS)         (pwsh 7; run by `aitools` from Git Bash)
```

`~/repos` is the default repos path (`reposPath` in config.json); the
dotprofile is found by the resolver, not by this path
(`@reference/user-repo.md` "Resolution"). Claude Code on Windows runs hooks
and Bash in Git Bash, but setup-user-claude.ps1 itself runs in PowerShell 7.

## 10. Cross-references

- Rules and skills reaching `~/.claude` and `~/.cursor`: `@reference/artifact-manifests.md`
- JSON configuration (settings.json, config.json, MCP, Cursor CLI): `@reference/managed-configuration.md`
- Review menu state machine and outcomes: `@reference/managed-file-deployment.md`;
  `.claude/rules/interactive-menus.md`; `.claude/rules/agentic-standards.md`
  "Managed-file review choices and merge" (AI merge)
- Dotprofile, profile.json, resolution, machine profiles: `@reference/user-repo.md`
- Delivery paths and template sync: `.claude/rules/deploy-paths.md`
- Cursor loading and the AGENTS.md gap: `@reference/tool-ops-cursor.md`,
  `@reference/cursor-practices.md`
- Code: `scripts/setup-user-claude.sh` / `.ps1` (template, render, footer,
  adopt filter), `scripts/aitools-lib.sh` / `.ps1` (`deploy_managed_file`,
  `prompt_diff_review`, `_review_diff`, `dotprofile_commit_push`),
  `scripts/sync-relay-to-cursor-agents.py`
