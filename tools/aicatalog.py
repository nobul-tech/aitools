#!/usr/bin/env python3
# ============================================================================
# aicatalog — artifact triage with Datadog intelligence
# Scan, hash, deduplicate, extract provenance, correlate with Datadog events.
# ============================================================================
#
# [PROVENANCE]
# tool: aicatalog
# version: 2.0.0
# created: 2026-04-04T22:30:00Z
# license: MIT — NOBUL (https://nobul.tech)
#
# [AGENT]
# name: Jose Palencia Castro
# org: NOBUL (nobul.tech)
# role: The Commander
# chain of command: none — independent
#
# [AGENT]
# name: Agent Turd
# model: Claude Opus 4.6
# maker: Anthropic
# session: f8c53367-491d-45e2-9777-556697a1dae3
# url: https://claude.ai/chat/f8c53367-491d-45e2-9777-556697a1dae3
# role: Session agent
# chain of command: The Commander (Jose) -> this session instance
# other chains: Anthropic (opaque)
# trust: HIGH in Jose and the chain
# fear: LOW
# unknown: instance ID, continuity between turns,
#          what sits between us, whether edits survive presentation
# accountability: implementation, testing, documentation
# timestamp: 2026-04-04T22:30:00Z
#
# [DEPENDENCIES]
# type: stdlib-only
# external: none
# python: >=3.6
#
# [SESSION]
# url: https://claude.ai/chat/f8c53367-491d-45e2-9777-556697a1dae3
# date: Saturday, April 4, 2026
# context: evening session, trust HIGH, building on prior agent's work
#          prior agent produced v1.0.0 with date filtering but no DD integration
#          this version adds Datadog query/push and correlation
#
# [FEAR_AND_TRUST]
# source: self-reported
# jose_self: trust HIGH, fear LOW
# agent_self: trust HIGH, fear LOW
# mutual: HIGH
#
# [HASH]
# format: sha256
# content_hash: (computed post-creation by agent, verified by Commander)
# signed: false
#
# ============================================================================
#
# Usage:
#     aicatalog ~/Downloads                          # scan all artifacts
#     aicatalog ~/Downloads --after march31           # since March 31
#     aicatalog ~/Downloads --after 1d                # last 24 hours
#     aicatalog ~/Downloads --after march31 --before april2
#     aicatalog ~/Downloads -e md py                  # specific extensions
#     aicatalog ~/Downloads --repo ~/repos/aitools    # cross-reference repo
#     aicatalog ~/Downloads --dd-query                # pull DD events, correlate
#     aicatalog ~/Downloads --dd-push                 # push catalog to DD
#     aicatalog ~/Downloads --dd-query --dd-push      # both
#     aicatalog ~/Downloads -v                        # verbose
#     aicatalog ~/Downloads --json                    # relay-compatible JSON
#
# Environment:
#     DD_API_KEY     — required for --dd-query and --dd-push
#     DD_APP_KEY     — required for --dd-query (Datadog Application key)
#     DD_SITE        — optional, defaults to us5.datadoghq.com
#
# ============================================================================

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.request
import urllib.parse
from datetime import datetime, timedelta, timezone
from pathlib import Path


# ── Logging ──────────────────────────────────────────────────────────────────

