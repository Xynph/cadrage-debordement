'use strict';
// Option de nouvelle carrière « Qualités des joueurs » (notation façon FM, 24/11/2026) : « Précises » (défaut) ou
// « En fourchette tant que pas observé ». En fourchette, nos joueurs encore peu suivis montrent chaque qualité en
// fourchette (attributesV2Range) ; l'option est sauvegardée dans la carrière et survit au rechargement.
const assert = require('node:assert/strict');
const test = require('node:test');
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');
const { factory } = require('../native/engine/player-knowledge.cjs');

test('Précises (défaut) : aucune fourchette sur nos joueurs', () => {
  const jeu = ouvrir({ hebdomadaire: true });
  try {
    const model = creer(jeu);
    assert.ok(model.squad.length > 20);
    assert.ok(model.squad.every(p => p.attributesV2Range === undefined), 'pas de fourchette sans l’option');
    assert.ok(model.squad.every(p => p.knowledge?.qualitesLargeur === undefined));
    // Niveau calculé selon le poste et le rôle (niveau-calcule.cjs) : rôles de la fiche, meilleur rôle du poste principal.
    const niveau = require('../native/engine/niveau-calcule.cjs');
    const ids = new Set(niveau.ROLES.map(r => r[0]));
    for (const p of model.squad) {
      const n = p.niveauCalcule;
      assert.ok(n && Number.isInteger(n.niveau) && n.niveau >= 15 && n.niveau <= 99, p.id);
      assert.ok(ids.has(n.role) && n.roles[n.role] === n.niveau, p.id);
      assert.ok(Object.keys(n.roles).length >= 3 && Object.keys(n.roles).every(id => ids.has(id)), p.id);
      assert.equal(n.niveau, niveau.niveauJoueur(p).niveau, 'qualités précises : niveau des vraies qualités');
    }
    // Deux 3e ligne aile, l'un Plaqueur l'autre Gratteur : leur Niveau dépend du rôle (poids clé/utile).
    const aile = model.squad.find(p => niveau.familleDe(p) === 'aile');
    if (aile) assert.notEqual(aile.niveauCalcule.roles['aile-plaqueur'], undefined);
  } finally { jeu.fermer(); }
});

test('En fourchette : qualités de nos joueurs en fourchette, option sauvegardée', () => {
  const jeu = ouvrir({ hebdomadaire: true });
  try {
    let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, qualites: 'fourchette' }));
    const avec = model.squad.filter(p => p.attributesV2Range);
    assert.equal(avec.length, model.squad.length, 'tous nos joueurs sont en fourchette au début de la carrière');
    for (const p of avec) {
      assert.equal(p.knowledge.qualitesLargeur, 9);
      for (const [cle, r] of Object.entries(p.attributesV2Range)) {
        assert.equal(r.max - r.min, 8, cle);
        assert.ok(r.min <= p.attributesV2[cle] && r.max >= p.attributesV2[cle], cle);
      }
    }
    const etat = JSON.parse(jeu.call('export').meta.exportText).state;
    assert.equal(etat.qualitesJoueurs.mode, 'fourchette');
    // Tout ce que l'écran calcule part de la fourchette (vérificateur, 24/11) : qualités = milieu de la fourchette,
    // jamais la vraie valeur ; note au poste décalée d'autant ; ni relevé ni flèches (vraies valeurs au dixième).
    const vrais = new Map(etat.clubs[etat.club].players.map(p => [p.id, p]));
    let differentes = 0;
    for (const p of avec) {
      const vrai = vrais.get(p.id);
      assert.ok(vrai, p.id);
      for (const [cle, r] of Object.entries(p.attributesV2Range)) {
        assert.equal(p.attributesV2[cle], (r.min + r.max) / 2, cle);
        if (p.attributesV2[cle] !== vrai.attributesV2?.[cle]) differentes++;
      }
      for (const k of ['releve', 'fleches', 'nativeAttributesV1']) assert.equal(p[k], undefined, k);
      assert.ok(p.niveauCalcule && Number.isInteger(p.niveauCalcule.niveau), 'niveau calculé selon le poste et le rôle');
    }
    assert.ok(differentes > avec.length * 20, 'les qualités montrées ne sont pas les vraies');
    // Rechargement : même option, mêmes fourchettes.
    const avant = JSON.stringify(model.squad[0].attributesV2Range);
    jeu.bridge.close();
    const reprise = ouvrir({ hebdomadaire: true, dataDir: jeu.dataDir });
    try {
      model = reprise.call('snapshot');
      assert.equal(JSON.stringify(model.squad[0].attributesV2Range), avant);
    } finally { reprise.bridge.close(); }
  } finally { jeu.fermer(); }
});

