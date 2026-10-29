#!/usr/bin/env bash
# test-fanout-lib.sh -- tests for the fan-out helpers in scripts/aitools-lib.sh and
# scripts/aitools-lib.ps1 (plans/skills-and-rules-fanout.md section 3.3, batch FO-1):
# the deploy tracker's "removed" outcome and unknown outcomes (counted as failed),
# rule_name_kind / Get-RuleNameKind, skill_name_kind / Get-SkillNameKind,
# read_harness_manifest / Read-HarnessManifest (rules and skills: ok, header-bad,
# BOM, CRLF, invalid lines, duplicates, unreadable, unknown kind),
# read_rules_manifest / Read-RulesManifest (same output as the general reader for
# rules; setup-user-cursor defines no copy of its own), fanout_text_equal / Test-FanoutTextEqual and fanout_dir_matches /
# Test-FanoutDirMatches (match, extra or missing file, *.bak.* ignored, empty dir,
# symlinks, unreadable entries).
#
# One bash process and one pwsh process each source the lib under an isolated
# HOME and log dir and run the whole case list; every result must equal the
# expectation, and bash must equal PowerShell (parity). Cases that need an
# unreadable file are left out when chmod cannot make one (root, Windows).
# Safe to re-run: everything lives in a temp dir removed on exit.
# Platform: macOS, Linux, Git Bash. Exit 1 if any case fails.
#
# Usage: bash tests/fanout-lib/test-fanout-lib.sh [--bash-only] [--help]
#   --bash-only               skip the PowerShell side (also when pwsh is missing)
#   AITOOLS_TEST_BASH=/bin/bash  run the lib under another bash (macOS 3.2)

set -uo pipefail

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    perl -ne 'print if $. >= 2 && $. <= 22' "$0"
    exit 0
fi

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TB="${AITOOLS_TEST_BASH:-bash}"
USE_PS=true
if [ "${1:-}" = "--bash-only" ] || ! command -v pwsh >/dev/null 2>&1; then USE_PS=false; fi

WORK="$(mktemp -d)"
cleanup() {
    # the unreadable fixtures must be readable again before rm can remove them
    chmod -R u+rwx "$WORK" 2>/dev/null || printf 'warn: chmod -R on %s failed\n' "$WORK" >&2
    rm -rf "$WORK"
}
trap cleanup EXIT

PASS=0
FAIL=0
SKIP=0
ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$1"; }

F="$WORK/fix"      # fixtures; case arguments are paths relative to it
mkdir -p "$F"
TAB=$(printf '\t')

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
# mf FILE HEADER LINE...: a manifest; "|" in a LINE stands for the TAB
mf() {
    local file="$1" header="$2"; shift 2
    { printf '%s\n' "$header"
      for l in "$@"; do printf '%s\n' "$l" | tr '|' '\t'; done
    } > "$F/$file"
}
RH="# aitools rules manifest v1"
SH="# aitools skills manifest v1"

mf r-ok "$RH" "a.md|shared" "b.md|aitools" "c.md|dotprofile" "d.md|retired"
mf r-headerbad "# aitools rules manifest v2" "a.md|shared"
mf r-skillshead "$SH" "a.md|shared"
mf r-headeronly "$RH"
mf r-invalid "$RH" "noext|shared" "sub/x.md|shared" 'back\x.md|shared' "y.bak.2.md|shared" \
    "z.md|bogus" "w.md" "v.md|shared|extra" "" "u.md|shared" "U.md|dotprofile" "|shared" \
    ".hidden.md|shared" "my-skill|shared"
printf '\xEF\xBB\xBF# aitools rules manifest v1\na.md\tshared\n' > "$F/r-bom"
printf '# aitools rules manifest v1\r\na.md\tshared\r\nb.md\taitools\r\ne.md\tshared\r' > "$F/r-crlf"
printf '# aitools rules manifest v1' > "$F/r-nolf"
printf '# aitools rules manifest v1\r' > "$F/r-crnolf"
: > "$F/r-empty"
mkdir -p "$F/r-dir"

mf s-ok "$SH" "my-skill|shared" "Other|aitools" "third|dotprofile" "gone|retired"
mf s-ruleshead "$RH" "my-skill|shared"
mf s-invalid "$SH" ".hidden|shared" "a/b|shared" 'a\b|shared' "x.bak.1|shared" "dup|shared" \
    "DUP|aitools" "ok.md|shared" "q|nope" "My Skill|dotprofile" "|shared"
printf '\xEF\xBB\xBF# aitools skills manifest v1\r\nmy-skill\tshared\r\n' > "$F/s-bomcrlf"

# text_equal fixtures
mkdir -p "$F/t"
printf 'a\n' > "$F/t/a-lf"
printf 'a\r\n\n' > "$F/t/a-crlf2"
printf 'a' > "$F/t/a-none"
printf 'b\n' > "$F/t/b"
printf 'a\r\nb\n' > "$F/t/ab-crlf"
printf 'a\nb\n' > "$F/t/ab-lf"
: > "$F/t/empty"
printf '\n' > "$F/t/nl"
printf '\xff\xfe\xc3\xa9\n' > "$F/t/bin1"
printf '\xff\xfe\xc3\xa9' > "$F/t/bin2"
mkdir -p "$F/t/dir"

