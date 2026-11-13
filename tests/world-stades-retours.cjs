'use strict';
// Carrière Monde : capacité des stades (116 clubs) et dates de retour des internationaux (une seule source).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { ouvrir } = require('./helpers/carriere-monde.cjs');
const table = require('../native/engine/world-stadium-capacities.json');

// 1. Table des capacités : un club = une capacité plausible, aucun nom propre.
const ids = Object.keys(table.capacities);
assert.equal(ids.length, 116, '116 clubs');
assert.deepEqual(ids.map(Number).sort((a, b) => a - b), [...Array(116).keys()]);
for (const id of ids) { const n = table.capacities[id]; assert.ok(Number.isInteger(n) && n >= 2000 && n <= 40000, 'capacité plausible club ' + id + ' : ' + n); }
assert.equal(table.capacities[0], 19500, 'Ernest-Wallon');
assert.ok(new Set(Object.values(table.capacities)).size > 60, 'capacités variées, plus de 12 000 partout');
const moyenne = (a, b) => { const v = Object.entries(table.capacities).filter(([k]) => k >= a && k <= b).map(([, n]) => n); return v.reduce((x, y) => x + y, 0) / v.length; };
assert.ok(moyenne(0, 13) > moyenne(14, 29) && moyenne(14, 29) > moyenne(88, 101) && moyenne(88, 101) > moyenne(102, 115), 'Élite > Accession > Nationale > Championship');
// La billetterie réelle (recettes du club) ne lit pas la capacité : seul le module supporters (affichage) la lit.
assert.ok(!/stadiumCapacity|CDWorldStadiumCapacities/.test(fs.readFileSync(path.join(__dirname, '../native/engine/club-budget.cjs'), 'utf8')), 'club-budget ne lit pas la capacité');

// 2. Moteur : capacité, abonnés, affluence et recette prévues suivent le stade ; retours = mêmes dates.
const jeu = ouvrir({});
try {
  const rows = [];
  for (const club of [0, 11, 14, 52, 102]) {
    const m = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club, start: 'premiers-clubs' }));
    const f = m.clubLife.clubStrategy.fans;
    assert.equal(f.capacity, table.capacities[club], 'capacité du club ' + club);
    assert.ok(f.subscribers >= 0.2 * f.capacity && f.subscribers <= 0.78 * f.capacity, 'abonnés dans 20-78 % de la capacité : club ' + club);
    assert.ok(f.expectedAttendance <= f.capacity && f.expectedTicketRevenue === f.expectedAttendance * f.price);
    rows.push(club + ' : ' + f.capacity + ' places, ' + f.subscribers + ' abonnés, ' + f.expectedAttendance + ' spectateurs prévus, ' + f.expectedTicketRevenue + ' € par match');
    if (club !== 0) continue;
    const a = m.international.availability, r = m.clubLife.reprise;
    assert.ok(r.internationals.length > 0 && a.absentCount === a.players.length, 'internationaux absents');
    const retours = new Map(r.internationals.map(x => [x.id, x.returnDate]));
    assert.equal(a.nextReturn, [...retours.values()].sort()[0], 'premier retour : même date dans les deux panneaux');
    assert.equal(a.nextReturn, r.internationals[0].returnDate);
    for (const p of a.players) if (retours.has(p.id)) assert.equal(p.returnDate, retours.get(p.id), 'même retour pour ' + p.name);
    assert.deepEqual([...retours.keys()].sort(), a.players.map(p => p.id).sort(), 'mêmes joueurs absents');
    console.log('Retours club 0 : ' + a.absentCount + ' absents, premier retour ' + a.nextReturn + ', dernier ' + a.players.at(-1).returnDate);
  }
  console.log(rows.join('\n'));
  console.log('world-stades-retours PASS');
} finally { jeu.fermer(); }
