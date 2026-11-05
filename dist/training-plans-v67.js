'use strict';
// V67 — Plans d'entraînement : arbitrages de groupe sur les modes V27 déjà persistés.
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDTrainingPlansV67=api;
})(typeof globalThis==='object'?globalThis:null,function(){
 const PLANS=Object.freeze({
  proteger:{label:'Protéger le XV',detail:'Titulaires : récupération. Remplaçants aptes : séance normale.'},
  relever:{label:'Faire progresser la relève',detail:'Jeunes aptes et frais : intensif. Titulaires fatigués : récupération.'},
  equilibrer:{label:'Équilibrer les charges',detail:'Repos si charge ou condition critique ; les autres suivent une séance normale.'}
 });
 const escape=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 function allowed(s){return !!s&&Array.isArray(s.clubs?.[s.club]?.players)&&Array.isArray(s.lineup)&&!s.live&&!s.trained&&s.phase==='league';}
 function mode(p,key,isStarter){
  if(p.injury)return 'repos';
  const fatigue=Number.isFinite(p.physicalLoad?.fatigue)?p.physicalLoad.fatigue:0;
  const condition=Number.isFinite(p.condition)?p.condition:100;
  if(key==='proteger')return isStarter?'repos':'normal';
  if(key==='relever'){
   if(isStarter&&(condition<75||fatigue>=45))return 'repos';
   if(Number.isFinite(p.age)&&p.age<=23&&condition>=80&&fatigue<35)return 'intense';
   return 'normal';
  }
  if(key==='equilibrer')return fatigue>=45||condition<65?'repos':'collective';
  return null;
 }
 function preview(s,key,engine){
  if(!PLANS[key]||!s||!Array.isArray(s.clubs?.[s.club]?.players)||!engine||typeof engine.outcome!=='function')return null;
  const starters=new Set(Array.isArray(s.lineup)?s.lineup:[]);
  const players=s.clubs[s.club].players.map(p=>{
   const planned=mode(p,key,starters.has(p.id));
   const actual=planned==='collective'?'normal':planned;
   const projected=engine.outcome(p,actual);
   return {id:p.id,name:p.name,plan:planned,current:p.condition,
    condition:projected.condition,fatigue:projected.fatigue,
    injured:!!p.injury,starter:starters.has(p.id)};
  });
  const counts={repos:0,normal:0,intense:0,collective:0};
  players.forEach(p=>counts[p.plan]++);
  return {key,players,counts,conditionGain:players.reduce((n,p)=>n+p.condition-p.current,0),
   highFatigue:players.filter(p=>!p.injured&&p.fatigue>=45).length,
   eligible:allowed(s),label:PLANS[key].label};
 }
 function apply(s,key,{outcome,save,render}={}){
  if(!allowed(s)||!PLANS[key]||typeof outcome!=='function'||typeof save!=='function')return false;
  const data=preview(s,key,{outcome});
  if(!data)return false;
  const players=s.clubs[s.club].players;
  const before=players.map(p=>({had:Object.prototype.hasOwnProperty.call(p,'physicalLoad'),
   value:p.physicalLoad?{...p.physicalLoad}:null}));
  const training=s.training;
  try{
   s.training='normal';
   data.players.forEach((row,i)=>{
    const p=players[i],prior=p.physicalLoad&&p.physicalLoad.version===1?p.physicalLoad:null;
    p.physicalLoad={...(prior||{version:1,fatigue:0}),plan:row.plan};
   });
   if(save()===false)throw Error('Sauvegarde refusée');
   if(typeof render==='function')render();
   return true;
  }catch(_){
   s.training=training;
   before.forEach((prior,i)=>{if(prior.had)players[i].physicalLoad=prior.value;else delete players[i].physicalLoad;});
   return false;
  }
 }
 function panel(s,engine){
  if(!s||!Array.isArray(s.clubs?.[s.club]?.players)||!engine)return '';
  const can=allowed(s),rows=Object.keys(PLANS).map(key=>preview(s,key,engine));
  return '<section class="card" aria-label="Plans entraînement V67"><div class="cardtitle"><h2>Plans d’entraînement · V67</h2><span class="tag">'+(can?'À PRÉPARER':'LECTURE SEULE')+'</span></div>'+
   '<p class="help">Choisissez une répartition effective des charges par joueur avant la séance. Les prévisions utilisent le moteur physique V27. Aucun gain de note ou blessure aléatoire anticipé.</p>'+
   '<div class="stack">'+rows.map(d=>'<div class="row budgetline"><div><strong>'+escape(PLANS[d.key].label)+'</strong>'+
   '<small>'+escape(PLANS[d.key].detail)+'</small><small>'+d.counts.repos+' récupération · '+(d.counts.normal+d.counts.collective)+' normale · '+d.counts.intense+' intense · condition totale '+(d.conditionGain>=0?'+':'')+d.conditionGain+' pts · '+d.highFatigue+' joueurs restant très chargés</small></div>'+
   '<button class="small" type="button" onclick="trainingPlanV67(\''+d.key+'\')" '+(can?'':'disabled')+'>Appliquer</button></div>').join('')+'</div>'+
   '<details><summary>Voir les projections joueur par joueur</summary><div class="tablewrap"><table><thead><tr><th>Joueur</th><th>Mode prévu</th><th>Condition après séance</th><th>Charge après séance</th></tr></thead><tbody>'+
   rows[0].players.map((p,i)=>'<tr><td>'+escape(p.name)+'</td><td>'+rows.map(d=>escape(d.players[i].plan)).join(' / ')+'</td><td>'+rows.map(d=>d.players[i].condition).join(' / ')+'</td><td>'+rows.map(d=>d.players[i].fatigue).join(' / ')+'</td></tr>').join('')+
   '</tbody></table></div><p class="help">Colonnes dans l’ordre : protéger / relève / équilibrer. Blessés en récupération automatique.</p></details>'+
   '<p class="help">Cette action configure les plans V27 existants, sans lancer la séance. En cas de délégation au préparateur, les plans individuels restent prioritaires sur le mode collectif pour les exceptions.</p></section>';
 }
 function install(root){
  if(!root||typeof root.tactics!=='function'||typeof root.physicalTrainingOutcome!=='function'||typeof root.save!=='function')return false;
  if(root.tactics.__v67Wrapped)return true;
  const current=()=>typeof S!=='undefined'?S:root.S;
  const engine={outcome:(p,mode)=>root.physicalTrainingOutcome(p,mode)};
  const previous=root.tactics;
  const wrapped=function(){return previous()+panel(current(),engine);};
  wrapped.__v67Wrapped=true;root.tactics=wrapped;
  root.trainingPlanV67=key=>apply(current(),key,{
   outcome:engine.outcome,
   save:()=>{root.save();return typeof lastSaveError==='undefined'||!lastSaveError;},
   render:()=>{if(typeof root.render==='function')root.render();}
  });
  return true;
 }
 return Object.freeze({PLANS,allowed,mode,preview,apply,panel,install});
});
if(typeof document!=='undefined'&&typeof CDTrainingPlansV67==='object')CDTrainingPlansV67.install(globalThis);