# dir_matches fixtures: d/<case>/T (the deployed copy) and d/<case>/C (harness copy)
skill() {  # skill DIR: a small skill tree
    mkdir -p "$1/sub/deep"
    printf -- '---\nname: s\n---\nBody\n' > "$1/SKILL.md"
    printf 'x\n' > "$1/sub/x.txt"
    printf 'y\n' > "$1/sub/deep/y.sh"
}
D="$F/d"
skill "$D/match/T"; skill "$D/match/C"
printf -- '---\r\nname: s\r\n---\r\nBody\r\n\r\n' > "$D/match/C/SKILL.md.crlf"   # not under T: ignored
printf -- '---\nname: s\n---\nBody\r\n\n' > "$D/match/C/SKILL.md"            # trailing CR/LF differ only
skill "$D/extra/T"; skill "$D/extra/C"; printf 'user\n' > "$D/extra/T/mine.md"
skill "$D/candextra/T"; skill "$D/candextra/C"; printf 'new\n' > "$D/candextra/C/new.md"
skill "$D/differ/T"; skill "$D/differ/C"; printf 'y2\n' > "$D/differ/T/sub/deep/y.sh"
skill "$D/innercr/T"; skill "$D/innercr/C"; printf 'x\r\ny\n' > "$D/innercr/T/sub/x.txt"; printf 'x\ny\n' > "$D/innercr/C/sub/x.txt"
skill "$D/bak/T"; skill "$D/bak/C"
printf 'old\n' > "$D/bak/T/SKILL.md.bak.2026-10-26T010203Z"
printf 'old\n' > "$D/bak/T/sub/X.BAK.1"
mkdir -p "$D/empty/T" "$D/empty/C"
mkdir -p "$D/onlybak/T" "$D/onlybak/C"; printf 'old\n' > "$D/onlybak/T/SKILL.md.bak.1"
mkdir -p "$D/emptysub/T/sub" "$D/emptysub/C"
skill "$D/hidden/T"; skill "$D/hidden/C"; printf 'ds\n' > "$D/hidden/T/.DS_Store"
skill "$D/candmissing/T"
skill "$D/canddir/T"; skill "$D/canddir/C"; rm -f "$D/canddir/C/sub/x.txt"; mkdir -p "$D/canddir/C/sub/x.txt"
mkdir -p "$D/targetfile"; printf 'f\n' > "$D/targetfile/T"; skill "$D/targetfile/C"
mkdir -p "$D/targetmissing"; skill "$D/targetmissing/C"
SYMLINKS=true
skill "$D/linktarget/real"; skill "$D/linktarget/C"
if ! ln -s "$D/linktarget/real" "$D/linktarget/T" 2>/dev/null || [ ! -L "$D/linktarget/T" ]; then
    SYMLINKS=false   # Git Bash without symlink support: the symlink cases are skipped
fi
skill "$D/linkinside/T"; skill "$D/linkinside/C"
if $SYMLINKS; then
    rm -f "$D/linkinside/T/sub/x.txt"
    ln -s "$D/linkinside/C/sub/x.txt" "$D/linkinside/T/sub/x.txt"
fi
skill "$D/linkdir/T"; skill "$D/linkdir/C"
if $SYMLINKS; then ln -s "$D/linkdir/C/sub" "$D/linkdir/T/other"; fi
# deploy_managed_file / Deploy-ManagedFile onto a symlink destination, one copy
# per shell: dangling (failed, nothing written through it; also in a dry run)
# and live (written through, the link kept)
if $SYMLINKS; then
    for tag in sh ps; do
        L="$F/ml/$tag"
        mkdir -p "$L"
        ln -s "$L/nowhere.md" "$L/dangling.md"
        ln -s "$L/nowhere2.md" "$L/dangling2.md"
        printf 'old\n' > "$L/live-target.md"
        ln -s "$L/live-target.md" "$L/live.md"
    done
fi

# FIFO fixtures (a FIFO under TARGET, and one in CAND at a TARGET file's path):
# both must give 1 without reading (reading a FIFO blocks)
FIFOS=true
skill "$D/fifo/T"; skill "$D/fifo/C"; printf 'p\n' > "$D/fifo/C/pipe"
skill "$D/candfifo/T"; skill "$D/candfifo/C"; printf 'p\n' > "$D/candfifo/T/p.txt"
if ! command -v mkfifo >/dev/null 2>&1 || ! mkfifo "$D/fifo/T/pipe" "$D/candfifo/C/p.txt"; then
    FIFOS=false
fi

# backup_dir fixtures, one copy per shell (each run backs them up): plain;
# a name with [ ] * ? next to 6 old backups and decoys a glob would match
# (another directory's backups, a non-stamp suffix); no top-level *.md; missing
SPECIAL=true
for tag in sh ps; do
    B="$F/bd/$tag"
    mkdir -p "$B/plain/rules" "$B/nomd/d" "$B/missing" "$B/unread/d" "$B/mdcase/upper" "$B/partial/part"
    printf 'a\n' > "$B/plain/rules/a.md"
    printf 'u\n' > "$B/mdcase/upper/X.MD"                 # the *.md count ignores case
    printf 'a\n' > "$B/partial/part/a.md"                 # + an unreadable file: the copy fails part-way
    printf 's\n' > "$B/partial/part/secret.txt"
    # a file symlink and a directory symlink inside the backed-up directory
    mkdir -p "$B/link/lk" "$B/link/outdir"
    printf 'a\n' > "$B/link/lk/a.md"
    printf 'outside\n' > "$B/link/outside.txt"
    printf 'x\n' > "$B/link/outdir/x.txt"
    if $SYMLINKS; then
        ln -s "$B/link/outside.txt" "$B/link/lk/l.md"
        ln -s "$B/link/outdir" "$B/link/lk/sub"
    fi
    printf 'x\n' > "$B/nomd/d/x.txt"
    printf 'a\n' > "$B/unread/d/a.md"
    if mkdir -p "$B/special/r[1]*?"; then
        printf 'a\n' > "$B/special/r[1]*?/a.md"
        for d in 1 2 3 4 5 6; do mkdir -p "$B/special/r[1]*?.bak.2020-01-0${d}T000000Z"; done
        mkdir -p "$B/special/r1zz.bak.2020-01-01T000000Z" "$B/special/r[1]*?.bak.foo" \
            "$B/special/r[1]*?.bak.2020-01-01T000000Z.bak.2020-01-02T000000Z" \
            "$B/special/r[1]*?x.bak.2020-01-07T000000Z"
    else
        SPECIAL=false   # a file system that refuses * ? in names (Windows)
    fi
done

# Unreadable fixtures (skipped when chmod 000 still leaves them readable)
UNREAD=true
skill "$D/unread2/T"; skill "$D/unread2/C"
printf 'a\n' > "$D/unread2/T/a.txt"; printf 'a\n' > "$D/unread2/C/a.txt"
printf 'b\n' > "$D/unread2/T/b.txt"; printf 'b\n' > "$D/unread2/C/b.txt"
chmod 000 "$D/unread2/T/a.txt" "$D/unread2/T/b.txt"
skill "$D/noexec/T"; skill "$D/noexec/C"; chmod 644 "$D/noexec/T/sub"
chmod 000 "$F/bd/sh/unread/d" "$F/bd/ps/unread/d"
chmod 000 "$F/bd/sh/partial/part/secret.txt" "$F/bd/ps/partial/part/secret.txt"
printf '%s\n' "$RH" > "$F/r-unread"; chmod 000 "$F/r-unread"
printf 'a\n' > "$F/t/unread"; chmod 000 "$F/t/unread"
skill "$D/unreadfile/T"; skill "$D/unreadfile/C"; chmod 000 "$D/unreadfile/T/sub/x.txt"
skill "$D/unreadsub/T"; skill "$D/unreadsub/C"; chmod 000 "$D/unreadsub/T/sub"
skill "$D/unreadcand/T"; skill "$D/unreadcand/C"; chmod 000 "$D/unreadcand/C/SKILL.md"
skill "$D/unreaddiffer/T"; skill "$D/unreaddiffer/C"; chmod 000 "$D/unreaddiffer/T/sub/x.txt"
printf 'changed\n' > "$D/unreaddiffer/T/SKILL.md"
if [ -r "$F/r-unread" ]; then UNREAD=false; fi

