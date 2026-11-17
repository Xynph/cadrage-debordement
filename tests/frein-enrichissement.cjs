'use strict';
const assert=require('node:assert/strict');
const {test}=require('node:test');
const B=require('../native/engine/club-budget.cjs');
const forces=[...Array.from({length:14},(_,i)=>({id:i,division:'elite',base:70+i})),...Array.from({length:16},(_,i)=>({id:14+i,division:'accession',base:60+i}))];
const parType=Object.fromEntries(['mecene','entreprise','association'].map(t=>[t,forces.find(f=>B.proprietaire(forces,f.id).type===t).id]));
const clot=(compte,tresorerie,joue=true)=>B.cloture({division:'elite',compte,tresorerie,rang:7,taille:14,joue});
const compteTest=(extra={})=>({type:'mecene',enveloppe:2e6,depart:10e6,recettes:30e6,charges:31e6,salaires:10e6,masse:10e6,division:'elite',rang:7,taille:14,...extra});

test('Clôture avec réserve : une perte absorbée par la caisse n’appelle aucun apport',()=>{
 const compte=compteTest({reserve:5e6}),r=clot(compte,7.5e6);// perte de 2,5 M€ avant prime, caisse restée au-dessus de 5 M€
 assert.ok(r.resultat<0,'la saison est bien déficitaire');
 assert.equal(r.apport,0);assert.equal(r.decouvert,0);assert.ok(!r.ecritures.some(e=>e.title==='Apport du propriétaire'));
 assert.ok(r.messages.some(m=>/réserve/.test(m)),'message de réserve pour le club joué');
 assert.ok(!clot(compte,7.5e6,false).messages.length,'aucun message pour un club géré');
});
test('Clôture avec réserve : l’apport remonte la caisse à la réserve, dans la limite de l’enveloppe',()=>{
 for(const [reserve,enveloppe] of [[9.5e6,2e6],[12e6,2e6],[30e6,5e5]]){
  const tresorerie=7.5e6,compte=compteTest({reserve,enveloppe}),r=clot(compte,tresorerie),fin=tresorerie+r.prime-(r.amende||0);
  const deficit=Math.max(0,-r.resultat),manque=Math.max(0,reserve-fin);
  assert.ok(manque>0,'la caisse passerait sous la réserve');
  assert.equal(r.apport,Math.min(compte.enveloppe,deficit,manque),'réserve '+reserve);if(enveloppe<deficit)assert.equal(r.apport,enveloppe,'plafonné par l’enveloppe');
  assert.equal(r.decouvert,Math.max(0,Math.min(deficit,manque)-compte.enveloppe));
 }
 const a=B.apportProprietaire(compteTest({reserve:9e6}),1.5e6,8.5e6);assert.equal(a.apport,5e5);assert.equal(a.absorbe,1e6);
});
test('Clôture sans réserve (anciens comptes) : apport = min(enveloppe, déficit), comme avant',()=>{
 for(const tresorerie of [9e6,8e6,5e6,12e6]){
  const compte=compteTest(),r=clot(compte,tresorerie),deficit=Math.max(0,-r.resultat);
  assert.equal(r.apport,Math.min(compte.enveloppe,deficit),'trésorerie '+tresorerie);assert.equal(r.decouvert,deficit-r.apport);
 }
 const r=clot(compteTest(),9e6);assert.ok(!r.messages.some(m=>/prises sur la réserve/.test(m)));
});
test('Ouverture avec excédents : réinvestissement, dividende de l’entreprise, rien pour mécène et association',()=>{
 const recettes=B.recettes(forces),riche=id=>({id,cash:recettes.get(id)*2,masse:1e7});
 for(const type of ['mecene','entreprise','association']){
  const id=parType[type],clubs=forces.map(f=>f.id===id?riche(id):{id:f.id,cash:0,masse:1e7});
  const c=B.ouverture({forces,saison:2,clubs,excedents:true}).clubs[id],surplus=c.depart+c.dividende-c.reserve;
  assert.ok(c.reserve>=recettes.get(id)*0.1-5000&&c.reserve<=recettes.get(id)*0.2+5000,'réserve entre 10 et 20 % des recettes');
  assert.ok(c.investissement>0,type+' réinvestit');
  if(type==='entreprise'){assert.ok(c.dividende>0);assert.equal(c.depart,riche(id).cash-c.dividende,'depart = cash - dividende');}
  else{assert.equal(c.dividende,0,type);assert.equal(c.depart,riche(id).cash);}
  assert.ok(c.investissement+c.dividende<=surplus+1,'on ne dépense pas plus que l’excédent');
  const sans=B.ouverture({forces,saison:2,clubs,excedents:false}).clubs[id];
  assert.equal(sans.investissement,0);assert.equal(sans.dividende,0);assert.equal(sans.depart,riche(id).cash);assert.equal(sans.reserve,c.reserve);
 }
 const pauvre=B.ouverture({forces,saison:2,clubs:forces.map(f=>({id:f.id,cash:0,masse:1e7})),excedents:true});
 assert.ok(pauvre.clubs.every(c=>c.investissement===0&&c.dividende===0),'pas d’excédent sans caisse au-dessus de la réserve');
});
test('Semaine avec investissement : écriture négative = investissement / semaines, arrondie à 100',()=>{
 const base={forces,clubId:3,masseHebdo:150000,semaines:34,domicile:true,alea:0.5,libelle:'S'};
 const sans=B.semaine(base),avec=B.semaine({...base,investissement:1234567});
 const e=avec.filter(x=>/Investissements/.test(x.title));assert.equal(e.length,1);
 assert.equal(e[0].amount,-Math.round(1234567/34/100)*100);assert.equal(Math.abs(e[0].amount)%100,0);
 assert.ok(!sans.some(x=>/Investissements/.test(x.title)));assert.equal(avec.length,sans.length+1);
 assert.ok(!B.semaine({...base,investissement:0}).some(x=>/Investissements/.test(x.title)));
});
test('Six saisons à +1 M€ avant prime : la caisse reste bornée (réserve + 3 M€), l’ancien schéma ajoute 6 M€',()=>{
 for(const type of ['mecene','entreprise','association']){
  const id=parType[type],r=B.reserveCible(B.recettes(forces).get(id),id);
  let cash=r,ancien=r,max=r;
  for(let saison=2;saison<=7;saison++){
   const c=B.ouverture({forces,saison,clubs:forces.map(f=>({id:f.id,cash:f.id===id?cash:0,masse:1e7})),excedents:true}).clubs[id];
   cash=c.depart+1e6-c.investissement;ancien+=1e6;max=Math.max(max,cash);
  }
  assert.equal(ancien,r+6e6);assert.ok(max<=r+3e6,type+' : caisse '+max+' > réserve '+r+' + 3 M€');
  assert.ok(cash>=r,'la caisse ne passe pas sous la réserve');
 }
});

