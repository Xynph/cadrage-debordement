'use strict';
// Discussion avec l'agent (revue FM27, idée 24 ; choix de Léo du 23/11/2026) : le ton donné à l'agent d'une piste règle la
// demande (+6 % / = / −3 %) et le nombre de propositions de la journée (4 / 3 / 2) ; la relation avec l'agent est gardée
// (+2 / +1 / −1). native/engine/ton-agent.cjs, commande agent_ton, projection market[].agent.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const K = require('../native/engine/ton-agent.cjs');

test('Règles pures : tons et crans de relation', () => {
  assert.deepEqual(Object.keys(K.TONS), ['tout_prix', 'enthousiaste', 'curieux']);
  assert.deepEqual(Object.values(K.TONS).map(t => [t.ecart, t.essais, t.relation]), [[6, 4, 2], [0, 3, 1], [-3, 2, -1]]);
  assert.deepEqual([-10, -6, -5, -2, -1, 0, 1, 2, 5, 6, 10].map(K.cran), [0, 0, 1, 1, 2, 2, 2, 3, 3, 4, 4]);
  assert.equal(K.etatValide({ version: 1, tons: {}, relations: { a: 3 } }), true);
  assert.equal(K.etatValide({ version: 1, tons: { a: { ton: 'fou', saison: 1, semaine: 1 } }, relations: {} }), false);
  assert.equal(K.etatValide({ version: 1, tons: {}, relations: { a: 11 } }), false);
});

test('Carrière Monde : ton à tout prix (4 propositions), curieux (2), relation gardée', { timeout: 600000 }, () => {
  const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  const lire = code => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + code + ')'));
  try {
    const model = creer(jeu);
    const plancher = lire("typeof budgetActif==='function'&&budgetActif()?budgetPlancherHebdo():1000");
    const pistes = model.market.filter(p => p.available && p.agent && p.salary >= plancher * 3)
      .sort((a, b) => b.salary - a.salary || (a.id < b.id ? -1 : 1));
    assert.ok(pistes.length >= 2, 'deux pistes chères disponibles');
    for (const p of pistes) assert.deepEqual([p.agent.ton, p.agent.essais, p.agent.relation, p.agent.cran, p.agent.libre], ['', 3, 0, 2, true]);
    const [a, b] = pistes;
    const offrir = id => jeu.brut('recruit', { playerId: id, salary: plancher, years: 1, confirmed: true });
    const piste = (m, id) => m.market.find(p => p.id === id);

    // À tout prix : demande +6 %, quatre propositions.
    let r = jeu.brut('agent_ton', { playerId: a.id, ton: 'tout_prix' });
    assert.equal(r.ok, true, r.error);
    let vu = piste(r.model, a.id);
    assert.equal(vu.salary, Math.round(a.salary * 1.06 / 10) * 10, 'demande +6 %');
    assert.deepEqual([vu.agent.ton, vu.agent.essais, vu.agent.ecart, vu.agent.relation, vu.agent.avant, vu.agent.cran, vu.agent.libre], ['tout_prix', 4, 6, 2, 0, 3, false]);
    assert.match(jeu.brut('agent_ton', { playerId: a.id, ton: 'curieux' }).error, /déjà/);
    for (let n = 1; n <= 3; n++) {
      r = offrir(a.id);
      assert.equal(r.ok, true, r.error);
      assert.equal(r.model.meta.negotiation.status, 'counter', 'proposition ' + n + ' : ' + JSON.stringify(r.model.meta.negotiation));
      assert.match(r.model.meta.negotiation.message, new RegExp(n + '/4\\.$'));
    }
    assert.equal(piste(r.model, a.id).negotiation.attempts, 3);
    r = offrir(a.id);
    assert.equal(r.ok, true, r.error);
    assert.equal(r.model.meta.negotiation.status, 'withdrawn', '4e proposition refusée : rupture');
    assert.equal(offrir(a.id).ok, false, 'plus de 5e proposition');

    // Curieux : demande −3 %, deux propositions.
    r = jeu.brut('agent_ton', { playerId: b.id, ton: 'curieux' });
    assert.equal(r.ok, true, r.error);
    vu = piste(r.model, b.id);
    assert.equal(vu.salary, Math.round(b.salary * .97 / 10) * 10, 'demande −3 %');
    assert.deepEqual([vu.agent.essais, vu.agent.relation, vu.agent.cran], [2, -1, 2]);
    r = offrir(b.id);
    assert.equal(r.model.meta.negotiation.status, 'counter');
    assert.match(r.model.meta.negotiation.message, /1\/2\.$/);
    r = offrir(b.id);
    assert.equal(r.model.meta.negotiation.status, 'withdrawn', '2e proposition refusée : rupture');
    assert.equal(offrir(b.id).ok, false);

    // Négociation commencée : plus de ton pour cette journée ; relation gardée dans la sauvegarde.
    const c = pistes[2];
    if (c) {
      assert.equal(offrir(c.id).ok, true);
      assert.match(jeu.brut('agent_ton', { playerId: c.id, ton: 'enthousiaste' }).error, /commencée/);
    }
    assert.deepEqual(lire('S.tonAgent.relations'), { [a.id]: 2, [b.id]: -1 });
    assert.equal(lire('(validateCareer(S),true)'), true);
  } finally { jeu.fermer(); }
});
