"""Probe: why check-path-refs.py git_ignored() misses gitignored paths on Windows."""
import subprocess
import sys

root = sys.argv[1]
paths = [".claude/rules/relay-outbound.md", ".claude/settings.local.json", ".cursor/mcp.json"]
for label, kwargs in (("text", {"text": True, "input": "\n".join(paths)}),
                      ("bytes", {"input": ("\n".join(paths) + "\n").encode()})):
    proc = subprocess.run(["git", "-C", root, "check-ignore", "--no-index", "--stdin"],
                          capture_output=True, check=False, **kwargs)
    print(label, "rc=", proc.returncode, "stdout=", repr(proc.stdout), "stderr=", repr(proc.stderr))
for p in paths:
    proc = subprocess.run(["git", "-C", root, "check-ignore", "--no-index", p],
                          capture_output=True, text=True, check=False)
    print("single", p, "rc=", proc.returncode, repr(proc.stdout))
