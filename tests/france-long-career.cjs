'use strict';
const {context}=require('./france-harness.cjs');
const {readFixture,assertFixtureGuards,runSeasons,assertCheckpoint}=require('./helpers/france-long-career.cjs');
const {freezeFranceBirths}=require('./helpers/frozen-france-births.cjs');
const fixture=readFixture();assertFixtureGuards(fixture);
// Preserve the frozen v1 checkpoint, including all five seasons and exact RNG.
const began=performance.now(),h=context();
h.run("var setupPopulationV2=aiRosterSetup;aiRosterSetup=function(){var result=setupPopulationV2();S.aiRosterVersion=1;S.aiRoster.version=1;delete S.aiRoster.population;return result};");
freezeFranceBirths(h);
h.run("start(29,'france')");
require('node:assert/strict').equal(h.run('S.aiRosterVersion'),fixture.checkpoint.save.state.aiRosterVersion,'Frozen France checkpoint requires AI policy v1');
runSeasons(h,1,5);assertCheckpoint(h,fixture);
console.log('France S1–S5 PASS : checkpoint natif S6 et RNG identiques à la campagne continue',JSON.stringify({ms:performance.now()-began}));
