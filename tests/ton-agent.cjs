'use strict';
// Discussion avec l'agent (revue FM27, idée 24 ; retouche « incertitude » du 23/11/2026) : ton, relation et caractère caché
// font pencher demande, patience et minimum accepté EN MOYENNE, avec un hasard de la journée tiré par la graine du monde.
// Rien de chiffré dans la projection ; le caractère se découvre (2e tour, négociation terminée, joueur observé).
// native/engine/ton-agent.cjs, commandes agent_ton / agent_question, projection market[].agent.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const K = require('../native/engine/ton-agent.cjs');

const N = 400;
const ids = Array.from({ length: N }, (_, i) => 'piste-' + i);
const moyenne = xs => xs.reduce((a, b) => a + b, 0) / xs.length;
function avecS(S, fn) {
  const avant = globalThis.S;
  globalThis.S = S;
  try { return fn(); } finally { if (avant === undefined) delete globalThis.S; else globalThis.S = avant; }
}
const monde = (seed = 7) => ({ season: 1, careerVariation: { seed }, economy: { week: 3, talks: {} }, market: ids.map(id => ({ id })), tonAgent: { version: 1, tons: {}, relations: {} } });

test('Règles pures : tons, crans, caractères, sauvegarde', () => {
  assert.deepEqual(Object.keys(K.TONS), ['tout_prix', 'enthousiaste', 'curieux']);
  assert.deepEqual(Object.keys(K.CARACTERES), ['gourmand', 'presse', 'fidele', 'poker', 'arrangeant']);
  assert.deepEqual(Object.values(K.CARACTERES).map(c => c.mot), ['Gourmand', 'Pressé', 'Fidèle à son joueur', 'Joueur de poker', 'Arrangeant']);
  assert.deepEqual([-10, -6, -5, -2, -1, 0, 1, 2, 5, 6, 10].map(K.cran), [0, 0, 1, 1, 2, 2, 2, 3, 3, 4, 4]);
  assert.equal(K.etatValide({ version: 1, tons: {}, relations: { a: 3 }, agents: { a: { car: 'poker', connu: false } } }), true);
  assert.equal(K.etatValide({ version: 1, tons: {}, relations: {}, agents: { a: { car: 'menteur', connu: false } } }), false);
  assert.equal(K.etatValide({ version: 1, tons: {}, relations: {}, jours: { a: { saison: 1, semaine: 2, n: 6, vexe: false } } }), false);
  assert.equal(K.etatValide({ version: 1, tons: {}, relations: { a: 11 } }), false);
});

test('Tendances moyennes sur 400 agents : le ton et la relation penchent sans garantir', () => {
  const S = monde();
  avecS(S, () => {
    const k = K.factory();
    const mesurer = (ton, rel) => {
      S.tonAgent.tons = {}; S.tonAgent.relations = {};
      for (const id of ids) {
        if (ton) S.tonAgent.tons[id] = { ton, saison: 1, semaine: 3 };
        if (rel) S.tonAgent.relations[id] = rel;
      }
      return { d: ids.map(id => k.ecartDemande(id)), s: ids.map(id => k.ecartSeuil(id)), p: ids.map(id => k.patience(id)) };
    };
    const tp = mesurer('tout_prix'), en = mesurer('enthousiaste'), cu = mesurer('curieux'), sans = mesurer('');
    // Demande : À tout prix > Enthousiaste > Curieux en moyenne, mais les plages se chevauchent.
    assert.ok(moyenne(tp.d) > moyenne(en.d) + 4 && moyenne(en.d) > moyenne(cu.d) + 2, `demande moyenne ${moyenne(tp.d)} / ${moyenne(en.d)} / ${moyenne(cu.d)}`);
    assert.ok(Math.min(...tp.d) < Math.max(...cu.d), 'un Curieux peut payer plus cher qu’un À tout prix');
    for (const x of [...tp.d, ...cu.d]) assert.ok(x >= -12 && x <= 19, 'écart de demande borné : ' + x);
    // Patience : 2 à 5, la même tendance, et un agent neutre peut rompre après 2 comme après 5.
    for (const x of [...tp.p, ...cu.p, ...sans.p, ...mesurer('curieux', -8).p]) assert.ok(x >= 2 && x <= 5);
    assert.ok(moyenne(tp.p) > moyenne(en.p) && moyenne(en.p) > moyenne(cu.p), `patience moyenne ${moyenne(tp.p)} / ${moyenne(en.p)} / ${moyenne(cu.p)}`);
    assert.ok(sans.p.includes(2) && sans.p.includes(5) && sans.p.includes(3), 'patience sans ton : 2 à 5 possibles');
    // Relation : Proche aide, Froide gêne (demande, minimum, patience).
    const proche = mesurer('', 8), froide = mesurer('', -8);
    assert.ok(moyenne(proche.d) < moyenne(sans.d) - 3 && moyenne(froide.d) > moyenne(sans.d) + 4);
    assert.ok(moyenne(proche.s) < moyenne(sans.s) - 2 && moyenne(froide.s) > moyenne(sans.s) + 3);
    assert.ok(moyenne(proche.p) > moyenne(froide.p) + 1.2, `patience Proche ${moyenne(proche.p)} / Froide ${moyenne(froide.p)}`);
    for (const x of [...proche.s, ...froide.s]) assert.ok(x >= -12 && x <= 11, 'minimum borné : ' + x);
    // Les cinq caractères sont tirés, chacun au moins 10 % du temps.
    const parCar = {};
    for (const id of ids) parCar[k.caractere(id)] = (parCar[k.caractere(id)] || 0) + 1;
    assert.deepEqual(Object.keys(parCar).sort(), Object.keys(K.CARACTERES).sort());
    for (const n of Object.values(parCar)) assert.ok(n >= N * .1, JSON.stringify(parCar));
    // Même graine : mêmes tirages ; autre graine ou autre journée : tirages différents.
    const avant = ids.map(id => [k.caractere(id), k.ecartDemande(id), k.patience(id)]);
    assert.deepEqual(ids.map(id => [k.caractere(id), k.ecartDemande(id), k.patience(id)]), avant);
    S.economy.week = 4;
    assert.notDeepEqual(ids.map(id => k.ecartDemande(id)), avant.map(x => x[1]), 'autre journée, autre hasard');
    assert.deepEqual(ids.map(id => k.caractere(id)), avant.map(x => x[0]), 'le caractère ne change pas d’une journée à l’autre');
    S.careerVariation.seed = 8;
    assert.notDeepEqual(ids.map(id => k.caractere(id)), avant.map(x => x[0]), 'autre monde, autres caractères');
  });
});

