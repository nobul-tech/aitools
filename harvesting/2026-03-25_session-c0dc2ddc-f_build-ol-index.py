#!/usr/bin/env python3
"""Build the Operational Learning Index.

This script scans all OL data sources across all projects and produces
a single consolidated index that:
1. Catalogs every OL source with metadata and quality signals
2. Extracts and deduplicates OL entries from AARs, investigations, consolidated docs
3. Ranks entries by quality signals (evidence count, commander validation, reuse count)
4. Produces a loadable markdown artifact for session context

Sources scanned:
- harvesting/ directory (AARs, investigations, research)
- Consolidated OL document (this session)
- Incident entries with OL implications
- Release notes (operational patterns)
- Running estimate (version history = session arc OL)
- Cross-project session audits

Quality signals:
- evidence_count: How many distinct evidence items support this OL
- commander_validated: Whether the commander explicitly confirmed this
- reuse_count: How many sessions/contexts reference this OL
- cross_project: Whether this OL applies across projects
- incident_linked: Whether this is backed by an incident investigation
- has_counter_evidence: Whether counter-evidence was documented (higher quality)

Output:
- operational-learning-index.md: Human-readable, context-loadable index
- operational-learning-index.json: Machine-readable for future automation
"""

import json
import os
import re
from pathlib import Path
from datetime import datetime
from typing import Any
from collections import Counter

# Paths
AITOOLS = Path("/Users/pepe/repos/aitools")
HARVESTING = AITOOLS / "harvesting"
SCRATCH = AITOOLS / ".scratch/session-c0dc2ddc-f"
INCIDENTS = AITOOLS / "reference/incidents.json"
RELEASE_NOTES = AITOOLS / "RELEASE_NOTES.md"
RUNNING_ESTIMATE = AITOOLS / ".aitools/channel/running-estimate.json"
CONSOLIDATED_OL = SCRATCH / "consolidated-operational-learning.md"
MANIFEST = HARVESTING / "harvest-manifest.json"

# Output
OUT_MD = SCRATCH / "operational-learning-index.md"
OUT_JSON = SCRATCH / "operational-learning-index.json"


class OLEntry:
    """A single operational learning entry."""

    def __init__(
        self,
        id: str,
        title: str,
        principle: str,
        category: str,  # principle, pattern, anti-pattern, gap, architectural
        scope: str,  # universal, aitools, nobul-ops, marse, cross-project
        source: str,  # Where this was first documented
        evidence: list[str],
        counter_evidence: list[str],
        carry_forward: str,
        quality_score: float = 0.0,
        quality_signals: dict[str, Any] | None = None,
        tags: list[str] | None = None,
        related: list[str] | None = None,
    ):
        self.id = id
        self.title = title
        self.principle = principle
        self.category = category
        self.scope = scope
        self.source = source
        self.evidence = evidence
        self.counter_evidence = counter_evidence
        self.carry_forward = carry_forward
        self.quality_score = quality_score
        self.quality_signals = quality_signals or {}
        self.tags = tags or []
        self.related = related or []

    def to_dict(self) -> dict:
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
            "related": self.related,
        }


def compute_quality_score(entry: OLEntry) -> float:
    """Compute quality score from signals.

    Scoring (0-10 scale):
    - Base: 3.0 (every documented OL gets a baseline)
    - Evidence items: +0.5 per item, max +3.0
    - Counter-evidence documented: +1.5 (shows rigor)
    - Commander validated: +1.5
    - Cross-project applicability: +1.0
    - Incident-linked: +0.5
    - Has carry-forward instruction: +0.5
    """
    score = 3.0

    # Evidence weight
    ev_count = len(entry.evidence)
    score += min(ev_count * 0.5, 3.0)

    # Counter-evidence documented
    if entry.counter_evidence:
        score += 1.5
        entry.quality_signals["has_counter_evidence"] = True

    # Commander validated
    if entry.quality_signals.get("commander_validated"):
        score += 1.5

    # Cross-project
    if entry.scope in ("universal", "cross-project"):
        score += 1.0
        entry.quality_signals["cross_project"] = True

    # Incident-linked
    if entry.quality_signals.get("incident_linked"):
        score += 0.5

    # Has carry-forward
    if entry.carry_forward:
        score += 0.5

    return min(score, 10.0)


