'use strict';
const {readFixture,resumeCheckpoint,runSeasons,assertFinal}=require('./helpers/france-long-career.cjs');
const {freezeFranceBirths}=require('./helpers/frozen-france-births.cjs');
const fixture=readFixture(),began=performance.now();
const h=resumeCheckpoint(fixture);
freezeFranceBirths(h);
runSeasons(h,6,10);assertFinal(h,fixture);
console.log('France S6–S10 PASS : S11 et RNG identiques à la campagne continue, 4330 résultats au total',JSON.stringify({ms:performance.now()-began}));
