"""Build the issue #180 history comment: sections 1-3 of body v2.0, copied verbatim."""
import sys

src, out = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
start = text.index("## 1. AAR (after-action review)")
end = text.index("## What exists today, and the gaps")
header = (
    "## History: the commander's March 2026 schemas (moved from body v2.0, verbatim)\n\n"
    "Body v3.0 (2026-11-15, session dbd05b0c) replaces these sections with the schemas the commander "
    "decided on 2026-11-15. They are kept here word for word, as the record the decisions build on. "
    "Where this history says `insights` or `findings`, read the decisions in the body: the AAR node "
    "became `findings` (D-SR2) and then `deviations` (D-SR22). Citation conventions (`<dp>`, `L<n>`) "
    "are in the body under \"How to read the citations\".\n\n"
)
footer = "\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n"
open(out, "w", encoding="utf-8").write(header + text[start:end].rstrip() + "\n" + footer)
print("written", len(header + text[start:end]), "chars")
