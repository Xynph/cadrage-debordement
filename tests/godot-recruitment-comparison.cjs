'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE;
test('Comparaison recrutement : deux candidats, recherche, écarts, clavier et lecture sans mutation',{skip:!godot&&'SDK Godot requis'},()=>{
 const output=process.env.CD_COMPARISON_OUTPUT||fs.mkdtempSync(path.join(os.tmpdir(),'oval-comparison-'));
 fs.mkdirSync(output,{recursive:true});
 const graphics=process.env.CD_COMPARISON_GRAPHICS==='1';
 if(process.env.QA_RESOLUTION)assert.match(process.env.QA_RESOLUTION,/^(1920x1080|2560x1440)$/);
 const result=spawnSync(godot,[...(graphics?['--display-driver','x11','--rendering-method','gl_compatibility','--windowed']:['--headless']),'--audio-driver','Dummy','--max-fps','60','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-recruitment-comparison.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:120000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:fs.mkdtempSync(path.join(os.tmpdir(),'oval-comparison-profile-')),CD_COMPARISON_OUTPUT:output}});
 const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log);console.log('Preuves comparaison : '+output);if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);assert.deepEqual(JSON.parse(fs.readFileSync(path.join(output,'report.json'),'utf8')).failures,[]);
});
