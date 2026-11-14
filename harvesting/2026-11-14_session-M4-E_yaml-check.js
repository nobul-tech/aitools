// Parse check.yml with the js-yaml bundled in the vercel CLI (read-only use) and print the
// steps of the pywinpty-related changes.
const yaml = require('C:/Users/jdpal/AppData/Roaming/npm/node_modules/vercel/node_modules/js-yaml');
const fs = require('fs');
const f = process.argv[2];
const d = yaml.load(fs.readFileSync(f, 'utf8'));
for (const [job, v] of Object.entries(d.jobs)) {
  console.log(`${job}: ${v.steps.length} steps`);
  for (const s of v.steps) {
    if (/pywinpty/i.test(s.name || '')) {
      console.log(`  - ${s.name} | shell=${s.shell || '(default)'} | if=${s.if || ''}`);
      console.log('    run: ' + String(s.run).split('\n').join('\n         '));
    }
  }
}
