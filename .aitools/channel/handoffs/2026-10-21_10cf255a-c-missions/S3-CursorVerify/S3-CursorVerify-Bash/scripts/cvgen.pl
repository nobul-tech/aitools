#!/usr/bin/env perl
# cvgen.pl -- S3-CursorVerify output generator (contract v1.0 "Output"), platform-neutral.
#
#   cvgen.pl tree HOME OUT
#       One line per entry under HOME/.cursor/rules, HOME/.cursor/skills,
#       HOME/.aitools/rules, HOME/.aitools/skills (recursive; the four roots themselves
#       are not listed):
#         <path relative to HOME, forward slashes><TAB><f|d|l><TAB><octal mode, 4 digits><TAB><sha256 or ->
#       sorted bytewise; every ".bak.<UTC stamp>" (YYYY-MM-DDTHHMMSSZ, optional -N) -> ".bak.TS".
#       Files: sha256 of the bytes. Dirs and symlinks: "-". A root that does not exist
#       contributes nothing.
#   cvgen.pl bakdirs HOME OUT
#       Sibling directory backups (not in tree.txt): entries named <root>.bak.* beside the
#       four roots, listed recursively in the tree format.
#   cvgen.pl rows OUT SUMMARY...
#       The summary rows whose tool (field 2) is "harness files", "cursor rules",
#       "cursor skills", or whose category is ACTION, in emitted order, DETAIL rows
#       included; SUMMARY files concatenated in argument order.
#   cvgen.pl snap HOME OUT
#       Everything under HOME/.cursor and HOME/.aitools except HOME/.aitools/logs:
#         <rel><TAB><type><TAB><mode><TAB><sha256 or -><TAB><mtime with nanoseconds>
#       (raw names, no .bak.TS substitution) -- for "nothing written" checks.
use strict;
use warnings;
use File::Find;
use Digest::SHA;
use Time::HiRes ();

my $cmd = shift @ARGV // die "usage: cvgen.pl tree|bakdirs|rows|snap ...\n";

sub sha_of {
    my $p = shift;
    my $d = Digest::SHA->new(256);
    open my $fh, "<:raw", $p or die "cannot read $p: $!\n";
    $d->addfile($fh);
    close $fh;
    return $d->hexdigest;
}

sub norm_ts {
    my $s = shift;
    $s =~ s/\.bak\.\d{4}-\d\d-\d\dT\d{6}Z(?:-\d+)?/.bak.TS/g;
    return $s;
}

sub entry {   # (rel, abs) -> "rel\ttype\tmode\tsha"
    my ($rel, $abs) = @_;
    my @st = lstat $abs or die "cannot lstat $abs: $!\n";
    my $mode = sprintf "%04o", $st[2] & 07777;
    if (-l _) { return ($rel, "l", $mode, "-") }
    if (-d _) { return ($rel, "d", $mode, "-") }
    return ($rel, "f", $mode, sha_of($abs));
}

sub walk {    # walk(HOME, root-rel) -> list of [rel, abs]
    my ($home, $root) = @_;
    my $top = "$home/$root";
    return () unless -d $top && !-l $top;
    my @out;
    find({ no_chdir => 1, wanted => sub {
        return if $File::Find::name eq $top;
        my $rel = substr($File::Find::name, length($home) + 1);
        push @out, [$rel, $File::Find::name];
    } }, $top);
    return @out;
}

sub write_lines {
    my ($out, @lines) = @_;
    open my $o, ">:raw", $out or die "cannot write $out: $!\n";
    print $o "$_\n" for @lines;
    close $o or die "cannot write $out: $!\n";
}

my @roots = (".cursor/rules", ".cursor/skills", ".aitools/rules", ".aitools/skills");

if ($cmd eq "tree") {
    my ($home, $out) = @ARGV;
    my @lines;
    for my $r (@roots) {
        for my $e (walk($home, $r)) {
            my @f = entry(@$e);
            $f[0] = norm_ts($f[0]);
            push @lines, join("\t", @f);
        }
    }
    { use bytes; @lines = sort @lines; }
    write_lines($out, @lines);
} elsif ($cmd eq "bakdirs") {
    my ($home, $out) = @ARGV;
    my @lines;
    for my $r (@roots) {
        my ($parent, $base) = $r =~ m{\A(.*)/([^/]+)\z};
        opendir my $dh, "$home/$parent" or next;
        for my $n (grep { /\A\Q$base\E\.bak\./ } readdir $dh) {
            my $rr = "$parent/$n";
            my @f = entry($rr, "$home/$rr");
            $f[0] = norm_ts($f[0]);
            push @lines, join("\t", @f);
            if (-d "$home/$rr" && !-l "$home/$rr") {
                for my $e (walk($home, $rr)) {
                    my @g = entry(@$e);
                    $g[0] = norm_ts($g[0]);
                    push @lines, join("\t", @g);
                }
            }
        }
        closedir $dh;
    }
    { use bytes; @lines = sort @lines; }
    write_lines($out, @lines);
} elsif ($cmd eq "rows") {
    my ($out, @files) = @ARGV;
    my @lines;
    for my $f (@files) {
        open my $h, "<:raw", $f or die "cannot read $f: $!\n";
        while (my $l = <$h>) {
            $l =~ s/\r?\n\z//;
            my ($cat, $tool) = split /\|/, $l, 3;
            next unless defined $tool;
            push @lines, $l if $cat eq "ACTION"
                || $tool eq "harness files" || $tool eq "cursor rules" || $tool eq "cursor skills";
        }
        close $h;
    }
    write_lines($out, @lines);
} elsif ($cmd eq "snap") {
    my ($home, $out) = @ARGV;
    my @lines;
    for my $r (".cursor", ".aitools") {
        for my $e (walk($home, $r)) {
            next if $e->[0] =~ m{\A\.aitools/logs(?:/|\z)};
            my @f = entry(@$e);
            my @st = Time::HiRes::lstat($e->[1]);
            push @lines, join("\t", @f, sprintf("%.9f", $st[9]));
        }
    }
    { use bytes; @lines = sort @lines; }
    write_lines($out, @lines);
} else {
    die "unknown command: $cmd\n";
}
