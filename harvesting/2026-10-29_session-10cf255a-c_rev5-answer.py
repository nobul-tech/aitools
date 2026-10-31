"""Print the saved answers for a few review-page items (choice and note)."""
import json
import os
import sys

ANS = "/Users/new-jose/repos/aitools/.scratch/session-10cf255a-c/gate-answers/answers"
IDS = ["REV5", "REV4", "TA-SKILL", "TA-INTENT", "TA-GLOSSARY", "TA-M2", "N-Q1", "D-TS10", "D-TS11",
       "N-Q3", "P-Q1", "S2L-Q3", "S2L-Q5", "SD-8-ext", "R2", "R3", "C-14"]


def main() -> int:
    for i in IDS:
        p = os.path.join(ANS, i + ".json")
        if not os.path.exists(p):
            print(i, "MISSING")
            continue
        with open(p, encoding="utf-8") as f:
            d = json.load(f)
        b = d.get("data", d)
        print(f"{i}: {str(b.get('choice', ''))[:220]}" + (f" | note: {b['note'][:300]}" if b.get("note") else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
