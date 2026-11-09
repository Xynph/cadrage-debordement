'use strict';

// Conditions from the League One registration announcement for 2026–27 and
// its transition measures. This accepts evidence, not a player's nationality.
function classifyEvidence(evidence,{allowEstimate=false}={}){
 const e=evidence||{},d=e.declared||{};
 const result=(category,basis,reason)=>({category,basis,reason});
 const known=['A-1','A-2','B','C'];
 const cited=x=>typeof x==='string'&&x.trim().length>0;
 if(d.season==='2026-27'&&cited(d.source)&&known.includes(d.category))
  return result(d.category,'official-2026-27','current-declaration');
 if(Number.isInteger(e.japanSeniorCaps)&&e.japanSeniorCaps>=30)
  return result('A-1','derived-official-criteria','thirty-japan-caps');
 if(e.grandfathered===true&&cited(e.grandfatherSource))
  return result('A-1','derived-official-criteria','transition-measure');
 if(e.noOtherUnion===true){
  if(e.birthInJapan===true||e.ancestorBornInJapan===true)
   return result('A-1','derived-official-criteria','birth-or-ancestry');
  if(Number.isInteger(e.schoolJapanCompulsoryYears)&&e.schoolJapanCompulsoryYears>=6&&e.schoolJapanCompulsoryYears<=9)
   return result('A-1','derived-official-criteria','compulsory-education');
  if(Number.isInteger(e.jrfuRegistrationMonths)&&e.jrfuRegistrationMonths>=48){
   if(e.a1Excluded===true)return result('A-2','derived-official-criteria','registration-48-months');
   if(allowEstimate)return result('A-2','estimated','registration-a1-unresolved');
  }
 }
 if(allowEstimate&&d.season==='2025-26'&&cited(d.source)){
  if(d.category==='B'||d.category==='C')return result(d.category,'estimated','prior-registration');
  if(d.category==='A'&&e.domesticPathwayVerified===true&&cited(e.domesticPathwaySource))
   return result('A-1','estimated','domestic-pathway-and-prior-a');
 }
 return result(null,'unknown','insufficient-evidence');
}
module.exports={classifyEvidence};
