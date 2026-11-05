'use strict';
// V64 — Vestiaire vivant : les interactions V36/V37 ont désormais des conséquences sportives.
// Aucun nouveau champ dans la sauvegarde : satisfaction, moral collectif et journal V37 existants.
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDVestiaireV64=api;
})(typeof globalThis==='object'?globalThis:null,function(){
 const bounded=(n,min,max)=>Math.max(min,Math.min(max,Math.round(n)));
 const safe=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 function status(p){
  const score=p?.satisfaction?.score;
  if(!Number.isFinite(score))return 'Non suivi';
  return score<40?'En crise':score<55?'Fragile':score>=80?'Épanoui':'Stable';
 }
 // Capture la photographie AVANT que V36 n'efface une promesse soldée.
 function snapshot(players){
  return (Array.isArray(players)?players:[]).map(p=>({
   id:p.id,score:p.satisfaction?.score??65,
   minutes:p.dev?.minutes??0,
   promise:p.satisfaction?.promise?{...p.satisfaction.promise}:null,
   last:p.satisfaction?.history?.length??0,
   injury:!!p.injury
  }));
 }
 function roundImpact(players,before){
  const prior=new Map((Array.isArray(before)?before:[]).map(x=>[x.id,x]));
  const changes=[],warnings=[];
  for(const p of Array.isArray(players)?players:[]){
   const st=p.satisfaction,old=prior.get(p.id);
   if(!st||!old)continue;
   const played=Math.max(0,(p.dev?.minutes??0)-old.minutes);
   const resolved=old.promise&&!st.promise;
   const last=resolved?st.history?.[st.history.length-1]:null;
   // Ne pas punir un blesse ; la promesse V36 est alors suspendue.
   let delta=0;
   if(!p.injury&&!old.injury&&!old.promise){
    if(played>=40&&st.score<75)delta=1;
    else if(played===0&&st.score<60)delta=-1;
   }
   if(delta)st.score=bounded(st.score+delta,20,95);
   if(resolved&&last?.status==='broken')warnings.push({id:p.id,name:p.name,type:'broken'});
   else if(resolved&&last?.status==='kept')warnings.push({id:p.id,name:p.name,type:'kept'});
   if(delta)changes.push({id:p.id,name:p.name,delta});
  }
  const scores=players.map(p=>p.satisfaction?.score).filter(Number.isFinite);
  const average=scores.length?scores.reduce((a,b)=>a+b,0)/scores.length:65;
  const crises=scores.filter(v=>v<40).length;
  const broken=warnings.filter(x=>x.type==='broken').length;
  const kept=warnings.filter(x=>x.type==='kept').length;
  // Effet reel : le moteur existant prend S.morale dans strength() et les matchs.
  // Amplitude plafonnee : evite toute inflation sur les longues carrieres.
  const moodDelta=bounded((average<48?-2:average>=78?1:0)-Math.min(2,crises)+Math.min(2,kept)-Math.min(3,broken),-5,3);
  return {changes,warnings,average:Math.round(average),crises,moodDelta};
 }
 function meetingImpact(choice,firstForRound){
  if(!firstForRound)return {morale:0,trust:0};
  if(choice==='rassurer')return {morale:1,trust:0};
  if(choice==='clarifier')return {morale:0,trust:1};
  return {morale:0,trust:0}; // ecouter apporte deja +2 en satisfaction V37
 }
 function panel(s,players){
  if(!s||!Array.isArray(players))return '';
  if(s.satisfactionVersion!==1||s.relationsVersion!==1)
   return '<section class="card" aria-label="Vestiaire V64"><h2>Vestiaire · V64</h2><p>Activez le suivi V36/V37 dans les relations du club pour obtenir les echanges et leurs effets sur le collectif.</p></section>';
  const sorted=[...players].sort((a,b)=>(a.satisfaction?.score??65)-(b.satisfaction?.score??65)||String(a.name).localeCompare(String(b.name),'fr'));
  const mean=sorted.length?Math.round(sorted.reduce((n,p)=>n+(p.satisfaction?.score??65),0)/sorted.length):65;
  const unstable=sorted.filter(p=>(p.satisfaction?.score??65)<55).length;
  const crisis=sorted.filter(p=>(p.satisfaction?.score??65)<40).length;
  const blocked=!!s.live||Object.keys(s.economy?.talks||{}).length>0||s.phase==='ended';
  const weekly=(s.economy?.relationLog||[]).some(x=>x.kind==='coach'&&x.season===s.season&&x.round===s.round);
  const options=[['ecouter','Écouter · +2 satisfaction'],['rassurer','Rassurer · +1 satisfaction, +1 moral collectif si premier entretien de la journée'],['clarifier','Clarifier · +1 confiance de direction si premier entretien de la journée']];
  return '<section class="card" aria-label="Vestiaire V64">'+
    '<div class="cardtitle"><h2>Vestiaire · Climat humain</h2><span class="tag">'+unstable+' joueur(s) sous tension</span></div>'+
    '<p class="help">Moral collectif '+s.morale+'/100 (influe sur la force de votre XV) · satisfaction moyenne '+mean+'/100 · '+crisis+' crise(s). Les minutes reellement jouees et les promesses modifient la satisfaction ; les bilans hebdomadaires ajustent le moral. Aucune intervention possible pendant un match.</p>'+
    (weekly?'<p class="help">Effet collectif de l’entretien deja utilise cette journee. Les autres entretiens restent individuels.</p>':'')+
    '<details><summary>Ouvrir les entretiens et tensions de l’effectif</summary>'+
    '<div class="tablewrap"><table><thead><tr><th>Joueur</th><th>Satisfaction</th><th>Engagement</th><th>Entretien</th></tr></thead><tbody>'+
    sorted.map(p=>{
     const st=p.satisfaction||{},promise=st.promise;
     const already=st.coachMeeting?.season===s.season&&st.coachMeeting?.week===s.economy?.week;
     const available=!blocked&&!already;
     const choices=available?options.map(([key,label])=>'<button class="small" type="button" onclick="coachConversation(\''+safe(p.id)+'\',\''+key+'\')">'+safe(label)+'</button>').join(' '):'<small>'+(already?'Entretien deja effectue cette semaine':'Entretien indisponible')+'</small>';
     return '<tr><td>'+safe(p.name)+'</td><td>'+safe(status(p))+' · '+(st.score??65)+'/100</td><td>'+ (promise?'Promesse '+safe(promise.target)+' · '+promise.completed+'/3 matchs':'Aucune promesse active')+'</td><td>'+choices+'</td></tr>';
    }).join('')+
    '</tbody></table></div></details>'+
    '<p class="help">Les promesses de temps de jeu sont gerees dans le panneau Satisfaction et promesses. La discussion « Écouter » ameliore le joueur ; « Rassurer » ou « Clarifier » peut aussi modifier le moral collectif ou la confiance. Un seul bonus collectif par journee.</p></section>';
 }
 function install(root){
  if(!root||typeof root.recordSatisfactionRound!=='function'||typeof root.coachConversation!=='function'||typeof root.managerTeamView!=='function')return false;
  if(root.recordSatisfactionRound.__v64Wrapped)return true;
  const oldRound=root.recordSatisfactionRound;
  function record(l){
   const s=root.S;
   const can=!!s&&s.satisfactionVersion===1&&s.relationsVersion===1&&l?.finished&&l.pair?.[l.userSide]===s.club;
   const prior=can?snapshot(s.clubs[s.club].players):null;
   const result=oldRound(l);
   if(!result||!can)return result;
   const impact=roundImpact(s.clubs[s.club].players,prior);
   s.morale=bounded(s.morale+impact.moodDelta,25,98);
   if(impact.warnings.length&&typeof root.managerMessage==='function')
    root.managerMessage('Vestiaire : engagements de temps de jeu',impact.warnings.slice(0,3).map(x=>x.name+' : '+(x.type==='broken'?'promesse non tenue':'promesse honoree')).join(' · '),'staff','team');
   return result;
  }
  record.__v64Wrapped=true;
  root.recordSatisfactionRound=record;
  const oldTalk=root.coachConversation;
  root.coachConversation=function(id,choice){
   const s=root.S;
   const first=!!s&&!(s.economy?.relationLog||[]).some(x=>x.kind==='coach'&&x.season===s.season&&x.round===s.round);
   const ok=oldTalk(id,choice);
   if(!ok||!s)return ok;
   const bonus=meetingImpact(choice,first);
   if(bonus.morale)s.morale=bounded(s.morale+bonus.morale,25,98);
   if(bonus.trust)s.trust=bounded(s.trust+bonus.trust,0,100);
   if((bonus.morale||bonus.trust)&&typeof root.save==='function')root.save();
   return ok;
  };
  const oldTeam=root.managerTeamView;
  root.managerTeamView=function(){
   const s=root.S;
   return oldTeam()+(s?.clubs?.[s.club]?panel(s,s.clubs[s.club].players):'');
  };
  return true;
 }
 return Object.freeze({snapshot,roundImpact,meetingImpact,status,panel,install});
});
if(typeof document!=='undefined'&&typeof CDVestiaireV64==='object')CDVestiaireV64.install(globalThis);
