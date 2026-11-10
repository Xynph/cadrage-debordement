'use strict';

// Serialized into the world VM and called once on the initial senior rosters.
module.exports = function createSeniorCalibration(projectSkills, roleNote, roleWeights, rolePriors) {
  const version = 1;
  const openerId = 'lnr:2436';
  const openerProfile = {
    passing: 95, receiving: 91, offload: 77, ballHandling: 94,
    kickDistance: 93, kickAccuracy: 96,
    decisions: 96, anticipation: 90, vision: 95, teamwork: 88, leadership: 85,
    positioning: 83, tackling: 72, evasion: 82, ballCarry: 76,
  };
  // Curated starting tiers for ten documented senior profiles, by stable ID.
  // The last column contains their signature attributes.
  const elite = {
    'lnr:2449': [96, 96, ['passing', 'decisions', 'evasion']],
    'world:jlo:e9174f62b95a2e2f7c3e72f2': [95, 95, ['hooking', 'lineoutThrow', 'jackal']],
    'world:urc:185466': [94, 95, ['scrumTechnique', 'strength']],
    'world:prem:155409': [94, 94, ['lineoutJump', 'jumping', 'leadership']],
    'world:urc:235189': [93, 94, ['kickDistance', 'kickAccuracy', 'goalAccuracy']],
    'world:srp:p-20e72f6a2de567813bdcfb40': [93, 93, ['aerialAbility', 'topSpeed', 'positioning']],
    'lnr:2425': [92, 93, ['jackal', 'tackling', 'ruckClearout']],
    'world:urc:147486': [92, 92, ['jackal', 'tackling', 'positioning']],
    'world:srp:p-421a0e8fd929af7e40f1448d': [92, 92, ['passing', 'acceleration', 'ballCarry']],
    'world:urc:154929': [92, 92, ['acceleration', 'agility', 'evasion']],
  };
  const anchors = [[73, 0], [79, 3], [82, 5], [84, 7], [87, 8], [90, 8]];
  const weightsByPosition = new Map();
  const round = value => Math.round(value * 100) / 100;
  const compareId = (a, b) => Number(a > b) - Number(a < b);

  function alignStartingRole(player, confirmedPosition) {
    const originalPosition = player.gameplayPosition || player.pos;
    if (player.age < 23 || !player.attributesV2 || originalPosition === confirmedPosition) return;
    const original = rolePriors[originalPosition];
    const confirmed = rolePriors[confirmedPosition];
    if (!original || !confirmed) return;

    // Keep the player's estimated deviation from the V12 reference at each attribute.
    const attributesV2 = Object.fromEntries(Object.entries(player.attributesV2).map(([key, value]) => [
      key, Math.min(97, Math.max(20, value + confirmed[key] - original[key])),
    ]));
    player.attributesV2 = attributesV2;
    player.skills = projectSkills({ attributesV2, gameplayPosition: confirmedPosition });
  }

  function dose(rating) {
    if (rating <= anchors[0][0]) return 0;
    for (let i = 1; i < anchors.length; i++) {
      const [upper, high] = anchors[i];
      const [lower, low] = anchors[i - 1];
      if (rating <= upper) return Math.round(low + (high - low) * (rating - lower) / (upper - lower));
    }
    return anchors.at(-1)[1];
  }

  function axes(player, position) {
    const key = position + ':' + player.fam;
    if (!weightsByPosition.has(key)) {
      const neutral = Object.fromEntries(Object.keys(player.attributesV2).map(axis => [axis, 50]));
      const baseline = projectSkills({ attributesV2: neutral, gameplayPosition: position });
      const weights = Object.entries(roleWeights[player.fam]);
      const total = weights.reduce((sum, [, weight]) => sum + weight, 0);
      const sensitive = Object.keys(neutral).map(axis => {
        const adjusted = projectSkills({ attributesV2: { ...neutral, [axis]: 51 }, gameplayPosition: position });
        const weight = weights.reduce((sum, [skill, factor]) =>
          sum + factor * (adjusted[skill] - baseline[skill]), 0) / total;
        return { axis, weight };
      }).filter(({ weight }) => weight > 0);
      weightsByPosition.set(key, sensitive);
    }
    return weightsByPosition.get(key);
  }

  function calibrate(player) {
    const opener = player.id === openerId;
    const tier = elite[player.id];
    const lift = dose(player.rating);
    if (!opener && !tier && !lift) return;

    const initialNote = roleNote(player);
    const position = player.gameplayPosition || player.pos;
    const starting = player.attributesV2;
    const attributesV2 = { ...starting };
    const baseline = projectSkills({ attributesV2: starting, gameplayPosition: position });
    // Keep the existing difference between the source skills and their projection,
    // for example when the documented position differs from the original one.
    const skillsAt = () => Object.fromEntries(Object.entries(projectSkills({ attributesV2, gameplayPosition: position }))
      .map(([key, value]) => [key, round(Math.min(99, Math.max(15, player.skills[key] + value - baseline[key])))]));
    let skills = skillsAt();
    let note = initialNote;
    if (opener) {
      for (const [axis, value] of Object.entries(openerProfile)) {
        attributesV2[axis] = Math.max(starting[axis], value);
      }
      skills = skillsAt();
      note = roleNote({ ...player, skills });
    } else {
      const target = tier ? tier[1] : Math.min(90, initialNote + lift);
      if (tier) {
        for (const axis of tier[2]) attributesV2[axis] = Math.max(starting[axis], Math.min(97, target + 1));
        skills = skillsAt();
        note = roleNote({ ...player, skills });
      }
      const axesForRole = axes(player, position);
      while (note < target) {
        let choice = null;
        let best = 0;
        for (const { axis, weight } of axesForRole) {
          const increase = attributesV2[axis] - starting[axis];
          if (attributesV2[axis] >= 97 || !tier && (increase >= 16 || weight < 0.05)) continue;
          const priority = weight / (1 + 0.3 * increase);
          if (priority > best || priority === best && compareId(axis, choice) < 0) {
            choice = axis;
            best = priority;
          }
        }
        if (!choice) break;
        attributesV2[choice] = Math.min(97, attributesV2[choice] + 1);
        skills = skillsAt();
        note = roleNote({ ...player, skills });
      }
    }

    if (note <= initialNote) return;
    const targetRating = opener ? 88 : tier ? tier[0] : Math.min(90, player.rating + note - initialNote);
    const rating = Math.max(player.rating, targetRating);
    const growth = rating - player.rating;
    player.skillBase += growth;
    player.rating = rating;
    player.attributesV2 = attributesV2;
    player.skills = skills;
    player.dev.seasonStart = rating;
    if (opener) player.dev.potential = Math.max(player.dev.potential, 91);
    else player.dev.potential = Math.min(Math.max(97, player.dev.potential), player.dev.potential + growth);
  }

  function apply(players, sources = null) {
    for (const player of players) {
      if (player.age >= 23 && player.attributesV2 && (!sources || sources.has(player.id))) calibrate(player);
    }
  }

  return Object.freeze({ version, alignStartingRole, apply });
};
