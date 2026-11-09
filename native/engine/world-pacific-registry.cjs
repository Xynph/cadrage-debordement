'use strict';

const PACIFIC=Object.freeze({
 id:'rugby-world-2026-11-09-pacific-v2',version:2,baseId:'rugby-world-2026-11-08-v1',baseCount:58,count:10,
 label:'Pacifique',prefix:'srp:',group:()=> 'srp',provenance:'pacificExtension',
 leagues:[{id:'srp',name:'Super Rugby Pacific',country:'NZ/AU/FJ'}],
});
const JAPAN=Object.freeze({
 id:'rugby-world-2026-11-09-japan-v3',version:3,baseId:PACIFIC.id,baseCount:68,count:20,
 label:'Japon',prefix:'jlo:',group:i=>i<12?'jlo-d1':'jlo-d2',provenance:'japanExtension',
 leagues:[{id:'jlo-d1',name:'Japan Rugby League One · Division 1',country:'JP'},{id:'jlo-d2',name:'Japan Rugby League One · Division 2',country:'JP'}],
});

const NATIONALE=Object.freeze({
 id:'rugby-world-2026-11-09-nationale-v4',version:4,baseId:JAPAN.id,baseCount:88,count:14,
 label:'Nationale',prefix:'nat:slot-',group:()=> 'nationale',provenance:'nationaleExtension',
 leagues:[{id:'nationale',name:'Nationale',country:'FR'}],
});

const CHAMP=Object.freeze({
 id:'rugby-world-2026-11-09-champ-v5',version:5,baseId:NATIONALE.id,baseCount:102,count:14,
 label:'Champ Rugby',prefix:'champ:slot-',group:()=> 'champ',provenance:'champExtension',
 leagues:[{id:'champ',name:'Champ Rugby',country:'ENG'}],
});

function compose(base,extension,variant){
 if(extension===null||extension===undefined)return null;
 const {id,version,baseId,baseCount,count,prefix,group}=variant;
 const check=(yes,label)=>{if(!yes)throw Error('Extension '+variant.label+' invalide : '+label+'.');};
 check(base?.id===baseId&&base.clubCount===baseCount&&base.clubs.length===baseCount,'édition de départ');
 check(extension.id===id&&extension.version===version&&extension.marker?.id===id&&extension.marker?.version===version&&extension.baseId===base.id,'édition');
 check(typeof extension.snapshot==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(extension.snapshot),'date du registre');
 check(Array.isArray(extension.clubs)&&extension.clubs.length===count&&Array.isArray(extension.moves)&&extension.worldProfiles&&typeof extension.worldProfiles==='object'&&!Array.isArray(extension.worldProfiles),'clubs, transferts ou profils');
 const clubs=base.clubs.map(c=>({...c,players:c.players.slice()})),playerClub=new Map();
 for(const c of clubs)for(const p of c.players){check(!playerClub.has(p.id),'identifiant ancien dupliqué');playerClub.set(p.id,c.id);}
 const newIds=new Set();
 const keys=new Set(clubs.map(c=>c.key));
 const object=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
 for(const [i,source] of extension.clubs.entries()){
  check(object(source)&&source.id===baseCount+i&&source.leagueId===group(i)&&typeof source.key==='string'&&source.key.startsWith(prefix)&&!keys.has(source.key)&&Array.isArray(source.players),'franchise');
  keys.add(source.key);
  for(const p of source.players){
   check(typeof p?.id==='string'&&p.id.startsWith('world:')&&p.worldRatingsVersion===1&&!playerClub.has(p.id)&&!newIds.has(p.id)&&object(extension.worldProfiles[p.id]),'profil '+variant.label+' dupliqué ou incomplet');
   newIds.add(p.id);
  }
  clubs.push({...source,players:source.players.slice()});
 }
 check(Object.keys(extension.worldProfiles).length===newIds.size&&Object.keys(extension.worldProfiles).every(key=>newIds.has(key)),'profils sans joueur');
 const moves=new Set();
 for(const item of extension.moves){
  check(Array.isArray(item)&&item.length===3,'transfert mal formé');
  const [pid,from,to]=item;
  check(typeof pid==='string'&&playerClub.get(pid)===from&&!moves.has(pid)&&Number.isInteger(to)&&to>=baseCount&&to<baseCount+count,'transfert non unique ou club inconnu');
  const i=clubs[from].players.findIndex(p=>p.id===pid);
  check(i>=0,'joueur à transférer absent');
  clubs[to].players.push(clubs[from].players.splice(i,1)[0]);
  moves.add(pid);
 }
 if(version===4&&extension.nationaleQualifications!==undefined){
  const position=extension.nationaleQualifications,expected=new Set([...newIds,...moves]);
  const roles=['Pilier gauche','Talonneur','Pilier droit','Deuxième ligne','Troisième ligne','Numéro 8','Demi de mêlée','Demi d’ouverture','Centre','Ailier','Arrière'];
  check(object(position)&&Object.entries(position).every(([pid,item])=>expected.has(pid)&&object(item)&&Object.keys(item).length===2&&
   Array.isArray(item.roles)&&item.roles.length>=1&&new Set(item.roles).size===item.roles.length&&item.roles.every(x=>roles.includes(x))&&
   Array.isArray(item.sources)&&item.sources.length>=1&&item.sources.every(x=>/^nat-source-[0-9a-f]{16}$/.test(x))),'qualifications de la Nationale');
 }
 if(version===3&&extension.japanCategories!==undefined){
  const categories=extension.japanCategories,expected=new Set([...newIds,...moves]);
  check(object(categories)&&Object.keys(categories).length===expected.size&&Object.entries(categories).every(([pid,item])=>expected.has(pid)&&object(item)&&Object.keys(item).length===3&&['A-1','A-2','B','C'].includes(item.category)&&['official-2026-27','derived-official-criteria','estimated'].includes(item.basis)&&typeof item.reason==='string'&&/^[a-z0-9-]{1,80}$/.test(item.reason)),'qualifications japonaises');
 }
 return {
  ...base,id,version,marker:{id,version},snapshot:extension.snapshot,clubCount:clubs.length,playerCount:playerClub.size+newIds.size,
  clubs,leagues:[...base.leagues,...variant.leagues],
  worldProfiles:{...base.worldProfiles,...extension.worldProfiles},
  ...(version===3&&extension.japanCategories?{japanCategories:extension.japanCategories}:{}),
  ...(version===4&&extension.nationaleQualifications?{nationaleQualifications:extension.nationaleQualifications}:{}),
  provenance:{...base.provenance,[variant.provenance]:extension.provenance??null},
 };
}
const extendWorldRegistry=(base,extension)=>compose(base,extension,PACIFIC);
const extendJapanRegistry=(pacific,extension)=>compose(pacific,extension,JAPAN);
const extendNationaleRegistry=(japan,extension)=>compose(japan,extension,NATIONALE);
const extendChampRegistry=(nationale,extension)=>compose(nationale,extension,CHAMP);
module.exports={extendWorldRegistry,extendJapanRegistry,extendNationaleRegistry,extendChampRegistry};
