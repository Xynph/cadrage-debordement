'use strict';

function factory(geometry) {
  const LEAGUE = 'champ';
  const FROZEN_MODEL = 'champ-rugby-2026-27-closed-14';
  const FIRST_SEASON = 2026;
  const ANCHOR = '2026-08-17';
  const DAY = 86_400_000;
  const EXTRA_TIME = Object.freeze({halves: Object.freeze([10, 10]), startDelay: 0, interval: 1});
  const DATES = Object.freeze({quarter: '2027-05-08', semi: '2027-05-15', final: '2027-05-29'});
  const fail = (valid, reason) => { if (!valid) throw Error('Champ Rugby — ' + reason + '.'); };
  const integer = (n, min, max) => Number.isSafeInteger(n) && n >= min && n <= max;
  const nat = n => Number.isSafeInteger(n) && n >= 0;
  const id = x => nat(x) || typeof x === 'string' && /^[A-Za-z0-9:_-]{1,180}$/.test(x);
  const unique = (value, count, valid = nat) => Array.isArray(value) && value.length === count &&
    Array.from(value).every(valid) && new Set(value).size === count;
  const same = (a, b) => Array.isArray(a) && a.length === b.length && b.every((x, i) => a[i] === x);
  const vector = (v, max) => Array.isArray(v) && v.length === 2 && Array.from(v).every(n => integer(n, 0, max));
  const tied = v => v[0] === v[1];
  const winnerSide = v => v[0] > v[1] ? 0 : 1;
  const knownPhase = phase => Object.hasOwn(DATES, phase) || phase === 'relegation' || phase === 'access';

  function day(date) {
    fail(typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date), 'date invalide');
    const ms = Date.parse(date + 'T00:00:00Z');
    fail(Number.isFinite(ms) && new Date(ms).toISOString().slice(0, 10) === date, 'date invalide');
    return ms;
  }

  function seasonConfig({season = FIRST_SEASON, anchor, weeks = 46, seasonModel} = {}) {
    fail(integer(season, FIRST_SEASON, 2200), 'saison invalide');
    fail(season === FIRST_SEASON || seasonModel === FROZEN_MODEL, 'convention de saison simulée requise');
    const opening = Date.UTC(season, 7, 21);
    const defaultAnchor = opening - ((new Date(opening).getUTCDay() + 6) % 7) * DAY;
    const start = anchor === undefined ? defaultAnchor : day(anchor);
    fail(new Date(start).getUTCDay() === 1 && integer(weeks, 1, 52), 'ancre du lundi ou horizon invalide');
    return {season, start, weeks, offset: defaultAnchor - day(ANCHOR)};
  }

  function shift(date, config) {
    return new Date(day(date) + config.offset).toISOString().slice(0, 10);
  }

  function weekOf(date, config) {
    const week = Math.floor((day(date) - config.start) / (7 * DAY));
    fail(integer(week, 0, config.weeks - 1), 'rencontre hors horizon');
    return week;
  }

  fail(geometry?.schema === 'champ-calendar-geometry-v1' && geometry.season === FIRST_SEASON &&
    geometry.clubCount === 14 && geometry.anchor === ANCHOR && geometry.timezone === 'Europe/London' &&
    Array.isArray(geometry.fixtures) && geometry.fixtures.length === 182, 'calendrier source incomplet');
  const seasonOne = seasonConfig();
  const pairKeys = new Set();
  const roundClubs = new Set();
  const weekClubs = new Set();
  const fixtures = Array.from(geometry.fixtures, (f, i) => {
    fail(f && unique([f.home, f.away], 2, n => integer(n, 0, 13)) &&
      f.competitionRound === Math.floor(i / 7) && f.slot === i % 7 &&
      typeof f.kickoffLocal === 'string' && /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(f.kickoffLocal) &&
      ['rfu_fixture_card', 'rfu_match_centre'].includes(f.kickoffSource), 'calendrier source incohérent');
    const {home, away, competitionRound, slot, date, kickoffLocal, kickoffSource} = f;
    const pairKey = `${home}:${away}`;
    fail(!pairKeys.has(pairKey), 'doublon de calendrier');
    pairKeys.add(pairKey);
    const week = weekOf(date, seasonOne);
    for (const club of [home, away]) {
      const roundKey = `${competitionRound}:${club}`;
      const weekKey = `${week}:${club}`;
      fail(!roundClubs.has(roundKey) && !weekClubs.has(weekKey), 'collision du calendrier');
      roundClubs.add(roundKey);
      weekClubs.add(weekKey);
    }
    return {home, away, competitionRound, slot, date, kickoffLocal, kickoffSource};
  });

  function fixture(config, phase, round, slot, homeId, awayId, date, scheduleSource, competitionId = LEAGUE) {
    return {
      id: `${competitionId}:${config.season}:${phase}:${round}:${slot}`, competitionId,
      season: config.season, phase, round, competitionRound: round, week: date === null ? null : weekOf(date, config),
      date, kickoffLocal: null, timezone: 'Europe/London', homeId, awayId, neutral: false,
      venuePolicy: phase === 'league' ? 'home' : 'higher-seed-home', venueHostId: homeId, scheduleSource,
    };
  }

  function calendarFixtures({clubs, ...options}) {
    fail(unique(clubs, 14), 'liste des 14 clubs invalide');
    const config = seasonConfig(options);
    const initial = config.season === FIRST_SEASON;
    return fixtures.map(f => ({
      ...fixture(config, 'league', f.competitionRound, f.slot, clubs[f.home], clubs[f.away], shift(f.date, config),
        initial ? 'rfu-published-card' : 'generated-frozen-format'),
      kickoffLocal: initial ? f.kickoffLocal : null,
      kickoffSource: initial ? f.kickoffSource : null,
      dateStatus: initial ? 'rfu-card' : 'generated',
    }));
  }

  function scoreValid(score, tries) {
    fail(vector(score, 250) && vector(tries, 50) && score.every((n, i) => n >= 5 * tries[i]), 'score ou essais invalides');
  }

  function pointsFor(score, tries, side) {
    const other = 1 - side;
    const margin = score[side] - score[other];
    return {base: margin > 0 ? 4 : margin === 0 ? 2 : 0,
      bo: Number(tries[side] - tries[other] >= 3), bd: Number(margin < 0 && margin >= -7)};
  }

  function terrainPoints(score, tries) {
    scoreValid(score, tries);
    return [0, 1].map(side => {
      const {base, bo, bd} = pointsFor(score, tries, side);
      return base + bo + bd;
    });
  }

  function table(clubIds, results, {fixtures: schedule, deductions = {}, tieBreaks = {}} = {}) {
    fail(unique(clubIds, 14) && Array.isArray(results), 'entrée de classement invalide');
    const byId = new Map(clubIds.map(clubId => [clubId, {clubId, played: 0, won: 0, drawn: 0, lost: 0,
      pf: 0, pa: 0, tf: 0, ta: 0, terrain: 0, offensiveBonus: 0, defensiveBonus: 0, form: []}]));
    const scheduleById = schedule === undefined ? null : new Map(schedule.map(f => [f.id, f]));
    const matchIds = new Set();
    const pairs = new Set();
    const included = [];
    for (const r of results) {
      if (r?.competitionId !== LEAGUE || r.phase !== 'league') continue;
      fail(unique(r.pair, 2) && r.pair.every(id => byId.has(id)), 'club hors poule');
      const key = r.pair.join(':');
      fail(typeof r.fixtureId === 'string' && r.fixtureId && !matchIds.has(r.fixtureId) && !pairs.has(key), 'doublon de résultat');
      matchIds.add(r.fixtureId);
      pairs.add(key);
      const f = scheduleById?.get(r.fixtureId);
      fail(!scheduleById || (f?.competitionId === LEAGUE && f.phase === 'league' &&
        same(r.pair, [f.homeId, f.awayId])), 'résultat hors calendrier');
      scoreValid(r.score, r.tries);
      const round = f?.competitionRound ?? r.competitionRound;
      fail(round === undefined || integer(round, 0, 25), 'journée invalide');
      const date = f?.date ?? r.date;
      if (date !== undefined && date !== null) day(date);
      included.push({r, round, date: date || null, kickoff: f?.kickoffLocal || ''});
    }
    const allDated = included.every(match => match.date !== null);
    included.sort((a, b) => (allDated ? a.date.localeCompare(b.date) ||
      a.kickoff.localeCompare(b.kickoff) : (a.round ?? 26) - (b.round ?? 26)) ||
      a.r.fixtureId.localeCompare(b.r.fixtureId));
    for (const {r, round} of included) {
      for (const side of [0, 1]) {
        const row = byId.get(r.pair[side]);
        const other = 1 - side;
        const won = r.score[side] > r.score[other];
        const drawn = r.score[side] === r.score[other];
        const {base, bo, bd} = pointsFor(r.score, r.tries, side);
        row.played++;
        row.won += Number(won);
        row.drawn += Number(drawn);
        row.lost += Number(!won && !drawn);
        row.pf += r.score[side];
        row.pa += r.score[other];
        row.tf += r.tries[side];
        row.ta += r.tries[other];
        row.terrain += base + bo + bd;
        row.offensiveBonus += bo;
        row.defensiveBonus += bd;
        row.form.push(won ? 'W' : drawn ? 'D' : 'L');
        if (!allDated && round === undefined) row.orderUnknown = true;
      }
    }
    const drawOrder = tieBreaks.drawOrder;
    if (drawOrder !== undefined) fail(unique(clubIds.map(cid => drawOrder?.[cid]), 14), 'ordre de tirage incomplet');

    for (const row of byId.values()) {
      const deduction = deductions[row.clubId] ?? 0;
      fail(nat(deduction), 'retrait de points invalide');
      row.deduction = deduction;
      row.points = row.terrain - deduction;
      row.diff = row.pf - row.pa;
      row.tryDiff = row.tf - row.ta;
      row.bonus = row.offensiveBonus + row.defensiveBonus;
    }
    function resolve(group, missing) {
      for (const row of group) {
        if (missing) row.unavailableTieBreak = missing;
        if (drawOrder) row.tieResolution = 'game-draw';
        else row.unresolvedTie = true;
      }
      return group.sort((a, b) => drawOrder ? drawOrder[a.clubId] - drawOrder[b.clubId] : a.clubId - b.clubId);
    }
    const criteria = ['points', 'won', 'diff', 'pf'];
    function rank(group, index) {
      if (group.length < 2) return group;
      const skip = index - criteria.length + 1;
      if (skip > 0 && group.some(row => row.played > 1 && row.orderUnknown)) return resolve(group, 'match-order');
      if (skip > 0 && group.every(row => row.played <= skip)) return resolve(group);
      const buckets = new Map();
      for (const row of group) {
        const value = skip <= 0 ? row[criteria[index]] : row.form.slice(skip).filter(x => x === 'W').length;
        if (!buckets.has(value)) buckets.set(value, []);
        buckets.get(value).push(row);
      }
      return [...buckets.keys()].sort((a, b) => b - a).flatMap(value => rank(buckets.get(value), index + 1));
    }
    return rank([...byId.values()], 0).map(({orderUnknown, ...row}, i) => ({
      ...row, rank: i + 1, form: row.form.slice(-5),
    }));
  }

  function playoffSeeds(rows) {
    fail(Array.isArray(rows) && rows.length === 14 && rows.every((r, i) => r.rank === i + 1 && r.played === 26),
      'phase qualificative de 26 journées incomplète');
    const top = rows.slice(0, 6);
    fail(top.every(r => !r.unresolvedTie) && unique(top.map(r => r.clubId), 6), 'ordre des six qualifiés indéterminé');
    return top.map(r => r.clubId);
  }

  function kickAt(round, {length = 100, width = 70} = {}) {
    fail(integer(round, 0, 999) && Number.isFinite(length) && length > 64 &&
      Number.isFinite(width) && width > 30, 'géométrie du tir invalide');
    const position = round < 6 ? round + 1 : 4;
    const depth = position <= 3 ? 22 : length / 2 - 10;
    const lateral = [2, 5].includes(position) ? width / 2 - 15 :
      [3, 6].includes(position) ? 15 - width / 2 : 0;
    return {position, kicker: round % 3, depth, lateral, distance: Math.hypot(depth, lateral),
      angle: Math.atan2(Math.abs(lateral), depth)};
  }

  function shootoutWinner(q) {
    fail(q && integer(q.first, 0, 1) && integer(q.end, 0, 1) &&
      vector(q.score, 1000) && Array.isArray(q.attempts) && integer(q.attempts.length, 12, 2000) &&
      q.attempts.length % 2 === 0 && Array.isArray(q.eligible) && q.eligible.length === 2 &&
      q.eligible.every(team => Array.isArray(team) && integer(team.length, 3, 15) && unique(team, team.length, id)) &&
      new Set(q.eligible.flat()).size === q.eligible.flat().length &&
      Array.isArray(q.kickers) && q.kickers.length === 2 && q.kickers.every((team, s) =>
        unique(team, 3, id) && team.every(pid => q.eligible[s].includes(pid))), 'preuve de tirs au but invalide');
    const replacements = q.replacements ?? [];
    fail(Array.isArray(replacements) && replacements.length <= 24, 'liste de remplaçants invalide');
    const active = q.kickers.map(team => team.slice());
    const injured = new Set();
    const total = [0, 0];
    let nextReplacement = 0;
    for (const [i, kick] of q.attempts.entries()) {
      while (replacements[nextReplacement]?.before === i) {
        const change = replacements[nextReplacement++];
        const {side, kicker, outId, inId} = change;
        fail(integer(side, 0, 1) && integer(kicker, 0, 2) && active[side][kicker] === outId &&
          q.eligible[side].includes(inId) && !active[side].includes(inId) && !injured.has(inId), 'remplaçant inéligible');
        injured.add(outId);
        active[side][kicker] = inId;
      }
      const round = Math.floor(i / 2);
      const side = i % 2 === 0 ? q.first : 1 - q.first;
      const {position, kicker} = kickAt(round);
      fail(kick?.side === side && kick.position === position &&
        kick.playerId === active[side][kicker] && typeof kick.made === 'boolean', 'position, ordre ou buteur du tir invalide');
      total[side] += Number(kick.made);
      if (i % 2 === 1 && round >= 5 && !tied(total)) {
        fail(i === q.attempts.length - 1 && nextReplacement === replacements.length, 'tirs ajoutés après le tour décisif');
        fail(same(q.score, total), 'total des tirs incohérent');
        return winnerSide(total);
      }
    }
    fail(false, 'séance de tirs incomplète ou sans vainqueur');
  }

  function knockoutWinner(result) {
    fail(result?.competitionId === LEAGUE && knownPhase(result.phase) && unique(result.pair, 2), 'résultat éliminatoire invalide');
    const {pair, score, tries, overtime, shootout} = result;
    scoreValid(score, tries);
    if (overtime !== undefined || tied(score)) {
      fail(overtime && vector(overtime.regulationScore, 250) && tied(overtime.regulationScore) &&
        score.every((s, i) => s >= overtime.regulationScore[i]) && integer(overtime.regulationEnd, 80, 220) &&
        integer(overtime.firstEnd, overtime.regulationEnd + 10, 230) &&
        integer(overtime.end, overtime.firstEnd + 10, 240) &&
        (result.duration === undefined || result.duration === overtime.end), 'preuve de prolongation invalide');
    }
    const method = !tied(score) ? 'score' : !tied(tries) ? 'tries' : 'shootout';
    fail(method === 'shootout' || shootout === undefined, 'séance de tirs injustifiée');
    const side = method === 'score' ? winnerSide(score) : method === 'tries' ? winnerSide(tries) : shootoutWinner(shootout);
    const winner = pair[side];
    fail(result.winner === undefined || result.winner === winner, 'vainqueur incohérent');
    return {winner, method};
  }

  function resultFor(f, results) {
    const found = results.filter(r => r?.fixtureId === f.id);
    fail(found.length <= 1, 'doublon de résultat éliminatoire');
    if (found.length === 0) return null;
    const [r] = found;
    fail(r.phase === f.phase && r.competitionId === f.competitionId && r.season === f.season &&
      same(r.pair, [f.homeId, f.awayId]), 'résultat hors rencontre');
    return r;
  }

  function knockoutFixtures({phase, seeds, results = [], ...options}) {
    fail(Object.hasOwn(DATES, phase) && unique(seeds, 6) && Array.isArray(results), 'phase ou têtes de série invalides');
    const config = seasonConfig(options);
    const phases = Object.keys(DATES);
    const plan = (current, pairs) => pairs.map(([home, away], slot) => ({
      ...fixture(config, current, phases.indexOf(current), slot, home, away, shift(DATES[current], config),
        config.season === FIRST_SEASON ? 'worcester-published-stage-date' : 'generated-frozen-format'),
      dateStatus: config.season === FIRST_SEASON ? 'club-announced-stage-date' : 'generated',
      venuePolicy: current === 'final' ? 'higher-seed-home-unless-designated' : 'higher-seed-home',
    }));
    const winners = matches => matches.map(f => {
      const r = resultFor(f, results);
      return r === null ? null : knockoutWinner(r).winner;
    });
    const rank = (a, b) => seeds.indexOf(a) - seeds.indexOf(b);
    const [one, two, three, four, five, six] = seeds;
    const quarters = plan('quarter', [[three, six], [four, five]]);
    if (phase === 'quarter') return quarters;
    const q = winners(quarters);
    if (q.includes(null)) return [];
    const [better, worse] = q.sort(rank);
    const semis = plan('semi', [[one, worse], [two, better]]);
    if (phase === 'semi') return semis;
    const s = winners(semis);
    return s.includes(null) ? [] : plan('final', [s.sort(rank)]);
  }

  function finalOutcome(options) {
    const [f] = knockoutFixtures({...options, phase: 'final'});
    if (!f) return null;
    const r = resultFor(f, options.results || []);
    if (!r) return null;
    const {winner: champion} = knockoutWinner(r);
    return {champion, finalist: r.pair.find(cid => cid !== champion)};
  }

  function lowerPlan({ranked, national1, closedBoundary = false, results = [], dates = {}, ...options}) {
    fail(unique(ranked, 14) && Array.isArray(results), 'classement de relégation invalide');
    const config = seasonConfig(options);
    if (closedBoundary) return {status: 'closed-game-boundary', nextMembers: ranked.slice()};
    const plan = (phase, home, away, competitionId = LEAGUE) => {
      const date = dates[phase] ?? null;
      return {...fixture(config, phase, 0, 0, home, away, date,
        date ? 'caller-assigned-date' : 'awaiting-date', competitionId), venuePolicy: 'host-home'};
    };
    const [twelfth, thirteenth, bottom] = ranked.slice(-3);
    const relegation = plan('relegation', twelfth, thirteenth);
    const base = {directRelegation: bottom, relegation};
    if (!national1) return {...base, status: 'awaiting-national1'};
    const {ranked: nlr, approval = {}} = national1;
    fail(unique(nlr, 3) && nlr.every(cid => !ranked.includes(cid)), 'classement National 1 invalide');
    const eligibility = nlr.map(cid => approval[cid]);
    fail(eligibility.every(v => v === undefined || typeof v === 'boolean'), 'avis MOS invalide');
    if (eligibility.includes(undefined)) return {...base, status: 'awaiting-mos'};
    const directPromotion = nlr.find(cid => approval[cid]);
    if (directPromotion === undefined) return {...base, status: 'awaiting-rfu'};
    const rest = nlr.slice(1).filter(cid => cid !== directPromotion && approval[cid]);
    base.directPromotion = directPromotion;
    if (rest.length === 2) base.national1Playoff = plan('promotion', ...rest, 'national1-promotion');
    const relegationResult = resultFor(relegation, results);
    if (!relegationResult) return {...base, status: 'awaiting-relegation'};
    const loser = relegationResult.pair.find(cid => cid !== knockoutWinner(relegationResult).winner);
    let challenger = rest[0];
    if (base.national1Playoff) {
      const witnessed = resultFor(base.national1Playoff, results);
      if (!witnessed) return {...base, status: 'awaiting-national1-playoff'};
      scoreValid(witnessed.score, witnessed.tries);
      fail(witnessed.pair.includes(witnessed.winner) &&
        (tied(witnessed.score) || witnessed.winner === witnessed.pair[winnerSide(witnessed.score)]),
      'vainqueur National 1 incohérent');
      challenger = witnessed.winner;
    }
    if (challenger === undefined) return {...base, status: 'ready', promoted: [directPromotion], relegated: [bottom], reprieved: loser};
    const accession = plan('access', loser, challenger);
    const accessionResult = resultFor(accession, results);
    if (!accessionResult) return {...base, accession, status: 'awaiting-accession'};
    const moves = knockoutWinner(accessionResult).winner === challenger;
    return {...base, accession, status: 'ready',
      promoted: moves ? [directPromotion, challenger] : [directPromotion],
      relegated: moves ? [bottom, loser] : [bottom]};
  }

  return Object.freeze({
    LEAGUE, FROZEN_MODEL, EXTRA_TIME, PREM_PROMOTION_2026_27: false, calendarFixtures, terrainPoints,
    table, playoffSeeds, kickAt, shootoutWinner, knockoutWinner, knockoutFixtures, finalOutcome, lowerPlan,
  });
}

module.exports = {factory};
