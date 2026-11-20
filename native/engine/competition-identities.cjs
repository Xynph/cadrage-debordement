'use strict';
const path=require('node:path');
const FORMATS=require('./competition-formats.json');

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
  // Saison de départ et format lus dans les données ; compétition absente du fichier : rien d'ajouté.
  const facts=FORMATS.competitions?.[id];
  if(facts){
   const start=Number(FORMATS.anneeDepart);
   if(Number.isInteger(start))row.startSeasonLabel=facts.saison==='civile'?String(start+1):start+'-'+(start+1);
   if(Array.isArray(facts.format)&&facts.format.length)row.formatLines=facts.format.filter(line=>typeof line==='string'&&line);
  }
  return [id,row];
 }));
}

// Noms complets de base (table ci-dessus et nom du registre de l'édition) → nom fourni par le pack.
// Les noms courts ne sont pas remplacés : trop génériques pour un remplacement dans du texte libre.
function replacements(database,pack){
 const result=[];
 for(const id of allowed(database)){
  const name=pack?.competitions?.[id]?.name;
  if(typeof name!=='string'||!name)continue;
  const sources=new Set([BASE[id][0]]);
  for(const row of database.leagues||[])if(row.id===id&&typeof row.name==='string'&&row.name)sources.add(row.name);
  for(const from of sources)if(from!==name)result.push([from,name]);
 }
 return result;
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

module.exports={allowed,presentation,apply,replacements};
