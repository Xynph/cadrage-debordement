'use strict';
// Mesure de l'étalement des notes et des potentiels d'une carrière Monde neuve, par championnat.
// Usage : node scripts/mesure-notes-championnats.cjs [--json sortie.json] [--seed 20261114]
// Sert au chantier « notes moins resserrées » (suite de #850) : comparer avant / après un changement du barème V2.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const repo = path.resolve(__dirname, '..');
const { createBridge } = require(path.join(repo, 'native/engine/worker.cjs'));

const args = process.argv.slice(2);
const opt = name => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : null; };
const seed = Number(opt('--seed') || 20261114);

const game = fs.readFileSync(path.join(repo, 'dist/game.js'), 'utf8');
const positions = game.split(/\r?\n/).filter(line => /^const (?:POS|FAMILIES)=/.test(line)).join('\n');
const sandbox = vm.createContext({ clamp: (x, a, b) => Math.max(a, Math.min(b, x)), focusedBonus: () => 0 });
vm.runInContext(positions + '\n' + fs.readFileSync(path.join(repo, 'dist/rugby.js'), 'utf8') + '\nthis.buildSheet=buildSheet;', sandbox);
const { buildSheet } = sandbox;

const mean = l => l.reduce((s, x) => s + x, 0) / (l.length || 1);
const sd = l => { const m = mean(l); return Math.sqrt(mean(l.map(x => (x - m) ** 2))); };
const q = (l, p) => { const s = [...l].sort((a, b) => a - b); return s.length ? s[Math.min(s.length - 1, Math.floor(p * s.length))] : NaN; };
const r1 = x => Math.round(x * 10) / 10;

const root = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-mesure-notes-'));
const bridge = createBridge({ dataDir: path.join(root, 'carriere'), seed, now: 1794300000000 });
let serial = 0;
const ask = (command, payload = {}) => {
  const result = bridge.handle({ id: ++serial, command, payload });
  if (!result.ok) throw new Error(command + ' : ' + result.error);
  return result.model;
};
let state;
try {
  ask('new_career', { mode: 'world-champ', club: 0, varyCurrent: false });
  state = JSON.parse(ask('export').meta.exportText).state;
} finally {
  bridge.close();
  fs.rmSync(root, { recursive: true, force: true });
}

const leagueOf = new Map(Object.entries(state.worldMode.leagues).flatMap(([id, l]) => l.members.map(c => [c, id])));
const ORDER = ['elite', 'prem', 'urc', 'srp', 'jlo-d1', 'accession', 'jlo-d2', 'nationale', 'champ'];
const clubs = state.clubs.map(club => {
  const { lineup } = buildSheet(club);
  const byId = new Map(club.players.map(p => [p.id, p]));
  const xvPlayers = lineup.map(id => byId.get(id)).filter(Boolean);
  const ratings = club.players.map(p => p.rating).sort((a, b) => b - a);
  return {
    id: club.id, league: leagueOf.get(club.id) || 'guest',
    xv: mean(xvPlayers.map(p => p.rating)),
    // Écart entre le XV et le bas de l'effectif (les 8 moins bons) : étalement interne au club.
    inner: mean(xvPlayers.map(p => p.rating)) - mean(ratings.slice(-8)),
    sdClub: sd(ratings),
    players: club.players,
  };
});
const academies = [{ clubId: state.club, players: state.development?.academy || [] }, ...(state.aiRoster?.academies || [])];

