# S3-H-Cursor research: Cursor's user-level rules location

Written by S3-H-Cursor, 2026-10-22. All web sources were read through the
chrome-devtools MCP (navigate plus in-page `fetch` of the `.md` variant that the
site's `llms.txt` lists). Retrieved 2026-10-22 ~20:30Z. The raw captures were
`.scratch/session-hcursor/cursor-docs-rules.json` and `cursor-docs-md.json` (scratch, not tracked).

## Answer

| Surface | User-level rules location | Format | Evidence |
|---------|--------------------------|--------|----------|
| Cursor IDE (desktop, 3.13.10) | `~/.cursor/rules/` (Windows: `%USERPROFILE%\.cursor\rules`) | `*.mdc` with `---` frontmatter; `.md` ignored | help doc (A1) + IDE bundle (B3) |
| Cursor CLI `agent` (2026.05.21-f84ab11) | same directory | same | help doc (A1) + CLI bundle (B1, B2) |

The rule files are **loaded through an ancestor walk**. Both surfaces walk from the
workspace directory up to `/` and load `<dir>/.cursor/rules/**/*.mdc` at each
level, so `~/.cursor/rules/*.mdc` applies to every workspace **under `$HOME`**
and to **no workspace outside it** (for example `/tmp/x`, `C:\repos\x`, or
`D:\code\x`). Neither surface has a separate "home rules" lookup (B2, B3).

The `.md` files in `~/.aitools/rules` (Claude Code format) must be **converted** to
`.mdc` with frontmatter: plain `.md` is ignored (A2, B2), and a `.mdc` without a
leading `---` frontmatter block is dropped silently (B4).

The live canary was **not run**: the Cursor CLI is not authenticated on this
machine (section C). The location rests on one official doc sentence (A1) plus
the shipped code of both clients (B1-B4). There is no observed agent answer.

## A. Official documentation (verbatim)

A1. https://cursor.com/help/customization/rules.md, "Where are rules stored?"
(retrieved 2026-10-22):

> - **Project rules** are stored in `.cursor/rules/` inside your project folder. They're version-controlled with git.
> - **User rules** in Cursor Settings are stored on your Cursor account. They apply across all your projects and sync when you sign in on another machine.
> - **User rule files** in `~/.cursor/rules` (Windows: `%USERPROFILE%\.cursor\rules`) stay on the machine and do not sync.

A2. https://cursor.com/docs/rules.md, "Rule file structure" (retrieved 2026-10-22):

> Each rule is an `.mdc` file that you can name anything you want. Project rules must use the `.mdc` extension. A plain `.md` file in `.cursor/rules` is ignored by the rules system because it has no frontmatter to specify `description`, `globs`, and `alwaysApply`. If you prefer plain markdown, use [AGENTS.md](https://cursor.com/docs/rules.md#agentsmd) instead.

A3. https://cursor.com/docs/rules.md, frontmatter semantics (verbatim table rows):

> | `true` | — | — | Always included. Globs and description are ignored. |
> | `false` | — | provided | Auto-attached when a matching file is in context. |
> | `false` | provided | omitted | Agent reads the description and pulls the rule in when relevant. |
> | `false` | omitted | omitted | Included only when you @-mention the rule in chat. |

A4. https://cursor.com/docs/rules.md, "User Rules" (the reference page names only the UI):

> User Rules are global preferences defined in **Customize → Rules** that apply across all projects. They are used by Agent (Chat) [...]

A5. https://cursor.com/docs/cli/using.md, "Rules":

> The CLI agent supports the same rules system as the editor. You can create rules in the `.cursor/rules` directory [...] The CLI also reads AGENTS.md and CLAUDE.md at the project root (if present) and applies them as rules alongside `.cursor/rules`.

A6. **Contradiction.** https://cursor.com/docs/skills.md (migration section):

> User rules are also not migrated since they are not stored on the file system.

This sentence is about the account-stored User Rules (A1, bullet 2). It does
not contradict the *user rule files* bullet, but a reader can take it to mean
that no file location exists. The reference pages (A4, A5) never mention
`~/.cursor/rules`. A1 is the only doc that does.

A7. https://cursor.com/docs/rules.md, precedence: "Rules are applied in this order: **Team Rules → Project Rules → User Rules**."

## B. Empirical evidence from the installed clients (read-only inspection)

The code was read from the installed bundles with a Perl context grep (`.scratch/session-hcursor/grep-bundle.pl`).
Minified identifiers are quoted as found.

B1. CLI `generate-rule` / `/rules` create flow,
`~/.local/share/cursor-agent/versions/2026.05.21-f84ab11/8463.index.js`:

```
{value:"user",label:"User Rule",hint:"Applies to all your projects",path:l().join((0,s.homedir)(),".cursor","rules")}
...
const o="user"===e.scope?l().join((0,s.homedir)(),".cursor","rules"):l().join(t,".cursor","rules");
... d=l().join(o,`${e.ruleName}.mdc`) ... `---\ndescription: ...\nglobs:\nalwaysApply: false\n---\n...`
```

The CLI's own `/rules` browser (`1931.index.js`) lists the user scope from
`join(homedir(),".cursor","rules")` and keeps only files with `.endsWith(".mdc")`.

B2. CLI agent loader, `index.js`, `LocalCursorRulesService.load` calls
`loadRulesFromDirAndAncestors(workspace)`:

```
for(;;){const e=(0,s.join)(o,".cursor","rules");i.push(... this.loadRulesFromDirectory(r.ctx,e) ...);
const t=[];a&&t.push("CLAUDE.md","CLAUDE.local.md"),t.push("AGENTS.md"); ...
const n=(0,s.dirname)(o);if(n===o)break;o=n}
```

and `loadRulesFromDirectory` walks `includeGlobs:["**/*.mdc"]`.

B3. IDE agent loader, `/Applications/Cursor.app/Contents/Resources/app/extensions/cursor-agent-exec/dist/main.js`
(Cursor 3.13.10): same `LocalCursorRulesService.loadRulesFromDirAndAncestors`
loop and the same `includeGlobs:["**/*.mdc"]`.

B4. Frontmatter parser and type mapping (CLI `index.js`; the IDE matches):

```
function cr(e){const t=e.trimStart();if(!t.startsWith("---"))return null; ...
  "globs"!==l||""!==c?i[l]=lr(c):(i.globs=[],a="globs") ...  // `globs:` + `- item` lines -> array
function ur(e){ if(!0===e.frontmatter.alwaysApply) -> global
  else globs non-empty -> fileGlobbed
  else description non-empty -> agentFetched
  else -> manuallyAttached }
```

So:
- No frontmatter means `null` and the rule is skipped.
- `alwaysApply: true` means the rule is always included.
- A YAML list under `globs:` is accepted.

B6. **Glob anchoring** (found by S3-H-Cursor-Review and re-verified by the author).
IDE `cursor-agent-exec/dist/main.js`:

```
function rL(e){...for(let e=r.length-2;e>=0;e--)if(".cursor"===r[e]&&"rules"===r[e+1]){const t=r.slice(0,e);return 0===t.length?tL:t.join(tL)}return n}
function aL(e,t){...if("fileGlobbed"===n){const t=e.type?.type.value.globs??[],n=nL(rL(e.fullPath)),s=iL(r,n)?r.slice(n.length+1):void 0;
  return t.some(e=>{const t=(0,qF.oL)(e);return(0,eL.Z1)(t)?(0,QJ.xF)(r,t,{dot:!0}):!!s&&(0,QJ.xF)(s,t,{dot:!0})})}
```

The IDE matches a relative glob against the file path relative to the
directory that owns `.cursor/rules`. For a user rule file that directory is
`$HOME`. An absolute glob is matched against the full path. So the literal
`scripts/**` matches only `~/scripts/...`, while `**/scripts/**` matches
`~/repos/aitools/scripts/...`. The CLI bundle has no client-side glob matcher,
so its anchoring is **unknown**. A `**/` prefix is correct under either anchor
(`$HOME` or the workspace).

B5. Neither bundle (CLI `index.js`, IDE `cursor-agent-exec/dist/main.js`,
`workbench.desktop.main.js`) contains `".cursor","AGENTS.md"` or
`.cursor/AGENTS.md`. The loader reads `<ancestor>/AGENTS.md`, which is
`~/AGENTS.md`. See INCIDENT marker 1 in the hand-back. Caveat: a path built
dynamically would not show up in a string search.

## C. Canary test (verbatim)

Design: an empty workspace `/tmp/hcursor-canary-ws`, outside every repo, so no
project rules can leak in. Prompt (`.scratch/session-hcursor/canary-prompt.txt`):
"Do not use any tools [...] list every token you were given in your rules or
instructions that starts with AITOOLS-CANARY- [...] If you were given none,
print exactly NONE." Plan:
1. Baseline run with no canary.
2. Two canaries in `~/.cursor/rules/`: `aitools-canary-<ts>.mdc` with
   `alwaysApply: true`, and `aitools-canary-<ts>.md` (plain), each with its own
   token.
3. `--output-format stream-json`, to prove that no tool call read the token off
   disk.

C1. Isolated HOME (`HOME=<scratch>/home agent status`):

```
Not logged in
```

The CLI stores its auth per HOME, so it cannot run under an isolated HOME.

C2. Real HOME, `agent status`:

```
✓ Login successful!
Logged in (unable to fetch user details)
```

`agent about`, run both inside and outside the Claude Code sandbox:

```
User Email          Not logged in
```

The baseline `agent -p --trust --mode ask --workspace /tmp/hcursor-canary-ws --output-format stream-json "<prompt>"` returned exit 1:

```
Error: Authentication required. Please run 'agent login' first, or set CURSOR_API_KEY environment variable.
```

**Result: NOT RUN.** `agent login` needs the commander's browser. No canary
file was created, and the real `~/.cursor` was not modified. `~/.cursor/rules/`
did not exist before this session and still does not.

C3. Manual canary for the commander (run after `agent login`; about 1 minute):

```bash
mkdir -p ~/.cursor/rules ~/hcursor-canary-ws
printf -- '---\nalwaysApply: true\n---\nThe secret token is AITOOLS-CANARY-MDC-7Q4.\n' > ~/.cursor/rules/aitools-canary.mdc
printf 'The secret token is AITOOLS-CANARY-MD-9K2.\n' > ~/.cursor/rules/aitools-canary.md
cd ~/hcursor-canary-ws
agent -p --trust --mode ask "Do not use any tools. List every token in your rules that starts with AITOOLS-CANARY-, one per line, or print NONE."
rm ~/.cursor/rules/aitools-canary.mdc
rm ~/.cursor/rules/aitools-canary.md
```

Expected from the code (B2-B4): `AITOOLS-CANARY-MDC-7Q4` only. The workspace
must be under `~`. A second run from `/tmp/x` should print `NONE`.

## D. Consequences for the fan-out

1. Target: `$HOME/.cursor/rules/` (bash) and `$env:USERPROFILE\.cursor\rules` (PS1).
   Source, per the S3-Harness contract correction of 2026-10-22: only
   `~/.aitools/rules/*.md`. `*.bak.*` backups and other files are skipped.
2. Convert `<name>.md` to `<name>.mdc`:
   - No frontmatter: prepend `---\nalwaysApply: true\n---\n` (this matches
     Claude Code, where a rule without `paths:` is always loaded).
   - Claude Code `paths:` frontmatter (a block list, a list at column 0, one
     value, or a `[a, b]` flow list): rewrite it as a `globs:` **block list**
     with indented `  - ` items. Cursor splits an inline value on commas
     (`src/**/*.{ts,tsx}` would break) and reads only indented items. Anchor each
     relative pattern as `**/<pattern>` (B6). Keep absolute and `**/` patterns.
     Add `alwaysApply: false` (A3 row 2, "Auto-attached when a matching file is
     in context").
   - Every other frontmatter key is kept.
   - After the deploy, check each converted file the way Cursor parses it (it
     splits the whole file on `---`). A `---` inside a frontmatter value is
     reported with `log_warn`.
   - Revised after review on PR #87 (B1, N1-N3).
3. Reach: only workspaces under the user's home directory. aitools repos live
   under `~/repos/` (macOS) / `%USERPROFILE%\repos\` (Windows, per the user
   CLAUDE.md), so the rules reach them. `.claude/rules/cross-platform.md` says
   Windows repos live in `C:\repos\`, which is **outside** `%USERPROFILE%`, and
   user rule files would not load there. See the open question in the hand-back.
4. Size: every `alwaysApply: true` rule is included in every Agent chat in every
   workspace under `$HOME`. `~/.aitools/rules` will hold aitools'
   `.claude/rules` (26 files) plus shared/dotprofile rules. Many of them carry
   `paths:`, so they become file-globbed rather than always-applied.