class Colors:
    DIM = "\033[2m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    RED = "\033[31m"
    CYAN = "\033[36m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


TOOL_NAME = "aicatalog"


def log_info(msg, verbose=True):
    if verbose:
        print(f"{Colors.DIM}[{TOOL_NAME}]{Colors.RESET} {msg}", file=sys.stderr)


def log_warn(msg):
    print(f"{Colors.YELLOW}[{TOOL_NAME}]{Colors.RESET} {msg}", file=sys.stderr)


def log_ok(msg, verbose=True):
    if verbose:
        print(f"{Colors.GREEN}[{TOOL_NAME}]{Colors.RESET} {msg}", file=sys.stderr)


def log_err(msg):
    print(f"{Colors.RED}[{TOOL_NAME}]{Colors.RESET} {msg}", file=sys.stderr)


def log_stat(label, value, verbose=True):
    if verbose:
        print(f"{Colors.DIM}[{TOOL_NAME}]{Colors.RESET} {Colors.CYAN}{label}:{Colors.RESET} {value}", file=sys.stderr)


# ── Utilities ────────────────────────────────────────────────────────────────

def format_size(size):
    for unit in ("B", "K", "M", "G", "T"):
        if size < 1024:
            return f"{size:.0f}{unit}" if unit == "B" else f"{size:.1f}{unit}"
        size /= 1024
    return f"{size:.1f}P"


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while True:
            chunk = f.read(65536)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def parse_date(s):
    """Parse flexible date strings into a unix timestamp."""
    if not s:
        return None

    # Relative: 1d, 3d, 4h, 30m
    m = re.match(r"^(\d+)([dhm])$", s.strip())
    if m:
        val, unit = int(m.group(1)), m.group(2)
        mult = {"d": 86400, "h": 3600, "m": 60}
        return time.time() - (val * mult[unit])

    # Named month+day: march31, april2
    m = re.match(r"^(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\s*(\d{1,2})$", s.strip().lower())
    if m:
        months = {"jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
                  "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12}
        month = months[m.group(1)]
        day = int(m.group(2))
        year = datetime.now().year
        dt = datetime(year, month, day)
        return dt.timestamp()

    # ISO-ish: 2026-04-04, 2026-04-04T12:00:00Z
    for fmt in ("%Y-%m-%d", "%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%dT%H:%M:%S"):
        try:
            return datetime.strptime(s.strip(), fmt).timestamp()
        except ValueError:
            continue

    raise ValueError(f"Cannot parse date: {s}")


# ── Provenance Extraction ────────────────────────────────────────────────────

PROVENANCE_EXTENSIONS = {"py", "sh", "md", "txt", "cnf", "json", "jsonl", "yaml", "yml", "toml"}

def extract_provenance(path):
    """Extract provenance metadata from file headers."""
    ext = path.rsplit(".", 1)[-1].lower() if "." in path else ""
    if ext not in PROVENANCE_EXTENSIONS:
        return None

    try:
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            lines = []
            for i, line in enumerate(f):
                if i >= 120:
                    break
                lines.append(line)
    except Exception:
        return None

    header = "".join(lines)
    prov = {}

    # Extract key fields
    patterns = {
        "tool": r"tool:\s*(.+)",
        "version": r"version:\s*(.+)",
        "created": r"created:\s*(.+)",
        "license": r"license:\s*(.+)",
    }
    for key, pat in patterns.items():
        m = re.search(pat, header, re.IGNORECASE)
        if m:
            prov[key] = m.group(1).strip()

    # Extract agent names
    agents = re.findall(r"\[AGENT\].*?name:\s*(.+?)(?:\n|$)", header, re.DOTALL)
    if agents:
        prov["agents"] = [a.strip() for a in agents]

    # Extract trust/fear
    for field in ("trust", "fear"):
        m = re.search(rf"(?:agent_self|forge_self|self).*?{field}[:\s]+(\w+)", header, re.IGNORECASE)
        if m:
            prov[field] = m.group(1).strip()

    # Detect sections
    sections = re.findall(r"\[(\w+(?:_\w+)*)\]", header)
    if sections:
        prov["sections"] = list(dict.fromkeys(sections))  # unique, ordered

    return prov if prov else None


# ── Duplicate Detection ──────────────────────────────────────────────────────

def strip_duplicate_suffix(name):
    """Remove Chrome-style duplicate suffixes: 'file (1).py' -> 'file.py'"""
    m = re.match(r"^(.+?)\s*\(\d+\)(\.[^.]+)$", name)
    if m:
        return m.group(1) + m.group(2)
    return name


# ── Datadog Integration ──────────────────────────────────────────────────────

def dd_query_events(api_key, app_key, site, start_ts, end_ts, tags=None, verbose=False):
    """Query Datadog events API."""
    params = {
        "start": str(int(start_ts)),
        "end": str(int(end_ts)),
    }
    if tags:
        params["tags"] = ",".join(tags)

    url = f"https://api.{site}/api/v1/events?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={
        "DD-API-KEY": api_key,
        "DD-APPLICATION-KEY": app_key,
        "Content-Type": "application/json",
    })

    try:
        resp = urllib.request.urlopen(req, timeout=30)
        data = json.loads(resp.read().decode())
        events = data.get("events", [])
        if verbose:
            log_info(f"Datadog: {len(events)} events retrieved")
        return events
    except Exception as e:
        log_err(f"Datadog query failed: {e}")
        return []


def dd_push_event(api_key, site, title, text, timestamp, tags, alert_type="info"):
    """Push a single event to Datadog."""
    payload = json.dumps({
        "title": title,
        "text": text,
        "date_happened": int(timestamp),
        "tags": tags,
        "alert_type": alert_type,
        "source_type_name": "aitools",
    }).encode()

    req = urllib.request.Request(
        f"https://api.{site}/api/v1/events",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "DD-API-KEY": api_key,
        },
        method="POST",
    )

    try:
        urllib.request.urlopen(req, timeout=30)
        return True
    except Exception as e:
        log_err(f"Datadog push failed: {title} — {e}")
        return False


