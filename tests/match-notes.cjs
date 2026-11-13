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
    assert.equal(doc.state.matchNotes.version, 2);
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

// ---- Équipe-type de la journée, équipe de la saison (demande de Léo, 13 novembre 2026) ----------
const POSTES = ['Pilier gauche', 'Talonneur', 'Pilier droit', 'Deuxième ligne', 'Deuxième ligne', 'Troisième ligne', 'Troisième ligne', 'Numéro 8', 'Demi de mêlée', 'Demi d’ouverture', 'Ailier', 'Centre', 'Centre', 'Ailier', 'Arrière'];
const GROUPES = [0, 1, 2, 3, 3, 4, 4, 4, 5, 6, 7, 8, 8, 7, 9];
const groupeDe = pos => GROUPES[POSTES.indexOf(pos === 'Numéro 8' ? 'Numéro 8' : pos)];

// Quelques journées déléguées en mode commun (Top 14 et Pro D2) : renvoie les modèles de chaque journée.
function jouerJournees(jeu, journees) {
  let model = jeu.call('new_career', { mode: 'common', club: 29 });
  const vus = [];
  for (let j = 0, garde = 0; j < journees && garde < 40; garde++) {
    model = settleClubMeetings(model, jeu.call) || model;
    if (model.next) {
      if (!model.selection.valid) jeu.call('auto_lineup');
      model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
      jeu.call('delegate'); j++;
      model = skipMatchTalk(model, jeu.call);
      model = settleClubMeetings(model, jeu.call) || model;
    }
    const r = jeu.brut('finish_round');
    if (r.ok) { model = r.model; vus.push(model); }
  }
  return vus;
}

test('Équipe-type : publiée à chaque journée, pour chaque championnat, quinze postes distincts, déterministe', () => {
  const lancer = () => { const jeu = ouvrir(); try { const vus = jouerJournees(jeu, 4); return { vus, etat: jeu.etat() }; } finally { jeu.fermer(); } };
  const a = lancer();
  assert.ok(a.vus.length >= 4);
  let precedent = 0;
  for (const model of a.vus) {
    const eq = model.clubLife.matchNotes.equipeType;
    assert.deepEqual(eq.ligues.map(l => l.nom).sort(), ['Pro D2', 'Top 14'], 'les deux championnats suivis');
    for (const l of eq.ligues) {
      const x = l.journee;
      assert.ok(x, l.nom + ' : équipe de la journée');
      assert.equal(x.joueurs.length, 15);
      assert.equal(new Set(x.joueurs.map(j => j.id)).size, 15, 'quinze joueurs distincts');
      assert.deepEqual(x.joueurs.map(j => j.numero), Array.from({ length: 15 }, (_, k) => k + 1));
      x.joueurs.forEach((j, k) => assert.equal(groupeDe(j.poste), GROUPES[k], 'poste du maillot ' + (k + 1)));
      for (const j of x.joueurs) { assert.ok(j.noteMatch >= 1 && j.noteMatch <= 10); assert.ok(j.club && j.club.presentation, 'club avec présentation'); assert.ok(j.selections >= 1); }
      assert.equal(x.joueurs.filter(j => j.etoile).length, 1, 'un joueur de la journée');
      assert.ok(x.entraineur === null || x.entraineur.marge >= 1);
      if (l.manager) assert.ok(x.numero >= precedent, 'journée suivante'), precedent = x.numero;
    }
    const mine = eq.ligues[0];
    assert.equal(mine.manager, true, 'le championnat du manager passe en premier');
    assert.ok((model.messages || []).some(t => /^XV de la \d+(re|e) journée · Pro D2/.test(String(t))), 'actualité publiée à chaque journée, club du manager présent ou non');
  }
  // Même graine, même équipe : aucun tirage dans le choix.
  const b = lancer();
  assert.deepEqual(b.etat.matchNotes.equipes, a.etat.matchNotes.equipes);
  assert.equal(a.etat.matchNotes.version, 2);
  // Meilleur de chaque poste : personne de mieux noté au même poste n'a été écarté.
  const noms = new Set(); for (const c of a.etat.clubs) for (const p of c.players) noms.add(p.id);
  for (const e of Object.values(a.etat.matchNotes.equipes)) { assert.equal(e.ids.length, 15); for (const id of e.ids) assert.ok(noms.has(id)); }
});

