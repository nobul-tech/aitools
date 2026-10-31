"""Run check-path-refs.py's candidate/exists logic on one file against the repo root (scratch)."""
import importlib.util
import sys
from pathlib import Path

root = Path("/Users/new-jose/repos/aitools")
spec = importlib.util.spec_from_file_location("cpr", root / "scripts/check-path-refs.py")
cpr = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cpr)
f = Path(sys.argv[1])
dead = 0
for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
    if cpr.IGNORE_MARKER in line:
        continue
    for tok in cpr.BACKTICK.findall(line) + cpr.AT_PATH.findall(line):
        c = cpr.candidate(tok)
        if c and not cpr.exists(root, c):
            print(f"{n}: {c}")
            dead += 1
print(f"dead path references: {dead}")
sys.exit(1 if dead else 0)
