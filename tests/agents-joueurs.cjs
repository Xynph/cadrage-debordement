'use strict';
// Agents de joueurs nommés (retour de Léo du 23/11/2026) : chaque joueur de 18 ans et plus a un agent nommé, avec son
// agence ; la plus grosse agence compte ≈ 100-150 joueurs, aucun agent n’en suit plus de 30, la plupart des agents en ont de 1 à 8. Annuaire tiré par la
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

test('Visages des agents : sexe, liste des femmes, répartition, anciennes sauvegardes', () => {
  const S1 = monde(11), S2 = monde(11);
  const [e1, e2] = [S1, S2].map(S => avecS(S, () => { A.factory().observe(); return S.agentsJoueurs; }));
  assert.deepEqual(e1.agents.map(a => [a.id, a.sexe, a.portrait]), e2.agents.map(a => [a.id, a.sexe, a.portrait]), 'même graine : mêmes visages');
  const k = A.factory();
  const femmes = e1.agents.filter(a => a.sexe === 'F');
  assert.ok(femmes.length >= e1.agents.length * .08 && femmes.length <= e1.agents.length * .25, `agentes minoritaires : ${femmes.length}/${e1.agents.length}`);
  for (const a of e1.agents) {
    assert.ok((a.sexe === 'F' ? k.FEMMES : k.HOMMES).includes(a.portrait), `visage de la bonne liste : ${a.id} ${a.sexe} ${a.portrait}`);
  }
  assert.equal(k.FEMMES.length + k.HOMMES.length, 60);
  // Prénom féminin pour une agente (jamais un prénom du générateur du staff, tous masculins).
  for (const a of femmes) assert.match(a.nom, /^(Amélie|Anne|Camille|Caroline|Céline|Charlotte|Claire|Élodie|Émilie|Hélène|Isabelle|Julie|Laure|Léa|Lucie|Manon|Marion|Mathilde|Nathalie|Pauline|Sandrine|Sophie|Valérie|Virginie|Abigail|Alice|Amy|Chloe|Emily|Emma|Georgia|Grace|Hannah|Helen|Jessica|Kate|Laura|Lucy|Megan|Olivia|Rachel|Rebecca|Sarah|Victoria|Zoe|Aiko|Akemi|Ayaka|Chiaki|Emi|Haruka|Hitomi|Kaori|Keiko|Mai|Mayumi|Megumi|Miho|Misaki|Naomi|Nanami|Rie|Sakura|Sayaka|Tomoko|Yoko|Yui|Yumi|Yuko) /);
  // Jamais deux visages identiques dans une agence (les listes sont assez longues pour ce monde) ; visages répartis.
  const parAgence = {};
  for (const a of e1.agents) { const cle = a.agence + '|' + a.portrait; assert.ok(!parAgence[cle], 'même visage dans ' + a.agence); parAgence[cle] = true; }
  // Visages répartis dans chaque origine (par sexe) : chaque visage d'un groupe sert à peu près autant de fois.
  for (const o of k.ORIGINES) for (const [sexe, liste] of [['H', k.HOMMES], ['F', k.FEMMES]]) {
    const qui = e1.agents.filter(a => a.sexe === sexe && a.origine === o);
    if (!qui.length) continue;
    const n = liste.filter(v => k.ORIGINE(v) === o).map(v => qui.filter(a => a.portrait === v).length);
    assert.ok(Math.max(...n) - Math.min(...n) <= 2, `visages répartis (${o} ${sexe}) : ` + n.join(','));
  }
  // Sauvegarde : aller-retour JSON, mêmes visages, annuaire valide.
  avecS({ ...S1, agentsJoueurs: JSON.parse(JSON.stringify(e1)) }, () => {
    const k2 = A.factory();
    assert.equal(k2.etatValide(globalThis.S.agentsJoueurs), true);
    assert.equal(k2.observe(), 0, 'visages déjà posés : rien à refaire');
    assert.deepEqual(globalThis.S.agentsJoueurs.agents.map(a => a.portrait), e1.agents.map(a => a.portrait));
  });
  // Ancienne sauvegarde (annuaire sans visage) : agents hommes, visages posés par le même calcul, puis gardés.
  const ancien = () => { const e = JSON.parse(JSON.stringify(e1)); for (const a of e.agents) { delete a.sexe; delete a.portrait; delete a.origine; } return e; };
  const [v1, v2] = [ancien(), ancien()].map(e => avecS({ ...monde(11), agentsJoueurs: e }, () => {
    const k3 = A.factory();
    assert.equal(k3.etatValide(e), true, 'ancien annuaire valide');
    assert.equal(k3.observe(), 1, 'visages posés');
    assert.equal(k3.observe(), 0);
    assert.equal(k3.etatValide(e), true);
    return e.agents.map(a => a.sexe + a.portrait);
  }));
  assert.deepEqual(v1, v2, 'ancienne sauvegarde : attribution stable');
  assert.ok(v1.every(x => x[0] === 'H' && k.HOMMES.includes(Number(x.slice(1)))), 'agents d’avant : visages d’hommes');
  // Sauvegarde d'avant l'accord nom / visage (sexe et visage sans origine) : visages refaits au chargement, exactement
  // ceux d'un annuaire neuf de même graine ; stable d'un chargement à l'autre.
  const sansOrigine = () => { const e = JSON.parse(JSON.stringify(e1)); e.agents.forEach((a, i) => { delete a.origine; a.portrait = (a.sexe === 'F' ? k.FEMMES : k.HOMMES)[i % (a.sexe === 'F' ? k.FEMMES : k.HOMMES).length]; }); return e; };
  for (const e of [sansOrigine(), sansOrigine()]) avecS({ ...monde(11), agentsJoueurs: e }, () => {
    const k4 = A.factory();
    assert.equal(k4.etatValide(e), true, 'annuaire sans origine lisible');
    assert.equal(k4.observe(), 1, 'visages refaits');
    assert.equal(k4.observe(), 0);
    assert.deepEqual(e, e1, 'mêmes visages qu’un annuaire neuf');
  });
  // Visage invalide ou d'une autre liste : annuaire refusé.
  const faux = JSON.parse(JSON.stringify(e1)); faux.agents[0].portrait = faux.agents[0].sexe === 'F' ? k.HOMMES[0] : k.FEMMES[0];
  assert.equal(k.etatValide(faux), false);
  const autreOrigine = JSON.parse(JSON.stringify(e1)), a0 = autreOrigine.agents[0];
  a0.portrait = (a0.sexe === 'F' ? k.FEMMES : k.HOMMES).find(v => k.ORIGINE(v) !== a0.origine);
  assert.equal(k.etatValide(autreOrigine), false, 'visage d’une autre origine que celle gardée : refusé');
});

