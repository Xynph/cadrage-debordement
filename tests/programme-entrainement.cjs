'use strict';
// Programme d'entraînement jour par jour (Entraînement › Mois, 22/11/2026) : les séances de la semaine agissent sur la
// semaine simulée du club, en écart à une semaine de référence (la semaine moyenne du programme proposé par le staff).
//  1. calcul pur (calendar-planning.cjs weekEffects) : standard proche de la référence, matchs rapprochés = plus de repos, bornes ;
//  2. carrière Monde : la projection expose la semaine (`calendarPlanning.week`) ;
//  3. même état, même graine : une semaine au niveau de la référence simule EXACTEMENT comme sans programme ; une semaine allégée
//     (matchs rapprochés) baisse la fatigue et la progression, monte la condition, de la valeur annoncée ;
//  4. risque de blessure et moral (23/11/2026) : une semaine risquée blesse plus à l'entraînement, le moral du groupe
//     bouge de la valeur ; une séance remplacée (commande calendar_session) change la semaine simulée.
const assert = require('node:assert/strict');
const planning = require('../native/engine/calendar-planning.cjs');
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');

const semaine = kinds => kinds.map((kind, i) => ({ date: '2026-09-2' + (1 + Math.min(i, 6)), kind }));
const STANDARD = ['strength', 'team', 'video', 'kicking', 'skills', 'tactics', 'speed', 'recovery'];
const zero = { fatigue: 0, condition: 0, avants: 0, arrieres: 0, cohesion: 0, blessure: 0, moral: 0 };

