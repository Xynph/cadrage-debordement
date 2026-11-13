'use strict';
// Notes de match (native/engine/match-notes.cjs) : calcul unique et déterministe, sans tirage ;
// note du direct = note enregistrée ; tous les matchs simulés notés ; sauvegarde (migration,
// aller-retour) ; effets bornés. Voir docs/notes-de-match-20261113.md.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const vm = require('node:vm');
const M = require('./helpers/carriere-monde.cjs');
const N = require('../native/engine/match-notes.cjs');
const H = require('../native/engine/match-highlights.cjs');

// Carrière Monde (`world-champ`, seul mode autorisé) : mêmes options que le jeu, voir tests/helpers/carriere-monde.cjs.
function ouvrir(options = {}) {
  const jeu = M.ouvrir(options);
  const etat = () => JSON.parse(jeu.call('export').meta.exportText).state;
  const disque = () => JSON.parse(fs.readFileSync(path.join(jeu.dataDir, 'PrototypeGodot', 'donnees.json'), 'utf8'));
  return { ...jeu, etat, disque };
}

// Domaine des notes dans une VM minimale (deux clubs de 22 joueurs, familles variées) : aucun mode de carrière.
function domaine() {
  const familles = [0, 1, 0, 3, 2, 2, 3, 3, 4, 5, 7, 7, 6, 6, 8];
  const joueurs = c => Array.from({ length: 22 }, (_, k) => ({ id: `c${c}p${k}`, name: `Joueur ${c}-${k}`, fam: familles[k % 15], rating: 60 + ((k * 7 + c * 3) % 25), age: 25 }));
  const ctx = vm.createContext({ S: { club: 0, season: 1, phase: 'league', clubs: [{ id: 0, players: joueurs(0) }, { id: 1, players: joueurs(1) }] }, roleNote: p => p.rating });
  const run = source => vm.runInContext(source, ctx);
  run(`var CDMatchNotesMoteur=(${N.moteur.toString()})();var dom=(${N.factory.toString()})();`);
  return { run };
}

// Journal synthétique : un porteur, un plaqueur, un essai.
// Document d'export re-signé après modification (même empreinte que saves.js).
function signe(document, change) { const doc = structuredClone(document); change(doc.state); const text = JSON.stringify(doc.state); let h = 2166136261; for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619); doc.checksum = (h >>> 0).toString(16).padStart(8, '0'); return JSON.stringify(doc); }
const sc = (kind, team, actor, extra = {}) => ({ min: 1, type: 'play', scene: { kind, team, actor, on: [['a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9', 'a10', 'a11', 'a12', 'a13', 'a14', 'a15'], ['b1', 'b2', 'b3', 'b4', 'b5', 'b6', 'b7', 'b8', 'b9', 'b10', 'b11', 'b12', 'b13', 'b14', 'b15']], from: { x: 40, y: 30 }, to: { x: 48, y: 30 }, score: [0, 0], ...extra } });

test('Calcul : déterministe, sans tirage, base 6,5, bornes 1–10, remplaçant à 6,5', () => {
  const journal = [sc('carry', 0, 'a10'), sc('carry', 0, 'a12', { to: { x: 75, y: 40 } }), sc('turnover', 1, 'b7'), sc('try', 0, 'a14', { score: [5, 0], origin: 'open' }), sc('card', 1, 'b3', { incident: true, card: 'yellow', score: [5, 0] })];
  const cotes = {}, minutes = {};
  for (let k = 1; k <= 15; k++) { cotes['a' + k] = 0; cotes['b' + k] = 1; minutes['a' + k] = 80; minutes['b' + k] = 80; }
  cotes.a16 = 0; minutes.a16 = 0; // remplaçant pas encore entré
  const hasard = Math.random;
  Math.random = () => { throw Error('tirage interdit'); };
  let r1, r2;
  try { r1 = N.noter(journal, { cotes, minutes, score: [5, 0], fini: true }); r2 = N.noter(journal, { cotes, minutes, score: [5, 0], fini: true }); }
  finally { Math.random = hasard; }
  assert.deepEqual(r1, r2, 'même journal, mêmes notes');
  assert.equal(N.NOTE_DEPART, 6.5);
  assert.equal(r1.joueurs.a16.note, 6.5, 'remplaçant : 6,5 à l’entrée');
  for (const n of Object.values(r1.joueurs)) assert.ok(n.note >= 1 && n.note <= 10 && Math.round(n.note * 10) === n.note * 10, 'échelle 1–10 à une décimale');
  assert.ok(r1.joueurs.a14.note > r1.joueurs.a1.note, 'le marqueur passe devant');
  assert.ok(r1.joueurs.b3.note < 6.5, 'carton : note en baisse');
  assert.equal(r1.joueurs.a14.essais, 1);
  // Homme du match : performance relative au poste (sans famille connue : la meilleure note).
  const meilleure = Math.max(...Object.values(r1.joueurs).filter(n => n.minutes >= 30).map(n => n.note));
  assert.equal(r1.joueurs[r1.hommeDuMatch].note, meilleure, 'homme du match : meilleure note à poste inconnu');
  // Avec les postes : un pilier au-dessus de la moyenne des piliers passe devant un troisième
  // ligne à note égale (normalisation par poste).
  const familles = {}; for (let k = 1; k <= 15; k++) { familles['a' + k] = 6; familles['b' + k] = 6; }
  familles.a1 = 0; familles.a14 = 3;
  const tete = N.noter([sc('carry', 0, 'a1', { to: { x: 75, y: 40 } }), sc('carry', 0, 'a14', { to: { x: 75, y: 40 } })], { cotes, minutes, familles, score: [0, 0], fini: true });
  assert.equal(tete.hommeDuMatch, 'a1', 'normalisation par poste');
  // Le direct (match-direct.cjs) appelle le même calcul.
  const D = require('../native/engine/match-direct.cjs');
  const lignes = H.normaliser(journal);
  const direct = D.notesDuMatch(lignes, journal, 0, { cotes, minutes, fini: true });
  assert.equal(direct.a14.note, r1.joueurs.a14.note);
});

