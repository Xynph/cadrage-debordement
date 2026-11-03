'use strict';
// Retour rapide de developpement, jamais une preuve de CI de fusion.
const fs = require('node:fs');
const {spawnSync} = require('node:child_process');
const {selectTests, allTests} = require('./select-tests.cjs');
function plan(files) {
  const suites = selectTests(files);
  return {suites, full: suites.length === allTests.length, total: allTests.length};
}
function execute(files, runner = spawnSync) {
  const result = plan(files);
  console.log('Tests rapides : '+result.suites.length+'/'+result.total+(result.full?' (couverture totale par prudence)':''));
  if (!result.suites.length) return 0; // changements purement documentaires
  let failed = 0;
  for (const suite of result.suites) {
    const started = Date.now();
    const child = runner(process.execPath,[suite],{stdio:'inherit',timeout:180000});
    const ok = !child.error && child.status===0;
    console.log((ok?'PASS ':'FAIL ')+suite+' '+((Date.now()-started)/1000).toFixed(1)+'s');
    if (!ok) failed++;
  }
  return failed ? 1 : 0;
}
if (require.main===module) {
  const input = process.argv[2];
  if (!input || !fs.existsSync(input)) {
    console.error('Usage: node ci/quick-check.cjs <fichier-liste-chemins-modifies>');
    process.exit(2);
  }
  process.exitCode=execute(fs.readFileSync(input,'utf8').split(/\r?\n/).filter(Boolean));
}
module.exports={plan,execute};
