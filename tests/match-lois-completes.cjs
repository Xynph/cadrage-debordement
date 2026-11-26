'use strict';
// Lois manquantes (docs/lois-manquantes-20261126.md) : matchs de Top 14 joués par le vrai moteur (carrière world-champ,
// harnais du monde, graine fixe), journal lu fait par fait.
// - fréquences par match proches du réel d'élite : coups francs (3-5), passes en avant (2-4), essais de pénalité
//   (~0,1), drops tentés (~0,2), mêlées accordées (12-15) et cartons jaunes (~1,3) ;
// - coup franc (loi 20) : jeu à la main ou coup de pied du bénéficiaire, jamais de tir au but ni de mêlée ; touche directe
//   depuis ses 22 : lancer adverse ;
// - essai de pénalité (loi 8) : 7 points sans transformation, carton jaune du fautif juste avant ;
// - passe en avant (loi 11) : mêlée adverse (ou avantage à l'adversaire) ;
// - drop : 3 points, surtout dans le dernier quart d'heure.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { worldYouth } = require('./helpers/youth-world-harness.cjs');

const N = 144, COMP = 'elite';
const BRUIT = new Set(['sub', 'tactic', 'card', 'advantage']);

function jouer(n) {
  const matchs = [];
  for (let monde = 0; matchs.length < n; monde++) {
    const t = worldYouth({ seed: 61126 + monde * 101, club: monde * 7 });
    const total = Number(t.run(`S.worldMode.fixtures.filter(f=>f.competitionId==='${COMP}'&&f.phase==='league').length`));
    for (let i = 0; i < 48 && matchs.length < n; i++) {
      matchs.push(JSON.parse(t.run(`(()=>{const f=S.worldMode.fixtures.filter(f=>f.competitionId==='${COMP}'&&f.phase==='league')[(${i}*7+${monde}*13)%${total}];
        S.round=f.week;const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);S.club=pair[0];
        const l=createRugbyMatch(pair,null,false);for(let n=0;!l.finished;n++){if(n>4000)throw Error('boucle');l.paused=false;advanceRugby(l)}
        return JSON.stringify({abbr:pair.map(id=>S.clubs[id].abbr),score:l.score,tries:l.tries,yellows:l.stats[0].yellows+l.stats[1].yellows,
          transfos:l.stats.map(s=>({c:s.conversions,a:s.conversionAttempts,pt:s.penaltyTries||0,panneau:statsPanel(l).includes((s.conversions-(s.penaltyTries||0))+' / '+(s.conversionAttempts-(s.penaltyTries||0)))})),
          events:l.events.map(e=>({min:e.min,type:e.type,text:e.text,s:e.scene?{kind:e.scene.kind,team:e.scene.team,cause:e.scene.cause,score:e.scene.score}:{}}))});})()`)));
    }
  }
  return matchs;
}

const matchs = jouer(N);
const suivant = (ev, j) => { let q = j + 1; while (q < ev.length && BRUIT.has(ev[q].type)) q++; return ev[q] || null; };
const scoreAvant = (ev, j) => { for (let q = j - 1; q >= 0; q--) if (ev[q].s.score) return ev[q].s.score; return [0, 0]; };

