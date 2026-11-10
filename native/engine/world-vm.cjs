'use strict';
const {createWorldEditions}=require('./world-editions.cjs');
const competitions=require('./world-competitions.cjs');
const validation=require('./world-validation.cjs');
const knockout=require('./world-knockout.cjs');
const career=require('./world-career.cjs');
const seniorCalibration=require('./senior-calibration.cjs');
const initialContracts=require('./world-initial-contracts.json');
const dispatch=require('./world-dispatch.cjs');
const pacificRules=require('./super-rugby-pacific.cjs');
const pacificCalendar=require('./srp-calendar-2027.json');
const pacificMatch=require('./srp-match.cjs');
const japanRules=require('./league-one-d1.cjs'),japanSeason=require('./japan-season.cjs');
const japanD1=require('./jlo-d1-calendar-2026-27-public.json'),japanD2=require('./jlo-d2-calendar-2026-27-public.json');
const nationaleMatch=require('./nationale-match.cjs'),nationaleSquad=require('./nationale-squad.cjs'),nationaleCards=require('./nationale-qualification.cjs'); const nationale=require('./nationale.cjs'),nationaleCalendar=require('./nationale-calendar-2026-27.json');
const japanMatch=require('./japan-match.cjs'),japanEligibility=require('./japan-eligibility.cjs'),japanQuota=require('./japan-quota-runtime.cjs');

const champRules=require('./champ-rugby.cjs'),champCalendar=require('./champ-calendar-2026-27.json'),champMatch=require('./champ-match.cjs');

function bootstrap(){
 return [
  'const CDWorldRegistry=JSON.parse(nativeWorldRegistryText);',
  'const CDWorldPacificRegistry=typeof nativeWorldPacificRegistryText==="undefined"?null:JSON.parse(nativeWorldPacificRegistryText);',
  'const CDWorldJapanRegistry=typeof nativeWorldJapanRegistryText==="undefined"?null:JSON.parse(nativeWorldJapanRegistryText);',
  'const CDWorldNationaleRegistry=typeof nativeWorldNationaleRegistryText==="undefined"?null:JSON.parse(nativeWorldNationaleRegistryText);',
  'const CDWorldChampRegistry=typeof nativeWorldChampRegistryText==="undefined"?null:JSON.parse(nativeWorldChampRegistryText);',
  `const CDWorldEditions=(${createWorldEditions.toString()})(CDWorldRegistry,CDWorldPacificRegistry,CDWorldJapanRegistry,CDWorldNationaleRegistry,CDWorldChampRegistry);`,
  `const CDWorldSRP=(${pacificRules.factory.toString()})(${JSON.stringify(pacificCalendar)});`,
  `const CDWorldSRPMatch=(${pacificMatch.toString()})(CDWorldSRP);`,
  `const CDWorldJapanRules=(${japanRules.factory.toString()})(${JSON.stringify(japanD1)});`,
  `const CDWorldJapan=(${japanSeason.factory.toString()})(CDWorldJapanRules,${JSON.stringify(japanD2)});`,
  `const CDWorldJapanMatch=(${japanMatch.toString()})(CDWorldJapanRules);`,
  `const CDWorldJapanQuota=(${japanQuota.factory.toString()})((${japanEligibility.factory.toString()})());`,
  `const CDWorldNationale=(${nationale.factory.toString()})(${JSON.stringify(nationaleCalendar)});`,
  `const CDWorldNationaleMatch=(${nationaleMatch.toString()})(CDWorldNationale);`,
  `const CDWorldNationaleCards=(${nationaleCards.factory.toString()})();`,
  `const CDWorldChamp=(${champRules.factory.toString()})(${JSON.stringify(champCalendar)});`,
  `const CDWorldChampMatch=(${champMatch.toString()})(CDWorldChamp);`,
  `const CDWorldCompetitions=(${competitions.factory.toString()})();`,
  `const CDWorldValidation=(${validation.toString()})();`,
  `const CDWorldKnockout=(${knockout.toString()})();`,
  `const CDWorldInitialContracts=${JSON.stringify(initialContracts)};`,
  `const CDWorldSeniorCalibration=(${seniorCalibration.toString()})(lnrProjectV12,roleNote,ROLE_WEIGHTS);`,
  `const CDWorldCareer=(${dispatch.toString()})(CDWorldEditions,(edition,active)=>(${career.toString()})(edition,active,CDWorldInitialContracts,CDWorldSeniorCalibration));`,
  `CDWorldCareer.installHooks();if(CDWorldPacificRegistry)CDWorldSRPMatch.installHooks();if(CDWorldJapanRegistry){CDWorldJapanMatch.installHooks();CDWorldJapanQuota.installHooks();}const CDNationaleReducedBench=CDWorldNationaleRegistry?(${nationaleSquad.toString()})():null;`,
 ].join('');
}
module.exports={bootstrap};
