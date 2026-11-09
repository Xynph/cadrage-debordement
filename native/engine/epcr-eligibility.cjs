'use strict';

// Pure 2026/27 EPCR diagnostic. No roster selection, persistence, clock or RNG.
// Kept self-contained for injection into the native VM via factory.toString().
function factory() {
  const roles = ['LH', 'HK', 'TH'];
  const object = x => x !== null && typeof x === 'object' && !Array.isArray(x);
  const issue = (code, playerIds = []) => ({ code, playerIds: playerIds.slice() });
  function profile(options) {
    const violations = [];
    if (!object(options)) violations.push(issue('invalid-options'));
    else {
      if (options.season !== '2026/27') violations.push(issue('unsupported-season'));
      if (!['champions', 'challenge'].includes(options.competitionId)) violations.push(issue('unsupported-competition'));
    }
    return {
      covered: violations.length === 0, violations,
      season: '2026/27', maxRegistered: 42, minRegisteredFrontRow: 10,
      minSheet: 19, maxSheet: 23, starters: 15, minSheetFrontRow: 6,
      source: object(options) && options.competitionId === 'challenge'
        ? 'https://www.epcrugby.com/challenge-cup/ecc-rules'
        : 'https://www.epcrugby.com/champions-cup/champions-cup-rules',
      sections: ['3.1', '3.2', '3.3'], sourceScope: 'official-summary'
    };
  }
  function inspect(players, scope) {
    const violations = [], rows = [], ids = new Set();
    if (!Array.isArray(players)) return { rows, violations: [issue(scope + '-invalid-players')] };
    for (const p of players) {
      if (!object(p) || typeof p.id !== 'string' || p.id.trim().length === 0) {
        violations.push(issue(scope + '-invalid-player')); continue;
      }
      if (ids.has(p.id)) violations.push(issue(scope + '-duplicate-player', [p.id]));
      ids.add(p.id);
      const unknown = p.frontRow === undefined || p.frontRow === null;
      if (!unknown && (!Array.isArray(p.frontRow) || p.frontRow.some(r => !roles.includes(r)) || new Set(p.frontRow).size !== p.frontRow.length)) {
        violations.push(issue(scope + '-invalid-qualification', [p.id])); continue;
      }
      rows.push({ id: p.id, frontRow: unknown ? null : p.frontRow.slice() });
    }
    return { rows, violations };
  }
  const counts = rows => ({ players: rows.length, frontRow: rows.filter(p => p.frontRow && p.frontRow.length).length, unknownFrontRow: rows.filter(p => p.frontRow === null).length });
  function finish(violations, unknowns, totals) {
    const status = violations.length ? 'invalid' : unknowns.length ? 'unknown' : 'valid';
    return { valid: status === 'valid', status, violations, unknowns, counts: totals };
  }
  function minimum(rows, number, code, violations, unknowns) {
    const n = counts(rows);
    if (n.frontRow + n.unknownFrontRow < number) violations.push(issue(code));
    else if (n.frontRow < number) unknowns.push(issue(code, rows.filter(p => p.frontRow === null).map(p => p.id)));
  }
  function registration(players, options) {
    const p = profile(options), checked = inspect(players, 'registration');
    const violations = p.violations.concat(checked.violations), unknowns = [];
    if (Array.isArray(players) && players.length > p.maxRegistered) violations.push(issue('registration-size'));
    minimum(checked.rows, p.minRegisteredFrontRow, 'registration-front-row', violations, unknowns);
    return finish(violations, unknowns, counts(checked.rows));
  }
  // Distinct reserve players must cover the three first replacements. Merely
  // counting three qualifications on the same versatile player is insufficient.
  function covers(rows, allowUnknown) {
    function assign(index, used) {
      if (index === roles.length) return true;
      return rows.some((p, i) => !used.has(i) && ((p.frontRow === null && allowUnknown) || p.frontRow?.includes(roles[index])) && assign(index + 1, new Set([...used, i])));
    }
    return assign(0, new Set());
  }
  function teamSheet(starters, reserves, registeredPlayers, options) {
    const p = profile(options), a = inspect(starters, 'starters'), b = inspect(reserves, 'reserves'), list = inspect(registeredPlayers, 'registration');
    const registeredReport = registration(registeredPlayers, options);
    const violations = registeredReport.violations.concat(a.violations, b.violations), unknowns = registeredReport.unknowns.slice();
    const canonical = player => ({ id: player.id, frontRow: list.rows.find(x => x.id === player.id)?.frontRow ?? null });
    const selected = a.rows.concat(b.rows), rows = selected.map(canonical), n = counts(rows);
    if (!Array.isArray(starters) || !Array.isArray(reserves) || starters.length !== p.starters || starters.length + reserves.length < p.minSheet || starters.length + reserves.length > p.maxSheet) violations.push(issue('sheet-size'));
    const ids = new Set();
    for (const player of selected) {
      if (ids.has(player.id)) violations.push(issue('sheet-duplicate-player', [player.id]));
      ids.add(player.id);
      const registered = list.rows.find(x => x.id === player.id);
      if (!registered) violations.push(issue('sheet-unregistered-player', [player.id]));
      // The submitted list is the source of qualification evidence. A sheet
      // cannot grant a new role to a player to pass this diagnostic.
      else if (player.frontRow !== null && registered.frontRow !== null && player.frontRow.some(role => !registered.frontRow.includes(role))) violations.push(issue('sheet-qualification-mismatch', [player.id]));
    }
    minimum(rows, p.minSheetFrontRow, 'sheet-front-row', violations, unknowns);
    for (let i = 0; i < roles.length; i++) {
      const player = a.rows[i] ? canonical(a.rows[i]) : null;
      if (!player || (player.frontRow !== null && !player.frontRow.includes(roles[i]))) violations.push(issue('starter-front-row-' + roles[i], player ? [player.id] : []));
      else if (player.frontRow === null) unknowns.push(issue('starter-front-row-' + roles[i], [player.id]));
    }
    if (!covers(b.rows.map(canonical), false)) {
      if (covers(b.rows.map(canonical), true)) unknowns.push(issue('replacement-front-row', b.rows.map(canonical).filter(x => x.frontRow === null).map(x => x.id)));
      else violations.push(issue('replacement-front-row'));
    }
    return finish(violations, unknowns, { ...n, starters: Array.isArray(starters) ? starters.length : 0, reserves: Array.isArray(reserves) ? reserves.length : 0 });
  }
  return { profile, registration, teamSheet };
}
module.exports = { ...factory(), factory };
