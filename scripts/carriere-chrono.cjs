'use strict';
// Chrono et empreinte d'une carrière Monde simulée (club 29, cadence hebdomadaire).
// Mesure le temps par commande et, à chaque fin de saison (avant puis après « Saison suivante »), relève une empreinte :
// soldes et effectifs des clubs (transferts), graine du hasard et empreinte de chaque section de l'état S
// (classements, calendrier, marché…). Deux sorties de même graine se comparent avec --comparer.
// Usage : node scripts/carriere-chrono.cjs --graine 7 --saisons 2 --sortie e.json [--club 29] [--complet] [--depuis 2] [--phases]
//   --complet : modèle complet de l'interface (sans le mode rapide) ; --depuis n : part du point de reprise du début
//   de la saison n (tests/helpers/carriere-reprise.cjs ; joué puis gardé s'il manque) ; CD_REPRISES=0 : aucun point.
//   node scripts/carriere-chrono.cjs --comparer a.json b.json : sections, soldes et effectifs identiques ?
const vm = require('node:vm'), runInContext = vm.runInContext;
vm.runInContext = (code, ctx, options) => runInContext(code, ctx, { ...options, timeout: Math.max(options?.timeout ?? 0, 600000) });
const fs = require('node:fs'), { createHash } = require('node:crypto');
const { ouvrirSaison, jouerSaison, saisonSuivante } = require('../tests/helpers/carriere-reprise.cjs');
const args = process.argv.slice(2), opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };

if (args[0] === '--comparer') {
  const [a, b] = args.slice(1).map(f => JSON.parse(fs.readFileSync(f, 'utf8')));
  let ecarts = 0;
  for (const sa of a.saisons) {
    const sb = b.saisons.find(x => x.saison === sa.saison);
    if (!sb) { console.log('saison ' + sa.saison + ' absente de la seconde sortie'); continue; }
    for (const moment of ['fin', 'apres']) {
      const x = sa[moment], y = sb[moment], diff = [];
      if (x.graineRng !== y.graineRng) diff.push('graine du hasard');
      if (x.clubsHash !== y.clubsHash) diff.push('soldes/effectifs');
      for (const k of new Set([...Object.keys(x.sections), ...Object.keys(y.sections)])) if (x.sections[k] !== y.sections[k]) diff.push('S.' + k);
      ecarts += diff.length;
      console.log('saison ' + sa.saison + ' ' + moment.padEnd(5) + (diff.length ? ' DIFFÉRENT : ' + diff.join(', ') : ' identique (' + Object.keys(x.sections).length + ' sections, soldes, effectifs, graine)'));
    }
  }
  process.exitCode = ecarts ? 1 : 0;
  return;
}

const GRAINE = Number(opt('--graine', 4242)), SAISONS = Number(opt('--saisons', 1)), CLUB = Number(opt('--club', 29)), SORTIE = opt('--sortie', null);
const DEPUIS = Number(opt('--depuis', 1)), PHASES = args.includes('--phases'), COMPLET = args.includes('--complet');
const t0 = Date.now();
const options = { ...(COMPLET ? { rapide: false, simulation: true } : {}), ...(PHASES ? { timing: true } : {}) };
const chrono = {}, phases = {};
const { jeu, model: depart, repriseDe, garder } = ouvrirSaison({ graine: GRAINE, saison: DEPUIS, carriere: { club: CLUB }, options });
const handle = jeu.bridge.handle;
jeu.bridge.handle = req => { const d = process.hrtime.bigint(); try { const r = handle(req); for (const [k, v] of Object.entries(r?.timing || {})) phases[k] = (phases[k] || 0) + v; return r; } finally { const c = (chrono[req.command] ||= { n: 0, ms: 0 }); c.n++; c.ms += Number(process.hrtime.bigint() - d) / 1e6; } };
const run = src => jeu.bridge.vm.run(src);
const h = t => createHash('sha256').update(t).digest('hex').slice(0, 16);
const empreinte = () => {
  const e = JSON.parse(run(`JSON.stringify({season:S.season,phase:S.phase,
    clubs:S.clubs.map(c=>({id:c.id,cash:c.cash,players:c.players.map(p=>p.id).sort((a,b)=>a-b).join(',')})),
    sections:Object.fromEntries(Object.keys(S).map(k=>[k,JSON.stringify(S[k])]))})`));
  for (const k of Object.keys(e.sections)) e.sections[k] = h(e.sections[k] ?? 'undefined');
  e.graineRng = jeu.bridge.vm.seed();
  e.clubsHash = h(JSON.stringify(e.clubs));
  return e;
};
console.log('départ saison ' + DEPUIS + (repriseDe > 1 ? ' (point de reprise de la saison ' + repriseDe + ')' : '') + ' en ' + Math.round((Date.now() - t0) / 1000) + ' s');
let model = depart;
const rapport = { graine: GRAINE, club: CLUB, rapide: !COMPLET, depuis: DEPUIS, saisons: [] };
for (let saison = DEPUIS; saison <= SAISONS; saison++) {
  const ts = Date.now();
  model = jouerSaison(jeu, model);
  const fin = empreinte(), tn = Date.now();
  model = saisonSuivante(jeu);
  garder(saison + 1);
  const apres = empreinte();
  rapport.saisons.push({ saison, msSaison: tn - ts, msBascule: Date.now() - tn, fin, apres });
  console.log('saison ' + saison + ' : ' + Math.round((tn - ts) / 1000) + ' s + bascule ' + Math.round((Date.now() - tn) / 1000) + ' s, clubs ' + fin.clubsHash + ' / ' + apres.clubsHash + ', hasard ' + apres.graineRng);
}
rapport.chrono = Object.fromEntries(Object.entries(chrono).sort((a, b) => b[1].ms - a[1].ms).map(([k, v]) => [k, { n: v.n, ms: Math.round(v.ms) }]));
rapport.msTotal = Date.now() - t0;
if (PHASES) { rapport.phases = Object.fromEntries(Object.entries(phases).sort((a, b) => b[1] - a[1]).map(([k, v]) => [k, Math.round(v)])); console.log(JSON.stringify(rapport.phases)); }
console.log(JSON.stringify(rapport.chrono));
if (SORTIE) fs.writeFileSync(SORTIE, JSON.stringify(rapport, null, 1));
jeu.fermer();
