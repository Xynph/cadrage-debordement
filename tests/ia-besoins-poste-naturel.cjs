'use strict';
// Besoins des clubs de l'ordinateur comptés au poste naturel (carrière Monde, moteur natif).
// Le moteur natif laisse tout joueur dépanner aux postes 4 à 15 : compter ces dépannages effaçait tout manque
// hors première ligne, et les clubs de l'ordinateur ne recrutaient plus que des piliers et des talonneurs.
// La feuille de match, elle, garde les dépannages.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');

test('Club de l\'ordinateur sans demi d\'ouverture : besoin, piste et garde-fou au poste naturel', { timeout: 300000 }, () => {
  const jeu = M.ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  try {
    M.creer(jeu);
    const r = source => jeu.bridge.vm.run(source);
    const slot = r('FAMILIES.findIndex((f,i)=>i>=3&&FAMILIES.indexOf(f)===i&&POS[i]==="Demi d’ouverture")');
    assert.ok(slot >= 3, 'poste de demi d\'ouverture introuvable');
    r(`var club=S.clubs.find(c=>c.id!==S.club&&c.players.filter(p=>naturalSlot(p,${slot})).length>=1);
      var gardien=club.players.find(p=>naturalSlot(p,${slot})&&p.age<p.dev.retireAge-1);
      club.players=club.players.filter(p=>p===gardien||!naturalSlot(p,${slot}));
      var goal=aiRosterTarget(club);club.players=club.players.slice(0,goal-3);
      if(!club.players.includes(gardien))club.players[0]=gardien;`);
    assert.equal(r(`club.players.filter(p=>naturalSlot(p,${slot})).length`), 1);
    // Dépannage conservé : un autre joueur peut toujours tenir le maillot.
    assert.equal(r(`club.players.some(p=>p!==gardien&&slotEligible(p,${slot}))`), true, 'dépannage attendu (moteur natif)');
    const besoins = JSON.parse(r('JSON.stringify(aiRosterDepthNeeds(club).map(n=>n.slot))'));
    assert.ok(besoins.includes(slot), 'besoin au poste de demi d\'ouverture attendu : ' + besoins.join(','));
    const piste = r(`(()=>{const t=aiRosterPopulationTargets(club,aiRosterMarketPool([])).find(x=>x.need.slot===${slot});return t?naturalSlot(t.p,${slot}):null})()`);
    assert.equal(piste, true, 'piste au besoin de demi d\'ouverture : un demi d\'ouverture naturel');
    // Seul demi d'ouverture naturel : le club ne le libère pas pour faire de la place.
    assert.equal(r('aiRosterReleasable(club,gardien,new Set())'), false);
  } finally { jeu.fermer(); }
});
