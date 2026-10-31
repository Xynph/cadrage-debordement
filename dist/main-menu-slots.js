'use strict';
// Local career library. Legacy bdt-v1 stays the canonical active save.
const CDMenuSlots=(()=>{
 const INDEX='cd-career-slots-v2',PREFIX='cd-career-slot-v2:',MAX=5;
 const idOk=id=>typeof id==='string'&&/^s-[0-9a-z-]{6,42}$/.test(id);
 const hash=s=>{let n=2166136261;for(let i=0;i<s.length;i++){n^=s.charCodeAt(i);n=Math.imul(n,16777619)}return (n>>>0).toString(16)};
 const storage=()=>gameStorage;
 function index(){
  const raw=storage().getItem(INDEX);
  if(!raw)return {version:2,active:null,items:[]};
  const d=JSON.parse(raw);
  if(!d||d.version!==2||!Array.isArray(d.items)||d.items.length>MAX||d.items.some(x=>!idOk(x.id)||typeof x.name!=='string'||x.name.length>56||typeof x.updatedAt!=='string'||!Number.isFinite(Date.parse(x.updatedAt)))||new Set(d.items.map(x=>x.id)).size!==d.items.length||d.active!==null&&!d.items.some(x=>x.id===d.active))throw Error('Bibliothèque de carrières endommagée : aucune modification effectuée.');
  return d;
 }
 function writeIndex(d){storage().setItem(INDEX,JSON.stringify(d))}
 const label=v=>String(v||'Ma carrière').trim().slice(0,56)||'Ma carrière';
 function envelope(state){
  const s=JSON.stringify(state);
  if(s.length>5*1024*1024)throw Error('Carrière trop volumineuse pour cet emplacement.');
  return JSON.stringify({version:2,checksum:hash(s),state:JSON.parse(s)});
 }
 function list(){return index()}
 function create(name,state){
  const d=index();if(d.items.length>=MAX)throw Error('Limite de cinq carrières atteinte.');
  let id;do{id='s-'+Date.now().toString(36)+'-'+Math.floor(Math.random()*0xFFFFFF).toString(36).padStart(6,'0')}while(d.items.some(x=>x.id===id));
  const saved=envelope(state);
  storage().setItem(PREFIX+id,saved);
  d.items.push({id,name:label(name),updatedAt:new Date().toISOString()});d.active=id;
  try{writeIndex(d)}catch(e){try{storage().removeItem(PREFIX+id)}catch(_){}throw e}
  return id;
 }
 function restore(id){
  const d=index();if(!idOk(id)||!d.items.some(x=>x.id===id))throw Error('Emplacement introuvable.');
  const raw=storage().getItem(PREFIX+id);if(!raw)throw Error('Fichier de carrière manquant.');
  const doc=JSON.parse(raw);
  if(!doc||doc.version!==2||!doc.state||hash(JSON.stringify(doc.state))!==doc.checksum)throw Error('Carrière endommagée : restauration refusée.');
  return JSON.parse(JSON.stringify(doc.state));
 }
 function setActive(id){const d=index();if(id!==null&&!d.items.some(x=>x.id===id))throw Error('Emplacement introuvable.');d.active=id;writeIndex(d)}
 function update(state){const d=index();if(!d.active)return;const slot=d.items.find(x=>x.id===d.active);if(!slot)return;storage().setItem(PREFIX+slot.id,envelope(state));slot.updatedAt=new Date().toISOString();writeIndex(d)}
 function remove(id){const d=index();const j=d.items.findIndex(x=>x.id===id);if(j<0)throw Error('Emplacement introuvable.');d.items.splice(j,1);if(d.active===id)d.active=null;writeIndex(d);storage().removeItem(PREFIX+id)}
 return {list,create,restore,setActive,update,remove,max:MAX};
})();
