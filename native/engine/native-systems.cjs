'use strict';
// Closed production manifest. Each domain owns its rules and strict validator;
// the worker remains the only disk transaction and save authority.
const domains={press:require('./press.cjs'),relationships:require('./relationships.cjs'),clubWorld:require('./club-world.cjs'),academyPathways:require('./academy.cjs'),clubStrategy:require('./club-strategy.cjs'),clubSupport:require('./club-support.cjs'),managerCareer:require('./manager-career.cjs'),playbook:require('./playbook.cjs'),coachNotebook:require('./coach-notes.cjs')};
const files=Object.freeze([...new Set(Object.values(domains).flatMap(d=>d.files))]);
const commands=Object.freeze(Object.values(domains).flatMap(d=>d.commands));
if(new Set(commands).size!==commands.length)throw Error('Commandes natives de domaine en double.');
function bootstrap(){
 const definitions=Object.entries(domains).map(([key,d])=>JSON.stringify(key)+':('+d.factory.toString()+')()').join(',');
 return `const nativeSystems=(()=>{
  const domains={${definitions}},owners=new Map();
  ${Object.entries(domains).map(([key,d])=>d.commands.map(c=>`owners.set(${JSON.stringify(c)},domains[${JSON.stringify(key)}]);`).join('')).join('')}
  return {
   project(){return S?Object.fromEntries(Object.entries(domains).map(([key,d])=>[key,d.project()])):{};},
   validate(state){if(state)for(const d of Object.values(domains))d.validate(state);},
   execute(command,payload){const owner=owners.get(command);if(!owner)throw Error('Commande de domaine inconnue.');return owner.execute(command,payload);},
   installHooks(){for(const d of Object.values(domains))d.installHooks();}
  };
 })();
 const nativeBaseValidator=validateCareer;
 validateCareer=state=>{const result=nativeBaseValidator(state);nativeSystems.validate(state);return result;};
 nativeSystems.installHooks();`;
}
module.exports={files,commands,bootstrap};
