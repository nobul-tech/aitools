#!/usr/bin/env python3
"""Build ~/.aitools/knowledge.db -- FTS5 full-text search over all work product.

Scans: session transcripts, plans, reference docs, rules, harvested artifacts,
git log, release notes, operational learning, running estimate, incidents.

Uses stdlib sqlite3 only (no sqlite-utils dependency). FTS5 is built into
standard Python sqlite3.

Reuses patterns from build-ol-index-v2.py: section parsing, quality scoring,
project detection, OL extraction.
"""

import json
import os
import re
import sqlite3
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

# === Paths ===
HOME = Path.home()
AITOOLS = HOME / "repos" / "aitools"
DOTPROFILE = HOME / "repos" / "aitools-nobul-jose"
NOBUL_OPS = HOME / "repos" / "nobul-ops"
MARSE = HOME / "repos" / "marse"
DB_PATH = HOME / ".aitools" / "knowledge.db"

HARVESTING = AITOOLS / "harvesting"
PLANS = AITOOLS / "plans"
REFERENCE = AITOOLS / "reference"
RULES = AITOOLS / ".claude" / "rules"
SESSIONS = DOTPROFILE / "sessions"
INCIDENTS = REFERENCE / "incidents.json"
RUNNING_ESTIMATE = AITOOLS / ".aitools" / "channel" / "running-estimate.json"
RELEASE_NOTES = AITOOLS / "RELEASE_NOTES.md"

# Repos to scan git log from
REPOS = {
    "aitools": AITOOLS,
    "nobul-ops": NOBUL_OPS,
    "marse": MARSE,
}


def create_db(db_path: Path) -> sqlite3.Connection:
    """Create the knowledge database with FTS5."""
    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()

    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")

    # Main documents table
    conn.execute("""
        CREATE TABLE documents (
            id TEXT PRIMARY KEY,
            repo TEXT NOT NULL,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL,
            date TEXT,
            project TEXT,
            quality_score REAL DEFAULT 0.0,
            source_path TEXT,
            meta TEXT
        )
    """)

    # FTS5 virtual table for full-text search
    conn.execute("""
        CREATE VIRTUAL TABLE documents_fts USING fts5(
            title,
            body,
            content='documents',
            content_rowid='rowid',
            tokenize='porter unicode61'
        )
    """)

    # Triggers to keep FTS in sync
    conn.execute("""
        CREATE TRIGGER documents_ai AFTER INSERT ON documents BEGIN
            INSERT INTO documents_fts(rowid, title, body)
            VALUES (new.rowid, new.title, new.body);
        END
    """)
    conn.execute("""
        CREATE TRIGGER documents_ad AFTER DELETE ON documents BEGIN
            INSERT INTO documents_fts(documents_fts, rowid, title, body)
            VALUES ('delete', old.rowid, old.title, old.body);
        END
    """)
    conn.execute("""
        CREATE TRIGGER documents_au AFTER UPDATE ON documents BEGIN
            INSERT INTO documents_fts(documents_fts, rowid, title, body)
            VALUES ('delete', old.rowid, old.title, old.body);
            INSERT INTO documents_fts(rowid, title, body)
            VALUES (new.rowid, new.title, new.body);
        END
    """)

    # Tags table
    conn.execute("""
        CREATE TABLE tags (
            doc_id TEXT NOT NULL,
            tag TEXT NOT NULL,
            FOREIGN KEY (doc_id) REFERENCES documents(id)
        )
    """)
    conn.execute("CREATE INDEX idx_tags_doc ON tags(doc_id)")
    conn.execute("CREATE INDEX idx_tags_tag ON tags(tag)")

    # Provenance table (future use)
    conn.execute("""
        CREATE TABLE provenance (
            source_id TEXT NOT NULL,
            target_id TEXT NOT NULL,
            relation TEXT NOT NULL,
            confidence REAL DEFAULT 1.0,
            FOREIGN KEY (source_id) REFERENCES documents(id),
            FOREIGN KEY (target_id) REFERENCES documents(id)
        )
    """)

    # Build metadata
    conn.execute("""
        CREATE TABLE build_meta (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    """)

    conn.commit()
    return conn


