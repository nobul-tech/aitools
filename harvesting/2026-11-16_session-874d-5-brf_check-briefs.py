#!/usr/bin/env python3
"""Independent structural and quote check of the mission briefs of session dbd05b0c.

Usage: check-briefs.py
Reads the briefs, RFC 0011 rules (hard-coded from sections 3.1-3.3), the
extracted prompts, the issue JSON and the plan; prints one line per finding.
"""
import json
import os
import re
import sys

SCR = "/Users/new-jose/repos/aitools/.scratch/session-dbd05b0c-2365-4159-9976-bc64a2af874d"
MINE = "/Users/new-jose/repos/aitools/.scratch/session-874d-5-brf"
PLAN = "/Users/new-jose/repos/aitools/plans/structured-reports/implementation-plan.md"
ARCHIVE = "/Users/new-jose/repos/aitools-nobul-jose/sessions/aitools/2026-03-16_79b05dd0.jsonl"
BRIEFS = [
    "874d-2-structured-reports-brief.json",
    "874d-3-spec-verify-brief.json",
    "874d-4-adversarial-brief.json",
    "874d-5-brief-verify-brief.json",
    "874d-6-standards-verify-brief.json",
]
KEYS = ["provenance", "identity", "intent", "objectives", "constraints", "assumptions",
        "decisions", "ambiguities", "operational_learning", "rules", "skills", "access",
        "name_prefix", "duties", "return"]
FORBIDDEN = {"facts", "report_at_once_if", "meta", "findings", "conflict_priority", "permissions"}
NODE_TYPE = {"objectives": "objective", "assumptions": "assumption", "decisions": "decision",
             "ambiguities": "ambiguity", "operational_learning": "operational_learning"}
SRC_KINDS = {"commander", "agent", "telemetry", "artifact", "web"}
TYPE_FIELDS = {
    "objective": {"required": ["id", "type", "text", "source"]},
    "assumption": {"required": ["id", "type", "text", "status", "confidence", "evidence",
                                "impact_if_false", "source"],
                   "enums": {"status": {"unverified", "verified", "falsified"},
                             "confidence": {"low", "moderate", "high"}}},
    "decision": {"required": ["id", "type", "text", "decided_by", "date", "quote", "status", "source"],
                 "enums": {"status": {"decided", "implemented", "verified", "deferred", "reversed"}}},
    "ambiguity": {"required": ["id", "type", "text", "source", "readings", "resolution",
                               "resolved_by", "evidence", "status"],
                  "enums": {"status": {"resolved", "open"},
                            "resolved_by": {"reason", "read", "test", "delegate", "rfi", "assumption"}}},
    "operational_learning": {"required": ["id", "type", "text", "source"]},
}
ID_PREFIX = {"objective": "OBJ-", "assumption": "ASM-", "ambiguity": "AMB-",
             "operational_learning": "OL-", "decision": "D"}


def norm(s: str) -> str:
    return s


