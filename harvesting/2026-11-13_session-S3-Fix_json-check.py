#!/usr/bin/env python3
"""Parse each JSON file given on the command line; print OK or the error."""
import json
import sys

rc = 0
for path in sys.argv[1:]:
    try:
        with open(path, encoding="utf-8") as fh:
            json.load(fh)
        print(f"OK   {path}")
    except Exception as exc:  # report every failure, never swallow
        print(f"FAIL {path}: {exc}")
        rc = 1
sys.exit(rc)
