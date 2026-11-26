'use strict';
// Fautes de main et avantage (audit du 27/11/2026, docs/fautes-main-avantage-20261127.md) : 300 matchs de championnat
// (Top 14, Premiership, URC, carrière Monde, vrai moteur) ; ce que le joueur lit doit suivre la loi et les ordres de
// grandeur du rugby d'élite.
//  1. deux récupérations de suite à la même minute : la seconde raconte une relance immédiate (« Ballon aussitôt rendu »),
//     pas une récupération sortie de nulle part ;
//  2. avantage sur en-avant ou passe en avant : la faute est racontée juste avant, par l'autre équipe ;
//  3. avantage non obtenu (loi 7) : retour à la mêlée (faute de main) ou à la pénalité, joué par l'équipe annoncée ;
//  4. renvoi repris par l'équipe qui botte : « Renvoi court » ;
//  5. fréquences par match dans les fourchettes de l'élite (en-avants, passes en avant, mêlées, coups francs, avantages,
//     renvois aux 22 m et sur la ligne, jaunes).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { worldYouth } = require('./helpers/youth-world-harness.cjs');

const PAR_CHAMPIONNAT = Number(process.env.CD_FAUTES_MAIN_MATCHS) || 100;
const CHAMPIONNATS = ['elite', 'prem', 'urc'];
const BRUIT = new Set(['card', 'sub', 'tactic', 'message']);

function simuler(comp, nombre) {
  const matchs = [];
  for (let monde = 0; matchs.length < nombre; monde++) {
    const t = worldYouth({ seed: 913571 + monde * 101, club: monde * 7 });
    const total = Number(t.run(`S.worldMode.fixtures.filter(f=>f.competitionId==='${comp}'&&f.phase==='league').length`));
    for (let i = 0; i < 42 && matchs.length < nombre; i++) {
      matchs.push(JSON.parse(t.run(`(()=>{const f=S.worldMode.fixtures.filter(f=>f.competitionId==='${comp}'&&f.phase==='league')[(${i}*7+${monde}*13)%${total}];S.round=f.week;
      const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);
      S.club=pair[0];const l=createRugbyMatch(pair,null,false);for(let n=0;!l.finished;n++){if(n>4000)throw Error('boucle');l.paused=false;advanceRugby(l)}
      return JSON.stringify({k:'${comp}:${matchs.length}',events:l.events.map(e=>({min:e.min,text:e.text,type:e.type,scene:e.scene&&{kind:e.scene.kind,team:e.scene.team,cause:e.scene.cause}})),stats:l.stats,abbr:pair.map(ci=>S.clubs[ci].abbr)});})()`)));
    }
  }
  return matchs;
}

let matchs = null;
const jouer = () => matchs || (matchs = CHAMPIONNATS.flatMap(c => simuler(c, PAR_CHAMPIONNAT)));
const precedent = (E, i) => { let j = i - 1; while (j >= 0 && BRUIT.has(E[j].type)) j--; return E[j] || null; };
const suivant = (E, i) => { let j = i + 1; while (j < E.length && BRUIT.has(E[j].type)) j++; return E[j] || null; };

test('Deux récupérations de suite : la seconde raconte la relance aussitôt perdue', { timeout: 1800000 }, () => {
  let cascades = 0; const fautes = [];
  for (const m of jouer()) m.events.forEach((e, i) => {
    if (e.type !== 'turnover' || !/ après le plaquage pour /.test(e.text)) return;
    const p = precedent(m.events, i);
    // Le porteur arrêté est de l'équipe qui venait de récupérer le ballon, à la même minute.
    if (!p || p.type !== 'turnover' || p.min !== e.min || p.scene?.team === e.scene?.team) return;
    cascades++;
    if (!/^Ballon aussitôt rendu : .* relance tout de suite mais est arrêté net : /.test(e.text)) fautes.push(`${m.k} [${i}] ${p.text} -> ${e.text}`);
  });
  assert.ok(cascades >= 15, `assez de récupérations enchaînées pour juger (${cascades})`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length}/${cascades} secondes récupérations sans relance racontée`);
});

test('Avantage sur en-avant ou passe en avant : la faute de l’autre équipe est racontée juste avant', { timeout: 1800000 }, () => {
  let n = 0; const fautes = [];
  for (const m of jouer()) m.events.forEach((e, i) => {
    const a = /^Avantage sur (en-avant|passe en avant) pour (\S+?)[.: ]/.exec(e.text);
    if (!a) return;
    n++;
    const p = precedent(m.events, i);
    const ok = p && p.scene?.kind === 'hand-fault' && (a[1] === 'en-avant' ? /un en-avant/.test(p.text) : /une passe en avant/.test(p.text)) && m.abbr[p.scene.team] !== a[2];
    if (!ok) fautes.push(`${m.k} [${i}] ${e.text} <- ${p ? p.text : 'rien'}`);
  });
  assert.ok(n >= 300 * 4, `assez d’avantages sur faute de main (${n})`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length}/${n} avantages sans faute racontée`);
});

