#!/usr/bin/env perl
# check-ci-suites.pl -- every tracked test suite is run by the CI workflow on
# exactly the platforms it targets (plan FO-0, CLAUDE.md "tests/"; commander
# 2026-11-14: "sh scripts and tests should only run on linux/mac and ps1 on
# windows"). Safe to re-run: reads only.
#
# Usage:
#   git ls-files 'tests/*/test-*.sh' 'tests/*/test-*.ps1' | perl scripts/check-ci-suites.pl [--root DIR] [WORKFLOW]
#   perl scripts/check-ci-suites.pl --help
#
# Reads suite paths (repo-relative, one per line) on stdin and the workflow
# file WORKFLOW (default .github/workflows/check.yml). A suite counts as run in
# a job (macos, linux, windows: the job keys under "jobs:") when a single-line
# "run:" step of that job, before any "#", runs it:
#   test-*.sh   "bash <path>"
#   test-*.ps1  "pwsh ... <path>" (-File optional, any letter case; the path
#               with / or \ separators, optionally quoted)
# Where each suite must run (the suite file is read under --root, default .):
#   test-*.ps1            the windows job, and no other job
#   test-*.sh with the    the macos and linux jobs, and not the windows job
#   POSIX guard           (it refuses Windows; its .ps1 twin runs there)
#   test-*.sh without     every job: a cross-platform suite (listed in the "OS
#   a guard               guard exemptions" table of .claude/rules/cross-platform.md,
#                         which tests/os-guards enforces)
# %only below narrows a suite to fewer jobs, with the reason; %exempt lists a
# suite that cannot run in CI at all. A stale entry fails: an %exempt suite
# that is run anyway, or an entry not on stdin whose file still exists under
# --root or that the workflow still names.
# Blind spots (a cheap static check): a suite started inside a "run: |" block
# is reported missing; if: conditions are ignored (an if: false step still
# counts).
#
# Output: one "::error::" line per problem (GitHub annotation), "exempt:" and
# "only:" lines, then "All N test suites are in CI on their platforms" on
# success.
# Exit: 0 every suite runs where it should, or is exempt; 1 a suite missing from
# a job, run in a job it must not run in, a stale entry, an unsupported suite
# type, an unreadable .sh suite, or no suites on stdin; 2 usage or read error.
# Platform: any perl 5 (CI linux job; macOS, Linux, Windows locally).
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
my $root = ".";
if (@ARGV >= 2 && $ARGV[0] eq "--root") {
    $root = $ARGV[1];
    splice(@ARGV, 0, 2);
}
if (@ARGV > 1) {
    print STDERR "check-ci-suites: usage: ... | perl scripts/check-ci-suites.pl [--root DIR] [WORKFLOW] (--help)\n";
    exit 2;
}

my @JOBS = qw(macos linux windows);

my %exempt = (
    # "tests/<dir>/test-<name>.sh" => "reason it cannot run in CI",
);
# A suite that runs in fewer jobs than its kind requires: the jobs and why.
my %only = (
    "tests/ci-suites/test-check-ci-suites.sh" => [ [qw(linux)], "a static check of the workflow and a perl script; one copy is enough" ],
);

