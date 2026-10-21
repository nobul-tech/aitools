#!/usr/bin/env python3
"""Render S3-Gate-review-page.md from S3-Gate-review-page.json (single source).

intent: Keep the S3-Gate review page Markdown identical in content to its JSON
source, so the session commander can edit the JSON (or render it as an Artifact)
and regenerate the page. NOT a general renderer. Consumers: S3-Gate, the session
commander.

Usage: python3 -I S3-Gate-render-review-page.py <json-path> <md-path>
Validates that every item has the required keys and a known section, that ids are
unique, then writes the Markdown page. Exits 1 on any validation error.
"""
import json
import re
import sys

REQUIRED = ("id", "section", "question", "options", "recommendation", "why", "blocks", "source")


def fail(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(1)


PLACEHOLDER = re.compile(r"<([A-Za-z{][^<>\n]*)>")


def esc(text: str) -> str:
    """Escape <placeholder> outside code spans so Markdown renderers keep it visible."""
    parts = text.split("`")
    for i in range(0, len(parts), 2):
        parts[i] = PLACEHOLDER.sub(r"&lt;\1&gt;", parts[i])
    return "`".join(parts)


def cell(text: str) -> str:
    return esc(text).replace("|", "\\|").replace("\n", " ")


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: S3-Gate-render-review-page.py <json-path> <md-path>")
    with open(sys.argv[1], encoding="utf-8") as f:
        data = json.load(f)
    meta = data["meta"]
    sections = meta["sections"]
    items = data["items"]
    seen = set()
    for it in items:
        missing = [k for k in REQUIRED if k not in it]
        if missing:
            fail(f"item {it.get('id')} missing {missing}")
        if it["section"] not in sections:
            fail(f"item {it['id']} has unknown section {it['section']}")
        if it["id"] in seen:
            fail(f"duplicate id {it['id']}")
        if not isinstance(it["options"], list) or not it["options"]:
            fail(f"item {it['id']} options must be a non-empty list")
        seen.add(it["id"])

    counts = {s: sum(1 for it in items if it["section"] == s) for s in sections}
    intent = meta["intent"]
    out = []
    out.append("# S3-Gate review page: tool support, machine profile, skill layout")
    out.append("")
    out.append(f"**Intent**: **Purpose**: {intent['purpose']} **Scope**: {intent['scope']} **Audience**: {intent['audience']}")
    out.append("")
    out.append("Generated from `S3-Gate-review-page.json` by `S3-Gate-render-review-page.py` "
               "(the JSON is the single source; edit it, then re-render). "
               f"{meta['author']}.")
    out.append("")
    out.append("## Summary")
    out.append("")
    out.append(f"1. {counts['a']} blocking decisions (section a). Four are new or changed by the A/B pass. "
               "D-TS13: exit 2 counts as a user abort only with an abort marker. REV4: approve tree rev 4 instead of rev 3. "
               "S2L-Q3: the 9 untracked skill copies are already gone. C.1: M2 absorbs Workstream A's resolver and verification only.")
    out.append(f"2. {counts['b']} protected-file rows (section b). 23 are drafted (9 of them by S3-Gate: rows 1, 3-6, 14-16, 25). "
               "Row 17 is void under PR-c, row 24 is carved out to mission LEDGER, and one S2-Layout sibling row is added.")
    out.append(f"3. {counts['c']} glossary decisions (section c), {counts['d']} non-blocking pre-answers (section d), "
               f"{counts['e']} known defects (section e).")
    out.append("4. Suggested answer order: N-Q1 and D-TS10..13 first (every M2/M3 code batch waits on them), "
               "then REV4 and the row batch, then the S2-Layout items (PR-a can start as soon as item PR-a is answered).")
    out.append("5. Context, not questions: " + esc(meta["context"]))
    out.append("")
    out.append(f"Path key: {meta['pathKey']}")
    out.append("")

    for sec, title in sections.items():
        sec_items = [it for it in items if it["section"] == sec]
        out.append(f"## ({sec}) {title}")
        out.append("")
        if sec == "b":
            out.append("| Id | Row | Status | Recommendation | Blocks | Draft |")
            out.append("|---|---|---|---|---|---|")
            for it in sec_items:
                out.append("| " + " | ".join(cell(x) for x in (
                    it["id"], it["question"], it["why"], it["recommendation"], it["blocks"], it["source"])) + " |")
            out.append("")
            continue
        for it in sec_items:
            out.append(f"### {it['id']}: {esc(it['question'])}")
            out.append("")
            out.append("- **Options:**")
            for opt in it["options"]:
                out.append(f"  - {esc(opt)}")
            out.append(f"- **Recommendation:** {esc(it['recommendation'])}")
            out.append(f"- **Why:** {esc(it['why'])}")
            out.append(f"- **Blocks:** {esc(it['blocks'])}")
            out.append(f"- **Source:** {esc(it['source'])}")
            out.append("")

    with open(sys.argv[2], "w", encoding="utf-8") as f:
        f.write("\n".join(out).rstrip() + "\n")
    print(f"ok: {len(items)} items; " + ", ".join(f"{s}={n}" for s, n in counts.items()))


if __name__ == "__main__":
    main()
