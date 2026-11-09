'use strict';
const registry=require('./staff-registry.json');
const worldRegistry=require('./world-staff-registry.json');
const worldIds=new Set(worldRegistry.clubs.flatMap(c=>c.members.map(p=>p.id)));
const ids=new Set(registry.clubs.flatMap(c=>c.members.map(p=>p.id)));
function project(model){
 const selected=model.meta?.mode==='world'?worldRegistry:model.meta?.mode==='common'?registry:null;
 const teams=selected?selected.clubs.map(c=>({id:c.id,name:model.meta.catalogue.find(x=>x.id===c.id)?.name||'Club '+c.id,members:c.members.map(p=>({...p}))})):[];
 return {...model,staff:{version:registry.version,observedAt:registry.observedAt,teams,notice:'Encadrement de référence documenté, indépendant de la saison de carrière. Les rôles et les portraits ne donnent aucun bonus de simulation. Les délégations restent vos choix.'}};
}
module.exports={project,ids,registry,worldIds,worldRegistry};
