#!/usr/bin/env bash
# Wait until S3-FanPlan writes its report or plan.
set -euo pipefail
d=/Users/new-jose/repos/aitools/.aitools/channel/handoffs/2026-10-21_10cf255a-c-missions/S3-FanPlan
until ls "$d" | grep -E -q "report|plan\.md|S3-FanPlan-plan"; do
  sleep 30
done
ls -la "$d"
