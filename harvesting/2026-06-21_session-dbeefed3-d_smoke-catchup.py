#!/usr/bin/env python3
"""Smoke test the new harvest+audit path: timing + idempotency.

Avoids the archive/git-push side effects -- exercises _catchup_harvest (which
should now skip all .harvested dirs) and _audit_manifest (single git pass)."""
import importlib.util
import time
from pathlib import Path

REPO = Path("/Users/new-jose/repos/aitools")
spec = importlib.util.spec_from_file_location(
    "aith", REPO / "scripts" / "ait-harvest.py")
aith = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aith)

harvest_before = len(list((REPO / "harvesting").iterdir()))

# 1. harvest sweep -- every scratch dir is marked .harvested, so expect 0 work.
deadline = time.monotonic() + 10.0
t0 = time.monotonic()
recovered, project_root = aith._catchup_harvest(
    str(REPO), "deadbeef00-fake", deadline)
t_harvest = time.monotonic() - t0

# 2. audit -- single git pass over past-due artifacts.
t0 = time.monotonic()
hv = REPO / "harvesting"
aith._audit_manifest(hv / "harvest-manifest.json", hv, REPO, deadline)
t_audit = time.monotonic() - t0

harvest_after = len(list((REPO / "harvesting").iterdir()))

print(f"_catchup_harvest: recovered={recovered}  time={t_harvest*1000:.0f}ms")
print(f"_audit_manifest:  time={t_audit*1000:.0f}ms")
print(f"harvesting/ file count: {harvest_before} -> {harvest_after} "
      f"(delta {harvest_after - harvest_before}, want 0 new copies)")
print("PASS" if recovered == 0 and harvest_after == harvest_before else "CHECK")
