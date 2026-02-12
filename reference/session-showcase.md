# Multi-Platform AI Tooling for Users

I work across Windows and macOS with multiple AI coding tools — Cursor and Claude Code — plus their integrations with external services via MCP servers. MCP (Model Context Protocol) is an open standard that lets AI tools connect to external services like Vercel, Webflow, and browser DevTools. Keeping all of this configured consistently and setup repeatable across two platforms is tedious and error-prone when done manually. I built automation to solve that for my own workflow.

## What This Covers

Eight setup scripts — four pairs of Windows PowerShell and macOS bash — plus shared configuration files and reference documentation:

- **Claude Code user preferences** — installs a cross-machine config file so every Claude Code session starts with the same identity, code style defaults, and tool preferences, regardless of which machine or project directory it's launched from

- **Cursor CLI and User Rules** — installs dependencies (ripgrep, required at runtime by Cursor's CLI), installs the Cursor CLI itself, writes a standard CLI config, and copies a centrally-managed set of AI behavior rules to the clipboard for pasting into Cursor Settings

- **Claude Code MCP servers** — configures Chrome DevTools (local browser automation), Vercel (deployment platform), and Webflow (site builder) integrations using Claude Code's config format

- **Cursor MCP servers** — configures the same three servers using Cursor's different config format and file location

- **Shared rules and templates** — a single source-of-truth file for User Rules that feeds both tools, a default project rules template for scaffolding new repos, and reference documentation covering both tools' setup procedures and known quirks

Each script is idempotent — safe to re-run without duplicating or corrupting existing configuration.

### Repo Structure

```
ai-tooling/
  scripts/              8 setup scripts (4 PowerShell + 4 bash pairs)
  shared/
    claude-shared.md    Shared preferences (source of truth)
    cursor-rules/       User Rules + project rule templates
    mcp/                MCP server documentation
    shell/              Shell aliases for both platforms
  reference/            Setup notes, practices, and this document
  docs/                 Vendor documentation for offline/RAG use
```

The repo syncs between machines via Google Drive. Scripts reference platform-appropriate paths at runtime.

## The Cross-Platform Problem

This is harder than it looks. A few examples from the actual work:

**Paths, package managers, and shells differ everywhere.** Windows uses `winget` for package installation and PowerShell for scripting; macOS uses `brew` and bash. Clipboard commands (`Set-Clipboard` vs `pbcopy`), path separators, home directory variables (`$env:USERPROFILE` vs `$HOME`), and JSON file locations are all platform-specific. Every script needs two complete implementations that produce the same result.

**Same servers, different config formats.** Claude Code and Cursor both connect to the same MCP servers, but their JSON structures differ. Claude Code uses `type`, `command`, and `args` fields and stores config in `~/.claude.json`. Cursor uses `command`/`args` for local servers and a `url` field for remote ones, stored in `~/.cursor/mcp.json`. There is no shared config — each tool needs its own setup logic.

**Undocumented interop gaps.** Cursor can read Claude Code's user config file (`~/.claude/CLAUDE.md`), which sounds like free interoperability. In practice, Cursor doesn't resolve the `@import` directives that Claude Code supports, so a config file that works in one tool is silently incomplete in the other. The workaround: the setup script reads the shared source file and writes its contents inline, so both tools see the same rules without either needing to understand the other's syntax.

**Platform-specific bugs require platform-specific fixes.** On Windows, Node.js is invoked through a `cmd /c` shim. Claude Code's own CLI command for adding MCP servers misinterprets the `/c` flag as a file path, silently producing a broken configuration that fails at runtime with an opaque "Connection closed" error. The fix: the Windows script bypasses the CLI entirely and edits the JSON config file directly. This category of issue doesn't surface until you actually run the scripts on both platforms.

**Idempotency is non-trivial.** Scripts need to detect existing configuration, remove it cleanly, and re-apply without leaving duplicates or corrupted state. Different tools offer different mechanisms for this — some have CLI commands for removal, others require parsing and rewriting JSON. Getting this right means a user can always re-run the setup after updating the source-of-truth files and trust that the result is correct.

## How This Was Built

The entire session — research, scripting, debugging, documentation — was done through AI pair programming: Claude Code running in Cursor's integrated terminal, working directly in the codebase.

This was not a one-shot generation. The process was iterative: write a script, test it, hit a platform-specific bug (like the `cmd /c` issue above), debug it with the AI's help, adjust the approach, and repeat. Some decisions required reading vendor documentation that turned out to be incomplete or outdated, then verifying behavior empirically.

The AI handled the boilerplate — generating PowerShell and bash variants, JSON manipulation, argument parsing, and documentation formatting. The human made the architectural calls — what to automate, where to draw boundaries between tools, how to structure source-of-truth files, and what to document versus what to leave implicit.

## Why This Pattern Scales

**Onboarding.** A new team member runs a few scripts instead of following a multi-page setup guide with platform-specific branches. The result is a correctly configured environment in minutes, with fewer support requests and less variance between setups.

**Consistency.** Everyone gets the same AI behavior rules, the same integrations, and the same guardrails. There is no configuration drift between machines, between tools, or between people. When the team agrees on a convention, it propagates through a single file change.

**Maintainability.** Edit the source-of-truth file, re-run the script. Changes propagate without anyone manually editing JSON on each machine. The scripts themselves rarely need updating — they're structured around the config format, not the config content.

**Adaptability.** The same script-pair pattern works for any tool that stores config in files. Adding a new MCP server, a new set of rules, or support for a new tool means extending what's already there — not rebuilding from scratch. The repo is a scaffold, not a monolith.

A caveat worth stating: this was built for one person's workflow with specific tools. Scaling to a team would require testing across more environments, adding organization-specific configuration, and handling edge cases that don't appear with a single user. The pattern is proven; the specific scripts would need adaptation.

## Closing

The hardest part of AI enablement isn't the AI — it's the setup, maintenance, and consistency around it. Automating that layer is where the compounding value lives.
