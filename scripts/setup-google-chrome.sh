#!/usr/bin/env bash
# setup-google-chrome.sh — Installs Google Chrome and NSS tools, and trusts the agent-proxy
# CA certificates in Chrome's NSS store, in the Claude Code web environment (D-CHR1–D-CHR3,
# reference/tool-ops-google-chrome.md). Install commands: /tool-registry skill entries
# google-chrome and nss-tools (registries/tool-registry.json).
# Safe to re-run — every step checks the current state and changes only what differs.
# Platform: Linux (amd64, apt), Claude Code web environment only. In any other environment
# it writes an "n/a (<environment>)" summary row and changes nothing (D-ENV7).
# setup-google-chrome.ps1 is the Windows pair: Windows is never the Claude Code web
# environment, so it only reports n/a (D-ENV4).
#
# Managed: package google-chrome-stable, package libnss3-tools, and in $HOME/.pki/nssdb
#   (store created if missing) every certificate of the CA file (a bundle), matched by
#   SHA-256 fingerprint under any nickname and trusted C (D-ENV9). A missing one is
#   imported as "ccr-agent-proxy" (first) / "ccr-agent-proxy-<n>" (n-th) or the next free
#   "ccr-agent-proxy-<n>"; a nickname is deleted only when an import needs it and it holds
#   a certificate that is not in the CA file.
# Preserved: every other certificate and nickname in the NSS store (logged when it is one
#   of ours and not in the CA file); the image's Playwright Chromium.
#
# Overrides (tests): AITOOLS_CHROME_BIN (default /opt/google/chrome/chrome),
#   AITOOLS_PROXY_CA (default /root/.ccr/agent-proxy-ca.crt).

set -euo pipefail

# --- Flag parsing ---
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
    esac
done
[ "${AITOOLS_DRY_RUN:-}" = "1" ] && DRY_RUN=true

# --- Shared library ---
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/aitools-lib.sh"
logging_init "setup-google-chrome"

# --- OS guard ---
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        log_error "This script is for macOS/Linux. On Windows, use ${SCRIPT_NAME}.ps1 instead."
        exit 1 ;;
esac

[ "$DRY_RUN" = "true" ] && log "[DRY RUN] Preview mode -- nothing will be installed or written"

CHROME_DEB_URL="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
# Verified: 2026-10-05 (154.0.8037.97) -- Puppeteer's stable-channel default path
CHROME_BIN="${AITOOLS_CHROME_BIN:-/opt/google/chrome/chrome}"
PROXY_CA="${AITOOLS_PROXY_CA:-/root/.ccr/agent-proxy-ca.crt}"
NSSDB="$HOME/.pki/nssdb"
CA_NICK="ccr-agent-proxy"

# Log captured command output to the log file as detail lines (blank lines skipped).
write_output_detail() {  # label, output
    local line
    while IFS= read -r line; do
        if [ -n "${line// /}" ]; then log_detail "$1: $line"; fi
    done <<< "$2"
}

# apt-get install with one retry after `apt-get update` (a fresh container may have
# stale package lists). Returns apt-get's exit code and sets APT_INSTALL_OUTPUT /
# APT_INSTALL_RC (the last attempt's output and exit code). Output goes to the log as
# detail, except a failed last attempt's: the caller passes it to error_reason, which
# logs it (reference/logging.md 8.2).
apt_install() {  # label, package-or-deb-path
    local label="$1" target="$2" out rc=0
    APT_INSTALL_OUTPUT=""; APT_INSTALL_RC=0
    out=$(DEBIAN_FRONTEND=noninteractive apt-get install -y "$target" 2>&1) || rc=$?
    write_output_detail "apt-get install $label (exit $rc)" "$out"
    if [ "$rc" -eq 0 ]; then return 0; fi
    log "apt-get install $label failed (exit $rc) -- running apt-get update and retrying once"
    local urc=0
    out=$(apt-get update 2>&1) || urc=$?
    write_output_detail "apt-get update (exit $urc)" "$out"
    rc=0
    out=$(DEBIAN_FRONTEND=noninteractive apt-get install -y "$target" 2>&1) || rc=$?
    APT_INSTALL_OUTPUT="$out"; APT_INSTALL_RC="$rc"
    if [ "$rc" -eq 0 ]; then write_output_detail "apt-get install $label retry (exit $rc)" "$out"; fi
    return "$rc"
}

