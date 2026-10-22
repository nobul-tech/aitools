// review_json_fields / Review-JsonFields: SOURCE against LOCAL, field by field.
// The same text is embedded in aitools-lib.sh and aitools-lib.ps1: keep them identical.
//   plan  SRC LOCAL OUT_PLAN
//     OUT_PLAN: one line per differing field: idx<TAB>kind<TAB>key<TAB>local<TAB>source
//     kind: differ | source-only | local-only. A whole array is one field.
//   apply SRC LOCAL ADOPT CHOICES OUT_LOCAL OUT_ADOPT OUT_RESULT OUT_REQ_LOCAL OUT_REQ_ADOPT
//     ADOPT: the adopt target, or "-" for none.
//     CHOICES: idx<TAB>overwrite|adopt|skip|keep per field (missing = skip).
//     OUT_LOCAL / OUT_ADOPT: new file content, or empty when that file is unchanged.
//     OUT_RESULT: "over=N adopt=N skip=N kept=N".
//     OUT_REQ_LOCAL / OUT_REQ_ADOPT: JSON array of SOURCE's top-level keys the
//     written file must keep (keys the review chose to leave absent excluded).
//   keys  SRC OUT_KEYS
//     OUT_KEYS: JSON array of SOURCE's top-level keys ([] when not an object).
// Key order is preserved: existing keys keep their position, new keys are appended.
// Exit 3 with the reason on stderr when a file cannot be read or parsed.
const fs = require('fs');
const mode = process.argv[2];
function readJson(p, label) {
    let text;
    try { text = fs.readFileSync(p, 'utf8'); }
    catch (e) {
        if (e.code === 'ENOENT') return undefined;
        throw new Error(label + ': cannot read ' + p + ': ' + e.message);
    }
    if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
    try { return JSON.parse(text); }
    catch (e) { throw new Error(label + ': ' + p + ' is not valid JSON: ' + e.message); }
}
function isObj(v) { return v !== null && typeof v === 'object' && !Array.isArray(v); }
function has(o, k) { return Object.prototype.hasOwnProperty.call(o, k); }
function canon(v) {
    if (Array.isArray(v)) return '[' + v.map(canon).join(',') + ']';
    if (isObj(v)) return '{' + Object.keys(v).sort().map(k => JSON.stringify(k) + ':' + canon(v[k])).join(',') + '}';
    return JSON.stringify(v);
}
function fields(src, loc) {
    const out = [];
    if (!isObj(src) || !isObj(loc)) {
        if (canon(src) !== canon(loc)) out.push({ path: [], kind: 'differ', s: src, l: loc });
        return out;
    }
    (function walk(s, l, path) {
        const keys = Object.keys(s).concat(Object.keys(l).filter(k => !has(s, k)));
        for (const k of keys) {
            const p = path.concat([k]);
            const inS = has(s, k), inL = has(l, k);
            if (inS && inL) {
                if (isObj(s[k]) && isObj(l[k])) walk(s[k], l[k], p);
                else if (canon(s[k]) !== canon(l[k])) out.push({ path: p, kind: 'differ', s: s[k], l: l[k] });
            } else if (inS) {
                out.push({ path: p, kind: 'source-only', s: s[k] });
            } else {
                out.push({ path: p, kind: 'local-only', l: l[k] });
            }
        }
    })(src, loc, []);
    return out;
}
function disp(v) {
    if (v === undefined) return '(absent)';
    let t = JSON.stringify(v);
    if (t.length > 200) t = t.slice(0, 197) + '...';
    return t;
}
function clean(t) { return String(t).replace(/[\t\r\n]/g, ' '); }
function clone(v) { return v === undefined ? undefined : JSON.parse(JSON.stringify(v)); }
function setPath(obj, path, val) {
    let o = obj;
    for (let i = 0; i < path.length - 1; i++) {
        if (!isObj(o[path[i]])) o[path[i]] = {};
        o = o[path[i]];
    }
    o[path[path.length - 1]] = val;
}
function delPath(obj, path) {
    let o = obj;
    for (let i = 0; i < path.length - 1; i++) {
        if (!isObj(o[path[i]])) return;
        o = o[path[i]];
    }
    delete o[path[path.length - 1]];
}
function keptKeys(src, obj) {
    if (!isObj(src) || !isObj(obj)) return [];
    return Object.keys(src).filter(k => has(obj, k));
}
try {
    const src = readJson(process.argv[3], 'source');
    if (src === undefined) throw new Error('source: ' + process.argv[3] + ' not found');
    if (mode === 'keys') {
        fs.writeFileSync(process.argv[4], JSON.stringify(isObj(src) ? Object.keys(src) : []) + '\n');
        process.exit(0);
    }
    const loc = readJson(process.argv[4], 'local');
    if (loc === undefined) throw new Error('local: ' + process.argv[4] + ' not found');
    const list = fields(src, loc);
    if (mode === 'plan') {
        const lines = list.map((f, i) => [i, f.kind, f.path.length ? clean(f.path.join('.')) : '(document)',
            clean(disp(f.l)), clean(disp(f.s))].join('\t'));
        fs.writeFileSync(process.argv[5], lines.length ? lines.join('\n') + '\n' : '');
    } else if (mode === 'apply') {
        const adoptPath = (process.argv[5] && process.argv[5] !== '-') ? process.argv[5] : '';
        const choices = {};
        for (const line of fs.readFileSync(process.argv[6], 'utf8').split(/\r?\n/)) {
            const m = /^(\d+)\t(\w+)$/.exec(line);
            if (m) choices[m[1]] = m[2];
        }
        let newLocal = clone(loc);
        let adoptObj;
        if (adoptPath) {
            adoptObj = readJson(adoptPath, 'adopt target');
            if (adoptObj === undefined) adoptObj = clone(src);
        }
        let over = 0, adopt = 0, skip = 0, kept = 0;
        list.forEach((f, i) => {
            const c = choices[String(i)] || 'skip';
            if (c === 'adopt' && adoptPath) {
                adopt++;
                if (f.path.length === 0) adoptObj = clone(f.l);
                else if (f.kind === 'source-only') delPath(adoptObj, f.path);
                else setPath(adoptObj, f.path, clone(f.l));
            } else if (c === 'overwrite' && f.kind !== 'local-only') {
                over++;
                if (f.path.length === 0) newLocal = clone(f.s);
                else setPath(newLocal, f.path, clone(f.s));
            } else if (f.kind === 'local-only' && c !== 'skip') {
                kept++;
            } else {
                skip++;
            }
        });
        fs.writeFileSync(process.argv[7], over ? JSON.stringify(newLocal, null, 2) + '\n' : '');
        fs.writeFileSync(process.argv[8], adopt ? JSON.stringify(adoptObj, null, 2) + '\n' : '');
        fs.writeFileSync(process.argv[9], 'over=' + over + ' adopt=' + adopt + ' skip=' + skip + ' kept=' + kept + '\n');
        fs.writeFileSync(process.argv[10], JSON.stringify(keptKeys(src, newLocal)) + '\n');
        fs.writeFileSync(process.argv[11], JSON.stringify(adoptPath ? keptKeys(src, adoptObj) : []) + '\n');
    } else {
        throw new Error('unknown mode: ' + mode);
    }
} catch (e) {
    process.stderr.write(String((e && e.message) || e) + '\n');
    process.exit(3);
}
