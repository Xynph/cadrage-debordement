'use strict';
// Feuille incomplète : appel d'un Espoir du centre de formation (décision de Léo, 14/11/2026), carrière Monde.
//  - le staff (sélection automatique, composition confiée) complète la feuille avec le meilleur jeune du centre apte au
//    poste (18 ans au moins, non blessé), prêté pour le match seulement (marqueur espoirLoan, rendu au centre ensuite) ;
//  - règle JIFF : à note proche, un jeune JIFF passe devant quand la feuille est sous l'exigence ;
//  - sans jeune apte : la feuille reste à 22 (Nationale), aucun appel ; « Jouer à 22 » n'appelle personne ;
//  - le jeune appelé joue, reçoit une note de match et de l'expérience, puis retourne au centre.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

// Plus aucun pilier gauche valide (hors titulaire) : le 17 est introuvable parmi les pros.
const PILIER_GAUCHE_MANQUANT = `(()=>{const c=S.clubs[S.club],starter=S.lineup[0];for(const p of c.players)if(p.id!==starter&&(p.pos==='Pilier gauche'||p.nationaleQualifications?.includes('Pilier gauche')))p.injury=3;S.reserves[1]=null;S.trained=true;})()`;
// Le titulaire n°1 lui-même est blessé : le jeune doit jouer d'entrée.
const TOUS_PILIERS_GAUCHES_BLESSES = `(()=>{const c=S.clubs[S.club];for(const p of c.players)if(p.pos==='Pilier gauche'||p.nationaleQualifications?.includes('Pilier gauche'))p.injury=3;S.trained=true;})()`;
const run = (jeu, code) => JSON.parse(jeu.bridge.vm.run(`JSON.stringify(${code})`));

test('Nationale : sélection du staff complète la feuille avec le meilleur jeune apte, qui retourne au centre après la journée', () => {
  const jeu = M.ouvrir({ testVm: true });
  try {
    let model = M.jusquAuMatch(jeu, M.creer(jeu, 90));
    jeu.bridge.vm.run(PILIER_GAUCHE_MANQUANT);
    model = jeu.call('snapshot');
    assert.equal(model.selection.valid, false);
    assert.deepEqual(model.selection.reducedBench, { size: 22, vacantNumber: 17 }, 'le match à 22 reste proposé');
    const offre = model.selection.espoirs;
    assert.ok(offre && offre.available, 'un jeune est proposé');
    assert.equal(offre.slots.length, 1);
    const place = offre.slots[0];
    assert.equal(place.slot, 16);
    assert.equal(place.candidates[0].id, place.proposedId, 'le premier candidat est le choix par défaut');
    assert.ok(place.candidates[0].age >= 18, 'âge minimal respecté');
    assert.equal(place.candidates[0].pos, 'Pilier gauche');
    assert.ok(place.candidates.every((c, i, l) => i === 0 || l[i - 1].note >= c.note || l[i - 1].jiff !== c.jiff), 'classés par note au poste');
    const avant = run(jeu, 'S.development.academy.length');

    model = jeu.call('auto_lineup');
    assert.equal(model.selection.valid, true, 'feuille complétée par le staff');
    assert.equal(model.selection.slots[16].playerId, place.proposedId);
    const appele = model.squad.find(p => p.id === place.proposedId);
    assert.equal(appele.calledUp, true);
    assert.equal(appele.contractLabel, 'Appelé du centre de formation');
    assert.equal(run(jeu, 'S.development.academy.length'), avant - 1, 'il quitte la liste du centre pour la journée');
    assert.equal(model.selection.reducedBench, undefined, 'plus de feuille à 22 à proposer');
    // Jamais de promotion : même effectif pro (hors prêt), pas de salaire pro, statut espoirLoan seulement.
    assert.equal(run(jeu, `S.clubs[S.club].players.filter(p=>p.espoirLoan).length`), 1);

    // Match délégué : le jeune est sur la feuille, la journée close le rend au centre.
    model = jeu.regler(model);
    model = skipMatchTalk(jeu.call('begin_match', { delegated: true, composition: true }), jeu.call);
    assert.equal(model.live.nominationSize, undefined, 'match à 23');
    model = skipMatchTalk(jeu.call('delegate'), jeu.call);
    assert.equal(run(jeu, `S.clubs[S.club].players.filter(p=>p.espoirLoan).length`), 1, 'toujours prêté tant que la journée n’est pas close');
    if (model.live) model = skipMatchTalk(jeu.call('finish_round'), jeu.call);
    model = M.jusquALaSemaineSuivante(jeu, jeu.regler(model));
    assert.equal(run(jeu, `S.clubs[S.club].players.filter(p=>p.espoirLoan).length`), 0, 'plus aucun jeune prêté');
    assert.equal(run(jeu, 'S.development.academy.length') >= avant - 1, true);
    assert.equal(run(jeu, `S.development.academy.some(p=>p.id===${JSON.stringify(place.proposedId)}&&p.academy===true&&p.espoirLoan===undefined)`), true, 'de retour au centre, statut d’origine');
    assert.equal(run(jeu, `S.clubs[S.club].players.some(p=>p.id===${JSON.stringify(place.proposedId)})`), false, 'pas promu pro');
  } finally { jeu.fermer(); }
});