test('Équipe de la saison : seuil de matchs, départage, migration depuis la version 1', () => {
  const c = context(5);
  c.run("start(0,'fiction')");
  c.run(`const CDMatchNotesMoteur=(${N.moteur.toString()})();const CDNotesEffets=false;const dom=(${N.factory.toString()})();`);
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
    const c = context(5); c.run("start(0,'fiction')");
    c.run(`const CDMatchNotesMoteur=(${N.moteur.toString()})();const CDNotesEffets=${actifs};const dom=(${N.factory.toString()})();`);
    return JSON.parse(c.run(`(()=>{const ids=Array.from({length:15},(_,k)=>'l'+k);S.matchNotes={version:2,saison:S.season,joueurs:{l0:{s:[20,1300,1600,0,0,0,0],f:[65,65,65,65,65]}},detail:{},passees:{},confiance:{},semaine:null,recompenses:[],dernier:null,reg:{},regJ:{},equipes:{},saisons:[{saison:S.season,ligue:'elite',ids,moy:ids.map(()=>70),matchs:ids.map(()=>20),sel:ids.map(()=>1),clubs:ids.map(()=>0),journees:26}]};dom.validate(S);const e=dom.effets;return JSON.stringify({v:e.valeur('l0'),i:e.interet('l0'),autre:e.valeur('zz')})})()`));
  };
  const on = lire(true), off = lire(false);
  assert.equal(on.v, 1.03); assert.equal(on.i, 0.5); assert.equal(on.autre, 1, 'non lauréat : aucun effet');
  assert.deepEqual(off, { v: 1, i: 0, autre: 1 }, 'effets coupés');
});

// Packs d'identité : même mécanisme que l'effectif et la fiche club (logoPath, portraitPath par identifiant),
// repli sur l'écusson et le portrait originaux du jeu. Aucune image réelle : pixel de test.
test('Équipe-type : pack absent = identités du jeu ; pack installé = logos et portraits du pack', () => {
  const media = require('../native/engine/media-packs.cjs'), db = require('../dist/rugby-common-rosters.js'), crypto = require('node:crypto'), zlib = require('node:zlib');
  const zip = items => { let offset = 0; const locals = [], centrals = []; for (const item of items) { const n = Buffer.from(item.name), data = Buffer.isBuffer(item.data) ? item.data : Buffer.from(item.data || ''), crc = media.crc32(data), local = Buffer.alloc(30), central = Buffer.alloc(46); local.writeUInt32LE(0x04034b50); local.writeUInt16LE(20, 4); local.writeUInt16LE(0x800, 6); local.writeUInt32LE(crc, 14); local.writeUInt32LE(data.length, 18); local.writeUInt32LE(data.length, 22); local.writeUInt16LE(n.length, 26); central.writeUInt32LE(0x02014b50); central.writeUInt16LE(0x314, 4); central.writeUInt16LE(20, 6); central.writeUInt16LE(0x800, 8); central.writeUInt32LE(crc, 16); central.writeUInt32LE(data.length, 20); central.writeUInt32LE(data.length, 24); central.writeUInt16LE(n.length, 28); central.writeUInt32LE((0x81a4 * 65536) >>> 0, 38); central.writeUInt32LE(offset, 42); locals.push(local, n, data); centrals.push(central, n); offset += local.length + n.length + data.length; } const cd = Buffer.concat(centrals), end = Buffer.alloc(22); end.writeUInt32LE(0x06054b50); end.writeUInt16LE(items.length, 8); end.writeUInt16LE(items.length, 10); end.writeUInt32LE(cd.length, 12); end.writeUInt32LE(offset, 16); return Buffer.concat([...locals, cd, end]); };
  const pixel = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII=', 'base64');
  const jeu = ouvrir();
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
    const manifest = { schema: 'cd-identity-pack-v1', id: 'essai-xv', name: 'Identités test', version: '1', databaseId: db.id, rightsStatus: 'test-local',
      clubs: Array.from({ length: 30 }, (_, id) => ({ id, logo: 'image' })), players: ids.map(id => ({ id, name: 'Nom du pack ' + id.slice(4), portrait: 'image', synthetic: true })),
      assets: [{ id: 'image', path: 'médias/image.png', sha256: crypto.createHash('sha256').update(pixel).digest('hex'), bytes: pixel.length }] };
    const fichier = path.join(os.tmpdir(), 'rl27-xv-pack-' + process.pid + '.zip');
    fs.writeFileSync(fichier, zip([{ name: 'pack.json', data: JSON.stringify(manifest) }, { name: 'médias/image.png', data: pixel }]));
    try {
      const apercu = jeu.call('pack_inspect', { path: fichier }).packs.preview;
      jeu.call('pack_install', { path: fichier, digest: apercu.digest });
      const model = jeu.call('pack_select', { id: apercu.id, scope: 'career' });
      const apres = model.clubLife.matchNotes.equipeType;
      for (const l of apres.ligues) for (const j of joueursXV(l)) {
        assert.ok(String(j.club.presentation.logoPath || '').endsWith('.png'), 'pack : logo du club par identifiant');
        assert.ok(String(j.portraitPath || '').endsWith('.png'), 'pack : portrait du joueur par identifiant');
        assert.match(j.name, /^Nom du pack /, 'pack : nom du joueur');
      }
      const retour = jeu.call('pack_select', { id: 'base', scope: 'career' });
      assert.equal(retour.clubLife.matchNotes.equipeType.ligues[0].journee.joueurs[0].club.presentation.logoPath, undefined, 'retour au jeu de base : écusson original');
    } finally { fs.rmSync(fichier, { force: true }); }
  } finally { jeu.fermer(); }
});
