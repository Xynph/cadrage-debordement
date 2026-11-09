'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const agents = fs.readFileSync(path.join(root, 'AGENTS.md'), 'utf8');
const protocol = fs.readFileSync(path.join(root, 'docs/developpement-parallele.md'), 'utf8').replace(/\s+/g, ' ');

test('les producteurs coordonnent les collisions dans les PR actives', () => {
  assert.match(agents, /branches distinctes/);
  assert.match(protocol, /En cas de travail simultané/);
  assert.match(protocol, /chemins et les interfaces/);
  assert.match(protocol, /suspendre les écritures/);
});

test('la description de la PR contient la passation unique', () => {
  assert.match(agents, /description de la PR/);
  for (const field of ['Périmètre', 'Collisions', 'Tests', 'Prochaine action']) {
    assert.ok(protocol.includes('**' + field + '**'), field);
  }
  assert.doesNotMatch(agents, /PASSATION dans #73|Réserver les chemins dans #73 avant modification/);
  assert.equal(fs.existsSync(path.join(root, '.github/workflows/producer-handoff.yml')), false);
});

test('un seul intégrateur applique le gate officiel et vérifie la CI après fusion', () => {
  assert.match(agents, /Un seul intégrateur/);
  assert.match(agents, /protections serveur/);
  assert.match(agents, /Aucun push direct/);
  assert.match(protocol, /HEAD exact/);
  assert.match(protocol, /gate officiel en production/);
  assert.match(protocol, /CI du commit fusionné/);
});

test('les références produit et la validation des sauvegardes sont conservées', () => {
  for (const reference of ['docs/rugby-rules-reference.md', 'docs/donnees-du-jeu.md', 'offline/README.md']) {
    assert.ok(agents.includes(reference), reference);
  }
  assert.match(protocol, /rétrocompatibilité des sauvegardes/);
});
