'use strict';
// Discussion avec un joueur (revue FM27, idée 23) : phrases selon la situation, effet réel selon le caractère, la
// situation et la hiérarchie (déterministe), commande relationship_conversation avec `phrase`, fil gardé en sauvegarde.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {createBridge}=require('../native/engine/worker.cjs');
const Disc=require('../native/engine/discussion-joueur.cjs').factory();

// --- Règles pures -------------------------------------------------------------------------------------------------
// Le fier (Ambitieux) prend mal la critique, l'exigeant la prend bien ; le sensible a besoin d'être écouté.
assert.equal(Disc.effet('critique','Ambitieux'),-4);
assert.equal(Disc.effet('critique','Sensible'),-4);
assert.equal(Disc.effet('critique','Exigeant'),2);
assert.equal(Disc.effet('ecoute','Sensible'),4);
assert.equal(Disc.effet('ecoute','Competiteur'),1);
assert.equal(Disc.effet('collectif','Ambitieux'),-1);
assert.equal(Disc.effet('collectif','Protecteur'),3);
// Situation et hiérarchie s'ajoutent ; borné à ±5.
assert.equal(Disc.effet('critique','Sensible','mecontent','jeune'),-5);
assert.equal(Disc.effet('ecoute','Sensible','temps_jeu','cadre'),5);
assert.equal(Disc.effet('exigence','Exigeant','blesse'),1);
assert.equal(Disc.effet('eloge','Ambitieux','en_forme','jeune'),5);
// Même entrée, même sortie (aucun tirage).
for(let i=0;i<3;i++)assert.equal(Disc.effet('soutien','Loyal','peu_utilise','groupe'),3);
// Attitude : 6 paliers ; la réponse déplace d'un palier (±1, ±2) ou de deux (±3 et plus).
assert.deepEqual([25,30,44,45,55,65,80,95].map(Disc.palier),[0,1,1,2,3,4,5,5]);
assert.deepEqual([-5,-3,-2,-1,0,1,2,3,5].map(Disc.pas),[-2,-2,-1,-1,0,1,1,2,2]);
assert.equal(Disc.reponse('critique',-4),'Tu me parles pas comme ça.');
assert.equal(Disc.reponse('critique',2),'Reçu. Tu vas voir la réaction.');
// Moral du groupe : un relais entraîne le groupe, un cadre seulement vers le bas.
assert.deepEqual([[ 'relais',3],['relais',-2],['relais',1],['cadre',-3],['cadre',4],['groupe',-5]].map(([r,e])=>Disc.moralGroupe(r,e)),[1,-1,0,-1,0,0]);
// Situations : blessé d'abord, puis temps de jeu promis, mécontent, peu utilisé, en forme.
const s0={season:1,economy:{week:3},matchNotes:{detail:{f:[[1,2,'x',80,72,0,0,0,0],[2,3,'x',80,75,0,0,0,0],[3,4,'x',80,70,0,0,0,0]]}}};
assert.equal(Disc.situation({id:'a',injury:2,satisfaction:{score:30}},s0,{humeur:'mecontent'}),'blesse');
assert.equal(Disc.situation({id:'a',injury:0,satisfaction:{score:30}},s0,{humeur:'attentif'}),'temps_jeu');
assert.equal(Disc.situation({id:'a',injury:0,satisfaction:{score:40}},s0,{humeur:'content'}),'mecontent');
assert.equal(Disc.situation({id:'a',injury:0,satisfaction:{score:60}},s0,{humeur:'neutre',juges:4,moyenne:12}),'peu_utilise');
assert.equal(Disc.situation({id:'f',injury:0,satisfaction:{score:60}},s0,null),'en_forme');
assert.equal(Disc.situation({id:'a',injury:0,satisfaction:{score:60}},s0,null),'normal');
// Phrases : trois par situation, courtes ; un relais ou un cadre en situation normale reçoit « collectif ».
for(const sit of ['blesse','temps_jeu','mecontent','peu_utilise','en_forme','normal']){
 const l=Disc.phrases(sit,'groupe');assert.equal(l.length,3,sit);
 for(const ph of l){assert.ok(ph.texte.length<=40,ph.texte);assert.ok(['ecouter','rassurer','clarifier'].includes(ph.choix));}
}
assert.equal(Disc.phrases('normal','relais')[1].id,'n_leader');assert.equal(Disc.phrases('normal','groupe')[1].id,'n_soutien');
// Hiérarchie : relais, 5 cadres, jeunes (21 ans et moins), groupe.
global.CDLivingLockerRoom={personality:p=>({trait:'Loyal',leadership:p.lead})};
const h=Disc.hierarchie([{id:'L',lead:99,age:30},...[1,2,3,4,5,6].map(i=>({id:'c'+i,lead:90-i,age:28})),{id:'j',lead:10,age:20},{id:'g',lead:20,age:25}],'L');
assert.deepEqual(['L','c1','c5','c6','j','g'].map(id=>h.get(id)),['relais','cadre','cadre','groupe','jeune','groupe']);
delete global.CDLivingLockerRoom;

