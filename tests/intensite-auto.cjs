'use strict';
// Intensité d'entraînement « Auto » par forme (revue FM27, idée 13 ; choix de Léo du 23/11/2026) : un joueur en « Auto »
// (ancienne clé « collective » = « Suivre le collectif ») part de la séance de la semaine (ou de celle du préparateur en
// délégation) et la règle de son niveau de forme (< 60 / 60 / 70 / 80 / 90 %, sauvegardée dans S.intensiteAuto, défaut
// Repos, Repos, Normal, Normal, Normal) l'ajuste d'un cran : Repos −1, Normal =, Intensif +1, borné. L'intensif n'est
// retenu qu'à ≥ 90 % de forme et charge < 25. Commandes set_intensite_auto {niveau, mode} et appliquer_avis_kine.
// Coup d'envoi : une blessure à la séance du jour qui laisse un poste vide appelle un espoir, sinon un refus clair.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');

const DEFAUT = ['repos', 'repos', 'normal', 'normal', 'normal'];
const MODES = ['repos', 'normal', 'intense'];
const niveau = c => [60, 70, 80, 90].filter(s => c >= s).length;
const auto = (p, regle, base) => {
  const m = MODES[Math.max(0, Math.min(2, MODES.indexOf(base) + { repos: -1, normal: 0, intense: 1 }[regle[niveau(p.condition)]]))];
  return m === 'intense' && !(p.condition >= 90 && p.physicalLoad < 25) ? 'normal' : m;
};
const attendu = (p, regle, base = 'normal') => p.injury > 0 ? 'repos' : p.loadPlan === 'collective' ? auto(p, regle, base) : p.loadPlan;

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
    assert.deepEqual(model.decisions.training.intensiteAuto, { seuils: [60, 70, 80, 90], regle: DEFAUT, base: 'normal', chargeBasse: 25, available: true });
    assert.equal(vm('PHYSICAL_PLANS.collective'), 'Auto');
    assert.ok(model.squad.every(p => p.loadPlan === 'collective'), 'tout l’effectif en Auto');
    // Formes étalées sur les cinq niveaux, charges basses et hautes.
    jeu.bridge.vm.run('S.clubs[S.club].players.forEach((p,i)=>{p.injury=0;p.condition=[45,59,60,69,70,79,80,89,90,100][i%10];ensurePhysicalLoad(p).fatigue=[0,10,30,60][i%4];})');
    model = jeu.call('set_player_load', { playerId: model.squad[0].id, mode: 'collective' });
    assert.deepEqual(new Set(model.squad.map(p => niveau(p.condition))), new Set([0, 1, 2, 3, 4]));
    assert.equal(model.decisions.training.intensiteAuto.base, 'normal', 'séance de la semaine : normale');
    assert.equal(model.decisions.training.intensiteAuto.chargeBasse, 25);
    for (const p of model.squad) {
      assert.equal(p.loadMode, attendu(p, DEFAUT), p.name + ' : ' + p.condition + ' %');
      for (const base of MODES) assert.equal(p.autoModes[base], auto(p, DEFAUT, base), p.name + ' · séance ' + base);
    }
    assert.ok(model.squad.every(p => p.loadMode !== 'intense'), 'règle par défaut, séance normale : aucun intensif');
    // Garde-fou de l'intensif (séance intensive) : ≥ 90 % et charge < 25 seulement.
    const garde = (c, f) => vm(`intensiteAutoPour({condition:${c},physicalLoad:{version:1,fatigue:${f},plan:'collective'}},'intense')`);
    assert.deepEqual([garde(100, 0), garde(90, 24), garde(90, 25), garde(89, 0), garde(65, 0), garde(50, 0)], ['intense', 'intense', 'normal', 'normal', 'normal', 'normal']);
    // Seuils exacts : 59 → très basse, 60 → basse, 90 → très bonne.
    assert.equal(vm('[59,60,69.9,70,80,89,90].map(c=>niveauForme({condition:c}))').join(), '0,1,1,2,3,3,4');
    // Règle d'une carte : Intensif = +1 cran (borné, garde-fou compris), Repos = −1.
    model = jeu.call('set_intensite_auto', { niveau: 4, mode: 'intense' });
    const regle = ['repos', 'repos', 'normal', 'normal', 'intense'];
    assert.deepEqual(model.decisions.training.intensiteAuto.regle, regle);
    assert.deepEqual(vm('S.intensiteAuto'), regle);
    for (const p of model.squad) assert.equal(p.loadMode, attendu(p, regle), p.name);
    assert.ok(model.squad.some(p => p.loadMode === 'intense') && model.squad.some(p => p.condition >= 90 && p.loadMode === 'normal'), 'intensif pour les frais seulement');
    model = jeu.call('set_intensite_auto', { niveau: 2, mode: 'repos' });
    regle[2] = 'repos';
    for (const p of model.squad) assert.equal(p.loadMode, attendu(p, regle), p.name);
    // Choix individuel prioritaire ; blessé toujours au repos.
    const choisi = model.squad.find(p => p.condition < 60);
    model = jeu.call('set_player_load', { playerId: choisi.id, mode: 'intense' });
    assert.equal(model.squad.find(p => p.id === choisi.id).loadMode, 'intense');
    assert.equal(vm('physicalModeFor({injury:2,condition:95,physicalLoad:{version:1,fatigue:0,plan:"collective"}},S.club)'), 'repos', 'blessé au repos');
    // Délégation de l'entraînement : la séance du préparateur sert de base.
    model = jeu.call('set_delegation', { key: 'training', enabled: true });
    const staff = vm('staffTrainingDecision(S,S.training).mode');
    assert.equal(model.decisions.training.intensiteAuto.base, staff);
    for (const p of model.squad) assert.equal(p.loadMode, attendu(p, regle, staff), p.name + ' · préparateur ' + staff);
    model = jeu.call('set_delegation', { key: 'training', enabled: false });
    // Refus : niveau ou mode inconnus, « Auto » n'est pas une intensité de règle.
    for (const payload of [{ niveau: 5, mode: 'repos' }, { niveau: -1, mode: 'repos' }, { niveau: '1', mode: 'repos' }, { niveau: 1, mode: 'collective' }, { niveau: 1, mode: 'max' }, {}]) {
      const r = jeu.bridge.handle({ id: 99000 + Math.floor(Math.random() * 999), command: 'set_intensite_auto', payload });
      assert.equal(r.ok, false, JSON.stringify(payload));
    }
    assert.deepEqual(vm('S.intensiteAuto'), regle, 'règle intacte après les refus');
    // Avis du kiné appliqué à tous : chaque joueur valide reçoit l'avis ; en Auto quand sa règle le donne déjà.
    assert.ok(model.squad.some(p => p.avisKine !== p.loadMode), 'des écarts avant');
    model = jeu.call('appliquer_avis_kine');
    for (const p of model.squad) {
      assert.equal(p.loadMode, p.avisKine, p.name + ' : avis appliqué');
      if (p.loadPlan !== 'collective') assert.notEqual(p.autoModes.normal, p.avisKine, p.name + ' : reste en Auto si la règle suffit');
    }
    assert.ok(model.squad.filter(p => p.condition < 60).every(p => p.avisKine === 'repos'), 'condition < 60 : repos');
    // Séance intensive : chaque joueur en Auto travaille à « séance + cran de sa carte », garde-fou compris.
    jeu.bridge.vm.run("S.clubs[S.club].players.forEach(p=>{ensurePhysicalLoad(p).plan='collective';})");
    jeu.bridge.vm.run('globalThis.__modes={};const __avant=applyPhysicalTraining;applyPhysicalTraining=function(p,mode){if(S.clubs[S.club].players.includes(p))__modes[p.id]=mode;return __avant(p,mode);}');
    const avant = vm('S.clubs[S.club].players.map(p=>({id:p.id,condition:p.condition,physicalLoad:physicalLoadValue(p),injury:p.injury,loadPlan:p.physicalLoad?.plan??"collective"}))');
    jeu.call('train', { mode: 'intense' });
    const modes = vm('__modes');
    for (const p of avant) assert.equal(modes[p.id], attendu(p, regle, 'intense'), p.id + ' à ' + p.condition + ' %');
    assert.ok(avant.some(p => modes[p.id] === 'intense') && avant.some(p => modes[p.id] === 'normal'), 'séance intensive ajustée par la forme');
    // Sauvegarde : règle valide acceptée, règle abîmée refusée.
    assert.equal(vm('(()=>{const s=JSON.parse(JSON.stringify(S));try{validateCareer(s);return "ok"}catch(e){return String(e.message)}})()'), 'ok');
    for (const faux of ['["repos"]', '["repos","repos","normal","normal","collective"]', '"intense"']) {
      assert.notEqual(vm('(()=>{const s=JSON.parse(JSON.stringify(S));s.intensiteAuto=' + faux + ';try{validateCareer(s);return "ok"}catch(e){return "refus"}})()'), 'ok', faux);
    }
  } finally { jeu.fermer(); }
});

