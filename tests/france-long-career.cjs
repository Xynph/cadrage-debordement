'use strict';
const {context}=require('./france-harness.cjs');
const {readFixture,assertFixtureGuards,runSeasons,assertCheckpoint}=require('./helpers/france-long-career.cjs');
const fixture=readFixture();assertFixtureGuards(fixture);
const began=performance.now(),h=context();h.run("start(29,'france')");
runSeasons(h,1,5);assertCheckpoint(h,fixture);
console.log('France S1–S5 PASS : checkpoint natif S6 et RNG identiques à la campagne continue',JSON.stringify({ms:performance.now()-began}));
