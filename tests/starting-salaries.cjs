'use strict';
const assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process');
const path=require('node:path');
const {test}=require('node:test');
const M=require('../native/engine/starting-salaries.cjs');
const forces=[...Array.from({length:14},(_,i)=>({id:i,division:'elite',base:70+i})),...Array.from({length:16},(_,i)=>({id:14+i,division:'accession',base:60+i}))];
test('Référence : croît avec le niveau, bornée aux extrémités',()=>{
 for(let n=46;n<=99;n++)assert.ok(M.reference(n)>M.reference(n-1));
 assert.equal(M.reference(20),M.reference(45));assert.equal(M.reference(120),M.reference(99));
});
test('Politique des clubs : un club fort paie plus, chaque club a son tempérament',()=>{
 const p=M.politiques(forces);assert.ok(p.get(13)>p.get(0)&&p.get(29)>p.get(14));
 assert.ok([...p.values()].every(x=>x>0.75&&x<1.4));assert.ok(new Set([...p.values()].map(x=>x.toFixed(3))).size>20);
});
test('Variété : à niveau, poste, âge et club égaux, des joueurs sous-payés et surpayés',()=>{
 const annuels=Array.from({length:400},(_,i)=>M.detail({id:'j'+i,rating:75,fam:3,age:27},1).annuel).sort((a,b)=>a-b);
 assert.ok(annuels[399]>annuels[0]*2.2,'écart d’au moins 2,2 entre extrêmes');
 const ref=M.reference(75);assert.ok(annuels.filter(a=>a<ref*0.8).length>40&&annuels.filter(a=>a>ref*1.25).length>40);
 assert.ok(Math.abs(annuels[200]-ref*1.04)/ref<0.14,'la médiane reste proche de la référence');
 assert.deepEqual(M.detail({id:'x',rating:75,fam:3,age:27},1),M.detail({id:'x',rating:75,fam:3,age:27},1),'déterministe');
 assert.ok(M.detail({id:'star',rating:99,fam:2,age:31},1.3).annuel<=800000);
});
test('Application : une seule fois, à la création seulement',()=>{
 const etat={season:1,round:0,live:null,clubs:[{id:0,players:[{id:'a',rating:80,fam:5,age:27,salary:1},{id:'b',rating:62,fam:1,age:20,salary:1}]}]};
 M.apply(etat,forces);assert.ok(etat.clubs[0].players[0].salary>etat.clubs[0].players[1].salary*3);
 const avant=JSON.stringify(etat);M.apply(etat,forces);assert.equal(JSON.stringify(etat),avant);
 assert.throws(()=>M.apply({season:2,round:0,clubs:[]},forces),/création/);
});
const sonde=`const {createBridge}=require('./native/engine/worker.cjs');const {settleClubMeetings}=require('./tests/helpers/club-meetings.cjs');const fs=require('fs'),os=require('os'),path=require('path');
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'rl27-sal-'));let b=createBridge({dataDir:dir,seed:27,now:1794178800000}),n=0;
const good=(c,p={})=>{const r=b.handle({id:++n,command:c,payload:p});if(!r.ok)throw Error(c+' : '+r.error);return r.model;},etat=()=>JSON.parse(good('export').meta.exportText).state;
let m=settleClubMeetings(good('new_career',{mode:'common',club:29}),good);const S=etat();
const t=S.clubs.flatMap(c=>c.players),nb=t.length,ma=t.reduce((s,p)=>s+p.salary,0)/nb,mb=t.reduce((s,p)=>s+p.rating,0)/nb;let ab=0,a=0,c=0;for(const p of t){ab+=(p.salary-ma)*(p.rating-mb);a+=(p.salary-ma)**2;c+=(p.rating-mb)**2;}
const an=k=>k.players.reduce((s,p)=>s+p.salary,0)*52,m75=t.filter(p=>p.rating===75).map(p=>p.salary);
// Une semaine jouée par l'API publique, puis export, réimport et reprise depuis le disque.
m=settleClubMeetings(good('train'),good);good('auto_lineup');good('begin_match');good('delegate');settleClubMeetings(good('finish_round'),good);
const S1=etat(),texte=good('export').meta.exportText;good('import',{text:texte});const reimport=good('export').meta.exportText===texte;
good('shutdown');b=createBridge({dataDir:dir,now:1794178800000});const reprise=good('export').meta.exportText===texte;
// Première commande après la reprise : la semaine suivante doit suivre le même budget.
m=settleClubMeetings(good('snapshot'),good);m=settleClubMeetings(good('train'),good);good('auto_lineup');good('begin_match');good('delegate');settleClubMeetings(good('finish_round'),good);const S2=etat();b.close();
const titres=x=>[...new Set(x.ledger.filter(l=>l.title.includes(' · ')).map(l=>l.title.split(' · ').pop()))].sort();
console.log(JSON.stringify({marque:S.startingSalaries??null,correlation:ab/Math.sqrt(a*c),elite:S.clubs.slice(0,14).reduce((s,k)=>s+an(k),0)/14,accession:S.clubs.slice(14).reduce((s,k)=>s+an(k),0)/16,ecart75:Math.max(...m75)/Math.min(...m75),
 budget:S.clubBudget??null,annonce:S.news.some(x=>/comblera|adhérents/.test(x)),titres:titres(S1),titres2:titres({ledger:S2.ledger.slice(0,10)}),semaines:[S1.clubBudget?.semaines??null,S2.clubBudget?.semaines??null],reimport,reprise,
 deltas:S1.clubs.map((k,i)=>k.cash-S.clubs[i].cash),masses:S.clubs.map(k=>k.players.reduce((s,p)=>s+p.salary,0)),domicile:S1.history.filter(r=>r.week===0).map(r=>r.pair[0]),vainqueurs:S1.history.filter(r=>r.week===0).map(r=>r.score[0]>r.score[1]?r.pair[0]:r.score[1]>r.score[0]?r.pair[1]:-1)}));`;