# ---------------------------------------------------------------------------
# Cases: id <TAB> expected <TAB> call <TAB> arg1 [<TAB> arg2]; no empty fields.
# Manifest results: lines joined with " ;; ", rule lines first, TAB shown as ^,
# CR as <CR>, "(none)" for no line, "fail" when the reader fails or throws.
# ---------------------------------------------------------------------------
CASES="$WORK/cases"
{
# deploy tracker ("pairs" outcome:item, comma separated)
printf 't-removed\tDETAIL|t|removed: a.md ;; OK|t|1 removed ;; text=1 removed ;; errors=0\ttracker\tremoved:a.md\n'
printf 't-unknown\tDETAIL|t|failed: b.md ;; ERROR|t|1 failed ;; text=1 failed ;; errors=1\ttracker\tbogus:b.md\n'
printf 't-blank\tDETAIL|t|failed: x.md ;; ERROR|t|1 failed ;; text=1 failed ;; errors=1\ttracker\t:x.md\n'
printf 't-mix\tDETAIL|t|added: a.md ;; DETAIL|t|removed: b.md ;; DETAIL|t|failed: d.md ;; ERROR|t|1 failed ;; text=1 added, 1 removed, 1 verified, 1 failed ;; errors=1\ttracker\tadded:a.md,removed:b.md,verified:c.md,bogus:d.md,preserved:e.md\n'
printf 't-order\tDETAIL|t|accept & adopt: a.md ;; DETAIL|t|removed: b.md ;; DETAIL|t|updated: d.md ;; DETAIL|t|added: e.md ;; OK|t|1 added, 1 updated, 1 accepted, 1 removed, 1 verified ;; text=1 added, 1 updated, 1 accepted, 1 removed, 1 verified ;; errors=0\ttracker\taccept & adopt:a.md,removed:b.md,verified:c.md,updated:d.md,created:e.md\n'
printf 't-skip\tDETAIL|t|removed: a.md ;; DETAIL|t|skipped: b.md ;; WARN|t|1 skipped (user review) ;; text=1 removed ;; errors=0\ttracker\tremoved:a.md,skipped:b.md\n'
# every count 0 (only preserved / skipped items): the text is "n/a (nothing to deploy)", never "verified"
printf 't-preserved\tOK|t|n/a (nothing to deploy) ;; text=n/a (nothing to deploy) ;; errors=0\ttracker\tpreserved:a.md\n'
printf 't-skiponly\tDETAIL|t|skipped: a.md ;; WARN|t|1 skipped (user review) ;; text=n/a (nothing to deploy) ;; errors=0\ttracker\tskipped:a.md\n'
# outcomes are matched case-sensitively in both shells
printf 't-case\tDETAIL|t|failed: x.md ;; DETAIL|t|failed: y.md ;; DETAIL|t|failed: z.md ;; ERROR|t|3 failed ;; text=3 failed ;; errors=3\ttracker\tRemoved:x.md,Added:y.md,CREATED:z.md\n'
# name kinds
for spec in "a.md rule skill" "A.MD rule skill" ".hidden.md hidden hidden" ".aitools-skills-manifest hidden hidden" \
            "x.md.bak.2026-10-22T010203Z backup backup" "X.MD.BAK.1 backup backup" "odd.bak.2026.md backup backup" \
            "Skill.Bak.1 backup backup" "skill.bak other skill" "notes.txt other skill" "my-skill other skill" \
            "My_Skill-2 other skill"; do
    set -- $spec
    printf 'rk-%s\t%s\trkind\t%s\n' "$1" "$2" "$1"
    printf 'sk-%s\t%s\tskind\t%s\n' "$1" "$3" "$1"
done
# manifests
printf 'm-r-ok\trule^a.md^shared ;; rule^b.md^aitools ;; rule^c.md^dotprofile ;; rule^d.md^retired\tmanifest\tr-ok\trules\n'
printf 'm-r-headerbad\theader-bad\tmanifest\tr-headerbad\trules\n'
printf 'm-r-skillshead\theader-bad\tmanifest\tr-skillshead\trules\n'
printf 'm-r-headeronly\t(none)\tmanifest\tr-headeronly\trules\n'
printf 'm-r-invalid\t%s\tmanifest\tr-invalid\trules\n' 'rule^u.md^shared ;; rule^.hidden.md^shared ;; invalid^noext<TAB>shared ;; invalid^sub/x.md<TAB>shared ;; invalid^back\x.md<TAB>shared ;; invalid^y.bak.2.md<TAB>shared ;; invalid^z.md<TAB>bogus ;; invalid^w.md ;; invalid^v.md<TAB>shared<TAB>extra ;; invalid^U.md<TAB>dotprofile ;; invalid^<TAB>shared ;; invalid^my-skill<TAB>shared'
printf 'm-r-bom\trule^a.md^shared\tmanifest\tr-bom\trules\n'
printf 'm-r-crlf\trule^a.md^shared ;; rule^b.md^aitools ;; invalid^e.md<TAB>shared<CR>\tmanifest\tr-crlf\trules\n'
printf 'm-r-nolf\t(none)\tmanifest\tr-nolf\trules\n'
printf 'm-r-crnolf\theader-bad\tmanifest\tr-crnolf\trules\n'
printf 'm-r-empty\theader-bad\tmanifest\tr-empty\trules\n'
printf 'm-r-dir\tfail\tmanifest\tr-dir\trules\n'
printf 'm-r-missing\tfail\tmanifest\tr-missing\trules\n'
printf 'm-s-ok\trule^my-skill^shared ;; rule^Other^aitools ;; rule^third^dotprofile ;; rule^gone^retired\tmanifest\ts-ok\tskills\n'
printf 'm-s-ruleshead\theader-bad\tmanifest\ts-ruleshead\tskills\n'
printf 'm-s-invalid\t%s\tmanifest\ts-invalid\tskills\n' 'rule^dup^shared ;; rule^ok.md^shared ;; rule^My Skill^dotprofile ;; invalid^.hidden<TAB>shared ;; invalid^a/b<TAB>shared ;; invalid^a\b<TAB>shared ;; invalid^x.bak.1<TAB>shared ;; invalid^DUP<TAB>aitools ;; invalid^q<TAB>nope ;; invalid^<TAB>shared'
printf 'm-s-bomcrlf\trule^my-skill^shared\tmanifest\ts-bomcrlf\tskills\n'
printf 'm-s-rulesfile\t%s\tmanifest\tr-ok\tskills\n' 'header-bad'
printf 'm-kind-caps\tfail\tmanifest\tr-ok\tRules\n'
printf 'm-kind-bogus\tfail\tmanifest\tr-ok\tbogus\n'
# read_harness_manifest exit codes (bash only: PowerShell throws): 0 read,
# 1 missing / unreadable / directory, 2 unknown KIND
printf 'mrc-ok\trc=0\tsh_mrc\tr-ok\trules\n'
printf 'mrc-headerbad\trc=0\tsh_mrc\tr-headerbad\trules\n'
printf 'mrc-missing\trc=1\tsh_mrc\tr-missing\trules\n'
printf 'mrc-dir\trc=1\tsh_mrc\tr-dir\trules\n'
printf 'mrc-kind\trc=2\tsh_mrc\tr-ok\tRules\n'
# read_rules_manifest = read_harness_manifest FILE rules (output, stderr and exit code)
for m in r-ok r-headerbad r-skillshead r-headeronly r-invalid r-bom r-crlf r-nolf r-crnolf r-empty r-missing s-ok; do
    printf 'rr-%s\tsame\trr\t%s\n' "$m" "$m"
done
# text equality
printf 'te-trailing\trc=0\tteq\tt/a-lf\tt/a-crlf2\n'
printf 'te-nonl\trc=0\tteq\tt/a-none\tt/a-lf\n'
printf 'te-differ\trc=1\tteq\tt/a-lf\tt/b\n'
printf 'te-innercr\trc=1\tteq\tt/ab-crlf\tt/ab-lf\n'
printf 'te-emptynl\trc=0\tteq\tt/empty\tt/nl\n'
printf 'te-bytes\trc=0\tteq\tt/bin1\tt/bin2\n'
printf 'te-missing\trc=2\tteq\tt/a-lf\tt/nope\n'
printf 'te-missing1\trc=2\tteq\tt/nope\tt/a-lf\n'
printf 'te-dir\trc=2\tteq\tt/dir\tt/a-lf\n'
printf 'te-emptyarg\trc=2\tteq\t-\tt/a-lf\n'
# perl itself fails (a stub perl first on PATH): rc 2 and a detail line (bash only)
printf 'te-perlfail\trc=2\tsh_teqperl\tt/a-lf\tt/b\n'
# directory match
printf 'dm-match\trc=0\tdmatch\td/match/T\td/match/C\n'
printf 'dm-extra\trc=1\tdmatch\td/extra/T\td/extra/C\n'
printf 'dm-candextra\trc=0\tdmatch\td/candextra/T\td/candextra/C\n'
printf 'dm-differ\trc=1\tdmatch\td/differ/T\td/differ/C\n'
printf 'dm-innercr\trc=1\tdmatch\td/innercr/T\td/innercr/C\n'
printf 'dm-bak\trc=0\tdmatch\td/bak/T\td/bak/C\n'
printf 'dm-empty\trc=1\tdmatch\td/empty/T\td/empty/C\n'
printf 'dm-onlybak\trc=1\tdmatch\td/onlybak/T\td/onlybak/C\n'
printf 'dm-emptysub\trc=1\tdmatch\td/emptysub/T\td/emptysub/C\n'
printf 'dm-hidden\trc=1\tdmatch\td/hidden/T\td/hidden/C\n'
printf 'dm-candmissing\trc=1\tdmatch\td/candmissing/T\td/candmissing/C\n'
printf 'dm-canddir\trc=1\tdmatch\td/canddir/T\td/canddir/C\n'
printf 'dm-targetfile\trc=1\tdmatch\td/targetfile/T\td/targetfile/C\n'
printf 'dm-targetmissing\trc=1\tdmatch\td/targetmissing/T\td/targetmissing/C\n'
printf 'dm-emptytarget\trc=1\tdmatch\t-\td/match/C\n'
printf 'dm-emptycand\trc=1\tdmatch\td/match/T\t-\n'
if $FIFOS; then
    printf 'dm-fifo\trc=1\tdmatch\td/fifo/T\td/fifo/C\n'
    printf 'dm-candfifo\trc=1\tdmatch\td/candfifo/T\td/candfifo/C\n'
fi
# backup_dir / Backup-Dir ("@" is the shell's own fixture copy); <TS> is this run's stamp
printf 'bd-plain\tok=true reason=- path=rules.bak.<TS> copied=yes siblings=rules,rules.bak.<TS>\tbdir\tbd/@/plain/rules\n'
printf 'bd-nomd\tok=false reason=no top-level *.md path=- copied=no siblings=d\tbdir\tbd/@/nomd/d\n'
printf 'bd-missing\tok=false reason=no directory path=- copied=no siblings=(none)\tbdir\tbd/@/missing/nope\n'
printf 'bd-mdcase\tok=true reason=- path=upper.bak.<TS> copied=yes siblings=upper,upper.bak.<TS>\tbdir\tbd/@/mdcase/upper\n'
if $SYMLINKS; then
    # symlinks inside the directory: cp -R keeps them as links (sh); Copy-DirectoryTree copies their content (ps)
    printf 'bd-link-sh\tok=true l.md=link sub=link sub/x.txt=yes\tsh_bdirlink\tbd/@/link/lk\n'
    printf 'bd-link-ps\tok=true l.md=file:outside sub=dir sub/x.txt=yes\tps_bdirlink\tbd/@/link/lk\n'
fi
if $SPECIAL; then
    printf 'bd-special\t%s\tbdir\t%s\n' \
        'ok=true reason=- path=r[1]*?.bak.<TS> copied=yes siblings=r1zz.bak.2020-01-01T000000Z,r[1]*?,r[1]*?.bak.2020-01-01T000000Z.bak.2020-01-02T000000Z,r[1]*?.bak.2020-01-03T000000Z,r[1]*?.bak.2020-01-04T000000Z,r[1]*?.bak.2020-01-05T000000Z,r[1]*?.bak.2020-01-06T000000Z,r[1]*?.bak.<TS>,r[1]*?.bak.foo,r[1]*?x.bak.2020-01-07T000000Z' \
        'bd/@/special/r[1]*?'
fi
if $SYMLINKS; then
    printf 'dm-linktarget\trc=1\tdmatch\td/linktarget/T\td/linktarget/C\n'
    printf 'dm-linkinside\trc=1\tdmatch\td/linkinside/T\td/linkinside/C\n'
    printf 'dm-linkdir\trc=1\tdmatch\td/linkdir/T\td/linkdir/C\n'
fi
if $SYMLINKS; then
    printf 'ml-dangling\tresult=failed target=absent\tdmf\tml/@/dangling.md\n'
    printf 'ml-dangling-dry\tresult=failed target=absent\tdmfdry\tml/@/dangling2.md\n'
    printf 'ml-live\tresult=updated target=new\tdmf\tml/@/live.md\n'
fi
if $UNREAD; then
    printf 'm-r-unread\tfail\tmanifest\tr-unread\trules\n'
    printf 'rr-r-unread\tsame\trr\tr-unread\n'
    printf 'te-unread\trc=2\tteq\tt/unread\tt/a-lf\n'
    printf 'dm-unreadfile\trc=2\tdmatch\td/unreadfile/T\td/unreadfile/C\n'
    printf 'dm-unreadsub\trc=2\tdmatch\td/unreadsub/T\td/unreadsub/C\n'
    printf 'dm-unreadcand\trc=2\tdmatch\td/unreadcand/T\td/unreadcand/C\n'
    printf 'dm-unreaddiffer\trc=2\tdmatch\td/unreaddiffer/T\td/unreaddiffer/C\n'
    printf 'dm-unread2\trc=2\tdmatch\td/unread2/T\td/unread2/C\n'
    printf 'dm-noexec\trc=2\tdmatch\td/noexec/T\td/noexec/C\n'
    printf 'mrc-unread\trc=1\tsh_mrc\tr-unread\trules\n'
    printf 'bd-unread\tok=false reason=cannot list path=- copied=no siblings=d\tbdir\tbd/@/unread/d\n'
    # a copy that fails part-way leaves no stamped directory behind (removed, or renamed .bak.incomplete.)
    printf 'bd-partial\tok=false reason=copy failed path=- copied=no siblings=part\tbdir\tbd/@/partial/part\n'
fi
} > "$CASES"
if ! $SYMLINKS; then SKIP=$((SKIP + 8)); printf '  skip symlink cases (ln -s does not make symlinks here)\n'; fi
if ! $FIFOS; then SKIP=$((SKIP + 2)); printf '  skip FIFO cases (no mkfifo)\n'; fi
if ! $SPECIAL; then SKIP=$((SKIP + 1)); printf '  skip backup_dir special-name case (* ? not allowed in names here)\n'; fi
if ! $UNREAD; then SKIP=$((SKIP + 12)); printf '  skip unreadable cases (chmod 000 leaves files readable: root or Windows)\n'; fi

