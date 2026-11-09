'use strict';
const {readFixture,resumeCheckpoint,runSeasons,assertFinal}=require('./helpers/france-long-career.cjs');
const fixture=readFixture(),began=performance.now();
const h=resumeCheckpoint(fixture);
// This frozen campaign predates portrait-bank births. Keep its historical
// constructors for new players without changing the imported checkpoint or
// filtering the final full-state SHA/RNG assertions. Current births stay bank 2.
h.run(`var goldenMakePlayer=makePlayer,goldenAcademyPlayer=academyPlayer;
 makePlayer=function(){var p=goldenMakePlayer.apply(this,arguments);delete p.appearanceBankVersion;return p};
 academyPlayer=function(){var p=goldenAcademyPlayer.apply(this,arguments);delete p.appearanceBankVersion;return p};`);
runSeasons(h,6,10);assertFinal(h,fixture);
console.log('France S6–S10 PASS : S11 et RNG identiques à la campagne continue, 4330 résultats au total',JSON.stringify({ms:performance.now()-began}));
