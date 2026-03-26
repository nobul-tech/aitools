#!/usr/bin/env python3
"""Build the Operational Learning Index v2.

Improvements over v1:
- Section-based parsing instead of fragile multi-group regex
- Richer AAR extraction (observations, insights, proposals)
- Fix missing OL entries (OL-4, OL-6, OL-9, OL-11, OL-13)
- Proper carry-forward assignment
"""

import json
import os
import re
from pathlib import Path
from datetime import datetime, timezone
from typing import Any
from collections import Counter

# Paths
AITOOLS = Path("/Users/pepe/repos/aitools")
HARVESTING = AITOOLS / "harvesting"
SCRATCH = AITOOLS / ".scratch/session-c0dc2ddc-f"
INCIDENTS = AITOOLS / "reference/incidents.json"
RUNNING_ESTIMATE = AITOOLS / ".aitools/channel/running-estimate.json"
CONSOLIDATED_OL = SCRATCH / "consolidated-operational-learning.md"

OUT_MD = SCRATCH / "operational-learning-index.md"
OUT_JSON = SCRATCH / "operational-learning-index.json"


class OLEntry:
    def __init__(self, **kwargs: Any):
        self.id: str = kwargs.get("id", "")
        self.title: str = kwargs.get("title", "")
        self.principle: str = kwargs.get("principle", "")
        self.category: str = kwargs.get("category", "pattern")
        self.scope: str = kwargs.get("scope", "universal")
        self.source: str = kwargs.get("source", "")
        self.evidence: list[str] = kwargs.get("evidence", [])
        self.counter_evidence: list[str] = kwargs.get("counter_evidence", [])
        self.carry_forward: str = kwargs.get("carry_forward", "")
        self.quality_score: float = kwargs.get("quality_score", 0.0)
        self.quality_signals: dict[str, Any] = kwargs.get("quality_signals", {})
        self.tags: list[str] = kwargs.get("tags", [])

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "principle": self.principle,
            "category": self.category,
            "scope": self.scope,
            "source": self.source,
            "evidence": self.evidence,
            "counter_evidence": self.counter_evidence,
            "carry_forward": self.carry_forward,
            "quality_score": self.quality_score,
            "quality_signals": self.quality_signals,
            "tags": self.tags,
        }


def compute_quality_score(entry: OLEntry) -> float:
    """Quality score 0-10."""
    score = 3.0
    score += min(len(entry.evidence) * 0.5, 3.0)
    if entry.counter_evidence:
        score += 1.5
        entry.quality_signals["has_counter_evidence"] = True
    if entry.quality_signals.get("commander_validated"):
        score += 1.5
    if entry.scope in ("universal", "cross-project"):
        score += 1.0
    if entry.quality_signals.get("incident_linked"):
        score += 0.5
    if entry.carry_forward:
        score += 0.5
    return min(score, 10.0)


def parse_section_content(text: str) -> dict[str, str]:
    """Parse a section into its bold-prefixed parts."""
    parts: dict[str, str] = {}
    current_key = ""
    current_lines: list[str] = []

    for line in text.split("\n"):
        bold_match = re.match(r"\*\*(.+?)\*\*:?\s*(.*)", line)
        if bold_match:
            if current_key:
                parts[current_key] = "\n".join(current_lines).strip()
            current_key = bold_match.group(1).lower().rstrip(":")
            first_content = bold_match.group(2).strip()
            current_lines = [first_content] if first_content else []
        else:
            current_lines.append(line)

    if current_key:
        parts[current_key] = "\n".join(current_lines).strip()

    return parts


def extract_bullet_items(text: str) -> list[str]:
    """Extract bullet items from text."""
    items = []
    for line in text.split("\n"):
        stripped = line.strip()
        if stripped.startswith("- "):
            items.append(stripped[2:].strip())
    return items


def detect_commander_validation(text: str) -> bool:
    """Check if text mentions commander validation."""
    lower = text.lower()
    patterns = [
        "commander said",
        "commander directed",
        "commander corrected",
        "commander caught",
        'commander\'s response',
        "commander enforced",
        "commander instructed",
        "direct quote",
        "the commander",
    ]
    return any(p in lower for p in patterns)


