# aitools at a glance

**Intent**: **Purpose**: Show on one page what aitools is: its parts, how
content flows from the repos to a machine and back, and where each thing
lives. It is drawn in ASCII, so a new agent or maintainer gets oriented in
one read. **Scope**: The big picture, the repo map, the learning loop, and
pointers to the detail. NOT component definitions (`reference/harness.md`).
NOT deploy mechanics (`reference/managed-file-deployment.md`,
`.claude/rules/deploy-paths.md`). NOT rule and skill anatomy
(`reference/rules.md`, `reference/skills.md`). NOT install steps
(`README.md`). **Audience**: Anyone new to aitools, every agent that needs
the map before the detail, and the commander when explaining aitools.

v1.0 (2026-11-04)

## In one sentence

aitools installs and manages the lifecycle of AI tools (Claude Code, Cursor, MCP servers and
CLI tools) on every machine and environment supported. It also ships the
**harness**: the rules, skills, hooks, references and registries that make
every agent session in every repo work the same way and start from what
the last session learned.

## 1. The big picture

```
  +-------------------------------+     +-------------------------------+
  | aitools repo   (everyone)     |     | dotprofile  aitools-<user>    |
  |  shared/    user-scope source |     |  profile.json  identity,      |
  |  .claude/   project rules and |     |                machines,      |
  |             skills            |     |                settings       |
  |  scripts/   CLI + setup code  |     |  claude/CLAUDE.md   template  |
  |  reference/ registries/       |     |  claude/rules/ claude/skills/ |
  +---------------+---------------+     +---------------+---------------+
                  |                                     |
                  +------------------+------------------+
                                     |
           three delivery paths: same scripts, equivalent result
                                     |
       +-----------------------------+-----------------------------+
       |                             |                             |
   DEV path                      MDM path                    PACKAGE path
   `aitools`, `aitools install`  build-deploy.sh             build-package.sh
   runs scripts/setup-*          -> <dotprofile>/deploy/     .pkg .intunewin .deb
   diff review + adopt           self-contained, no clone    (v1.0 scaffold)
       |                             |                             |
       +-----------------------------+-----------------------------+
                                     |
                                     v
  +-----------------------------------------------------------------------+
  | ~/.aitools/   the deployed harness  (deploy-harness, runs first)      |
  |   rules/  skills/  hooks/  reference/  registries/  bin/              |
  |   config.json (generated from profile.json)      logs/                |
  +-----------------------------------+-----------------------------------+
                                      |
         fan-out (setup-user-claude, setup-user-cursor) + setup-user-hooks,
         -settings, -mcp, -shell, setup-<tool>
                                      |
        +-----------------------------+-----------------------------+
        v                             v                             v
   ~/.claude/                    ~/.cursor/                    the machine
   CLAUDE.md  rules/  skills/    rules/*.mdc  skills/          CLI tools: gh uv
   hooks/  settings.json         cli-config  mcp.json          go rust typst
   MCP servers                                                 pandoc python ...
        |                             |                        shell aliases,
        +--------------+--------------+                        PATH block
                       v
     an agent session in ANY repo: macOS, Windows 11, Linux (Ubuntu);
     local, Claude Code web or Cursor cloud
```

The dotprofile wins for personal content (the CLAUDE.md template,
`profile.json`). For rules and skills the first source wins a name clash:
`shared/`, then `.claude/`, then the dotprofile.

## 2. The learning loop

```
  +------------------------------------------------------------------+
  |                                                                  |
  v                                                                  |
  SESSION START         WORK                     SESSION END         |
  scratch dir           PreToolUse guards:       archive transcript  |
  catch-up, handoff     standing orders,         harvest .scratch/   |
  harness DB            delegation duty,           -> harvesting/    |
  dashboard             glossary                 harness DB          |
                        PostToolUse: .sh fixup   tool-ops audit      |
                        Stop: failure-mode,                          |
                        intelligence                                 |
                                  |                                  |
                                  v                                  |
            harvesting/   handoffs   incidents   decisions           |
                                  |                                  |
                                  v                                  |
            promote into a rule / skill / reference / registry       |
            (a PR to aitools, or [a]dopt in the deploy menu)         |
                                  |                                  |
                                  v                                  |
            the next `aitools` run deploys it to every machine ------+
```

Hooks and their events: `shared/hooks/hooks-manifest.json`.

## 3. The harness: five artifact kinds

