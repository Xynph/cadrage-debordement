'use strict';
// Avis du conseil sur notre jeu (revue FM27, idée n° 31, choix de Léo du 23/11/2026) :
//  1. bilan du conseil : la note du jeu compte (15 %), sans rien changer quand elle est absente ;
//  2. module seul (conseil-jeu.cjs) : chiffres de la saison, moyenne, rang, avis ▲ / ▼, familles, attentes par club
//     (identités différentes selon les clubs, stables), note pondérée par les attentes, sauvegarde validée ;
//  3. entrées dans les 22 m : une par passage du ballon dans les 22 m adverses, sans tirage ;
//  4. vrai moteur (carrière Monde) : entrées dans les 22 m et jeunes titulaires enregistrés, projection
//     clubLife.conseilJeu, bilan du conseil avec la note du jeu et ses poids, identité fixée dans la sauvegarde,
//     sauvegarde relue à l'identique, ancienne sauvegarde (sans ces champs) acceptée avec ses valeurs par défaut.
const assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const BoardPlanning = require('../dist/board-planning.js');
const ConseilJeu = require('../native/engine/conseil-jeu.cjs');

// 1. Conseil : jeu 15 % (résultats 50, finances 15, formation 10, supporters 10).
const poids = { results: .5, finances: .15, youth: .1, supporters: .1, jeu: .15 };
const sans = BoardPlanning.boardConfidence({ current: 60, results: 50, finances: 70, youth: 50, supporters: 60, weights: { results: .6, finances: .2, youth: .1, supporters: .1 }, pull: .7 });
const avec = jeu => BoardPlanning.boardConfidence({ current: 60, results: 50, finances: 70, youth: 50, supporters: 60, jeu, weights: poids, pull: .7 });
assert.ok(avec(20).next < avec(50).next && avec(50).next < avec(85).next, 'le conseil suit la note du jeu : ' + [avec(20).next, avec(50).next, avec(85).next].join(' / '));
assert.ok(Math.abs(avec(85).next - avec(20).next) >= 6, 'effet réel, pas symbolique');
assert.equal(BoardPlanning.boardConfidence({ current: 60, results: 50, finances: 70, youth: 50, weights: { results: .7, finances: .2, youth: .1 }, pull: .7 }).next, 56, 'sans note du jeu : calcul d’avant');
assert.ok(Number.isFinite(sans.next));
assert.throws(() => BoardPlanning.boardConfidence({ current: 60, results: 50, finances: 70, youth: 50, supporters: 60, weights: poids }), /invalide/, 'note du jeu exigée avec son poids');
assert.throws(() => BoardPlanning.boardConfidence({ current: 60, results: 50, finances: 70, youth: 50, supporters: 60, jeu: 50, weights: { ...poids, jeu: .2 } }), /invalide/, 'poids sur 100 %');