const sorties={};
function creer(drapeau){
 if(sorties[drapeau])return sorties[drapeau];
 const r=spawnSync(process.execPath,['-e',sonde],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:600000,env:{...process.env,CD_SALAIRES_PAR_NIVEAU:drapeau}});
 assert.equal(r.status,0,r.stderr.slice(-800));return sorties[drapeau]=JSON.parse(r.stdout.trim().split('\n').pop());
}
test('Vrai moteur, drapeau éteint : rien ne change',()=>{const x=creer('0');assert.equal(x.marque,null);assert.ok(Math.abs(x.correlation)<0.1);});
test('Vrai moteur, drapeau éteint : une semaine jouée garde l’ancienne économie, pour tous les clubs',()=>{
 const x=creer('0');assert.equal(x.budget,null);assert.equal(x.annonce,false);assert.deepEqual(x.semaines,[null,null]);
 assert.deepEqual(x.titres,['Entretien des installations','Partenaires','Prime de victoire','Salaires','Billetterie'].filter(t=>x.titres.includes(t)).sort());assert.ok(x.titres.includes('Salaires')&&!x.titres.includes('Cotisations'));
 for(let i=0;i<29;i++)assert.equal(x.deltas[i],160000-x.masses[i]+(x.domicile.includes(i)?360000:0)+(x.vainqueurs.includes(i)?80000:0),'club '+i+' : ancien calcul hebdomadaire');
 assert.ok(x.reimport&&x.reprise);
});
test('Vrai moteur, drapeau allumé : salaires liés au niveau, variés, masses réalistes',()=>{
 const x=creer('1');assert.deepEqual(x.marque,{version:3,semaines:52});
 assert.ok(x.correlation>0.7&&x.correlation<0.95,'lié au niveau sans être mécanique : '+x.correlation);
 assert.ok(x.elite>8e6&&x.elite<11.5e6,'masse moyenne en première division : '+x.elite);
 assert.ok(x.accession>2.4e6&&x.accession<4e6,'masse moyenne en deuxième division : '+x.accession);
 assert.ok(x.ecart75>2.5,'à niveau 75, écart de salaire d’au moins 2,5 : '+x.ecart75);
});
test('Contrats espoirs : hors du noyau, un joueur de 22 ans ou moins a un salaire d’espoir',()=>{
 const joueurs=[...Array.from({length:M.NOYAU},(_,i)=>({id:'pro'+i,rating:85-i%10,fam:3,age:27})),{id:'jeune',rating:70,fam:3,age:20},{id:'ancien',rating:70,fam:3,age:29},{id:'pepite',rating:90,fam:5,age:20}];
 const s=M.club(joueurs,'elite',1);
 assert.equal(s.get('jeune').espoir,true);assert.ok(s.get('jeune').annuel<=60000);
 assert.equal(s.get('ancien').espoir,false,'un joueur installé hors du noyau reste professionnel');
 assert.equal(s.get('pepite').espoir,false,'un jeune dans les meilleurs du club est payé en professionnel');
 assert.ok(s.get('pepite').annuel>s.get('jeune').annuel*4);
});
test('Vrai moteur, drapeau allumé : budget réaliste pour tous les clubs, sauvegarde relue et reprise exactes',()=>{
 const x=creer('1');assert.equal(x.budget.version,1);assert.equal(x.budget.saison,1);assert.equal(x.budget.clubs.length,30);assert.equal(x.annonce,true,'le propriétaire annonce son enveloppe');
 for(const k of ['recettesPrevues','chargesPrevues','resultatPrevu','masseSalariale','limiteRecettes','margeRecettes','tresoreriePrevue'])assert.ok(Number.isFinite(x.budget.prevision[k]),k);
 assert.ok(['mecene','entreprise','association'].includes(x.budget.prevision.proprietaire.type));
 for(const t of ['Abonnements','Partenaires','Versement de la ligue','Salaires des joueurs','Cotisations','Staff et fonctionnement'])assert.ok(x.titres.includes(t)&&x.titres2.includes(t),t+' avant et après la reprise');
 assert.ok(!x.titres.includes('Salaires')&&!x.titres.includes('Prime de victoire'));assert.deepEqual(x.semaines,[1,2]);
 assert.ok(x.reimport,'export puis import : texte identique');assert.ok(x.reprise,'reprise depuis le disque : texte identique');
 // Les clubs gérés par le jeu ne touchent plus 160 000 € + 360 000 € par semaine quels que soient leurs salaires.
 const elite=x.deltas.slice(0,14),accession=x.deltas.slice(14,29);
 assert.ok(Math.abs(elite.reduce((s,d)=>s+d,0)/14)<150000,'élite, variation moyenne sur une semaine : '+elite.reduce((s,d)=>s+d,0)/14);
 assert.ok(Math.abs(accession.reduce((s,d)=>s+d,0)/15)<60000,'accession, variation moyenne sur une semaine : '+accession.reduce((s,d)=>s+d,0)/15);
});
// Carrière mondiale la plus large : tous les championnats de la base.
const sondeMonde=`const {createBridge}=require('./native/engine/worker.cjs');const {settleClubMeetings}=require('./tests/helpers/club-meetings.cjs');const fs=require('fs'),os=require('os'),path=require('path');
const b=createBridge({dataDir:fs.mkdtempSync(path.join(os.tmpdir(),'rl27-monde-')),seed:27,now:1794178800000});let n=0;
const good=(c,p={})=>{const r=b.handle({id:++n,command:c,payload:p});if(!r.ok)throw Error(c+' : '+r.error);return r.model;},etat=()=>JSON.parse(good('export').meta.exportText).state;
let m=settleClubMeetings(good('new_career',{mode:'world-champ',club:30}),good);const S=etat();
const de=new Map();for(const [l,v] of Object.entries(S.worldMode.leagues))for(const id of v.members)de.set(id,l);
const masses={};for(const c of S.clubs){const l=de.get(c.id)||'guest';(masses[l]=masses[l]||[]).push(c.players.reduce((s,p)=>s+p.salary,0)*52);}
settleClubMeetings(good('finish_round'),good);const S1=etat(),texte=good('export').meta.exportText;good('import',{text:texte});const reimport=good('export').meta.exportText===texte;b.close();
console.log(JSON.stringify({marque:S.startingSalaries??null,masses:Object.fromEntries(Object.entries(masses).map(([l,v])=>[l,v.reduce((s,x)=>s+x,0)/v.length])),budget:S.clubBudget?{version:S.clubBudget.version,clubs:S.clubBudget.clubs.length,divisions:[...new Set(S.clubBudget.clubs.map(c=>c.division))].sort(),prevision:S.clubBudget.prevision}:null,
 annonce:S.news.some(x=>/comblera|adhérents/.test(x)),titres:[...new Set(S1.ledger.filter(l=>l.title.includes(' · ')).map(l=>l.title.split(' · ').pop()))].sort(),reimport,deltas:S1.clubs.map((k,i)=>k.cash-S.clubs[i].cash),ligues:S.clubs.map(c=>de.get(c.id)||'guest')}));`;
