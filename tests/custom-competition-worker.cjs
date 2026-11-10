'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const worker=process.env.CD_CUSTOM_WORKER||path.resolve(__dirname,'../native/engine/worker.cjs');
const {createBridge}=require(worker),editor=require('../native/engine/competition-editor.cjs');
function fixture(t){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-custom-competition-'));
 let bridge=createBridge({dataDir:dir,seed:827381,now:1794178800000}),serial=0;
 t.after(()=>{bridge.close();fs.rmSync(dir,{recursive:true,force:true});});
 const send=(command,payload={})=>bridge.handle({id:++serial,command,payload});
 const good=(command,payload)=>{const r=send(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 return {send,good,bytes:()=>fs.readFileSync(path.join(dir,'PrototypeGodot','donnees.json')),restart:()=>{bridge.close();bridge=createBridge({dataDir:dir,seed:1,now:10});}};
}
function document(){const d=editor.generate({name:'Ligue des vallées',clubs:Array.from({length:14},(_,i)=>'Club des vallées '+(i+1)),doubleRound:true});d.fixtures.forEach(f=>{if(f.round===1)f.round=2;else if(f.round===2)f.round=1;});return d;}
const payload=()=>({mode:'custom',club:3,confirmed:true,document:document()});
test('Le lancement explicite conserve un calendrier modifié et des identités contrôlées sur disque',t=>{
 const f=fixture(t),p=payload(),m=f.good('new_career',p);
 assert.equal(m.leagues[0].name,p.document.name);assert.match(m.leagues[0].notice,/fictive/);assert.equal(m.club.name,'Club des vallées 4');assert.equal(m.club.abbr,'C04');assert.equal(m.club.presentation.name,m.club.name,'présentation UI personnalisée');
 const doc=JSON.parse(f.good('export').meta.exportText);assert.equal(doc.state.customCompetition.name,p.document.name);
 const expected=p.document.fixtures.filter(x=>x.round===1).map(x=>[Number(x.homeId.slice(5))-1,Number(x.awayId.slice(5))-1]);assert.deepEqual(doc.state.schedule[0],expected);
 const before=f.good('export').meta.exportText,bytes=f.bytes();
 f.restart();assert.equal(f.good('export').meta.exportText,before);assert.deepEqual(f.bytes(),bytes);
 f.good('import',{text:before});assert.equal(f.good('export').meta.exportText,before);
});
test('Formats non jouables, caractères et import forgé sont refusés sans modifier ancienne carrière',t=>{
 const f=fixture(t);f.good('new_career',{mode:'fiction',club:0});const before=f.good('export').meta.exportText,bytes=f.bytes();
 for(const bad of [{...payload(),confirmed:false},{...payload(),club:14},{...payload(),document:editor.generate({name:'Deux clubs',clubs:['A','B'],doubleRound:true})},{...payload(),document:{...document(),name:'<dangereux>'}}]){assert.equal(f.send('new_career',bad).ok,false);assert.equal(f.good('export').meta.exportText,before);assert.deepEqual(f.bytes(),bytes);}
 f.restart();assert.equal(f.good('export').meta.exportText,before,'ancienne carrière reprend sans marqueur');
 f.good('new_career',payload());const custom=f.good('export').meta.exportText;
 for(const mutate of [s=>s.clubs[0].name='Autre',s=>s.customCompetition.clubs[0].abbr='A',s=>s.customCompetition.schedule[0][0].reverse(),s=>s.customCompetition.extra=true,s=>s.customCompetition.version=2,s=>s.customCompetition.clubs[1].name=s.customCompetition.clubs[0].name,s=>s.commonDatabase={id:'fake',version:1}]){
  const bad=JSON.parse(custom);mutate(bad.state);assert.equal(f.send('import',{text:JSON.stringify(bad)}).ok,false);assert.equal(f.good('export').meta.exportText,custom);
 }
 f.good('begin_match');const during=f.good('export').meta.exportText;assert.equal(f.send('new_career',payload()).ok,false);assert.equal(f.good('export').meta.exportText,during);
});
test('La saison complète reste jouable et la saison2 reprend le calendrier personnalisé',t=>{
 const f=fixture(t);f.good('new_career',payload());const initial=JSON.parse(f.good('export').meta.exportText).state.customCompetition;
 let m=f.good('snapshot'),steps=0;
 while(m.meta.phase!=='ended'){
  assert.ok(++steps<=29,'26 journées puis trois phases finales maximum');
  if(m.next){f.good('train',{mode:'repos'});const sheet=f.good('auto_lineup');if(!sheet.selection.valid)f.good('promote_cover',{confirmed:true});f.good('begin_match');f.good('delegate');}
  m=f.good('finish_round');
 }
 const ended=JSON.parse(f.good('export').meta.exportText).state;
 assert.equal(ended.history.filter(x=>x.phase==='league').length,182);
 assert.equal(new Set(ended.history.filter(x=>x.phase==='league').map(x=>x.pair.join('-'))).size,182);
 m=f.good('next_season',{confirmed:true});assert.equal(m.meta.season,2);
 const season2=f.good('export').meta.exportText,state=JSON.parse(season2).state;
 assert.deepEqual(state.customCompetition,initial);assert.deepEqual(state.schedule,initial.schedule);assert.ok(state.clubs.every((c,i)=>c.name===initial.clubs[i].name));
 f.restart();assert.equal(f.good('export').meta.exportText,season2);f.good('import',{text:season2});assert.equal(f.good('export').meta.exportText,season2);
});

test('Le remplacement depuis atelier protège la carrière et les refus ne créent aucune copie',t=>{
 const f=fixture(t),initial=f.good('new_career',{mode:'fiction',club:0});
 const original=f.good('export').meta.exportText,bytes=f.bytes(),disk=JSON.parse(bytes);
 const empty=f.good('snapshot').meta.profileSafety.entries;
 assert.deepEqual(empty,[]);
 for(const invalid of [{...payload(),confirmed:false},{...payload(),club:14},{...payload(),extra:true},
  {...payload(),document:{...document(),name:'<invalide>'}},{...payload(),varyCurrent:'false'}]){
  assert.equal(f.send('new_career',invalid).ok,false);
  assert.deepEqual(f.bytes(),bytes,'Refus prévalidé sans toucher profil/RNG/horloge');
  assert.deepEqual(f.good('snapshot').meta.profileSafety.entries,empty,'Refus sans copie de remplacement');
 }
 const created=f.good('new_career',{...payload(),varyCurrent:false});
 const copy=created.meta.profileSafety.entries.find(entry=>entry.reason==='nouvelle-carriere');
 assert.ok(copy,'Copie de la carrière précédente réellement persistée');
 assert.equal(copy.club,initial.club.name);
 assert.deepEqual(fs.readFileSync(path.join(created.meta.dataDir,'Copies-securite',copy.id,'profil.json')),bytes,'Copie disque exacte du profil précédent');
 assert.equal(f.send('restore_checkpoint',{id:copy.id}).ok,false,'Reprise exige confirmation');
 f.good('restore_checkpoint',{id:copy.id,confirmed:true});
 assert.equal(f.good('export').meta.exportText,original,'Ancienne carrière entièrement restaurée');
 const restored=JSON.parse(f.bytes());assert.equal(restored.seed,disk.seed);assert.equal(restored.clock,disk.clock);
 f.good('begin_match');const live=f.bytes(),entries=f.good('snapshot').meta.profileSafety.entries;
 assert.equal(f.send('new_career',payload()).ok,false,'Contexte match refuse remplacement');
 assert.deepEqual(f.bytes(),live);assert.deepEqual(f.good('snapshot').meta.profileSafety.entries,entries,'Match en cours : aucune copie créée');
});
