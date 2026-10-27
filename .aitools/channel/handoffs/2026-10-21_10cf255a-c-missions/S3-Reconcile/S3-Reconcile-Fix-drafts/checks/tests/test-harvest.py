#!/usr/bin/env python3
"""test-harvest.py -- run ait-harvest.py catchup (original and patched) on a
fake repo under a temp HOME and report what was harvested.

Usage: python3 test-harvest.py <ait-harvest.py> [<ait-harvest.py> ...]
Fixture: own live session dir (pointer target), a long-named delegate dir
(old mtime), a recent delegate dir (live), each with bookkeeping/staging files.
"""
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

OWN_SID = "abcdefghij-1111-2222"
FILES = ["notes.md", "probe.sh", "msg-fix.txt", "pr-body.md", "events.jsonl",
         ".intelligence-last-check", "commit-msg.txt", "build.log"]


def build(base: Path) -> tuple[Path, Path]:
    home = base / "home"
    repo = base / "repo"
    (home / ".aitools").mkdir(parents=True)
    repo.mkdir()
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    sc = repo / ".scratch"
    old = time.time() - 3 * 3600
    dirs = [("session-abcdefghij", None), ("session-reconcile-fix", old),
            ("session-live", None), ("session-short", old)]
    if os.environ.get("ONLY_LONG"):
        dirs = dirs[:2]
    for name, age in dirs:
        d = sc / name
        d.mkdir(parents=True)
        for f in FILES:
            (d / f).write_text(f"{name}/{f}\n")
            if age:
                os.utime(d / f, (age, age))
        if age:
            os.utime(d, (age, age))
    (sc / ".current-session").write_text(str(sc / "session-abcdefghij"))
    return home, repo


def run(script: str) -> None:
    with tempfile.TemporaryDirectory() as t:
        base = Path(t)
        home, repo = build(base)
        env = dict(os.environ, HOME=str(home))
        env.pop("AITOOLS_DEPLOY_IN_PROGRESS", None)
        p = subprocess.run([sys.executable, script, "catchup", "--session", OWN_SID,
                            "--cwd", str(repo)], env=env, stdin=subprocess.DEVNULL,
                           capture_output=True, text=True)
        print(f"=== {script}\n rc={p.returncode} stderr={p.stderr.strip()!r}")
        hv = sorted(x.name for x in (repo / "harvesting").glob("*")) if (repo / "harvesting").is_dir() else []
        print(" harvested:", [h for h in hv if h != "harvest-manifest.json"])
        for d in sorted((repo / ".scratch").iterdir()):
            if d.is_dir():
                print(f" {d.name}: .harvested={'yes' if (d / '.harvested').exists() else 'no'}")
        print(" .current-session present:", (repo / ".scratch" / ".current-session").exists())
        log = home / ".aitools" / "logs" / "ait-harvest.log"
        if log.exists():
            for ln in log.read_text().splitlines():
                print("  log|", ln.split("] ", 2)[-1])


for s in sys.argv[1:]:
    run(s)
