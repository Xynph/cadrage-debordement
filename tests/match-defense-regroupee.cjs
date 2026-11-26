'use strict';
// Défense regroupée en fin de match (DEFENSE_REGROUPEE, dist/tactical-plans.js ; docs/ia-decisions-match-20261126.md) :
// sur la touche gagnée après une pénaltouche et la séquence qui suit, à partir de la 70e, l'équipe qui mène défend sa ligne
// à quinze : le ballon porté est plus souvent arrêté (contestSetPiece, dist/rugby.js) et la finition dans les 22 plus dure
// (advanceCausalPlay, dist/restarts.js). Avant la 70e, ou quand la défense est menée, rien ne change.
// Méthode : un vrai match IA contre IA de Premiership (carrière Monde, graine fixe) est figé à la 65e et à la 78e ; chaque
// situation est rejouée N fois avec les mêmes tirages, une fois avec les réglages du jeu, une fois avec la défense regroupée
// neutralisée (porte et finition à 0). Mêmes tirages : la différence ne vient que de la défense regroupée.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');

const N = 1500;

function mesurer() {
  const h = context(4242, { club: 102, console: false });
  try {
    return JSON.parse(h.run(`(()=>{
     const fx=S.worldMode.fixtures.filter(f=>f.competitionId==='prem'&&f.phase==='league'&&f.homeId!==S.club&&f.awayId!==S.club),f=fx[3];
     S.round=f.week;const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);
     const l=createRugbyMatch(pair,null,true),fige={};
     for(let n=0;!l.finished&&!fige[78];n++){if(n>5000)throw Error('boucle');l.paused=false;advanceRugby(l);const m=matchMinute(l);
      for(const k of [65,78])if(!fige[k]&&m>=k&&m<k+1&&!l.finished){const c=JSON.parse(JSON.stringify(l));c.events=c.events.slice(-3);fige[k]=JSON.stringify(c)}}
     if(!fige[65]||!fige[78])throw Error('match sans 65e ou 78e');
     const reel=Math.random,D=DEFENSE_REGROUPEE;
     // Tirages fixes par essai (mulberry32) : les deux réglages voient exactement les mêmes nombres.
     const graine=s=>()=>{s|=0;s=s+0x6D2B79F5|0;let t=Math.imul(s^s>>>15,1|s);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296};
     // Équipe 0 à l'attaque (vers x = 100), score donné ; porte : touche sur pénalité à 5 m ; finition : temps de jeu dans les 22.
     function jouer(minute,score,phase,neutre){
      DEFENSE_REGROUPEE=neutre?{...D,porte:0,finition:0}:D;let essais=0,facteur=0;
      try{for(let i=0;i<${N};i++){Math.random=graine(7919*i+(phase==='porte'?1:2));const l=JSON.parse(fige[minute]);
       l.score=score.slice();l.paused=false;l.finished=false;l.possession=0;delete l.suitePenaltouche;if(l.flow){l.flow.advantage=null;l.flow.atBreak=false}const avant=l.tries[0];
       if(phase==='porte')grantSetPiece(l,'lineout',0,95,'penalty-touch',0);
       else{l.territory=82;l.kickContext={team:0,halfEligible:false,twentyTwoEligible:false};suitePenaltouche(l,0);facteur+=defenseRegroupee(l,0);advanceCausalPlay(l)}
       if(l.tries[0]>avant)essais++}}
      finally{Math.random=reel;DEFENSE_REGROUPEE=D}
      return {essais,facteur:facteur/${N}};
     }
     const out={};
     for(const [nom,minute,score] of [['fin-mene',78,[10,15]],['avant70-mene',65,[10,15]],['fin-menee',78,[15,10]]])
      for(const phase of ['porte','finition'])out[nom+':'+phase]={jeu:jouer(minute,score,phase,false),neutre:jouer(minute,score,phase,true)};
     return JSON.stringify(out)})()`));
  } finally { h.close(); }
}

test('Défense regroupée : après la 70e, la défense qui mène arrête plus de ballons portés et de fins d’action dans ses 22 ; sinon rien ne change', { timeout: 600000 }, () => {
  const r = mesurer();
  const taux = x => x.essais / N;
  console.log(JSON.stringify(Object.fromEntries(Object.entries(r).map(([k, v]) => [k, { jeu: +taux(v.jeu).toFixed(3), neutre: +taux(v.neutre).toFixed(3), facteur: +v.jeu.facteur.toFixed(2) }]))));
  // 78e, défense qui mène : effet à 0,8 (plein effet à la 80e).
  assert.ok(r['fin-mene:finition'].jeu.facteur >= 0.75, 'défense regroupée active à la 78e : ' + JSON.stringify(r['fin-mene:finition'].jeu));
  const porte = r['fin-mene:porte'], fin = r['fin-mene:finition'];
  assert.ok(taux(porte.neutre) - taux(porte.jeu) >= 0.03,
    `ballon porté sur pénaltouche plus souvent arrêté à la 78e : ${taux(porte.jeu).toFixed(3)} essai par touche contre ${taux(porte.neutre).toFixed(3)} sans défense regroupée`);
  assert.ok(taux(fin.neutre) - taux(fin.jeu) >= 0.05,
    `finition dans les 22 plus dure à la 78e : ${taux(fin.jeu).toFixed(3)} essai par temps de jeu contre ${taux(fin.neutre).toFixed(3)} sans défense regroupée`);
  // Avant la 70e, ou quand la défense est menée : mêmes tirages, mêmes essais.
  for (const nom of ['avant70-mene', 'fin-menee']) for (const phase of ['porte', 'finition']) {
    const x = r[nom + ':' + phase];
    assert.equal(x.jeu.essais, x.neutre.essais, `${nom} (${phase}) : la défense regroupée ne doit rien changer`);
    assert.equal(x.jeu.facteur, 0, `${nom} (${phase}) : défense regroupée inactive`);
  }
});
