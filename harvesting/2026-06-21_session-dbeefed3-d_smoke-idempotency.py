#!/usr/bin/env python3
"""Verify a new orphaned scratch dir harvests ONCE, then self-skips.

Builds an isolated temp project root so the real harvesting/ is untouched."""
import importlib.util
import tempfile
import time
from pathlib import Path

REPO = Path("/Users/new-jose/repos/aitools")
spec = importlib.util.spec_from_file_location(
    "aith", REPO / "scripts" / "ait-harvest.py")
aith = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aith)

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    sess = "abc1234567"
    sdir = root / ".scratch" / f"session-{sess}"
    sdir.mkdir(parents=True)
    (sdir / "useful-tool.sh").write_text("#!/usr/bin/env bash\necho hi\n")
    (sdir / "build.log").write_text("ephemeral\n")  # should be skipped

    deadline = time.monotonic() + 10.0

    # Run 1: expect 1 harvested, marker written.
    r1, _ = aith._catchup_harvest(str(root), None, deadline)
    marker = (sdir / ".harvested").exists()
    hv1 = sorted(p.name for p in (root / "harvesting").iterdir()
                 if p.name != "harvest-manifest.json")

    # Run 2: expect 0 (dir now marked), no new copies.
    r2, _ = aith._catchup_harvest(str(root), None, deadline)
    hv2 = sorted(p.name for p in (root / "harvesting").iterdir()
                 if p.name != "harvest-manifest.json")

    print(f"run1 recovered={r1} (want 1)   marker written={marker} (want True)")
    print(f"run1 harvesting files: {hv1}")
    print(f"run2 recovered={r2} (want 0)")
    print(f"run2 harvesting files: {hv2}")
    ok = (r1 == 1 and marker and r2 == 0 and hv1 == hv2 and len(hv1) == 1)
    print("PASS" if ok else "FAIL")
