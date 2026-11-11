'use strict';

// Keep historical birth rules for the frozen state and RNG receipts.
// Current player creation and save normalization are tested separately.
function freezeFranceBirths(h) {
  h.run(`var goldenMakePlayer=makePlayer,goldenAcademyPlayer=academyPlayer,goldenSetupDevelopment=setupDevelopment;
   makePlayer=function(){var p=goldenMakePlayer.apply(this,arguments);delete p.appearanceBankVersion;return p};
   academyPlayer=function(clubId,slot,season,serial,emergency=false){
    var p=goldenAcademyPlayer.apply(this,arguments),h=seedHash(p.id);
    var info=serial>=300&&serial<315&&worldActive()?worldClub(clubId):null;
    p.dev.potential=clamp((emergency?68+h%10:76+h%19)+Math.max(0,(info?.facilities||2)-2),p.rating,99);
    delete p.appearanceBankVersion;return p;
   };
   normalizeAcademyPotential=()=>false;
   setupDevelopment=function(){goldenSetupDevelopment.apply(this,arguments);if(S?.development)delete S.development.academyPotentialVersion;};`);
}

module.exports = { freezeFranceBirths };
