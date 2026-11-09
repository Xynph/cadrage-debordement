'use strict';

// Self-contained factory for the native VM. Only the calendar and bracket are
// confirmed for 2027. Match and table policy must be opted into separately.
function factory(ledger) {
  const competitionId = 'srp';
  const phases = Object.freeze(['elimination', 'semi', 'final']);
  const referencePolicy = 'srp-2026-reference';
  const futurePolicy = 'repeat-2027-template';
  const rulesId = 'super-rugby-pacific-2027-draw-v1';
  const dayMs = 86400000;
  const clone = value => JSON.parse(JSON.stringify(value));
  const check = (ok, detail) => { if (!ok) throw Error('Super Rugby Pacific — ' + detail); };
  const validClubId = id => Number.isSafeInteger(id) && id >= 0;
  const validPair = values => Array.isArray(values) && values.length === 2 && values.every(validClubId) && values[0] !== values[1];
  const validScore = values => Array.isArray(values) && values.length === 2 && values.every(x => Number.isSafeInteger(x) && x >= 0 && x <= 250);
  const phaseRules = Object.freeze({
    policy: referencePolicy,
    status: 'provisional-2026-reference-not-verified-for-2027',
    regular: Object.freeze({restBefore: 5, superPoint: 10}),
    playoffs: Object.freeze({restBefore: 5, extraHalf: 10, halftime: 2, restBeforeSuddenDeath: 5, suddenDeath: 10, kickersPerSide: 5}),
    source: 'https://super.rugby/superrugby/about-super-rugby/tournament-format/',
  });
  const reference = clone(ledger);
  const clubKeys = Object.freeze(reference.clubKeys.slice());
  const roundCount = 17;

  check(reference.schema === 'srp-2027-calendar-v1' && reference.season === 2027, 'version de calendrier inconnue.');
  check(clubKeys.length === 10 && new Set(clubKeys).size === 10, 'liste des clubs incomplète.');
  check(reference.regular.length === 80 && new Set(reference.regular.map(f => f.id)).size === 80, 'calendrier initial incomplet.');

  function rules(id = competitionId) {
    check(id === competitionId, 'compétition inconnue.');
    return {
      id: rulesId, competitionId, season: 2027, clubs: 10, rounds: 17, matchesPerClub: 16, byesPerClub: 1,
      regularMatches: 80, playoffs: 6, knockoutMatches: 5, phases: phases.slice(),
      formatStatus: 'confirmed-2027', playingPolicyStatus: phaseRules.status, playingPolicy: referencePolicy,
      bonus: {tryMargin: 3, losingMargin: 7, status: phaseRules.status},
      provenance: clone(reference.sources || {}),
    };
  }

  function edition(season, assumedFuture) {
    check(Number.isSafeInteger(season) && season >= 2027 && season <= 9999, 'saison invalide.');
    if (season > 2027) check(assumedFuture === futurePolicy, 'calendrier ultérieur non publié : politique de simulation requise.');
    return season === 2027;
  }

  function seasonDate(date, season) {
    if (season === 2027) return date;
    const februaryEighth = new Date(Date.UTC(season, 1, 8));
    const secondFriday = februaryEighth.getTime() + ((5 - februaryEighth.getUTCDay() + 7) % 7) * dayMs;
    return new Date(secondFriday + Date.parse(date) - Date.parse('2027-02-12')).toISOString().slice(0,10);
  }

  function clubIdsByKey(clubs) {
    check(Array.isArray(clubs) && clubs.length === 10, 'dix clubs du catalogue requis.');
    const ids = new Map();
    for (const club of clubs) {
      check(clubKeys.includes(club?.key) && validClubId(club.id) && !ids.has(club.key), 'club du calendrier inconnu ou répété.');
      ids.set(club.key, club.id);
    }
    check(new Set(ids.values()).size === clubKeys.length, 'identifiant de club dupliqué.');
    return ids;
  }

  function calendarFixtures({clubs, season = 2027, competitionId: id = competitionId, futurePolicy: assumedFuture}) {
    rules(id);
    const official = edition(season, assumedFuture);
    const byKey = clubIdsByKey(clubs);
    const rotateHome = !official && (season - 2027) % 2 === 1;
    return reference.regular.map(match => {
      const [homeKey, awayKey] = rotateHome ? [match.awayKey, match.homeKey] : [match.homeKey, match.awayKey];
      const id = match.id.replace(':2027:', `:${season}:`);
      const centralised = match.venuePolicy === 'centralised-super-round';
      return {
        id, fixtureId: id, competitionId, season, phase: 'league', round: match.roundNumber - 1, slot: match.slot,
        date: seasonDate(match.date, season), homeId: byKey.get(homeKey), awayId: byKey.get(awayKey),
        scheduleSource: official ? 'official-2027-draw' : 'generated-game-repeat-2027-template',
        neutral: centralised, // Gestion : la journée centralisée n'est pas une billetterie du club nominalement à domicile.
        venuePolicy: match.venuePolicy, venue: official ? match.venue?.name ?? null : null,
        venueCity: official ? match.venue?.city ?? null : null, venueDesignationPending: !official || !match.venue,
        kickoffUtc: official ? match.kickoffUtc : null, providerId: official ? match.provider?.id ?? null : null,
      };
    });
  }

  function byes(clubIds, fixtures) {
    check(Array.isArray(clubIds) && clubIds.length === 10 && new Set(clubIds).size === 10, 'liste de clubs invalide.');
    return Array.from({length: roundCount}, (_, round) => {
      const playing = new Set(fixtures.filter(f => f.round === round).flatMap(f => [f.homeId, f.awayId]));
      return {round, clubIds: clubIds.filter(id => !playing.has(id))};
    });
  }

  function policy(id) {
    check(id === referencePolicy, 'barème et horloge 2027 non vérifiés : politique de simulation explicite requise.');
  }

  function resultPoints(score, tries, assumedPolicy) {
    policy(assumedPolicy);
    check(validScore(score) && validScore(tries) && tries.every((x, side) => x * 5 <= score[side]), 'score ou essais invalides.');
    return [0,1].map(side => {
      const diff = score[side] - score[1 - side];
      const attackingBonus = tries[side] - tries[1 - side] >= 3 ? 1 : 0;
      const losingBonus = diff < 0 && diff >= -7 ? 1 : 0;
      return {points: (diff > 0 ? 4 : diff === 0 ? 2 : 0) + attackingBonus + losingBonus, attackingBonus, losingBonus};
    });
  }

  function tieOrder(clubIds, drawOrder) {
    if (drawOrder === undefined) return null;
    const ranks = Array.isArray(drawOrder) ? Object.fromEntries(drawOrder.map((id,i) => [id,i+1])) : drawOrder;
    check(ranks && typeof ranks === 'object' && Object.keys(ranks).length === clubIds.length, 'ordre de tirage invalide.');
    const values = clubIds.map(id => ranks[id]);
    check(new Set(values).size === clubIds.length && values.every(rank => Number.isInteger(rank) && rank >= 1 && rank <= clubIds.length), 'tirage non bijectif.');
    return ranks;
  }

  function table(clubIds, results, id = competitionId, options = {}) {
    rules(id);
    policy(options.policy);
    check(Array.isArray(clubIds) && clubIds.length === 10 && clubIds.every(validClubId) && new Set(clubIds).size === 10, 'liste du classement invalide.');
    check(Array.isArray(results), 'liste de résultats invalide.');
    const rows = new Map(clubIds.map(clubId => [clubId, {
      clubId, played: 0, won: 0, drawn: 0, lost: 0, pf: 0, pa: 0, tf: 0, ta: 0,
      bonus: 0, attackingBonus: 0, losingBonus: 0, points: 0, form: [],
    }]));
    const seen = new Set();
    const scheduled = options.fixtures ? new Map(options.fixtures.map(f => [f.id,f])) : null;
    const regular = results.filter(r => r?.competitionId === competitionId && r.phase === 'league'
      && (options.season === undefined || r.season === options.season));
    for (const result of regular) {
      check(typeof result.fixtureId === 'string' && result.fixtureId && !seen.has(result.fixtureId), 'résultat régulier dupliqué ou sans identité.');
      seen.add(result.fixtureId);
      check(validPair(result.pair) && result.pair.every(id => rows.has(id)), 'adversaire absent du classement.');
      if (scheduled) {
        const fixture = scheduled.get(result.fixtureId);
        check(fixture && fixture.phase === 'league' && result.pair[0] === fixture.homeId && result.pair[1] === fixture.awayId, 'résultat hors calendrier.');
      }
      const awards = resultPoints(result.score, result.tries, options.policy);
      if (result.winner !== undefined && result.winner !== null) {
        check(result.score[0] !== result.score[1] && result.winner === result.pair[result.score[0] > result.score[1] ? 0 : 1], 'vainqueur régulier contraire au score.');
      }
      result.pair.forEach((clubId, side) => {
        const row = rows.get(clubId), other = 1 - side;
        const diff = result.score[side] - result.score[other];
        check(++row.played <= 16, 'trop de matchs réguliers pour un club.');
        row.pf += result.score[side]; row.pa += result.score[other];
        row.tf += result.tries[side]; row.ta += result.tries[other];
        row[diff > 0 ? 'won' : diff === 0 ? 'drawn' : 'lost']++;
        row.form.push(diff > 0 ? 'W' : diff === 0 ? 'D' : 'L');
        row.points += awards[side].points;
        row.attackingBonus += awards[side].attackingBonus;
        row.losingBonus += awards[side].losingBonus;
        row.bonus = row.attackingBonus + row.losingBonus;
      });
    }
    const compare = (a,b) => b.points - a.points || b.won - a.won || (b.pf - b.pa) - (a.pf - a.pa)
      || b.tf - a.tf || (b.tf - b.ta) - (a.tf - a.ta);
    const draw = tieOrder(clubIds, options.tieBreaks?.drawOrder);
    const ranked = [...rows.values()].sort((a,b) => compare(a,b) || (draw ? draw[a.clubId] - draw[b.clubId] : a.clubId - b.clubId));
    for (let i = 0; i < ranked.length;) {
      let end = i + 1;
      while (end < ranked.length && compare(ranked[i], ranked[end]) === 0) end++;
      const unresolvedTie = end - i > 1 && !draw;
      for (let k = i; k < end; k++) {
        ranked[k].rank = (unresolvedTie ? i : k) + 1;
        ranked[k].unresolvedTie = unresolvedTie;
      }
      i = end;
    }
    return ranked;
  }

  function playoffSeeds(ranked) {
    check(Array.isArray(ranked) && ranked.length === 10 && ranked.every(row => row.played === 16), 'saison régulière incomplète.');
    const six = ranked.slice(0,6);
    check(six.every((row,i) => !row.unresolvedTie && row.rank === i + 1), 'le tirage doit départager les qualifiés.');
    return six.map(row => row.clubId);
  }

  function nextMatchPeriod({phase, period, score, policy: assumedPolicy}) {
    policy(assumedPolicy);
    check((phase === 'league' || phases.includes(phase)) && validScore(score), 'phase de rencontre ou score invalide.');
    const tied = score[0] === score[1];
    const done = {period: 'finished', winnerSide: tied ? null : (score[0] > score[1] ? 0 : 1)};
    if (phase === 'league') {
      check(['regulation', 'super-point'].includes(period), 'période de championnat invalide.');
      return period === 'regulation' && tied ? {period: 'super-point', rest: 5, minutes: 10, firstScoreWins: true} : done;
    }
    if (period === 'regulation') return tied ? {period: 'extra-first', rest: 5, minutes: 10, firstScoreWins: false} : done;
    if (period === 'extra-first') return {period: 'extra-second', rest: 2, minutes: 10, firstScoreWins: false};
    if (period === 'extra-second') return tied ? {period: 'sudden-death', rest: 5, minutes: 10, firstScoreWins: true} : done;
    check(period === 'sudden-death', 'période de phases finales invalide.');
    return tied ? {period: 'shootout', kickersPerSide: 5, marksMetres: 22, markCycle: [1,2,3]} : done;
  }

  function shootoutWinner(evidence, assumedPolicy, eligible) {
    policy(assumedPolicy);
    const q = evidence;
    check(q && [0,1].includes(q.first) && Array.isArray(q.kickers) && q.kickers.length === 2
      && q.kickers.every(side => Array.isArray(side) && side.length === 5 && side.every(id => typeof id === 'string' && id.length > 0))
      && new Set(q.kickers.flat()).size === 10, 'cinq tireurs distincts requis par équipe.');
    if (eligible) check(q.kickers.every((side,i) => side.every(id => eligible[i]?.includes(id))), 'tireur inéligible à la dernière sirène.');
    check(Array.isArray(q.attempts) && q.attempts.length > 0 && q.attempts.length <= 2000, 'suite de tirs invalide.');
    const tally = [0,0], taken = [0,0];
    let winner = null;
    for (const [index, attempt] of q.attempts.entries()) {
      const round = Math.floor(index / 2), side = index % 2 ? 1 - q.first : q.first;
      check(winner === null && attempt?.side === side && attempt.playerId === q.kickers[side][round % 5]
        && attempt.location === round % 3 + 1 && typeof attempt.made === 'boolean', 'ordre, tireur ou position du tir incohérent.');
      taken[side]++;
      if (attempt.made) tally[side]++;
      if (round < 5) {
        if (tally[0] > tally[1] + 5 - taken[1]) winner = 0;
        if (tally[1] > tally[0] + 5 - taken[0]) winner = 1;
      } else if (index % 2 && tally[0] !== tally[1]) winner = tally[0] > tally[1] ? 0 : 1;
    }
    check(winner !== null && Array.isArray(q.score) && q.score.length === 2 && q.score.every((n,i) => n === tally[i]), 'tirs sans vainqueur ou score incohérent.');
    return winner;
  }

  function knockoutWinner(result, fixture, assumedPolicy) {
    check(result?.fixtureId === fixture.id && result.season === fixture.season && result.phase === fixture.phase
      && result.competitionId === competitionId && validPair(result.pair) && result.pair[0] === fixture.homeId
      && result.pair[1] === fixture.awayId && validScore(result.score), 'résultat incompatible avec le tableau des finales.');
    let winnerSide;
    if (result.score[0] !== result.score[1]) {
      check(result.decision === undefined || result.decision?.method === 'score', 'départage déclaré malgré un score décisif.');
      winnerSide = result.score[0] > result.score[1] ? 0 : 1;
    }
    else {
      check(Number.isSafeInteger(result.duration) && result.duration >= 110 && result.duration <= 240
        && result.decision?.method === 'shootout', 'égalité sans prolongations et tirs au but attestés.');
      winnerSide = shootoutWinner(result.decision.shootout, assumedPolicy);
    }
    const winner = result.pair[winnerSide];
    check(result.winner === winner, 'vainqueur déclaré incompatible avec le résultat.');
    return winner;
  }

  function knockoutFixtures({competitionId: id = competitionId, season = 2027, seeds, phase, results = [], futurePolicy: assumedFuture, policy: assumedPolicy}) {
    rules(id);
    const official = edition(season, assumedFuture);
    check(Array.isArray(seeds) && seeds.length === 6 && seeds.every(validClubId) && new Set(seeds).size === 6, 'six têtes de série distinctes requises.');
    check(phases.includes(phase) && Array.isArray(results), 'phase finale inconnue.');
    const bySeed = new Map(seeds.map((id,i) => [id,i]));
    const make = (stage, pairings) => pairings.map(([homeId,awayId],slot) => {
      const published = reference.finals[stage][slot];
      const id = `srp:${season}:${stage}:m${slot+1}`;
      return {
        id, fixtureId: id, competitionId, season, phase: stage, round: roundCount + phases.indexOf(stage), slot: slot+1,
        date: seasonDate(published.date, season), homeId, awayId, neutral: false, venue: null, venueDesignationPending: true,
        venuePolicy: 'higher-seed-hosts', providerId: official ? published.providerId ?? null : null, kickoffUtc: null,
        scheduleSource: official ? published.dateStatus : 'generated-game-repeat-2027-template',
      };
    });
    const winners = (stage, fixtures) => {
      const relevant = results.filter(r => r?.competitionId === competitionId && r.season === season && r.phase === stage);
      const canonical = new Map(fixtures.map(f => [f.id, f]));
      check(new Set(relevant.map(r => r.fixtureId)).size === relevant.length && relevant.every(r => canonical.has(r.fixtureId)), 'résultat de phase finale sans rencontre unique.');
      const played = relevant.map(r => knockoutWinner(r, canonical.get(r.fixtureId), assumedPolicy));
      return played.length === fixtures.length ? played.sort((a,b) => bySeed.get(a) - bySeed.get(b)) : [];
    };
    const eliminations = make('elimination', [[seeds[2],seeds[5]],[seeds[3],seeds[4]]]);
    if (phase === 'elimination') return eliminations;
    const qualifiers = winners('elimination', eliminations);
    if (qualifiers.length !== 2) return [];
    const semifinals = make('semi', [[seeds[0],qualifiers[1]],[seeds[1],qualifiers[0]]]);
    if (phase === 'semi') return semifinals;
    const finalists = winners('semi', semifinals);
    return finalists.length === 2 ? make('final', [finalists]) : [];
  }

  return Object.freeze({rulesId, competitionId, clubKeys, phases, referencePolicy, futurePolicy, phaseRules, rules,
    calendarFixtures, regularFixtures: calendarFixtures, byes, table, resultPoints, playoffSeeds,
    knockoutFixtures, knockoutWinner, nextMatchPeriod, shootoutWinner});
}

module.exports = {factory};
