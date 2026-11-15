"""Test: check-path-refs.py filters every gitignored path (not only the last) and still reports dead ones.

Builds a temp git repo under this scratch dir with CLAUDE.md citing two ignored
paths and one dead path; expects exactly the dead path, exit 1.
"""
import shutil
import subprocess
import sys
from pathlib import Path

wt = Path(sys.argv[1])
tmp = Path(__file__).resolve().parent / "pathrefs-fixture"
if tmp.exists():
    shutil.rmtree(tmp)
(tmp / "scripts").mkdir(parents=True)
shutil.copy(wt / "scripts" / "check-path-refs.py", tmp / "scripts" / "check-path-refs.py")
subprocess.run(["git", "init", "-q", str(tmp)], check=True)
(tmp / ".gitignore").write_text(".claude/settings.local.json\n.cursor/mcp.json\n", encoding="utf-8")
(tmp / "CLAUDE.md").write_text(
    "a `.claude/settings.local.json` b\nc `.cursor/mcp.json` d\ne `.claude/rules/gone.md` f\n",
    encoding="utf-8",
)
proc = subprocess.run([sys.executable, str(tmp / "scripts" / "check-path-refs.py"), "--root", str(tmp)],
                      capture_output=True, text=True, check=False)
print(proc.stdout, proc.stderr)
ok = proc.returncode == 1 and proc.stdout.strip().splitlines() == [
    "CLAUDE.md:3: .claude/rules/gone.md", "dead path references: 1"]
print("PASS" if ok else f"FAIL (exit {proc.returncode})")
sys.exit(0 if ok else 1)
