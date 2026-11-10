'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(process.env.TEMP||require('node:os').tmpdir(),'cd-coach-notes06-'));let b,seq=0;
const open=()=>b=createBridge({dataDir:root,seed:506,now:1700000000000});
const call=(command,payload={})=>b.handle({id:++seq,command,payload});
const good=(command,payload={})=>{const r=call(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const exported=()=>good('export').meta.exportText;
function sign(doc){const raw=JSON.stringify(doc.state);let hash=2166136261;for(let i=0;i<raw.length;i++)hash=Math.imul(hash^raw.charCodeAt(i),16777619);doc.checksum=(hash>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
try{
 open();let m=settleClubMeetings(good('new_career',{mode:'fiction',club:0}),good),legacy=exported(),prior=JSON.parse(legacy),file=path.join(m.meta.dataDir,'donnees.json'),disk=fs.readFileSync(file),context=m.clubLife.coachNotebook.context,id=m.squad[0].id;
 for(let i=0;i<3;i++)good('snapshot');assert.equal(exported(),legacy);assert.deepEqual(fs.readFileSync(file),disk);assert.equal(prior.state.coachNotebook,undefined);
 const text='Émile & Zoé : <projet> "jeu calme" `revoir` 😀\n\tAucune promesse.';
 m=good('coach_note_save',{context,target:id,text});assert.equal(m.clubLife.coachNotebook.entries[0].text,text);assert.equal(m.meta.coachNote.command,'coach_note_save');
 const current=JSON.parse(exported()).state,without={...current};delete without.coachNotebook;assert.deepEqual(without,prior.state,'Aucun effet sur attributs, finances ou autre domaine');
 const saved=exported(),raw=JSON.parse(fs.readFileSync(file));assert.equal(raw.seed,JSON.parse(disk).seed);assert.equal(raw.clock,JSON.parse(disk).clock);
 assert.ok(current.coachNotebook.entries[0].textCodes.every(Number.isInteger));assert.equal(current.coachNotebook.entries[0].text,undefined);
 good('import',{text:saved});good('shutdown');open();assert.equal(exported(),saved);assert.equal(good('snapshot').clubLife.coachNotebook.entries[0].text,text);
 for(const corrupt of [s=>s.coachNotebook.extra=true,s=>s.coachNotebook.entries[0].week=35,s=>s.coachNotebook.entries[0].season++,s=>s.coachNotebook.entries.push({...s.coachNotebook.entries[0]}),s=>s.coachNotebook.entries[0].textCodes=[0xd800],s=>s.coachNotebook.entries[0].textCodes=[0],s=>s.coachNotebook.entries[0].textCodes=Array(2001).fill(65),s=>s.coachNotebook.entries[0].text='Contrat non déployé']){const doc=JSON.parse(saved);corrupt(doc.state);const bytes=fs.readFileSync(file);assert.equal(call('import',{text:sign(doc)}).ok,false);assert.equal(exported(),saved);assert.deepEqual(fs.readFileSync(file),bytes);}
 const priorBytes=fs.readFileSync(file);
 const refused=refuseSavePublication(file,()=>call('coach_note_save',{context,target:id,text:'Brouillon non sauvegardé'}));
 assert.equal(refused.ok,false);
 assert.equal(exported(),saved);assert.deepEqual(fs.readFileSync(file),priorBytes);
 // Explicit changed-world fixture, without a multi-season campaign or private pack.
 const other=createBridge({dataDir:path.join(root,'changed-world-fixture'),seed:506,now:1700000000000});let moved;
 try{assert.equal(other.handle({id:1,command:'new_career',payload:{mode:'fiction',club:1}}).ok,true);moved=JSON.parse(other.handle({id:2,command:'export'}).model.meta.exportText);}finally{other.close();}
 moved.state.coachNotebook=current.coachNotebook;m=settleClubMeetings(good('import',{text:sign(moved)}),good);assert.equal(m.clubLife.coachNotebook.entries[0].text,text);assert.equal(m.clubLife.coachNotebook.entries[0].club,0);
 // Stable player identity resolves from the current world, never a saved name.
 const renamed=JSON.parse(exported());renamed.state.clubs[0].players.find(p=>p.id===id).name='Identité témoin nouvelle';m=good('import',{text:sign(renamed)});assert.equal(m.clubLife.coachNotebook.entries[0].name,'Identité témoin nouvelle');
 const missing=JSON.parse(exported());missing.state.clubs[0].players.find(p=>p.id===id).id='fixture-player-gone';m=good('import',{text:sign(missing)});assert.equal(m.clubLife.coachNotebook.entries[0].available,false);assert.equal(m.clubLife.coachNotebook.entries[0].name,null);
 m=good('coach_note_save',{context:m.clubLife.coachNotebook.context,target:id,text:'Dossier sorti, note conservée'});assert.equal(m.clubLife.coachNotebook.entries[0].text,'Dossier sorti, note conservée');
 good('import',{text:legacy});assert.equal(good('snapshot').clubLife.coachNotebook.entries.length,0,'Ancien import sans domaine');
 m=good('coach_note_save',{context:good('snapshot').clubLife.coachNotebook.context,target:'career',text:'Nouvelle intention'});settleClubMeetings(good('new_career',{mode:'fiction',club:0}),good);assert.equal(good('snapshot').clubLife.coachNotebook.entries.length,0,'Nouvelle carrière du même club sans fuite');
 // Counted code points really consume the untouched safeTree node budget.
 const bounded=JSON.parse(legacy),targets=bounded.state.clubs.flatMap(c=>c.players).slice(0,100);
 bounded.state.coachNotebook={version:1,entries:targets.map(p=>({target:p.id,textCodes:Array(1000).fill(65),...context}))};
 m=good('import',{text:sign(bounded)});const boundedText=exported(),boundedBytes=fs.readFileSync(file);
 const hostile=JSON.parse(boundedText);hostile.state.coachNotebook.entries.forEach(e=>e.textCodes=Array(2000).fill(65));
 const rejected=call('import',{text:sign(hostile)});assert.equal(rejected.ok,false);assert.match(rejected.error,/complexe/);assert.equal(exported(),boundedText);assert.deepEqual(fs.readFileSync(file),boundedBytes,'Limite globale non contournée, rollback exact');
 const count=v=>1+(v&&typeof v==='object'?Object.values(v).reduce((n,x)=>n+count(x),0):0),near=JSON.parse(legacy);
 near.state.coachNotebook={version:1,entries:targets.map(p=>({target:p.id,textCodes:[65],...context}))};
 const overhead=count(near.state)-100,length=Math.floor((199990-overhead)/100);assert.ok(length>=1&&length<2000);
 near.state.coachNotebook.entries.forEach(e=>e.textCodes=Array(length).fill(65));m=good('import',{text:sign(near)});
 const nearText=exported(),nearBytes=fs.readFileSync(file),update=call('coach_note_save',{context:m.clubLife.coachNotebook.context,target:targets[0].id,text:'B'.repeat(2000)});
 assert.equal(update.ok,false);assert.match(update.error,/complexe/);assert.equal(exported(),nearText);assert.deepEqual(fs.readFileSync(file),nearBytes,'Commande note bien formée dépassant le budget : rollback atomique');
 console.log('Budget compté sans modification : base '+count(prior.state)+' nœuds ; fixture proche '+count(near.state)+' ; longueur par note '+length+'.');
 fs.writeFileSync(path.join(root,'carnet-reception.json'),saved);
 console.log('Carnet06 vrai worker PASS : libre Unicode, schema/import strict,2000points comptés, ancienne/nouvelle carrière, identité/mobilité fixture, export/reprise/RNG/disque, refus disque et complexité globale inchangée. Preuves : '+root);
}finally{b?.close();}
