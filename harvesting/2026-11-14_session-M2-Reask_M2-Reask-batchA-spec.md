# M2-Reask batch A spec v1.0: library wrapper + lib menus + answer logging

Files: scripts/aitools-lib.sh, scripts/aitools-lib.ps1 (both twins together).

1. Add `read_menu_choice` (bash) right after `read_tty_choice`, and `Read-MenuChoice`
   (PS1) right after `Read-ConsoleChoice`, exactly per the shared contract in
   M2-Reask-common-brief.md. Header comment on each: purpose, args, EOF detection
   (contract flag + warnings-delta fallback), hot-loop guard, parity note, spec
   pointer (reference/managed-file-deployment.md "Menus", .claude/rules/interactive-menus.md).
   Also initialise the contract variables at lib load: bash `READ_TTY_EOF=0`, PS1
   `$script:ReadConsoleEof = $false` (do NOT touch the bodies of read_tty_choice /
   Read-ConsoleChoice: mission M3-Fixes owns them).
2. Convert these menus to the wrapper (menu lines unchanged; the wrapper prints the
   prompt line, so remove the caller's own prompt printf/Write):
   a. prompt_diff_review / Prompt-DiffReview: VALID "o a m s x" with adopt, "o s x"
      without; DEFAULT o; DEFAULT_DESC "overwrite"; CONTEXT "review <file leaf or
      display path>"; PROMPT "  choice [o/a/m/s/x]: " / "  choice [o/s/x]: ".
      Explicit branches for each valid answer; the old `*)` / `default` overwrite
      branch goes (keep a defensive `*)` that logs an error and re-loops, or
      equivalent, since the wrapper only returns valid answers). The "a"/"m" without
      adopt branches go (not valid answers any more).
   b. prompt_json_field_review / Prompt-JsonFieldReview: VALID from the flags:
      overwrite allowed + adopt allowed "o a s x"; overwrite allowed, no adopt
      "o s x"; overwrite not allowed "a s x" (adopt is always allowed there today;
      if adopt_allowed=0 and overwrite_allowed=0 use "s x"); DEFAULT o, or s when
      overwrite is not allowed; DEFAULT_DESC the existing $default_desc; CONTEXT
      "json <leaf>" (or "<file label>: <leaf>" where a file label exists after the
      M1 merge); PROMPT the existing "  choice [...]: " text. Add an explicit `o`
      branch (today `o` only works through the default branch).
   c. _invoke_ai_merge / Invoke-AiMerge accept prompt: VALID "y r n"; DEFAULT n;
      DEFAULT_DESC "reject the merge (back to the review menu)"; CONTEXT "merge
      preview <leaf>"; PROMPT "  [y]es accept / [r]efine / [n]o reject: " (bash
      had a leading "\n" in the same printf: print the blank line separately before
      the wrapper call so the re-asked prompt has no blank line).
      The "refinement feedback:" read stays free text (out of scope): unchanged.
   d. Any other choice prompt in these two libs found by the inventory
      (M2-Reask-Inv-inventory.md) -- list each one you convert.
2e. PROMPT and CONTEXT carry user data (alias values, repo names, file paths):
   print as data (bash `printf '%s' "$prompt" > /dev/tty`; PS1 `[Console]::Write($Prompt)`),
   never as a printf format. PS1 Read-MenuChoice must emit nothing to the pipeline
   except its return value (check LogDetail/LogWarn do not write to the output stream;
   callers assign `$x = Read-MenuChoice ...`).
3. Every answer is logged by the wrapper (detail). Keep the existing outcome lines
   ("  >> overwritten: ...") unchanged.
4. Verify: bash -n, pwsh parser, `git diff --summary` (no mode change), and run
   tests/managed-files/test-managed-files.sh (Git Bash) and
   tests/managed-files/test-managed-files.ps1 (pwsh). pty cases SKIP locally
   (no pywinpty): say so. Expect the existing test "empty choice at the menu:
   overwrite" (PS1) to fail/hang only if it runs -- it is SKIPPED locally; batch D
   rewrites it. Also run a quick non-pty unit probe of the wrapper: PS1 via
   `[Console]::SetIn([IO.StringReader]::new("`n`nskip`nq`no`n"))` then
   Read-MenuChoice -> expect "o" with 4 re-ask hints and 5 detail lines; and an
   empty Console.In -> expect the default plus the EOF warning. bash: define a stub
   `read_tty_choice` after sourcing the lib that reads from a file descriptor, to
   drive read_menu_choice the same way (and an EOF stub that calls log_warn and
   returns "").
