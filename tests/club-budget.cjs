'use strict';
const assert=require('node:assert/strict');
const {test}=require('node:test');
const B=require('../native/engine/club-budget.cjs');
const forces=[...Array.from({length:14},(_,i)=>({id:i,division:'elite',base:70+i})),...Array.from({length:16},(_,i)=>({id:14+i,division:'accession',base:60+i}))];
const moyenne=l=>l.reduce((s,x)=>s+x,0)/l.length;
test('Recettes visées : moyenne exacte par division, club fort mieux doté',()=>{
 const r=B.recettes(forces),e=forces.slice(0,14).map(c=>r.get(c.id)),a=forces.slice(14).map(c=>r.get(c.id));
 assert.ok(Math.abs(moyenne(e)-33e6)<1&&Math.abs(moyenne(a)-10.7e6)<1);
 assert.ok(e[13]>e[0]*1.8&&a[15]>a[0]*2&&Math.min(...e)>Math.max(...a));
});
test('Parts de recettes : chaque division totalise 100 %',()=>{
 for(const d of Object.values(B.DIVISIONS))assert.ok(Math.abs(d.partenaires+d.ligue+d.billetterie+d.boutique+d.divers-1)<1e-9);
});
test('Une saison type : salaires payés sur 52 semaines, club moyen proche de l’équilibre',()=>{
 for(const [clubId,masseAnnuelle] of [[6,9.9e6],[21,3.2e6]]){
  let total=0,salaires=0,recettes=0;
  for(let s=0;s<34;s++)for(const e of B.semaine({forces,clubId,masseHebdo:masseAnnuelle/52,semaines:34,domicile:s%2===0,alea:0.5,libelle:'S'})){
   total+=e.amount;if(e.title.endsWith('Salaires des joueurs'))salaires-=e.amount;if(e.amount>0)recettes+=e.amount;}
  // La part du versement de la ligue liée au classement arrive en fin de saison : ici, un club de milieu de tableau.
  const division=clubId<14?'elite':'accession',taille=clubId<14?14:16,prime=(B.primeClassement(division,1,taille)+B.primeClassement(division,taille,taille))/2;total+=prime;recettes+=prime;
  assert.ok(Math.abs(salaires-masseAnnuelle)/masseAnnuelle<0.01,'les 34 semaines de compétition paient l’année entière');
  assert.ok(Math.abs(recettes-B.recettes(forces).get(clubId))/recettes<0.02,'recettes de la saison égales aux recettes visées');
  assert.ok(Math.abs(total)<recettes*0.08,'résultat de la saison à moins de 8 % des recettes : '+Math.round(total));
  assert.ok(salaires/( -(total-recettes))>0.2&&salaires/(-(total-recettes))<0.36,'les joueurs pèsent entre 20 et 36 % des charges');
 }
});
test('Billetterie et boutique seulement à domicile ; entrées invalides refusées',()=>{
 const base={forces,clubId:20,masseHebdo:60000,semaines:34,alea:0.5,libelle:'S'};
 const ext=B.semaine({...base,domicile:false}),dom=B.semaine({...base,domicile:true});
 assert.ok(!ext.some(e=>/Billetterie|Boutique/.test(e.title))&&dom.filter(e=>/Billetterie|Boutique/.test(e.title)).length===2);
 assert.throws(()=>B.semaine({...base,clubId:99,domicile:true}),/division/);assert.throws(()=>B.semaine({...base,semaines:0,domicile:true}),/semaines/);
});

