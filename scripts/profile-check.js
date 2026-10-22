#!/usr/bin/env node
// profile-check.js -- Validate profile.json and detect v1 profiles needing migration
//
// Usage: node scripts/profile-check.js [--config PATH]
//
// Reads config.json to find the user repo, then validates profile.json.
// Outputs a JSON result to stdout. Callers (aitools, aitools.ps1) handle
// interactive prompts and writes based on the result.
//
// Exit codes: 0 always (callers parse JSON output, not exit codes).

'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

// --- Parse args ---
let configPath = path.join(os.homedir(), '.aitools', 'config.json');
const args = process.argv.slice(2);
for (let i = 0; i < args.length; i++) {
    if (args[i] === '--config' && args[i + 1]) {
        configPath = args[++i];
    }
}

// --- Helpers ---
function output(result) {
    process.stdout.write(JSON.stringify(result) + '\n');
}

function readJson(filePath) {
    try {
        // Strip UTF-8 BOM (PowerShell 5.x writes one)
        let raw = fs.readFileSync(filePath, 'utf8');
        raw = raw.replace(/^\uFEFF/, '');
        return JSON.parse(raw);
    } catch (e) {
        if (e.code === 'ENOENT') return null;
        return { _parseError: e.message };
    }
}

// --- Read config.json ---
const config = readJson(configPath);
if (!config) {
    output({ status: 'unconfigured', issues: [], message: 'No config.json found' });
    process.exit(0);
}
if (config._parseError) {
    output({ status: 'error', issues: [{ code: 'CONFIG_CORRUPT', message: 'config.json is invalid JSON: ' + config._parseError }] });
    process.exit(0);
}

const userRepoPath = config.userRepoPath;
if (!userRepoPath) {
    output({ status: 'unconfigured', issues: [], message: 'userRepoPath not set in config.json' });
    process.exit(0);
}

// --- Read profile.json ---
const profilePath = path.join(userRepoPath, 'profile.json');
const profile = readJson(profilePath);
if (!profile) {
    output({
        status: 'error',
        profilePath: profilePath,
        issues: [{ code: 'PROFILE_MISSING', message: 'profile.json not found at ' + profilePath, fix: 'run aitools user init' }]
    });
    process.exit(0);
}
if (profile._parseError) {
    output({
        status: 'error',
        profilePath: profilePath,
        issues: [{ code: 'PROFILE_CORRUPT', message: 'profile.json is invalid JSON: ' + profile._parseError, fix: 'manual' }]
    });
    process.exit(0);
}

// --- v1 detection ---
if (profile.version !== 2) {
    // Extract migration data from v1 flat fields
    const migrationData = {
        name: (profile.git && profile.git.name) || profile.name || '',
        email: (profile.git && profile.git.email) || profile.email || '',
        github: profile.github || '',
        company: profile.company || '',
        machines: Array.isArray(profile.machines) ? profile.machines : []
    };
    // Preserve non-v1 sections (e.g., cursor)
    const preserve = {};
    const v1Keys = ['name', 'email', 'github', 'company', 'git', 'machines', 'version'];
    for (const key of Object.keys(profile)) {
        if (!v1Keys.includes(key)) {
            preserve[key] = profile[key];
        }
    }
    if (Object.keys(preserve).length > 0) {
        migrationData.preserve = preserve;
    }

    output({
        status: 'migrate',
        version: profile.version || 1,
        profilePath: profilePath,
        issues: [{ code: 'V1_PROFILE', message: 'profile.json is v1 (legacy). Migration to v2 recommended.', fix: 'migrate' }],
        migrationData: migrationData
    });
    process.exit(0);
}

// --- v2 validation ---
const issues = [];
// config.json caches this machine's profile key (machineId: the raw machine id,
// lower-cased -- profiles are keyed by it, re-key design (e)); machineAlias is a
// display value, and the cache of a revision 2.1 (alias-keyed) profile.
const machineId = config.machineId || '';
const machineAlias = config.machineAlias || '';
// Machine matching is the native resolver's job (scripts/aitools-profile.sh /
// .ps1; reported by setup-user-config on every run). os.hostname() is the
// DNS/DHCP-derived kernel name and is never used (P-Q5). Here only the cached
// key is checked: profiles[machineId] (keys ignore case), or a 2.1 profile keyed
// by alias whose machine.id is machineId (legacy read).
if (machineId && profile.profiles && typeof profile.profiles === 'object') {
    const idl = String(machineId).toLowerCase();
    const known = Object.keys(profile.profiles).some(k => {
        const p = profile.profiles[k];
        const mid = (p && p.machine && p.machine.id) ? String(p.machine.id).toLowerCase() : '';
        return k.toLowerCase() === idl || mid === idl;
    });
    if (!known) {
        issues.push({ code: 'MACHINE_ID_UNKNOWN', message: 'config.json machineId ' + machineId + ' is not a profile in profile.json', field: 'machineId', fix: 'run aitools user init' });
    }
}

// Identity checks
if (!profile.identity) {
    issues.push({ code: 'MISSING_IDENTITY', message: 'identity section is missing', fix: 'prompt' });
} else {
    if (!profile.identity.github) {
        issues.push({ code: 'MISSING_FIELD', message: 'identity.github is missing', field: 'identity.github', fix: 'prompt' });
    }
    if (!profile.identity.email) {
        issues.push({ code: 'MISSING_FIELD', message: 'identity.email is missing', field: 'identity.email', fix: 'prompt' });
    }
    if (!profile.identity.git || !profile.identity.git.name) {
        issues.push({ code: 'MISSING_FIELD', message: 'identity.git.name is missing', field: 'identity.git.name', fix: 'prompt' });
    }
    if (!profile.identity.git || !profile.identity.git.email) {
        issues.push({ code: 'MISSING_FIELD', message: 'identity.git.email is missing', field: 'identity.git.email', fix: 'prompt' });
    }
}

// Profiles checks
if (!profile.profiles || Object.keys(profile.profiles).length === 0) {
    issues.push({ code: 'NO_PROFILES', message: 'No machine profiles defined', fix: 'prompt' });
}

// Build result
const status = issues.length === 0 ? 'ok' : 'warn';

output({
    status: status,
    version: 2,
    profilePath: profilePath,
    machineId: machineId,
    machineAlias: machineAlias,
    issues: issues
});