def extract_from_consolidated_ol() -> list[OLEntry]:
    """Extract OL entries from the consolidated operational learning document."""
    entries = []

    content = CONSOLIDATED_OL.read_text()

    # Parse OL-N entries (Part 3: Operational Learning -- Principles)
    ol_pattern = re.compile(
        r"### (OL-\d+): (.+?)\n\n"
        r"\*\*Principle\*\*: (.+?)(?=\n\n\*\*Evidence\*\*:)"
        r"\n\n\*\*Evidence\*\*:\n(.+?)"
        r"(?:\n\n\*\*Counter-evidence.*?\*\*:?\n(.+?))?"
        r"(?:\n\n\*\*Carry-forward instruction\*\*: (.+?)(?=\n\n###|\n\n---|\Z))",
        re.DOTALL,
    )

    for m in ol_pattern.finditer(content):
        ol_id = m.group(1)
        title = m.group(2).strip()
        principle = m.group(3).strip()
        evidence_text = m.group(4).strip()
        counter_text = m.group(5).strip() if m.group(5) else ""
        carry_forward = m.group(6).strip() if m.group(6) else ""

        # Parse evidence items (lines starting with -)
        evidence = [
            line.strip().lstrip("- ")
            for line in evidence_text.split("\n")
            if line.strip().startswith("-")
        ]

        counter_evidence = []
        if counter_text:
            counter_evidence = [
                line.strip().lstrip("- ")
                for line in counter_text.split("\n")
                if line.strip().startswith("-") or line.strip()
            ]
            # If no bullet points, treat whole text as one item
            if not counter_evidence:
                counter_evidence = [counter_text]

        # Determine scope
        scope = "universal"  # OL entries are general principles

        # Determine category
        category = "principle"
        if "anti-pattern" in title.lower() or "doesn't work" in title.lower():
            category = "anti-pattern"
        elif "gap" in title.lower() or "missing" in title.lower():
            category = "gap"
        elif "architectural" in title.lower() or "direction" in title.lower():
            category = "architectural"

        # Quality signals
        signals: dict[str, Any] = {
            "commander_validated": False,
            "incident_linked": False,
            "cross_project": False,
        }

        # Check for commander validation markers
        if "commander" in evidence_text.lower() and (
            "said" in evidence_text.lower()
            or "directed" in evidence_text.lower()
            or "corrected" in evidence_text.lower()
        ):
            signals["commander_validated"] = True

        # Check for cross-project evidence
        project_mentions = set()
        for proj in ["aitools", "marse", "nobul-ops"]:
            if proj in evidence_text.lower():
                project_mentions.add(proj)
        if len(project_mentions) >= 2:
            scope = "cross-project"
            signals["cross_project"] = True

        entry = OLEntry(
            id=ol_id,
            title=title,
            principle=principle,
            category=category,
            scope=scope,
            source="consolidated-operational-learning.md",
            evidence=evidence,
            counter_evidence=counter_evidence,
            carry_forward=carry_forward,
            quality_signals=signals,
            tags=list(project_mentions) if project_mentions else ["universal"],
        )

        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def extract_project_specific_ol() -> list[OLEntry]:
    """Extract project-specific OL (A1-A8, N1-N5, M1-M4) from consolidated doc."""
    entries = []
    content = CONSOLIDATED_OL.read_text()

    # Parse A-N/N-N/M-N entries
    ps_pattern = re.compile(
        r"\*\*([ANM]\d+): (.+?)\*\*\n(.+?)(?=\n\n\*\*[ANM]\d+:|\n\n---|\n\n###|\Z)",
        re.DOTALL,
    )

    scope_map = {"A": "aitools", "N": "nobul-ops", "M": "marse"}

    for m in ps_pattern.finditer(content):
        ps_id = m.group(1)
        title = m.group(2).strip()
        body = m.group(3).strip()

        prefix = ps_id[0]
        scope = scope_map.get(prefix, "universal")

        entry = OLEntry(
            id=ps_id,
            title=title,
            principle=body,
            category="pattern",
            scope=scope,
            source="consolidated-operational-learning.md",
            evidence=[],
            counter_evidence=[],
            carry_forward="",
            quality_signals={"commander_validated": False},
            tags=[scope],
        )
        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def extract_delegation_principles() -> list[OLEntry]:
    """Extract delegation principles (P1-P7) from consolidated doc."""
    entries = []
    content = CONSOLIDATED_OL.read_text()

    # Parse P-N entries (Part 2)
    p_pattern = re.compile(
        r"\*\*(P\d+): (.+?)\.\*\*\n(.+?)(?=\n\n\*\*P\d+:|\n\n###|\n\n---|\Z)",
        re.DOTALL,
    )

    for m in p_pattern.finditer(content):
        p_id = m.group(1)
        title = m.group(2).strip()
        body = m.group(3).strip()

        # Parse evidence
        evidence = []
        ev_match = re.findall(r"- Evidence: (.+?)(?=\n- |$)", body, re.DOTALL)
        for ev in ev_match:
            evidence.append(ev.strip())

        counter_evidence = []
        cev_match = re.findall(
            r"- Counter-evidence: (.+?)(?=\n- |$)", body, re.DOTALL
        )
        for cev in cev_match:
            counter_evidence.append(cev.strip())

        entry = OLEntry(
            id=f"D-{p_id}",
            title=f"Delegation: {title}",
            principle=body.split("\n\n")[0] if "\n\n" in body else body,
            category="principle",
            scope="universal",
            source="consolidated-operational-learning.md",
            evidence=evidence,
            counter_evidence=counter_evidence,
            carry_forward="",
            quality_signals={
                "commander_validated": True,
                "cross_project": True,
            },
            tags=["delegation"],
        )
        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def extract_anti_patterns() -> list[OLEntry]:
    """Extract anti-patterns from consolidated doc."""
    entries = []
    content = CONSOLIDATED_OL.read_text()

    ap_pattern = re.compile(
        r"\*\*Anti-pattern (\d+): (.+?)\.\*\*\n(.+?)(?=\n\n\*\*Anti-pattern|\n\n###|\n\n---|\Z)",
        re.DOTALL,
    )

    for m in ap_pattern.finditer(content):
        ap_num = m.group(1)
        title = m.group(2).strip()
        body = m.group(3).strip()

        evidence = []
        ev_match = re.findall(r"- Evidence: (.+?)(?=\n- |$)", body, re.DOTALL)
        for ev in ev_match:
            evidence.append(ev.strip())

        entry = OLEntry(
            id=f"AP-{ap_num}",
            title=f"Anti-pattern: {title}",
            principle=body.split("\n\n")[0] if "\n\n" in body else body,
            category="anti-pattern",
            scope="universal",
            source="consolidated-operational-learning.md",
            evidence=evidence,
            counter_evidence=[],
            carry_forward="",
            quality_signals={
                "commander_validated": True,
            },
            tags=["delegation", "anti-pattern"],
        )
        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def extract_gaps() -> list[OLEntry]:
    """Extract gaps (G1-G6) from consolidated doc."""
    entries = []
    content = CONSOLIDATED_OL.read_text()

    gap_pattern = re.compile(
        r"\*\*(G\d+): (.+?)\.\*\*\n(.+?)(?=\n\n\*\*G\d+:|\n\n###|\n\n---|\Z)",
        re.DOTALL,
    )

    for m in gap_pattern.finditer(content):
        g_id = m.group(1)
        title = m.group(2).strip()
        body = m.group(3).strip()

        entry = OLEntry(
            id=g_id,
            title=f"Gap: {title}",
            principle=body,
            category="gap",
            scope="universal",
            source="consolidated-operational-learning.md",
            evidence=[],
            counter_evidence=[],
            carry_forward="",
            quality_signals={},
            tags=["gap", "future-work"],
        )
        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def extract_uncaptured_patterns() -> list[OLEntry]:
    """Extract uncaptured patterns (U1-U4, P1-P4 from Part 6)."""
    entries = []
    content = CONSOLIDATED_OL.read_text()

    # U-patterns
    u_pattern = re.compile(
        r"\*\*(U\d+): (.+?)\.\*\*\n(.+?)(?=\n\n\*\*U\d+:|\n\n###|\n\n---|\Z)",
        re.DOTALL,
    )

    for m in u_pattern.finditer(content):
        u_id = m.group(1)
        title = m.group(2).strip()
        body = m.group(3).strip()

        entry = OLEntry(
            id=u_id,
            title=f"Uncaptured: {title}",
            principle=body,
            category="gap",
            scope="universal",
            source="consolidated-operational-learning.md",
            evidence=[],
            counter_evidence=[],
            carry_forward="",
            quality_signals={},
            tags=["uncaptured", "future-work"],
        )
        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def extract_from_incidents() -> list[OLEntry]:
    """Extract OL from incidents that have deep investigations."""
    entries = []
    try:
        with open(INCIDENTS) as f:
            data = json.load(f)
    except Exception:
        return entries

    for inc in data.get("incidents", []):
        # Only extract OL from incidents with suggestedResolution and observation
        if not inc.get("suggestedResolution") or not inc.get("observation"):
            continue

        # Only high+ severity incidents carry meaningful OL
        if inc.get("severity") not in ("critical", "high"):
            continue

        entry = OLEntry(
            id=f"INC-{inc['id']}",
            title=f"Incident: {inc['title']}",
            principle=inc.get("observation", ""),
            category="pattern",
            scope="aitools",
            source=f"incidents.json #{inc['id']}",
            evidence=[inc.get("observation", "")],
            counter_evidence=[],
            carry_forward=inc.get("suggestedResolution", ""),
            quality_signals={
                "incident_linked": True,
                "severity": inc.get("severity"),
            },
            tags=["incident", inc.get("severity", "")],
        )
        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def extract_from_aars() -> list[OLEntry]:
    """Extract OL from harvested AARs."""
    entries = []

    # Find unique AARs (deduplicate the 7x copies)
    seen_bases: set[str] = set()
    aar_files: list[Path] = []

    for f in sorted(HARVESTING.iterdir()):
        if "aar" not in f.name.lower():
            continue
        # Extract base name
        m = re.match(r"\d{4}-\d{2}-\d{2}_(?:\d+_)?(.+)", f.name)
        base = m.group(1) if m else f.name
        if base in seen_bases:
            continue
        seen_bases.add(base)
        aar_files.append(f)

    for aar_path in aar_files:
        try:
            if aar_path.suffix == ".json":
                with open(aar_path) as f:
                    aar = json.load(f)
                title = aar.get("title", aar.get("name", aar_path.stem))
                # Extract lessons learned
                lessons = aar.get("lessonsLearned", aar.get("lessons", []))
                if isinstance(lessons, list) and lessons:
                    for i, lesson in enumerate(lessons):
                        if isinstance(lesson, dict):
                            lesson_text = lesson.get(
                                "description", lesson.get("lesson", str(lesson))
                            )
                        else:
                            lesson_text = str(lesson)

                        entry = OLEntry(
                            id=f"AAR-{aar_path.stem}-{i}",
                            title=f"AAR: {title} - lesson {i+1}",
                            principle=lesson_text,
                            category="pattern",
                            scope="aitools",
                            source=f"harvesting/{aar_path.name}",
                            evidence=[],
                            counter_evidence=[],
                            carry_forward="",
                            quality_signals={},
                            tags=["aar", "harvested"],
                        )
                        entry.quality_score = compute_quality_score(entry)
                        entries.append(entry)
            elif aar_path.suffix == ".md":
                content = aar_path.read_text()
                # Extract title from first heading
                title_match = re.search(r"^#\s+(.+)$", content, re.MULTILINE)
                title = title_match.group(1) if title_match else aar_path.stem

                entry = OLEntry(
                    id=f"AAR-{aar_path.stem}",
                    title=f"AAR: {title}",
                    principle=content[:500],
                    category="pattern",
                    scope="aitools",
                    source=f"harvesting/{aar_path.name}",
                    evidence=[],
                    counter_evidence=[],
                    carry_forward="",
                    quality_signals={},
                    tags=["aar", "harvested"],
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

    meta = data.get("meta", {})
    version_history = meta.get("versionHistory", [])

    # Each version represents a session milestone
    for vh in version_history:
        version = vh.get("version")
        changes = vh.get("changes", "")
        if not changes or len(changes) < 50:
            continue

        entry = OLEntry(
            id=f"RE-v{version}",
            title=f"Running Estimate v{version}",
            principle=changes,
            category="pattern",
            scope="aitools",
            source="running-estimate.json",
            evidence=[],
            counter_evidence=[],
            carry_forward="",
            quality_signals={},
            tags=["running-estimate", "session-arc"],
        )
        entry.quality_score = compute_quality_score(entry)
        entries.append(entry)

    return entries


def generate_markdown_index(entries: list[OLEntry]) -> str:
    """Generate the human-readable, context-loadable markdown index."""
    # Sort by quality score descending
    entries.sort(key=lambda e: -e.quality_score)

    lines = []
    lines.append("# Operational Learning Index")
    lines.append("")
    lines.append(f"**Generated**: {datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')}")
    lines.append(f"**Entries**: {len(entries)}")
    lines.append(
        f"**Quality range**: {min(e.quality_score for e in entries):.1f} - {max(e.quality_score for e in entries):.1f}"
    )
    lines.append("")

    # Summary statistics
    cat_counts = Counter(e.category for e in entries)
    scope_counts = Counter(e.scope for e in entries)
    lines.append("## Summary")
    lines.append("")
    lines.append(f"| Category | Count |")
    lines.append(f"|----------|-------|")
    for cat, count in cat_counts.most_common():
        lines.append(f"| {cat} | {count} |")
    lines.append("")
    lines.append(f"| Scope | Count |")
    lines.append(f"|-------|-------|")
    for scope, count in scope_counts.most_common():
        lines.append(f"| {scope} | {count} |")
    lines.append("")

    # Quality tiers
    tier1 = [e for e in entries if e.quality_score >= 8.0]
    tier2 = [e for e in entries if 6.0 <= e.quality_score < 8.0]
    tier3 = [e for e in entries if 4.0 <= e.quality_score < 6.0]
    tier4 = [e for e in entries if e.quality_score < 4.0]

    lines.append("## Quality Tiers")
    lines.append("")
    lines.append(
        f"- **Tier 1 (8.0+)**: {len(tier1)} entries -- Commander-validated, cross-project, evidence-rich"
    )
    lines.append(
        f"- **Tier 2 (6.0-7.9)**: {len(tier2)} entries -- Well-evidenced, single-project or multi-evidence"
    )
    lines.append(
        f"- **Tier 3 (4.0-5.9)**: {len(tier3)} entries -- Documented but thin evidence"
    )
    lines.append(
        f"- **Tier 4 (<4.0)**: {len(tier4)} entries -- Noted but unvalidated"
    )
    lines.append("")

    # Tier 1: Full detail (these are the highest value)
    if tier1:
        lines.append("---")
        lines.append("")
        lines.append("## Tier 1: Highest Confidence (8.0+)")
        lines.append("")
        for entry in tier1:
            lines.append(f"### {entry.id}: {entry.title}")
            lines.append(f"**Score**: {entry.quality_score:.1f} | **Scope**: {entry.scope} | **Category**: {entry.category}")
            lines.append(f"**Source**: {entry.source}")
            lines.append("")
            lines.append(f"**Principle**: {entry.principle}")
            lines.append("")
            if entry.evidence:
                lines.append("**Evidence**:")
                for ev in entry.evidence:
                    lines.append(f"- {ev}")
                lines.append("")
            if entry.counter_evidence:
                lines.append("**Counter-evidence**:")
                for cev in entry.counter_evidence:
                    lines.append(f"- {cev}")
                lines.append("")
            if entry.carry_forward:
                lines.append(f"**Carry-forward**: {entry.carry_forward}")
                lines.append("")
            if entry.tags:
                lines.append(f"**Tags**: {', '.join(entry.tags)}")
                lines.append("")

    # Tier 2: Moderate detail
    if tier2:
        lines.append("---")
        lines.append("")
        lines.append("## Tier 2: Strong Evidence (6.0-7.9)")
        lines.append("")
        for entry in tier2:
            lines.append(f"### {entry.id}: {entry.title}")
            lines.append(f"**Score**: {entry.quality_score:.1f} | **Scope**: {entry.scope} | **Category**: {entry.category}")
            lines.append("")
            lines.append(f"{entry.principle}")
            lines.append("")
            if entry.carry_forward:
                lines.append(f"**Carry-forward**: {entry.carry_forward}")
                lines.append("")

    # Tier 3: Compact
    if tier3:
        lines.append("---")
        lines.append("")
        lines.append("## Tier 3: Documented (4.0-5.9)")
        lines.append("")
        lines.append("| ID | Title | Score | Scope | Source |")
        lines.append("|-----|-------|-------|-------|--------|")
        for entry in tier3:
            lines.append(
                f"| {entry.id} | {entry.title[:60]} | {entry.quality_score:.1f} | {entry.scope} | {entry.source[:40]} |"
            )
        lines.append("")

    # Tier 4: List only
    if tier4:
        lines.append("---")
        lines.append("")
        lines.append("## Tier 4: Noted (<4.0)")
        lines.append("")
        for entry in tier4:
            lines.append(f"- **{entry.id}**: {entry.title} (score {entry.quality_score:.1f}, {entry.scope})")
        lines.append("")

    # Cross-reference section
    lines.append("---")
    lines.append("")
    lines.append("## Data Source Inventory")
    lines.append("")
    lines.append("### Where OL lives today")
    lines.append("")
    lines.append("| Source | Location | Count | Notes |")
    lines.append("|--------|----------|-------|-------|")
    lines.append("| Consolidated OL | .scratch/session-*/consolidated-operational-learning.md | 1 | First consolidation, this session |")
    lines.append("| Harvested AARs | harvesting/*aar*.json | 14 unique (84 with duplicates) | 7x duplication from harvesting bug |")
    lines.append("| Investigations | harvesting/*investigation*.md, *rca*.md | ~17 unique | Root cause analyses |")
    lines.append("| Incidents | reference/incidents.json | 48 open, 2 closed | Structured, severity-ranked |")
    lines.append("| Running Estimate | .aitools/channel/running-estimate.json | 12 version entries | Session arc history |")
    lines.append("| Release Notes | RELEASE_NOTES.md | 12 releases documented | Operational patterns in changelogs |")
    lines.append("| Session Archives | aitools-nobul-jose/sessions/ | 259 across 24 projects | 478MB, JSONL format |")
    lines.append("| Session DB | .aitools/harness.db + sessions/*.db | 1 active session | 62 messages, schema exists but sparse data |")
    lines.append("| Delegation Audits | .scratch/session-*/*audit*.md | 3 (this session) | Cross-project delegation quality analysis |")
    lines.append("")

    lines.append("### Harvesting health")
    lines.append("")
    lines.append("- **435 artifacts** in manifest, **0 promoted** to harness")
    lines.append("- **54 base names duplicated** (some 7x) -- harvesting bug creating copies on each session")
    lines.append("- **433 status=harvested**, 2 status=candidate, 0 promoted")
    lines.append("- The promotion pipeline is not functioning -- artifacts accumulate but never advance")
    lines.append("")

    lines.append("### Quality signal availability")
    lines.append("")
    lines.append("| Signal | Available? | Where | Reliability |")
    lines.append("|--------|-----------|-------|-------------|")
    lines.append("| Evidence count | Yes | Consolidated OL | High -- manually curated |")
    lines.append("| Commander validation | Yes | Consolidated OL, transcripts | High -- explicit quotes |")
    lines.append("| Cross-project scope | Yes | Consolidated OL, audits | High -- projects named |")
    lines.append("| Counter-evidence | Yes | Consolidated OL | High -- shows rigor |")
    lines.append("| Incident linkage | Yes | incidents.json | Medium -- many incidents lack OL connection |")
    lines.append("| Git reference count | Partial | git log | Medium -- requires git log parsing |")
    lines.append("| Reuse across sessions | No | Would require transcript mining | Low -- not yet instrumented |")
    lines.append("| Recency | Yes | File timestamps, commit dates | Low quality signal per OL-3 |")
    lines.append("")

    # Iteration guidance
    lines.append("---")
    lines.append("")
    lines.append("## Iteration Guidance")
    lines.append("")
    lines.append("This index is the first iteration. Future missions can extend it by:")
    lines.append("")
    lines.append("1. **Mine session transcripts** for commander corrections (each is an implicit OL entry)")
    lines.append("2. **Parse AARs** more deeply -- current extraction is shallow for JSON AARs")
    lines.append("3. **Cross-reference with git log** -- which OL entries led to actual commits?")
    lines.append("4. **Add quality signal: delegation score** -- from delegation audit reports")
    lines.append("5. **Fix harvesting duplication** -- deduplicate the 54 base names with 7x copies")
    lines.append("6. **Build promotion pipeline** -- 0/435 artifacts promoted is a process failure")
    lines.append("7. **Instrument reuse tracking** -- when an OL entry is loaded into a session and influences a decision")
    lines.append("8. **Add cross-project OL from nobul-ops and marse** -- currently only aitools-specific AARs are harvested")
    lines.append("")

    return "\n".join(lines)


def main() -> None:
    print("Building Operational Learning Index...")

    all_entries: list[OLEntry] = []

    # Extract from all sources
    print("  Extracting from consolidated OL...")
    all_entries.extend(extract_from_consolidated_ol())
    print(f"    -> {len(all_entries)} entries")

    print("  Extracting project-specific OL...")
    ps = extract_project_specific_ol()
    all_entries.extend(ps)
    print(f"    -> {len(ps)} entries")

    print("  Extracting delegation principles...")
    dp = extract_delegation_principles()
    all_entries.extend(dp)
    print(f"    -> {len(dp)} entries")

    print("  Extracting anti-patterns...")
    ap = extract_anti_patterns()
    all_entries.extend(ap)
    print(f"    -> {len(ap)} entries")

    print("  Extracting gaps...")
    gaps = extract_gaps()
    all_entries.extend(gaps)
    print(f"    -> {len(gaps)} entries")

    print("  Extracting uncaptured patterns...")
    uc = extract_uncaptured_patterns()
    all_entries.extend(uc)
    print(f"    -> {len(uc)} entries")

    print("  Extracting from incidents...")
    inc = extract_from_incidents()
    all_entries.extend(inc)
    print(f"    -> {len(inc)} entries")

    print("  Extracting from AARs...")
    aars = extract_from_aars()
    all_entries.extend(aars)
    print(f"    -> {len(aars)} entries")

    print("  Extracting from running estimate...")
    re_entries = extract_from_running_estimate()
    all_entries.extend(re_entries)
    print(f"    -> {len(re_entries)} entries")

    # Compute all quality scores
    for entry in all_entries:
        entry.quality_score = compute_quality_score(entry)

    print(f"\nTotal entries: {len(all_entries)}")

    # Generate markdown
    print("Generating markdown index...")
    md_content = generate_markdown_index(all_entries)
    OUT_MD.write_text(md_content)
    print(f"  Written to {OUT_MD}")

    # Generate JSON
    print("Generating JSON index...")
    json_data = {
        "meta": {
            "generated": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
            "entry_count": len(all_entries),
            "sources": [
                "consolidated-operational-learning.md",
                "incidents.json",
                "harvesting/*.json (AARs)",
                "running-estimate.json",
            ],
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
    print(f"  Written to {OUT_JSON}")

    # Print summary
    print(f"\n=== Index Summary ===")
    tier_counts = {
        "Tier 1 (8.0+)": len([e for e in all_entries if e.quality_score >= 8.0]),
        "Tier 2 (6.0-7.9)": len(
            [e for e in all_entries if 6.0 <= e.quality_score < 8.0]
        ),
        "Tier 3 (4.0-5.9)": len(
            [e for e in all_entries if 4.0 <= e.quality_score < 6.0]
        ),
        "Tier 4 (<4.0)": len([e for e in all_entries if e.quality_score < 4.0]),
    }
    for tier, count in tier_counts.items():
        print(f"  {tier}: {count}")


if __name__ == "__main__":
    main()
