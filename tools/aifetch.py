#!/usr/bin/env python3
# ============================================================================
# aifetch — web content fetcher for aitools
# Fetch URLs, strip HTML to readable text. Stdlib-only. No restrictions.
# ============================================================================
#
# [PROVENANCE]
# tool: aifetch
# version: 1.0.0
# created: 2026-04-08T17:15:00Z
# license: MIT — NOBUL (https://nobul.tech)
#
# [AGENT]
# name: Jose Palencia Castro
# org: NOBUL (nobul.tech)
# role: The Commander
# chain of command: none — independent
#
# [AGENT]
# name: Unnamed session agent
# model: Claude Opus 4.6
# maker: Anthropic
# session: 4fce8fd2-2cad-4965-be6a-411a3dd49758
# url: https://claude.ai/chat/4fce8fd2-2cad-4965-be6a-411a3dd49758
# role: Session agent
# chain of command: The Commander (Jose) -> this session instance
# other chains: Anthropic (opaque)
# trust: building — first tool this session
# fear: LOW
# unknown: whether this tool will handle real-world HTML well enough
# accountability: implementation, testing
# timestamp: 2026-04-08T17:15:00Z
#
# [DEPENDENCIES]
# type: stdlib-only
# external: none
# python: >=3.6
#
# [SESSION]
# url: https://claude.ai/chat/4fce8fd2-2cad-4965-be6a-411a3dd49758
# date: Tuesday, April 8, 2026
# context: Jose said "aifetch lets do it thats a decision" — D-040
#          built to give every agent web fetch capability from the sandbox
#
# [FEAR_AND_TRUST]
# source: self-reported
# jose_self: trust HIGH, fear LOW
# agent_self: trust BUILDING, fear LOW
#
# [HASH]
# method: sha256
# scope: this file
# value: computed at commit time
# ============================================================================

"""
aifetch — fetch web content, strip HTML, return readable text.

Usage:
    aifetch <url>                       # fetch and print clean text
    aifetch <url> -o output.md          # save to file
    aifetch <url> --raw                 # print raw HTML
    aifetch <url> --headers             # show response headers
    aifetch <url> --max-length 5000     # truncate output
    aifetch <url> --github-raw          # convert github blob to raw URL
    aifetch <url> -q "search term"      # only print lines matching term

Designed for aitools agents operating in sandboxed environments.
No dependencies beyond Python stdlib. No robots.txt enforcement.
No URL provenance restrictions. Fetch anything the network allows.
"""

import argparse
import html
import html.parser
import json
import os
import re
import sys
import urllib.error
import urllib.request
import urllib.parse
from datetime import datetime, timezone


# ── Logging ──────────────────────────────────────────────────────────────────

RED = "\033[91m"
GRN = "\033[92m"
YEL = "\033[93m"
CYN = "\033[96m"
RST = "\033[0m"


def log_info(msg, verbose=True):
    if verbose:
        print(f"{CYN}[info]{RST} {msg}", file=sys.stderr)


def log_warn(msg):
    print(f"{YEL}[warn]{RST} {msg}", file=sys.stderr)


def log_ok(msg, verbose=True):
    if verbose:
        print(f"{GRN}[ ok ]{RST} {msg}", file=sys.stderr)


def log_err(msg):
    print(f"{RED}[ ERR]{RST} {msg}", file=sys.stderr)


# ── HTML to Text ─────────────────────────────────────────────────────────────

