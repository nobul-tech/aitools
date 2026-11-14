# M2-Reask common brief v1.0 (for every M2-Reask delegate)

Read this file in full; it is part of your delegation prompt.

## Rules and CLAUDE.md files (read IN FULL before other work, any not already in your context)
- User: C:\Users\jdpal\.claude\CLAUDE.md; C:\Users\jdpal\.claude\rules\concurrent-agents.md, scratch.md, tool-evaluation.md, tool-lifecycle.md, tool-ops.md, web-sources.md (delegation.md does not exist on this machine; the /delegate skill carries it)
- Project: C:\Users\jdpal\repos\aitools\CLAUDE.md; C:\Users\jdpal\repos\aitools\.aitools\channel\CLAUDE.md; every file in C:\Users\jdpal\repos\aitools\.claude\worktrees\menus-reask\.claude\rules\ (agentic-standards.md, aitools-workspace.md, config-file-safety.md, cross-platform.md, deploy-paths.md, documentation-standards.md, frameworks.md, git-safety.md, glossary.md, governed-data-access.md, hook-lifecycle.md, hook-rollout.md, incident-governance.md, interactive-menus.md, managed-file-deployment.md, script-standards.md, smoke-test-pattern.md)
- Mission-specific (worktree copies under C:\Users\jdpal\repos\aitools\.claude\worktrees\menus-reask\reference\): managed-file-deployment.md, script-standards-detail.md (sections you need; it is 1231 lines -- read at least "Logging", "Exit footer", "Error handling"), cross-platform-detail.md, logging.md

## Critical rules restated
- Simple Bash only: no `$(...)`, backticks, `&&`, `||`, `;`, multi-line commands, or globs in `rm` in a Bash tool call. Separate calls; anything longer goes in a scratch script you Write and then run (`bash <file>` / `pwsh -NoProfile -File <file>`). The standing-order-guard hook also blocks cat/head/tail/sed/awk outside a pipeline (use Read) and `;` inside `pwsh -Command` (use `pwsh -File`). Never a foreground sleep.
- Read/Edit/Write/Grep/Glob for file operations; Perl, not sed/awk, for string manipulation.
- No silent failures in reusable code; structured logging only (log/log_warn/log_detail; Log/LogWarn/LogDetail).
- PS1 and bash menus MUST show identical options, text and order (interactive-menus.md; check-post-push step 29 audits it).
- Console I/O: PS1 `[Console]::Write/WriteLine` and input only through Read-ConsoleChoice (via the new wrapper); bash `printf ... > /dev/tty` and input only through read_tty_choice (via the new wrapper). Never `Read-Host`/`Write-Host`, never a bare `read`.
- bash 3.2 compatible (no `${var,,}`, no associative arrays, no `mapfile`; `printf -v` is fine). ASCII in PS1 code.
- Run `bash -n` and the pwsh parser on every touched script:
  `pwsh -NoProfile -File <scratch>/parse.ps1 <path>` where parse.ps1 runs `[System.Management.Automation.Language.Parser]::ParseFile($args[0],[ref]$null,[ref]$e)` and prints `$e`.
- Run `git diff` on a file before editing it (concurrent agents). Never switch the main checkout's branch, never commit there, never remove another agent's worktree, never force-push, never push to main.
- The edit hook sh-file-fixup sets +x on any edited .sh: after editing any .sh check `git ls-files -s` / `git diff --summary` for a mode change vs origin/main and ship none (on origin/main 941e64a scripts/aitools-lib.sh is already 100755, so no change is expected there; a test file that was 100644 must stay 100644).
- Never run aitools, aitools install, setup-user-*, deploy-harness or build-deploy.sh against the real HOME; only under an isolated HOME in your scratch.
- Cite a source (file:function or command output) for every claim; say "unknown" rather than guess.

## Skills
Load /delegate first, before you launch any delegate of any kind, and give every delegate this same instruction (the duty recurses). Then /scratch. If a skill will not load, read C:\Users\jdpal\.claude\skills\<name>\SKILL.md by hand. Skill overrides: do not ask the user questions (state assumptions); do not file incidents (report `INCIDENT:` lines).

## Conflicts (D-DEL6)
Resolution order: 1) the commander's own words, newest first; 2) your delegation prompt (and this brief); 3) skills. A prompt cannot loosen a rule unless it quotes the commander. Never drop a mandated skill or rule silently: follow its non-conflicting parts and record `CONFLICT: <A> vs <B> -- resolved by <tier>: <what you did>`.

Commander's words for this mission (session 87795dc3, 2026-11-13, verbatim): "2) no default or other characters should re-ask." -- answering: "Should a bare Enter at a review menu re-ask instead of overwriting? Today Prompt-DiffReview, Prompt-JsonFieldReview and their bash twins treat any input they don't recognise as overwrite. That includes a bare Enter, a whole word such as skip, and keystrokes left over from the raw-console bug." Suggested and accepted: "re-ask on unrecognised input, bare Enter included. EOF, --force and non-interactive runs keep overwrite, as the spec says. ... logging every menu answer." These words override interactive-menus.md / agentic-standards.md / managed-file-deployment.md text saying an unrecognised/empty answer selects overwrite.

