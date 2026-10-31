## Web Source Reading

**Intent**: **Purpose**: Make every coding agent read web content through a
real browser (the Chrome DevTools MCP, `chrome-devtools` skill) instead of
WebFetch, so what the agent acts on is what the page actually says.
**Scope**: Which tool reads web pages, the fallback when the browser is not
available, and how to disclose a fallback. NOT web search (finding pages).
NOT browser automation for testing or debugging (`chrome-devtools` skill).
NOT tool evaluation (`/tool-eval` skill). **Audience**: Every agent, in every
repo, on every platform and environment.

### The rule

When you read any web page — official docs, API references, release notes,
changelogs, READMEs, issues, blog posts, tutorials, Stack Overflow, anything
— strongly prefer the Chrome DevTools MCP over WebFetch. There is no
"low-stakes" exemption: the cost of a browser read is a few tool calls; the
cost of acting on a wrong summary is unbounded.

Load the `chrome-devtools` skill and follow its gidance/instructions:

Expand tabs, platform toggles and collapsed sections (`click`) before reading 
content that hides behind them.  Quote what you record verbatim from the page, 
never from memory.

### Why

WebFetch converts HTML to markdown and then summarizes it through a smaller
model: two layers of information loss. It does not run JavaScript, so it
misses SPAs, tabbed install instructions, platform toggles and lazy-loaded
content, and it can paraphrase commands, versions and flags. A real browser
renders the page the way a human sees it and returns the text unchanged.

### Fallback (only when the browser cannot be used)

Use WebFetch only when the Chrome DevTools MCP is not available in the
session, or fails on the page after a retry (crash, timeout, a block the
browser cannot pass). When you fall back:

- Say so in your response: which URL, why the browser was not used
- Treat the result as a lead, not a fact; do not record WebFetch output
  verbatim in a source-of-truth file — re-read it in the browser first
- If the MCP is missing or broken, surface that so it can be fixed

### Cross-references

- Browser tools and patterns: `chrome-devtools` skill
- How to read a tool's docs: `/tool-ops` skill
- Before reading a managed tool's docs: `/tool-registry` skill (it may
  already hold verified information)
