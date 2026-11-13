'use strict';
// Statut JIFF et quota LNR (décision de Léo du 12/11/2026 : « comme dans la réalité »), en carrière
// Monde (world-champ) : clubs français = Top 14 (« elite »), Pro D2 (« accession ») et Nationale du Monde.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const vm = require('node:vm');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { factory } = require('../native/engine/jiff.cjs');

// Réécrit l'empreinte d'un export modifié (même calcul que dist/saves.js).
function encoded(doc) {
  const text = JSON.stringify(doc.state);
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) h = Math.imul(h ^ text.charCodeAt(i), 16777619);
  doc.checksum = (h >>> 0).toString(16).padStart(8, '0');
  return JSON.stringify(doc);
}
const copy = x => JSON.parse(JSON.stringify(x));
const local = factory(); // getStatus / setStatus / isJiff n'utilisent que l'état passé.
const sheets = s => s.jiff.counts;

// Une carrière Monde partagée (création ~15 s) : Toulouse, club 0 du Top 14.
let shared = null;
function career() {
  if (shared) return shared;
  const dataDir = fs.mkdtempSync(path.join(path.resolve(os.tmpdir()), 'cd-jiff-monde-'));
  const bridge = createBridge({ dataDir, seed: 607655, now: 1794178800000 });
  let id = 0;
  const ask = (command, payload = {}) => bridge.handle({ id: ++id, command, payload });
  const ok = (command, payload) => { const r = ask(command, payload); assert.equal(r.ok, true, `${command}: ${r.error}`); return r.model; };
  const go = (command, payload) => settleClubMeetings(ok(command, payload), ok);
  const exported = () => JSON.parse(ok('export').meta.exportText);
  const round = () => {
    const model = ok('snapshot');
    if (model.next) {
      if (!model.selection.valid) { ok('auto_lineup'); if (!ok('snapshot').selection.valid) ok('promote_cover', { confirmed: true }); }
      ok('begin_match'); ok('delegate');
    }
    return go('finish_round');
  };
  go('new_career', { mode: 'world-champ', club: 0 });
  shared = { ask, ok, go, exported, round, close() { bridge.close(); fs.rmSync(dataDir, { recursive: true, force: true }); } };
  process.on('exit', () => shared.close());
  return shared;
}
// Feuilles de saison régulière Top 14 / Pro D2 jouées par chaque club avant la semaine courante.
function expectedSheets(s) {
  const out = {};
  for (const f of s.worldMode.fixtures) if (f.week < s.round && f.phase === 'league' && ['elite', 'accession'].includes(f.competitionId))
    for (const c of [f.homeId, f.awayId]) out[c] = (out[c] || 0) + 1;
  return out;
}

test('Barème : retrait de points sous 16 JIFF de moyenne, prime du fonds à partir de 17', () => {
  assert.deepEqual([16, 15.5, 15, 13, 5].map(local.deductionFor), [0, 1, 2, 6, 10]);
  assert.deepEqual([[16.9, 'elite'], [17, 'elite'], [18, 'elite'], [20, 'elite'], [17, 'accession'], [21, 'accession']].map(([a, l]) => local.bonusFor(l, a)),
    [0, 220000, 320000, 320000, 190000, 280000]);
});

