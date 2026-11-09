'use strict';
const {createWorldEditions}=require('./world-editions.cjs');
const competitions=require('./world-competitions.cjs');
const validation=require('./world-validation.cjs');
const knockout=require('./world-knockout.cjs');
const career=require('./world-career.cjs');
const dispatch=require('./world-dispatch.cjs');
const pacificRules=require('./super-rugby-pacific.cjs');
const pacificCalendar=require('./srp-calendar-2027.json');
const pacificMatch=require('./srp-match.cjs');
const japanRules=require('./league-one-d1.cjs'),japanSeason=require('./japan-season.cjs');
const japanD1=require('./jlo-d1-calendar-2026-27-public.json'),japanD2=require('./jlo-d2-calendar-2026-27-public.json');
const japanMatch=require('./japan-match.cjs'),japanEligibility=require('./japan-eligibility.cjs'),japanQuota=require('./japan-quota-runtime.cjs');

function bootstrap(){
 return [
  'const CDWorldRegistry=JSON.parse(nativeWorldRegistryText);',
  'const CDWorldPacificRegistry=typeof nativeWorldPacificRegistryText==="undefined"?null:JSON.parse(nativeWorldPacificRegistryText);',
  'const CDWorldJapanRegistry=typeof nativeWorldJapanRegistryText==="undefined"?null:JSON.parse(nativeWorldJapanRegistryText);',
  `const CDWorldEditions=(${createWorldEditions.toString()})(CDWorldRegistry,CDWorldPacificRegistry,CDWorldJapanRegistry);`,
  `const CDWorldSRP=(${pacificRules.factory.toString()})(${JSON.stringify(pacificCalendar)});`,
  `const CDWorldSRPMatch=(${pacificMatch.toString()})(CDWorldSRP);`,
  `const CDWorldJapanRules=(${japanRules.factory.toString()})(${JSON.stringify(japanD1)});`,
  `const CDWorldJapan=(${japanSeason.factory.toString()})(CDWorldJapanRules,${JSON.stringify(japanD2)});`,
  `const CDWorldJapanMatch=(${japanMatch.toString()})(CDWorldJapanRules);`,
  `const CDWorldJapanQuota=(${japanQuota.factory.toString()})((${japanEligibility.factory.toString()})());`,
  `const CDWorldCompetitions=(${competitions.factory.toString()})();`,
  `const CDWorldValidation=(${validation.toString()})();`,
  `const CDWorldKnockout=(${knockout.toString()})();`,
  `const CDWorldCareer=(${dispatch.toString()})(CDWorldEditions,${career.toString()});`,
  'CDWorldCareer.installHooks();if(CDWorldPacificRegistry)CDWorldSRPMatch.installHooks();if(CDWorldJapanRegistry){CDWorldJapanMatch.installHooks();CDWorldJapanQuota.installHooks();}',
 ].join('');
}
module.exports={bootstrap};
