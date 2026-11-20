'use strict';
// Audit manuel des flux financiers d'une carrière Monde (world-champ), budget de saison réaliste compris.
// Vraies semaines jouées au worker par les commandes publiques (tests/helpers/carriere-monde.cjs), aucun
// coefficient ni état de production modifié. Pendant chaque clôture de semaine (`finish_round`), le moteur est
// seulement observé : chaque écriture de caisse est relevée avec la fonction qui l'a faite, et les arguments
// du barème du budget sont copiés ; tout est retiré avant la commande suivante. La relecture
// (native/engine/world-finance-flow-audit.cjs) rapproche ensuite chaque variation de caisse de ses flux.
//   node ci/world-finance-flow-audit.cjs --weeks 14 --out rapport.json [--seed 4242] [--club 102]
//   node ci/world-finance-flow-audit.cjs --intersaison 1 --weeks 2 --out rapport.json   (saison entière, bascule, 2 semaines)
const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const assert = require('node:assert/strict'), {execFileSync} = require('node:child_process');
const {ouvrir, creer} = require('../tests/helpers/carriere-monde.cjs');
const {reconcile, reconcileInterseason, billingReplay} = require('../native/engine/world-finance-flow-audit.cjs');
const sha = x => crypto.createHash('sha256').update(typeof x === 'string' || Buffer.isBuffer(x) ? x : JSON.stringify(x)).digest('hex');

// Code exécuté dans le moteur. `cash` de chaque club devient un accesseur qui garde la même valeur et ne fait
// que noter l'écriture (première fonction nommée de la pile) ; budgetSemaine et le barème sont enveloppés pour
// copier leurs arguments et leurs écritures, sans les modifier. `__auditFinance.off()` remet tout en place.
const PROBE = String.raw`
globalThis.__auditFinance={on(snapshot){
 const a={writes:[],debts:[],billing:{},closing:{},events:[],snapshot:null,inBudget:null,restore:[]};__auditFinance.cur=a;
 // Première fonction nommée de la pile au-dessus de l'accesseur ou de l'enveloppe (skip : noms de l'enveloppe).
 const nom=(skip=[])=>{for(const l of new Error().stack.split(String.fromCharCode(10)).slice(2)){
  const m=/^\s*at (?:async )?([^\s(]+) \(/.exec(l);if(m&&!/^(Array|Object|Function|Reflect)\./.test(m[1])&&!['nom','set','get',...skip].includes(m[1]))return m[1];}return '?';};
 const tracer=(o,key,id,list)=>{let v=o[key];Object.defineProperty(o,key,{enumerable:true,configurable:true,
  get(){return v},set(n){if(n!==v)list.push({clubId:id,delta:n-v,fn:nom()});v=n;}});
  a.restore.push(()=>Object.defineProperty(o,key,{value:v,writable:true,enumerable:true,configurable:true}));};
 for(const c of S.clubs)tracer(c,'cash',c.id,a.writes);
 for(const i of S.worldManagement.clubInfo)tracer(i,'debt',i.id,a.debts);
 const cb=nativeClubBudget,bs=budgetSemaine,www=worldWeeklyEconomy,ev=aiRosterEvent;
 nativeClubBudget={...cb,semaine(args){const r=cb.semaine(args);if(a.inBudget&&!a.inBudget.args)a.inBudget.args=JSON.parse(JSON.stringify(args));return r;},
  // Clôture des comptes (intersaison) : arguments et résultat copiés, rattachés au club par le compteur passé.
  cloture(args){const r=cb.cloture(args),id=S.clubBudget.clubs.indexOf(args.compte);
   if(id>=0)a.closing[id]={args:JSON.parse(JSON.stringify(args)),result:JSON.parse(JSON.stringify(r))};return r;}};
 // Événements d'effectif des clubs gérés (renouvellement, recrutement…) avec la fonction qui les déclare.
 aiRosterEvent=function(clubId,kind,p,fee=0){a.events.push({clubId,kind,fee,fn:nom(['aiRosterEvent'])});return ev.apply(this,arguments);};
 a.restore.push(()=>{aiRosterEvent=ev;});
 budgetSemaine=function(forces,repere,c,rencontre,libelle){
  const compte=S.clubBudget?.clubs?.[c.id],cap={args:null,compte:{imprevu:compte?.imprevu,fraisMatch:compte?.fraisMatch},invest:null};
  // Investissements des excédents (club-investments.cjs) : répartition du club entre ses chantiers, cette saison.
  const ie=typeof investActif==='function'&&investActif()?investEtat():null;if(ie&&ie.saison===S.season&&ie.clubs?.[c.id])cap.invest={parts:{...ie.clubs[c.id].parts}};
  const prev=a.inBudget;a.inBudget=cap;try{const r=bs(forces,repere,c,rencontre,libelle);cap.ecritures=JSON.parse(JSON.stringify(r));
   if(c.id!==S.club&&a.inBilling)a.billing[c.id]=cap;return r;}finally{a.inBudget=prev;}};
 worldWeeklyEconomy=function(results){
  if(snapshot&&!a.snapshot)a.snapshot=JSON.stringify({S,results});
  a.inBilling=true;try{return www(results);}finally{a.inBilling=false;}};
 a.restore.push(()=>{nativeClubBudget=cb;budgetSemaine=bs;worldWeeklyEconomy=www;});
},off(){const a=__auditFinance.cur;for(const f of a.restore)f();__auditFinance.cur=null;
 return JSON.stringify({writes:a.writes,debts:a.debts,billing:a.billing,closing:a.closing,events:a.events,snapshot:a.snapshot});}};`;

