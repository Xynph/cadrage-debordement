'use strict';
// Carrière Monde exportée juste après un match (résultat validé, avant « Continuer ») : elle doit s'importer dans
// un jeu fraîchement lancé (aucune carrière chargée). Avant le correctif, la validation des causeries du match gardé
// en mémoire recalculait le pronostic d'avant-match sur la carrière chargée (nulle au lancement) :
// « Cannot read properties of null (reading 'clubs') ».
const assert = require('node:assert/strict');
const { ouvrir, creer, jusquAuMatch, jouerLeMatch } = require('./helpers/carriere-monde.cjs');

const a = ouvrir({ testVm: true }), b = ouvrir({ testVm: true });
try {
  let model = creer(a, 0);
  model = jusquAuMatch(a, model);
  model = jouerLeMatch(a, model);
  assert.equal(a.bridge.vm.run('!!S.live&&S.live.finished&&S.worldMode.resultConfirmed===true'), true, 'match joué, résultat validé, pas encore « Continuer »');
  assert.equal(a.bridge.vm.run('!!S.contextualMatch&&!!S.contextualMatch.current'), true, 'causeries du match encore gardées dans la carrière');
  const texte = a.call('export').meta.exportText, document = JSON.parse(texte);
  assert.equal(b.bridge.vm.run('S===null'), true, 'jeu neuf : aucune carrière chargée');
  b.call('import', { text: texte });
  const relu = JSON.parse(b.call('export').meta.exportText);
  assert.equal(relu.checksum, document.checksum, 'ré-export : même empreinte');
  assert.equal(JSON.stringify(relu.state), JSON.stringify(document.state), 'carrière importée identique à l’export');
  assert.equal(b.bridge.vm.run('!!S.live&&S.live.finished'), true, 'le match terminé est restitué');
  console.log('import après match : carrière Monde exportée avant « Continuer » réimportée à l’identique PASS.');
} finally { a.fermer(); b.fermer(); }
