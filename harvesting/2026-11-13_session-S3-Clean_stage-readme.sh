#!/usr/bin/env bash
# Stage reference/README.md as HEAD plus only S3-Clean's two row changes
# (the other session's uncommitted aitools.md row stays unstaged).
set -euo pipefail
cd /Users/new-jose/repos/aitools
s=/Users/new-jose/repos/aitools/.scratch/session-S3-Clean
git show HEAD:reference/README.md > "$s/readme-head.md"
perl -ne '
    if (/^\| `framework-artifact-harvesting\.md` \|/) {
        print "| `artifact-harvesting.md` | Artifact harvesting: source discipline, criteria and what the harvest hooks do |\n";
        $a++; next;
    }
    if (/^\| `framework-source-of-truth\.md` \|/) { $b++; next; }
    print;
    END { die "row not found (a=$a b=$b)\n" unless $a == 1 && $b == 1; }
' "$s/readme-head.md" > "$s/readme-staged.md"
blob=$(git hash-object -w "$s/readme-staged.md")
git update-index --cacheinfo "100644,$blob,reference/README.md"
printf 'staged reference/README.md as blob %s\n' "$blob"
git diff --cached reference/README.md
printf -- '--- still unstaged:\n'
git diff reference/README.md
