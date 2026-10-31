#!/usr/bin/env python3
"""Run grep-prompts.py over archive files whose names sort >= --since.

usage: grep-archive.py --dir DIR --since 2026-03-14 --grep RX [--ctx N] [--max N]
Skips *_subagent-*.jsonl files (agent text, not commander words).
"""
import argparse
import os
import subprocess
import sys


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--dir", required=True)
    ap.add_argument("--since", required=True)
    ap.add_argument("--grep", required=True)
    ap.add_argument("--ctx", default="800")
    ap.add_argument("--max", default="2000")
    a = ap.parse_args()
    files = sorted(
        os.path.join(a.dir, f) for f in os.listdir(a.dir)
        if f.endswith(".jsonl") and "_subagent-" not in f and f >= a.since
    )
    if not files:
        print("no files", file=sys.stderr)
        return 1
    here = os.path.dirname(os.path.abspath(__file__))
    cmd = [sys.executable, os.path.join(here, "grep-prompts.py"), "--grep", a.grep,
           "--ctx", a.ctx, "--max", a.max] + files
    return subprocess.call(cmd)


if __name__ == "__main__":
    sys.exit(main())