test('Avantage non obtenu (loi 7) : retour à la mêlée ou à la pénalité, jouée par l’équipe annoncée', { timeout: 1800000 }, () => {
  const n = { mêlée: 0, pénalité: 0 }; const fautes = [];
  for (const m of jouer()) m.events.forEach((e, i) => {
    const r = /retour à la (pénalité|mêlée) pour (\S+)\.$/.exec(e.text);
    if (!r) return;
    n[r[1]]++;
    const s = suivant(m.events, i);
    if (!s) return;
    const equipe = m.abbr.indexOf(r[2]);
    const ok = equipe >= 0 && e.scene?.team === equipe && (r[1] === 'mêlée'
      ? (s.type === 'setup' && s.scene?.kind === 'scrum' && s.scene.team === equipe) || /^(Coup franc pour|Mi-temps|Coup de sifflet final)/.test(s.text)
      : s.scene?.team === equipe && s.type !== 'turnover');
    if (!ok) fautes.push(`${m.k} [${i}] ${e.text} -> ${s.type} ${s.text}`);
  });
  assert.ok(n['mêlée'] >= 300 && n['pénalité'] >= 300, `assez de retours d’avantage (${JSON.stringify(n)})`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length} retours d’avantage mal joués`);
});

test('Renvoi repris par l’équipe qui botte : « Renvoi court », jamais une réception ordinaire', { timeout: 1800000 }, () => {
  let repris = 0; const fautes = [];
  for (const m of jouer()) m.events.forEach((e, i) => {
    if (e.type !== 'restart') return;
    const r = m.events[i + 1];
    if (!r || r.scene?.kind !== 'reception') return;
    if (r.scene.team === e.scene?.team) { repris++; if (!/^Renvoi court/.test(r.text)) fautes.push(`${m.k} [${i + 1}] ${r.text}`); }
  });
  assert.ok(repris >= 60, `assez de renvois repris (${repris})`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length}/${repris} renvois repris racontés comme une réception`);
});

test('Fréquences par match dans les fourchettes de l’élite', { timeout: 1800000 }, () => {
  const c = {}; const add = (k, v = 1) => { c[k] = (c[k] || 0) + v; };
  const M = jouer();
  for (const m of M) {
    add('jaunes', m.stats[0].yellows + m.stats[1].yellows);
    for (const e of m.events) {
      const k = e.scene?.kind, t = e.text;
      if (/commet un en-avant/.test(t)) add('enAvants');
      if (/commet une passe en avant/.test(t)) add('passesAvant');
      if (e.type === 'setup' && k === 'scrum') add('melees');
      if (/^Coup franc pour/.test(t)) add('coupsFrancs');
      if (/^Avantage sur /.test(t)) add('avantages');
      if (/^(Avantage terminé|Essai ou points obtenus : avantage terminé)/.test(t)) add('avantagesObtenus');
      if (k === 'drop22') add('renvois22');
      if (k === 'goalLine') add('renvoisLigne');
    }
  }
  const p = k => (c[k] || 0) / M.length;
  const resume = Object.keys(c).map(k => `${k} ${p(k).toFixed(2)}`).join(', ');
  console.log(`  ${M.length} matchs, par match : ${resume}`);
  // Réel élite (docs/realite-matchs-20261125.md, docs/lois-manquantes-20261126.md) ; fourchettes larges : mesure, pas réglage.
  const fourchettes = { enAvants: [8, 20], passesAvant: [1.5, 4], melees: [10, 16], coupsFrancs: [2, 5.5], avantages: [8, 25], avantagesObtenus: [2, 10], renvois22: [0.7, 4], jaunes: [0.8, 1.9] };
  for (const [k, [a, b]] of Object.entries(fourchettes)) assert.ok(p(k) >= a && p(k) <= b, `${k} ${p(k).toFixed(2)} hors [${a}, ${b}] (${resume})`);
  assert.ok(p('renvois22') + p('renvoisLigne') >= 1.4, `renvois aux 22 m et sur la ligne ${(p('renvois22') + p('renvoisLigne')).toFixed(2)} (${resume})`);
});
