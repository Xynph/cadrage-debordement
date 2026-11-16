'use strict';
// Banc de mesure de « Jour suivant » et « Continuer » côté moteur (lot 36, docs : passation de la PR).
// Usage : node --max-old-space-size=2048 tools/avance-mesure.cjs [--club 102] [--suivis elite,accession,nationale]
//         [--graine 827381] [--sans-differe] [--preparer <dossier>] [--depuis <dossier>] [--sortie mesure.json]
// Carrière Monde (`world-champ`) avec les options du jeu (journal d'actions, écriture différée, erreurs légères).
// --preparer : crée la carrière et l'amène au lendemain de la deuxième clôture de la saison (un match joué), puis
// l'enregistre dans <dossier> (une fois, ~2 min). --depuis : repart d'une copie de ce dossier (mesures A/B comparables).
// Mesures : temps de réponse de chaque « Jour suivant » de la semaine, de la clôture de semaine et de deux « Continuer »
// (match du club délégué entre les deux) ; travail fait après la réponse (validation, sauvegarde) relevé à part ;
// empreinte SHA-256 de la carrière à la fin (même graine, même empreinte avec ou sans --sans-differe).
// Une seule exécution à la fois (machine partagée) : les durées absolues dépendent de la charge.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), crypto = require('node:crypto');
const M = require('../tests/helpers/carriere-monde.cjs');

const args = process.argv.slice(2), opt = (name, fallback) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : fallback; };
const club = Number(opt('--club', 102)), graine = Number(opt('--graine', 827381));
const suivis = opt('--suivis', 'elite,accession,nationale').split(',').filter(Boolean);
const preparer = opt('--preparer', null), depuis = opt('--depuis', null), sortie = opt('--sortie', null);
const options = { seed: graine, journal: true, deferredCommits: true, lightErrors: true, timing: true, testVm: true, ...(args.includes('--sans-differe') ? { dayDeferral: false } : {}) };
const mediane = xs => xs.length ? [...xs].sort((a, b) => a - b)[(xs.length - 1) >> 1] : null;

if (preparer) {
  fs.mkdirSync(preparer, { recursive: true });
  const jeu = M.ouvrir({ ...options, dataDir: preparer });
  try {
    let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club, detailedLeagues: suivis }));
    let clotures = 0, matchs = 0, close = false;
    for (let i = 0; i < 200 && !(close && clotures >= 2 && matchs >= 1); i++) {
      model = jeu.regler(model);
      if (model.meta.calendarCadence?.matchReady && model.next) { model = M.jouerLeMatch(jeu, model); matchs++; close = false; continue; }
      const semaine = model.meta.week;
      model = jeu.call(model.meta.calendarToday < '2026-08-17' ? 'advance_until_event' : 'advance_day', { fromDate: model.meta.calendarToday });
      close = model.meta.week !== semaine && model.meta.calendarToday > '2026-08-17';
      if (close) clotures++;
    }
    jeu.call('save');
    console.log(JSON.stringify({ prepare: preparer, date: model.meta.calendarToday, clotures, matchs }));
  } finally { jeu.bridge.close(); }
  process.exit(0);
}

if (!depuis) { console.error('Indiquez --depuis <dossier> (préparé avec --preparer).'); process.exit(2); }
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-avance-mesure-'));
fs.cpSync(depuis, dir, { recursive: true });
fs.rmSync(path.join(dir, 'PrototypeGodot', 'profil.lock'), { force: true });
const jeu = M.ouvrir({ ...options, dataDir: dir });
const res = { differe: options.dayDeferral !== false, jours: [], joursCpu: [], cloture: null, continuer: [], apresReponse: [] };
// Temps processeur (utilisateur + système) d'une commande : moins sensible que la durée à la charge d'une machine partagée.
const cpu = since => { const u = process.cpuUsage(since); return Math.round((u.user + u.system) / 1000); };
try {
  const apres = () => { const t = performance.now(); jeu.bridge.handle.flush(); res.apresReponse.push(Math.round(performance.now() - t)); };
  let model = jeu.call('snapshot');
  // Semaine : jours un par un jusqu'à la clôture comprise (le match du club, s'il tombe, est joué à part).
  for (let d = 0; d < 9 && res.cloture === null; d++) {
    model = jeu.regler(model); apres();
    if (model.meta.calendarCadence?.matchReady && model.next) { model = M.jouerLeMatch(jeu, model); apres(); continue; }
    const semaine = model.meta.week, c = process.cpuUsage(), t = performance.now(), r = jeu.brut('advance_day', { fromDate: model.meta.calendarToday });
    if (!r.ok) throw Error(r.error);
    const ms = Math.round(performance.now() - t), cpuMs = cpu(c); model = r.model; apres();
    if (model.meta.week !== semaine) res.cloture = { ms, cpu: cpuMs, phases: r.timing }; else { res.jours.push(ms); res.joursCpu.push(cpuMs); }
  }
  for (let k = 0; k < 3 && res.continuer.length < 2; k++) {
    model = jeu.regler(model); apres();
    if (model.meta.calendarCadence?.matchReady && model.next) { model = M.jouerLeMatch(jeu, model); apres(); continue; }
    const c = process.cpuUsage(), t = performance.now(), r = jeu.brut('advance_until_event', { fromDate: model.meta.calendarToday });
    if (!r.ok) throw Error(r.error);
    model = r.model; res.continuer.push({ ms: Math.round(performance.now() - t), cpu: cpu(c), jours: model.meta.advanceUntilEvent.days, arret: model.meta.advanceUntilEvent.stop.kind }); apres();
  }
  res.medianeJour = mediane(res.jours); res.medianeJourCpu = mediane(res.joursCpu);
  res.empreinte = crypto.createHash('sha256').update(jeu.bridge.vm.run('JSON.stringify(S)')).digest('hex').slice(0, 16);
  res.date = model.meta.calendarToday;
} finally { jeu.bridge.close(); fs.rmSync(dir, { recursive: true, force: true }); }
const texte = JSON.stringify(res);
if (sortie) fs.writeFileSync(sortie, texte);
console.log(texte);