test('Le titulaire manquant est remplacé par le jeune : il joue, reçoit une note de match et de l’expérience', () => {
  const jeu = M.ouvrir({ testVm: true });
  try {
    let model = M.jusquAuMatch(jeu, M.creer(jeu, 90));
    jeu.bridge.vm.run(TOUS_PILIERS_GAUCHES_BLESSES);
    model = jeu.call('auto_lineup');
    assert.equal(model.selection.valid, true);
    const titulaire = model.selection.slots[0].playerId, jeune = model.squad.find(p => p.id === titulaire);
    assert.equal(jeune.calledUp, true, 'le n°1 est le jeune du centre');
    const xp = run(jeu, `S.clubs[S.club].players.find(p=>p.id===${JSON.stringify(titulaire)}).dev.appearances`);
    model = jeu.regler(model);
    model = skipMatchTalk(jeu.call('begin_match', { delegated: true, composition: false }), jeu.call);
    model = skipMatchTalk(jeu.call('delegate'), jeu.call);
    // La journée close : notes enregistrées (comme pour les autres joueurs), expérience, retour au centre.
    if (model.live) model = skipMatchTalk(jeu.call('finish_round'), jeu.call);
    model = M.jusquALaSemaineSuivante(jeu, jeu.regler(model));
    const note = run(jeu, `(()=>{const id=${JSON.stringify(titulaire)},n=S.matchNotes;return {matchs:n?.joueurs?.[id]?.s?.[0]??0,minutes:n?.joueurs?.[id]?.s?.[2]??0,detail:(n?.detail?.[id]||[]).length};})()`);
    assert.ok(note.matchs >= 1 && note.minutes >= 40, 'une note de match est enregistrée pour le jeune : ' + JSON.stringify(note));
    assert.ok(note.detail >= 1, 'détail de la note dans le journal du club');
    assert.equal(run(jeu, `S.development.academy.find(p=>p.id===${JSON.stringify(titulaire)}).dev.appearances`), xp + 1, 'une apparition de plus au compteur du jeune');
    assert.equal(run(jeu, `S.development.academy.find(p=>p.id===${JSON.stringify(titulaire)}).dev.minutes`) >= 40, true, 'minutes de jeu créditées');
    assert.equal(run(jeu, `S.development.academy.some(p=>p.id===${JSON.stringify(titulaire)}&&p.espoirLoan===undefined&&p.academy===true)`), true, 'rendu au centre');
    assert.equal(run(jeu, `S.lineup.includes(${JSON.stringify(titulaire)})||S.reserves.includes(${JSON.stringify(titulaire)})`), false, 'plus sur la feuille');
  } finally { jeu.fermer(); }
});