// État financier comparé avant / après la semaine (lecture du moteur, sans export de la carrière).
const READ = `JSON.stringify({mode:CDWorldCareer.active(S)&&S.worldMode?.champ?'world-champ':'other',season:S.season,week:S.worldMode.week,phase:S.phase,club:S.club,
 clubs:S.clubs.map(c=>({id:c.id,cash:c.cash,players:c.players.map(p=>({id:p.id,salary:p.salary}))})),
 facilities:Object.fromEntries(S.clubs.map(c=>[c.id,worldClub(c.id).facilities])),ledger:S.ledger,
 accordsIA:S.calendrierMutations?.accordsIA||[],fixtures:S.history.length,budgetActif:budgetActif(),
 debt:Object.fromEntries(S.clubs.map(c=>[c.id,worldClub(c.id).debt])),upgrades:S.worldManagement.upgrades||[],
 dividends:Object.fromEntries((S.clubBudget?.clubs||[]).map((k,id)=>[id,k?.dividende||0])),budgetSeason:S.clubBudget?.saison??null,
 jiff:S.jiff?.results||[],formationFees:S.formationFees?.payments||[],prets:S.pretsActionnaires||{}})`;

// Contre-épreuve sur une copie isolée de l'état pris à l'entrée de la facturation, dans un second worker :
// la vraie fonction de production est rejouée ; un salaire de +1000 € pour un club géré change sa caisse
// exactement de ce que dit le barème, et rien d'autre (RNG, résultats, autres clubs).
function counterfactual(snapshotText, billing, seed) {
  const {S: base, results} = JSON.parse(snapshotText);
  const id = base.clubs.find(c => c.id !== base.club && billing[c.id]).id;
  const jeu = ouvrir({testVm: true, hebdomadaire: true, simulation: true, seed});
  try {
    creer(jeu, base.club);
    const vm = jeu.bridge.vm;
    vm.run('globalThis.__auditSnap=' + JSON.stringify(snapshotText));
    vm.run('globalThis.__auditResults=JSON.parse(__auditSnap).results');
    function variant(extra) {
      vm.run('S=JSON.parse(__auditSnap).S');
      if (extra) vm.run(`S.clubs.find(c=>c.id===${id}).players[0].salary+=1000`);
      const rng = vm.seed(), sports = vm.run('JSON.stringify({history:S.history,live:S.live,fixtures:S.worldMode.fixtures})');
      const cash = JSON.parse(vm.run('JSON.stringify(Object.fromEntries(S.clubs.map(c=>[c.id,c.cash])))'));
      assert.equal(vm.run('worldWeeklyEconomy(__auditResults)'), true);
      assert.equal(vm.seed(), rng, 'financial application does not consume RNG');
      assert.equal(vm.run('JSON.stringify({history:S.history,live:S.live,fixtures:S.worldMode.fixtures})'), sports, 'sports and fixtures unchanged');
      const after = vm.run('JSON.stringify(S)');
      assert.equal(vm.run('worldWeeklyEconomy(__auditResults)'), false, 'duplicate week refused');
      assert.equal(vm.run('JSON.stringify(S)'), after, 'no second payment, ledger or state mutation');
      const state = JSON.parse(after);
      return {deltas: Object.fromEntries(state.clubs.map(c => [c.id, c.cash - cash[c.id]])), state};
    }
    const plain = variant(false), raised = variant(true);
    // Rejeu isolé : chaque club géré reçoit exactement la facturation observée dans la vraie semaine.
    const rows = base.clubs.filter(c => c.id !== base.club).map(c => ({clubId: c.id, replayDelta: plain.deltas[c.id]}));
    const expectedDifference = billingReplay(billing[id], {extraWeeklyWages: 1000}).reduce((n, e) => n + e.amount, 0)
      - billingReplay(billing[id]).reduce((n, e) => n + e.amount, 0);
    const difference = raised.deltas[id] - plain.deltas[id];
    assert.equal(difference, expectedDifference, 'one extra 1000 weekly wage costs exactly what the season budget schedule says');
    assert.ok(difference < 0);
    // Tous les autres clubs et tout l'état non financier du club restent identiques entre les deux copies.
    const strip = s => { const t = structuredClone(s); const c = t.clubs.find(x => x.id === id); c.cash = 0; c.players[0].salary = 0; delete t.clubBudget.clubs[id]; return t; };
    assert.deepEqual(strip(raised.state), strip(plain.state));
    return {clubId: id, extraWeeklyWages: 1000, cashDeltaDifference: difference, expectedDifference,
      rngUnchanged: true, sportsUnchanged: true, otherStateIdentical: true, duplicateWeekRefused: true, replay: rows,
      scope: 'Isolated worker copy of the state at billing entry; executes the production worldWeeklyEconomy (season budget branch).'};
  } finally { jeu.fermer(); }
}

