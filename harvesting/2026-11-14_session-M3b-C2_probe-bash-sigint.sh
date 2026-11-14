#!/usr/bin/env bash
# probe-bash-sigint.sh -- does the bash AI spinner survive Ctrl+C?
# Replica of _start_spinner (scripts/aitools-lib.sh): same ( loop ) & shape, but each frame is
# appended to a file instead of /dev/tty so it can be observed here. The "setup script" is a
# non-interactive bash (job control off, like setup-*.sh) started in its own process group;
# Ctrl+C is modelled as SIGINT to that whole process group (what the terminal sends).
set -euo pipefail
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/sigint"
mkdir -p "$dir"
frames="$dir/frames.txt"; pidf="$dir/spinner.pid"
: > "$frames"; : > "$pidf"
set -m   # job control here, so the child below gets its own process group
bash -c '
    ( chars="/-\\|"; i=0; while true; do printf "%s\n" "${chars:$((i % 4)):1}" >> "$1"; i=$((i + 1)); sleep 0.2; done ) &
    echo $! > "$2"
    sleep 30   # the AI call
' probe "$frames" "$pidf" &
child=$!
sleep 1.2
spid="$(cat "$pidf")"
before="$(wc -l < "$frames")"
echo "setup-script pid=$child spinner pid=$spid frames before SIGINT=$before"
kill -INT -- "-$child"
sleep 0.5
if kill -0 "$child" 2>/dev/null; then echo "setup script still running after SIGINT"; else echo "setup script ended after SIGINT"; fi
n1="$(wc -l < "$frames")"
sleep 1.5
n2="$(wc -l < "$frames")"
if kill -0 "$spid" 2>/dev/null; then alive=yes; else alive=no; fi
echo "after SIGINT: spinner alive=$alive frames +0.5s=$n1 +2.0s=$n2"
if [ "$alive" = yes ]; then kill "$spid"; echo "cleanup: killed spinner $spid"; fi