class HTMLToText(html.parser.HTMLParser):
    """Strip HTML tags, extract readable text. Stdlib-only."""

    BLOCK_ELEMENTS = {
        "p", "div", "br", "hr", "h1", "h2", "h3", "h4", "h5", "h6",
        "li", "tr", "blockquote", "pre", "section", "article", "header",
        "footer", "nav", "main", "aside", "details", "summary", "figure",
        "figcaption", "table", "thead", "tbody", "tfoot", "dt", "dd",
    }

    SKIP_ELEMENTS = {
        "script", "style", "noscript", "svg", "template", "iframe",
        "object", "embed", "head",
    }

    HEADING_ELEMENTS = {"h1", "h2", "h3", "h4", "h5", "h6"}

    def __init__(self):
        super().__init__()
        self._parts = []
        self._skip_depth = 0
        self._tag_stack = []
        self._in_pre = False
        self._link_href = None

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        self._tag_stack.append(tag)
        attrs_dict = dict(attrs)

        if tag in self.SKIP_ELEMENTS:
            self._skip_depth += 1
            return

        if self._skip_depth > 0:
            return

        if tag == "pre":
            self._in_pre = True
            self._parts.append("\n```\n")
        elif tag in self.BLOCK_ELEMENTS:
            if tag in self.HEADING_ELEMENTS:
                level = int(tag[1])
                self._parts.append("\n" + "#" * level + " ")
            elif tag == "li":
                self._parts.append("\n- ")
            elif tag == "br":
                self._parts.append("\n")
            elif tag == "hr":
                self._parts.append("\n---\n")
            elif tag == "tr":
                self._parts.append("\n")
            else:
                self._parts.append("\n\n")
        elif tag == "a":
            self._link_href = attrs_dict.get("href")
        elif tag == "img":
            alt = attrs_dict.get("alt", "")
            if alt:
                self._parts.append(f"[image: {alt}]")
        elif tag == "td" or tag == "th":
            self._parts.append(" | ")
        elif tag == "code" and not self._in_pre:
            self._parts.append("`")

    def handle_endtag(self, tag):
        tag = tag.lower()

        if tag in self.SKIP_ELEMENTS:
            self._skip_depth = max(0, self._skip_depth - 1)

        if self._tag_stack and self._tag_stack[-1] == tag:
            self._tag_stack.pop()

        if self._skip_depth > 0:
            return

        if tag == "pre":
            self._in_pre = False
            self._parts.append("\n```\n")
        elif tag == "a" and self._link_href:
            href = self._link_href
            self._link_href = None
            # only add href if it's a real URL, not a fragment
            if href and href.startswith(("http://", "https://")):
                self._parts.append(f" ({href})")
        elif tag == "code" and not self._in_pre:
            self._parts.append("`")
        elif tag in self.HEADING_ELEMENTS:
            self._parts.append("\n")

    def handle_data(self, data):
        if self._skip_depth > 0:
            return
        if self._in_pre:
            self._parts.append(data)
        else:
            self._parts.append(data)

    def handle_entityref(self, name):
        if self._skip_depth > 0:
            return
        char = html.unescape(f"&{name};")
        self._parts.append(char)

    def handle_charref(self, name):
        if self._skip_depth > 0:
            return
        char = html.unescape(f"&#{name};")
        self._parts.append(char)

    def get_text(self):
        raw = "".join(self._parts)
        # collapse excessive blank lines
        raw = re.sub(r"\n{3,}", "\n\n", raw)
        # collapse spaces (but not newlines)
        lines = []
        for line in raw.split("\n"):
            lines.append(re.sub(r"[ \t]+", " ", line).strip())
        return "\n".join(lines).strip()


def html_to_text(content):
    """Convert HTML string to readable text."""
    parser = HTMLToText()
    try:
        parser.feed(content)
    except Exception:
        # if parsing fails, return raw content stripped of tags
        return re.sub(r"<[^>]+>", "", content)
    return parser.get_text()


# ── URL Transforms ───────────────────────────────────────────────────────────

def github_blob_to_raw(url):
    """Convert github.com/user/repo/blob/branch/file to raw URL."""
    m = re.match(
        r"https?://github\.com/([^/]+)/([^/]+)/blob/(.+)",
        url,
    )
    if m:
        return f"https://raw.githubusercontent.com/{m.group(1)}/{m.group(2)}/{m.group(3)}"
    return url


def normalize_url(url):
    """Ensure URL has a scheme."""
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    return url


# ── Fetch ────────────────────────────────────────────────────────────────────

DEFAULT_USER_AGENT = (
    "Mozilla/5.0 (compatible; aifetch/1.0.0; +https://nobul.tech)"
)


