'use strict';
// Read-only bridge to canonical Cadrage Debordement career state. Never invent match outcomes.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDMediaNativeAdapter=api;})(typeof globalThis==='object'?globalThis:null,function(){
const clean=x=>String(x??'').slice(0,180);
function collect(s){
 if(!s||!Number.isInteger(s.season)||!Number.isInteger(s.round)||!Array.isArray(s.clubs))return [];
 const season=s.season,week=s.round,clubs=s.clubs.filter(c=>c&&Number.isInteger(c.id)&&typeof c.name==='string'),names=new Map(clubs.map(c=>[c.id,c.name])),events=[];
 const put=(kind,id,title,detail,r=week)=>events.push({kind,id:clean(id),title:clean(title),detail:clean(detail).slice(0,500),season,week:r});
 if(Array.isArray(s.history))s.history.forEach((match,i)=>{
 if(!match||!Array.isArray(match.pair)||match.pair.length!==2||!match.pair.every(id=>names.has(id))||!Array.isArray(match.score)||match.score.length!==2||!match.score.every(n=>Number.isInteger(n)&&n>=0))return;
 const r=Number.isInteger(match.round)&&match.round>=0?match.round:week;if(r>week)return;
 const a=names.get(match.pair[0]),b=names.get(match.pair[1]),score=match.score;
 put('result','native-result-'+season+'-'+r+'-'+match.pair.join('-')+'-'+i,a+' '+score[0]+'–'+score[1]+' '+b,'Résultat enregistré en '+(match.phase==='league'?'championnat':'compétition')+'.',r);
 });
 const ranked=clubs.filter(c=>Number.isFinite(c.points)&&Number.isFinite(c.played)).sort((a,b)=>b.points-a.points||(b.pf-b.pa)-(a.pf-a.pa)||a.id-b.id);
 ranked.slice(0,5).forEach((c,i)=>put('standing','native-standing-'+season+'-'+week+'-'+c.id,(i+1)+'e : '+c.name,c.points+' points en '+c.played+' rencontres.'));
 clubs.forEach(c=>{if(!Array.isArray(c.players))return;c.players.filter(p=>p&&Number.isFinite(p.injury)&&p.injury>0&&typeof p.name==='string').slice(0,2).forEach(p=>put('injury','native-injury-'+season+'-'+week+'-'+c.id+'-'+clean(p.id||p.name),p.name+' indisponible ('+c.name+')','Blessure enregistrée : '+Math.round(p.injury)+' semaine(s) restante(s).'));});
 return events;
}
return Object.freeze({collect});
});