# Print the n-th (1-based) PEM certificate of a file; empty output if there is none.
pem_cert() {  # file, n
    perl -0777 -ne 'my @c = /(-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----)/sg; print $c['"$2"' - 1], "\n" if $c['"$2"' - 1];' "$1"
}
# SHA-256 fingerprint (lowercase hex of the DER) of each PEM certificate on stdin, one per
# line, in file order. Certificates are matched by fingerprint, never by nickname (D-ENV9).
pem_fingerprints() {
    perl -MMIME::Base64 -MDigest::SHA=sha256_hex -0777 -ne 'while (/-----BEGIN CERTIFICATE-----(.*?)-----END CERTIFICATE-----/sg) { print sha256_hex(decode_base64($1)), "\n" }'
}

# True when an NSS trust string ("C,,", "CT,C,C", ...) trusts the certificate as a CA for
# TLS servers (C in the SSL field), which is what Chrome needs.
trust_ok() { case "${1%%,*}" in *C*) return 0 ;; *) return 1 ;; esac; }

# Read every certificate in the store into parallel arrays STORE_NICKS / STORE_TRUSTS /
# STORE_FPS. Returns non-zero, with SCAN_STORE_RC 1, when the store cannot be listed:
# the error is recorded here, at the source, for every caller (no caller records it again).
scan_store() {
    STORE_NICKS=(); STORE_TRUSTS=(); STORE_FPS=()
    SCAN_STORE_RC=0
    [ -f "$NSSDB/cert9.db" ] || return 0
    local out rc=0 rows nick trust cert_out crc fp n=0
    out=$(certutil -L -d "sql:$NSSDB" 2>&1) || rc=$?
    if [ "$rc" -ne 0 ]; then
        SCAN_STORE_RC=1
        # error_reason logs the output as detail lines
        write_error "chrome proxy ca" "could not list the NSS store $(display_path "$NSSDB")" "$(error_reason "$out" "$rc")"
        return 1
    fi
    # Data rows only: the two header lines start with "Certificate Nickname" and a space.
    rows=$(printf '%s\n' "$out" | perl -ne 'next if /^\s/ || /^Certificate Nickname/; print "$1\t$2\n" if /^(.+?)\s+(\S*,\S*,\S*)\s*$/')
    while IFS=$'\t' read -r nick trust; do
        [ -n "$nick" ] || continue
        crc=0
        # stdin from /dev/null: the loop reads its rows from stdin.
        cert_out=$(certutil -L -d "sql:$NSSDB" -n "$nick" -a 2>&1 < /dev/null) || crc=$?
        fp=""
        if [ "$crc" -eq 0 ]; then
            fp=$(printf '%s\n' "$cert_out" | pem_fingerprints)
            fp="${fp%%$'\n'*}"   # first certificate only
        else
            # Listed but unreadable: kept with an empty fingerprint, so it never matches
            # a bundle certificate and is never deleted.
            write_output_detail "certutil -L -n $nick (exit $crc)" "$cert_out"
        fi
        STORE_NICKS[$n]="$nick"; STORE_TRUSTS[$n]="$trust"; STORE_FPS[$n]="$fp"
        n=$((n + 1))
    done <<< "$rows"
    return 0
}

# Index in the STORE_* arrays of the nickname holding a fingerprint; prints nothing if none.
store_index_of_fp() {  # fingerprint
    local j=0
    while [ "$j" -lt "${#STORE_FPS[@]}" ]; do
        if [ -n "${STORE_FPS[$j]}" ] && [ "${STORE_FPS[$j]}" = "$1" ]; then echo "$j"; return 0; fi
        j=$((j + 1))
    done
    return 0
}
# Index in the STORE_* arrays of a nickname; prints nothing if absent.
store_index_of_nick() {  # nickname
    local j=0
    while [ "$j" -lt "${#STORE_NICKS[@]}" ]; do
        if [ "${STORE_NICKS[$j]}" = "$1" ]; then echo "$j"; return 0; fi
        j=$((j + 1))
    done
    return 0
}
# True when a fingerprint is one of the bundle's (BUNDLE_FPS).
in_bundle() {  # fingerprint
    local f
    for f in "${BUNDLE_FPS[@]}"; do [ "$f" = "$1" ] && return 0; done
    return 1
}

