'use strict';
// Fragilité physique (native/engine/fragilite.cjs ; décision de Léo du 22/11/2026, fenêtre blessure) : une valeur par
// joueur (0-100) tirée de la résistance cachée des vrais joueurs ou tirée à la création, enregistrée sur les
// carrières existantes, qui module de −25 % à +25 % les tirages de blessure (après match, séance intensive, incident
// de match) et de rechute ; envoyée à l'écran (squad[].fragilite, squad[].rechute des blessés).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { factory } = require('../native/engine/fragilite.cjs');

const f = factory();
f.installHooks();

test('Échelle : résistance 50 → 100, 76 → 0 ; facteur de 0,75 à 1,25, 1 au milieu', () => {
  assert.equal(f.valeur({ id: 'a', hiddenTraitsV2: { injuryResistance: 76 } }), 0);
  assert.equal(f.valeur({ id: 'a', hiddenTraitsV2: { injuryResistance: 50 } }), 100);
  assert.equal(f.valeur({ id: 'a', hiddenTraitsV2: { injuryResistance: 63 } }), 50);
  assert.equal(f.facteur({ id: 'a', hiddenTraitsV2: { injuryResistance: 76 } }), 0.75);
  assert.equal(f.facteur({ id: 'a', hiddenTraitsV2: { injuryResistance: 50 } }), 1.25);
  assert.equal(f.facteur({ id: 'a', hiddenTraitsV2: { injuryResistance: 63 } }), 1);
  assert.equal(globalThis.facteurFragilite, f.facteur);
  assert.equal(globalThis.valeurFragilite, f.valeur);
});

test('Joueurs créés : tirage stable par identifiant, réparti, enregistré par observe (ancienne carrière)', () => {
  const joueurs = Array.from({ length: 400 }, (_, i) => ({ id: 'cree:' + i }));
  const valeurs = joueurs.map(p => f.valeur(p));
  assert.deepEqual(joueurs.map(p => f.valeur(p)), valeurs, 'stable');
  assert.ok(Math.min(...valeurs) <= 10 && Math.max(...valeurs) >= 90, 'toute l’échelle');
  const moyenne = valeurs.reduce((a, b) => a + b, 0) / valeurs.length;
  assert.ok(moyenne > 40 && moyenne < 60, 'moyenne ' + moyenne);
  const vrai = { id: 'vrai', hiddenTraitsV2: { injuryResistance: 60 } };
  globalThis.S = { clubs: { 0: { players: [...joueurs.slice(0, 3), vrai] } }, economy: { freeAgents: [{ id: 'libre' }] }, market: [] };
  assert.equal(f.observe(), 4);
  assert.equal(vrai.fragilite, undefined, 'vrai joueur : la résistance des bases suffit');
  assert.equal(joueurs[0].fragilite, valeurs[0]);
  assert.equal(f.observe(), 0, 'déjà posée');
  joueurs[1].fragilite = 3;
  assert.equal(f.valeur(joueurs[1]), 3, 'valeur enregistrée prioritaire');
  assert.equal(f.validate(globalThis.S), true);
  joueurs[2].fragilite = 140;
  assert.throws(() => f.validate(globalThis.S), /Fragilité/);
  delete globalThis.S;
});

test('Tirages de blessure modulés par la fragilité (après match, séance intensive, incident, rechute)', () => {
  const lire = p => fs.readFileSync(path.join(__dirname, '..', p), 'utf8');
  assert.match(lire('dist/rugby.js'), /let risk=\(p\.condition<55\?\.07:\.025\)\*minutes\/80\*\(typeof facteurFragilite==='function'\?facteurFragilite\(p\):1\)/);
  assert.match(lire('dist/game.js'), /Math\.random\(\)<\.018\*\(typeof facteurFragilite==='function'\?facteurFragilite\(p\):1\)/);
  assert.match(lire('native/engine/incidents-match.cjs'), /kind==='blessure'&&typeof facteurFragilite==='function'/);
  assert.match(lire('native/engine/club-mail.cjs'), /relapseChance\(p\)/);
  // Effet mesuré sur la règle d'après match : 10 000 titulaires fragiles contre 10 000 solides, même condition.
  let graine = 7;
  const alea = () => ((graine = (graine * 1103515245 + 12345) % 2147483648) / 2147483648);
  const blessures = resistance => { let n = 0; for (let i = 0; i < 20000; i++) if (alea() < 0.025 * f.facteur({ id: 'x', hiddenTraitsV2: { injuryResistance: resistance } })) n++; return n; };
  const fragiles = blessures(50), solides = blessures(76);
  assert.ok(fragiles / solides > 1.4 && fragiles / solides < 2.0, 'rapport ' + fragiles / solides);
});

test('Rechute : le courrier applique la fragilité au risque choisi par le médecin', () => {
  globalThis.nativeClubMailData = require('../native/engine/club-mail.cjs').DATA;
  const mail = require('../native/engine/club-mail.cjs').factory();
  assert.equal(mail.blessures.rechute({ id: 'a', injuryRelapse: 20, hiddenTraitsV2: { injuryResistance: 50 } }), 25);
  assert.equal(mail.blessures.rechute({ id: 'a', injuryRelapse: 20, hiddenTraitsV2: { injuryResistance: 76 } }), 15);
});

test('Carrière Monde : fragilité et rechute envoyées à l’écran, posée sur les joueurs créés', { timeout: 600000 }, () => {
  const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  try {
    const model = creer(jeu);
    for (const p of model.squad) assert.ok(Number.isInteger(p.fragilite) && p.fragilite >= 0 && p.fragilite <= 100, p.name + ' : fragilité');
    assert.ok(new Set(model.squad.map(p => p.fragilite)).size > 5, 'valeurs variées');
    for (const p of model.squad) assert.equal(p.risqueBlessure, Math.round((p.condition < 55 ? 7 : 2.5) * (1 + (p.fragilite - 50) * 0.005) * 10) / 10, p.name + ' : risque au prochain match');
    const sans = JSON.parse(jeu.bridge.vm.run('JSON.stringify(Object.values(S.clubs).flatMap(c=>c.players).filter(p=>!Number.isFinite(p.hiddenTraitsV2?.injuryResistance)&&!Number.isInteger(p.fragilite)).length)'));
    assert.equal(sans, 0, 'chaque joueur créé a sa fragilité enregistrée');
    // Un blessé reçoit son risque de rechute (0 tant que le médecin n'a pas fixé de suivi).
    jeu.bridge.vm.run('(()=>{const p=S.clubs[S.club].players[0];p.injury=3;p.injuryRelapse=20;})()');
    const apres = jeu.call('set_player_load', { playerId: model.squad.find(p => !(p.injury > 0)).id, mode: 'repos' });
    const blesse = apres.squad.find(p => p.injury > 0 && p.rechute !== undefined);
    assert.ok(blesse, 'rechute envoyée pour un blessé');
    assert.ok(Number.isInteger(blesse.rechute) && blesse.rechute >= 0 && blesse.rechute <= 100);
  } finally { jeu.fermer(); }
});
