'use strict';
// Notes de match (native/engine/match-notes.cjs) : calcul unique et déterministe, sans tirage ;
// note du direct = note enregistrée ; tous les matchs simulés notés ; sauvegarde (migration,
// aller-retour) ; effets bornés. Voir docs/notes-de-match-20261113.md.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const { context } = require('./france-harness.cjs');
const N = require('../native/engine/match-notes.cjs');
const H = require('../native/engine/match-highlights.cjs');

function ouvrir(options = {}) {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-notes-'));
  const bridge = createBridge({ dataDir, seed: 2024, now: 1700000000000, ...options });
  let id = 0;
  const brut = (command, payload = {}) => bridge.handle({ id: ++id, command, payload });
  const call = (command, payload = {}) => { const r = brut(command, payload); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
  const etat = () => JSON.parse(call('export').meta.exportText).state;
  return { brut, call, etat, fermer: () => { try { bridge.close(); } catch (e) { /* déjà fermé */ } fs.rmSync(dataDir, { recursive: true, force: true }); } };
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
  const meilleure = Math.max(...Object.values(r1.joueurs).filter(n => n.minutes >= 30).map(n => n.note));
  assert.equal(r1.joueurs[r1.hommeDuMatch].note, meilleure, 'homme du match : meilleure note');
  // Le direct (match-direct.cjs) appelle le même calcul.
  const D = require('../native/engine/match-direct.cjs');
  const lignes = H.normaliser(journal);
  const direct = D.notesDuMatch(lignes, journal, 0, { cotes, minutes, fini: true });
  assert.equal(direct.a14.note, r1.joueurs.a14.note);
});

test('Matchs simulés : même score et même tirage avec le journal des notes', () => {
  const jouer = avecNotes => {
    const c = context(77);
    c.run("start(0,'fiction')");
    if (avecNotes) c.run(`const CDMatchNotesMoteur=(${N.moteur.toString()})();const CDNotesEffets=false;const dom=(${N.factory.toString()})();dom.installHooks();`);
    const out = JSON.parse(c.run('JSON.stringify([0,1,2,3].map(k=>{const r=rugbySimulate([k,k+5]);return {score:r.score,tries:r.tries}}))'));
    return { out, tirage: c.seed(), notes: avecNotes ? JSON.parse(c.run('JSON.stringify(S.matchNotes)')) : null };
  };
  const sans = jouer(false), avec = jouer(true);
  assert.deepEqual(avec.out, sans.out, 'scores et essais identiques');
  assert.equal(avec.tirage, sans.tirage, 'curseur du générateur identique');
  const notes = Object.values(avec.notes.joueurs);
  assert.ok(notes.length >= 4 * 2 * 15, 'chaque joueur ayant joué a sa note : ' + notes.length);
  assert.ok(notes.every(j => j.s[0] === 1 && j.f.length === 1 && j.f[0] >= 10 && j.f[0] <= 100));
});

test('Direct : la note affichée en fin de match est la note enregistrée ; homme du match ; autres matchs notés', () => {
  const jeu = ouvrir({ matchHighlights: 'dynamique' });
  try {
    let model = jeu.call('new_career', { club: 0 });
    settleClubMeetings(model, jeu.call);
    model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
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

test('Sauvegarde : aller-retour, migration d’une ancienne sauvegarde sans notes, validation', () => {
  const jeu = ouvrir();
  try {
    let model = jeu.call('new_career', { club: 0 });
    settleClubMeetings(model, jeu.call);
    model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
    jeu.call('delegate');
    jeu.call('finish_round');
    const texte = jeu.call('export').meta.exportText;
    const doc = JSON.parse(texte);
    assert.equal(doc.state.matchNotes.version, 1);
    jeu.call('import', { text: texte });
    assert.deepEqual(jeu.etat().matchNotes, doc.state.matchNotes, 'aller-retour exact');
    // Ancienne sauvegarde : pas de notes, historique vide puis rempli au match suivant.
    const sansNotes = jeu.call('import', { text: signe(doc, state => { delete state.matchNotes; }) });
    assert.deepEqual(sansNotes.clubLife.matchNotes.joueurs, {}, 'ancienne sauvegarde : historique vide');
    assert.equal(jeu.etat().matchNotes, undefined, 'rien n’est inventé pour le passé');
    // Un état corrompu est refusé.
    const id = Object.keys(doc.state.matchNotes.joueurs)[0];
    const casse = jeu.brut('import', { text: signe(doc, state => { state.matchNotes.joueurs[id].f = [999]; }) });
    assert.equal(casse.ok, false, 'note hors échelle refusée');
    assert.match(casse.error, /Notes de match/);
  } finally { jeu.fermer(); }
});

test('Effets bornés : composition, valeur, intérêt, salaire, sélection, moral', () => {
  const c = context(5);
  c.run("start(0,'fiction')");
  c.run(`const CDMatchNotesMoteur=(${N.moteur.toString()})();const dom=(${N.factory.toString()})();`);
  const extremes = JSON.parse(c.run(`(()=>{S.matchNotes={version:1,saison:S.season,joueurs:{haut:{s:[20,2000,1600,9,99,999,9],f:[100,100,100,100,100]},bas:{s:[20,200,1600,0,0,0,0],f:[10,10,10,10,10]},neutre:{s:[20,1300,1600,0,0,0,0],f:[65,65,65,65,65]}},detail:{},passees:{},confiance:{},semaine:null,recompenses:[],dernier:null};
    const e=dom.effets,r={};for(const id of ['haut','bas','neutre','inconnu'])r[id]={composition:e.composition(id),valeur:e.valeur(id),interet:e.interet(id),salaire:e.salaire(id),selection:e.selection(id)};dom.validate(S);return JSON.stringify(r)})()`));
  assert.deepEqual(extremes.neutre, { composition: 1, valeur: 1, interet: 0, salaire: 1, selection: 0 }, '6,5 de moyenne : aucun effet');
  assert.deepEqual(extremes.inconnu, { composition: 1, valeur: 1, interet: 0, salaire: 1, selection: 0 }, 'sans note : aucun effet');
  assert.deepEqual(extremes.haut, { composition: 1.04, valeur: 1.12, interet: 3, salaire: 1.06, selection: 2 }, 'plafonds');
  assert.deepEqual(extremes.bas, { composition: 0.97, valeur: 0.92, interet: -2, salaire: 0.96, selection: -1.5 }, 'planchers');
});
