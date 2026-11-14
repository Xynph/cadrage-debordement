'use strict';
const assert=require('node:assert/strict'),{test}=require('node:test');
const {context}=require('./monde-harness.cjs');

// Carrière Monde réelle (world-champ) : une seule carrière par économie, chaque mesure repart du même état et RNG.
// Deux économies : l'ancienne (CD_SALAIRES_PAR_NIVEAU=0), où chaque club IA touche 80 000 € par victoire, et le budget
// réaliste, par défaut depuis le 13/11, où la prime de victoire n'existe plus (la ligue verse une prime de classement en
// fin de saison). La variable est lue à la création de la carrière.
function economie(drapeau){
 const avant=process.env.CD_SALAIRES_PAR_NIVEAU;
 if(drapeau===undefined)delete process.env.CD_SALAIRES_PAR_NIVEAU;else process.env.CD_SALAIRES_PAR_NIVEAU=drapeau;
 let h,base;
 try{h=context(52602);base=h.checkpoint();}
 finally{if(avant===undefined)delete process.env.CD_SALAIRES_PAR_NIVEAU;else process.env.CD_SALAIRES_PAR_NIVEAU=avant;}
 require('node:test').after(()=>h.close());
 return function finance(fixture){
  h.restore(base);
  h.ctx.fixture=fixture;
  h.run([
   'var ids=fixture.pair, initial=ids.map(id=>S.clubs[id].cash);',
   'worldWeeklyEconomy([fixture]);',
   'var delta=ids.map((id,i)=>S.clubs[id].cash-initial[i]);',
   'var repeat=worldWeeklyEconomy([fixture]);',
   'var final=ids.map((id,i)=>S.clubs[id].cash-initial[i]);'
  ].join('\n'));
  return {delta:Array.from(h.run('delta')),final:Array.from(h.run('final')),repeat:h.run('repeat'),seed:h.seed()};
 };
}
const draw={pair:[1,2],score:[18,18],phase:'league',competitionId:'elite',neutral:false};
const expected=new Map([[1,[80000,0]],[2,[0,80000]]]);

const ancienne=economie('0'),realiste=economie(undefined);

test('Monde (ancienne économie) : la prime d’un KO départagé au même score va au vrai vainqueur IA une seule fois',()=>{
 const reference=ancienne(draw);
 for(const winner of [1,2]){
  const record={...draw,phase:'semi',winner};
  const actual=ancienne(record);
  assert.deepEqual(actual.delta.map((d,i)=>d-reference.delta[i]),expected.get(winner));
  assert.equal(actual.repeat,false);
  assert.deepEqual(actual.final,actual.delta);
  assert.equal(actual.seed,reference.seed);
 }
});

test('Monde (ancienne économie) : une manche nulle du barrage Japon n’anticipe pas le résultat cumulé',()=>{
 const leg={...draw,phase:'promotion',competitionId:'jlo-d1-d2'};
 const reference=ancienne(leg);
 const actual=ancienne({...leg,score:[18,24]});
 assert.deepEqual(actual.delta.map((d,i)=>d-reference.delta[i]),[0,80000]);
});

// Budget réaliste : les recettes d'une semaine ne dépendent que de la phase, du lieu et de la forme ; aucune prime n'est
// versée au vainqueur d'un match (la prime de classement est créditée une fois, à la clôture de la saison). Le vainqueur d'un
// KO départagé au même score ne reçoit donc rien de plus que le perdant, et rien n'est payé deux fois.
test('Monde (budget réaliste) : un KO départagé au même score ne verse aucune prime de match, ni au vainqueur ni deux fois',()=>{
 const reference=realiste({...draw,phase:'semi'});
 for(const winner of [1,2]){
  const actual=realiste({...draw,phase:'semi',winner});
  assert.deepEqual(actual.delta,reference.delta,'La prime de match de l’ancienne économie (80 000 €) ne doit plus exister.');
  assert.equal(actual.repeat,false);
  assert.deepEqual(actual.final,actual.delta);
  assert.equal(actual.seed,reference.seed);
 }
});

test('Monde (budget réaliste) : une manche nulle du barrage Japon n’anticipe pas le résultat cumulé',()=>{
 const leg={...draw,phase:'promotion',competitionId:'jlo-d1-d2'};
 const reference=realiste(leg);
 const actual=realiste({...leg,score:[18,24]});
 assert.deepEqual(actual.delta,reference.delta,'Le score d’une manche ne crédite aucune prime au vainqueur de la manche.');
});