def detect_projects(text: str) -> set[str]:
    """Detect project mentions in text."""
    lower = text.lower()
    projects = set()
    for p in ["aitools", "marse", "nobul-ops"]:
        if p in lower:
            projects.add(p)
    return projects


def extract_ol_principles(content: str) -> list[OLEntry]:
    """Extract OL-1 through OL-14 from consolidated doc."""
    entries = []

    # Split on ### OL-N headings
    sections = re.split(r"### (OL-\d+): (.+?)\n", content)

    # sections[0] is before first match, then groups of [id, title, body, id, title, body, ...]
    i = 1
    while i + 2 < len(sections):
        ol_id = sections[i]
        title = sections[i + 1].strip()
        body = sections[i + 2]
        i += 3

        # Trim body at next section boundary
        for boundary in ["### OL-", "## Part", "---\n"]:
            idx = body.find(boundary)
            if idx > 0:
                body = body[:idx]

        parts = parse_section_content(body)

        principle = parts.get("principle", "")
        evidence_text = parts.get("evidence", "")
        counter_text = parts.get("counter-evidence", parts.get("counter-evidence (violation consequences)", parts.get("counter-evidence (the original sin)", "")))
        carry_forward = parts.get("carry-forward instruction", "")

        evidence = extract_bullet_items(evidence_text)
        if not evidence and evidence_text:
            evidence = [evidence_text]

        counter_evidence = extract_bullet_items(counter_text)
        if not counter_evidence and counter_text:
            counter_evidence = [counter_text]

        full_text = body
        projects = detect_projects(full_text)
        scope = "cross-project" if len(projects) >= 2 else "universal"

        signals: dict[str, Any] = {
            "commander_validated": detect_commander_validation(full_text),
            "cross_project": len(projects) >= 2,
        }

        entry = OLEntry(
            id=ol_id,
            title=title,
            principle=principle,
            category="principle",
            scope=scope,
            source="consolidated-operational-learning.md",
            evidence=evidence,
            counter_evidence=counter_evidence,
            carry_forward=carry_forward,
            quality_signals=signals,
            tags=list(projects) if projects else ["universal"],
        )
        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def extract_delegation_principles(content: str) -> list[OLEntry]:
    """Extract P1-P7 delegation principles."""
    entries = []

    sections = re.split(r"\*\*(P\d+): (.+?)\.\*\*\n", content)
    i = 1
    while i + 2 < len(sections):
        p_id = sections[i]
        title = sections[i + 1].strip()
        body = sections[i + 2]
        i += 3

        # Trim at next P-N or section boundary
        for boundary in ["\n**P", "\n### ", "\n---"]:
            idx = body.find(boundary)
            if idx > 0:
                body = body[:idx]

        # Extract first paragraph as principle
        paragraphs = body.strip().split("\n\n")
        principle = paragraphs[0].strip() if paragraphs else body.strip()

        evidence = extract_bullet_items(body)
        counter_evidence = []
        for line in body.split("\n"):
            if line.strip().startswith("- Counter-evidence:"):
                counter_evidence.append(line.strip()[len("- Counter-evidence:"):].strip())

        signals: dict[str, Any] = {
            "commander_validated": detect_commander_validation(body),
            "cross_project": True,
        }

        entry = OLEntry(
            id=f"D-{p_id}",
            title=f"Delegation: {title}",
            principle=principle,
            category="principle",
            scope="universal",
            source="consolidated-operational-learning.md",
            evidence=[e for e in evidence if not e.startswith("Counter-evidence")],
            counter_evidence=counter_evidence,
            carry_forward="",
            quality_signals=signals,
            tags=["delegation"],
        )
        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def extract_anti_patterns(content: str) -> list[OLEntry]:
    """Extract anti-patterns."""
    entries = []
    sections = re.split(r"\*\*Anti-pattern (\d+): (.+?)\.\*\*\n", content)
    i = 1
    while i + 2 < len(sections):
        ap_num = sections[i]
        title = sections[i + 1].strip()
        body = sections[i + 2]
        i += 3

        for boundary in ["\n**Anti-pattern", "\n### ", "\n---"]:
            idx = body.find(boundary)
            if idx > 0:
                body = body[:idx]

        evidence = extract_bullet_items(body)

        entry = OLEntry(
            id=f"AP-{ap_num}",
            title=f"Anti-pattern: {title}",
            principle=body.split("\n\n")[0].strip() if "\n\n" in body else body.strip(),
            category="anti-pattern",
            scope="universal",
            source="consolidated-operational-learning.md",
            evidence=evidence,
            quality_signals={"commander_validated": detect_commander_validation(body)},
            tags=["delegation", "anti-pattern"],
        )
        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def extract_project_specific(content: str) -> list[OLEntry]:
    """Extract A1-A8, N1-N5, M1-M4."""
    entries = []
    scope_map = {"A": "aitools", "N": "nobul-ops", "M": "marse"}

    sections = re.split(r"\*\*([ANM]\d+): (.+?)\.\*\*\n", content)
    i = 1
    while i + 2 < len(sections):
        ps_id = sections[i]
        title = sections[i + 1].strip()
        body = sections[i + 2]
        i += 3

        for boundary in [f"\n**{ps_id[0]}", "\n### ", "\n---"]:
            idx = body.find(boundary)
            if idx > 0:
                body = body[:idx]

        scope = scope_map.get(ps_id[0], "universal")

        entry = OLEntry(
            id=ps_id,
            title=title,
            principle=body.strip(),
            category="pattern",
            scope=scope,
            source="consolidated-operational-learning.md",
            quality_signals={},
            tags=[scope],
        )
        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def extract_gaps(content: str) -> list[OLEntry]:
    """Extract G1-G6 and U1-U4."""
    entries = []

    for prefix, label in [("G", "Gap"), ("U", "Uncaptured"), ("P", "Observed")]:
        pattern_str = rf"\*\*({prefix}\d+): (.+?)\.\*\*\n"
        sections = re.split(pattern_str, content)
        i = 1
        while i + 2 < len(sections):
            g_id = sections[i]
            title = sections[i + 1].strip()
            body = sections[i + 2]
            i += 3

            for boundary in [f"\n**{prefix}", "\n### ", "\n---"]:
                idx = body.find(boundary)
                if idx > 0:
                    body = body[:idx]

            entry = OLEntry(
                id=g_id,
                title=f"{label}: {title}",
                principle=body.strip(),
                category="gap",
                scope="universal",
                source="consolidated-operational-learning.md",
                quality_signals={},
                tags=[label.lower(), "future-work"],
            )
            entry.quality_score = compute_quality_score(entry)
            entries.append(entry)

    return entries


