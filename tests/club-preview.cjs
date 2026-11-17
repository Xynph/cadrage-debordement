'use strict';
// Aperçu d'un club à la création (commande `club_preview`, écran « Options de carrière ») : carrière Monde
// (world-champ), sans carrière ouverte. Contrat de meta.clubPreview, lecture seule (aucun fichier du dossier de
// données écrit ou modifié), déterminisme, rapidité, puis cohérence avec la carrière réellement créée : même
// 1re rencontre, même date de reprise du club, même président, mêmes visages dans l'effectif.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { ouvrir } = require('./helpers/carriere-monde.cjs');

const ISO = /^\d{4}-\d{2}-\d{2}$/;
const isIso = x => typeof x === 'string' && ISO.test(x) && new Date(x + 'T00:00:00Z').toISOString().slice(0, 10) === x;

// Empreinte du dossier de données : chemin relatif → taille et SHA-256 de chaque fichier.
function empreinte(dir) {
  const out = {};
  const walk = d => {
    for (const e of fs.readdirSync(d, { withFileTypes: true })) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) walk(p);
      else out[path.relative(dir, p)] = crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
    }
  };
  walk(dir);
  return out;
}

function verifierVisage(f, role) {
  assert.ok(f && typeof f === 'object', role + ' présent');
  assert.equal(typeof f.id, 'string', role + '.id');
  assert.equal(typeof f.name, 'string', role + '.name');
  assert.ok(f.name.length > 0, role + '.name');
  assert.equal(typeof f.pos, 'string', role + '.pos');
  for (const k of ['age', 'rating', 'potential']) assert.ok(Number.isInteger(f[k]), role + '.' + k);
  if ('appearanceId' in f) assert.equal(typeof f.appearanceId, 'string', role + '.appearanceId');
  if ('appearanceBuild' in f) assert.equal(typeof f.appearanceBuild, 'number', role + '.appearanceBuild');
  if ('appearanceBankVersion' in f) assert.ok([1, 2].includes(f.appearanceBankVersion), role + '.appearanceBankVersion');
  if ('portraitIndex' in f) assert.ok(Number.isInteger(f.portraitIndex), role + '.portraitIndex');
}

function verifierContrat(p, club, catalogue) {
  const nom = id => catalogue.find(c => c.id === id)?.name;
  assert.deepEqual(Object.keys(p).sort(), ['club', 'faces', 'firstFixture', 'friendlies', 'president', 'reprise', 'rivals']);
  assert.equal(p.club, club);
  assert.equal(p.reprise.firstClubs, '2026-07-13');
  assert.ok(isIso(p.reprise.club) && isIso(p.reprise.eve), 'dates de reprise ISO');
  assert.ok(p.reprise.club >= '2026-07-13' && p.reprise.club < p.reprise.eve, 'reprise avant la veille');
  assert.ok(Number.isInteger(p.friendlies.count) && p.friendlies.count >= 1 && p.friendlies.count <= 4);
  assert.ok(Array.isArray(p.friendlies.dates) && p.friendlies.dates.length <= p.friendlies.count);
  for (const d of p.friendlies.dates) assert.ok(isIso(d) && d > p.reprise.club && d <= p.reprise.eve, 'amical ' + d);
  const f = p.firstFixture;
  assert.ok(f, '1re rencontre connue');
  assert.ok(isIso(f.date));
  assert.equal(p.reprise.eve, new Date(Date.parse(f.date + 'T00:00:00Z') - 86400000).toISOString().slice(0, 10), 'veille = jour d’avant la 1re rencontre');
  assert.ok(f.kickoff === null || /^\d{2}:\d{2}$/.test(f.kickoff));
  assert.ok(Number.isInteger(f.opponentId) && f.opponentId !== club);
  assert.equal(f.opponentName, nom(f.opponentId), 'nom de l’adversaire du catalogue');
  assert.equal(typeof f.home, 'boolean');
  assert.equal(typeof f.competition, 'string');
  assert.ok(Number.isInteger(f.round) && f.round >= 1);
  assert.ok(Array.isArray(p.rivals));
  for (let i = 0; i < p.rivals.length; i++) {
    const r = p.rivals[i];
    assert.ok(Number.isInteger(r.id) && r.id !== club);
    assert.equal(r.name, nom(r.id) ?? r.name);
    assert.equal(typeof r.name, 'string');
    assert.ok(Number.isInteger(r.tension) && r.tension > 0);
    assert.ok(Array.isArray(r.dates) && r.dates.every(isIso));
    if (i) assert.ok(p.rivals[i - 1].tension >= r.tension, 'rivaux triés par tension décroissante');
  }
  for (const role of ['leader', 'best', 'prospect']) verifierVisage(p.faces[role], role);
  assert.ok(p.president === null || typeof p.president.name === 'string' && p.president.name.length > 0);
}

