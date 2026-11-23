'use strict';
// Tests physiques avant le match et historique des blessures (native/engine/tests-physiques.cjs ; revue FM27 n° 36,
// choix A de Léo du 23/11/2026) : historique gardé dans la carrière, tests de reprise avec hasard, conseil du médecin
// jamais exact et d'autant plus juste qu'il est bon, risque de blessure qui grimpe au-delà de la vraie limite (pas de
// sortie forcée), message du médecin dans la Réception. Règles pures d'abord, puis carrière Monde réelle.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { factory } = require('../native/engine/tests-physiques.cjs');

const f = factory();
f.installHooks();
const t = f._tests;

test('Conseil du médecin : multiple de 5, jamais la vraie limite, plus juste avec un meilleur médecin', () => {
  const s = { season: 1, careerVariation: { seed: 7 } };
  const ecarts = { bon: [], moyen: [] };
  for (let i = 0; i < 400; i++) {
    const fx = { id: 'fx' + i }, p = { id: 'j' + i };
    const vrai = 15 + (i * 7) % 66;
    for (const [cle, niveau] of [['bon', 85], ['moyen', 45]]) {
      const m = t.conseil(s, fx, p, vrai, niveau);
      assert.ok(m % 5 === 0 && m >= 0 && m <= 80, 'conseil ' + m);
      assert.notEqual(m, vrai, 'jamais exact');
      if (m > 0) ecarts[cle].push(Math.abs(m - vrai));
    }
  }
  const moyenne = l => l.reduce((a, b) => a + b, 0) / l.length;
  assert.ok(moyenne(ecarts.bon) < moyenne(ecarts.moyen) - 2, moyenne(ecarts.bon) + ' / ' + moyenne(ecarts.moyen));
  assert.ok(Math.max(...ecarts.bon) <= 10, 'un très bon médecin reste proche');
});

test('Vraie limite : blessure longue et retour récent la font baisser, hasard borné', () => {
  const s = { season: 1, careerVariation: { seed: 3 } };
  const moyenne = (semaines, depuis) => {
    let n = 0;
    for (let i = 0; i < 200; i++) n += t.tolerance(s, { id: 'fx' + i }, { id: 'p' + i, condition: 95 }, { s: semaines, f: '2026-10-01' }, '2026-10-' + String(1 + depuis).padStart(2, '0'));
    return n / 200;
  };
  assert.ok(moyenne(1, 10) > moyenne(4, 10) + 8, 'blessure plus longue');
  assert.ok(moyenne(4, 14) > moyenne(4, 1) + 8, 'retour plus ancien');
  for (let i = 0; i < 200; i++) {
    const v = t.tolerance(s, { id: 'x' + i }, { id: 'y' + i, condition: 40 }, { s: 30, f: '2026-10-01' }, '2026-10-02');
    assert.ok(v >= f.RULES.MIN && v <= f.RULES.MAX);
  }
});

test('Risque en match : × 1 + 0,1 par minute au-delà de la vraie limite, pour la rencontre testée seulement', () => {
  globalThis.S = { testsPhysiques: { version: 1, historique: {}, tests: { fixture: 'm1', date: '2026-10-10', fait: '2026-10-08', medecin: { id: null, nom: null }, joueurs: [{ id: 'a', ok: false, conseil: 40, tolerance: 42, t: 'mollet', s: 2, retour: '2026-10-05' }] } } };
  const l = { worldContext: { id: 'm1' } };
  assert.equal(facteurTestPhysique({ id: 'a' }, 40, l), 1, 'sous la limite');
  assert.ok(Math.abs(facteurTestPhysique({ id: 'a' }, 62, l) - 3) < 1e-9, '20 minutes de trop : × 3');
  assert.equal(facteurTestPhysique({ id: 'a' }, 80, { worldContext: { id: 'm2' } }), 1, 'autre rencontre');
  assert.equal(facteurTestPhysique({ id: 'b' }, 80, l), 1, 'joueur non testé');
  assert.equal(f.validate(globalThis.S), true);
  for (const casse of [{ conseil: 42 }, { conseil: 43 }, { ok: true }, { tolerance: 90 }]) {
    const s = JSON.parse(JSON.stringify(globalThis.S));
    Object.assign(s.testsPhysiques.tests.joueurs[0], casse);
    assert.throws(() => f.validate(s), /Tests physiques/, JSON.stringify(casse));
  }
  delete globalThis.S;
});

test('Branchements : après le match et pendant (incident), courrier du médecin', () => {
  const lire = p => fs.readFileSync(path.join(__dirname, '..', p), 'utf8');
  assert.match(lire('dist/rugby.js'), /facteurFragilite\(p\):1\)\*\(typeof facteurTestPhysique==='function'\?facteurTestPhysique\(p,minutes,l\):1\)/);
  assert.match(lire('native/engine/incidents-match.cjs'), /facteurTestPhysique\(q,l\.sheets\[c\.side\]\.minutes/);
  const mail = require('../native/engine/club-mail.json');
  assert.equal(mail.types.tests_reprise.expediteur, 'Le médecin du club');
  assert.equal(mail.categories[mail.types.tests_reprise.categorie].label, 'Médical');
});

