#!/usr/bin/env node
// aitools-profile.js -- the one resolver for "where is my dotprofile" and
// "which machine profile is this machine".
//
// Intent: Resolve, deterministically and with a stated reason ("via"), the
// dotprofile repo path and this machine's profile in profile.json, and derive
// the config.json values that come from them. NOT a writer of config.json
// (setup-user-config.sh/.ps1 is the only writer). NOT a writer of profile.json
// except the `register` subcommand, which writes to a temp file the caller
// validates, backs up and moves. NOT the settings.json sync (sync_managed_json).
// Consumed by: resolve_user_repo_path / resolve_machine_profile (bash shared lib),
// Resolve-UserRepoPath / Resolve-MachineProfile (PowerShell shared lib),
// setup-user-config.sh/.ps1, build-deploy.sh, profile-check.js (require),
// (Do not name the shared-lib files in this file: build-deploy's lib inliners
// replace any line containing them, which would corrupt the embedded copy.)
// aitools / aitools.ps1 `user init`, and the generated deploy/setup-user-claude.*
// (embedded copy).
//
// Usage: node aitools-profile.js <command> [options]   (--help for details)
// Exit codes: 0 resolved / ok, 1 nothing found (expected states, e.g. before
// `aitools user init`), 2 error (bad input, unreadable or corrupt JSON,
// ambiguous match). Results are JSON on stdout unless --format is given.
// Node stdlib only. Safe to re-run: every command except `register` is read-only.

'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const { spawnSync } = require('child_process');

const HELP = `aitools-profile.js -- dotprofile and machine-profile resolver

Commands:
  user-repo-path   Print the dotprofile path. Options: --config F, --github-user U,
                   --format native|mixed|bash (default native), --json
  machine-id       Print this machine's hashed stable id (sha256:<16 hex>)
  resolve          JSON: which profile this machine uses and why.
                   Options: --config F, --profile F, --alias A, --environment E
  derive-config    JSON: the config.json values derived from profile.json.
                   Options: --config F, --github-user U, --user-repo-path P,
                   --repos-path P, --alias A, --environment E
  snapshot         JSON: identity + profiles + cursor from --profile F (for embedding)
  register         Write --profile F with this machine registered under --alias A to
                   --out TMP. Options: --name N, --company C, --shell S, --create
                   (start a new profile; needs --github-user U, --email E)

Output: JSON, or --format tagged (key<TAB>value lines; --path-form bash|mixed|native).

Environment overrides: AITOOLS_USER_REPO_PATH, AITOOLS_MACHINE_ALIAS,
AITOOLS_PROFILE_FILE, AITOOLS_ENVIRONMENT (resolved by aitools-lib).
Exit: 0 ok, 1 not found, 2 error.`;

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------
function parseArgs(argv) {
    const out = { _: [] };
    for (let i = 0; i < argv.length; i++) {
        const a = argv[i];
        if (a === '--help' || a === '-h') { out.help = true; continue; }
        if (a.startsWith('--')) {
            const eq = a.indexOf('=');
            if (eq > 0) { out[a.slice(2, eq)] = a.slice(eq + 1); continue; }
            const next = argv[i + 1];
            if (next === undefined || next.startsWith('--')) { out[a.slice(2)] = true; }
            else { out[a.slice(2)] = next; i++; }
        } else {
            out._.push(a);
        }
    }
    return out;
}

// Read JSON with BOM strip. Returns { value } | { missing: true } | { error }.
function readJson(file) {
    let raw;
    try {
        raw = fs.readFileSync(file, 'utf8');
    } catch (e) {
        if (e.code === 'ENOENT') return { missing: true };
        return { error: 'cannot read ' + file + ': ' + e.message };
    }
    raw = raw.replace(/^﻿/, '');
    try {
        const v = JSON.parse(raw);
        if (v === null || typeof v !== 'object' || Array.isArray(v)) {
            return { error: file + ': top level is not an object' };
        }
        return { value: v };
    } catch (e) {
        return { error: file + ' is invalid JSON: ' + e.message };
    }
}

function isDir(p) {
    try { return fs.statSync(p).isDirectory(); } catch (e) { return false; }
}

