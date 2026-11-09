'use strict';
const files=Object.freeze([]),commands=Object.freeze([]);
// Serialized in the native VM. A view of existing results, never a new history.
function factory(){
 const finite=n=>typeof n==='number'&&Number.isFinite(n)&&n>=0;
 const pair=a=>Array.isArray(a)&&a.length===2;
 const name=(s,id)=>s.clubs.find(c=>c.id===id)?.name||'Club #'+id;
 function matches(s){
  return (s.history||[]).filter(r=>pair(r.pair)&&r.pair.includes(s.club)&&pair(r.score)&&r.score.every(finite)&&(r.season===undefined||r.season===s.season)).slice(-5).map(r=>{
   const side=r.pair.indexOf(s.club),opponent=r.pair[1-side],pf=r.score[side],pa=r.score[1-side];
   const decidedAfterTie=pf===pa&&r.pair.includes(r.winner),outcome=decidedAfterTie?(r.winner===s.club?'V':'D'):pf>pa?'V':pf<pa?'D':'N';
   const raw=r.stats?.[side],stats={};
   for(const k of ['lineouts','lineoutsWon','scrums','scrumsWon','penalties'])if(finite(raw?.[k]))stats[k]=raw[k];
   return {season:s.season,round:r.round??null,week:r.week??null,phase:r.phase??null,fixtureId:r.fixtureId??null,opponent,opponentName:name(s,opponent),home:side===0,pointsFor:pf,pointsAgainst:pa,triesFor:pair(r.tries)&&r.tries.every(finite)?r.tries[side]:null,outcome,decidedAfterTie,stats};
  });
 }
 function summary(rows){return {played:rows.length,won:rows.filter(r=>r.outcome==='V').length,drawn:rows.filter(r=>r.outcome==='N').length,lost:rows.filter(r=>r.outcome==='D').length,pointsFor:rows.reduce((n,r)=>n+r.pointsFor,0),pointsAgainst:rows.reduce((n,r)=>n+r.pointsAgainst,0)};}
 function setPiece(rows,key){
  const games=rows.filter(r=>finite(r.stats[key])&&finite(r.stats[key+'Won'])&&r.stats[key+'Won']<=r.stats[key]);
  const attempts=games.reduce((n,r)=>n+r.stats[key],0),won=games.reduce((n,r)=>n+r.stats[key+'Won'],0);
  return {matches:games.length,attempts,won,rate:attempts>0?won/attempts:null};
 }
 function project(){
  const s=typeof S==='undefined'?null:S,base={available:!!s,source:'S.history',season:s?.season??null,clubId:s?.club??null,window:5,matches:[],summary:summary([]),metrics:null,comparison:null,advice:[],notice:'Cinq dernières rencontres conservées du club actuel, saison actuelle. Statistiques collectives du moteur ; les données absentes restent inconnues. Les écarts ne prouvent pas une cause. Aucun historique individuel par match n’est déduit.'};
  if(!s)return base;
  const rows=matches(s),discipline=rows.filter(r=>finite(r.stats.penalties)),penalties=discipline.reduce((n,r)=>n+r.stats.penalties,0);
  base.matches=rows.slice().reverse();base.summary=summary(rows);
  base.metrics={lineouts:setPiece(rows,'lineouts'),scrums:setPiece(rows,'scrums'),penalties:{matches:discipline.length,total:penalties,average:discipline.length?penalties/discipline.length:null}};
  if(rows.length===5){
   const group=a=>({count:a.length,pointsFor:a.reduce((n,r)=>n+r.pointsFor,0)/a.length,pointsAgainst:a.reduce((n,r)=>n+r.pointsAgainst,0)/a.length});
   const recent=group(rows.slice(-3)),previous=group(rows.slice(0,2));
   base.comparison={recent,previous,pointsForDelta:recent.pointsFor-previous.pointsFor,pointsAgainstDelta:recent.pointsAgainst-previous.pointsAgainst,notice:'Trois rencontres récentes comparées aux deux précédentes. Adversaires, lieux et phases peuvent différer ; ce constat ne mesure pas l’effet d’une consigne.'};
  }
  for(const [key,label]of [['lineouts','touche'],['scrums','mêlée']]){
   const m=base.metrics[key];if(m.matches<3||m.attempts<10||m.rate>.55)continue;
   base.advice.push({key,title:'Conquête à examiner : '+label,evidence:m.won+' / '+m.attempts+' ballons conservés sur '+m.matches+' rencontres documentées.',action:'Comparer la composition du pack et le travail de conquête. Ce bilan collectif ne désigne pas un joueur responsable.'});
  }
  if(discipline.length>=3&&base.metrics.penalties.average>=9)base.advice.push({key:'discipline',title:'Discipline à examiner',evidence:penalties+' pénalités concédées sur '+discipline.length+' rencontres documentées.',action:'Revoir les consignes et la préparation disciplinaire, puis observer les prochaines rencontres. Ce constat ne permet pas d’attribuer les fautes à un joueur.'});
  return base;
 }
 return {project,validate:()=>true,installHooks:()=>true};
}
module.exports={files,commands,factory};
