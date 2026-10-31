#!/usr/bin/env perl
# a121b-analyze.pl RUNSDIR [case...] -- evaluate the runner's captures per case
# and language: deploy.log line format (UTC Z, script name, level), error/warn
# counts vs the exit footer line and the exit code, ERROR/WARN/ACTION rows
# present when errors/warnings were logged, non-DETAIL row detail > 30 chars,
# console lines outside the log format (unstructured output), and the sh/ps
# parity of the claude rules + ACTION rows and of the log levels/messages.
use strict; use warnings;
my $dir = shift or die "usage: a121b-analyze.pl RUNSDIR [case...]\n";
my @cases = @ARGV;
unless (@cases) { opendir my $d, $dir or die $!; @cases = sort grep { -f "$dir/$_/sh.rc" } readdir $d; }
my $fmt = qr/\A\[\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\] \[setup-user-claude\] \[(info|ok|warn|error|detail)\] (.*)\z/;
sub slurp { my $f = shift; open my $h, "<", $f or return (); my @l = <$h>; chomp @l; s/\r\z// for @l; return @l; }
sub norm {  # path/timestamp normalisation for sh/ps message comparison
    my ($m, $c) = @_;
    $m =~ s{\Q$dir/$c\E/(sh|ps)}{<H>}g; $m =~ s{\Q$dir\E}{<OUT>}g;
    $m =~ s/\.bak\.[0-9TZ-]+/.bak.TS/g; return $m;
}
for my $c (@cases) {
    my %r;
    print "=== $c\n";
    for my $l (qw(sh ps)) {
        my $rc = (slurp("$dir/$c/$l.rc"))[0];
        my @log = slurp("$dir/$c/$l.deploy.log");
        my @rows = slurp("$dir/$c/$l.summary");
        my @out = slurp("$dir/$c/$l.out");
        my ($e, $w, @bad, @msgs) = (0, 0);
        my $footer = "";
        for my $x (@log) {
            if ($x =~ $fmt) {
                my ($lv, $m) = ($1, $2);
                if ($m =~ /\AFAILED with|\ACOMPLETED/) { $footer = "$lv $m"; next; }
                $e++ if $lv eq 'error'; $w++ if $lv eq 'warn';
                push @msgs, "$lv " . norm($m, $c) if $lv ne 'detail';
            } else { push @bad, $x; }
        }
        my @nd = grep { !/\ADETAIL\|/ } @rows;
        my @long = grep { my @f = split /\|/, $_, 3; $f[0] ne 'ACTION' && length($f[2] // '') > 30 } @nd;
        my $hasErrRow = grep { /\AERROR\|/ } @rows;
        my $hasWarnRow = grep { /\A(WARN|ACTION)\|/ } @rows;
        # console lines that are neither log-format lines nor blank (stderr leaks)
        my @raw = grep { my $y = $_; $y =~ s/\e\[[0-9;]*m//g; $y ne '' && $y !~ $fmt } @out;
        printf "  %s rc=%s errors=%d warns=%d footer=[%s]\n", $l, $rc, $e, $w, $footer;
        print "    ROWS: $_\n" for @rows;
        print "    !! bad log line: $_\n" for @bad;
        print "    !! detail > 30 chars: $_\n" for @long;
        print "    !! unstructured console: $_\n" for @raw;
        print "    !! errors logged but rc=$rc\n" if $e && $rc ne '1';
        print "    !! rc=1 but no error logged\n" if !$e && $rc eq '1';
        print "    !! errors logged but no ERROR row\n" if $e && !$hasErrRow;
        print "    !! warnings logged but no WARN/ACTION row\n" if $w && !$hasWarnRow && !$e;
        my $fe = $footer =~ /FAILED with (\d+)/ ? $1 : 0;
        print "    !! footer count $fe != errors $e\n" if $fe != $e;
        print "    !! footer missing\n" if $footer eq '';
        $r{$l} = { rows => [sort grep { /\A(ACTION\||[A-Z]+\|claude rules\|)/ } @rows], msgs => [@msgs], rc => $rc };
    }
    my ($a, $b) = (join("\n", @{$r{sh}{rows}}), join("\n", @{$r{ps}{rows}}));
    print "  PARITY rows: ", ($a eq $b ? "same" : "DIFFER"), "\n";
    if ($a ne $b) { print "    sh: $_\n" for @{$r{sh}{rows}}; print "    ps: $_\n" for @{$r{ps}{rows}}; }
    print "  PARITY rc: ", ($r{sh}{rc} eq $r{ps}{rc} ? "same" : "DIFFER"), "\n";
    my %lv; for my $l (qw(sh ps)) { for (@{$r{$l}{msgs}}) { my ($v) = /\A(\w+)/; $lv{$l}{$v}++; } }
    my $ls = join ",", map { "$_=" . ($lv{sh}{$_} // 0) } qw(error warn);
    my $lp = join ",", map { "$_=" . ($lv{ps}{$_} // 0) } qw(error warn);
    print "  PARITY levels: sh[$ls] ps[$lp]", ($ls eq $lp ? "" : "  DIFFER"), "\n";
    # error/warn messages present in one language only (normalised)
    my %in; for my $l (qw(sh ps)) { for (grep { /\A(error|warn) / } @{$r{$l}{msgs}}) { $in{$_}{$l} = 1; } }
    for my $m (sort keys %in) { next if $in{$m}{sh} && $in{$m}{ps}; print "    only-", ($in{$m}{sh} ? "sh" : "ps"), ": $m\n"; }
}
