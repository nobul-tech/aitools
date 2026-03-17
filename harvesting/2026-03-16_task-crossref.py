#!/usr/bin/env python3
"""Cross-reference integrity audit for aitools harness files.

Scans rules, CLAUDE.md, skills, and reference docs for:
1. @-references (e.g., @reference/foo.md) -- checks if target exists
2. Backtick file paths (e.g., `reference/foo.md`) -- checks if target exists
3. Skill references (e.g., `/tool-registry` skill) -- checks if skill dir exists

Output: JSON list of broken references.
"""

import json
import os
import re
import sys
from pathlib import Path

REPO = Path("/Users/pepe/repos/aitools")

# Files to scan
SCAN_DIRS = [
    REPO / ".claude" / "rules",
    REPO / ".claude" / "skills",
    REPO / "reference",
]
SCAN_FILES = [
    REPO / "CLAUDE.md",
    REPO / "ROADMAP.md",
]

# Patterns
# @-references: @reference/foo.md, @.claude/rules/bar.md, @scripts/baz.sh
AT_REF = re.compile(r'@((?:reference|\.claude|scripts|shared|plans|rfcs|\.cursor|deploy)/[^\s),`\'">\]|]+)')

# Backtick file paths that look like repo-relative paths
BACKTICK_PATH = re.compile(r'`((?:reference|\.claude|scripts|shared|plans|rfcs|\.cursor|deploy|harvesting|CLAUDE\.md|ROADMAP\.md|RELEASE_NOTES\.md|README\.md)[^\s`]*)`')

# Skill directory references: `/tool-registry` skill, `/incident` skill
SKILL_REF = re.compile(r'`/([a-z][a-z0-9-]+)`\s+skill')

findings = []

def check_path(ref_path: str, source_file: str, line_no: int, ref_type: str):
    """Check if a referenced path exists in the repo."""
    # Strip trailing punctuation that might have been captured
    ref_path = ref_path.rstrip('.,;:)')

    # Skip if it's a URL fragment or placeholder
    if ref_path.startswith('http') or '{{' in ref_path:
        return

    # Handle paths with wildcards -- skip those
    if '*' in ref_path:
        return

    target = REPO / ref_path
    if not target.exists():
        findings.append({
            "type": ref_type,
            "reference": ref_path,
            "source_file": str(source_file),
            "line": line_no,
            "status": "MISSING",
        })


def check_skill(skill_name: str, source_file: str, line_no: int):
    """Check if a skill directory exists."""
    # Check both project-level and user-level skill locations
    project_skill = REPO / ".claude" / "skills" / skill_name / "SKILL.md"
    shared_skill = REPO / "shared" / "skills" / skill_name / "SKILL.md"

    if not project_skill.exists() and not shared_skill.exists():
        findings.append({
            "type": "skill_reference",
            "reference": f"/{ skill_name}",
            "source_file": str(source_file),
            "line": line_no,
            "status": "MISSING",
        })


def scan_file(filepath: Path):
    """Scan a single file for cross-references."""
    if not filepath.exists():
        return
    if filepath.suffix not in ('.md', '.mdc', '.json'):
        return
    # Skip binary/large files
    if filepath.stat().st_size > 500_000:
        return

    try:
        text = filepath.read_text(encoding='utf-8', errors='replace')
    except Exception:
        return

    rel_source = str(filepath.relative_to(REPO))

    for i, line in enumerate(text.splitlines(), 1):
        # @-references
        for match in AT_REF.finditer(line):
            check_path(match.group(1), rel_source, i, "@-reference")

        # Backtick paths
        for match in BACKTICK_PATH.finditer(line):
            path_val = match.group(1)
            # Skip if it's a function call or code pattern
            if '(' in path_val or '=' in path_val:
                continue
            # Skip if it's clearly a directory pattern not a file
            if path_val.endswith('/'):
                # Check as directory
                target = REPO / path_val.rstrip('/')
                if not target.exists():
                    findings.append({
                        "type": "backtick_path",
                        "reference": path_val,
                        "source_file": rel_source,
                        "line": i,
                        "status": "MISSING",
                    })
                continue
            check_path(path_val, rel_source, i, "backtick_path")

        # Skill references
        for match in SKILL_REF.finditer(line):
            check_skill(match.group(1), rel_source, i)


def main():
    # Scan individual files
    for f in SCAN_FILES:
        scan_file(f)

    # Scan directories recursively
    for d in SCAN_DIRS:
        if not d.exists():
            continue
        for filepath in sorted(d.rglob('*')):
            if filepath.is_file():
                scan_file(filepath)

    # Also scan .cursor/rules
    cursor_rules = REPO / ".cursor" / "rules"
    if cursor_rules.exists():
        for filepath in sorted(cursor_rules.rglob('*')):
            if filepath.is_file():
                scan_file(filepath)

    # Deduplicate
    seen = set()
    unique = []
    for f in findings:
        key = (f["type"], f["reference"], f["source_file"], f["line"])
        if key not in seen:
            seen.add(key)
            unique.append(f)

    # Sort by source file, then line
    unique.sort(key=lambda x: (x["source_file"], x["line"]))

    # Output
    print(json.dumps(unique, indent=2))
    print(f"\n--- Total broken references: {len(unique)} ---", file=sys.stderr)


if __name__ == "__main__":
    main()