const out = { seed, leagues: {}, global: {} };
for (const id of ORDER) {
  const list = clubs.filter(c => c.league === id);
  const players = list.flatMap(c => c.players);
  const young = players.filter(p => p.age <= 23);
  const youth = academies.filter(a => (leagueOf.get(a.clubId) || 'guest') === id).flatMap(a => a.players);
  out.leagues[id] = {
    clubs: list.length,
    xvMoyen: r1(mean(list.map(c => c.xv))),
    xvSigma: Math.round(sd(list.map(c => c.xv)) * 100) / 100,
    xvEcart: r1(Math.max(...list.map(c => c.xv)) - Math.min(...list.map(c => c.xv))),
    noteP10: q(players.map(p => p.rating), 0.1),
    noteP50: q(players.map(p => p.rating), 0.5),
    noteP90: q(players.map(p => p.rating), 0.9),
    noteSigma: r1(sd(players.map(p => p.rating))),
    sigmaDansClub: r1(mean(list.map(c => c.sdClub))),
    xvMoinsBas: r1(mean(list.map(c => c.inner))),
    potP50: q(players.map(p => p.dev.potential), 0.5),
    potP90: q(players.map(p => p.dev.potential), 0.9),
    potSigma: r1(sd(players.map(p => p.dev.potential))),
    jeunesPotSigma: r1(sd(young.map(p => p.dev.potential))),
    jeunesMarge: r1(mean(young.map(p => p.dev.potential - p.rating))),
    centrePotP50: youth.length ? q(youth.map(p => p.dev.potential), 0.5) : null,
    centrePotP90: youth.length ? q(youth.map(p => p.dev.potential), 0.9) : null,
  };
}
const all = clubs.flatMap(c => c.players);
const youngAll = all.filter(p => p.age <= 25 && p.rating < 90);
const per90 = {};
for (const p of youngAll) if (p.dev.potential >= 90) per90[p.age] = (per90[p.age] || 0) + 1;
out.global = {
  joueurs: all.length,
  noteSigma: r1(sd(all.map(p => p.rating))),
  note85: all.filter(p => p.rating >= 85).length,
  note90: all.filter(p => p.rating >= 90).length,
  potSigma: r1(sd(all.map(p => p.dev.potential))),
  pot85: all.filter(p => p.dev.potential >= 85).length,
  pot90: all.filter(p => p.dev.potential >= 90).length,
  pot90ParAge: per90,
  sigmaXvTousClubs: r1(sd(clubs.filter(c => c.league !== 'guest').map(c => c.xv))),
};

const cols = ['clubs', 'xvMoyen', 'xvSigma', 'xvEcart', 'noteP10', 'noteP50', 'noteP90', 'noteSigma', 'sigmaDansClub', 'xvMoinsBas', 'potP50', 'potP90', 'potSigma', 'jeunesPotSigma', 'jeunesMarge', 'centrePotP50', 'centrePotP90'];
console.log(['ligue', ...cols].join('\t'));
for (const id of ORDER) console.log([id, ...cols.map(c => out.leagues[id][c])].join('\t'));
console.log(JSON.stringify(out.global));
// --clubs : XV de chaque club par championnat, du plus fort au plus faible, et corrélation (Spearman) entre l'ordre
// des XV et le rang réel des clubs (world-niveaux-v2.json → ordre), quand il est connu.
const ordreReel = require(path.join(repo, 'native/engine/world-niveaux-v2.json')).ordre || {};
const rangs = l => { const s = l.map((x, i) => [x, i]).sort((a, b) => a[0] - b[0]); const r = []; s.forEach(([, i], k) => { r[i] = k; }); return r; };
const spearman = (a, b) => { const ra = rangs(a), rb = rangs(b), n = a.length; return 1 - 6 * ra.reduce((t, x, i) => t + (x - rb[i]) ** 2, 0) / (n * (n * n - 1)); };
for (const id of ORDER) {
  const list = clubs.filter(c => c.league === id).sort((a, b) => b.xv - a.xv);
  out.leagues[id].xvClubs = list.map(c => [c.id, r1(c.xv)]);
  const reel = ordreReel[id];
  if (reel) out.leagues[id].spearmanReel = Math.round(spearman(list.map(c => -c.xv), list.map(c => reel.indexOf(c.id))) * 100) / 100;
  if (args.includes('--clubs')) console.log(id + (reel ? ' (Spearman XV / rang réel ' + out.leagues[id].spearmanReel + ')' : '') + ' : ' + list.map(c => c.id + ' ' + r1(c.xv)).join(' · '));
}
if (opt('--json')) fs.writeFileSync(opt('--json'), JSON.stringify(out, null, 1));
