"""Check a mission brief against RFC 0011 v1.2 (3.1 to 3.3, 3.2.6, 3.3.3a, 3.7.2).

Usage: check-brief-schema.py <brief.json>
Prints each problem; exits 1 if any.
"""
import json
import os
import re
import sys

b = json.load(open(sys.argv[1], encoding="utf-8"))
problems = []


def bad(msg):
    problems.append(msg)


KEYS = ["provenance", "identity", "intent", "objectives", "constraints", "assumptions", "decisions",
        "operational_learning", "artifacts", "deliverables"]
if list(b) != KEYS:
    bad(f"top-level keys {list(b)} != {KEYS}")
FORBIDDEN = {"facts", "report_at_once_if", "meta", "findings", "conflict_priority", "permissions", "rules",
             "skills", "ambiguities", "access", "name_prefix", "duties", "return"}


def walk(node, path):
    if isinstance(node, dict):
        for k, v in node.items():
            if path == "" and k in FORBIDDEN:
                bad(f"forbidden node {k}")
            walk(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            walk(v, f"{path}[{i}]")
    elif isinstance(node, str) and "```" in node:
        bad(f"three backticks in {path}")


walk(b, "")

p = b.get("provenance", {})
for k in ("document", "schema_version", "version", "mission", "session_id", "session_db", "session_scratch",
          "written_by", "chain_of_command", "created_at"):
    if k not in p:
        bad(f"provenance.{k} missing")
if p.get("document") != "mission-brief":
    bad("provenance.document")
if not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", p.get("created_at", "")):
    bad("provenance.created_at not UTC Z")
if os.path.basename(sys.argv[1]) != f"{p.get('mission')}-brief.json":
    bad("file name does not match <mission name>-brief.json")

TYPE_IDS = {"objective": r"OBJ-\d+", "assumption": r"ASM-\d+", "decision": r"D[0-9a-f]{4}-\d+",
            "operational_learning": r"OL-\d+"}
ITEM_NODES = {"objectives": "objective", "assumptions": "assumption", "decisions": "decision",
              "operational_learning": "operational_learning"}
SRC_KINDS = {"commander", "agent", "telemetry", "artifact", "web"}
for node, typ in ITEM_NODES.items():
    seen = set()
    for it in b.get(node, []):
        ident = it.get("id", "?")
        for k in ("id", "type", "text", "source"):
            if k not in it:
                bad(f"{node} {ident}: {k} missing")
        if it.get("type") != typ:
            bad(f"{node} {ident}: type {it.get('type')}")
        if not re.fullmatch(TYPE_IDS[typ], ident):
            bad(f"{node} {ident}: id pattern")
        if ident in seen:
            bad(f"{node} {ident}: duplicate id")
        seen.add(ident)
        s = it.get("source", {})
        if s.get("kind") not in SRC_KINDS or not s.get("location"):
            bad(f"{node} {ident}: source")
        if s.get("kind") == "commander" and not it.get("quote"):
            bad(f"{node} {ident}: commander source with no quote")
        if typ == "assumption":
            if it.get("status") not in ("unverified", "verified", "falsified"):
                bad(f"{ident}: status")
            if it.get("confidence") not in ("low", "moderate", "high"):
                bad(f"{ident}: confidence")
            if it.get("status") in ("verified", "falsified") and not it.get("ref"):
                bad(f"{ident}: settled with no ref")
            if not it.get("impact_if_false"):
                bad(f"{ident}: impact_if_false empty")
        if typ == "decision":
            if it.get("status") not in ("decided", "implemented", "verified", "deferred", "reversed", "superseded"):
                bad(f"{ident}: status")
            for sb in it.get("superseded_by", []):
                if set(sb) != {"decision", "part"}:
                    bad(f"{ident}: superseded_by entry {sb}")

for i, c in enumerate(b.get("constraints", [])):
    if set(c) != {"text", "source"}:
        bad(f"constraints[{i}] keys {list(c)}")

for i, a in enumerate(b.get("artifacts", [])):
    if set(a) != {"path", "instruction"}:
        bad(f"artifacts[{i}] keys {list(a)}")
    if not os.path.isabs(a.get("path", "")):
        bad(f"artifacts[{i}] path not absolute")
    elif not os.path.isfile(a["path"]):
        bad(f"artifacts[{i}] missing file {a['path']}")
    if a.get("instruction") not in ("read in full", "use as reference for answers"):
        bad(f"artifacts[{i}] instruction {a.get('instruction')!r}")
    if a.get("path", "").startswith(os.path.expanduser("~/repos/aitools/registries/")):
        bad(f"artifacts[{i}] lists a governed registry JSON")

obj_ids = {o["id"] for o in b.get("objectives", [])}
aar = 0
for i, d in enumerate(b.get("deliverables", [])):
    if set(d) != {"kind", "ref", "objective", "text"}:
        bad(f"deliverables[{i}] keys {list(d)}")
    if d.get("kind") not in ("aar", "pr", "issue", "commit", "file"):
        bad(f"deliverables[{i}] kind")
    want = {""} if d.get("kind") == "aar" else obj_ids  # RFC 0011 v1.4 3.2.6: "" for the AAR
    if d.get("objective") not in want:
        bad(f"deliverables[{i}] objective {d.get('objective')!r}")
    aar += d.get("kind") == "aar"
if aar != 1:
    bad(f"{aar} AAR deliverables (need exactly 1)")

for m in problems:
    print("PROBLEM", m)
print(f"{len(b.get('artifacts', []))} artifacts, {len(b.get('decisions', []))} decisions; {len(problems)} problems")
sys.exit(1 if problems else 0)
