'use strict';
const {createWorldEditions}=require('./world-editions.cjs');
const competitions=require('./world-competitions.cjs');
const validation=require('./world-validation.cjs');
const knockout=require('./world-knockout.cjs');
const career=require('./world-career.cjs');
const dispatch=require('./world-dispatch.cjs');

function bootstrap(){
 return [
  'const CDWorldRegistry=JSON.parse(nativeWorldRegistryText);',
  `const CDWorldEditions=(${createWorldEditions.toString()})(CDWorldRegistry);`,
  `const CDWorldCompetitions=(${competitions.factory.toString()})();`,
  `const CDWorldValidation=(${validation.toString()})();`,
  `const CDWorldKnockout=(${knockout.toString()})();`,
  `const CDWorldCareer=(${dispatch.toString()})(CDWorldEditions,${career.toString()});`,
  'CDWorldCareer.installHooks();',
 ].join('');
}
module.exports={bootstrap};