def extract_from_incidents() -> list[OLEntry]:
    """Extract OL from high-severity incidents."""
    entries = []
    try:
        with open(INCIDENTS) as f:
            data = json.load(f)
    except Exception:
        return entries

    for inc in data.get("incidents", []):
        if not inc.get("suggestedResolution") or not inc.get("observation"):
            continue
        if inc.get("severity") not in ("critical", "high"):
            continue

        entry = OLEntry(
            id=f"INC-{inc['id']}",
            title=f"Incident: {inc['title']}",
            principle=inc.get("observation", ""),
            category="pattern",
            scope="aitools",
            source=f"incidents.json #{inc['id']}",
            evidence=[inc["observation"]],
            carry_forward=inc.get("suggestedResolution", ""),
            quality_signals={"incident_linked": True, "severity": inc.get("severity")},
            tags=["incident", inc.get("severity", "")],
        )
        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def extract_from_aars() -> list[OLEntry]:
    """Extract OL from harvested AARs -- deep extraction."""
    entries = []
    seen_bases: set[str] = set()

    for f in sorted(HARVESTING.iterdir()):
        if "aar" not in f.name.lower():
            continue
        m = re.match(r"\d{4}-\d{2}-\d{2}_(?:\d+_)?(.+)", f.name)
        base = m.group(1) if m else f.name
        if base in seen_bases:
            continue
        seen_bases.add(base)

        try:
            if f.suffix == ".json":
                with open(f) as fh:
                    aar = json.load(fh)
                title = aar.get("title", aar.get("name", f.stem))

                # Extract insights (richer than lessonsLearned)
                insights = aar.get("insights", [])
                for idx, insight in enumerate(insights):
                    if isinstance(insight, dict):
                        analysis = insight.get("analysis", "")
                        if len(analysis) < 30:
                            continue
                        entry = OLEntry(
                            id=f"AAR-{base}-I{idx+1}",
                            title=f"AAR Insight: {title}",
                            principle=analysis[:500],
                            category="pattern",
                            scope="aitools",
                            source=f"harvesting/{f.name}",
                            evidence=[analysis],
                            quality_signals={},
                            tags=["aar", "insight"],
                        )
                        entry.quality_score = compute_quality_score(entry)
                        entries.append(entry)

                # Extract proposals
                proposals = aar.get("proposals", [])
                for idx, prop in enumerate(proposals):
                    if isinstance(prop, dict):
                        what = prop.get("what", "")
                        why = prop.get("why", "")
                        if len(what) < 20:
                            continue
                        entry = OLEntry(
                            id=f"AAR-{base}-P{idx+1}",
                            title=f"AAR Proposal: {title}",
                            principle=what,
                            carry_forward=why,
                            category="pattern",
                            scope="aitools",
                            source=f"harvesting/{f.name}",
                            quality_signals={},
                            tags=["aar", "proposal"],
                        )
                        entry.quality_score = compute_quality_score(entry)
                        entries.append(entry)

                # Extract lessons learned
                lessons = aar.get("lessonsLearned", aar.get("lessons", []))
                for idx, lesson in enumerate(lessons):
                    if isinstance(lesson, dict):
                        text = lesson.get("description", lesson.get("lesson", str(lesson)))
                    else:
                        text = str(lesson)
                    if len(text) < 20:
                        continue
                    entry = OLEntry(
                        id=f"AAR-{base}-L{idx+1}",
                        title=f"AAR Lesson: {title}",
                        principle=text[:500],
                        category="pattern",
                        scope="aitools",
                        source=f"harvesting/{f.name}",
                        quality_signals={},
                        tags=["aar", "lesson"],
                    )
                    entry.quality_score = compute_quality_score(entry)
                    entries.append(entry)

            elif f.suffix == ".md":
                content = f.read_text()
                title_match = re.search(r"^#\s+(.+)$", content, re.MULTILINE)
                title = title_match.group(1) if title_match else f.stem

                entry = OLEntry(
                    id=f"AAR-{base}",
                    title=f"AAR: {title}",
                    principle=content[:500],
                    category="pattern",
                    scope="aitools",
                    source=f"harvesting/{f.name}",
                    quality_signals={},
                    tags=["aar"],
                )
                entry.quality_score = compute_quality_score(entry)
                entries.append(entry)
        except Exception:
            continue

    return entries


