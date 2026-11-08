'use strict';
const registry=require('./staff-registry.json');
const ids=new Set(registry.clubs.flatMap(c=>c.members.map(p=>p.id)));
function project(model){
 const teams=model.meta?.mode==='common'?registry.clubs.map(c=>({id:c.id,name:model.meta.catalogue.find(x=>x.id===c.id)?.name||'Club '+c.id,members:c.members.map(p=>({...p}))})):[];
 return {...model,staff:{version:registry.version,observedAt:registry.observedAt,teams,notice:'Encadrement de référence documenté, indépendant de la saison de carrière. Les rôles et les portraits ne donnent aucun bonus de simulation. Les délégations restent vos choix.'}};
}
module.exports={project,ids,registry};