function defaultConfigPath() {
    return path.join(os.homedir(), '.aitools', 'config.json');
}

// Path forms. native: OS form (config.json storage). mixed: forward slashes
// (env var exported to build-deploy; valid in Git Bash, PowerShell and node).
// bash: /c/... on Windows (Git Bash), unchanged elsewhere.
function formatPath(p, form) {
    if (!p) return p;
    if (form === 'mixed') return p.replace(/\\/g, '/');
    if (form === 'bash') {
        const m = /^([A-Za-z]):[\\/](.*)$/.exec(p);
        if (m && process.platform === 'win32') return '/' + m[1].toLowerCase() + '/' + m[2].replace(/\\/g, '/');
        return p.replace(/\\/g, '/');
    }
    return path.normalize(p);
}

function shortHost(h) {
    return String(h || '').split('.')[0].trim().toLowerCase();
}

// Environment: prefer the value the shared lib already resolved (passed with
// --environment or exported). Parity copy of the lib rule for standalone callers
// (build-deploy, profile-check): claude-code-web exists only on linux.
function resolveEnvironment(explicit) {
    let env = explicit || process.env.AITOOLS_ENVIRONMENT || '';
    if (env !== 'claude-code-web' && env !== 'local') {
        env = process.env.CLAUDE_CODE_REMOTE === 'true' ? 'claude-code-web' : 'local';
    }
    if (process.platform !== 'linux') env = 'local';
    return env;
}

// ---------------------------------------------------------------------------
// Machine identity
// ---------------------------------------------------------------------------
// Raw stable id per platform. Returns { raw, source } or { error }.
//   macOS:   IOPlatformUUID (ioreg) -- hardware-bound, survives OS reinstall
//   Windows: HKLM\SOFTWARE\Microsoft\Cryptography MachineGuid -- UNVERIFIED on
//            this harness (changes on OS reinstall; duplicated on unsysprepped clones)
//   Linux:   /etc/machine-id, then /var/lib/dbus/machine-id (duplicated on cloned images)
function rawMachineId() {
    if (process.platform === 'darwin') {
        const r = spawnSync('/usr/sbin/ioreg', ['-rd1', '-c', 'IOPlatformExpertDevice'], { encoding: 'utf8' });
        if (r.status !== 0 || !r.stdout) return { error: 'ioreg failed (exit ' + r.status + ')' };
        const m = /"IOPlatformUUID"\s*=\s*"([^"]+)"/.exec(r.stdout);
        return m ? { raw: m[1], source: 'IOPlatformUUID' } : { error: 'IOPlatformUUID not found in ioreg output' };
    }
    if (process.platform === 'win32') {
        // UNVERIFIED: verify on the workstation before relying on it (KnownPaths rule).
        const r = spawnSync('reg', ['query', 'HKLM\\SOFTWARE\\Microsoft\\Cryptography', '/v', 'MachineGuid'], { encoding: 'utf8' });
        if (r.status !== 0 || !r.stdout) return { error: 'reg query MachineGuid failed (exit ' + r.status + ')' };
        const m = /MachineGuid\s+REG_SZ\s+(\S+)/i.exec(r.stdout);
        return m ? { raw: m[1], source: 'MachineGuid' } : { error: 'MachineGuid not found in reg output' };
    }
    for (const f of ['/etc/machine-id', '/var/lib/dbus/machine-id']) {
        try {
            const v = fs.readFileSync(f, 'utf8').trim();
            if (v) return { raw: v, source: f };
        } catch (e) {
            if (e.code !== 'ENOENT') return { error: 'cannot read ' + f + ': ' + e.message };
        }
    }
    return { error: 'no machine-id file found' };
}

// Hashed form stored in profile.json: hardware ids are not written to git raw.
function machineId() {
    const r = rawMachineId();
    if (r.error) return r;
    // Keyed (app-specific) hash, so the stored value cannot be matched against the
    // raw id or another application's hash of it.
    const h = crypto.createHmac('sha256', 'aitools-machine-id-v1').update(r.raw.trim().toUpperCase()).digest('hex');
    return { id: 'sha256:' + h.slice(0, 16), source: r.source };
}

