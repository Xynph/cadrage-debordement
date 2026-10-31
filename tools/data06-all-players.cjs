'use strict';
const fs=require('node:fs'),path=require('node:path');
const ROOT=path.resolve(__dirname,'..');
const srcRoster=['top14-a','top14-b','prod2-a','prod2-b'];
const imports=[['data05-bulk','profiles'],['data05-bulk2','players'],['data05-bulk3','players']];
function decodeName(s){
 if(typeof s!=='string'||!s.trim())throw Error('Invalid player name');
 return s.replace(/&(#(?:x[0-9a-f]+|[0-9]+)|amp|quot|apos|lt|gt|nbsp);/gi,(match,entity)=>{
  if(entity[0]==='#'){
   const hex=entity[1]?.toLowerCase()==='x',n=Number.parseInt(entity.slice(hex?2:1),hex?16:10);
   return n>0&&n<=0x10ffff&&!(n>=0xd800&&n<=0xdfff)?String.fromCodePoint(n):match;
  }
  return {amp:'&',quot:'"',apos:"'",lt:'<',gt:'>',nbsp:' '}[entity.toLowerCase()]||match;
 }).normalize('NFC');
}
function comparableName(s){return decodeName(s).normalize('NFKC').trim().replace(/\s+/g,' ').toLocaleLowerCase('fr')}
function validateProfileName(rosterName,sourceName,id){
 if(comparableName(rosterName)!==comparableName(sourceName))throw Error('Individual name mismatch for '+id);
}
function build(root=ROOT){
 const clubs=srcRoster.flatMap(s=>JSON.parse(fs.readFileSync(path.join(root,'modding/data03',s+'.json'),'utf8')).clubs);
 const list=clubs.flatMap(c=>c.players.map(p=>({id:p.id,name:decodeName(p.name),club:c.club,league:c.league,url:p.url})));
 if(clubs.length!==30||list.length!==1592||new Set(list.map(p=>p.id)).size!==1592)throw Error('Invalid 30-club/1592-player reference roster');
 const known=new Map(list.map(p=>[p.id,p])),enriched=new Map();
 const seenNames=new Map();
 for(const [dir,key] of imports)for(let i=1;i<=5;i++){
  const file=path.join(root,'modding',dir,'profiles-'+String(i).padStart(2,'0')+'.json');
  const data=JSON.parse(fs.readFileSync(file,'utf8'))[key];
  if(!Array.isArray(data))throw Error('Invalid source '+file);
  for(const raw of data){
   const id=raw.id,ref=known.get(id);
   if(!ref||ref.club!==raw.club||(raw.url||raw.sourceUrl)!==ref.url||enriched.has(id))throw Error('Invalid/duplicate identity '+id);
   validateProfileName(ref.name,raw.returnedName||raw.name,id);
   enriched.set(id,raw);
  }
 }
 if(enriched.size!==240)throw Error('Expected 240 individually sourced profiles, got '+enriched.size);
 const players=list.map(p=>{
  const a=enriched.get(p.id);
  const h=a?.heightCm??(typeof a?.height==='string'&&/^[12]m\d{2}$/.test(a.height)?Number(a.height.replace('m','')):null);
  const player={...p,position:a?.positionGroup||a?.position||null,nationality:a?.nationality||null,ageReported:a?.ageReported??a?.age??null,heightCm:h??null,weightKg:a?.weightKg??null,birthDate:null,jiff:null,contractEnd:null,salary:null,clubBudget:null,actualPerformance:null,gameRatingEstimate:null,sourceType:a?'lnr-individual-snapshot':'lnr-official-roster',profileEnriched:Boolean(a),historicalAsOfJuly1Verified:false};
  const nm=p.club+'|'+p.name.normalize('NFKD').toLowerCase();
  seenNames.set(nm,(seenNames.get(nm)||0)+1);
  return player;
 });
 const conflictNames=[...seenNames].filter(([,n])=>n>1).map(([name,count])=>({name,count}));
 return {schema:'data06-all-players-v1',season:'2026-2027',snapshot:'2026-10-31',historicalAsOfJuly1Verified:false,summary:{clubs:clubs.length,players:players.length,individualProfiles:enriched.size,rosterOnly:players.length-enriched.size,nameConflicts:conflictNames},players};
}
function write(root=ROOT,out=path.join(root,'modding/data06/all-players-2026-2027.json')){
 const data=build(root);fs.mkdirSync(path.dirname(out),{recursive:true});fs.writeFileSync(out,JSON.stringify(data,null,2)+'\n');return data.summary;
}
if(require.main===module)console.log(JSON.stringify(write(),null,2));
module.exports={build,write,decodeName,validateProfileName};
