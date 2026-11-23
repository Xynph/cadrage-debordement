'use strict';
// Agents de joueurs nommés (retour de Léo du 23/11/2026) : chaque joueur de 18 ans et plus a un agent nommé, avec son
// agence ; quelques grandes agences ont beaucoup de clients, la plupart des agents en ont de 1 à 5. Annuaire tiré par la
// graine du monde et gardé dans la sauvegarde ; relation et caractère sont ceux de l'agent (partagés par ses clients) ;
// les anciennes sauvegardes (relation et caractère par joueur) sont converties.
// native/engine/agents-joueurs.cjs, native/engine/ton-agent.cjs.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const A = require('../native/engine/agents-joueurs.cjs');

function avecS(S, fn) {
  const avant = globalThis.S;
  globalThis.S = S;
  try { return fn(); } finally { if (avant === undefined) delete globalThis.S; else globalThis.S = avant; }
}
// Petit monde synthétique : 40 clubs de 45 joueurs, un marché de 60 joueurs libres.
const monde = seed => ({
  careerVariation: { seed }, season: 1, club: 0,
  clubs: Array.from({ length: 40 }, (_, c) => ({ id: c, name: 'Club ' + c, players: Array.from({ length: 45 }, (_, i) => ({ id: `p${c}-${i}`, name: 'J ' + i, pos: 'Centre', age: 19 + (i % 15), rating: 50 + i })) })),
  market: Array.from({ length: 60 }, (_, i) => ({ id: 'libre-' + i, name: 'L ' + i, pos: 'Ailier', age: i === 0 ? 17 : 24 })),
});

