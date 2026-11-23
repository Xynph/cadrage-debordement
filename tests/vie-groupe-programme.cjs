'use strict';
// Panneaux de l'Effectif (21/11/2026) : trois mesures réelles du moteur, lues par l'Effectif, l'Entraînement et le Vestiaire.
//  - clubLife.weekProgram : programme de la semaine jour par jour (programme-semaine.cjs), tiré du calendrier journalier,
//    du match du club et de la séance collective (charge S.training, faite = S.trained) ;
//  - clubLife.relationships.tensions : niveau et joueurs concernés (mécontents, paroles non tenues, duos en rivalité) ;
//  - clubLife.relationships.playerTrust / playerTrustHistory : confiance des joueurs envers le manager (pas celle du
//    conseil, S.trust), relevée chaque semaine comme la trésorerie.
const test = require('node:test');
const assert = require('node:assert/strict');
const M = require('./helpers/carriere-monde.cjs');

const jeu = M.ouvrir({ testVm: true });
test.after(() => jeu.fermer());
const run = source => jeu.bridge.vm.run(source);
const etat = source => JSON.parse(run('JSON.stringify(' + source + ')'));

let model = M.creer(jeu, 102);

test('Programme : sept jours du lundi au dimanche, aujourd’hui repéré, séance unique', () => {
  const w = model.clubLife.weekProgram;
  assert.ok(w, 'programme présent en carrière Monde');
  assert.equal(w.days.length, 7);
  assert.deepEqual(w.days.map(d => d.lettre), ['L', 'M', 'M', 'J', 'V', 'S', 'D']);
  assert.equal(new Date(w.weekStart + 'T00:00:00Z').getUTCDay(), 1, 'la semaine commence un lundi');
  assert.equal(w.today, model.meta.calendarToday);
  assert.equal(w.days[w.todayIndex].date, w.today);
  assert.equal(w.days.filter(d => d.today).length, 1);
  assert.equal(w.days.filter(d => d.kind === 'seance').length, 1, 'une seule séance collective simulée par semaine');
  assert.equal(w.days[w.sessionDay].charge, model.meta.training || 'normal');
});

test('Semaine de match : match le jour de la rencontre, veille, séance à J-3, récupération le lendemain', () => {
  model = M.jusquAuMatch(jeu, model);
  const w = model.clubLife.weekProgram, f = etat('CDWorldCareer.userFixture(S)');
  assert.equal(w.matchDay, w.todayIndex, 'jour de match = aujourd’hui');
  const m = w.days[w.matchDay];
  assert.equal(m.kind, 'match');
  assert.equal(m.date, f.date);
  assert.equal(m.fixtureId, f.id);
  if (w.matchDay >= 1) assert.equal(w.days[w.matchDay - 1].kind, 'veille');
  if (w.matchDay >= 3) assert.equal(w.sessionDay, w.matchDay - 3);
  if (w.matchDay <= 5) assert.equal(w.days[w.matchDay + 1].kind, 'recuperation');
});

test('Séance effectuée : le jour de la séance passe à fait, la charge suit le choix', () => {
  if (!model.meta.trained) model = jeu.call('train', { mode: 'intense' });
  const w = model.clubLife.weekProgram;
  assert.equal(w.trained, true);
  assert.equal(w.days[w.sessionDay].done, true);
  assert.equal(w.charge, etat('S.training'));
});

test('Relevé hebdomadaire de la confiance du groupe dans groupHistory, daté comme la trésorerie', () => {
  model = M.jouerLeMatch(jeu, jeu.regler(model));
  model = M.jusquALaSemaineSuivante(jeu, model);
  const h = model.clubLife.relationships.playerTrustHistory, cash = model.finance.cashHistory;
  assert.ok(h.length >= 1, 'un relevé après la semaine jouée');
  const dernier = h[h.length - 1];
  assert.ok(cash.some(c => c.date === dernier.date), 'même date que le relevé de trésorerie');
  assert.ok(Number.isInteger(dernier.confiance));
  assert.equal(model.groupHistory.at(-1).confiance, dernier.confiance, 'même relevé que le moral et la condition (groupHistory)');
});

test('Ancienne sauvegarde : sans relevé, la confiance et les tensions sont calculées au chargement', () => {
  run('delete S.groupHistory;validateCareer(S)');
  const r = etat("nativeSystems.domain('relationships').project()");
  assert.deepEqual(r.playerTrustHistory, []);
  assert.ok(Number.isInteger(r.playerTrust));
  assert.ok(r.tensions && Array.isArray(r.tensions.players));
});

test('Confiance des joueurs : agrégat des confiances individuelles, distinct du conseil', () => {
  const r = model.clubLife.relationships;
  assert.ok(Number.isInteger(r.playerTrust) && r.playerTrust >= 0 && r.playerTrust <= 100);
  assert.equal(r.trust, etat('S.trust'), 'trust reste la confiance du conseil');
  for (const p of r.players) assert.ok(Number.isInteger(p.trust) && p.trust >= 0 && p.trust <= 100);
  // Une promesse non tenue fait baisser la confiance du joueur concerné.
  const id = r.players[0].id, avant = r.players[0].trust;
  run(`(()=>{const p=S.clubs[S.club].players.find(x=>x.id===${JSON.stringify(id)});p.satisfaction.history.push({season:S.season,round:S.round,status:'broken',minutes:0,target:'titulaire'});})()`);
  const apres = etat(`nativeSystems.domain('relationships').playerTrust(S.clubs[S.club].players.find(x=>x.id===${JSON.stringify(id)}))`);
  assert.ok(apres < avant, 'parole non tenue : confiance en baisse');
});

test('Tensions : mécontents et paroles non tenues listés, niveau qui monte', () => {
  const calme = etat("nativeSystems.domain('relationships').tensions()");
  run(`(()=>{const ps=S.clubs[S.club].players,d=ps.find((x,i)=>i>2&&x.fam===ps[2].fam);ps[1].satisfaction.score=25;ps[2].satisfaction.score=40;d.satisfaction.score=40;})()`);
  const t = etat("nativeSystems.domain('relationships').tensions()");
  const ids = etat('(()=>{const ps=S.clubs[S.club].players;return [ps[0].id,ps[1].id,ps[2].id,ps.find((x,i)=>i>2&&x.fam===ps[2].fam).id];})()');
  assert.ok(t.score > calme.score);
  assert.ok(t.level >= 2, 'plusieurs mécontents et une parole rompue : tension vive');
  const row = id => t.players.find(p => p.id === id);
  assert.deepEqual(row(ids[0]).raisons.includes('promesse'), true);
  assert.equal(row(ids[1]).raisons.includes('mecontent'), true);
  assert.equal(t.players[0].id, ids[1], 'le plus touché en tête');
  assert.ok(t.duos.some(d => [d.a, d.b].sort().join() === [ids[2], ids[3]].sort().join()), 'deux insatisfaits du même poste : duo à risque');
});

