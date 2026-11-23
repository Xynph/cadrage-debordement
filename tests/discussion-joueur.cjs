'use strict';
// Discussion avec un joueur (revue FM27, idée 23) : discussion en trois tours (ouverture, relance, conclusion), phrases
// selon la situation, chaque réponse propre à la phrase dite, effet réel selon le caractère, la situation, la hiérarchie
// et le chemin (déterministe), commande relationship_conversation avec `phrase`, reprise d'une discussion en cours.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {createBridge}=require('../native/engine/worker.cjs');
const Disc=require('../native/engine/discussion-joueur.cjs').factory();
const TRAITS=['Ambitieux','Loyal','Exigeant','Discret','Protecteur','Competiteur','Sensible','Collectif'];
const RANGS=['relais','cadre','groupe','jeune'];

// --- Arbres : cohérence -------------------------------------------------------------------------------------------
const vus=new Set(),triplets=new Set();
for(const [sit,a] of Object.entries(Disc.ARBRES)){
 assert.equal(a.ouvertures.length,3,sit);assert.equal(a.fins.length,2,sit);
 for(const rang of RANGS){
  const ouv=Disc.options(sit,rang,[]);assert.equal(ouv.length,3);
  for(const o of ouv){
   const relances=Disc.options(sit,rang,[o]);assert.equal(relances.length,2,`${sit}/${o} : deux relances`);
   for(const r of relances){assert.notEqual(r,o);assert.deepEqual(Disc.options(sit,rang,[o,r]),a.fins);assert.deepEqual(Disc.options(sit,rang,[o,r,a.fins[0]]),[]);}
  }
 }
 for(const id of [...a.ouvertures,...a.ouvertures.flatMap(o=>Disc.NOEUDS[o].suite),...a.fins])vus.add(id);
}
vus.add('n_leader');for(const id of Disc.NOEUDS.n_leader.suite)vus.add(id);
assert.deepEqual([...vus].sort(),Object.keys(Disc.NOEUDS).sort(),'chaque phrase est dans un arbre, aucune orpheline');
for(const [id,n] of Object.entries(Disc.NOEUDS)){
 assert.ok(n.texte.length<=40,`phrase courte : ${n.texte}`);
 assert.ok(Disc.RULES.NATURES.includes(n.nature)&&['ecouter','rassurer','clarifier'].includes(n.choix),id);
 assert.equal(n.reponses.length,3,id);assert.equal(new Set(n.reponses).size,3,`${id} : trois réponses différentes`);
 for(const r of n.reponses)assert.ok(r.length<=45&&!/coach\s*[,.]?\s*je comprends ton point|n'hésite pas/i.test(r),r);
 const cle=n.reponses.join('|');assert.ok(!triplets.has(cle),`${id} : réponses propres à la phrase`);triplets.add(cle);
 // Chaque réponse correspond à la phrase dite : bonne réaction → 1re, neutre → 2e, mauvaise → 3e.
 assert.equal(Disc.reponse(id,3),n.reponses[0]);assert.equal(Disc.reponse(id,0),n.reponses[1]);assert.equal(Disc.reponse(id,-2),n.reponses[2]);
}
assert.equal(Disc.reponse('inconnue',2),null);

// --- Réactions et effet du chemin ---------------------------------------------------------------------------------
assert.equal(Disc.effet('critique','Ambitieux'),-4);assert.equal(Disc.effet('critique','Sensible'),-4);assert.equal(Disc.effet('critique','Exigeant'),2);
assert.equal(Disc.effet('ecoute','Sensible'),4);assert.equal(Disc.effet('collectif','Protecteur'),3);
assert.equal(Disc.effet('critique','Sensible','mecontent','jeune'),-5);assert.equal(Disc.effet('ecoute','Sensible','temps_jeu','cadre'),5);
assert.deepEqual([4,3,2,1,0,-1,-3].map((r,i)=>Disc.poids(r,i===0?0:1)),[4,2,1,1,0,-1,-2]);
assert.equal(Disc.total([5,5,5]),6);assert.equal(Disc.total([-5,-5,-4]),-6);assert.equal(Disc.total([2,-3,1]),1);
assert.deepEqual([25,30,44,45,55,65,80,95].map(Disc.palier),[0,1,1,2,3,4,5,5]);
assert.deepEqual([-5,-3,-2,-1,0,1,2,3,5].map(Disc.pas),[-2,-2,-1,-1,0,1,1,2,2]);
assert.deepEqual([['relais',3],['relais',-2],['relais',1],['cadre',-3],['cadre',4],['groupe',-5]].map(([r,e])=>Disc.moralGroupe(r,e)),[1,-1,0,-1,0,0]);
// Le chemin compte : avec un fier (Ambitieux), critiquer puis exiger coûte, écouter puis faire confiance rapporte.
const chemin=(sit,rang,trait,ids)=>Disc.total(ids.map(id=>Disc.effet(Disc.NOEUDS[id].nature,trait,sit,rang)));
assert.ok(chemin('normal','groupe','Ambitieux',['n_critique','n_details','n_fin_samedi'])<0);
assert.ok(chemin('normal','groupe','Ambitieux',['n_ecoute','n_objectif','n_fin_confiance'])>0);
// … et un exigeant aime l'inverse de ce qu'aime un sensible.
assert.ok(chemin('normal','groupe','Exigeant',['n_critique','n_details','n_fin_samedi'])>chemin('normal','groupe','Sensible',['n_critique','n_details','n_fin_samedi']));
// Tous les chemins, tous les caractères, tous les rangs : total borné, toujours le même (aucun tirage).
for(const sit of Object.keys(Disc.ARBRES))for(const rang of RANGS)for(const trait of TRAITS)
 for(const o of Disc.options(sit,rang,[]))for(const r of Disc.options(sit,rang,[o]))for(const f of Disc.options(sit,rang,[o,r])){
  const t=chemin(sit,rang,trait,[o,r,f]);assert.ok(Math.abs(t)<=6);assert.equal(chemin(sit,rang,trait,[o,r,f]),t);
 }
// Situations : blessé d'abord, puis temps de jeu promis, mécontent, peu utilisé, en forme.
const s0={season:1,economy:{week:3},matchNotes:{detail:{f:[[1,2,'x',80,72,0,0,0,0],[2,3,'x',80,75,0,0,0,0],[3,4,'x',80,70,0,0,0,0]]}}};
assert.equal(Disc.situation({id:'a',injury:2,satisfaction:{score:30}},s0,{humeur:'mecontent'}),'blesse');
assert.equal(Disc.situation({id:'a',injury:0,satisfaction:{score:30}},s0,{humeur:'attentif'}),'temps_jeu');
assert.equal(Disc.situation({id:'a',injury:0,satisfaction:{score:40}},s0,{humeur:'content'}),'mecontent');
assert.equal(Disc.situation({id:'a',injury:0,satisfaction:{score:60}},s0,{humeur:'neutre',juges:4,moyenne:12}),'peu_utilise');
assert.equal(Disc.situation({id:'f',injury:0,satisfaction:{score:60}},s0,null),'en_forme');
assert.equal(Disc.situation({id:'a',injury:0,satisfaction:{score:60}},s0,null),'normal');
assert.equal(Disc.options('normal','relais',[])[1],'n_leader');assert.equal(Disc.options('normal','groupe',[])[1],'n_soutien');
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
 const rel=()=>m.clubLife.relationships,ctx=()=>rel().context,joueur=id=>rel().players.find(p=>p.id===id);
 const dire=(p,ph)=>{m=good('relationship_conversation',{context:ctx(),playerId:p.id,choice:ph.choice,phrase:ph.id});return joueur(p.id);};
 const rangs=rel().players.map(p=>p.discussion?.hierarchie);
 assert.equal(rangs.filter(r=>r==='relais').length,1,'un seul relais');assert.equal(rangs.filter(r=>r==='cadre').length,5,'cinq cadres');
 for(const p of rel().players){
  assert.deepEqual(p.discussion.phrases.map(x=>x.id),Disc.options(p.discussion.situation,p.discussion.hierarchie,[]));
  assert.equal(p.discussion.tour,0);assert.equal(p.discussion.faite,false);assert.equal(p.discussion.attitude,Disc.palier(p.score));
 }
 // Trois tours avec un joueur du groupe : ouverture critique, relance, conclusion.
 let cible=rel().players.find(p=>p.discussion.hierarchie==='groupe'&&p.discussion.situation==='normal');
 assert.ok(cible,'un joueur « groupe » en situation normale');
 const trait=cible.personality.trait,avant=cible.score,moral=m.meta.morale,choisis=[];
 bad('relationship_conversation',{context:ctx(),playerId:cible.id,choice:'ecouter',phrase:'n_critique'});
 bad('relationship_conversation',{context:ctx(),playerId:cible.id,choice:'ecouter',phrase:'n_objectif'});
 for(let tour=0;tour<3;tour++){
  const ph=joueur(cible.id).discussion.phrases[0];choisis.push(ph.id);
  if(tour===1)bad('relationship_conversation',{context:ctx(),playerId:cible.id,choice:'clarifier',phrase:'n_critique'});
  const apres=dire(cible,ph),reactions=choisis.map(id=>Disc.effet(Disc.NOEUDS[id].nature,trait,'normal','groupe'));
  assert.equal(apres.discussion.tour,tour+1);assert.equal(apres.discussion.faite,tour===2);
  assert.equal(apres.score,Math.max(20,Math.min(95,avant+Disc.total(reactions))),`satisfaction après le tour ${tour+1}`);
  const fil=apres.discussion.fil.tours;assert.equal(fil.length,tour+1);
  fil.forEach((t,i)=>{assert.equal(t.phrase,choisis[i]);assert.equal(t.texte,Disc.NOEUDS[choisis[i]].texte);
   assert.ok(Disc.NOEUDS[choisis[i]].reponses.includes(t.reponse),'la réponse répond à la phrase dite');assert.equal(t.reponse,Disc.reponse(choisis[i],reactions[i]));});
  assert.equal(apres.discussion.attitude,Math.max(0,Math.min(5,Disc.palier(avant)+Disc.pas(Disc.total(reactions)))));
  if(tour<2)assert.deepEqual(apres.discussion.phrases.map(x=>x.id),Disc.options('normal','groupe',choisis),'les phrases suivantes découlent de la précédente');
 }
 assert.deepEqual(joueur(cible.id).discussion.phrases,[]);assert.equal(joueur(cible.id).conversationAvailable,false);
 assert.equal(m.meta.morale,Math.min(98,moral),'groupe : pas d’écho sur le moral, clarifier sans moral');
 bad('relationship_conversation',{context:ctx(),playerId:cible.id,choice:'rassurer',phrase:'n_fin_confiance'});
 // Le relais : écho de la conclusion sur le moral du groupe.
 const relais=rel().players.find(p=>p.discussion.hierarchie==='relais'),sitR=relais.discussion.situation,idsR=[];
 let moral2=m.meta.morale;
 for(let tour=0;tour<3;tour++){
  const ph=joueur(relais.id).discussion.phrases[0];idsR.push(ph.id);
  const premier=tour===0&&ph.choice==='rassurer'?1:0;
  dire(relais,ph);
  const tot=Disc.total(idsR.map(id=>Disc.effet(Disc.NOEUDS[id].nature,relais.personality.trait,sitR,'relais')));
  const attendu=Math.max(25,Math.min(98,moral2+(tour===2?Disc.moralGroupe('relais',tot):0)));
  if(premier===0)assert.equal(m.meta.morale,attendu,`moral après le tour ${tour+1}`);
  moral2=m.meta.morale;
 }
 // Sans phrase : l'ancien entretien garde son bonus fixe (scènes, autres écrans).
 const autre=rel().players.find(p=>p.conversationAvailable);
 m=good('relationship_conversation',{context:ctx(),playerId:autre.id,choice:'ecouter'});
 assert.equal(joueur(autre.id).score,Math.min(95,autre.score+2));
 assert.deepEqual(joueur(autre.id).discussion.phrases,[],'entretien de la semaine déjà tenu');
 // Discussion interrompue après l'ouverture, reprise après rechargement de la carrière.
 const coupe=rel().players.find(p=>p.conversationAvailable&&p.discussion.phrases.length===3);
 const ouv=coupe.discussion.phrases[2];dire(coupe,ouv);
 const saved=good('export').meta.exportText;
 good('shutdown');b=createBridge({dataDir:root});m=good('snapshot');
 assert.equal(good('export').meta.exportText,saved,'Reprise fidèle.');
 const repris=joueur(coupe.id).discussion;
 assert.equal(repris.tour,1);assert.deepEqual(repris.phrases.map(x=>x.id),Disc.options(repris.situation,repris.hierarchie,[ouv.id]));
 dire(coupe,repris.phrases[1]);assert.equal(joueur(coupe.id).discussion.tour,2);
 assert.equal(joueur(cible.id).discussion.fil.tours.length,3,'fil de trois tours gardé');
 console.log('Discussion avec un joueur : trois tours cohérents, réponses propres à chaque phrase, effet selon caractère et chemin, reprise PASS.');
}finally{b?.close();}
