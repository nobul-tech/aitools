"""Probe: call check-path-refs.py functions directly and show the git_ignored() input/output."""
import importlib.util
import sys
from pathlib import Path

root = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("cpr", root / "scripts" / "check-path-refs.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
paths = [".claude/rules/relay-outbound.md", ".claude/settings.local.json", ".cursor/mcp.json"]
print("git_ignored(sorted paths):", mod.git_ignored(root, paths))
print("git_ignored(mcp only):", mod.git_ignored(root, [".cursor/mcp.json"]))