test('Carrière Monde : statuts initiaux, feuilles comptées en Top 14 / Pro D2, projection de la feuille', () => {
  const c = career();
  // Le Top 14 et la Pro D2 commencent après les premières semaines du calendrier Monde.
  let model = c.round(), s = c.exported().state;
  for (let i = 0; i < 14 && (Object.keys(expectedSheets(s)).length < 30 || Object.values(expectedSheets(s)).some(n => n < 2)); i++) { model = c.round(); s = c.exported().state; }
  assert.equal(s.jiff?.version, 1, 'le JIFF s’active en carrière Monde');
  const L = s.worldMode.leagues, french = new Set(['elite', 'accession', 'nationale'].flatMap(k => L[k].members));
  for (const k of ['elite', 'accession', 'nationale']) for (const ci of L[k].members) {
    const pros = s.clubs[ci].players, share = pros.filter(p => local.isJiff(s, p)).length / pros.length;
    assert.ok(share >= .66 && share < .8, `${s.clubs[ci].name} : ${share}`);
  }
  for (const k of ['prem', 'urc', 'srp', 'champ']) for (const ci of L[k].members)
    assert.equal(s.clubs[ci].players.filter(p => local.isJiff(s, p) && !/^youth-/.test(p.id)).length, 0, `${s.clubs[ci].name} n’est pas français`);
  // Jeunes des centres français : saisons de centre d'après l'âge, statut à trois saisons.
  const academies = [...s.development.academy.map(p => [0, p]), ...s.aiRoster.academies.flatMap(a => a.players.map(p => [a.clubId, p]))];
  for (const [ci, p] of academies) {
    const e = local.getStatus(s, p.id);
    if (!french.has(ci)) { assert.ok(!e || e[0] === 0); continue; }
    const centre = Math.max(0, Math.min(3, p.age - 16));
    assert.deepEqual(e, [centre >= 3 ? 1 : 0, centre, 0], p.id);
  }
  // Une feuille par journée de saison régulière, uniquement pour le Top 14 et la Pro D2.
  const expected = expectedSheets(s), counts = sheets(s);
  assert.equal(Object.keys(expected).length, 30, 'les 30 clubs du Top 14 et de la Pro D2 ont joué');
  assert.deepEqual(Object.fromEntries(Object.entries(counts).map(([k, r]) => [k, r[0]])), Object.fromEntries(Object.entries(expected).map(([k, n]) => [k, n])));
  // Feuilles de l'ordinateur conformes : au moins 16 JIFF en moyenne.
  for (const [ci, [n, total]] of Object.entries(counts)) if (+ci !== s.club) assert.ok(total / n >= 16, `${s.clubs[ci].name} : ${total / n}`);
  const view = model.clubLife.jiff;
  assert.equal(view.applies, true);
  assert.equal(view.league, 'elite');
  assert.equal(view.target, 16);
  assert.equal(view.sheets, counts[s.club][0]);
  assert.ok(Number.isInteger(view.currentSheet));
});

test('Carrière Monde : la composition automatique de l’ordinateur remonte vers 16 JIFF', () => {
  const c = career();
  const doc = c.exported(), s = doc.state;
  // Un club de l'ordinateur qui joue une journée de Top 14 cette semaine.
  const f = s.worldMode.fixtures.find(x => x.week === s.round && x.phase === 'league' && x.competitionId === 'elite' && ![x.homeId, x.awayId].includes(s.club));
  assert.ok(f, 'journée de Top 14 cette semaine');
  const team = s.clubs[f.homeId];
  // Pire cas : seuls les joueurs les moins bien notés sont JIFF (la meilleure feuille n'en compte presque aucun).
  const order = team.players.slice().sort((a, b) => b.rating - a.rating);
  order.forEach((p, i) => local.setStatus(s, p.id, i < 26 ? [0, 0, 0] : [1, 0, 5]));
  const before = copy(sheets(s)[team.id] || [0, 0]);
  c.ok('import', { text: encoded(doc) });
  c.round();
  const after = c.exported().state;
  const row = sheets(after)[team.id], count = row[1] - before[1];
  assert.equal(row[0], before[0] + 1);
  assert.ok(count >= 12, `${team.name} : ${count} JIFF sur la feuille`);
});

test('Carrière Monde : le retrait de points JIFF compte au classement Monde', () => {
  const c = career();
  const doc = c.exported(), s = doc.state;
  const target = s.worldMode.leagues.elite.members.find(id => id !== s.club);
  const points = s.clubs[target].points;
  s.jiff.deductions = { [target]: 3 }; s.jiff.deductionSeason = s.season;
  // Sans retrait recopié dans le club, la sauvegarde est incohérente avec le classement Monde.
  const refused = c.ask('import', { text: encoded(copy(doc)) });
  assert.equal(refused.ok, false);
  assert.match(refused.error, /classement/);
  s.clubs[target].points = points - 3;
  const model = c.ok('import', { text: encoded(doc) });
  const rows = model.leagues.find(l => l.id === 'elite').rows;
  const row = rows.find(r => r.id === target);
  assert.equal(row.points, points - 3);
  assert.ok(rows.every((r, i) => i === 0 || rows[i - 1].points >= r.points), 'classement trié après retrait');
});

// Fin de saison sur un état Monde réel, dans une VM isolée (le passage de saison complet est mesuré
// hors suite : 46 semaines).
function seasonVm() {
  const c = career();
  const s = c.exported().state;
  const news = [];
  const fixtures = [];
  const ctx = vm.createContext({ S: s, news: t => news.push(t),
    CDWorldCareer: { active: () => true, fixtures: () => fixtures, rows: () => [], clubReleaseOn: () => null } });
  vm.runInContext(`var CDJiff=(${factory.toString()})();`, ctx);
  return { s, ctx, news, run: src => vm.runInContext(src, ctx) };
}