# Run certutil with output captured; returns certutil's exit code and sets
# RUN_CERTUTIL_OUTPUT / RUN_CERTUTIL_RC. The output goes to the log as detail on success;
# a failed run's output is left to the caller's error_reason, which logs it (logging.md 8.2).
run_certutil() {  # label, certutil args...
    local label="$1" out rc=0
    shift
    out=$(certutil "$@" 2>&1 < /dev/null) || rc=$?   # never wait for a prompt
    RUN_CERTUTIL_OUTPUT="$out"; RUN_CERTUTIL_RC="$rc"
    if [ "$rc" -eq 0 ]; then write_output_detail "certutil $label (exit $rc)" "$out"; fi
    return "$rc"
}

# The reason a certificate is not trusted C after a certutil step (-M or -A): certutil's
# own error when it failed, else the given text; nothing when scan_store failed (that
# error is already recorded at its source). Prints the reason; returns 1 when there is
# nothing to record.
trust_fail_reason() {  # reason when certutil succeeded but the trust is still not C
    if [ "$RUN_CERTUTIL_RC" -ne 0 ]; then
        error_reason "$RUN_CERTUTIL_OUTPUT" "$RUN_CERTUTIL_RC"
    elif [ "$SCAN_STORE_RC" -ne 0 ]; then
        return 1
    else
        printf '%s\n' "$1"
    fi
}

RUN_CERTUTIL_OUTPUT=""; RUN_CERTUTIL_RC=0; SCAN_STORE_RC=0

# --- Environment gate (D-CHR1: managed only in the Claude Code web environment) ---
if ! is_claude_code_web; then
    write_environment_skip "google chrome" "Google Chrome is managed only in the Claude Code web environment (D-CHR1); nothing changed"
elif [ "$(id -u)" -ne 0 ]; then
    write_error "google chrome" "requires root" "apt-get and the root NSS store need root; running as uid $(id -u)"
elif ! command -v apt-get >/dev/null 2>&1 || [ "$(dpkg --print-architecture 2>/dev/null)" != "amd64" ]; then
    # dpkg's stderr is dropped: a missing dpkg yields "" and fails the same test.
    write_error "google chrome" "needs apt on amd64" "Google's .deb is amd64 only; apt-get missing or dpkg architecture is not amd64"
