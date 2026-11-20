'use strict';
// Limite de masse des clubs gérés votée avec le budget de la saison (docs/gdd/calendrier-mutations.md § 3 quinquies,
// décision 5). Carrière Monde (world-champ), club 102. Le niveau (base) des clubs bouge à l'arrivée des espoirs, juste
// après la remise à niveau des contrats de l'intersaison : il ne doit plus recalculer la limite en cours de saison, sinon
// un club recalé sous sa limite se retrouve 25 à 30 % au-dessus (mesure du 20/11/2026). Au budget suivant, la limite
// suit de nouveau le niveau du club.
const assert = require('node:assert/strict');
const { ouvrir } = require('./helpers/carriere-monde.cjs');

const jeu = ouvrir({ testVm: true, hebdomadaire: true });
try {
  jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'premiers-clubs', varyCurrent: true }));
  const run = src => JSON.parse(jeu.bridge.vm.run(src));
  const limites = `JSON.stringify(Object.fromEntries(S.clubs.filter(c=>c.id!==S.club).map(c=>[c.id,aiRosterWageLimit(c)])))`;
  // Début de saison 2 : budget voté (comme worldNewSeason), puis le niveau de chaque club géré bouge de ±2 (espoirs).
  const avant = run(`(()=>{S.season=2;budgetOuvrir(false,true);return ${limites};})()`);
  const apres = run(`(()=>{for(const c of S.clubs)if(c.id!==S.club)c.base=Math.max(57,Math.min(95,c.base+(c.id%2?2:-2)));return ${limites};})()`);
  const bouges = Object.keys(avant).filter(id => apres[id] !== avant[id]);
  assert.deepEqual(bouges, [], 'Limite de masse inchangée en cours de saison quand le niveau des clubs bouge : ' + bouges.slice(0, 5).map(id => id + ' ' + avant[id] + ' → ' + apres[id]).join(', '));
  // Le niveau est noté avec le budget de la saison (sauvegardé).
  assert.equal(run(`JSON.stringify(S.clubs.filter(c=>c.id!==S.club).every(c=>Number.isFinite(S.clubBudget.clubs[c.id].base)))`), true, 'Niveau des clubs noté dans le budget de la saison');
  // Budget de la saison suivante : la limite suit de nouveau le niveau (au moins un club de Championship change).
  const suivante = run(`(()=>{S.season=3;budgetOuvrir(false,true);return ${limites};})()`);
  const champ = run(`JSON.stringify(S.worldMode.leagues.champ.members.filter(id=>id!==S.club))`);
  assert.ok(champ.some(id => suivante[id] !== apres[id]), 'Au budget suivant, la limite suit le nouveau niveau');
  console.log('limite de masse votée avec le budget de la saison : OK');
} finally { jeu.fermer(); }
