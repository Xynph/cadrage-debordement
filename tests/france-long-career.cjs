'use strict';
const {context}=require('./france-harness.cjs');
const {readFixture,assertFixtureGuards,runSeasons,assertCheckpoint}=require('./helpers/france-long-career.cjs');
const fixture=readFixture();assertFixtureGuards(fixture);
// Preserve the frozen v1 checkpoint, including all five seasons and exact RNG.
const began=performance.now(),h=context();
h.run("var setupPopulationV2=aiRosterSetup;aiRosterSetup=function(){var result=setupPopulationV2();S.aiRosterVersion=1;S.aiRoster.version=1;delete S.aiRoster.population;return result};");
// Match the same pre-portrait-bank births as the frozen S6/S11 references.
// Only fixture constructors differ; no state/hash filtering or production rule.
h.run(`var goldenMakePlayer=makePlayer,goldenAcademyPlayer=academyPlayer;
 makePlayer=function(){var p=goldenMakePlayer.apply(this,arguments);delete p.appearanceBankVersion;return p};
 academyPlayer=function(){var p=goldenAcademyPlayer.apply(this,arguments);delete p.appearanceBankVersion;return p};`);
h.run("start(29,'france')");
require('node:assert/strict').equal(h.run('S.aiRosterVersion'),fixture.checkpoint.save.state.aiRosterVersion,'Frozen France checkpoint requires AI policy v1');
runSeasons(h,1,5);assertCheckpoint(h,fixture);
console.log('France S1–S5 PASS : checkpoint natif S6 et RNG identiques à la campagne continue',JSON.stringify({ms:performance.now()-began}));
