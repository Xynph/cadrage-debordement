'use strict';
// Sauvegarde idempotente (carrière Monde `world-champ`), 1/3 : à la création (départ « club », avant-saison du
// 13 juillet et choix de reprise), charger un profil ne modifie rien et export -> import -> export redonne exactement
// le même état. Suite coupée en trois le 16/11/2026 (mêmes assertions) pour rester sous le délai de 180 s du lanceur CI ;
// la suite (après un match, export réduit) est dans tests/sauvegarde-idempotente-match.cjs et -reduit.cjs. Outils et rappel
// de la preuve d'empreinte : tests/helpers/sauvegarde-idempotente.cjs.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { M, faits, rechargerEtVerifier } = require('./helpers/sauvegarde-idempotente.cjs');

test('Monde : export -> import -> export identique à la création (avant-saison, reprise)', { timeout: 1500000 }, () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-sauvegarde-'));
  try {
    const jeu = M.ouvrir({ dataDir: dir });
    try {
      // Départ « club » : avant-saison du 13 juillet (S.preseason) et choix de reprise (S.reprise).
      jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'club' }));
      jeu.call('save');
    } finally { jeu.fermer(); }
    const depart = faits(dir);
    assert.equal(depart.avantSaison, true, 'avant-saison présente à la création');
    assert.equal(depart.reprise, true, 'reprise présente à la création');
    rechargerEtVerifier(dir, 'création');
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
});