test('Matchs simulés (Monde) : mêmes résultats et même tirage avec et sans le journal des notes', () => {
  // Référence : domaine des notes absent (option notes:false) ; effets coupés dans les deux cas
  // (les effets, eux, orientent légitimement les choix des entraîneurs IA).
  const jouer = notes => {
    const jeu = ouvrir({ notes, notesEffets: false, hebdomadaire: true });
    try {
      let model = M.creer(jeu);
      model = M.jouer(jeu, model, 2);
      const etat = jeu.etat();
      const resultats = etat.history.map(r => [r.fixtureId ?? null, r.score, r.pair, r.competitionId ?? null]);
      return { resultats, seed: jeu.disque().seed, notes: etat.matchNotes ?? null };
    } finally { jeu.fermer(); if (global.gc) global.gc(); }
  };
  const sans = jouer(false), avec = jouer(true);
  assert.ok(sans.resultats.length >= 100, 'matchs de toute la journée simulés : ' + sans.resultats.length);
  assert.deepEqual(avec.resultats, sans.resultats, 'scores identiques');
  assert.equal(avec.seed, sans.seed, 'curseur du générateur identique');
  assert.equal(sans.notes, null, 'référence sans domaine des notes (ni club, ni sélections)');
  const notes = Object.values(avec.notes.joueurs);
  assert.ok(notes.length >= 2 * 15 * 7, 'chaque joueur ayant joué a sa note : ' + notes.length);
  assert.ok(notes.every(j => j.s[0] >= 1 && j.f.length >= 1 && j.f.every(x => x >= 10 && x <= 100)));
});

