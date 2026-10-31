'use strict';
// Pont vers les fonctions natives : aucune logique de marché, de formation ou de sauvegarde parallèle.
const CDNativeCenters=(function(){
 const scout={view:'overview',search:'',family:'all',sortBy:'name',direction:'asc',observedOnly:false,watchedOnly:false};
 const youth={view:'overview',search:'',family:'all',sortBy:'name',direction:'asc',selectedId:null};
 let boundRoot=null;
 const hasScout=()=>typeof CDUI03ScoutData==='object'&&typeof CDUI03ScoutComponents==='object';
 const hasAcademy=()=>typeof CDUI04AcademyData==='object'&&typeof CDUI04AcademyComponents==='object';
 function recruitmentView(){
  if(!hasScout()||!S?.manager)return typeof globalThis.recruitmentView==='function'?globalThis.recruitmentView():'';
  const m=S.manager;
  const model=CDUI03ScoutData.buildCenter({
   pool:managerPool(),reports:m.reports,missions:m.missions,watch:m.watch,
   needs:recruitmentNeeds(),season:S.season,week:S.economy.week
  },{evidence:recruitmentEvidence});
  const table=CDUI03ScoutData.candidateTable(model,scout);
  return CDUI03ScoutComponents.renderCenter(model,{...scout,table})+
   '<p class="help">Pour négocier un contrat, rendez-vous dans Mercato après avoir consulté le joueur.</p>';
 }
 function formationView(){
  if(!hasAcademy()||!S?.development)return typeof globalThis.formationIntegrated==='function'?globalThis.formationIntegrated():'';
  const source=JSON.parse(JSON.stringify({
   academy:S.development.academy,professionals:club().players,
   retired:S.development.retired,season:S.season,clubName:club().name,
   locked:economyLocked()
  }));
  const model=CDUI04AcademyData.buildCenter(source,{
   roleNote,potentialAtRole,developmentBadge,developmentFocusOptions,
   developmentFocusValue,retirementSeason
  });
  if(youth.selectedId&&![...model.academy,...model.young].some(p=>p.id===youth.selectedId))
   youth.selectedId=null;
  const table=(youth.view==='academy'||youth.view==='young')?
   CDUI04AcademyData.table(model,{kind:youth.view,search:youth.search,family:youth.family,
    sortBy:youth.sortBy,direction:youth.direction}):undefined;
  return CDUI04AcademyComponents.renderCenter(model,{...youth,table,attributeLabels:ATTR});
 }
 function validScout(id){return typeof id==='string'&&managerPool().some(p=>p.id===id);}
 function validYouth(id){return typeof id==='string'&&
  (S.development.academy.some(p=>p.id===id)||club().players.some(p=>p.id===id));}
 function mission(args){
  if(view!=='recruitment'||!S||!args)return false;
  const ok=createScoutMission(args.family,args.maxAge,args.budget,args.maxWage);
  if(!ok)toast('Mission refusée : vérifiez la trésorerie, les critères et la limite de quatre missions.');
  return ok;
 }
 function follow(id){
  if(view!=='recruitment'||!S?.manager||typeof id!=='string')return false;
  if(!S.manager.watch.includes(id)&&!validScout(id))return false;
  watchPlayer(id);return true;
 }
 function candidate(id){
  if(view!=='recruitment'||!validScout(id))return false;
  // La fiche native n'accède pas aux attributs cachés des profils non observés.
  if(S.market.some(p=>p.id===id)||S.development.academy.some(p=>p.id===id))
   inspectCareerPlayer(id);
  else {nav('market');toast('Retrouvez ce candidat dans les offres et négociations du mercato.');}
  return true;
 }
 function focus(id,value){
  if(view!=='formation'||!validYouth(id))return false;
  return setDevelopmentFocus(id,value);
 }
 function promote(id,confirmed){
  if(view!=='formation'||!S||!S.development.academy.some(p=>p.id===id)||!confirmed)return false;
  return promoteYouth(id);
 }
 function rerenderSearch(section,value){
  if(section==='scout')scout.search=value;else youth.search=value;
  render();
  const selector=section==='scout'?'[data-ui03-action="search"]':'[data-ui04-action="search"]';
  const input=document.querySelector(selector);
  if(input?.focus){input.focus();if(input.setSelectionRange)input.setSelectionRange(value.length,value.length);}
 }
 function bind(){
  const root=document.querySelector('#app');
  if(!root||typeof root.addEventListener!=='function'||root===boundRoot)return;
  boundRoot=root;
  if(hasScout())CDUI03ScoutComponents.bindActions(root,{
   onTab:key=>{if(Object.hasOwn(CDUI03ScoutComponents.TABS,key)){scout.view=key;render();}},
   onSort:key=>{if(CDUI03ScoutData.SORTS.includes(key)){scout.direction=scout.sortBy===key&&scout.direction==='asc'?'desc':'asc';scout.sortBy=key;render();}},
   onSearch:value=>rerenderSearch('scout',value),
   onFamily:value=>{scout.family=value;render();},
   onObservedOnly:value=>{scout.observedOnly=value;render();},
   onWatchedOnly:value=>{scout.watchedOnly=value;render();},
   onMission:mission,onWatch:follow,onCandidate:candidate
  });
  if(hasAcademy())CDUI04AcademyComponents.bindActions(root,{
   onTab:key=>{if(Object.hasOwn(CDUI04AcademyComponents.TABS,key)){youth.view=key;youth.selectedId=null;render();}},
   onSort:key=>{if(CDUI04AcademyData.SORTS.includes(key)){youth.direction=youth.sortBy===key&&youth.direction==='asc'?'desc':'asc';youth.sortBy=key;render();}},
   onFamily:value=>{youth.family=value;render();},
   onSearch:value=>rerenderSearch('youth',value),
   onDetails:id=>{if(validYouth(id)){youth.selectedId=id;render();}},
   onClose:()=>{youth.selectedId=null;render();},
   onNativeProfile:id=>{if(validYouth(id))inspectCareerPlayer(id);},
   onFocus:focus,
   onPromote:id=>{if(!validYouth(id))return;const p=S.development.academy.find(q=>q.id===id);
    if(p&&typeof window.confirm==='function'&&window.confirm('Promouvoir '+p.name+' dans l’équipe professionnelle ?'))promote(id,true);}
  });
 }
 return Object.freeze({recruitmentView,formationView,bind,mission,follow,candidate,focus,promote});
})();