test('Coup d’envoi : blessure à la séance du jour, un espoir complète la feuille ; sinon refus clair', { timeout: 600000 }, () => {
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  const vm = code => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + code + ')'));
  try {
    let model = jusquAuMatch(jeu, creer(jeu));
    assert.equal(vm('S.trained'), false, 'séance pas encore faite le jour du match');
    if (!model.selection.valid) model = jeu.call('auto_lineup');
    // La séance lancée par le coup d'envoi blesse tous les piliers gauches pros (aucun remplaçant chez les pros).
    jeu.bridge.vm.run("{const __t=trainWeek;trainWeek=function(){const avant=S.trained;__t();if(!avant)for(const p of S.clubs[S.club].players)if(!p.espoirLoan&&slotEligible(p,0))p.injury=3;};}");
    const centre = vm("S.development.academy.filter(p=>slotEligible(p,0)).length");
    const r = jeu.brut('begin_match');
    if (r.ok) {
      assert.ok(centre > 0, 'un espoir apte au poste au centre');
      assert.ok(vm('!!S.live'), 'match lancé');
      const tenu = vm('(()=>{const ids=S.lineup.concat(S.reserves);return ids.map(id=>S.clubs[S.club].players.find(p=>p.id===id)).filter(p=>p&&p.espoirLoan).map(p=>p.pos)})()');
      assert.ok(tenu.length > 0, 'un espoir complète la feuille : ' + JSON.stringify(tenu));
      console.log('Espoir appelé au coup d’envoi : ' + tenu.join(', '));
      assert.ok(vm('S.clubs[S.club].players.filter(p=>!p.espoirLoan&&slotEligible(p,0)).every(p=>p.injury>0)'), 'les piliers gauches pros sont bien blessés');
      return;
    }
    assert.match(r.error, /^Blessure à la séance d’avant-match : .+ forfait, aucun remplaçant au poste\. Effectue d’abord la séance/u);
    assert.equal(vm('S.trained||!!S.live'), false, 'refus sans séance ni match enregistrés');
  } finally { jeu.fermer(); }
});

test('Coup d’envoi : sans jeune au centre, le refus nomme les blessés de la séance du jour', { timeout: 600000 }, () => {
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  const vm = code => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + code + ')'));
  try {
    let model = jusquAuMatch(jeu, creer(jeu));
    if (!model.selection.valid) model = jeu.call('auto_lineup');
    jeu.bridge.vm.run("S.development.academy=[];{const __t=trainWeek;trainWeek=function(){const avant=S.trained;__t();if(!avant)for(const p of S.clubs[S.club].players)if(!p.espoirLoan&&slotEligible(p,0))p.injury=3;};}");
    const r = jeu.brut('begin_match');
    assert.equal(r.ok, false);
    assert.match(r.error, /^Blessure à la séance d’avant-match : .+ \(Pilier gauche\).* forfait, aucun remplaçant au poste\. Effectue d’abord la séance \(Entraînement\), puis complète la feuille \(Composition\)\.$/u);
    assert.equal(vm('S.trained||!!S.live'), false, 'refus sans séance ni match enregistrés');
  } finally { jeu.fermer(); }
});
