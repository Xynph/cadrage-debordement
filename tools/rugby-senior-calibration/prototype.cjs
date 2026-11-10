'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { projectSkills } = require('../../scripts/build-world-registry.cjs');

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
const round = value => Math.round(value * 100) / 100;
const rugby = fs.readFileSync(path.resolve(__dirname, '../../dist/rugby.js'), 'utf8');
const { ROLE_WEIGHTS, roleNote } = vm.runInNewContext(
  rugby.slice(0, rugby.indexOf('function slotEligible')) + '\n({ ROLE_WEIGHTS, roleNote })',
  { clamp, focusedBonus: (p, k) => p.dev?.specialization?.version === 1 ? p.dev.specialization.bonuses[k] || 0 : 0 }
);

// This prototype adds contrast at the top of the existing senior scale.
const anchors = [[73, 0], [76, 2], [79, 3], [82, 7], [83, 9], [84, 10], [87, 9], [90, 7]];
const sensitivity = new Map();

function lift(rating) {
  if (rating <= anchors[0][0]) return 0;
  for (let i = 1; i < anchors.length; i++) {
    const [upper, high] = anchors[i], [lower, low] = anchors[i - 1];
    if (rating <= upper) return Math.round(low + (high - low) * (rating - lower) / (upper - lower));
  }
  return anchors.at(-1)[1];
}

function axesFor(player, position) {
  const key = position + ':' + player.fam;
  if (sensitivity.has(key)) return sensitivity.get(key);
  const neutral = Object.fromEntries(Object.keys(player.attributesV2).map(axis => [axis, 50]));
  const baseline = projectSkills(neutral, position);
  const weights = Object.entries(ROLE_WEIGHTS[player.fam]);
  const total = weights.reduce((sum, [, weight]) => sum + weight, 0);
  const axes = Object.keys(neutral).map(axis => {
    const adjusted = projectSkills({ ...neutral, [axis]: 51 }, position);
    const weight = round(weights.reduce((sum, [skill, factor]) =>
      sum + factor * (adjusted[skill] - baseline[skill]), 0) / total);
    return { axis, weight };
  }).filter(({ weight }) => weight >= 0.06);
  sensitivity.set(key, axes);
  return axes;
}

function calibrate(player, override, applyCurve) {
  // Keep the under-23 cohort on the existing development scale.
  const dose = applyCurve && player.age >= 23 ? lift(player.rating) : 0;
  if (!dose && !override) return player;

  const position = player.gameplayPosition || player.pos;
  const starting = player.attributesV2;
  const attributesV2 = { ...starting };
  const baseline = projectSkills(starting, position);
  const skillsAt = attributes => Object.fromEntries(Object.entries(projectSkills(attributes, position)).map(
    ([key, value]) => [key, round(clamp(player.skills[key] + value - baseline[key], 15, 99))]
  ));
  const noteAt = attributes => roleNote({ ...player, skills: skillsAt(attributes) });
  const initialNote = roleNote(player);

  if (override) {
    assert.ok(Object.keys(override).length > 0, 'Dérogation vide');
    for (const [axis, value] of Object.entries(override)) {
      assert.ok(Object.hasOwn(attributesV2, axis) && Number.isInteger(value) && value >= 20 && value <= 97, axis);
      attributesV2[axis] = value;
    }
  } else {
    const target = Math.min(97, initialNote + dose);
    const axes = axesFor(player, position);
    while (noteAt(attributesV2) < target) {
      const choices = axes.filter(({ axis }) => attributesV2[axis] < 97 && attributesV2[axis] - starting[axis] < 16);
      choices.sort((a, b) => {
        const priority = ({ axis, weight }) => weight / (1 + .3 * (attributesV2[axis] - starting[axis]));
        return priority(b) - priority(a) || a.axis.localeCompare(b.axis);
      });
      if (!choices.length) break;
      attributesV2[choices[0].axis]++;
    }
  }

  const delta = noteAt(attributesV2) - initialNote;
  const rating = clamp(player.rating + delta, player.rating, 97);
  const growth = rating - player.rating;
  const result = {
    ...player,
    rating,
    skillBase: player.skillBase + growth,
    attributesV2,
    skills: skillsAt(attributesV2),
    dev: {
      ...player.dev,
      potential: clamp(player.dev.potential + growth, rating, 97),
      seasonStart: rating,
    },
  };
  assert.equal(roleNote(result), initialNote + delta, 'La note moteur suit le profil détaillé');
  return result;
}

function prepare(state, overrides, applyCurve = true) {
  assert.ok(
    state.worldMode?.version === 5 && state.season === 1 && state.round === 0 && state.phase === 'league' &&
      !state.live && !state.trained && state.history.length === 0,
    'Le barème d’essai exige une nouvelle carrière Monde Champ avant toute décision.'
  );
  const seen = new Set();
  const clubs = state.clubs.map(club => ({
    ...club,
    players: club.players.map(player => {
      assert.ok(player.attributesV2 && Object.keys(player.attributesV2).length === 36, player.id);
      const override = Object.hasOwn(overrides, player.id) ? overrides[player.id] : undefined;
      if (override) seen.add(player.id);
      return calibrate(player, override, applyCurve);
    }),
  }));
  assert.equal(seen.size, Object.keys(overrides).length, 'Joueur du dossier absent du registre');
  return { ...state, clubs };
}

module.exports = { anchors, prepare, roleNote };
