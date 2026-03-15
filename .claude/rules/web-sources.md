---
paths:
  - scripts/**
  - deploy/**
  - shared/**
  - reference/**
  - plans/**
  - rfcs/**
  - .claude/rules/**
  - .cursor/rules/**
  - CLAUDE.md
  - RELEASE_NOTES.md
  - ROADMAP.md
  - README.md
---

## Web Source Reading (this repo)

When reading web content that will feed into source-of-truth files
(install commands, config steps, lifecycle fields, setup procedures),
use the Chrome DevTools MCP skill (`chrome-devtools`) instead of WebFetch.

### Why

WebFetch converts HTML to markdown via a smaller model -- two layers of
information loss (rendering + summarization). Official docs sites are
often JS-rendered SPAs with tabbed interfaces and platform toggles that
WebFetch misses. When accuracy matters, use the real browser.

### When to use Chrome DevTools MCP skill

- Reading official tool docs to extract install commands for the `/tool-registry` skill
- Verifying config requirements, post-install steps, or dependencies
- Checking release notes or changelogs for lifecycle field updates
- Any page whose content will be recorded verbatim in a protected file

### When WebFetch is fine

- General web searches and research (use WebSearch for queries)
- Blog posts, tutorials, Stack Overflow -- low-stakes reference
- Quick fact-checks that don't feed into protected files
- Static pages where JS rendering isn't needed (plain GitHub READMEs)

### Cross-reference

Before reading a tool's docs, check via the `/tool-registry` skill first --
it may already have verified information. If proposing changes to an existing
entry, re-verify using Chrome DevTools MCP skill before editing.
