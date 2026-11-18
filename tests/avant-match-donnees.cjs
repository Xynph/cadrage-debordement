'use strict';
// Écran Match avant le coup d'envoi (maquette « Retenue », 17/11/2026) : données calculées par le moteur
// (native/engine/avant-match.cjs, `clubLife.avantMatch`) à partir des vraies statistiques d'une carrière Monde
// (world-champ, club 102, cadence de la semaine) : forme, forces en présence, confrontations, joueurs adverses à
// surveiller et clés de Gabi. Tout est recalculé ici depuis l'état : aucun chiffre ne doit être inventé, la
// projection est déterministe et ne consomme aucun aléa.
const test = require('node:test');
const assert = require('node:assert/strict');
const M = require('./helpers/carriere-monde.cjs');

const jeu = M.ouvrir({ testVm: true, hebdomadaire: true });
test.after(() => jeu.fermer());
const run = source => jeu.bridge.vm.run(source);
const etat = source => JSON.parse(run('JSON.stringify(' + source + ')'));

let model = M.creer(jeu, 102);
const debut = M.jusquAuMatch(jeu, model);
const premier = debut.clubLife.avantMatch;
model = M.jouer(jeu, debut, 3);
model = M.jusquAuMatch(jeu, model);
const am = model.clubLife.avantMatch;
const S = etat('{club:S.club,season:S.season,history:S.history,fixture:CDWorldCareer.userFixture(S),notes:S.matchNotes.joueurs,clubs:S.clubs.map(c=>({id:c.id,players:c.players.map(p=>({id:String(p.id),name:p.name,injury:p.injury||0,suspension:p.suspension||0}))}))}');
const pair = [S.fixture.homeId, S.fixture.awayId], adv = pair.find(id => id !== S.club);
const issue = (r, id) => { const i = r.pair.indexOf(id); return r.score[i] > r.score[1 - i] ? 'V' : r.score[i] < r.score[1 - i] ? 'D' : 'N'; };
const deLaSaison = id => S.history.filter(r => r.pair.includes(id) && r.pair[0] !== r.pair[1] && (r.season ?? S.season) === S.season)
  .sort((a, b) => String(a.date).localeCompare(String(b.date)) || String(a.fixtureId).localeCompare(String(b.fixtureId)));

test('Premier match de la saison : pas de forces ni de joueurs chiffrés, repli honnête', () => {
  assert.ok(premier, 'projection présente le jour du premier match');
  assert.deepEqual(premier.forme, [[], []]);
  assert.equal(premier.forces, null, 'aucun match : pas de forces en présence');
  assert.notEqual(premier.aSurveiller.source, 'statistiques');
  for (const j of premier.aSurveiller.joueurs) assert.equal(j.chiffre, null, 'XV probable : aucun chiffre');
  assert.equal(premier.gabi.cles.length, 3);
});

test('Forme : 5 derniers résultats réels de chaque club', () => {
  assert.equal(am.fixtureId, S.fixture.id);
  pair.forEach((id, i) => assert.deepEqual(am.forme[i], deLaSaison(id).slice(-5).map(r => issue(r, id))));
  assert.ok(am.forme[0].length >= 1 && am.forme[1].length >= 1, 'les deux clubs ont joué');
});

test('Forces en présence : moyennes recalculées depuis l’historique', () => {
  assert.ok(am.forces, 'forces disponibles après 3 journées');
  assert.equal(am.forces.saison, 'en cours');
  pair.forEach((id, i) => {
    const ms = deLaSaison(id), n = ms.length, e = am.forces.equipes[i];
    let essais = 0, contre = 0, t = 0, tg = 0, m = 0, mg = 0;
    for (const r of ms) { const k = r.pair.indexOf(id), st = r.stats?.[k] || {}; essais += r.tries[k]; contre += r.score[1 - k]; t += st.lineouts || 0; tg += st.lineoutsWon || 0; m += st.scrums || 0; mg += st.scrumsWon || 0; }
    assert.equal(e.matchs, n);
    assert.equal(e.essais, Math.round(essais / n * 10) / 10);
    assert.equal(e.encaisses, Math.round(contre / n * 10) / 10);
    assert.equal(e.touches, t ? Math.round(tg / t * 100) : null);
    assert.equal(e.melees, m ? Math.round(mg / m * 100) : null);
    assert.ok(e.touches === null || (e.touches >= 0 && e.touches <= 100));
  });
});

test('Confrontations : bilan cohérent avec l’historique', () => {
  const face = S.history.filter(r => r.pair.includes(S.club) && r.pair.includes(adv));
  const c = am.confrontations;
  assert.equal(c.joues, face.length);
  assert.equal(c.victoires + c.nuls + c.defaites, c.joues);
  assert.ok(c.derniers.length <= 5 && c.derniers.length === Math.min(5, face.length));
  for (const l of c.derniers) assert.ok(['V', 'N', 'D'].includes(l.issue));
});