test('Carrière Monde : historique, tests de reprise, message du médecin, sauvegarde, ancienne carrière', { timeout: 900000 }, () => {
  const M = require('./helpers/carriere-monde.cjs');
  const jeu = M.ouvrir({ testVm: true, mandatoryPress: false });
  try {
    const vm = jeu.bridge.vm;
    const val = src => JSON.parse(vm.run(`JSON.stringify(${src})`));
    let m = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'veille' }));
    // Rendez-vous médical du blessé posé à la main : coupé (comme le harnais Monde), la suite vise le moteur des tests.
    const cmd = (nom, charge) => {
      vm.run('delete S.clubMeetings');
      let r = jeu.call(nom, charge);
      vm.run('delete S.clubMeetings');
      for (const decision of r?.clubLife?.reprise?.due || []) r = jeu.call('reprise_decide', { decision, option: 'staff' });
      return r;
    };
    // Un titulaire blessé (mollet, entraînement) : la ligne s'ouvre au relevé suivant.
    const id = val('S.lineup.find(Boolean)');
    const joueur = `S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(id)})`;
    vm.run(`{const p=${joueur};p.injury=2;p.injuryType='mollet';p.injuryDate=CDWorldCareer.calendarToday(S);p.injuryCause='entrainement';}`);
    m = cmd('set_delegation', { key: 'lineup', enabled: false });
    let h = m.clubLife.testsPhysiques.historique[id];
    assert.ok(h && h.length === 1 && h[0].enCours && h[0].type === 'mollet' && h[0].semaines === 2 && h[0].cause === 'entrainement', JSON.stringify(h));
    // Guérison : la ligne se ferme à la date du jour.
    vm.run(`${joueur}.injury=0`);
    m = cmd('advance_day', { fromDate: m.meta.calendarToday });
    h = m.clubLife.testsPhysiques.historique[id];
    assert.ok(h[0].fin && !h[0].enCours, JSON.stringify(h));
    // Jours jusqu'au match : tests faits deux jours avant, joueur testé une fois.
    for (let j = 0; j < 30 && !m.clubLife.testsPhysiques.tests; j++) {
      if (m.meta.calendarCadence?.matchReady) break;
      m = cmd('advance_day', { fromDate: m.meta.calendarToday });
    }
    const tests = m.clubLife.testsPhysiques.tests;
    assert.ok(tests, 'tests de reprise avant la rencontre');
    const ligne = tests.joueurs.find(x => x.id === id);
    assert.ok(ligne && typeof ligne.ok === 'boolean' && ligne.minutes % 5 === 0 && ligne.type === 'mollet', JSON.stringify(tests));
    assert.equal(ligne.tolerance, undefined, 'la vraie limite n’est jamais projetée');
    const etat = val('S.testsPhysiques.tests.joueurs').find(x => x.id === id);
    assert.notEqual(etat.conseil, etat.tolerance, 'conseil jamais exact');
    assert.equal(val(`S.testsPhysiques.historique[${JSON.stringify(id)}].at(-1).x`), tests.fixture);
    // Message du médecin dans la Réception.
    const mails = m.clubLife.clubMail.mails.filter(x => x.type === 'tests_reprise');
    assert.equal(mails.length, 1, 'un message du médecin');
    assert.match(mails[0].corps, new RegExp(val(`${joueur}.name`)));
    assert.match(mails[0].corps, /\((réussi|échoué), /);
    // Risque en match : au-delà de la vraie limite seulement.
    const fx = JSON.stringify(tests.fixture);
    assert.equal(val(`facteurTestPhysique(${joueur},${etat.tolerance},{worldContext:{id:${fx}}})`), 1);
    assert.ok(Math.abs(val(`facteurTestPhysique(${joueur},${etat.tolerance + 10},{worldContext:{id:${fx}}})`) - 2) < 1e-9);
    // Le match se joue (aucune sortie forcée), l'état reste valide et survit à l'aller-retour de sauvegarde.
    m = M.jouerLeMatch(jeu, M.jusquAuMatch(jeu, m));
    vm.run('validateCareer(S)');
    vm.run('pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import");validateCareer(S)');
    assert.equal(val(`S.testsPhysiques.historique[${JSON.stringify(id)}].length`), 1, 'historique gardé par la sauvegarde');
    // Ancienne carrière : l'historique part des commotions enregistrées.
    vm.run(`delete S.testsPhysiques;${joueur}.commotion={version:1,n:1,hist:[{date:'2026-08-02',retour:'2026-08-14'}],protocole:null};`);
    m = cmd('advance_day', { fromDate: m.meta.calendarToday });
    h = m.clubLife.testsPhysiques.historique[id];
    assert.ok(h && h.some(e => e.type === 'commotion' && e.date === '2026-08-02' && e.fin === '2026-08-14'), JSON.stringify(h));
  } finally { jeu.fermer(); }
});
