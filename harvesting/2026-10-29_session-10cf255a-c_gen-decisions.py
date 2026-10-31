"""Generate plans/tool-support-and-machine-profile.md from the review-page items and the commander's saved answers."""
import glob
import json
import os
import sys

ANS = "/Users/new-jose/repos/aitools/.scratch/session-10cf255a-c/gate-answers/answers"
SRC = ("/Users/new-jose/repos/aitools/.claude/worktrees/gatefix/.aitools/channel/handoffs/"
       "2026-10-21_10cf255a-c-missions/S3-GateFix/S3-GateFix-review-page.json")
OUT = "/Users/new-jose/repos/aitools/.claude/worktrees/gate-decisions/plans/tool-support-and-machine-profile.md"
SECT = {"ta": "TOOL-ADOPT approval", "a": "Blocking gate questions", "b": "Protected-file batch",
        "c": "Glossary", "d": "Non-blocking", "e": "Known defects"}
# Decisions given in chat after the page (2026-10-21) override the page answer.
OVERRIDE = {
    "D-TS13": "(b) Bare exit 2 = user abort. No abort-marker file (chat, 2026-10-21: \"exit 2 = abort is fine for a user abort; avoid this\"). Rev 5 section 7.5 marker text is not implemented",
    "N-Q2": "Both auto-commit and push (confirmed in chat 2026-10-21); the existing dotprofile auto-commit/push in setup-user-claude is kept",
    "C.1": "Yes: the new tool-support work (M2) takes over tooling-resolution Workstream A's resolver and verification scope; B and C stay separate (chat 2026-10-21)",
    "P-Q4": "Writer silent; aitools user init prompts (chat 2026-10-21)",
    "N-Q6": "The registry schema allows only one preferred install method per platform; a violation gets its own detail message (chat 2026-10-21)",
    "REV4": "Superseded by REV5 (approved)",
}


def clean(s: str) -> str:
    return " ".join(str(s).split()).replace("|", "\\|")


def main() -> int:
    with open(SRC, encoding="utf-8") as f:
        items = json.load(f)["items"]
    ans = {}
    for p in glob.glob(os.path.join(ANS, "*.json")):
        with open(p, encoding="utf-8") as f:
            d = json.load(f)
        b = d.get("data", d)
        ans[str(b.get("itemId", os.path.basename(p)[:-5]))] = b
    lines = [
        "# Tool support and machine profile: gate decisions",
        "",
        "**Intent**: **Purpose**: Record every commander decision taken at the tool-support gate, so the",
        "implementation missions (M2 tool support, M3 machine profile, S2-Layout PRs, /tool-adopt,",
        "deploy-harness) build on decided text rather than conversation. **Scope**: The decisions and",
        "notes from the review page (S3-GateFix, PR #66) and the chat clarifications that override",
        "them. NOT the designs themselves (the decision tree rev 5, the drafts in the mission",
        "folders). NOT the managed-file model (`.claude/rules/agentic-standards.md`). **Audience**:",
        "Every agent implementing M2, M3, LAYOUT, TOOL-ADOPT or HARNESS.",
        "",
        "Decided 2026-10-21 by the commander. Source of the answers: the review page artifact",
        "(https://claude.ai/artifact/Mqm6D32Xt5gKGUxPZTMSDY, collection `answers`, 95 of 95",
        "answered). Item text and options: `.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/",
        "S3-GateFix/S3-GateFix-review-page.json`.",
        "",
        "## Decisions that change the drafts",
        "",
        "- **D-TS13 reversed**: bare exit 2 = user abort; no abort marker.",
        "- **Registries stay in `registries/`** (SD-8-reg): deploy-harness copies them to",
        "  `~/.aitools/registries/` (macOS/Linux) and `%USERPROFILE%\\.aitools\\registries\\` (Windows).",
        "  LAYOUT PR-b does not move them.",
        "- **SD-8 extended** to 7 user-level skills (adds incident, glossary, frameworks).",
        "- **Machine identity**: raw machine ids (P-Q2); resolver is native `scripts/aitools-profile.sh/.ps1`",
        "  (P-Q3), not JavaScript; one scutil command that reports `nobul-mac`, and scripts that take",
        "  hostnames from DNS are removed (P-Q5).",
        "- **`tool-versions.json` is deleted** and every reference remediated; `tool-registry.md` is",
        "  deprecated, references point to the `/tool-registry` skill (S2L-Q6, T-Q7).",
        "- **LAYOUT and M2 run in parallel** (C-SEQ).",
        "- **/tool-adopt does the work** (evaluate when needed, write the registry entry and setup",
        "  scripts), at user level (TA-PLACE, TA-SKILL).",
        "- **Dotprofile writes auto-commit and push** (N-Q2).",
        "- **Re-run the correctness (A) review as an independent delegate** (E-independence).",
        "",
        "## All items",
        "",
        "| Item | Section | Question | Decision | Note |",
        "|------|---------|----------|----------|------|",
    ]
    n = 0
    for it in items:
        if it.get("kind") not in ("question", "row"):
            continue
        i = str(it["id"])
        a = ans.get(i, {})
        dec = OVERRIDE.get(i) or a.get("choice") or ""
        if not dec:
            dec = "(see note)" if a.get("note") else "(unanswered)"
        q = it.get("question") or it.get("title") or ""
        lines.append(f"| {i} | {SECT.get(it['section'], it['section'])} | {clean(q)} | {clean(dec)} | {clean(a.get('note', ''))} |")
        n += 1
    lines += ["", f"{n} items.", ""]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"ok: {n} items -> {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
