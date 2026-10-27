#!/usr/bin/env python3
"""S3-MF-Incidents-apply.py -- append an approved incident batch to registries/incidents.json.

Intent: apply the S3-MF-Incidents draft batch (#146 onward) to the incident
registry once the commander approves it. Validates the batch (required fields,
enums, non-empty affected, sequential ids that start at the registry max + 1),
refuses to reformat the registry (byte-for-byte round-trip guard), appends the
entries to the "incidents" array, sets meta.lastUpdated, and re-validates the
written file. Idempotent: a batch whose ids are all present with identical
content is a no-op (exit 0); a partial or differing overlap is an error.

Dry run by default; --write writes. Exit 0 ok / no-op, 1 validation error,
2 usage error. Platform: any (python3 stdlib only). Run with python3 -I.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REQUIRED = [
    "id", "title", "status", "severity", "affected", "linked", "referenceFile",
    "observation", "expected", "impact", "discoveryContext", "discipline",
    "frameworks", "suggestedResolution", "rootCause", "correctiveAction",
    "preventionLayer", "created", "updated",
]
STATUS = {"open", "planned", "closed"}
SEVERITY = {"critical", "high", "medium", "low"}
TEXT_REQUIRED = ["title", "observation", "expected", "impact", "discoveryContext", "suggestedResolution"]


def dump(data: object) -> str:
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def all_ids(reg: dict) -> list[int]:
    return [e["id"] for e in reg.get("incidents", [])] + [e["id"] for e in reg.get("closed", [])]


def check_entry(e: dict) -> list[str]:
    errs: list[str] = []
    missing = [k for k in REQUIRED if k not in e]
    extra = [k for k in e if k not in REQUIRED]
    if missing:
        errs.append(f"#{e.get('id')}: missing fields {missing}")
    if extra:
        errs.append(f"#{e.get('id')}: unknown fields {extra}")
    if e.get("status") not in STATUS:
        errs.append(f"#{e.get('id')}: bad status {e.get('status')!r}")
    if e.get("severity") not in SEVERITY:
        errs.append(f"#{e.get('id')}: bad severity {e.get('severity')!r}")
    if not isinstance(e.get("affected"), list) or not e.get("affected"):
        errs.append(f"#{e.get('id')}: affected must be a non-empty list")
    for k in TEXT_REQUIRED:
        if not isinstance(e.get(k), str) or not e.get(k, "").strip():
            errs.append(f"#{e.get('id')}: {k} must be non-empty text")
    if not isinstance(e.get("id"), int):
        errs.append(f"id {e.get('id')!r} is not an integer")
    return errs


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--registry", required=True, help="path to registries/incidents.json")
    ap.add_argument("--batch", required=True, help="path to S3-MF-Incidents-batch.json")
    ap.add_argument("--date", default=None, help="meta.lastUpdated value (default: newest 'updated' in the batch)")
    ap.add_argument("--write", action="store_true", help="write the registry (default: dry run)")
    a = ap.parse_args()

    reg_path, batch_path = Path(a.registry), Path(a.batch)
    try:
        reg_text = reg_path.read_text(encoding="utf-8")
        reg = json.loads(reg_text)
        batch = json.loads(batch_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"error: cannot read input: {exc}", file=sys.stderr)
        return 1
    if not isinstance(batch, list) or not batch:
        print("error: batch must be a non-empty JSON array", file=sys.stderr)
        return 1
    if dump(reg) != reg_text:
        print("error: registry does not round-trip byte for byte (indent 2, UTF-8); refusing to reformat it", file=sys.stderr)
        return 1

    errs = [m for e in batch for m in check_entry(e)]
    if errs:
        for m in errs:
            print(f"error: {m}", file=sys.stderr)
        return 1

    existing = {e["id"]: e for e in reg["incidents"]}
    present = [e for e in batch if e["id"] in existing or e["id"] in {c["id"] for c in reg["closed"]}]
    if present:
        if len(present) == len(batch) and all(existing.get(e["id"]) == e for e in batch):
            print(f"no-op: all {len(batch)} batch ids already present with identical content")
            return 0
        print(f"error: {len(present)} of {len(batch)} batch ids already in the registry with different content or a partial overlap: {[e['id'] for e in present]}", file=sys.stderr)
        return 1

    ids = all_ids(reg)
    if len(ids) != len(set(ids)):
        print("error: registry already has duplicate ids", file=sys.stderr)
        return 1
    start = max(ids) + 1
    want = list(range(start, start + len(batch)))
    got = [e["id"] for e in batch]
    if got != want:
        print(f"error: batch ids {got[0]}..{got[-1]} are not sequential from registry max + 1 ({start})", file=sys.stderr)
        return 1

    reg["incidents"].extend(batch)
    reg["meta"]["lastUpdated"] = a.date or max(e["updated"] for e in batch)
    out = dump(reg)
    check = json.loads(out)
    ids2 = all_ids(check)
    ok = len(ids2) == len(set(ids2)) and max(ids2) == want[-1]
    if not ok:
        print("error: post-apply validation failed (duplicate ids or wrong max)", file=sys.stderr)
        return 1

    summary = (f"ids {want[0]}-{want[-1]} ({len(batch)} entries); registry after: "
               f"{len(check['incidents'])} incidents, {len(check['closed'])} closed, max {max(ids2)}, "
               f"unique {len(ids2) == len(set(ids2))}, lastUpdated {check['meta']['lastUpdated']}")
    if not a.write:
        print(f"dry run ok: would append {summary}")
        return 0
    tmp = reg_path.with_suffix(reg_path.suffix + ".tmp")
    try:
        tmp.write_text(out, encoding="utf-8")
        json.loads(tmp.read_text(encoding="utf-8"))
        tmp.replace(reg_path)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"error: write failed, registry left untouched: {exc}", file=sys.stderr)
        if tmp.exists():
            tmp.unlink()
        return 1
    print(f"written: appended {summary}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
