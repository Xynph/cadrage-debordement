'use strict';
// Mesure d'une saison complète de carrière Monde en cadence JOURNALIÈRE (advance_day, le vrai rythme du jeu),
// par l'API publique du worker : jeunes, effectifs des clubs IA, économie, stratégie, presse, notes de match.
// La mesure de référence (ci/world-career-measure.cjs) avance en cadence hebdomadaire et ne voit donc pas
// les crochets que la clôture journalière sautait.
// Usage : node scripts/mesure-saison-quotidienne.cjs [club=102] > rapport.json
const vm = require('node:vm'), runInContext = vm.runInContext;
vm.runInContext = (code, ctx, options) => runInContext(code, ctx, { ...options, timeout: Math.max(options?.timeout ?? 0, 180000) });
const { ouvrir, jouerLeMatch } = require('../tests/helpers/carriere-monde.cjs');

const CLUB = Number(process.argv[2] || 102);
const jeu = ouvrir({ testVm: true });
const run = src => jeu.bridge.vm.run(src);
const t0 = Date.now();
let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: CLUB, start: 'premiers-clubs', varyCurrent: true }));

const BILAN = `(()=>{const med=v=>{const s=v.slice().sort((a,b)=>a-b);return s.length?s[s.length>>1]:null;};
 const moy=v=>v.length?Math.round(v.reduce((a,b)=>a+b,0)/v.length*10)/10:null;
 const clubs=Object.values(S.clubs||{}).filter(Boolean),ia=clubs.filter(c=>c.id!==S.club);
 const own=S.clubs[S.club],acad=S.development?.academy||[];
 const ligue=id=>{for(const [k,l] of Object.entries(S.worldMode?.leagues||{}))if(l.members?.includes(id))return k;return 'autre';};
 const parLigue={};for(const c of ia){const k=ligue(c.id);(parLigue[k]||(parLigue[k]={n:0,rouge:0,cash:[],effectif:[]})).n++;const L=parLigue[k];L.cash.push(c.cash||0);L.effectif.push(c.players?.length||0);if((c.cash||0)<0)L.rouge++;}
 for(const L of Object.values(parLigue)){L.cashMed=med(L.cash);L.effectifMin=Math.min(...L.effectif);L.effectifMed=med(L.effectif);delete L.cash;delete L.effectif;}
 const centresIA=S.aiRoster?.academies;const tailleCentres=Array.isArray(centresIA)?centresIA.map(a=>(a.players||a.prospects||[]).length):[];
 return JSON.stringify({saison:S.season,phase:S.phase,semaine:S.worldMode?.week,
  jeunes:{centre:acad.length,niveauMoy:moy(acad.map(p=>p.rating)),potentielMoy:moy(acad.map(p=>p.dev?.potential??p.potential??0)),
   rapport:S.academyReport?{semaine:S.academyReport.week,n:Object.keys(S.academyReport.ratings||{}).length}:null,prevision:S.academyIntakeForecast??null,
   suivi:S.academyFollowUp?{cracks:S.academyFollowUp.cracks?.length,caps:S.academyFollowUp.caps?.length}:null,
   promotions:(S.v77Promotions?.promotions||[]).length,selectionsJeunes:Object.keys(S.youthNational?.played||{}).length,
   matchsJeunes:(S.youthMatches?.results||S.youthMatches?.history||[]).length,espoirs:S.espoirsMatch?{prets:(S.espoirsMatch.loans||[]).length}:null,
   centresIA:{n:tailleCentres.length,med:med(tailleCentres),min:tailleCentres.length?Math.min(...tailleCentres):null}},
  effectifsIA:{min:Math.min(...ia.map(c=>c.players.length)),med:med(ia.map(c=>c.players.length)),max:Math.max(...ia.map(c=>c.players.length)),sous30:ia.filter(c=>c.players.length<30).length,
   niveauMed:med(ia.map(c=>moy(c.players.map(p=>p.rating))))},
  economie:{clubJoue:{cash:own.cash,effectif:own.players.length},iaRouge:ia.filter(c=>(c.cash||0)<0).length,iaCashMed:med(ia.map(c=>c.cash||0)),parLigue},
  strategie:S.nativeBoardCalendar?{revues:(S.nativeBoardCalendar.history||[]).length,reunions:(S.nativeBoardCalendar.meetings||[]).length,semaine:S.nativeBoardCalendar.week??null}:null,
  presse:S.pressPromises?{promesses:(S.pressPromises.promises||S.pressPromises.items||[]).length,tenues:JSON.stringify(S.pressPromises).match(/kept|tenue/g)?.length||0}:null,
  ficheClub:S.clubSheet?{clubs:Object.keys(S.clubSheet.clubs||{}).length,breves:JSON.stringify(S.clubSheet).length}:null,
  notes:S.matchNotes?{journeesAnnoncees:JSON.stringify(S.matchNotes).match(/annoncee":true/g)?.length||0,semaine:S.matchNotes.semaine?.cle}:null,
  jiff:S.jiff?{feuilles:(S.jiff.results||[]).length}:null,
  courriers:(()=>{const m=S.clubMail?.items||S.clubMail?.mails||S.clubMail?.inbox||[];const t={};for(const x of m){const k=x.type||x.kind||'?';t[k]=(t[k]||0)+1;}return {n:m.length,types:t};})()});})()`;

const releves = [];
let semaine = run('S.worldMode.week');
for (let garde = 0; garde < 420 && run("S.phase!=='ended'"); garde++) {
  model = jeu.regler(model);
  if (model.meta.calendarCadence?.matchReady && model.next) model = jouerLeMatch(jeu, model);
  else if (model.meta.calendarCadence?.canAdvance) model = jeu.call('advance_day', { fromDate: model.meta.calendarToday });
  else if (model.live) model = jeu.regler(jeu.call('finish_round'));
  else throw Error('journée bloquée : ' + model.meta.calendarToday);
  const w = run('S.worldMode.week');
  if (w !== semaine) { semaine = w; if (w % 8 === 0) releves.push(JSON.parse(run(BILAN))); }
}
releves.push(JSON.parse(run(BILAN)));
jeu.fermer();
console.log(JSON.stringify({ club: CLUB, duree: Math.round((Date.now() - t0) / 1000), releves }, null, 1));
