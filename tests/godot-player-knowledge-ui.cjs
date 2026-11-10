'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const knowledgeWorker=process.env.CD_KNOWLEDGE_WORKER||path.resolve(__dirname,'../native/engine/worker.cjs');
const hasKnowledge=!!process.env.CD_KNOWLEDGE_WORKER||fs.existsSync(path.resolve(__dirname,'../native/engine/player-knowledge.cjs'));
test('UI connaissance : vrai modèle, potentiel en intervalle, observation confirmée et aucune écriture en consultation',{skip:!process.env.CD_GODOT_EXECUTABLE||!hasKnowledge?'SDK et worker knowledge requis':false},()=>{
 const output=process.env.CD_KNOWLEDGE_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'oval-knowledge-ui-'));fs.mkdirSync(output,{recursive:true});
 const graphics=process.env.CD_KNOWLEDGE_GRAPHICS==='1';
 const result=spawnSync(process.env.CD_GODOT_EXECUTABLE,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed','--resolution','2560x1440']:['--headless']),'--audio-driver','Dummy','--max-fps','120','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-player-knowledge-ui.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:180000,env:{...process.env,CD_KNOWLEDGE_WORKER:knowledgeWorker,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_GODOT_DATA_DIR:fs.mkdtempSync(path.join(os.tmpdir(),'oval-knowledge-profile-')),CD_KNOWLEDGE_OUTPUT:output}});
 const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log.trim());console.log('Preuves connaissance : '+output);
 if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output,'report.json'),'utf8')).failures,[]);
});