def extract_from_running_estimate() -> list[OLEntry]:
    """Extract session arc OL from running estimate version history."""
    entries = []
    try:
        with open(RUNNING_ESTIMATE) as f:
            data = json.load(f)
    except Exception:
        return entries

    for vh in data.get("meta", {}).get("versionHistory", []):
        changes = vh.get("changes", "")
        if len(changes) < 50:
            continue
        entry = OLEntry(
            id=f"RE-v{vh['version']}",
            title=f"Running Estimate v{vh['version']}",
            principle=changes,
            category="pattern",
            scope="aitools",
            source="running-estimate.json",
            quality_signals={},
            tags=["running-estimate", "session-arc"],
        )
        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def generate_markdown_index(entries: list[OLEntry]) -> str:
    """Generate the context-loadable markdown index."""
    entries.sort(key=lambda e: -e.quality_score)
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    lines: list[str] = []
    lines.append("# Operational Learning Index")
    lines.append("")
    lines.append(f"**Generated**: {now}")
    lines.append(f"**Entries**: {len(entries)}")
    scores = [e.quality_score for e in entries]
    lines.append(f"**Quality range**: {min(scores):.1f} - {max(scores):.1f}")
    lines.append(f"**Session**: c0dc2ddc-f464-404d-a637-8103afda27af")
    lines.append("")
    lines.append("**Purpose**: Make all accumulated operational learning accessible,")
    lines.append("queryable, and quality-ranked. Load this file at session start to")
    lines.append("have the full OL inventory in context. Iteratively improvable --")
    lines.append("subsequent missions can extend the index with new sources and signals.")
    lines.append("")

    # Summary
    cat_counts = Counter(e.category for e in entries)
    scope_counts = Counter(e.scope for e in entries)
    lines.append("## Summary")
    lines.append("")
    lines.append("| Category | Count |  | Scope | Count |")
    lines.append("|----------|-------|--|-------|-------|")
    cats = list(cat_counts.most_common())
    scopes = list(scope_counts.most_common())
    max_rows = max(len(cats), len(scopes))
    for r in range(max_rows):
        cat_cell = f"| {cats[r][0]} | {cats[r][1]} |" if r < len(cats) else "| | |"
        scope_cell = f" {scopes[r][0]} | {scopes[r][1]} |" if r < len(scopes) else " | |"
        lines.append(f"{cat_cell}{scope_cell}")
    lines.append("")

    # Quality tiers
    tier1 = [e for e in entries if e.quality_score >= 8.0]
    tier2 = [e for e in entries if 6.0 <= e.quality_score < 8.0]
    tier3 = [e for e in entries if 4.0 <= e.quality_score < 6.0]
    tier4 = [e for e in entries if e.quality_score < 4.0]

    lines.append("## Quality Tiers")
    lines.append("")
    lines.append(f"- **Tier 1 (8.0+)**: {len(tier1)} -- Commander-validated, cross-project, evidence-rich")
    lines.append(f"- **Tier 2 (6.0-7.9)**: {len(tier2)} -- Well-evidenced or multi-signal")
    lines.append(f"- **Tier 3 (4.0-5.9)**: {len(tier3)} -- Documented but thin evidence")
    lines.append(f"- **Tier 4 (<4.0)**: {len(tier4)} -- Noted but unvalidated")
    lines.append("")

    # Tier 1
    if tier1:
        lines.append("---")
        lines.append("")
        lines.append("## Tier 1: Highest Confidence (8.0+)")
        lines.append("")
        for e in tier1:
            lines.append(f"### {e.id}: {e.title}")
            lines.append(f"**Score**: {e.quality_score:.1f} | **Scope**: {e.scope} | **Category**: {e.category}")
            lines.append(f"**Source**: {e.source}")
            lines.append("")
            lines.append(f"**Principle**: {e.principle}")
            lines.append("")
            if e.evidence:
                lines.append("**Evidence**:")
                for ev in e.evidence:
                    lines.append(f"- {ev}")
                lines.append("")
            if e.counter_evidence:
                lines.append("**Counter-evidence**:")
                for cev in e.counter_evidence:
                    lines.append(f"- {cev}")
                lines.append("")
            if e.carry_forward:
                lines.append(f"**Carry-forward**: {e.carry_forward}")
                lines.append("")
            lines.append(f"**Tags**: {', '.join(e.tags)}")
            lines.append("")

    # Tier 2
    if tier2:
        lines.append("---")
        lines.append("")
        lines.append("## Tier 2: Strong Evidence (6.0-7.9)")
        lines.append("")
        for e in tier2:
            lines.append(f"### {e.id}: {e.title}")
            lines.append(f"**Score**: {e.quality_score:.1f} | **Scope**: {e.scope} | **Category**: {e.category}")
            lines.append("")
            # Truncate principle for Tier 2
            p = e.principle
            if len(p) > 300:
                p = p[:300] + "..."
            lines.append(f"{p}")
            lines.append("")
            if e.carry_forward:
                lines.append(f"**Carry-forward**: {e.carry_forward}")
                lines.append("")

    # Tier 3
    if tier3:
        lines.append("---")
        lines.append("")
        lines.append("## Tier 3: Documented (4.0-5.9)")
        lines.append("")
        lines.append("| ID | Title | Score | Scope | Source |")
        lines.append("|-----|-------|-------|-------|--------|")
        for e in tier3:
            t = e.title[:60]
            s = e.source[:40]
            lines.append(f"| {e.id} | {t} | {e.quality_score:.1f} | {e.scope} | {s} |")
        lines.append("")

    # Tier 4
    if tier4:
        lines.append("---")
        lines.append("")
        lines.append("## Tier 4: Noted (<4.0)")
        lines.append("")
        for e in tier4:
            lines.append(f"- **{e.id}**: {e.title} ({e.scope})")
        lines.append("")

    # Data source inventory
    lines.append("---")
    lines.append("")
    lines.append("## Data Source Inventory")
    lines.append("")
    lines.append("| Source | Location | Items | Status |")
    lines.append("|--------|----------|-------|--------|")
    lines.append("| Consolidated OL | .scratch/session-*/consolidated-operational-learning.md | 14 principles, 7 delegation, 4 anti-patterns, 6 gaps | First consolidation |")
    lines.append("| Harvested AARs | harvesting/*aar*.json | 14 unique (84 with 7x duplication bug) | Shallow extraction |")
    lines.append("| Incidents | reference/incidents.json | 48 open (21 high+), 2 closed | Structured |")
    lines.append("| Running Estimate | .aitools/channel/running-estimate.json | 12 version entries | Session arc history |")
    lines.append("| Session Archives | aitools-nobul-jose/sessions/ | 259 across 24 projects (478MB) | Untapped |")
    lines.append("| Session DB | .aitools/harness.db + sessions/*.db | 62 messages (1 session) | Schema exists, sparse data |")
    lines.append("| Release Notes | RELEASE_NOTES.md | v0.56-v0.66.0 | Not yet extracted |")
    lines.append("| Delegation Audits | .scratch/session-*/*audit*.md | 3 cross-project audits | This session only |")
    lines.append("")

    lines.append("### Harvesting health")
    lines.append("")
    lines.append("- 435 artifacts in manifest, **0 promoted** (promotion pipeline not functioning)")
    lines.append("- 54 base names duplicated (some 7x) -- harvesting bug")
    lines.append("- 433 harvested, 2 candidate, 0 promoted")
    lines.append("")

    lines.append("### Quality signals used")
    lines.append("")
    lines.append("| Signal | Weight | Reliability |")
    lines.append("|--------|--------|-------------|")
    lines.append("| Evidence count | +0.5/item (max +3.0) | High |")
    lines.append("| Counter-evidence documented | +1.5 | High (shows rigor) |")
    lines.append("| Commander validation | +1.5 | High (explicit quotes) |")
    lines.append("| Cross-project scope | +1.0 | High |")
    lines.append("| Incident linkage | +0.5 | Medium |")
    lines.append("| Carry-forward instruction | +0.5 | Medium |")
    lines.append("| Recency | NOT USED | Low per OL-3 |")
    lines.append("")

    # Iteration guidance
    lines.append("---")
    lines.append("")
    lines.append("## Iteration Guidance for Future Missions")
    lines.append("")
    lines.append("1. **Mine session transcripts** for commander corrections (each = implicit OL)")
    lines.append("2. **Deeper AAR extraction** -- current v2 gets insights/proposals/lessons but JSON AARs have rich observation chains")
    lines.append("3. **Git log cross-reference** -- which OL entries led to commits?")
    lines.append("4. **Delegation score signal** -- from audit reports")
    lines.append("5. **Fix harvesting 7x duplication** -- deduplicate base names")
    lines.append("6. **Build promotion pipeline** -- 0/435 promoted is a process failure")
    lines.append("7. **Instrument reuse tracking** -- when OL is loaded and influences decisions")
    lines.append("8. **Extract from release notes** -- operational patterns in changelogs")
    lines.append("9. **Cross-project OL from nobul-ops/marse** -- only aitools AARs are harvested currently")
    lines.append("10. **SQLite persistence** -- add OL entries to harness DB for cross-session querying")
    lines.append("")

    return "\n".join(lines)