test('Annuaire déterministe par graine, un agent par joueur adulte', () => {
  const S1 = monde(11), S2 = monde(11), S3 = monde(12);
  const [e1, e2, e3] = [S1, S2, S3].map(S => avecS(S, () => { const k = A.factory(); k.observe(); return S.agentsJoueurs; }));
  assert.deepEqual(e1, e2, 'même graine : même annuaire');
  assert.notDeepEqual(e1.agents.map(a => a.nom), e3.agents.map(a => a.nom), 'autre graine : autres agents');
  avecS(S1, () => {
    const k = A.factory();
    assert.equal(k.etatValide(S1.agentsJoueurs), true);
    assert.equal(k.observe(), 0, 'annuaire déjà posé : rien à refaire');
    const ids = new Set(e1.agents.map(a => a.id));
    for (const c of S1.clubs) for (const p of c.players) assert.ok(ids.has(k.agentId(p.id, p.age)), 'agent connu pour ' + p.id);
    assert.equal(k.agentId('libre-0', 17), null, 'moins de 18 ans : pas encore d’agent');
    // Même joueur, même agent, même après un transfert ; joueur créé plus tard : un agent aussi.
    const avant = k.agentId('p3-4');
    S1.clubs[7].players.push(S1.clubs[3].players.splice(4, 1)[0]);
    assert.equal(A.factory().agentId('p3-4'), avant, 'l’agent suit le joueur');
    assert.ok(ids.has(k.agentId('jeune-promu-2031', 18)), 'nouveau joueur affecté');
    // Noms et agences fictifs, sans caractère interdit dans la sauvegarde.
    for (const a of e1.agents) { assert.match(a.nom, /^\S+ \S+/); assert.doesNotMatch(a.nom + a.agence, /[<>"`&]/); }
    assert.equal(new Set(e1.agents.map(a => a.nom)).size, e1.agents.length, 'noms uniques');
  });
  assert.throws(() => avecS(S1, () => A.factory().validate({ agentsJoueurs: { version: 1, graine: 1, agents: [{ id: 'x' }] } })), /Annuaire/);
});

test('Carrière Monde : répartition, projection, relation partagée, migration des anciennes sauvegardes', { timeout: 600000 }, () => {
  const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');
  const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
  const lire = code => JSON.parse(jeu.bridge.vm.run('JSON.stringify(' + code + ')'));
  try {
    const model = creer(jeu);
    // Chaque joueur (clubs, marché) de 18 ans et plus a un agent de l'annuaire.
    const bilan = lire(`(()=>{const ids=new Set(S.agentsJoueurs.agents.map(a=>a.id));let n=0,sans=0,jeunes=0;
      for(const p of [...S.clubs.flatMap(c=>c.players),...S.market]){n++;const a=agentJoueurId(p.id,p.age);if(p.age<18){jeunes++;if(a)sans=-1e9;continue;}if(!ids.has(a))sans++;}return {n,sans,jeunes};})()`);
    assert.ok(bilan.n > 5000, 'monde complet : ' + bilan.n);
    assert.equal(bilan.sans, 0, 'joueurs sans agent');
    // Répartition : quelques grandes agences, beaucoup d'agents avec 1 à 5 clients.
    const r = lire('agentsJoueursRepartition()');
    const petits = r.tailles.filter(k => k >= 1 && k <= 5).length, agences = Object.values(r.parAgence).sort((a, b) => b - a);
    assert.ok(r.agents >= 600 && r.agents <= 1600, 'nombre d’agents : ' + r.agents);
    assert.ok(petits >= r.agents * .6, `agents à 1-5 clients : ${petits}/${r.agents}`);
    assert.ok(agences[0] >= 250 && agences[4] >= 150 && agences[5] < 120, 'cinq grandes agences : ' + agences.slice(0, 7));
    assert.ok(Math.max(...r.tailles) >= 40, 'un agent de grande agence gère beaucoup de joueurs');
    // Projection : agents de l'effectif et du marché, nom, agence, clients (sans note), relation en cran.
    const vue = model.clubLife.agentsJoueurs;
    for (const p of [...model.squad, ...model.market].filter(p => p.age >= 18)) assert.ok(vue.agents[vue.joueurs[p.id]], 'agent projeté pour ' + p.id);
    const fiche = vue.agents[vue.joueurs[model.market[0].id]];
    assert.deepEqual(Object.keys(fiche).sort(), ['age', 'agence', 'caractere', 'clients', 'cran', 'id', 'nom', 'pays', 'rang', 'rangMot', 'total']);
    assert.ok(fiche.clients.length >= 1 && fiche.clients.length <= 12 && fiche.total >= fiche.clients.length);
    assert.ok(fiche.clients.every(c => c.length === 7), 'lignes compactes, sans note');
    assert.equal(model.market[0].agent.nom, fiche.nom, 'même agent dans la discussion');

    // Relation partagée : deux pistes du même agent ; le ton donné pour l'une compte pour l'autre.
    const parAgent = {};
    for (const p of model.market.filter(p => p.available && p.agent?.libre)) (parAgent[p.agent.agent] ||= []).push(p);
    const paire = Object.values(parAgent).find(l => l.length >= 2);
    assert.ok(paire, 'deux pistes du même agent sur le marché');
    const [x, y] = paire;
    let res = jeu.brut('agent_ton', { playerId: x.id, ton: 'tout_prix' });
    assert.equal(res.ok, true, res.error);
    const vy = res.model.market.find(p => p.id === y.id).agent;
    assert.equal(vy.cran, 3, 'relation Bonne aussi pour l’autre client');
    assert.equal(res.model.clubLife.agentsJoueurs.agents[x.agent.agent].cran, 3, 'cran de l’agent dans sa fiche');
    res = jeu.brut('agent_question', { playerId: x.id });
    assert.equal(res.ok, true, res.error);
    assert.notEqual(res.model.market.find(p => p.id === y.id).agent.caractere, '', 'caractère découvert pour tous ses clients');

    // Migration : ancienne sauvegarde (version 1, relation et caractère par joueur) → par agent.
    const ag = x.agent.agent, carAvant = lire(`agentJoueur(${JSON.stringify(ag)}).car`);
    const autre = ['gourmand', 'presse', 'fidele', 'poker', 'arrangeant'].find(c => c !== carAvant);
    jeu.bridge.vm.run(`S.tonAgent={version:1,tons:{},relations:{${JSON.stringify(x.id)}:4,${JSON.stringify(y.id)}:3},agents:{${JSON.stringify(y.id)}:{car:${JSON.stringify(autre)},connu:true}}};delete S.agentsJoueurs;`);
    assert.equal(lire('(validateCareer(S),true)'), true, 'ancienne sauvegarde valide');
    res = jeu.brut('agent_question', { playerId: model.market.find(p => p.agent.agent !== ag).id });
    assert.equal(res.ok, true, res.error);
    const t = lire('S.tonAgent');
    assert.equal(t.version, 2);
    assert.equal(t.relations[ag], 7, 'relations des deux clients additionnées pour l’agent');
    assert.equal(t.connus[ag], true, 'découverte gardée');
    assert.equal(lire(`agentJoueur(${JSON.stringify(ag)}).car`), autre, 'caractère gardé repris par l’agent');
    assert.equal(res.model.market.find(p => p.id === y.id).agent.cran, 4, 'Proche pour ses deux clients');
    // Sauvegarde : annuaire refait à l'identique (graine), carrière valide après un aller-retour JSON.
    assert.equal(lire('S.agentsJoueurs.agents.length'), r.agents);
    assert.equal(lire('(validateCareer(JSON.parse(JSON.stringify(S))),true)'), true);
  } finally { jeu.fermer(); }
});
