/* UI-04A — lecture seule du centre de formation réel, sans simulation. */
(function(root,build){
 'use strict';
 const api=build();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDUI04AcademyData=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 'use strict';
 const SORTS=Object.freeze(['name','age','position','note','potential','gain','minutes','focus']);
 const VIEWS=Object.freeze(['overview','academy','young','history']);
 function num(value){return typeof value==='number'&&Number.isFinite(value)?value:null}
 function txt(value){return typeof value==='string'?value:''}
 function integer(value){return Number.isInteger(value)?value:null}
 function normalize(value){return String(value??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('fr')}
 function clone(value){return JSON.parse(JSON.stringify(value))}
 function safeHistory(list){
  return Array.isArray(list)?list.map(h=>({
   season:integer(h.season),age:integer(h.age),start:num(h.start),end:num(h.end),
   minutes:num(h.minutes),appearances:integer(h.appearances)
  })):[];
 }
 function requireDeps(deps){
  for(const k of ['roleNote','potentialAtRole','developmentBadge','developmentFocusOptions',
   'developmentFocusValue','retirementSeason'])
   if(typeof deps?.[k]!=='function')throw new TypeError('Fonctions natives de formation requises : '+k);
 }
 function playerView(p,kind,deps,context){
  if(!p||typeof p.id!=='string'||!p.id||!['academy','professional'].includes(kind))
   throw new TypeError('Joueur ou origine invalide');
  // Les fonctions du moteur peuvent initialiser skills et dev : jamais sur le document de carrière.
  const q=clone(p);
  const note=num(deps.roleNote(q));
  const potential=num(deps.potentialAtRole(q));
  const badge=txt(deps.developmentBadge(q));
  const choices=deps.developmentFocusOptions(q);
  if(!Array.isArray(choices))throw new TypeError('Objectifs individuels natifs requis');
  const focus=deps.developmentFocusValue(q);
  const choiceList=[...new Set(choices.filter(v=>typeof v==='string'))];
  const dev=q.dev||{};
  const history=safeHistory(dev.history);
  const focusBonus=dev.specialization?.bonuses&&typeof dev.specialization.bonuses==='object'?
   Object.fromEntries(Object.entries(dev.specialization.bonuses).filter(([k,v])=>typeof k==='string'&&num(v)!==null)):{};
  return {
   id:q.id,name:txt(q.name),position:txt(q.pos),family:integer(q.fam),kind,
   age:integer(q.age),note,potential,general:num(q.rating),
   gain:num(q.rating)!==null&&num(dev.seasonStart)!==null?q.rating-dev.seasonStart:null,
   minutes:num(dev.minutes),appearances:integer(dev.appearances),careerMinutes:num(dev.careerMinutes),
   focus:choiceList.includes(focus)?focus:choiceList[0]||null,
   focusOptions:choiceList,focusBonus,focusXp:num(dev.specialization?.xp),
   history,badge,retirementSeason:integer(deps.retirementSeason(q)),
   contractEnd:kind==='professional'?integer(q.contractEnd):null,
   salary:kind==='professional'?num(q.salary):null,
   condition:num(q.condition),injury:num(q.injury),
   canPromote:kind==='academy'&&!context.locked&&context.professionalCount<42,
   promotionBlockedReason:kind!=='academy'?null:
    context.locked?'Actions indisponibles pendant le match ou la clôture de saison':
    context.professionalCount>=42?'Effectif professionnel complet (42 joueurs)':null
  };
 }
 function buildCenter(source,deps){
  if(!source||!Array.isArray(source.academy)||!Array.isArray(source.professionals)||
   !Array.isArray(source.retired)||!Number.isInteger(source.season)||source.season<1||
   typeof source.clubName!=='string')throw new TypeError('État natif de la formation requis');
  requireDeps(deps);
  const ctx={locked:!!source.locked,professionalCount:source.professionals.length};
  const academy=source.academy.map(p=>playerView(p,'academy',deps,ctx));
  const young=source.professionals.filter(p=>p.age<=23).map(p=>playerView(p,'professional',deps,ctx));
  const retirementRisk=source.professionals.map(p=>{
   const q=clone(p);return deps.retirementSeason(q)<=source.season+1;
  }).filter(Boolean).length;
  const groupGain=source.professionals.reduce((sum,p)=>
   sum+Math.max(0,num(p.rating)!==null&&num(p.dev?.seasonStart)!==null?p.rating-p.dev.seasonStart:0),0);
  const retired=source.retired.filter(p=>p.club===source.clubName).map(r=>({
   id:txt(r.id),name:txt(r.name),age:integer(r.age),season:integer(r.season),
   careerMinutes:num(r.minutes)
  }));
  return {version:1,season:source.season,clubName:source.clubName,locked:ctx.locked,
   academy,young,retired,
   totals:{academy:academy.length,young:young.length,youngMinutes:young.reduce((s,p)=>s+(p.minutes||0),0),
    professionalCount:ctx.professionalCount,promotionSlots:Math.max(0,42-ctx.professionalCount),
    retirementRisk,groupGain},
   disclaimer:'Le potentiel est un plafond de simulation, pas une progression garantie.'};
 }
 function compare(a,b){
  if(a==null)return b==null?0:1;
  if(b==null)return -1;
  if(typeof a==='number'&&typeof b==='number')return a-b;
  return String(a).localeCompare(String(b),'fr',{sensitivity:'base',numeric:true});
 }
 function table(model,options={}){
  if(!model||model.version!==1)throw new TypeError('Projection du centre de formation requise');
  const kind=options.kind||'academy';
  if(!['academy','young'].includes(kind))throw new RangeError('Origine inconnue');
  const sortBy=options.sortBy||'name',direction=options.direction||'asc';
  if(!SORTS.includes(sortBy)||!['asc','desc'].includes(direction))throw new RangeError('Tri inconnu');
  const family=options.family==null||options.family==='all'?'all':Number(options.family);
  if(family!=='all'&&(!Number.isInteger(family)||family<0||family>8))throw new RangeError('Famille de poste inconnue');
  const maxAge=options.maxAge==null?null:Number(options.maxAge);
  if(maxAge!==null&&(!Number.isInteger(maxAge)||maxAge<16||maxAge>45))throw new RangeError('Âge limite inconnu');
  const search=normalize(options.search).trim();
  let rows=model[kind].filter(p=>
   (family==='all'||p.family===family)&&
   (maxAge===null||p.age<=maxAge)&&
   (!search||normalize(p.name+' '+p.position).includes(search))&&
   (!options.canPromoteOnly||p.canPromote)
  );
  rows=rows.map((row,index)=>({row,index})).sort((a,b)=>{
   const delta=compare(a.row[sortBy],b.row[sortBy]);
   return delta?(direction==='desc'?-delta:delta):a.index-b.index;
  }).map(v=>v.row);
  return {kind,sortBy,direction,total:rows.length,rows};
 }
 return Object.freeze({SORTS,VIEWS,playerView,buildCenter,table});
});