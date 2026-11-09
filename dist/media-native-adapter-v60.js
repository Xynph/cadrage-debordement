'use strict';
// Read-only bridge to canonical career facts. Identity labels are web-only;
// native consumers use the IDs and numbers in facts.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDMediaNativeAdapter=api;})(typeof globalThis==='object'?globalThis:null,function(){
const clean=x=>String(x??'').slice(0,180);
function collect(s){
 if(!s||!Number.isInteger(s.season)||!Number.isInteger(s.round)||!Array.isArray(s.clubs))return [];
 const season=s.season,week=s.franceMode?.version===1?s.franceMode.week:s.round,clubs=s.clubs.filter(c=>c&&Number.isInteger(c.id)&&typeof c.name==='string'),names=new Map(clubs.map(c=>[c.id,c.name])),events=[];
 const world=typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s);
 const division=id=>world?CDWorldCareer.leagueId(s,id):s.franceMode?.leagues?Object.keys(s.franceMode.leagues).find(key=>s.franceMode.leagues[key].members.includes(id))||'access':'historical';
 const put=(kind,id,title,detail,facts,r=week,y=season)=>events.push({kind,id:clean(id).slice(0,100),title:clean(title),detail:clean(detail),season:y,week:r,facts});
 if(Array.isArray(s.history))s.history.forEach((match,i)=>{
 if(!match||!Array.isArray(match.pair)||match.pair.length!==2||!match.pair.every(id=>names.has(id))||!Array.isArray(match.score)||match.score.length!==2||!match.score.every(n=>Number.isInteger(n)&&n>=0))return;
 const y=Number.isInteger(match.season)?match.season:season,r=Number.isInteger(match.week)?match.week:Number.isInteger(match.round)&&match.round>=0?match.round:week;if(y>season||y===season&&r>week||y<1||r<0)return;
 const a=names.get(match.pair[0]),b=names.get(match.pair[1]),score=match.score;
 put('result',match.fixtureId||'native-result-'+y+'-'+r+'-'+match.pair.join('-')+'-'+i,a+' '+score[0]+'–'+score[1]+' '+b,'Résultat enregistré en compétition.',{clubIds:match.pair.slice(),score:score.slice(),divisionId:world?match.competitionId:match.leagueId||division(match.pair[0]),phase:match.phase||'league'},r,y);
 });
 const divisions=[...new Set(clubs.map(c=>division(c.id)))];
 const ordered=id=>world?CDWorldCareer.ranked(s,id):typeof CDFranceCompetition!=='undefined'&&s.franceMode?.version===1?CDFranceCompetition.ranked(s,id):typeof S!=='undefined'&&s===S&&typeof ranked==='function'?ranked():clubs.slice().sort((a,b)=>b.points-a.points||(b.pf-b.pa)-(a.pf-a.pa)||b.pf-a.pf||a.id-b.id);
 divisions.forEach(id=>ordered(id).filter(c=>division(c.id)===id&&Number.isFinite(c.points)&&Number.isFinite(c.played)).forEach((c,i)=>put('standing','native-standing-'+season+'-'+week+'-'+c.id,(i+1)+'e : '+c.name,c.points+' points en '+c.played+' rencontres.',{clubId:c.id,divisionId:id,rank:i+1,points:c.points,played:c.played})));
 clubs.forEach(c=>{if(!Array.isArray(c.players))return;c.players.filter(p=>p&&Number.isFinite(p.injury)&&p.injury>0&&typeof p.name==='string').slice(0,2).forEach(p=>put('injury','native-injury-'+season+'-'+week+'-'+c.id+'-'+clean(p.id||p.name),p.name+' indisponible ('+c.name+')','Indisponibilité actuellement enregistrée.',{clubId:c.id,playerId:p.id,divisionId:division(c.id),weeks:Math.round(p.injury)}));});
 return events;
}
return Object.freeze({collect});
});
