'use strict';
// V117-V123: narration contextuelle adossee aux systemes V36/V37, V64, V70.
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDLivingLockerRoom=api;
})(typeof globalThis==='object'?globalThis:null,function(){
 const cap=(n,a,b)=>Math.max(a,Math.min(b,Math.round(n)));
 const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&amp;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const TRAITS=['Ambitieux','Loyal','Exigeant','Discret','Protecteur','Competiteur','Sensible','Collectif'];
 const CHOICES=Object.freeze({
  ecouter:{label:"L'ecouter",detail:"Satisfaction +4 ; moral collectif +1",sat:4,morale:1,trust:0},
  cadrer:{label:"Rappeler les exigences",detail:"Satisfaction -3 ; confiance de direction +2 ; moral -1",sat:-3,morale:-1,trust:2},
  responsabiliser:{label:"Lui donner un role dans le groupe",detail:"Satisfaction +2 ; moral +2 ; engagement de temps de jeu a suivre",sat:2,morale:2,trust:0}
 });
 const hash=x=>{let h=2166136261;for(const c of String(x)){h=Math.imul(h^c.charCodeAt(0),16777619)}return h>>>0};
 function personality(p){
  if(!p||typeof p.id!=='string')return null;
  const h=hash(p.id),trait=TRAITS[h%TRAITS.length];
  return {trait,leadership:cap(Math.round((p.skills?.mental??p.rating??65)*.65+(p.age??24)*.6+(p.satisfaction?.score??65)*.2),0,100)};
 }
 const weekKey=s=>String(s.season)+':'+String(s.economy?.week);
 function roster(s){return Array.isArray(s?.clubs?.[s.club]?.players)?s.clubs[s.club].players:[]}
 function valid(s){return !!s&&s.phase==='league'&&s.manager&&s.economy&&Number.isInteger(s.season)&&Number.isInteger(s.economy.week)&&Array.isArray(s.manager.inbox)}
 function getState(s){const x=s?.livingLockerRoom;return x?.version===1&&Array.isArray(x.history)&&Array.isArray(x.commitments)?x:null}
 function state(s){return getState(s)||{version:1,history:[],commitments:[],closed:[]}}
 function weeklyEvent(s){
  if(!valid(s))return null;
  const history=state(s).history,key=weekKey(s);
  const already=history.find(x=>x.key===key);
  if(already)return null;
  const previous=new Set(history.slice(-3).map(x=>x.playerId));
  const players=roster(s).filter(p=>p&&typeof p.id==='string'&&!p.injury&&Number.isFinite(p.condition));
  if(!players.length)return null;
  const pool=players.map(p=>{
   const sat=p.satisfaction?.score??65,leader=personality(p);
   const kind=sat<52?'tension':p.condition<66?'fatigue':p.age<=23&&p.dev?.minutes>=120?'revelation':
    p.contractEnd===s.season?'contrat':leader.leadership>=73?'leadership':'ambition';
   const urgency=kind==='tension'?50-sat:kind==='fatigue'?40-p.condition:kind==='contrat'?12:kind==='revelation'?9:kind==='leadership'?7:3;
   return {p,kind,urgency,leader};
  }).sort((a,b)=>(Number(previous.has(a.p.id))-Number(previous.has(b.p.id)))||(b.urgency-a.urgency)||(hash(key+a.p.id)-hash(key+b.p.id)));
  const selected=pool[0];if(!selected)return null;
  const label={tension:'Un joueur doute de sa place',fatigue:'Un cadre tire sur la corde',
   revelation:'Un jeune attend un signal',contrat:'Une echeance contractuelle pese sur le groupe',
   leadership:'Un leader veut etre entendu',ambition:'Un joueur demande un entretien'}[selected.kind];
  const context={tension:'Son niveau de satisfaction est bas.',fatigue:'Sa condition physique exige une attention particuliere.',
   revelation:'Ses minutes en equipe premiere commencent a compter.',contrat:'Son contrat arrive a echeance cette saison.',
   leadership:'Son influence potentielle dans le groupe est importante.',ambition:'Son projet individuel et celui du club doivent etre alignes.'}[selected.kind];
  return {key,playerId:selected.p.id,kind:selected.kind,title:label,context,trait:selected.leader.trait,leadership:selected.leader.leadership};
 }
 function allowed(s){return !!valid(s)&&!s.live&&!s.trained&&!getState(s)?.history.some(x=>x.key===weekKey(s))}
 function apply(s,choice,{save,message,render}={}){
  if(!allowed(s)||!Object.hasOwn(CHOICES,choice)||typeof save!=='function')return false;
  const e=weeklyEvent(s);if(!e)return false;
  const p=roster(s).find(x=>x.id===e.playerId);if(!p)return false;
  const before={had:Object.prototype.hasOwnProperty.call(s,'livingLockerRoom'),data:s.livingLockerRoom,score:p.satisfaction?.score,
    morale:s.morale,trust:s.trust,inbox:s.manager.inbox.slice(),serial:s.manager.serial};
  const cfg=CHOICES[choice],next=JSON.parse(JSON.stringify(state(s)));
  try{
   next.history.push({...e,choice,season:s.season,week:s.economy.week,status:'decided'});
   next.history=next.history.slice(-80);
   if(p.satisfaction&&Number.isFinite(p.satisfaction.score))p.satisfaction.score=cap(p.satisfaction.score+cfg.sat,20,95);
   s.morale=cap((Number.isFinite(s.morale)?s.morale:75)+cfg.morale,25,98);
   s.trust=cap((Number.isFinite(s.trust)?s.trust:70)+cfg.trust,0,100);
   if(choice==='responsabiliser'){
    next.commitments.push({id:e.key+':'+p.id,playerId:p.id,originSeason:s.season,originWeek:s.economy.week,
      dueWeek:s.economy.week+2,baseline:p.dev?.minutes??0,target:60,status:'open'});
    next.commitments=next.commitments.slice(-30);
   }
   s.livingLockerRoom=next;
   if(typeof message==='function')message('Vestiaire : '+e.title,
     p.name+' ('+e.trait+') : '+cfg.label+'. '+cfg.detail+'.','staff','team');
   if(save()===false)throw Error('Echec de la sauvegarde');
   if(typeof render==='function')render();
   return true;
  }catch(_){
   if(before.had)s.livingLockerRoom=before.data;else delete s.livingLockerRoom;
   if(p.satisfaction&&Number.isFinite(before.score))p.satisfaction.score=before.score;
   s.morale=before.morale;s.trust=before.trust;
   s.manager.inbox=before.inbox;s.manager.serial=before.serial;
   return false;
  }
 }
 function settle(s,{message}={}){
  const st=getState(s);if(!valid(s)||!st)return [];
  const outcomes=[];
  for(const c of st.commitments){
   if(c.status!=='open')continue;
   if(c.originSeason!==s.season){c.status='expired';c.resolvedWeek=s.economy.week;continue;}
   if(s.economy.week<c.dueWeek)continue;
   const p=roster(s).find(x=>x.id===c.playerId);
   const minutes=p?.dev?.minutes??0;
   const honored=!!p&&(minutes-c.baseline>=c.target||!!p.injury);
   c.status=honored?'honored':'broken';c.resolvedWeek=s.economy.week;
   if(p?.satisfaction&&Number.isFinite(p.satisfaction.score))
    p.satisfaction.score=cap(p.satisfaction.score+(honored?3:-6),20,95);
   s.morale=cap((Number.isFinite(s.morale)?s.morale:75)+(honored?1:-2),25,98);
   outcomes.push({id:c.id,playerId:c.playerId,status:c.status});
   if(typeof message==='function')message('Engagement de vestiaire '+(honored?'honore':'non tenu'),
    (p?.name||'Joueur parti du club')+' : objectif de '+c.target+' minutes examine.','staff','team');
  }
  if(st.commitments.length>30)st.commitments=st.commitments.slice(-30);
  return outcomes;
 }
 function panel(s){
  if(!valid(s))return '';
  const event=weeklyEvent(s),st=state(s),latest=st.history.slice(-4).reverse(),pending=st.commitments.filter(x=>x.status==='open');
  const p=event&&roster(s).find(x=>x.id===event.playerId);
  const buttons=event?Object.entries(CHOICES).map(([key,c])=>
   '<button type="button" class="small" onclick="livingLockerDecision(\''+key+'\')" '+(!allowed(s)?'disabled':'')+'>'+
   esc(c.label)+'</button>').join(' '):'';
  return '<section class="card" aria-label="Monde vivant et vestiaire V117">'+
   '<div class="cardtitle"><h2>Monde vivant · Vie du vestiaire</h2><span class="tag">'+(event?'DECISION A PRENDRE':'SUIVI DU GROUPE')+'</span></div>'+
   (event?'<h3>'+esc(event.title)+'</h3><p><strong>'+esc(p?.name||'Joueur')+'</strong> · '+esc(event.trait)+
    ' · leadership '+event.leadership+'/100</p><p>'+esc(event.context)+'</p><p class="help">Une decision maximum par semaine, sans evenement aleatoire gratuit. Les profils restent stables dans la carriere.</p><div class="row">'+buttons+'</div>':
    '<p>Votre entretien de cette semaine a ete traite. Les consequences restent dans la sauvegarde.</p>')+
   '<details><summary>Suivi des engagements ('+pending.length+') et decisions ('+latest.length+')</summary><ul>'+
   pending.slice(-5).map(x=>'<li>Engagement : '+esc(roster(s).find(p=>p.id===x.playerId)?.name||'Joueur parti')+' · '+x.target+' minutes avant semaine '+x.dueWeek+'</li>').join('')+
   latest.map(x=>'<li>S'+x.season+' / semaine '+x.week+' : '+esc(x.title)+' — '+esc(CHOICES[x.choice]?.label||x.choice)+'</li>').join('')+
   '</ul></details><p class="help">Les decisions ajustent la satisfaction V36/V64, le moral collectif utilise par le moteur et la confiance de direction. Les engagements sont controles deux semaines plus tard.</p></section>';
 }
 function install(root){
  if(!root||typeof root.render!=='function'||typeof root.managerWeek!=='function'||typeof root.managerMessage!=='function'||typeof root.save!=='function')return false;
  if(root.__livingRoomInstalled)return true;
  root.__livingRoomInstalled=true;
  const current=()=>typeof S!=='undefined'?S:root.S;
  const oldRender=root.render,oldWeek=root.managerWeek;
  // A native PC dashboard renders a fixed workspace. Mount this section in
  // its scrollable Dossiers tab, never as an extra fixed-layout main sibling.
  root.render=function(){
   const result=oldRender.apply(this,arguments);
   if(typeof document==='undefined'||typeof view==='undefined'||view!=='dashboard')return result;
   const target=root.document?.querySelector('#app .layout .main .da42-workspace-shell[data-da43-section="dashboard"] [data-da42-page="dossiers"]');
   if(target&&typeof target.insertAdjacentHTML==='function')target.insertAdjacentHTML('beforeend',panel(current()));
   return result;
  };
  root.managerWeek=function(){const result=oldWeek.apply(this,arguments);const s=current();if(s){const out=settle(s,{message:(...args)=>root.managerMessage(...args)});if(out.length)root.save()}return result};
  root.livingLockerDecision=function(choice){
   const ok=apply(current(),choice,{save:()=>{root.save();return typeof lastSaveError==='undefined'||!lastSaveError;},
    message:(...args)=>root.managerMessage(...args),render:()=>root.render()});
   if(!ok&&typeof root.toast==='function')root.toast('Decision indisponible ou sauvegarde impossible.');
   return ok;
  };
  return true;
 }
 return Object.freeze({CHOICES,personality,weeklyEvent,allowed,state,apply,settle,panel,install});
});
if(typeof document!=='undefined'&&typeof CDLivingLockerRoom==='object')CDLivingLockerRoom.install(globalThis);