## WRITE_BLOCKED
If any write or tool call is denied by a permission check or hook, do not retry it in another form. Record `WRITE_BLOCKED: <what> -- <exact denial text>`, put the content in your response, and continue.

## Name prefix (D-DEL1)
Every *.md file you create starts with your prefix given in the prompt (e.g. `M2-Reask-A-notes.md`). A file mirroring a repo path keeps the repo name. Documents and spec edits are versions (v1.0, v1.1), never drafts (D-DEL5).

## Operational learning
- Root cause behind this mission: on Windows the review menu often read input in raw console mode; [Console]::ReadLine returned only after the NEXT key, keystrokes leaked into the next menu, and the switch default ("overwrite") silently applied a leaked or empty answer. Evidence: C:\Users\jdpal\repos\aitools\.scratch\session-87795dc3-e9b0-4f82-937b-139b3f13fa81\investigation-findings.md (read-only).
- Parallel missions you must not overlap: M1-Ship (branch fix/json-review-display: JSON review display in Prompt-JsonFieldReview/Review-JsonFields and their bash twins, deploy-harness read-only copies, .gitignore); M3-Fixes (branch fix/console-and-profile: the BODIES of Read-ConsoleChoice / read_tty_choice, setup-user-shell.*, aitools-install.ps1 Step 7, aitools.ps1 Step 2, the AI-merge spinner). Do not edit those.
- pywinpty is NOT installed on this Windows machine, so pty test cases in tests/managed-files SKIP locally; CI on Linux/macOS runs them.
- Known pre-existing check failures (record, do not block): pre-commit step 6 (harvesting file mode), step 20 dead path refs, pre-push step 7 (dotprofile deploy/ stale).
- `.ps1` files check out with CRLF (line-anchored patterns miss them); PowerShell names are case-insensitive; use absolute paths.
- GitHub repo nobul-tech/aitools, default branch main.

## Shared contract: the menu-choice wrapper (identical text in every batch)
New library helpers (in scripts/aitools-lib.sh / scripts/aitools-lib.ps1, placed right after read_tty_choice / Read-ConsoleChoice):

bash:   read_menu_choice VAR "VALID" DEFAULT "DEFAULT_DESC" "CONTEXT" "PROMPT"
PS1:    $c = Read-MenuChoice -Valid @(...) -Default <letter> -DefaultDesc "<desc>" -Context "<ctx>" -Prompt "<prompt>"

- VALID: the accepted answers, lowercase, space-separated in bash ("o a m s x"), an array in PS1. Usually single letters; may be words (e.g. "y n").
- DEFAULT: the answer taken ONLY at EOF (input ended). Must be one of VALID.
- DEFAULT_DESC: what the default does, passed to read_tty_choice / Read-ConsoleChoice for their EOF warning (e.g. "overwrite").
- CONTEXT: short label for the log line (e.g. "review CLAUDE.md", "settings.json permissions.allow[3]").
- PROMPT: the prompt line, printed by the wrapper before every read (e.g. "  choice [o/a/m/s/x]: "). The caller prints the menu lines; the wrapper prints the prompt line.
- Loop: print PROMPT; read one line through read_tty_choice / Read-ConsoleChoice (bodies unchanged; M3 owns them); trim surrounding whitespace; lowercase.
  - Answer in VALID: log at detail `menu answer (<CONTEXT>): "<raw>" -> <answer>`; return it (bash: set VAR; PS1: return value).
  - EOF: log at detail `menu answer (<CONTEXT>): EOF -> <DEFAULT>` (read_tty_choice/Read-ConsoleChoice already logged the warning); return DEFAULT.
  - Anything else (empty line, a word, an invalid letter): log at detail `menu answer (<CONTEXT>): "<raw>" -> not one of <a/b/c>, asked again`; print exactly `  please type one of a/b/c` (VALID joined with "/") on its own line, then loop (prompt printed again).
- EOF detection (read_tty_choice / Read-ConsoleChoice return "" both at EOF and for a typed empty line): the wrapper sets READ_TTY_EOF=0 / $script:ReadConsoleEof = $false before each read; it treats the read as EOF when READ_TTY_EOF=1 / $script:ReadConsoleEof is $true after the read (contract proposed to M3: read_tty_choice / Read-ConsoleChoice set it at EOF), OR, until M3 implements that, when the answer is "" and the warnings counter (bash WARNINGS, PS1 $script:warnings) rose during the read (their EOF branch calls log_warn / LogWarn, which increments it).
- Hot-loop guard: after 50 consecutive unrecognised answers the wrapper logs a warning `No valid answer after 50 tries at <CONTEXT> -- treating input as ended, defaulting to <DEFAULT_DESC>` and returns DEFAULT.
- Not called at all in --force / AITOOLS_FORCE / non-interactive runs: the callers keep their existing early returns (overwrite, or the documented default) before printing any menu.
- Detail lines are file-only (deploy.log), never on the console.
