'use strict';
// Leviers de redressement consultatifs (reprise de l'étude économie V2, PR #352/#353) : ce que le manager peut
// réellement changer d'ici la fin de saison, sans prêt, recette ni pénalité inventés, et sans rien débiter.
const assert=require('node:assert/strict');
const {test}=require('node:test');
const B=require('../native/engine/club-budget.cjs');
const base={reste:20,masseHebdo:200000};

test('Saison financée : aucun levier, sauf l’alerte des travaux qui la feraient basculer',()=>{
 const ok=B.leviers({...base,solde:500000,formationHebdo:12000});
 assert.equal(ok.etat,'serein');assert.equal(ok.manque,0);assert.deepEqual(ok.leviers,[],'rien à suspendre quand la saison est financée');
 const travaux=B.leviers({...base,solde:500000,devis:750000});
 assert.equal(travaux.etat,'vigilance');assert.equal(travaux.leviers.length,1);
 assert.deepEqual([travaux.leviers[0].cle,travaux.leviers[0].effet,travaux.leviers[0].risque],['installations',0,750000],'le devis n’est pas une économie : la prévision ne le compte pas');
 assert.equal(B.leviers({...base,solde:500000,devis:400000}).etat,'serein');
});

test('Manque couvert par les dépenses facultatives : suspendre la formation payée suffit',()=>{
 const r=B.leviers({...base,solde:-150000,formationHebdo:12000});
 assert.equal(r.etat,'facultatif');assert.equal(r.manque,150000);
 const f=r.leviers.find(l=>l.cle==='formation');assert.equal(f.effet,240000);assert.deepEqual(f.commande,{command:'club_academy_investment',amount:0});
 assert.ok(!r.leviers.some(l=>l.cle==='salaires'),'pas de départ demandé quand la formation suffit');
 assert.match(r.conclusion,/la caisse finira la saison à 150 000 € sous zéro/);
});

test('Dépenses facultatives insuffisantes : la masse salariale à libérer couvre exactement le reste',()=>{
 const r=B.leviers({...base,solde:-1e6,formationHebdo:4000,coutSalaire:1.4,objectif:'proprietaire'});
 assert.equal(r.etat,'effectif');
 const s=r.leviers.find(l=>l.cle==='salaires');assert.equal(s.effet,1e6-80000);
 assert.ok(r.salairesALiberer*20*1.4>=920000&&(r.salairesALiberer-100)*20*1.4<920000,'arrondi à la centaine au-dessus');
 assert.match(r.conclusion,/ce que le propriétaire comblera/);
 const grave=B.leviers({...base,solde:-5e6});
 assert.equal(grave.etat,'grave');assert.ok(grave.salairesALiberer>base.masseHebdo*0.25);
 const tard=B.leviers({...base,reste:0,solde:-5e5,formationHebdo:12000});
 assert.equal(tard.etat,'tard');assert.deepEqual(tard.leviers,[],'plus de semaine : plus de levier');
});

test('Amende de la ligue : repasser sous la limite l’efface et compte dans le redressement',()=>{
 const r=B.leviers({...base,solde:-600000,amende:500000,depassement:1e6,formationHebdo:12000});
 assert.deepEqual(r.leviers.map(l=>l.cle),['amende','formation']);assert.equal(r.etat,'facultatif');
 assert.match(r.leviers[0].titre,/1 M€ de masse annuelle en moins/);
});

test('Jamais d’argent créé ni d’entrée douteuse acceptée ; textes immersifs',()=>{
 for(const solde of [-3e6,-2e5,0,4e5])for(const formationHebdo of [0,4000,12000]){
  const r=B.leviers({...base,solde,formationHebdo,devis:600000,amende:solde<0?100000:0,depassement:200000});
  assert.ok(r.leviers.every(l=>Number.isFinite(l.effet)&&l.effet>=0&&!('pret' in l)&&!/prêt bancaire|subvention|fictif/i.test(l.titre+l.contrepartie)));
  assert.ok(r.leviers.reduce((s,l)=>s+l.effet,0)<=Math.max(r.manque,0)+formationHebdo*base.reste+100000+100,'les leviers ne promettent pas plus que leurs effets réels');
  assert.ok(!/fictif/i.test(r.conclusion));
 }
 assert.throws(()=>B.leviers({...base,solde:NaN}),/entrées invalides/);
 assert.throws(()=>B.leviers({...base,solde:0,objectif:'banque'}),/entrées invalides/);
 assert.throws(()=>B.leviers({...base,solde:0,coutSalaire:0}),/entrées invalides/);
});