test('Propriétaire : type stable, enveloppe proportionnée, association sans apport',()=>{
 const p=forces.map(f=>B.proprietaire(forces,f.id));assert.deepEqual(p,forces.map(f=>B.proprietaire(forces,f.id)),'déterministe');
 assert.ok(['mecene','entreprise','association'].every(t=>p.some(x=>x.type===t)),'les trois types existent');
 for(const [i,x] of p.entries()){const r=B.recettes(forces).get(i);
  if(x.type==='association')assert.equal(x.enveloppe,0);else assert.ok(x.enveloppe>0&&x.enveloppe<r*0.16&&x.enveloppe%50000===0,'enveloppe '+x.enveloppe);
  assert.ok(!/fictif/i.test(B.annonce({type:x.type,enveloppe:x.enveloppe})));}
 assert.notEqual(B.proprietaire(forces,13).type,'association','le club le plus fort de l’élite a un actionnaire');
});
test('Prime de classement : décroît avec le rang, redistribue exactement le quart du versement de la ligue',()=>{
 for(const [division,taille] of [['elite',14],['accession',16]]){
  const primes=Array.from({length:taille},(_,i)=>B.primeClassement(division,i+1,taille));
  for(let i=1;i<taille;i++)assert.ok(primes[i]<primes[i-1]);
  const d=B.DIVISIONS[division];assert.ok(Math.abs(moyenne(primes)-d.moyenne*d.ligue*B.PART_PRIME)<200);assert.ok(primes[0]>primes[taille-1]*5);
 }
 assert.throws(()=>B.primeClassement('elite',15,14),/rang/);
});
test('Affluence : la billetterie suit les résultats récents ; les phases finales rapportent plus',()=>{
 const base={forces,clubId:6,masseHebdo:190000,semaines:34,receptions:13,domicile:true,alea:0.5,libelle:'S'};
 const guichet=x=>B.semaine({...base,...x}).find(e=>/Billetterie/.test(e.title)).amount;
 const noir=guichet({resultats:['D','D','D','D','D']}),moyen=guichet({resultats:['V','D','N','V','D']}),faste=guichet({resultats:['V','V','V','V','V']});
 assert.ok(noir<moyen&&moyen<faste&&faste/noir>1.35&&faste/noir<1.6,'de la série noire à la série faste : '+noir+' '+moyen+' '+faste);
 assert.equal(guichet({resultats:[]}),guichet({resultats:['V','D']}),'sans match joué, forme neutre');
 assert.equal(B.forme(['D','D','D','V','V','V','V','V']),1,'seuls les cinq derniers matchs comptent');
 assert.ok(guichet({phase:'barrage',resultats:['V','D','N','V','D']})>moyen*2,'un barrage à domicile rapporte plus qu’une journée ordinaire');
 const neutre=B.semaine({...base,domicile:false,neutre:true,phase:'final'});
 assert.ok(neutre.some(e=>/Part de recette de phase finale/.test(e.title)&&e.amount>0)&&!neutre.some(e=>/Billetterie|Boutique/.test(e.title)));
 const sansHasard=B.semaine({...base,alea:undefined,repere:'1|4'});assert.deepEqual(sansHasard,B.semaine({...base,alea:undefined,repere:'1|4'}),'sans alea fourni, tirage stable');
 const abo=B.semaine({...base,domicile:false}).find(e=>/Abonnements/.test(e.title));assert.ok(abo.amount>0,'les abonnements rentrent aussi les semaines à l’extérieur');
});
test('Saison réelle : 13 réceptions en élite, 15 en accession, la billetterie visée est encaissée',()=>{
 for(const [clubId,rencontres,part] of [[6,26,0.16],[21,30,0.08]]){
  let billets=0;for(let s=0;s<34;s++)for(const e of B.semaine({forces,clubId,masseHebdo:1,semaines:34,receptions:rencontres/2,domicile:s<rencontres&&s%2===0,alea:0.5,libelle:'S'}))if(/Billetterie|Abonnements/.test(e.title))billets+=e.amount;
  const vise=B.recettes(forces).get(clubId)*part;assert.ok(Math.abs(billets-vise)/vise<0.01,'billetterie '+billets+' pour '+vise);
 }
});
test('Règles de la ligue : plafond de 10,7 M€ en élite, 52 % des recettes partout',()=>{
 const sain=B.regles({division:'elite',masseAnnuelle:9e6,recettes:30e6});assert.equal(sain.amende,0);assert.equal(sain.margePlafond,1.7e6);assert.equal(sain.margeRecettes,6.6e6);
 const plafond=B.regles({division:'elite',masseAnnuelle:12.7e6,recettes:40e6});assert.equal(plafond.depassementPlafond,2e6);assert.equal(plafond.amende,1e6);
 const ratio=B.regles({division:'accession',masseAnnuelle:4e6,recettes:6e6});assert.equal(ratio.plafond,null);assert.equal(ratio.margePlafond,null);assert.equal(ratio.depassementRecettes,880000);assert.equal(ratio.amende,440000);
 assert.equal(B.regles({division:'elite',masseAnnuelle:30e6,recettes:40e6}).amende,2e6,'amende bornée');
});
const compte=(type,enveloppe,extra={})=>({type,enveloppe,depart:3e6,recettes:10e6,charges:10.5e6,salaires:3e6,masse:3e6,...extra});
test('Clôture : le propriétaire comble le déficit jusqu’à son enveloppe, pas au-delà',()=>{
 const prime=B.primeClassement('accession',8,16);
 const couvert=B.cloture({division:'accession',compte:compte('mecene',1.5e6),tresorerie:2e6,rang:8,taille:16,joue:true});
 assert.equal(couvert.apport,1e6-prime);assert.equal(couvert.decouvert,0);assert.equal(couvert.confiance,0);
 assert.ok(couvert.ecritures.some(e=>e.title==='Apport du propriétaire'&&e.amount===1e6-prime)&&couvert.ecritures.some(e=>/^Prime de classement de la ligue/.test(e.title)&&e.amount===prime));
 const depasse=B.cloture({division:'accession',compte:compte('entreprise',500000),tresorerie:0.5e6,rang:8,taille:16,joue:true});
 assert.equal(depasse.apport,500000);assert.equal(depasse.decouvert,2.5e6-prime-500000);assert.ok(depasse.confiance<=-5&&depasse.confiance>=-15);assert.ok(depasse.messages.some(m=>/confiance/.test(m)));
 const asso=B.cloture({division:'accession',compte:compte('association',0),tresorerie:2e6,rang:8,taille:16,joue:true});
 assert.equal(asso.apport,0);assert.ok(!asso.ecritures.some(e=>e.title==='Apport du propriétaire'));assert.ok(asso.confiance<0&&asso.messages.some(m=>/association/.test(m)));
 const vert=B.cloture({division:'accession',compte:compte('mecene',1.5e6),tresorerie:3.4e6,rang:8,taille:16,joue:true});
 assert.equal(vert.apport,0);assert.equal(vert.confiance,0);assert.ok(vert.messages.some(m=>/dans le vert/.test(m)));
 const gere=B.cloture({division:'accession',compte:compte('entreprise',500000),tresorerie:0.5e6,rang:8,taille:16});assert.deepEqual(gere.messages,[]);assert.equal(gere.confiance,0,'un club géré par le jeu ne touche ni à la confiance ni aux messages');
 for(const r of [couvert,depasse,asso,vert])assert.ok(r.messages.length&&r.messages.every(m=>!/fictif/i.test(m)));
});
test('Clôture : dépassement constaté à la dernière journée, amende et confiance',()=>{
 const r=B.cloture({division:'elite',compte:compte('mecene',5e6,{depart:8e6,recettes:40e6,charges:39e6,masse:12.7e6}),tresorerie:9e6,rang:3,taille:14,joue:true});
 assert.equal(r.amende,1e6);assert.equal(r.confiance,-6);assert.ok(r.ecritures.some(e=>/^Amende de la ligue \(dépassement du plafond salarial\)$/.test(e.title)&&e.amount===-1e6));
 const ratio=B.cloture({division:'accession',compte:compte('mecene',1e6,{recettes:6e6,charges:6e6,masse:4e6}),tresorerie:3e6,rang:16,taille:16,joue:true});
 assert.ok(ratio.amende>0&&ratio.ecritures.some(e=>/52 % des recettes/.test(e.title)));
});
test('Clubs gérés par le jeu : économies quand le déficit dépasse l’enveloppe, excédents réinvestis',()=>{
 assert.equal(B.ajustement(10e6,3e6,0),0,'à l’équilibre, rien ne bouge');
 assert.ok(Math.abs(B.ajustement(10e6,2e6,0)-0.7*1.4e6)<1);
 assert.equal(B.ajustement(10e6,4e6,1.4e6),0,'déficit couvert par le propriétaire : pas de plan d’économies');
 assert.ok(Math.abs(B.ajustement(10e6,4e6,0)+0.7*1.4e6)<1);assert.equal(B.ajustement(10e6,8e6,0),-1.5e6,'économies bornées à 15 % des recettes');
 const base={forces,clubId:20,masseHebdo:150000,semaines:34,domicile:false,alea:0.5,libelle:''},cout=x=>-B.semaine({...base,...x}).find(e=>/fonctionnement/.test(e.title)).amount;
 assert.ok(cout({gere:true})<cout({gere:false}),'un club géré trop dépensier réduit son train de vie');
});
test('Prévision de la saison : champs lisibles, alertes de la ligue et du propriétaire',()=>{
 const c=B.ouverture({forces,saison:1,clubs:forces.map(f=>({id:f.id,cash:5e6,masse:12.9e6}))});assert.equal(c.clubs.length,30);assert.equal(c.saison,1);
 const p=B.prevision({forces,clubId:13,compte:c.clubs[13],tresorerie:5e6,masseHebdo:12.9e6/52,semaines:34,reste:34,receptions:13,receptionsRestantes:13,rang:7,taille:14});
 for(const k of ['recettesPrevues','chargesPrevues','resultatPrevu','horsBudget','apportPrevu','masseSalariale','plafondSalarial','limiteRecettes','margePlafond','margeRecettes','primeClassementPrevue','tresoreriePrevue'])assert.ok(Number.isFinite(p.prevision[k]),k);
 assert.equal(p.prevision.plafondSalarial,10.7e6);assert.ok(p.prevision.margePlafond<0&&p.prevision.amendePrevue>0);assert.ok(p.alertes.some(a=>a.cle==='plafond'&&/10,7 M€/.test(a.message)));
 assert.ok(Math.abs(p.prevision.recettesPrevues-B.recettes(forces).get(13))/p.prevision.recettesPrevues<0.03,'en début de saison, la prévision retrouve les recettes visées');
 assert.equal(p.prevision.resultatPrevu,p.prevision.recettesPrevues-p.prevision.chargesPrevues-p.prevision.amendePrevue);
 const vente=B.prevision({forces,clubId:13,compte:c.clubs[13],tresorerie:5.4e6,masseHebdo:9e6/52,semaines:34,reste:34,receptions:13,receptionsRestantes:13,rang:7,taille:14}).prevision;
 assert.equal(vente.horsBudget,400000,'une vente de joueur entre dans la prévision');assert.ok(vente.margePlafond>0&&vente.amendePrevue===0);
 const pauvre=B.prevision({forces,clubId:14,compte:{...c.clubs[14],type:'association',enveloppe:0},tresorerie:5e6,masseHebdo:6e6/52,semaines:34,reste:34,receptions:15,receptionsRestantes:15,rang:8,taille:16});
 assert.equal(pauvre.prevision.plafondSalarial,null);assert.ok(pauvre.alertes.some(a=>a.cle==='recettes')&&pauvre.alertes.some(a=>a.cle==='deficit'));assert.ok(pauvre.alertes.every(a=>!/fictif/i.test(a.message)));
 assert.equal(B.euros(1250000),'1,25 M€');assert.equal(B.euros(-350000),'350 000 €');
});

