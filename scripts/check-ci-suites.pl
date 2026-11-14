#!/usr/bin/env perl
# check-ci-suites.pl -- every tracked test suite is run by a step of the CI
# workflow (plan FO-0, CLAUDE.md "tests/"). Safe to re-run: reads only.
#
# Usage:
#   git ls-files 'tests/*/test-*.sh' 'tests/*/test-*.ps1' | perl scripts/check-ci-suites.pl [WORKFLOW]
#   perl scripts/check-ci-suites.pl --help
#
# Reads suite paths (repo-relative, one per line) on stdin and the workflow
# file WORKFLOW (default .github/workflows/check.yml). A suite counts as run
# when a single-line "run:" step, before any "#", runs it:
#   test-*.sh   "bash <path>"
#   test-*.ps1  "pwsh ... <path>" (-File optional, any letter case; the path
#               with / or \ separators, optionally quoted)
# A suite that cannot run in CI goes in %exempt below with the reason; an
# exempt suite that is also run, or no longer exists, fails too (stale
# exemption).
# Blind spots (a cheap static check): a suite started inside a "run: |"
# block is reported missing; a suite run in any job counts (not one per
# platform); if: conditions are ignored (an if: false step still counts).
#
# Output: one "::error::" line per problem (GitHub annotation), "exempt:"
# lines, then "All N test suites are in CI or exempt" on success.
# Exit: 0 every suite run or exempt; 1 a suite not run, a stale exemption, an
# unsupported suite type, or no suites on stdin; 2 usage or read error.
# Platform: any perl 5 (CI linux job; macOS, Linux, Git Bash locally).
# Called by: .github/workflows/check.yml "Every test suite is in CI".
# Tests: tests/ci-suites/test-check-ci-suites.sh.
use strict;
use warnings;

if (@ARGV && ($ARGV[0] eq "--help" || $ARGV[0] eq "-h")) {
    open(my $self, "<", $0) or do { print STDERR "check-ci-suites: cannot read $0: $!\n"; exit 2 };
    while (my $l = <$self>) {
        last if $. > 1 && $l !~ /^#/;
        next if $. == 1;
        $l =~ s/^# ?//;
        print $l;
    }
    close($self);
    exit 0;
}
if (@ARGV > 1) {
    print STDERR "check-ci-suites: usage: ... | perl scripts/check-ci-suites.pl [WORKFLOW] (--help)\n";
    exit 2;
}

my %exempt = (
    # "tests/<dir>/test-<name>.sh" => "reason it cannot run in CI",
);

my $workflow = @ARGV ? $ARGV[0] : ".github/workflows/check.yml";
open(my $fh, "<", $workflow) or do { print "::error::cannot read $workflow: $!\n"; exit 2 };
my $yml = do { local $/; <$fh> };
close($fh);

# path_re: the path with each / matching / or \ (Windows form in a pwsh step)
sub path_re {
    my ($p) = @_;
    return join('[\\\\/]', map { quotemeta } split(m{/}, $p, -1));
}

my ($n, $bad) = (0, 0);
my %seen;
while (my $p = <STDIN>) {
    $p =~ s/\r?\n\z//;
    next if $p eq "";
    $n++;
    $seen{$p} = 1;
    my $run;
    if ($p =~ /\.sh\z/) {
        $run = $yml =~ /^\s*run:\s[^#\n]*\bbash\s+\Q$p\E(?:\s|$)/m;
    } elsif ($p =~ /\.ps1\z/) {
        my $re = path_re($p);
        $run = $yml =~ /^\s*run:\s[^#\n]*\bpwsh\b[^#\n]*?\s(?i:-File\s+)?["']?$re["']?(?:\s|$)/m;
    } else {
        print "::error::$p is not a test-*.sh or test-*.ps1 suite\n";
        $bad++;
        next;
    }
    if (exists $exempt{$p}) {
        if ($run) { print "::error::$p is run in CI and also exempt: remove the exemption\n"; $bad++; }
        else { print "exempt: $p ($exempt{$p})\n"; }
    } elsif (!$run) {
        print "::error::$p is not run by any step in $workflow\n";
        $bad++;
    }
}
for my $p (sort keys %exempt) {
    next if $seen{$p};
    print "::error::exempt suite $p is not tracked: remove the exemption\n";
    $bad++;
}
if ($n == 0) {
    print "::error::no test suites on stdin (git ls-files 'tests/*/test-*.sh' 'tests/*/test-*.ps1')\n";
    exit 1;
}
exit 1 if $bad;
print "All $n test suites are in CI or exempt\n";
exit 0;
