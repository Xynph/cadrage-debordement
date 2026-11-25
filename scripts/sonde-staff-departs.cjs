'use strict';
// Sonde : staff du club joué renouvelé par le directeur sportif (native/engine/staff-renouvellement.cjs) sur les gros staffs.
// Joue une carrière Monde (cadence hebdomadaire, mode simulation) jusqu'à l'été de la saison --jusqua, et relève :
//  - par fenêtre de fins de contrat (mars à juin) : départs par motif, dont « le marché offre nettement mieux » ;
//  - à l'été (juillet-août) : embauches, dont réembauches de remplaçants pour des départs « mieux » ;
//  - l'effectif du staff du club au fil des semaines (min / max par mois).
// Usage : node scripts/sonde-staff-departs.cjs [--club 71] [--graine 2026] [--jusqua 3] [--json fichier]
const vm = require('node:vm'), runInContext = vm.runInContext;
vm.runInContext = (code, ctx, options) => runInContext(code, ctx, { ...options, timeout: Math.max(options?.timeout ?? 0, 600000) });
const fs = require('node:fs');
const { ouvrir, jouerLeMatch } = require('../tests/helpers/carriere-monde.cjs');
const args = process.argv.slice(2), opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
const CLUB = Number(opt('--club', 71)), GRAINE = Number(opt('--graine', 2026)), JUSQUA = Number(opt('--jusqua', 3)), JSONF = opt('--json', null);

const debut = Date.now();
const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true, seed: GRAINE });
const run = src => jeu.bridge.vm.run(src);
let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: CLUB }));

// Espion : chaque série de décisions du directeur sportif, et les arrivées réelles (ids) qu'elle produit.
run(`(()=>{
 globalThis.__sonde={series:[],effectif:[]};
 const miens=()=>S.staffCareer.people.flat().filter(p=>p.clubId===S.club).map(p=>p.id);
 const f=dsStaffObserver;
 dsStaffObserver=function(){
  const avant=new Set(miens()),lots=new Set((S.manager.staffDesk?.lots||[]).map(l=>l.id)),dec=new Set((S.manager.staffDesk?.decisions||[]).map(d=>d.id));
  const r=f.apply(this,arguments);
  if(r){const b=S.manager.staffDesk,nouv=b.lots.filter(l=>!lots.has(l.id));
   const raisons={};for(const d of b.decisions)if(!dec.has(d.id)&&d.d==='libere')raisons[d.raison]=(raisons[d.raison]||0)+1;
   const arrives=miens().filter(id=>!avant.has(id));
   __sonde.series.push({saison:S.season,date:nouv[0]?.date,prolonges:nouv.reduce((n,l)=>n+l.prolonges.length,0),departs:nouv.reduce((n,l)=>n+l.departs.length,0),raisons,
    recrues:nouv.reduce((n,l)=>n+l.recrues.length,0),arrives:arrives.length,refus:nouv.reduce((n,l)=>n+l.refus,0)});}
  return r;
 };
 globalThis.__releveEffectif=()=>{const d=CDPreseason.pending(S)?.today||dsContratsAujourdhui();__sonde.effectif.push({saison:S.season,date:d,n:miens().length});};
})()`);

const relever = () => run('__releveEffectif()');
relever();
const depart = run('S.staffCareer.people.flat().filter(p=>p.clubId===S.club).length');
const cible = JSON.parse(run('JSON.stringify(S.staffCareer.targets.find(t=>t.clubId===S.club).roles)'));
for (let g = 0; g < 400; g++) {
  model = jeu.regler(model);
  if (run('S.phase') === 'ended') {
    if (run('S.season') >= JUSQUA) break;
    model = jeu.regler(jeu.call('next_season', { confirmed: true }));
    relever();
    continue;
  }
  // Saison --jusqua : on s'arrête après l'été (premier match de la saison joué).
  if (run('S.season') >= JUSQUA && run('S.round') >= 2) break;
  model = model.next ? jouerLeMatch(jeu, model) : jeu.regler(jeu.call('finish_round'));
  relever();
}
const sonde = JSON.parse(run('JSON.stringify(__sonde)'));
jeu.fermer();

const mois = d => Number(String(d).slice(5, 7));
const fenetres = {}, etes = {};
for (const s of sonde.series) {
  const m = mois(s.date);
  if (m >= 3 && m <= 6) {
    const f = fenetres[s.saison] ??= { series: 0, prolonges: 0, departs: 0, mieux: 0, raisons: {} };
    f.series++; f.prolonges += s.prolonges; f.departs += s.departs; f.mieux += s.raisons.mieux || 0;
    for (const [k, v] of Object.entries(s.raisons)) f.raisons[k] = (f.raisons[k] || 0) + v;
  } else if (m === 7 || m === 8) {
    const e = etes[s.saison] ??= { series: 0, recrues: 0, arrives: 0 };
    e.series++; e.recrues += s.recrues; e.arrives += s.arrives;
  }
}
const parMois = {};
for (const e of sonde.effectif) {
  const k = 's' + e.saison + ' ' + String(e.date).slice(0, 7), v = parMois[k] ??= { min: e.n, max: e.n };
  v.min = Math.min(v.min, e.n); v.max = Math.max(v.max, e.n);
}
const resume = { club: CLUB, graine: GRAINE, staffDepart: depart, cible, fenetres, etes, effectifParMois: parMois, series: sonde.series, duree_s: Math.round((Date.now() - debut) / 1000) };
console.log(`Club ${CLUB} (graine ${GRAINE}) : staff de départ ${depart}, cible ${Object.values(cible).reduce((a, b) => a + b, 0)} ${JSON.stringify(cible)}`);
for (const [s, f] of Object.entries(fenetres)) console.log(`  Fenêtre mars-juin s${s} : ${f.prolonges} prolongés, ${f.departs} départs dont ${f.mieux} « le marché offre mieux » ${JSON.stringify(f.raisons)}`);
for (const [s, e] of Object.entries(etes)) console.log(`  Été s${s} : ${e.recrues} embauches (${e.arrives} arrivées effectives)`);
console.log('  Effectif du staff par mois : ' + Object.entries(parMois).map(([k, v]) => k + ' ' + (v.min === v.max ? v.min : v.min + '-' + v.max)).join(' | '));
console.log(`  (${resume.duree_s} s)`);
if (JSONF) fs.writeFileSync(JSONF, JSON.stringify(resume, null, 1));
