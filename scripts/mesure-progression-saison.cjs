'use strict';
// Mesure de la progression des qualités (36 attributs) sur une saison Monde complète, transition comprise
// (idée FM27 n° 14, progression étalée sur la saison) : progression totale par tranche d'âge et régularité.
// Chaque semaine : moyenne des 36 qualités et niveau de chaque joueur (clubs, agents libres, centre du club).
// Usage : node --max-old-space-size=3000 scripts/mesure-progression-saison.cjs [graine=827381] [club=102] [sortie.json] [--sans-cible]
// --sans-cible : progression répartie également sur les 36 qualités (comme avant l'entraînement ciblé du 24/11/2026).
// En plus (24/11/2026) : compétences de match moyennes (force réelle en match), profils générés (qualités entières),
// note au poste (roleNote), concentration de la progression (part du gain des 36 portée par les 8 qualités qui ont le plus monté).
// Sortie : progression totale (moyenne des 36 qualités, début de saison → après la transition) par tranche d'âge ;
// à-coups : part de la progression faite en une seule semaine, part faite à la transition, plus gros pas mensuel.
const fs = require('node:fs');
const vm = require('node:vm'), runInContext = vm.runInContext;
vm.runInContext = (code, ctx, options) => runInContext(code, ctx, { ...options, timeout: Math.max(options?.timeout ?? 0, 180000) });
const { context } = require('../tests/monde-harness.cjs');

const ARGS = process.argv.slice(2).filter(a => !a.startsWith('--')), SANS_CIBLE = process.argv.includes('--sans-cible');
const GRAINE = Number(ARGS[0] || 827381), CLUB = Number(ARGS[1] || 102), SORTIE = ARGS[2] || null;
const RELEVE = `JSON.stringify((()=>{const out={};const vu=p=>{if(!p||out[p.id])return;let a=p.attributesV2,gen=false;
 if(!a&&typeof p.nativeAttributesV1==='string'){try{a=nativeAttributeStore.project(p).attributesV2;gen=true;}catch(e){a=null;}}if(!a)return;const v=Object.values(a);
 if(v.length!==36)return;const sk=Object.keys(ATTR).map(k=>skill(p,k));
 out[p.id]=[Math.round(v.reduce((a,b)=>a+b,0)/36*1000)/1000,p.rating,p.age,Math.round(sk.reduce((a,b)=>a+b,0)/sk.length*100)/100,gen?1:0,v.map(x=>Math.round(x*10)/10),Math.round(roleNote(p)*100)/100];};
 for(const c of S.clubs)for(const p of c.players||[])vu(p);for(const p of S.economy?.freeAgents||[])vu(p);for(const p of S.development?.academy||[])vu(p);
 return {date:CDWorldCareer.calendarToday(S),joueurs:out};})())`;

const t0 = Date.now();
const h = context(GRAINE, { club: CLUB, console: false });
if (SANS_CIBLE) h.run("nativeSystems.domain('entrainementCible').poids=()=>null");
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
  taille = JSON.parse(h.run(`JSON.stringify({total:JSON.stringify(S).length,sans:JSON.stringify(S,(k,v)=>k==='rq'||k==='rh'||k==='etale'||k==='releveQualites'?undefined:v).length})`));
} finally { h.close(); }

const debut = releves[0].joueurs, fin = releves.at(-1).joueurs, avantTransition = releves.at(-2).joueurs;
const tranche = age => age <= 22 ? '≤22' : age <= 26 ? '23-26' : age <= 30 ? '27-30' : '31+';
const bandes = {};
const moy = v => v.length ? Math.round(v.reduce((a, b) => a + b, 0) / v.length * 1000) / 1000 : null;
const competences = [], notes = [], concentration = [], generes = [];
for (const [id, [m0, , age, sk0, gen, v0]] of Object.entries(debut)) {
  if (!fin[id]) continue; // parti à la retraite ou hors du monde
  competences.push(fin[id][3] - sk0); notes.push(fin[id][6] - debut[id][6]);
  if (gen) generes.push(fin[id][0] - m0);
  // Concentration : sur le gain de la saison (avant transition), part portée par les 8 qualités qui ont le plus monté.
  const g = (avantTransition[id] || fin[id])[5].map((x, i) => x - v0[i]), gains = g.filter(x => x > 0).sort((a, b) => b - a);
  const tot = gains.reduce((a, b) => a + b, 0);
  if (tot >= 3) concentration.push(gains.slice(0, 8).reduce((a, b) => a + b, 0) / tot);
  if (gen) continue;
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
  sansCible: SANS_CIBLE, joueurs: tous.length, progressionMoyenne: moy(tous), parTranche: resume,
  competencesMoyennes: moy(competences), noteAuPosteMoyenne: moy(notes), generes: { joueurs: generes.length, progressionMoyenne: moy(generes) },
  partDes8QualitesLesPlusMontees: moy(concentration),
  taille: taille && { sauvegarde: taille.total, releve: taille.total - taille.sans, part: Math.round((taille.total - taille.sans) / taille.sans * 1000) / 10 + ' %' } };
console.log(JSON.stringify(rapport, null, 1));
if (SORTIE) fs.writeFileSync(SORTIE, JSON.stringify({ rapport, releves }, null, 0));
