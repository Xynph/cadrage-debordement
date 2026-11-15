'use strict';
// Hiérarchie et pénalités du moteur complet sur de vrais effectifs Monde (docs/hierarchie-penalites-20261114.md).
// Carrière world-champ (graine fixe, club humain 102, hors des clubs joués ici). Deux séries de rencontres
// créées comme un match de championnat (createRugbyMatch + advanceRugby, sélection de l'IA, condition 100) :
// - Top 14 contre Top 14 (paires tirées, domicile au premier tiré) : avantage du terrain, pénalités, points ;
// - Top 14 contre Nationale (grand écart de niveau, domicile alterné) : le favori gagne nettement, des surprises restent.
// Bornes statistiques larges (aucun score exact attendu) : la graine fixe rend le test reproductible, et les
// bornes tiennent aussi avec des effectifs plus étagés (barème des notes V2).
const test = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');

const VM = String.raw`globalThis.__hp=function(o){
 const date=(S.worldMode.fixtures.find(f=>f.week===S.round)||S.worldMode.fixtures[0]).date,out=[];
 const membres=c=>S.worldMode.leagues[c].members.filter(i=>i!==S.club);
 const A=membres(o.a),B=membres(o.b);
 for(let i=0;i<o.n;i++){
  const x=A[Math.floor(Math.random()*A.length)];let y;do y=B[Math.floor(Math.random()*B.length)];while(y===x);
  const pair=o.alterne&&i%2?[y,x]:[x,y];
  for(const ci of pair)for(const p of S.clubs[ci].players)p.condition=100;
  const f={id:'hp-'+i,week:S.round,date,homeId:pair[0],awayId:pair[1],competitionId:'elite',phase:'league',round:1,neutral:false};
  S.worldMode.fixtures.push(f);
  try{
   const l=createRugbyMatch(pair,null,true),niveau=[teamLevel(activePlayers(l,0)),teamLevel(activePlayers(l,1))],melee=[unit(l,0,'scrum',p=>p.fam<=2),unit(l,1,'scrum',p=>p.fam<=2)];
   const aw=awardPenalty,phases={},meleePour=[0,0];
   awardPenalty=function(m,side,opt){if(m===l){const k=opt?.phase||'jeu';phases[k]=(phases[k]||0)+1;if(k==='melee')meleePour[side]++}return aw.apply(this,arguments)};
   try{for(let k=0;!l.finished&&k<700;k++){l.paused=false;advanceRugby(l)}}finally{awardPenalty=aw}
   out.push({niveau,melee,meleePour,phases,score:l.score.slice(),tries:l.tries.slice(),pen:l.stats.map(s=>s.penalties),buts:l.stats.map(s=>s.goals),tirs:l.stats.map(s=>s.goalAttempts),version:l.penalitesVersion})}
  finally{S.worldMode.fixtures.splice(S.worldMode.fixtures.indexOf(f),1)}}
 return JSON.stringify(out)};`;

const moy = a => a.reduce((x, y) => x + y, 0) / a.length;
const gagne = (m, s) => m.score[s] > m.score[1 - s] ? 1 : m.score[s] === m.score[1 - s] ? 0.5 : 0;

