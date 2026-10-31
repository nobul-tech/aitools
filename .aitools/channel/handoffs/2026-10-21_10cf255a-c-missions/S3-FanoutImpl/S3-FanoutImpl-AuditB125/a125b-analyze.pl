#!/usr/bin/env perl
# a125b-analyze.pl -- per case: exit codes, summary rows (sh vs ps), deploy.log
# format check (every line [YYYY-MM-DDTHH:MM:SSZ] [setup-user-skills] [level] msg,
# level in info|ok|warn|error|detail), error-line count vs ERROR rows, and a
# timestamp-stripped, path-normalized diff of the deploy.log lines (sh vs ps).
# Usage: perl a125b-analyze.pl OUTDIR [case...]
use strict; use warnings;
my $out = shift or die "usage: a125b-analyze.pl OUTDIR [case...]\n";
my @cases = @ARGV;
unless (@cases) {
    opendir my $d, $out or die "$out: $!";
    @cases = sort grep { -d "$out/$_/sh" } readdir $d;
}
sub slurp { my $f = shift; open my $fh, '<', $f or return (); my @l = <$fh>; chomp @l; s/\r\z// for @l; return @l }
sub norm {
    my ($l, $case, $lang) = @_;
    $l =~ s/^\[\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\] //;
    $l =~ s/\Q$out\E\/\Q$case\E\/\Q$lang\E/~/g;
    $l =~ s/\Q$out\E/<OUT>/g;
    return $l;
}
for my $c (@cases) {
    print "=" x 70, "\n== $c\n";
    my %rc = map { $_ => (slurp("$out/$c/$_.rc"))[0] } qw(sh ps);
    print "rc: sh=$rc{sh} ps=$rc{ps}", ($rc{sh} eq $rc{ps} ? "" : "  <-- RC DIFF"), "\n";
    my %rows = map { $_ => [ slurp("$out/$c/$_.summary") ] } qw(sh ps);
    for my $lang (qw(sh ps)) { print "rows $lang: $_\n" for @{ $rows{$lang} } }
    my $rs = join("\n", sort @{ $rows{sh} }); my $rp = join("\n", sort @{ $rows{ps} });
    print $rs eq $rp ? "rows: SAME\n" : "rows: DIFF  <--\n";
    for my $lang (qw(sh ps)) {
        my @log = slurp("$out/$c/$lang.deploy.log");
        my ($bad, $err, $warn) = (0, 0, 0);
        for (@log) {
            if (/^\[\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\] \[([^\]]+)\] \[(info|ok|warn|error|detail)\] /) {
                my ($sn, $lv) = ($1, $2);
                print "  $lang SCRIPTNAME? $_\n" if $sn ne 'setup-user-skills' && $sn ne 'aitools-profile';
                next if $sn ne 'setup-user-skills';
                $err++ if $lv eq 'error' && !/FAILED with/; $warn++ if $lv eq 'warn' && !/COMPLETED with/;
            } else { $bad++; print "  $lang BADFMT: $_\n" }
        }
        my $errrows = grep { /^ERROR\|/ } @{ $rows{$lang} };
        print "$lang log: lines=", scalar(@log), " badfmt=$bad error-lines=$err warn-lines=$warn ERROR-rows=$errrows\n";
        my $exp = $err > 0 ? 1 : 0;
        print "  $lang EXIT MISMATCH (errors=$err rc=$rc{$lang})\n" if $exp != $rc{$lang};
    }
    my @ls = map { norm($_, $c, 'sh') } grep { !/\[detail\] platform=/ } slurp("$out/$c/sh.deploy.log");
    my @lp = map { norm($_, $c, 'ps') } grep { !/\[detail\] platform=/ } slurp("$out/$c/ps.deploy.log");
    my %ins = map { $_ => 1 } @lp; my %inp = map { $_ => 1 } @ls;
    my @only_s = grep { !$ins{$_} } @ls; my @only_p = grep { !$inp{$_} } @lp;
    if (!@only_s && !@only_p) { print "log lines: SAME set\n" }
    else { print "  sh-only: $_\n" for @only_s; print "  ps-only: $_\n" for @only_p }
    for my $lang (qw(sh ps)) {
        my @o = slurp("$out/$c/$lang.out");
        my @odd = grep { !/^\[\d{4}-\d\d-\d\dT/ && /\S/ } @o;
        print "  $lang console non-log line: $_\n" for @odd;
    }
    my %files = map { $_ => join(",", slurp("$out/$c/$_.files")) } qw(sh ps);
    print "files sh: $files{sh}\n";
    print $files{sh} eq $files{ps} ? "files: SAME\n" : "files ps: $files{ps}  <-- DIFF\n";
}
