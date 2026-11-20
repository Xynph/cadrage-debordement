'use strict';

// Installed in the native career VM. The floor is a game policy for signed
// professionals and does not change match-day eligibility or the source data.
//
// Décision de Léo du 19/11/2026 (docs/gdd/calendrier-mutations.md § 3 quater, points 2 et 3) : en carrière Monde,
// le club joué n'a plus de plancher de 40 ni de joueurs de complément signés automatiquement (les 40 étaient un
// choix technique, #502). Seul garde-fou : les espoirs du centre montent pour un match quand la feuille de 23 ne
// peut pas être remplie (espoirs-match.cjs), avec une alerte avant (continuer.cjs, « Effectif trop juste »).
// Les joueurs « depth-… » déjà signés restent sous contrat jusqu'à leur échéance.
// Clubs gérés : plancher gardé ; `options.managedFloor === false` le coupe en Monde (worker.cjs le lit de
// CD_PLANCHER_CLUBS_GERES=0, pour la mesure multi-saisons). Hors Monde (anciens modes), comportement d'origine.
// Dans la VM, worker.cjs pose `nativeDepthOptions` juste avant l'installation (aucun argument : texte d'appel inchangé).
module.exports = function professionalDepth(options = typeof nativeDepthOptions !== 'undefined' ? nativeDepthOptions : {}) {
  const minimum = 40;
  const managedFloor = options?.managedFloor !== false;
  const world = state => !!state?.worldMode;
  // Club joué d'une carrière Monde : jamais complété.
  const playedClubExempt = state => world(state);
  const applies = (state, clubId) => !world(state) || (clubId === state.club ? false : managedFloor);
  const prefix = 'depth-';
  const slots = POS.map((position, index) => ({
    position, index, demand: POS.filter(role => role === position).length
  })).filter((slot, index) => POS.indexOf(slot.position) === index);

  function nextSlot(players, rotation) {
    return slots.map(slot => ({
      ...slot,
      // Emergency placements are legal with a severe aptitude penalty; they
      // cannot replace a specialist when balancing the professional roster.
      // Front-row coverage still requires the actual side qualifications.
      coverage: players.filter(player => slot.index < 3
        ? slotEligible(player, slot.index) : player.pos === slot.position).length / slot.demand
    })).sort((a, b) => a.coverage - b.coverage ||
      (a.index + rotation) % POS.length - (b.index + rotation) % POS.length)[0];
  }

  function newPlayer(id, slot, players, incumbents, season) {
    const seed = seedHash(id);
    const samePosition = incumbents.filter(player => player.pos === slot.position);
    const peers = samePosition.length ? samePosition : incumbents;
    const ceiling = Math.min(...incumbents.map(player => player.rating), 99);
    const roleCeiling = Math.max(15, Math.min(...peers.map(player => roleNote(player)), 99) - 1);
    const sample = (hash, fallback) => incumbents.length
      ? incumbents[hash % incumbents.length].name.trim().split(/\s+/)
      : [fallback];
    const first = sample(seed, FIRST[seed % FIRST.length])[0];
    const last = sample(seedHash(id + ':last'), LAST[seed % LAST.length]).at(-1);
    const candidate = first + ' ' + last;
    const name = players.some(player => player.name === candidate)
      ? FIRST[seed % FIRST.length] + ' ' + LAST[seedHash(id + ':name') % LAST.length]
      : candidate;
    const player = ensureSkills({
      id, name, appearanceBankVersion: 2, pos: slot.position, fam: FAMILIES[slot.index],
      age: 18 + seedHash(id + ':age') % 16,
      rating: Math.max(15, Math.min(ceiling - 2 - seed % 6, 65)),
      condition: 92 + seed % 9, injury: 0,
      salary: 1400 + 100 * (seedHash(id + ':salary') % 9),
      contractEnd: season + seed % 2
    });
    while (roleNote(player) > roleCeiling) {
      for (const key of Object.keys(ATTR)) player.skills[key] = Math.max(15, player.skills[key] - 1);
    }
    ensureDevelopment(player);
    player.dev.potential = Math.max(player.rating, Math.min(player.dev.potential, ceiling));
    return player;
  }

  function additions(clubId, players, season, occupied = new Set()) {
    if (players.length >= minimum) return [];
    const sourced = players.filter(player => !player.id.startsWith(prefix));
    const incumbents = sourced.length ? sourced : players;
    const roster = players.slice();
    let serial = 0;
    while (roster.length < minimum) {
      let id;
      do id = `${prefix}${clubId}-${season}-${++serial}`; while (occupied.has(id));
      occupied.add(id);
      const slot = nextSlot(roster, seedHash(id) % POS.length);
      roster.push(newPlayer(id, slot, roster, incumbents, season));
    }
    return roster.slice(players.length);
  }

  function fill(state) {
    if (!state || state.live || state.clubs.every(club => club.players.length >= minimum || !applies(state, club.id))) return;
    const occupied = new Set([
      ...state.clubs.flatMap(club => club.players), ...state.market, ...state.economy.freeAgents,
      ...(state.development?.academy ?? []), ...(state.development?.retired ?? []),
      ...(state.aiRoster?.academies ?? []).flatMap(center => center.players)
    ].map(player => player.id));
    for (const club of state.clubs) {
      if (!applies(state, club.id)) continue;
      const signed = additions(club.id, club.players, state.season, occupied);
      for (const player of signed) {
        player.joinedSeason = state.season;
        player.joinedRound = state.round;
        if (state.phase === 'ended') player.contractEnd = state.season + 1;
        club.players.push(player);
      }
    }
  }

  return { minimum, managedFloor, applies, playedClubExempt, additions, fill };
};
