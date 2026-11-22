'use strict';
// Marché entre clubs (21/11/2026) : chaque profil garde sa forme récente compacte (match-notes.cjs) pour les cases de
// forme de l'écran « Entre clubs » : [note × 10, semaine, adversaire, points pour, points contre], le plus ancien d'abord.
// Carrière Monde (world-champ), un match joué.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const M = require('./helpers/carriere-monde.cjs');

const jeu = M.ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
try {
  let m = M.creer(jeu, 5);
  const avant = m.clubLife.interclubMarket.candidates;
  assert.ok(avant.length > 0, 'profils du marché entre clubs');
  assert.ok(avant.every(p => p.forme === undefined), 'aucune forme avant le premier match');
  m = M.jouer(jeu, m, 1);
  const profils = m.clubLife.interclubMarket.candidates;
  const avecForme = profils.filter(p => Array.isArray(p.forme));
  assert.ok(avecForme.length > 0, 'des profils ont une forme après une journée jouée');
  for (const p of avecForme) {
    assert.ok(p.forme.length >= 1 && p.forme.length <= 5, 'au plus cinq matchs : ' + p.name);
    for (const f of p.forme) {
      assert.ok(Array.isArray(f) && (f.length === 1 || f.length === 5), 'forme compacte : ' + JSON.stringify(f));
      assert.ok(Number.isInteger(f[0]) && f[0] >= 10 && f[0] <= 100, 'note × 10 : ' + f[0]);
      if (f.length === 5) {
        assert.ok(m.clubLife.interclubMarket.candidates.some(q => q.clubId === f[2]) || m.club?.id === f[2], 'adversaire connu : ' + f[2]);
        assert.ok(Number.isInteger(f[3]) && Number.isInteger(f[4]), 'score : ' + JSON.stringify(f));
      }
    }
  }
  const taille = JSON.stringify(profils.map(p => p.forme || null)).length;
  console.log(`interclub-forme : ${avecForme.length} / ${profils.length} profils avec forme, ${Math.round(taille / 1024)} Ko de forme`);
  assert.ok(taille < 400 * 1024, 'forme compacte : moins de 400 Ko pour tout le marché');
} finally {
  jeu.fermer();
  fs.rmSync(jeu.dataDir, { recursive: true, force: true });
}
console.log('OK interclub-forme');