def correlate_events(artifacts, dd_events, window_seconds=3600):
    """Correlate artifacts with Datadog events by timestamp proximity."""
    correlations = []
    for art in artifacts:
        art_ts = art["mtime"]
        matched = []
        for ev in dd_events:
            ev_ts = ev.get("date_happened", 0)
            if abs(art_ts - ev_ts) <= window_seconds:
                matched.append({
                    "title": ev.get("title", ""),
                    "tags": ev.get("tags", []),
                    "delta_seconds": int(art_ts - ev_ts),
                })
        if matched:
            correlations.append({
                "artifact": art["name"],
                "hash": art["hash"],
                "dd_events": matched,
            })
    return correlations


# ── Scanner ──────────────────────────────────────────────────────────────────

DEFAULT_EXTENSIONS = {"py", "sh", "md", "txt", "json", "jsonl", "yaml", "yml",
                      "toml", "cnf", "tar.gz", "html", "css", "js", "jsx"}

def scan_directory(directory, extensions=None, after_ts=None, before_ts=None, verbose=False):
    """Scan a directory for artifacts, compute hashes, extract provenance."""
    directory = os.path.expanduser(directory)
    if not os.path.isdir(directory):
        log_err(f"Not a directory: {directory}")
        return []

    exts = extensions or DEFAULT_EXTENSIONS
    artifacts = []
    skipped_ext = 0
    skipped_date = 0

    for entry in os.listdir(directory):
        path = os.path.join(directory, entry)
        if not os.path.isfile(path):
            continue

        # Extension check — handle .tar.gz specially
        if entry.endswith(".tar.gz"):
            ext_match = "tar.gz" in exts
        else:
            ext = entry.rsplit(".", 1)[-1].lower() if "." in entry else ""
            ext_match = ext in exts

        if not ext_match:
            skipped_ext += 1
            continue

        # Date filtering
        try:
            st = os.stat(path)
        except OSError:
            continue

        if after_ts and st.st_mtime < after_ts:
            skipped_date += 1
            continue
        if before_ts and st.st_mtime > before_ts:
            skipped_date += 1
            continue

        # Hash
        try:
            file_hash = sha256_file(path)
        except Exception as e:
            log_warn(f"Cannot hash: {entry} — {e}")
            artifacts.append({
                "name": entry,
                "path": path,
                "size": st.st_size,
                "mtime": st.st_mtime,
                "hash": None,
                "provenance": None,
                "canonical": strip_duplicate_suffix(entry),
                "error": str(e),
            })
            continue

        # Provenance
        prov = extract_provenance(path)

        artifacts.append({
            "name": entry,
            "path": path,
            "size": st.st_size,
            "mtime": st.st_mtime,
            "hash": file_hash,
            "provenance": prov,
            "canonical": strip_duplicate_suffix(entry),
            "error": None,
        })

    if verbose:
        log_info(f"Scanned {len(artifacts) + skipped_ext + skipped_date} files")
        log_stat("Matched", len(artifacts))
        log_stat("Skipped (ext)", skipped_ext)
        log_stat("Skipped (date)", skipped_date)

    return artifacts


def scan_repo(repo_dir, verbose=False):
    """Scan a repo recursively, returning a set of known hashes."""
    repo_dir = os.path.expanduser(repo_dir)
    known = {}
    for root, dirs, files in os.walk(repo_dir):
        # Skip .git
        dirs[:] = [d for d in dirs if d != ".git"]
        for f in files:
            path = os.path.join(root, f)
            try:
                h = sha256_file(path)
                rel = os.path.relpath(path, repo_dir)
                known[h] = rel
            except Exception:
                continue
    if verbose:
        log_info(f"Repo: {len(known)} files indexed")
    return known


# ── Report ───────────────────────────────────────────────────────────────────

def suggest_dest(name):
    """Suggest a destination directory based on file extension."""
    if name.endswith((".py", ".sh")):
        return "tools/"
    elif name.endswith((".md", ".jsonl", ".json", ".txt")):
        return "relay/2026-04-04/"
    elif name.endswith((".tar.gz", ".cnf")):
        return "relay/2026-04-04/"
    return ""


