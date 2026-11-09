'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {classifyEvidence}=require('../native/engine/japan-category-evidence.cjs');

test('Une déclaration 2026–27 reste distincte d’une catégorie ancienne',()=>{
 assert.deepEqual(classifyEvidence({declared:{category:'B',season:'2026-27',source:'club-roster-26'}},{allowEstimate:true}),{category:'B',basis:'official-2026-27',reason:'current-declaration'});
 const historical={declared:{category:'C',season:'2025-26',source:'club-roster-25'}};
 assert.equal(classifyEvidence(historical).category,null);
 assert.deepEqual(classifyEvidence(historical,{allowEstimate:true}),{category:'C',basis:'estimated',reason:'prior-registration'});
 assert.equal(classifyEvidence({declared:{category:'A',season:'2025-26',source:'club-roster-25'}},{allowEstimate:true}).category,null);
});

test('Les critères A-1 reposent sur des preuves explicites, sans passeport déduit',()=>{
 assert.equal(classifyEvidence({nationality:'JP',birthInJapan:true}).category,null);
 assert.equal(classifyEvidence({noOtherUnion:true,birthInJapan:true}).category,'A-1');
 assert.equal(classifyEvidence({noOtherUnion:true,schoolJapanCompulsoryYears:6}).category,'A-1');
 assert.equal(classifyEvidence({noOtherUnion:true,ancestorBornInJapan:true}).category,'A-1');
 assert.equal(classifyEvidence({japanSeniorCaps:30}).reason,'thirty-japan-caps');
 assert.equal(classifyEvidence({grandfathered:true,grandfatherSource:'club-communique-26'}).reason,'transition-measure');
 assert.equal(classifyEvidence({japanSeniorCaps:29,grandfathered:true}).category,null);
});

test('Les 48 mois seuls ne suffisent pas à établir une catégorie officielle A-2',()=>{
 const e={noOtherUnion:true,jrfuRegistrationMonths:48};
 assert.equal(classifyEvidence(e).category,null);
 assert.equal(classifyEvidence(e,{allowEstimate:true}).basis,'estimated');
 assert.deepEqual(classifyEvidence({...e,a1Excluded:true}),{category:'A-2',basis:'derived-official-criteria',reason:'registration-48-months'});
 assert.equal(classifyEvidence({...e,jrfuRegistrationMonths:47,a1Excluded:true}).category,null);
});
