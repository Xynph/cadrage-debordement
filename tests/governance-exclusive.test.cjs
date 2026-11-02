'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const file = fs.readFileSync(path.join(__dirname, '../AGENTS.md'), 'utf8');

test('two producers may work concurrently only on compatible reserved paths', () => {
 assert.match(file, /deux développeurs peuvent travailler en même temps sur GitHub/);
 assert.match(file, /Réserver les chemins dans #73 avant modification/);
 assert.match(file, /arrêter toute écriture conflictuelle/);
});

test('merges remain serialized under one integrator', () => {
 assert.match(file, /La fusion reste sérialisée/);
 assert.match(file, /un seul intégrateur désigné/);
 assert.match(file, /Un seul intégrateur effectue les opérations de fusion à la fois/);
});

test('explicit permission on each PR and no implicit merge', () => {
 assert.match(file, /Léo doit autoriser explicitement chaque PR/);
 assert.match(file, /autorisation explicite de Léo par numéro de PR et HEAD/);
 assert.match(file, /Les réservations #73 n'accordent aucun droit de fusion/);
 assert.match(file, /\/cd-check/);
 assert.match(file, /\/cd-merge/);
});

test('release safeguards retained', () => {
 for (const token of ['ci/release-gate.cjs', 'docs/chat-release-gate.md', 'sept jobs post-fusion', 'rulesets main']) {
  assert.ok(file.includes(token), token);
 }
});

test('handoff and user-facing action labels', () => {
 assert.match(file, /PASSATION dans #73/);
 assert.match(file, /jamais seulement « Continuer »/);
});

test('obsolete exclusivity claims are not reinstated as current policy', () => {
 assert.match(file, /supplanté par le protocole parallèle/);
 for (const forbidden of [
  'Les sessions peuvent être simultanées',
  'travaux indépendants peuvent se poursuivre simultanément',
  'compte intégrateur unique est seul responsable',
  'fusion réservée au compte intégrateur unique'
 ]) assert.ok(!file.includes(forbidden), forbidden);
});