# A stub perl that fails, for te-perlfail
mkdir -p "$WORK/badperl"
printf '#!/bin/sh\necho "stub perl: boom" >&2\nexit 9\n' > "$WORK/badperl/perl"
chmod +x "$WORK/badperl/perl"

# The rr cases: setup-user-cursor's own manifest readers were deleted in FO-5
# (it uses the lib's, FAN-PLAN F1), so read_rules_manifest / Read-RulesManifest
# are compared with the lib's general reader for KIND rules (the m-r-* cases
# pin that reader's output). The comparison functions keep their old names.
CUR_SH="$WORK/cursor-copy.sh"
CUR_PS="$WORK/cursor-copy.ps1"
printf 'cursor_read_rules_manifest() { read_harness_manifest "$1" rules; }\n' > "$CUR_SH"
printf 'function Read-CursorRulesManifest([string]$Path) { return Read-HarnessManifest -Path $Path -Kind "rules" }\n' > "$CUR_PS"
if grep -q '^read_rules_manifest()' "$REPO/scripts/setup-user-cursor.sh" || grep -q '^function Read-RulesManifest\b' "$REPO/scripts/setup-user-cursor.ps1"; then
    bad "setup-user-cursor defines its own read_rules_manifest / Read-RulesManifest again (use the lib's, FAN-PLAN F1)"
