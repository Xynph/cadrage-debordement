'use strict';
// Marché de départ d'une carrière Monde neuve : le vivier des joueurs libres se compte au poste naturel.
// Le moteur natif laisse tout joueur dépanner aux postes 4 à 15 ; compter ces dépannages remplissait le vivier
// avec les seules premières lignes et l'écran Recrutement n'avait aucune piste au besoin n° 1 du club.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

test('Carrière Monde neuve : pistes à chaque poste naturel et au besoin n° 1 du club', { timeout: 300000 }, () => {
  const jeu = M.ouvrir({ hebdomadaire: true });
  try {
    const model = M.creer(jeu);
    const market = model.market || [];
    const postes = new Set(market.map(p => p.pos));
    assert.ok(postes.size >= 10, 'postes au marché : ' + [...postes].join(', '));
    const besoin = model.decisions?.recruitment?.needs?.[0]?.pos;
    assert.ok(besoin, 'besoin n° 1 attendu');
    assert.ok(market.some(p => p.pos === besoin), 'aucune piste au besoin n° 1 : ' + besoin);
  } finally { jeu.fermer?.(); }
});
