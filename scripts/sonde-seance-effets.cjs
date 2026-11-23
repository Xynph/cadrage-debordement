'use strict';
// Sonde (idée FM27 n° 25, 23/11/2026) : blessures à l'entraînement et moral du groupe sur une saison Monde (club 102,
// cadence hebdomadaire, matchs délégués), selon les effets des séances du programme jour par jour.
// Usage : node scripts/sonde-seance-effets.cjs avant|apres|lourd|leger [sortie.json]
//  avant : effets du programme coupés (comme avant le risque et le moral) ;
//  apres : programme proposé par le staff (effets branchés) ;
//  lourd : chaque séance à venir remplacée par « Force » (commande calendar_session), risque maximal ;
//  leger : chaque séance à venir remplacée par « Récupération ».
// Compte les blessures nées pendant la séance collective (club du manager) et le moral moyen.
const fs = require('node:fs');
const { ouvrir, creer, jusquAuMatch, jouerLeMatch, jusquALaSemaineSuivante } = require('../tests/helpers/carriere-monde.cjs');

const mode = ['avant', 'lourd', 'leger'].includes(process.argv[2]) ? process.argv[2] : 'apres';
const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
const vm = jeu.bridge.vm;
const REMPLACE = { lourd: { kind: 'strength', label: 'Force' }, leger: { kind: 'recovery', label: 'Récupération' } }[mode];
try {
  let model = creer(jeu);
  if (mode === 'avant') vm.run('nativeProgrammeDesactive=true');
  // Compteur posé autour de trainWeek (après les crochets du moteur) : nouveaux blessés du club pendant la séance.
  vm.run('nativeSondeBlessures=0;(()=>{const t=globalThis.trainWeek;globalThis.trainWeek=function(){const c=S.clubs[S.club],avant=new Set(c.players.filter(p=>p.injury).map(p=>p.id)),deja=S.trained;const r=t.apply(this,arguments);if(!deja)nativeSondeBlessures+=c.players.filter(p=>p.injury&&!avant.has(p.id)).length;return r;};})()');
  const saison = model.meta.season;
  const remplacer = m => {
    if (!REMPLACE) return m;
    for (const s of m.calendarPlanning?.sessions || []) {
      if (s.completed || (s.kind === REMPLACE.kind && s.label === REMPLACE.label)) continue;
      const r = jeu.brut('calendar_session', { sessionId: s.sourceId || s.id, ...REMPLACE });
      if (r.ok) m = r.model;
    }
    return m;
  };
  const moraux = [];
  let semaines = 0;
  for (let k = 0; k < 40 && model.meta.phase !== 'ended'; k++) {
    model = remplacer(model);
    model = jusquAuMatch(jeu, model);
    if (model.meta.phase === 'ended' || model.meta.season !== saison) break;
    semaines++;
    moraux.push(Number(vm.run('S.morale')));
    model = jouerLeMatch(jeu, model);
    model = jusquALaSemaineSuivante(jeu, model);
  }
  const bilan = { mode, semaines, blessuresEntrainement: Number(vm.run('nativeSondeBlessures')),
    moralMoyen: +(moraux.reduce((n, v) => n + v, 0) / Math.max(1, moraux.length)).toFixed(1), training: vm.run('S.training') };
  console.log(JSON.stringify(bilan));
  if (process.argv[3]) fs.writeFileSync(process.argv[3], JSON.stringify(bilan, null, 1));
} finally {
  jeu.fermer();
}
