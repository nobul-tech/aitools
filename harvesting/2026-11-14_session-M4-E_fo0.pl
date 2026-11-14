
            my %exempt = (
              # "tests/<dir>/test-<name>.sh" => "reason it cannot run in CI",
            );
            open(my $fh, "<", ".github/workflows/check.yml") or die "cannot read .github/workflows/check.yml: $!\n";
            my $yml = do { local $/; <$fh> };
            close($fh);
            my ($n, $bad) = (0, 0);
            my %seen;
            while (my $p = <STDIN>) {
              chomp $p;
              next if $p eq "";
              $n++;
              $seen{$p} = 1;
              my $run = $yml =~ /^\s*run:\s[^#\n]*\bbash\s+\Q$p\E(?:\s|$)/m;
              if (exists $exempt{$p}) {
                if ($run) { print "::error::$p is run in CI and also exempt: remove the exemption\n"; $bad++; }
                else { print "exempt: $p ($exempt{$p})\n"; }
              } elsif (!$run) {
                print "::error::$p is not run by any step in .github/workflows/check.yml\n"; $bad++;
              }
            }
            for my $p (sort keys %exempt) {
              next if $seen{$p};
              print "::error::exempt suite $p is not tracked: remove the exemption\n"; $bad++;
            }
            die "::error::no tests/*/test-*.sh found (git ls-files)\n" if $n == 0;
            exit 1 if $bad;
            print "All $n test suites are in CI or exempt\n";