function creerMonde(drapeau){
 const r=spawnSync(process.execPath,['-e',sondeMonde],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:600000,env:{...process.env,CD_SALAIRES_PAR_NIVEAU:drapeau}});
 assert.equal(r.status,0,r.stderr.slice(-800));return JSON.parse(r.stdout.trim().split('\n').pop());
}
test('Vrai moteur, carrière mondiale, drapeau éteint : ni marque ni budget, ancien calcul',()=>{
 const x=creerMonde('0');assert.equal(x.marque,null);assert.equal(x.budget,null);assert.equal(x.annonce,false);assert.ok(x.reimport);
 assert.ok(x.titres.includes('Salaires')&&!x.titres.includes('Cotisations'));assert.ok(x.masses.champ>5e6,'masses de l’ancien barème');
});
test('Vrai moteur, carrière mondiale, drapeau allumé : chaque championnat à son niveau, budget pour les 116 clubs',()=>{
 const x=creerMonde('1'),E=require('../native/engine/league-economy.cjs').CHAMPIONNATS;
 assert.equal(x.marque.version,3);assert.deepEqual(Object.keys(x.marque.calage).sort(),['champ','guest','jlo-d1','jlo-d2','nationale','prem','srp','urc']);
 for(const [nom,c] of Object.entries(E))assert.ok(Math.abs(x.masses[nom]-c.masse)/c.masse<0.1,nom+' : masse moyenne '+Math.round(x.masses[nom])+' pour '+c.masse);
 assert.ok(x.masses.elite>x.masses.prem&&x.masses.prem>x.masses.urc&&x.masses.nationale>x.masses.champ);
 assert.equal(x.budget.clubs,116);assert.deepEqual(x.budget.divisions,Object.keys(E).sort());assert.equal(x.annonce,true);
 assert.equal(x.budget.prevision.plafondSalarial,7.5e6,'le plafond du championnat anglais s’applique à un club anglais');assert.equal(x.budget.prevision.limiteRecettes,null,'la règle des 52 % ne vaut qu’en France');
 for(const t of ['Abonnements','Cotisations','Staff et fonctionnement'])assert.ok(x.titres.includes(t),t);assert.ok(x.reimport,'export puis import : texte identique');
 // Une semaine : aucun club ne gagne ou ne perd plus de 4 % des recettes moyennes de son championnat.
 x.deltas.forEach((d,i)=>assert.ok(Math.abs(d)<E[x.ligues[i]].recettes*0.04,'club '+i+' ('+x.ligues[i]+') : '+d));
});