test('Fréquences par match : coups francs, passes en avant, essais de pénalité, drops, mêlées, jaunes', () => {
  const c = {}, add = (k, v = 1) => { c[k] = (c[k] || 0) + v; };
  for (const m of matchs) {
    add('jaunes', m.yellows);
    for (const e of m.events) {
      if (/^Coup franc pour /.test(e.text)) add('cf');
      if (e.s.kind === 'hand-fault' && e.s.cause === 'forward-pass') add('passes');
      if (e.type === 'try' && /^\S+ · Essai de pénalité/.test(e.text)) add('essaisPen');
      if (/ tente le drop /.test(e.text)) add('drops');
      if (e.type === 'setup' && e.s.kind === 'scrum') add('melees');
    }
  }
  const p = k => (c[k] || 0) / matchs.length;
  const bilan = Object.fromEntries(['cf', 'passes', 'essaisPen', 'drops', 'melees', 'jaunes'].map(k => [k, +p(k).toFixed(2)]));
  console.log('lois complètes, par match :', JSON.stringify(bilan), 'essais de pénalité', c.essaisPen || 0, 'drops', c.drops || 0);
  assert.ok(p('cf') >= 2.4 && p('cf') <= 5, 'coups francs par match (réel 3-5) : ' + JSON.stringify(bilan));
  assert.ok(p('passes') >= 1.8 && p('passes') <= 4.5, 'passes en avant par match (réel 2-4) : ' + JSON.stringify(bilan));
  assert.ok(c.essaisPen >= 3 && p('essaisPen') <= 0.25, 'essais de pénalité (réel 0,07-0,15 par match) : ' + JSON.stringify(bilan));
  assert.ok(p('drops') >= 0.08 && p('drops') <= 0.5, 'drops tentés (réel ~0,2 par match) : ' + JSON.stringify(bilan));
  assert.ok(p('melees') >= 11.2, 'mêlées accordées (Top 14 réel 12-15) : ' + JSON.stringify(bilan));
  assert.ok(p('jaunes') >= 0.9 && p('jaunes') <= 1.7, 'cartons jaunes (réel 1,1-1,5) : ' + JSON.stringify(bilan));
});

test('Coup franc : jeu à la main ou coup de pied, ni tir au but ni mêlée ; touche directe = lancer adverse', () => {
  const fautes = []; let vus = 0, touches = 0;
  for (const m of matchs) m.events.forEach((e, j) => {
    const r = /^Coup franc pour (\S+) : /.exec(e.text);
    if (!r) return;
    vus++;
    const side = m.abbr.indexOf(r[1]), suite = suivant(m.events, j);
    if (side < 0 || e.s.team !== side) { fautes.push('bénéficiaire : ' + e.text); return; }
    if (!suite) return;
    if (['goal', 'miss'].includes(suite.type) || /pénalité|poteaux|drop/i.test(suite.text)) fautes.push('tir au but sur coup franc : ' + suite.text);
    if (suite.type === 'setup') fautes.push('mêlée ou touche sur coup franc : ' + suite.text);
    if (!(suite.s.team === side && ['carry', 'touch', 'kick', 'ingoal'].includes(suite.s.kind))) fautes.push(`suite inattendue : ${e.text} -> ${suite.text}`);
    if (suite.s.kind === 'touch') {
      touches++;
      const lancer = suivant(m.events, m.events.indexOf(suite));
      if (lancer && lancer.type === 'setup' && lancer.s.kind === 'lineout' && lancer.s.team !== 1 - side) fautes.push('lancer au botteur du coup franc : ' + suite.text);
      if (suite.s.cause === '50-22') fautes.push('50:22 sur coup franc : ' + suite.text);
    }
  });
  assert.ok(vus >= 150 && touches >= 10, `assez de coups francs observés (${vus}, dont ${touches} en touche)`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length}/${vus} coups francs irréguliers`);
});

test('Essai de pénalité : 7 points sans transformation, carton jaune du fautif', () => {
  const fautes = []; let vus = 0;
  for (const m of matchs) m.events.forEach((e, j) => {
    if (!(e.type === 'try' && /Essai de pénalité/.test(e.text))) return;
    vus++;
    const side = e.s.team, avant = scoreAvant(m.events, j);
    if (!e.s.score || e.s.score[side] - avant[side] !== 7 || e.s.score[1 - side] !== avant[1 - side]) fautes.push('pas 7 points : ' + e.text);
    if (/transform/.test(e.text.replace('sans transformation', ''))) fautes.push('transformation : ' + e.text);
    const apres = m.events.slice(j + 1, j + 4).filter(x => !BRUIT.has(x.type));
    if (apres.some(x => /transform|poteaux/.test(x.text) || x.type === 'goal' || x.type === 'miss')) fautes.push('tir après l’essai de pénalité : ' + e.text);
    let q = j - 1; while (q >= 0 && m.events[q].type === 'card') q--;
    const cartons = m.events.slice(q + 1, j);
    if (!cartons.some(x => /^Carton (jaune|rouge)|carton rouge|second jaune/.test(x.text))) fautes.push('sans carton : ' + e.text);
    if (m.events[q]?.type !== 'penalty' || m.events[q].s.team !== side) fautes.push('sans faute sifflée juste avant : ' + e.text);
  });
  // Statistiques du match vues par le joueur : transformations tentées = essais marqués hors essais de pénalité.
  for (const m of matchs) for (const side of [0, 1]) {
    const t = m.transfos[side], vusIci = m.events.filter(e => e.type === 'try' && /Essai de pénalité/.test(e.text) && e.s.team === side).length;
    if (t.pt !== vusIci) fautes.push(`compte des essais de pénalité ${t.pt} ≠ ${vusIci}`);
    if (t.a - t.pt !== m.tries[side] - vusIci) fautes.push(`transformations tentées affichées ${t.a - t.pt} pour ${m.tries[side] - vusIci} essais marqués`);
    if (!t.panneau) fautes.push('statistiques du match : transformations sans retrait des essais de pénalité');
  }
  assert.ok(vus >= 3, `assez d’essais de pénalité observés (${vus})`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length}/${vus} essais de pénalité irréguliers`);
});

