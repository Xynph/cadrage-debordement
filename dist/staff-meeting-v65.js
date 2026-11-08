'use strict';
// V65 — Réunion de staff : décision hebdomadaire effective, sans changement de schéma de sauvegarde.
// Le reçu utilise l'inbox du manager déjà persistée en V17.
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDStaffMeetingV65=api;
})(typeof globalThis==='object'?globalThis:null,function(){
 const OPTIONS=Object.freeze({
  recuperation:{label:'Récupération ciblée',detail:'Les joueurs fatigués récupèrent jusqu’à 5 points de condition. Confiance du conseil −1.',morale:0,trust:-1},
  cohesion:{label:'Cohésion de groupe',detail:'Moral collectif +3. Les joueurs disponibles perdent 1 point de condition.',morale:3,trust:0},
  exigence:{label:'Exigence sportive',detail:'Confiance du conseil +2, moral collectif −2. Les joueurs disponibles perdent 2 points de condition.',morale:-2,trust:2}
 });
 const bounded=(n,min,max)=>Math.max(min,Math.min(max,Math.round(n)));
 const escapeHtml=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 function currentMeeting(s){
  if(!s||!Array.isArray(s.manager?.inbox))return null;
  return s.manager.inbox.find(e=>e.kind==='staff-v65'&&e.season===s.season&&e.week===s.economy?.week)||null;
 }
 function eligible(s){
  return Array.isArray(s?.clubs?.[s.club]?.players)?s.clubs[s.club].players.filter(p=>p&&!p.injury&&Number.isFinite(p.condition)):[];
 }
 function available(s){
  return !!s&&!!s.manager&&!!s.economy&&Number.isInteger(s.season)&&Number.isInteger(s.economy.week)&&
   s.phase==='league'&&!s.live&&!s.trained&&currentMeeting(s)===null&&Array.isArray(s.clubs?.[s.club]?.players);
 }
 function preview(s,key){
  if(!OPTIONS[key])return null;
  const targets=eligible(s);
  const deltas=targets.map(p=>({id:p.id,before:p.condition,
   after:bounded(p.condition+(key==='recuperation'?(p.condition<90?5:0):key==='cohesion'?-1:-2),0,100)}));
  return {key,players:deltas,affected:deltas.filter(p=>p.after!==p.before).length,
   morale:bounded((Number.isFinite(s?.morale)?s.morale:75)+OPTIONS[key].morale,25,98),
   trust:bounded((Number.isFinite(s?.trust)?s.trust:70)+OPTIONS[key].trust,0,100)};
 }
 function perform(s,key,{message,save,render}={}){
  if(!available(s)||!OPTIONS[key]||typeof message!=='function'||typeof save!=='function')return false;
  const result=preview(s,key),prior={morale:s.morale,trust:s.trust,condition:result.players.map(p=>p.before),inbox:s.manager.inbox.map(x=>x)};
  const members=eligible(s);
  try{
   result.players.forEach((change,i)=>{members[i].condition=change.after});
   s.morale=result.morale;s.trust=result.trust;
   message('Réunion de staff : '+OPTIONS[key].label,
    OPTIONS[key].detail+' '+result.affected+' joueur(s) concerné(s).',
    'staff-v65','dashboard');
   // Le message est aussi le verrou daté : semaine/saison déjà renseignées par managerMessage().
   if(!currentMeeting(s))throw Error('Compte rendu introuvable');
   const saved=save();
   if(saved===false)throw Error('Sauvegarde refusée');
   if(typeof render==='function')render();
   return true;
  }catch(_){
   result.players.forEach((change,i)=>{members[i].condition=prior.condition[i]});
   s.morale=prior.morale;s.trust=prior.trust;s.manager.inbox=prior.inbox;
   return false;
  }
 }
 function panel(s){
  if(!s?.manager||!s?.economy)return '';
  const meeting=currentMeeting(s),locked=!available(s);
  const players=eligible(s);
  return '<section class="card" aria-label="Réunion de staff V65">'+
   '<div class="cardtitle"><h2>Réunion de staff · V65</h2><span class="tag">'+(meeting?'DÉCISION PRISE':'ARBITRAGE HEBDOMADAIRE')+'</span></div>'+
   '<p class="help">Un arbitrage par semaine de championnat, avant entraînement. Décidez entre fraîcheur, cohésion et pression sportive. '+players.length+' joueurs disponibles. Les effets sont appliqués immédiatement et conservés par la sauvegarde du club.</p>'+
   (meeting?'<p class="notice">Cette semaine : '+escapeHtml(meeting.title)+' — '+escapeHtml(meeting.body)+'</p>':
    '<div class="stack">'+Object.entries(OPTIONS).map(([key,opt])=>'<div class="row budgetline"><div><strong>'+escapeHtml(opt.label)+'</strong><small>'+escapeHtml(opt.detail)+'</small></div><button class="small" type="button" onclick="staffMeetingV65(\''+key+'\')" '+(locked?'disabled':'')+'>Choisir</button></div>').join('')+'</div>'+
    (locked?'<p class="help">Réunion indisponible pendant le match, après l’entraînement ou hors championnat.</p>':''))+
   '</section>';
 }
 function install(root){
  if(!root||typeof root.managerOffice!=='function'||typeof root.managerMessage!=='function'||typeof root.save!=='function')return false;
  if(root.managerOffice.__v65Wrapped)return true;
  const current=()=>typeof S!=='undefined'?S:root.S;
  const previous=root.managerOffice;
  const wrapped=function(){const s=current();return previous()+panel(s)};
  wrapped.__v65Wrapped=true;root.managerOffice=wrapped;
  root.staffMeetingV65=function(key){
   const s=current();
   return perform(s,key,{message:(...args)=>root.managerMessage(...args),save:()=>{root.save();return typeof lastSaveError==='undefined'||!lastSaveError},render:()=>{if(typeof root.render==='function')root.render()}});
  };
  return true;
 }
 return Object.freeze({OPTIONS,currentMeeting,eligible,available,preview,perform,panel,install});
});
if(!globalThis.CDNativeHeadless&&typeof document!=='undefined'&&typeof CDStaffMeetingV65==='object')CDStaffMeetingV65.install(globalThis);
