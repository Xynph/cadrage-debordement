'use strict';
// Multiplex des autres matchs de la journée et classement en direct « si ça finit ainsi »
// (native/engine/match-multiplex.cjs, projeté dans live.direct.journee), carrière world-champ.
// - même graine : S.history identique avec et sans déroulé anticipé (championnats suivis de loin) ;
// - fin du match montrée : multiplex et classement en direct = résultats et classement officiels ;
// - le déroulé ne modifie pas la carrière et ne consomme aucun tirage du flux principal ;
// - la minute du multiplex ne dépasse jamais la minute montrée ;
// - temps ajouté au coup d'envoi mesuré et affiché.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { ouvrir, jusquAuMatch, jusquALaSemaineSuivante } = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

const CLUB = 0;
const vmJson = (jeu, source) => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + source + ')'));

function partie({ multiplex = true, suivisDeLoin = true } = {}) {
  const jeu = ouvrir({ testVm: true });
  if (!multiplex) jeu.bridge.vm.run("nativeSystems.domain('multiplex').setEnabled(false)");
  const creation = { mode: 'world-champ', club: CLUB, ...(suivisDeLoin ? { detailedLeagues: [] } : {}) };
  let model = jeu.regler(jeu.call('new_career', creation));
  model = jusquAuMatch(jeu, model);
  if (!model.selection.valid) model = jeu.call('auto_lineup');
  if (!model.selection.valid) model = jeu.call('promote_cover', { confirmed: true });
  return { jeu, model };
}

// Coup d'envoi mesuré, puis le match en direct jusqu'au bout ; `observer` voit chaque réponse.
function jouerEnDirect(jeu, model, observer = () => {}) {
  const t0 = performance.now();
  model = jeu.call('begin_match');
  const ms = performance.now() - t0;
  model = skipMatchTalk(model, jeu.call);
  observer(model);
  for (let n = 0; n < 400 && !(model.live.finished && model.live.direct?.borne >= model.live.events.length); n++) {
    model = skipMatchTalk(model, jeu.call);
    if (model.live.paused && !model.live.finished) model = jeu.call('pause', { paused: false });
    model = jeu.call('tick', { steps: 5 });
    observer(model);
  }
  assert.equal(model.live.finished, true, 'match terminé');
  return { model, ms };
}

function valider(jeu, model) {
  model = skipMatchTalk(model, jeu.call); // débrief d'après-match passé
  if (model.live) model = skipMatchTalk(jeu.call('finish_round'), jeu.call);
  return jusquALaSemaineSuivante(jeu, model);
}

test('même graine : S.history identique avec et sans déroulé anticipé, multiplex = officiel en fin de match', () => {
  const avec = partie({ multiplex: true }), sans = partie({ multiplex: false });
  try {
    // Aucune différence au coup d'envoi : même carrière (match compris) et même flux principal.
    const a = jouerEnDirect(avec.jeu, avec.model, model => {
      const direct = model.live.direct, j = direct?.journee;
      assert.ok(j, 'journée projetée dans le direct');
      const montree = direct.echantillon.minutes;
      assert.ok(j.minute <= montree, `minute du multiplex ${j.minute} ≤ minute montrée ${montree}`);
      for (const m of j.matchs) assert.ok(m.fini || m.minute <= j.minute, 'aucune rencontre en avance sur notre match');
    });
    const b = jouerEnDirect(sans.jeu, sans.model);
    assert.equal(b.model.live.direct.journee ?? null, null, 'sans multiplex, pas de journée');
    assert.deepEqual(a.model.live.score, b.model.live.score, 'notre match se joue de la même façon');
    console.log(`# begin_match : ${a.ms.toFixed(0)} ms avec multiplex, ${b.ms.toFixed(0)} ms sans (+${(a.ms - b.ms).toFixed(0)} ms)`);

    const finale = a.model.live.direct.journee, competition = vmJson(avec.jeu, 'CDWorldCareer.userFixture(S).competitionId');
    assert.ok(finale.matchs.length >= 5, 'les autres rencontres de la journée');
    assert.ok(finale.matchs.every(m => m.fini));
    assert.ok(finale.classement.length >= 10 && finale.classement.filter(r => r.nous).length === 1);

    valider(avec.jeu, a.model); valider(sans.jeu, b.model);
    const hA = vmJson(avec.jeu, 'S.history'), hB = vmJson(sans.jeu, 'S.history');
    assert.ok(hA.length > 0);
    assert.deepEqual(hA, hB, 'mêmes résultats pour toutes les rencontres, la nôtre comprise');
    const compteurs = vmJson(avec.jeu, "nativeSystems.domain('multiplex').counters()");
    assert.equal(compteurs.consumed, finale.matchs.length, 'déroulé consommé à la validation');
    assert.equal(compteurs.divergences, 0);

    // Multiplex final = résultats officiels.
    for (const m of finale.matchs) {
      const r = hA.find(x => x.fixtureId === m.id);
      assert.ok(r, 'résultat officiel de ' + m.id);
      assert.deepEqual([r.score, r.tries], [[m.home.score, m.away.score], [m.home.essais, m.away.essais]], m.id);
    }
    // Classement en direct final = classement officiel (points, bonus, rang).
    const officiel = vmJson(avec.jeu, `CDWorldCareer.rows(S,${JSON.stringify(competition)})`);
    assert.deepEqual(finale.classement.map(r => [r.clubId, r.rang, r.points, r.joues, r.diff, r.bonusOff, r.bonusDef]),
      officiel.map((r, i) => [r.clubId, i + 1, r.points, r.played, r.pf - r.pa, r.offensiveBonus, r.defensiveBonus]));
  } finally { avec.jeu.fermer(); sans.jeu.fermer(); }
});

test('le déroulé ne modifie pas la carrière et ne tire rien du flux principal', () => {
  const { jeu, model } = partie();
  try {
    const debut = skipMatchTalk(jeu.call('begin_match'), jeu.call);
    assert.ok(debut.live.direct.journee, 'déroulé calculé au coup d’envoi');
    const avant = jeu.bridge.vm.run('JSON.stringify(S)'), graine = jeu.bridge.vm.seed();
    jeu.bridge.vm.run("nativeSystems.domain('multiplex').setEnabled(false);nativeSystems.domain('multiplex').setEnabled(true)");
    const t0 = performance.now();
    const n = jeu.bridge.vm.run("nativeSystems.domain('multiplex').prepare().matchs.size");
    const ms = performance.now() - t0;
    console.log(`# déroulé seul : ${n} rencontres en ${ms.toFixed(0)} ms`);
    assert.ok(n >= 5);
    assert.equal(jeu.bridge.vm.run('JSON.stringify(S)'), avant, 'carrière inchangée (live compris)');
    assert.equal(jeu.bridge.vm.seed(), graine, 'flux principal intact');
  } finally { jeu.fermer(); }
});

test('championnats tous suivis en détail : les résultats officiels restent ceux du multiplex', () => {
  const { jeu, model } = partie({ suivisDeLoin: false });
  try {
    const { model: fin } = jouerEnDirect(jeu, model);
    const finale = fin.live.direct.journee;
    assert.ok(finale && finale.matchs.length >= 5);
    valider(jeu, fin);
    const h = vmJson(jeu, 'S.history');
    for (const m of finale.matchs) {
      const r = h.find(x => x.fixtureId === m.id);
      assert.deepEqual([r.score, r.tries], [[m.home.score, m.away.score], [m.home.essais, m.away.essais]], m.id);
    }
    assert.equal(vmJson(jeu, "nativeSystems.domain('multiplex').counters()").divergences, 0);
  } finally { jeu.fermer(); }
});
