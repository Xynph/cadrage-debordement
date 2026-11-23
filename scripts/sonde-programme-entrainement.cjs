'use strict';
// Sonde : une saison Monde (club 102, cadence hebdomadaire, matchs délégués) avec ou sans les effets du programme
// d'entraînement jour par jour (Entraînement › Mois). Moyennes du club par semaine de match : fatigue, condition,
// progression (XP + niveau), semaines types rencontrées, effets appliqués.
// Usage : node scripts/sonde-programme-entrainement.cjs avec|sans|standard [sortie.json]
// standard : semaine type standard imposée à chaque match (calendar_template) ; avec : programme proposé par le staff.
const fs = require('node:fs');
const { ouvrir, creer, jusquAuMatch, jouerLeMatch, jusquALaSemaineSuivante } = require('../tests/helpers/carriere-monde.cjs');

const mode = ['sans', 'standard'].includes(process.argv[2]) ? process.argv[2] : 'avec';
const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true });
const vm = jeu.bridge.vm;
const mesure = () => JSON.parse(vm.run('JSON.stringify((()=>{const ps=S.clubs[S.club].players.filter(p=>!p.injury);const m=f=>ps.reduce((n,p)=>n+f(p),0)/Math.max(1,ps.length);return {fatigue:m(p=>p.physicalLoad?.fatigue??0),condition:m(p=>p.condition),progression:S.clubs[S.club].players.reduce((n,p)=>n+p.rating+(p.dev?.xp??0),0),blesses:S.clubs[S.club].players.filter(p=>p.injury).length}})())'));
const lignes = [];
try {
  let model = creer(jeu);
  if (mode === 'sans') vm.run('nativeProgrammeDesactive=true');
  const depart = mesure();
  const saison = model.meta.season;
  const imposer = m => {
    const p = m.calendarPlanning || {}, today = p.today || '';
    for (const f of p.fixtures || m.calendar || []) {
      if (f.played || !f.date || f.date < today || p.programmeByFixture?.[f.id] === 'standard' || !(f.id in (p.programmeByFixture || {}))) continue;
      const r = jeu.brut('calendar_template', { fixtureId: f.id, template: 'standard' });
      if (r.ok) m = r.model;
    }
    return m;
  };
  for (let k = 0; k < 40 && model.meta.phase !== 'ended'; k++) {
    if (mode === 'standard') model = imposer(model);
    model = jusquAuMatch(jeu, model);
    if (model.meta.phase === 'ended' || model.meta.season !== saison) break;
    if (mode === 'standard') model = imposer(model);
    const semaine = model.calendarPlanning?.week;
    const f = (model.calendarPlanning?.fixtures || model.calendar || []).find(x => x.date && semaine && x.date >= semaine.weekStart && !x.played);
    lignes.push({ semaine: semaine?.weekStart, modele: f ? model.calendarPlanning?.programmeByFixture?.[f.id] ?? null : null, effets: semaine?.effects ?? null, ...mesure() });
    model = jouerLeMatch(jeu, model);
    model = jusquALaSemaineSuivante(jeu, model);
  }
  const moyenne = cle => lignes.reduce((n, l) => n + l[cle], 0) / Math.max(1, lignes.length);
  const modeles = {};
  for (const l of lignes) modeles[l.modele] = (modeles[l.modele] || 0) + 1;
  const bilan = { mode, semaines: lignes.length, fatigue: +moyenne('fatigue').toFixed(2), condition: +moyenne('condition').toFixed(2),
    blesses: +moyenne('blesses').toFixed(2), progression: +(mesure().progression - depart.progression).toFixed(2), modeles };
  console.log(JSON.stringify(bilan));
  if (process.argv[3]) fs.writeFileSync(process.argv[3], JSON.stringify({ bilan, lignes }, null, 1));
} finally {
  jeu.fermer();
}
