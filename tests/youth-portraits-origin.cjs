'use strict';
// Portraits des jeunes cohérents avec leur origine (#610) et noms uniques par club.
// La banque v2 étiquette la teinte de peau de ses 160 bases joueurs (les 32 historiques l'ont été le 13/11/2026).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const { context } = require('./france-harness.cjs');
const worldVm = require('../native/engine/world-vm.cjs');
const registry = require('../native/engine/world-registry.json');
const portraits = require('../native/engine/portraits.cjs');

const root = path.resolve(__dirname, '..');
const catalogue = JSON.parse(fs.readFileSync(path.join(root, 'native/godot/art/regen-bank-v2/catalogue.json'), 'utf8'));
const TONE = { fair: 'L', light: 'L', tan: 'T', brown: 'B', deep: 'D' };
const tones = Array.from({ length: 160 }, () => '.');
for (const base of catalogue.bases.filter(b => b.kind === 'player')) {
  const tone = base.observedTraits?.skinTone;
  if (tone) tones[Number(base.id.split(':')[1])] = TONE[tone];
}
function world() {
  const h = context(437493);
  h.ctx.nativeWorldRegistryText = JSON.stringify(registry);
  h.run(worldVm.bootstrap());
  h.run("CDWorldCareer.start(0, 'world', true);");
  return h;
}
const toneOf = player => tones[portraits.describe(player).cell];

test('La table de teintes embarquée suit le catalogue de la banque v2', () => {
  const h = context(437493);
  assert.equal(h.run('PORTRAIT_TONES'), tones.join(''));
  assert.equal(tones.filter(t => t !== '.').length, 160, 'les 160 bases sont étiquetées');
});

test('Teintes par origine : pays du Pacifique et d’Afrique australe orientés, Europe majoritairement claire, variété gardée', () => {
  const h = context(437493);
  const result = JSON.parse(h.run(`(function () {
    const out = {};
    for (const nation of Object.keys(YOUTH_LOOKS)) {
      out[nation] = Array.from({ length: 1500 }, (_, i) => {
        const id = 'youth-3-2-' + i, look = youthLookId(id, nation);
        return [id, look];
      });
    }
    return JSON.stringify(out);
  })()`));
  const allowed = { FIJ: 'TBD', TGA: 'TBD', SAM: 'TBD', NAM: 'TBD', ZIM: 'TBD', JPN: 'LT', KOR: 'LT', FRA: 'LTBD', RSA: 'LTBD' };
  for (const [nation, rows] of Object.entries(result)) {
    const counts = {};
    for (const [id, look] of rows) {
      if (look != null) assert.ok(look.startsWith(id + ':look'), look);
      const tone = toneOf({ appearanceBankVersion: 2, id, ...(look == null ? {} : { appearanceId: look }) });
      counts[tone] = (counts[tone] || 0) + 1;
    }
    assert.ok(!counts['.'], `${nation} : aucune base non étiquetée`);
    if (allowed[nation]) assert.ok(Object.keys(counts).every(t => allowed[nation].includes(t)), `${nation} ${JSON.stringify(counts)}`);
    // Un identifiant dont la cellule convient déjà garde son comportement historique : pas de variante.
    const natural = rows.filter(([, look]) => look == null).length;
    assert.ok(natural > 0 && natural < rows.length, `${nation} : ${natural}`);
  }
  const share = (nation, tone, rows = result[nation]) => rows.filter(([id, look]) => toneOf({ appearanceBankVersion: 2, id, ...(look == null ? {} : { appearanceId: look }) }) === tone).length / rows.length;
  assert.ok(share('FIJ', 'D') > .28 && share('FIJ', 'D') < .42, String(share('FIJ', 'D')));
  assert.ok(share('FIJ', 'T') > .14 && share('FIJ', 'T') < .26);
  assert.ok(share('FRA', 'L') > .58 && share('FRA', 'L') < .74, String(share('FRA', 'L')));
  assert.ok(share('FRA', 'D') < .05);
  assert.ok(share('RSA', 'D') > .15 && share('RSA', 'B') > .2, 'Afrique du Sud : mélange de teintes');
});

