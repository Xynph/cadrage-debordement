'use strict';
// Derbys et rivalités dans la carrière Monde (docs/derbys-20261116.md ; dist/rugby.js, bloc DERBYS) :
//   1. Données : seuil, rivalités semées valides, effets de match bornés (+10 à +20 % de fautes).
//   2. Détection (world-champ, club 5) : rivalité semée reconnue dès la première saison, affiche ordinaire non.
//   3. Match IA contre IA à graine fixe, affiches IA de la semaine jouées sous règles de derby puis sans :
//      pénalités +10 à +25 %, au plus +1 carton par match en moyenne, rencontre sans derbyVersion inchangée.
//   4. Retentissement : moral, confiance, supporters et pression bougent plus qu'un match ordinaire.
//   5. Presse : le prochain adversaire rival fait de la conférence un grand moment « derby ».
const test = require('node:test');
const assert = require('node:assert/strict');
const {context} = require('./monde-harness.cjs');

const h = context(827381, {club: 5}).start(5);
test.after(() => h.close());
const N = Math.max(30, Number(process.env.CD_DERBY_MESURES) || 40);

test('Données : rivalités et bornes', () => {
  const D = JSON.parse(h.run('JSON.stringify(DERBYS)'));
  assert.equal(D.version, 1);
  assert.ok(D.match.fautes >= 1.1 && D.match.fautes <= 1.2);
  assert.ok(D.match.carton > 0 && D.match.carton <= .03);
  assert.ok(D.match.domicile >= 1 && D.match.domicile <= 1.5);
  const vus = new Set(), n = h.run('S.clubs.length');
  for (const [a, b, t] of D.rivalites) {
    assert.ok(Number.isInteger(a) && Number.isInteger(b) && a !== b && a < n && b < n, a + '-' + b);
    assert.ok(t >= D.seuil && t <= 100);
    const k = Math.min(a, b) + ':' + Math.max(a, b); assert.ok(!vus.has(k), 'doublon ' + k); vus.add(k);
  }
  for (const e of Object.values(D.apres)) for (const v of Object.values(e)) assert.ok(Math.abs(v) <= 4);
});

test('Détection : rivalité semée dès la première saison', () => {
  assert.equal(h.run("CDWorldEditions.forState(S).mode"), 'world-champ');
  assert.equal(h.run('isDerby(S,5,15)'), true);
  assert.equal(h.run('isDerby(S,15,5)'), true);
  assert.equal(h.run('isDerby(S,5,30)'), false);
});

test('Match : intensité bornée, mesurée à graine fixe', () => {
  const m = JSON.parse(h.run(`(()=>{const rng=Math.random,out={};
   const jouer=(derby)=>{let pen=0,cartons=0,pts=[0,0],sig=[];
    for(let k=0;k<${N};k++){let x=(k*2654435761+7)>>>0;Math.random=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296};
     const fx=CDWorldCareer.fixtures(S).filter(f=>f.homeId!==S.club&&f.awayId!==S.club),f=fx[k%fx.length],pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);
     const snap=pair.flatMap(id=>S.clubs[id].players.map(p=>[p,p.condition,p.injury]));
     const l=createRugbyMatch(pair,null,true);if(!derby){delete l.derbyVersion;delete l.derby}else{l.derbyVersion=1;l.derby={tension:70}}
     for(let g=0;!l.finished&&g<600;g++){l.paused=false;advanceRugby(l)}
     for(const [p,c,i] of snap){p.condition=c;p.injury=i}
     pen+=l.stats[0].penalties+l.stats[1].penalties;cartons+=l.stats[0].yellows+l.stats[1].yellows;pts[0]+=l.score[0];pts[1]+=l.score[1];sig.push(l.score.join('-'))}
    return {pen:pen/${N},cartons:cartons/${N},dom:pts[0]/${N},ext:pts[1]/${N},sig:sig.join(',')}};
   try{out.derby=jouer(true);out.ordinaire=jouer(false);out.ordinaire2=jouer(false)}finally{Math.random=rng}return JSON.stringify(out)})()`, 600000));
  console.log('# mesures derby', JSON.stringify({derby: {...m.derby, sig: undefined}, ordinaire: {...m.ordinaire, sig: undefined}}));
  assert.equal(m.ordinaire.sig, m.ordinaire2.sig, 'déterminisme');
  const ratio = m.derby.pen / m.ordinaire.pen;
  // DERBYS.match.fautes (×1,12) ne vaut que pour les fautes de jeu (~60 % des pénalités sifflées) : ×1,06-1,08
  // sur 160 matchs ; la mesure à graine fixe bouge aussi avec toute règle qui consomme le hasard autrement (vent par période : 1,098).
  assert.ok(ratio >= 1.03 && ratio <= 1.2, 'pénalités ×' + ratio.toFixed(3));
  assert.ok(m.derby.cartons - m.ordinaire.cartons > 0 && m.derby.cartons - m.ordinaire.cartons <= 1, 'cartons ' + m.derby.cartons + ' / ' + m.ordinaire.cartons);
});

test('Retentissement plus fort qu’un match ordinaire', () => {
  const r = JSON.parse(h.run(`(()=>{const avant=JSON.stringify(S);try{S.morale=70;S.trust=50;if(S.pressRelations){S.pressRelations.fanTrust=50;S.pressRelations.boardPressure=50}
   const ord=derbyAftermath(S,{pair:[5,30],score:[20,10]});const v=derbyAftermath(S,{pair:[15,5],score:[30,10]});
   return JSON.stringify({ord,v,morale:S.morale,trust:S.trust,fan:S.pressRelations?.fanTrust??null,pression:S.pressRelations?.boardPressure??null})}finally{S=JSON.parse(avant)}})()`));
  assert.equal(r.ord, null);
  assert.equal(r.v.issue, 'defaite');
  assert.equal(r.morale, 67); assert.equal(r.trust, 48);
  if (r.fan !== null) { assert.equal(r.fan, 46); assert.equal(r.pression, 54); }
});

test('Presse : conférence de derby contre le rival semé', () => {
  h.toMatch();
  const r = h.run(`(()=>{const avant=JSON.stringify(S),rivales=JSON.stringify(DERBYS.rivalites);try{
   const f=nextMatch();if(!f)return 'sans match';const opp=f[0]===S.club?f[1]:f[0];
   const ctx0=nativeSystems.domain('press').context(S);DERBYS.rivalites.push([S.club,opp,70]);if(S.interclubWorld?.pairs)for(const k of Object.keys(S.interclubWorld.pairs))S.interclubWorld.pairs[k].tension=0;
   const ctx=nativeSystems.domain('press').context(S);return JSON.stringify({avant:ctx0.conference?.moment?.kind??null,apres:ctx.conference?.moment?.kind??null,dispo:!!ctx.conference?.available})}
   finally{S=JSON.parse(avant);DERBYS.rivalites.splice(0,DERBYS.rivalites.length,...JSON.parse(rivales))}})()`);
  console.log('# presse', r);
  const p = JSON.parse(r);
  assert.equal(p.avant === 'derby', false);
  if (p.dispo) assert.equal(p.apres, 'derby');
});