// Hostname candidates, all lowercased short names. Same list in bash and PS1
// because both call this module (closes the $env:COMPUTERNAME parity gap).
function hostnameCandidates() {
    const set = new Set();
    const add = v => { const s = shortHost(v); if (s) set.add(s); };
    add(os.hostname());
    if (process.platform === 'darwin') {
        for (const k of ['LocalHostName', 'ComputerName']) {
            const r = spawnSync('/usr/sbin/scutil', ['--get', k], { encoding: 'utf8' });
            if (r.status === 0 && r.stdout) add(r.stdout.trim().replace(/\s+/g, '-'));
        }
    }
    if (process.platform === 'win32') add(process.env.COMPUTERNAME);
    return Array.from(set);
}

// ---------------------------------------------------------------------------
// Dotprofile path -- the single definition of the location convention:
//   <reposPath>/aitools-<github-user>
//   reposPath default: ~/repos (macOS, Linux), %USERPROFILE%\repos (Windows)
// Order: AITOOLS_USER_REPO_PATH > config.userRepoPath > convention (githubUser
// from --github-user or config.githubUser) > the only aitools-* dir under
// reposPath that holds a profile.json > none.
// ---------------------------------------------------------------------------
function defaultReposPath() {
    return path.join(os.homedir(), 'repos');
}

function resolveUserRepoPath(cfg, opts) {
    const o = opts || {};
    const warnings = [];
    // An explicit argument beats the environment override (a caller's choice wins).
    if (o.explicit) {
        if (isDir(o.explicit)) return { path: path.normalize(o.explicit), via: 'argument', warnings };
        return { error: '--user-repo-path does not exist: ' + o.explicit, warnings };
    }
    const override = o.override !== undefined ? o.override : process.env.AITOOLS_USER_REPO_PATH;
    if (override) {
        if (isDir(override)) return { path: path.normalize(override), via: 'env', warnings };
        return { error: 'AITOOLS_USER_REPO_PATH does not exist: ' + override, warnings };
    }
    if (cfg.userRepoPath) {
        if (isDir(cfg.userRepoPath)) return { path: path.normalize(cfg.userRepoPath), via: 'config', warnings };
        warnings.push('config.json userRepoPath does not exist: ' + cfg.userRepoPath);
    }
    const base = o.reposPath || cfg.reposPath || defaultReposPath();
    const user = o.githubUser || cfg.githubUser || '';
    if (user) {
        const p = path.join(base, 'aitools-' + user);
        if (isDir(p)) return { path: p, via: 'convention', warnings };
        return { path: '', via: 'none', expected: p, warnings };
    }
    let found = [];
    try {
        found = fs.readdirSync(base)
            .filter(n => /^aitools-[A-Za-z0-9-]+$/.test(n))
            .map(n => path.join(base, n))
            .filter(p => fs.existsSync(path.join(p, 'profile.json')));
    } catch (e) {
        if (e.code !== 'ENOENT') warnings.push('cannot list ' + base + ': ' + e.message);
    }
    if (found.length === 1) {
        warnings.push('githubUser unknown -- used the only dotprofile under ' + base);
        return { path: found[0], via: 'scan', warnings };
    }
    if (found.length > 1) warnings.push('githubUser unknown and ' + found.length + ' aitools-* repos with profile.json under ' + base);
    return { path: '', via: 'none', warnings };
}

// ---------------------------------------------------------------------------
// Machine profile resolution. Order (first decisive step wins):
//   1. override alias   (AITOOLS_MACHINE_ALIAS or --alias)   via=override
//   2. environment      claude-code-web profile               via=environment
//   3. machine.id       hashed stable id                      via=id
//   4. config alias     config.json machineAlias              via=alias
//   5. hostname         legacy, warns                         via=hostname
//   6. none             ERROR; never a silent first-profile fallback
// ---------------------------------------------------------------------------
function effectiveProfile(p, alias) {
    const prof = p.profiles[alias] || {};
    const ident = p.identity || {};
    const git = ident.git || {};
    return {
        alias: alias,
        name: prof.name !== undefined ? prof.name : (ident.name !== undefined ? ident.name : (git.name || '')),
        company: prof.company !== undefined ? prof.company : (ident.company || ''),
        gitName: git.name || '',
        gitEmail: git.email || '',
        github: ident.github || '',
        machine: prof.machine || {},
        toolExceptions: prof.toolExceptions || {}
    };
}

