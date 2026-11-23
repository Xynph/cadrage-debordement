'use strict';
// Mesure de la progression des qualités (36 attributs) sur une saison Monde complète, transition comprise
// (idée FM27 n° 14, progression étalée sur la saison) : progression totale par tranche d'âge et régularité.
// Chaque semaine : moyenne des 36 qualités et niveau de chaque joueur (clubs, agents libres, centre du club).
// Usage : node --max-old-space-size=3000 scripts/mesure-progression-saison.cjs [graine=827381] [club=102] [sortie.json]
// Sortie : progression totale (moyenne des 36 qualités, début de saison → après la transition) par tranche d'âge ;
// à-coups : part de la progression faite en une seule semaine, part faite à la transition, plus gros pas mensuel.
const fs = require('node:fs');
const vm = require('node:vm'), runInContext = vm.runInContext;
vm.runInContext = (code, ctx, options) => runInContext(code, ctx, { ...options, timeout: Math.max(options?.timeout ?? 0, 180000) });
const { context } = require('../tests/monde-harness.cjs');

const GRAINE = Number(process.argv[2] || 827381), CLUB = Number(process.argv[3] || 102), SORTIE = process.argv[4] || null;
const RELEVE = `JSON.stringify((()=>{const out={};const vu=p=>{if(!p||out[p.id]||!p.attributesV2)return;const v=Object.values(p.attributesV2);
 if(v.length!==36)return;out[p.id]=[Math.round(v.reduce((a,b)=>a+b,0)/36*1000)/1000,p.rating,p.age];};
 for(const c of S.clubs)for(const p of c.players||[])vu(p);for(const p of S.economy?.freeAgents||[])vu(p);for(const p of S.development?.academy||[])vu(p);
 return {date:CDWorldCareer.calendarToday(S),joueurs:out};})())`;

const t0 = Date.now();
const h = context(GRAINE, { club: CLUB, console: false });
const releves = [];
let taille = null;
try {
  releves.push(JSON.parse(h.run(RELEVE)));
  for (let garde = 0; garde < 80 && h.run("S.phase!=='ended'"); garde++) { h.week(1, { validate: false }); releves.push(JSON.parse(h.run(RELEVE))); }
  h.run('validateCareer(S)');
  h.run('delete S.clubMeetings');
  h.command('next_season', { confirmed: true });
  releves.push(JSON.parse(h.run(RELEVE)));
  // Taille de la sauvegarde (texte de la carrière) avec et sans le relevé mensuel et la progression en attente.
  taille = JSON.parse(h.run(`JSON.stringify({total:JSON.stringify(S).length,sans:JSON.stringify(S,(k,v)=>k==='rq'||k==='etale'||k==='releveQualites'?undefined:v).length})`));
} finally { h.close(); }

const debut = releves[0].joueurs, fin = releves.at(-1).joueurs, avantTransition = releves.at(-2).joueurs;
const tranche = age => age <= 22 ? '≤22' : age <= 26 ? '23-26' : age <= 30 ? '27-30' : '31+';
const bandes = {};
const moy = v => v.length ? Math.round(v.reduce((a, b) => a + b, 0) / v.length * 1000) / 1000 : null;
for (const [id, [m0, , age]] of Object.entries(debut)) {
  if (!fin[id]) continue; // parti à la retraite ou hors du monde
  const b = bandes[tranche(age)] || (bandes[tranche(age)] = { n: 0, total: [], niveau: [], transition: [], plusGrosseSemaine: [], partPlusGrosseSemaine: [], plusGrosMois: [] });
  const serie = releves.map(r => r.joueurs[id]?.[0]).filter(v => v !== undefined);
  const total = fin[id][0] - m0;
  b.n++; b.total.push(total); b.niveau.push(fin[id][1] - debut[id][1]);
  b.transition.push(avantTransition[id] ? fin[id][0] - avantTransition[id][0] : 0);
  let gros = 0; for (let k = 1; k < serie.length; k++) gros = Math.max(gros, Math.abs(serie[k] - serie[k - 1]));
  b.plusGrosseSemaine.push(gros);
  if (Math.abs(total) >= .5) b.partPlusGrosseSemaine.push(gros / Math.abs(total));
  let grosMois = 0; for (let k = 4; k < serie.length; k += 4) grosMois = Math.max(grosMois, Math.abs(serie[k] - serie[k - 4]));
  b.plusGrosMois.push(grosMois);
}
const resume = {};
for (const [k, b] of Object.entries(bandes)) resume[k] = {
  joueurs: b.n, progressionMoyenne: moy(b.total), niveauMoyen: moy(b.niveau), aLaTransition: moy(b.transition),
  plusGrosseSemaineMoyenne: moy(b.plusGrosseSemaine), partEnUneSemaine: moy(b.partPlusGrosseSemaine), plusGrosPas4Semaines: moy(b.plusGrosMois),
};
const tous = Object.values(bandes).flatMap(b => b.total);
const rapport = { graine: GRAINE, club: CLUB, semaines: releves.length - 2, de: releves[0].date, a: releves.at(-1).date, duree: Math.round((Date.now() - t0) / 1000),
  joueurs: tous.length, progressionMoyenne: moy(tous), parTranche: resume,
  taille: taille && { sauvegarde: taille.total, releve: taille.total - taille.sans, part: Math.round((taille.total - taille.sans) / taille.sans * 1000) / 10 + ' %' } };
console.log(JSON.stringify(rapport, null, 1));
if (SORTIE) fs.writeFileSync(SORTIE, JSON.stringify({ rapport, releves }, null, 0));
