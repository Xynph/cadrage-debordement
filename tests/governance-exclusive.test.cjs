'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const file = fs.readFileSync(path.join(__dirname, '../AGENTS.md'), 'utf8');
test('exclusive alternation and one active integrator', () => {
 assert.match(file, /jamais actifs simultanément/);
 assert.match(file, /Un seul compte actif et un seul intégrateur/);
});
test('explicit permission on each PR and no implicit merge', () => {
 assert.match(file, /Léo doit autoriser explicitement chaque PR/);
 assert.match(file, /Le compte producteur ne fusionne pas/);
 assert.match(file, /\/cd-check/);
 assert.match(file, /\/cd-merge/);
});
test('release safeguards retained', () => {
 for (const token of ['ci/release-gate.cjs','docs/chat-release-gate.md','sept jobs post-fusion','rulesets main']) assert.ok(file.includes(token), token);
});
test('handoff and user-facing action labels', () => {
 assert.match(file, /passation #73/);
 assert.match(file, /jamais seulement « Continuer »/);
});
