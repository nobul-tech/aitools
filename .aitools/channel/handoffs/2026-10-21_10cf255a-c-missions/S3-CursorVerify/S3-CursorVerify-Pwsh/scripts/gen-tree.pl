#!/usr/bin/env perl
# gen-tree.pl HOME OUTDIR -- S3-CursorVerify-Pwsh tree generator (contract v1.0 "Output").
# Writes:
#   OUTDIR/tree.txt      contract spec: one line per entry under HOME/.cursor/rules,
#                        HOME/.cursor/skills, HOME/.aitools/rules, HOME/.aitools/skills:
#                        <path relative to HOME>\t<f|d|l>\t<octal mode>\t<sha256 or ->
#                        sorted bytewise; every .bak.<UTC stamp> replaced by .bak.TS
#   OUTDIR/tree-ext.txt  the same for the sibling backup dirs <root>.bak.<UTC>/** (not in the spec)
#   OUTDIR/snap.txt      every entry under HOME/.cursor and HOME/.aitools except .aitools/logs,
#                        real names, with size and mtime (ns) -- for the P2 "nothing changed" diff
# Platform-neutral (core perl only). Paths are relative to HOME, '/' separators.
use strict;
use warnings;
use File::Find ();
use Digest::SHA ();
use Time::HiRes ();

my ($home, $out) = @ARGV;
die "usage: gen-tree.pl HOME OUTDIR\n" unless defined $out && -d $home && -d $out;
$home =~ s{/+$}{};
die "refusing the real HOME\n" if $home eq '/Users/new-jose';

my @roots = ('.cursor/rules', '.cursor/skills', '.aitools/rules', '.aitools/skills');
my (@tree, @ext, @snap);

sub norm { my $p = shift; $p =~ s/\.bak\.\d{4}-\d\d-\d\dT\d{6}Z(?:-\d+)?/.bak.TS/g; return $p; }

sub entry_line {
    my ($abs, $rel) = @_;
    my @st = lstat($abs) or die "lstat $abs: $!\n";
    my $mode = sprintf('%04o', $st[2] & 07777);
    my ($type, $sum) = ('f', '-');
    if (-l _) { $type = 'l'; }
    elsif (-d _) { $type = 'd'; }
    else {
        open(my $fh, '<:raw', $abs) or die "open $abs: $!\n";
        $sum = Digest::SHA->new(256)->addfile($fh)->hexdigest;
        close $fh;
    }
    return ($type, $mode, $sum, \@st);
}

sub walk {
    my ($start, $cb) = @_;
    return unless -e $start || -l $start;
    File::Find::find({ no_chdir => 1, wanted => sub {
        my $abs = $File::Find::name;
        return if $abs eq $start;
        $cb->($abs);
    } }, $start);
}

for my $r (@roots) {
    walk("$home/$r", sub {
        my $abs = shift;
        (my $rel = $abs) =~ s{^\Q$home\E/}{};
        my ($t, $m, $s) = entry_line($abs, $rel);
        push @tree, join("\t", norm($rel), $t, $m, $s);
    });
    # sibling backup directories <root>.bak.<UTC>[-n]
    my ($parent, $base) = ($r =~ m{^(.*)/([^/]+)$});
    if (opendir(my $dh, "$home/$parent")) {
        for my $n (sort readdir $dh) {
            next unless $n =~ /^\Q$base\E\.bak\./;
            my $top = "$home/$parent/$n";
            push @ext, join("\t", norm("$parent/$n"), (entry_line($top, "$parent/$n"))[0..2]);
            walk($top, sub {
                my $abs = shift;
                (my $rel = $abs) =~ s{^\Q$home\E/}{};
                push @ext, join("\t", norm($rel), (entry_line($abs, $rel))[0..2]);
            });
        }
        closedir $dh;
    }
}

for my $top ('.cursor', '.aitools') {
    walk("$home/$top", sub {
        my $abs = shift;
        (my $rel = $abs) =~ s{^\Q$home\E/}{};
        return if $rel =~ m{^\.aitools/logs(?:/|$)};
        my ($t, $m, $s) = entry_line($abs, $rel);
        my @st = Time::HiRes::lstat($abs);
        my $size = $t eq 'f' ? $st[7] : '-';
        my $mt = $t eq 'd' ? '-' : sprintf('%.6f', $st[9]);   # dir mtimes move with any child
        push @snap, join("\t", $rel, $t, $m, $s, $size, $mt);
    });
}

sub dump_sorted {
    my ($file, @lines) = @_;
    open(my $fh, '>:raw', $file) or die "write $file: $!\n";
    print $fh "$_\n" for sort { $a cmp $b } @lines;
    close $fh;
}
dump_sorted("$out/tree.txt", @tree);
dump_sorted("$out/tree-ext.txt", @ext);
dump_sorted("$out/snap.txt", @snap);
printf "tree.txt %d lines, tree-ext.txt %d lines, snap.txt %d lines\n", scalar(@tree), scalar(@ext), scalar(@snap);
