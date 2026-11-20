'use strict';
// Sonde : joue une saison Monde (club 102, cadence hebdomadaire), sauvegarde l'état S avant la bascule (--etat fichier),
// ou repart d'un état sauvegardé (--depuis fichier), puis joue la bascule en relevant, après chaque étape de l'intersaison,
// le nombre de clubs gérés au-dessus de leur limite de masse (> 0, > 1 %, > 3 %) et leur somme de masse.
// Usage : node scripts/sonde-bascule-masse.cjs [--graine 4242] [--saisons 1] [--etat s.json | --depuis s.json]
const vm = require('node:vm'), runInContext = vm.runInContext;
vm.runInContext = (code, ctx, options) => runInContext(code, ctx, { ...options, timeout: Math.max(options?.timeout ?? 0, 600000) });
const fs = require('node:fs');
const { ouvrir, jouerLeMatch } = require('../tests/helpers/carriere-monde.cjs');
const args = process.argv.slice(2), opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
const GRAINE = Number(opt('--graine', 4242)), SAISONS = Number(opt('--saisons', 1)), ETAT = opt('--etat', null), DEPUIS = opt('--depuis', null);
const jeu = ouvrir({ testVm: true, hebdomadaire: true, simulation: true, seed: GRAINE });
const run = src => jeu.bridge.vm.run(src);
let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club: 102, start: 'premiers-clubs', varyCurrent: true }));
if (DEPUIS) run('S=JSON.parse(' + JSON.stringify(fs.readFileSync(DEPUIS, 'utf8')) + ');');
else {
  for (let saison = 1; saison <= SAISONS; saison++) {
    for (let g = 0; g < 200 && run('S.phase') !== 'ended'; g++) {
      model = jeu.regler(model);
      if (run('S.phase') === 'ended') break;
      model = model.next ? jouerLeMatch(jeu, model) : jeu.regler(jeu.call('finish_round'));
    }
    if (saison < SAISONS) model = jeu.regler(jeu.call('next_season', { confirmed: true }));
  }
  if (ETAT) fs.writeFileSync(ETAT, run('JSON.stringify(S)'));
}
const SONDE = `(()=>{
 globalThis.__sonde=[];
 const releve=etape=>{let n=0,n1=0,n3=0,m=0,ids=[];
  for(const c of S.clubs){if(c.id===S.club)continue;const masse=c.players.reduce((a,p)=>a+(p.salary||0),0),l=aiRosterWageLimit(c);m+=masse;
   if(masse>l)n++;if(masse>l*1.01){n1++;ids.push(c.id)}if(masse>l*1.03)n3++;}
  __sonde.push({etape,saison:S.season,n,n1,n3,masse:m,ids:ids.join(',')});};
 globalThis.__releve=releve;
 for(const nom of ['worldEndSeason','careerSeasonEnd','rollDevelopmentYear','worldPrepareRenewalLiquidity','settleContracts','aiRosterContracts','calIAExecuter','calIAMasseBascule','newSeason','worldNewSeason','beginDevelopmentSeason','resetSatisfactionSeason','v39SeasonReset','careerSeasonStart','autoLineup','promoteCover','refreshMarket','managerMobilityOnSeasonStart','trimHistories','budgetAvantProfondeur','budgetProfondeur']){
  let f;try{f=eval(nom)}catch(e){continue}if(typeof f!=='function')continue;
  const w=function(){const r=f.apply(this,arguments);try{releve('après '+nom)}catch(e){}return r;};
  try{eval(nom+'=w')}catch(e){}
 }
 const sf=nativeStartingSalaries.recaler;
 releve('avant bascule');
 return 'ok';
})()`;
console.log(run(SONDE));
jeu.call('next_season', { confirmed: true });
run("__releve('après next_season')");
for (const r of JSON.parse(run('JSON.stringify(__sonde)'))) console.log(r.etape.padEnd(40), 's' + r.saison, '>0', r.n, '>1%', r.n1, '>3%', r.n3, 'masse', r.masse, r.n1 ? '[' + r.ids + ']' : '');
jeu.fermer();
