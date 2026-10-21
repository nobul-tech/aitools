#!/usr/bin/env bash
# test-inline-embed.sh -- simulate B5.4: embed aitools-profile.js in a PS1 here-string,
# pipe through build-deploy's inline_lib_ps1 perl, extract the JS back, node --check it.
set -euo pipefail
M="/Users/new-jose/repos/aitools/.scratch/session-360aa8f3-8/missions/S5-Profile"
JS="$M/S5-Profile-drafts/scripts/aitools-profile.js"
LIBPS1="/Users/new-jose/repos/aitools/scripts/aitools-lib.ps1"
LIBSH="/Users/new-jose/repos/aitools/scripts/aitools-lib.sh"
T="$M/tests/review/run-inline"
rm -rf "$T"
mkdir -p "$T"
{
    printf '%s\n' '$embeddedProfileJs = @'"'"
    cat "$JS"
    printf '%s\n' "'@"
} | perl -e '
    open my $lib, "<", $ARGV[0] or die "Cannot open lib: $!";
    my $content = do { local $/; <$lib> };
    close $lib;
    while (<STDIN>) { if (/aitools-lib\.ps1/) { print $content; } else { print; } }
' "$LIBPS1" > "$T/gen.ps1"
perl -ne 'print if 2 .. /^\x27@$/ and !/^\x27@$/' "$T/gen.ps1" > "$T/extracted-ps1.js"
printf 'PS1 lines: original JS %s, extracted %s\n' "$(wc -l < "$JS")" "$(wc -l < "$T/extracted-ps1.js")"
rc=0
node --check "$T/extracted-ps1.js" > "$T/check-ps1.txt" 2>&1 || rc=$?
printf 'PS1 node --check exit=%s\n' "$rc"
perl -ne 'print if $. <= 6' "$T/check-ps1.txt"
rc=0
node "$T/extracted-ps1.js" machine-id > "$T/run-ps1.txt" 2>&1 || rc=$?
printf 'PS1 extracted resolver run exit=%s (1 = the resolver contract "nothing found")\n' "$rc"
# Bash side: same with inline_lib_bash pattern
{
    printf '%s\n' "cat > x.js <<'__EMBEDDED_PROFILE_JS__'"
    cat "$JS"
    printf '%s\n' '__EMBEDDED_PROFILE_JS__'
} | perl -e '
    open my $lib, "<", $ARGV[0] or die "Cannot open lib: $!";
    my $content = do { local $/; <$lib> };
    close $lib;
    while (<STDIN>) { if (/source.*aitools-lib\.sh/) { print $content; } else { print; } }
' "$LIBSH" > "$T/gen.sh"
printf 'bash: original+2 lines=%s generated lines=%s\n' "$(($(wc -l < "$JS") + 2))" "$(wc -l < "$T/gen.sh")"
