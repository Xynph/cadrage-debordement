'use strict';

module.exports = function createNativePlayerAttributes() {
  const referencePlayers = CDCommonRosters.clubs.flatMap(club => club.players);
  const keys = Object.keys(referencePlayers[0].attributesV2);
  const skills = Object.keys(ATTR);
  const profiles = new Map();
  const valid = value => Number.isFinite(value) && value >= 20 && value <= 97;

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
      return skills.filter(skill => response[skill] > 0).map(skill => [skill, response[skill]]);
    });
    const profile = { rating, attributesV2, baseline, influences };
    profiles.set(position, profile);
    return profile;
  }

  return function playerAttributes(source) {
    const original = source.attributesV2;
    if (original && keys.every(key => valid(original[key]))) {
      return { attributesV2: original, attributesV2Estimated: false };
    }

    // Legacy and generated profiles use the detailed reference for their position.
    // The short ratings remain the simulation inputs; this reconstruction is read-only.
    const player = ensureSkills({ ...source });
    const reference = referenceFor(player.gameplayPosition || player.pos);
    const ratingDelta = player.rating - reference.rating;
    const deltas = Object.fromEntries(skills.map(key => [
      key, clamp(player.skills[key] + player.rating - player.skillBase, 15, 99) - reference.baseline[key]
    ]));
    const attributesV2 = Object.fromEntries(keys.map((key, index) => {
      if (valid(original?.[key])) return [key, original[key]];
      let weightedDelta = 0;
      let totalWeight = 0;
      for (const [skill, weight] of reference.influences[index]) {
        weightedDelta += deltas[skill] * weight;
        totalWeight += weight;
      }
      const delta = totalWeight ? weightedDelta / totalWeight : ratingDelta;
      return [key, clamp(Math.round(reference.attributesV2[key] + delta), 20, 97)];
    }));
    return { attributesV2, attributesV2Estimated: true };
  };
};
