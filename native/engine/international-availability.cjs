'use strict';

// Read-only presentation of confirmed releases. Future windows never predict names.
const shift = (date, days) => new Date(Date.parse(date + 'T00:00:00Z') + days * 86400000).toISOString().slice(0, 10);
const compare = (a, b) => a < b ? -1 : a > b ? 1 : 0;

function projectAvailability({ date, clubManaged, clubId, players, callups, releaseWindows, editions, teams }) {
  const own = clubManaged ? players.filter(player => player.clubId === clubId) : [];
  const ownById = new Map(own.map(player => [player.id, player]));
  const nations = new Map(teams.map(team => [team.id, team.name]));
  const competitions = new Map(editions.map(edition => [edition.id, edition.name]));
  const details = camp => ({ nation: camp.nation, nationName: nations.get(camp.nation) ?? camp.nation,
    competitionId: camp.competitionId, competitionName: competitions.get(camp.competitionId) ?? camp.competitionId,
    from: camp.from, through: camp.through, returnDate: shift(camp.through, 1) });
  const active = new Map();
  for (const camp of callups) {
    if (camp.from > date || camp.through < date) continue;
    for (const id of camp.playerIds) {
      const player = ownById.get(id);
      if (!player || active.get(id)?.through >= camp.through) continue;
      active.set(id, { id, name: player.name, pos: player.pos, ...details(camp) });
    }
  }
  const absent = [...active.values()].sort((a, b) => compare(a.returnDate, b.returnDate) || compare(a.name, b.name) || compare(a.id, b.id));
  const byPosition = new Map();
  for (const player of own) {
    const position = player.pos;
    if (!byPosition.has(position)) byPosition.set(position, { position, total: 0, available: 0, called: 0, injured: 0 });
    const group = byPosition.get(position);
    group.total++;
    if (active.has(player.id)) group.called++;
    if (player.injury > 0) group.injured++;
    if (!active.has(player.id) && !(player.injury > 0) && !(player.suspension > 0)) group.available++;
  }
  const positions = [...byPosition.values()].filter(group => group.called > 0)
    .sort((a, b) => a.available - b.available || b.called - a.called || compare(a.position, b.position));
  const horizonDate = shift(date, 90);
  const groups = new Map();
  for (const window of releaseWindows) {
    if (window.from <= date || window.from > horizonDate) continue;
    const key = [window.competitionId, window.from, window.through].join('/');
    if (!groups.has(key)) groups.set(key, { competitionId: window.competitionId,
      competitionName: competitions.get(window.competitionId) ?? window.competitionId,
      from: window.from, through: window.through, nations: [] });
    const group = groups.get(key);
    if (!group.nations.some(nation => nation.id === window.nation)) group.nations.push({ id: window.nation, name: nations.get(window.nation) ?? window.nation });
  }
  const windows = [...groups.values()].sort((a, b) => compare(a.from, b.from) || compare(a.competitionId, b.competitionId) || compare(a.through, b.through));
  for (const window of windows) window.nations.sort((a, b) => compare(a.name, b.name));
  const returned = new Map();
  for (const camp of callups) {
    const returnDate = shift(camp.through, 1);
    if (returnDate > date || returnDate < shift(date, -6)) continue;
    for (const id of camp.playerIds) {
      const player = ownById.get(id);
      if (!player || active.has(id) || returned.get(id)?.returnDate >= returnDate) continue;
      returned.set(id, { id, name: player.name, pos: player.pos, ...details(camp) });
    }
  }
  return { date, clubManaged: !!clubManaged, absentCount: absent.length, nextReturn: absent[0]?.returnDate ?? null,
    positions, players: absent, horizonDate, windows,
    returned: [...returned.values()].sort((a, b) => compare(b.returnDate, a.returnDate) || compare(a.id, b.id)) };
}

module.exports = { projectAvailability };