test('Projection sans chiffres, humeur qui se tend, caractère gardé', () => {
  const S = monde();
  avecS(S, () => {
    const k = K.factory();
    const v = k.vue('piste-1');
    assert.deepEqual(Object.keys(v).sort(), ['avant', 'caractere', 'cran', 'faites', 'humeur', 'libre', 'ton']);
    assert.equal(v.caractere, '', 'caractère inconnu au départ');
    assert.ok(['calme', 'agace', 'tendu'].includes(v.humeur));
    // Humeur : suit la patience restante (au plus un cran plus tendue, une fois sur trois) ; « tendu » à la dernière.
    const rang = { calme: 0, agace: 1, tendu: 2 };
    let brouillees = 0, total = 0;
    for (const id of ids.slice(0, 120)) {
      const max = k.patience(id);
      S.economy.talks['1:3:recruit:' + id] = { status: 'counter', attempts: 1 };
      for (let n = 0; n < max; n++) {
        S.tonAgent.jours = { [id]: { saison: 1, semaine: 3, n, vexe: false } };
        const h = rang[k.humeur(id)], reste = max - n, base = reste >= 3 ? 0 : reste === 2 ? 1 : 2;
        assert.ok(h === base || h === base + 1, `${id} : humeur ${h}, base ${base}`);
        if (base < 2) { total++; if (h > base) brouillees++; }
        if (n === max - 1) assert.equal(h, 2, 'dernière proposition : tendu');
      }
    }
    assert.ok(brouillees > total * .15 && brouillees < total * .5, `humeur brouillée ${brouillees}/${total}`);
    // Caractère : la sauvegarde prime sur le tirage ; le mot ne sort qu'une fois découvert.
    S.tonAgent.agents = { 'piste-2': { car: 'poker', connu: false } };
    assert.equal(k.caractere('piste-2'), 'poker');
    assert.equal(k.vue('piste-2').caractere, '');
    S.tonAgent.agents['piste-2'].connu = true;
    assert.equal(k.vue('piste-2').caractere, 'Joueur de poker');
    // Joueur observé par le recruteur : caractère découvert.
    S.playerKnowledge = { version: 1, records: [[['piste-3', 'observed']]] };
    assert.notEqual(k.vue('piste-3').caractere, '');
    assert.equal(k.etatValide(S.tonAgent), true);
  });
});

