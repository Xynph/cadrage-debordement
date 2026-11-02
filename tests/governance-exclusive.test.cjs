'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const file = fs.readFileSync(path.join(__dirname, '../AGENTS.md'), 'utf8');
const parallel = fs.readFileSync(path.join(__dirname, '../docs/developpement-parallele.md'), 'utf8');

test('parallel producers are allowed only on compatible branches and reserved paths', () => {
 assert.match(file, /deux développeurs peuvent travailler en même temps sur GitHub/);
 assert.match(file, /Réserver les chemins dans #73 avant modification/);
 assert.match(file, /Un seul intégrateur effectue les opérations de fusion à la fois/);
 assert.match(parallel, /deux développeurs GitHub simultanés sur des branches et fichiers compatibles/);
 assert.match(parallel, /STOP sur la zone touchée/);
});
test('explicit permission on each PR and no implicit merge', () => {
 assert.match(file, /Léo doit autoriser explicitement chaque PR/);
 assert.match(file, /Le producteur ne fusionne pas sa propre PR sans revue indépendante/);
 assert.match(file, /\/cd-check/);
 assert.match(file, /\/cd-merge/);
 assert.match(parallel, /autorisation explicite de Léo pour la PR et son HEAD/);
});
test('release safeguards retained', () => {
 for (const token of ['ci/release-gate.cjs','docs/chat-release-gate.md','sept jobs post-fusion','rulesets main']) assert.ok(file.includes(token), token);
 assert.match(parallel, /Aucun bypass et aucun push sur main/);
});
test('handoff and coordination remain mandatory', () => {
 assert.match(file, /passation #73/);
 assert.match(file, /jamais seulement « Continuer »/);
 assert.match(parallel, /Passation courte dans #73/);
});
test('no contradictory legacy parallel-work or fixed-account clauses', () => {
 for (const forbidden of ['Les sessions peuvent être simultanées','travaux indépendants peuvent se poursuivre simultanément','compte intégrateur unique est seul responsable','fusion réservée au compte intégrateur unique']) assert.ok(!file.includes(forbidden), forbidden);
});
