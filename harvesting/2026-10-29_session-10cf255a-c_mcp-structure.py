"""Print MCP config structure (server names, keys) without values, so no secret is shown."""
import json
import os
import sys
from typing import Any

PATHS = [
    "/Users/new-jose/repos/aitools/.mcp.json",
    "/Users/new-jose/repos/aitools/.cursor/mcp.json",
    os.path.expanduser("~/.claude.json"),
    os.path.expanduser("~/.cursor/mcp.json"),
]


def main() -> int:
    for p in PATHS:
        if not os.path.exists(p):
            print(f"{p}: absent")
            continue
        try:
            with open(p, encoding="utf-8") as f:
                d: Any = json.load(f)
        except Exception as e:  # report and continue
            print(f"{p}: unreadable ({e})")
            continue
        servers = d.get("mcpServers", {}) if isinstance(d, dict) else {}
        fc = [k for k in servers if "firecrawl" in k.lower()]
        print(f"{p}: top-level servers={sorted(servers)} firecrawl={fc}")
        if isinstance(d, dict) and isinstance(d.get("projects"), dict):
            for proj, cfg in d["projects"].items():
                ps = cfg.get("mcpServers", {}) if isinstance(cfg, dict) else {}
                pf = [k for k in ps if "firecrawl" in k.lower()]
                if pf:
                    print(f"  project {proj}: firecrawl servers={pf}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
