'use strict';

const id='rugby-world-2026-11-09-pacific-v2',version=2;

function extendWorldRegistry(base,extension){
 if(extension===null||extension===undefined)return null;
 const check=(yes,label)=>{if(!yes)throw Error('Extension Pacifique invalide : '+label+'.');};
 check(extension.id===id&&extension.version===version&&extension.marker?.id===id&&extension.marker?.version===version&&extension.baseId===base.id,'édition');
 check(typeof extension.snapshot==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(extension.snapshot),'date du registre');
 check(Array.isArray(extension.clubs)&&extension.clubs.length===10&&Array.isArray(extension.moves)&&extension.worldProfiles&&typeof extension.worldProfiles==='object'&&!Array.isArray(extension.worldProfiles),'clubs, transferts ou profils');
 const clubs=base.clubs.map(c=>({...c,players:c.players.slice()})),playerClub=new Map();
 for(const c of clubs)for(const p of c.players){check(!playerClub.has(p.id),'identifiant ancien dupliqué');playerClub.set(p.id,c.id);}
 const newIds=new Set();
 const keys=new Set(clubs.map(c=>c.key));
 const object=value=>value!==null&&typeof value==='object'&&!Array.isArray(value);
 for(const [i,source] of extension.clubs.entries()){
  check(object(source)&&source.id===58+i&&source.leagueId==='srp'&&typeof source.key==='string'&&source.key.startsWith('srp:')&&!keys.has(source.key)&&Array.isArray(source.players),'franchise');
  keys.add(source.key);
  for(const p of source.players){
   check(typeof p?.id==='string'&&p.id.startsWith('world:')&&p.worldRatingsVersion===1&&!playerClub.has(p.id)&&!newIds.has(p.id)&&object(extension.worldProfiles[p.id]),'profil Pacifique dupliqué ou incomplet');
   newIds.add(p.id);
  }
  clubs.push({...source,players:source.players.slice()});
 }
 check(Object.keys(extension.worldProfiles).length===newIds.size&&Object.keys(extension.worldProfiles).every(key=>newIds.has(key)),'profils sans joueur');
 const moves=new Set();
 for(const item of extension.moves){
  check(Array.isArray(item)&&item.length===3,'transfert mal formé');
  const [pid,from,to]=item;
  check(typeof pid==='string'&&playerClub.get(pid)===from&&!moves.has(pid)&&Number.isInteger(to)&&to>=58&&to<68,'transfert non unique ou club inconnu');
  const i=clubs[from].players.findIndex(p=>p.id===pid);
  check(i>=0,'joueur à transférer absent');
  clubs[to].players.push(clubs[from].players.splice(i,1)[0]);
  moves.add(pid);
 }
 return {
  ...base,id,version,marker:{id,version},snapshot:extension.snapshot,clubCount:clubs.length,playerCount:playerClub.size+newIds.size,
  clubs,leagues:[...base.leagues,{id:'srp',name:'Super Rugby Pacific',country:'NZ/AU/FJ'}],
  worldProfiles:{...base.worldProfiles,...extension.worldProfiles},
  provenance:{...base.provenance,pacificExtension:extension.provenance??null},
 };
}
module.exports={extendWorldRegistry};
