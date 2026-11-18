'use strict';
// Le président fixe un objectif de classement au club géré, dans tout championnat, sans défi de départ ;
// un jalon de classement déjà fixé (défi) n'est pas remplacé ; l'objectif est reconduit à la saison suivante.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

const run = (jeu, code) => JSON.parse(jeu.bridge.vm.run(`JSON.stringify(${code})`));
const OBJECTIF = `(()=>{const b=S.nativeBoardCalendar,lid=CDWorldCareer.leagueId(S),n=S.worldMode.leagues[lid].members.length;
 return {league:lid,n,season:b?.season,rang:(b?.objectives||[]).filter(o=>o.type==='rank').map(o=>({id:o.id,target:o.target,deadline:o.deadline,status:o.status}))};})()`;

// Clubs de championnats différents (identifiants du catalogue de création) : Top 14, Pro D2, Premiership, URC.
for (const [nom, club] of [['Top 14', 20], ['championnat anglais', 60], ['URC', 90], ['club de 102', 102]]) {
  test(`${nom} : sans défi, le président fixe un objectif de classement réaliste`, () => {
    const jeu = M.ouvrir({ testVm: true });
    try {
      M.creer(jeu, club);
      const o = run(jeu, OBJECTIF);
      assert.equal(o.rang.length, 1, 'un objectif de classement : ' + JSON.stringify(o));
      assert.ok(o.rang[0].target >= 1 && o.rang[0].target <= o.n - 1, 'objectif dans le championnat : ' + JSON.stringify(o));
      assert.ok(o.rang[0].deadline > 0 && o.rang[0].status === 'pending');
      assert.equal(o.season, 1);
    } finally { jeu.fermer(); }
  });
}

test('Un jalon de classement déjà fixé n’est pas remplacé ; l’appel répété ne double rien', () => {
  const jeu = M.ouvrir({ testVm: true });
  try {
    M.creer(jeu, 102);
    const avant = run(jeu, OBJECTIF);
    assert.equal(run(jeu, 'nativeSystems.domain("clubStrategy").presidentObjective()'), false, 'déjà fixé : rien à faire');
    assert.deepEqual(run(jeu, OBJECTIF), avant);
  } finally { jeu.fermer(); }
});

test('Avec un défi de départ, c’est l’objectif du défi qui reste', () => {
  const jeu = M.ouvrir({ testVm: true });
  try {
    const d = JSON.stringify(jeu.brut('start_challenges', {})).match(/"id":"([a-z-]+)","titre"[^]*?"club":(\d+)/);
    assert.ok(d, 'un défi proposé');
    jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: +d[2], start: 'premiers-clubs', varyCurrent: true, challenge: { id: d[1], club: +d[2] } }));
    const o = run(jeu, OBJECTIF);
    assert.equal(o.rang.length, 1);
    assert.ok(o.rang[0].id.startsWith('defi:'), 'objectif du défi conservé : ' + JSON.stringify(o));
  } finally { jeu.fermer(); }
});

test('Nouvelle saison : le président refixe un objectif (sans calendrier préalable ni défi)', () => {
  const jeu = M.ouvrir({ testVm: true });
  try {
    M.creer(jeu, 102);
    // Saison suivante simulée dans la machine : le calendrier de la saison 1 est remplacé comme à advanceSeason.
    jeu.bridge.vm.run('delete S.nativeBoardCalendar;S.season=2;');
    assert.equal(run(jeu, 'nativeSystems.domain("clubStrategy").presidentObjective()'), true);
    const o = run(jeu, OBJECTIF);
    assert.equal(o.season, 2);
    assert.equal(o.rang.length, 1);
    assert.ok(o.rang[0].id.startsWith('pres:2:'));
  } finally { jeu.fermer(); }
});
