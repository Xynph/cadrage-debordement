'use strict';
// Recherche ciblée du recruteur (native/engine/recherche-ciblee.cjs ; idée FM27 n° 26, option B choisie par Léo le
// 23/11/2026) : critères lus par le moteur (maillot, rôle, note au poste et potentiel minimum, âge, indemnité,
// priorité, recruteurs), 5 000 € débités à l'envoi, nouveaux joueurs trouvés ensuite (libres ET sous contrat) qui
// deviennent observés, liste des joueurs déjà observés avec les estimations du recruteur. Carrière Monde réelle.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const { factory } = require('../native/engine/recherche-ciblee.cjs');
const { ouvrir, creer, jouer } = require('./helpers/carriere-monde.cjs');

const f = factory();

test('Table des rôles du moteur = table de l’écran (fiche_roles.gd)', () => {
  const gd = fs.readFileSync(path.resolve(__dirname, '../native/godot/ui/immersive08/fiche_roles.gd'), 'utf8');
  const lignes = [...gd.matchAll(/^\t\["([a-z-]+)", "([a-z]+)", "[^"]+", \[([^\]]*)\], \[([^\]]*)\]\],$/gm)];
  const liste = s => [...s.matchAll(/"([A-Za-z]+)"/g)].map(x => x[1]);
  const ecran = lignes.map(m => [m[1], m[2], liste(m[3]), liste(m[4])]);
  assert.equal(ecran.length, 30);
  assert.deepEqual(f.ROLES.map(r => [r[0], r[1], r[2].slice(), r[3].slice()]), ecran);
});

test('Priorité et recruteurs : nombre de nouveaux joueurs et semaines de travail', () => {
  const n = (priority, scouts) => f._tests.nombreNouveaux({ priority, scouts: Array(scouts).fill(0).map((_, i) => 's' + i) });
  assert.deepEqual([n('prioritaire', 1), n('standard', 1), n('continue', 1)], [3, 2, 1]);
  assert.deepEqual([n('standard', 0), n('standard', 2), n('standard', 3), n('standard', 5)], [2, 3, 4, 4], 'un recruteur de plus = un joueur de plus (+2 au plus)');
  assert.deepEqual(f.SEMAINES, { prioritaire: 1, standard: 2, continue: 2 });
  assert.equal(f.COUT, 5000);
});

test('Carrière Monde : mission payée, critères tenus, nouveaux joueurs observés, recherche continue relancée', () => {
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  try {
    let m = creer(jeu);
    const etat = () => JSON.parse(jeu.call('export').meta.exportText).state;
    const rc = m.clubLife.rechercheCiblee;
    assert.equal(rc.cout, 5000);
    assert.equal(rc.disponible, true);
    assert.ok(rc.recruteurs.length >= 1, 'recruteurs du staff');
    const scouts = rc.recruteurs.map(x => x.id);
    const base = { family: 7, maxAge: 30, budget: 10000000, maxWage: 100000, confirmed: true, position: 12, minNote: 0, minPotential: 0, minAge: 18, scouts };
    // Critères refusés avant tout paiement.
    let s = etat();
    const avant = s.clubs[s.club].cash;
    for (const faux of [{ role: 'pilier-mobile' }, { family: 6 }, { priority: 'urgente' }, { scouts: ['inconnu'] }, { minAge: 31 }]) {
      const r = jeu.brut('scout_mission', { ...base, role: 'centre-perceur', priority: 'standard', ...faux });
      assert.equal(r.ok, false, JSON.stringify(faux));
    }
    s = etat();
    assert.equal(s.clubs[s.club].cash, avant, 'aucun débit sur un refus');
    // Prioritaire : 5 000 €, une semaine de travail.
    m = jeu.call('scout_mission', { ...base, role: 'centre-perceur', minNote: 60, minAge: 21, maxAge: 29, priority: 'prioritaire' });
    s = etat();
    assert.equal(avant - s.clubs[s.club].cash, 5000);
    const job = s.manager.missions.at(-1);
    assert.equal(job.remaining, 1);
    assert.equal(job.cible.priority, 'prioritaire');
    assert.equal(m.clubLife.rechercheCiblee.missions.length, 1);
    // Continue : relancée sans frais en fin de file.
    m = jeu.call('scout_mission', { ...base, family: 4, position: 9, priority: 'continue', minNote: 0, maxAge: 35 });
    s = etat();
    assert.equal(avant - s.clubs[s.club].cash, 10000);
    m = jouer(jeu, m, 4);
    s = etat();
    const rapports = s.manager.reports.filter(r => r.mission === job.id);
    assert.ok(rapports.length >= 1 && rapports.length <= 6, 'pistes en nombre raisonnable');
    const nouveaux = rapports.filter(r => !r.cible.connu);
    assert.ok(nouveaux.length <= 3, 'Prioritaire : 3 nouveaux au plus');
    for (const r of rapports) {
      assert.equal(r.cible.maillot, 12);
      assert.ok(r.age >= 21 && r.age <= 29, 'âge tenu');
      assert.ok(r.note >= 60, 'note au poste minimum tenue');
    }
    const connus = new Set(m.clubLife.rechercheCiblee.connus.map(x => x.id));
    for (const r of nouveaux) assert.ok(connus.has(r.playerId), 'nouveau joueur trouvé = joueur observé');
    const continues = s.manager.missions.filter(j => j.cible?.priority === 'continue');
    assert.ok(continues.length >= 2, 'recherche continue relancée');
    assert.ok(continues.every((j, i) => j.cible.cycle === i + 1));
    assert.equal(avant - s.clubs[s.club].cash >= 10000, true);
    const journal = s.manager.inbox.filter(x => /^Recherche ciblée/.test(x.title));
    assert.ok(journal.length >= 2, 'message à chaque rapport');
    // Liste des joueurs déjà observés : estimations seulement, jamais la note exacte.
    for (const x of m.clubLife.rechercheCiblee.connus) {
      assert.ok(['observed', 'deep'].includes(x.suivi));
      assert.equal(x.familiarite.length, 15);
      assert.ok(Object.keys(x.estime.postes).length >= 1);
      assert.equal(x.rating ?? null, null);
      assert.equal(x.positionRatings, undefined);
    }
    assert.ok(m.clubLife.rechercheCiblee.connus.some(x => x.club !== null), 'joueurs sous contrat ailleurs aussi');
  } finally { jeu.fermer(); }
});