fi

# ---------------------------------------------------------------------------
# Drivers
# ---------------------------------------------------------------------------
cat > "$WORK/drive.sh" <<'DRIVE'
# Source the lib, run every case from $CASES, write "<id><TAB><result>" lines to $OUT
set -uo pipefail
source "$REPO/scripts/aitools-lib.sh"
logging_init "test-fanout-lib"
source "$CUR_SH"
TAB=$(printf '\t')
: > "$OUT"
emit() { printf '%s\t%s\n' "$1" "$2" >> "$OUT"; }
fx() {  # fixture path: "-" is the empty string, "@" this shell's copy (sh)
    if [ "$1" = "-" ]; then return 0; fi
    local p="$F/$1"
    printf '%s' "${p//@/sh}"
}
names_of() {  # the sorted top-level names of directory $1, comma-joined
    perl -e 'opendir my $dh, $ARGV[0] or exit 0; print join(",", sort grep { $_ ne "." && $_ ne ".." } readdir $dh)' "$1"
}
entry_type() {  # link | dir | file:<first line> | missing (a link is not followed)
    perl -e 'my $p = shift; if (-l $p) { print "link" } elsif (-d $p) { print "dir" }
             elsif (-f $p) { open my $fh, "<", $p or do { print "file:unreadable"; exit 0 }; my $c = <$fh>; $c = "" unless defined $c; chomp $c; print "file:$c" }
             else { print "missing" }' "$1"
}
norm() {  # manifest reader stdout -> one line (rule lines first)
    perl -e 'my (@r, @i); while (<STDIN>) { s/\n\z//; s/\t/^/g; s/\r/<CR>/g; if (/\Arule\^/) { push @r, $_ } else { push @i, $_ } }
             my @a = (@r, @i); print @a ? join(" ;; ", @a) : "(none)"'
}
while IFS="$TAB" read -r id want call a1 a2 <&3; do
    case "$call" in
        tracker)
            export AITOOLS_SUMMARY_FILE="$WORK/sum-sh-$id"
            : > "$AITOOLS_SUMMARY_FILE"
            e0=$ERRORS
            deploy_tracker_init
            rest="$a1,"
            while [ -n "$rest" ]; do
                pair=${rest%%,*}; rest=${rest#*,}
                deploy_tracker_record "${pair%%:*}" t "${pair#*:}"
            done
            deploy_tracker_summary t
            rows=$(perl -e 'my @l = <STDIN>; s/\n\z// for @l; print join(" ;; ", @l)' < "$AITOOLS_SUMMARY_FILE")
            emit "$id" "$rows ;; text=$DEPLOY_TRACKER_TEXT ;; errors=$((ERRORS - e0))" ;;
        rkind) emit "$id" "$(rule_name_kind "$a1")" ;;
        skind) emit "$id" "$(skill_name_kind "$a1")" ;;
        manifest)
            if out=$(read_harness_manifest "$F/$a1" "$a2" 2>"$WORK/err-sh"); then
                emit "$id" "$(printf '%s\n' "$out" | perl -ne 'print if length > 1' | norm)"
            else
                emit "$id" "fail"
            fi ;;
        rr)
            # same output and message; exit: both 0 or both non-zero
            o1=$(read_rules_manifest "$F/$a1" 2>&1); r1=$?
            o2=$(cursor_read_rules_manifest "$F/$a1" 2>&1); r2=$?
            z1=ok; [ "$r1" -eq 0 ] || z1=fail
            z2=ok; [ "$r2" -eq 0 ] || z2=fail
            if [ "$o1" = "$o2" ] && [ "$z1" = "$z2" ]; then emit "$id" "same"; else emit "$id" "differ (lib rc=$r1, cursor rc=$r2)"; fi ;;
        sh_mrc) rc=0; read_harness_manifest "$(fx "$a1")" "$a2" > /dev/null 2>&1 || rc=$?; emit "$id" "rc=$rc" ;;
        teq) rc=0; fanout_text_equal "$(fx "$a1")" "$(fx "$a2")" || rc=$?; emit "$id" "rc=$rc" ;;
        sh_teqperl) rc=0; PATH="$WORK/badperl:$PATH" fanout_text_equal "$(fx "$a1")" "$(fx "$a2")" || rc=$?; emit "$id" "rc=$rc" ;;
        dmatch) rc=0; fanout_dir_matches "$(fx "$a1")" "$(fx "$a2")" || rc=$?; emit "$id" "rc=$rc" ;;
        dmf|dmfdry)
            p=$(fx "$a1")
            if [ "$call" = "dmfdry" ]; then DRY_RUN=true; else DRY_RUN=false; fi
            deploy_managed_file "new" "$p" "t" "$(basename "$p")" "" < /dev/null > /dev/null 2>&1
            DRY_RUN=false
            tgt=$(perl -e 'my $l = readlink $ARGV[0]; if (!defined $l) { print "notlink"; exit 0 }
                           if (!-e $l) { print "target=absent"; exit 0 }
                           open my $fh, "<", $l or do { print "target=unreadable"; exit 0 };
                           local $/; my $c = <$fh>; $c =~ s/\n\z//; print "target=$c"' "$p")
            emit "$id" "result=$MANAGED_FILE_RESULT $tgt" ;;
        ps_*) ;;   # PowerShell-only case
        sh_bdirlink)
            p=$(fx "$a1")
            backup_dir "$p"
            x=no
            if [ -f "$BACKUP_DIR_PATH/sub/x.txt" ]; then x=yes; fi
            emit "$id" "ok=$BACKUP_DIR_OK l.md=$(entry_type "$BACKUP_DIR_PATH/l.md") sub=$(entry_type "$BACKUP_DIR_PATH/sub") sub/x.txt=$x" ;;
        bdir)
            p=$(fx "$a1")
            backup_dir "$p"
            copied=no   # yes: the copy holds the same top-level names as the source
            if [ "$BACKUP_DIR_OK" = true ]; then
                src_names=$(names_of "$p"); bak_names=$(names_of "$BACKUP_DIR_PATH")
                if [ -n "$src_names" ] && [ "$src_names" = "$bak_names" ]; then copied=yes; fi
            fi
            bp="-"
            if [ -n "$BACKUP_DIR_PATH" ]; then bp=$(basename "$BACKUP_DIR_PATH"); fi
            sib=$(perl -e 'opendir my $dh, $ARGV[0] or do { print "cannot list"; exit 0 };
                           my @n = sort grep { $_ ne "." && $_ ne ".." } readdir $dh; print @n ? join(",", @n) : "(none)"' "$(dirname "$p")")
            res="ok=$BACKUP_DIR_OK reason=${BACKUP_DIR_REASON:--} path=$bp copied=$copied siblings=$sib"
            emit "$id" "$(printf '%s' "$res" | perl -pe 's/(?!2020)[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}Z/<TS>/g')" ;;
        *) emit "$id" "unknown call $call" ;;
    esac
