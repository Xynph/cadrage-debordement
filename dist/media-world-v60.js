'use strict';
// V60: fictional media coverage, grounded only in the current simulated career.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDMediaWorld=api;api.install();})(typeof globalThis==='object'?globalThis:null,function(){
const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const hash=s=>Array.from(String(s)).reduce((h,c)=>(h*31+c.charCodeAt(0))>>>0,2166136261);
const types=['Débrief de la journée','Le marché des transferts','La relève','Enquête tactique','L’édito des supporters','Entretien du vestiaire','Les enjeux de demain'];
function headlines(s){
 if(!s||!Array.isArray(s.clubs)||!Number.isInteger(s.season)||!Number.isInteger(s.round))return [];
 const week=s.round,season=s.season;
 const clubs=s.clubs.filter(c=>c&&typeof c.name==='string'&&Number.isInteger(c.id));
 if(!clubs.length)return [];
 const roster=globalThis.CDPressQuestionBank?.journalists||[];
 return types.map((type,i)=>{
  const club=clubs[(hash(season+':'+week+':'+i)%clubs.length)];
  const mine=club.id===s.club;
  const topic=['le prochain défi','les choix de rotation','la gestion des espoirs','les équilibres défensifs','les ambitions du groupe','le projet sportif','les points à prendre'][i];
  const title=club.name+' : '+topic;
  const line=mine&&s.morale<45?'Le club traverse une période délicate ; les prochaines décisions seront scrutées.':mine&&s.morale>75?'La dynamique est favorable, mais le calendrier impose de rester vigilant.':'Notre rédaction présente les enjeux de la semaine sans préjuger des résultats.';
  const source=roster.length?roster[(hash(club.id+':'+season+':'+week+':'+i))%roster.length]:null;
  return {id:season+':'+week+':'+club.id+':'+i,clubId:club.id,kind:type,title,summary:line,byline:source&&{name:source.name,outlet:source.outlet},isUserClub:mine};
 });
}
function issue(s){if(!s||!Number.isInteger(s.season)||!Number.isInteger(s.round))return null;return {id:s.season+':'+s.round,season:s.season,week:s.round,articles:headlines(s)};}
function render(s){
 const edition=issue(s);if(!edition)return '';
 const evidence=globalThis.CDMediaEvidence,bridge=globalThis.CDMediaNativeAdapter;const derived=bridge?bridge.collect(s):[];const factual=evidence?evidence.html([...derived,...(Array.isArray(s.mediaEvents)?s.mediaEvents:[])],{season:s.season,week:s.round}):'';
 return factual+'<section class="card" id="cd-media-world"><h3>Troisième Mi-Temps · Le fil rugby</h3><p>Édition de carrière · saison '+edition.season+', semaine '+edition.week+'</p><details><summary>Explorer les '+edition.articles.length+' chroniques du championnat</summary>'+
 edition.articles.map(a=>'<article><h4>'+escape(a.kind)+' · '+escape(a.title)+'</h4><p>'+escape(a.summary)+'</p><small>'+escape(a.byline?a.byline.name+' · '+a.byline.outlet:'Rédaction de Troisième Mi-Temps')+' · chronique simulée</small></article>').join('')+
 '</details><p><small>Actualités fictives fondées uniquement sur les données disponibles du jeu. Les noms des journalistes identifient des intervenants simulés, sans déclaration ni approbation réelle.</small></p></section>';
}
function install(){if(typeof root.managerOffice!=='function'||root.managerOffice.__cdMediaWorld)return false;const previous=root.managerOffice;function wrapped(){return previous()+render(typeof S==='undefined'?null:S);}wrapped.__cdMediaWorld=true;root.managerOffice=wrapped;return true;}
return Object.freeze({types,headlines,issue,render,install});
});