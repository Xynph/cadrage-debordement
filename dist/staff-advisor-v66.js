'use strict';
// V66 — Conseiller de staff : diagnostic lisible et décision déléguée au mécanisme V65.
// Aucune écriture propre dans les sauvegardes ; aucun effet sportif en dehors de V65.
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDStaffAdvisorV66=api;
})(typeof globalThis==='object'?globalThis:null,function(){
 const safe=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const avg=xs=>xs.length?Math.round(xs.reduce((a,b)=>a+b,0)/xs.length):0;
 function diagnostic(s,v65){
  if(!s||!v65||typeof v65.preview!=='function'||typeof v65.available!=='function')return null;
  const players=v65.eligible(s),conditions=players.map(p=>p.condition);
  const fatigue=conditions.filter(c=>c<65).length;
  const tired=conditions.filter(c=>c<85).length;
  const plans=Object.keys(v65.OPTIONS).map(key=>{
   const result=v65.preview(s,key);
   return {key,label:v65.OPTIONS[key].label,affected:result.affected,
    morale:result.morale,trust:result.trust,
    conditionGain:result.players.reduce((n,p)=>n+p.after-p.before,0)};
  });
  // Priorités de management : limiter d'abord la fatigue critique, puis les crises humaines.
  // À niveau sain, la confiance est une troisième priorité.
  let recommended='cohesion',reason='Renforcer la cohésion du groupe avant la prochaine rencontre.';
  if(fatigue>0&&(fatigue>=3||avg(conditions)<72)){
   recommended='recuperation';reason=fatigue+' joueur(s) disponible(s) sous 65 de condition : préserver leur fraîcheur.';
  }else if(Number.isFinite(s.morale)&&s.morale<68){
   recommended='cohesion';reason='Moral collectif à '+s.morale+'/100 : recréer de la cohésion.';
  }else if(Number.isFinite(s.trust)&&s.trust<60){
   recommended='exigence';reason='Confiance de direction à '+s.trust+'/100 : montrer davantage d’exigence.';
  }else if(tired>=Math.max(3,Math.ceil(players.length/3))){
   recommended='recuperation';reason=tired+' joueur(s) sous 85 de condition : anticiper l’accumulation de fatigue.';
  }else{
   recommended='cohesion';reason='Équilibre satisfaisant : entretenir le collectif sans surcharger les joueurs.';
  }
  return {available:v65.available(s),players:players.length,mean:avg(conditions),
   fatigue,tired,morale:s.morale,trust:s.trust,recommended,reason,plans};
 }
 function panel(s,v65){
  const d=diagnostic(s,v65);
  if(!d)return '';
  const locked=!d.available;
  return '<section class="card" aria-label="Conseiller de staff V66">'+
   '<div class="cardtitle"><h2>Conseiller de staff · V66</h2><span class="tag">'+(locked?'LECTURE SEULE':'DÉCISION DISPONIBLE')+'</span></div>'+
   '<p class="help">Diagnostic sur '+d.players+' joueur(s) disponibles · condition moyenne '+d.mean+'/100 · '+d.fatigue+' sous 65 · moral '+safe(d.morale)+'/100 · confiance '+safe(d.trust)+'/100.</p>'+
   '<p class="notice"><strong>Conseil : '+safe(v65.OPTIONS[d.recommended].label)+'</strong> — '+safe(d.reason)+'</p>'+
   '<div class="tablewrap"><table><thead><tr><th>Arbitrage</th><th>Condition totale</th><th>Moral prévu</th><th>Confiance prévue</th><th>Action</th></tr></thead><tbody>'+
   d.plans.map(p=>'<tr><td>'+safe(p.label)+(p.key===d.recommended?' · conseillé':'')+'</td>'+
   '<td>'+(p.conditionGain>=0?'+':'')+p.conditionGain+' pts ('+p.affected+' joueurs)</td>'+
   '<td>'+p.morale+'/100</td><td>'+p.trust+'/100</td><td><button class="small" type="button" onclick="staffAdvisorV66(\''+p.key+'\')" '+(locked?'disabled':'')+'>Valider</button></td></tr>').join('')+
   '</tbody></table></div>'+
   '<p class="help">Prévisions calculées sur les valeurs actuelles. Le choix applique la réunion V65, avec son verrou hebdomadaire, ses interdictions et sa sauvegarde. Aucun second bonus n’est possible.</p></section>';
 }
 function install(root,v65){
  if(!root||typeof root.managerOffice!=='function'||typeof root.staffMeetingV65!=='function'||!v65)return false;
  if(root.managerOffice.__v66Wrapped)return true;
  const previous=root.managerOffice;
  const current=()=>typeof S!=='undefined'?S:root.S;
  const wrapped=function(){return previous()+panel(current(),v65)};
  wrapped.__v66Wrapped=true;root.managerOffice=wrapped;
  root.staffAdvisorV66=function(key){
   const s=current(),d=diagnostic(s,v65);
   if(!d||!d.available||!d.plans.some(p=>p.key===key))return false;
   return root.staffMeetingV65(key);
  };
  return true;
 }
 return Object.freeze({diagnostic,panel,install});
});
if(typeof document!=='undefined'&&typeof CDStaffAdvisorV66==='object')
 CDStaffAdvisorV66.install(globalThis,globalThis.CDStaffMeetingV65);
