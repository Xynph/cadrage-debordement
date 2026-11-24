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

test('bornes 15-99 ; qualités uniformes : Niveau = qualités + profil du meilleur rôle (écart au joueur typique)', () => {
  for (const f of N.FAMILLES) {
    // Qualités toutes égales : la note de chaque rôle est la même, seul reste le recentrage (−CENTRE_ROLE) borné.
    const bonus = Math.max(...N.ROLES.filter(r => r[1] === f).map(r => Math.max(-N.PROFIL_MAX, Math.min(N.PROFIL_MAX, -N.CENTRE_ROLE[r[0]]))));
    assert.equal(N.niveauJoueur(joueur(f, 20)).niveau, Math.max(15, Math.round(N.CALAGE.A * (0.92 * (20 + N.PART_ROLE * bonus) + 0.08 * 61) + N.CALAGE.B)), f);
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

// --- Le rôle compte (écart 4 du vérificateur, 25/11) : mesures sur la base mondiale des tests -------------------------
const zlib = require('node:zlib');
const monde = (() => {
  const t = JSON.parse(zlib.gunzipSync(fs.readFileSync(path.join(__dirname, 'fixtures', 'monde-champ-102-main-690a7ced4.json.gz'))));
  return JSON.parse(t.store['bdt-v1']).clubs.flatMap(c => c.players || []);
})();
const typiques = {};
const typique = famille => ({ ...(typiques[famille] ||= (() => {
  const ps = monde.filter(p => N.familleDe(p) === famille);
  return Object.fromEntries(N.CLES.map(k => [k, Math.round(ps.reduce((t, p) => t + N.qualites(p)[k], 0) / ps.length)]));
})()) });
const profil = (famille, ecarts) => {
  const base = typique(famille);
  for (const [k, v] of Object.entries(ecarts)) base[k] += v;
  return joueur(famille, 60, { attributesV2: base });
};
const auRole = (p, id) => N.niveauJoueur(p, { roleId: id }).niveau;

test('3e ligne aile : profil de gratteur ≥ 1 cran (2 points) au-dessus du Plaqueur, et inversement', () => {
  const gratteur = profil('aile', { jackal: 12, ruckClearout: 10, anticipation: 6, tackling: -5 });
  const plaqueur = profil('aile', { tackling: 12, positioning: 8, endurance: 8, jackal: -5 });
  assert.ok(auRole(gratteur, 'aile-gratteur') - auRole(gratteur, 'aile-plaqueur') >= 2, JSON.stringify(N.niveauJoueur(gratteur).roles));
  assert.ok(auRole(plaqueur, 'aile-plaqueur') - auRole(plaqueur, 'aile-gratteur') >= 2, JSON.stringify(N.niveauJoueur(plaqueur).roles));
  assert.equal(N.niveauJoueur(gratteur).role, 'aile-gratteur');
  assert.equal(N.niveauJoueur(plaqueur).role, 'aile-plaqueur');
  // Joueur typique du poste : les rôles se tiennent à 1 point près.
  const t = N.niveauJoueur(joueur('aile', 60, { attributesV2: typique('aile') })).roles.map(r => r.niveau);
  assert.ok(Math.max(...t) - Math.min(...t) <= 1, String(t));
});

test('chaque poste : un profil marqué sur les qualités clés d’un rôle fait gagner ce rôle d’au moins 2 points', () => {
  for (const r of N.ROLES) {
    const autres = N.ROLES.filter(x => x[1] === r[1] && x[0] !== r[0]);
    const ecarts = {};
    for (const k of r[3]) ecarts[k] = 10;
    for (const x of autres) for (const k of x[3]) if (!r[3].includes(k) && !r[4].includes(k)) ecarts[k] = -5;
    const p = profil(r[1], ecarts);
    for (const x of autres) assert.ok(auRole(p, r[0]) - auRole(p, x[0]) >= 2, r[0] + ' / ' + x[0] + ' ' + JSON.stringify(N.niveauJoueur(p).roles));
  }
});

test('Monde : écarts entre rôles réels, meilleurs rôles répartis, Niveau moyen par poste sans dérive', () => {
  const parFamille = {};
  for (const p of monde) {
    const n = N.niveauJoueur(p);
    if (!n) continue;
    const f = (parFamille[n.famille] ||= { ecarts: [], meilleurs: {}, niveaux: [], ratings: [] });
    const v = n.roles.map(r => r.niveau);
    f.ecarts.push(Math.max(...v) - Math.min(...v));
    f.meilleurs[n.role] = (f.meilleurs[n.role] || 0) + 1;
    f.niveaux.push(n.niveau); f.ratings.push(p.rating);
  }
  const moy = a => a.reduce((s, v) => s + v, 0) / a.length;
  for (const [nom, f] of Object.entries(parFamille)) {
    assert.ok(moy(f.ecarts) >= 2, nom + ' écart moyen entre rôles ' + moy(f.ecarts));
    assert.ok(Math.max(...f.ecarts) <= 2 * Math.ceil(N.CALAGE.A * 0.92 * N.PART_ROLE * N.PROFIL_MAX) + 1, nom + ' écart borné');
    const parts = Object.values(f.meilleurs).map(c => c / f.niveaux.length);
    assert.equal(parts.length, 3, nom + ' : les trois rôles sont parfois le meilleur');
    assert.ok(Math.max(...parts) <= 0.6 && Math.min(...parts) >= 0.15, nom + ' ' + JSON.stringify(f.meilleurs));
    assert.ok(Math.abs(moy(f.niveaux) - moy(f.ratings)) <= 3, nom + ' Niveau moyen ' + moy(f.niveaux) + ' / rating ' + moy(f.ratings));
  }
});

test('calage reporté dans le module = calage recalculé sur la base mondiale ; centres de somme nulle par poste', () => {
  const c = N.caler(monde);
  for (const [id, v] of Object.entries(c.centres)) assert.ok(Math.abs(v - N.CENTRE_ROLE[id]) < 0.02, id);
  assert.ok(Math.abs(c.A - N.CALAGE.A) < 0.002 && Math.abs(c.B - N.CALAGE.B) < 0.05, JSON.stringify(c));
  for (const f of N.FAMILLES) assert.ok(Math.abs(N.ROLES.filter(r => r[1] === f).reduce((t, r) => t + N.CENTRE_ROLE[r[0]], 0)) < 0.05, f);
});
