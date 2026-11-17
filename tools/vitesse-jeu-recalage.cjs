'use strict';
// Recalage des coûts de référence de la jauge « Vitesse de jeu estimée » (native/engine/league-detail.cjs, REFERENCE).
// Usage : node --max-old-space-size=2048 tools/vitesse-jeu-recalage.cjs [--suivis club|tous|elite,prem,...] [--club 102]
//         [--semaines 3] [--echauffement 2] [--budget 230] [--graine 827381]
// Carrière Monde (`world-champ`) avec les options du jeu (journal d'actions, écriture différée, erreurs légères).
// Mesure : le benchmark() du moteur (avant/après), puis le coût de semaines réelles complètes comportant un match du club :
// jours un par un, clôture de semaine, rendez-vous réglés, match délégué, et travail après réponse (écriture différée vidée
// après chaque commande, comme le jeu le fait dès que le moteur est libre).
// --suivis club : seul le championnat du club est suivi en détail ; tous : tous les championnats.
// Une exécution mesure une configuration (~3 à 4 min) ; lancer les deux séparément. Ligne finale : CD_RECALAGE {...}.
// Ramené à la référence comme estimate() : ÷ facteur du banc d'essai (série/calcul), ÷ contention (≤ 2 cœurs : 1,12 ; < 8 Go : 1,15).
// Le modèle de saison est celui de estimate() : semaine = baseWeekMs×série + (matchs suivis×detailedMatchMs + matchs de loin×quickMatchMs)×calcul/46.
const os = require('node:os');
const LD = require('../native/engine/league-detail.cjs');
const M = require('../tests/helpers/carriere-monde.cjs');

const args = process.argv.slice(2), opt = (n, d) => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : d; };
const club = Number(opt('--club', 102)), graine = Number(opt('--graine', 827381));
const nSemaines = Number(opt('--semaines', 3)), echauffement = Number(opt('--echauffement', 2)), budgetMs = Number(opt('--budget', 230)) * 1000;
const tous = Object.keys(LD.SEASON_MATCHES);
const mode = opt('--suivis', 'club');
const suivis = mode === 'tous' ? tous : mode === 'club' ? ['elite'] : mode.split(',').filter(Boolean);
const mediane = xs => xs.length ? [...xs].sort((a, b) => a - b)[(xs.length - 1) >> 1] : null;
const t0 = performance.now();
const bancAvant = LD.benchmark();

const jeu = M.ouvrir({ seed: graine, journal: true, deferredCommits: true, lightErrors: true, testVm: true });
let acc = 0, accCpu = 0, accCmd = 0, nCmd = 0;
const orig = jeu.bridge.handle, flush = orig.flush;
const mesure = (fn) => { const c = process.cpuUsage(), t = performance.now(); const r = fn(); const u = process.cpuUsage(c); acc += performance.now() - t; accCpu += (u.user + u.system) / 1000; return r; };
const enrobe = m => { const a = acc; const r = mesure(() => orig(m)); accCmd += acc - a; nCmd++; if (flush) mesure(() => flush()); return r; };
enrobe.flush = flush;
jeu.bridge.handle = enrobe;
const semaines = [];
try {
  let model = jeu.regler(jeu.call('new_career', { mode: 'world-champ', club, detailedLeagues: suivis }));
  const creationMs = Math.round(acc); acc = 0; accCpu = 0; accCmd = 0; nCmd = 0;
  let match = false, jours = 0, jeuxMatch = 0;
  for (let i = 0; i < 400 && semaines.filter(s => s.match).length < echauffement + nSemaines && performance.now() - t0 < budgetMs; i++) {
    model = jeu.regler(model);
    if (model.meta.calendarCadence?.matchReady && model.next) { model = M.jouerLeMatch(jeu, model); match = true; continue; }
    const semaine = model.meta.week;
    model = jeu.call('advance_day', { fromDate: model.meta.calendarToday }); jours++;
    if (model.meta.week !== semaine) { semaines.push({ semaine, match, jours, ms: Math.round(acc), cpuMs: Math.round(accCpu), reponseMs: Math.round(accCmd), commandes: nCmd }); acc = 0; accCpu = 0; accCmd = 0; nCmd = 0; match = false; jours = 0; }
  }
  var creation = creationMs, date = model.meta.calendarToday;
} finally { jeu.bridge.close(); }
const bancApres = LD.benchmark();
const banc = { serialMs: mediane([bancAvant.serialMs, bancApres.serialMs]), computeMs: mediane([bancAvant.computeMs, bancApres.computeMs]) };
const R = LD.REFERENCE, cores = os.cpus().length, memoryGb = os.totalmem() / 2 ** 30;
const serial = banc.serialMs / R.benchmarkMs.serial, compute = banc.computeMs / R.benchmarkMs.compute;
const contention = (cores <= 2 ? 1.12 : 1) * (memoryGb < 8 ? 1.15 : 1);
const utiles = semaines.filter(s => s.match).slice(echauffement);
const semaineMs = mediane(utiles.map(s => s.ms)), semaineCpuMs = mediane(utiles.map(s => s.cpuMs));
const total = tous.reduce((a, id) => a + LD.SEASON_MATCHES[id], 0);
const suivisN = suivis.reduce((a, id) => a + (LD.SEASON_MATCHES[id] || 0), 0), loinN = total - suivisN;
// Semaine ramenée à la référence (hors contention, machine de référence) : base + parts des matchs de la saison.
const weekRef = semaineMs / contention;
const resultat = {
  suivis: mode, club, date, creationMs: creation, benchmark: { avant: bancAvant, apres: bancApres, retenu: banc, facteurSerie: +serial.toFixed(3), facteurCalcul: +compute.toFixed(3) },
  machine: { cores, memoryGb: +memoryGb.toFixed(1), contention, node: process.version },
  semaines: semaines.map(s => ({ semaine: s.semaine, match: s.match, jours: s.jours, ms: s.ms, cpuMs: s.cpuMs, reponseMs: s.reponseMs, commandes: s.commandes })),
  semaineMs, semaineCpuMs, semaineReponseMs: mediane(utiles.map(s => s.reponseMs)), semaineRefMs: Math.round(weekRef * 1000) / 1000, suivisN, loinN,
  // baseWeekMs si le coût d'un match suivi / de loin est celui de REFERENCE (estimation directe, sans seconde configuration).
};
// Ramené par estimate() : base*série + (suivis*d + loin*q)*calcul/46 = semaine de référence.
resultat.baseWeekMsSiMatchs = Math.round((weekRef - (suivisN * R.detailedMatchMs + loinN * R.quickMatchMs) * compute / 46) / serial);
resultat.estimationActuelleMs = LD.estimate({ detailed: suivis, machine: { ...banc, cores, memoryGb } }).weekMs;
console.log('CD_RECALAGE ' + JSON.stringify(resultat));