def walk_keys(obj, path=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield path + "." + k, k
            yield from walk_keys(v, path + "." + k)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from walk_keys(v, "%s[%d]" % (path, i))


def load_sources():
    prompts = json.load(open(os.path.join(MINE, "prompts.json"), encoding="utf-8"))
    issue = json.load(open(os.path.join(MINE, "issue180.json"), encoding="utf-8"))
    corpus = {"issue-body": issue["body"]}
    for i, c in enumerate(issue["comments"]):
        corpus["issue-comment-%d" % i] = c["body"]
    for ln, t in prompts.items():
        corpus["dbd05b0c L%s" % ln] = t
    if os.path.exists(ARCHIVE):
        with open(ARCHIVE, encoding="utf-8") as fh:
            for n, line in enumerate(fh, 1):
                if n == 419:
                    try:
                        rec = json.loads(line)
                        c = rec.get("message", {}).get("content")
                        if isinstance(c, list):
                            c = "\n".join(b.get("text", "") for b in c if isinstance(b, dict))
                        corpus["79b05dd0 L419"] = c or ""
                    except json.JSONDecodeError:
                        corpus["79b05dd0 L419"] = ""
    return corpus


def where(q, corpus):
    return [k for k, t in corpus.items() if q in t]


def main() -> int:
    corpus = load_sources()
    plan = open(PLAN, encoding="utf-8").read()
    headings = re.findall(r"^## (WP-\d: .*)$", plan, re.M)
    for name in BRIEFS:
        p = os.path.join(SCR, name)
        print("=" * 70)
        print(name)
        try:
            b = json.load(open(p, encoding="utf-8"))
        except json.JSONDecodeError as e:
            print("  INVALID JSON", e)
            continue
        keys = list(b.keys())
        print("  keys order ok:", keys == KEYS, "" if keys == KEYS else keys)
        for path, k in walk_keys(b):
            if k in FORBIDDEN:
                print("  FORBIDDEN node", path)
        prov = b["provenance"]
        for f in ["document", "schema_version", "version", "mission", "session_id", "session_db",
                  "session_scratch", "written_by", "chain_of_command", "created_at"]:
            if f not in prov:
                print("  provenance missing", f)
        if prov.get("document") != "mission-brief":
            print("  provenance.document", prov.get("document"))
        mission = prov.get("mission")
        exp = os.path.join(prov.get("session_scratch", ""), mission + "-brief.json")
        print("  D874d-42 path ok:", os.path.abspath(exp) == os.path.abspath(p))
        print("  name_prefix ok:", b.get("name_prefix") == mission + "-",
              " identity.name ok:", b["identity"].get("name") == mission)
        if not re.match(r"^[0-9a-f]{4}-\d+-[A-Za-z0-9-]+$", mission):
            print("  mission name pattern FAIL", mission)
        for k in ["name", "level", "delegated_by", "parallel_missions"]:
            if k not in b["identity"]:
                print("  identity missing", k)
        for k in ["purpose", "scope", "out_of_scope", "audience"]:
            if k not in b["intent"]:
                print("  intent missing", k)
        for k in ["read_only", "writable", "scratch"]:
            if k not in b["access"]:
                print("  access missing", k)
        for k in ["hand_back", "file"]:
            if k not in b["return"]:
                print("  return missing", k)
        if b["skills"][0].get("name") != "/delegate":
            print("  skills[0] is not /delegate")
        for s in b["skills"]:
            for k in ["name", "use", "override"]:
                if k not in s:
                    print("  skill missing", k, s)
        for c in b["constraints"]:
            if set(c) - {"text", "source"} or "source" not in c:
                print("  constraint fields", sorted(c))
            if c["source"]["kind"] not in SRC_KINDS:
                print("  constraint source.kind", c["source"]["kind"])
        # items
        for node, typ in NODE_TYPE.items():
            ids = []
            for i, it in enumerate(b[node]):
                pth = "%s[%d]" % (node, i)
                if it.get("type") != typ:
                    print("  ", pth, "type", it.get("type"), "expected", typ)
                spec = TYPE_FIELDS[typ]
                for f in spec["required"]:
                    if f not in it:
                        print("  ", pth, it.get("id"), "missing field", f)
                for f, allowed in spec.get("enums", {}).items():
                    if f in it and it[f] not in allowed:
                        print("  ", pth, it.get("id"), "bad enum", f, it[f])
                src = it.get("source", {})
                if src.get("kind") not in SRC_KINDS:
                    print("  ", pth, it.get("id"), "bad source.kind", src.get("kind"))
                if "location" not in src:
                    print("  ", pth, it.get("id"), "missing source.location")
                if src.get("kind") == "commander" and not it.get("quote"):
                    print("  ", pth, it.get("id"), "commander source without quote")
                if not str(it.get("id", "")).startswith(ID_PREFIX[typ]):
                    print("  ", pth, "id prefix", it.get("id"))
                ids.append(it.get("id"))
                # quote check
                q = it.get("quote")
                if q:
                    pieces = [x.strip() for x in q.split("…")] if "…" in q else [q]
                    for piece in pieces:
                        w = where(piece, corpus)
                        if not w:
                            print("  QUOTE NOT FOUND", pth, it.get("id"), repr(piece[:90]))
                        else:
                            loc = src.get("location", "")
                            m = re.search(r"L(\d+)", loc)
                            if m and "dbd05b0c" in loc and ("dbd05b0c L" + m.group(1)) not in w:
                                print("  QUOTE line mismatch", pth, it.get("id"), "cited L" + m.group(1), "found", w)
                            if "…" in q:
                                print("  quote joins pieces with ellipsis", pth, it.get("id"), w)
                # quoted text inside location
                for lq in re.findall(r'"((?:[^"\\]|\\.)*?)"', src.get("location", "")):
                    pass
                if typ == "ambiguity":
                    if not where(it["text"], corpus):
                        print("  ambiguity text not verbatim in issue/transcript", it.get("id"), repr(it["text"]))
                    else:
                        print("  ambiguity text found", it.get("id"), where(it["text"], corpus)[:3],
                              "source.kind", src.get("kind"))
            if len(ids) != len(set(ids)):
                print("  duplicate ids in", node)
            print("  ", node, "ids:", ids)
        # objectives vs plan headings
        for it in b["objectives"]:
            if it["source"]["kind"] == "artifact" and "implementation-plan.md" in it["source"]["location"]:
                print("  ", it["id"], "matches plan heading:", it["text"] in headings)
        # paths
        def strip(pth):
            return pth.split(" (")[0].strip()
        for r in b["rules"]:
            if not os.path.exists(r):
                print("  RULES PATH MISSING", r)
        for k in ["read_only", "writable"]:
            for a in b["access"][k]:
                s = strip(a)
                if s.startswith("/") and not os.path.exists(s):
                    print("  ACCESS PATH MISSING (%s)" % k, a)
        if b["access"]["scratch"] and not os.path.exists(b["access"]["scratch"]):
            print("  access.scratch does not exist yet:", b["access"]["scratch"])
        for c in prov["chain_of_command"]:
            if not os.path.exists(c):
                print("  chain_of_command missing", c)
    print("plan headings:", headings)
    return 0


if __name__ == "__main__":
    sys.exit(main())
