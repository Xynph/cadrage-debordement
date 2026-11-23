'use strict';
// Discussion avec l'agent (revue FM27, idée 24 ; choix de Léo du 23/11/2026) : le ton donné à l'agent d'une piste règle la
// demande (+6 % / = / −3 %) et le nombre de propositions de la journée (4 / 3 / 2) ; la relation avec l'agent est gardée
// (+2 / +1 / −1) et pèse aussi : Proche −5 % / +1 proposition / minimum −4 % ; Bonne −2 % / minimum −2 % ; Distante +3 % /
// minimum +2 % ; Froide +6 % / −1 proposition / minimum +5 %. Issue : accord +1, offre ridicule −1 (une fois par journée),
// rupture −1. native/engine/ton-agent.cjs, commande agent_ton, projection market[].agent.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const K = require('../native/engine/ton-agent.cjs');

test('Règles pures : tons et crans de relation', () => {
  assert.deepEqual(Object.keys(K.TONS), ['tout_prix', 'enthousiaste', 'curieux']);
  assert.deepEqual(Object.values(K.TONS).map(t => [t.ecart, t.essais, t.relation]), [[6, 4, 2], [0, 3, 1], [-3, 2, -1]]);
  assert.deepEqual([-10, -6, -5, -2, -1, 0, 1, 2, 5, 6, 10].map(K.cran), [0, 0, 1, 1, 2, 2, 2, 3, 3, 4, 4]);
  assert.deepEqual(K.EFFETS.map(e => [e.demande, e.essais, e.seuil]), [[6, -1, 5], [3, 0, 2], [0, 0, 0], [-2, 0, -2], [-5, 1, -4]]);
  assert.equal(K.etatValide({ version: 1, tons: {}, relations: { a: 3 } }), true);
  assert.equal(K.etatValide({ version: 1, tons: {}, relations: {}, jours: { a: { saison: 1, semaine: 2, n: 4, vexe: true } } }), true);
  assert.equal(K.etatValide({ version: 1, tons: {}, relations: {}, jours: { a: { saison: 1, semaine: 2, n: 6, vexe: false } } }), false);
  assert.equal(K.etatValide({ version: 1, tons: { a: { ton: 'fou', saison: 1, semaine: 1 } }, relations: {} }), false);
  assert.equal(K.etatValide({ version: 1, tons: {}, relations: { a: 11 } }), false);
});

test('Effet de chaque cran, cumul avec le ton, bornes', () => {
  const avant = globalThis.S;
  try {
    const S = globalThis.S = { season: 1, economy: { week: 3, talks: {} }, market: [{ id: 'x' }], tonAgent: { version: 1, tons: {}, relations: {} } };
    const k = K.factory();
    const p = { id: 'x' };
    const mesure = r => { S.tonAgent.relations.x = r; return [k.demande(10000, p, 'recruit'), k.essais('x'), k.seuil(10000, p, 'recruit')]; };
    // Sans ton : Froide, Distante, Neutre, Bonne, Proche.
    assert.deepEqual([-8, -3, 0, 3, 8].map(mesure), [[10600, 2, 10500], [10300, 3, 10200], [10000, 3, 10000], [9800, 3, 9800], [9500, 4, 9600]]);
    // Prolongation et renouvellement non touchés.
    assert.equal(k.demande(10000, p, 'renew'), 10000);
    assert.equal(k.seuil(10000, p, 'renew'), 10000);
    // Cumul avec le ton (écarts additionnés, propositions bornées 1..5).
    S.tonAgent.tons.x = { ton: 'tout_prix', saison: 1, semaine: 3 };
    assert.deepEqual(mesure(10), [10100, 5, 9600], 'Proche + À tout prix : +6 −5 %, 5 propositions');
    assert.deepEqual(mesure(-10), [11200, 3, 10500], 'Froide + À tout prix : +12 %, 3 propositions');
    S.tonAgent.tons.x = { ton: 'curieux', saison: 1, semaine: 3 };
    assert.deepEqual(mesure(-10), [10300, 1, 10500], 'Froide + Curieux : 1 proposition au minimum');
    assert.deepEqual(mesure(6), [9200, 3, 9600], 'Proche + Curieux : −8 %, 3 propositions');
    // Ton d'une autre journée : seule la relation compte.
    S.economy.week = 4;
    assert.deepEqual(mesure(-3), [10300, 3, 10200]);
    const v = k.vue('x');
    assert.deepEqual([v.ton, v.essais, v.cran, v.effet, v.faites], ['', 3, 1, { demande: 3, essais: 0, seuil: 2 }, 0]);
  } finally { if (avant === undefined) delete globalThis.S; else globalThis.S = avant; }
});