test('Carrière Monde : ton, découverte, patience cachée, relation selon l’issue', { timeout: 600000 }, () => {
  const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  const lire = code => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + code + ')'));
  try {
    const model = creer(jeu);
    const plancher = lire("typeof budgetActif==='function'&&budgetActif()?budgetPlancherHebdo():1000");
    const pistes = model.market.filter(p => p.available && p.agent && p.salary >= plancher * 3)
      .sort((a, b) => b.salary - a.salary || (a.id < b.id ? -1 : 1));
    assert.ok(pistes.length >= 4, 'quatre pistes chères disponibles');
    for (const p of pistes) {
      assert.deepEqual([p.agent.ton, p.agent.cran, p.agent.faites, p.agent.libre], ['', 2, 0, true]);
      for (const cle of ['essais', 'ecart', 'effet', 'relation', 'patience']) assert.equal(p.agent[cle], undefined, 'pas de chiffre : ' + cle);
    }
    const [a, b, c, d] = pistes;
    const offrir = id => jeu.brut('recruit', { playerId: id, salary: plancher, years: 1, confirmed: true });
    const piste = (m, id) => m.market.find(p => p.id === id);
    const relations = () => lire('S.tonAgent.relations');
    const agents = () => lire('S.tonAgent.agents||{}');

    // À tout prix : relation +2 (Bonne), caractère gardé mais pas encore découvert (sauf joueur déjà observé).
    let r = jeu.brut('agent_ton', { playerId: a.id, ton: 'tout_prix' });
    assert.equal(r.ok, true, r.error);
    let vu = piste(r.model, a.id);
    assert.deepEqual([vu.agent.ton, vu.agent.cran, vu.agent.avant, vu.agent.libre], ['tout_prix', 3, 2, false]);
    assert.ok(agents()[a.id], 'caractère gardé dans la sauvegarde');
    const observe = a.knowledge?.stage === 'observed' || a.knowledge?.stage === 'deep';
    if (!observe) assert.equal(vu.agent.caractere, '', 'caractère encore inconnu');
    assert.match(jeu.brut('agent_ton', { playerId: a.id, ton: 'curieux' }).error, /déjà/);
    // Deuxième tour : le caractère se découvre (le mot seulement).
    r = jeu.brut('agent_question', { playerId: a.id });
    assert.equal(r.ok, true, r.error);
    vu = piste(r.model, a.id);
    assert.ok(Object.values(require('../native/engine/ton-agent.cjs').CARACTERES).some(x => x.mot === vu.agent.caractere), 'caractère découvert : ' + vu.agent.caractere);

    // Offres ridicules jusqu'à la rupture : entre 2 et 5 propositions, réplique sans « n/3 », humeur qui ne se calme pas.
    const rompre = id => {
      let n = 0, res;
      do {
        res = offrir(id); n++;
        assert.equal(res.ok, true, res.error);
        assert.doesNotMatch(String(res.model.meta.negotiation.message), /\d\/\d/, 'aucun compteur dans la réplique');
      } while (res.model.meta.negotiation.status === 'counter' && n < 6);
      assert.equal(res.model.meta.negotiation.status, 'withdrawn', 'rupture');
      assert.ok(n >= 2 && n <= 5, 'patience entre 2 et 5 : ' + n);
      assert.equal(piste(res.model, id).agent.humeur, 'rompu');
      assert.equal(offrir(id).ok, false, 'plus de proposition après la rupture');
      return n;
    };
    const na = rompre(a.id);
    assert.equal(relations()[a.id], 0, 'ridicule −1 (une fois) puis rupture −1 : ' + na + ' propositions');

    // Curieux : relation −1 ; après la rupture le caractère est découvert ; relation −3.
    r = jeu.brut('agent_ton', { playerId: b.id, ton: 'curieux' });
    assert.equal(piste(r.model, b.id).agent.cran, 2);
    rompre(b.id);
    assert.equal(relations()[b.id], -3);
    assert.equal(agents()[b.id].connu, true, 'négociation terminée : caractère découvert');

    // Proche : accord au minimum accepté (relation +1, caractère découvert).
    jeu.bridge.vm.run(`S.tonAgent.relations[${JSON.stringify(c.id)}]=7;`);
    const minimum = lire(`reservationWage(S.market.find(p=>p.id===${JSON.stringify(c.id)}),'recruit',1)`);
    r = jeu.brut('recruit', { playerId: c.id, salary: minimum, years: 1, confirmed: true });
    assert.equal(r.ok, true, r.error);
    assert.equal(relations()[c.id], 8, 'accord : +1');
    assert.equal(agents()[c.id].connu, true);

    // Négociation commencée : plus de ton ; sauvegarde valide.
    assert.equal(offrir(d.id).ok, true);
    assert.equal(agents()[d.id].connu, true, 'première proposition : caractère connu pour toujours');
    assert.notEqual(lire(`tonAgentVue(${JSON.stringify(d.id)}).caractere`), '', 'mot du caractère projeté');
    assert.match(jeu.brut('agent_ton', { playerId: d.id, ton: 'enthousiaste' }).error, /commencée/);
    assert.equal(lire('(validateCareer(S),true)'), true);
  } finally { jeu.fermer(); }
});
