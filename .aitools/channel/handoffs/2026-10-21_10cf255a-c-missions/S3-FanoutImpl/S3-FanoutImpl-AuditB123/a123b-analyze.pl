#!/usr/bin/env perl
# a123b-analyze.pl OUTDIR [case...] -- checklist analysis of a123b-runner.sh output.
# Per case: log-line format (every deploy.log line), error count vs ERROR row vs
# exit code, OK/WARN/ERROR detail length (<= 30), sh/ps parity of summary rows
# (all categories, in order), of deploy.log messages (level + message, home
# path and backup stamps normalised, driver footer lines dropped) and of the
# resulting ~/.cursor tree. Writes <case>/parity.diff when anything differs.
use strict; use warnings;
my $out = shift or die "usage: a123b-analyze.pl OUTDIR [case...]\n";
my @cases = @ARGV;
unless (@cases) { opendir my $d, $out or die; @cases = sort grep { -d "$out/$_" && !/^\./ } readdir $d; }
sub slurp { my $f = shift; open my $fh, "<", $f or return (); my @l = <$fh>; chomp @l; return @l }
sub norm {
    my ($s, $h) = @_;
    $s =~ s/\Q$h\E/~/g; $s =~ s{\\}{/}g;
    $s =~ s/\.bak\.[0-9]{4}-?[0-9]{2}-?[0-9]{2}T[0-9:]+Z(?:-\d+)?/.bak.TS/g;
    return $s;
}
my $fmt = qr/\A\[\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\] \[[A-Za-z0-9._-]+\] \[(info|ok|warn|error|detail)\] /;
printf "%-14s %-4s %-4s %-6s %-6s %-5s %-5s %-5s %s\n", qw(case rc.s rc.p err.s err.p rows logs tree notes);
for my $c (@cases) {
    my $C = "$out/$c";
    next unless -f "$C/sh.rc";
    my (%rc, %err, %rows, %msgs, @notes);
    for my $l (qw(sh ps)) {
        ($rc{$l}) = slurp("$C/$l.rc");
        my $h = "$C/$l";
        my @log = slurp("$C/$l.deploy.log");
        my $n = 0; my $e = 0; my @m;
        for my $x (@log) {
            $n++;
            if ($x !~ $fmt) { push @notes, "$l: bad log line $n: $x"; next }
            my $lvl = $1;
            (my $msg = $x) =~ s/$fmt//;
            $e++ if $lvl eq "error";
            next if $msg =~ /\A(FAILED with|COMPLETED)/;   # driver footers differ by design
            next if $lvl eq "detail" && $msg =~ /\A(platform=|backup_dir:|Backup-Dir:)/;
            push @m, "[$lvl] " . norm($msg, $h);
        }
        $err{$l} = $e;
        $msgs{$l} = \@m;
        my @s = map { norm($_, $h) } slurp("$C/$l.summary");
        $rows{$l} = \@s;
        my $has_err_row = grep { /\AERROR\|/ } @s;
        for my $r (@s) {
            my ($cat, $tool, $det) = split /\|/, $r, 3;
            next unless defined $det;
            if ($cat =~ /\A(OK|WARN|ERROR)\z/ && length($det) > 30) { push @notes, "$l: detail > 30 chars: $r" }
        }
        if ($e > 0 && !$has_err_row) { push @notes, "$l: $e error line(s) but no ERROR row" }
        if ($e == 0 && $has_err_row) { push @notes, "$l: ERROR row but no error line" }
        if ($rc{$l} ne "2") {
            if ($e > 0 && $rc{$l} ne "1") { push @notes, "$l: errors but exit $rc{$l}" }
            if ($e == 0 && $rc{$l} ne "0") { push @notes, "$l: no errors but exit $rc{$l}" }
        }
    }
    my $rp = join("\n", @{$rows{sh}}) eq join("\n", @{$rows{ps}}) ? "yes" : "NO";
    my $lp = join("\n", @{$msgs{sh}}) eq join("\n", @{$msgs{ps}}) ? "yes" : "NO";
    my @ts = slurp("$C/sh.tree"); my @tp = slurp("$C/ps.tree");
    my $tp = join("\n", @ts) eq join("\n", @tp) ? "yes" : "NO";
    if ($rp eq "NO" || $lp eq "NO" || $tp eq "NO") {
        open my $o, ">", "$C/parity.diff" or die;
        for my $pair (["rows", $rows{sh}, $rows{ps}], ["logs", $msgs{sh}, $msgs{ps}], ["tree", \@ts, \@tp]) {
            my ($k, $a, $b) = @$pair;
            my %inb; $inb{$_}++ for @$b; my %ina; $ina{$_}++ for @$a;
            print $o "== $k: only sh\n", map({ "  $_\n" } grep { !$inb{$_} } @$a);
            print $o "== $k: only ps\n", map({ "  $_\n" } grep { !$ina{$_} } @$b);
            if (join("\n", sort @$a) eq join("\n", sort @$b) && join("\n", @$a) ne join("\n", @$b)) { print $o "== $k: same lines, different order\n" }
        }
        close $o;
    } else { unlink "$C/parity.diff" }
    printf "%-14s %-4s %-4s %-6s %-6s %-5s %-5s %-5s %s\n", $c, $rc{sh}, $rc{ps}, $err{sh}, $err{ps}, $rp, $lp, $tp, scalar(@notes);
    print "    $_\n" for @notes;
}