test('Carrière Monde : ton, relation qui pèse, issue qui la fait évoluer', { timeout: 600000 }, () => {
  const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  const lire = code => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + code + ')'));
  try {
    const model = creer(jeu);
    const plancher = lire("typeof budgetActif==='function'&&budgetActif()?budgetPlancherHebdo():1000");
    const pistes = model.market.filter(p => p.available && p.agent && p.salary >= plancher * 3)
      .sort((a, b) => b.salary - a.salary || (a.id < b.id ? -1 : 1));
    assert.ok(pistes.length >= 5, 'cinq pistes chères disponibles');
    for (const p of pistes) assert.deepEqual([p.agent.ton, p.agent.essais, p.agent.relation, p.agent.cran, p.agent.faites, p.agent.libre], ['', 3, 0, 2, 0, true]);
    const [a, b, c, d, e] = pistes;
    // Offre ridicule (moins de 70 % de la demande).
    const offrir = id => jeu.brut('recruit', { playerId: id, salary: plancher, years: 1, confirmed: true });
    const piste = (m, id) => m.market.find(p => p.id === id);
    const relations = () => lire('S.tonAgent.relations');
    const poser = (id, r) => jeu.bridge.vm.run(`S.tonAgent=S.tonAgent||{version:1,tons:{},relations:{}};S.tonAgent.relations[${JSON.stringify(id)}]=${r};`);

    // À tout prix : relation 0 → +2 (Bonne) : demande +6 −2 = +4 %, quatre propositions.
    let r = jeu.brut('agent_ton', { playerId: a.id, ton: 'tout_prix' });
    assert.equal(r.ok, true, r.error);
    let vu = piste(r.model, a.id);
    assert.equal(vu.salary, Math.round(a.salary * 1.04 / 10) * 10, 'demande +4 %');
    assert.deepEqual([vu.agent.ton, vu.agent.essais, vu.agent.ecart, vu.agent.relation, vu.agent.avant, vu.agent.cran, vu.agent.libre], ['tout_prix', 4, 6, 2, 0, 3, false]);
    assert.deepEqual(vu.agent.effet, { demande: -2, essais: 0, seuil: -2 });
    assert.match(jeu.brut('agent_ton', { playerId: a.id, ton: 'curieux' }).error, /déjà/);
    for (let n = 1; n <= 3; n++) {
      r = offrir(a.id);
      assert.equal(r.ok, true, r.error);
      assert.equal(r.model.meta.negotiation.status, 'counter', 'proposition ' + n + ' : ' + JSON.stringify(r.model.meta.negotiation));
      assert.match(r.model.meta.negotiation.message, new RegExp(n + '/4\\.$'));
      assert.equal(piste(r.model, a.id).agent.faites, n);
    }
    assert.equal(relations()[a.id], 1, 'offre ridicule : −1 une seule fois dans la journée');
    r = offrir(a.id);
    assert.equal(r.model.meta.negotiation.status, 'withdrawn', '4e proposition refusée : rupture');
    assert.match(r.model.meta.negotiation.message, /quatre propositions/);
    assert.equal(offrir(a.id).ok, false, 'plus de 5e proposition');
    assert.equal(relations()[a.id], 0, 'rupture : −1');

    // Curieux : relation −1 (Neutre), deux propositions ; ridicule −1 puis rupture −1.
    r = jeu.brut('agent_ton', { playerId: b.id, ton: 'curieux' });
    vu = piste(r.model, b.id);
    assert.equal(vu.salary, Math.round(b.salary * .97 / 10) * 10, 'demande −3 %');
    assert.deepEqual([vu.agent.essais, vu.agent.relation, vu.agent.cran], [2, -1, 2]);
    r = offrir(b.id);
    assert.match(r.model.meta.negotiation.message, /1\/2\.$/);
    r = offrir(b.id);
    assert.equal(r.model.meta.negotiation.status, 'withdrawn');
    assert.equal(relations()[b.id], -3);

    // Proche (+8) + À tout prix (+10) : cinq propositions, demande +1 %.
    poser(c.id, 8);
    r = jeu.brut('agent_ton', { playerId: c.id, ton: 'tout_prix' });
    vu = piste(r.model, c.id);
    assert.equal(vu.salary, Math.round(c.salary * 1.01 / 10) * 10, 'demande +6 −5 %');
    assert.deepEqual([vu.agent.essais, vu.agent.relation, vu.agent.cran], [5, 10, 4]);
    for (let n = 1; n <= 4; n++) {
      r = offrir(c.id);
      assert.equal(r.model.meta.negotiation.status, 'counter', 'proposition ' + n);
      assert.match(r.model.meta.negotiation.message, new RegExp(n + '/5\\.$'));
    }
    r = offrir(c.id);
    assert.equal(r.model.meta.negotiation.status, 'withdrawn', '5e refusée');
    assert.match(r.model.meta.negotiation.message, /cinq propositions/);
    assert.equal(offrir(c.id).ok, false);
    assert.equal(relations()[c.id], 8);

    // Froide (−8) + Curieux (−9) : une seule proposition.
    poser(d.id, -8);
    r = jeu.brut('agent_ton', { playerId: d.id, ton: 'curieux' });
    vu = piste(r.model, d.id);
    assert.equal(vu.salary, Math.round(d.salary * 1.03 / 10) * 10, 'demande −3 +6 %');
    assert.deepEqual([vu.agent.essais, vu.agent.cran], [1, 0]);
    r = offrir(d.id);
    assert.equal(r.model.meta.negotiation.status, 'withdrawn', 'une proposition refusée : rupture');
    assert.match(r.model.meta.negotiation.message, /^La proposition a échoué/);
    assert.equal(relations()[d.id], -10, 'bornée à −10');

    // Proche, sans ton : minimum accepté −4 % ; accord au minimum : relation +1.
    const minimum = () => lire(`reservationWage(S.market.find(p=>p.id===${JSON.stringify(e.id)}),'recruit',1)`);
    const neutre = minimum();
    poser(e.id, 7);
    const proche = minimum();
    assert.ok(proche < neutre * .95, `minimum Proche ${proche} < 95 % de ${neutre}`);
    r = jeu.brut('recruit', { playerId: e.id, salary: proche, years: 1, confirmed: true });
    assert.equal(r.ok, true, r.error);
    assert.equal(relations()[e.id], 8, 'accord : +1');

    // Négociation commencée : plus de ton pour cette journée ; relation gardée dans la sauvegarde.
    const f = pistes[5];
    if (f) {
      assert.equal(offrir(f.id).ok, true);
      assert.match(jeu.brut('agent_ton', { playerId: f.id, ton: 'enthousiaste' }).error, /commencée/);
    }
    assert.equal(lire('(validateCareer(S),true)'), true);
  } finally { jeu.fermer(); }
});
