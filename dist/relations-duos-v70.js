'use strict';
// V70 — Liens entre joueurs : mecanique distincte du moral individuel V64.
// Les duos sont des simulations de relations, pas des faits sur des personnes reelles.
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDRelationsV70=api;
})(typeof globalThis==='object'?globalThis:null,function(){
 const clamp=(v,a,b)=>Math.max(a,Math.min(b,Math.round(v)));
 const escape=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const ACTIONS=Object.freeze({
  duo:{label:'Construire des automatismes',detail:'Deux joueurs travaillent ensemble : lien +18, condition −2 chacun.'},
  mediation:{label:'Désamorcer une rivalité',detail:'Dialogue encadré : lien +25, confiance de direction −1.'},
  mentorat:{label:'Confier un relais au leader',detail:'Le leader accompagne un partenaire : lien +15, condition du leader −2.'}
 });
 function roster(s){return Array.isArray(s?.clubs?.[s.club]?.players)?s.clubs[s.club].players:[]}
 function seasonKey(s){return String(s?.season)+':'+String(s?.economy?.week)}
 function pairKey(a,b){return [a,b].sort().join('|')}
 function records(s){return Array.isArray(s?.v70Relations?.pairs)?s.v70Relations.pairs:[]}
 function leader(s){
  const available=roster(s).filter(p=>!p.injury&&p.condition>=60&&(p.satisfaction?.score??65)>=55);
  return available.sort((a,b)=>(b.skills?.mental??b.rating??50)-(a.skills?.mental??a.rating??50)||String(a.id).localeCompare(String(b.id)))[0]||null;
 }
 function rawRisk(a,b){
  const low=Math.min(a.satisfaction?.score??65,b.satisfaction?.score??65);
  // Un risque sportif suppose, jamais une rivalite biographique inventee.
  return low<40?-20:low<55&&a.fam===b.fam?-15:0;
 }
 function relation(s,a,b){
  const pa=roster(s).find(p=>p.id===a),pb=roster(s).find(p=>p.id===b);
  if(!pa||!pb||pa===pb)return null;
  const entry=records(s).find(x=>x.key===pairKey(a,b));
  const value=entry&&Number.isFinite(entry.score)?clamp(entry.score,-30,60):rawRisk(pa,pb);
  return {a:pa,b:pb,key:pairKey(a,b),score:value,
   label:value>=25?'Affinité solide':value>=8?'Automatismes en progrès':value<=-12?'Risque de rivalité':'Relation neutre'};
 }
 function allowed(s){return !!s&&s.phase==='league'&&!s.live&&!s.trained&&Number.isInteger(s?.economy?.week)&&
  Array.isArray(s?.manager?.inbox)&&s.v70Relations?.last!==seasonKey(s)&&roster(s).length>=2}
 function preview(s,mode,a,b){
  if(!Object.hasOwn(ACTIONS,mode))return null;
  const rel=relation(s,a,b);if(!rel)return null;
  if(rel.a.injury||rel.b.injury||rel.a.condition<45||rel.b.condition<45)return null;
  if(mode==='mentorat'&&leader(s)?.id!==a)return null;
  if(mode==='mediation'&&rel.score>=8)return null;
  const delta=mode==='mediation'?25:mode==='mentorat'?15:18;
  return {...rel,mode,before:rel.score,after:clamp(rel.score+delta,-30,60),
   costA:mode==='duo'||mode==='mentorat'?2:0,costB:mode==='duo'?2:0,
   trustCost:mode==='mediation'?1:0};
 }
 function perform(s,mode,a,b,{save,render,message}={}){
  if(!allowed(s)||typeof save!=='function')return false;
  const p=preview(s,mode,a,b);if(!p)return false;
  const old=JSON.stringify(s.v70Relations??null),had=Object.prototype.hasOwnProperty.call(s,'v70Relations');
  const ca=p.a.condition,cb=p.b.condition,trust=s.trust,priorInbox=Array.isArray(s.manager?.inbox)?s.manager.inbox.map(x=>x):null,serial=s.manager?.serial;
  try{
   const oldPairs=records(s).filter(x=>x.key!==p.key);
   s.v70Relations={version:1,last:seasonKey(s),pairs:[...oldPairs,{key:p.key,a:p.a.id,b:p.b.id,score:p.after,season:s.season,week:s.economy.week}].slice(-8)};
   p.a.condition=clamp(ca-p.costA,0,100);p.b.condition=clamp(cb-p.costB,0,100);
   if(p.trustCost)s.trust=clamp(trust-p.trustCost,0,100);
   if(typeof message==='function')message('Relations de groupe : '+ACTIONS[mode].label,
    p.a.name+' / '+p.b.name+' : '+p.before+' → '+p.after+' (simulation du lien).','relations-v70','team');
   if(save()===false)throw Error('Sauvegarde impossible');
   if(typeof render==='function')render();
   return true;
  }catch(_){
   if(had)s.v70Relations=JSON.parse(old);else delete s.v70Relations;
   p.a.condition=ca;p.b.condition=cb;s.trust=trust;
   if(priorInbox)s.manager.inbox=priorInbox;
   if(Number.isFinite(serial))s.manager.serial=serial;
   return false;
  }
 }
 function matchSnapshot(s,match){
  if(!s||!match||match.userSide<0||match.pair[match.userSide]!==s.club)return null;
  const ids=new Set(match.sheets[match.userSide].initial);
  const starters=roster(s).filter(p=>ids.has(p.id)&&!p.injury);
  const valid=new Set(starters.map(p=>p.id));
  const existing=records(s).filter(x=>valid.has(x.a)&&valid.has(x.b)&&Number.isFinite(x.score))
   .map(x=>({a:x.a,b:x.b,score:clamp(x.score,-30,60)}));
  const keys=new Set(existing.map(x=>pairKey(x.a,x.b))),risks=[];
  // Rivalites *potentielles* fondees sur les profils visibles : aucune biographie inventee.
  for(let i=0;i<starters.length;i++)for(let j=i+1;j<starters.length;j++){
   const a=starters[i],b=starters[j],key=pairKey(a.id,b.id);
   if(keys.has(key))continue;
   const score=rawRisk(a,b);
   if(score<0)risks.push({a:a.id,b:b.id,score});
  }
  risks.sort((a,b)=>a.score-b.score||pairKey(a.a,a.b).localeCompare(pairKey(b.a,b.b)));
  const duos=[...existing,...risks.slice(0,2)].slice(0,8);
  return duos.length?{version:1,side:match.userSide,duos}:null;
 }
 function matchBonus(match,side,kind){
  const data=match?.v70Relations;
  if(!data||data.version!==1||side!==data.side||kind!=='attack'||match.finished)return 0;
  const active=new Set((match.sheets?.[side]?.on||[]).filter(Boolean));
  const relevant=data.duos.filter(p=>active.has(p.a)&&active.has(p.b));
  // Maximum deux liens influents. +1.8 point au mieux, -1.2 en crise.
  return Math.max(-.012,Math.min(.018,relevant.slice(0,2).reduce((sum,p)=>sum+
   (p.score>=8?Math.min(.009,p.score*.0003):p.score<=-12?Math.max(-.006,p.score*.0003):0),0)));
 }
 function panel(s){
  if(!s?.manager||!s?.economy||s.phase==='ended')return '';
  const players=roster(s).filter(p=>!p.injury).slice().sort((a,b)=>String(a.name).localeCompare(String(b.name),'fr'));
  if(players.length<2)return '';
  const can=allowed(s),head=leader(s),pairs=records(s),escapeOption=p=>'<option value="'+escape(p.id)+'">'+escape(p.name)+'</option>';
  const first=players.find(x=>x.id===head?.id)||players[0],second=players.find(x=>x.id!==first.id)||players[1];
  const show=(p,q)=>{const rel=relation(s,p.id,q.id);return rel?rel.label+' ('+rel.score+')':'—'};
  return '<section class="card v70-relations" aria-label="Relations de groupe V70">'+
   '<div class="cardtitle"><h2>Duos, rivalités et leadership · V70</h2><span class="tag">'+(can?'INTERVENTION DISPONIBLE':'LECTURE SEULE')+'</span></div>'+
   '<p class="help">Le vestiaire V64 suit les personnes ; ici, vous gérez les liens entre joueurs. Leurs affinités n\'influencent le match que si les deux sont simultanément sur le terrain. Effet limité à ±1,8 point de résolution offensive.</p>'+
   '<p><strong>Leader pressenti :</strong> '+escape(head?.name||'Aucun joueur assez disponible')+' · sélection basée sur qualités mentales, condition et satisfaction.</p>'+
   '<div class="row budgetline"><label>Joueur A<select id="v70-a">'+players.map(escapeOption).join('').replace('value="'+escape(first.id)+'"','value="'+escape(first.id)+'" selected')+'</select></label>'+
   '<label>Joueur B<select id="v70-b">'+players.map(escapeOption).join('').replace('value="'+escape(second.id)+'"','value="'+escape(second.id)+'" selected')+'</select></label></div>'+
   '<p class="help">Exemple de lien : '+escape(first.name)+' / '+escape(second.name)+' — '+escape(show(first,second))+'. Pour le mentorat, choisir le leader en joueur A. Pour la médiation, choisir un duo sous tension.</p>'+
   '<div class="stack">'+Object.entries(ACTIONS).map(([key,x])=>'<div class="row budgetline"><div><strong>'+escape(x.label)+'</strong><small>'+escape(x.detail)+'</small></div><button type="button" class="small" onclick="v70Action(\''+key+'\')" '+(can?'':'disabled')+'>Décider</button></div>').join('')+'</div>'+
   '<details><summary>Liens suivis ('+pairs.length+')</summary><ul>'+pairs.map(x=>{const rel=relation(s,x.a,x.b);return rel?'<li>'+escape(rel.a.name)+' / '+escape(rel.b.name)+' : '+escape(rel.label)+' ('+rel.score+')</li>':''}).join('')+'</ul></details>'+
   '<p class="help">Une intervention par semaine, avant la séance. Pas de gain aléatoire, aucune action en match. La préparation est enregistrée dans la carrière et photographiée au coup d\'envoi.</p></section>';
 }
 function install(root){
  if(!root||typeof root.managerTeamView!=='function'||typeof root.createRugbyMatch!=='function'||typeof root.teamEdge!=='function')return false;
  if(root.managerTeamView.__v70Wrapped)return true;
  const current=()=>typeof S!=='undefined'?S:root.S;
  const priorTeam=root.managerTeamView;
  const team=function(){return priorTeam()+panel(current())};
  team.__v70Wrapped=true;root.managerTeamView=team;
  const priorMatch=root.createRugbyMatch;
  root.createRugbyMatch=function(pair,legacy=null,automated=false,preparation=null){
   const match=priorMatch(pair,legacy,automated,preparation);
   if(!legacy&&!automated){const data=matchSnapshot(current(),match);if(data)match.v70Relations=data;}
   return match;
  };
  const priorEdge=root.teamEdge;
  root.teamEdge=function(l,side,kind){return priorEdge(l,side,kind)+matchBonus(l,side,kind)};
  root.v70Action=function(mode){
   const a=root.document?.getElementById('v70-a')?.value,b=root.document?.getElementById('v70-b')?.value;
   const ok=perform(current(),mode,a,b,{save:()=>{root.save();return typeof lastSaveError==='undefined'||!lastSaveError;},
    message:(...args)=>root.managerMessage(...args),render:()=>root.render()});
   if(!ok&&typeof root.toast==='function')root.toast('Duo ou décision indisponible : vérifiez les joueurs et le verrou hebdomadaire.');
   return ok;
  };
  return true;
 }
 return Object.freeze({ACTIONS,roster,leader,rawRisk,relation,allowed,preview,perform,matchSnapshot,matchBonus,panel,install});
});
if(typeof CDNativeHeadless==='undefined'&&typeof document!=='undefined'&&typeof CDRelationsV70==='object')CDRelationsV70.install(globalThis);
