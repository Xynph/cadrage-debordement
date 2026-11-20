'use strict';
// Outil des tests Monde (tests/helpers/carriere-monde.cjs) : `jouer` traverse la fin de saison.
// Club hors phase finale, saison close (phase « ended ») : il n'y a plus de match à attendre ni de journée
// à valider ; l'outil réclamait encore `finish_round`, refusé, et toute sonde d'une saison s'arrêtait là.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

test('Saison close sans phase finale : jouer passe à la saison suivante et joue son premier match', { timeout: 600000 }, () => {
  const jeu = M.ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  try {
    M.creer(jeu);
    // Avance rapide jusqu'à la fin de la saison 1 (journées validées par le moteur, matchs du club compris).
    jeu.bridge.vm.run('while(S.phase!=="ended")finishRound();""', 600000);
    let model = jeu.call('snapshot');
    assert.equal(model.meta.phase, 'ended');
    assert.equal(model.meta.season, 1);
    model = M.jouer(jeu, model, 1);
    assert.equal(model.meta.season, 2, 'premier match de la saison 2 joué');
    assert.notEqual(model.meta.phase, 'ended');
  } finally { jeu.fermer(); }
});
