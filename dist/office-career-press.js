'use strict';
// V58/V60: projections consultatives du bureau. Aucun champ ajoute a la sauvegarde.
(function(root){
 const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const topics={derby:'Derby',injury:'Blessures',form:'Forme sportive',transfers:'Transferts',objectives:'Objectifs'};
 const tones={honest:'Franc',confident:'Confiant',cautious:'Prudent',aggressive:'Offensif'};
 let topic='form',tone='honest';
 function current(){return typeof S==='undefined'?null:S;}
 function coachRisks(s){
  if(!s||!Array.isArray(s.clubs)||!Array.isArray(s.worldManagement?.clubInfo)||!root.CDCoachMarket)return [];
  return s.clubs.filter(c=>c&&c.id!==s.club).map(c=>{
   const w=s.worldManagement.clubInfo[c.id];if(!w||!Number.isInteger(w.coachConfidence)||!Number.isInteger(w.consecutiveLosses))return null;
   try{return {id:c.id,name:c.name,risk:root.CDCoachMarket.dismissalRisk({confidence:w.coachConfidence,consecutiveLosses:w.consecutiveLosses}).risk};}catch(_){return null;}
  }).filter(Boolean).sort((a,b)=>b.risk-a.risk).slice(0,3);
 }
 function advance(state,season){
  let n=state;while(n.season<season)n=root.CDPressRelations.nextSeason(n);
  return n;
 }
 function validatePressCareer(s){
  if(s.pressRelations===undefined)return true;
  if(!root.CDPressRelations||!Number.isInteger(s.club)||!Number.isInteger(s.season)||!Number.isInteger(s.round))throw Error('Carrière presse invalide');
  const p=s.pressRelations;root.CDPressRelations.validate(p);
  if(p.clubId!=='club-'+s.club||p.season>s.season||p.stories.length>40||p.history.length>500||p.used.length>500||p.week>26||p.stories.some(e=>!e||!root.CDPressRelations.topics.includes(e.topic)||!root.CDPressRelations.tones.includes(e.tone)))throw Error('Carrière presse incohérente');
  return true;
 }
 function holdConference(s,selectedTopic=topic,selectedTone=tone){
  if(!s||s.live||!root.CDPressRelations||!topics[selectedTopic]||!tones[selectedTone])return false;
  const api=root.CDPressRelations,initial=s.pressRelations||api.create('club-'+s.club);
  validatePressCareer(s);
  const state=advance(initial,s.season);
  const result=api.interview(state,{topic:selectedTopic,tone:selectedTone,season:s.season,week:s.round});
  const old={press:s.pressRelations,morale:s.morale,trust:s.trust};
  try{
   s.pressRelations=result.state;
   s.morale=Math.max(0,Math.min(100,Math.round(s.morale+result.event.delta.morale)));
   if(Number.isFinite(s.trust))s.trust=Math.max(0,Math.min(100,Math.round(s.trust-result.event.delta.boardPressure)));
   validatePressCareer(s);
   if(typeof save==='function')save();
   if(typeof lastSaveError!=='undefined'&&lastSaveError)throw Error('Enregistrement local impossible');
   if(typeof render==='function')render();
   return true;
  }catch(error){s.morale=old.morale;s.trust=old.trust;if(old.press===undefined)delete s.pressRelations;else s.pressRelations=old.press;throw error;}
 }
 function pressPreview(s,selectedTopic=topic,selectedTone=tone){
  if(!s||!root.CDPressRelations||!topics[selectedTopic]||!tones[selectedTone])return null;
  try{
   const api=root.CDPressRelations,base=api.create('club-'+s.club);
   const existing=s.pressRelations;const state=existing?advance(existing,s.season):base;const result=api.interview(state,{topic:selectedTopic,tone:selectedTone,season:s.season,week:s.round});
   return {media:result.state.mediaTrust-state.mediaTrust,fans:result.state.fanTrust-state.fanTrust,pressure:result.state.boardPressure-state.boardPressure,morale:result.state.morale-state.morale};
  }catch(_){return null;}
 }
 function render(){
  const s=current();if(!s)return '';
  const risks=coachRisks(s),preview=pressPreview(s); const state=s.pressRelations,history=state?.stories||[];
  const item=(entries,selected)=>Object.entries(entries).map(([k,v])=>'<option value="'+k+'"'+(k===selected?' selected':'')+'>'+esc(v)+'</option>').join('');
  const risksHtml=risks.length?'<ul>'+risks.map(r=>'<li>'+esc(r.name)+' : risque indicatif '+r.risk+'/100</li>').join('')+'</ul>':'<p>Indicateurs des bancs adverses indisponibles pour cette carrière.</p>';
  const delta=v=>(v>0?'+':'')+v;
  const pressHtml=preview?'<p>Effets prévus : médias '+delta(preview.media)+', supporters '+delta(preview.fans)+', pression direction '+delta(preview.pressure)+', moral '+delta(preview.morale)+'.</p>':'<p>Projection indisponible ou sujet déjà traité cette semaine.</p>'; const historyHtml=history.length?'<ul>'+history.slice(-5).reverse().map(e=>'<li>Saison '+e.season+', semaine '+e.week+' : '+esc(topics[e.topic])+' — '+esc(tones[e.tone])+'</li>').join('')+'</ul>':'<p>Aucune conférence enregistrée.</p>';
  return '<section class="card" id="cd-office-v58-v60" aria-label="Carrière et relations presse"><h3>Carrière des entraîneurs et presse</h3><h4>Bancs adverses — V58</h4>'+risksHtml+'<p>Pour candidater ou changer de club, utilisez la mobilité native à l’intersaison.</p><h4>Préparer une conférence — V60</h4><label>Sujet <select data-cd-press-topic>'+item(topics,topic)+'</select></label> <label>Ton <select data-cd-press-tone>'+item(tones,tone)+'</select></label><div data-cd-press-preview>'+pressHtml+'</div><small>Simulation de préparation uniquement : aucune conférence enregistrée, aucun effet sur la carrière ou les sauvegardes.</small></section>';
 }
 function install(){
  if(typeof root.managerOffice!=='function')return false;
  if(root.managerOffice.__cdOfficeBridge)return true;
  const previous=root.managerOffice;
  function wrapped(){return previous() + render();}
  wrapped.__cdOfficeBridge=true;root.managerOffice=wrapped;return true;
 }
 if(typeof document!=='undefined')document.addEventListener('click',function(event){if(!event.target?.matches?.('#cd-office-v58-v60 [data-cd-press-confirm]'))return;try{holdConference(current());}catch(error){if(typeof toast==='function')toast('Conférence impossible : '+error.message);}});
 if(typeof document!=='undefined')document.addEventListener('change',function(event){
  const el=event.target;if(!el||!el.matches?.('#cd-office-v58-v60 [data-cd-press-topic], #cd-office-v58-v60 [data-cd-press-tone]'))return;
  if(el.hasAttribute('data-cd-press-topic')&&topics[el.value])topic=el.value;
  if(el.hasAttribute('data-cd-press-tone')&&tones[el.value])tone=el.value;
  const host=document.getElementById('cd-office-v58-v60');if(!host)return;
  const panel=host.querySelector('[data-cd-press-preview]'),v=pressPreview(current());
  if(panel)panel.textContent=v?'Effets théoriques : médias '+(v.media>0?'+':'')+v.media+', supporters '+(v.fans>0?'+':'')+v.fans+', pression direction '+(v.pressure>0?'+':'')+v.pressure+', moral '+(v.morale>0?'+':'')+v.morale+'.':'Projection indisponible.';
 });
 const api=Object.freeze({coachRisks,pressPreview,holdConference,validatePressCareer,render,install});root.validatePressCareer=validatePressCareer;
 root.CDOfficeBridge=api;if(typeof module==='object'&&module.exports)module.exports=api;
 install();
})(typeof globalThis==='object'?globalThis:window);
