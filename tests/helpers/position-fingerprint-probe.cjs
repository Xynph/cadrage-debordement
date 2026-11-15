'use strict';
// Entrées détachées du Monde réel ; instrumentation des accès, pas du temps.
module.exports=function fingerprintProbe(h){
 return JSON.parse(h.run(`JSON.stringify((()=>{
  const p=JSON.parse(JSON.stringify(club().players[0]));p.id='position-fingerprint-probe';
  const data=p.dev;data.specialization={version:1,bonuses:{scrum:0}};
  let reads=0;Object.defineProperty(p,'dev',{get(){reads++;return data;}});
  const project=()=>nativePositionAptitudes.project(p),sequence=[];
  project();reads=0;for(let i=0;i<100;i++)project();const devReads=reads;
  sequence.push(project());data.specialization.bonuses.scrum=5;sequence.push(project());
  data.specialization.bonuses={scrum:-3,power:4};sequence.push(project());
  data.specialization.version=2;sequence.push(project());
  data.specialization.version=1;sequence.push(project());
  delete data.specialization;sequence.push(project());
  data.specialization={version:1};let malformedRejected=false;
  try{project();}catch(error){malformedRejected=true;}
  return {devReads,sequence,malformedRejected};
 })())`));
};