test('Passe en avant : mêlée adverse, ou avantage à l’adversaire', () => {
  const fautes = []; let vus = 0, melees = 0;
  for (const m of matchs) m.events.forEach((e, j) => {
    if (!(e.type === 'play' && e.s.kind === 'hand-fault' && e.s.cause === 'forward-pass')) return;
    vus++;
    const fautif = e.s.team, adverse = m.abbr[1 - fautif], suite = suivant(m.events, j), avantage = m.events[j + 1];
    if (!/passe en avant/.test(e.text)) fautes.push('cause sans récit : ' + e.text);
    if (/ : introduction adverse\.$/.test(e.text)) {
      if (suite && suite.type === 'setup') { melees++; if (!(suite.s.kind === 'scrum' && suite.s.team === 1 - fautif)) fautes.push(`pas de mêlée adverse : ${e.text} -> ${suite.text}`); }
    } else if (!(avantage && (avantage.text === `Avantage sur passe en avant pour ${adverse}.` || /^Avantage sur passe en avant pour /.test(avantage.text) && avantage.text.includes(adverse) || /^Aucun avantage obtenu/.test(avantage.text)))) {
      fautes.push(`ni mêlée ni avantage adverse : ${e.text} -> ${avantage ? avantage.text : 'rien'}`);
    }
  });
  assert.ok(vus >= 150 && melees >= 50, `assez de passes en avant observées (${vus}, ${melees} mêlées directes)`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length}/${vus} passes en avant mal sanctionnées`);
});

test('Drop : 3 points, surtout en fin de match', () => {
  const fautes = []; let tentes = 0, reussis = 0, tard = 0;
  for (const m of matchs) m.events.forEach((e, j) => {
    if (/ tente le drop /.test(e.text)) { tentes++; if (e.min >= 60) tard++; }
    if (e.type === 'goal' && /Drop réussi/.test(e.text)) {
      reussis++;
      const side = e.s.team, avant = scoreAvant(m.events, j);
      if (!e.s.score || e.s.score[side] - avant[side] !== 3) fautes.push('pas 3 points : ' + e.text);
      if (!/ tente le drop /.test(m.events[j - 1]?.text || '')) fautes.push('drop réussi sans tentative : ' + e.text);
    }
  });
  assert.ok(tentes >= 8 && reussis >= 2, `assez de drops (${tentes} tentés, ${reussis} réussis)`);
  assert.ok(reussis / tentes >= 0.25 && reussis / tentes <= 0.75, `réussite crédible : ${reussis}/${tentes}`);
  assert.ok(tard / tentes >= 0.35, `drops surtout en fin de match : ${tard}/${tentes} après la 60e`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length} drops irréguliers`);
});
