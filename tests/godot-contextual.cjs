'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
const repository = path.resolve(__dirname,'..');

for (const [name,script] of [
  ['rooms','godot-contextual-rooms.gd'],
  ['ui','godot-contextual-ui.gd'],
  ['match-club-branding','godot-match-club-branding.gd'],
  ['shutdown','helpers/contextualqa-shutdown.gd'],
  ['flow','godot-contextual-flow.gd']
]) test('Native contextual '+name+': real Godot '+(name==='flow'?'career and match integration':'rendering contract'), {
  skip:!godot && 'SDK Godot requis (CD_GODOT_EXECUTABLE)',
  timeout:300000
}, () => {
  // No test can fall back to the user's default career or Godot preferences.
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(),'cd-contextual-'+name+'-'));
  const artifacts = process.env.CD_CONTEXTUAL_ARTIFACTS
    ? path.resolve(process.env.CD_CONTEXTUAL_ARTIFACTS,name)
    : path.join(temporary,'artifacts');
  fs.mkdirSync(artifacts,{recursive:true});
  const graphics = process.env.CD_CONTEXTUAL_GRAPHICS === '1';
  const result = spawnSync(godot,[...(graphics?[]:['--headless']),
    '--audio-driver','Dummy','--max-fps','120','--log-file',path.join(artifacts,'runtime.log'),
    '--path',path.join(repository,'native/godot'),'--script',path.join(__dirname,script)],{
    cwd:repository,
    env:{...process.env,
      XDG_DATA_HOME:path.join(temporary,'data'),XDG_CONFIG_HOME:path.join(temporary,'config'),XDG_CACHE_HOME:path.join(temporary,'cache'),
      APPDATA:path.join(temporary,'appdata'),LOCALAPPDATA:path.join(temporary,'localappdata'),TEMP:path.join(temporary,'tmp'),TMP:path.join(temporary,'tmp'),
      CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_SEED:'13',
      CD_GODOT_DATA_DIR:path.join(temporary,'profile'),CD_CONTEXTUAL_ARTIFACTS:artifacts,
      // Direct d'origine : le parcours « flow » avance le match par pas du direct et attend la causerie
      // dès la fin de la période. Le parcours en temps forts est couvert par tests/godot-match-temps-forts.
      ...(name==='flow'?{CD_MATCH_TEMPS_FORTS:'0'}:{})},
    encoding:'utf8',windowsHide:true,timeout:285000,maxBuffer:16*1024*1024
  });
  const output = (result.stdout||'')+(result.stderr||'');
  fs.writeFileSync(path.join(artifacts,'godot.log'),output);
  console.log(output.trim());console.log('Contextual '+name+' artifacts: '+artifacts);
  if(result.error)throw result.error;
  assert.equal(result.status,0,output);
  assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/,'Godot must complete without engine/script errors');
  if(name==='flow'){
    const report=JSON.parse(fs.readFileSync(path.join(artifacts,'report.json'),'utf8'));
    assert.deepEqual(report.failures,[]);assert.ok(report.checks>=600);
    assert.equal(report.real_worker,true);
  }
});