// 2. Module seul, sur une saison fabriquée : 4 clubs, 3 journées, notre club = 0.
const stats = (o = {}) => ({ possession: 50, territory: 2500, scrums: 10, scrumsWon: 9, lineouts: 10, lineoutsWon: 8, penalties: 8, yellows: 0, conversions: 2, conversionAttempts: 3, goalAttempts: 3, goals: 2, ...o });
const match = (round, pair, score, tries, s0 = {}, s1 = {}) => ({ season: 2, round, competitionRound: round - 1, competitionId: 'elite', phase: 'league', pair, score, tries, stats: [stats(s0), stats(s1)] });
const history = [
  match(1, [0, 1], [30, 10], [4, 1], { entries22: 12, jeunes: 4 }, { entries22: 5, jeunes: 1 }), match(1, [2, 3], [20, 20], [2, 2], { entries22: 8, jeunes: 2 }, { entries22: 8, jeunes: 2 }),
  match(2, [2, 0], [15, 25], [1, 3], { entries22: 6, jeunes: 2 }, { entries22: 10, jeunes: 5 }), match(2, [3, 1], [12, 9], [1, 0], { entries22: 7, jeunes: 2 }, { entries22: 4, jeunes: 1 }),
  match(3, [0, 3], [18, 22], [2, 3], { entries22: 9, jeunes: 3 }, { entries22: 9, jeunes: 2 }), match(3, [1, 2], [6, 30], [0, 4], { entries22: 3, jeunes: 1 }, { entries22: 11, jeunes: 2 }),
  // Saison passée et autre championnat : ignorés ; ancien match sans entrées dans les 22 m : ces chiffres manquent seulement.
  { ...match(9, [0, 1], [0, 50], [0, 7]), season: 1 }, { ...match(1, [0, 5], [3, 60], [0, 9]), competitionId: 'champions', phase: 'pool' },
];
const etat = { season: 2, round: 3, club: 0, history, careerVariation: { seed: 7 }, clubs: [0, 1, 2, 3, 4, 5].map(id => ({ id, base: 60 + id * 4 })) };
global.S = etat;
const domaine = ConseilJeu.factory();
const d = domaine.donnees(etat);
assert.equal(d.saison, 2); assert.equal(d.competition, 'elite'); assert.ok(d.courante);
assert.equal(d.matchs.length, 3, 'nos 3 matchs de championnat de la saison');
assert.deepEqual(d.matchs.map(m => m.journee), [1, 2, 3]);
assert.equal(Object.keys(d.indicateurs).length, 16, '14 chiffres + entrées dans les 22 m + jeunes titulaires');
const e22 = d.indicateurs.entrees22;
assert.equal(e22.nous, (12 + 10 + 9) / 3); assert.equal(e22.total, 31, 'total de la saison');
assert.equal(e22.rang, 1, 'meilleur total d’entrées dans les 22 m'); assert.equal(e22.avis, 'up'); assert.equal(e22.clubs, 4);
assert.equal(d.indicateurs.victoires.nous, 100 * 2 / 3); assert.equal(d.indicateurs.encaisses.sens, -1);
assert.equal(d.indicateurs.encaisses.rang, 1, 'points encaissés : moins c’est mieux (47 sur 3 matchs, à égalité en tête)');
for (const i of Object.values(d.indicateurs)) assert.ok(i.note >= 0 && i.note <= 100 && ['up', 'down', 'neutre'].includes(i.avis), i.id);
assert.deepEqual(d.familles.map(f => f.id), ['plan', 'conquete', 'spectacle', 'attaque', 'defense', 'formation']);
assert.ok(d.familles.every(f => [1, 2, 3].includes(f.attente)), 'attente 1 à 3 par famille');
const somme = d.familles.reduce((n, f) => n + f.note * f.attente, 0) / d.familles.reduce((n, f) => n + f.attente, 0);
assert.ok(Math.abs(d.note - somme) < 1e-9, 'note du jeu = familles pondérées par les attentes du club');
assert.ok(Object.keys(ConseilJeu.factory().RULES.PROFILS).includes(d.profil));
// Attentes par club : identités variées sur 60 clubs, stables d'un appel à l'autre, et fixée = gardée.
etat.clubs = Array.from({ length: 60 }, (_, id) => ({ id, base: 60 + (id % 30) }));
const identites = etat.clubs.map(c => domaine.profil(c.id));
assert.ok(new Set(identites).size >= 4, 'chaque club a ses attentes : ' + JSON.stringify(identites.reduce((o, p) => (o[p] = (o[p] || 0) + 1, o), {})));
assert.deepEqual(etat.clubs.map(c => domaine.profil(c.id)), identites, 'identité déterministe');
etat.clubDirections = { clubs: { 0: { strategy: 'rajeunissement', president: { traits: { ambition: 20, prudence: 50 } }, director: { traits: { formation: 100 } }, coach: { traits: { youth: 100 } } } } };
assert.equal(domaine.profil(0), 'formation', 'direction tournée vers les jeunes : attente Formation');
const autre = etat.clubs.findIndex(c => domaine.profil(c.id) !== 'formation');
etat.conseilJeu = { version: 1, attentes: { 0: 'spectacle' } };
assert.equal(domaine.profil(0), 'spectacle', 'identité fixée dans la sauvegarde gardée');
assert.ok(domaine.validate(etat));
assert.ok(domaine.validate({ ...etat, conseilJeu: undefined }), 'ancienne sauvegarde sans avis : acceptée');
assert.throws(() => domaine.validate({ ...etat, conseilJeu: { version: 1, attentes: { 0: 'tiki-taka' } } }), /attente invalide/);
assert.throws(() => domaine.validate({ ...etat, conseilJeu: { version: 2, attentes: {} } }), /sauvegarde invalide/);
assert.ok(autre >= 0);
// Note du bilan : saison en cours, au moins 3 matchs ; part de hasard bornée (±6) ; identité fixée à ce moment.
delete etat.conseilJeu; delete etat.clubDirections;
const note = domaine.noteBilan();
assert.ok(Number.isInteger(note) && Math.abs(note - d.note) <= 6.5, 'note du bilan ≈ note du jeu ± hasard : ' + note + ' / ' + d.note);
assert.deepEqual(etat.conseilJeu, { version: 1, attentes: { 0: d.profil } }, 'identité fixée au premier bilan');
etat.season = 3;
assert.equal(domaine.noteBilan(), null, 'saison neuve sans match : pas de note du jeu au bilan');
delete global.S;