```
  KIND        LOADS              ANSWERS                LIVES IN
  ---------   ----------------   --------------------   ------------------------
  rule        always in context  what must be true      shared/rules/
                                                        .claude/rules/
  skill       on demand          how to do it           shared/skills/
                                                        .claude/skills/
  registry    through its skill  the data               registries/
  reference   when pointed to    why, and exact detail  reference/
  hook        on an event        is it happening now?   shared/hooks/
```

They form three governance layers:

```
  PREVENTION  ------->  DETECTION & ENFOCEMENT  ----->  AUDIT
  rules, skills,        hooks, pre-commit and      post-push checks, CI on
  CLAUDE.md             pre-push checks            macOS / Linux / Windows,
                                                   incidents (/incident), hook KPI metrics
```

There are five registries, each read and written only through its skill:
tools (`/tool-registry`), tool operations (`/tool-ops`), incidents
(`/incident`), vocabulary (`/glossary`) and frameworks (`/frameworks`).

## 4. Scope: where a source lives decides who it is for

```
  SOURCE                        WRITTEN FOR             REACHES
  ---------------------------   ---------------------   ----------------------
  shared/skills, shared/rules   any repo, any user      every repo (user scope)
  .claude/rules, .claude/skills work on aitools itself  aitools (project)
  <dotprofile>/claude/...       one user                that user's machines
  .cursor/rules                 Cursor in aitools       aitools (project)
```


## 5. Repo map

```
aitools/
|-- CLAUDE.md              orientation for every agent, every session
|-- README.md              install and quick start
|-- ROADMAP.md             in progress / planned / completed
|-- RELEASE_NOTES.md       version history
|
|-- shared/                SOURCE of everything deployed to user scope
|   |-- skills/            user-level skills, one directory each
|   |-- rules/             user-level rules
|   |-- hooks/             Claude Code hooks + hooks-manifest.json
|   |-- claude-shared.md   fallback template for ~/.claude/CLAUDE.md
|   |-- shell/             aliases.sh, aliases.ps1
|   |-- cursor-rules/      Cursor User Rules to paste by hand (not deployed)
|   `-- mcp/               MCP setup notes (not deployed)
|-- .claude/               project scope: rules, skills, commands
|-- .cursor/rules/         Cursor (.mdc) twins of the project rules
|
|-- scripts/               the code
|   |-- aitools  aitools.ps1           CLI entry points
|   |-- aitools-install.*  bootstrap.* installers
|   |-- aitools-lib.*  check-lib.*     shared libraries
|   |-- deploy-harness.*               fills ~/.aitools
|   |-- setup-user-*.*                 ~/.claude, ~/.cursor, settings, shell
|   |-- setup-<tool>.*                 one .sh/.ps1 pair per managed tool
|   |-- build-deploy.sh                MDM build -> <dotprofile>/deploy/
|   |-- build-package.sh               package build (scaffold)
|   |-- check-*.*                      pre-commit / pre-push / post-push
|   `-- *.py                           harness DB, harvest, session readers
|-- tests/                 one suite per area; CI runs them on 3 OSes
|-- packaging/             package launchers: macos/ windows/ linux/
|-- .github/workflows/     CI
|
|-- registries/            governed JSON (through its skill only)
|-- reference/             the detail behind the rules (this file)
|-- plans/                 multi-session plans
|-- rfcs/                  design RFCs
|
|-- harvesting/            harvested session artifacts, to promote
|-- .aitools/channel/      agent-to-agent files, handoffs, carry-forward
|-- deploy/                FROZEN historical MDM baseline (do not edit)
`-- .scratch/              per-session temp files (gitignored)
```

## 6. The commands you use

```
  aitools                 pull, rebuild, deploy everything      (daily)
  aitools install         install or upgrade tools, then deploy (new machine)
  aitools user init       connect the dotprofile, register this machine
  aitools --force         no prompts: the source wins (backups kept)
  aitools --dry-run       show what would change
  hh                      git pull, harness git status, then aitools
```

Both platforms, every flag: `README.md` "Quick start".

## 7. Where to go next

| You want | Read |
|----------|------|
| The components and how they relate | `reference/harness.md` |
| What rules and skills are, and their scopes | `reference/rules.md`, `reference/skills.md` |
| How a file gets deployed (menus, adopt, backups) | `reference/managed-file-deployment.md` |
| The three delivery paths | `.claude/rules/deploy-paths.md` |
| Dotprofile, profile.json, machine profiles | `reference/user-repo.md` |
| Platforms and environments supported | `reference/cross-platform-detail.md` |
| How the harness grows (frameworks) | `reference/framework-adoption.md` |
| Script conventions | `.claude/rules/script-standards.md` |
| Why it exists (the origins) | `reference/do-what-feels-right.md` |
