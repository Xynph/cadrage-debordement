'use strict';
// Programme d'entraînement jour par jour (Entraînement › Mois, 22/11/2026) : les séances de la semaine agissent sur la
// semaine simulée du club, en écart à une semaine de référence (la semaine moyenne du programme proposé par le staff).
//  1. calcul pur (calendar-planning.cjs weekEffects) : standard proche de la référence, matchs rapprochés = plus de repos, bornes ;
//  2. carrière Monde : la projection expose la semaine (`calendarPlanning.week`) ;
//  3. même état, même graine : une semaine au niveau de la référence simule EXACTEMENT comme sans programme ; une semaine allégée
//     (matchs rapprochés) baisse la fatigue et la progression, monte la condition, de la valeur annoncée.
const assert = require('node:assert/strict');
const planning = require('../native/engine/calendar-planning.cjs');
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');

const semaine = kinds => kinds.map((kind, i) => ({ date: '2026-09-2' + (1 + Math.min(i, 6)), kind }));
const STANDARD = ['strength', 'team', 'video', 'kicking', 'skills', 'tactics', 'speed', 'recovery'];
const zero = { fatigue: 0, condition: 0, avants: 0, arrieres: 0, cohesion: 0 };

assert.deepEqual(planning.weekEffects(semaine(STANDARD), '2026-09-23').effects, { fatigue: 1, condition: 0, avants: 2, arrieres: 2, cohesion: 0 }, 'semaine type standard complète : à un ou deux points de la référence');
const enchainee = STANDARD.filter(kind => kind !== 'strength');
assert.deepEqual(planning.weekEffects(semaine(enchainee), '2026-09-23').effects, { fatigue: -2, condition: 1, avants: -2, arrieres: 0, cohesion: 0 }, 'semaine standard entre deux matchs (force du lundi remplacée par la récupération)');
const rapproches = planning.weekEffects(semaine(['tactics', 'video', 'speed', 'recovery']), '2026-09-23').effects;
assert.deepEqual(rapproches, { fatigue: -6, condition: 2, avants: -8, arrieres: -6, cohesion: 0 }, 'matchs rapprochés');
const lourde = planning.weekEffects(semaine(Array(9).fill('strength')), '2026-09-23').effects;
assert.equal(lourde.fatigue, 8, 'fatigue bornée');
assert.equal(lourde.avants, 12, 'progression bornée');
assert.equal(planning.weekEffects(semaine(STANDARD), '2026-09-29').counts.strength, 0, 'autre semaine : séances non comptées');
assert.equal(planning.weekEffects([], 'pas une date'), null);
assert.deepEqual(planning.weekEffects([], '2026-09-23').effects, zero, 'semaine sans séance : rien ne change');

const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
try {
  const model = creer(jeu);
  const week = model.calendarPlanning?.week;
  assert.ok(week && /^\d{4}-\d{2}-\d{2}$/.test(week.weekStart), 'semaine du programme projetée');
  const vm = jeu.bridge.vm;
  const etat = vm.run('JSON.stringify(S)');
  const essai = (effets) => {
    vm.run('S=JSON.parse(' + JSON.stringify(etat) + ');S.trained=false;for(const p of S.clubs[S.club].players){ensurePhysicalLoad(p).fatigue=40;p.condition=60}');
    vm.setSeed(777);
    vm.run(effets ? 'nativeProgrammeDesactive=false;nativeProgrammeEffets={season:S.season,round:S.round,effects:' + JSON.stringify(effets) + '}' : 'nativeProgrammeDesactive=true');
    vm.run('trainWeek()');
    return JSON.parse(vm.run('JSON.stringify(S.clubs[S.club].players.map(p=>({id:p.id,injury:p.injury,condition:p.condition,fatigue:p.physicalLoad?.fatigue??null,xp:p.dev?.xp??0,rating:p.rating})))'));
  };
  const sans = essai(null), standard = essai(zero), leger = essai(rapproches);
  assert.deepEqual(standard, sans, 'semaine de référence : simulation identique à la seule charge hebdomadaire');
  const valides = sans.map((p, i) => [p, leger[i]]).filter(([p]) => !p.injury);
  assert.ok(valides.length > 10, 'joueurs valides');
  const moyenne = f => valides.reduce((n, pair) => n + f(pair), 0) / valides.length;
  const dFatigue = moyenne(([a, b]) => (b.fatigue ?? 0) - (a.fatigue ?? 0));
  const dCondition = moyenne(([a, b]) => b.condition - a.condition);
  assert.ok(dFatigue < -4 && dFatigue >= -6, 'matchs rapprochés : fatigue en baisse (' + dFatigue + ')');
  assert.ok(dCondition > 0 && dCondition <= 2, 'matchs rapprochés : condition en hausse (' + dCondition + ')');
  assert.ok(moyenne(([a, b]) => (b.xp + b.rating) - (a.xp + a.rating)) <= 0, 'matchs rapprochés : progression pas plus forte');
  vm.run('nativeProgrammeDesactive=false');
} finally {
  jeu.fermer();
}
console.log('Programme d’entraînement : semaine de référence neutre, effets par séance bornés et appliqués au club.');
