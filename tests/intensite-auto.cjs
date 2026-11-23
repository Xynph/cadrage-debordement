'use strict';
// Intensité d'entraînement « Auto » par forme (revue FM27, idée 13 ; choix de Léo du 23/11/2026) : une règle par niveau de
// forme (< 60 / 60 / 70 / 80 / 90 % de condition), sauvegardée (S.intensiteAuto), par défaut Repos, Repos, Normal,
// Normal, Intensif ; chaque joueur en « Auto » (ancienne clé « collective » = « Suivre le collectif ») prend
// l'intensité de la règle de sa forme à la séance. Commande set_intensite_auto {niveau, mode}.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');

const DEFAUT = ['repos', 'repos', 'normal', 'normal', 'intense'];
const niveau = c => [60, 70, 80, 90].filter(s => c >= s).length;
const attendu = (p, regle) => p.injury > 0 ? 'repos' : p.loadPlan === 'collective' ? regle[niveau(p.condition)] : p.loadPlan;

test('Carrière Monde : règle Auto par forme, commande, séance, sauvegarde', { timeout: 600000 }, () => {
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  const vm = code => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + code + ')'));
  try {
    let model = creer(jeu);
    // Carrière neuve : règle par défaut posée, tous les joueurs en Auto, libellé « Auto ».
    assert.deepEqual(vm('S.intensiteAuto'), DEFAUT);
    // Ancienne carrière (aucune règle sauvegardée) : la règle par défaut est posée à la commande suivante.
    jeu.bridge.vm.run('delete S.intensiteAuto');
    assert.deepEqual(jeu.call('snapshot').decisions.training.intensiteAuto.regle, DEFAUT, 'lecture : règle par défaut');
    model = jeu.call('set_player_load', { playerId: model.squad[0].id, mode: 'collective' });
    assert.deepEqual(vm('S.intensiteAuto'), DEFAUT);
    assert.deepEqual(model.decisions.training.intensiteAuto, { seuils: [60, 70, 80, 90], regle: DEFAUT, available: true });
    assert.equal(vm('PHYSICAL_PLANS.collective'), 'Auto');
    assert.ok(model.squad.every(p => p.loadPlan === 'collective'), 'tout l’effectif en Auto');
    // Conditions étalées sur les cinq niveaux, puis intensité appliquée = règle de la forme.
    jeu.bridge.vm.run('S.clubs[S.club].players.forEach((p,i)=>{p.injury=0;p.condition=[45,59,60,69,70,79,80,89,90,100][i%10];})');
    model = jeu.call('set_player_load', { playerId: model.squad[0].id, mode: 'collective' });
    assert.deepEqual(new Set(model.squad.map(p => niveau(p.condition))), new Set([0, 1, 2, 3, 4]));
    for (const p of model.squad) assert.equal(p.loadMode, attendu(p, DEFAUT), p.name + ' : ' + p.condition + ' %');
    // Seuils exacts : 59 → très basse, 60 → basse, 90 → très bonne.
    assert.equal(vm('[59,60,69.9,70,80,89,90].map(c=>niveauForme({condition:c}))').join(), '0,1,1,2,3,3,4');
    // Changer la règle d'un niveau : sauvegardée, appliquée aux joueurs en Auto de ce niveau seulement.
    model = jeu.call('set_intensite_auto', { niveau: 4, mode: 'repos' });
    const regle = ['repos', 'repos', 'normal', 'normal', 'repos'];
    assert.deepEqual(model.decisions.training.intensiteAuto.regle, regle);
    assert.deepEqual(vm('S.intensiteAuto'), regle);
    for (const p of model.squad) assert.equal(p.loadMode, attendu(p, regle), p.name);
    // Choix individuel prioritaire ; blessé toujours au repos ; retour en Auto.
    const choisi = model.squad.find(p => p.condition < 60);
    model = jeu.call('set_player_load', { playerId: choisi.id, mode: 'intense' });
    assert.equal(model.squad.find(p => p.id === choisi.id).loadMode, 'intense');
    model = jeu.call('set_intensite_auto', { niveau: 0, mode: 'normal' });
    regle[0] = 'normal';
    assert.equal(vm('physicalModeFor({injury:2,condition:95,physicalLoad:{version:1,fatigue:0,plan:"collective"}},S.club)'), 'repos', 'blessé au repos');
    for (const p of model.squad) assert.equal(p.loadMode, attendu(p, regle), p.name);
    // Refus : niveau ou mode inconnus, « Auto » n'est pas une intensité de règle.
    for (const payload of [{ niveau: 5, mode: 'repos' }, { niveau: -1, mode: 'repos' }, { niveau: '1', mode: 'repos' }, { niveau: 1, mode: 'collective' }, { niveau: 1, mode: 'max' }, {}]) {
      const r = jeu.bridge.handle({ id: 99000 + Math.floor(Math.random() * 999), command: 'set_intensite_auto', payload });
      assert.equal(r.ok, false, JSON.stringify(payload));
    }
    assert.deepEqual(vm('S.intensiteAuto'), regle, 'règle intacte après les refus');
    // Avis du kiné appliqué à tous : chaque joueur valide reçoit l'avis ; en Auto quand sa règle le donne déjà.
    jeu.bridge.vm.run('S.clubs[S.club].players.forEach((p,i)=>{ensurePhysicalLoad(p).fatigue=[0,10,30,60][i%4];})');
    model = jeu.call('set_intensite_auto', { niveau: 0, mode: 'normal' });
    assert.ok(model.squad.some(p => p.avisKine !== p.loadMode), 'des écarts avant');
    for (const p of model.squad) assert.ok(['repos', 'normal', 'intense'].includes(p.avisKine), p.name + ' : avis');
    model = jeu.call('appliquer_avis_kine');
    for (const p of model.squad) {
      assert.equal(p.loadMode, p.avisKine, p.name + ' : avis appliqué');
      if (p.loadPlan !== 'collective') assert.notEqual(regle[niveau(p.condition)], p.avisKine, p.name + ' : reste en Auto si la règle suffit');
    }
    assert.ok(model.squad.some(p => p.loadPlan === 'collective') && model.squad.some(p => p.loadPlan !== 'collective'));
    assert.ok(model.squad.filter(p => p.condition < 60).every(p => p.avisKine === 'repos'), 'condition < 60 : repos');
    // Séance : chaque joueur en Auto travaille à l'intensité de la règle de sa forme au moment de la séance, quelle que
    // soit la charge de la séance collective (ici intense).
    jeu.bridge.vm.run('globalThis.__modes={};const __avant=applyPhysicalTraining;applyPhysicalTraining=function(p,mode){if(S.clubs[S.club].players.includes(p))__modes[p.id]=mode;return __avant(p,mode);}');
    const avant = vm('S.clubs[S.club].players.map(p=>({id:p.id,condition:p.condition,injury:p.injury,loadPlan:p.physicalLoad?.plan??"collective"}))');
    jeu.call('train', { mode: 'intense' });
    const modes = vm('__modes');
    for (const p of avant) assert.equal(modes[p.id], attendu(p, regle), p.id + ' à ' + p.condition + ' %');
    assert.ok(avant.some(p => p.loadPlan === 'collective' && modes[p.id] !== 'intense'), 'la charge collective ne s’impose plus aux joueurs en Auto');
    // Sauvegarde : règle valide acceptée, règle abîmée refusée.
    assert.equal(vm('(()=>{const s=JSON.parse(JSON.stringify(S));try{validateCareer(s);return "ok"}catch(e){return String(e.message)}})()'), 'ok');
    for (const faux of ['["repos"]', '["repos","repos","normal","normal","collective"]', '"intense"']) {
      assert.notEqual(vm('(()=>{const s=JSON.parse(JSON.stringify(S));s.intensiteAuto=' + faux + ';try{validateCareer(s);return "ok"}catch(e){return "refus"}})()'), 'ok', faux);
    }
  } finally { jeu.fermer(); }
});
