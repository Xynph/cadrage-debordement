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
function domaine(effets) {
  const familles = [0, 1, 0, 3, 2, 2, 3, 3, 4, 5, 7, 7, 6, 6, 8];
  const joueurs = c => Array.from({ length: 22 }, (_, k) => ({ id: `c${c}p${k}`, name: `Joueur ${c}-${k}`, fam: familles[k % 15], rating: 60 + ((k * 7 + c * 3) % 25), age: 25 }));
  const ctx = vm.createContext({ S: { club: 0, season: 1, phase: 'league', clubs: [{ id: 0, players: joueurs(0) }, { id: 1, players: joueurs(1) }] }, roleNote: p => p.rating });
  const run = source => vm.runInContext(source, ctx);
  if (effets !== undefined) run(`var CDNotesEffets=${effets};`);
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

test('Poste occupé (maillots 1 à 15) : pondération de la note, homme du match = meilleure note', () => {
  const cotes = {}, minutes = {}, postes = {}, familles = {};
  for (let k = 1; k <= 15; k++) { cotes['a' + k] = 0; cotes['b' + k] = 1; minutes['a' + k] = 80; minutes['b' + k] = 80; postes['a' + k] = k - 1; postes['b' + k] = k - 1; familles['a' + k] = 6; familles['b' + k] = 6; }
  const journal = [sc('carry', 0, 'a1', { to: { x: 70, y: 40 } }), sc('carry', 0, 'a7', { to: { x: 70, y: 40 } }), sc('carry', 0, 'a10', { to: { x: 70, y: 40 } }), sc('turnover', 1, 'b6'), sc('kick', 1, 'b10', { to: { x: 10, y: 30 } })];
  const r = N.noter(journal, { cotes, minutes, postes, familles, score: [0, 0], fini: true });
  // Même course : le pilier (peu de faits attendus) passe devant le troisième ligne (beaucoup).
  assert.ok(r.joueurs.a1.note > r.joueurs.a7.note, 'attendu du poste retiré');
  // Le poste occupé prime sur le poste naturel (familles toutes « ailier » ici).
  const sansPoste = N.noter(journal, { cotes, minutes, familles, score: [0, 0], fini: true });
  assert.notEqual(sansPoste.joueurs.a1.note, r.joueurs.a1.note, 'le maillot porté compte, pas seulement la famille');
  for (const x of [r, sansPoste]) {
    const meilleure = Math.max(...Object.values(x.joueurs).filter(n => n.minutes >= 30).map(n => n.note));
    assert.equal(x.joueurs[x.hommeDuMatch].note, meilleure, 'homme du match : la meilleure note');
  }
  // Sans aucun fait, un troisième ligne (beaucoup de faits attendus) est noté sous un pilier.
  const vide = N.noter([], { cotes, minutes, postes, score: [0, 0], fini: true });
  assert.ok(vide.joueurs.a6.note < vide.joueurs.a1.note, 'match vide : attendu du poste non rempli');
  assert.equal(N.POSTES_NOTE.length, 15);
  // Domaine : poste occupé = maillot de départ, puis celui du joueur remplacé, sinon la place actuelle.
  const { run } = domaine();
  const postesDomaine = JSON.parse(run(`JSON.stringify(dom.contexte({pair:[0,1],score:[0,0],minute:80,finished:true,
    subs:[{side:0,out:'c0p5',in:'c0p17'},{side:0,out:'c0p17',in:'c0p20'},{side:1,out:'c1p0',in:'c1p15'}],
    sheets:[{initial:${JSON.stringify(Array.from({ length: 15 }, (_, k) => 'c0p' + k))},on:${JSON.stringify(Array.from({ length: 15 }, (_, k) => k === 5 ? 'c0p20' : 'c0p' + k))},used:${JSON.stringify([...Array.from({ length: 15 }, (_, k) => 'c0p' + k), 'c0p17', 'c0p20'])},minutes:{}},
     {initial:${JSON.stringify(Array.from({ length: 15 }, (_, k) => 'c1p' + k))},on:${JSON.stringify(Array.from({ length: 15 }, (_, k) => k === 0 ? 'c1p15' : 'c1p' + k))},used:${JSON.stringify([...Array.from({ length: 15 }, (_, k) => 'c1p' + k), 'c1p15'])},minutes:{}}]}).postes)`));
  assert.equal(postesDomaine.c0p5, 5);
  assert.equal(postesDomaine.c0p17, 5, 'remplaçant : maillot du joueur remplacé');
  assert.equal(postesDomaine.c0p20, 5, 'remplaçant du remplaçant');
  assert.equal(postesDomaine.c1p15, 0);
  assert.equal(postesDomaine.c1p14, 14);
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
    assert.equal(doc.state.matchNotes.version, 2);
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

// ---- Équipe-type de la journée, équipe de la saison (demande de Léo, 13 novembre 2026) ----------
const POSTES = ['Pilier gauche', 'Talonneur', 'Pilier droit', 'Deuxième ligne', 'Deuxième ligne', 'Troisième ligne', 'Troisième ligne', 'Numéro 8', 'Demi de mêlée', 'Demi d’ouverture', 'Ailier', 'Centre', 'Centre', 'Ailier', 'Arrière'];
const GROUPES = [0, 1, 2, 3, 3, 4, 4, 4, 5, 6, 7, 8, 8, 7, 9];
const groupeDe = pos => GROUPES[POSTES.indexOf(pos === 'Numéro 8' ? 'Numéro 8' : pos)];

// Quelques journées déléguées en carrière Monde (mode unique, consigne de Léo du 13/11 : plus aucun test en
// ancien mode France), club de l'élite française : renvoie les modèles de chaque journée.
function jouerJournees(jeu, journees) {
  let model = M.creer(jeu, 0);
  const vus = [];
  for (let j = 0; j < journees; j++) { model = M.jouer(jeu, model, 1); vus.push(model); }
  return vus;
}

test('Équipe-type : publiée à chaque journée, pour chaque championnat, quinze postes distincts, déterministe', () => {
  const lancer = () => { const jeu = ouvrir({ hebdomadaire: true }); try { const vus = jouerJournees(jeu, 4); return { vus, etat: jeu.etat() }; } finally { jeu.fermer(); } };
  const a = lancer();
  assert.ok(a.vus.length >= 4);
  let precedent = 0;
  for (const model of a.vus) {
    const eq = model.clubLife.matchNotes.equipeType;
    assert.ok(eq.ligues.length >= 1, 'au moins un championnat publié');
    for (const l of eq.ligues) {
      const x = l.journee;
      assert.ok(x, l.nom + ' : équipe de la journée');
      assert.equal(x.joueurs.length, 15);
      assert.equal(x.libelleSaison, require('../dist/season-label.js').libelleSaison(x.saison), 'libellé de saison du jeu (2026-2027), pas « Saison 1 »');
      assert.match(x.libelleSaison, /^\d{4}-\d{4}$/);
      assert.equal(new Set(x.joueurs.map(j => j.id)).size, 15, 'quinze joueurs distincts');
      assert.deepEqual(x.joueurs.map(j => j.numero), Array.from({ length: 15 }, (_, k) => k + 1));
      x.joueurs.forEach((j, k) => assert.equal(groupeDe(j.poste), GROUPES[k], 'poste du maillot ' + (k + 1)));
      for (const j of x.joueurs) { assert.ok(j.noteMatch >= 1 && j.noteMatch <= 10); assert.ok(j.club && j.club.presentation, 'club avec présentation'); assert.ok(j.selections >= 1); }
      assert.equal(x.joueurs.filter(j => j.etoile).length, 1, 'un joueur de la journée');
      assert.ok(x.entraineur === null || x.entraineur.marge >= 1);
      if (l.manager) assert.ok(x.numero >= precedent, 'journée suivante'), precedent = x.numero;
    }
    const mine = eq.ligues[0];
    if (!eq.ligues.some(l => l.manager)) continue; // calendrier mondial : d'autres championnats commencent plus tôt
    assert.equal(mine.manager, true, 'le championnat du manager passe en premier');
    assert.equal(mine.id, 'elite');
    assert.ok((model.messages || []).some(t => String(t).startsWith('XV de la ') && String(t).includes(' journée · ' + mine.nom)), 'actualité publiée à chaque journée, club du manager présent ou non');
  }
  const suivis = a.vus.at(-1).clubLife.matchNotes.equipeType.ligues.map(l => l.id);
  assert.ok(['elite', 'accession'].every(id => suivis.includes(id)) && suivis.length >= 3, 'chaque championnat du monde suivi : ' + suivis);
  // Même graine, même équipe : aucun tirage dans le choix.
  const b = lancer();
  assert.deepEqual(b.etat.matchNotes.equipes, a.etat.matchNotes.equipes);
  assert.equal(a.etat.matchNotes.version, 2);
  // Meilleur de chaque poste : personne de mieux noté au même poste n'a été écarté.
  // Un jeune appelé pour le match peut être reparti en centre de formation depuis (aiRoster.academies, development.academy).
  const noms = new Set(); for (const c of a.etat.clubs) for (const p of c.players) noms.add(p.id);
  for (const p of [...(a.etat.development?.academy || []), ...(a.etat.aiRoster?.academies || []).flatMap(x => x.players || [])]) noms.add(p.id);
  for (const e of Object.values(a.etat.matchNotes.equipes)) { assert.equal(e.ids.length, 15); for (const id of e.ids) assert.ok(noms.has(id), 'joueur inconnu des effectifs : ' + id); }
});

test('Équipe de la saison : seuil de matchs, départage, migration depuis la version 1', () => {
  const c = domaine(false);
  const out = JSON.parse(c.run(`(()=>{
    const reg={};let n=0;
    // 10 joueurs par poste : moyenne 6,0 à 7,5, tous 8 matchs ; sauf « fantome » (2 matchs, 9,9) et « egal » (même moyenne que le meilleur)
    const capacite=[1,1,1,2,3,1,1,2,2,1];
    for(let g=0;g<10;g++)for(let k=0;k<6;k++){const id='p'+g+'_'+k;reg[id]=[8,(60+k*5+g)*8,640,0,k===5?3:0,g,k%2];}
    reg.fantome=[2,99*2,160,2,0,0,0];
    reg.egal=[8,(60+25+0)*8,640,0,5,0,1];   // même moyenne que p0_5, davantage de sélections
    S.matchNotes={version:2,saison:S.season,joueurs:{},detail:{},passees:{},confiance:{},semaine:null,recompenses:[],dernier:null,reg:{elite:reg},regJ:{elite:10},equipes:{},saisons:[]};
    dom.validate(S);dom.finSaison();dom.finSaison();
    const s=S.matchNotes.saisons;dom.validate(S);
    return JSON.stringify({saisons:s,n:s.length});})()`));
  assert.equal(out.n, 1, 'une seule équipe de la saison par championnat (appel répété sans effet)');
  const f = out.saisons[0];
  assert.equal(f.ids.length, 15);
  assert.ok(!f.ids.includes('fantome'), 'sous le seuil de matchs (50 % de 10 journées) : écarté malgré 9,9 de moyenne');
  assert.equal(f.ids[0], 'egal', 'à moyenne égale : le plus de sélections en équipe-type');
  assert.equal(f.journees, 10);
  f.ids.forEach((id, k) => assert.ok(f.matchs[k] >= 5));
  assert.ok(f.moy.every(x => x >= 10 && x <= 100));
  // Migration : une version 1 reste valide et se complète sans rien inventer.
  const migre = JSON.parse(c.run(`(()=>{S.matchNotes={version:1,saison:S.season,joueurs:{},detail:{},passees:{},confiance:{},semaine:null,recompenses:[],dernier:null};dom.validate(S);dom.migrer(S.matchNotes);dom.validate(S);return JSON.stringify(S.matchNotes)})()`));
  assert.equal(migre.version, 2);
  assert.deepEqual([migre.reg, migre.regJ, migre.equipes, migre.saisons], [{}, {}, {}, []]);
  // Un état v2 incohérent est refusé.
  assert.throws(() => c.run(`(()=>{S.matchNotes.saisons=[{saison:1,ligue:'elite',ids:['a'],moy:[70],matchs:[3],sel:[0],clubs:[0],journees:3}];dom.validate(S)})()`), /Notes de match/);
});

test('Équipe de la saison : bonus de valeur borné, coupé par CD_NOTES_EFFETS=0', () => {
  const lire = actifs => {
    const c = domaine(actifs);
    return JSON.parse(c.run(`(()=>{const ids=Array.from({length:15},(_,k)=>'l'+k);S.matchNotes={version:2,saison:S.season,joueurs:{l0:{s:[20,1300,1600,0,0,0,0],f:[65,65,65,65,65]}},detail:{},passees:{},confiance:{},semaine:null,recompenses:[],dernier:null,reg:{},regJ:{},equipes:{},saisons:[{saison:S.season,ligue:'elite',ids,moy:ids.map(()=>70),matchs:ids.map(()=>20),sel:ids.map(()=>1),clubs:ids.map(()=>0),journees:26}]};dom.validate(S);const e=dom.effets;return JSON.stringify({v:e.valeur('l0'),i:e.interet('l0'),autre:e.valeur('zz')})})()`));
  };
  const on = lire(true), off = lire(false);
  assert.equal(on.v, 1.03); assert.equal(on.i, 0.5); assert.equal(on.autre, 1, 'non lauréat : aucun effet');
  assert.deepEqual(off, { v: 1, i: 0, autre: 1 }, 'effets coupés');
});

// Packs d'identité : même mécanisme que l'effectif et la fiche club (logoPath, portraitPath par identifiant),
// repli sur l'écusson et le portrait originaux du jeu. Aucune image réelle : pixel de test.
test('Équipe-type : pack absent = identités du jeu ; pack installé = logos du pack (carrière Monde)', () => {
  const media = require('../native/engine/media-packs.cjs'), crypto = require('node:crypto'), zlib = require('node:zlib');
  const zip = items => { let offset = 0; const locals = [], centrals = []; for (const item of items) { const n = Buffer.from(item.name), data = Buffer.isBuffer(item.data) ? item.data : Buffer.from(item.data || ''), crc = media.crc32(data), local = Buffer.alloc(30), central = Buffer.alloc(46); local.writeUInt32LE(0x04034b50); local.writeUInt16LE(20, 4); local.writeUInt16LE(0x800, 6); local.writeUInt32LE(crc, 14); local.writeUInt32LE(data.length, 18); local.writeUInt32LE(data.length, 22); local.writeUInt16LE(n.length, 26); central.writeUInt32LE(0x02014b50); central.writeUInt16LE(0x314, 4); central.writeUInt16LE(20, 6); central.writeUInt16LE(0x800, 8); central.writeUInt32LE(crc, 16); central.writeUInt32LE(data.length, 20); central.writeUInt32LE(data.length, 24); central.writeUInt16LE(n.length, 28); central.writeUInt32LE((0x81a4 * 65536) >>> 0, 38); central.writeUInt32LE(offset, 42); locals.push(local, n, data); centrals.push(central, n); offset += local.length + n.length + data.length; } const cd = Buffer.concat(centrals), end = Buffer.alloc(22); end.writeUInt32LE(0x06054b50); end.writeUInt16LE(items.length, 8); end.writeUInt16LE(items.length, 10); end.writeUInt32LE(cd.length, 12); end.writeUInt32LE(offset, 16); return Buffer.concat([...locals, cd, end]); };
  const pixel = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=', 'base64');
  const jeu = ouvrir({ hebdomadaire: true });
  try {
    const vus = jouerJournees(jeu, 2);
    const avant = vus.at(-1).clubLife.matchNotes.equipeType;
    const joueursXV = l => [...l.journee.joueurs, ...(l.saison?.joueurs || [])];
    for (const l of avant.ligues) for (const j of joueursXV(l)) {
      assert.equal(j.club.presentation.logoPath, undefined, 'pack absent : pas de logo du pack');
      assert.equal(j.portraitPath, undefined, 'pack absent : pas de portrait du pack');
      assert.ok(Number.isInteger(j.portraitIndex), 'portrait original du jeu');
    }
    const ids = [...new Set(avant.ligues.flatMap(l => joueursXV(l).map(j => j.id)))];
    const base = vus.at(-1).meta.champDatabase, clubsXV = [...new Set(avant.ligues.flatMap(l => joueursXV(l).map(j => j.club.id)))];
    const manifest = { schema: 'cd-identity-pack-v1', id: 'essai-xv', name: 'Identités test', version: '1', databaseId: base.id, rightsStatus: 'test-local',
      clubs: clubsXV.map(id => ({ id, logo: 'image' })), players: [], // identités de joueurs Monde : couvertes par les tests des packs Monde ; ici, les logos
      assets: [{ id: 'image', path: 'médias/image.png', sha256: crypto.createHash('sha256').update(pixel).digest('hex'), bytes: pixel.length }] };
    const fichier = path.join(os.tmpdir(), 'rl27-xv-pack-' + process.pid + '.zip');
    fs.writeFileSync(fichier, zip([{ name: 'pack.json', data: JSON.stringify(manifest) }, { name: 'médias/image.png', data: pixel }]));
    try {
      const apercu = jeu.call('pack_inspect', { path: fichier, mode: 'world-champ' }).packs.preview;
      jeu.call('pack_install', { path: fichier, digest: apercu.digest });
      const model = jeu.call('pack_select', { id: apercu.id, scope: 'career', mode: 'world-champ' });
      const apres = model.clubLife.matchNotes.equipeType;
      let couverts = 0;
      for (const l of apres.ligues) for (const j of joueursXV(l)) {
        couverts++;
        assert.ok(String(j.club.presentation.logoPath || '').endsWith('.png'), 'pack : logo du club par identifiant');
      }
      assert.ok(couverts >= 15, 'au moins un XV complet couvert par le pack : ' + couverts);
      const retour = jeu.call('pack_select', { id: 'base', scope: 'career', mode: 'world-champ' });
      assert.equal(retour.clubLife.matchNotes.equipeType.ligues[0].journee.joueurs[0].club.presentation.logoPath, undefined, 'retour au jeu de base : écusson original');
    } finally { fs.rmSync(fichier, { force: true }); }
  } finally { jeu.fermer(); }
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
