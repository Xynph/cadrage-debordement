'use strict';

// Native VM factory. These periods use the expressly provisional 2026 Pacific
// reference. The calendar/bracket and the playing policy are separate editions.
module.exports = function srpMatchFactory(rules) {
  const policy = rules.referencePolicy;
  const causes = Object.freeze({
    'super-point': 'srp-super-point', 'extra-first': 'srp-extra-first',
    'extra-second': 'srp-extra-second', 'sudden-death': 'srp-sudden-death',
  });
  const scoringFields = ['goals', 'goalAttempts', 'conversions', 'conversionAttempts'];
  const clone = value => JSON.parse(JSON.stringify(value));
  const equal = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  const integer = (n, min, max) => Number.isSafeInteger(n) && n >= min && n <= max;
  const pair = (a, max) => Array.isArray(a) && a.length === 2 && a.every(n => integer(n, 0, max));
  const plain = value => value !== null && typeof value === 'object' && !Array.isArray(value);
  const keys = (value, allowed) => plain(value) && Object.keys(value).length === allowed.length && allowed.every(k => Object.hasOwn(value, k));
  const check = (ok, reason) => { if (!ok) throw Error('Super Rugby Pacific — ' + reason); };
  const golden = kind => kind === 'super-point' || kind === 'sudden-death';
  const tied = score => score[0] === score[1];
  const lastPeriod = l => Array.isArray(l?.srpExtra?.periods) ? l.srpExtra.periods.at(-1) : null;
  const playerId = id => typeof id === 'string' && /^[A-Za-z0-9:_-]{1,180}$/.test(id);

  function applies(l, s = S) {
    return !!l && l.worldContext?.competitionId === 'srp' && [2,3,4,5].includes(s?.worldMode?.version)
      && typeof CDWorldCareer !== 'undefined' && CDWorldCareer.active(s) === true;
  }

  function witness(r, minute) {
    return {minute, score: r.score.slice(), tries: r.tries.slice(),
      ...Object.fromEntries(scoringFields.map(key => [key, r.stats.map(stats => stats[key])]))};
  }

  function eligibleKickers(l, side) {
    return activePlayers(l, side).filter(p => !l.sheets[side].sentOff.includes(p.id));
  }

  function playShootout(l) {
    const eligible = [0,1].map(side => eligibleKickers(l, side));
    const chosen = eligible.map(group => group.slice().sort((a,b) => skill(b,'goal')-skill(a,'goal') || a.id.localeCompare(b.id)).slice(0,5));
    check(chosen.every(group => group.length === 5), 'cinq tireurs éligibles requis par équipe.');
    const record = {kickers: chosen.map(group => group.map(p => p.id)), end: rand(0,1), first: rand(0,1),
      score: [0,0], attempts: [], eligible: eligible.map(group => group.map(p => p.id))};
    const taken = [0,0];
    let winner = null;
    for (let round = 0; winner === null && round < 1000; round++) {
      const location = round % 3 + 1;
      const depth = 22, offset = location === 1 ? 0 : 20;
      const distance = Math.hypot(depth, offset), angle = Math.atan2(offset, depth);
      for (const side of [record.first, 1-record.first]) {
        const p = chosen[side][round % 5];
        const weather = l.weather === 'Vent' ? .16 : l.weather === 'Pluie' ? .06 : 0;
        const chance = clamp(.23 + skill(p,'goal',true)*.006 - Math.max(0,distance-25)*.005 - angle*.13
          + (unit(l,side,'mental')-70)*.001 - weather, .22, .93);
        const made = Math.random() < chance;
        record.attempts.push({side, playerId: p.id, location, made});
        taken[side]++;
        if (made) record.score[side]++;
        if (round < 5 && record.score[0] > record.score[1] + 5 - taken[1]) winner = 0;
        if (round < 5 && record.score[1] > record.score[0] + 5 - taken[0]) winner = 1;
        if (winner !== null) break;
      }
      if (round >= 5 && record.score[0] !== record.score[1]) winner = record.score[0] > record.score[1] ? 0 : 1;
    }
    check(winner !== null && rules.shootoutWinner(record, policy, record.eligible) === winner, 'tirs sans décision valide.');
    return {winner, record};
  }

  function declareKnockout(l, winnerSide, method, shootout = null) {
    check(integer(winnerSide,0,1), 'vainqueur éliminatoire absent.');
    l.winner = l.pair[winnerSide];
    l.decision = {method, extraTime: Boolean(l.srpExtra), redCards: l.sheets.map(sh => sh.redCards.length), ...(shootout ? {shootout} : {})};
    if (shootout) addEvent(l, `${S.clubs[l.winner].abbr} se qualifie aux tirs au but.`, 'end');
  }

  function finish(l) {
    check(applies(l), 'contexte Pacific v2 requis.');
    const prior = lastPeriod(l);
    if (prior) {
      check(prior.end === null, 'période déjà enregistrée.');
      prior.end = witness(l,l.minute);
    }
    const phase = l.worldContext.phase;
    const next = rules.nextMatchPeriod({phase, period: prior?.kind || 'regulation', score: l.score, policy});
    if (next.period === 'finished') {
      if (phase !== 'league') declareKnockout(l, next.winnerSide, 'score');
      return false;
    }
    if (next.period === 'shootout') {
      const {winner,record} = playShootout(l);
      declareKnockout(l, winner, 'shootout', record);
      return false;
    }

    if (!l.srpExtra) l.srpExtra = {version: 1, policy, regulation: witness(l,l.minute), periods: []};
    // A rest interval has no played minutes. The second extra period swaps
    // the kicker. Other starts use a simulated coin toss under this policy.
    const kickoff = next.period === 'extra-second' ? 1-prior.kickoff : rand(0,1);
    const period = {kind: next.period, start: l.minute, limit: l.minute+next.minutes,
      rest: next.rest, kickoff, firstScore: null, end: null};
    l.srpExtra.periods.push(period);
    l.flow.fullEnd = period.limit;
    l.flow.ballDead = false;
    const message = {
      'super-point':'Super Point. La première marque décide de la rencontre.',
      'extra-first':'Prolongation. Première période de dix minutes.',
      'extra-second':'Prolongation. Changement de camp et seconde période de dix minutes.',
      'sudden-death':'Mort subite. La première marque décide de la qualification.',
    }[period.kind];
    addEvent(l, message, 'break');
    check(performKickRestart(l,'kickoff',kickoff,causes[period.kind],1-kickoff), 'reprise de prolongation refusée.');
    return true;
  }

  function goldenPeriod(l) {
    if (!applies(l) || l.finished) return null;
    const p = lastPeriod(l);
    return p && p.end === null && golden(p.kind) ? p : null;
  }

  let installed = false;
  function installHooks() {
    if (installed) return;
    installed = true;
    const oldRegister = registerRestart, oldFlowScored = flowScored, oldScoreTry = scoreTry, oldCapture = captureMatchAction;
    captureMatchAction = function(l, type, meta) {
      if (l.userSide < 0 && (type === 'try' || type === 'goal') && goldenPeriod(l) && integer(meta?.team,0,1)) {
        // Automated games omit presentation scenes. Use the real capture for
        // this one causal scoring event without changing the simulated match.
        return oldCapture({...l,userSide:meta.team},type,meta);
      }
      return oldCapture.apply(this,arguments);
    };
    registerRestart = function(l, kind, team, at, cause, by, origin) {
      if (!applies(l) || !Object.values(causes).includes(cause)) return oldRegister.apply(this, arguments);
      const p = lastPeriod(l);
      check(p && kind === 'kickoff' && p.start === l.minute && causes[p.kind] === cause && p.kickoff === team, 'reprise Pacific hors période.');
      const replacement = p.kind === 'extra-second' ? 'extra-second' : 'extra-first';
      const restart = oldRegister(l, kind, team, at, replacement, by, origin);
      if (restart) restart.cause = cause;
      return restart;
    };
    flowScored = function(l, side) {
      const p = goldenPeriod(l);
      if (!p) return oldFlowScored.apply(this, arguments);
      const action = l.events.at(-1);
      check(!p.firstScore && ['try','goal'].includes(action?.type) && action.scene?.team === side, 'première marque sans action causale.');
      p.firstScore = {kind: action.type, side, minute: l.minute};
      endFlowPeriod(l);
      return true;
    };
    scoreTry = function(l, side, origin, startAt = l.territory) {
      if (!goldenPeriod(l)) return oldScoreTry.apply(this, arguments);
      if (!beforeTryUnderAdvantage(l,side)) return;
      l.tries[side]++;
      l.score[side] += 5;
      const scorer = actionPlayer(l,side);
      addEvent(l, `${S.clubs[l.pair[side]].abbr} · Essai décisif${scorer ? ' de '+scorer.name : ''}. ${l.score.join(' – ')}.`, 'try',
        {kind:'try',team:side,actor:scorer?.id||null,from:{x:startAt,y:35},to:{x:attackingGoal(side),y:35},possession:side});
      flowScored(l,side);
    };
  }

  function historyFields(l) {
    return applies(l) && l.srpExtra ? {srpExtra: clone(l.srpExtra)} : {};
  }

  function witnessValid(data, skippedConversionSide = null, minMinute = 80) {
    check(keys(data,['minute','score','tries',...scoringFields]) && integer(data.minute,minMinute,240)
      && pair(data.score,250) && pair(data.tries,50) && scoringFields.every(key => pair(data[key],1000)), 'preuve de score ou durée invalide.');
    for (const side of [0,1]) {
      const expectedAttempts = data.tries[side] - (skippedConversionSide === side ? 1 : 0);
      check(data.goalAttempts[side] >= data.goals[side] && data.conversionAttempts[side] >= data.conversions[side]
        && data.conversionAttempts[side] === expectedAttempts
        && data.score[side] === data.tries[side]*5 + data.conversions[side]*2 + data.goals[side]*3, 'score incompatible avec les actions.');
    }
  }

  function cumulative(before, after) {
    check(['score','tries',...scoringFields].every(key => after[key].every((n,side) => n >= before[key][side])), 'compteurs sportifs rétroactifs.');
  }

  function goldenProof(before, after, score) {
    if (score === null) {
      check(equal(before.score, after.score), 'variation sans première marque.');
      return;
    }
    check(keys(score,['kind','side','minute']) && ['try','goal'].includes(score.kind)
      && integer(score.side,0,1) && score.minute === after.minute, 'première marque invalide.');
    const side = score.side, other = 1-side, isTry = score.kind === 'try';
    check(after.score[side] === before.score[side] + (isTry ? 5 : 3) && after.score[other] === before.score[other]
      && after.tries[side] === before.tries[side]+(isTry ? 1 : 0) && after.goals[side] === before.goals[side]+(isTry ? 0 : 1)
      && equal(after.conversions,before.conversions) && equal(after.conversionAttempts,before.conversionAttempts),
    'la première marque doit arrêter le match sans action supplémentaire.');
  }

  function validateExtra(proof, phase, current, finished) {
    const expected = phase === 'league' ? ['super-point'] : ['extra-first','extra-second','sudden-death'];
    check(keys(proof,['version','policy','regulation','periods']) && proof.version === 1 && proof.policy === policy
      && Array.isArray(proof.periods) && proof.periods.length > 0 && proof.periods.length <= expected.length, 'chronologie de prolongation inconnue.');
    witnessValid(proof.regulation);
    check(tied(proof.regulation.score), 'prolongation sans égalité réglementaire.');
    let previous = proof.regulation;
    let kickoff = null;
    for (const [index,p] of proof.periods.entries()) {
      const isLast = index === proof.periods.length - 1;
      check(keys(p,['kind','start','limit','rest','kickoff','firstScore','end']) && p.kind === expected[index]
        && p.start === previous.minute && p.limit === p.start+10 && integer(p.limit,90,240)
        && p.rest === (p.kind === 'extra-second' ? 2 : 5) && integer(p.kickoff,0,1), 'période ou heure de reprise incohérente.');
      if (p.kind === 'extra-second') check(p.kickoff === 1-kickoff, 'coup d’envoi sans changement de camp.');
      if (p.kind === 'sudden-death') check(tied(previous.score), 'mort subite sans égalité après la prolongation.');
      check(p.firstScore === null || (golden(p.kind) && isLast && finished && p.end !== null), 'première marque hors de la fin du match.');
      if (p.end === null) {
        check(isLast && !finished && current.minute >= p.start, 'période inachevée incompatible avec le match.');
        witnessValid(current);
        cumulative(previous,current);
        if (golden(p.kind)) goldenProof(previous,current,null);
      } else {
        check(!isLast || finished, 'une période close doit déclencher la suivante ou finir le match.');
        witnessValid(p.end,p.firstScore?.kind === 'try' ? p.firstScore.side : null);
        check(p.end.minute > p.start && (p.firstScore !== null || p.end.minute >= p.limit), 'durée effective de prolongation invalide.');
        cumulative(previous,p.end);
        if (golden(p.kind)) goldenProof(previous,p.end,p.firstScore);
        if (isLast) {
          check(equal(current,p.end), 'preuve finale différente du résultat.');
          check(p.kind !== 'extra-first' && (p.kind !== 'extra-second' || !tied(p.end.score)), 'phase finale arrêtée avant sa décision.');
        }
        previous = p.end;
      }
      kickoff = p.kickoff;
    }
    return proof.periods.at(-1);
  }

  function restartAllowed(restart,l) {
    return restart?.kind === 'kickoff' && Array.isArray(l.srpExtra?.periods) && l.srpExtra.periods.some(p =>
      p && Object.hasOwn(causes,p.kind) && causes[p.kind] === restart.cause && p.start === restart.minute && p.kickoff === restart.team);
  }

  function flowBoundary(l) { return lastPeriod(l)?.limit; }
  function earlyFinish(l) { return !!lastPeriod(l)?.firstScore && lastPeriod(l).end?.minute === l.minute; }

  function validateDecision(r, fixture, extra, live) {
    if (fixture.phase === 'league') {
      check(r.winner === undefined && r.decision === undefined, 'décision éliminatoire dans le championnat.');
      return;
    }
    const d = r.decision, isTie = tied(r.score);
    check(keys(d,isTie ? ['method','extraTime','redCards','shootout'] : ['method','extraTime','redCards'])
      && d.extraTime === Boolean(extra) && pair(d.redCards,23), 'preuve de décision éliminatoire invalide.');
    if (live) check(equal(d.redCards,live.sheets.map(sh => sh.redCards.length)), 'décision contraire aux exclusions de la feuille.');
    let side;
    if (!isTie) {
      check(d.method === 'score', 'départage déclaré malgré le score.');
      side = r.score[0] > r.score[1] ? 0 : 1;
    } else {
      const q = d.shootout;
      check(extra?.kind === 'sudden-death' && extra.end && extra.firstScore === null && d.method === 'shootout', 'tirs sans mort subite achevée.');
      check(keys(q,['kickers','end','first','score','attempts','eligible']) && integer(q.end,0,1)
        && Array.isArray(q.eligible) && q.eligible.length === 2 && q.eligible.every(list => Array.isArray(list)
          && list.length >= 5 && list.length <= 15 && new Set(list).size === list.length && list.every(playerId))
        && new Set(q.eligible.flat()).size === q.eligible[0].length+q.eligible[1].length
        && Array.isArray(q.attempts) && q.attempts.every(a => keys(a,['side','playerId','location','made'])), 'preuve de tirs non reconnue.');
      if (live) check(equal(q.eligible,[0,1].map(i => eligibleKickers(live,i).map(p => p.id))), 'éligibilité des tireurs incompatible avec la feuille.');
      side = rules.shootoutWinner(q,policy,q.eligible);
    }
    check(r.winner === r.pair[side], 'vainqueur déclaré incohérent.');
  }

  function validateResult(r, fixture, live = null) {
    check(fixture?.competitionId === 'srp' && (fixture.phase === 'league' || rules.phases.includes(fixture.phase))
      && equal(r.pair,[fixture.homeId,fixture.awayId]) && ['Sec','Vent','Pluie'].includes(r.weather)
      && pair(r.score,250) && pair(r.tries,50) && Array.isArray(r.stats) && r.stats.length === 2 && r.stats.every(plain), 'résultat hors calendrier ou statistiques absentes.');
    if (!live) check(r.fixtureId === fixture.id && r.phase === fixture.phase && r.competitionId === 'srp', 'identifiant de résultat incohérent.');
    const current = witness(r,live ? live.minute : r.duration);
    const extra = r.srpExtra === undefined ? null : validateExtra(r.srpExtra,fixture.phase,current,true);
    if (!extra) {
      witnessValid(current);
      check(!tied(r.score), 'égalité sans Super Point ou prolongation.');
    }
    validateDecision(r,fixture,extra,live);
  }

  function validateLive(l, fixture) {
    check(fixture?.competitionId === 'srp' && (fixture.phase === 'league' || rules.phases.includes(fixture.phase))
      && l.knockout === undefined && l.flowVersion === 1 && l.restartVersion === 1 && Array.isArray(l.restartLog) && Array.isArray(l.events),
    'contexte de prolongation incompatible.');
    check(['Sec','Vent','Pluie'].includes(l.weather) && pair(l.score,250) && pair(l.tries,50) && Array.isArray(l.stats)
      && l.stats.length === 2 && l.stats.every(plain), 'statistiques de match invalides.');
    const current = witness(l,l.minute);
    if (l.srpExtra === undefined) {
      if (l.finished) validateResult(l,fixture,l);
      else {
        witnessValid(current,null,0);
        check(l.winner === undefined && l.decision === undefined, 'décision avant la fin.');
      }
      return;
    }
    const last = validateExtra(l.srpExtra,fixture.phase,current,l.finished);
    check(l.flow?.period === 2 && l.flow.fullEnd === last.limit && l.srpExtra.regulation.minute >= l.flow.firstEnd+40, 'chronomètre de prolongation incompatible.');
    const actualRestarts = l.restartLog.filter(r => Object.values(causes).includes(r.cause));
    check(actualRestarts.length === l.srpExtra.periods.length && l.srpExtra.periods.every((p,i) =>
      actualRestarts[i].cause === causes[p.kind] && restartAllowed(actualRestarts[i],l)), 'reprises de prolongation manquantes ou incohérentes.');
    if (last.firstScore) {
      const mark = last.firstScore;
      const scoringEvents = l.events.filter(e => ['try','goal'].includes(e.type) && e.min > last.start);
      check(scoringEvents.length === 1 && scoringEvents[0].type === mark.kind && scoringEvents[0].min === mark.minute
        && scoringEvents[0].scene?.team === mark.side && equal(scoringEvents[0].scene.score,l.score)
        && equal(scoringEvents[0].scene.tries,l.tries), 'première marque absente du journal causal.');
    }
    if (l.finished) validateDecision(l,fixture,last,l);
    else check(l.winner === undefined && l.decision === undefined, 'décision avant la fin.');
  }

  return Object.freeze({applies, finish, historyFields, installHooks, restartAllowed, flowBoundary, earlyFinish, validateLive, validateResult});
};