test('club_preview : contrat, lecture seule, déterminisme et cohérence avec la carrière Monde créée', { timeout: 900000 }, t => {
  const jeu = ouvrir({ testVm: true });
  t.after(() => jeu.fermer());
  const catalogue = jeu.call('snapshot').meta.champCatalogue;
  const japon = catalogue.find(c => c.playable && c.division === 'jlo-d1');
  assert.ok(japon, 'un club du Japon jouable');
  const clubs = [0, 102, japon.id];
  assert.ok(catalogue.find(c => c.id === 0).division === 'elite' && catalogue.find(c => c.id === 102).division === 'champ');

  // Arguments refusés en français.
  assert.match(jeu.brut('club_preview', { club: 99999 }).error, /Club inconnu/);
  assert.match(jeu.brut('club_preview', { club: '0' }).error, /Paramètres d’aperçu de club invalides/);
  assert.match(jeu.brut('club_preview', { club: 0, autre: 1 }).error, /Paramètres d’aperçu de club invalides/);

  const avant = empreinte(jeu.dataDir);
  const apercus = new Map(), temps = [];
  for (const club of clubs) {
    const debut = performance.now();
    const model = jeu.call('club_preview', { club });
    temps.push(Math.round(performance.now() - debut));
    assert.equal(model.meta.hasCareer, false, 'aucune carrière créée');
    verifierContrat(model.meta.clubPreview, club, catalogue);
    apercus.set(club, model.meta.clubPreview);
  }
  // Remplacé à chaque appel et déterministe.
  for (const club of clubs) assert.deepEqual(jeu.call('club_preview', { club }).meta.clubPreview, apercus.get(club));
  assert.deepEqual(empreinte(jeu.dataDir), avant, 'aucun fichier écrit ni modifié par club_preview');
  t.diagnostic('club_preview (ms) : ' + temps.join(', '));
  assert.ok(Math.max(...temps) < 1500, 'aperçu rapide (' + temps.join(', ') + ' ms)');

  // L'Élite a sa date de reprise publiée ; le club 0 a des derbys de championnat datés.
  assert.ok(apercus.get(0).rivals.length > 0 && apercus.get(0).rivals.some(r => r.dates.length > 0));

  // Après la création avec ce club, la carrière retrouve l'aperçu.
  for (const club of clubs) {
    const p = apercus.get(club);
    const model = jeu.call('new_career', { mode: 'world-champ', club, start: 'premiers-clubs' });
    const calendrier = model.calendar.filter(x => !x.played).sort((a, b) => a.date.localeCompare(b.date) || a.id.localeCompare(b.id));
    const premier = calendrier[0];
    const domicile = premier.home.id === club;
    // Coup d'envoi : publié dans l'aperçu, sinon null (la carrière affiche alors une heure simulée).
    const { opponentName, kickoff, ...attendu } = p.firstFixture;
    assert.deepEqual({
      date: premier.date, opponentId: domicile ? premier.away.id : premier.home.id,
      home: domicile, competition: premier.competitionId, round: premier.competitionRound + 1,
    }, attendu, '1re rencontre du club ' + club);
    if (kickoff !== null) assert.equal(premier.kickoffLocal, kickoff, 'coup d’envoi du club ' + club);
    assert.equal(opponentName, (domicile ? premier.away : premier.home).name, 'adversaire du club ' + club);
    const reprise = model.clubLife.reprise.club;
    assert.equal(reprise.habitual, p.reprise.club, 'date habituelle de reprise du club ' + club);
    assert.equal(reprise.firstMatch, premier.date);
    assert.deepEqual(reprise.friendlies, p.friendlies.dates, 'amicaux du club ' + club);
    for (const r of p.rivals) {
      const dates = model.calendar.filter(x => x.phase === 'league' && [x.home.id, x.away.id].includes(r.id)).map(x => x.date).sort();
      assert.deepEqual(r.dates.slice().sort(), dates, 'derby ' + club + '-' + r.id);
    }
    if (p.president) {
      const nom = JSON.parse(jeu.bridge.vm.run('JSON.stringify(S.clubDirections?.clubs?.[' + club + ']?.president?.name??null)'));
      assert.equal(nom, p.president.name, 'président du club ' + club);
    }
    const effectif = new Set(model.squad.map(x => x.id));
    for (const role of ['leader', 'best', 'prospect']) assert.ok(effectif.has(p.faces[role].id), role + ' dans l’effectif du club ' + club);
  }
});

test('club_preview ne change rien à la carrière créée ensuite (même graine, même état)', { timeout: 600000 }, t => {
  const etat = apercu => {
    const jeu = ouvrir({ testVm: true });
    try {
      jeu.call('snapshot');
      if (apercu) for (const club of [0, 102]) jeu.call('club_preview', { club });
      jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'premiers-clubs' });
      return jeu.bridge.vm.run('JSON.stringify(S)');
    } finally { jeu.fermer(); }
  };
  assert.ok(etat(false) === etat(true), 'carrière identique avec ou sans aperçu préalable');
});