// Le branchement dans le moteur du jeu, sans passer par le disque.
const {context}=require('./native-reference-harness.cjs');
function moteur(marque){
 const h=context();h.run('CDCommonCareer.start(29);');
 if(marque){h.ctx.nativeStartingSalaries=require('../native/engine/starting-salaries.cjs');h.run("nativeStartingSalaries.apply(S,CDFranceClubs.clubs.map(c=>({id:c.id,division:c.division,base:c.base})));");}
 h.ctx.nativeClubBudget=B;h.run(B.BRANCHEMENT);if(marque)h.run('budgetOuvrir(true)');
 const lire=source=>JSON.parse(h.run('JSON.stringify('+source+')'));
 return {...h,lire,semaine:()=>h.run("financeWeek(null,false);worldWeeklyEconomy(CDFranceCompetition.currentFixtures(S).map(f=>({...f,score:[20,10],tries:[2,1]})));")};
}
test('Moteur, carrière non marquée : ancien calcul intact pour le club joué et pour les autres',()=>{
 const h=moteur(false),avant=h.lire('S.clubs.map(c=>({cash:c.cash,masse:c.players.reduce((s,p)=>s+p.salary,0)}))'),recoit=h.lire('CDFranceCompetition.currentFixtures(S).map(f=>f.pair[0])');
 h.semaine();const S=h.lire('S');assert.equal(S.clubBudget,undefined);assert.equal(S.startingSalaries,undefined);
 assert.deepEqual(S.ledger.map(e=>e.title.split(' · ').pop()),['Entretien des installations','Partenaires','Salaires']);assert.equal(S.ledger[1].amount,160000);
 for(const c of S.clubs)if(c.id!==29){const gagne=recoit.includes(c.id);assert.equal(c.cash-avant[c.id].cash,160000-avant[c.id].masse+(gagne?360000+80000:0),'club '+c.id);}
 h.run("ledgerEntry('Financement de début de saison',2500000)");assert.equal(h.lire('S.ledger[0]').amount,2500000,'le versement de 2,5 M€ reste en place');
});
test('Moteur, carrière marquée : budget annoncé, même modèle pour tous les clubs, sauvegarde valide',()=>{
 const h=moteur(true);let S=h.lire('S');
 assert.equal(S.clubBudget.version,1);assert.equal(S.clubBudget.clubs.length,30);assert.ok(S.news.some(n=>/comblera|adhérents/.test(n)),'le propriétaire s’annonce en début de saison');
 assert.ok(S.clubBudget.prevision.recettesPrevues>5e6&&S.clubBudget.prevision.proprietaire.libelle);assert.equal(h.run('validateCareer(S);true'),true);
 const R=B.recettes(S.clubs.map(c=>({id:c.id,division:c.id<14?'elite':'accession',base:c.base}))),avant=S.clubs.map(c=>c.cash);
 h.semaine();S=h.lire('S');
 const titres=S.ledger.map(e=>e.title.split(' · ').pop());for(const t of ['Abonnements','Versement de la ligue','Cotisations','Staff et fonctionnement'])assert.ok(titres.includes(t),t);
 assert.equal(S.clubs[29].cash-avant[29],S.ledger.reduce((s,e)=>s+e.amount,0));assert.equal(S.clubBudget.semaines,1);
 for(const c of S.clubs){const d=c.cash-avant[c.id];assert.ok(Math.abs(d)<R.get(c.id)*0.03,'club '+c.id+' : une semaine ne pèse pas plus de 3 % des recettes annuelles ('+d+')');
  assert.ok(S.clubBudget.clubs[c.id].recettes>0&&S.clubBudget.clubs[c.id].salaires>0,'compteur du club '+c.id);}
 const total=S.clubs.reduce((s,c)=>s+c.cash-avant[c.id],0);assert.ok(Math.abs(total)<30*150000,'les 30 clubs ne s’enrichissent pas en bloc : '+total);
 assert.equal(h.run('validateCareer(S);true'),true);assert.equal(h.run('validateCareer(JSON.parse(JSON.stringify(S)));true'),true,'la sauvegarde relue passe la validation');
});
test('Moteur, carrière marquée : la vente d’un joueur crédite la caisse et entre dans la prévision',()=>{
 const h=moteur(true),avant=h.lire('({nous:club().cash,eux:S.clubs[1].cash})');
 h.run("const vendu=club().players[20];S.economy.offers.push({id:'offre-test',playerId:vendu.id,buyer:1,fee:300000,expires:S.economy.week+3});");
 assert.equal(h.run("acceptSale('offre-test')"),true);const S=h.lire('S');
 assert.equal(S.clubs[29].cash,avant.nous+300000);assert.equal(S.clubs[1].cash,avant.eux-300000);assert.ok(/^Vente : /.test(S.ledger[0].title)&&S.ledger[0].amount===300000);
 h.semaine();assert.equal(h.lire('S.clubBudget.prevision.horsBudget'),300000);
});
test('Moteur, carrière marquée : la fin de saison remplace les 2,5 M€ par prime, sanction et apport',()=>{
 const h=moteur(true);h.semaine();
 // Fin de saison simulée : classement archivé, le club joué finit 9e avec 800 000 € de pertes.
 h.run("S.franceMode.yearbook.push({season:1,standings:{elite:S.franceMode.leagues.elite.members.slice(),accession:[14,15,16,17,18,19,20,21,29,22,23,24,25,26,27,28]}});S.season=2;club().cash=S.clubBudget.clubs[29].depart-800000;S.clubs[14].cash=S.clubBudget.clubs[14].depart-9000000;S.trust=70;S.clubBudget.clubs.forEach((c,i)=>{c.recettes=i<14?40e6:12e6;});");
 const avant=h.lire('({comptes:S.clubBudget.clubs,cash:S.clubs.map(c=>c.cash)})'),prime=B.primeClassement('accession',9,16);
 h.run("ledgerEntry('Financement de début de saison',2500000)");let S=h.lire('S');
 assert.ok(!S.ledger.some(e=>e.amount===2500000),'plus de versement identique pour tous');
 const apport=Math.min(avant.comptes[29].enveloppe,800000-prime);
 assert.deepEqual(S.ledger.slice(0,apport>0?2:1).map(e=>e.amount).sort((a,b)=>a-b),(apport>0?[prime,apport]:[prime]).sort((a,b)=>a-b));
 if(apport>0)assert.equal(S.ledger[0].title,'Apport du propriétaire');
 assert.equal(S.clubs[29].cash,avant.cash[29]+prime+apport);
 assert.equal(S.clubs[14].cash,avant.cash[14]+B.primeClassement('accession',1,16)+avant.comptes[14].enveloppe,'un club géré très déficitaire reçoit sa prime et toute l’enveloppe, rien de plus');
 assert.ok(S.clubs.every(c=>c.cash-avant.cash[c.id]<avant.comptes[c.id].enveloppe+3e6),'personne ne reçoit 2,5 M€ d’office en plus de sa prime');
 h.run('worldNewSeason()');S=h.lire('S');
 assert.equal(S.clubBudget.saison,2);assert.equal(S.clubBudget.semaines,0);assert.equal(S.clubs[14].cash,0,'le découvert d’un club géré devient une dette');assert.ok(S.worldManagement.clubInfo[14].debt>0);
 assert.ok(S.news.filter(n=>/comblera|adhérents/.test(n)).length>=2,'nouvelle annonce du propriétaire pour la saison 2');
 assert.equal(S.clubBudget.clubs[29].depart,S.clubs[29].cash);
});
test('Moteur, carrière marquée : des comptes illisibles dans une sauvegarde sont rouverts, sans arrêt du jeu',()=>{
 for(const casse of ["S.clubBudget.clubs.pop()","S.clubBudget.clubs[3].type='inconnu'","S.clubBudget.clubs[29].recettes=null","delete S.clubBudget","S.clubBudget.alertes=7"]){
  const h=moteur(true);h.run(casse);h.semaine();const b=h.lire('S.clubBudget');
  assert.equal(b.clubs.length,30,casse);assert.equal(b.semaines,1,casse);assert.ok(Number.isFinite(b.prevision.resultatPrevu),casse);assert.equal(h.run('validateCareer(S);true'),true);
 }
});
