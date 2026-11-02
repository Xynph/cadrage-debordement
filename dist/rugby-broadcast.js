'use strict';
// Programme TV fictif : aucune émission réelle, aucune citation de journaliste réel.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDRugbyBroadcast=api;api.install();})(typeof globalThis==='object'?globalThis:null,function(){
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const HASH=s=>Array.from(String(s)).reduce((h,c)=>(h*33+c.charCodeAt(0))>>>0,5381);
const SHOW='Troisième Mi-Temps';
const SEGMENTS=Object.freeze(['À la une','Décryptage tactique','Le banc des experts','Face aux micros','La question des supporters']);
function generate(s){
 if(!s||!Number.isInteger(s.season)||!Number.isInteger(s.round))return null;
 const journalists=globalThis.CDPressQuestionBank?.journalists||[];
 const club=s.clubs?.find(c=>c.id===s.club)?.name||'votre club';
 const key=s.season+':'+s.round+':'+s.club;
 const seed=HASH(key);
 const pressure=s.pressRelations?.boardPressure??Math.max(0,100-(s.trust??50));
 const morale=s.morale??50;
 const form=morale<45?'une période de doute':morale>70?'une dynamique encourageante':'une saison disputée';
 const evidence=globalThis.CDMediaNativeAdapter?.collect(s)||[];
 const topResult=evidence.find(e=>e.kind==='result');
 const topInjury=evidence.find(e=>e.kind==='injury');
 const leader=evidence.find(e=>e.kind==='standing');
 const special=topResult&&s.round>=20?'Édition spéciale : le sprint final du championnat':topInjury&&pressure>65?'Édition spéciale : le défi de l'effectif':'Le débrief de la semaine';
 const titles=[
 topResult?topResult.title:club+' : les enjeux d’une semaine décisive',
 leader?'Classement : '+leader.title:'Analyse : les choix collectifs à surveiller lors de la prochaine journée',
 'Table ronde : jusqu’où peut aller '+club+' ?',
 topInjury?'Infirmerie : '+topInjury.title:'Entretien fictif : le management sous pression',
 'Les supporters s’interrogent sur les ambitions du club'
 ];
 const bodies=[
 topResult?topResult.detail:'Notre rédaction revient sur '+form+' et les priorités sportives de '+club+'.',
 leader?leader.detail:'Débat de plateau sur la conquête, la défense et l’utilisation du banc.',
 'Les observateurs confrontent les objectifs annoncés à la progression du collectif.',
 topInjury?topInjury.detail:pressure>65?'L’encadrement devra répondre aux attentes grandissantes de la direction.':'Comment maintenir la confiance et la cohésion du groupe ?',
 'Le public attend une réponse sportive et des décisions lisibles de la part du staff.'
 ];
 return {id:key,name:SHOW,special,season:s.season,week:s.round,segments:SEGMENTS.map((type,i)=>({type,title:titles[i],body:bodies[i],journalist:journalists.length?journalists[(seed+i*3)%journalists.length]:null}))};
}
function render(s){
 const ep=generate(s);if(!ep)return '';
 return '<section class="card" id="cd-rugby-broadcast" aria-label="Magazine rugby fictif"><h3>'+SHOW+' — magazine rugby</h3><p>Saison '+ep.season+', semaine '+ep.week+' · édition fictive générée à partir de votre carrière</p>'+
 ep.segments.map(g=>'<article><h4>'+esc(g.type)+' · '+esc(g.title)+'</h4><p>'+esc(g.body)+'</p><small>Chronique fictive'+(g.journalist?' · '+esc(g.journalist.name)+' ('+esc(g.journalist.outlet)+')':'')+'</small></article>').join('')+
 '<p><small>Émission originale du jeu, indépendante des médias cités. Les propos, analyses et interviews sont simulés et ne reflètent pas les opinions réelles des journalistes.</small></p></section>';
}
function install(){
 if(typeof root.managerOffice!=='function'||root.managerOffice.__cdBroadcast)return false;
 const prev=root.managerOffice;const wrapped=function(){return prev()+render(typeof S==='undefined'?null:S);};wrapped.__cdBroadcast=true;root.managerOffice=wrapped;return true;
}
return Object.freeze({name:SHOW,segments:SEGMENTS,generate,render,install});
});