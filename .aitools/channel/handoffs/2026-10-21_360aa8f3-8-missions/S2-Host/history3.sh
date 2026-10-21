#!/usr/bin/env bash
set -uo pipefail
L=/Users/new-jose/.aitools/logs
for f in $L/checks.jsonl $L/deploy.jsonl; do
  echo "=== $f"
  head -c 400 "$f"; echo
  perl -ne 'my ($h)=/"host":"([^"]*)"/; my ($t)=/"(?:ts|timestamp|time)":"([^"]*)"/; next unless defined $h; $t//="?"; $f{$h}//=$t; $l{$h}=$t; $c{$h}++; END{for(sort keys %f){print "$_ n=$c{$_} first=$f{$_} last=$l{$_}\n"}}' "$f"
  echo '--- host transitions (in file order)'
  perl -ne 'my ($h)=/"host":"([^"]*)"/; my ($t)=/"(?:ts|timestamp|time)":"([^"]*)"/; next unless defined $h; if(!defined $p || $p ne $h){print "$t -> $h\n"; $p=$h}' "$f"
done
echo '=== deploy.log first line per day around June 21-23'
grep -hE '^\[2026-06-2[0-3]' $L/deploy.log | perl -ne 'if(/^\[(\d{4}-\d\d-\d\dT\d\d)/){print "$1\n" unless $s{$1}++}'
echo '=== deploy.log "Profile interpolation" lines June 21-22'
grep -hE '^\[2026-06-2[12].*Profile interpolation' $L/deploy.log
echo '=== system.log / install history for hostname (read-only)'
ls -la /Library/Preferences/SystemConfiguration/preferences.plist
grep -iE 'hostname|computername' /var/log/install.log 2>/dev/null | tail -n 5