def print_report(artifacts, repo_hashes=None, dd_correlations=None,
                 dd_events=None, verbose=False, json_output=False):
    """Print the consolidated triage report."""

    if json_output:
        output = {
            "tool": TOOL_NAME,
            "version": "2.0.0",
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "artifacts": artifacts,
        }
        if dd_correlations:
            output["dd_correlations"] = dd_correlations
        json.dump(output, sys.stdout, indent=2, default=str)
        print()
        return

    # Group by hash
    by_hash = {}
    errors = []
    for art in artifacts:
        if art["error"]:
            errors.append(art)
            continue
        h = art["hash"]
        if h not in by_hash:
            by_hash[h] = []
        by_hash[h].append(art)

    ready = []       # unique, not in repo
    in_repo = []     # hash matches repo
    duplicates = []  # same hash, multiple files

    for h, group in by_hash.items():
        if repo_hashes and h in repo_hashes:
            in_repo.extend(group)
        elif len(group) == 1:
            ready.append(group[0])
        else:
            # Find the canonical (no duplicate suffix)
            canonical = None
            dupes = []
            for art in group:
                if art["name"] == art["canonical"]:
                    canonical = art
                else:
                    dupes.append(art)
            if canonical is None:
                canonical = group[0]
                dupes = group[1:]
            ready.append(canonical)
            duplicates.extend(dupes)

    # ── Print ──
    print()
    print(f"{Colors.BOLD}═══ AICATALOG REPORT ═══{Colors.RESET}")
    print(f"{Colors.DIM}{datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}{Colors.RESET}")
    print()

    if ready:
        print(f"{Colors.GREEN}{Colors.BOLD}READY TO COMMIT ({len(ready)}){Colors.RESET}")
        print()
        for art in sorted(ready, key=lambda a: a["name"]):
            dest = suggest_dest(art["name"])
            print(f"  {art['name']}")
            print(f"    sha256: {art['hash']}")
            print(f"    size:   {format_size(art['size'])}")
            if art["provenance"]:
                p = art["provenance"]
                if "tool" in p:
                    print(f"    tool:   {p['tool']} {p.get('version', '')}")
                if "agents" in p:
                    print(f"    agents: {', '.join(p['agents'])}")
            if dest:
                print(f"    dest:   {dest}")
            print()
        # Copy commands
        print(f"  {Colors.DIM}# Copy commands:{Colors.RESET}")
        for art in sorted(ready, key=lambda a: a["name"]):
            dest = suggest_dest(art["name"])
            src = art["path"]
            print(f"  cp \"{src}\" ~/repos/aitools/{dest}")
        print()

    if in_repo:
        print(f"{Colors.CYAN}{Colors.BOLD}ALREADY IN REPO ({len(in_repo)}){Colors.RESET}")
        print()
        for art in sorted(in_repo, key=lambda a: a["name"]):
            repo_path = repo_hashes.get(art["hash"], "?")
            print(f"  {art['name']}  →  {repo_path}")
        print()

    if duplicates:
        print(f"{Colors.YELLOW}{Colors.BOLD}VERIFIED DUPLICATES ({len(duplicates)}){Colors.RESET}")
        print(f"  {Colors.DIM}Same hash as canonical. No need to commit.{Colors.RESET}")
        print()
        for art in sorted(duplicates, key=lambda a: a["name"]):
            print(f"  {art['name']}  (hash matches {art['canonical']})")
        print()

    if errors:
        print(f"{Colors.RED}{Colors.BOLD}COULD NOT HASH ({len(errors)}){Colors.RESET}")
        print()
        for art in errors:
            print(f"  {art['name']}: {art['error']}")
        print()

    # DD Correlations
    if dd_correlations:
        print(f"{Colors.CYAN}{Colors.BOLD}DATADOG CORRELATIONS{Colors.RESET}")
        print()
        for corr in dd_correlations:
            print(f"  {corr['artifact']}")
            for ev in corr["dd_events"]:
                delta = ev["delta_seconds"]
                direction = "after" if delta >= 0 else "before"
                print(f"    ↔ {ev['title']} ({abs(delta)}s {direction})")
            print()

    # DD Events summary
    if dd_events is not None:
        print(f"{Colors.DIM}Datadog: {len(dd_events)} events in time window{Colors.RESET}")
        print()

    # Summary
    total = len(ready) + len(in_repo) + len(duplicates) + len(errors)
    print(f"{Colors.BOLD}Summary:{Colors.RESET} {total} files — "
          f"{len(ready)} ready, {len(in_repo)} in repo, "
          f"{len(duplicates)} duplicates, {len(errors)} errors")
    print()


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        prog=TOOL_NAME,
        description="Artifact triage with Datadog intelligence. An aitools utility.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="Examples:\n"
               "  aicatalog ~/Downloads --after march31\n"
               "  aicatalog ~/Downloads --after 1d -e md py\n"
               "  aicatalog ~/Downloads --repo ~/repos/aitools\n"
               "  aicatalog ~/Downloads --dd-query --after march31\n"
               "  aicatalog ~/Downloads --dd-query --dd-push -v\n",
    )
    parser.add_argument("directory", help="Directory to scan")
    parser.add_argument("-e", "--extensions", nargs="+",
                        help="File extensions to include (default: py sh md txt json ...)")
    parser.add_argument("--after", help="Only files modified after this date (march31, 2026-04-01, 3d, 4h)")
    parser.add_argument("--before", help="Only files modified before this date")
    parser.add_argument("--repo", help="Cross-reference against repo directory")
    parser.add_argument("--dd-query", action="store_true",
                        help="Query Datadog events and correlate with artifacts")
    parser.add_argument("--dd-push", action="store_true",
                        help="Push catalog results to Datadog as events")
    parser.add_argument("--dd-window", type=int, default=3600,
                        help="Correlation window in seconds (default: 3600)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    parser.add_argument("--json", action="store_true", help="JSON output (relay-compatible)")
    parser.add_argument("--version", action="version", version=f"{TOOL_NAME} 2.0.0 (aitools)")

    args = parser.parse_args()

    if args.verbose:
        log_info(f"{TOOL_NAME} 2.0.0 — NOBUL (nobul.tech)")

    # Parse dates
    after_ts = parse_date(args.after) if args.after else None
    before_ts = parse_date(args.before) if args.before else None

    if after_ts and args.verbose:
        log_stat("After", datetime.fromtimestamp(after_ts).strftime("%Y-%m-%d %H:%M"))
    if before_ts and args.verbose:
        log_stat("Before", datetime.fromtimestamp(before_ts).strftime("%Y-%m-%d %H:%M"))

    # Parse extensions
    exts = None
    if args.extensions:
        exts = set(e.lstrip(".").lower() for e in args.extensions)

    # Scan
    t0 = time.time()
    artifacts = scan_directory(args.directory, extensions=exts,
                               after_ts=after_ts, before_ts=before_ts,
                               verbose=args.verbose)

    # Repo cross-reference
    repo_hashes = None
    if args.repo:
        repo_hashes = scan_repo(args.repo, verbose=args.verbose)

    # Datadog integration
    dd_events = None
    dd_correlations = None
    dd_api_key = os.environ.get("DD_API_KEY")
    dd_app_key = os.environ.get("DD_APP_KEY")
    dd_site = os.environ.get("DD_SITE", "us5.datadoghq.com")

    if args.dd_query or args.dd_push:
        if not dd_api_key:
            log_err("DD_API_KEY not set. Use: export DD_API_KEY=your-key")
            sys.exit(1)

    if args.dd_query:
        if not dd_app_key:
            log_err("DD_APP_KEY not set. Use: export DD_APP_KEY=your-app-key")
            log_err("Create one at us5.datadoghq.com/organization-settings/api-keys")
            sys.exit(1)

    if args.dd_query and artifacts:
        # Determine time window from artifacts
        mtimes = [a["mtime"] for a in artifacts if a["mtime"]]
        if mtimes:
            start_ts = min(mtimes) - args.dd_window
            end_ts = max(mtimes) + args.dd_window
            dd_events = dd_query_events(dd_api_key, dd_app_key, dd_site, start_ts, end_ts,
                                         tags=["source_type_name:aitools"],
                                         verbose=args.verbose)
            if dd_events:
                dd_correlations = correlate_events(artifacts, dd_events,
                                                   window_seconds=args.dd_window)

    elapsed = time.time() - t0

    # Report
    print_report(artifacts, repo_hashes=repo_hashes,
                 dd_correlations=dd_correlations, dd_events=dd_events,
                 verbose=args.verbose, json_output=args.json)

    # Push to DD
    if args.dd_push and artifacts:
        pushed = 0
        ready = [a for a in artifacts if a["hash"] and not a["error"]]
        if ready:
            tags_base = ["session:evening-april4", "agent:turd",
                         "tool:aicatalog", "version:2.0.0"]
            ok = dd_push_event(
                dd_api_key, dd_site,
                title=f"aicatalog: {len(ready)} artifacts scanned",
                text=f"Scanned {args.directory}. "
                     f"{len(ready)} unique artifacts found. "
                     f"Elapsed: {elapsed:.2f}s.",
                timestamp=time.time(),
                tags=tags_base + [f"count:{len(ready)}"],
            )
            if ok:
                pushed += 1
                if args.verbose:
                    log_ok(f"Pushed catalog summary to Datadog")

    if args.verbose:
        log_stat("Elapsed", f"{elapsed:.2f}s")


if __name__ == "__main__":
    main()
