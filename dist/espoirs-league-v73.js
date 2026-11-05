'use strict';
(function(root){
const MODES=['equilibre','performance','developpement','repos'];
const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
const hash=str=>{let h=2166136261;for(let i=0;i<str.length;i++){h^=str.charCodeAt(i);h=Math.imul(h,16777619)}return h>>>0};
const clubPlayers=(s,id)=>id===s.club?s.development?.academy||[]:s.aiRoster?.academies?.find(a=>a.clubId===id)?.players||[];
const clubName=(s,id)=>s.clubs[id]?.name||('Club '+id);
function roundRobin(ids){const a=ids.slice();if(a.length%2)a.push(-1);const out=[];for(let r=0;r<2*(a.length-1);r++){const pairs=[];for(let i=0;i<a.length/2;i++){const x=a[i],y=a[a.length-1-i];if(x>=0&&y>=0)pairs.push((r+i)%2?[y,x]:[x,y])}out.push(pairs);a.splice(1,0,a.pop())}return out}
function groupRounds(groups){const rounds=groups.map(g=>roundRobin(g));return Array.from({length:Math.max(...rounds.map(x=>x.length))},(_,i)=>rounds.flatMap(r=>r[i]||[]))}
function setup(s){if(!s?.development||!s.aiRoster?.academies||s.clubs?.length!==14)return null;
 if(s.v73Espoirs?.version===1&&s.v73Espoirs.season===s.season)return s.v73Espoirs;
 const old=s.v73Espoirs,groups=[Array.from({length:7},(_,i)=>i),Array.from({length:7},(_,i)=>i+7)];
 const state={version:1,season:s.season,round:0,stage:'preliminaire',groups,fixtures:groupRounds(groups),results:[],mode:'equilibre',lineup:[],minutes:{},fatigue:{},history:old?.history?.slice(-4)||[],qualified:[],champion:null,challenge:null};
 s.v73Espoirs=state;return state}
function read(s){return s?.v73Espoirs?.version===1&&s.v73Espoirs.season===s.season?s.v73Espoirs:null}
function standing(s,ids,results=read(s)?.results||[]){const rows=ids.map(id=>({id,played:0,win:0,draw:0,loss:0,for:0,against:0,bonus:0,points:0}));
 for(const m of results){const h=rows.find(x=>x.id===m.pair[0]),a=rows.find(x=>x.id===m.pair[1]);if(!h||!a)continue;
 for(const [x,y,tries,otherTries] of [[h,a,m.tries[0],m.tries[1]],[a,h,m.tries[1],m.tries[0]]]){x.played++;x.for+=m.score[x===h?0:1];x.against+=m.score[x===h?1:0];if(x===h?m.score[0]>m.score[1]:m.score[1]>m.score[0]){x.win++;x.points+=4}else if(m.score[0]===m.score[1]){x.draw++;x.points+=2}else x.loss++;const bp=tries-otherTries>=3?1:0,bd=(x===h?m.score[1]-m.score[0]:m.score[0]-m.score[1]);x.bonus+=bp+(bd>0&&bd<=5?1:0);x.points+=bp+(bd>0&&bd<=5?1:0)}}
 return rows.sort((a,b)=>b.points-a.points||(b.for-b.against)-(a.for-a.against)||b.for-a.for||a.id-b.id)}
function chosen(s,id,st=read(s)){const players=clubPlayers(s,id),used=new Set(),manual=id===s.club?st?.lineup||[]:[],slots=typeof root.POS!=='undefined'?root.POS:Array.from({length:15},(_,i)=>i);
 return slots.map((pos,i)=>{const forced=players.find(p=>p.id===manual[i]&&p.pos===pos&&!used.has(p.id));
 const pool=players.filter(p=>p.pos===pos&&!used.has(p.id)&&!p.injury);const mode=id===s.club?st?.mode:'equilibre';
 pool.sort((a,b)=>{const value=p=>p.rating+(mode==='developpement'?(p.dev?.potential-p.rating)*.6:0)+(mode==='repos'?(p.condition-100)*.8:0)-(st?.fatigue[p.id]||0)*.24;return value(b)-value(a)||a.id.localeCompare(b.id)});
 const pick=forced||pool[0]||players.find(p=>!used.has(p.id));if(pick)used.add(pick.id);return pick||null})}
function scoreMatch(s,pair,round,phase,st){const teams=pair.map(id=>chosen(s,id,st)),rating=teams.map(p=>p.reduce((n,x)=>n+(x?.rating||35)*(x?.condition||85)/100,0)/15);
 const seed=hash(s.season+':'+round+':'+phase+':'+pair.join('-')),delta=rating[0]-rating[1];const x=clamp(Math.round(23+delta*.48+(seed%17)-8+2),3,65),y=clamp(Math.round(23-delta*.48+(Math.floor(seed/17)%17)-8),3,65),tries=[Math.max(0,Math.floor(x/7)),Math.max(0,Math.floor(y/7))];
 return {pair,score:[x,y],tries,round,phase,players:teams.map(ps=>ps.map(p=>p?.id||null))}}
function registerMinutes(s,m,st){for(let side=0;side<2;side++){const club=m.pair[side];for(const id of m.players[side]){if(!id)continue;const p=clubPlayers(s,club).find(x=>x.id===id);if(!p)continue;const minutes=80, prior=st.minutes[id]||0;st.minutes[id]=prior+minutes;
 const tired=st.fatigue[id]||0;st.fatigue[id]=clamp(tired+10,0,100);p.condition=clamp(p.condition-6,35,100);
 if(typeof root.growPlayer==='function')root.growPlayer(p,.07*Math.max(.4,p.condition/100),false);
 if(prior<640&&st.minutes[id]>=640&&p.dev){p.dev.potential=clamp(Math.max(p.rating,p.dev.potential+1),p.rating,99)}
 }}}
function applyRound(s,st,round){if(round!==st.round||round<0||round>=26)return false;
 if(round===14){const first=st.groups.map(ids=>standing(s,ids,st.results.filter(x=>x.phase==='preliminaire')));
 const selected=first.map(g=>g.slice(0,4).map(x=>x.id)),losers=first.flatMap(g=>g.slice(4).map(x=>x.id));
 st.qualified=selected.flat();st.groups=[ [selected[0][0],selected[1][1],selected[0][2],selected[1][3]], [selected[1][0],selected[0][1],selected[1][2],selected[0][3]],losers ];
 const stages=groupRounds(st.groups.slice(0,2)),challenge=roundRobin(losers).slice(0,6);
 st.fixtures=st.fixtures.concat(Array.from({length:6},(_,i)=>[...(stages[i]||[]),...(challenge[i]||[])]));st.stage='qualification'}
 if(round===20){const ranked=st.groups.slice(0,2).map(g=>standing(s,g,st.results.filter(x=>x.phase==='qualification')));
 st.fixtures[20]=[[ranked[0][0].id,ranked[1][1].id],[ranked[1][0].id,ranked[0][1].id]];st.stage='demi-finales';
 const challengers=standing(s,st.groups[2],st.results.filter(x=>x.phase==='challenge'));st.challenge=challengers[0]?.id??null}
 if(round===21){const semis=st.results.filter(x=>x.phase==='demi-finales');if(semis.length===2)st.fixtures[21]=[semis.map(m=>m.pair[m.score[0]>=m.score[1]?0:1])];st.stage='finale'}
 const phase=round<14?'preliminaire':round<20?'qualification':round===20?'demi-finales':round===21?'finale':'repos';
 for(const pair of st.fixtures[round]||[]){const kind=round>=14&&round<20&&st.groups[2].includes(pair[0])?'challenge':phase;
 const match=scoreMatch(s,pair,round,kind,st);st.results.push(match);registerMinutes(s,match,st)}
 // Recovery for every unselected academy player, including those on a bye.
 const played=new Set(st.results.filter(x=>x.round===round).flatMap(x=>x.players.flat()).filter(Boolean));
 for(const id of s.clubs.map(x=>x.id))for(const p of clubPlayers(s,id)){const prev=st.fatigue[p.id]||0;if(!played.has(p.id))p.condition=clamp(p.condition+8,35,100);st.fatigue[p.id]=clamp(prev-(played.has(p.id)?2:11),0,100)}
 if(round===21){const f=st.results.find(x=>x.phase==='finale');st.champion=f?f.pair[f.score[0]>=f.score[1]?0:1]:null;st.stage='terminee'}
 st.round++;return true}
function advance(s){const st=read(s);if(!st||!s.development)return false;const target=Math.min(26,s.phase==='league'?s.round:26);
 while(st.round<target)applyRound(s,st,st.round);return true}
function closeSeason(s){const st=read(s);if(!st)return false;while(st.round<26)applyRound(s,st,st.round);
 st.history.unshift({season:st.season,champion:st.champion,challenge:st.challenge,minutes:st.minutes[s.development.academy[0]?.id]||0});st.history=st.history.slice(0,4);return true}
function setMode(s,mode,save){const st=read(s);if(!st||!MODES.includes(mode)||s.live||s.phase==='ended')return false;const prev=st.mode;st.mode=mode;try{if(save()===false)throw Error('save')}catch{st.mode=prev;return false}return true}
function setPlayer(s,slot,id,save){const st=read(s),players=clubPlayers(s,s.club),pos=root.POS?.[slot];
 if(!st||!Number.isInteger(slot)||slot<0||slot>=15||!players.some(p=>p.id===id&&p.pos===pos)||st.lineup.some((x,i)=>i!==slot&&x===id)||s.live||s.phase==='ended')return false;
 const prev=st.lineup.slice();st.lineup[slot]=id;try{if(save()===false)throw Error('save')}catch{st.lineup=prev;return false}return true}
const safe=t=>String(t).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
function panel(s){const st=read(s);if(!st)return '<section class="card"><h2>Championnat Espoirs</h2><p>Disponible dans une carrière avec centres de formation actifs.</p></section>';
 const groups=st.groups.map((ids,i)=>{const phase=i===2?'challenge':st.round<14?'preliminaire':'qualification',r=standing(s,ids,st.results.filter(x=>x.phase===phase));
 return '<div class="card"><h3>'+(i===2?'Challenge de France · groupe simulé':'Poule '+(i+1))+'</h3><div class="tablewrap"><table><thead><tr><th>#</th><th>Club</th><th>J</th><th>Pts</th><th>Diff.</th></tr></thead><tbody>'+r.map((x,k)=>'<tr><td>'+(k+1)+'</td><td>'+safe(clubName(s,x.id))+'</td><td>'+x.played+'</td><td>'+x.points+'</td><td>'+(x.for-x.against)+'</td></tr>').join('')+'</tbody></table></div></div>'}).join('');
 const chosenPlayers=chosen(s,s.club,st),editable=!s.live&&s.phase!=='ended';
 const composition=chosenPlayers.map((p,i)=>'<tr><td>'+(i+1)+'</td><td>'+safe(root.POS?.[i]||'Poste')+'</td><td><select aria-label="Espoir poste '+(i+1)+'" onchange="v73Select('+i+',this.value)" '+(editable?'':'disabled')+'>'+clubPlayers(s,s.club).filter(x=>x.pos===root.POS?.[i]).map(x=>'<option value="'+safe(x.id)+'" '+(p?.id===x.id?'selected':'')+'>'+safe(x.name)+' · '+Math.round(x.rating)+' · '+Math.round(x.condition)+'%</option>').join('')+'</select></td><td>'+(p?st.minutes[p.id]||0:0)+'</td></tr>').join('');
 const recent=st.results.slice(-12).reverse().map(m=>'<div class="row budgetline"><span>'+safe(clubName(s,m.pair[0]))+' — '+safe(clubName(s,m.pair[1]))+'</span><b>'+m.score.join(' – ')+'</b></div>').join('');
 const next=st.fixtures[st.round]||[];
 const promotions=clubPlayers(s,s.club).slice().sort((a,b)=>(st.minutes[b.id]||0)-(st.minutes[a.id]||0)).slice(0,3).map(p=>'<p>'+safe(p.name)+' · '+(st.minutes[p.id]||0)+' min · niveau '+Math.round(p.rating)+' / potentiel '+Math.round(p.dev?.potential||p.rating)+'</p>').join('');
 return '<section class="cd04-panel" style="padding:18px;margin-top:18px"><h2>V73 · Reichel Espoirs — Trophée Medhi Narjissi</h2><p>Adaptation fictive à 14 clubs, inspirée des phases FFR : 2 poules de 7 (14 journées), 2 poules qualificatives de 4 et un challenge de 6 (6 journées), demi-finales et finale (J21–J22). Matchs générés, sans calendrier officiel.</p><p><strong>Saison '+st.season+' · Journée Espoirs '+Math.min(26,st.round)+' / 26 · '+safe(st.stage)+'</strong> · '+st.results.length+' résultats · Champion : '+(st.champion===null?'à déterminer':safe(clubName(s,st.champion)))+'</p><h3>Composition et rotation</h3><label>Gestion du XV Espoirs <select onchange="v73Mode(this.value)" '+(editable?'':'disabled')+'>'+MODES.map(v=>'<option value="'+v+'" '+(st.mode===v?'selected':'')+'>'+({equilibre:'Équilibrée',performance:'Performance',developpement:'Développement des jeunes',repos:'Préserver la condition'}[v])+'</option>').join('')+'</select></label><div class="tablewrap"><table><thead><tr><th>#</th><th>Poste</th><th>Espoir retenu</th><th>Minutes</th></tr></thead><tbody>'+composition+'</tbody></table></div><h3>Jeunes à suivre pour une promotion</h3>'+promotions+'<p class="help">Les promotions se font via les boutons natifs de la Formation ; le championnat ne crée aucun professionnel automatiquement. Les titulaires progressent, gagnent des minutes et subissent une fatigue réversible.</p><h3>Classements et qualifications</h3><div class="grid">'+groups+'</div><h3>Prochaines affiches</h3>'+(next.map(p=>'<p>'+safe(clubName(s,p[0]))+' — '+safe(clubName(s,p[1]))+'</p>').join('')||'<p>Aucune rencontre programmée.</p>')+'<h3>Derniers résultats</h3>'+recent+'</section>'}
function install(g){if(!g||typeof g.finishRound!=='function'||typeof g.advanceSeason!=='function')return false;if(g.finishRound.__v73)return true;
 const get=()=>typeof S!=='undefined'?S:g.S,save=()=>{g.save();return typeof lastSaveError==='undefined'||!lastSaveError};
 const finish=g.finishRound;g.finishRound=function(){const s=get(),before=s&&s.round,season=s&&s.season,r=finish.apply(this,arguments);if(s&&s.season===season&&s.round!==before&&read(s)){advance(s);save()}return r};g.finishRound.__v73=true;
 const next=g.advanceSeason;g.advanceSeason=function(){const s=get();if(s)closeSeason(s);const r=next.apply(this,arguments);if(get()&&get().season!==s?.season){setup(get());save()}return r};
 const former=g.formationView; if(typeof former==='function'){g.formationView=function(){const html=former.apply(this,arguments);return html+panel(get())}}
 if(typeof g.CDNativeCenters==='object'&&typeof g.CDNativeCenters.formationView==='function'){const old=g.CDNativeCenters.formationView;g.CDNativeCenters.formationView=function(){return old.apply(this,arguments)+panel(get())}}
 g.v73Mode=mode=>{const ok=setMode(get(),mode,save);if(ok)g.render();return ok};
 g.v73Select=(slot,id)=>{const ok=setPlayer(get(),slot,id,save);if(ok)g.render();return ok};return true}
const api={roundRobin,setup,read,standing,chosen,scoreMatch,applyRound,advance,closeSeason,setMode,setPlayer,panel,install};if(typeof module==='object'&&module.exports)module.exports=api;root.CDEspoirsV73=api;if(typeof document!=='undefined')install(root)
})(typeof globalThis==='object'?globalThis:this);
