'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const realWorker=process.env.CD_KNOWLEDGE_WORKER||path.resolve(__dirname,'../native/engine/worker.cjs');
const hasKnowledge=!!process.env.CD_KNOWLEDGE_WORKER||fs.existsSync(path.resolve(__dirname,'../native/engine/player-knowledge.cjs'));
test('Un refus d’export termine le banc proprement sans accéder à un export absent',{skip:!process.env.CD_GODOT_EXECUTABLE||!hasKnowledge?'SDK et worker knowledge requis':false},()=>{
 const output=fs.mkdtempSync(path.join(os.tmpdir(),'oval-knowledge-export-refusal-'));
 const wrapper=path.join(output,'refusing-worker.cjs');
 // Même vrai moteur ; seule la réponse export est volontairement refusée.
 fs.writeFileSync(wrapper,`'use strict';
const {createBridge}=require(${JSON.stringify(realWorker)}),readline=require('node:readline');
const bridge=createBridge({dailyCalendar:true,mandatoryPress:true,internationalCareer:true,dataDir:process.argv[process.argv.indexOf('--data-dir')+1]});
const input=readline.createInterface({input:process.stdin,crlfDelay:Infinity});
input.on('line',line=>{const request=JSON.parse(line);const reply=request.command==='export'?{id:request.id,ok:false,model:null,error:'QA_EXPORT_REFUSED'}:bridge.handle(request);process.stdout.write(JSON.stringify(reply)+'\\n');if(request.command==='shutdown'){input.close();process.stdin.destroy();}});
input.on('close',()=>bridge.close());process.on('exit',()=>bridge.close());
`);
 const started=performance.now();
 const run=spawnSync(process.env.CD_GODOT_EXECUTABLE,['--headless','--audio-driver','Dummy','--max-fps','120','--path','native/godot','--log-file',path.join(output,'engine.log'),'--script',path.resolve(__dirname,'godot-player-knowledge-ui.gd')],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:45000,env:{...process.env,CD_KNOWLEDGE_WORKER:wrapper,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_GODOT_DATA_DIR:fs.mkdtempSync(path.join(os.tmpdir(),'oval-export-refusal-profile-')),CD_KNOWLEDGE_OUTPUT:output}});
 const log=(run.stdout||'')+(run.stderr||'');fs.writeFileSync(path.join(output,'godot.log'),log);console.log(log.trim());console.log('Preuve refus export : '+output+' · '+Math.round(performance.now()-started)+' ms');
 if(run.error)throw run.error;assert.equal(run.status,1,log);assert.match(log,/QA_EXPORT_REFUSED/);assert.doesNotMatch(log,/SCRIPT ERROR|Invalid access|Parse Error/);
 const report=JSON.parse(fs.readFileSync(path.join(output,'report.json'),'utf8'));assert.equal(report.failed_command,'export');assert.ok(report.failures.length>0);assert.ok(report.command_timings.some(x=>x.command==='export'&&!x.ok));
});
