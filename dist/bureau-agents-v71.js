'use strict';
// V71 — Bureau des agents : outil joueur branche sur la negotiation V34 existante.
// Les representants sont des archetypes fictifs ; aucune personne reelle n'est inventee.
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDAgentsV71=api;
})(typeof globalThis==='object'?globalThis:null,function(){
 const escape=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;'}[c]));
 const round100=n=>Math.ceil(n/100)*100;
 const POLICY=Object.freeze({
  ferme:{label:'Offre ferme',detail:'Tentative basse : risque de contre-offre ou de retrait apres trois refus.',ratio:.94},
  equilibre:{label:'Accord cible',detail:'Vise le seuil contractuel actuel, sans promesse de signature.',ratio:1},
  securiser:{label:'Securiser la prolongation',detail:'Propose une marge de 4 % sur le seuil pour limiter les discussions.',ratio:1.04}
 });
 let choice={id:'',years:2,policy:'equilibre'};
 function roster(s){return Array.isArray(s?.clubs?.[s.club]?.players)?s.clubs[s.club].players:[];}
 function player(s,id){return roster(s).find(p=>p.id===id)||null;}
 function expiry(s,p){return Math.max(1,p.contractEnd-(s.season+(s.phase==='ended'?1:0))+2);}
 function eligible(s,p,years){
  if(!p||!s?.economy||s.live||s.phase==='ended'||!Number.isInteger(years)||years<1||years>3)return false;
  if(!Number.isInteger(p.contractEnd)||!Number.isFinite(p.salary))return false;
  const remain=(p.dev?.retireAge??50)-p.age;
  return years>=expiry(s,p)&&years<=remain;
 }
 function archetype(p){
  const index=Array.from(String(p.id||'')).reduce((n,c)=>n+c.charCodeAt(0),0)%3;
  return ['Mandataire prudent','Representant ambitieux','Conseiller exigeant'][index];
 }
 function quote(s,id,years,policy,bridge){
  const p=player(s,id),rule=POLICY[policy];
  if(!rule||!eligible(s,p,years)||!bridge||typeof bridge.reservation!=='function'||typeof bridge.fee!=='function')return null;
  const minimum=bridge.reservation(p,'renew',years),fee=bridge.fee(p,'renew');
  if(!Number.isFinite(minimum)||minimum<1000||minimum>100000||!Number.isFinite(fee)||fee<0)return null;
  const wage=Math.max(1000,Math.min(100000,policy==='ferme'?Math.floor(minimum*rule.ratio/100)*100:round100(minimum*rule.ratio)));
  const season=s.season+(s.phase==='ended'?1:0);
  const end=season+years-1;
  return {id:p.id,name:p.name,agent:archetype(p),years,policy,wage,minimum,fee,end,
   deltaWeek:wage-p.salary,deltaSeason:(wage-p.salary)*29,
   totalCommitment:wage*29*years+fee,
   cashAfter:s.clubs[s.club].cash-fee,affordable:s.clubs[s.club].cash>=fee,
   likely:wage>=minimum?'Accord de principe probable':'Contre-offre probable',
   attempts:s.economy.talks?.[String(s.season)+':'+String(s.economy.week)+':renew:'+id]?.attempts||0};
 }
 function history(s){return Array.isArray(s?.v71AgentDesk?.history)?s.v71AgentDesk.history:[];}
 function append(s,item){
  if(!s.v71AgentDesk||s.v71AgentDesk.version!==1)s.v71AgentDesk={version:1,history:[]};
  s.v71AgentDesk.history=[{...item},...history(s)].slice(0,24);
 }
 function perform(s,id,years,policy,bridge){
  if(!s||!bridge||typeof bridge.negotiate!=='function'||typeof bridge.save!=='function')return false;
  const q=quote(s,id,years,policy,bridge);
  if(!q||!q.affordable||q.attempts>=3)return false;
  const old=JSON.stringify(s.v71AgentDesk??null),had=Object.prototype.hasOwnProperty.call(s,'v71AgentDesk');
  // L'ancienne API est l'unique autorite pour les discussions et leur issue.
  const ok=bridge.negotiate(id,'renew',q.wage,years);
  if(!ok)return false;
  const key=String(s.season)+':'+String(s.economy.week)+':renew:'+id;
  const talk=s.economy.talks?.[key];
  if(!talk)return false;
  append(s,{id,season:s.season,week:s.economy.week,years,policy,wage:q.wage,
   status:talk.status,attempt:talk.attempts});
  try{
   if(bridge.save()===false)throw Error('Sauvegarde indisponible');
  }catch(_){
   if(had)s.v71AgentDesk=JSON.parse(old);else delete s.v71AgentDesk;
   // Le moteur contractuel reste source de verite ; ne pas annuler ses tentatives.
   return false;
  }
  if(typeof bridge.render==='function')bridge.render();
  return true;
 }
 function signed(s,key){
  const talk=s?.economy?.talks?.[key];
  if(!talk||talk.kind!=='renew'||talk.status!=='signed')return false;
  const entry=history(s).find(x=>x.id===talk.id&&x.season===s.season&&x.week===s.economy.week);
  if(!entry)return false;
  entry.status='signed';entry.wage=talk.acceptedSalary;
  return true;
 }
 function pick(s){
  const players=roster(s).filter(p=>Number.isInteger(p.contractEnd)&&p.contractEnd<=s.season+1)
   .sort((a,b)=>a.contractEnd-b.contractEnd||b.rating-a.rating||String(a.id).localeCompare(String(b.id)));
  return players;
 }
 function panel(s,bridge){
  if(!s?.economy||!bridge)return '';
  const players=pick(s),selected=players.find(p=>p.id===choice.id)||players[0];
  if(!selected)return '<section class="card" aria-label="Agents V71"><h2>Bureau des agents · V71</h2><p>Aucune prolongation prioritaire a etudier.</p></section>';
  choice.id=selected.id;
  const validYears=[1,2,3].filter(y=>eligible(s,selected,y));
  const years=validYears.includes(choice.years)?choice.years:validYears[0];
  if(years)choice.years=years;
  const policy=POLICY[choice.policy]?choice.policy:'equilibre';
  const q=years?quote(s,selected.id,years,policy,bridge):null;
  const talkKey=String(s.season)+':'+String(s.economy.week)+':renew:'+selected.id;
  const talk=s.economy.talks[talkKey];
  const blocked=!q||!q.affordable||q.attempts>=3||!!s.live;
  const fmt=n=>Number.isFinite(n)?new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(n):'—';
  const log=history(s).slice(0,5).map(x=>'<li>S'+x.season+' J'+(x.week+1)+' · '+escape(player(s,x.id)?.name||x.id)+
   ' · '+escape(POLICY[x.policy]?.label||x.policy)+' · '+fmt(x.wage)+'/sem. · '+escape(x.status)+'</li>').join('');
  return '<section class="card" aria-label="Agents V71"><div class="cardtitle"><h2>Bureau des agents · V71</h2><span class="tag">NEGOCIATION ACTIVE</span></div>'+
   '<p class="help">Choisissez comment aborder un representant fictif. Le moteur de contrats applique toujours les memes regles de salaire, de retrait, de prime, de confirmation et de retraite. Aucun salaire n’est verse avant signature.</p>'+
   '<div class="row budgetline"><label>Joueur<select id="v71-player" onchange="v71Select(\'id\',this.value)">'+
   players.map(p=>'<option value="'+escape(p.id)+'"'+(p.id===selected.id?' selected':'')+'>'+escape(p.name)+' · fin S'+p.contractEnd+'</option>').join('')+'</select></label>'+
   '<label>Duree<select id="v71-years" onchange="v71Select(\'years\',this.value)">'+
   validYears.map(y=>'<option value="'+y+'"'+(y===years?' selected':'')+'>'+y+' saison(s)</option>').join('')+'</select></label>'+
   '<label>Approche<select id="v71-policy" onchange="v71Select(\'policy\',this.value)">'+
   Object.entries(POLICY).map(([k,v])=>'<option value="'+k+'"'+(k===policy?' selected':'')+'>'+escape(v.label)+'</option>').join('')+'</select></label></div>'+
   (q?'<p><strong>'+escape(q.agent)+'</strong> · '+escape(POLICY[policy].detail)+'</p>'+
   '<div class="row"><span>Proposition / semaine</span><strong>'+fmt(q.wage)+'</strong></div>'+
   '<div class="row"><span>Ecart salarial hebdomadaire</span><strong>'+fmt(q.deltaWeek)+'</strong></div>'+
   '<div class="row"><span>Variation sur 29 journees</span><strong>'+fmt(q.deltaSeason)+'</strong></div>'+
   '<div class="row"><span>Prime immediate en cas de signature</span><strong>'+fmt(q.fee)+'</strong></div>'+
   '<div class="row"><span>Engagement theorique ('+years+' saison(s))</span><strong>'+fmt(q.totalCommitment)+'</strong></div>'+
   '<p class="help">Lecture de l’offre : '+escape(q.likely)+'. '+q.attempts+'/3 tentative(s) cette journee. '+
   (q.affordable?'Prime couverte par la tresorerie fictive.':'Tresorerie insuffisante pour la prime.')+
   ' Cette estimation ne signe pas le contrat.</p>'+
   '<button class="dark" type="button" onclick="v71Submit()" '+(blocked?'disabled':'')+'>Envoyer cette proposition au representant</button> '+
   '<button class="small" type="button" onclick="openContract(\''+escape(selected.id)+'\',\'renew\')">Voir la negociation contractuelle</button>':'<p>Aucune duree de prolongation autorisee pour ce joueur.</p>')+
   (talk?'<p class="notice">Derniere reponse : '+escape(talk.message)+' '+(talk.status==='counter'||talk.status==='ready'?'Ouvrez la negociation pour confirmer ou revoir la proposition.':'')+'</p>':'')+
   '<details><summary>Historique des mandats ('+history(s).length+')</summary><ul>'+log+'</ul></details>'+
   '<p class="help">Mandats enregistres dans la sauvegarde, sur 24 entrees maximum. Les anciennes carrieres restent jouables sans V71 ; aucune modification du contrat existant tant que la signature n’est pas confirmee.</p></section>';
 }
 function install(root){
  if(!root||typeof root.contractsPanel!=='function'||typeof root.negotiateContract!=='function'||typeof root.confirmContract!=='function')return false;
  if(root.contractsPanel.__v71Wrapped)return true;
  const state=()=>typeof S!=='undefined'?S:root.S;
  const bridge=()=>({reservation:root.reservationWage,fee:root.contractFee,negotiate:root.negotiateContract,
   save:()=>{root.save();return typeof lastSaveError==='undefined'||!lastSaveError;},
   render:root.render});
  const oldPanel=root.contractsPanel;
  const wrapped=function(){return oldPanel()+panel(state(),bridge());};
  wrapped.__v71Wrapped=true;root.contractsPanel=wrapped;
  const oldConfirm=root.confirmContract;
  root.confirmContract=function(key){
   const ok=oldConfirm(key);
   if(ok&&signed(state(),key))root.save();
   return ok;
  };
  root.v71Select=function(field,value){
   if(field==='id'&&player(state(),value))choice.id=value;
   else if(field==='policy'&&POLICY[value])choice.policy=value;
   else if(field==='years'&&[1,2,3].includes(Number(value)))choice.years=Number(value);
   else return false;
   root.render();return true;
  };
  root.v71Submit=function(){
   const ok=perform(state(),choice.id,choice.years,choice.policy,bridge());
   if(!ok&&typeof root.toast==='function')root.toast('Mandat indisponible : verifiez le budget, la duree et les tentatives.');
   return ok;
  };
  return true;
 }
 return Object.freeze({POLICY,archetype,eligible,quote,perform,signed,panel,install});
});
if(typeof document!=='undefined'&&typeof CDAgentsV71==='object')CDAgentsV71.install(globalThis);