def main() -> None:
    print("Building Operational Learning Index v2...")

    content = CONSOLIDATED_OL.read_text()
    all_entries: list[OLEntry] = []

    # Core OL principles
    print("  OL principles...")
    ol = extract_ol_principles(content)
    all_entries.extend(ol)
    print(f"    -> {len(ol)} (expected 14)")

    # Delegation principles
    print("  Delegation principles...")
    dp = extract_delegation_principles(content)
    all_entries.extend(dp)
    print(f"    -> {len(dp)}")

    # Anti-patterns
    print("  Anti-patterns...")
    ap = extract_anti_patterns(content)
    all_entries.extend(ap)
    print(f"    -> {len(ap)}")

    # Project-specific
    print("  Project-specific...")
    ps = extract_project_specific(content)
    all_entries.extend(ps)
    print(f"    -> {len(ps)}")

    # Gaps and uncaptured
    print("  Gaps and uncaptured...")
    gaps = extract_gaps(content)
    all_entries.extend(gaps)
    print(f"    -> {len(gaps)}")

    # Incidents
    print("  Incidents...")
    inc = extract_from_incidents()
    all_entries.extend(inc)
    print(f"    -> {len(inc)}")

    # AARs
    print("  AARs...")
    aars = extract_from_aars()
    all_entries.extend(aars)
    print(f"    -> {len(aars)}")

    # Running estimate
    print("  Running estimate...")
    re_entries = extract_from_running_estimate()
    all_entries.extend(re_entries)
    print(f"    -> {len(re_entries)}")

    # Recompute scores
    for e in all_entries:
        e.quality_score = compute_quality_score(e)

    print(f"\nTotal: {len(all_entries)} entries")

    # Deduplicate by ID
    seen_ids: set[str] = set()
    unique: list[OLEntry] = []
    for e in all_entries:
        if e.id not in seen_ids:
            seen_ids.add(e.id)
            unique.append(e)
    if len(unique) < len(all_entries):
        print(f"  Deduplicated: {len(all_entries)} -> {len(unique)}")
    all_entries = unique

    # Generate outputs
    md = generate_markdown_index(all_entries)
    OUT_MD.write_text(md)
    print(f"  Markdown: {OUT_MD}")

    json_data = {
        "meta": {
            "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "version": 2,
            "entry_count": len(all_entries),
            "quality_model": {
                "base": 3.0,
                "evidence_per_item": 0.5,
                "evidence_cap": 3.0,
                "counter_evidence": 1.5,
                "commander_validated": 1.5,
                "cross_project": 1.0,
                "incident_linked": 0.5,
                "carry_forward": 0.5,
                "max_score": 10.0,
            },
        },
        "entries": [e.to_dict() for e in sorted(all_entries, key=lambda x: -x.quality_score)],
    }
    OUT_JSON.write_text(json.dumps(json_data, indent=2, default=str))
    print(f"  JSON: {OUT_JSON}")

    # Summary
    print("\n=== Quality Distribution ===")
    for tier, label in [(8.0, "Tier 1 (8.0+)"), (6.0, "Tier 2 (6.0-7.9)"), (4.0, "Tier 3 (4.0-5.9)"), (0.0, "Tier 4 (<4.0)")]:
        if tier >= 8.0:
            count = len([e for e in all_entries if e.quality_score >= tier])
        elif tier >= 6.0:
            count = len([e for e in all_entries if tier <= e.quality_score < 8.0])
        elif tier >= 4.0:
            count = len([e for e in all_entries if tier <= e.quality_score < 6.0])
        else:
            count = len([e for e in all_entries if e.quality_score < 4.0])
        print(f"  {label}: {count}")


if __name__ == "__main__":
    main()
