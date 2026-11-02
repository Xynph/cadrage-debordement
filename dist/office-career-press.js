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
 function pressPreview(s,selectedTopic=topic,selectedTone=tone){
  if(!s||!root.CDPressRelations||!topics[selectedTopic]||!tones[selectedTone])return null;
  try{
   const api=root.CDPressRelations,base=api.create('club-'+s.club);
   const result=api.interview(base,{topic:selectedTopic,tone:selectedTone,season:1,week:0});
   return {media:result.state.mediaTrust-base.mediaTrust,fans:result.state.fanTrust-base.fanTrust,pressure:result.state.boardPressure-base.boardPressure,morale:result.state.morale-base.morale};
  }catch(_){return null;}
 }
 function render(){
  const s=current();if(!s)return '';
  const risks=coachRisks(s),preview=pressPreview(s);
  const item=(entries,selected)=>Object.entries(entries).map(([k,v])=>'<option value="'+k+'"'+(k===selected?' selected':'')+'>'+esc(v)+'</option>').join('');
  const risksHtml=risks.length?'<ul>'+risks.map(r=>'<li>'+esc(r.name)+' : risque indicatif '+r.risk+'/100</li>').join('')+'</ul>':'<p>Indicateurs des bancs adverses indisponibles pour cette carrière.</p>';
  const delta=v=>(v>0?'+':'')+v;
  const pressHtml=preview?'<p>Effets théoriques : médias '+delta(preview.media)+', supporters '+delta(preview.fans)+', pression direction '+delta(preview.pressure)+', moral '+delta(preview.morale)+'.</p>':'<p>Projection indisponible.</p>';
  return '<section class="card" id="cd-office-v58-v60" aria-label="Carrière et relations presse"><h3>Carrière des entraîneurs et presse</h3><h4>Bancs adverses — V58</h4>'+risksHtml+'<p>Pour candidater ou changer de club, utilisez la mobilité native à l’intersaison.</p><h4>Préparer une conférence — V60</h4><label>Sujet <select data-cd-press-topic>'+item(topics,topic)+'</select></label> <label>Ton <select data-cd-press-tone>'+item(tones,tone)+'</select></label><div data-cd-press-preview>'+pressHtml+'</div><small>Simulation de préparation uniquement : aucune conférence enregistrée, aucun effet sur la carrière ou les sauvegardes.</small></section>';
 }
 function install(){
  if(typeof root.managerOffice!=='function')return false;
  if(root.managerOffice.__cdOfficeBridge)return true;
  const previous=root.managerOffice;
  function wrapped(){return previous() + render();}
  wrapped.__cdOfficeBridge=true;root.managerOffice=wrapped;return true;
 }
 if(typeof document!=='undefined')document.addEventListener('change',function(event){
  const el=event.target;if(!el||!el.matches?.('#cd-office-v58-v60 [data-cd-press-topic], #cd-office-v58-v60 [data-cd-press-tone]'))return;
  if(el.hasAttribute('data-cd-press-topic')&&topics[el.value])topic=el.value;
  if(el.hasAttribute('data-cd-press-tone')&&tones[el.value])tone=el.value;
  const host=document.getElementById('cd-office-v58-v60');if(!host)return;
  const panel=host.querySelector('[data-cd-press-preview]'),v=pressPreview(current());
  if(panel)panel.textContent=v?'Effets théoriques : médias '+(v.media>0?'+':'')+v.media+', supporters '+(v.fans>0?'+':'')+v.fans+', pression direction '+(v.pressure>0?'+':'')+v.pressure+', moral '+(v.morale>0?'+':'')+v.morale+'.':'Projection indisponible.';
 });
 const api=Object.freeze({coachRisks,pressPreview,render,install});
 root.CDOfficeBridge=api;if(typeof module==='object'&&module.exports)module.exports=api;
 install();
})(typeof globalThis==='object'?globalThis:window);
