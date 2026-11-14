'use strict';
// Retouches de cohérence (carrière Monde, mode unique), côté moteur :
//  1. fiche club : « remplaçants les plus utilisés » ne reprend jamais un joueur du XV type affiché à côté ;
//  2. fiche club : « Vos confrontations » sans match passé reçoit le prochain match entre les deux clubs
//     (date, lieu, compétition), absent quand les clubs ne se rencontrent pas ;
//  4. délégation : une feuille à 22 (pilier de remplacement manquant) peut être déléguée, le match est joué à 22 ;
//  5. finances : le centre de formation (coût réel du budget de saison) est publié à part, dans les charges.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

test('Fiche club : le banc le plus utilisé exclut le XV type, le prochain match entre les deux clubs est publié', () => {
  const jeu = M.ouvrir({ hebdomadaire: true, testVm: true });
  try {
    let model = M.creer(jeu, 0);
    const own = model.leagues.find(l => l.rows.some(r => r.id === 0));
    const adverse = own.rows.map(r => r.id).find(id => id !== 0);
    const autreLigue = model.leagues.find(l => l !== own && l.rows.length && !l.rows.some(r => r.id === 0));
    // Avant tout match : aucune confrontation, mais un prochain match au calendrier.
    const avant = jeu.brut('club_sheet', { club: adverse }).model.clubSheet;
    assert.equal(avant.headToHead.played, 0);
    const prochain = avant.headToHead.upcoming;
    assert.ok(prochain, 'prochain match entre les deux clubs publié');
    assert.match(prochain.date, /^\d{4}-\d{2}-\d{2}/);
    assert.equal(typeof prochain.home, 'boolean');
    assert.ok(prochain.competitionId, 'compétition connue');
    if (prochain.home) assert.equal(prochain.stadium, jeu.brut('club_sheet', { club: 0 }).model.clubSheet.stadium, 'lieu : stade du club qui reçoit');
    // Tous les clubs de la ligue : la rencontre à venir est la plus proche des non jouées.
    const calendrier = jeu.bridge.vm.run(`JSON.stringify((S.worldMode.fixtures||[]).filter(f=>(f.homeId===0&&f.awayId===${adverse})||(f.homeId===${adverse}&&f.awayId===0)).map(f=>[f.id,f.date]).sort((a,b)=>String(a[1]).localeCompare(String(b[1]))))`);
    assert.equal(JSON.parse(calendrier)[0][0], prochain.fixtureId, 'la plus proche des rencontres non jouées');
    if (autreLigue) {
      const loin = autreLigue.rows[0].id;
      const h = jeu.brut('club_sheet', { club: loin }).model.clubSheet.headToHead;
      assert.ok(h.upcoming === null || typeof h.upcoming.fixtureId === 'string' || typeof h.upcoming.fixtureId === 'number', 'prochain match absent ou valide pour un autre championnat');
    }
    assert.equal(jeu.brut('club_sheet', { club: 0 }).model.clubSheet.headToHead.upcoming, null, 'votre propre fiche : pas de confrontation avec soi-même');
    // Quelques journées : le banc ne contient aucun titulaire du XV type.
    model = M.jouer(jeu, model, 4);
    let bancs = 0, titulairesAvecEntrees = 0;
    for (const id of own.rows.map(r => r.id)) {
      const fiche = jeu.brut('club_sheet', { club: id }).model.clubSheet;
      const xv = new Set(fiche.xv.slots.map(s => s.id).filter(Boolean));
      for (const e of [...fiche.xv.bench, ...fiche.xv.probableBench.map(x => ({ id: x }))]) assert.equal(xv.has(e.id), false, 'club ' + id + ' : ' + e.id + ' est dans le XV type et dans les remplaçants');
      bancs += fiche.xv.bench.length;
      titulairesAvecEntrees += fiche.squad.filter(p => xv.has(p.id) && p.benchEntries > 0).length;
    }
    assert.ok(bancs > 0, 'des bancs sont publiés');
    console.log(`banc sans titulaire du XV : ${bancs} remplaçants, dont ${titulairesAvecEntrees} titulaires du XV ayant aussi des entrées en jeu, écartés`);
    const apres = jeu.brut('club_sheet', { club: adverse }).model.clubSheet.headToHead;
    assert.ok(apres.played >= 1 ? apres.last.length >= 1 : true);
  } finally { jeu.fermer(); }
});

test('Finances : le centre de formation est publié à part dans les charges hebdomadaires du budget de saison', () => {
  const jeu = M.ouvrir({ hebdomadaire: true });
  try {
    const model = M.creer(jeu, 7);
    const f = model.clubLife.clubStrategy.finance;
    assert.ok(f.budget, 'budget de saison actif');
    assert.equal(f.academyInvestment, 0, 'aucune formation payée en plus au départ : l’ancienne ligne valait 0 %');
    assert.ok(f.budget.centreFormationHebdo > 1000, 'centre de formation : coût hebdomadaire réel ' + f.budget.centreFormationHebdo);
    assert.ok(f.budget.centreFormationHebdo < f.budget.fonctionnementHebdo, 'compris dans le fonctionnement, pas en plus');
    assert.ok(f.weeklyCosts >= f.weeklyWages + f.budget.fonctionnementHebdo, 'le centre est dans le total des charges, pas en plus');
    const part = f.budget.centreFormationHebdo / f.weeklyCosts;
    assert.ok(part > 0.03 && part < 0.15, 'part de la charge cohérente avec PART_FORMATION : ' + (100 * part).toFixed(1) + ' %');
    console.log(`centre de formation : ${f.budget.centreFormationHebdo} €/sem. sur ${f.weeklyCosts} € de charges (${(100 * part).toFixed(1)} %)`);
  } finally { jeu.fermer(); }
});

test('Délégation : feuille à 22 (pilier de remplacement manquant), match délégué joué à 22 après confirmation', () => {
  const jeu = M.ouvrir({ testVm: true });
  try {
    let model = M.jusquAuMatch(jeu, M.creer(jeu, 90));
    jeu.bridge.vm.run(`(()=>{const c=S.clubs[S.club],starter=S.lineup[0];for(const p of c.players)if(p.id!==starter&&(p.pos==='Pilier gauche'||p.nationaleQualifications?.includes('Pilier gauche')))p.injury=3;S.reserves[1]=null;S.trained=true;})()`);
    model = jeu.call('snapshot');
    assert.equal(model.selection.valid, false);
    assert.deepEqual(model.selection.reducedBench, { size: 22, vacantNumber: 17 });
    // La fenêtre de délégation confirme le match à 22 : begin_match { delegated, composition, reducedBench }.
    model = jeu.call('begin_match', { delegated: true, composition: true, reducedBench: true });
    assert.equal(model.live.nominationSize, 22, 'match lancé à 22');
    model = skipMatchTalk(jeu.call('delegate'), jeu.call);
    assert.ok(model.live === null || model.live.finished, 'match délégué joué jusqu’au bout');
  } finally { jeu.fermer(); }
});