function resolveMachine(p, ctx) {
    const c = ctx || {};
    const res = { alias: '', via: 'none', warnings: [], errors: [] };
    if (!p || p.version !== 2 || !p.profiles || typeof p.profiles !== 'object') {
        res.errors.push('profile.json is not v2 or has no profiles');
        return res;
    }
    const aliases = Object.keys(p.profiles).filter(a => p.profiles[a] && typeof p.profiles[a] === 'object');
    if (aliases.length !== Object.keys(p.profiles).length) res.warnings.push('profile.json has profile entries that are not objects -- ignored');
    if (aliases.length === 0) { res.errors.push('profile.json has no machine profiles'); return res; }
    const environment = resolveEnvironment(c.environment);
    const mid = c.machineId !== undefined ? c.machineId : machineId();
    res.environment = environment;
    res.machineId = mid.id || '';
    if (mid.error) res.machineIdError = mid.error;
    res.hostnames = c.hostnames || hostnameCandidates();

    const done = (alias, via) => {
        res.alias = alias; res.via = via;
        res.profile = effectiveProfile(p, alias);
        const pid = res.profile.machine.id;
        if (via !== 'id' && via !== 'environment' && res.machineId && pid && pid !== res.machineId) {
            res.warnings.push('profile "' + alias + '" is registered to another machine (machine.id ' + pid + ', this machine ' + res.machineId + ')');
        }
        if (via !== 'id' && via !== 'environment' && via !== 'hostname' && res.machineId && !pid) {
            res.warnings.push('profile "' + alias + '" has no machine.id -- run: aitools user init (registers this machine)');
        }
        return res;
    };

    const override = c.alias || process.env.AITOOLS_MACHINE_ALIAS || '';
    res.overrideSource = c.alias ? 'argument' : (override ? 'env' : '');
    if (override) {
        if (aliases.includes(override)) return done(override, 'override');
        res.errors.push('override alias "' + override + '" not in profiles (' + aliases.join(', ') + ')');
        return res;
    }
    if (environment === 'claude-code-web') {
        const m = aliases.filter(a => (p.profiles[a].machine || {}).environment === 'claude-code-web');
        if (m.length === 1) return done(m[0], 'environment');
        if (m.length > 1) { res.errors.push('more than one claude-code-web profile: ' + m.join(', ')); return res; }
        res.warnings.push('no profile has machine.environment "claude-code-web"');
    } else if (res.machineId) {
        const m = aliases.filter(a => (p.profiles[a].machine || {}).id === res.machineId);
        if (m.length === 1) {
            if (c.configAlias && c.configAlias !== m[0]) {
                res.warnings.push('config.json machineAlias "' + c.configAlias + '" disagrees with machine.id match "' + m[0] + '" -- machine.id wins');
            }
            return done(m[0], 'id');
        }
        if (m.length > 1) { res.errors.push('machine.id ' + res.machineId + ' is registered on more than one profile: ' + m.join(', ')); return res; }
    }
    if (c.configAlias) {
        if (p.profiles[c.configAlias]) return done(c.configAlias, 'alias');
        res.warnings.push('config.json machineAlias "' + c.configAlias + '" not in profiles (' + aliases.join(', ') + ')');
    }
    const hm = aliases.filter(a => {
        const m = p.profiles[a].machine || {};
        const names = [m.hostname].concat(Array.isArray(m.hostnames) ? m.hostnames : []).map(shortHost).filter(Boolean);
        return names.some(n => res.hostnames.includes(n));
    });
    if (hm.length === 1) {
        res.warnings.push('matched by hostname only (legacy) -- run: aitools user init (registers machine.id)');
        return done(hm[0], 'hostname');
    }
    if (hm.length > 1) { res.errors.push('hostname matches more than one profile: ' + hm.join(', ')); return res; }
    res.errors.push('no profile matches this machine (machine.id ' + (res.machineId || 'unavailable') + ', hostnames ' + res.hostnames.join('/') + ') -- run: aitools user init');
    return res;
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------
function loadConfig(args) {
    const file = args.config || defaultConfigPath();
    const r = readJson(file);
    if (r.error) return { file, error: r.error };
    return { file, cfg: r.missing ? {} : r.value, missing: !!r.missing };
}

function profileFileFor(repo, args) {
    return args.profile || process.env.AITOOLS_PROFILE_FILE || (repo ? path.join(repo, 'profile.json') : '');
}

// Output: JSON (default) or, with --format tagged, one "key<TAB>value" line per
// field plus "warn<TAB>..." / "error<TAB>..." lines -- for bash wrappers that
// read with `while IFS=$'\t' read -r k v`. Values are single-line.
let OUTPUT_TAGGED = false;
let TAGGED_PATH_FORM = 'bash';
function oneLine(v) { return String(v === undefined || v === null ? '' : v).replace(/[\r\n\t]+/g, ' '); }
function emit(obj, code) {
    if (!OUTPUT_TAGGED) {
        process.stdout.write(JSON.stringify(obj) + '\n');
        process.exit(code);
    }
    const lines = [];
    const put = (k, v) => lines.push(k + '\t' + oneLine(v));
    const pathKeys = new Set(['path', 'profileFile', 'userRepoPath']);
    for (const [k, v] of Object.entries(obj)) {
        if (k === 'warnings' || k === 'errors' || k === 'profile' || k === 'derived') continue;
        if (Array.isArray(v)) put(k, v.join('/'));
        else if (v !== null && typeof v === 'object') continue;
        else put(k, pathKeys.has(k) ? formatPath(v, TAGGED_PATH_FORM) : v);
    }
    if (obj.profile) {
        for (const k of ['name', 'company', 'gitName', 'gitEmail', 'github']) put(k, obj.profile[k]);
    }
    if (obj.derived) for (const [k, v] of Object.entries(obj.derived)) put('derived.' + k, v);
    for (const w of obj.warnings || []) put('warn', w);
    for (const e of obj.errors || []) put('error', e);
    process.stdout.write(lines.join('\n') + '\n');
    process.exit(code);
}

function cmdUserRepoPath(args) {
    const c = loadConfig(args);
    // A corrupt config.json must not block the run that repairs it (setup-user-config):
    // warn and resolve without it (convention / scan still work).
    const r = resolveUserRepoPath(c.error ? {} : c.cfg, { githubUser: args['github-user'] });
    if (c.error) r.warnings.unshift(c.error + ' -- resolving without it');
    if (args.json || OUTPUT_TAGGED) {
        if (r.error) { r.errors = [r.error]; delete r.error; emit(r, 2); }
        emit(r, r.path ? 0 : 1);
    }
    for (const w of r.warnings) console.error('warning: ' + w);
    if (r.error) { console.error(r.error); process.exit(2); }
    if (!r.path) process.exit(1);
    process.stdout.write(formatPath(r.path, args.format || 'native') + '\n');
    process.exit(0);
}

function cmdMachineId() {
    const r = machineId();
    if (r.error) { console.error(r.error); process.exit(2); }
    process.stdout.write(r.id + '\n');
    process.exit(0);
}

function cmdResolve(args) {
    const c = loadConfig(args);
    if (c.error) emit({ via: 'none', errors: [c.error + ' -- run setup-user-config (aitools) to rebuild it'] }, 2);
    let pf = args.profile || process.env.AITOOLS_PROFILE_FILE || '';
    if (pf && !fs.existsSync(pf)) {
        emit({ via: 'none', errors: ['profile file set but missing: ' + pf + (args.profile ? '' : ' (AITOOLS_PROFILE_FILE)')], profileFile: pf }, 2);
    }
    let repo = null;
    if (!pf) {
        repo = resolveUserRepoPath(c.cfg, {});
        if (repo.error) emit({ via: 'none', errors: [repo.error], warnings: repo.warnings }, 2);
        if (!repo.path) emit({ via: 'none', errors: [], warnings: repo.warnings, profileFile: '' }, 1);
        pf = path.join(repo.path, 'profile.json');
    }
    const r = readJson(pf);
    if (r.missing) emit({ via: 'none', errors: [], warnings: ['profile.json not found: ' + pf], profileFile: pf }, 1);
    if (r.error) emit({ via: 'none', errors: [r.error], profileFile: pf }, 2);
    const res = resolveMachine(r.value, { alias: args.alias, configAlias: c.cfg.machineAlias || '', environment: args.environment });
    // No machine match: still report the identity-level values (machine-independent),
    // never another profile's overrides. Exit stays 2 so callers log the error.
    if (!res.alias && r.value && r.value.version === 2) {
        const ident = r.value.identity || {};
        const git = ident.git || {};
        res.profile = { alias: '', name: ident.name || git.name || '', company: ident.company || '', gitName: git.name || '', gitEmail: git.email || '', github: ident.github || '', machine: {}, toolExceptions: {} };
    }
    res.profileFile = pf;
    if (repo) { res.userRepoPath = repo.path; res.userRepoVia = repo.via; res.warnings = repo.warnings.concat(res.warnings); }
    emit(res, res.alias ? 0 : 2);
}

function cmdDeriveConfig(args) {
    const c = loadConfig(args);
    // A corrupt config.json must not block re-deriving it: the writer rebuilds it.
    const cfg = Object.assign({}, c.error ? {} : c.cfg);
    const preWarnings = c.error ? [c.error + ' -- deriving without it'] : [];
    if (args['repos-path']) cfg.reposPath = args['repos-path'];
    const repo = resolveUserRepoPath(cfg, { githubUser: args['github-user'], explicit: args['user-repo-path'] });
    const out = { warnings: preWarnings.concat(repo.warnings), errors: [], derived: {} };
    if (repo.error) { out.errors.push(repo.error); emit(out, 2); }
    if (!repo.path) {
        out.warnings.push('no dotprofile found -- only bootstrap keys written (shared-only mode)');
        if (args['github-user']) out.derived.githubUser = args['github-user'];
        emit(out, 1);
    }
    // Values that came from an environment override are used for this run but not
    // persisted: config.json records the machine's own answer, not a test's or a caller's.
    if (repo.via !== 'env') out.derived.userRepoPath = repo.path;
    else out.warnings.push('dotprofile from AITOOLS_USER_REPO_PATH -- not saved to config.json');
    out.userRepoVia = repo.via;
    const r = readJson(path.join(repo.path, 'profile.json'));
    if (r.missing) { out.warnings.push('profile.json not found in ' + repo.path); emit(out, 1); }
    if (r.error) { out.errors.push(r.error); emit(out, 2); }
    const p = r.value;
    const gh = args['github-user'] || (p.identity && p.identity.github) || cfg.githubUser || '';
    if (gh) out.derived.githubUser = gh;
    const res = resolveMachine(p, { alias: args.alias, configAlias: cfg.machineAlias || '', environment: args.environment });
    out.warnings = out.warnings.concat(res.warnings);
    out.errors = out.errors.concat(res.errors);
    out.machineId = res.machineId;
    out.hostnames = res.hostnames;
    out.aliases = Object.keys(p.profiles || {});
    if (res.alias) {
        if (res.via === 'override' && res.overrideSource === 'env') out.warnings.push('machine alias from AITOOLS_MACHINE_ALIAS -- not saved to config.json');
        else out.derived.machineAlias = res.alias;
        out.via = res.via;  // logged by the writer, not stored (it would change run to run)
        out.company = res.profile.company;
    }
    emit(out, res.alias ? 0 : 2);
}

function cmdSnapshot(args) {
    if (!args.profile) { console.error('--profile is required'); process.exit(2); }
    const r = readJson(args.profile);
    if (r.missing) { console.error('profile.json not found: ' + args.profile); process.exit(1); }
    if (r.error) { console.error(r.error); process.exit(2); }
    const p = r.value;
    // claude.settings is excluded: setup-user-settings syncs it from the live file.
    const snap = { version: p.version, identity: p.identity || {}, cursor: p.cursor || {}, profiles: p.profiles || {} };
    process.stdout.write(JSON.stringify(snap) + '\n');
    process.exit(0);
}

function cmdRegister(args) {
    const alias = args.alias;
    if (!alias || !args.profile || !args.out) { console.error('register needs --profile, --alias and --out'); process.exit(2); }
    if (!/^[A-Za-z0-9][A-Za-z0-9_-]*$/.test(alias)) { console.error('invalid alias: ' + alias); process.exit(2); }
    let p;
    const r = readJson(args.profile);
    if (r.error) { console.error(r.error); process.exit(2); }
    if (r.missing) {
        if (!args.create) { console.error('profile.json not found (use --create): ' + args.profile); process.exit(1); }
        p = { version: 2, identity: { github: args['github-user'] || '', email: args.email || '', git: { name: args.name || '', email: args.email || '' } }, profiles: {} };
    } else {
        p = r.value;
    }
    if (p.version !== 2) { console.error('profile.json is not v2 -- migrate first'); process.exit(2); }
    if (!p.profiles || typeof p.profiles !== 'object') p.profiles = {};
    const env = resolveEnvironment(args.environment);
    const mid = env === 'claude-code-web' ? {} : machineId();
    if (mid.error) console.error('warning: ' + mid.error + ' -- profile registered without machine.id');
    if (mid.id) {
        for (const [a, prof] of Object.entries(p.profiles)) {
            if (a !== alias && prof.machine && prof.machine.id === mid.id) {
                console.error('machine.id ' + mid.id + ' is already registered on profile "' + a + '"');
                process.exit(2);
            }
        }
    }
    const state = p.profiles[alias] ? 'updated' : 'created';
    const prof = p.profiles[alias] || {};
    if (args.name !== undefined && args.name !== true && prof.name === undefined && !(p.identity && p.identity.name)) prof.name = args.name;
    if (args.company !== undefined && args.company !== true && prof.company === undefined && !(p.identity && p.identity.company)) prof.company = args.company;
    const m = prof.machine || {};
    const before = JSON.stringify(m);
    if (mid.id) m.id = mid.id;
    if (env === 'claude-code-web') m.environment = 'claude-code-web';
    if (!m.hostname) m.hostname = os.hostname();
    m.os = process.platform;
    m.arch = process.arch;
    if (args.shell && args.shell !== true) m.shell = args.shell;
    prof.machine = m;
    p.profiles[alias] = prof;
    const changed = state === 'created' || JSON.stringify(m) !== before;
    fs.writeFileSync(args.out, JSON.stringify(p, null, 2) + '\n');
    const v = JSON.parse(fs.readFileSync(args.out, 'utf8'));
    if (!v.profiles || !v.profiles[alias]) { console.error('validation failed: profile ' + alias + ' missing after write'); process.exit(2); }
    process.stdout.write(JSON.stringify({ result: changed ? state : 'unchanged', alias, machineId: mid.id || '' }) + '\n');
    process.exit(0);
}

module.exports = { resolveUserRepoPath, resolveMachine, machineId, hostnameCandidates, effectiveProfile, formatPath, readJson };

if (require.main === module) {
    const args = parseArgs(process.argv.slice(2));
    const cmd = args._[0];
    if (args.format === 'tagged') { OUTPUT_TAGGED = true; TAGGED_PATH_FORM = args['path-form'] || 'bash'; }
    if (args.help || !cmd) { process.stdout.write(HELP + '\n'); process.exit(cmd ? 0 : (args.help ? 0 : 2)); }
    const table = {
        'user-repo-path': cmdUserRepoPath, 'machine-id': cmdMachineId, resolve: cmdResolve,
        'derive-config': cmdDeriveConfig, snapshot: cmdSnapshot, register: cmdRegister
    };
    if (!table[cmd]) { console.error('unknown command: ' + cmd + ' (see --help)'); process.exit(2); }
    try { table[cmd](args); }
    catch (e) { console.error('aitools-profile: ' + cmd + ' failed: ' + e.message); process.exit(2); }
}
