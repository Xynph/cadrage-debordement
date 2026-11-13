'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
test('Toutes les colonnes : tri, molette interne, identifiants et lecture pure',{
  skip:!process.env.CD_GODOT_EXECUTABLE&&'SDK Godot requis',
},()=>{
  const output=fs.mkdtempSync(path.join(os.tmpdir(),'oval-player-tables-'));
  const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--audio-driver','Dummy','--max-fps','120','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-player-table-order.gd')],{
    cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:180000,
    env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(output,'profile'),CD_GODOT_GUIDE_MODULE_TEST:'1',CD_GODOT_SELF_TEST:'0',CD_PLAYER_TABLE_OUTPUT:output},
  });
  const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log.trim());console.log('Preuves tris : '+output);
  if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output,'report.json'),'utf8')).failures,[]);
});
