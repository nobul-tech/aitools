#!/usr/bin/env python3
"""Render the S3-GateFix review page Markdown from its JSON source.

intent: Keep the review page Markdown identical in content to its JSON source,
with every summary line derived from the JSON, so the session commander can
edit the JSON (or publish it as an Artifact) and regenerate the page. NOT a
general renderer. Consumers: S3-GateFix, the session commander.

Run with -I so no module is imported from the current directory:
    python3 -I S3-GateFix-render-review-page.py <json-path> <md-path>
    python3 -I S3-GateFix-render-review-page.py --check <json-path>
"""
import argparse
import json
import re
import sys
from typing import Any

KINDS = ("question", "context", "row")
REQUIRED = {
    "question": ("id", "section", "question", "options", "recommendation", "why", "blocks", "source"),
    "context": ("id", "section", "title", "text", "source"),
    "row": ("id", "section", "title", "state", "draftedBy", "draftStatus", "options",
            "recommendation", "blocks", "draft"),
}
STATUSES = ("open", "approved", "superseded", "resolved")
ROW_STATES = ("drafted", "text-only", "void", "carved-out")
CHANGED = ("new", "changed")
META_REQUIRED = ("intent", "title", "author", "sections", "answerOrder", "pathKey")
PLACEHOLDER = re.compile(r"<([A-Za-z{][^<>\n]*)>")


def esc(text: str) -> str:
    """Escape <placeholder> outside code spans so Markdown renderers keep it visible."""
    parts = text.split("`")
    for i in range(0, len(parts), 2):
        parts[i] = PLACEHOLDER.sub(r"&lt;\1&gt;", parts[i])
    return "`".join(parts)


def cell(text: str) -> str:
    return esc(text).replace("|", "\\|").replace("\n", " ")


def validate(data: dict[str, Any]) -> list[str]:
    errs: list[str] = []
    meta = data.get("meta", {})
    for k in META_REQUIRED:
        if k not in meta:
            errs.append(f"meta missing {k}")
    sections = meta.get("sections", {})
    for sid, sec in sections.items():
        if not isinstance(sec, dict) or sec.get("kind") not in KINDS or not sec.get("title"):
            errs.append(f"section {sid} needs a title and a kind in {KINDS}")
    seen: set[str] = set()
    for it in data.get("items", []):
        iid = it.get("id", "?")
        kind = it.get("kind")
        if kind not in KINDS:
            errs.append(f"item {iid}: kind {kind!r} not in {KINDS}")
            continue
        missing = [k for k in REQUIRED[kind] if not it.get(k)]
        if missing:
            errs.append(f"item {iid}: missing or empty {missing}")
        sec = sections.get(it.get("section"))
        if sec is None:
            errs.append(f"item {iid}: unknown section {it.get('section')!r}")
        elif kind == "context" and sec["kind"] != "context":
            errs.append(f"item {iid}: context item in a {sec['kind']} section")
        elif kind != "context" and sec["kind"] == "context":
            errs.append(f"item {iid}: {kind} item in the context section")
        if iid in seen:
            errs.append(f"duplicate id {iid}")
        seen.add(iid)
        if kind != "context" and (not isinstance(it.get("options"), list) or not it.get("options")):
            errs.append(f"item {iid}: options must be a non-empty list")
        if it.get("status", "open") not in STATUSES:
            errs.append(f"item {iid}: status {it.get('status')!r} not in {STATUSES}")
        if it.get("status", "open") != "open" and not it.get("statusNote"):
            errs.append(f"item {iid}: status {it['status']} needs a statusNote")
        if kind == "row" and it.get("state") not in ROW_STATES:
            errs.append(f"item {iid}: state {it.get('state')!r} not in {ROW_STATES}")
        if "changed" in it and it["changed"] not in CHANGED:
            errs.append(f"item {iid}: changed {it['changed']!r} not in {CHANGED}")
    return errs


