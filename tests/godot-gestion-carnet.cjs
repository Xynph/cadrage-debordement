'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {spawn} = require('node:child_process');
const {test} = require('node:test');
const CHILD_TIMEOUT_MS = 150000;
const OUTPUT_LIMIT_BYTES = 32 * 1024 * 1024;

test('Gestion carnet : saisie clavier, continuité et comparaison sans mutation', {
  skip: !process.env.CD_GODOT_EXECUTABLE && 'SDK Godot requis',
}, async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-gestion-carnet-'));
  const trace = path.join(root, 'progress.jsonl');
  const log = path.join(root, 'godot.log');
  console.log('GESTION_WRAPPER ' + JSON.stringify({phase:'prepare', root, trace, child_timeout_ms:CHILD_TIMEOUT_MS}));
  fs.writeFileSync(path.join(root, 'archive-fixture.json'), require('node:zlib').gunzipSync(fs.readFileSync(path.join(__dirname, 'fixtures/roster-foundation-v1-s2.json.gz'))));
  fs.writeFileSync(log, '');
  const started = Date.now();
  const result = await new Promise(resolve => {
    const child = spawn(process.env.CD_GODOT_EXECUTABLE, [
      ...(process.env.CD_GESTION_GRAPHICS === '1' ? [] : ['--headless']),
      '--audio-driver', 'Dummy', '--max-fps', '120', '--log-file', path.join(root, 'godot-engine.log'),
      '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-gestion-carnet.gd'),
    ], {
      env: {...process.env, CD_NODE_EXECUTABLE:process.execPath, CD_GODOT_SELF_TEST:'0', CD_GODOT_DATA_DIR:root,
        CD_ARCHIVE_FIXTURE:path.join(root, 'archive-fixture.json'), CD_GESTION_PROGRESS:trace,
        CD_GESTION_CAPTURES:process.env.CD_GESTION_CAPTURES || root},
      windowsHide:true, stdio:['ignore', 'pipe', 'pipe'],
    });
    let output = '';
    let bytes = 0;
    let error = null;
    let timedOut = false;
    let outputLimit = false;
    const timer = setTimeout(() => {
      timedOut = true;
      console.error('GESTION_WRAPPER ' + JSON.stringify({phase:'child-timeout', milliseconds:Date.now()-started, root, trace}));
      child.kill('SIGKILL');
    }, CHILD_TIMEOUT_MS);
    const collect = (stream, chunk) => {
      bytes += chunk.length;
      if (bytes > OUTPUT_LIMIT_BYTES) { outputLimit = true; child.kill('SIGKILL'); return; }
      output += chunk.toString('utf8');
      fs.appendFileSync(log, chunk);
      stream.write(chunk);
    };
    child.stdout.on('data', chunk => collect(process.stdout, chunk));
    child.stderr.on('data', chunk => collect(process.stderr, chunk));
    child.on('error', value => { error = value; });
    child.on('close', (status, signal) => {
      clearTimeout(timer);
      resolve({status, signal, error, timedOut, outputLimit, output});
    });
  });
  const receipt = {status:result.status, signal:result.signal, timed_out:result.timedOut,
    output_limit:result.outputLimit, milliseconds:Date.now()-started, child_timeout_ms:CHILD_TIMEOUT_MS,
    error:result.error?.message || null, trace};
  fs.writeFileSync(path.join(root, 'wrapper.json'), JSON.stringify(receipt, null, 2) + '\n');
  console.log('GESTION_WRAPPER ' + JSON.stringify({phase:'child-close', ...receipt}));
  console.log('Preuves gestion : ' + root);
  if (result.error) throw result.error;
  assert.equal(result.timedOut, false, 'Délai enfant 150 s atteint ; consulter la trace progressive ' + trace);
  assert.equal(result.outputLimit, false, 'Sortie enfant supérieure à 32 Mio');
  assert.equal(result.status, 0, result.output);
  assert.doesNotMatch(result.output, /SCRIPT ERROR|Parse Error|ERROR:/);
});
