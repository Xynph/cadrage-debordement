'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
test('Négociation UI et vrai worker: contre-offre, refus préservé, transaction confirmée',{skip:!godot&&'SDK Godot requis'},()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-deep-market-ui-')),app=path.join(root,'app'),project=path.join(app,'native/godot'),source=path.resolve(__dirname,'../native/godot'),engine=path.join(app,'native/engine');
 a(fs.existsSync(path.join(source,'assets/clubs.json')),'staging --stage-only requis');
 fs.mkdirSync(project,{recursive:true});
 for(const entry of fs.readdirSync(source,{withFileTypes:true})){if(entry.name==='.godot')continue;const from=path.join(source,entry.name),to=path.join(project,entry.name);if(entry.isFile())fs.copyFileSync(from,to);else if(['ui','guide','audio'].includes(entry.name))fs.cpSync(from,to,{recursive:true});else fs.symlinkSync(from,to,'junction');}
 fs.cpSync(path.resolve(source,'../engine'),engine,{recursive:true});fs.symlinkSync(path.resolve(source,'../../dist'),path.join(app,'dist'),'junction');
 if(process.env.CD_DEEP_MARKET_WORKER)fs.copyFileSync(process.env.CD_DEEP_MARKET_WORKER,path.join(engine,'worker.cjs'));
 if(process.env.CD_DEEP_MARKET_MAIN)fs.copyFileSync(process.env.CD_DEEP_MARKET_MAIN,path.join(project,'main.gd'));
 fs.copyFileSync(path.join(__dirname,'deepen-market-ui.gd'),path.join(project,'deepen-market-test.gd'));
 const env={...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_DATA_DIR:path.join(root,'profile'),CD_DEEP_MARKET_ARTIFACTS:root,XDG_DATA_HOME:path.join(root,'xdg/data'),XDG_CONFIG_HOME:path.join(root,'xdg/config'),XDG_CACHE_HOME:path.join(root,'xdg/cache')};for(const key of ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME'])fs.mkdirSync(env[key],{recursive:true});
 const imported=spawnSync(godot,['--headless','--editor','--path',project,'--import'],{env,encoding:'utf8',timeout:90000});fs.writeFileSync(path.join(root,'import.log'),(imported.stdout||'')+(imported.stderr||''));a.equal(imported.status,0,imported.error?.message);
 const result=spawnSync(godot,['--headless','--audio-driver','Dummy','--max-fps','120','--path',project,'--script',path.join(project,'deepen-market-test.gd')],{env,encoding:'utf8',timeout:90000}),output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(root,'runtime.log'),output);console.log(output.trim());console.log('Preuves marché : '+root);a.equal(result.status,0,result.error?.message||output);a.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:|instances were leaked/);const report=JSON.parse(fs.readFileSync(path.join(root,'report.json'),'utf8'));a.deepEqual(report.failures,[]);a(report.checks>=20);
});