test('Fin de saison : centre, licence, retrait la saison suivante et prime du fonds', () => {
  const { s, run, news } = seasonVm();
  const L = s.worldMode.leagues;
  s.jiff.deductions = {}; s.jiff.deductionSeason = s.season;
  // Un Espoir d'un centre de l'ordinateur français, à deux saisons de centre.
  const ai = s.aiRoster.academies.find(a => L.accession.members.includes(a.clubId));
  const young = ai.players.find(p => !local.isJiff(s, p));
  local.setStatus(s, young.id, [0, 2, 0]);
  // Un jeune pro du club sorti du centre (youth-0-…), à 20 ans et deux saisons de centre.
  const own = s.clubs[s.club];
  const formed = own.players.find(p => !local.isJiff(s, p)) || own.players[0];
  formed.id = formed.id.startsWith('youth-0-') ? formed.id : 'youth-0-1-900'; formed.age = 20;
  local.setStatus(s, formed.id, [0, 2, 0]);
  // Un pro d'un club anglais : jamais JIFF par la licence.
  const english = s.clubs[L.prem.members[0]].players.find(p => p.age <= 22) || Object.assign(s.clubs[L.prem.members[0]].players[0], { age: 21 });
  local.setStatus(s, english.id, [0, 0, 4]);
  const other = L.elite.members.find(id => id !== s.club), pro = L.accession.members[0];
  s.jiff.counts = { [other]: [26, 26 * 14], [s.club]: [26, 26 * 18], [pro]: [30, 30 * 17] };
  const cash = s.clubs.map(c => c.cash);
  const r = JSON.parse(run(`(() => { const season = S.season, pending = CDJiff.closeSeason(S, season);
    const during = CDJiff.deduction(S, ${other});
    const next = CDJiff.deductionsFor(S, season + 1);
    S.season++; CDJiff.openSeason(S, pending);
    return JSON.stringify({ pending, during, next, deduction: CDJiff.deduction(S, ${other}), own: CDJiff.deduction(S, S.club),
      young: CDJiff.isJiff(S, { id: ${JSON.stringify(young.id)} }), formed: CDJiff.isJiff(S, { id: ${JSON.stringify(formed.id)} }),
      english: CDJiff.isJiff(S, { id: ${JSON.stringify(english.id)} }), results: S.jiff.results.length, counts: Object.keys(S.jiff.counts).length,
      cash: S.clubs.map(c => c.cash), validate: CDJiff.validate(S) }); })()`));
  assert.equal(r.during, 0, 'Le classement de la saison terminée n’est pas modifié');
  assert.deepEqual(r.next, { [other]: 4 }, 'retraits connus pour la saison suivante dès le bilan');
  assert.deepEqual(r.pending, { [other]: 4 });
  assert.equal(r.deduction, 4);
  assert.equal(r.own, 0);
  assert.equal(r.young, true, 'trois saisons au centre français');
  assert.equal(r.formed, true, 'un Espoir passé pro garde ses saisons de centre');
  assert.equal(r.english, false, 'la licence ne compte qu’en France');
  assert.equal(r.cash[s.club] - cash[s.club], 320000, 'prime du fonds JIFF (Top 14, 18 de moyenne)');
  assert.equal(r.cash[pro] - cash[pro], 190000, 'prime du fonds JIFF (Pro D2, 17 de moyenne)');
  assert.equal(r.cash[other], cash[other]);
  assert.equal(r.results, 3);
  assert.equal(r.counts, 0, 'Les feuilles sont remises à zéro pour la nouvelle saison');
  assert.equal(r.validate, true);
  assert.ok(news.some(t => t.includes('fonds JIFF')));
});

test('Validation stricte : un état JIFF altéré est refusé', () => {
  const { run } = seasonVm();
  for (const breakage of [
    '(b => b[Object.keys(b)[0]] = [2, 0, 0])(Object.values(S.jiff.players)[0])',
    'S.jiff.players.b99 = { x: [0, 0, 0] }',
    'S.jiff.deductions[0] = 50',
    'S.jiff.extra = 1',
    'S.jiff.results.push({ season: 1, clubId: 0, league: "elite", sheets: 1, average: 30, deduction: 0, bonus: 0 })',
  ]) {
    assert.throws(() => run(`(() => { const saved = JSON.parse(JSON.stringify(S.jiff)); try { ${breakage}; CDJiff.validate(S); } finally { S.jiff = saved; } })()`), /JIFF/);
  }
  assert.equal(run('CDJiff.validate(S)'), true);
});
