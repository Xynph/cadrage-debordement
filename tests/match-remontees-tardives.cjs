'use strict';
// Remontées tardives (docs/remontees-tardives-20261127.md) : une équipe menée de 11 à 14 points à la 75e finit à 7 points
// ou moins de l'adversaire dans 20 à 25 % des matchs réels. L'équipe qui mène de deux scores défend regroupée sur toute
// action adverse en fin de match (DEFENSE_REGROUPEE.deuxScores, dist/tactical-plans.js) ; le hasard reste.
// Méthode : de vrais matchs IA contre IA (carrière Monde, Top 14 et URC, graines fixes) sont figés à la 75e ; le score est
// fixé (une équipe mène de 3 à 14 points) et chaque situation est rejouée jusqu'au coup de sifflet final avec des tirages
// fixes, une fois avec les réglages du jeu, une fois sans la défense regroupée à deux scores. Mêmes tirages : la différence
// ne vient que d'elle.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');

const MATCHS = 40, REJEUX = 40;
const ECARTS = [3, 6, 9, 11, 12, 13, 14];

function mesurer(comp, graine) {
  const h = context(graine, { club: 102, console: false });
  try {
    return JSON.parse(h.run(`(()=>{
     const fx=S.worldMode.fixtures.filter(f=>f.competitionId==='${comp}'&&f.phase==='league'&&f.homeId!==S.club&&f.awayId!==S.club);
     const tirages=s=>()=>{s|=0;s=s+0x6D2B79F5|0;let t=Math.imul(s^s>>>15,1|s);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296};
     const reel=Math.random,D=DEFENSE_REGROUPEE,E=${JSON.stringify(ECARTS)},fige=[];
     try{
      for(let i=0;i<${MATCHS};i++){const f=fx[(i*7)%fx.length];S.round=f.week;const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);
       Math.random=tirages(1000+i);const l=createRugbyMatch(pair,null,true);if(typeof initPilotageIA==='function')initPilotageIA(l,f);
       for(let k=0;!l.finished;k++){if(k>5000)throw Error('boucle');l.paused=false;advanceRugby(l);if(matchMinute(l)>=75){fige.push(JSON.stringify(l));break}}}
      const jouer=neutre=>{DEFENSE_REGROUPEE=neutre?{...D,deuxScores:null}:D;const r={};
       try{fige.forEach((txt,i)=>{for(let j=0;j<${REJEUX};j++){Math.random=tirages(7919*i+31*j+5);const c=JSON.parse(txt),ec=E[j%E.length],mene=(i+j)%2,base=Math.min(c.score[0],c.score[1]);
        c.score[mene]=base+ec;c.score[1-mene]=base;
        for(let k=0;!c.finished;k++){if(k>5000)throw Error('boucle de fin');c.paused=false;advanceRugby(c)}
        const x=r[ec]=r[ec]||{n:0,proches:0,fins:[]};x.n++;const fin=c.score[mene]-c.score[1-mene];if(Math.abs(fin)<=7)x.proches++;x.fins.push(fin)}})}
       finally{DEFENSE_REGROUPEE=D}
       return r};
      return JSON.stringify({figes:fige.length,jeu:jouer(false),neutre:jouer(true)});
     }finally{Math.random=reel}})()`));
  } finally { h.close(); }
}

const part = (r, ecarts) => { let n = 0, p = 0; for (const e of ecarts) { n += r[e].n; p += r[e].proches; } return { n, taux: 100 * p / n }; };

test('Remontées tardives : menée de 11 à 14 points à la 75e, une équipe revient moins souvent à 7 points ou moins, sans que les fins serrées changent',{ timeout: 900000 }, () => {
  const tous = { jeu: [], neutre: [] };
  for (const [comp, graine] of [['elite', 7], ['elite', 4242], ['urc', 7]]) {
    const r = mesurer(comp, graine);
    assert.equal(r.figes, MATCHS, `${comp}/${graine} : tous les matchs atteignent la 75e`);
    const jeu = part(r.jeu, [11, 12, 13, 14]), neutre = part(r.neutre, [11, 12, 13, 14]);
    console.log(`${comp} graine ${graine} : remontées ${jeu.taux.toFixed(1)} % (sans défense regroupée à deux scores ${neutre.taux.toFixed(1)} %, ${jeu.n} fins)`);
    // Écart de moins de deux scores à la 75e : la défense regroupée à deux scores n'entre en jeu que si le meneur creuse
    // l'écart ensuite ; les fins serrées restent aussi fréquentes (à 3 points près).
    const petitJeu = part(r.jeu, [3, 6, 9]), petitNeutre = part(r.neutre, [3, 6, 9]);
    console.log(`  menée de 3 à 9 : ${petitJeu.taux.toFixed(1)} % de fins à 7 points ou moins (sans : ${petitNeutre.taux.toFixed(1)} %)`);
    assert.ok(Math.abs(petitJeu.taux - petitNeutre.taux) <= 3, `${comp}/${graine} : menée de 3 à 9 à la 75e, fins serrées changées : ${petitJeu.taux.toFixed(1)} contre ${petitNeutre.taux.toFixed(1)} %`);
    tous.jeu.push(jeu); tous.neutre.push(neutre);
  }
  const total = l => { const n = l.reduce((s, x) => s + x.n, 0); return { n, taux: l.reduce((s, x) => s + x.taux * x.n, 0) / n }; };
  const jeu = total(tous.jeu), neutre = total(tous.neutre);
  console.log(`Ensemble : ${jeu.taux.toFixed(1)} % (sans : ${neutre.taux.toFixed(1)} %) sur ${jeu.n} fins`);
  // Échelle de ce banc (IA contre IA, effectifs au complet en début de saison) : plus basse que la saison Monde complète.
  // Mesures du 27/11 : ici 27 % sur main et 19 % avec la défense regroupée à deux scores ; IA contre IA (3 × 600 matchs),
  // Top 14 25 → 17 %, URC 30 → 21 % ; en saison Monde, main 34 % (réel Top 14 20-25 %). Bornes avec marge ; le hasard reste (jamais de score figé).
  assert.ok(jeu.taux <= 21, `menée de 11 à 14 à la 75e, retour à 7 points ou moins trop fréquent : ${jeu.taux.toFixed(1)} % (21 % au plus sur ce banc)`);
  assert.ok(jeu.taux >= 10, `retour au score devenu trop rare : ${jeu.taux.toFixed(1)} % (10 % au moins sur ce banc)`);
  for (const x of tous.jeu) assert.ok(x.taux >= 8 && x.taux <= 26, `championnat ou graine hors de la fourchette : ${x.taux.toFixed(1)} %`);
  assert.ok(neutre.taux - jeu.taux >= 6, `la défense regroupée à deux scores doit peser : ${jeu.taux.toFixed(1)} contre ${neutre.taux.toFixed(1)} %`);
});
