/* UI-02A: native, read-only data projections; no auto-load in the game. */
(function(root,build){
 'use strict';
 const api=build();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDUI02Data=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 'use strict';
 const LABELS=Object.freeze({name:'Joueur',position:'Poste',age:'Âge',note:'Note au poste',condition:'Condition',potential:'Potentiel',salary:'Salaire / semaine',contract:'Fin de contrat',minutes:'Minutes',physical:'Charge physique',status:'Statut',injury:'Blessure',development:'Développement'});
 const PRESETS=Object.freeze({
  overview:Object.freeze(['name','position','age','note','condition','potential','status']),
  contracts:Object.freeze(['name','position','age','salary','contract','status']),
  fitness:Object.freeze(['name','position','condition','physical','injury','minutes']),
  development:Object.freeze(['name','position','age','note','potential','minutes','development'])
 });
 const KEYS=Object.keys(LABELS);
 function assertDeps(d){
  if(!d||!['roleNote','potentialAtRole','skill','physicalLoadValue'].every(k=>typeof d[k]==='function')||!d.attributes||typeof d.attributes!=='object')
   throw new TypeError('Calculs natifs des joueurs requis');
 }
 function n(x){return typeof x==='number'&&Number.isFinite(x)?x:null}
 function normalize(x){return String(x??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('fr')}
 function status(p,ctx){return p.injury>0?'Blessé':(ctx.lineup||[]).includes(p.id)?'Titulaire':(ctx.reserves||[]).includes(p.id)?'Banc':'Hors groupe'}
 function chooseColumns(cols,preset){
  const values=cols===undefined?(PRESETS[preset]||PRESETS.overview):cols;
  if(!Array.isArray(values)||!values.length)throw new TypeError('Liste de colonnes requise');
  const unique=[];
  for(const key of values){if(!KEYS.includes(key))throw new RangeError('Colonne inconnue : '+String(key));if(!unique.includes(key))unique.push(key)}
  return unique;
 }
 function playerView(p,deps,ctx={}){
  assertDeps(deps);
  if(!p||typeof p.id!=='string'||!p.id)throw new TypeError('Joueur natif invalide');
  // Official read helpers can initialize skills/development. Never call on original.
  const copy=JSON.parse(JSON.stringify(p));
  const attributes={};
  for(const [key,label] of Object.entries(deps.attributes)){
   if(typeof key==='string'&&typeof label==='string')attributes[key]={label,value:n(Math.round(deps.skill(copy,key)))};
  }
  const note=n(deps.roleNote(copy)),potential=n(deps.potentialAtRole(copy));
  const history=Array.isArray(copy.dev?.history)?copy.dev.history.map(h=>({
   season:n(h.season),age:n(h.age),start:n(h.start),end:n(h.end),
   minutes:n(h.minutes),appearances:n(h.appearances)
  })):[];
  return {id:p.id,name:typeof copy.name==='string'?copy.name:'',position:typeof copy.pos==='string'?copy.pos:'',
   family:n(copy.fam),age:n(copy.age),note,condition:n(copy.condition),potential,
   salary:n(copy.salary),contract:n(copy.contractEnd),minutes:n(copy.dev?.minutes),
   physical:n(deps.physicalLoadValue(copy)),status:status(copy,ctx),injury:n(copy.injury),
   development:copy.dev?.specialization?.focus||'equilibre',attributes,history};
 }
 function compareValue(a,b){
  if(a==null)return b==null?0:1;if(b==null)return -1;
  return typeof a==='number'&&typeof b==='number'?a-b:String(a).localeCompare(String(b),'fr',{sensitivity:'base',numeric:true});
 }
 function tableView(players,deps,ctx={},opt={}){
  if(!Array.isArray(players))throw new TypeError('Liste de joueurs requise');
  const columns=chooseColumns(opt.columns,opt.preset||'overview');
  const sortBy=opt.sortBy||'name',direction=opt.direction||'asc';
  if(!KEYS.includes(sortBy))throw new RangeError('Tri inconnu');
  if(!['asc','desc'].includes(direction))throw new RangeError('Sens de tri inconnu');
  let rows=players.map(p=>playerView(p,deps,ctx));
  const search=normalize(opt.search).trim();
  if(search)rows=rows.filter(r=>normalize(r.name+' '+r.position).includes(search));
  if(opt.family!==undefined&&opt.family!==null){
   const family=Number(opt.family);
   if(!Number.isInteger(family)||family<0||family>8)throw new RangeError('Famille invalide');
   rows=rows.filter(r=>r.family===family);
  }
  if(opt.status)rows=rows.filter(r=>r.status===opt.status);
  if(opt.onlyInjured)rows=rows.filter(r=>r.injury>0);
  if(opt.expiring&&Number.isInteger(ctx.season))rows=rows.filter(r=>r.contract!==null&&r.contract<=ctx.season);
  rows=rows.map((r,i)=>({r,i})).sort((a,b)=>{
   const c=compareValue(a.r[sortBy],b.r[sortBy]);
   return c?(direction==='desc'?-c:c):a.i-b.i;
  }).map(x=>x.r);
  const total=rows.length;
  if(opt.limit!==undefined){
   if(!Number.isInteger(opt.limit)||opt.limit<0||opt.limit>10000)throw new RangeError('Limite invalide');
   rows=rows.slice(0,opt.limit);
  }
  return {columns:columns.map(key=>({key,label:LABELS[key]})),total,sortBy,direction,
   rows:rows.map(r=>({id:r.id,cells:Object.fromEntries(columns.map(key=>[key,r[key]??null]))}))};
 }
 function comparePlayers(players,deps,ctx={}){
  if(!Array.isArray(players)||players.length!==2||!players[0]||!players[1]||players[0].id===players[1].id)throw new RangeError('Deux joueurs différents requis');
  const a=players.map(p=>playerView(p,deps,ctx));
  const keys=['note','condition','potential','salary','physical','minutes'];
  return {players:a.map(p=>({id:p.id,name:p.name,position:p.position})),
   sameFamily:a[0].family===a[1].family,
   rows:[...keys.map(key=>({key,label:LABELS[key],values:a.map(p=>p[key])})),
    ...Object.entries(deps.attributes).map(([key,label])=>({key,label,values:a.map(p=>p.attributes[key]?.value??null)}))]};
 }
 return Object.freeze({LABELS,PRESETS,chooseColumns,playerView,tableView,comparePlayers});
});
