'use strict';
// Build-time facts stay here; only base names from data/names and dated role references ship.
// The source (data/staff/verified.json) lives in the private data repository: see scripts/sources-privees.cjs.
const fs=require('node:fs'),path=require('node:path'),privees=require('./sources-privees.cjs');
const root=path.resolve(__dirname,'..'),SOURCE='data/staff/verified.json',TARGET='native/engine/staff-registry.json';
const fold=s=>s.normalize('NFKC').toLocaleLowerCase('fr');
function readSource(){const file=privees.locate(SOURCE);if(!file)throw privees.missingError(TARGET);return JSON.parse(fs.readFileSync(file,'utf8'));}
function build(source=readSource()){
 if(source.schema!=='oval-staff-references-v1'||source.version!==1||!Array.isArray(source.people))throw Error('Registre staff source invalide.');
 const real=new Set(source.people.map(p=>fold(p.name))),used=new Set(),ids=new Set();
 const clubs=Array.from({length:30},(_,id)=>({id,members:[]}));
 const baseNames=require('./base-names.cjs'),names=baseNames.frenchStaff();
 for(const p of source.people){
  if(!p.importEligible)continue;
  if(!Number.isInteger(p.clubId)||p.clubId<0||p.clubId>29||typeof p.id!=='string'||!new RegExp('^staff:'+p.clubId+':[a-f0-9]{16}$').test(p.id)||ids.has(p.id)||typeof p.name!=='string'||!p.name.trim()||p.name.length>120||typeof p.role!=='string'||!p.role.trim()||p.role.length>160||typeof p.observedAt!=='string'||!/^\d{4}-\d{2}-\d{2}T/.test(p.observedAt)||!(p.sourceSeason===null||typeof p.sourceSeason==='string'&&p.sourceSeason.length<=60))throw Error('Personne staff invalide : '+p.id);
  ids.add(p.id);
  // The display name is read by identifier and never derived from the source identity.
  const name=baseNames.nameOf(names,p.id);
  if(real.has(fold(name))||used.has(fold(name)))throw Error('Nom de base refusé : '+p.id);
  used.add(fold(name));
  // No source URL, real name, portrait link, or private filesystem path here.
  clubs[p.clubId].members.push({id:p.id,clubId:p.clubId,name,role:p.role,sourceSeason:p.sourceSeason,sourceDate:p.sourceDate||null,historical:p.historical===true,observedAt:p.observedAt.slice(0,10),portraitStatus:'anonymous'});
 }
 for(const c of clubs)c.members.sort((a,b)=>a.id.localeCompare(b.id));
 return {schema:'oval-anonymous-staff-v1',version:1,observedAt:source.observedAt,clubs};
}
// Without the private source: the published registry must be the one whose fingerprint is published,
// and every member must still carry the name of its identifier in data/names.
function verifyPublished(){
 privees.verifyCompiled(TARGET);
 const names=require('./base-names.cjs').frenchStaff(),registry=JSON.parse(fs.readFileSync(path.join(root,TARGET),'utf8'));
 if(registry.schema!=='oval-anonymous-staff-v1'||registry.clubs.length!==30)throw Error('Registre staff publié invalide.');
 for(const p of registry.clubs.flatMap(c=>c.members))if(p.name!==require('./base-names.cjs').nameOf(names,p.id))throw Error('Nom de base périmé dans le registre staff publié : '+p.id+'. Relancer la compilation avec les sources privées.');
 return registry;
}
function run(check){
 const file=path.join(root,TARGET),sourceFile=privees.locate(SOURCE);
 if(!sourceFile){
  if(!check)throw privees.missingError(TARGET);
  verifyPublished();console.warn(privees.absentMessage(TARGET));return 'verified';
 }
 const text=JSON.stringify(build(JSON.parse(fs.readFileSync(sourceFile,'utf8'))),null,2)+'\n';
 if(check){if(fs.readFileSync(file,'utf8').replace(/\r\n/g,'\n')!==text)throw Error('Staff anonymisé périmé.');}
 else fs.writeFileSync(file,text);
 privees.recordCompiled(TARGET,{[SOURCE]:sourceFile,'data/names/noms-staffs-v1.json':path.join(root,'data/names/noms-staffs-v1.json')},check);
 return 'compiled';
}
module.exports={build,run,verifyPublished,SOURCE,TARGET};
if(require.main===module){
 const outcome=run(process.argv.includes('--check'));
 console.log(outcome==='compiled'?'Staff : registre anonymisé compilé sans identités ou photos réelles.':'Staff : registre anonymisé publié vérifié par empreinte.');
}