test('Un jeune formé en France : la teinte suit son origine tirée par youthHeritage', () => {
  const h = world();
  const r = JSON.parse(h.run(`S.clubs[3].country = 'FR'; (function () {
    const club = S.clubs[3], rows = [];
    for (let i = 0; i < 400; i++) {
      const p = academyPlayer(3, i % 15, 7, 5000 + i, false, club);
      rows.push({ id: p.id, appearanceId: p.appearanceId, origin: youthHeritage(p.id, 'FRA') });
      club.players.push(p);
    }
    return JSON.stringify(rows);
  })()`));
  const supports = { FRA: 'LTBD', FIJ: 'TBD', TGA: 'TBD', SAM: 'TBD', GEO: 'LTB', RSA: 'LTBD', POR: 'LTBD', ENG: 'LTBD', ARG: 'LTB', NZL: 'LTBD' };
  const pacific = r.filter(x => ['FIJ', 'TGA', 'SAM'].includes(x.origin));
  assert.ok(pacific.length > 0);
  for (const row of r) {
    const tone = toneOf({ appearanceBankVersion: 2, id: row.id, ...(row.appearanceId == null ? {} : { appearanceId: row.appearanceId }) });
    assert.ok(supports[row.origin].includes(tone), `${row.origin} ${tone}`);
  }
});

test('Aucun doublon de nom dans un même club (effectif et centre), même quand la liste de noms du pays est épuisée', () => {
  const h = context();
  h.ctx.nativeWorldRegistryText = JSON.stringify(registry);
  h.run(worldVm.bootstrap());
  const r = JSON.parse(h.run(`CDWorldCareer.start(0, 'world', true);
    (function () {
      const japanese = S.clubs[5]; japanese.country = 'JP';
      const academy = S.aiRoster.academies.find(a => a.clubId === japanese.id);
      for (let i = 0; i < 450; i++) academy.players.push(academyPlayer(japanese.id, i % 15, 9, 9000 + i, false, japanese));
      const names = [...japanese.players, ...academy.players].map(p => p.name);
      const youth = academy.players.filter(p => /^youth-\\d+-9-9\\d{3}$/.test(p.id));
      const count = {}; for (const n of names) count[n] = (count[n] || 0) + 1;
      // Tous les centres générés au démarrage : aucun nom de jeune en double dans son club.
      const clubs = S.clubs.map(c => {
        const a = S.aiRoster.academies.find(x => x.clubId === c.id), list = [...c.players, ...(a ? a.players : [])];
        const seen = {}; for (const p of list) seen[p.name] = (seen[p.name] || 0) + 1;
        return (a ? a.players : []).filter(p => seen[p.name] > 1).length;
      });
      return JSON.stringify({ youth: youth.length, duplicates: youth.filter(p => count[p.name] > 1).length, clubs: clubs.reduce((a, b) => a + b, 0),
        pro: japanese.players.length, compound: youth.filter(p => p.name.split(' ')[0].includes('-')).length });
    })()`));
  assert.equal(r.youth, 450);
  assert.equal(r.duplicates, 0);
  assert.equal(r.clubs, 0, 'centres du départ : aucun doublon avec le club');
  assert.ok(r.compound > 0, 'les prénoms composés servent quand la liste est épuisée');
});

test('Hors carrière monde : aucun changement (ni portrait salé, ni nom modifié)', () => {
  const h = context(437493);
  const r = JSON.parse(h.run(`start(0, 'france'); JSON.stringify(Array.from({ length: 60 }, (_, i) => academyPlayer(2, i % 15, 3, 100 + i, false, S.clubs[2]).appearanceId ?? null))`));
  assert.ok(r.every(x => x === null));
});

test('Le même identifiant donne toujours le même nom et le même portrait quand le club n’a rien changé', () => {
  const h = world();
  const r = JSON.parse(h.run(`JSON.stringify([academyPlayer(2, 4, 3, 77, false, S.clubs[2]), academyPlayer(2, 4, 3, 77, false, S.clubs[2])].map(p => [p.name, p.appearanceId ?? null]))`));
  assert.deepEqual(r[0], r[1]);
});

test('Un identifiant renommé après la création garde son portrait : l’appearanceId salé reste la racine stable', () => {
  const h = world();
  const rows = JSON.parse(h.run(`S.clubs[3].country = 'FIJ'.slice(0, 2); S.clubs[3].country = 'FJ';
    JSON.stringify(Array.from({ length: 40 }, (_, i) => { const p = academyPlayer(3, i % 15, 4, 700 + i, false, S.clubs[3]); const before = p.appearanceId ?? null; p.id = 'p3-' + i + '-renomme'; return [before, p.appearanceId ?? null]; }))`));
  assert.ok(rows.some(([a]) => a !== null), 'des jeunes ont un identifiant d’apparence salé');
  for (const [before, after] of rows) assert.equal(before, after);
  const salted = rows.find(([a]) => a !== null)[0];
  assert.match(salted, /^[A-Za-z0-9:_.-]{1,180}$/);
  assert.equal(portraits.describe({ appearanceBankVersion: 2, id: 'p3-0-renomme', appearanceId: salted }).appearanceId, salted);
});