else
    # --- 1. Google Chrome ---
    if [ -x "$CHROME_BIN" ]; then
        chrome_rc=0
        # Chrome logs a channel WARNING on stderr for --version (observed 2026-10-05):
        # stdout is the version; stderr is captured separately into the log.
        chrome_err_file="$LOG_DIR/.setup-google-chrome.stderr"
        chrome_err=""
        chrome_version=$("$CHROME_BIN" --version 2>"$chrome_err_file") || chrome_rc=$?
        if [ -f "$chrome_err_file" ]; then
            chrome_err=$(cat "$chrome_err_file")
            rm -f "$chrome_err_file"
        fi
        chrome_version="${chrome_version%"${chrome_version##*[![:space:]]}"}"
        if [ "$chrome_rc" -eq 0 ] && [ -n "$chrome_version" ]; then
            write_output_detail "chrome --version stderr" "$chrome_err"
            log_ok "Google Chrome present: $chrome_version"
            write_summary OK "google chrome" "$chrome_version"
        else
            # error_reason logs the stderr as detail lines
            write_error "google chrome" "binary broken" "$(error_reason "$chrome_err" "$chrome_rc")"
        fi
    elif [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would download $CHROME_DEB_URL and apt-get install it"
        write_summary OK "google chrome" "dry-run: would install"
    elif ! deb_dir=$(mktemp -d); then
        write_error "google chrome" "temp dir failed" "mktemp -d failed -- cannot download the Chrome .deb"
    else
        log "Installing Google Chrome from $CHROME_DEB_URL"
        deb="$deb_dir/google-chrome-stable_current_amd64.deb"
        curl_rc=0
        curl_out=$(curl -fsSL -o "$deb" "$CHROME_DEB_URL" 2>&1) || curl_rc=$?
        if [ "$curl_rc" -ne 0 ]; then
            # error_reason logs the output as detail lines
            write_error "google chrome" "download failed" "$(error_reason "$curl_out" "$curl_rc")"
        elif apt_install "google-chrome-stable" "$deb"; then
            if [ -x "$CHROME_BIN" ]; then
                # stderr dropped: a failing --version leaves the fallback text below.
                chrome_version=$("$CHROME_BIN" --version 2>/dev/null) || chrome_version="version unknown"
                chrome_version="${chrome_version%"${chrome_version##*[![:space:]]}"}"
                log_ok "Google Chrome installed: $chrome_version"
                write_summary OK "google chrome" "$chrome_version"
            else
                write_error "google chrome" "installed, binary missing" "$CHROME_BIN not found after apt-get install"
            fi
        else
            write_error "google chrome" "apt-get install failed" "$(error_reason "$APT_INSTALL_OUTPUT" "$APT_INSTALL_RC")"
        fi
        rm -rf "$deb_dir"
    fi

    # --- 2. NSS tools (certutil) ---
    if command -v certutil >/dev/null 2>&1; then
        log_ok "certutil present ($(command -v certutil))"
        write_summary OK "nss tools" "certutil present"
    elif [ "$DRY_RUN" = "true" ]; then
        log "[DRY RUN] Would apt-get install libnss3-tools"
        write_summary OK "nss tools" "dry-run: would install"
    elif ! apt_install "libnss3-tools" "libnss3-tools"; then
        write_error "nss tools" "install failed" "$(error_reason "$APT_INSTALL_OUTPUT" "$APT_INSTALL_RC")"
    elif command -v certutil >/dev/null 2>&1; then
        log_ok "libnss3-tools installed ($(command -v certutil))"
        write_summary OK "nss tools" "installed"
    else
        write_error "nss tools" "install failed" "certutil not on PATH after installing libnss3-tools"
    fi

    # --- 3. Agent-proxy CA certificates in Chrome's NSS store (D-CHR3, D-ENV9) ---
    ca_count=0
    if [ -r "$PROXY_CA" ]; then
        # perl, not grep -c: grep exits 1 on zero matches, which set -e would turn into an abort.
        ca_count=$(perl -ne '$n++ if /-----BEGIN CERTIFICATE-----/; END { print $n + 0 }' "$PROXY_CA")
    fi
    if [ ! -r "$PROXY_CA" ]; then
        # No OK record: there is nothing to verify
        write_warn "chrome proxy ca" "$PROXY_CA not found -- Chrome will fail every HTTPS page (net_error -202)"
    elif [ "$ca_count" -eq 0 ]; then
        write_error "chrome proxy ca" "CA file unreadable" "$PROXY_CA holds no PEM certificate"
    elif ! command -v certutil >/dev/null 2>&1; then
        if [ "$DRY_RUN" = "true" ]; then
            log "[DRY RUN] Would create $(display_path "$NSSDB") and import $ca_count certificate(s) from $PROXY_CA"
            write_summary OK "chrome proxy ca" "dry-run: $ca_count of $ca_count to change"
        else
            # Only reached after the nss tools step failed (its error is recorded above):
            # a consequence of that failure, logged at info (one cause, one red line)
            log "certutil unavailable (the nss tools step failed) -- $PROXY_CA not imported"
        fi
    else
        nss_ok=true
        if [ ! -f "$NSSDB/cert9.db" ] && [ "$DRY_RUN" != "true" ]; then
            n_rc=0
            n_out=$( { mkdir -p "$NSSDB" && certutil -N -d "sql:$NSSDB" --empty-password; } 2>&1) || n_rc=$?
            if [ "$n_rc" -ne 0 ]; then
                nss_ok=false
                # error_reason logs the output as detail lines
                write_error "chrome proxy ca" "NSS store create failed" "$(error_reason "$n_out" "$n_rc")"
            else
                write_output_detail "certutil -N (exit $n_rc)" "$n_out"
            fi
        fi
        BUNDLE_FPS=()
        if [ "$nss_ok" = "true" ]; then
            while IFS= read -r fp; do
                [ -n "$fp" ] && BUNDLE_FPS[${#BUNDLE_FPS[@]}]="$fp"
            done <<< "$(pem_fingerprints < "$PROXY_CA")"
            if [ "${#BUNDLE_FPS[@]}" -ne "$ca_count" ]; then
                nss_ok=false
                write_error "chrome proxy ca" "CA file unreadable" "$ca_count PEM block(s) but ${#BUNDLE_FPS[@]} decodable certificate(s)"
            elif ! scan_store; then
                # scan_store recorded the error at its source
                nss_ok=false
            fi
        fi
        if [ "$nss_ok" = "true" ]; then
            # Per bundle certificate (matched by SHA-256 fingerprint, D-ENV9):
            #   in the store under any nickname, trusted C  -> verified (nickname kept)
            #   in the store, not trusted as a CA            -> trust set to C,, (updated)
            #   not in the store                             -> imported (created); its
            #     nickname is ccr-agent-proxy[-i], or the next free ccr-agent-proxy-<n>.
            # A nickname is deleted only when it is needed for an import and holds a
            # certificate that is not in the bundle (replaced). Every other certificate in
            # the store is left as it is.
            n_verified=0; n_created=0; n_replaced=0; n_updated=0; n_failed=0; n_dry=0
            pem_file="$LOG_DIR/.setup-google-chrome.pem"
            i=1
            while [ "$i" -le "$ca_count" ]; do
                fp="${BUNDLE_FPS[$((i - 1))]}"
                short="${fp:0:16}"
                j=$(store_index_of_fp "$fp")
                if [ -n "$j" ] && trust_ok "${STORE_TRUSTS[$j]}"; then
                    n_verified=$((n_verified + 1))
                    log_ok "Certificate $i of $PROXY_CA (sha256 $short...) trusted as ${STORE_NICKS[$j]} (${STORE_TRUSTS[$j]})"
                elif [ -n "$j" ]; then
                    if [ "$DRY_RUN" = "true" ]; then
                        n_dry=$((n_dry + 1))
                        log "[DRY RUN] Would set trust C,, on ${STORE_NICKS[$j]} (certificate $i, now '${STORE_TRUSTS[$j]}')"
                    elif run_certutil "-M ${STORE_NICKS[$j]}" -M -d "sql:$NSSDB" -n "${STORE_NICKS[$j]}" -t "C,," \
                            && scan_store && j=$(store_index_of_fp "$fp") && [ -n "$j" ] && trust_ok "${STORE_TRUSTS[$j]}"; then
                        n_updated=$((n_updated + 1))
                        log_ok "Set trust C,, on ${STORE_NICKS[$j]} (certificate $i, sha256 $short...)"
                    else
                        n_failed=$((n_failed + 1))
                        if reason=$(trust_fail_reason "trust still not C after certutil -M"); then
                            write_error "chrome proxy ca" "could not set trust C,, on certificate $i (sha256 $short...)" "$reason"
                        fi
                    fi
                else
                    # Not in the store: choose the nickname.
                    nick="$CA_NICK"
                    [ "$i" -gt 1 ] && nick="$CA_NICK-$i"
                    k=$(store_index_of_nick "$nick")
                    stale=false
                    if [ -n "$k" ]; then
                        if [ -n "${STORE_FPS[$k]}" ] && ! in_bundle "${STORE_FPS[$k]}"; then
                            stale=true   # holds a certificate that is not in the bundle
                        else
                            # Held by another bundle certificate (or unreadable): use the next
                            # free ccr-agent-proxy-<n> instead of touching it.
                            m=2
                            while [ -n "$(store_index_of_nick "$CA_NICK-$m")" ]; do m=$((m + 1)); done
                            nick="$CA_NICK-$m"
                        fi
                    fi
                    if [ "$DRY_RUN" = "true" ]; then
                        n_dry=$((n_dry + 1))
                        if [ "$stale" = "true" ]; then
                            log "[DRY RUN] Would replace $nick (certificate not in $PROXY_CA) with certificate $i (sha256 $short...)"
                        else
                            log "[DRY RUN] Would import certificate $i (sha256 $short...) as $nick (trust C,,)"
                        fi
                    elif ! { pem_cert "$PROXY_CA" "$i" > "$pem_file" && [ -s "$pem_file" ]; }; then
                        n_failed=$((n_failed + 1))
                        write_error "chrome proxy ca" "could not extract certificate $i" "no PEM block $i in $PROXY_CA"
                    elif [ "$stale" = "true" ] && ! run_certutil "-D $nick" -D -d "sql:$NSSDB" -n "$nick"; then
                        n_failed=$((n_failed + 1))
                        write_error "chrome proxy ca" "could not remove $nick (certificate not in $PROXY_CA)" "$(error_reason "$RUN_CERTUTIL_OUTPUT" "$RUN_CERTUTIL_RC")"
                    elif run_certutil "-A $nick" -A -d "sql:$NSSDB" -n "$nick" -t "C,," -i "$pem_file" \
                            && scan_store && j=$(store_index_of_fp "$fp") && [ -n "$j" ] && trust_ok "${STORE_TRUSTS[$j]}"; then
                        if [ "$stale" = "true" ]; then
                            n_replaced=$((n_replaced + 1))
                            log_ok "Replaced $nick (certificate not in $PROXY_CA) with certificate $i (sha256 $short...)"
                        else
                            n_created=$((n_created + 1))
                            log_ok "Imported certificate $i (sha256 $short...) as $nick (trust C,,)"
                        fi
                    else
                        n_failed=$((n_failed + 1))
                        if reason=$(trust_fail_reason "trust not C after certutil -A"); then
                            write_error "chrome proxy ca" "certificate $i (sha256 $short...) not trusted after import as $nick" "$reason"
                        fi
                    fi
                    # Keep the in-memory view current for the next certificate's checks
                    # (a failure is recorded by scan_store).
                    if [ "$DRY_RUN" != "true" ] && ! scan_store; then
                        n_failed=$((n_failed + 1))
                    fi
                fi
                i=$((i + 1))
            done
            rm -f "$pem_file"
            # Our nicknames whose certificate is not in the bundle and was not needed for an
            # import are preserved (another writer may own them), but logged.
            extra=""
            j=0
            while [ "$j" -lt "${#STORE_NICKS[@]}" ]; do
                case "${STORE_NICKS[$j]}" in
                    "$CA_NICK"|"$CA_NICK"-[0-9]*)
                        if [ -n "${STORE_FPS[$j]}" ] && ! in_bundle "${STORE_FPS[$j]}"; then
                            extra="$extra ${STORE_NICKS[$j]}"
                        fi ;;
                esac
                j=$((j + 1))
            done
            if [ -n "$extra" ]; then
                log "Preserved NSS nicknames holding certificates not in $PROXY_CA:$extra"
            fi
            n_changed=$((n_created + n_replaced + n_updated))
            parts=""
            [ "$n_created" -gt 0 ] && parts="$parts, $n_created created"
            [ "$n_replaced" -gt 0 ] && parts="$parts, $n_replaced replaced"
            [ "$n_updated" -gt 0 ] && parts="$parts, $n_updated updated"
            row="$ca_count certs: ${parts#, }"
            # OK status text is at most 30 characters (script-standards); fall back to a total.
            [ "${#row}" -le 30 ] || row="$ca_count certs, $n_changed changed"
            log "CA certificates: $ca_count in bundle, $n_verified verified, $n_created created, $n_replaced replaced, $n_updated trust updated, $n_failed failed, $n_dry dry-run"
            if [ "$n_failed" -gt 0 ]; then
                # Each failure is recorded at its source; no OK record
                :
            elif [ "$n_dry" -gt 0 ]; then
                write_summary OK "chrome proxy ca" "dry-run: $n_dry of $ca_count to change"
            elif [ "$n_changed" -eq 0 ]; then
                write_summary OK "chrome proxy ca" "verified ($ca_count certs)"
            else
                write_summary OK "chrome proxy ca" "$row"
            fi
        fi
    fi
fi

# --- Exit ---
if [ "$ERRORS" -gt 0 ]; then
    log "FAILED with $ERRORS error(s)" "error"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    log "COMPLETED with $WARNINGS warning(s)" "warn"
    exit 0
else
    log "COMPLETED successfully" "ok"
    exit 0
fi
