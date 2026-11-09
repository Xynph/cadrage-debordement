'use strict';

function factory(geometry) {
  const LEAGUE = 'nationale';
  const ACCESS = 'access-nationale';
  const FROZEN_MODEL = 'nationale-2026-27-closed-14';
  const FIRST_SEASON = 2026;
  const ANCHOR = '2026-08-17';
  const DAY = 86_400_000;
  const PLAYOFF_DATES = Object.freeze({barrage: '2027-05-01', semi: '2027-05-08', final: '2027-05-15'});
  const ACCESS_DATES = Object.freeze(['2027-05-29', '2027-05-30']);
  const fail = (valid, reason) => { if (!valid) throw new Error(`Nationale — ${reason}.`); };
  const nonnegative = n => Number.isSafeInteger(n) && n >= 0;
  const list = (value, count) => Array.isArray(value) && value.length === count &&
    Array.from(value).every(nonnegative) && new Set(value).size === count;
  const same = (a, b) => Array.isArray(a) && a.length === b.length && b.every((id, i) => a[i] === id);
  const sameSet = (a, b) => list(a, b.length) && b.every(id => a.includes(id));
  const vector = v => Array.isArray(v) && v.length === 2 && Array.from(v).every(nonnegative);
  const higher = (a, b) => a === b ? null : a > b ? 0 : 1;

  function day(date) {
    fail(typeof date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(date), 'date invalide');
    const parsed = Date.parse(`${date}T00:00:00Z`);
    fail(Number.isFinite(parsed) && new Date(parsed).toISOString().slice(0, 10) === date, 'date invalide');
    return parsed;
  }

  function seasonConfig({season = FIRST_SEASON, anchor, weeks = 46, seasonModel} = {}) {
    fail(Number.isInteger(season) && season >= FIRST_SEASON && season <= 2200, 'saison invalide');
    fail(season === FIRST_SEASON || seasonModel === FROZEN_MODEL, 'convention de saison simulée requise');
    const opening = Date.UTC(season, 7, 21);
    const defaultAnchor = opening - ((new Date(opening).getUTCDay() + 6) % 7) * DAY;
    const start = anchor === undefined ? defaultAnchor : day(anchor);
    fail(new Date(start).getUTCDay() === 1 && Number.isInteger(weeks) && weeks > 0 && weeks <= 52,
      'ancre du lundi ou horizon invalide');
    return {season, start, weeks, offset: defaultAnchor - day(ANCHOR)};
  }

  function shifted(date, config) {
    return new Date(day(date) + config.offset).toISOString().slice(0, 10);
  }

  function weekOf(date, config) {
    const week = Math.floor((day(date) - config.start) / (7 * DAY));
    fail(week >= 0 && week < config.weeks, 'rencontre hors horizon');
    return week;
  }

  fail(geometry?.schema === 'nationale-calendar-geometry-v1' && geometry.season === FIRST_SEASON &&
    geometry.clubCount === 14 && geometry.anchor === ANCHOR && geometry.timezone === 'Europe/Paris' &&
    Array.isArray(geometry.fixtures) && geometry.fixtures.length === 182, 'calendrier source incomplet');
  const seasonOne = seasonConfig();
  const pairKeys = new Set();
  const roundClubs = new Set();
  const legPairs = new Set();
  const weekClubs = new Set();
  const fixtures = geometry.fixtures.map((f, i) => {
    const {home, away, competitionRound, slot, date, kickoffLocal} = f;
    fail(list([home, away], 2) && home < 14 && away < 14 && competitionRound === Math.floor(i / 7) &&
      slot === i % 7 && typeof kickoffLocal === 'string' && /^(?:[01]\d|2[0-3]):[0-5]\d$/.test(kickoffLocal),
    'calendrier source incohérent');
    const pairKey = `${home}:${away}`;
    fail(!pairKeys.has(pairKey), 'doublon de calendrier');
    pairKeys.add(pairKey);
    const legKey = `${Math.floor(competitionRound / 13)}:${Math.min(home, away)}:${Math.max(home, away)}`;
    fail(!legPairs.has(legKey), 'aller-retour dans la même moitié du calendrier');
    legPairs.add(legKey);
    const week = weekOf(date, seasonOne);
    for (const club of [home, away]) {
      const roundKey = `${competitionRound}:${club}`;
      const weekKey = `${week}:${club}`;
      fail(!roundClubs.has(roundKey) && !weekClubs.has(weekKey), 'collision du calendrier');
      roundClubs.add(roundKey);
      weekClubs.add(weekKey);
    }
    return {home, away, competitionRound, slot, date, kickoffLocal};
  });

  function calendarFixtures({clubs, ...options}) {
    fail(list(clubs, 14), 'liste des 14 clubs invalide');
    const config = seasonConfig(options);
    return fixtures.map(f => {
      const date = shifted(f.date, config);
      return {
        id: `${LEAGUE}:${config.season}:league:${f.competitionRound}:${f.slot}`,
        competitionId: LEAGUE, season: config.season, phase: 'league', round: f.competitionRound,
        competitionRound: f.competitionRound, week: weekOf(date, config), date,
        dateStatus: config.season === FIRST_SEASON ? 'published' : 'generated',
        kickoffLocal: f.kickoffLocal, timezone: 'Europe/Paris',
        homeId: clubs[f.home], awayId: clubs[f.away], neutral: false, venueHostId: clubs[f.home],
        venuePolicy: 'home', scheduleSource: config.season === FIRST_SEASON ? 'ffr-published' : 'generated-frozen-format',
      };
    });
  }

  function validateScore(score, tries) {
    fail(vector(score) && vector(tries) && score.every((n, i) => n >= 5 * tries[i]), 'score ou essais invalides');
  }

  function pointsFor(score, tries, side) {
    const other = 1 - side;
    const margin = score[side] - score[other];
    return {base: margin > 0 ? 4 : margin === 0 ? 2 : 0,
      bo: Number(tries[side] - tries[other] >= 3), bd: Number(margin < 0 && margin >= -7)};
  }

  function terrainPoints(score, tries) {
    validateScore(score, tries);
    return [0, 1].map(side => {
      const {base, bo, bd} = pointsFor(score, tries, side);
      return base + bo + bd;
    });
  }

  function table(clubIds, results, {fixtures: schedule, deductions = {}, tieBreaks = {}} = {}) {
    fail(list(clubIds, 14) && Array.isArray(results), 'entrée de classement invalide');
    const rows = new Map(clubIds.map(clubId => [clubId, {
      clubId, played: 0, won: 0, drawn: 0, lost: 0, pf: 0, pa: 0, tf: 0, ta: 0,
      terrain: 0, bonus: 0, offensiveBonus: 0, defensiveBonus: 0, administrativeBonus: 0,
      forfeits: 0, form: [],
    }]));
    const scheduled = schedule === undefined ? null : new Map(schedule.map(f => [f.id, f]));
    const matches = [];
    const seen = new Set();
    const pairs = new Set();
    for (const r of results) {
      if (r?.competitionId !== LEAGUE || r.phase !== 'league') continue;
      fail(list(r.pair, 2) && r.pair.every(id => rows.has(id)), 'club hors poule');
      const pairKey = r.pair.join(':');
      fail(typeof r.fixtureId === 'string' && r.fixtureId && !seen.has(r.fixtureId) && !pairs.has(pairKey),
        'doublon de résultat ou identifiant absent');
      seen.add(r.fixtureId);
      pairs.add(pairKey);
      const f = scheduled?.get(r.fixtureId);
      fail(!scheduled || (f?.competitionId === LEAGUE && f.phase === 'league' &&
        same(r.pair, [f.homeId, f.awayId])), 'résultat hors calendrier');
      validateScore(r.score, r.tries);
      const admin = r.administrative;
      if (admin !== undefined) {
        fail(admin && admin.kind === 'forfeit' && [0, 1].includes(admin.side) &&
          r.score[admin.side] === 0 && r.score[1 - admin.side] === 25 && same(r.tries, [0, 0]),
        'forfait simple non homologué');
      }
      const order = f?.competitionRound ?? r.competitionRound;
      fail(order === undefined || (Number.isInteger(order) && order >= 0 && order < 26), 'journée invalide');
      matches.push({r, order,
        points: admin ? (admin.side === 0 ? [-2, 5] : [5, -2]) : terrainPoints(r.score, r.tries)});
    }
    matches.sort((a, b) => (a.order ?? 0) - (b.order ?? 0) || (a.r.fixtureId < b.r.fixtureId ? -1 : 1));
    for (const {r, points, order} of matches) {
      for (const side of [0, 1]) {
        const row = rows.get(r.pair[side]);
        const other = 1 - side;
        const won = r.score[side] > r.score[other];
        const drawn = r.score[side] === r.score[other];
        row.played++;
        row.won += Number(won);
        row.drawn += Number(drawn);
        row.lost += Number(!won && !drawn);
        row.pf += r.score[side];
        row.pa += r.score[other];
        row.tf += r.tries[side];
        row.ta += r.tries[other];
        row.terrain += points[side];
        if (r.administrative) {
          row.forfeits += Number(r.administrative.side === side);
          row.administrativeBonus += Number(r.administrative.side !== side);
          if (r.administrative.side === side) {
            if (order === undefined) row.playoffEligibilityUnknown = true;
            else if (order >= 24) row.playoffIneligible = true;
          }
        } else {
          const {bo, bd} = pointsFor(r.score, r.tries, side);
          row.offensiveBonus += bo;
          row.defensiveBonus += bd;
        }
        row.form.push(won ? 'W' : drawn ? 'D' : 'L');
      }
    }
    for (const row of rows.values()) {
      const deduction = deductions[row.clubId] ?? 0;
      fail(nonnegative(deduction), 'retrait de points invalide');
      row.deduction = deduction;
      row.points = row.terrain - deduction;
      row.diff = row.pf - row.pa;
      row.tryDiff = row.tf - row.ta;
      row.bonus = row.offensiveBonus + row.defensiveBonus + row.administrativeBonus;
      row.form = row.form.slice(-5);
    }

    const drawOrder = tieBreaks.drawOrder;
    if (drawOrder !== undefined) {
      fail(list(clubIds.map(id => drawOrder?.[id]), clubIds.length), 'ordre de tirage incomplet');
    }
    function resolve(items, unavailableTieBreak) {
      for (const row of items) {
        if (unavailableTieBreak) row.unavailableTieBreak = unavailableTieBreak;
        if (drawOrder) row.tieResolution = 'game-draw';
        else row.unresolvedTie = true;
      }
      return items.slice().sort((a, b) => drawOrder ? drawOrder[a.clubId] - drawOrder[b.clubId] : a.clubId - b.clubId);
    }
    const direct = (field, direction = 1) => group => group.map(r => direction * r[field]);
    const supplied = field => Object.assign(group => {
      const values = group.map(row => tieBreaks[field]?.[row.clubId]);
      return values.every(nonnegative) ? values.map(n => -n) : null;
    }, {field});
    const h2h = metric => group => {
      const totals = new Map(group.map(r => [r.clubId, 0]));
      for (const {r, points} of matches) {
        if (!r.pair.every(id => totals.has(id))) continue;
        for (const side of [0, 1]) {
          const id = r.pair[side];
          totals.set(id, totals.get(id) + metric(r, points, side));
        }
      }
      return group.map(row => totals.get(row.clubId));
    };
    const criteria = [
      direct('points'),
      h2h((_r, points, s) => points[s]),
      h2h((r, _p, s) => r.score[s] - r.score[1 - s]),
      h2h((r, _p, s) => r.tries[s] - r.tries[1 - s]),
      direct('diff'), direct('tryDiff'), direct('pf'), direct('tf'), direct('forfeits', -1),
      supplied('suspensionWeeks'),
      // No previous phase exists in the single 26-round regular-season pool.
      supplied('previousRank'),
    ];
    function rank(group, index) {
      if (group.length < 2) return group;
      const criterion = criteria[index];
      if (!criterion) return resolve(group);
      const scores = criterion(group);
      if (!scores) return resolve(group, criterion.field);
      const bins = new Map();
      for (const [i, score] of scores.entries()) {
        if (!bins.has(score)) bins.set(score, []);
        bins.get(score).push(group[i]);
      }
      return [...bins.keys()].sort((a, b) => b - a).flatMap(score => rank(bins.get(score), index + 1));
    }
    return rank([...rows.values()], 0).map((row, index) => ({...row, rank: index + 1}));
  }

  function playoffSeeds(rows) {
    fail(Array.isArray(rows) && rows.length === 14 && rows.every((r, i) => r.rank === i + 1 && r.played === 26),
      'phase qualificative de 26 journées incomplète');
    const top = rows.slice(0, 6);
    fail(top.every(r => !r.playoffIneligible && !r.playoffEligibilityUnknown), 'qualification à faire homologuer après forfait');
    fail(top.every(r => !r.unresolvedTie) && list(top.map(r => r.clubId), 6), 'ordre des six qualifiés indéterminé');
    return top.map(r => r.clubId);
  }

  function shootoutWinner(extra) {
    const {kickers, attempts} = extra;
    const playerId = id => nonnegative(id) || (typeof id === 'string' && /^[A-Za-z0-9:_-]{1,180}$/.test(id));
    fail(Array.isArray(kickers) && kickers.length === 2 && kickers.every(k =>
      Array.isArray(k) && k.length >= 5 && k.length <= 15 &&
      Array.from(k).every(playerId) && new Set(k).size === k.length) &&
      new Set(kickers.flat()).size === kickers.flat().length &&
      Array.isArray(attempts) && attempts.length >= 5, 'preuve de tirs au but invalide');
    const first = [new Set(), new Set()];
    const rotation = [new Set(), new Set()];
    const totals = [0, 0];
    for (const [i, pair] of attempts.entries()) {
      fail(Array.isArray(pair) && pair.length === 2, 'deux tentatives par tour requises');
      for (const side of [0, 1]) {
        const kick = pair[side];
        fail(kick && typeof kick.scored === 'boolean' && kickers[side].includes(kick.playerId), 'buteur inéligible');
        if (i < 5) {
          fail(!first[side].has(kick.playerId), 'buteur répété en première série');
          first[side].add(kick.playerId);
          totals[side] += Number(kick.scored);
        } else {
          const seen = rotation[side];
          if (seen.size === kickers[side].length - 5) seen.clear();
          fail(!first[side].has(kick.playerId) && !seen.has(kick.playerId), 'buteur invalide dans la rotation');
          seen.add(kick.playerId);
        }
      }
      const decisive = i === 4 ? higher(...totals) :
        i > 4 ? higher(Number(pair[0].scored), Number(pair[1].scored)) : null;
      if (decisive !== null) {
        fail(i === attempts.length - 1, 'tirs ajoutés après le tour décisif');
        return decisive;
      }
    }
    fail(false, 'séance de tirs sans vainqueur');
  }

  function knockoutWinner(result) {
    fail(result?.competitionId === LEAGUE && Object.hasOwn(PLAYOFF_DATES, result.phase) && list(result.pair, 2),
      'résultat éliminatoire invalide');
    const {score, tries, pair, extra} = result;
    validateScore(score, tries);
    const scoreSide = higher(...score);
    if (extra !== undefined || scoreSide === null) {
      fail(extra && vector(extra.regulationScore) && extra.regulationScore[0] === extra.regulationScore[1] &&
        extra.extraMinutes === 20 && score.every((s, i) => s >= extra.regulationScore[i]), 'preuve de prolongation invalide');
    }
    const triesSide = higher(...tries);
    const side = scoreSide ?? triesSide ?? shootoutWinner(extra);
    const method = scoreSide !== null ? 'score' : triesSide !== null ? 'tries' : 'shootout';
    fail(method === 'shootout' || (!extra?.attempts && !extra?.kickers), 'tirs au but injustifiés');
    const winner = pair[side];
    fail(result.winner === undefined || result.winner === winner, 'vainqueur incohérent');
    return {winner, method};
  }

  function resultMatches(result, fixture) {
    return result.fixtureId === fixture.id && result.phase === fixture.phase &&
      result.competitionId === fixture.competitionId && same(result.pair, [fixture.homeId, fixture.awayId]);
  }

  function knockoutFixtures({phase, seeds, results = [], ...options}) {
    fail(Object.hasOwn(PLAYOFF_DATES, phase) && list(seeds, 6) && Array.isArray(results), 'phase ou têtes de série invalides');
    const config = seasonConfig(options);
    const phases = Object.keys(PLAYOFF_DATES);
    function plan(current, pairs) {
      const date = shifted(PLAYOFF_DATES[current], config);
      const round = phases.indexOf(current);
      const neutral = current === 'final';
      return pairs.map(([homeId, awayId], slot) => ({
        id: `${LEAGUE}:${config.season}:${current}:${round}:${slot}`, competitionId: LEAGUE,
        season: config.season, phase: current, round, competitionRound: round, week: weekOf(date, config),
        date, dateStatus: config.season === FIRST_SEASON ? 'published-phase-day' : 'generated',
        kickoffLocal: null, timezone: 'Europe/Paris', homeId, awayId, neutral,
        venueHostId: neutral ? null : homeId, venuePolicy: neutral ? 'organiser-designated' : 'higher-seed-home',
        venueDesignationPending: neutral,
        scheduleSource: config.season === FIRST_SEASON ? 'ffr-published-phase' : 'generated-frozen-format',
      }));
    }
    function winners(stage) {
      return stage.map(fixture => {
        const found = results.filter(r => r?.fixtureId === fixture.id);
        fail(found.length <= 1, 'doublon de résultat éliminatoire');
        if (found.length === 0) return null;
        fail(resultMatches(found[0], fixture), 'résultat affecté à la mauvaise rencontre');
        return knockoutWinner(found[0]).winner;
      });
    }
    const [one, two, three, four, five, six] = seeds;
    const barrage = plan('barrage', [[three, six], [four, five]]);
    if (phase === 'barrage') return barrage;
    const [b1, b2] = winners(barrage);
    if (b1 === null || b2 === null) return [];
    const semi = plan('semi', [[one, b2], [two, b1]]);
    if (phase === 'semi') return semi;
    const [m1, m2] = winners(semi);
    return m1 === null || m2 === null ? [] : plan('final', [[m1, m2]]);
  }

  function finalOutcome(options) {
    const [fixture] = knockoutFixtures({...options, phase: 'final'});
    if (!fixture) return null;
    const found = (options.results || []).filter(r => r?.fixtureId === fixture.id);
    fail(found.length <= 1, 'doublon de résultat de finale');
    if (found.length === 0) return null;
    const [result] = found;
    fail(resultMatches(result, fixture), 'résultat affecté à la mauvaise rencontre');
    const {winner: champion} = knockoutWinner(result);
    return {champion, finalist: result.pair.find(id => id !== champion)};
  }

  function accessPlan({nationaleFinal, proD2Rank, approval = {}, committeeDecision,
    result, resolveAccessTie, ...options}) {
    const {champion, finalist} = nationaleFinal || {};
    fail(list(proD2Rank, 16) && list([champion, finalist], 2) &&
      [champion, finalist].every(id => !proD2Rank.includes(id)), 'finale ou classement Pro D2 invalide');
    const config = seasonConfig(options);
    const [challenger, bottom] = proD2Rank.slice(-2);
    const c = approval[champion];
    const f = approval[finalist];
    for (const flag of [c, f]) fail(flag === undefined || typeof flag === 'boolean', 'avis du cahier des charges invalide');
    if (c === undefined || f === undefined) return {status: 'awaiting-approval', fixture: null};
    if (!c || !f) {
      fail(!result, 'résultat fourni pour un barrage non organisé');
      if (!c && !f) return {status: 'ready', fixture: null, promoted: [], relegated: [], retained: [challenger, bottom]};
      if (!c && !committeeDecision) return {status: 'awaiting-committee', fixture: null, retained: [challenger]};
      if (!c) {
        fail(committeeDecision.promoted === finalist && typeof committeeDecision.reference === 'string' &&
          committeeDecision.reference.trim(), 'décision de commission invalide');
      }
      return {status: 'ready', fixture: null, promoted: [c ? champion : finalist], relegated: [bottom],
        retained: [challenger], ...(c ? {} : {decisionReference: committeeDecision.reference})};
    }
    const dateWindow = ACCESS_DATES.map(d => shifted(d, config));
    const simulationDate = dateWindow[0];
    const fixture = {
      id: `${ACCESS}:${config.season}:access:0:0`, competitionId: ACCESS, season: config.season, phase: 'access',
      round: 0, competitionRound: 0, week: weekOf(simulationDate, config),
      date: null, dateWindow, simulationDate, dateStatus: config.season === FIRST_SEASON ? 'published-window' : 'generated-window',
      kickoffLocal: null, timezone: 'Europe/Paris', homeId: finalist, awayId: challenger,
      neutral: false, venueHostId: finalist, venuePolicy: 'nationale-finalist-home',
      scheduleSource: config.season === FIRST_SEASON ? 'lnr-published-window' : 'generated-frozen-format',
    };
    if (!result) return {status: 'awaiting-match', fixture};
    fail(resultMatches(result, fixture), 'résultat affecté à la mauvaise rencontre');
    validateScore(result.score, result.tries);
    const side = higher(...result.score);
    if (side === null && typeof resolveAccessTie !== 'function') return {status: 'awaiting-access-decision', fixture};
    const winner = side === null ? resolveAccessTie(result, fixture) : result.pair[side];
    fail(result.pair.includes(winner) && (result.winner === undefined || result.winner === winner), 'vainqueur de barrage incohérent');
    const promotedFinalist = winner === finalist;
    return {status: 'ready', fixture, winner, promoted: promotedFinalist ? [champion, finalist] : [champion],
      relegated: promotedFinalist ? [bottom, challenger] : [bottom], retained: promotedFinalist ? [] : [challenger]};
  }

  function combineFrenchMovements({members, ranks, topMovement, lower}) {
    const {elite, accession, nationale} = members || {};
    fail(list(elite, 14) && list(accession, 16) && list(nationale, 14) &&
      new Set([...elite, ...accession, ...nationale]).size === 44, 'partition française invalide');
    fail(sameSet(ranks?.elite, elite) && sameSet(ranks?.accession, accession), 'classements français incompatibles');
    const {promoted: up, relegated: down} = topMovement || {};
    fail(Array.isArray(up) && [1, 2].includes(up.length) && list(up, up.length) &&
      up.every(id => ranks.accession.slice(0, 6).includes(id)), 'promotion vers le Top 14 invalide');
    fail(same(down, ranks.elite.slice(-up.length).reverse()), 'relégation du Top 14 invalide');
    const except = (ids, dropped) => ids.filter(id => !dropped.includes(id));
    const nextElite = except(elite, down).concat(up);
    const unchangedProD2 = except(accession, up).concat(down);
    fail((topMovement.elite === undefined || sameSet(topMovement.elite, nextElite)) &&
      (topMovement.accession === undefined || sameSet(topMovement.accession, unchangedProD2)), 'partition Top 14–Pro D2 incohérente');

    const natFinal = lower?.nationaleFinal;
    fail(natFinal && [natFinal.champion, natFinal.finalist].every(id => nationale.includes(id)), 'finalistes hors Nationale');
    const transition = accessPlan({...lower, proD2Rank: ranks.accession});
    if (transition.status !== 'ready') return transition;
    const {promoted, relegated} = transition;
    const nextAccession = except(accession, [...up, ...relegated]).concat(down, promoted);
    const replacements = new Map(promoted.map((id, i) => [id, relegated[i]]));
    const nextNationale = nationale.map(id => replacements.get(id) ?? id);
    fail(nextAccession.length === 16 && nextNationale.length === 14 &&
      new Set([...nextElite, ...nextAccession, ...nextNationale]).size === 44, 'partition française finale incohérente');
    return {
      status: 'ready', elite: nextElite, accession: nextAccession, nationale: nextNationale,
      topBoundary: {promoted: up.slice(), relegated: down.slice()}, nationaleBoundary: transition,
      lowerBoundary: 'closed-without-nationale-2',
      epcrCandidateOrder: ranks.elite.filter(id => nextElite.includes(id))
        .concat(ranks.accession.filter(id => nextElite.includes(id))),
    };
  }

  function lineupCards(cards) {
    fail(Array.isArray(cards) && cards.length <= 23 &&
      Array.from(cards).every(c => c === null || ['A', 'B', 'C'].includes(c)), 'carte FFR invalide');
    const b = cards.filter(c => c === 'B').length;
    const c = cards.filter(c => c === 'C').length;
    const unknown = cards.filter(c => c === null).length;
    const status = b + c > 4 || c > 1 ? 'exceeded' : unknown > 0 ? 'unknown' : 'compliant';
    return {status, b, c, unknown};
  }

  return Object.freeze({
    LEAGUE, ACCESS, FROZEN_MODEL, calendarFixtures, terrainPoints, table, playoffSeeds,
    knockoutFixtures, knockoutWinner, finalOutcome, accessPlan, combineFrenchMovements, lineupCards,
  });
}

module.exports = {factory};
