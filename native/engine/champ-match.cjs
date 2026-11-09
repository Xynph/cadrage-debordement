'use strict';

// RFU 2026–27 regulation 4.3(c) and Schedule 5. The two played periods
// remain on the shared engine clock. Only the Champ decision is specialised.
module.exports = function champMatchFactory(rules, editionId = 'rugby-world-2026-11-09-champ-v5') {
  const ruleId = 'champ-rfu-2026-27-schedule5-v1';
  const phases = ['quarter', 'semi', 'final', 'relegation', 'access'];
  const sportKeys = ['score', 'tries', 'goals', 'goalAttempts', 'conversions', 'conversionAttempts'];
  const fail = (valid, reason) => { if (!valid) throw Error('Champ Rugby — ' + reason + '.'); };
  const integer = (n, min, max) => Number.isSafeInteger(n) && n >= min && n <= max;
  const vector = (v, max) => Array.isArray(v) && v.length === 2 && Array.from(v).every(n => integer(n, 0, max));
  const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  const tied = v => v[0] === v[1];
  const keys = (v, allowed) => v && typeof v === 'object' && !Array.isArray(v) &&
    Object.keys(v).length === allowed.length && allowed.every(k => Object.hasOwn(v, k));
  const isFixture = f => f?.competitionId === rules.LEAGUE && phases.includes(f.phase);

  function applies(l, s = S) {
    return isFixture(l?.worldContext) && s?.worldMode?.version === 5 && s.commonDatabase?.id === editionId &&
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

  function eligibleIds(l, side) {
    const sheet = l.sheets[side];
    return sheet.on.filter(id => id !== null && !sheet.sentOff.includes(id) &&
      !sheet.cards.some(card => card.id === id && card.until > l.minute));
  }

  function playShootout(l) {
    const eligible = [0, 1].map(side => eligiblePlayers(l, side));
    const players = eligible.map(team => team.slice().sort((a, b) =>
      skill(b, 'goal') - skill(a, 'goal') || a.id.localeCompare(b.id)).slice(0, 3));
    fail(players.every(team => team.length === 3), 'trois buteurs présents sur le terrain sont requis');
    const q = {first: rand(0, 1), end: rand(0, 1), eligible: eligible.map(team => team.map(p => p.id)),
      kickers: players.map(team => team.map(p => p.id)), attempts: [], score: [0, 0]};
    for (let round = 0; round < 1000; round++) {
      const {position, kicker, distance, angle} = rules.kickAt(round);
      for (const side of [q.first, 1 - q.first]) {
        const player = players[side][kicker];
        const chance = clamp(.23 + skill(player, 'goal', true) * .006 -
          Math.max(0, distance - 25) * .005 - angle * .13 + (unit(l, side, 'mental') - 70) * .001 -
          (l.weather === 'Vent' ? .16 : l.weather === 'Pluie' ? .06 : 0), .22, .93);
        const made = Math.random() < chance;
        q.attempts.push({side, playerId: player.id, position, made});
        q.score[side] += Number(made);
      }
      if (round >= 5 && !tied(q.score)) return q;
    }
    fail(false, 'séance de tirs sans vainqueur après 1000 tours');
  }

  function asRuleResult(r) {
    if (!isFixture(r) || r.champExtra === undefined) return r;
    const p = r.champExtra;
    const overtime = {regulationEnd: p.regulationEnd, firstEnd: p.firstEnd, end: p.end,
      regulationScore: p.regulation.score};
    return {...r, overtime, ...(r.decision?.shootout ? {shootout: r.decision.shootout} : {})};
  }

  function finish(l) {
    fail(applies(l), 'contexte de phase finale v5 requis');
    if (!l.knockout && tied(l.score)) {
      fail(l.champExtra === undefined, 'prolongation déjà ouverte');
      const regulation = sport(l);
      fail(CDWorldKnockout.finish(l) && l.knockout?.period === 1, 'première prolongation non ouverte');
      l.champExtra = {version: 1, ruleId, regulationEnd: l.knockout.regulationEnd, firstEnd: null,
        end: null, regulation, first: null};
      return true;
    }
    const p = l.champExtra;
    if (l.knockout?.period === 1) {
      fail(p && p.firstEnd === null, 'première prolongation incohérente');
      const first = sport(l);
      addEvent(l, 'Une minute d’intervalle réglementaire entre les prolongations.', 'break');
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
    const {competitionId, phase} = l.worldContext;
    const framed = asRuleResult({competitionId, phase, pair: l.pair, score: l.score, tries: l.tries,
      champExtra: p, duration: l.minute, decision});
    const {winner, method} = rules.knockoutWinner(framed);
    l.winner = winner;
    l.decision = {method, ...decision};
    if (method !== 'score') addEvent(l, S.clubs[winner].abbr +
      (method === 'tries' ? ' se qualifie au nombre d’essais.' : ' remporte la séance de tirs au but.'), 'end');
    return false;
  }

  function historyFields(l) {
    return applies(l) && l.champExtra ? {champExtra: JSON.parse(JSON.stringify(l.champExtra))} : {};
  }

  function validateExtra(p, current, minute, finished) {
    fail(keys(p, ['version', 'ruleId', 'regulationEnd', 'firstEnd', 'end', 'regulation', 'first']) &&
      p.version === 1 && p.ruleId === ruleId && integer(p.regulationEnd, 80, minute) &&
      (p.firstEnd === null ? p.first === null && !finished : integer(p.firstEnd, p.regulationEnd + 10, minute)) &&
      (finished ? p.end === minute && p.end >= p.firstEnd + 10 : p.end === null), 'chronologie de prolongation invalide');
    validateSport(p.regulation);
    fail(tied(p.regulation.score), 'prolongation après un score décisif');
    if (p.firstEnd !== null) validateSport(p.first, p.regulation);
    validateSport(current, p.first || p.regulation);
  }

  function foreignProof(r) {
    return r.srpExtra !== undefined || r.japanExtra !== undefined || r.nationaleExtra !== undefined ||
      r.overtime !== undefined || r.shootout !== undefined || r.extra !== undefined;
  }

  function validateResult(r, f, live = null) {
    fail(isFixture(f) && same(r.pair, [f.homeId, f.awayId]) && ['Sec', 'Vent', 'Pluie'].includes(r.weather) &&
      !foreignProof(r), 'résultat hors calendrier');
    if (!live) fail(r.fixtureId === f.id && r.competitionId === f.competitionId &&
      r.phase === f.phase && r.season === f.season, 'identifiant du résultat incohérent');
    const minute = live ? live.minute : r.duration;
    fail(integer(minute, 80, 240), 'durée de match invalide');
    const current = sport(r);
    const p = r.champExtra;
    if (p === undefined) validateSport(current);
    else validateExtra(p, current, minute, true);
    const d = r.decision;
    const hasShootout = tied(r.score) && tied(r.tries);
    fail(keys(d, hasShootout ? ['method', 'extraTime', 'redCards', 'shootout'] :
      ['method', 'extraTime', 'redCards']) && d.extraTime === (p !== undefined) &&
      vector(d.redCards, 23) && r.pair.includes(r.winner), 'décision éliminatoire incomplète');
    if (live) fail(same(d.redCards, live.sheets.map(sh => sh.redCards.length)), 'exclusions différentes de la feuille');
    if (hasShootout) {
      const q = d.shootout;
      fail(keys(q, ['first', 'end', 'eligible', 'kickers', 'attempts', 'score']) &&
        Array.isArray(q.attempts) && q.attempts.length <= 2000 &&
        q.attempts.every(k => keys(k, ['side', 'playerId', 'position', 'made'])), 'preuve de tirs au but invalide');
      if (live) fail(same(q.eligible, [0, 1].map(side => eligibleIds(live, side))),
        'buteurs différents des joueurs présents sur le terrain');
    }
    const official = rules.knockoutWinner(asRuleResult({...r, competitionId: f.competitionId, phase: f.phase}));
    fail(r.winner === official.winner && d.method === official.method, 'décision différente de la preuve');
  }

  function validateLive(l, f) {
    fail(isFixture(l?.worldContext) && isFixture(f) && l.worldContext.phase === f.phase &&
      (l.worldContext.fixtureId ?? l.worldContext.id) === f.id && same(l.pair, [f.homeId, f.awayId]) &&
      !foreignProof(l) && ['Sec', 'Vent', 'Pluie'].includes(l.weather) &&
      l.flowVersion === 1 && l.restartVersion === 1 && Array.isArray(l.restartLog),
    'contexte de match incompatible');
    const p = l.champExtra;
    if (p === undefined) {
      fail(l.knockout === undefined, 'prolongation sans preuve Champ');
      validateSport(sport(l));
    } else {
      validateExtra(p, sport(l), l.minute, l.finished);
      const period = p.firstEnd === null ? 1 : 2;
      const clock = l.knockout;
      fail(keys(clock, ['version', 'period', 'regulationEnd', 'firstEnd']) && clock.version === 1 &&
        clock.period === period && clock.regulationEnd === p.regulationEnd && clock.firstEnd === p.firstEnd &&
        l.flow?.period === 2 && integer(l.flow.firstEnd, 40, p.regulationEnd - 40) &&
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