test('Option inconnue refusée', () => {
  const jeu = ouvrir({ hebdomadaire: true });
  try {
    const r = jeu.brut('new_career', { mode: 'world-champ', club: 102, qualites: 'floues' });
    assert.equal(r.ok, false);
    assert.match(r.error, /Qualités des joueurs/);
  } finally { jeu.fermer(); }
});

test('Suivi : 9 points, puis 5 après 4 semaines, puis précises après 8 ; recrue suivie depuis son arrivée', () => {
  const k = factory();
  const joueur = { id: 'j1', name: 'A', pos: 'Pilier', rating: 60, attributesV2: { tackling: 61 } };
  const etat = (semaine, extra = {}) => ({ season: 1, round: 0, worldMode: { week: semaine }, club: 0, careerVariation: { seed: 1 },
    qualitesJoueurs: { version: 1, mode: 'fourchette', debut: { season: 1, week: 0 } }, clubs: [{ id: 0, players: [{ ...joueur, ...extra }] }] });
  const largeur = s => k.visibility(s).j1.knowledge.qualitesLargeur ?? 0;
  assert.equal(largeur(etat(0)), 9);
  assert.equal(largeur(etat(4)), 5);
  assert.equal(largeur(etat(8)), 0);
  const recrue = { ...etat(20), round: 12 };
  recrue.clubs[0].players[0].joinedSeason = 1; recrue.clubs[0].players[0].joinedRound = 10;
  assert.equal(largeur(recrue), 9, 'arrivée il y a 2 journées');
  const vu = etat(0); delete vu.qualitesJoueurs;
  assert.equal(largeur(vu), 0, 'sans option : précises');
});

test('En fourchette, au fil des semaines : 9 puis 5 points puis précises (projection vérifiée)', () => {
  const jeu = ouvrir({ hebdomadaire: true, verifyProjection: true, testVm: true });
  try {
    let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, qualites: 'fourchette' }));
    const largeur = m => m.squad[0].knowledge.qualitesLargeur ?? 0;
    assert.equal(largeur(model), 9);
    // Début du suivi reculé de 4 puis 8 semaines (même effet qu'avancer le calendrier, sans jouer la préparation).
    jeu.bridge.vm.run('S.qualitesJoueurs.debut.week-=4');
    model = jeu.call('snapshot');
    assert.equal(largeur(model), 5);
    assert.ok(Object.values(model.squad[0].attributesV2Range).every(r => r.max - r.min === 4));
    jeu.bridge.vm.run('S.qualitesJoueurs.debut.week-=4');
    model = jeu.call('snapshot');
    assert.equal(largeur(model), 0);
    assert.ok(model.squad.every(p => p.attributesV2Range === undefined), 'précises une fois le joueur bien suivi');
  } finally { jeu.fermer(); }
});

test('En fourchette : la note au poste suit le milieu des fourchettes (poids du poste), jamais la vraie note', () => {
  const k = factory();
  const qualites = Object.fromEntries(require('../native/engine/niveau-calcule.cjs').CLES.map(c => [c, 60]));
  const etat = { season: 1, round: 0, worldMode: { week: 0 }, club: 0, careerVariation: { seed: 3 },
    qualitesJoueurs: { version: 1, mode: 'fourchette', debut: { season: 1, week: 0 } },
    clubs: [{ id: 0, players: [{ id: 'j1', name: 'A', pos: 'Pilier gauche', rating: 60, attributesV2: qualites }] }] };
  const model = { squad: [{ id: 'j1', name: 'A', pos: 'Pilier gauche', primaryPositions: [1], rating: 60, attributesV2: { ...qualites }, positionRatings: { 1: 60, 11: 40 }, releve: 'x', fleches: { n: 1 } }] };
  k.project(model, k.visibility(etat));
  const p = model.squad[0];
  const milieux = Object.values(p.attributesV2Range).map(r => (r.min + r.max) / 2);
  assert.ok(milieux.some(m => m !== 60), 'des milieux différents de la vraie valeur');
  // Attendu : vraie note + écart pondéré (poids du poste) entre milieux et vraies qualités, arrondi.
  const nc = require('../native/engine/niveau-calcule.cjs');
  const attendu = (note, famille) => { const w = nc.poids(famille, null); let t = 0, s = 0; for (const c of nc.CLES) { t += w[c] * (p.attributesV2[c] - 60); s += w[c]; } return Math.round(note + t / s); };
  assert.deepEqual(p.positionRatings, { 1: attendu(60, 'pilier'), 11: attendu(40, 'ailier') });
  assert.ok(nc.CLES.every(c => p.attributesV2[c] !== 60 || p.attributesV2Range[c].min + 4 === 60), 'qualités montrées = milieux');
  assert.equal(p.releve, undefined);
  assert.equal(p.fleches, undefined);
  assert.equal(p.niveauCalcule.role.startsWith('pilier-'), true);
});