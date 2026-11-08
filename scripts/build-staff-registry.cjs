'use strict';
// Build-time facts stay here; only pseudonyms and dated role references ship.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const fold=s=>s.normalize('NFKC').toLocaleLowerCase('fr');
function build(source=JSON.parse(fs.readFileSync(path.join(root,'data/staff/verified.json'),'utf8'))){
 if(source.schema!=='oval-staff-references-v1'||source.version!==1||!Array.isArray(source.people))throw Error('Registre staff source invalide.');
 const real=new Set(source.people.map(p=>fold(p.name))),used=new Set(),ids=new Set();
 const clubs=Array.from({length:30},(_,id)=>({id,members:[]}));
 const endings={a:'e',b:'p',c:'s',d:'t',e:'a',f:'v',g:'k',h:'n',i:'o',j:'g',k:'c',l:'n',m:'n',n:'m',o:'u',p:'b',q:'k',r:'l',s:'z',t:'d',u:'a',v:'f',w:'v',x:'s',y:'i',z:'s'};
 for(const p of source.people){
  if(!p.importEligible)continue;
  if(!Number.isInteger(p.clubId)||p.clubId<0||p.clubId>29||typeof p.id!=='string'||!new RegExp('^staff:'+p.clubId+':[a-f0-9]{16}$').test(p.id)||ids.has(p.id)||typeof p.name!=='string'||!p.name.trim()||p.name.length>120||typeof p.role!=='string'||!p.role.trim()||p.role.length>160||typeof p.observedAt!=='string'||!/^\d{4}-\d{2}-\d{2}T/.test(p.observedAt)||!(p.sourceSeason===null||typeof p.sourceSeason==='string'&&p.sourceSeason.length<=60))throw Error('Personne staff invalide : '+p.id);
  ids.add(p.id);
  let name=p.name.normalize('NFKC').replace(/[\p{L}]+/gu,word=>word.replace(/\p{L}$/u,c=>{const n=endings[c.toLowerCase()]||'a';return c===c.toUpperCase()?n.toUpperCase():n;}));
  if(real.has(fold(name))||used.has(fold(name)))name+=' '+p.id.slice(-4);
  while(real.has(fold(name))||used.has(fold(name)))name+='x';used.add(fold(name));
  // No source URL, real name, portrait link, or private filesystem path here.
  clubs[p.clubId].members.push({id:p.id,clubId:p.clubId,name,role:p.role,sourceSeason:p.sourceSeason,sourceDate:p.sourceDate||null,historical:p.historical===true,observedAt:p.observedAt.slice(0,10),portraitStatus:'anonymous'});
 }
 for(const c of clubs)c.members.sort((a,b)=>a.id.localeCompare(b.id));
 return {schema:'oval-anonymous-staff-v1',version:1,observedAt:source.observedAt,clubs};
}
module.exports={build};
if(require.main===module){
 const file=path.join(root,'native/engine/staff-registry.json'),text=JSON.stringify(build(),null,2)+'\n';
 if(process.argv.includes('--check')){if(fs.readFileSync(file,'utf8').replace(/\r\n/g,'\n')!==text)throw Error('Staff anonymisé périmé.');}
 else fs.writeFileSync(file,text);
 console.log('Staff : registre anonymisé compilé sans identités ou photos réelles.');
}
