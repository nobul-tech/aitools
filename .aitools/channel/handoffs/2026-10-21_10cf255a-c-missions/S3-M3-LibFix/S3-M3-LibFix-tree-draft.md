# S3-M3-LibFix draft: decision tree rev 5 names (awaiting approval)

**Intent**: **Purpose**: The exact text changes that make reference/tool-support-decision-tree.md (protected; rev 5 is on PR #78, branch docs/m2-tree-user-repo) match the PR #80 result-name Contract. **Scope**: those five passages only. NOT applied: the file is protected and owned by PR #78, so it needs Jose's approval and the owner of #78 to apply it. **Audience**: Jose, the PR #78 owner, the M2 lead.

The source is review S3-M3-LibFix-Review M2 (https://github.com/nobul-tech/aitools/pull/80#pullrequestreview-5620940373). Line numbers are those at /Users/new-jose/repos/aitools/.claude/worktrees/m3docs/reference/tool-support-decision-tree.md on 2026-10-22.

1. **Lines 309-310** (section 7 introduction, the globals list).
   - Old: `` `TOOL_EXC_PLATFORM` / `TOOL_EXC_METHOD` / `TOOL_EXC_PATH` / `TOOL_EXC_DECIDED_AT` (`tool_exception_get`) ``
   - New: `` `AITLIB_TOOL_EXC_FOUND` / `AITLIB_TOOL_EXC_PLATFORM` / `AITLIB_TOOL_EXC_METHOD` / `AITLIB_TOOL_EXC_PATH` / `AITLIB_TOOL_EXC_DECIDED_AT` (`tool_exception_get`; the `AITLIB_` prefix is the aitools-lib result-name contract, PR #80) ``
2. **Line 399** (section 7.2 table, `tool_exception_get` row, last column). The old text contradicts lines 300-305 and 377.
   - Old: ``prints `<platform>|<method>|<path>|<decidedAt>` or nothing; 1 store unavailable (one warn; treated as no exception). Wraps `aitools-profile.sh` / `.ps1 exception-get` (section 8)``
   - New: ``sets `AITLIB_TOOL_EXC_FOUND` (true/false) and `AITLIB_TOOL_EXC_PLATFORM` / `_METHOD` / `_PATH` / `_DECIDED_AT`; PS1 returns `@{Found; Platform; Method; Path; DecidedAt}` or `$null`; 1 store unavailable (one warn; treated as no exception). Wraps `aitools-profile.sh` / `.ps1 exception-get` (section 8)``
3. **Line 567** (section 8 Location).
   - Old: `` result in `MACHINE_ALIAS` / `MACHINE_VIA` ``
   - New: `` result in `AITLIB_MACHINE_ALIAS` / `AITLIB_MACHINE_VIA` (PowerShell `$script:AitLibMachineAlias` / `$script:AitLibMachineVia`) ``
4. **Line 618** (section 8 Writer).
   - Old: `` Allowed when `MACHINE_VIA` is `id`, ``
   - New: `` Allowed when the resolved via (`AITLIB_MACHINE_VIA`) is `id`, ``
5. **Optional, section 8 Writer.** Add after the writer sentence: ``The writer sets `AITLIB_TOOL_EXC_RESULT` (created, updated, unchanged, dry-run, refused, failed) and `AITLIB_TOOL_EXC_PUSHED`; unchanged and dry-run write nothing and do not warn.``
