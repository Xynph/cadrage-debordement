'use strict';
// Types de blessure (native/engine/club-mail.cjs, données « blessures » de club-mail.json ; demande de Léo, 18/11/2026) :
// type tiré à la création, cohérent avec la durée, stable (empreinte, pas de hasard), cause lue dans le journal du
// club, effacé à la guérison ; commotion = protocole (une à deux semaines) ; ancienne sauvegarde sans type acceptée.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { factory, DATA } = require('../native/engine/club-mail.cjs');

globalThis.nativeClubMailData = DATA;
const mail = factory();

const state = () => ({ season: 2, club: 0, news: ['Jean Dupont est blessé après la rencontre : 3 semaine(s) d’indisponibilité.', 'Marc Petit s’est blessé à l’entraînement : indisponible 1 semaine(s).'],
  clubs: { 0: { players: [
    { id: 'a', name: 'Jean Dupont', pos: 'Pilier gauche', injury: 3 },
    { id: 'b', name: 'Marc Petit', pos: 'Ailier', injury: 1 },
    { id: 'c', name: 'Luc Martin', pos: 'Centre', injury: 0 },
  ] }, 1: { players: Array.from({ length: 60 }, (_, i) => ({ id: 'x' + i, name: 'Adverse ' + i, pos: i % 2 ? 'Talonneur' : 'Arrière', injury: 1 + (i % 4) })) } } });

test('Données : types crédibles, durées et poids valides, commotion sous protocole', () => {
  const types = DATA.blessures.types;
  assert.ok(Object.keys(types).length >= 8);
  for (const [k, t] of Object.entries(types)) {
    assert.ok(t.libelle && t.conseil, k);
    assert.ok(t.semaines[0] >= 1 && t.semaines[0] <= t.semaines[1], k + ' : durée');
    assert.ok(t.poids.avants >= 0 && t.poids.arrieres >= 0 && t.poids.avants + t.poids.arrieres > 0, k + ' : poids');
  }
  assert.match(types.commotion.libelle, /protocole/i);
  assert.ok(types.commotion.semaines[1] <= 2);
  assert.ok(types.croises.semaines[0] >= 12, 'ligaments croisés : longue absence');
});

test('Type tiré à la création, cohérent avec la durée, stable, cause du journal, effacé à la guérison', () => {
  const s = state();
  mail.blessures.typer(s, '2026-09-20');
  const [a, b, c] = s.clubs[0].players;
  for (const p of [a, b, ...s.clubs[1].players]) {
    const t = DATA.blessures.types[p.injuryType];
    assert.ok(t, p.id + ' : type');
    assert.ok(p.injury >= t.semaines[0] && p.injury <= t.semaines[1], p.id + ' : ' + p.injuryType + ' pour ' + p.injury + ' sem.');
    assert.equal(p.injuryDate, '2026-09-20');
  }
  assert.equal(c.injuryType, undefined);
  assert.equal(a.injuryCause, 'match');
  assert.equal(b.injuryCause, 'entrainement');
  assert.ok(!s.clubs[1].players.some(p => /Arri/.test(p.pos) && p.injuryType === 'cou'), 'cervicales : avants seulement');
  assert.ok(new Set(s.clubs[1].players.map(p => p.injuryType)).size >= 4, 'variété des types');
  // Stable : même état, même jour -> mêmes types ; un type déjà posé ne change plus.
  const again = state();
  mail.blessures.typer(again, '2026-09-20');
  assert.deepEqual(again.clubs[1].players.map(p => p.injuryType), s.clubs[1].players.map(p => p.injuryType));
  const kept = a.injuryType;
  a.injury = 2;
  mail.blessures.typer(s, '2026-09-27');
  assert.equal(a.injuryType, kept);
  // Guérison : type, cause et date effacés.
  a.injury = 0;
  mail.blessures.typer(s, '2026-10-04');
  assert.equal(a.injuryType, undefined);
  assert.equal(a.injuryCause, undefined);
  assert.equal(a.injuryDate, undefined);
});

test('Ancienne sauvegarde : joueur blessé sans type accepté, type inconnu refusé', () => {
  const s = state();
  s.clubMail = { version: 1, seq: 0, last: null, mails: [], sent: {}, suites: [], memo: {} };
  assert.equal(mail.validate(s), true);
  s.clubs[0].players[0].injuryType = 'inconnu';
  assert.throws(() => mail.validate(s), /type de blessure/);
});

