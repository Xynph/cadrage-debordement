'use strict';
// Humeur unique des supporters (revue FM27, idée n° 15, choix de Léo du 23/11/2026) : l'humeur des tribunes
// (club-strategy.cjs) remplace l'ancien « sentiment » ; elle fait varier, modestement et de façon déterministe :
//  1. le public des matchs à domicile du club du manager et sa billetterie (club-budget.cjs, facteurHumeur :
//     ×0,90 à humeur 0, ×1,10 à humeur 100, neutre à 50 ou inconnue) ;
//  2. la demande et l'affluence prévues (fan-experience-v111-v116.js, forecast) ;
//  3. le bilan du conseil (board-planning.js + career-integration.js : supporters 10 %, résultats 60 %).
// Puis, dans le vrai moteur (carrière Monde) : projection sans « sentiment », humeur = anneau des tribunes,
// branchements budget / conseil / affluence lus sur cette humeur, bilan du conseil qui l'enregistre.
const assert = require('node:assert/strict'), fs = require('node:fs'), path = require('node:path'), os = require('node:os');
const B = require('../native/engine/club-budget.cjs');
const BoardPlanning = require('../dist/board-planning.js');
const Fans = require('../dist/fan-experience-v111-v116.js');

// 1. Facteur et public : déterministes, bornés, neutres sans humeur.
assert.equal(B.facteurHumeur(50), 1);
assert.equal(B.facteurHumeur(null), 1);
assert.equal(B.facteurHumeur(undefined), 1);
assert.equal(B.facteurHumeur(0), 0.9);
assert.equal(B.facteurHumeur(100), 1.1);
assert.equal(B.facteurHumeur(-20), 0.9, 'borné');
assert.equal(B.facteurHumeur(140), 1.1, 'borné');
const match = humeur => B.spectateurs({ capacite: 12000, resultats: ['V', 'D', 'N'], cle: '29|1|f1', humeur });
const neutre = match(null);
assert.equal(match(50), neutre, 'humeur 50 = public d’avant');
assert.equal(match(27), match(27), 'déterministe');
assert.ok(match(27) < neutre && match(80) > neutre, 'le public suit l’humeur : ' + [match(27), neutre, match(80)].join(' / '));
assert.ok(Math.abs(match(0) - neutre) / neutre <= 0.12 && Math.abs(match(100) - neutre) / neutre <= 0.12, 'effet modeste');
assert.equal(B.spectateurs({ capacite: 12000, resultats: [], cle: 'x', phase: 'final', humeur: 0 }), 11640, 'phase finale : stade plein quoi qu’il arrive');
// Billetterie d'une réception : exactement le facteur de l'humeur ; boutique et autres recettes inchangées.
const forces = [...Array.from({ length: 14 }, (_, i) => ({ id: i, division: 'elite', base: 70 + i })), ...Array.from({ length: 16 }, (_, i) => ({ id: 14 + i, division: 'accession', base: 60 + i }))];
const semaine = humeur => B.semaine({ forces, clubId: 3, masseHebdo: 60000, semaines: 34, domicile: true, alea: 0.5, libelle: 'S', resultats: ['V', 'N'], humeur });
const billet = ecritures => ecritures.find(e => e.title === 'S · Billetterie').amount;
const autres = ecritures => ecritures.filter(e => e.title !== 'S · Billetterie').map(e => e.amount);
assert.deepEqual(semaine(50), semaine(null), 'humeur 50 = semaine d’avant');
assert.ok(Math.abs(billet(semaine(100)) / billet(semaine(50)) - 1.1) < 2e-3 && Math.abs(billet(semaine(0)) / billet(semaine(50)) - 0.9) < 2e-3, 'billetterie ×0,90 à ×1,10');
assert.deepEqual(autres(semaine(0)), autres(semaine(100)), 'seule la billetterie bouge');

// 2. Demande prévue : 35 + humeur / 2 (+ campagne, accueil, prix), comme l'ancien sentiment.
const etat = () => ({ season: 1, club: 0, live: false, phase: 'league', clubs: [{ cash: 100000, stadiumCapacity: 12000, players: [] }] });
assert.equal(Fans.forecast(etat(), 27).demand, 49);
assert.equal(Fans.forecast(etat(), 50).demand, 60);
assert.equal(Fans.forecast(etat()).demand, 60, 'humeur inconnue = neutre');

