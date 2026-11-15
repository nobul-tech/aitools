#!/usr/bin/env perl
# classify-guards.pl -- classify every product script and test suite by its OS
# guard, for tests/os-guards/test-os-guards.sh (macOS/Linux) and
# tests/os-guards/test-os-guards.ps1 (Windows). One classifier, two harnesses.
#
# Usage: perl tests/os-guards/classify-guards.pl ROOT RULES FILELIST
#   ROOT      the repo root
#   RULES     .claude/rules/cross-platform.md (its "### OS guard exemptions" table)
#   FILELIST  a file of repo-relative paths, one per line (git ls-files -- scripts
#             shared packaging tests)
# Output, one line per classified file, tab-separated:
#   win       <path>             .ps1 with the Windows guard (-not $IsWindows ...
#                                "This script is for Windows" ... exit 1)
#   posix     <path>             .sh (or shell script without extension) with the
#                                POSIX guard (MINGW*|MSYS*|CYGWIN*) ... "This script
#                                is for macOS/Linux" ... exit 1); a test suite also
#                                needs the ${BASH_VERSINFO[5]:-} case (below)
#   weak      <path>             a test suite whose POSIX guard lacks the
#                                ${BASH_VERSINFO[5]:-} case (*-msys*|*-cygwin*|*-mingw*)
#   exempt    <path> <token>     no guard; listed in the exemptions table (token)
#   unexempt  <path>             no guard and not listed
# Classified: every .ps1 and .sh, and every extensionless file with a bash/sh
# shebang, under scripts/, shared/ and packaging/; under tests/ only the suites
# tests/<dir>/test-*.sh and tests/<dir>/test-*.ps1 (helpers are not run alone).
# Exemption tokens: the backticked words in column 2 of the table; a token with
# a "/" matches the whole path (* and ? do not cross "/"), otherwise the file
# name; "x.sh/.ps1" stands for x.sh and x.ps1.
# Exit: 0 classified; 2 a file could not be read or no exemption tokens found.
# Platform: any perl 5 (macOS, Linux, Windows: Git for Windows or Strawberry).
use strict;
use warnings;

if (@ARGV && ($ARGV[0] eq "--help" || $ARGV[0] eq "-h")) {
    open(my $self, "<", $0) or do { print STDERR "classify-guards: cannot read $0: $!\n"; exit 2 };
    while (my $l = <$self>) {
        last if $. > 1 && $l !~ /^#/;
        next if $. == 1;
        $l =~ s/^# ?//;
        print $l;
    }
    close($self);
    exit 0;
}
if (@ARGV != 3) {
    print STDERR "classify-guards: usage: perl classify-guards.pl ROOT RULES FILELIST (--help)\n";
    exit 2;
}
my ($root, $rules, $list) = @ARGV;

sub fail { print STDERR "classify-guards: $_[0]\n"; exit 2 }

# Exemption tokens: column 2 of the "### OS guard exemptions" table.
open my $rf, "<", $rules or fail("cannot read $rules: $!");
my ($in, @tok) = (0);
while (my $l = <$rf>) {
    if ($l =~ /^### OS guard exemptions/) { $in = 1; next }
    last if $in && $l =~ /^### /;
    next unless $in && $l =~ /^\|/;
    my @col = split /\|/, $l;
    next unless defined $col[2];
    for my $t ($col[2] =~ /`([^`]+)`/g) {
        if ($t =~ m{^(.*)\.sh/\.ps1$}) { push @tok, "$1.sh", "$1.ps1" } else { push @tok, $t }
    }
}
close $rf;
fail("no exemption tokens found in $rules") unless @tok;
my $glob2re = sub { my $g = quotemeta shift; $g =~ s/\\\*/[^\/]*/g; $g =~ s/\\\?/./g; qr/^$g$/ };
my @pat = map { [ $_, $glob2re->($_), (index($_, "/") >= 0) ] } @tok;

open my $lf, "<", $list or fail("cannot read $list: $!");
while (my $f = <$lf>) {
    $f =~ s/\r?\n\z//;
    next if $f eq "";
    my $is_test = ($f =~ m{^tests/});
    if ($is_test) {
        next unless $f =~ m{^tests/.+/test-[^/]+\.(?:sh|ps1)$};
    } elsif ($f !~ /\.(ps1|sh)$/) {
        next if $f =~ m{\.[^/]+$};           # other extensions: not scripts we classify
        open my $sb, "<", "$root/$f" or fail("cannot read $f: $!");
        my $first = <$sb> // ""; close $sb;
        next unless $first =~ m{^#!.*\b(ba)?sh\b};
    }
    open my $fh, "<", "$root/$f" or fail("cannot read $f: $!");
    local $/; my $t = <$fh>; close $fh;
    $t =~ s/\r//g;
    my $kind = "none";
    if ($f =~ /\.ps1$/) {
        $kind = "win" if $t =~ /-not \$IsWindows\)\s*\{[^}]{0,300}?This script is for Windows[^}]{0,200}?exit 1/s;
    } else {
        if ($t =~ /MINGW\*\|MSYS\*\|CYGWIN\*\)[^;]{0,300}?This script is for macOS\/Linux[^;]{0,200}?exit 1/s) {
            $kind = "posix";
            if ($is_test && $t !~ /"\$\{BASH_VERSINFO\[5\]:-\}"\s+in\s+\*-msys\*\|\*-cygwin\*\|\*-mingw\*\)[^;]{0,300}?This script is for macOS\/Linux[^;]{0,200}?exit 1/s) {
                $kind = "weak";
            }
        }
    }
    if ($kind eq "none") {
        (my $base = $f) =~ s{.*/}{};
        my ($hit) = grep { $_->[2] ? $f =~ $_->[1] : $base =~ $_->[1] } @pat;
        print $hit ? "exempt\t$f\t$hit->[0]\n" : "unexempt\t$f\n";
    } else {
        print "$kind\t$f\n";
    }
}
close $lf;
exit 0;