test('Joueurs à surveiller : adversaires disponibles, chiffres tirés de leurs totaux de saison', () => {
  const s = am.aSurveiller, roster = S.clubs[adv].players;
  assert.ok(['statistiques', 'probable', 'aucune'].includes(s.source));
  assert.ok(s.joueurs.length >= 1 && s.joueurs.length <= 3);
  assert.equal(new Set(s.joueurs.map(j => j.id)).size, s.joueurs.length, 'trois joueurs différents');
  for (const j of s.joueurs) {
    const p = roster.find(x => x.id === j.id);
    assert.ok(p, j.name + ' est dans l’effectif adverse');
    assert.equal(p.name, j.name);
    assert.equal(p.injury, 0, 'pas de blessé');
    assert.ok(Number.isInteger(j.numero) && j.numero >= 1 && j.numero <= 15, 'numéro du XV type');
    if (s.source !== 'statistiques') continue;
    const t = S.notes[j.id].s;
    assert.ok(t[0] >= 2, 'au moins deux matchs joués');
    const attendu = {
      buteur: Math.round(t[12] / t[13] * 100) + ' %',
      franchissements: (Math.round(t[8] / t[0] * 10) / 10).toFixed(1).replace('.', ',') + ' / m',
      grattages: (Math.round(t[11] / t[0] * 10) / 10).toFixed(1).replace('.', ',') + ' / m',
      plaquages: (Math.round(t[4] / t[0] * 10) / 10).toFixed(1).replace('.', ',') + ' / m',
      essais: t[3] + ' essais',
    }[j.categorie];
    assert.equal(j.chiffre, attendu, j.categorie + ' de ' + j.name);
  }
  assert.equal(s.source, 'statistiques', 'après 3 journées, les statistiques désignent les joueurs');
});

test('Totaux de saison : grattages et buts tentés/réussis enregistrés', () => {
  const lignes = Object.values(S.notes).filter(j => j.s[0] > 0);
  assert.ok(lignes.every(j => j.s.length === 14));
  assert.ok(lignes.some(j => j.s[11] > 0), 'des ballons grattés');
  assert.ok(lignes.some(j => j.s[13] > 0), 'des tentatives au but');
  assert.ok(lignes.every(j => j.s[12] <= j.s[13]), 'réussis ≤ tentés');
  run('validateCareer(S)');
});

test('Clés de Gabi : une phrase et trois clés, sans doublon', () => {
  assert.match(am.gabi.phrase, /Trois clés pour moi :$/);
  assert.equal(am.gabi.cles.length, 3);
  assert.equal(new Set(am.gabi.cles.map(c => c.titre)).size, 3);
  for (const c of am.gabi.cles) { assert.ok(c.titre.length > 0 && c.titre.length <= 40, c.titre); assert.ok(c.detail.length <= 60, c.detail); }
});

test('Lecture seule et déterministe : même projection, aucun aléa consommé', () => {
  const seed = jeu.bridge.vm.seed();
  const a = jeu.call('snapshot').clubLife.avantMatch, b = jeu.call('snapshot').clubLife.avantMatch;
  assert.deepEqual(a, b);
  assert.deepEqual(a, am);
  assert.equal(jeu.bridge.vm.seed(), seed);
});

test('Météo annoncée : la clé du vent suit le sens réel', () => {
  run("S.worldMode.meteo={fixtureId:CDWorldCareer.userFixture(S).id,date:CDWorldCareer.userFixture(S).date,weather:'Vent',pluie:0,vent:2,chaleur:0,terrain:'souple',sens:" + (1 - pair.indexOf(S.club)) + "};validateCareer(S)");
  const g = jeu.call('snapshot').clubLife.avantMatch.gabi;
  assert.equal(g.cles[0].titre, 'Tenir le score face au vent');
  assert.ok(g.cles.some(c => c.titre === 'Accélérer après la pause'));
  run('delete S.worldMode.meteo');
});

test('Météo annoncée : sans vent, Gabi ne parle pas du vent et la tuile dit la même chose', () => {
  run("S.worldMode.meteo={fixtureId:CDWorldCareer.userFixture(S).id,date:CDWorldCareer.userFixture(S).date,weather:'Pluie',pluie:1,vent:0,chaleur:0,terrain:'souple',sens:0};validateCareer(S)");
  const snap = jeu.call('snapshot');
  assert.equal(snap.next.meteo.vent, 0, 'écran Match : pas de vent annoncé');
  assert.ok(!snap.clubLife.avantMatch.gabi.cles.some(c => /vent/i.test(c.titre + ' ' + c.detail)), JSON.stringify(snap.clubLife.avantMatch.gabi.cles));
  run('delete S.worldMode.meteo');
});

test('Affiche : capacité du stade du club qui reçoit (photo d’avant-match à sa taille)', () => {
  const snap = jeu.call('snapshot');
  const attendu = etat('CDWorldStadiumCapacities[S.clubs[' + snap.next.pair[0] + '].id]');
  assert.equal(snap.next.capacity, attendu);
  assert.ok(Number.isInteger(snap.next.capacity) && snap.next.capacity > 0);
});

if (process.env.CD_AVANT_MATCH_DUMP) console.log(JSON.stringify({ premier, am }, null, 1));

test('Arbitre : désigné avec les mêmes fixtureId et competitionId que le direct, clé de Gabi seulement si ruck 4/5 ou plus', () => {
  const attendu = etat(`arbitreDuMatch(${JSON.stringify(S.fixture.id)},${JSON.stringify(S.fixture.competitionId)})`);
  assert.ok(am.arbitre, 'arbitre présent');
  assert.deepEqual(am.arbitre, { nom: attendu.nom, civilite: attendu.civilite, pays: attendu.pays, rucks: attendu.rucks, melee: attendu.melee, horsJeu: attendu.horsJeu, cartons: attendu.cartons, resume: attendu.resume });
  assert.equal(am.gabi.cles.length, 3);
  if (attendu.rucks < 4) assert.ok(!am.gabi.cles.some(c => /siffle beaucoup les rucks/.test(c.titre)), 'pas de clé arbitre sans tendance forte');
});
