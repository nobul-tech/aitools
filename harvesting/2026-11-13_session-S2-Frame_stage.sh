#!/usr/bin/env bash
# stage.sh -- stage only S2-Frame's paths; README.md as HEAD plus S2-Frame's two rows.
set -euo pipefail
repo=/Users/new-jose/repos/aitools
scratch="$repo/.scratch/session-S2-Frame"
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }
log() { printf '[%s] [stage] [%s] %s\n' "$(ts)" "$1" "$2"; }

git -C "$repo" show HEAD:reference/README.md > "$scratch/README.head.md"

ADV='| `framework-adversarial-review.md` | Adversarial review (red teaming, devil'"'"'s advocacy, pre-mortem, key assumptions check): sources for checklist item 8 |'
PBR='| `framework-perspective-based-reading.md` | Perspective-based reading (Basili et al.): sources for checklist item 9 |'
export ADV PBR
perl -pe '
  if (/^\| `framework-adoption\.md` \|/) { $_ .= "$ENV{ADV}\n"; $a++ }
  if (/^\| `framework-managed-file-deployment\.md` \|/) { $_ .= "$ENV{PBR}\n"; $b++ }
  END { die "anchor missing\n" unless $a == 1 && $b == 1 }
' "$scratch/README.head.md" > "$scratch/README.staged.md"

added=$(diff "$scratch/README.head.md" "$scratch/README.staged.md" | grep -c '^>' || true)
if [ "$added" != "2" ]; then
  log error "expected 2 added lines, got $added"
  exit 1
fi
log ok "staged README differs from HEAD by $added added lines"

blob=$(git -C "$repo" hash-object -w "$scratch/README.staged.md")
git -C "$repo" update-index --cacheinfo "100644,$blob,reference/README.md"
log ok "README.md staged as blob $blob"

git -C "$repo" add -- registries/framework-registry.json reference/framework-adversarial-review.md reference/framework-perspective-based-reading.md
log ok "staged registry and two reference files"

git -C "$repo" diff --cached --stat