test('« Jouer à 22 » n’appelle aucun jeune ; sans jeune apte, la feuille reste à 22 ; choix manuel du jeune', () => {
  const jeu = M.ouvrir({ testVm: true });
  try {
    let model = M.jusquAuMatch(jeu, M.creer(jeu, 90));
    jeu.bridge.vm.run(PILIER_GAUCHE_MANQUANT);
    // Le joueur choisit le jeune (ici le 2e candidat s'il existe) pour la place 17.
    model = jeu.call('snapshot');
    const candidats = model.selection.espoirs.slots[0].candidates;
    const choix = candidats[candidats.length - 1];
    model = jeu.call('espoir_appeler', { assignments: [{ slot: 16, playerId: choix.id }] });
    assert.equal(model.selection.valid, true);
    assert.equal(model.selection.slots[16].playerId, choix.id, 'choix manuel respecté');
    // Il libère la place : le jeune retourne au centre aussitôt.
    model = jeu.regler(model);
    model = jeu.call('set_lineup', { playerId: null, slot: 16 });
    assert.equal(run(jeu, `S.development.academy.some(p=>p.id===${JSON.stringify(choix.id)}&&p.espoirLoan===undefined)`), true, 'jeune rendu au centre');
    assert.equal(run(jeu, `S.clubs[S.club].players.some(p=>p.espoirLoan)`), false);
    // Jouer à 22 : aucun appel, même avec la composition confiée au staff.
    jeu.bridge.vm.run(PILIER_GAUCHE_MANQUANT);
    model = jeu.call('snapshot');
    assert.deepEqual(model.selection.reducedBench, { size: 22, vacantNumber: 17 });
    assert.ok(model.selection.espoirs?.available, 'le jeune reste proposé tant qu’on n’a pas choisi');
    model = jeu.regler(model);
    model = jeu.call('begin_match', { delegated: true, composition: true, reducedBench: true });
    assert.equal(model.live.nominationSize, 22, 'match à 22 respecté malgré un jeune disponible');
    assert.equal(run(jeu, `S.clubs[S.club].players.filter(p=>p.espoirLoan).length`), 0, 'personne n’a été appelé');
    skipMatchTalk(jeu.call('delegate'), jeu.call);
  } finally { jeu.fermer(); }
  // Aucun jeune apte : plus d'offre, la feuille reste à 22.
  const vide = M.ouvrir({ testVm: true });
  try {
    let model = M.jusquAuMatch(vide, M.creer(vide, 90));
    vide.bridge.vm.run(PILIER_GAUCHE_MANQUANT);
    vide.bridge.vm.run(`for(const p of S.development.academy)if(p.pos==='Pilier gauche'||p.pos==='Talonneur'||p.pos==='Pilier droit')p.age=16;`);
    model = vide.call('snapshot');
    assert.equal(model.selection.espoirs, undefined, 'aucun jeune de 18 ans ou plus apte');
    model = vide.call('auto_lineup');
    assert.equal(model.selection.valid, false);
    assert.deepEqual(model.selection.reducedBench, { size: 22, vacantNumber: 17 }, 'match à 22 conservé');
    assert.equal(run(vide, `S.clubs[S.club].players.filter(p=>p.espoirLoan).length`), 0);
  } finally { vide.fermer(); }
});

test('Règle JIFF : un jeune JIFF passe devant un jeune non JIFF de note proche quand la feuille est sous l’exigence', () => {
  const jeu = M.ouvrir({ testVm: true });
  try {
    // Top 14 : club 0 ; la règle JIFF concerne la feuille du club.
    let model = M.jusquAuMatch(jeu, M.creer(jeu, 0));
    jeu.bridge.vm.run(`if(S.jiff?.version!==1)CDJiff.initialize(S);`);
    const actif = run(jeu, `[S.jiff?.version, S.club, Object.keys(CDJiff.subjectLeagues(S)), Object.values(CDJiff.subjectLeagues(S)).some(l=>l.includes(S.club))]`);
    assert.equal(actif[3], true, 'JIFF actif pour ce club : ' + JSON.stringify(actif));
    jeu.bridge.vm.run(TOUS_PILIERS_GAUCHES_BLESSES);
    // Tous les pros non JIFF : l'exigence (16 par feuille) n'est pas atteinte. Parmi les jeunes aptes au poste n° 1, le
    // meilleur est non JIFF, le deuxième JIFF : le jeune JIFF doit être proposé en premier.
    const duo = run(jeu, `(()=>{for(const p of S.clubs[S.club].players)CDJiff.setStatus(S,p.id,[0,0,0]);
      const l=S.development.academy.filter(p=>p.pos==='Pilier gauche'&&p.age>=18&&!p.injury).sort((a,b)=>nativePositionAptitudes.rating(b,0)-nativePositionAptitudes.rating(a,0)||(a.id<b.id?-1:1));
      l.forEach((p,i)=>CDJiff.setStatus(S,p.id,[i===1?1:0,i===1?3:2,0]));return [l[0].id,l[1].id,nativePositionAptitudes.rating(l[0],0),nativePositionAptitudes.rating(l[1],0)];})()`);
    model = jeu.call('snapshot');
    const place = model.selection.espoirs.slots[0];
    assert.equal(place.slot, 0, 'le n° 1 est à pourvoir');
    assert.equal(place.proposedId, duo[1], 'le jeune JIFF est proposé en premier (' + duo[2] + ' contre ' + duo[3] + ') : ' + JSON.stringify(place.candidates.map(c => [c.id, c.note, c.jiff])));
    assert.equal(place.candidates[0].jiff, true);
    model = jeu.call('auto_lineup');
    assert.equal(model.selection.valid, true);
    assert.equal(model.selection.slots[0].playerId, duo[1], 'le jeune JIFF est sur la feuille du staff');
  } finally { jeu.fermer(); }
});
