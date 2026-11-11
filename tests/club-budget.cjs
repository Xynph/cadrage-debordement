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
