'use strict';
// Real scene and worker, physically frozen scripts, disposable profile on E when configured.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXECUTABLE||process.env.CD_GODOT_EXE;
if(!godot||!fs.existsSync(godot)){console.log('SKIP godot-interface-layout : SDK Godot absent.');process.exit(0);}
const dir=fs.mkdtempSync(path.join(process.env.CD_LAYOUT_TEMP||os.tmpdir(),'cd-layout-'));
const source=path.resolve(__dirname,'../native/godot'),project=path.join(dir,'godot');fs.mkdirSync(project,{recursive:true});
for(const name of fs.readdirSync(source)){const p=path.join(source,name);if(fs.statSync(p).isFile())fs.copyFileSync(p,path.join(project,name));}
for(const name of ['ui','guide','audio','intro','steam','legal','addons'])fs.cpSync(path.join(source,name),path.join(project,name),{recursive:true});
fs.copyFileSync(path.join(__dirname,'godot-interface-layout.gd'),path.join(project,'interface-layout-test.gd'));
// The copied harness resolves its relative preload beside itself.
fs.mkdirSync(path.join(project, 'helpers'), { recursive: true });
fs.copyFileSync(path.join(__dirname, 'helpers/contextual_flow.gd'), path.join(project, 'helpers/contextual_flow.gd'));
const manifest={};for(const base of ['','ui','guide','audio','intro','steam','legal','helpers'])for(const name of fs.readdirSync(path.join(project,base))){const p=path.join(project,base,name);if(fs.statSync(p).isFile()&&/\.(gd|godot|tscn|json)$/.test(name))manifest[path.join(base,name)]=crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');}fs.writeFileSync(path.join(dir,'source-manifest.json'),JSON.stringify(manifest,null,2));
for(const name of ['art','assets','fonts','branding','shaders','.godot'])fs.symlinkSync(path.join(source,name),path.join(project,name),'junction');
fs.symlinkSync(path.resolve(source,'../engine'),path.join(dir,'engine'),'junction');
// Carrière Monde (seul mode de jeu) créée par le vrai worker avec les options du jeu (calendrier quotidien, presse
// obligatoire, carrière internationale), arrêtée le jour où la conférence de présentation attend le manager
// (rendez-vous du club) : le courrier « À faire » mène à cette conférence, comme dans la partie.
{
  const {createBridge}=require('../native/engine/worker.cjs'),{settleClubMeetings}=require('./helpers/club-meetings.cjs');
  const dataDir=fs.mkdtempSync(path.join(dir,'carriere-'));
  const bridge=createBridge({dataDir,seed:7,now:1700000000000,dailyCalendar:true,mandatoryPress:true,internationalCareer:true});
  let id=0;const call=(command,payload={})=>{const r=bridge.handle({id:++id,command,payload});assert.equal(r.ok,true,command+' : '+r.error);return r.model;};
  const pending=model=>(model.clubLife?.press?.invitations||[]).some(invitation=>invitation.status==='pending');
  let model=call('new_career',{mode:'world-champ',club:0});
  for(let day=0;day<150&&!pending(model);day++){model=settleClubMeetings(model,call);model=call('advance_day',{fromDate:model.meta.calendarToday});}
  assert.ok(pending(model)&&model.clubLife?.clubMeetings?.scene?.kind==='press'&&!model.live,'Carrière Monde : la conférence de présentation attend le manager');
  fs.writeFileSync(path.join(dir,'career.json'),call('export').meta.exportText);
  bridge.close?.();fs.rmSync(dataDir,{recursive:true,force:true});
}
// Match Monde du club en direct, arrêté à la 65e minute (Journal du match).
const live=require('./monde-harness.cjs').context().toMatch();
live.run('beginMatch();while(S.live.minute<65&&!S.live.finished){S.live.paused=false;advanceRugby(S.live)};S.live.paused=true;syncMatchPresentation(S.live)');
fs.writeFileSync(path.join(dir,'live.json'),live.run('JSON.stringify(createSaveDocument())'));live.close();
for(const name of ['Roaming','Local'])fs.mkdirSync(path.join(dir,'AppData',name),{recursive:true});
fs.mkdirSync(path.join(dir,'tmp'),{recursive:true});
const voiceBefore=Object.fromEntries(fs.readdirSync(path.join(project,'guide/assets/voice')).filter(n=>n.endsWith('.wav')).map(n=>[n,crypto.createHash('sha256').update(fs.readFileSync(path.join(project,'guide/assets/voice',n))).digest('hex')]));
fs.writeFileSync(path.join(dir,'voice-manifest.json'),JSON.stringify(voiceBefore,null,2));
const result=spawnSync(godot,[...(process.env.CD_LAYOUT_GRAPHICS==='1'?[]:['--headless']),'--audio-driver','Dummy','--max-fps','60','--log-file',path.join(dir,'runtime.log'),'--path',project,'--script',path.join(project,'interface-layout-test.gd')],{env:{...process.env,APPDATA:path.join(dir,'AppData/Roaming'),LOCALAPPDATA:path.join(dir,'AppData/Local'),TEMP:path.join(dir,'tmp'),TMP:path.join(dir,'tmp'),CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(dir,'PrototypeGodot'),CD_LAYOUT_ARTIFACTS:dir},windowsHide:true,encoding:'utf8',timeout:180000});
const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(dir,'godot.log'),output);console.log(output);console.log('Preuves interface : '+dir);if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
for(const [file,hash] of Object.entries(manifest))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(project,file))).digest('hex'),hash,'Copie figée inchangée : '+file);
for(const [file,hash] of Object.entries(voiceBefore))assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(project,'guide/assets/voice',file))).digest('hex'),hash,'Audio inchangé : '+file);

