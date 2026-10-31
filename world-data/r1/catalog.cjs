'use strict';
/** R1 catalogue portable, aucun accès au moteur historique. */
const ID=/^(club|competition|player|staff|academy):[a-z0-9][a-z0-9-]*$/;
const ROLES=new Set(['head-coach','assistant','attack','defence','forwards','scrum','skills','fitness','medical','analyst','recruiter']);
const POSITIONS=new Set(['loosehead','hooker','tighthead','lock','blindside','openside','number-eight','scrum-half','fly-half','wing','centre','fullback']);
const isText=x=>typeof x==='string'&&x.trim().length>0;
const isDate=x=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&Number.isFinite(Date.parse(x))&&new Date(x).toISOString().slice(0,10)===x;
function validateCatalog(data,{complete=false}={}){
 const errors=[],error=(path,message)=>errors.push(path+': '+message);
 if(!data||typeof data!=='object'||Array.isArray(data))return {valid:false,errors:['catalogue: objet requis']};
 if(data.schemaVersion!==1)error('schemaVersion','version 1 requise');
 if(data.season!=='2026-2027')error('season','saison R1 requise');
 if(!isDate(data.snapshotDate))error('snapshotDate','date ISO réelle requise');
 const entities=['competitions','clubs','players','staff','academy'];
 const all=new Map();
 for(const kind of entities){
  if(!Array.isArray(data[kind])){error(kind,'tableau requis');continue}
  data[kind].forEach((item,i)=>{
   const path=kind+'['+i+']';
   if(!item||typeof item!=='object'||Array.isArray(item)){error(path,'objet requis');return}
   if(!ID.test(item.id||''))error(path+'.id','identifiant stable invalide');
   else if(all.has(item.id))error(path+'.id','identifiant dupliqué avec '+all.get(item.id));
   else all.set(item.id,path);
   if(!isText(item.name))error(path+'.name','nom requis');
   if(!item.provenance||typeof item.provenance!=='object'||!isText(item.provenance.sourceUrl)||!/^https:\/\//.test(item.provenance.sourceUrl)||
      !isDate(item.provenance.checkedOn)||!['official','third-party','manual'].includes(item.provenance.kind)||
      !['unknown','permission-required','licensed','original'].includes(item.provenance.reuse))
     error(path+'.provenance','origine, date et statut de réutilisation obligatoires');
   if(kind==='competitions'&&(!Number.isInteger(item.teamCount)||item.teamCount<2||!isText(item.country)))error(path,'format compétition invalide');
   if(kind==='clubs'&&!isText(item.competitionId))error(path+'.competitionId','référence compétition requise');
   if(kind==='players'||kind==='academy'){
    if(!isText(item.clubId))error(path+'.clubId','référence club requise');
    if(item.birthDate!==null&&!isDate(item.birthDate))error(path+'.birthDate','date connue ou null');
    if(!Array.isArray(item.positions)||!item.positions.length||item.positions.some(x=>!POSITIONS.has(x)))error(path+'.positions','postes normalisés requis');
    if(kind==='academy'&&item.birthDate===null)error(path+'.birthDate','date nécessaire pour qualifier un jeune');
   }
   if(kind==='staff'&&(!isText(item.clubId)||!ROLES.has(item.role)))error(path,'club et rôle requis');
   if(kind!=='competitions'&&item.rating!==undefined)error(path+'.rating','attributs fictifs interdits dans les faits');
   if(item.salary!==undefined||item.budget!==undefined)error(path,'finances non vérifiées interdites');
  });
 }
 const comp=new Map((data.competitions||[]).map(x=>[x.id,x]));
 const clubs=new Map((data.clubs||[]).map(x=>[x.id,x]));
 for(const [i,c] of (data.clubs||[]).entries())if(!comp.has(c.competitionId))error('clubs['+i+'].competitionId','compétition inconnue');
 for(const kind of ['players','academy','staff'])for(const [i,p] of (data[kind]||[]).entries())
  if(!clubs.has(p.clubId))error(kind+'['+i+'].clubId','club inconnu');
 for(const [id,c] of comp){
  const n=(data.clubs||[]).filter(x=>x.competitionId===id).length;
  if(n>c.teamCount||complete&&n!==c.teamCount)error(id,'nombre de clubs '+n+'/'+c.teamCount);
 }
 return {valid:errors.length===0,errors,counts:Object.fromEntries(entities.map(k=>[k,(data[k]||[]).length]))};
}
function importCatalog(raw,options={}){
 const parsed=typeof raw==='string'?JSON.parse(raw):raw;
 const result=validateCatalog(parsed,options);
 if(!result.valid)throw new Error(result.errors.join('\n'));
 return JSON.parse(JSON.stringify(parsed));
}
function mergeCatalog(base,increment){
 const next=JSON.parse(JSON.stringify(base));
 for(const kind of ['competitions','clubs','players','staff','academy']){
  const ids=new Set(next[kind].map(x=>x.id));
  for(const item of increment[kind]||[]){
   if(ids.has(item.id))throw new Error('Identifiant déjà utilisé : '+item.id);
   ids.add(item.id);next[kind].push(item);
  }
 }
 return importCatalog(next);
}
module.exports={validateCatalog,importCatalog,mergeCatalog,POSITIONS,ROLES};
