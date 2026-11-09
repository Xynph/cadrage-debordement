'use strict';
const fs=require('node:fs'),path=require('node:path');
const registry=require('./staff-registry.json');
const worldRegistry=require('./world-staff-registry.json');
const WORLD_ID='rugby-world-2026-11-08-v1';
const PACIFIC_ID='rugby-world-2026-11-09-pacific-v2';
const collectIds=r=>new Set(r.clubs.flatMap(c=>c.members.map(p=>p.id)));
const worldIds=collectIds(worldRegistry);
const ids=collectIds(registry);
const extension=path.join(__dirname,'world-pacific-staff-extension.json');
let pacificRegistry=null,pacificIds=null;
if(fs.existsSync(extension)){
 const delta=JSON.parse(fs.readFileSync(extension,'utf8'));
 const used=new Set(worldIds);
 const valid=(yes,label)=>{if(!yes)throw Error('Registre de staff Pacifique invalide : '+label+'.');};
 valid(delta?.baseId===WORLD_ID&&delta.databaseId===PACIFIC_ID&&Array.isArray(delta.clubs)&&delta.clubs.length===10,'édition');
 for(const [i,c] of delta.clubs.entries()){
  valid(c?.id===58+i&&Array.isArray(c.members)&&c.members.length>0,'club');
  for(const p of c.members){
   valid(p?.clubId===c.id&&typeof p.id==='string'&&p.id.length<=100&&!used.has(p.id)&&typeof p.name==='string'&&typeof p.role==='string','identité');
   used.add(p.id);
  }
 }
 pacificRegistry={...worldRegistry,observedAt:delta.observedAt,clubs:worldRegistry.clubs.concat(delta.clubs)};
 pacificIds=used;
}
const isWorld=id=>id===WORLD_ID||id===PACIFIC_ID;
function forDatabase(id){
 if(id===WORLD_ID)return {registry:worldRegistry,ids:worldIds};
 if(id===PACIFIC_ID){
  if(!pacificRegistry)throw Error('Registre de staff Pacifique indisponible.');
  return {registry:pacificRegistry,ids:pacificIds};
 }
 return {registry,ids};
}
function project(model){
 const mode=model.meta?.mode,id=model.meta?.database?.id,selected=mode==='world'?forDatabase(id??WORLD_ID).registry:mode==='common'?registry:null;
 const teams=selected?selected.clubs.map(c=>({id:c.id,name:model.meta.catalogue.find(x=>x.id===c.id)?.name||'Club '+c.id,members:c.members.map(p=>({...p}))})):[];
 return {...model,staff:{version:registry.version,observedAt:id===PACIFIC_ID?selected.observedAt:registry.observedAt,teams,notice:'Encadrement de référence documenté, indépendant de la saison de carrière. Les rôles et les portraits ne donnent aucun bonus de simulation. Les délégations restent vos choix.'}};
}
module.exports={project,ids,registry,worldIds,worldRegistry,isWorld,forDatabase};
