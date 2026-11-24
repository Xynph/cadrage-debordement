'use strict';
// Sonde d'équilibre des finances : joue plusieurs saisons Monde (cadence hebdomadaire, matchs délégués) et relève, à
// chaque fin de saison (après la clôture), la trésorerie (et la dette) de chaque club rapportée à ses recettes annuelles, par division :
// clubs dans le rouge, médiane, plus gros trésor. Sert à vérifier qu'un réglage du budget ne mène ni à la faillite
// généralisée ni à des trésors qui explosent.
// Usage : node scripts/sonde-equilibre-finances.cjs [--graine 4242] [--club 29] [--saisons 3] [--out rapport.json]
const vm = require('node:vm'), runInContext = vm.runInContext;
vm.runInContext = (code, ctx, options) => runInContext(code, ctx, { ...options, timeout: Math.max(options?.timeout ?? 0, 600000) });
const fs = require('node:fs');
const { ouvrir, jouerLeMatch } = require('../tests/helpers/carriere-monde.cjs');
const args = process.argv.slice(2), opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
const GRAINE = Number(opt('--graine', 4242)), CLUB = Number(opt('--club', 29)), SAISONS = Number(opt('--saisons', 3)), OUT = opt('--out', null);
const jeu = ouvrir({ testVm: true, hebdomadaire: true, rapide: true, seed: GRAINE });
const run = src => jeu.bridge.vm.run(src);
let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: CLUB }));
const RELEVE = `(()=>{const f=budgetForces(),a=nativeClubBudget.recettes(f),out=[];
 for(const c of S.clubs){const d=budgetLigue(c.id);if(!nativeClubBudget.DIVISIONS[d])continue;const w=typeof worldClub==='function'?worldClub(c.id):null;
  out.push({id:c.id,d,cash:Math.round(c.cash),dette:Math.round(w?.debt||0),recettes:Math.round(a.get(c.id)),masse:Math.round(budgetMasse(c)*52),joue:c.id===S.club});}
 return out;})()`;
const rapport = { graine: GRAINE, club: CLUB, saisons: [] };
const t0 = Date.now();
const mediane = v => { const s = [...v].sort((x, y) => x - y); return s.length ? s[Math.floor(s.length / 2)] : null; };
for (let saison = 1; saison <= SAISONS; saison++) {
  for (let g = 0; g < 200 && run('S.phase') !== 'ended'; g++) {
    model = jeu.regler(model);
    if (run('S.phase') === 'ended') break;
    model = model.next ? jouerLeMatch(jeu, model) : jeu.regler(jeu.call('finish_round'));
  }
  // Relevé après la clôture (prime de classement, apport du propriétaire, dividende, réinvestissements) : à l'ouverture suivante.
  model = jeu.regler(jeu.call('next_season', { confirmed: true }));
  const clubs = run(RELEVE), parDivision = {};
  for (const c of clubs) (parDivision[c.d] ||= []).push(c);
  const resume = {};
  for (const [d, L] of Object.entries(parDivision)) {
    const ratios = L.map(c => (c.cash - c.dette) / c.recettes);
    resume[d] = { clubs: L.length, rouge: L.filter(c => c.cash - c.dette < 0).length, medianeCaisse: mediane(L.map(c => c.cash)), medianeRatio: Math.round(mediane(ratios) * 1000) / 1000,
      maxRatio: Math.round(Math.max(...ratios) * 1000) / 1000, minRatio: Math.round(Math.min(...ratios) * 1000) / 1000 };
  }
  const joue = clubs.find(c => c.joue);
  rapport.saisons.push({ saison, minutes: Math.round((Date.now() - t0) / 60000), resume, joue });
  console.log(`saison ${saison} (${Math.round((Date.now() - t0) / 60000)} min) club joué : caisse ${joue?.cash}, dette ${joue?.dette}`);
  for (const [d, r] of Object.entries(resume)) console.log('  ' + d.padEnd(10) + JSON.stringify(r));
  if (OUT) fs.writeFileSync(OUT, JSON.stringify(rapport, null, 1));
}
jeu.fermer();
