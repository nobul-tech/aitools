#!/usr/bin/env python3
"""Extract human and key assistant messages from the 40-agent session transcript.
Produces a readable conversation log, working backwards from the end."""
import json
import sys

transcript = "/Users/pepe/.claude/projects/-Users-pepe-repos-aitools/e059186f-45b2-461b-a4ba-e33cd23f9ee1.jsonl"
output = "/Users/pepe/repos/aitools/.scratch/session-5HyCwPtSDH/40agent-conversation.md"

messages = []
with open(transcript, 'r') as f:
    for lineno, line in enumerate(f, 1):
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue

        msg_type = obj.get("type")
        is_sidechain = obj.get("isSidechain", False)

        # Skip subagent messages (sidechains) — we want the main conversation
        if is_sidechain:
            continue

        if msg_type == "human":
            content = obj.get("message", {}).get("content", [])
            if isinstance(content, list):
                for block in content:
                    if isinstance(block, dict) and block.get("type") == "text":
                        text = block.get("text", "").strip()
                        if len(text) > 10:
                            ts = obj.get("timestamp", "")
                            messages.append(f"## [HUMAN] L{lineno} ({ts})\n\n{text}\n")

        elif msg_type == "assistant":
            content = obj.get("message", {}).get("content", [])
            if isinstance(content, list):
                texts = []
                tool_calls = []
                for block in content:
                    if isinstance(block, dict):
                        if block.get("type") == "text":
                            t = block.get("text", "").strip()
                            if len(t) > 20:
                                texts.append(t)
                        elif block.get("type") == "tool_use":
                            name = block.get("name", "")
                            inp = block.get("input", {})
                            if name == "Agent":
                                desc = inp.get("description", "")
                                prompt_preview = inp.get("prompt", "")[:300]
                                tool_calls.append(f"  **Agent**: {desc}\n  Prompt: {prompt_preview}...")
                            elif name in ("Write", "Edit"):
                                path = inp.get("file_path", "")
                                tool_calls.append(f"  **{name}**: {path}")
                            else:
                                desc = inp.get("description", inp.get("command", "")[:100] if isinstance(inp.get("command"), str) else "")
                                tool_calls.append(f"  **{name}**: {desc}")

                if texts or tool_calls:
                    ts = obj.get("timestamp", "")
                    entry = f"## [ASSISTANT] L{lineno} ({ts})\n\n"
                    if texts:
                        # Truncate very long text blocks
                        for t in texts:
                            entry += (t[:2000] + "...[truncated]" if len(t) > 2000 else t) + "\n\n"
                    if tool_calls:
                        entry += "**Tool calls:**\n" + "\n".join(tool_calls) + "\n"
                    messages.append(entry)

with open(output, 'w') as f:
    f.write(f"# Session Z1IhGrcgGO Conversation Extract\n\n")
    f.write(f"Extracted {len(messages)} main-thread messages (subagent sidechains excluded)\n\n---\n\n")
    for msg in messages:
        f.write(msg + "\n---\n\n")

print(f"Extracted {len(messages)} messages to {output}")
