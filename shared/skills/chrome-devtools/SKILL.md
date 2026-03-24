---
name: chrome-devtools
description: Uses Chrome DevTools via MCP for efficient debugging, troubleshooting and browser automation. Use when debugging web pages, automating browser interactions, analyzing performance, or inspecting network requests.
---

## Intent

**Purpose**: Equip the agent with workflow patterns for Chrome
DevTools via MCP -- page interaction sequences, efficient data
retrieval, element inspection, accordion expansion, and documentation
reading shortcuts. **Scope**: Browser automation patterns and
troubleshooting guidance only. NOT accessibility-specific workflows
(see `/a11y-debugging`). NOT MCP server installation or configuration
(see `/tool-ops` skill for chrome-devtools MCP entry). **Audience**:
Any agent using the chrome-devtools MCP server for page inspection,
browser automation, or official documentation reading.

## Core Concepts

**Browser lifecycle**: Browser starts automatically on first tool call using a persistent Chrome profile. Configure via CLI args in the MCP server configuration: `npx chrome-devtools-mcp@latest --help`.

**Page selection**: Tools operate on the currently selected page. Use `list_pages` to see available pages, then `select_page` to switch context.

**Element interaction**: Use `take_snapshot` to get page structure with element `uid`s. Each element has a unique `uid` for interaction. If an element isn't found, take a fresh snapshot - the element may have been removed or the page changed.

## Workflow Patterns

### Before interacting with a page

1. Navigate: `navigate_page` or `new_page`
2. Wait: `wait_for` to ensure content is loaded if you know what you look for.
3. Snapshot: `take_snapshot` to understand page structure
4. Interact: Use element `uid`s from snapshot for `click`, `fill`, etc.

### Efficient data retrieval

- Use `filePath` parameter for large outputs (screenshots, snapshots, traces)
- Use pagination (`pageIdx`, `pageSize`) and filtering (`types`) to minimize data
- Set `includeSnapshot: false` on input actions unless you need updated page state

### Tool selection

- **Automation/interaction**: `take_snapshot` (text-based, faster, better for automation)
- **Visual inspection**: `take_screenshot` (when user needs to see visual state)
- **Additional details**: `evaluate_script` for data not in accessibility tree

### Expanding accordions, tabs, and FAQs

Many pages use JS-rendered accordions/tabs (e.g., FAQ sections) whose content is hidden until clicked. The a11y tree shows them as `tab` or `button` elements with `expandable` state but no inner content until expanded.

**Pattern:**
1. `take_snapshot` — identify the collapsed elements (look for `tab`/`button` with `expandable` but NOT `expanded`)
2. `click` on the element `uid` to expand it
3. `take_snapshot` again — the expanded content now appears inline in the tab/button's accessible name or as child nodes
4. Repeat for each accordion item

**Tips:**
- Only one accordion panel may be open at a time (clicking the next may collapse the previous) — snapshot after each click
- The expanded content often appears directly in the element's accessible name text, not as separate child nodes
- Save each snapshot to `filePath` to avoid flooding context when extracting large amounts of content
- If clicking doesn't expand (some require user interaction), ask the user to expand manually, then snapshot

### Parallel execution

You can send multiple tool calls in parallel, but maintain correct order: navigate → wait → snapshot → interact.

### Reading Claude Code docs efficiently

Every `code.claude.com/docs/en/<topic>` page has a markdown version at
`code.claude.com/docs/en/<topic>.md`. Navigate directly to the `.md`
URL — it gives clean markdown without the massive DOM of the rendered
page.

The full docs index is at: `https://code.claude.com/docs/llms.txt`

The rendered pages also have a "Copy page" dropdown (top-right) with:
- **Copy page** — copies as Markdown for LLMs to clipboard
- **View as Markdown** — opens the `.md` URL
- **Open in Claude** — opens in Claude for Q&A

## Troubleshooting

If `chrome-devtools-mcp` is insufficient, guide users to use Chrome DevTools UI:

- https://developer.chrome.com/docs/devtools
- https://developer.chrome.com/docs/devtools/ai-assistance

If there are errors launching `chrome-devtools-mcp` or Chrome, refer to https://github.com/ChromeDevTools/chrome-devtools-mcp/blob/main/docs/troubleshooting.md.
