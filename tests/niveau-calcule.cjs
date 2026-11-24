'use strict';
// Niveau calculé (planche notation façon FM, module isolé) : table complète, rôles identiques à l'écran, bornes, poids.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const N = require('../native/engine/niveau-calcule.cjs');

const joueur = (famille, valeur = 60, extra = {}) => ({
  id: 'test:1', gameplayPosition: Object.keys(N.FAMILLE_POSTE).find(k => N.FAMILLE_POSTE[k] === famille),
  attributesV2: Object.fromEntries(N.CLES.map(k => [k, valeur])), hiddenTraitsV2: { consistency: 61, bigMatches: 61 }, ...extra
});

test('36 qualités, 10 familles, 3 rôles par famille', () => {
  assert.equal(N.CLES.length, 36);
  assert.equal(N.FAMILLES.length, 10);
  for (const f of N.FAMILLES) {
    assert.equal(N.ROLES.filter(r => r[1] === f).length, 3, f);
    for (const k of Object.keys(N.POIDS_POSTE[f])) assert.ok(N.CLES.includes(k), f + ' ' + k);
  }
  for (const r of N.ROLES) for (const k of [...r[3], ...r[4]]) assert.ok(N.CLES.includes(k), r[0] + ' ' + k);
});

test('rôles identiques à la fiche joueur (fiche_roles.gd)', () => {
  const gd = fs.readFileSync(path.join(__dirname, '..', 'native', 'godot', 'ui', 'immersive08', 'fiche_roles.gd'), 'utf8');
  const lignes = [...gd.matchAll(/^\t\["([a-z-]+)", "([a-z]+)", "([^"]+)", \[([^\]]*)\], \[([^\]]*)\]\],$/gm)];
  const liste = s => s.split(',').map(x => x.trim().replace(/"/g, ''));
  assert.equal(lignes.length, N.ROLES.length);
  lignes.forEach((m, i) => assert.deepEqual([m[1], m[2], m[3], liste(m[4]), liste(m[5])], [...N.ROLES[i].slice(0, 3), [...N.ROLES[i][3]], [...N.ROLES[i][4]]]));
});

test('bornes 15-99 et qualités uniformes : niveau indépendant du poste', () => {
  for (const f of N.FAMILLES) {
    assert.equal(N.niveauJoueur(joueur(f, 20)).niveau, Math.max(15, Math.round(N.CALAGE.A * (0.92 * 20 + 0.08 * 61) + N.CALAGE.B)));
    assert.ok(N.niveauJoueur(joueur(f, 97)).niveau <= 99);
  }
});

test('la qualité du cœur du poste pèse plus qu’une qualité marginale', () => {
  const base = joueur('pilier');
  const melee = joueur('pilier', 60); melee.attributesV2.scrumTechnique = 90;
  const pied = joueur('pilier', 60); pied.attributesV2.kickDistance = 90;
  assert.ok(N.niveauJoueur(melee).brut - N.niveauJoueur(base).brut > 5 * (N.niveauJoueur(pied).brut - N.niveauJoueur(base).brut));
});

test('qualités compressées (nativeAttributesV1) lues comme attributesV2', () => {
  const p = joueur('ailier', 55);
  const q = { ...p, attributesV2: undefined, nativeAttributesV1: N.CLES.map(() => '55').join('') };
  assert.equal(N.niveauJoueur(q).niveau, N.niveauJoueur(p).niveau);
  assert.equal(N.niveauJoueur({ id: 'x', gameplayPosition: 'Ailier' }), null);
});
