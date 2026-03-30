# CC Context Tracking + Python Hooks — Evaluation

**Session**: 8a9efdbb-0ecc-4905-b09a-6799dd66f2ee
**Date**: 2026-03-29

## Question 1: Can we check context use at each agentic turn?

### Answer: Yes, two mechanisms

**Mechanism A — JSONL transcript parsing (available in ANY hook)**

Every `type: "assistant"` JSONL entry has a `message.usage` object:

```json
{
  "input_tokens": 3,
  "cache_creation_input_tokens": 30689,
  "cache_read_input_tokens": 11216,
  "cache_creation": {
    "ephemeral_5m_input_tokens": 0,
    "ephemeral_1h_input_tokens": 30689
  },
  "output_tokens": 38,
  "service_tier": "standard"
}
```

A Stop hook can: read last line of `transcript_path` → extract usage → compute
`input_tokens + cache_creation_input_tokens + cache_read_input_tokens` as
context consumption. Divide by known model limit (200K Sonnet, 1M Opus) for %.

**Mechanism B — Statusline command (separate from hooks)**

The `statusLine` setting in settings.json receives rich JSON including:

```json
{
  "context_window": {
    "total_input_tokens": 15234,
    "total_output_tokens": 4521,
    "context_window_size": 200000,
    "used_percentage": 8,
    "remaining_percentage": 92,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  }
}
```

This is the ONLY place CC provides `context_window_size` and pre-calculated
`used_percentage`. But statusline is a display mechanism, not a hook — it
cannot block or inject feedback.

### What's NOT available

- No token data in hook stdin JSON (none of the 12+ hook event types include usage)
- No `CLAUDE_CODE_CONTEXT_USED` environment variable
- No `context_window_size` in JSONL (must infer from model name)
- No thinking token breakout (thinking included in output_tokens)
- No cumulative session totals in JSONL (per-turn only)
- No way to detect if auto-compact has happened (resets effective context)

### Practical approach for a Stop hook

```python
import json, sys

input_data = json.load(sys.stdin)
transcript = input_data.get("transcript_path", "")

# Read last assistant entry from JSONL
last_usage = None
with open(transcript) as f:
    for line in f:
        try:
            entry = json.loads(line)
            if entry.get("type") == "assistant" and "message" in entry:
                usage = entry["message"].get("usage")
                if usage:
                    last_usage = usage
        except:
            continue

if last_usage:
    context_used = (
        last_usage.get("input_tokens", 0) +
        last_usage.get("cache_creation_input_tokens", 0) +
        last_usage.get("cache_read_input_tokens", 0)
    )
    # Opus 4.6 1M context
    pct = round(context_used / 1_000_000 * 100, 1)
    if pct > 70:
        print(f"CONTEXT WARNING: {pct}% used ({context_used:,} tokens)", file=sys.stderr)
```

### Upstream requests (all closed/stale)

| Issue | Title | Status |
|-------|-------|--------|
| #26340 | Token usage summary for Claude | Closed (dup of #20642) |
| #20642 | Runtime token usage visibility | Closed (stale) |
| #18027 | Native context visibility for self-regulating workflows | Open (stale) |
| #11535 | Expose token usage to statusline scripts | Partially resolved |
| #28999 | Expose /usage quota in statusLine JSON | Open |

---

## Question 2: Can we launch Python scripts from hooks?

### Answer: Yes, fully supported

CC hooks execute via `spawn('/bin/sh', ['-c', command])`. The `command` field
is a shell string. Any command works: `python3 /path/to/hook.py`.

**Anthropic provides an official Python hook example:**
`examples/hooks/bash_command_validator_example.py` in the claude-code repo.

Configuration:
```json
{
  "type": "command",
  "command": "python3 /Users/pepe/.claude/hooks/my-hook.py",
  "timeout": 30
}
```

### Protocol (identical for Python and bash)

| Channel | Purpose |
|---------|---------|
| stdin | JSON from CC (session_id, tool_name, tool_input, etc.) |
| stdout | JSON output (parsed on exit 0 only) |
| stderr | Feedback to agent (on exit 2) or logging (other exits) |
| exit 0 | Allow / success |
| exit 2 | Block — stderr fed back to Claude |
| other | Proceed, stderr logged |

### Timeout defaults

- Command hooks: 600s (10 min)
- Prompt hooks: 30s
- Agent hooks: 60s
- All configurable per-hook via `timeout` field

### Gotchas

1. **Shell profile pollution** — CC sources ~/.zshrc before running hooks.
   If profile prints to stdout, it breaks JSON parsing. Guard with
   `if [[ $- == *i* ]]; then`.
2. **No shebang exec** — Can't use `#!/usr/bin/env python3` as the command
   directly. Must be `python3 /path/to/script.py`.
3. **CWD may be invalid** — If working directory was deleted mid-session,
   hook spawning fails with ENOENT (#29260).
4. **stdout must be clean JSON** — Only JSON on stdout. Debug via stderr.

### Existing aitools pattern

Already using bash-wraps-Python in 6 hooks (harness-db-*.sh, harvest-session.sh,
session-archive.sh, scratch-init.sh). These detect Python availability:

```bash
if command -v python3 > /dev/null 2>&1; then
    python3 "$SCRIPT_DIR/harness-db.py" "$@"
fi
```

No barrier to using `python3` directly in the command field — it's just that
the aitools pattern chose bash wrappers for portability (Windows Git Bash
may not have Python on PATH).

---

## Combined opportunity

A Python Stop hook that does BOTH turn tracking AND context monitoring:

1. Read transcript_path from stdin JSON
2. Parse JSONL: count turns since last human message
3. Extract last usage object: compute context %
4. Inject steering via stderr when thresholds hit
5. Write metrics to harness-db SQLite for KPI tracking

Python makes this much cleaner than bash+perl — native JSON parsing,
SQLite via stdlib, proper error handling. The intent-sentinel-stop.sh
(currently bash+perl in harvesting/) is the natural candidate to rewrite.
