'use strict';
// Reprise avant le match : confirmation de « Quitter » pendant un match (menu, fermeture de la fenêtre), absente hors
// match. Godot réel (tests/godot-quitter-pendant-match.gd).
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE;
test('Quitter pendant un match : confirmation claire, aucune hors match',{skip:!godot&&'SDK Godot requis'},()=>{
 const output=fs.mkdtempSync(path.join(os.tmpdir(),'rl27-quitter-match-'));
 const profile=fs.mkdtempSync(path.join(os.tmpdir(),'rl27-quitter-match-profil-'));
 try{
  const result=spawnSync(godot,['--headless','--audio-driver','Dummy','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-quitter-pendant-match.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:300000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:profile,CD_QUITTER_MATCH_OUTPUT:output}});
  const log=(result.stdout||'')+(result.stderr||'');console.log(log);
  if(result.error)throw result.error;
  assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error/);
  const report=JSON.parse(fs.readFileSync(path.join(output,'report.json'),'utf8'));
  assert.deepEqual(report.failures,[]);assert.ok(report.checks>=10,'contrôles exécutés : '+report.checks);
 }finally{fs.rmSync(output,{recursive:true,force:true});fs.rmSync(profile,{recursive:true,force:true});}
});
