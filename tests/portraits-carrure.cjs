'use strict';
// Portraits cohérents avec la carrure (poids, taille, poste) et l'origine, pour les pros comme pour les jeunes.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { context } = require('./france-harness.cjs');
const makeFacts = require('../native/engine/player-facts.cjs');
const looks = require('../native/engine/portrait-looks.cjs');
const portraits = require('../native/engine/portraits.cjs');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');

const catalogue = require('../native/godot/art/regen-bank-v2/catalogue.json');
const bases = catalogue.bases.filter(b => b.kind === 'player');
const facts = makeFacts({ players: {
  heavy: { heightCm: 183, weightKg: 128, nationality: 'Fidji', flagCode: 'fj' },
  slight: { heightCm: 176, weightKg: 79, nationality: 'France', flagCode: 'fr' },
  tallLock: { heightCm: 203, weightKg: 118, nationality: 'France', flagCode: 'fr' },
} }, {}, {});
const instance = looks.createLooks(facts);
const player = (id, pos, extra = {}) => ({ id, name: 'Joueur ' + id, pos, age: 26, appearanceBankVersion: 2, ...extra });
const POSITIONS = ['Pilier gauche', 'Talonneur', 'Pilier droit', 'Deuxième ligne', 'Troisième ligne', 'Numéro 8', 'Demi de mêlée', 'Demi d’ouverture', 'Ailier', 'Centre', 'Arrière'];

test('Chaque base joueur porte une carrure et une teinte dans le catalogue, avec assez de bases par classe', () => {
  assert.equal(bases.length, 160);
  const counts = {};
  for (const b of bases) {
    assert.ok(['fine', 'moyenne', 'costaude', 'tres-costaude'].includes(b.carrure), b.id);
    assert.ok(['fair', 'light', 'tan', 'brown', 'deep'].includes(b.observedTraits.skinTone), b.id);
    counts[b.carrure] = (counts[b.carrure] || 0) + 1;
  }
  assert.deepEqual(counts, catalogue.carrureReview.counts);
  for (const n of Object.values(counts)) assert.ok(n >= 30, JSON.stringify(counts));
  // Les étiquettes de carrure suivent l'estimation de morphologie déjà présente : jamais l'opposé exact.
  const build = { slender: 1, average: 2, powerful: 3, heavyset: 4 }, rank = { fine: 1, moyenne: 2, costaude: 3, 'tres-costaude': 4 };
  for (const b of bases.filter(b => b.observedTraits.build)) assert.ok(Math.abs(build[b.observedTraits.build] - rank[b.carrure]) <= 2, b.id);
});

test('Les tables de teinte et de carrure embarquées (moteur et banque embarquée) suivent le catalogue', () => {
  const tone = { fair: 'L', light: 'L', tan: 'T', brown: 'B', deep: 'D' }, rank = { fine: 1, moyenne: 2, costaude: 3, 'tres-costaude': 4 };
  assert.equal(looks.TONES.join(''), bases.map(b => tone[b.observedTraits.skinTone]).join(''));
  assert.equal(looks.CARRURES.join(''), bases.map(b => rank[b.carrure]).join(''));
  const h = context(437493);
  assert.equal(h.run('PORTRAIT_TONES'), looks.TONES.join(''));
  const dev = JSON.parse(h.run('JSON.stringify(YOUTH_LOOKS)'));
  for (const [nation, table] of Object.entries(dev)) assert.deepEqual(looks.LOOKS[nation], table, nation);
});

test('Carrure attendue : mensurations documentées sinon poste (forwards costauds, demis/ailiers/arrière fins, centres moyens)', () => {
  const score = pos => looks.expectedScore({ pos });
  for (const pos of ['Pilier gauche', 'Pilier droit', 'Talonneur', 'Deuxième ligne', 'Troisième ligne', 'Numéro 8']) assert.ok(score(pos) >= .5, pos);
  for (const pos of ['Demi de mêlée', 'Demi d’ouverture', 'Ailier', 'Arrière']) assert.ok(score(pos) <= -.4, pos);
  assert.equal(score('Centre'), 0);
  const heavy = facts.project('heavy', null, player('heavy', 'Ailier')), slight = facts.project('slight', null, player('slight', 'Pilier gauche'));
  assert.equal(heavy.dimensionsSource, 'documented');
  assert.ok(looks.expectedScore({ pos: 'Ailier', ...heavy }) > .9, 'un ailier documenté à 128 kg est très costaud');
  assert.ok(looks.expectedScore({ pos: 'Pilier gauche', ...slight }) < -.5, 'un pilier documenté à 79 kg est fin');
  assert.ok(looks.expectedScore({ pos: 'Deuxième ligne', ...facts.project('tallLock', null, player('tallLock', 'Deuxième ligne')) }) < .6, 'la taille allège le poids');
});

