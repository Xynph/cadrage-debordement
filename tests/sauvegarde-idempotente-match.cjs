'use strict';
// Sauvegarde idempotente (carrière Monde `world-champ`), 2/3 : après un match (notes de match v2, politique supporters,
// abonnés), charger un profil ne modifie rien et export -> import -> export redonne exactement le même état. Suite
// coupée en trois le 16/11/2026 (mêmes assertions) pour rester sous le délai de 180 s du lanceur CI : création dans
// tests/sauvegarde-idempotente.cjs, export réduit dans tests/sauvegarde-idempotente-reduit.cjs. Outils et carrière
// jouée : tests/helpers/sauvegarde-idempotente.cjs.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { jouerUnMatch, faits, rechargerEtVerifier } = require('./helpers/sauvegarde-idempotente.cjs');

test('Monde : export -> import -> export identique après un match (notes de match, abonnés)', { timeout: 1500000 }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-sauvegarde-'));
  try {
    jouerUnMatch(dir);
    const jouee = faits(dir);
    assert.equal(jouee.notes, 2, 'notes de match v2');
    assert.ok(jouee.joueursNotes, 'notes de match enregistrées');
    assert.ok(Number.isInteger(jouee.abonnes) && jouee.abonnes > 0, 'abonnés présents');
    rechargerEtVerifier(dir, 'après un match');
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
