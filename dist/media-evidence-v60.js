'use strict';
// V60: publication fondée sur des faits explicitement fournis par le moteur, sans invention.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDMediaEvidence=api;})(typeof globalThis==='object'?globalThis:null,function(){
const kinds=Object.freeze(['result','standing','injury','transfer','performance','discipline','career']);
const esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function validEvent(e){return e&&kinds.includes(e.kind)&&typeof e.id==='string'&&e.id.length>0&&e.id.length<=100&&typeof e.title==='string'&&e.title.length>0&&e.title.length<=180&&typeof e.detail==='string'&&e.detail.length<=500&&Number.isInteger(e.season)&&e.season>0&&Number.isInteger(e.week)&&e.week>=0;}
function curate(events,{season,week,limit=12}={}){
 if(!Array.isArray(events)||!Number.isInteger(season)||!Number.isInteger(week)||!Number.isInteger(limit)||limit<1||limit>30)throw Error('Dossier média invalide');
 const seen=new Set();return events.filter(validEvent).filter(e=>e.season<season||(e.season===season&&e.week<=week)).sort((a,b)=>b.season-a.season||b.week-a.week||a.id.localeCompare(b.id)).filter(e=>{if(seen.has(e.id))return false;seen.add(e.id);return true;}).slice(0,limit).map(e=>Object.freeze({...e}));
}
function special(events,opts){const picked=curate(events,opts);const major=picked.filter(e=>['result','transfer','injury','career'].includes(e.kind));return major.length?{headline:'Édition spéciale · '+major[0].title,articles:major.slice(0,5)}:null;}
function html(events,opts){const data=curate(events,opts);const latest=special(events,opts);return '<section class="card" id="cd-v60-evidence"><h3>Troisième Mi-Temps · Les faits du championnat</h3>'+(latest?'<h4>'+esc(latest.headline)+'</h4>':'')+(data.length?data.map(e=>'<article><h4>'+esc(e.title)+'</h4><p>'+esc(e.detail)+'</p><small>Saison '+e.season+' · journée '+e.week+' · '+esc(e.kind)+'</small></article>').join(''):'<p>Aucune information sportive vérifiée disponible pour cette édition.</p>')+'<small>Informations issues exclusivement des événements consignés par la simulation.</small></section>';}
return Object.freeze({kinds,validEvent,curate,special,html});
});