test('Direct (Monde) : la note affichée en fin de match est la note enregistrée ; homme du match ; autres matchs notés', () => {
  const jeu = ouvrir({ hebdomadaire: true });
  try {
    let model = M.jusquAuMatch(jeu, M.creer(jeu));
    model = M.jouerLeMatch(jeu, model, { delegue: false });
    let dernier = null;
    for (let k = 0; k < 400 && !model.live.finished; k++) {
      if (model.clubLife?.matchTalks?.scene) { model = skipMatchTalk(model, jeu.call); continue; }
      model = jeu.call('tick', { minute: true, temps_forts: 'dynamique' });
      if (model.live.direct?.notes) dernier = model.live.direct;
    }
    assert.equal(model.live.finished, true, 'match terminé');
    // Tout montrer : le direct se lit alors sur le journal complet.
    for (let k = 0; k < 40 && dernier.borne < model.live.events.length; k++) { model = jeu.call('tick', { minute: true, temps_forts: 'aucun' }); dernier = model.live.direct; }
    const directNotes = dernier.notes, camp = dernier.camp;
    for (const n of Object.values(directNotes)) assert.ok(n.note >= 1 && n.note <= 10);
    // Le débrief clôt la journée (le résultat est confirmé).
    model = skipMatchTalk(model, jeu.call);
    if (model.live) model = jeu.call('finish_round');
    model = jeu.regler(model);
    const notes = model.clubLife.matchNotes;
    assert.ok(notes.dernier, 'dernier match enregistré');
    assert.ok(notes.dernier.hommeDuMatch && notes.dernier.hommeDuMatch.nom, 'homme du match désigné');
    const enregistre = Object.fromEntries(notes.dernier.notes.filter(n => n.cote === camp).map(n => [n.id, n.note]));
    assert.ok(Object.keys(directNotes).length >= 15, 'notes du direct pour toute l’équipe');
    for (const [id, n] of Object.entries(directNotes)) if (n.minutes > 0) assert.equal(n.note, enregistre[id], 'note du direct = note enregistrée (' + id + ')');
    const club = model.squad.filter(p => notes.joueurs[p.id]?.matchs === 1);
    assert.ok(club.length >= 15, 'joueurs du club notés : ' + club.length);
    const h = notes.joueurs[club[0].id].historique[0];
    assert.ok(h.adversaire && h.competition && h.minutes > 0 && h.note >= 1, 'historique du match');
    // Autres matchs de la journée (simulés sans direct) : notés aussi.
    const etat = jeu.etat();
    const clubs = new Set(etat.clubs.flatMap(c => c.players.filter(p => etat.matchNotes.joueurs[p.id]).map(() => c.id)));
    assert.ok(clubs.size > 2, 'joueurs d’autres clubs notés : ' + clubs.size + ' clubs');
    assert.ok(model.news?.some?.(t => /Homme du match/.test(t)) || etat.news.some(t => /Homme du match/.test(t)), 'actualité de l’homme du match');
  } finally { jeu.fermer(); }
});

test('Sauvegarde (Monde) : aller-retour, migration d’une ancienne sauvegarde sans notes, validation', () => {
  const jeu = ouvrir({ hebdomadaire: true });
  try {
    let model = M.jouer(jeu, M.creer(jeu), 1);
    const texte = jeu.call('export').meta.exportText;
    const doc = JSON.parse(texte);
    assert.equal(doc.state.matchNotes.version, 1);
    jeu.call('import', { text: texte });
    assert.deepEqual(jeu.etat().matchNotes, doc.state.matchNotes, 'aller-retour exact');
    // Ancienne sauvegarde : pas de notes, historique vide puis rempli au match suivant.
    const sansNotes = jeu.call('import', { text: signe(doc, state => { delete state.matchNotes; }) });
    assert.deepEqual(sansNotes.clubLife.matchNotes.joueurs, {}, 'ancienne sauvegarde : historique vide');
    assert.equal(jeu.etat().matchNotes, undefined, 'rien n’est inventé pour le passé');
    // Monde : plus de 2 000 joueurs notés (limite générique des tables de la sauvegarde) acceptés
    // jusqu'au nombre de joueurs du monde, refusés au-delà.
    const plus = (n, base) => signe(doc, state => { for (let k = 0; k < n; k++) state.matchNotes.joueurs['x' + base + k] = { s: [1, 65, 80, 0, 0, 0, 0], f: [65] }; });
    assert.equal(jeu.brut('import', { text: plus(2100, 'a') }).ok, true, 'plus de 2 000 joueurs notés : accepté');
    const trop = jeu.brut('import', { text: plus(40000, 'b') });
    assert.equal(trop.ok, false, 'table démesurée refusée');
    // Un état corrompu est refusé.
    const id = Object.keys(doc.state.matchNotes.joueurs)[0];
    const casse = jeu.brut('import', { text: signe(doc, state => { state.matchNotes.joueurs[id].f = [999]; }) });
    assert.equal(casse.ok, false, 'note hors échelle refusée');
    assert.match(casse.error, /Notes de match/);
  } finally { jeu.fermer(); }
});