// --- Vraie carrière Monde -----------------------------------------------------------------------------------------
const root=fs.mkdtempSync(path.join(os.tmpdir(),'discussion-joueur-'));
let b,seq=0;
const good=(command,payload={})=>{const r=b.handle({id:++seq,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;};
const bad=(command,payload={})=>{const r=b.handle({id:++seq,command,payload});assert.equal(r.ok,false,command+' doit être refusé');return r;};
try{
 b=createBridge({dataDir:root,seed:371,now:1700000000000});
 let m=settleClubMeetings(good('new_career',{mode:'world-champ',club:29}),good);
 const rel=()=>m.clubLife.relationships,ctx=()=>rel().context;
 assert.ok(rel().players.length>20);
 const rangs=rel().players.map(p=>p.discussion?.hierarchie);
 assert.equal(rangs.filter(r=>r==='relais').length,1,'un seul relais');
 assert.equal(rangs.filter(r=>r==='cadre').length,5,'cinq cadres');
 assert.equal(rel().players.find(p=>p.discussion.hierarchie==='relais').id,rel().leaderId);
 for(const p of rel().players){
  assert.equal(p.discussion.phrases.length,3);assert.equal(p.discussion.faite,false);
  assert.deepEqual(p.discussion.phrases.map(x=>x.id),Disc.phrases(p.discussion.situation,p.discussion.hierarchie).map(x=>x.id));
  assert.equal(p.discussion.attitude,Disc.palier(p.score));
 }
 // Joueur sans rôle particulier (effet du groupe connu) : la critique, l'écoute ou le soutien selon son caractère.
 const cible=rel().players.find(p=>p.discussion.hierarchie==='groupe'&&p.discussion.situation==='normal');
 assert.ok(cible,'un joueur « groupe » en situation normale');
 const phrase=cible.discussion.phrases[2],attendu=Disc.effet(phrase.nature,cible.personality.trait,'normal','groupe');
 const avant=cible.score,moral=m.meta.morale;
 bad('relationship_conversation',{context:ctx(),playerId:cible.id,choice:'ecouter',phrase:phrase.id});
 bad('relationship_conversation',{context:ctx(),playerId:cible.id,choice:'ecouter',phrase:'blesse_ecoute'});
 bad('relationship_conversation',{context:ctx(),playerId:cible.id,choice:'ecouter',phrase:'inconnue'});
 m=good('relationship_conversation',{context:ctx(),playerId:cible.id,choice:phrase.choice,phrase:phrase.id});
 const apres=rel().players.find(p=>p.id===cible.id);
 assert.equal(apres.score,Math.max(20,Math.min(95,avant+attendu)),'effet réel selon le caractère');
 assert.equal(m.meta.morale,Math.min(98,moral),'clarifier : pas de moral, groupe : pas d’écho');
 assert.equal(apres.discussion.faite,true);assert.equal(apres.conversationAvailable,false);
 const dernier=apres.discussion.fil.at(-1);
 assert.equal(dernier.phrase,phrase.id);assert.equal(dernier.texte,phrase.texte);assert.equal(dernier.effet,attendu);
 assert.equal(dernier.reponse,Disc.reponse(phrase.nature,attendu));
 assert.equal(apres.discussion.attitudeAvant,Disc.palier(avant));
 assert.equal(apres.discussion.attitude,Math.max(0,Math.min(5,Disc.palier(avant)+Disc.pas(attendu))));
 bad('relationship_conversation',{context:ctx(),playerId:cible.id,choice:phrase.choice,phrase:phrase.id});
 // Relais : effet réel et écho sur le moral du groupe.
 const relais=rel().players.find(p=>p.discussion.hierarchie==='relais'),ph=relais.discussion.phrases[0];
 const eR=Disc.effet(ph.nature,relais.personality.trait,relais.discussion.situation,'relais'),moral2=m.meta.morale;
 m=good('relationship_conversation',{context:ctx(),playerId:relais.id,choice:ph.choice,phrase:ph.id});
 assert.equal(rel().players.find(p=>p.id===relais.id).score,Math.max(20,Math.min(95,relais.score+eR)));
 assert.equal(m.meta.morale,Math.max(25,Math.min(98,moral2+Disc.moralGroupe('relais',eR))),'écho du relais sur le moral');
 // Sans phrase : l'ancien entretien garde son bonus fixe (scènes, autres écrans).
 const autre=rel().players.find(p=>p.conversationAvailable);
 m=good('relationship_conversation',{context:ctx(),playerId:autre.id,choice:'ecouter'});
 assert.equal(rel().players.find(p=>p.id===autre.id).score,Math.min(95,autre.score+2));
 // Sauvegarde : le fil revient à la reprise.
 const saved=good('export').meta.exportText;
 good('shutdown');b=createBridge({dataDir:root});m=good('snapshot');
 assert.equal(good('export').meta.exportText,saved,'Reprise fidèle.');
 assert.equal(rel().players.find(p=>p.id===cible.id).discussion.fil.at(-1).phrase,phrase.id);
 console.log('Discussion avec un joueur : phrases selon la situation, effet selon le caractère, relais, fil sauvegardé PASS.');
}finally{b?.close();}
