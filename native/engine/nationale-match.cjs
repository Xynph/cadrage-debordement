'use strict';

// FFR arts. 454–455 and rule 8. Keep the shared 2 × 10 minute clock and its
// restarts, with an edition-specific decision and evidence after both periods.
module.exports = function nationaleMatchFactory(rules) {
  const editions = {4:'rugby-world-2026-11-09-nationale-v4',5:'rugby-world-2026-11-09-champ-v5'};
  const phases = ['barrage', 'semi', 'final'];
  const sportKeys = ['score', 'tries', 'goals', 'goalAttempts', 'conversions', 'conversionAttempts'];
  const fail = (valid, reason) => { if (!valid) throw Error('Nationale — ' + reason + '.'); };
  const integer = (n, min, max) => Number.isSafeInteger(n) && n >= min && n <= max;
  const vector = (a, max) => Array.isArray(a) && a.length === 2 && Array.from(a).every(n => integer(n, 0, max));
  const equal = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  const keys = (v, allowed) => v && typeof v === 'object' && !Array.isArray(v) &&
    Object.keys(v).length === allowed.length && allowed.every(k => Object.hasOwn(v, k));
  const tied = values => values[0] === values[1];
  const playerId = id => typeof id === 'string' && /^[A-Za-z0-9:_-]{1,180}$/.test(id);
  const isFixture = f => f?.competitionId === 'nationale' && phases.includes(f.phase);

  function applies(l, s = S) {
    return isFixture(l?.worldContext) && [4,5].includes(s?.worldMode?.version) && s.commonDatabase?.id === editions[s.worldMode.version] &&
      typeof CDWorldCareer !== 'undefined' && CDWorldCareer.active(s) === true;
  }

  function sport(l) {
    fail(vector(l.score, 250) && vector(l.tries, 50) && Array.isArray(l.stats) && l.stats.length === 2 &&
      l.stats.every(s => s && typeof s === 'object'), 'statistiques de match invalides');
    return {score: l.score.slice(), tries: l.tries.slice(),
      ...Object.fromEntries(sportKeys.slice(2).map(k => [k, l.stats.map(s => s[k])]))};
  }

  function validateSport(now, prior) {
    fail(keys(now, sportKeys) && vector(now.score, 250) && vector(now.tries, 50) &&
      sportKeys.slice(2).every(k => vector(now[k], 1000)), 'preuve de score invalide');
    for (const side of [0, 1]) {
      fail(now.goals[side] <= now.goalAttempts[side] && now.conversions[side] <= now.conversionAttempts[side] &&
        now.conversionAttempts[side] === now.tries[side] &&
        now.score[side] === now.tries[side] * 5 + now.conversions[side] * 2 + now.goals[side] * 3,
      'score incompatible avec les actions');
      if (prior) fail(sportKeys.every(k => now[k][side] >= prior[k][side]), 'compteur sportif rétroactif');
    }
  }

  function eligiblePlayers(l, side) {
    return activePlayers(l, side).filter(p => !l.sheets[side].sentOff.includes(p.id));
  }

  function playShootout(l) {
    const eligible = [0, 1].map(i => eligiblePlayers(l, i));
    const players = eligible.map(team => team.slice().sort((a, b) =>
      skill(b, 'goal') - skill(a, 'goal') || a.id.localeCompare(b.id)));
    fail(players.every(team => team.length >= 5), 'cinq buteurs éligibles requis');
    const q = {first: rand(0, 1), end: rand(0, 1), eligible: eligible.map(list => list.map(p => p.id)),
      score: [0, 0], attempts: []};
    const {distance, angle} = goalKickGeometry(true, 35);
    for (let round = 0; round < 1000; round++) {
      if (round >= 5) fail(players.every(team => team.length > 5), 'relance sans autre buteur admissible');
      const kicks = [];
      for (const side of [q.first, 1 - q.first]) {
        const team = players[side];
        const player = team[round < 5 ? round : 5 + (round - 5) % (team.length - 5)];
        const probability = clamp(.23 + skill(player, 'goal', true) * .006 -
          Math.max(0, distance - 25) * .005 - angle * .13 + (unit(l, side, 'mental') - 70) * .001 -
          (l.weather === 'Vent' ? .16 : l.weather === 'Pluie' ? .06 : 0), .22, .93);
        const scored = Math.random() < probability;
        kicks.push({side, playerId: player.id, scored});
        q.score[side] += Number(scored);
      }
      q.attempts.push(kicks);
      if (round >= 4 && !tied(q.score)) return q;
    }
    fail(false, 'séance de tirs sans vainqueur après 1000 tours');
  }

  function asRuleResult(r) {
    if (!isFixture(r) || r.nationaleExtra === undefined) return r;
    const p = r.nationaleExtra;
    const q = r.decision?.shootout;
    const extra = {regulationScore: p.regulation.score, extraMinutes: 20};
    if (q) {
      extra.kickers = q.eligible;
      extra.attempts = q.attempts.map(kicks => q.first === 0 ? kicks : [kicks[1], kicks[0]]);
    }
    return {...r, extra};
  }

  function finish(l) {
    fail(applies(l), 'contexte de phase finale v4 requis');
    if (!l.knockout && tied(l.score)) {
      fail(l.nationaleExtra === undefined, 'prolongation déjà ouverte');
      const regulation = sport(l);
      fail(CDWorldKnockout.finish(l) && l.knockout?.period === 1, 'première prolongation non ouverte');
      l.nationaleExtra = {version: 1, regulationEnd: l.knockout.regulationEnd, firstEnd: null,
        end: null, regulation, first: null};
      return true;
    }
    const p = l.nationaleExtra;
    if (l.knockout?.period === 1) {
      fail(p && p.firstEnd === null, 'première prolongation incohérente');
      const first = sport(l);
      fail(CDWorldKnockout.finish(l) && l.knockout.period === 2, 'seconde prolongation non ouverte');
      p.first = first;
      p.firstEnd = l.knockout.firstEnd;
      return true;
    }
    if (p) {
      fail(p.end === null && l.knockout?.period === 2, 'seconde prolongation incohérente');
      p.end = l.minute;
    }
    const shootout = tied(l.score) && tied(l.tries) ? playShootout(l) : null;
    const decision = {extraTime: Boolean(p), redCards: l.sheets.map(sh => sh.redCards.length),
      ...(shootout ? {shootout} : {})};
    const framed = asRuleResult({...l, ...l.worldContext, decision});
    const {winner, method} = rules.knockoutWinner(framed);
    l.winner = winner;
    l.decision = {method, ...decision};
    if (method !== 'score') addEvent(l, S.clubs[winner].abbr +
      (method === 'tries' ? ' se qualifie au nombre d’essais.' : ' remporte la séance de tirs au but.'), 'end');
    return false;
  }

  function historyFields(l) {
    return applies(l) && l.nationaleExtra ? {nationaleExtra: JSON.parse(JSON.stringify(l.nationaleExtra))} : {};
  }

  function validateExtra(p, current, minute, finished) {
    fail(keys(p, ['version', 'regulationEnd', 'firstEnd', 'end', 'regulation', 'first']) &&
      p.version === 1 && integer(p.regulationEnd, 80, minute) &&
      (p.firstEnd === null ? p.first === null && !finished : integer(p.firstEnd, p.regulationEnd + 10, minute)) &&
      (finished ? p.end === minute && p.end >= p.firstEnd + 10 : p.end === null),
    'chronologie de prolongation invalide');
    validateSport(p.regulation);
    fail(tied(p.regulation.score), 'prolongation après un score décisif');
    if (p.firstEnd !== null) validateSport(p.first, p.regulation);
    validateSport(current, p.first || p.regulation);
  }

  function validateShootout(q, live) {
    fail(keys(q, ['first', 'end', 'eligible', 'score', 'attempts']) && integer(q.first, 0, 1) &&
      integer(q.end, 0, 1) && vector(q.score, 1000) && Array.isArray(q.eligible) && q.eligible.length === 2 &&
      q.eligible.every(team => Array.isArray(team) && integer(team.length, 5, 15) && team.every(playerId) &&
        new Set(team).size === team.length) &&
      new Set(q.eligible.flat()).size === q.eligible.flat().length &&
      Array.isArray(q.attempts) && integer(q.attempts.length, 5, 1000), 'preuve de tirs au but invalide');
    if (live) fail(equal(q.eligible, live.sheets.map(sh => sh.on.filter(id => id &&
      !sh.sentOff.includes(id) && !sh.cards.some(c => c.id === id && c.until > live.minute)))),
      'buteurs incompatibles avec la feuille');
    const total = [0, 0];
    for (const pair of q.attempts) {
      fail(Array.isArray(pair) && pair.length === 2 && [q.first, 1 - q.first].every((side, i) =>
        keys(pair[i], ['side', 'playerId', 'scored']) && pair[i].side === side &&
        playerId(pair[i].playerId) && typeof pair[i].scored === 'boolean'), 'ordre des tirs au but invalide');
      for (const kick of pair) total[kick.side] += Number(kick.scored);
    }
    fail(equal(total, q.score), 'total des tirs au but incohérent');
  }

  function validateResult(r, f, live = null) {
    fail(isFixture(f) && equal(r.pair, [f.homeId, f.awayId]) && ['Sec', 'Vent', 'Pluie'].includes(r.weather) &&
      r.srpExtra === undefined && r.japanExtra === undefined && r.extra === undefined, 'résultat hors calendrier');
    if (!live) fail(r.fixtureId === f.id && r.competitionId === f.competitionId &&
      r.phase === f.phase && r.season === f.season, 'identifiant du résultat incohérent');
    const minute = live ? live.minute : r.duration;
    fail(integer(minute, 80, 240), 'durée de match invalide');
    const current = sport(r);
    const p = r.nationaleExtra;
    if (p === undefined) validateSport(current);
    else validateExtra(p, current, minute, true);
    const d = r.decision;
    const hasShootout = tied(r.score) && tied(r.tries);
    fail(keys(d, hasShootout ? ['method', 'extraTime', 'redCards', 'shootout'] :
      ['method', 'extraTime', 'redCards']) && d.extraTime === (p !== undefined) &&
      vector(d.redCards, 23) && r.pair.includes(r.winner), 'décision éliminatoire incomplète');
    if (live) fail(equal(d.redCards, live.sheets.map(sh => sh.redCards.length)), 'exclusions différentes de la feuille');
    if (hasShootout) validateShootout(d.shootout, live);
    const official = rules.knockoutWinner(asRuleResult({...r, competitionId: f.competitionId, phase: f.phase}));
    fail(r.winner === official.winner && d.method === official.method, 'décision différente de la preuve');
  }

  function validateLive(l, f) {
    fail(isFixture(l?.worldContext) && isFixture(f) && l.worldContext.phase === f.phase &&
      (l.worldContext.fixtureId ?? l.worldContext.id) === f.id && equal(l.pair, [f.homeId, f.awayId]) &&
      l.srpExtra === undefined && l.japanExtra === undefined && l.extra === undefined &&
      l.flowVersion === 1 && l.restartVersion === 1 && Array.isArray(l.restartLog), 'contexte de match incompatible');
    const p = l.nationaleExtra;
    if (p === undefined) {
      fail(l.knockout === undefined, 'prolongation sans preuve Nationale');
      validateSport(sport(l));
    } else {
      validateExtra(p, sport(l), l.minute, l.finished);
      const period = p.firstEnd === null ? 1 : 2;
      const clock = l.knockout;
      fail(keys(clock, ['version', 'period', 'regulationEnd', 'firstEnd']) && clock.version === 1 &&
        clock.period === period && clock.regulationEnd === p.regulationEnd && clock.firstEnd === p.firstEnd &&
        l.flow?.period === 2 && p.regulationEnd >= l.flow.firstEnd + 40 &&
        l.flow.fullEnd === (p.firstEnd ?? p.regulationEnd) + 10, 'horloge de prolongation incohérente');
      const restarts = l.restartLog.filter(r => r.cause === 'extra-first' || r.cause === 'extra-second');
      fail(restarts.length === period && restarts.every((r, i) => r.kind === 'kickoff' &&
        r.cause === (i === 0 ? 'extra-first' : 'extra-second') &&
        r.team === (i === 0 ? l.firstKickoff : 1 - l.firstKickoff) &&
        r.minute === (i === 0 ? p.regulationEnd : p.firstEnd)), 'reprise de prolongation incohérente');
    }
    if (l.finished) validateResult(l, f, l);
    else fail(l.decision === undefined && l.winner === undefined, 'décision avant la fin');
  }

  return Object.freeze({isFixture, applies, finish, historyFields, asRuleResult, validateResult, validateLive});
};