assert.deepEqual(planning.weekEffects(semaine(STANDARD), '2026-09-23').effects, { fatigue: 1, condition: 0, avants: 2, arrieres: 2, cohesion: 0, blessure: 1, moral: 1 }, 'semaine type standard complète : à un ou deux points de la référence');
const enchainee = STANDARD.filter(kind => kind !== 'strength');
assert.deepEqual(planning.weekEffects(semaine(enchainee), '2026-09-23').effects, { fatigue: -2, condition: 1, avants: -2, arrieres: 0, cohesion: 0, blessure: -1, moral: 2 }, 'semaine standard entre deux matchs (force du lundi remplacée par la récupération)');
const rapproches = planning.weekEffects(semaine(['tactics', 'video', 'speed', 'recovery']), '2026-09-23').effects;
assert.deepEqual(rapproches, { fatigue: -6, condition: 2, avants: -8, arrieres: -6, cohesion: 0, blessure: -4, moral: 0 }, 'matchs rapprochés');
const lourde = planning.weekEffects(semaine(Array(9).fill('strength')), '2026-09-23').effects;
assert.equal(lourde.fatigue, 8, 'fatigue bornée');
assert.equal(lourde.avants, 12, 'progression bornée');
assert.equal(lourde.blessure, 4, 'risque borné');
assert.equal(lourde.moral, -2, 'moral borné');
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
  const essai = (effets, graine = 777, charge = null, tirage = null) => {
    vm.run('S=JSON.parse(' + JSON.stringify(etat) + ');S.trained=false;for(const p of S.clubs[S.club].players){ensurePhysicalLoad(p).fatigue=40;p.condition=60' + (charge ? ';p.physicalLoad.plan=' + JSON.stringify(charge) : '') + '}');
    vm.setSeed(graine);
    vm.run('if(!globalThis.hasardMoteur)globalThis.hasardMoteur=Math.random;Math.random=hasardMoteur');
    if (tirage !== null) vm.run('Math.random=()=>' + tirage);
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

  // Risque de blessure : sur 20 séances (graines), une semaine au risque maximal blesse plus qu'une semaine sans risque,
  // en charge normale (petit tirage ajouté) comme en charge intensive (tirage existant × 1,4) ; risque minimal en
  // intensive : moins de blessures. Mesuré, pas d'explosion : au plus ~0,4 % par joueur et par semaine en normale.
  const blesses = (effets, graine, charge, tirage = null) => {
    // Les blessés d'avant sont ceux de l'état de départ (pas ceux de l'essai précédent, qui fausserait le compte).
    const avant = new Set(JSON.parse(etat).clubs[JSON.parse(etat).club].players.filter(p => p.injury).map(p => p.id));
    return essai(effets, graine, charge, tirage).filter(p => p.injury && !avant.has(p.id)).length;
  };
  const compte = (effets, charge) => { let n = 0; for (let g = 1; g <= 20; g++) n += blesses(effets, 1000 + g, charge); return n; };
  // Charge normale : le tirage ajouté est trop rare (0,4 % au plus, fois la fragilité) pour un test au hasard : on fixe le tirage à 0,0005, sous le seuil de tout joueur fragile,
  // une semaine à risque maximal blesse alors des joueurs en charge normale et une semaine sans risque aucun.
  const normalSans = blesses(zero, 1001, 'normal', 0.0005), normalRisque = blesses({ ...zero, blessure: 4 }, 1001, 'normal', 0.0005);
  const intenseSans = compte(zero, 'intense'), intenseRisque = compte({ ...zero, blessure: 4 }, 'intense'), intenseCalme = compte({ ...zero, blessure: -4 }, 'intense');
  assert.ok(normalRisque > normalSans, 'charge normale : le risque ajoute des blessures (' + normalSans + ' → ' + normalRisque + ')');
  assert.ok(normalRisque - normalSans >= 1, 'charge normale : le tirage fixé blesse au moins un joueur (' + (normalRisque - normalSans) + ')');
  assert.ok(normalSans === 0, 'charge normale sans risque : le tirage fixé ne blesse personne (' + normalSans + ')');
  assert.ok(intenseRisque > intenseSans && intenseCalme < intenseSans, 'charge intensive : risque ' + intenseCalme + ' < ' + intenseSans + ' < ' + intenseRisque);
  // Moral du groupe : la séance collective le bouge de la valeur de la semaine.
  const moral = effets => { essai(effets); return Number(vm.run('S.morale')); };
  const moralSans = moral(zero);
  assert.equal(moral({ ...zero, moral: 2 }), Math.min(98, moralSans + 2), 'moral +2');
  assert.equal(moral({ ...zero, moral: -2 }), Math.max(25, moralSans - 2), 'moral −2');
  vm.run('nativeProgrammeDesactive=false');

  // Commande calendar_session : une séance à venir remplacée change le programme projeté et la semaine simulée.
  vm.run('S=JSON.parse(' + JSON.stringify(etat) + ')');
  let m = jeu.brut('snapshot').model;
  const today = m.calendarPlanning.today;
  const cible = m.calendarPlanning.sessions.find(s => !s.completed && s.date >= today && s.kind !== 'recovery');
  assert.ok(cible, 'une séance à venir');
  const effetsAvant = m.calendarPlanning.weeks;
  const r = jeu.brut('calendar_session', { sessionId: cible.id, kind: 'recovery', label: 'Récupération' });
  assert.equal(r.ok, true, r.error);
  m = r.model;
  const changee = m.calendarPlanning.sessions.find(s => s.sourceId === cible.id);
  assert.ok(changee && changee.kind === 'recovery' && changee.label === 'Récupération' && changee.swapped === true, 'séance remplacée');
  assert.equal(changee.date, cible.date, 'même jour');
  const lundi = Object.keys(m.calendarPlanning.weeks).filter(l => l <= cible.date).sort().pop();
  assert.ok(m.calendarPlanning.weeks[lundi].fatigue < effetsAvant[lundi].fatigue || m.calendarPlanning.weeks[lundi].fatigue === -8, 'la semaine de la séance s\'allège');
  assert.equal(jeu.brut('calendar_session', { sessionId: cible.id, kind: 'recovery', label: 'Inventée' }).ok, false, 'séance hors catalogue refusée');
  m = jeu.brut('calendar_session', { sessionId: cible.id, kind: cible.kind, label: cible.label }).model;
  assert.deepEqual(m.calendarPlanning.sessions.find(s => s.id === cible.id), cible, 'retour à la séance d\'origine');
  assert.deepEqual(m.calendarPlanning.weeks, effetsAvant, 'semaine d\'origine');
} finally {
  jeu.fermer();
}
console.log('Programme d’entraînement : semaine de référence neutre, effets par séance (risque et moral compris) bornés et appliqués au club, séance remplacée.');
