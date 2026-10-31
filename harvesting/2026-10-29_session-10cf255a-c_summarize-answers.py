"""Summarize the review-page answers: join each saved answer with its item and recommendation.

Prints one line per answered item: id, section, followed-recommendation flag, choice, note.
"""
import glob
import json
import os
import sys

ANS = "/Users/new-jose/repos/aitools/.scratch/session-10cf255a-c/gate-answers/answers"
SRC = ("/Users/new-jose/repos/aitools/.claude/worktrees/gatefix/.aitools/channel/handoffs/"
       "2026-10-21_10cf255a-c-missions/S3-GateFix/S3-GateFix-review-page.json")


def main() -> int:
    with open(SRC, encoding="utf-8") as f:
        items = {str(i["id"]): i for i in json.load(f)["items"]}
    answers = {}
    for p in glob.glob(os.path.join(ANS, "*.json")):
        with open(p, encoding="utf-8") as f:
            d = json.load(f)
        body = d.get("data", d)
        answers[str(body.get("itemId", os.path.basename(p)[:-5]))] = body
    answerable = [k for k, v in items.items() if v.get("kind") in ("question", "row")]
    missing = [k for k in answerable if k not in answers]
    deviations, notes = [], []
    for k in answerable:
        a = answers.get(k)
        if not a:
            continue
        it = items[k]
        rec = str(it.get("recommendation", "")).strip()
        choice = str(a.get("choice", ""))
        follows = choice.startswith("Recommendation:") or (rec[:3].lower() == choice[:3].lower() and rec[:1] == "(") or choice.lower().startswith(rec.lower()[:25])
        if not follows:
            deviations.append((k, it.get("section"), choice, rec))
        if a.get("note"):
            notes.append((k, it.get("section"), choice, a["note"]))
    print(f"answered {len(answerable) - len(missing)} / {len(answerable)}; missing: {missing}")
    print(f"\n== {len(deviations)} answers that differ from the recommendation ==")
    for k, s, c, r in deviations:
        print(f"[{s}] {k}\n   chose: {c[:300]}\n   rec:   {r[:200]}")
    print(f"\n== {len(notes)} answers with notes ==")
    for k, s, c, n in notes:
        print(f"[{s}] {k}\n   chose: {c[:200]}\n   note:  {n[:1200]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
