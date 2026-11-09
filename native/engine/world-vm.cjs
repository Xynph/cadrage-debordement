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

function bootstrap(){
 return [
  'const CDWorldRegistry=JSON.parse(nativeWorldRegistryText);',
  'const CDWorldPacificRegistry=typeof nativeWorldPacificRegistryText==="undefined"?null:JSON.parse(nativeWorldPacificRegistryText);',
  `const CDWorldEditions=(${createWorldEditions.toString()})(CDWorldRegistry,CDWorldPacificRegistry);`,
  `const CDWorldSRP=(${pacificRules.factory.toString()})(${JSON.stringify(pacificCalendar)});`,
  `const CDWorldSRPMatch=(${pacificMatch.toString()})(CDWorldSRP);`,
  `const CDWorldCompetitions=(${competitions.factory.toString()})();`,
  `const CDWorldValidation=(${validation.toString()})();`,
  `const CDWorldKnockout=(${knockout.toString()})();`,
  `const CDWorldCareer=(${dispatch.toString()})(CDWorldEditions,${career.toString()});`,
  'CDWorldCareer.installHooks();if(CDWorldPacificRegistry)CDWorldSRPMatch.installHooks();',
 ].join('');
}
module.exports={bootstrap};