test('Un pilier de 125 kg ne reçoit plus un visage fin d’ailier ; un demi fin ne reçoit plus un visage de pilier', () => {
  let heavy = 0, slight = 0;
  for (let i = 0; i < 600; i++) {
    const prop = instance.resolve(player('prop-' + i, 'Pilier gauche')), scrumHalf = instance.resolve(player('sh-' + i, 'Demi de mêlée'));
    assert.ok(looks.fits(.85, prop.cell) && !looks.far(.85, prop.cell), 'pilier ' + i);
    assert.ok(looks.fits(-.6, scrumHalf.cell) && !looks.far(-.6, scrumHalf.cell), 'demi ' + i);
    if (looks.CARRURES[prop.cell] >= 3) heavy++;
    if (looks.CARRURES[scrumHalf.cell] <= 2) slight++;
  }
  assert.equal(heavy, 600); assert.equal(slight, 600);
  const doc = instance.resolve(player('heavy', 'Ailier'));
  assert.ok(looks.CARRURES[doc.cell] >= 3, 'mensurations documentées prioritaires sur le poste');
});

test('Le portrait est déterministe, garde l’identifiant quand il convient déjà et suit la teinte d’origine', () => {
  const a = instance.resolve(player('stable-1', 'Pilier gauche')), b = instance.resolve(player('stable-1', 'Pilier gauche'));
  assert.deepEqual(a, b);
  const already = Array.from({ length: 400 }, (_, i) => player('keep-' + i, 'Centre')).filter(p => { const c = portraits.hash(p.id) % 160, want = looks.wantedTone(p.id, facts.origin(p.id)); return looks.fits(0, c) && (want === null || looks.TONES[c] === want); });
  assert.ok(already.length > 0);
  for (const p of already) assert.equal(instance.resolve(p).appearanceId, p.id);
  // Joueur fidjien documenté : teinte du Pacifique (jamais claire), carrure respectée.
  for (let i = 0; i < 200; i++) {
    const id = 'heavy', r = instance.resolve(player(id, 'Pilier gauche', { appearanceId: undefined }));
    assert.notEqual(r.tone, 'L');
  }
  // Teintes par origine : la table du Pacifique n'admet aucun visage clair.
  let fiji = 0;
  for (let i = 0; i < 300; i++) {
    const r = looks.wantedTone('fij-' + i, 'FIJ');
    assert.ok('TBD'.includes(r));
    fiji++;
  }
  assert.equal(fiji, 300);
  // Un jeune déjà orienté (identifiant salé) garde sa teinte ; seule la carrure peut re-saler.
  const youth = instance.resolve(player('youth-3-2-5', 'Pilier gauche', { appearanceId: 'youth-3-2-5:look2' }));
  assert.ok(youth.appearanceId.startsWith('youth-3-2-5:look2'));
  assert.ok(looks.fits(.85, youth.cell));
});

test('Banque historique (32 visages) : carrure respectée sans promotion vers la banque v2', () => {
  for (let i = 0; i < 300; i++) {
    const r = instance.resolve(player('old-' + i, i % 2 ? 'Demi de mêlée' : 'Pilier droit', { appearanceBankVersion: undefined }));
    assert.ok(r.cell < 32);
    assert.ok(looks.fits(i % 2 ? -.6 : .85, r.cell));
  }
});

