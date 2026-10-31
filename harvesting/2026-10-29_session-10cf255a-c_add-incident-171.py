"""add-incident-171.py -- append incident #171 to the approved S3-MF-Incidents batch (scratch).

The batch (#146-#170) is applied to registries/incidents.json by MERGE-ALL with the
batch's apply script; adding #171 here keeps ids in sequence and avoids a collision.
"""
import json
import sys

P = ("/Users/new-jose/repos/aitools/.aitools/channel/handoffs/"
     "2026-10-21_10cf255a-c-missions/S3-MF-Incidents/S3-MF-Incidents-batch.json")
raw = open(P, encoding="utf-8").read()
batch = json.loads(raw)
if any(e["id"] == 171 for e in batch):
    sys.exit("171 already present")
if batch[-1]["id"] != 170:
    sys.exit("unexpected last id %s" % batch[-1]["id"])
batch.append({
    "id": 171,
    "title": "No rule tells a delegate how to resolve conflicts between the commander's words, its delegation prompt and a mandated skill, so a commander-mandated skill was silently dropped",
    "status": "open",
    "severity": "medium",
    "affected": [
        "shared/skills/delegate/SKILL.md",
        "~/.claude/rules/delegation.md (dotprofile claude/rules/delegation.md)",
        ".aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/SC-mission-packet.md"
    ],
    "linked": "shared/skills/delegate/SKILL.md 'Conflict priority' (commit on main, 2026-10-26)",
    "referenceFile": None,
    "observation": "Mission MDM-WINTOOL (2026-10-26): the commander ordered 'use /deep-research skill to find an alternative'. The delegation prompt named anthropic-skills:deep-research and allowed a by-hand fallback only 'if it will not load'. S3-MdmWinTool-Research loaded the skill, found it mandates a coordinator-only role with its own researcher sub-agents and writes research_notes/ and reports/ into the working directory (the main checkout), judged that this clashed with the prompt's access paths and chrome-devtools citation rule, 'followed none of its process', and did the research by hand. plans/build-package/mdm-windows-tool-findings.md and S3-MdmWinTool-Research-notes.md:178 record it only as a low INCIDENT; the orchestrator's hand-back did not tell the Session Commander that the mandated skill was not used, and the commander had to ask where the deep-research report was.",
    "expected": "No spec exists for: how a delegate resolves a conflict between the commander's words, its delegation prompt, and a skill's own process or file locations; and the duty to report (not silently skip) a mandated skill it does not follow. ~/.claude/rules/delegation.md and the /delegate skill covered rules, skills and access paths separately but never their precedence.",
    "impact": "Commander-mandated skills can be silently replaced by ad-hoc work whenever a skill's defaults (file locations, sub-agent process) differ from a prompt's access rules, which is common for packaged skills. The commander gets a different method than he ordered without being told, and has to discover it himself; the delegating agent also relays a summary that hides it.",
    "discoveryContext": "Session Commander 10cf255a-c, 2026-10-26, reviewing MDM-WINTOOL's hand-back (commit c412377) after the commander asked 'where is the deep research report on an alternative that is not windows only?'. Audited: the MDM-WINTOOL launch prompt (Skills section), S3-MdmWinTool-Research-notes.md:178, mdm-windows-tool-findings.md:275, ~/.claude/rules/delegation.md, shared/skills/delegate/SKILL.md 'Writing the prompt'.",
    "discipline": None,
    "frameworks": None,
    "suggestedResolution": "Done in part: shared/skills/delegate/SKILL.md gains writing step 12 (pre-resolve each named skill's conflicts: allow its file locations or override them explicitly) and a 'Conflict priority' section plus a skeleton 'Conflicts' block (commander decision 2026-10-26): 1) the commander's own words, newest first (recent session transcripts; rules, standing orders and decision records that record them); 2) the delegation prompt; 3) skills; a prompt cannot loosen a rule unless it quotes the commander; never drop a mandated skill silently, record CONFLICT: lines. Remaining: add the priority order as a decision in ~/.claude/rules/delegation.md (dotprofile) and to the mission packet; have the delegation-duty-guard hook check for a Conflicts block; re-run MDM-WINTOOL's alternatives research with deep-research writing under the mission folder.",
    "rootCause": "The delegation prompt named a skill without reading what that skill does (its mandated process and output locations), and no rule gave delegates a precedence order, so the delegate picked one silently.",
    "correctiveAction": None,
    "preventionLayer": "Prevention: /delegate skill writing step 12 and Conflicts block; Detection (proposed): delegation-duty-guard checks for the Conflicts block",
    "created": "2026-10-26",
    "updated": "2026-10-26"
})
out = json.dumps(batch, indent=2, ensure_ascii=False) + "\n"
json.loads(out)
open(P, "w", encoding="utf-8").write(out)
print("appended 171; entries:", len(batch))
