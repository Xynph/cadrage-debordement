'use strict';
// V68 — Décisions médicales : complète le centre de disponibilité natif sans changer le moteur de match.
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDMedicalV68=api;
})(typeof globalThis==='object'?globalThis:null,function(){
 const PROTOCOLS=Object.freeze({
  prudent:{label:'Rééducation prudente',description:'Récupération sans raccourci ; priorité à la condition et à la baisse de charge.'},
  standard:{label:'Suivi standard',description:'Durée habituelle, remise en forme progressive.'},
  accelere:{label:'Retour accéléré',description:'Possibilité de gagner une semaine, mais risque de rechute et de fatigue.'}
 });
 const clamp=(n,min=0,max=100)=>Math.max(min,Math.min(max,n));
 const escape=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const statePlayer=(s,id)=>Array.isArray(s?.clubs?.[s.club]?.players)?s.clubs[s.club].players.find(p=>String(p.id)===String(id)):null;
 function canManage(s){return !!s&&!s.live&&!s.trained&&s.phase==='league'&&Array.isArray(s.clubs?.[s.club]?.players);}
 function treatment(p){return PROTOCOLS[p.medicalV68?.protocol]?p.medicalV68.protocol:'standard';}
 function isRecovering(p){return Number(p?.injury)>0;}
 function risk(s,p,salt){let hash=2166136261;const key=[s.season,s.round,p.id,salt].join('|');for(let i=0;i<key.length;i++){hash^=key.charCodeAt(i);hash=Math.imul(hash,16777619);}return (hash>>>0)/4294967296;}
 function choose(s,id,protocol,{save,render}={}){
  const p=statePlayer(s,id);
  if(!canManage(s)||!p||!isRecovering(p)||!PROTOCOLS[protocol]||typeof save!=='function')return false;
  const before=Object.prototype.hasOwnProperty.call(p,'medicalV68')?JSON.stringify(p.medicalV68):null;
  p.medicalV68={version:1,protocol,stage:'blesse'};
  try{if(save()===false)throw Error('Sauvegarde refusée');if(typeof render==='function')render();return true;}
  catch(_){if(before===null)delete p.medicalV68;else p.medicalV68=JSON.parse(before);return false;}
 }
 // Appelé une seule fois APRÈS la séance native : celle-ci gère déjà -1 semaine et la condition.
 function completeTraining(s,before){
  if(!s||!Array.isArray(s.clubs?.[s.club]?.players)||!before)return [];
  const reports=[];
  for(const p of s.clubs[s.club].players){
   const start=before.get(p.id);
   if(!start||start.injury<=0)continue;
   const protocol=start.protocol;
   const oldInjury=Number(p.injury)||0;
   const oldFatigue=Number(p.physicalLoad?.fatigue)||0;
   const oldCondition=Number.isFinite(p.condition)?p.condition:100;
   let incident='aucun';
   if(protocol==='prudent'){
    p.condition=clamp(oldCondition+8);
    if(p.physicalLoad)p.physicalLoad.fatigue=clamp(oldFatigue-10);
   }else if(protocol==='standard'){
    p.condition=clamp(oldCondition+3);
    if(p.physicalLoad)p.physicalLoad.fatigue=clamp(oldFatigue-4);
   }else if(protocol==='accelere'){
    p.condition=clamp(oldCondition-5);
    if(p.physicalLoad)p.physicalLoad.fatigue=clamp(oldFatigue+12);
    const dice=risk(s,p,'soins');
    if(dice<.18){p.injury=oldInjury+1;incident='contretemps';}
    else if(dice<.58&&oldInjury>0){p.injury=oldInjury-1;incident='gain de temps';}
   }
   const remaining=Number(p.injury)||0;
   p.medicalV68={version:1,protocol,stage:remaining>0?'blesse':'reprise'};
   reports.push({id:p.id,remaining,protocol,incident});
  }
  return reports;
 }
 function returnToPlay(s,id,choice,{save,render}={}){
  const p=statePlayer(s,id);
  if(!canManage(s)||!p||p.injury>0||p.medicalV68?.stage!=='reprise'||
   !['progressif','complet'].includes(choice)||typeof save!=='function')return false;
  const old={condition:p.condition,injury:p.injury,medical:JSON.stringify(p.medicalV68),
   physical:p.physicalLoad?{...p.physicalLoad}:null,hasPhysical:Object.prototype.hasOwnProperty.call(p,'physicalLoad')};
  try{
   if(choice==='progressif'){
    p.condition=clamp((Number(p.condition)||0)+8);
    p.physicalLoad={...(p.physicalLoad||{version:1,fatigue:0}),plan:'repos',
     fatigue:clamp((Number(p.physicalLoad?.fatigue)||0)-12)};
    p.medicalV68={...p.medicalV68,stage:'progressif'};
   }else{
    p.condition=clamp((Number(p.condition)||0)-7);
    p.physicalLoad={...(p.physicalLoad||{version:1,fatigue:0}),
     fatigue:clamp((Number(p.physicalLoad?.fatigue)||0)+12),plan:'normal'};
    if(risk(s,p,'retour')<.15)p.injury=1;
    p.medicalV68={...p.medicalV68,stage:'termine'};
   }
   if(save()===false)throw Error('Sauvegarde refusée');
   if(typeof render==='function')render();
   return true;
  }catch(_){
   p.condition=old.condition;p.injury=old.injury;p.medicalV68=JSON.parse(old.medical);
   if(old.hasPhysical)p.physicalLoad=old.physical;else delete p.physicalLoad;
   return false;
  }
 }
 function panel(s){
  if(!Array.isArray(s?.clubs?.[s.club]?.players))return '';
  const injured=s.clubs[s.club].players.filter(p=>Number(p.injury)>0);
  const ready=s.clubs[s.club].players.filter(p=>!p.injury&&p.medicalV68?.stage==='reprise');
  const phaseCan=canManage(s);
  const row=p=>{
   const protocol=treatment(p);
   return '<div class="row budgetline"><div><strong>'+escape(p.name)+'</strong><small>'+
    escape(p.pos||'')+' · '+Math.max(0,Number(p.injury)||0)+' semaine(s) · condition '+Math.round(p.condition||0)+
    '% · charge '+Math.round(p.physicalLoad?.fatigue||0)+'/100</small><small>Protocole actuel : '+escape(PROTOCOLS[protocol].label)+'</small></div>'+
    '<div><select aria-label="Protocole médical de '+escape(p.name)+'" data-medical-protocol="'+escape(p.id)+'" '+
     (phaseCan?'':'disabled')+'>'+Object.entries(PROTOCOLS).map(([key,v])=>
      '<option value="'+key+'"'+(key===protocol?' selected':'')+'>'+escape(v.label)+'</option>').join('')+
     '</select><button class="small" type="button" onclick="medicalProtocolV68(\''+escape(p.id)+'\')" '+
     (phaseCan?'':'disabled')+'>Valider</button></div></div>';
  };
  const readyRow=p=>'<div class="row budgetline"><div><strong>'+escape(p.name)+'</strong>'+
   '<small>Guéri médicalement · condition '+Math.round(p.condition||0)+'% · choisissez une reprise</small></div>'+
   '<div><button class="small" onclick="medicalReturnV68(\''+escape(p.id)+'\',\'progressif\')" '+
   (phaseCan?'':'disabled')+'>Reprise progressive</button> '+
   '<button class="small" onclick="medicalReturnV68(\''+escape(p.id)+'\',\'complet\')" '+
   (phaseCan?'':'disabled')+'>Retour immédiat à risque</button></div></div>';
  return '<section class="card" aria-label="Centre médical V68"><div class="cardtitle"><h2>Cellule médicale · V68</h2>'+
   '<span class="tag">'+(phaseCan?'DÉCISIONS OUVERTES':'LECTURE SEULE')+'</span></div>'+
   '<p class="help">Les semaines de blessure restent gérées par le moteur existant. Les protocoles agissent lors de la prochaine séance ; le retour accéléré peut gagner une semaine ou provoquer un contretemps. Aucun blessé ne devient sélectionnable avant guérison.</p>'+
   (injured.length?injured.map(row).join(''):'<p>Aucun blessé actuellement.</p>')+
   (ready.length?'<h3>Retour à la compétition</h3>'+ready.map(readyRow).join(''):'')+
   '<p class="help">La reprise progressive impose repos et récupération physique ; le retour immédiat ajoute de la charge, dégrade la condition et comporte un risque de rechute. Ces choix sont des mécanismes de jeu, pas des recommandations de santé réelle.</p></section>';
 }
 function install(root){
  if(!root||typeof root.managerTeamView!=='function'||typeof root.trainWeek!=='function'||
   typeof root.save!=='function')return false;
  if(root.managerTeamView.__v68Wrapped)return true;
  const current=()=>typeof S!=='undefined'?S:root.S;
  const previous=root.managerTeamView;
  const ui=function(...args){const content=previous.apply(this,args);
   const tab=typeof squadTab!=='undefined'?squadTab:root.squadTab;
   return tab==='health'?content+panel(current()):content;};
  ui.__v68Wrapped=true;root.managerTeamView=ui;
  const training=root.trainWeek;
  root.trainWeek=function(...args){
   const s=current();
   if(!s||s.trained||s.live||s.phase==='ended')return training.apply(this,args);
   const before=new Map((s.clubs?.[s.club]?.players||[]).map(p=>[p.id,{
    injury:Number(p.injury)||0,protocol:treatment(p)}]));
   const result=training.apply(this,args);
   if(s.trained)completeTraining(s,before);
   return result;
  };
  root.medicalProtocolV68=id=>{
   const s=current(),node=typeof document!=='undefined'?document.querySelector('[data-medical-protocol="'+String(id).replace(/["\\]/g,'')+'"]'):null;
   return choose(s,id,node?.value||'',{save:()=>{root.save();return typeof lastSaveError==='undefined'||!lastSaveError;},
    render:()=>root.render?.()});
  };
  root.medicalReturnV68=(id,choice)=>returnToPlay(current(),id,choice,{
   save:()=>{root.save();return typeof lastSaveError==='undefined'||!lastSaveError;},
   render:()=>root.render?.()});
  return true;
 }
 return Object.freeze({PROTOCOLS,canManage,treatment,risk,choose,completeTraining,returnToPlay,panel,install});
});
if(typeof document!=='undefined'&&typeof CDMedicalV68==='object')CDMedicalV68.install(globalThis);