// 3 et 4. Vrai moteur, carrière Monde (cadence de la semaine pour aller vite).
const Module = require('node:module'), workerPath = path.resolve(__dirname, '../native/engine/worker.cjs'), workerSource = fs.readFileSync(workerPath, 'utf8'), needle = 'return {handle,close};';
assert.equal(workerSource.split(needle).length, 2);
const instrumented = new Module(workerPath, module); instrumented.filename = workerPath; instrumented.paths = Module._nodeModulePaths(path.dirname(workerPath));
instrumented._compile(workerSource.replace(needle, 'return {handle,close,inspect:run};'), workerPath);
const { createBridge } = instrumented.exports;
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { playNextMatch } = require('./helpers/monde-matchs.cjs');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-conseil-jeu-'));
let b, seq = 0;
const call = (command, payload = {}) => { const r = b.handle({ id: ++seq, command, payload }); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
const options = { dailyCalendar: false, mandatoryPress: false, internationalCareer: false };
try {
  b = createBridge({ dataDir: root, seed: 31, now: 1700000000000, ...options });
  // 3. Entrées dans les 22 m : une par passage, rien tant que le camp y reste ; l'autre camp compte les siennes.
  const passages = JSON.parse(b.inspect(`(()=>{const l={possession:0,territory:50,stats:[{},{}]},pas=[[0,80],[0,90],[0,60],[0,85],[1,20],[1,10],[0,95]];for(const [p,t] of pas){l.possession=p;l.territory=t;compterEntree22(l);}return JSON.stringify(l.stats)})()`));
  assert.deepEqual(passages, [{ entries22: 3 }, { entries22: 1 }], 'entrées dans les 22 m comptées au passage');
  let m = settleClubMeetings(call('new_career', { mode: 'world-champ', club: 29 }), call);
  assert.equal(m.clubLife.conseilJeu.available, false, 'avant le premier match : rien à juger');
  for (let i = 0; i < 12 && !(m.clubLife.clubStrategy.finance.boardHistory || []).some(x => Number.isInteger(x.jeu)); i++) m = playNextMatch(m, call);
  const nos = JSON.parse(b.inspect('JSON.stringify(S.history.filter(r=>r.pair.includes(S.club)&&r.phase==="league").map(r=>r.stats))'));
  assert.ok(nos.length >= 3 && nos.every(s => s.every(x => Number.isInteger(x.entries22) && x.entries22 >= 0 && x.entries22 < 60 && Number.isInteger(x.jeunes) && x.jeunes >= 0 && x.jeunes <= 15)), 'entrées dans les 22 m et jeunes titulaires enregistrés : ' + JSON.stringify(nos.map(s => s.map(x => [x.entries22, x.jeunes]))));
  assert.ok(nos.some(s => s.some(x => x.entries22 > 0)), 'au moins une entrée dans les 22 m');
  const cj = m.clubLife.conseilJeu;
  assert.equal(cj.available, true); assert.ok(cj.courante); assert.ok(cj.matchs.length >= 3);
  assert.ok(cj.indicateurs.entrees22 && cj.indicateurs.entrees22.total >= 0, 'entrées dans les 22 m sur la saison');
  assert.ok(cj.indicateurs.jeunes, 'jeunes titulaires');
  assert.ok(Object.keys(cj.indicateurs).length >= 15, 'chiffres : ' + Object.keys(cj.indicateurs).join(', '));
  assert.ok(Number.isFinite(cj.note) && cj.familles.length === 6 && typeof cj.identite === 'string' && cj.identite.length > 0);
  const bilan = m.clubLife.clubStrategy.finance.boardHistory.find(x => Number.isInteger(x.jeu));
  assert.ok(bilan, 'bilan du conseil avec la note du jeu');
  assert.deepEqual(cj.dernierBilan, { season: bilan.season, round: bilan.round, jeu: bilan.jeu });
  const w = Number.isInteger(bilan.supporters) ? { results: .5, finances: .15, youth: .1, supporters: .1, jeu: .15 } : { results: .6, finances: .15, youth: .1, jeu: .15 };
  assert.equal(bilan.score, Math.round(Object.entries(w).reduce((n, [k, v]) => n + bilan[k] * v, 0)), 'poids du bilan : ' + JSON.stringify(bilan));
  assert.match(b.inspect('JSON.stringify(S.news.slice(0,60))'), /jeu 15 %/, 'bilan annoncé avec le jeu');
  const fixe = JSON.parse(b.inspect('JSON.stringify(S.conseilJeu)'));
  assert.deepEqual(fixe, { version: 1, attentes: { 29: cj.profil } }, 'identité du club fixée dans la sauvegarde');
  // Sauvegarde relue telle quelle.
  const saved = call('export').meta.exportText; call('shutdown'); b = createBridge({ dataDir: root, ...options });
  assert.equal(call('export').meta.exportText, saved, 'sauvegarde relue à l’identique');
  // Ancienne sauvegarde : sans identité, sans entrées dans les 22 m ni jeunes, bilans sans note du jeu.
  b.inspect('delete S.conseilJeu;for(const r of S.history)for(const s of r.stats||[]){delete s.entries22;delete s.jeunes}for(const x of S.careerManagement.boardHistory)delete x.jeu;0');
  const ancien = call('export').meta.exportText;
  call('shutdown'); b = createBridge({ dataDir: fs.mkdtempSync(path.join(os.tmpdir(), 'cd-conseil-jeu-ancien-')), ...options });
  m = call('import', { text: ancien });
  const vieux = m.clubLife.conseilJeu;
  assert.equal(vieux.available, true, 'ancienne sauvegarde : écran disponible');
  assert.equal(vieux.indicateurs.entrees22, undefined, 'ancienne sauvegarde : pas d’entrées dans les 22 m inventées');
  assert.equal(vieux.profil, cj.profil, 'ancienne sauvegarde : même identité recalculée');
  assert.equal(vieux.dernierBilan, null);
  assert.equal(b.inspect('JSON.stringify(S.conseilJeu)'), undefined, 'rien écrit avant le prochain bilan');
  console.log('Avis du conseil sur le jeu PASS : identité ' + cj.identite + ', note ' + Math.round(cj.note) + ', bilan ' + JSON.stringify(bilan) + ', 22 m ' + cj.indicateurs.entrees22.total + ' sur ' + cj.indicateurs.entrees22.matchs + ' matchs');
} finally { b?.close(); }