def insert_doc(
    conn: sqlite3.Connection,
    doc_id: str,
    repo: str,
    doc_type: str,
    title: str,
    body: str,
    date: Optional[str] = None,
    project: Optional[str] = None,
    quality_score: float = 0.0,
    source_path: Optional[str] = None,
    meta: Optional[dict] = None,
    tags: Optional[list[str]] = None,
) -> None:
    """Insert a document and its tags."""
    # Truncate body to 100KB to keep DB manageable
    if len(body) > 100_000:
        body = body[:100_000] + "\n\n[TRUNCATED]"

    conn.execute(
        """INSERT OR REPLACE INTO documents
           (id, repo, type, title, body, date, project, quality_score, source_path, meta)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            doc_id,
            repo,
            doc_type,
            title,
            body,
            date,
            project,
            quality_score,
            source_path,
            json.dumps(meta) if meta else None,
        ),
    )
    if tags:
        for tag in tags:
            conn.execute(
                "INSERT INTO tags (doc_id, tag) VALUES (?, ?)", (doc_id, tag)
            )


# === Scanners ===


def scan_markdown_files(conn: sqlite3.Connection, directory: Path, repo: str, doc_type: str) -> int:
    """Scan markdown files, splitting on ## headings into sections."""
    count = 0
    if not directory.exists():
        return 0

    for f in sorted(directory.rglob("*.md")):
        try:
            content = f.read_text(errors="replace")
        except Exception:
            continue

        rel = str(f.relative_to(directory))
        # Extract date from filename if present
        date_match = re.match(r"(\d{4}-\d{2}-\d{2})", f.name)
        date = date_match.group(1) if date_match else None

        # Get top-level title
        title_match = re.search(r"^#\s+(.+)$", content, re.MULTILINE)
        file_title = title_match.group(1) if title_match else f.stem

        # Insert whole file as one document
        doc_id = f"{repo}:{doc_type}:{rel}"
        insert_doc(
            conn,
            doc_id=doc_id,
            repo=repo,
            doc_type=doc_type,
            title=file_title,
            body=content,
            date=date,
            project=detect_project(content),
            source_path=str(f),
            tags=detect_tags(content, doc_type),
        )
        count += 1

        # Also insert each ## section as a separate searchable document
        sections = re.split(r"^(##\s+.+)$", content, flags=re.MULTILINE)
        sec_idx = 0
        for i in range(1, len(sections), 2):
            heading = sections[i].lstrip("#").strip()
            body = sections[i + 1] if i + 1 < len(sections) else ""
            if len(body.strip()) < 30:
                continue
            sec_idx += 1
            sec_id = f"{doc_id}:s{sec_idx}"
            insert_doc(
                conn,
                doc_id=sec_id,
                repo=repo,
                doc_type=f"{doc_type}-section",
                title=f"{file_title} > {heading}",
                body=body.strip(),
                date=date,
                project=detect_project(body),
                source_path=str(f),
                tags=detect_tags(body, doc_type),
            )
            count += 1

    return count


def scan_json_files(conn: sqlite3.Connection, directory: Path, repo: str, doc_type: str) -> int:
    """Scan JSON files, indexing structured content."""
    count = 0
    if not directory.exists():
        return 0

    for f in sorted(directory.rglob("*.json")):
        try:
            with open(f) as fh:
                data = json.load(fh)
        except Exception:
            continue

        rel = str(f.relative_to(directory))
        doc_id = f"{repo}:{doc_type}:{rel}"

        # Convert JSON to searchable text
        body = json_to_text(data)
        if len(body.strip()) < 20:
            continue

        title = f.stem
        if isinstance(data, dict):
            title = data.get("title", data.get("name", f.stem))

        insert_doc(
            conn,
            doc_id=doc_id,
            repo=repo,
            doc_type=doc_type,
            title=str(title),
            body=body,
            source_path=str(f),
            tags=detect_tags(body, doc_type),
        )
        count += 1

    return count


def json_to_text(data: Any, depth: int = 0) -> str:
    """Recursively convert JSON to searchable text."""
    if depth > 5:
        return ""
    if isinstance(data, str):
        return data
    if isinstance(data, (int, float, bool)):
        return str(data)
    if isinstance(data, list):
        parts = []
        for item in data[:50]:  # Limit array processing
            parts.append(json_to_text(item, depth + 1))
        return "\n".join(parts)
    if isinstance(data, dict):
        parts = []
        for k, v in data.items():
            if k in ("meta", "schema", "version"):
                continue
            text = json_to_text(v, depth + 1)
            if text.strip():
                parts.append(f"{k}: {text}")
        return "\n".join(parts)
    return ""


def scan_harvested_artifacts(conn: sqlite3.Connection) -> int:
    """Scan harvesting/ directory -- JSON AARs and other artifacts."""
    count = 0
    if not HARVESTING.exists():
        return 0

    seen_bases: set[str] = set()
    for f in sorted(HARVESTING.iterdir()):
        # Deduplicate by base name (handles the 7x duplication bug)
        m = re.match(r"\d{4}-\d{2}-\d{2}_(?:\d+_)?(.+)", f.name)
        base = m.group(1) if m else f.name
        if base in seen_bases:
            continue
        seen_bases.add(base)

        date_match = re.match(r"(\d{4}-\d{2}-\d{2})", f.name)
        date = date_match.group(1) if date_match else None

        try:
            if f.suffix == ".json":
                with open(f) as fh:
                    data = json.load(fh)
                title = str(data.get("title", data.get("name", f.stem))) if isinstance(data, dict) else f.stem
                body = json_to_text(data)
                tags = ["artifact"]
                if "aar" in f.name.lower():
                    tags.append("aar")

                doc_id = f"aitools:artifact:{base}"
                insert_doc(
                    conn,
                    doc_id=doc_id,
                    repo="aitools",
                    doc_type="artifact",
                    title=title,
                    body=body,
                    date=date,
                    source_path=str(f),
                    tags=tags,
                )
                count += 1

            elif f.suffix == ".md":
                content = f.read_text(errors="replace")
                title_match = re.search(r"^#\s+(.+)$", content, re.MULTILINE)
                title = title_match.group(1) if title_match else f.stem

                doc_id = f"aitools:artifact:{base}"
                insert_doc(
                    conn,
                    doc_id=doc_id,
                    repo="aitools",
                    doc_type="artifact",
                    title=title,
                    body=content,
                    date=date,
                    source_path=str(f),
                    tags=["artifact"],
                )
                count += 1

            elif f.suffix in (".py", ".sh", ".html"):
                content = f.read_text(errors="replace")
                doc_id = f"aitools:artifact:{base}"
                insert_doc(
                    conn,
                    doc_id=doc_id,
                    repo="aitools",
                    doc_type="artifact",
                    title=f.stem,
                    body=content[:50_000],
                    date=date,
                    source_path=str(f),
                    tags=["artifact", f.suffix.lstrip(".")],
                )
                count += 1

        except Exception:
            continue

    return count


def scan_session_transcripts(conn: sqlite3.Connection) -> int:
    """Scan session JSONL archives -- extract human messages and assistant text blocks."""
    count = 0
    if not SESSIONS.exists():
        return 0

    for project_dir in sorted(SESSIONS.iterdir()):
        if not project_dir.is_dir():
            continue
        project = project_dir.name

        for f in sorted(project_dir.glob("*.jsonl")):
            date_match = re.match(r"(\d{4}-\d{2}-\d{2})_(\w+)", f.name)
            date = date_match.group(1) if date_match else None
            session_id = date_match.group(2) if date_match else f.stem

            # Extract human messages and assistant text blocks
            human_messages: list[str] = []
            assistant_texts: list[str] = []

            try:
                with open(f, errors="replace") as fh:
                    for line in fh:
                        try:
                            data = json.loads(line)
                        except json.JSONDecodeError:
                            continue

                        msg_type = data.get("type")
                        if msg_type not in ("user", "assistant"):
                            continue

                        msg = data.get("message", {})
                        if not isinstance(msg, dict):
                            continue

                        role = msg.get("role", "")
                        content = msg.get("content", "")

                        if isinstance(content, str) and content.strip():
                            text = content.strip()
                        elif isinstance(content, list):
                            parts = []
                            for block in content:
                                if isinstance(block, dict):
                                    if block.get("type") == "text":
                                        parts.append(block.get("text", ""))
                                    elif block.get("type") == "tool_result":
                                        # skip tool results
                                        pass
                            text = "\n".join(parts).strip()
                        else:
                            continue

                        if not text or len(text) < 10:
                            continue

                        if role == "user":
                            # Filter out tool results
                            if data.get("toolUseResult"):
                                continue
                            human_messages.append(text)
                        elif role == "assistant":
                            assistant_texts.append(text)

            except Exception:
                continue

            if not human_messages and not assistant_texts:
                continue

            # Combine into one document per session
            all_text_parts = []
            for i, msg in enumerate(human_messages):
                all_text_parts.append(f"[Human {i+1}]: {msg[:2000]}")
            for i, msg in enumerate(assistant_texts[:20]):  # Limit assistant blocks
                all_text_parts.append(f"[Assistant {i+1}]: {msg[:2000]}")

            body = "\n\n".join(all_text_parts)

            doc_id = f"{project}:session:{session_id}"
            insert_doc(
                conn,
                doc_id=doc_id,
                repo="dotprofile",
                doc_type="session",
                title=f"Session {date} ({project})",
                body=body,
                date=date,
                project=project,
                source_path=str(f),
                meta={"human_count": len(human_messages), "assistant_count": len(assistant_texts)},
                tags=["session", project],
            )
            count += 1

    return count


def scan_git_log(conn: sqlite3.Connection) -> int:
    """Scan git log from all repos."""
    count = 0

    for repo_name, repo_path in REPOS.items():
        if not repo_path.exists():
            continue
        if not (repo_path / ".git").exists():
            continue

        try:
            result = subprocess.run(
                ["git", "-C", str(repo_path), "log", "--format=%H\t%ai\t%s\t%b", "-200"],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if result.returncode != 0:
                continue
        except Exception:
            continue

        for line in result.stdout.strip().split("\n"):
            if not line.strip():
                continue
            parts = line.split("\t", 3)
            if len(parts) < 3:
                continue
            sha = parts[0][:8]
            date = parts[1][:10]
            subject = parts[2]
            body_text = parts[3] if len(parts) > 3 else ""

            doc_id = f"{repo_name}:commit:{sha}"
            full_text = f"{subject}\n\n{body_text}" if body_text else subject
            insert_doc(
                conn,
                doc_id=doc_id,
                repo=repo_name,
                doc_type="commit",
                title=subject,
                body=full_text,
                date=date,
                project=repo_name,
                source_path=f"{repo_path}/.git",
                tags=["commit", repo_name],
            )
            count += 1

    return count


def scan_incidents(conn: sqlite3.Connection) -> int:
    """Scan incidents.json."""
    count = 0
    if not INCIDENTS.exists():
        return 0

    try:
        with open(INCIDENTS) as f:
            data = json.load(f)
    except Exception:
        return 0

    for inc in data.get("incidents", []):
        inc_id = inc.get("id", "?")
        title = inc.get("title", "Untitled")
        observation = inc.get("observation", "")
        expected = inc.get("expected", "")
        impact = inc.get("impact", "")
        resolution = inc.get("suggestedResolution", "")
        severity = inc.get("severity", "")
        status = inc.get("status", "")

        body = f"""Title: {title}
Severity: {severity}
Status: {status}
Observation: {observation}
Expected: {expected}
Impact: {impact}
Suggested Resolution: {resolution}
Affected: {', '.join(inc.get('affected', []))}"""

        doc_id = f"aitools:incident:{inc_id}"
        insert_doc(
            conn,
            doc_id=doc_id,
            repo="aitools",
            doc_type="incident",
            title=f"Incident #{inc_id}: {title}",
            body=body,
            date=inc.get("created"),
            project="aitools",
            quality_score={"critical": 9, "high": 7, "medium": 5, "low": 3}.get(severity, 3),
            source_path=str(INCIDENTS),
            meta={"severity": severity, "status": status},
            tags=["incident", severity, status],
        )
        count += 1

    # Also scan closed incidents
    for inc in data.get("closed", []):
        inc_id = inc.get("id", "?")
        title = inc.get("title", "Untitled")

        body_parts = [f"Title: {title}"]
        for field in ("observation", "expected", "impact", "correctiveAction", "rootCause"):
            val = inc.get(field, "")
            if val:
                body_parts.append(f"{field}: {val}")

        doc_id = f"aitools:incident-closed:{inc_id}"
        insert_doc(
            conn,
            doc_id=doc_id,
            repo="aitools",
            doc_type="incident",
            title=f"Closed Incident #{inc_id}: {title}",
            body="\n".join(body_parts),
            date=inc.get("closedDate", inc.get("created")),
            project="aitools",
            meta={"status": "closed"},
            tags=["incident", "closed"],
        )
        count += 1

    return count


def scan_release_notes(conn: sqlite3.Connection) -> int:
    """Scan RELEASE_NOTES.md, splitting by version."""
    count = 0
    if not RELEASE_NOTES.exists():
        return 0

    content = RELEASE_NOTES.read_text(errors="replace")
    # Split on ## vN.N.N headings
    sections = re.split(r"^(## v[\d.]+.*)$", content, flags=re.MULTILINE)

    for i in range(1, len(sections), 2):
        heading = sections[i].lstrip("#").strip()
        body = sections[i + 1] if i + 1 < len(sections) else ""
        if len(body.strip()) < 20:
            continue

        # Extract version and date
        ver_match = re.match(r"v([\d.]+)", heading)
        version = ver_match.group(1) if ver_match else heading
        date_match = re.search(r"\((\d{4}-\d{2}-\d{2})\)", heading)
        date = date_match.group(1) if date_match else None

        doc_id = f"aitools:release:v{version}"
        insert_doc(
            conn,
            doc_id=doc_id,
            repo="aitools",
            doc_type="release",
            title=heading,
            body=body.strip(),
            date=date,
            project="aitools",
            source_path=str(RELEASE_NOTES),
            tags=["release", f"v{version}"],
        )
        count += 1

    return count


def scan_running_estimate(conn: sqlite3.Connection) -> int:
    """Scan running estimate version history."""
    count = 0
    if not RUNNING_ESTIMATE.exists():
        return 0

    try:
        with open(RUNNING_ESTIMATE) as f:
            data = json.load(f)
    except Exception:
        return 0

    for vh in data.get("meta", {}).get("versionHistory", []):
        version = vh.get("version", "?")
        changes = vh.get("changes", "")
        date = vh.get("date", "")

        if len(changes) < 30:
            continue

        doc_id = f"aitools:running-estimate:v{version}"
        insert_doc(
            conn,
            doc_id=doc_id,
            repo="aitools",
            doc_type="running-estimate",
            title=f"Running Estimate v{version}",
            body=changes,
            date=date[:10] if date else None,
            project="aitools",
            source_path=str(RUNNING_ESTIMATE),
            tags=["running-estimate", "session-arc"],
        )
        count += 1

    return count


def scan_consolidated_ol(conn: sqlite3.Connection) -> int:
    """Scan the consolidated operational learning doc from this session."""
    count = 0
    scratch = AITOOLS / ".scratch" / "session-c0dc2ddc-f"
    ol_file = scratch / "consolidated-operational-learning.md"
    if not ol_file.exists():
        return 0

    content = ol_file.read_text(errors="replace")

    # Insert full doc
    insert_doc(
        conn,
        doc_id="aitools:ol:consolidated",
        repo="aitools",
        doc_type="ol",
        title="Consolidated Operational Learning",
        body=content,
        date="2026-03-25",
        project="aitools",
        quality_score=9.0,
        source_path=str(ol_file),
        tags=["ol", "consolidated", "carry-forward"],
    )
    count += 1

    # Extract OL-N principles
    sections = re.split(r"### (OL-\d+): (.+?)\n", content)
    i = 1
    while i + 2 < len(sections):
        ol_id = sections[i]
        title = sections[i + 1].strip()
        body = sections[i + 2]
        i += 3

        # Trim at next section boundary
        for boundary in ["### OL-", "## Part", "---\n"]:
            idx = body.find(boundary)
            if idx > 0:
                body = body[:idx]

        has_counter = "counter-evidence" in body.lower()
        has_commander = any(
            p in body.lower()
            for p in ["commander said", "commander directed", "commander corrected", "the commander"]
        )
        score = 5.0
        if has_counter:
            score += 1.5
        if has_commander:
            score += 1.5
        evidence_count = body.count("- ")
        score += min(evidence_count * 0.3, 2.0)

        doc_id = f"aitools:ol:{ol_id}"
        insert_doc(
            conn,
            doc_id=doc_id,
            repo="aitools",
            doc_type="ol",
            title=f"{ol_id}: {title}",
            body=body.strip(),
            date="2026-03-25",
            project="aitools",
            quality_score=min(score, 10.0),
            source_path=str(ol_file),
            tags=["ol", "principle"],
        )
        count += 1

    # Extract delegation principles (P1-P7)
    dp_sections = re.split(r"\*\*(P\d+): (.+?)\.\*\*\n", content)
    j = 1
    while j + 2 < len(dp_sections):
        p_id = dp_sections[j]
        title = dp_sections[j + 1].strip()
        body = dp_sections[j + 2]
        j += 3
        for boundary in ["\n**P", "\n### ", "\n---"]:
            idx = body.find(boundary)
            if idx > 0:
                body = body[:idx]

        doc_id = f"aitools:ol:D-{p_id}"
        insert_doc(
            conn,
            doc_id=doc_id,
            repo="aitools",
            doc_type="ol",
            title=f"Delegation: {title}",
            body=body.strip(),
            date="2026-03-25",
            project="aitools",
            quality_score=7.0,
            source_path=str(ol_file),
            tags=["ol", "delegation"],
        )
        count += 1

    return count


def scan_other_repos(conn: sqlite3.Connection) -> int:
    """Scan markdown docs from nobul-ops and marse."""
    count = 0
    for repo_name, repo_path in [("nobul-ops", NOBUL_OPS), ("marse", MARSE)]:
        if not repo_path.exists():
            continue
        # Scan top-level markdown files
        for f in sorted(repo_path.glob("*.md")):
            try:
                content = f.read_text(errors="replace")
            except Exception:
                continue
            if len(content.strip()) < 50:
                continue

            title_match = re.search(r"^#\s+(.+)$", content, re.MULTILINE)
            title = title_match.group(1) if title_match else f.stem

            doc_id = f"{repo_name}:doc:{f.name}"
            insert_doc(
                conn,
                doc_id=doc_id,
                repo=repo_name,
                doc_type="doc",
                title=title,
                body=content[:50_000],
                source_path=str(f),
                tags=["doc", repo_name],
            )
            count += 1

        # Scan .claude/rules/ if exists
        rules_dir = repo_path / ".claude" / "rules"
        if rules_dir.exists():
            count += scan_markdown_files(conn, rules_dir, repo_name, "rule")

    return count


# === Helpers ===


def detect_project(text: str) -> Optional[str]:
    """Detect which project text relates to."""
    lower = text.lower()
    projects = []
    for p in ["aitools", "marse", "nobul-ops"]:
        if p in lower:
            projects.append(p)
    if len(projects) == 1:
        return projects[0]
    if len(projects) > 1:
        return "cross-project"
    return None


def detect_tags(text: str, doc_type: str) -> list[str]:
    """Auto-detect tags from content."""
    tags = [doc_type]
    lower = text.lower()
    tag_keywords = {
        "delegation": ["delegation", "delegate", "subagent"],
        "governance": ["governance", "prevention", "detection", "audit"],
        "hook": ["hook", "prehook", "posthook", "sessionstart", "sessionend"],
        "cross-platform": ["cross-platform", "windows", "powershell", "macos"],
        "sqlite": ["sqlite", "fts5", "database"],
        "incident": ["incident", "deviation", "ambiguity"],
        "operational-learning": ["operational learning", "OL-", "carry-forward"],
    }
    for tag, keywords in tag_keywords.items():
        if any(kw in lower for kw in keywords):
            tags.append(tag)
    return tags


# === Query interface ===


def sanitize_fts_query(query: str) -> str:
    """Sanitize a user query for FTS5.

    FTS5 interprets bare words that match column names (like 'platform')
    as column filters. To prevent this, we quote each term with double quotes
    and join with spaces (implicit AND).

    Preserves explicit FTS5 operators: OR, AND, NOT, NEAR, *, "phrases".
    """
    # If user already used FTS5 syntax (quotes, OR, AND, NEAR, *), pass through
    if any(op in query for op in ['"', " OR ", " AND ", " NOT ", " NEAR ", "*"]):
        return query

    # Quote each word to prevent column-name interpretation
    words = query.split()
    quoted = [f'"{w}"' for w in words if w.strip()]
    return " ".join(quoted)


def search(db_path: Path, query: str, doc_type: Optional[str] = None,
           project: Optional[str] = None, limit: int = 20) -> list[dict]:
    """Search the knowledge database."""
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row

    # Sanitize query for FTS5: quote each word, join with spaces (implicit AND)
    # This prevents FTS5 from interpreting words as column names
    fts_query = sanitize_fts_query(query)

    # Build FTS5 query
    sql = """
        SELECT d.id, d.repo, d.type, d.title, d.date, d.project, d.quality_score,
               d.source_path,
               snippet(documents_fts, 1, '>>>', '<<<', '...', 40) as snippet
        FROM documents_fts fts
        JOIN documents d ON d.rowid = fts.rowid
        WHERE documents_fts MATCH ?
    """
    params: list[Any] = [fts_query]

    if doc_type:
        sql += " AND d.type = ?"
        params.append(doc_type)
    if project:
        sql += " AND (d.project = ? OR d.repo = ?)"
        params.extend([project, project])

    sql += " ORDER BY rank LIMIT ?"
    params.append(limit)

    try:
        rows = conn.execute(sql, params).fetchall()
    except sqlite3.OperationalError as e:
        print(f"Search error: {e}", file=sys.stderr)
        return []

    results = []
    for row in rows:
        results.append({
            "id": row["id"],
            "repo": row["repo"],
            "type": row["type"],
            "title": row["title"],
            "date": row["date"],
            "project": row["project"],
            "quality": row["quality_score"],
            "source": row["source_path"],
            "snippet": row["snippet"],
        })

    conn.close()
    return results


def stats(db_path: Path) -> dict:
    """Get database statistics."""
    conn = sqlite3.connect(str(db_path))
    result = {}

    result["total_docs"] = conn.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
    result["total_tags"] = conn.execute("SELECT COUNT(DISTINCT tag) FROM tags").fetchone()[0]

    type_counts = conn.execute(
        "SELECT type, COUNT(*) FROM documents GROUP BY type ORDER BY COUNT(*) DESC"
    ).fetchall()
    result["by_type"] = {row[0]: row[1] for row in type_counts}

    repo_counts = conn.execute(
        "SELECT repo, COUNT(*) FROM documents GROUP BY repo ORDER BY COUNT(*) DESC"
    ).fetchall()
    result["by_repo"] = {row[0]: row[1] for row in repo_counts}

    # DB file size
    result["db_size_mb"] = round(db_path.stat().st_size / (1024 * 1024), 2)

    conn.close()
    return result


# === CLI ===


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(
        description="Knowledge query system -- build and search ~/.aitools/knowledge.db",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 build-knowledge-db.py build              # Full rebuild
  python3 build-knowledge-db.py search "delegation" # Search all
  python3 build-knowledge-db.py search "sqlite" --type ol
  python3 build-knowledge-db.py search "hook" --project aitools --limit 5
  python3 build-knowledge-db.py stats               # Show DB stats
        """,
    )
    sub = parser.add_subparsers(dest="command")

    # Build
    sub.add_parser("build", help="Build the knowledge database from all sources")

    # Search
    sp = sub.add_parser("search", help="Search the knowledge database")
    sp.add_argument("query", help="FTS5 search query")
    sp.add_argument("--type", dest="doc_type", help="Filter by document type")
    sp.add_argument("--project", help="Filter by project")
    sp.add_argument("--limit", type=int, default=20, help="Max results (default: 20)")

    # Stats
    sub.add_parser("stats", help="Show database statistics")

    args = parser.parse_args()

    if args.command == "build":
        do_build()
    elif args.command == "search":
        if not DB_PATH.exists():
            print(f"Database not found: {DB_PATH}", file=sys.stderr)
            print("Run 'build' first.", file=sys.stderr)
            sys.exit(1)
        results = search(DB_PATH, args.query, args.doc_type, args.project, args.limit)
        if not results:
            print("No results found.")
            return
        for i, r in enumerate(results, 1):
            print(f"\n--- [{i}] {r['type']} | {r['title']} ---")
            if r["date"]:
                print(f"    Date: {r['date']}")
            if r["project"]:
                print(f"    Project: {r['project']}")
            print(f"    Repo: {r['repo']} | Quality: {r['quality']}")
            if r["source"]:
                print(f"    Source: {r['source']}")
            print(f"    {r['snippet']}")
    elif args.command == "stats":
        if not DB_PATH.exists():
            print(f"Database not found: {DB_PATH}", file=sys.stderr)
            sys.exit(1)
        s = stats(DB_PATH)
        print(f"\nKnowledge DB: {DB_PATH}")
        print(f"Size: {s['db_size_mb']} MB")
        print(f"Total documents: {s['total_docs']}")
        print(f"Unique tags: {s['total_tags']}")
        print("\nBy type:")
        for t, c in s["by_type"].items():
            print(f"  {t:25s} {c:5d}")
        print("\nBy repo:")
        for r, c in s["by_repo"].items():
            print(f"  {r:25s} {c:5d}")
    else:
        parser.print_help()


def do_build() -> None:
    """Build the full knowledge database."""
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"Building knowledge database: {DB_PATH}")
    print(f"Timestamp: {now}")
    print()

    conn = create_db(DB_PATH)
    total = 0

    # 1. Plans
    print("Scanning plans...")
    n = scan_markdown_files(conn, PLANS, "aitools", "plan")
    print(f"  -> {n} documents")
    total += n

    # 2. Reference docs
    print("Scanning reference docs...")
    n = scan_markdown_files(conn, REFERENCE, "aitools", "reference")
    print(f"  -> {n} documents")
    total += n

    # 3. Rules
    print("Scanning rules...")
    n = scan_markdown_files(conn, RULES, "aitools", "rule")
    print(f"  -> {n} documents")
    total += n

    # 4. Harvested artifacts
    print("Scanning harvested artifacts...")
    n = scan_harvested_artifacts(conn)
    print(f"  -> {n} documents")
    total += n

    # 5. Session transcripts
    print("Scanning session transcripts...")
    n = scan_session_transcripts(conn)
    print(f"  -> {n} documents")
    total += n

    # 6. Git log
    print("Scanning git logs...")
    n = scan_git_log(conn)
    print(f"  -> {n} documents")
    total += n

    # 7. Incidents
    print("Scanning incidents...")
    n = scan_incidents(conn)
    print(f"  -> {n} documents")
    total += n

    # 8. Release notes
    print("Scanning release notes...")
    n = scan_release_notes(conn)
    print(f"  -> {n} documents")
    total += n

    # 9. Running estimate
    print("Scanning running estimate...")
    n = scan_running_estimate(conn)
    print(f"  -> {n} documents")
    total += n

    # 10. Consolidated OL
    print("Scanning consolidated operational learning...")
    n = scan_consolidated_ol(conn)
    print(f"  -> {n} documents")
    total += n

    # 11. Reference JSON files
    print("Scanning reference JSON...")
    n = scan_json_files(conn, REFERENCE, "aitools", "reference-data")
    print(f"  -> {n} documents")
    total += n

    # 12. Other repos
    print("Scanning other repos (nobul-ops, marse)...")
    n = scan_other_repos(conn)
    print(f"  -> {n} documents")
    total += n

    # Record build metadata
    conn.execute(
        "INSERT INTO build_meta VALUES (?, ?)", ("built_at", now)
    )
    conn.execute(
        "INSERT INTO build_meta VALUES (?, ?)", ("total_docs", str(total))
    )
    conn.execute(
        "INSERT INTO build_meta VALUES (?, ?)", ("version", "1.0.0")
    )
    conn.commit()
    conn.close()

    print(f"\n=== Build Complete ===")
    print(f"Total documents: {total}")
    print(f"Database: {DB_PATH}")
    print(f"Size: {round(DB_PATH.stat().st_size / (1024 * 1024), 2)} MB")

    # Verify with a test query
    print("\n--- Verification: search for 'delegation' ---")
    results = search(DB_PATH, "delegation", limit=5)
    for r in results:
        print(f"  [{r['type']}] {r['title'][:60]}")


if __name__ == "__main__":
    main()
