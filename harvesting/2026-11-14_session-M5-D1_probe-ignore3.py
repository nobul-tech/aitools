"""Probe: wrap git_ignored() inside scan() to print its exact input and output."""
import importlib.util
import sys
from pathlib import Path

root = Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("cpr", root / "scripts" / "check-path-refs.py")
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
orig = mod.git_ignored


def wrapped(r, paths):
    out = orig(r, paths)
    print("git_ignored input:", [repr(p) for p in paths])
    print("git_ignored output:", out)
    return out


mod.git_ignored = wrapped
print("scan:", mod.scan(root))