// --- Moteur (carrière Monde `world-champ`, graine fixe) ---
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');
test('Moteur Monde : création sans dividende ni investissement, jokers au vrai prix, dividende de l’entreprise',()=>{
 const jeu=ouvrir({hebdomadaire:true,testVm:true});
 try{
  creer(jeu,0);
  const run=s=>jeu.bridge.vm.run(s),lire=s=>JSON.parse(run('JSON.stringify('+s+')'));
  // 1. Création : rien de distribué.
  assert.equal(lire('S.clubBudget.clubs.filter(c=>c.dividende>0||c.investissement>0).length'),0);
  assert.equal(lire('S.ledger.filter(e=>/Dividende/.test(JSON.stringify(e))).length'),0);
  assert.equal(lire('club().players.length>=40&&S.clubBudget.clubs[S.club].reserve>0'),true);
  // Outils : vide n places (joueurs retirés du club joué, lineup/reserves à null).
  run(`var T={marge:m=>{const c=club(),l=budgetLimites(false).get(c.id).limite,top=c.players.slice().sort((a,b)=>b.salary-a.salary)[0];
    top.salary=Math.max(1,top.salary+Math.floor((l-m-budgetMasse(c)*52)/52));},vider:n=>{const c=club();const ids=[...S.lineup.slice(0,n)];S.lineup=S.lineup.map((id,i)=>i<n?null:id);
    const feuille=new Set([...S.lineup,...S.reserves]);c.players=c.players.filter(p=>feuille.has(p.id));return ids},
   libre:(slot,sal)=>{const p=S.economy.freeAgents.find(x=>slotEligible(x,slot)&&!(x.injury>0));p.rating=90;p.salary=sal||p.salary;
    p.age=Math.min(p.age,28);p.contractEnd=S.season+3;return p.id}};`);
  const etat=()=>lire(`({vides:[...S.lineup,...S.reserves].filter(id=>!id).length})`);
  // 2. Joker libre au salaire demandé + espoirs au plancher.
  const ids=lire('T.vider(3)');run('T.marge(2e6)');const joker=lire('T.libre(0)');
  assert.equal(etat().vides,3);
  const r=lire(`(()=>{const p=S.economy.freeAgents.find(x=>x.id===${JSON.stringify(joker)});const demande=salaryDemandBreakdown(p,'recruit').asked;
   const avant=new Set(club().players.map(x=>x.id));const ok=promoteCover();
   const nouveaux=club().players.filter(x=>!avant.has(x.id));
   return {ok,demande,vides:[...S.lineup,...S.reserves].filter(id=>!id).length,j:club().players.find(x=>x.id===${JSON.stringify(joker)})||null,
    libre:S.economy.freeAgents.some(x=>x.id===${JSON.stringify(joker)}),saison:S.season,plancher:nativeStartingSalaries.plancherHebdo(S,budgetLigue(S.club)),
    autres:nouveaux.filter(x=>x.id!==${JSON.stringify(joker)}).map(x=>[x.salary,x.contractEnd])};})()`);
  assert.ok(r.j,'le joker rejoint le club');assert.equal(r.libre,false);
  assert.equal(r.j.contractEnd,r.saison);assert.equal(r.j.salary,r.demande);
  assert.equal(r.vides,0,'feuille complète');
  assert.ok(r.autres.length>=1,'des espoirs comblent les autres places');
  for(const [salaire,fin] of r.autres){assert.ok(salaire>=r.plancher,'espoir '+salaire+' < plancher '+r.plancher);assert.equal(fin,r.saison);}
  // 3. Limite salariale trop serrée : pas de joker, un espoir à la place.
  lire('T.vider(2)');
  run('T.marge(100)');const joker2=lire('T.libre(0)');
  const r3=lire(`(()=>{const avant=new Set(club().players.map(x=>x.id));const id=${JSON.stringify(joker2)};
   const l=budgetLimites(false).get(club().id);const limite=l?l.limite:Infinity;
   const ok=promoteCover();return {ok,limite,joker:club().players.some(x=>x.id===id),libre:S.economy.freeAgents.some(x=>x.id===id),
    vides:[...S.lineup,...S.reserves].filter(id=>!id).length,nouveaux:club().players.filter(x=>!avant.has(x.id)).length};})()`);
  assert.equal(r3.joker,false,'joker hors limite refusé');assert.equal(r3.libre,true);
  assert.ok(r3.nouveaux>=1);assert.equal(r3.vides,0);
  // 4. Dividende : caisse très au-dessus de la réserve, nouvelle saison.
  const d=lire(`(()=>{const c=club(),b=S.clubBudget.clubs[S.club];c.cash=b.reserve+50e6;const avant=c.cash,n=S.ledger.length;
   budgetOuvrir(true,true);const cb=S.clubBudget.clubs[S.club];
   return {type:cb.type,dividende:cb.dividende,avant,apres:club().cash,ecr:S.ledger.slice(n).filter(e=>/Dividende versé au groupe actionnaire/.test(JSON.stringify(e))).map(e=>e.amount??e.delta??e.value)};})()`);
  assert.equal(d.type,'entreprise');assert.ok(d.dividende>0);
  assert.equal(d.ecr.length,1);assert.equal(d.ecr[0],-d.dividende);assert.equal(d.apres,d.avant-d.dividende);
 }finally{jeu.fermer();}
});