test('Effets bornés : composition, valeur, intérêt, salaire, sélection, moral', () => {
  const c = domaine();
  const extremes = JSON.parse(c.run(`(()=>{S.matchNotes={version:1,saison:S.season,joueurs:{haut:{s:[20,2000,1600,9,99,999,9],f:[100,100,100,100,100]},bas:{s:[20,200,1600,0,0,0,0],f:[10,10,10,10,10]},neutre:{s:[20,1300,1600,0,0,0,0],f:[65,65,65,65,65]}},detail:{},passees:{},confiance:{},semaine:null,recompenses:[],dernier:null};
    const e=dom.effets,r={};for(const id of ['haut','bas','neutre','inconnu'])r[id]={composition:e.composition(id),valeur:e.valeur(id),interet:e.interet(id),salaire:e.salaire(id),selection:e.selection(id)};dom.validate(S);return JSON.stringify(r)})()`));
  assert.deepEqual(extremes.neutre, { composition: 1, valeur: 1, interet: 0, salaire: 1, selection: 0 }, '6,5 de moyenne : aucun effet');
  assert.deepEqual(extremes.inconnu, { composition: 1, valeur: 1, interet: 0, salaire: 1, selection: 0 }, 'sans note : aucun effet');
  assert.deepEqual(extremes.haut, { composition: 1.04, valeur: 1.12, interet: 3, salaire: 1.06, selection: 2 }, 'plafonds');
  assert.deepEqual(extremes.bas, { composition: 0.97, valeur: 0.92, interet: -2, salaire: 0.96, selection: -1.5 }, 'planchers');
});

test('Matchs internationaux : même calcul, sans tirage, enregistrés à part, sans doublon, effets bornés', () => {
  const c = domaine();
  const r = JSON.parse(c.run(`(()=>{const ids=k=>S.clubs[k].players.slice(0,20).map(p=>p.id);
    const m=[{cle:'six-nations-2027-r1-1',date:'2027-02-05',competition:'Tournoi des Six Nations 2027',equipes:[{nation:'FRA',nom:'France',ids:ids(0),points:27,essais:3},{nation:'ENG',nom:'Angleterre',ids:ids(1),points:13,essais:1}]}];
    const avant=Math.random;let tirages=0;Math.random=()=>{tirages++;return avant()};
    const n1=dom.enregistrerSelection(m),n2=dom.enregistrerSelection(m);Math.random=avant;
    for(let k=2;k<=4;k++)dom.enregistrerSelection([{...m[0],cle:'test-'+k,date:'2027-0'+(k+2)+'-01'}]);
    dom.validate(S);const id=ids(0)[0],p=dom.project();
    return JSON.stringify({n1,n2,tirages,lignes:S.matchNotes.selection.lignes[id].length,essais:Object.values(S.matchNotes.selection.lignes).reduce((a,d)=>a+d[0][5],0),hdm:Object.values(S.matchNotes.selection.lignes).reduce((a,d)=>a+d[0][6],0),selection:dom.effets.selection(id),valeur:dom.effets.valeur(id),vus:Object.keys(S.matchNotes.selection.vus).length,proj:p.joueurs[id]?.selection?.matchs??null})})()`));
  assert.equal(r.n1, 1); assert.equal(r.n2, 0, 'une rencontre déjà notée est ignorée');
  assert.equal(r.tirages, 0, 'aucun tirage');
  assert.equal(r.lignes, 4, 'historique « Sélection » du joueur');
  assert.equal(r.essais, 4, 'essais attribués = essais du score (3 + 1)');
  assert.equal(r.hdm, 1, 'un homme du match');
  assert.ok(r.selection >= -1.5 && r.selection <= 2 && r.valeur >= 0.92 && r.valeur <= 1.12, 'effets dans les bornes');
  assert.equal(r.vus, 4);
  // Le décalage de poste (étalonné sur un journal complet) ne s'applique pas à ce journal réduit aux essais :
  // à niveau égal et sans essai, un troisième ligne, un talonneur et un ailier reçoivent la même note.
  const nul = domaine();
  const egal = JSON.parse(nul.run(`(()=>{S.clubs.forEach(c=>c.players.forEach(p=>{p.rating=70}));const ids=k=>S.clubs[k].players.slice(0,20).map(p=>p.id);
    dom.enregistrerSelection([{cle:'nul',date:'2027-02-05',competition:'Test-match',equipes:[{nation:'FRA',nom:'France',ids:ids(0),points:10,essais:0},{nation:'ENG',nom:'Angleterre',ids:ids(1),points:10,essais:0}]}]);
    const L=S.matchNotes.selection.lignes;return JSON.stringify(Object.fromEntries(Object.entries(L).map(([id,d])=>[id,d[0][4]])))})()`));
  assert.ok(Object.keys(egal).length >= 30 && Object.values(egal).every(note => note === 65), 'avants non sous-notés : ' + JSON.stringify([...new Set(Object.values(egal))]));
  // Homme du match aussi pour les matchs internationaux : le marqueur d'un seul essai l'emporte à niveau égal.
  const essai = JSON.parse(nul.run(`(()=>{const ids=k=>S.clubs[k].players.slice(0,20).map(p=>p.id);
    dom.enregistrerSelection([{cle:'un-essai',date:'2027-02-12',competition:'Test-match',equipes:[{nation:'FRA',nom:'France',ids:ids(0),points:7,essais:1},{nation:'ENG',nom:'Angleterre',ids:ids(1),points:0,essais:0}]}]);
    const L=S.matchNotes.selection.lignes,hdm=Object.entries(L).filter(([,d])=>d.at(-1)[0]==='2027-02-12'&&d.at(-1)[6]).map(([id,d])=>[id,d.at(-1)[4],d.at(-1)[5]]);return JSON.stringify(hdm)})()`));
  assert.equal(essai.length, 1, 'un homme du match');
  assert.equal(essai[0][2], 1, 'le marqueur de l’essai');
  // Déterminisme : même entrée, mêmes notes dans une autre carrière identique.
  const d = domaine();
  const une = k => JSON.parse(k.run(`(()=>{const ids=k=>S.clubs[k].players.slice(0,20).map(p=>p.id);dom.enregistrerSelection([{cle:'x',date:'2027-02-05',competition:'Test-match',equipes:[{nation:'FRA',nom:'France',ids:ids(0),points:20,essais:2},{nation:'ENG',nom:'Angleterre',ids:ids(1),points:20,essais:2}]}]);return JSON.stringify(S.matchNotes.selection.lignes)})()`));
  const e = domaine();
  assert.deepEqual(une(d), une(e));
  // Sauvegarde sans bloc Sélection : valide.
  c.run('delete S.matchNotes.selection;dom.validate(S)');
});