// Carrière Monde (world-champ) : l'écran Finances lit les leviers dans la stratégie du club, sans rien modifier.
// Budget de saison réaliste (défaut des carrières Monde) : l'objectif est celui du propriétaire, la lecture ne touche à rien.
// Hors budget de saison (CD_SALAIRES_PAR_NIVEAU=0) : l'objectif est la caisse prévue, avec la billetterie moyenne restante.
const avecBudget=(valeur,fn)=>{const avant=process.env.CD_SALAIRES_PAR_NIVEAU;if(valeur===undefined)delete process.env.CD_SALAIRES_PAR_NIVEAU;else process.env.CD_SALAIRES_PAR_NIVEAU=valeur;
 try{return fn();}finally{if(avant===undefined)delete process.env.CD_SALAIRES_PAR_NIVEAU;else process.env.CD_SALAIRES_PAR_NIVEAU=avant;}};
test('Monde, budget de saison réaliste (défaut) : leviers lus sur la prévision, objectif du propriétaire, sans mutation',()=>{
 const {context}=require('./monde-harness.cjs');
 avecBudget(undefined,()=>{
  const h=context();
  try{
   h.start(0);
   assert.ok(h.run('!!S.startingSalaries'),'carrière marquée par défaut');
   const finance=()=>JSON.parse(h.run("JSON.stringify(nativeSystems.domain('clubStrategy').project().finance)"));
   const avant=h.run('JSON.stringify(S)'),graine=h.seed(),f=finance();
   assert.equal(h.run('JSON.stringify(S)'),avant,'lire les leviers ne touche pas la carrière');assert.equal(h.seed(),graine,'ni le tirage aléatoire');
   assert.ok(f.levers&&['serein','vigilance','facultatif','effectif','grave','tard'].includes(f.levers.etat));
   assert.equal(f.levers.objectif,'proprietaire');
   h.run("S.careerManagement.academyInvestment=12000;club().players.forEach(p=>{p.salary*=4;});budgetPrevoir(budgetForces(),budgetRepere())");
   const tendu=finance(),formation=tendu.levers.leviers.find(l=>l.cle==='formation');
   assert.ok(tendu.levers.manque>0&&formation&&formation.effet===12000*tendu.remainingWeeks);
   h.run("club().players.forEach(p=>{p.salary/=4;});budgetPrevoir(budgetForces(),budgetRepere())");
   h.ctx.leviersPayload=JSON.stringify({...formation.commande,context:{season:h.run('S.season'),week:h.run("nativeSystems.domain('clubStrategy').project().context.week"),club:0},confirmed:true});
   h.run("nativeSystems.domain('clubStrategy').execute('club_academy_investment',JSON.parse(leviersPayload))");
   assert.equal(h.run('S.careerManagement.academyInvestment'),0,'le levier proposé correspond à une vraie décision du club');
  }finally{h.close();}
 });
});

test('Monde, hors budget de saison : leviers lus sur la prévision du club, sans mutation, commande de formation applicable',()=>{
 const {context}=require('./monde-harness.cjs');
 avecBudget('0',()=>{
 const h=context();
 try{
  h.start(0);
  const finance=()=>JSON.parse(h.run("JSON.stringify(nativeSystems.domain('clubStrategy').project().finance)"));
  const avant=h.run('JSON.stringify(S)'),graine=h.seed(),f=finance();
  assert.equal(h.run('JSON.stringify(S)'),avant,'lire les leviers ne touche pas la carrière');assert.equal(h.seed(),graine,'ni le tirage aléatoire');
  assert.ok(f.levers&&['serein','vigilance','facultatif','effectif','grave','tard'].includes(f.levers.etat));
  assert.equal(f.levers.objectif,'tresorerie');const recues=h.run('S.worldMode.fixtures.filter(x=>x.homeId===S.club&&!x.neutral&&x.week>=S.worldMode.week).length');
  assert.ok(recues>5);assert.equal(f.levers.solde,Math.round((f.baseForecast+375000*recues)/100)*100,'hors budget de saison : la caisse prévue, billetterie moyenne des réceptions restantes comprise');
  h.run("S.careerManagement.academyInvestment=12000;club().cash-=4e7");
  const tendu=finance(),formation=tendu.levers.leviers.find(l=>l.cle==='formation');
  assert.ok(tendu.levers.manque>0&&formation&&formation.effet===12000*tendu.remainingWeeks);
  assert.ok(tendu.levers.leviers.some(l=>l.cle==='salaires'),'une caisse à −40 M€ ne se redresse pas avec la seule formation');
  h.run("club().cash+=4e7");
  const ctx=finance();h.ctx.leviersPayload=JSON.stringify({...formation.commande,context:{season:h.run('S.season'),week:h.run("nativeSystems.domain('clubStrategy').project().context.week"),club:0},confirmed:true});
  h.run("nativeSystems.domain('clubStrategy').execute('club_academy_investment',JSON.parse(leviersPayload))");
  assert.equal(h.run('S.careerManagement.academyInvestment'),0,'le levier proposé correspond à une vraie décision du club');
  assert.ok(ctx.levers);
 }finally{h.close();}
 });
});
