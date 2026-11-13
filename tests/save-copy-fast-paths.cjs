'use strict';
// Copies d'annulation et écriture du profil allégées (chantier sauvegarde incrémentale, 13/11/2026) :
// le fichier écrit reste exactement celui d'avant, la copie de secours garde l'ancien contenu sur un
// fichier distinct, et une écriture refusée annule la commande comme avant. Carrière Monde.
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs'),{settleClubMeetings}=require('./helpers/club-meetings.cjs');

test('profil identique, copie de secours distincte, annulation exacte après refus d’écriture',()=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-inc-copies-'));let b,n=0;
 const open=()=>createBridge({dataDir:root,seed:41,now:1794178800000,verifyCleanCopy:true});
 const raw=(command,payload={})=>b.handle({id:++n,command,payload});
 const good=(command,payload={})=>{const r=raw(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 const exported=()=>JSON.parse(good('export').meta.exportText).state;
 try{
  b=open();let m=settleClubMeetings(good('new_career',{mode:'world-champ',club:0}),good);
  const dir=m.meta.dataDir,file=path.join(dir,'donnees.json'),backup=path.join(dir,'donnees-precedentes.json');
  const canonical=()=>{const text=fs.readFileSync(file,'utf8'),parsed=JSON.parse(text);assert.equal(text,JSON.stringify({protocol:1,seed:parsed.seed,clock:parsed.clock,store:parsed.store}),'texte du profil identique à JSON.stringify');return parsed;};
  const tactics=m.tactics.attacks.map(t=>t.id);
  for(let i=0;i<3;i++){
   const before=fs.readFileSync(file);
   m=good('set_tactics',{attack:tactics[(i+1)%tactics.length],defense:m.tactics.defense});
   const parsed=canonical();assert.deepEqual(fs.readFileSync(backup),before,'la copie de secours garde exactement le fichier précédent');
   const a=fs.statSync(file),c=fs.statSync(backup);
   assert.notEqual(a.ino,c.ino,'profil et copie sont deux fichiers distincts');assert.equal(a.nlink,1);assert.equal(c.nlink,1);
   assert.equal(JSON.parse(parsed.store['bdt-v1']).tactic,tactics[(i+1)%tactics.length]);
  }
  // Refus métier : rien ne change, ni en mémoire ni sur disque.
  const stable=exported(),bytes=fs.readFileSync(file);
  assert.equal(raw('set_tactics',{attack:'inconnue',defense:'x'}).ok,false);
  assert.deepEqual(exported(),stable);assert.deepEqual(fs.readFileSync(file),bytes);
  // Écriture impossible (copie de secours remplacée par un dossier) : la commande est annulée.
  fs.rmSync(backup);fs.mkdirSync(backup);
  const failed=raw('set_tactics',{attack:tactics[0]===stable.tactic?tactics[1]:tactics[0],defense:m.tactics.defense});
  assert.equal(failed.ok,false);assert.match(failed.error,/Écriture de sauvegarde impossible/);
  assert.deepEqual(exported(),stable,'état en mémoire revenu à la dernière sauvegarde');assert.deepEqual(fs.readFileSync(file),bytes);
  fs.rmdirSync(backup);
  // Profil lié ailleurs (lien physique étranger) : copie complète, jamais de partage du fichier.
  const foreign=path.join(root,'lien-externe.json');fs.linkSync(file,foreign);
  const linked=fs.readFileSync(file);m=good('set_tactics',{attack:stable.tactic,defense:m.tactics.defense});
  assert.deepEqual(fs.readFileSync(backup),linked);assert.notEqual(fs.statSync(backup).ino,fs.statSync(foreign).ino,'copie indépendante du lien étranger');
  assert.deepEqual(fs.readFileSync(foreign),linked,'le fichier lié ailleurs n’est jamais réécrit');
  canonical();
  // Semaine réelle puis reprise : même carrière après redémarrage.
  if(m.next){if(!m.selection.valid){good('auto_lineup');if(!good('snapshot').selection.valid)good('promote_cover',{confirmed:true});}good('begin_match');good('delegate');}
  m=settleClubMeetings(good('finish_round'),good);
  const saved=good('export').meta.exportText;canonical();b.close();b=open();
  assert.equal(good('export').meta.exportText,saved);
 }finally{b?.close();fs.rmSync(root,{recursive:true,force:true});}
});