test('Carrière internationale : le match joué par la sélection est noté et rangé dans « Sélection »', () => {
  const vm = require('node:vm');
  const createNativeInternational = require('../native/engine/international-native.cjs');
  const joueur = { id: 'lnr:hook', name: 'Joueur de référence', pos: 'Talonneur', fam: 1, age: 29, rating: 85, condition: 100, injury: 0,
    primaryPosition: 2, primaryPositions: [2], secondaryPositions: [], positionRatings: { 2: 85 }, qualifiedFrontRowPositions: [2] };
  const facts = { nations: { FRA: ['France', 'fr'] }, players: { [joueur.id]: { seniorNation: 'FRA', seniorCaps: 5 } } };
  let date = '2027-01-30';
  const ctx = vm.createContext({
    S: { club: 0, season: 1, clubs: [{ id: 0, players: [joueur] }], phase: 'league', worldMode: { day: 0 } },
    CDWorldCareer: { active: () => true, calendarToday: () => date, nextOpening: () => '2027-08-16' },
    roleNote: p => p.rating,
    nativePositionAptitudes: { project: p => Object.fromEntries(['primaryPosition', 'primaryPositions', 'secondaryPositions', 'positionRatings', 'qualifiedFrontRowPositions'].map(k => [k, p[k]])) },
  });
  const run = source => vm.runInContext(source, ctx);
  run(`var CDMatchNotesMoteur=(${N.moteur.toString()})();var CDMatchNotes=(${N.factory.toString()})();`);
  const international = createNativeInternational(run, ctx, facts, true);
  international.initialize(42, { nationalRole: 'dual', nation: 'FRA' });
  const avance = () => { international.advance(international.read().career.date); date = new Date(Date.parse(date) + 86400000).toISOString().slice(0, 10); };
  while (international.read().career.date < '2027-02-06') avance();
  const modele = { club: { id: 0 }, meta: { calendarToday: date, canAdvanceSeason: false } };
  international.project(modele);
  const match = modele.international.currentManagedFixture;
  const resultat = () => JSON.stringify(Object.values(international.read().career.results).map(an => an[match.id]).find(Boolean));
  international.command('national_play_match', { fromDate: match.date, fixtureId: match.id });
  const lignes = JSON.parse(run('JSON.stringify(S.matchNotes.selection.lignes["lnr:hook"]||[])'));
  assert.equal(lignes.length, 1, 'le joueur du club a sa note de sélection');
  assert.equal(lignes[0][0], '2027-02-06');
  assert.ok(lignes[0][4] >= 10 && lignes[0][4] <= 100);
  assert.match(lignes[0][2], /Six Nations/);
  // Notes enregistrées sans toucher au résultat ni à la carrière internationale.
  const apres = resultat();
  run('CDMatchNotes.validate(S)');
  avance();
  assert.equal(JSON.parse(run('JSON.stringify(S.matchNotes.selection.lignes["lnr:hook"])')).length, 1, 'pas de doublon au jour suivant');
  assert.equal(resultat(), apres, 'résultat du match international inchangé');
});