test('Visage accordé à la culture du nom (monde FR / anglophone / Japon)', () => {
  // Nation d'origine des joueurs par club : France, Nouvelle-Zélande, Japon, Angleterre.
  const avant = globalThis.nativeFacts;
  const NATIONS = ['FRA', 'NZL', 'JPN', 'ENG'];
  globalThis.nativeFacts = { origin: id => NATIONS[Number(/^p(\d+)-/.exec(id)?.[1] || 0) % 4] };
  try {
    const [e1, e2] = [monde(23), monde(23)].map(S => avecS(S, () => { A.factory().observe(); return S.agentsJoueurs; }));
    assert.deepEqual(e1, e2, 'même graine : mêmes visages');
    const k = A.factory(), d = k.DONNEES_VISAGES;
    const parPays = { FR: [], EN: [], JP: [] };
    for (const a of e1.agents) {
      parPays[a.pays].push(a);
      assert.equal(k.ORIGINE(a.portrait), a.origine, 'origine gardée = origine du visage');
      assert.equal(d.visages[a.portrait][1], a.sexe, 'visage du bon sexe');
      assert.ok((d.parCulture[a.pays][a.origine] || 0) > 0, `${a.nom} (${a.pays}) : origine ${a.origine} impossible pour la culture du nom`);
    }
    for (const p of ['FR', 'EN', 'JP']) assert.ok(parPays[p].length >= 10, 'agents ' + p + ' : ' + parPays[p].length);
    // Japon : visages est-asiatiques ; noms anglophones et français : jamais de visage est-asiatique, surtout européens.
    assert.ok(parPays.JP.every(a => a.origine === 'est-asiatique'));
    for (const p of ['FR', 'EN']) {
      const l = parPays[p];
      assert.ok(l.every(a => a.origine !== 'est-asiatique'), p + ' : aucun visage est-asiatique');
      const europe = l.filter(a => a.origine === 'europe-nord' || a.origine === 'mediterraneen').length;
      assert.ok(europe >= l.length * .55 && europe < l.length, `${p} : surtout européens, avec de la diversité (${europe}/${l.length})`);
    }
    assert.ok(parPays.EN.some(a => a.origine === 'polynesien'), 'anglophones : part polynésienne');
    // Pas deux visages identiques dans une agence quand l'origine (ou une autre possible pour la culture) le permet.
    const agences = new Map();
    for (const a of e1.agents) { if (!agences.has(a.agence)) agences.set(a.agence, []); agences.get(a.agence).push(a); }
    for (const [nom, l] of agences) {
      // Visages possibles pour ce sexe et ces cultures : un doublon n'est permis que si l'agence en compte davantage.
      for (const sexe of ['H', 'F']) {
        const qui = l.filter(a => a.sexe === sexe);
        const possibles = new Set(qui.flatMap(a => Object.keys(d.parCulture[a.pays]).flatMap(o => (sexe === 'F' ? k.FEMMES : k.HOMMES).filter(v => k.ORIGINE(v) === o))));
        const differents = new Set(qui.map(a => a.portrait)).size;
        assert.ok(differents === qui.length || differents >= possibles.size, `même visage dans ${nom} (${sexe}) : ${qui.map(a => a.portrait)}`);
      }
    }
    // Aller-retour de sauvegarde : rien ne bouge.
    avecS({ ...monde(23), agentsJoueurs: JSON.parse(JSON.stringify(e1)) }, () => {
      const k2 = A.factory();
      assert.equal(k2.observe(), 0);
      assert.deepEqual(globalThis.S.agentsJoueurs, e1);
    });
  } finally { if (avant === undefined) delete globalThis.nativeFacts; else globalThis.nativeFacts = avant; }
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
    // Répartition réaliste : plusieurs agents par agence, plus grosse agence 100-150 clients, aucun agent au-delà de 30,
    // la plupart des agents à 1-8 clients, aucun agent sans client, quelques indépendants.
    const r = lire('agentsJoueursRepartition()');
    const petits = r.tailles.filter(k => k >= 1 && k <= 8).length, agences = Object.values(r.parAgence).sort((a, b) => b - a);
    assert.ok(r.agents >= 600 && r.agents <= 1600, 'nombre d’agents : ' + r.agents);
    assert.ok(Math.min(...r.tailles) >= 1, 'aucun agent sans client');
    assert.ok(petits >= r.agents * .7, `agents à 1-8 clients : ${petits}/${r.agents}`);
    assert.ok(Math.max(...r.tailles) <= 30, 'agent le plus chargé : ' + Math.max(...r.tailles));
    assert.ok(agences[0] >= 100 && agences[0] <= 150, 'plus grosse agence : ' + agences[0]);
    assert.ok(agences.length < r.agents * .6, 'plusieurs agents par agence : ' + agences.length + ' agences / ' + r.agents);
    const rangs = lire('S.agentsJoueurs.agents.map(a=>a.rang)');
    assert.ok(rangs.filter(x => x === 'independant').length >= 20 && rangs.filter(x => x === 'independant').length < r.agents * .3, 'quelques indépendants');
    // Nouveaux joueurs (jeunes promus, recrues) : affectés dans les mêmes bornes.
    const apres = lire(`(()=>{const c={};for(const p of [...S.clubs.flatMap(c=>c.players),...S.market]){const a=agentJoueurId(p.id,p.age);if(a)c[a]=(c[a]||0)+1;}
      for(let i=0;i<300;i++){const a=agentJoueurId('nouveau-'+i,20);c[a]=(c[a]||0)+1;}return Math.max(...Object.values(c));})()`);
    assert.ok(apres <= 30, 'agent le plus chargé avec 300 nouveaux joueurs : ' + apres);
    // Projection : agents de l'effectif et du marché, nom, agence, clients (sans note), relation en cran.
    const vue = model.clubLife.agentsJoueurs;
    for (const p of [...model.squad, ...model.market].filter(p => p.age >= 18)) assert.ok(vue.agents[vue.joueurs[p.id]], 'agent projeté pour ' + p.id);
    const fiche = vue.agents[vue.joueurs[model.market[0].id]];
    assert.deepEqual(Object.keys(fiche).sort(), ['age', 'agence', 'caractere', 'clients', 'cran', 'id', 'nom', 'pays', 'portrait', 'rang', 'rangMot', 'sexe', 'total']);
    assert.equal(fiche.portrait, lire(`agentJoueur(${JSON.stringify(fiche.id)}).portrait`), 'visage projeté = visage sauvegardé');
    assert.ok(fiche.clients.length >= 1 && fiche.clients.length <= 12 && fiche.total >= fiche.clients.length);
    assert.ok(fiche.clients.every(c => c.length === 7), 'lignes compactes, sans note');
    assert.equal(model.market[0].agent.nom, fiche.nom, 'même agent dans la discussion');

    // Relation partagée : deux pistes du même agent ; le ton donné pour l'une compte pour l'autre.
    // Les agents ont peu de clients : le temps de ces deux pistes, l'annuaire n'a qu'un agent (celui de la première piste).
    const libres = model.market.filter(p => p.available && p.agent?.libre);
    assert.ok(libres.length >= 2, 'deux pistes libres sur le marché');
    const x = libres[0], y = libres[1];
    jeu.bridge.vm.run(`globalThis.__dir=S.agentsJoueurs;S.agentsJoueurs={...S.agentsJoueurs,agents:[S.agentsJoueurs.agents.find(a=>a.id===${JSON.stringify(x.agent.agent)})]};`);
    let res = jeu.brut('agent_ton', { playerId: x.id, ton: 'tout_prix' });
    assert.equal(res.ok, true, res.error);
    const vy = res.model.market.find(p => p.id === y.id).agent;
    assert.equal(vy.cran, 3, 'relation Bonne aussi pour l’autre client');
    assert.equal(res.model.clubLife.agentsJoueurs.agents[x.agent.agent].cran, 3, 'cran de l’agent dans sa fiche');
    res = jeu.brut('agent_question', { playerId: x.id });
    assert.equal(res.ok, true, res.error);
    assert.notEqual(res.model.market.find(p => p.id === y.id).agent.caractere, '', 'caractère découvert pour tous ses clients');
    jeu.bridge.vm.run('S.agentsJoueurs=globalThis.__dir;delete globalThis.__dir;');

    // Migration : ancienne sauvegarde (version 1, relation et caractère par joueur) → par agent.
    // Deux clients du même agent (ligne de sa fiche) portent les anciennes relations.
    const [p1, p2] = lire(`(()=>{const g={};for(const c of S.clubs)for(const p of c.players){const a=agentJoueurId(p.id,p.age);if(a)(g[a]||=[]).push(p.id);}return Object.values(g).find(l=>l.length>=2).slice(0,2);})()`);
    const ag = lire(`agentJoueurId(${JSON.stringify(p1)})`), carAvant = lire(`agentJoueur(${JSON.stringify(ag)}).car`);
    const autre = ['gourmand', 'presse', 'fidele', 'poker', 'arrangeant'].find(c => c !== carAvant);
    jeu.bridge.vm.run(`S.tonAgent={version:1,tons:{},relations:{${JSON.stringify(p1)}:4,${JSON.stringify(p2)}:3},agents:{${JSON.stringify(p2)}:{car:${JSON.stringify(autre)},connu:true}}};delete S.agentsJoueurs;`);
    assert.equal(lire('(validateCareer(S),true)'), true, 'ancienne sauvegarde valide');
    res = jeu.brut('agent_question', { playerId: model.market.find(p => p.agent.agent !== ag).id });
    assert.equal(res.ok, true, res.error);
    const t = lire('S.tonAgent');
    assert.equal(t.version, 2);
    assert.equal(t.relations[ag], 7, 'relations des deux clients additionnées pour l’agent');
    assert.equal(t.connus[ag], true, 'découverte gardée');
    assert.equal(lire(`agentJoueur(${JSON.stringify(ag)}).car`), autre, 'caractère gardé repris par l’agent');
    assert.equal(lire(`tonAgentRelationCran(${JSON.stringify(ag)})`), 4, 'Proche pour ses deux clients');
    // Annuaire de la version précédente de la branche (35 / 20 / 45 %, ids différents) : refait, l'agent d'origine encore
    // présent garde relation, caractère et découverte ; les autres sont oubliés.
    const noms = lire('S.agentsJoueurs.agents.map(a=>a.nom)');
    const nomX = lire(`agentJoueur(${JSON.stringify(ag)}).nom`), autre2 = ['gourmand', 'presse', 'fidele', 'poker', 'arrangeant'].find(c => c !== lire(`agentJoueur(${JSON.stringify(ag)}).car`));
    jeu.bridge.vm.run(`(()=>{const e=S.agentsJoueurs;S.agentsJoueurs={version:1,graine:e.graine,agents:e.agents.map((a,i)=>({...a,id:'ag-'+(5000+i),rang:a.rang==='independant'?'petite':a.rang,car:a.nom===${JSON.stringify(nomX)}?${JSON.stringify(autre2)}:a.car}))};
      const ancien=S.agentsJoueurs.agents.find(a=>a.nom===${JSON.stringify(nomX)}).id;
      S.tonAgent={version:2,tons:{},relations:{[ancien]:5,'ag-9999':3},connus:{[ancien]:true}};})()`);
    assert.equal(lire('(validateCareer(S),true)'), true, 'sauvegarde de la version précédente valide');
    res = jeu.brut('agent_question', { playerId: model.market.find(p => p.agent.agent !== ag).id });
    assert.equal(res.ok, true, res.error);
    assert.equal(lire('S.agentsJoueurs.version'), 2, 'annuaire refait');
    const nouveau = lire(`S.agentsJoueurs.agents.find(a=>a.nom===${JSON.stringify(nomX)})`);
    assert.ok(nouveau && /^ag-[0-9]{1,4}$/.test(nouveau.id) && Number(nouveau.id.slice(3)) < 5000, 'agent d’origine retrouvé');
    assert.equal(nouveau.car, autre2, 'caractère gardé');
    const t2 = lire('S.tonAgent');
    assert.equal(t2.relations[nouveau.id], 5, 'relation gardée');
    assert.equal(t2.connus[nouveau.id], true, 'découverte gardée');
    assert.equal(Object.keys(t2.relations).length, 1, 'agent disparu oublié');
    const r2 = lire('agentsJoueursRepartition()');
    assert.ok(Math.max(...r2.tailles) <= 30 && Math.min(...r2.tailles) >= 1, 'répartition recalée');
    // Sauvegarde : annuaire refait à l'identique (graine), carrière valide après un aller-retour JSON.
    assert.equal(lire('S.agentsJoueurs.agents.length'), r.agents);
    assert.equal(lire('(validateCareer(JSON.parse(JSON.stringify(S))),true)'), true);
    // Visages : posés sur l'annuaire refait, gardés d'une commande à l'autre (même visage partout et après rechargement).
    const visages = lire('S.agentsJoueurs.agents.map(a=>a.portrait)');
    assert.ok(visages.every(v => v >= 1 && v <= 60));
    res = jeu.brut('agent_question', { playerId: model.market.find(p => p.agent.agent !== ag).id });
    assert.deepEqual(lire('S.agentsJoueurs.agents.map(a=>a.portrait)'), visages, 'visages gardés');
  } finally { jeu.fermer(); }
});
