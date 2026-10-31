#!/usr/bin/env perl
# loopscan.pl FILE... -- list bash while-loops whose stdin is redirected (here-string,
# file, or pipe) and whose body calls a function that may prompt on the terminal.
use strict;
use warnings;
my $prompting = qr/\b(deploy_managed_file|prompt_diff_review|review_json_fields|prompt_json_field_review|sync_managed_json|read_tty_choice|tty_interactive)\b/;
for my $f (@ARGV) {
    open(my $fh, '<', $f) or die "cannot read $f: $!\n";
    my @l = <$fh>;
    close $fh;
    my @stack;
    for my $i (0 .. $#l) {
        my $line = $l[$i];
        next if $line =~ /^\s*#/;
        if ($line =~ /\bwhile\b.*\bdo\b\s*$/ || $line =~ /\bwhile\b.*;\s*do\b/) {
            push @stack, { start => $i, piped => ($line =~ /\|\s*while\b/ ? 1 : 0), fd => ($line =~ /<&\s*\d/ ? 1 : 0) };
            next;
        }
        if ($line =~ /^\s*done\b(.*)$/ && @stack) {
            my $tail = $1;
            my $lp = pop @stack;
            my $redir = '';
            $redir = 'here-string' if $tail =~ /^\s*<<</;
            $redir = 'file' if $tail =~ /^\s*<\s*[^<&(]/;
            $redir = 'procsub' if $tail =~ /^\s*<\s*<\(/;
            $redir = 'pipe' if $lp->{piped};
            next unless $redir;
            next if $tail =~ /^\s*\d<</ || $lp->{fd};
            my $body = join('', @l[$lp->{start} .. $i]);
            my @hits = ($body =~ /$prompting/g);
            if (@hits) {
                my %u; @u{@hits} = ();
                printf "%s:%d-%d %s calls: %s\n", $f, $lp->{start} + 1, $i + 1, $redir, join(',', sort keys %u);
            }
        }
    }
}