// 3. Conseil : supporters 10 % (pris aux résultats), sans changer le calcul quand l'humeur est absente.
const sans = BoardPlanning.boardConfidence({ current: 60, results: 50, finances: 70, youth: 50, weights: { results: .7, finances: .2, youth: .1 }, pull: .7 });
const avec = h => BoardPlanning.boardConfidence({ current: 60, results: 50, finances: 70, youth: 50, supporters: h, weights: { results: .6, finances: .2, youth: .1, supporters: .1 }, pull: .7 });
assert.equal(avec(50).next, sans.next, 'humeur égale aux résultats : même confiance');
assert.ok(avec(27).next < sans.next && avec(80).next > sans.next, 'le conseil suit l’humeur : ' + [avec(27).next, sans.next, avec(80).next].join(' / '));
assert.throws(() => BoardPlanning.boardConfidence({ current: 60, results: 50, finances: 70, youth: 50, weights: { results: .6, finances: .2, youth: .1, supporters: .1 } }), /invalide/, 'humeur exigée avec son poids');
assert.throws(() => BoardPlanning.boardConfidence({ current: 60, results: 50, finances: 70, youth: 50, supporters: 50, weights: { results: .7, finances: .2, youth: .1, supporters: .1 } }), /invalide/, 'poids sur 100 %');

// 4. Vrai moteur, carrière Monde.
const Module = require('node:module'), workerPath = path.resolve(__dirname, '../native/engine/worker.cjs'), workerSource = fs.readFileSync(workerPath, 'utf8'), needle = 'return {handle,close};';
assert.equal(workerSource.split(needle).length, 2);
const instrumented = new Module(workerPath, module); instrumented.filename = workerPath; instrumented.paths = Module._nodeModulePaths(path.dirname(workerPath));
instrumented._compile(workerSource.replace(needle, 'return {handle,close,inspect:run};'), workerPath);
const { createBridge } = instrumented.exports;
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { playNextMatch } = require('./helpers/monde-matchs.cjs');
const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-supporters-humeur-'));
let b, seq = 0;
const call = (command, payload = {}) => { const r = b.handle({ id: ++seq, command, payload }); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
try {
  b = createBridge({ dataDir: root, seed: 31, now: 1700000000000 });
  let m = settleClubMeetings(call('new_career', { mode: 'world-champ', club: 29 }), call);
  const fans = m.clubLife.clubStrategy.fans;
  assert.equal(fans.sentiment, undefined, 'plus de sentiment dans la projection');
  assert.ok(Number.isInteger(fans.humeur), 'humeur des supporters : ' + fans.humeur);
  assert.equal(fans.supporters.mood, fans.humeur, 'une seule humeur : celle de l’anneau des tribunes');
  assert.equal(fans.supporters.segments.length, 6, 'six groupes');
  assert.equal(fans.humeurPublic, Math.round(100 * (B.facteurHumeur(fans.humeur) - 1)), 'effet affiché = effet appliqué');
  assert.equal(fans.demand, Fans.forecast({ season: 1, club: 0, clubs: [{ stadiumCapacity: fans.capacity }] }, fans.humeur).demand, 'demande lue sur l’humeur');
  assert.equal(Number(b.inspect('nativeSystems.domain("clubStrategy").humeur()')), fans.humeur, 'humeur du moteur = humeur affichée');
  assert.equal(b.inspect('JSON.stringify(S.v111to116?.sentiment)'), undefined, 'rien de sauvegardé sous l’ancien nom');
  // Branchements : budget (billetterie), affluence des matchs et conseil lisent la même humeur.
  assert.equal(Number(b.inspect('budgetHumeur()')), fans.humeur);
  assert.equal(Number(b.inspect('careerBoardFans()')), fans.humeur);
  // Premier bilan du conseil (tous les 3 matchs) : l'humeur y figure, avec son poids.
  for (let i = 0; i < 12 && !(m.clubLife.clubStrategy.finance.boardHistory || []).length; i++) m = playNextMatch(m, call);
  const bilan = m.clubLife.clubStrategy.finance.boardHistory[0];
  assert.ok(bilan && Number.isInteger(bilan.supporters), 'bilan du conseil : note des supporters ' + JSON.stringify(bilan));
  assert.equal(bilan.score, Math.round(.6 * bilan.results + .2 * bilan.finances + .1 * bilan.youth + .1 * bilan.supporters), 'poids 60/20/10/10');
  // Affluence enregistrée des matchs à domicile du club : bornée par la capacité, présente.
  const domicile = JSON.parse(b.inspect('JSON.stringify(S.history.filter(r=>r.pair[0]===S.club&&!r.neutral&&r.season===S.season).map(r=>r.affluence))'));
  assert.ok(domicile.every(n => Number.isInteger(n) && n > 0 && n <= fans.capacity), 'affluence à domicile : ' + domicile.join(', '));
  // Sauvegarde relue telle quelle.
  const saved = call('export').meta.exportText; call('shutdown'); b = createBridge({ dataDir: root }); assert.equal(call('export').meta.exportText, saved);
  console.log('Humeur des supporters PASS : public ' + [match(27), neutre, match(80)].join(' / ') + ' (humeur 27 / 50 / 80), conseil ' + [avec(27).next, sans.next, avec(80).next].join(' / ') + ', bilan ' + JSON.stringify(bilan));
} finally { b?.close(); }
