'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(process.env.TEMP||require('node:os').tmpdir(),'cd-coach-notes06-'));let b,seq=0;
const open=()=>b=createBridge({dataDir:root,seed:506,now:1700000000000});
const call=(command,payload={})=>b.handle({id:++seq,command,payload});
// Une sauvegarde Monde pèse plusieurs Mio : chaque import garde une copie de sécurité (limite 256 Mio). Le banc libère
// explicitement la plus ancienne copie par l'API confirmée quand la limite est atteinte, sans contourner le quota.
const good=(command,payload={})=>{let r=call(command,payload);for(let i=0;!r.ok&&(command==='import'||command==='new_career')&&/Copie de sécurité : limite/.test(r.error)&&i<12;i++){const entries=call('snapshot').model.meta.profileSafety.entries;assert.equal(call('remove_checkpoint',{id:entries.at(-1).id,confirmed:true}).ok,true);r=call(command,payload);}assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const exported=()=>good('export').meta.exportText;
function sign(doc){const raw=JSON.stringify(doc.state);let hash=2166136261;for(let i=0;i<raw.length;i++)hash=Math.imul(hash^raw.charCodeAt(i),16777619);doc.checksum=(hash>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
try{
 open();let m=settleClubMeetings(good('new_career',{mode:'world-champ',club:0}),good),legacy=exported(),prior=JSON.parse(legacy),file=path.join(m.meta.dataDir,'donnees.json'),disk=fs.readFileSync(file),context=m.clubLife.coachNotebook.context,id=m.squad[0].id;
 for(let i=0;i<3;i++)good('snapshot');assert.equal(exported(),legacy);assert.deepEqual(fs.readFileSync(file),disk);assert.equal(prior.state.coachNotebook,undefined);
 const text='Émile & Zoé : <projet> "jeu calme" `revoir` 😀\n\tAucune promesse.';
 m=good('coach_note_save',{context,target:id,text});assert.equal(m.clubLife.coachNotebook.entries[0].text,text);assert.equal(m.meta.coachNote.command,'coach_note_save');
 const current=JSON.parse(exported()).state,without={...current};delete without.coachNotebook;assert.deepEqual(without,prior.state,'Aucun effet sur attributs, finances ou autre domaine');
 const saved=exported(),raw=JSON.parse(fs.readFileSync(file));assert.equal(raw.seed,JSON.parse(disk).seed);assert.equal(raw.clock,JSON.parse(disk).clock);
 assert.ok(current.coachNotebook.entries[0].textCodes.every(Number.isInteger));assert.equal(current.coachNotebook.entries[0].text,undefined);
 good('import',{text:saved});good('shutdown');open();assert.equal(exported(),saved);assert.equal(good('snapshot').clubLife.coachNotebook.entries[0].text,text);
 for(const corrupt of [s=>s.coachNotebook.extra=true,s=>s.coachNotebook.entries[0].week=99,s=>s.coachNotebook.entries[0].season++,s=>s.coachNotebook.entries.push({...s.coachNotebook.entries[0]}),s=>s.coachNotebook.entries[0].textCodes=[0xd800],s=>s.coachNotebook.entries[0].textCodes=[0],s=>s.coachNotebook.entries[0].textCodes=Array(2001).fill(65),s=>s.coachNotebook.entries[0].text='Contrat non déployé']){const doc=JSON.parse(saved);corrupt(doc.state);const bytes=fs.readFileSync(file);assert.equal(call('import',{text:sign(doc)}).ok,false);assert.equal(exported(),saved);assert.deepEqual(fs.readFileSync(file),bytes);}
 const priorBytes=fs.readFileSync(file);
 const refused=refuseSavePublication(file,()=>call('coach_note_save',{context,target:id,text:'Brouillon non sauvegardé'}));
 assert.equal(refused.ok,false);
 assert.equal(exported(),saved);assert.deepEqual(fs.readFileSync(file),priorBytes);
 // Explicit changed-world fixture, without a multi-season campaign or private pack.
 // Monde : une carrière d'un autre club ne se greffe pas sur celle-ci (référence initiale d'effectif) ; le monde « changé » est le même club avec une autre graine.
 const other=createBridge({dataDir:path.join(root,'changed-world-fixture'),seed:507,now:1700000000000});let moved;
 try{assert.equal(other.handle({id:1,command:'new_career',payload:{mode:'world-champ',club:0}}).ok,true);moved=JSON.parse(other.handle({id:2,command:'export'}).model.meta.exportText);}finally{other.close();}
 moved.state.coachNotebook=current.coachNotebook;m=settleClubMeetings(good('import',{text:sign(moved)}),good);assert.equal(m.clubLife.coachNotebook.entries[0].text,text);assert.equal(m.clubLife.coachNotebook.entries[0].club,0);
 // Stable player identity resolves from the current world, never a saved name.
 const renamed=JSON.parse(exported());renamed.state.clubs[0].players.find(p=>p.id===id).name='Identité témoin nouvelle';m=good('import',{text:sign(renamed)});assert.equal(m.clubLife.coachNotebook.entries[0].name,'Identité témoin nouvelle');
 const missing=JSON.parse(exported());{const i=missing.state.clubs[0].players.findIndex(p=>p.id===id);missing.state.clubs[0].players.splice(i,1);}// Monde : l'identité d'un joueur est liée à sa référence d'effectif ; il disparaît donc du monde (retrait de l'effectif) au lieu d'être renommé.
 m=good('import',{text:sign(missing)});assert.equal(m.clubLife.coachNotebook.entries[0].available,false);assert.equal(m.clubLife.coachNotebook.entries[0].name,null);
 m=good('coach_note_save',{context:m.clubLife.coachNotebook.context,target:id,text:'Dossier sorti, note conservée'});assert.equal(m.clubLife.coachNotebook.entries[0].text,'Dossier sorti, note conservée');
 good('import',{text:legacy});assert.equal(good('snapshot').clubLife.coachNotebook.entries.length,0,'Ancien import sans domaine');
 m=good('coach_note_save',{context:good('snapshot').clubLife.coachNotebook.context,target:'career',text:'Nouvelle intention'});settleClubMeetings(good('new_career',{mode:'world-champ',club:0}),good);assert.equal(good('snapshot').clubLife.coachNotebook.entries.length,0,'Nouvelle carrière du même club sans fuite');
 // Monde : le budget général de nœuds de l'édition v5 (world-editions.cjs : maxSaveNodes 2 600 000, contre 200 000 dans l'ancien mode)
 // est hors d'atteinte du carnet (100 notes de 2000 points au plus, soit 200 000 nœuds). L'ancien contrôle « les points comptés épuisent
 // le budget » est remplacé par son équivalent Monde : la charge maximale légitime (100 notes de 2000 points) est acceptée à l'identique,
 // une 101e note est refusée, à l'import comme par la commande, sans aucun effet sur la mémoire ni sur le disque.
 const makeRoom=()=>{const safety=call('snapshot').model.meta.profileSafety;for(let i=0;i<12&&safety.entries.length>=safety.maxEntries-1&&safety.entries.length;i++){assert.equal(call('remove_checkpoint',{id:safety.entries.at(-1).id,confirmed:true}).ok,true);safety.entries.pop();}};
 const full=JSON.parse(legacy),targets=full.state.clubs.flatMap(c=>c.players).slice(0,101);
 full.state.coachNotebook={version:1,entries:targets.slice(0,100).map(p=>({target:p.id,textCodes:Array(2000).fill(65),...context}))};
 m=good('import',{text:sign(full)});const fullText=exported(),fullBytes=fs.readFileSync(file),loadedNotes=JSON.parse(fullText).state.coachNotebook.entries;
 assert.equal(loadedNotes.length,100);assert.ok(loadedNotes.every(e=>e.textCodes.length===2000),'Charge maximale légitime acceptée sans altération');
 const over=JSON.parse(fullText);over.state.coachNotebook.entries.push({target:targets[100].id,textCodes:[65],...context});
 makeRoom();const rejected=call('import',{text:sign(over)});assert.equal(rejected.ok,false);assert.match(rejected.error,/100 notes/);assert.equal(exported(),fullText);assert.deepEqual(fs.readFileSync(file),fullBytes,'101e note importée : rollback exact');
 const extra=call('coach_note_save',{context:m.clubLife.coachNotebook.context,target:targets[100].id,text:'B'});
 assert.equal(extra.ok,false);assert.equal(exported(),fullText);assert.deepEqual(fs.readFileSync(file),fullBytes,'101e note par la commande : rollback atomique');
 const rewritten=call('coach_note_save',{context:m.clubLife.coachNotebook.context,target:targets[0].id,text:'B'.repeat(2000)});assert.equal(rewritten.ok,true,rewritten.error);assert.equal(rewritten.model.clubLife.coachNotebook.entries.length,100,'Une note existante peut être réécrite à pleine longueur');
 fs.writeFileSync(path.join(root,'carnet-reception.json'),saved);
 console.log('Carnet06 vrai worker PASS : libre Unicode, schema/import strict,charge maximale de 100 notes de 2000 points et refus de la 101e, ancienne/nouvelle carrière, identité/mobilité fixture, export/reprise/RNG/disque, refus disque. Preuves : '+root);
}finally{b?.close();}