// Réponses au bulletin du médecin (18/11/2026) : conséquences affichées dérivées des effets réellement appliqués,
// risque de rechute tiré à la guérison par empreinte stable (graine fixe), date de retour avancée ou retardée.
test('Bulletin médical : chaque réponse montre ses vraies conséquences (rechute, date de retour)', () => {
  const answers = Object.fromEntries(DATA.types.blessure.reponses.map(r => [r.id, r.effets]));
  const base = DATA.blessures.rechute.base;
  const p = { id: 'a', injury: 3 };
  const txt = id => mail.blessures.effets(answers[id], p, '2026-09-20');
  assert.equal(mail.blessures.risque(p), base);
  assert.match(txt('progressif'), new RegExp('^Risque de rechute −8 \\(' + (base - 8) + ' %\\)'));
  assert.match(txt('progressif'), /Charge individuelle : charge allégée/);
  assert.match(txt('repos'), /Risque de rechute −12 \(0 %\) · Retour retardé au 18\/10/);
  assert.match(txt('repos'), /Satisfaction −1/);
  assert.match(txt('presser'), new RegExp('Risque de rechute \\+15 \\(' + (base + 15) + ' %\\) · Retour avancé au 04/10'));
  assert.match(txt('presser'), /Satisfaction \+2/);
  // Un seul jour d'arrêt restant : le retour ne peut pas avancer, rien n'est donc affiché pour lui.
  assert.doesNotMatch(mail.blessures.effets(answers.presser, { id: 'b', injury: 1 }, '2026-09-20'), /Retour/);
  // Joueur déjà guéri : aucune conséquence médicale affichée.
  assert.doesNotMatch(mail.blessures.effets(answers.progressif, { id: 'c', injury: 0 }, '2026-09-20'), /rechute/);
});

test('Rechute : tirée à la guérison selon le risque, déterministe, nouvelle blessure « rechute »', () => {
  const heal = (risk, id = 'a') => {
    const s = state();
    const p = s.clubs[0].players[0];
    p.id = id; mail.blessures.typer(s, '2026-09-20');
    p.injuryRelapse = risk; p.injury = 0;
    mail.blessures.typer(s, '2026-10-11');
    return p;
  };
  const sure = heal(100);
  assert.equal(sure.injury, DATA.blessures.rechute.semaines);
  assert.equal(sure.injuryCause, 'rechute');
  assert.equal(sure.injuryDate, '2026-10-11');
  assert.ok(sure.injuryType, 'type conservé');
  assert.equal(sure.injuryRelapse, undefined, 'une seule rechute tirée');
  const none = heal(0);
  assert.equal(none.injury, 0);
  assert.equal(none.injuryType, undefined);
  assert.equal(none.injuryRelapse, undefined);
  // Même graine, même résultat ; risque plus haut, plus de rechutes (200 joueurs).
  const count = risk => Array.from({ length: 200 }, (_, i) => heal(risk, 'j' + i).injury > 0).filter(Boolean).length;
  assert.equal(count(20), count(20));
  const low = count(4), high = count(27);
  assert.ok(low < high && low <= 20 && high >= 35, low + ' / ' + high);
  // Sans réponse au médecin (pas de risque posé) : aucune rechute, comme avant.
  const s = state(); mail.blessures.typer(s, '2026-09-20'); s.clubs[0].players[0].injury = 0; mail.blessures.typer(s, '2026-10-11');
  assert.equal(s.clubs[0].players[0].injury, 0);
  // Sauvegarde : risque hors bornes refusé.
  s.clubMail = { version: 1, seq: 0, last: null, mails: [], sent: {}, suites: [], memo: {} };
  s.clubs[0].players[1].injuryRelapse = 140;
  assert.throws(() => mail.validate(s), /risque de rechute/);
});

test('Bulletin médical : vrai adversaire, domicile ou extérieur, notre score d’abord, entraînement ou rechute', () => {
  const name = id => ({ 7: 'Stade Toulousain', 9: 'ASM Clermont' })[id] || '';
  const results = [
    { date: '2026-09-11', opp: 7, home: true, us: 24, them: 17 },
    { date: '2026-09-18', opp: 9, home: false, us: 17, them: 24 },
  ];
  const cause = (c, d) => mail.blessures.cause({ injuryCause: c, injuryDate: d }, results, name, '2026-09-19');
  assert.equal(cause('match', '2026-09-18'), 'Il est sorti touché sur le terrain de ASM Clermont (17-24, le 18/09).');
  assert.equal(cause('match', '2026-09-12'), 'Il est sorti touché à domicile contre Stade Toulousain (24-17, le 11/09).');
  assert.equal(cause('entrainement', '2026-09-18'), "Il s'est blessé à l'entraînement, le 18/09.");
  assert.match(cause('rechute', '2026-09-18'), /rechuté à l'entraînement, le 18\/09/);
  assert.doesNotMatch(mail.blessures.cause({ injuryCause: 'match', injuryDate: '2026-09-18' }, [{ date: '2026-09-18', opp: 3, home: true, us: 10, them: 3 }], name, '2026-09-18'), /nos adversaires|contre  /);
});