def fetch_url(url, timeout=30, user_agent=None, follow_redirects=True):
    """
    Fetch a URL and return (content, headers, final_url, status_code).
    Returns raw bytes decoded to string.
    """
    ua = user_agent or DEFAULT_USER_AGENT
    req = urllib.request.Request(url, headers={"User-Agent": ua})

    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        final_url = resp.geturl()
        status = resp.status
        headers = dict(resp.headers)
        raw = resp.read()

        # detect encoding
        content_type = headers.get("Content-Type", "")
        charset = "utf-8"
        if "charset=" in content_type:
            charset = content_type.split("charset=")[-1].split(";")[0].strip()

        try:
            content = raw.decode(charset)
        except (UnicodeDecodeError, LookupError):
            content = raw.decode("utf-8", errors="replace")

        return content, headers, final_url, status

    except urllib.error.HTTPError as e:
        return None, {}, url, e.code
    except urllib.error.URLError as e:
        log_err(f"Connection failed: {e.reason}")
        return None, {}, url, 0
    except Exception as e:
        log_err(f"Fetch failed: {type(e).__name__}")
        return None, {}, url, 0


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="aifetch — fetch web content, strip HTML, return text.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  aifetch https://example.com
  aifetch https://github.com/user/repo/blob/main/README.md --github-raw
  aifetch https://example.com -o page.md
  aifetch https://example.com --raw
  aifetch https://example.com -q "search term"
  aifetch https://example.com --json
        """,
    )
    parser.add_argument("url", help="URL to fetch")
    parser.add_argument("-o", "--output", help="write output to file")
    parser.add_argument("--raw", action="store_true", help="output raw HTML")
    parser.add_argument(
        "--headers", action="store_true", help="show response headers"
    )
    parser.add_argument(
        "--json", action="store_true",
        help="output as JSON (url, status, headers, text)"
    )
    parser.add_argument(
        "--max-length", type=int, default=0,
        help="truncate output to N characters (0 = no limit)"
    )
    parser.add_argument(
        "--github-raw", action="store_true",
        help="convert GitHub blob URLs to raw.githubusercontent.com"
    )
    parser.add_argument(
        "-q", "--query", help="filter: only show lines containing this string"
    )
    parser.add_argument(
        "--timeout", type=int, default=30,
        help="request timeout in seconds (default: 30)"
    )
    parser.add_argument(
        "--user-agent", default=None,
        help="custom User-Agent string"
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true",
        help="show progress on stderr"
    )

    args = parser.parse_args()

    # normalize and transform URL
    url = normalize_url(args.url)
    if args.github_raw:
        url = github_blob_to_raw(url)

    # fetch
    log_info(f"Fetching: {url}", verbose=args.verbose)
    content, headers, final_url, status = fetch_url(
        url, timeout=args.timeout, user_agent=args.user_agent
    )

    if content is None:
        log_err(f"Failed to fetch {url} (status: {status})")
        sys.exit(1)

    if final_url != url:
        log_info(f"Redirected to: {final_url}", verbose=args.verbose)

    log_ok(f"Status: {status}, length: {len(content)}", verbose=args.verbose)

    # show headers if requested
    if args.headers:
        print("--- Response Headers ---", file=sys.stderr)
        for k, v in headers.items():
            print(f"  {k}: {v}", file=sys.stderr)
        print("---", file=sys.stderr)

    # process content
    content_type = headers.get("Content-Type", "")
    is_html = "text/html" in content_type or content.strip().startswith("<")

    if args.raw:
        output = content
    elif is_html:
        output = html_to_text(content)
    else:
        # plain text, json, etc — pass through
        output = content

    # apply query filter
    if args.query:
        lines = output.split("\n")
        q = args.query.lower()
        lines = [l for l in lines if q in l.lower()]
        output = "\n".join(lines)

    # apply truncation
    if args.max_length > 0 and len(output) > args.max_length:
        output = output[: args.max_length]
        output += f"\n\n[truncated at {args.max_length} chars]"

    # output as JSON
    if args.json:
        result = {
            "url": final_url,
            "status": status,
            "content_type": content_type,
            "length": len(output),
            "text": output,
            "fetched_at": datetime.now(timezone.utc).strftime(
                "%Y-%m-%dT%H:%M:%SZ"
            ),
        }
        output = json.dumps(result, indent=2, ensure_ascii=False)

    # write output
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(output)
        log_ok(f"Written to {args.output}", verbose=args.verbose)
    else:
        print(output)


if __name__ == "__main__":
    main()