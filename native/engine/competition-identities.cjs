'use strict';
const path=require('node:path');

const BASE={
 elite:['Élite française','Élite'],
 accession:['Division d’accession française','Accession'],
 nationale:['Division fédérale française','Fédérale'],
 prem:['Élite anglaise','Élite anglaise'],
 champ:['Division d’accession anglaise','Accession anglaise'],
 urc:['Ligue intercontinentale','Intercontinentale'],
 srp:['Ligue du Pacifique','Pacifique'],
 'jlo-d1':['Élite japonaise','Japon D1'],
 'jlo-d2':['Division d’accession japonaise','Japon D2'],
 champions:['Coupe continentale Élite','Coupe Élite'],
 challenge:['Coupe continentale Accession','Coupe Accession'],
 access:['Barrage d’accession','Barrage'],
 'access-nationale':['Barrage Accession / Fédérale','Barrage fédéral'],
 'jlo-d1-d2':['Barrage Japon D1 / D2','Barrage Japon'],
};

function allowed(database){
 const result=new Set((database.leagues||[]).map(row=>row.id).filter(id=>Object.hasOwn(BASE,id)));
 if(database.leagues){result.add('champions');result.add('challenge');result.add('access');}
 if(result.has('nationale'))result.add('access-nationale');
 if(result.has('jlo-d2'))result.add('jlo-d1-d2');
 return result;
}

function presentation(database,pack){
 const ids=allowed(database);
 if(!database.leagues){ids.add('elite');ids.add('accession');ids.add('access');}
 return Object.fromEntries([...ids].map(id=>{
  const custom=pack?.competitions?.[id],base=BASE[id];
  const row={name:custom?.name??base[0],shortName:custom?.shortName??custom?.name??base[1]};
  if(custom?.logo)row.logoPath=path.join(pack.folder,custom.logo);
  return [id,row];
 }));
}

function apply(model,identities){
 model.meta.competitionIdentities=identities;
 const oldNames={
  'jlo-d1-d2':'Barrage Japon D1 / D2',
  'access-nationale':'Barrage Pro D2 / Nationale',
 };
 for(const league of model.leagues??[]){
  if(!Object.hasOwn(identities,league.id))continue;
  oldNames[league.id]=league.name;
  Object.assign(league,identities[league.id]);
 }
 for(const division of model.clubLife?.press?.journal?.divisions??[]){
  if(Object.hasOwn(identities,division.id))division.label=identities[division.id].name;
 }
 const relabel=match=>{
  const id=match.competitionId,identity=identities[id],previous=oldNames[id];
  if(identity&&typeof previous==='string'&&match.label?.startsWith(previous+' · ')){
   match.label=identity.name+match.label.slice(previous.length);
  }
 };
 for(const match of model.calendar??[])relabel(match);
 if(model.next){
  const prior=model.next.label;
  relabel(model.next);
  if(model.meta.roundLabel===prior)model.meta.roundLabel=model.next.label;
 }
}

module.exports={allowed,presentation,apply};
