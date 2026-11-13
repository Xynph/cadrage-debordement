#!/usr/bin/env node
'use strict';
// Validation des feuilles de statistiques (native/engine/match-stats.cjs) sur N matchs simulés par le
// vrai moteur (dist/, même harnais que les tests) : moyennes par poste (ramenées à 80 minutes, joueurs
// ayant joué au moins 40 minutes) et par équipe, comparées aux références réelles de
// docs/stats-match-realistes-20261113.md.
// Usage : node scripts/stats-match-validation.cjs [nombre=120] [--json]
const { context } = require('../tests/harness.cjs');
const MS = require('../native/engine/match-stats.cjs');

const GROUPES = [
 ['Piliers', [0, 2]], ['Talonneur', [1]], ['2e ligne', [3, 4]], ['Flankers', [5, 6]], ['N° 8', [7]],
 ['Demi de mêlée', [8]], ['Demi d’ouverture', [9]], ['Centres', [11, 12]], ['Ailiers', [10, 13]], ['Arrière', [14]]
];
const CHAMPS = ['plaquages', 'plaquagesManques', 'courses', 'metres', 'defenseursBattus', 'passes', 'offloads', 'soutiensRuck', 'coupsDePied', 'metresAuPied'];
const EQUIPE = ['plaquages', 'plaquagesManques', 'reussitePlaquage', 'courses', 'metres', 'franchissements', 'defenseursBattus', 'passes', 'offloads', 'rucks', 'recuperations', 'ballonsPerdus', 'penalitesConcedees', 'enAvant', 'coupsDePied', 'metresAuPied'];

function simuler(nombre) {
 const t = context();
 t.run('start(0)');
 const clubs = t.run('S.clubs.length');
 const matchs = [];
 for (let k = 0; k < nombre; k++) {
  const adversaire = 1 + (k % (clubs - 1));
  const domicile = k % 2 === 0;
  const res = JSON.parse(t.run(`(()=>{const pair=${domicile ? `[S.club,${adversaire}]` : `[${adversaire},S.club]`};const l=createRugbyMatch(pair);for(let n=0;!l.finished;n++){if(n>4000)throw Error('boucle');l.paused=false;advanceRugby(l)}
   const joueurs={};for(const ci of pair)for(const p of S.clubs[ci].players)joueurs[p.id]={skills:p.skills};
   return JSON.stringify({cle:'validation:${k}:'+pair.join('-'),events:l.events,score:l.score,tries:l.tries,stats:l.stats,tactical:l.tacticalStats,joueurs});})()`));
  matchs.push(res);
 }
 return matchs;
}

function mesurer(matchs) {
 const parPoste = new Map(GROUPES.map(([nom]) => [nom, { n: 0, minutes: 0, ...Object.fromEntries(CHAMPS.map(c => [c, 0])), valeurs: [] }]));
 const equipes = { n: 0, ...Object.fromEntries(EQUIPE.map(c => [c, 0])) };
 const ecarts = [];
 for (const m of matchs) {
  const f = MS.feuilleStatistiques(m.events, { cle: m.cle, joueurs: m.joueurs });
  for (const s of [0, 1]) {
   const e = f.equipes[s];
   equipes.n++;
   for (const c of EQUIPE) equipes[c] += e[c] ?? 0;
   const points = Object.values(f.joueurs).filter(j => j.camp === s).reduce((a, j) => a + j.points, 0);
   if (points !== m.score[s]) ecarts.push({ cle: m.cle, camp: s, points, score: m.score[s] });
  }
  for (const j of Object.values(f.joueurs)) {
   if (j.minutes < 40) continue;
   const groupe = GROUPES.find(([, postes]) => postes.includes(j.numero - 1));
   if (!groupe) continue;
   const g = parPoste.get(groupe[0]);
   g.n++; g.minutes += j.minutes;
   for (const c of CHAMPS) g[c] += j[c] * 80 / j.minutes;
   if (j.minutes >= 70) g.valeurs.push(j.plaquages);
  }
 }
 const poste = GROUPES.map(([nom]) => {
  const g = parPoste.get(nom), o = { poste: nom, joueurs: g.n };
  for (const c of CHAMPS) o[c] = g.n ? Math.round(g[c] / g.n * 10) / 10 : null;
  const v = g.valeurs.sort((a, b) => a - b);
  o.plaquagesP10P90 = v.length ? [v[Math.floor(v.length * .1)], v[Math.floor(v.length * .9)]] : null;
  return o;
 });
 const equipe = Object.fromEntries(EQUIPE.map(c => [c, Math.round(equipes[c] / equipes.n * 10) / 10]));
 return { matchs: matchs.length, poste, equipe, ecartsPoints: ecarts };
}

if (require.main === module) {
 const nombre = Number(process.argv[2]) || 120;
 const debut = Date.now();
 const resultat = mesurer(simuler(nombre));
 resultat.duree = Math.round((Date.now() - debut) / 1000) + ' s';
 if (process.argv.includes('--json')) console.log(JSON.stringify(resultat, null, 1));
 else {
  console.log(`${resultat.matchs} matchs (${resultat.duree}) — écarts de points : ${resultat.ecartsPoints.length}`);
  console.table(resultat.poste);
  console.table(resultat.equipe);
 }
}
module.exports = { simuler, mesurer, GROUPES };
