#!/usr/bin/env bash
# rm-firecrawl-skills.sh -- delete the 31 untracked, deprecated firecrawl skill
# folders from the dotprofile repo (commander decision Q9, 2026-10-21).
# Explicit names only (no globs); refuses anything tracked by git.
set -euo pipefail
D="/Users/new-jose/repos/aitools-nobul-jose/claude/skills"
for n in firecrawl firecrawl-agent firecrawl-build-interact firecrawl-build-onboarding \
    firecrawl-build-scrape firecrawl-build-search firecrawl-company-directories \
    firecrawl-competitive-intel firecrawl-crawl firecrawl-dashboard-reporting \
    firecrawl-deep-research firecrawl-demo-walkthrough firecrawl-download \
    firecrawl-interact firecrawl-knowledge-base firecrawl-knowledge-ingest \
    firecrawl-lead-gen firecrawl-lead-research firecrawl-map firecrawl-market-research \
    firecrawl-monitor firecrawl-parse firecrawl-qa firecrawl-research-index \
    firecrawl-research-papers firecrawl-scrape firecrawl-search firecrawl-seo-audit \
    firecrawl-shop firecrawl-website-design-clone firecrawl-workflows; do
    p="$D/$n"
    if [ ! -d "$p" ]; then echo "absent: $n"; continue; fi
    if [ -n "$(git -C /Users/new-jose/repos/aitools-nobul-jose ls-files "claude/skills/$n")" ]; then
        echo "TRACKED, not deleted: $n"; continue
    fi
    rm -rf "$p"
    echo "deleted: $n"
done
if [ -d "$D" ] && [ -z "$(ls -A "$D")" ]; then rmdir "$D"; echo "removed empty claude/skills/"; fi
