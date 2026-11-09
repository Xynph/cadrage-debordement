'use strict';

function factory(editionIds = {
  4: 'rugby-world-2026-11-09-nationale-v4',
  5: 'rugby-world-2026-11-09-champ-v5',
}) {
  const types = ['A', 'B', 'C'];
  const phases = ['league', 'barrage', 'semi', 'final'];
  const limits = Object.freeze({bc: 4, c: 1});
  const isId = id => typeof id === 'string' && /^[A-Za-z0-9:_-]{1,180}$/.test(id);
  const validSeason = season => Number.isSafeInteger(season) && season >= 2026 && season <= 2200;
  const ref = value => typeof value === 'string' && value.trim().length > 0 && value.length <= 400;
  const counts = () => ({A: 0, B: 0, C: 0});

  function applies(s, f) {
    const version = s?.worldMode?.version;
    if (![4, 5].includes(version) || typeof editionIds[version] !== 'string' ||
        s.commonDatabase?.version !== version || s.commonDatabase.id !== editionIds[version] ||
        f?.competitionId !== 'nationale' || !phases.includes(f.phase) || !validSeason(f.season)) return false;
    const members = s.worldMode.leagues?.nationale?.members;
    const clubs = [f.homeId, f.awayId];
    return Array.isArray(members) && clubs[0] !== clubs[1] &&
      clubs.includes(s.club) && clubs.every(id => Number.isSafeInteger(id) && members.includes(id));
  }

  function estimatedType(facts, season, clubId) {
    if (!Array.isArray(facts)) return null;
    const options = new Set();
    const seasons = (fact, count) => Array.isArray(fact.seasons) &&
      new Set(fact.seasons.filter(year => Number.isInteger(year) && year >= 1900 && year < season)).size >= count;
    for (const fact of facts) {
      if (!fact || !ref(fact.evidenceRef)) continue;
      if (fact.kind === 'french-citizenship' && fact.basis === 'explicit-civil-citizenship') options.add('A');
      if (fact.kind === 'ffr-active-licence-history' && fact.basis === 'official-licence-records' && seasons(fact, 5)) options.add('A');
      if (fact.kind === 'approved-academy-history' && fact.basis === 'approved-agreement-records' && seasons(fact, 3)) options.add('A');
      if (fact.kind === 'non-a-assessment' && fact.basis === 'reviewed-dossier' && fact.season === season &&
          fact.clubId === clubId && fact.completeCivilCitizenships === true && fact.allABasesReviewed === true) {
        if (fact.agreementClass === 'covered') options.add('B');
        if (fact.agreementClass === 'outside') options.add('C');
      }
    }
    return options.size === 1 ? options.values().next().value : null;
  }

  function classify(playerId, evidence, season, clubId) {
    const c = evidence?.card;
    if (c && types.includes(c.code) && c.season === season && c.clubId === clubId &&
        ['ffr-issued', 'ffr-authorised-registrar'].includes(c.authority) && ref(c.evidenceRef)) {
      return {playerId, status: 'verified', code: c.code, estimate: null};
    }
    const estimate = estimatedType(evidence?.facts, season, clubId);
    return {playerId, status: estimate ? 'estimated' : 'unknown', code: null, estimate};
  }

  function summarize(selected, {season, clubId, evidenceByPlayerId = {}}) {
    if (!Array.isArray(selected) || selected.length > 23 || !validSeason(season) || !Number.isSafeInteger(clubId)) {
      throw Error('Nationale — projection de feuille invalide.');
    }
    const playerIds = selected.filter(isId);
    const unique = [...new Set(playerIds)];
    const entries = unique.map(playerId => classify(playerId,
      Object.hasOwn(evidenceByPlayerId || {}, playerId) ? evidenceByPlayerId[playerId] : null, season, clubId));
    const verified = counts();
    const estimates = counts();
    for (const e of entries) {
      if (e.code) verified[e.code]++;
      if (e.estimate) estimates[e.estimate]++;
    }
    const unverified = entries.length - verified.A - verified.B - verified.C;
    const bc = verified.B + verified.C;
    const c = verified.C;
    const bounds = {bc: [bc, bc + unverified], c: [c, c + unverified]};
    const status = bc > limits.bc || c > limits.c ? 'verified-excess' :
      bounds.bc[1] <= limits.bc && bounds.c[1] <= limits.c ? 'within-bounds' : 'unverified';
    const detail = entries.length === 0 ? 'Aucun joueur sélectionné.' :
      status === 'verified-excess' ? 'Dépassement établi sur les cartes vérifiées.' :
      status === 'within-bounds' ? 'Plafonds respectés pour les joueurs renseignés.' : 'Plafonds indéterminés.';
    const unknownLabel = unverified === 1 ? '1 carte non vérifiée' : unverified + ' cartes non vérifiées';
    const estimateCount = estimates.A + estimates.B + estimates.C;
    const notice = {
      title: 'Qualifications FFR',
      summary: `B/C vérifiées ${bc}/${limits.bc} · C vérifiées ${c}/${limits.c}`,
      detail: `${unknownLabel} · ${detail}`,
      estimates: estimateCount > 0 ? `Estimations documentées · A ${estimates.A} · B ${estimates.B} · C ${estimates.C}` : null,
      tone: status === 'verified-excess' ? 'alert' : 'neutral',
    };
    return {
      rule: 'ffr-235-236-2026-27', ruleStatus: season === 2026 ? 'published-2026-27' : 'frozen-game-convention',
      scope: 'advisory-only', status, limits, verified, estimates, unverified, bounds,
      selectedCount: entries.length, emptySlots: selected.length - playerIds.length,
      duplicates: playerIds.length - unique.length, entries, notice,
    };
  }

  function project(s, fixture, selected, evidenceByPlayerId) {
    return applies(s, fixture) ? summarize(selected, {season: fixture.season, clubId: s.club, evidenceByPlayerId}) : null;
  }

  return Object.freeze({applies, summarize, project});
}

module.exports = {factory};
