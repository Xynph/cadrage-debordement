'use strict';
// Barème senior V2 hors du moteur : même fabrique que la VM Monde (native/engine/world-vm.cjs), avec la
// projection des attributs du compilateur du registre et la note au poste de dist/rugby.js.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '../..');

function roleTools() {
  const rugby = fs.readFileSync(path.join(root, 'dist/rugby.js'), 'utf8');
  const context = vm.createContext({ clamp: (value, min, max) => Math.min(max, Math.max(min, value)), focusedBonus: () => 0 });
  vm.runInContext(rugby.slice(0, rugby.indexOf('function slotEligible')) + '\nthis.roleNote=roleNote;this.ROLE_WEIGHTS=ROLE_WEIGHTS;', context);
  return { roleNote: context.roleNote, roleWeights: context.ROLE_WEIGHTS };
}

function levels() {
  const table = JSON.parse(fs.readFileSync(path.join(root, 'native/engine/world-niveaux-v2.json'), 'utf8'));
  return { joueurs: table.joueurs, clubs: table.clubs };
}

function createV2() {
  const { roleNote, roleWeights } = roleTools();
  const { projectSkills } = require('../../scripts/build-world-registry.cjs');
  const factory = require('../../native/engine/senior-calibration.cjs');
  const priors = require('../../native/engine/role-attribute-priors.json').roles;
  const scale = require('../../native/engine/world-rating-scale.json');
  const calibration = factory(p => projectSkills(p.attributesV2, p.gameplayPosition || p.pos), roleNote, roleWeights, priors, scale, levels());
  return { calibration, roleNote, scale };
}

// Applique le barème V2 à une copie des effectifs d'un registre, club par club, comme à la création d'une carrière.
function calibrateRegistry(registry, clubFilter = () => true) {
  const { calibration } = createV2();
  const clubs = JSON.parse(JSON.stringify(registry.clubs)).filter(clubFilter);
  const sources = new Map(registry.clubs.flatMap(c => c.players.map(p => [p.id, p])));
  for (const club of clubs) calibration.apply(club.players, sources, { clubId: club.id, leagueId: club.leagueId, registry });
  calibration.settle(clubs.flatMap(club => club.players));
  return clubs;
}

module.exports = { createV2, calibrateRegistry, levels, roleTools };