done 3< "$CASES"
DRIVE

cat > "$WORK/drive.ps1" <<'DRIVE'
# Dot-source the lib, run every case from $env:CASES, write "<id><TAB><result>" lines to $env:OUT
$ErrorActionPreference = "Stop"
. (Join-Path $env:REPO "scripts/aitools-lib.ps1")
Initialize-Logging "test-fanout-lib"
. $env:CUR_PS
$F = $env:F
$results = New-Object System.Collections.Generic.List[string]
function Format-Manifest($r) {
    if ($r.Status -eq "header-bad") { return "header-bad" }
    $a = @()
    foreach ($x in $r.Rules) { $a += "rule^$($x.Name)^$($x.Source)" }
    foreach ($x in $r.Invalid) { $a += "invalid^$x" }
    $a = @($a | ForEach-Object { $_ -replace "`r", "<CR>" })
    if ($a.Count -eq 0) { return "(none)" }
    return ($a -join " ;; ")
}
function Resolve-Fx([string]$Rel) {  # "-" is the empty string, "@" this shell's copy (ps)
    if ($Rel -eq "-") { return "" }
    return (Join-Path $F $Rel).Replace("@", "ps")
}
function Get-Names([string]$Dir) {  # sorted top-level names, comma-joined (as names_of in drive.sh)
    if (-not [IO.Directory]::Exists($Dir)) { return "" }
    [string[]]$n = @([IO.Directory]::GetFileSystemEntries($Dir) | ForEach-Object { [IO.Path]::GetFileName($_) })
    [Array]::Sort($n, [StringComparer]::Ordinal)
    return ($n -join ",")
}
function Get-EntryType([string]$Path) {  # link | dir | file:<first line> | missing (as entry_type in drive.sh)
    $info = [IO.FileInfo]::new($Path)
    if ($null -ne $info.LinkTarget) { return "link" }
    if ([IO.Directory]::Exists($Path)) { return "dir" }
    if ([IO.File]::Exists($Path)) { return "file:" + (([IO.File]::ReadAllText($Path) -split "`n")[0]) }
    return "missing"
}
function Invoke-Reader([scriptblock]$Read) {
    try { return Format-Manifest (& $Read) } catch { LogDetail "reader threw: $_"; return "fail" }
}
foreach ($line in [IO.File]::ReadAllLines($env:CASES)) {
    $fields = $line -split "`t"   # (not $f: PowerShell names are case-insensitive, $F is the fixtures dir)
    $id = $fields[0]; $call = $fields[2]
    $a1 = if ($fields.Count -gt 3) { $fields[3] } else { "" }
    $a2 = if ($fields.Count -gt 4) { $fields[4] } else { "" }
    if ($call.StartsWith("sh_")) { continue }   # bash-only case (ps_ cases run only here)
    switch -CaseSensitive ($call) {
        "tracker" {
            $env:AITOOLS_SUMMARY_FILE = Join-Path $env:WORK "sum-ps-$id"
            [IO.File]::WriteAllText($env:AITOOLS_SUMMARY_FILE, "")
            $e0 = $script:errors
            Initialize-DeployTracker
            foreach ($pair in ($a1 -split ",")) {
                $c = $pair.IndexOf(":")
                Record-DeployOutcome -Outcome $pair.Substring(0, $c) -ToolName "t" -ItemName $pair.Substring($c + 1)
            }
            Write-DeployTrackerSummary -ToolName "t"
            $rows = @([IO.File]::ReadAllLines($env:AITOOLS_SUMMARY_FILE)) -join " ;; "
            $res = "$rows ;; text=$($script:deployTrackerText) ;; errors=$($script:errors - $e0)"
        }
        "rkind" { $res = Get-RuleNameKind $a1 }
        "skind" { $res = Get-SkillNameKind $a1 }
        "manifest" { $p = Join-Path $F $a1; $k = $a2; $res = Invoke-Reader { Read-HarnessManifest -Path $p -Kind $k } }
        "rr" {
            $p = Join-Path $F $a1
            $x = Invoke-Reader { Read-RulesManifest $p }
            $y = Invoke-Reader { Read-CursorRulesManifest $p }
            $res = if ($x -ceq $y) { "same" } else { "differ (lib $x, cursor $y)" }
        }
        "teq" { $res = "rc=" + (Test-FanoutTextEqual (Resolve-Fx $a1) (Resolve-Fx $a2)) }
        "dmatch" { $res = "rc=" + (Test-FanoutDirMatches (Resolve-Fx $a1) (Resolve-Fx $a2)) }
        { $_ -ceq "dmf" -or $_ -ceq "dmfdry" } {
            $p = Resolve-Fx $a1
            $DryRun = ($call -ceq "dmfdry")
            $r = Deploy-ManagedFile -Content "new" -DestPath $p -ToolName "t" -ItemName ([IO.Path]::GetFileName($p)) 6>$null
            $DryRun = $false
            $lt = [IO.FileInfo]::new($p).LinkTarget
            $tgt = if ($null -eq $lt) { "notlink" }
                   elseif (-not (Test-Path -LiteralPath $lt)) { "target=absent" }
                   else { "target=" + ([IO.File]::ReadAllText($lt) -replace '\n\z', '') }
            $res = "result=$r $tgt"
        }
        "ps_bdirlink" {
            $p = Resolve-Fx $a1
            Backup-Dir -DirPath $p
            $b = $script:BackupDirPath
            $x = if ([IO.File]::Exists([IO.Path]::Combine($b, "sub", "x.txt"))) { "yes" } else { "no" }
            $ok = if ($script:BackupDirOk) { "true" } else { "false" }
            $res = "ok=$ok l.md=$(Get-EntryType ([IO.Path]::Combine($b, 'l.md'))) sub=$(Get-EntryType ([IO.Path]::Combine($b, 'sub'))) sub/x.txt=$x"
        }
        "bdir" {
            $p = Resolve-Fx $a1
            Backup-Dir -DirPath $p
            $copied = "no"   # yes: the copy holds the same top-level names as the source
            if ($script:BackupDirOk) {
                $srcNames = Get-Names $p; $bakNames = Get-Names $script:BackupDirPath
                if ($srcNames -and $srcNames -ceq $bakNames) { $copied = "yes" }
            }
            $bp = if ($script:BackupDirPath) { [IO.Path]::GetFileName($script:BackupDirPath) } else { "-" }
            try {
                [string[]]$sib = @([IO.Directory]::GetFileSystemEntries([IO.Path]::GetDirectoryName($p)) | ForEach-Object { [IO.Path]::GetFileName($_) })
                [Array]::Sort($sib, [StringComparer]::Ordinal)
                $sibText = if ($sib.Count -gt 0) { $sib -join "," } else { "(none)" }
            } catch {
                LogDetail "driver: cannot list the parent of ${p}: $_"
                $sibText = "cannot list"
            }
            $reason = if ($script:BackupDirReason) { $script:BackupDirReason } else { "-" }
            $ok = if ($script:BackupDirOk) { "true" } else { "false" }
            $res = "ok=$ok reason=$reason path=$bp copied=$copied siblings=$sibText" -replace '(?!2020)[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{6}Z', '<TS>'
        }
        default { $res = "unknown call $call" }
    }
    $results.Add("$id`t$res")
}
[IO.File]::WriteAllText($env:OUT, (($results -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
DRIVE

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
run_shell() {  # run_shell sh|ps: run the driver under an isolated HOME
    local s="$1" h="$WORK/home-$1"
    mkdir -p "$h"
    if [ "$s" = "sh" ]; then
        env HOME="$h" AITOOLS_LOG_DIR="$WORK/logs-sh" AITOOLS_SUMMARY_FILE="$WORK/sum-sh" \
            REPO="$REPO" CASES="$CASES" F="$F" WORK="$WORK" OUT="$WORK/out-sh" CUR_SH="$CUR_SH" \
            "$TB" "$WORK/drive.sh" < /dev/null > "$WORK/console-sh" 2>&1
    else
        env HOME="$h" USERPROFILE="$h" AITOOLS_LOG_DIR="$WORK/logs-ps" AITOOLS_SUMMARY_FILE="$WORK/sum-ps" \
            REPO="$REPO" CASES="$CASES" F="$F" WORK="$WORK" OUT="$WORK/out-ps" CUR_PS="$CUR_PS" \
            pwsh -NoProfile -File "$WORK/drive.ps1" < /dev/null > "$WORK/console-ps" 2>&1
    fi
}

SHELLS="sh"
if $USE_PS; then SHELLS="sh ps"; else SKIP=$((SKIP + 1)); printf '  skip PowerShell side (--bash-only or no pwsh)\n'; fi
for s in $SHELLS; do
    rc=0
    run_shell "$s" || rc=$?
    if [ "$rc" -ne 0 ] || [ ! -s "$WORK/out-$s" ]; then
        bad "$s driver ran (exit $rc)"
        perl -pe 's/\e\[[0-9;]*m//g; s/^/      | /' "$WORK/console-$s" | tail -n 25
    fi
done

# result_of SHELL ID: the result line of ID in that shell's output
result_of() {
    perl -e 'my ($id, $f) = @ARGV; open my $fh, "<", $f or exit 1;
             while (<$fh>) { s/\n\z//; my ($i, $r) = split /\t/, $_, 2; if ($i eq $id) { print $r; exit 0 } } exit 1' "$2" "$WORK/out-$1"
}

while IFS="$TAB" read -r id want call rest <&3; do
    case_shells="$SHELLS"
    case "$call" in
        sh_*) case_shells="sh" ;;   # bash-only cases: no PowerShell run, no parity
        ps_*) if $USE_PS; then case_shells="ps"; else continue; fi ;;   # PowerShell-only cases
    esac
    for s in $case_shells; do
        got=$(result_of "$s" "$id") || got="(no result)"
        if [ "$got" = "$want" ]; then
            ok "$s $id"
        else
            bad "$s $id"
            printf '      want: %s\n      got:  %s\n' "$want" "$got"
        fi
    done
    if $USE_PS && [ "$case_shells" = "sh ps" ]; then
        a=$(result_of sh "$id") || a="(none sh)"
        b=$(result_of ps "$id") || b="(none ps)"
        if [ "$a" = "$b" ]; then ok "parity $id"; else bad "parity $id (sh: $a | ps: $b)"; fi
    fi
done 3< "$CASES"

# The unknown outcome is logged with its name (both shells)
for s in $SHELLS; do
    if grep -rqF 'unknown outcome "bogus" for b.md (t) -- counted as failed' "$WORK/logs-$s"; then
        ok "$s unknown outcome logged"
    else
        bad "$s unknown outcome logged"
    fi
done

# Every deploy.log line keeps the [timestamp] [script] [level] format (a
# multi-line reason is one log line per entry)
for s in $SHELLS; do
    badlines=$(perl -ne 'print unless /\A\[\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\] \[test-fanout-lib\] \[(?:info|ok|warn|error|detail)\] /' "$WORK/logs-$s/deploy.log")
    if [ -z "$badlines" ]; then
        ok "$s deploy.log: every line has the log line format"
    else
        bad "$s deploy.log: lines without the log line format"
        printf '%s\n' "$badlines" | head -n 5 | perl -pe 's/^/      | /'
    fi
done

# logged SHELL TEXT DESC: a detail line containing TEXT in that shell's log
logged() {
    if grep -F -- "[detail] $2" "$WORK/logs-$1/deploy.log" > /dev/null; then
        ok "$1 detail log: $3"
    else
        bad "$1 detail log: $3 (no line with: $2)"
    fi
}
logged sh "fanout_text_equal: cannot read $F/t/nope: " "fanout_text_equal names the missing file and why"
logged sh "fanout_text_equal: cannot read $F/t/dir: is a directory" "fanout_text_equal: a directory"
logged sh "fanout_text_equal: perl failed (exit 9): stub perl: boom" "fanout_text_equal: perl failure"
logged sh "backup_dir: $F/bd/sh/nomd/d: not backed up (no top-level *.md file)" "backup_dir skip rule"
logged sh "backup_dir: $F/bd/sh/missing/nope: not backed up (no directory)" "backup_dir: no directory"
if $USE_PS; then
    logged ps "Test-FanoutTextEqual: cannot read $F/t/nope: " "Test-FanoutTextEqual names the missing file and why"
    logged ps "Test-FanoutTextEqual: cannot read $F/t/dir: is a directory" "Test-FanoutTextEqual: a directory"
    logged ps "Backup-Dir: $F/bd/ps/nomd/d: not backed up (no top-level *.md file)" "Backup-Dir skip rule"
    logged ps "Backup-Dir: $F/bd/ps/missing/nope: not backed up (no directory)" "Backup-Dir: no directory"
fi
if $SYMLINKS; then
    for s in $SHELLS; do
        if grep -F "[error] Failed: dangling.md: " "$WORK/logs-$s/deploy.log" | grep -qF "is a dangling symlink -- not written through it"; then
            ok "$s deploy_managed_file: dangling symlink logged as an error"
        else
            bad "$s deploy_managed_file: dangling symlink logged as an error"
        fi
    done
fi
if $UNREAD; then
    logged sh "fanout_dir_matches: cannot read $D/unread2/T/a.txt: " "fanout_dir_matches: first unreadable entry"
    logged sh "fanout_dir_matches: cannot read $D/unread2/T/b.txt: " "fanout_dir_matches: second unreadable entry (own line)"
    logged sh "fanout_dir_matches: cannot read $D/noexec/T/sub/" "fanout_dir_matches: lstat failure"
    for s in $SHELLS; do
        if grep -F "[info] Removed the incomplete backup copy $F/bd/$s/partial/part.bak." "$WORK/logs-$s/deploy.log" > /dev/null; then
            ok "$s backup_dir: the half-made copy is removed and logged"
        else
            bad "$s backup_dir: the half-made copy is removed and logged"
        fi
    done
    if $USE_PS; then
        logged ps "Test-FanoutDirMatches: cannot read $D/unread2/T/a.txt: " "Test-FanoutDirMatches: first unreadable entry"
        logged ps "Test-FanoutDirMatches: cannot read $D/unread2/T/b.txt: " "Test-FanoutDirMatches: second unreadable entry (own line)"
        logged ps "Test-FanoutDirMatches: cannot list $D/noexec/T/sub: " "Test-FanoutDirMatches: directory without search permission"
    fi
fi

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
