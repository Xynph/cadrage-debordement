'use strict';
// Sauvegarde idempotente (carrière Monde `world-champ`), 3/3 : export réduit sans perte (plafond abaissé de 10 % de la
// taille de l'export non réduit, relevée sur le pont de jeu avant sa fermeture), charger un profil ne modifie rien et
// export -> import -> export redonne exactement le même état. Voir tests/sauvegarde-idempotente-match.cjs (suite
// coupée en trois le 16/11/2026, mêmes assertions, pour rester sous le délai de 180 s du lanceur CI).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { jouerUnMatch, faits, rechargerEtVerifier } = require('./helpers/sauvegarde-idempotente.cjs');

test('Monde : export réduit -> import -> export identique (l\'état littéral diffère, l\'aller-retour reste exact)', { timeout: 1500000 }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-sauvegarde-'));
  try {
    const taille = jouerUnMatch(dir);
    assert.ok(faits(dir).joueursNotes, 'carrière jouée enregistrée');
    // Export réduit (plafond abaissé de 10 %) : l'état littéral diffère, l'aller-retour reste exact.
    rechargerEtVerifier(dir, 'export réduit', Math.floor(taille * 0.9));
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