function run({seed = 4242, weeks = 3, club = 102, interseason = false, counterfactual: withCounterfactual = !interseason, out} = {}) {
  assert(Number.isInteger(seed) && seed >= 0 && seed <= 0xffffffff); assert(Number.isInteger(weeks) && weeks >= 1 && weeks <= 30);
  assert(Number.isInteger(club) && club >= 0);
  const report = {schema: 'world-finance-flows-v2', mode: 'world-champ', seed, club, node: process.version,
    source: execFileSync('git', ['rev-parse', 'HEAD'], {cwd: path.join(__dirname, '..'), encoding: 'utf8'}).trim(),
    sources: Object.fromEntries(['dist/world-career.js', 'dist/facilities.js', 'native/engine/club-budget.cjs', 'native/engine/calendrier-mutations.cjs',
      'native/engine/worker.cjs', 'native/engine/world-finance-flow-audit.cjs', 'ci/world-finance-flow-audit.cjs', 'tests/helpers/carriere-monde.cjs']
      .map(f => [f, sha(fs.readFileSync(path.join(__dirname, '..', f)))])),
    policy: 'Public worker commands (weekly cadence); delegated matches; mandatory meetings settled by the test helper; engine observed during finish_round and next_season only.',
    weeks: []};
  const jeu = ouvrir({testVm: true, hebdomadaire: true, simulation: true, seed});
  const vm = jeu.bridge.vm;
  try {
    let model = creer(jeu, club);
    vm.run(PROBE);
    // Une commande observée : état avant, trace pendant la commande, état après.
    const observe = (command, payload, snapshot) => {
      const before = JSON.parse(vm.run(READ));
      assert.equal(before.budgetActif, true, 'season budget is the default economy');
      vm.run(`__auditFinance.on(${snapshot})`);
      let response, trace;
      try { response = jeu.brut(command, payload); } finally { trace = JSON.parse(vm.run('__auditFinance.off()')); }
      assert.equal(response.ok, true, command + ': ' + response.error);
      model = response.model;
      return {before, after: JSON.parse(vm.run(READ)), trace};
    };
    // Sans intersaison : `weeks` semaines de la saison en cours. Avec : toutes les semaines jusqu'à la fin de la
    // saison, la commande « Saison suivante », puis `weeks` semaines de la nouvelle saison.
    let after = 0;
    for (let n = 0; ; n++) {
      model = jeu.regler(model);
      if (model.meta.phase === 'ended') {
        assert.ok(interseason && !report.interseason, 'audit stays within one season');
        const {before, after: next, trace} = observe('next_season', {confirmed: true}, false);
        report.interseason = {...reconcileInterseason(before, next, trace), writes: trace.writes.length, debts: trace.debts.length, events: trace.events.length};
        model = jeu.regler(model);
        continue;
      }
      if (interseason ? report.interseason && after++ >= weeks : n >= weeks) break;
      if (model.next) {
        if (!model.selection.valid) model = jeu.call('auto_lineup');
        if (!model.selection.valid) model = jeu.call('promote_cover', {confirmed: true});
        model = jeu.call('begin_match'); model = jeu.call('delegate');
      }
      const counter = n === 0 && withCounterfactual;
      const {before, after: next, trace} = observe('finish_round', {}, counter);
      const reconciliation = reconcile(before, next, trace);
      const week = {...reconciliation, results: next.fixtures - before.fixtures, writes: trace.writes.length};
      if (counter) {
        const experiment = counterfactual(trace.snapshot, trace.billing, seed);
        for (const row of reconciliation.rows.filter(r => r.kind === 'ai'))
          assert.equal(experiment.replay.find(r => r.clubId === row.clubId).replayDelta, row.billing.observed, 'isolated replay equals the observed billing');
        week.billingReplay = {matched: experiment.replay.length, clubs: experiment.replay.length};
        delete experiment.replay; report.counterfactual = experiment;
      }
      report.weeks.push(week);
    }
    report.passed = true;
  } catch (error) { report.passed = false; report.failure = error.stack; throw error; }
  finally {
    jeu.fermer();
    if (out) { fs.mkdirSync(path.dirname(path.resolve(out)), {recursive: true}); fs.writeFileSync(out, JSON.stringify(report, null, 2)); }
  }
  return report;
}
if (require.main === module) {
  const args = process.argv.slice(2), o = {};
  for (let i = 0; i < args.length; i += 2) { assert(args[i + 1] !== undefined); const k = {'--seed': 'seed', '--weeks': 'weeks', '--club': 'club', '--out': 'out', '--intersaison': 'interseason'}[args[i]]; assert(k, 'unknown argument'); o[k] = k === 'out' ? args[i + 1] : k === 'interseason' ? args[i + 1] === '1' : Number(args[i + 1]); }
  assert(o.out, 'explicit --out required');
  try { const r = run(o); console.log(JSON.stringify({passed: r.passed, source: r.source, weeks: r.weeks.map(w => ({season: w.season, week: w.week, ...w.ai})), interseason: r.interseason?.ai, counterfactual: r.counterfactual})); }
  catch (error) { console.error(error.stack); process.exitCode = 1; }
}
module.exports = {run, counterfactual, PROBE, READ};