test('Paramètres du visage : la carrure élargit ou affine, avec un aléa propre au joueur, sans sortir du rendu crédible', () => {
  const plain = portraits.describe(player('param-1', 'Pilier gauche'));
  assert.equal(plain.build, undefined, 'sans carrure, rien ne change');
  const wide = portraits.describe(player('param-1', 'Pilier gauche', { appearanceBuild: 1 })), thin = portraits.describe(player('param-1', 'Pilier gauche', { appearanceBuild: -1 }));
  assert.ok(wide.faceWidth < thin.faceWidth && wide.jawWidth < thin.jawWidth, 'visage plus large = facteur du shader plus petit');
  assert.ok(thin.faceWidth - wide.faceWidth > .08 && thin.faceWidth - wide.faceWidth < .12);
  for (let i = 0; i < 500; i++) {
    for (const build of [-1, -.5, 0, .5, 1]) {
      const d = portraits.describe(player('rand-' + i, 'Ailier', { appearanceBuild: build }));
      assert.ok(d.faceWidth > .93 && d.faceWidth < 1.07, String(d.faceWidth));
      assert.ok(Math.abs(d.jawWidth) < .04);
      assert.ok(d.zoom >= 1.005 && d.zoom <= 1.032, 'pas de bord étiré : le zoom reste ≥ 1');
    }
  }
  const a = portraits.describe(player('rand-a', 'Ailier', { appearanceBuild: .5 })), b = portraits.describe(player('rand-b', 'Ailier', { appearanceBuild: .5 }));
  assert.notEqual(a.faceWidth, b.faceWidth, 'l’aléa propre au joueur est conservé');
  for (const bad of [2, -1.5, NaN, '1', null]) assert.equal(portraits.describe(player('param-1', 'Pilier gauche', { appearanceBuild: bad })).build, undefined);
  const gd = fs.readFileSync(path.join(__dirname, '../native/godot/ui/regen_portrait.gd'), 'utf8');
  for (const piece of ['1.0-.05*build+(face_width-1.0)*.45', '-.024*build+jaw_width*.6', '1.005+(zoom-1.005)*.6+.012*(1.0-build)/2.0']) assert.ok(gd.includes(piece), 'la version GDScript applique la même formule : ' + piece);
});

test('Le parcours d’un modèle projeté corrige les joueurs (pros, jeunes, marché) sans toucher aux membres du staff', () => {
  const model = { squad: [player('m-1', 'Pilier gauche')], market: [player('m-2', 'Demi de mêlée')], decisions: { staff: [{ id: 's-1', name: 'Coach', role: 'Entraîneur', age: 50 }] } };
  const before = JSON.stringify(model.decisions);
  instance.apply(model);
  assert.ok(typeof model.squad[0].appearanceBuild === 'number' && typeof model.market[0].appearanceBuild === 'number');
  assert.ok(looks.fits(.85, portraits.describe(model.squad[0]).cell) && looks.fits(-.6, portraits.describe(model.market[0]).cell));
  assert.equal(JSON.stringify(model.decisions), before);
});

test('Bilan sur 3000 joueurs simulés : plus aucune carrure incohérente avec le poste, tous postes et origines', () => {
  let before = 0, after = 0, far0 = 0, far1 = 0;
  for (let i = 0; i < 3000; i++) {
    const pos = POSITIONS[i % POSITIONS.length], p = player('bulk-' + i, pos), score = looks.expectedScore({ pos });
    const c0 = portraits.hash(p.id) % 160, r = instance.resolve(p);
    if (!looks.fits(score, c0)) before++; if (!looks.fits(score, r.cell)) after++;
    if (looks.far(score, c0)) far0++; if (looks.far(score, r.cell)) far1++;
  }
  assert.ok(before > 1000, 'avant : beaucoup d’incohérences ' + before);
  assert.equal(after, 0); assert.equal(far1, 0); assert.ok(far0 > 400);
});

test('Moteur réel : le portrait projeté est cohérent, la sauvegarde n’est ni modifiée ni écrite par la consultation', t => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-carrure-'));
  const b = createBridge({ dataDir: dir, seed: 827381, now: 1700000000000 });
  t.after(() => { b.close(); fs.rmSync(dir, { recursive: true, force: true }); });
  let serial = 0;
  const go = (command, payload = {}) => { const r = b.handle({ id: ++serial, command, payload }); assert.equal(r.ok, true, r.error); return r.model; };
  const m = settleClubMeetings(go('new_career', { mode: 'common', club: 0 }), go);
  const saved = go('export').meta.exportText, file = path.join(dir, 'PrototypeGodot/donnees.json'), bytes = fs.readFileSync(file);
  assert.ok(m.squad.length >= 23);
  for (const p of m.squad) {
    assert.equal(typeof p.appearanceBuild, 'number', p.name);
    const score = looks.expectedScore({ pos: p.pos, ...(p.playerFacts ?? {}) });
    assert.ok(score === null || looks.fits(score, portraits.describe(p).cell), p.pos);
  }
  assert.ok(!saved.includes('appearanceBuild'), 'la carrure n’est jamais enregistrée');
  go('snapshot'); assert.equal(go('export').meta.exportText, saved); assert.deepEqual(fs.readFileSync(file), bytes);
});
