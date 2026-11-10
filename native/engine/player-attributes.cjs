'use strict';

module.exports = function createNativePlayerAttributes() {
  const referencePlayers = CDCommonRosters.clubs.flatMap(club => club.players);
  // Order of the 36 pairs stored in nativeAttributesV1. Keep stable across editions.
  const keys = [
    'passing', 'receiving', 'offload', 'tackling', 'jackal', 'ruckClearout', 'ballCarry', 'evasion',
    'kickDistance', 'kickAccuracy', 'goalAccuracy', 'ballHandling', 'decisions', 'anticipation',
    'vision', 'positioning', 'composure', 'discipline', 'teamwork', 'leadership', 'workRate',
    'acceleration', 'topSpeed', 'agility', 'explosiveness', 'strength', 'endurance', 'jumping',
    'scrumTechnique', 'hooking', 'lineoutThrow', 'lineoutJump', 'lineoutLift', 'maul', 'kickChase', 'aerialAbility'
  ];
  const skills = Object.keys(ATTR);
  const profiles = new Map();
  const fullProfiles = new WeakSet();
  const valid = value => Number.isFinite(value) && value >= 20 && value <= 97;
  const positionOf = player => player.gameplayPosition || player.pos;
  const effectiveSkills = player => skills.map(key => skill(player, key));

  function referenceFor(position) {
    if (profiles.has(position)) return profiles.get(position);
    const atPosition = referencePlayers.filter(player => player.gameplayPosition === position);
    const players = atPosition.length ? atPosition : referencePlayers;
    const rating = players.reduce((total, player) => total + player.rating, 0) / players.length;
    const attributesV2 = Object.fromEntries(keys.map(key => [
      key, players.reduce((total, player) => total + player.attributesV2[key], 0) / players.length
    ]));
    const baseline = lnrProjectV12({ gameplayPosition: position, attributesV2 });
    const zero = Object.fromEntries(keys.map(key => [key, 0]));
    // Query the canonical forward projection, including its position-specific coefficients.
    const influences = keys.map(key => {
      const response = lnrProjectV12({ gameplayPosition: position, attributesV2: { ...zero, [key]: 100 } });
      return skills.flatMap((skill, index) => response[skill] > 0 ? [[index, response[skill]]] : []);
    });
    const profile = { rating, attributesV2, baseline, influences };
    profiles.set(position, profile);
    return profile;
  }

  function hasFullProfile(attributes) {
    if (!attributes || typeof attributes !== 'object') return false;
    if (fullProfiles.has(attributes)) return true;
    if (Object.keys(attributes).length !== keys.length || !keys.every(key => valid(attributes[key]))) return false;
    fullProfiles.add(attributes);
    return true;
  }

  function shifted(value, influences, deltas, ratingDelta) {
    let weightedDelta = 0;
    let totalWeight = 0;
    for (const [index, weight] of influences) {
      weightedDelta += deltas[index] * weight;
      totalWeight += weight;
    }
    const delta = totalWeight ? weightedDelta / totalWeight : ratingDelta;
    return clamp(Math.round(value + delta), 20, 97);
  }

  const pack = values => values.join('');
  const unpack = packed => keys.map((_, index) => Number(packed.slice(2 * index, 2 * index + 2)));

  function initialize(source) {
    const player = ensureSkills({ ...source });
    const reference = referenceFor(positionOf(player));
    const ratingDelta = player.rating - reference.rating;
    const deltas = effectiveSkills(player).map((value, index) => value - reference.baseline[skills[index]]);
    return pack(keys.map((key, index) => valid(source.attributesV2?.[key])
      ? Math.round(source.attributesV2[key])
      : shifted(reference.attributesV2[key], reference.influences[index], deltas, ratingDelta)));
  }

  function* populations(state, liveOnly = false) {
    if (liveOnly) {
      for (const clubId of state.live?.pair ?? []) yield state.clubs[clubId].players;
      return;
    }
    for (const club of state.clubs) yield club.players;
    yield state.development.academy;
    yield state.economy.freeAgents;
    yield state.market;
    for (const center of state.aiRoster?.academies ?? []) yield center.players;
    for (const center of state.nativeAcademy?.centers ?? []) if (center.players) yield center.players;
  }

  function before(state, liveOnly) {
    const previous = new Map();
    if (!state) return previous;
    for (const players of populations(state, liveOnly)) {
      for (const player of players) {
        if (player.nativeAttributesV1 === undefined || previous.has(player.id)) continue;
        previous.set(player.id, {
          packed: player.nativeAttributesV1, rating: player.rating, skills: effectiveSkills(player)
        });
      }
    }
    return previous;
  }

  function progressed(player, previous) {
    if (!previous) return initialize(player);
    const ratingDelta = player.rating - previous.rating;
    const deltas = effectiveSkills(player).map((value, index) => value - previous.skills[index]);
    if (!ratingDelta && deltas.every(delta => delta === 0)) return previous.packed;
    const reference = referenceFor(positionOf(player));
    return pack(unpack(previous.packed).map(
      (value, index) => shifted(value, reference.influences[index], deltas, ratingDelta)
    ));
  }

  function complete(state, previous = null, liveOnly = false) {
    if (!state) return;
    for (const players of populations(state, liveOnly)) {
      for (const player of players) {
        if (previous && !hasFullProfile(player.attributesV2)) {
          player.nativeAttributesV1 = progressed(player, previous.get(player.id));
          continue;
        }
        const packed = player.nativeAttributesV1;
        if (packed === undefined) {
          if (!hasFullProfile(player.attributesV2)) player.nativeAttributesV1 = initialize(player);
        } else if (
          typeof packed !== 'string' || packed.length !== 72 || !/^\d{72}$/.test(packed) || !unpack(packed).every(valid) ||
          hasFullProfile(player.attributesV2)
        ) {
          throw Error('Attributs détaillés du joueur invalides.');
        }
      }
    }
    if (!liveOnly && aiRosterPopulationActive(state)) {
      const freeAgents = new Map(state.economy.freeAgents.map(player => [player.id, player]));
      for (const player of state.market) {
        const original = freeAgents.get(player.id);
        if (original?.nativeAttributesV1 !== undefined) player.nativeAttributesV1 = original.nativeAttributesV1;
      }
    }
  }

  function project(player) {
    if (hasFullProfile(player.attributesV2)) return { attributesV2: player.attributesV2 };
    const values = unpack(player.nativeAttributesV1);
    return { attributesV2: Object.fromEntries(keys.map((key, index) => [key, values[index]])) };
  }

  return { before, complete, project };
};
