'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const directory = path.resolve(__dirname, '../.github/workflows');
const files = fs.readdirSync(directory).filter(f => /\.ya?ml$/.test(f));
let jobs = 0;
for (const file of files) {
  const text = fs.readFileSync(path.join(directory, file), 'utf8');
  const body = text.split(/^jobs:\s*$/m)[1];
  assert.ok(body, file + ': jobs requis');
  for (const block of body.split(/^  [\w-]+:\s*$/m).slice(1)) {
    jobs++;
    assert.match(block, /^    runs-on: \[self-hosted, (Linux, X64, rl27-(?:linux|control)|Windows, X64, rl27-windows)\]$/m, file);
    assert.match(block, /^    if: \$\{\{ github\.event\.repository\.private && \(github\.event_name != 'pull_request' \|\| github\.event\.pull_request\.head\.repo\.full_name == github\.repository\)/m, file);
  }
  assert.doesNotMatch(text, /^\s*runs-on:.*(?:ubuntu-|windows-|macos-|fromJSON)/m, file + ': aucun repli hébergé');
}
assert.equal(jobs, 77);
console.log(`PC-only: ${files.length} workflows, ${jobs} jobs personnels, gardes privé/forks vérifiées`);