test('Hiérarchie et pénalités sur de vrais effectifs Monde (moteur complet)', { timeout: 600000 }, () => {
  const h = context(20261114, { console: false });
  try {
    h.start(102);
    assert.equal(h.run('CDWorldEditions.forState(S).mode'), 'world-champ');
    h.run(VM);
    const meme = JSON.parse(h.run('__hp({a:"elite",b:"elite",n:200,alterne:false})', 1800000));
    const ecart = JSON.parse(h.run('__hp({a:"elite",b:"nationale",n:120,alterne:true})', 1800000));
    const tous = meme.concat(ecart);
    assert.ok(tous.every(m => m.version === 1), 'rencontres créées avec les pénalités réalistes');

    // Pénalités : ~20 sifflées par match (réel), réparties entre jeu courant, faute de l'attaquant, mêlée et touche.
    const sifflees = moy(meme.map(m => m.pen[0] + m.pen[1]));
    const phase = k => moy(meme.map(m => m.phases[k] || 0));
    const points = moy(meme.map(m => m.score[0] + m.score[1])), essais = moy(meme.map(m => m.tries[0] + m.tries[1]));
    const partPen = moy(meme.map(m => 3 * (m.buts[0] + m.buts[1]))) / points;
    const reussite = meme.reduce((a, m) => a + m.buts[0] + m.buts[1], 0) / meme.reduce((a, m) => a + m.tirs[0] + m.tirs[1], 0);
    console.log(JSON.stringify({ sifflees: +sifflees.toFixed(1), jeu: +phase('jeu').toFixed(1), attaque: +phase('attaque').toFixed(1), melee: +phase('melee').toFixed(1), touche: +phase('touche').toFixed(1),
      points: +points.toFixed(1), essais: +essais.toFixed(2), partPen: +(100 * partPen).toFixed(1), reussite: +(100 * reussite).toFixed(1) }));
    assert.ok(sifflees >= 15 && sifflees <= 25, `pénalités sifflées par match : ${sifflees.toFixed(1)}`);
    assert.ok(phase('jeu') >= 7 && phase('attaque') >= 1.5 && phase('melee') >= 1.5 && phase('touche') >= 0.5, 'quatre origines de pénalité');
    assert.ok(points >= 40 && points <= 62, `points par match en Top 14 : ${points.toFixed(1)}`);
    assert.ok(essais >= 4.6 && essais <= 7.2, `essais par match en Top 14 : ${essais.toFixed(2)}`);
    assert.ok(partPen >= 0.17 && partPen <= 0.36, `part des points sur pénalité : ${(100 * partPen).toFixed(1)} %`);
    assert.ok(reussite >= 0.62 && reussite <= 0.86, `réussite au but sur pénalité : ${(100 * reussite).toFixed(1)} %`);
    // La mêlée dominante obtient plus de pénalités de mêlée que l'autre.
    const domine = tous.filter(m => Math.abs(m.melee[0] - m.melee[1]) >= 2);
    const pourDominant = domine.reduce((a, m) => a + m.meleePour[m.melee[0] > m.melee[1] ? 0 : 1], 0), totalMelee = domine.reduce((a, m) => a + m.meleePour[0] + m.meleePour[1], 0);
    assert.ok(totalMelee > 50 && pourDominant / totalMelee > 0.55, `pénalités de mêlée au pack dominant : ${pourDominant}/${totalMelee}`);

    // Avantage du terrain entre clubs du même championnat : net, sans être écrasant.
    const domicile = moy(meme.map(m => gagne(m, 0)));
    assert.ok(domicile >= 0.52 && domicile <= 0.8, `victoires à domicile en Top 14 : ${(100 * domicile).toFixed(1)} %`);

    // Grand écart de niveau : le favori gagne nettement, à domicile comme à l'extérieur, mais pas toujours.
    const favori = ecart.map(m => gagne(m, m.niveau[0] >= m.niveau[1] ? 0 : 1));
    const ext = ecart.filter(m => m.niveau[1] > m.niveau[0]).map(m => gagne(m, 1));
    const ecartMoyen = moy(ecart.map(m => Math.abs(m.niveau[0] - m.niveau[1])));
    console.log(JSON.stringify({ ecartMoyen: +ecartMoyen.toFixed(1), favori: +(100 * moy(favori)).toFixed(1), favoriExterieur: +(100 * moy(ext)).toFixed(1), surprises: favori.filter(v => v < 1).length, domicile: +(100 * domicile).toFixed(1) }));
    assert.ok(ecartMoyen >= 5, `écart de niveau Top 14 / Nationale : ${ecartMoyen.toFixed(1)}`);
    assert.ok(moy(favori) >= 0.75 && moy(favori) <= 0.995, `victoires du favori : ${(100 * moy(favori)).toFixed(1)} %`);
    assert.ok(moy(ext) >= 0.6, `victoires du favori à l'extérieur : ${(100 * moy(ext)).toFixed(1)} %`);
    assert.ok(favori.some(v => v < 1), 'au moins une surprise');

    // Pente : sur toutes les rencontres, plus l'écart de niveau est grand, plus le favori gagne (logistique, terrain compris).
    let a = 0, b = 0;
    const pts = tous.map(m => [m.niveau[0] - m.niveau[1], gagne(m, 0)]);
    for (let it = 0; it < 3000; it++) { let ga = 0, gb = 0; for (const [x, y] of pts) { const p = 1 / (1 + Math.exp(-(a * x + b))); ga += (y - p) * x; gb += y - p; } a += 0.01 * ga / pts.length; b += 0.5 * gb / pts.length; }
    console.log(JSON.stringify({ pente: +a.toFixed(3), terrain: +b.toFixed(2) }));
    assert.ok(a >= 0.08 && a <= 0.45, `pente par point de niveau : ${a.toFixed(3)}`);
  } finally { h.close(); }
});