my $workflow = @ARGV ? $ARGV[0] : ".github/workflows/check.yml";
open(my $fh, "<", $workflow) or do { print "::error::cannot read $workflow: $!\n"; exit 2 };
my (%runs, $job, $in_jobs);
my $yml_text = "";
while (my $l = <$fh>) {
    $yml_text .= $l;
    $l =~ s/\r?\n\z//;
    if ($l =~ /^jobs:\s*$/) { $in_jobs = 1; next }
    if ($l =~ /^\S/) { $in_jobs = 0; $job = undef; next }
    next unless $in_jobs;
    if ($l =~ /^  ([A-Za-z0-9_-]+):\s*$/) { $job = $1; next }
    next unless defined $job;
    push @{ $runs{$job} }, $1 if $l =~ /^\s*run:\s([^#\n]*)/;
}
close($fh);

# path_re: the path with each / matching / or \ (Windows form in a pwsh step)
sub path_re {
    my ($p) = @_;
    return join('[\\\\/]', map { quotemeta } split(m{/}, $p, -1));
}

# jobs_running($path): the jobs with a single-line run: step that runs it
sub jobs_running {
    my ($p) = @_;
    my @hit;
    for my $j (sort keys %runs) {
        my $found = 0;
        for my $r (@{ $runs{$j} }) {
            if ($p =~ /\.sh\z/) {
                $found = 1 if $r =~ /\bbash\s+\Q$p\E(?:\s|$)/;
            } else {
                my $re = path_re($p);
                $found = 1 if $r =~ /\bpwsh\b.*?\s(?i:-File\s+)?["']?$re["']?(?:\s|$)/;
            }
            last if $found;
        }
        push @hit, $j if $found;
    }
    return @hit;
}

# posix_guarded($path): 1 guarded, 0 not, undef unreadable
sub posix_guarded {
    my ($p) = @_;
    open(my $sf, "<", "$root/$p") or return undef;
    local $/; my $t = <$sf>; close($sf);
    return ($t =~ /MINGW\*\|MSYS\*\|CYGWIN\*\)[^;]{0,300}?This script is for macOS\/Linux[^;]{0,200}?exit 1/s) ? 1 : 0;
}

my ($n, $bad) = (0, 0);
my %seen;
while (my $p = <STDIN>) {
    $p =~ s/\r?\n\z//;
    next if $p eq "";
    $n++;
    $seen{$p} = 1;
    if ($p !~ /\.(?:sh|ps1)\z/) {
        print "::error::$p is not a test-*.sh or test-*.ps1 suite\n";
        $bad++;
        next;
    }
    my @in = jobs_running($p);
    my %in = map { $_ => 1 } @in;
    if (exists $exempt{$p}) {
        if (@in) { print "::error::$p is run in CI and also exempt: remove the exemption\n"; $bad++; }
        else { print "exempt: $p ($exempt{$p})\n"; }
        next;
    }
    if (!@in) {
        print "::error::$p is not run by any step in $workflow\n";
        $bad++;
        next;
    }
    my (@want, $kind);
    if ($p =~ /\.ps1\z/) {
        @want = qw(windows);
        $kind = "a .ps1 suite (Windows)";
    } else {
        my $g = posix_guarded($p);
        if (!defined $g) {
            print "::error::cannot read $root/$p to check its OS guard\n";
            $bad++;
            next;
        }
        if ($g) { @want = qw(macos linux); $kind = "a POSIX-guarded .sh suite (macOS/Linux; its .ps1 twin runs on Windows)"; }
        else { @want = @JOBS; $kind = "a cross-platform .sh suite (no OS guard)"; }
    }
    if (exists $only{$p}) {
        my ($jobs, $why) = @{ $only{$p} };
        my %allowed = map { $_ => 1 } @want;
        for my $j (@$jobs) {
            next if $allowed{$j};
            print "::error::$p: %only names the $j job, where $kind must not run\n";
            $bad++;
        }
        @want = @$jobs;
        print "only: $p in " . join(", ", @want) . " ($why)\n";
    }
    my %want = map { $_ => 1 } @want;
    for my $j (@want) {
        next if $in{$j};
        print "::error::$p is $kind but no step of the $j job runs it\n";
        $bad++;
    }
    for my $j (@in) {
        next if $want{$j};
        print "::error::$p is $kind but the $j job runs it\n";
        $bad++;
    }
}
# A stale %exempt / %only entry: not on stdin, while its file still exists
# under --root or the workflow still names it. (An entry whose suite is gone
# from the tree and the workflow has no effect; a check run on a synthetic
# tree, as the tests do, never sees the real entries as stale.)
for my $p (sort(keys %exempt), sort(keys %only)) {
    next if $seen{$p};
    next unless -e "$root/$p" || index($yml_text, $p) >= 0;
    print "::error::$p is listed in check-ci-suites.pl but not on stdin (not tracked?): remove the entry\n";
    $bad++;
}
if ($n == 0) {
    print "::error::no test suites on stdin (git ls-files 'tests/*/test-*.sh' 'tests/*/test-*.ps1')\n";
    exit 1;
}
exit 1 if $bad;
print "All $n test suites are in CI on their platforms\n";
exit 0;
