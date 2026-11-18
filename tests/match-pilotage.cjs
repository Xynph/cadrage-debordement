'use strict';
// Pilotage du match (dist/match-pilotage.js) en carrière Monde : arbitre, consignes en direct, causeries à effet réel,
// staff qui décide quand le match lui est confié. Les effets se mesurent sur des moyennes d'échantillon (mêmes graines
// pour chaque réglage), jamais sur le résultat exact d'un match.
const assert = require('node:assert/strict');
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');

const jeu = ouvrir({ hebdomadaire: true, testVm: true });
try {
  let m = jusquAuMatch(jeu, creer(jeu));
  if (m.selection?.errors?.length) m = jeu.call('auto_lineup');
  m = jeu.call('begin_match');
  const p = m.live.pilotage;
  assert.ok(p, 'pilotage projeté dans le match du joueur');
  assert.ok(p.arbitre.nom && p.arbitre.resume, 'arbitre nommé');
  for (const k of ['rucks', 'melee', 'horsJeu', 'cartons']) assert.ok(p.arbitre[k] >= 1 && p.arbitre[k] <= 5, k);
  assert.equal(p.axes.length, 5);
  assert.deepEqual(Object.values(p.consignes), ['normal', 'normale', 'normale', 'normal', 'normale']);

  // Causerie d'avant-match : six tons distincts, dont « Furieux » ; réaction visible et état pour le match.
  const scene = m.clubLife.matchTalks.scene;
  assert.equal(scene.phase, 'pre');
  assert.deepEqual(scene.options.map(o => o.tone).sort(), ['assertive', 'calm', 'demanding', 'furious', 'protective', 'warm']);
  const furieux = scene.options.find(o => o.tone === 'furious');
  assert.equal(furieux.toneLabel, 'Furieux');
  const ids = scene.participants.map(x => x.id);
  m = jeu.call('match_talk_decide', { key: scene.key, phase: 'pre', choiceId: furieux.id, audience: 'group', playerIds: [] });
  const d = m.clubLife.matchTalks.scene.decision;
  assert.equal(d.reactions.length, ids.length);
  const etats = new Set(d.reactions.map(x => x.etat));
  assert.ok(etats.size >= 2, 'les joueurs ne réagissent pas tous pareil : ' + [...etats]);
  assert.ok(d.reactions.every(x => x.label && x.score >= -3 && x.score <= 3));
  assert.equal(Object.keys(m.live.pilotage.joueurs).length, ids.length, 'état de chaque joueur dans le match');
  m = jeu.call('match_talk_continue', { key: scene.key, phase: 'pre' });
  const vm = jeu.bridge.vm;
  vm.run('globalThis.__base=JSON.stringify(S.live);');

  // Consignes sans pause, effet mesuré depuis le changement ; consigne inconnue refusée.
  assert.equal(jeu.brut('set_consignes', { axe: 'rucks', valeur: 'folle' }).ok, false);
  assert.equal(jeu.brut('set_consignes', { axe: 'tempo', valeur: 'rapide' }).ok, false);
  m = jeu.call('set_consignes', { axe: 'rucks', valeur: 'agressive' });
  assert.equal(m.live.pilotage.consignes.rucks, 'agressive');
  m = jeu.call('tick', { steps: 15 });
  const bilan = m.live.pilotage.bilans.find(b => b.axe === 'rucks');
  assert.ok(bilan && /^Rucks « Contester » depuis \d+′ : \d+ pénalités?, \d+ ballons? arrachés?\.$/.test(bilan.texte), bilan?.texte);

  // Effets moyens : mêmes graines, un seul réglage change. Le match repart du coup d'envoi.
  vm.run('globalThis.__live=JSON.stringify(S.live);');
  const mesurer = (reglage, n = 160) => JSON.parse(vm.run(`(()=>{const acc={pen:0,jaunes:0,arraches:0,coups:0,touches:0,touchesG:0,ecart:0,matchs:0};
    for(let i=0;i<${n};i++){S.live=JSON.parse(__base);const l=S.live;
      ${reglage}
      let k=0;while(!l.finished&&k++<400){l.paused=false;advanceRugby(l)}
      const u=l.userSide,o=1-u;acc.pen+=l.stats[u].penalties;acc.jaunes+=l.stats[u].yellows||0;acc.arraches+=l.tacticalStats?.[o]?.handErrors||0;
      acc.coups+=l.tacticalStats?.[u]?.kicks||0;acc.touches+=l.stats[u].lineouts;acc.touchesG+=l.stats[u].lineoutsWon;acc.ecart+=l.score[u]-l.score[o];acc.matchs++}
    for(const k of Object.keys(acc))if(k!=='matchs')acc[k]/=acc.matchs;return JSON.stringify(acc)})()`, 600000));
  const neutre = 'l.pilotage.consignes={piedJeu:"normal",rucks:"normale",discipline:"normale",rythme:"normal",touche:"normale"};l.pilotage.etats={};l.pilotage.arbitre={...l.pilotage.arbitre,rucks:3,melee:3,horsJeu:3,cartons:3};';
  const seed = s => `Math.random=(()=>{let x=${s};return()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296}})();`;
  // Une graine par match, identique d'un réglage à l'autre.
  const serie = reglage => mesurer(neutre + reglage + seed('(i*7919+17)>>>0'));
  const base = serie('');
  const agressif = serie('l.pilotage.consignes.rucks="agressive";');
  const prudent = serie('l.pilotage.consignes.rucks="prudente";');
  const strict = serie('l.pilotage.consignes.discipline="stricte";');
  const arbitreRucks = serie('l.pilotage.consignes.rucks="agressive";l.pilotage.arbitre.rucks=5;l.pilotage.arbitre.horsJeu=4;');
  const cartons = serie('l.pilotage.arbitre.cartons=5;');
  const pied = serie('l.pilotage.consignes.piedJeu="plus";');
  const garder = serie('l.pilotage.consignes.piedJeu="moins";');
  const toucheSure = serie('l.pilotage.consignes.touche="sure";');
  const galvanises = serie('for(const id of l.sheets[l.userSide].initial)l.pilotage.etats[id]={etat:"galvanise",phase:"pre"};');
  const vexes = serie('for(const id of l.sheets[l.userSide].initial)l.pilotage.etats[id]={etat:"vexe",phase:"pre"};');
  const r = x => Math.round(x * 100) / 100;
  console.log('pénalités concédées : base', r(base.pen), '· rucks agressifs', r(agressif.pen), '· prudents', r(prudent.pen), '· zéro faute', r(strict.pen), '· agressifs + arbitre pointilleux', r(arbitreRucks.pen), '· galvanisés', r(galvanises.pen), '· vexés', r(vexes.pen));
  console.log('ballons arrachés : base', r(base.arraches), '· agressifs', r(agressif.arraches), '· prudents', r(prudent.arraches));
  console.log('jaunes : base', r(base.jaunes), '· arbitre sévère', r(cartons.jaunes), '| coups de pied : base', r(base.coups), '· occuper', r(pied.coups), '· garder', r(garder.coups));
  console.log('touche gagnée : base', r(base.touchesG / base.touches), '· sûre', r(toucheSure.touchesG / toucheSure.touches), '| écart de score : base', r(base.ecart), '· galvanisés', r(galvanises.ecart), '· vexés', r(vexes.ecart));
  // Stats crédibles : un Top 14 se joue autour de 10 à 12 pénalités concédées par équipe (moteur actuel : ~13).
  assert.ok(base.pen > 7 && base.pen < 16, 'base crédible : ' + base.pen);
  assert.ok(agressif.pen > base.pen * 1.12 && agressif.arraches > base.arraches, 'rucks agressifs : plus de fautes et de ballons arrachés');
  assert.ok(prudent.pen < base.pen, 'rucks prudents : moins de fautes');
  assert.ok(strict.pen < base.pen * .9, 'zéro faute : nettement moins de pénalités');
  assert.ok(arbitreRucks.pen > agressif.pen, 'un arbitre pointilleux punit davantage les rucks agressifs');
  assert.ok(arbitreRucks.pen < 20, 'pas de score de fautes absurde : ' + arbitreRucks.pen);
  assert.ok(cartons.jaunes > base.jaunes, 'arbitre sévère : plus de cartons');
  assert.ok(pied.coups > base.coups && garder.coups < base.coups, 'jeu au pied suivi');
  assert.ok(toucheSure.touchesG / toucheSure.touches > base.touchesG / base.touches, 'lancer court plus sûr');
  assert.ok(galvanises.ecart > vexes.ecart + 2, 'l’état des joueurs pèse sur le match');
  assert.ok(vexes.pen > base.pen, 'des joueurs vexés concèdent plus de fautes');
  vm.run('S.live=JSON.parse(__live);delete globalThis.__base;delete globalThis.__live;');

  // Match confié au staff : il prend les causeries (mi-temps et après) et note ses changements de consignes.
  m = jeu.call('delegate');
  const recus = m.clubLife.matchTalks.receipts.slice(-3);
  assert.equal(m.live.finished, true);
  assert.ok(recus.some(x => x.status === 'delegated' && x.choiceId), 'le staff a prononcé une causerie');
  console.log('journal du staff :', m.live.pilotage.journal.map(x => x.minute + '′ ' + x.texte).join(' | ') || '(aucun changement)');
  const confiance = JSON.parse(vm.run('JSON.stringify(S.pilotage)'));
  assert.equal(confiance.version, 1);
  assert.ok(Object.keys(confiance.confiance).length >= 15, 'confiance envers le manager conservée');
  console.log('match-pilotage : OK');
} finally { jeu.fermer(); }