def summary(data: dict[str, Any]) -> list[str]:
    meta, items = data["meta"], data["items"]
    out: list[str] = []
    n = 1
    for sid, sec in meta["sections"].items():
        sec_items = [it for it in items if it["section"] == sid]
        if sec["kind"] == "context":
            line = f"{len(sec_items)} context items (approved; nothing to answer)"
        elif sec["kind"] == "row":
            rows = [it for it in sec_items if it["kind"] == "row"]
            by_state = {s: sum(1 for r in rows if r["state"] == s) for s in ROW_STATES}
            by_author: dict[str, list[str]] = {}
            for r in rows:
                by_author.setdefault(r["draftedBy"], []).append(r["id"])
            states = ", ".join(f"{c} {s}" for s, c in by_state.items() if c)
            authors = "; ".join(f"{a}: {', '.join(ids)}" for a, ids in by_author.items())
            extra = len(sec_items) - len(rows)
            line = f"{len(rows)} protected-file rows ({states}; drafted by {authors})"
            if extra:
                line += f", plus {extra} question(s)"
        else:
            open_n = sum(1 for it in sec_items if it.get("status", "open") == "open")
            closed = [f"{it['id']} {it['status']}" for it in sec_items if it.get("status", "open") != "open"]
            line = f"{len(sec_items)} items, {open_n} open"
            if closed:
                line += f" ({'; '.join(closed)})"
        out.append(f"{n}. ({sid}) {sec['title']}: {line}.")
        n += 1
    new_ids = [it["id"] for it in items if it.get("changed") == "new"]
    chg_ids = [it["id"] for it in items if it.get("changed") == "changed"]
    out.append(f"{n}. New in this revision: {', '.join(new_ids) or 'none'}. "
               f"Changed: {', '.join(chg_ids) or 'none'}.")
    n += 1
    out.append(f"{n}. Suggested answer order: " + " → ".join(esc(s) for s in meta["answerOrder"]) + ".")
    return out


def render(data: dict[str, Any]) -> str:
    meta, items = data["meta"], data["items"]
    intent = meta["intent"]
    out = [f"# {meta['title']}", "",
           f"**Intent**: **Purpose**: {intent['purpose']} **Scope**: {intent['scope']} "
           f"**Audience**: {intent['audience']}", "",
           "Generated from the review-page JSON by `S3-GateFix-render-review-page.py` "
           f"(the JSON is the single source; edit it, then re-render). {meta['author']}.", "",
           "## Summary", ""]
    out += summary(data)
    out += ["", f"Path key: {meta['pathKey']}", ""]

    for sid, sec in meta["sections"].items():
        sec_items = [it for it in items if it["section"] == sid]
        out += [f"## ({sid}) {sec['title']}", ""]
        rows = [it for it in sec_items if it["kind"] == "row"]
        if rows:
            out += ["| Id | Row | State | Draft status | Options | Recommendation | Blocks | Draft |",
                    "|---|---|---|---|---|---|---|---|"]
            for it in rows:
                rid = it["id"] + (f" ({it['changed']})" if it.get("changed") else "")
                out.append("| " + " | ".join(cell(x) for x in (
                    rid, it["title"], it["state"], it["draftStatus"], " / ".join(it["options"]),
                    it["recommendation"], it["blocks"], it["draft"])) + " |")
            out.append("")
        for it in sec_items:
            if it["kind"] == "row":
                continue
            tag = f" ({it['changed']})" if it.get("changed") else ""
            if it["kind"] == "context":
                out += [f"### {it['id']}: {esc(it['title'])}", "", esc(it["text"]), "",
                        f"Source: {esc(it['source'])}", ""]
                continue
            out += [f"### {it['id']}{tag}: {esc(it['question'])}", ""]
            status = it.get("status", "open")
            if status != "open":
                out.append(f"- **Status:** {status.upper()} -- {esc(it['statusNote'])}. No answer needed.")
            if it.get("changeNote"):
                out.append(f"- **Change:** {esc(it['changeNote'])}")
            out.append("- **Options:**")
            out += [f"  - {esc(opt)}" for opt in it["options"]]
            out += [f"- **Recommendation:** {esc(it['recommendation'])}",
                    f"- **Why:** {esc(it['why'])}",
                    f"- **Blocks:** {esc(it['blocks'])}",
                    f"- **Source:** {esc(it['source'])}", ""]
    return "\n".join(out).rstrip() + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Validate the S3-GateFix review-page JSON and render it to Markdown. "
                    "Exits 1 on any validation error and writes nothing.")
    ap.add_argument("--check", action="store_true", help="validate only; do not write Markdown")
    ap.add_argument("json_path", help="review-page JSON (single source)")
    ap.add_argument("md_path", nargs="?", help="Markdown output path (required without --check)")
    args = ap.parse_args()
    if not args.check and not args.md_path:
        ap.error("md_path is required unless --check is given")
    try:
        with open(args.json_path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"error: cannot read {args.json_path}: {e}", file=sys.stderr)
        return 1
    errs = validate(data)
    if errs:
        for e in errs:
            print(f"error: {e}", file=sys.stderr)
        return 1
    counts = {s: sum(1 for it in data["items"] if it["section"] == s) for s in data["meta"]["sections"]}
    if not args.check:
        with open(args.md_path, "w", encoding="utf-8") as f:
            f.write(render(data))
    print(f"ok: {len(data['items'])} items; " + ", ".join(f"{s}={n}" for s, n in counts.items()))
    return 0


if __name__ == "__main__":
    sys.exit(main())
