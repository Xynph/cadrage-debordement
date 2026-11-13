'use strict';
(function(root){
const TYPES=['puissance','vitesse','endurance','technique'],ANSWERS=['promouvoir','preter','minutes','refuser'];
const copy=x=>JSON.parse(JSON.stringify(x)),esc=x=>String(x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const clean=x=>String(x??'').replace(/[&<>"'\x00-\x1f]/g,' ').slice(0,100);
const hash=x=>{let h=2166136261;for(const c of String(x)){h^=c.charCodeAt(0);h=Math.imul(h,16777619)}return h>>>0};
const academy=s=>s?.development?.academy||[],pros=s=>s?.clubs?.[s.club]?.players||[],players=s=>[...academy(s),...pros(s)];
const pot=p=>Number.isFinite(p?.dev?.potential)?p.dev.potential:p?.potential??p?.rating??0;
const valid=st=>!!st&&st.version===1&&Number.isInteger(st.season)&&st.season>0&&
Array.isArray(st.profiles)&&st.profiles.length<=90&&Array.isArray(st.offers)&&st.offers.length<=12&&
Array.isArray(st.promises)&&st.promises.length<=20&&Array.isArray(st.events)&&st.events.length<=160&&
Array.isArray(st.history)&&st.history.length<=12&&
st.profiles.every(x=>typeof x.id==='string'&&x.id.length<=100&&Number.isFinite(x.startRating)&&
Number.isInteger(x.morale)&&x.morale>=0&&x.morale<=100&&(x.program===null||TYPES.includes(x.program))&&
Number.isInteger(x.load)&&x.load>=0&&x.load<=3)&&
st.offers.every(x=>typeof x.id==='string'&&Number.isInteger(x.club)&&Number.isInteger(x.season))&&
st.promises.every(x=>typeof x.id==='string'&&ANSWERS.includes(x.answer)&&Number.isInteger(x.deadline))&&
st.events.every(x=>typeof x.id==='string'&&Number.isInteger(x.season))&&
st.history.every(x=>Number.isInteger(x.season)&&Array.isArray(x.graduates));
function profile(st,p){
if(typeof p?.id!=='string'||p.id.length>100)return null;
let q=st.profiles.find(x=>x.id===p.id);
if(!q&&st.profiles.length<90){q={id:p.id,name:clean(p.name),pos:clean(p.pos),
startRating:p.rating,baseline:p.rating,morale:65,program:null,load:0,firstSeason:st.season,trained:0};st.profiles.push(q)}
return q||null;
}
function ensure(s){
if(!s?.development||!Number.isInteger(s.season)||s.season<1)return null;
let st=s.v90to94;
if(st!==undefined){
if(!valid(st)||st.season>s.season)return null;
if(st.season<s.season){st={...st,season:s.season,offers:[],promises:st.promises.filter(x=>x.deadline>=s.season),
profiles:st.profiles.map(x=>({...x,startRating:x.baseline,load:0}))};s.v90to94=st}
}else{st={version:1,season:s.season,profiles:[],offers:[],promises:[],events:[],history:[]};s.v90to94=st}
for(const p of players(s).filter(x=>x.age<=24))profile(st,p);
return st;
}
function atomic(s,fn,save){const before=copy(s);
try{if(fn()!==true)return false;if(save&&save()===false)throw Error('save');return true}
catch{for(const k of Object.keys(s))delete s[k];Object.assign(s,before);return false}}
function log(st,s,id,type,note){st.events.push({id,type,season:s.season,note:clean(note)});st.events=st.events.slice(-160)}
function revelations(s){const st=ensure(s);if(!st)return [];
return academy(s).filter(p=>p.age<=21&&typeof p.id==='string').map(p=>{
const q=profile(st,p),minutes=Math.max(0,Number(s.v73Espoirs?.minutes?.[p.id])||0);
const growth=Math.round(p.rating-(q?.startRating??p.rating)),upside=Math.max(0,pot(p)-p.rating);
const surprise=hash(s.season+':'+p.id+':revelation')%100;
return {id:p.id,name:p.name,pos:p.pos,minutes,growth,upside,
label:growth>=3&&minutes>=320?'revelation':growth<=0&&minutes>=480?'stagnation':
upside>=12&&surprise<18?'sous-estime':'suivi'};}).sort((a,b)=>b.growth-a.growth||b.minutes-a.minutes||a.id.localeCompare(b.id))}
function offers(s){const st=ensure(s);if(!st)return [];
return academy(s).filter(p=>p.age<=21&&pot(p)>=72).map(p=>{
const interested=[];for(let i=0;i<(s.clubs||[]).length;i++){
if(i===s.club)continue;const interest=hash(s.season+':'+p.id+':'+i)%100;
if(interest<13)interested.push({club:i,name:clean(s.clubs[i].name),interest:100-interest})}
return {id:p.id,name:p.name,clubs:interested.sort((a,b)=>b.interest-a.interest).slice(0,3)};}).filter(x=>x.clubs.length)}
function retain(s,id,club,save){
const st=ensure(s),p=academy(s).find(x=>x.id===id),entry=offers(s).find(x=>x.id===id);
if(!st||s.live||s.phase==='ended'||!p||!entry?.clubs.some(x=>x.club===club)||
st.offers.some(x=>x.id===id&&x.season===s.season))return false;
const fee=Math.round(1000+Math.max(0,pot(p)-65)*100);
if(!Number.isFinite(s.clubs[s.club].cash)||s.clubs[s.club].cash<fee)return false;
return atomic(s,()=>{const q=profile(st,p);if(!q)return false;s.clubs[s.club].cash-=fee;
q.morale=Math.min(100,q.morale+12);st.offers.push({id,club,season:s.season,decision:'retenu',fee});
log(st,s,id,'fidelisation','Engagement contre la concurrence');return true},save)}
function specialize(s,id,kind,save){
const st=ensure(s),p=academy(s).find(x=>x.id===id);
if(!st||s.live||s.phase==='ended'||!p||p.age>21||!p.dev||!TYPES.includes(kind))return false;
return atomic(s,()=>{const q=profile(st,p);if(!q||q.load>=3)return false;
q.program=kind;q.load++;q.morale=Math.max(0,q.morale-2);
log(st,s,id,'specialisation',kind);return true},save)}
function interview(s,id,answer,save){
const st=ensure(s),p=players(s).find(x=>x.id===id);
if(!st||s.live||s.phase==='ended'||!p||p.age>24||!ANSWERS.includes(answer)||
st.promises.some(x=>x.id===id&&x.deadline>=s.season))return false;
return atomic(s,()=>{const q=profile(st,p);if(!q)return false;
q.morale=Math.max(0,Math.min(100,q.morale+(answer==='refuser'?-10:answer==='minutes'?4:8)));
st.promises.push({id,answer,season:s.season,deadline:s.season+1,
fulfilled:answer==='refuser',startMinutes:Number(s.v73Espoirs?.minutes?.[id]||0)});
log(st,s,id,'entretien',answer);return true},save)}
function tally(s){const st=ensure(s);if(!st)return [];
const all=[...(s.v77Promotions?.promotions||[]),...(s.v77Promotions?.history||[]).flatMap(x=>x.promotions||[])];
const bySeason=new Map(),seen=new Set();
for(const p of all){if(typeof p.playerId!=='string'||seen.has(p.playerId))continue;seen.add(p.playerId);
const record={id:p.playerId,name:clean(p.name),pos:clean(p.pos),season:p.season,potential:Number(p.potential)||0};
const a=bySeason.get(record.season)||[];a.push(record);bySeason.set(record.season,a)}
return [...bySeason].sort((a,b)=>a[0]-b[0]).map(([season,graduates])=>({
season,graduates,count:graduates.length,averagePotential:Math.round(graduates.reduce((n,x)=>n+x.potential,0)/graduates.length)}))}
function seasonEnd(s){
const st=ensure(s);if(!st||s.phase!=='ended'||st.history.some(x=>x.season===s.season))return false;
return atomic(s,()=>{
const completed=[];
for(const q of st.profiles){const p=players(s).find(x=>x.id===q.id);if(!p)continue;
const growth=p.rating-q.startRating;
if(growth>=3)log(st,s,p.id,'revelation','Progression remarquable');
if(q.program&&p.dev&&p.rating<pot(p)){
const gain=Math.min(1,pot(p)-p.rating),fatigue=Math.min(8,2*q.load);
p.rating=Math.min(99,p.rating+gain);
p.condition=Math.max(35,Math.min(100,Number(p.condition)||85)-fatigue);
q.trained+=gain;log(st,s,p.id,'bilan-specialisation',q.program+' +'+gain+' fatigue '+fatigue)}
q.baseline=p.rating}
for(const promise of st.promises){if(promise.fulfilled||promise.deadline<s.season)continue;
const promoted=pros(s).some(p=>p.id===promise.id),loaned=(s.v78to81?.loans||[]).some(x=>x.id===promise.id);
const minutes=Number(s.v73Espoirs?.minutes?.[promise.id]||0)-promise.startMinutes;
const achieved=promise.answer==='promouvoir'?promoted:promise.answer==='preter'?loaned:
promise.answer==='minutes'?minutes>=320:true;
promise.fulfilled=achieved;const q=st.profiles.find(x=>x.id===promise.id);
if(q)q.morale=Math.max(0,Math.min(100,q.morale+(achieved?7:-15)));
log(st,s,promise.id,achieved?'promesse-tenue':'promesse-non-tenue',promise.answer);
completed.push({id:promise.id,achieved})}
const graduates=tally(s).flatMap(x=>x.graduates).filter(x=>x.season===s.season);
st.history=[{season:s.season,graduates,trained:st.profiles.filter(x=>x.trained>0).length,promises:completed,
breakouts:st.events.filter(e=>e.season===s.season&&e.type==='revelation').length},...st.history].slice(0,12);
return true})}
function panel(s){
const st=ensure(s);if(!st)return '';
const locked=!!s.live||s.phase==='ended',arg=id=>JSON.stringify(id).replace(/"/g,'&quot;');
const rows=revelations(s).slice(0,12).map(x=>{
const q=st.profiles.find(p=>p.id===x.id);
return '<tr><td>'+esc(x.name)+'</td><td>'+esc(x.label)+'</td><td>'+x.growth+'</td><td>'+x.minutes+'</td><td>'+
TYPES.map(k=>'<button type="button" onclick="v92Specialize('+arg(x.id)+',\''+k+'\')"'+
(locked||q?.load>=3?' disabled':'')+'>'+k+'</button>').join(' ')+'</td></tr>'}).join('');
const rivals=offers(s).slice(0,10).map(x=>'<li>'+esc(x.name)+' : '+x.clubs.map(c=>esc(c.name)+
' <button type="button" onclick="v91Retain('+arg(x.id)+','+c.club+')"'+
(locked||st.offers.some(y=>y.id===x.id&&y.season===s.season)?' disabled':'')+
'>Fidéliser</button>').join(', ')+'</li>').join('');
const talks=players(s).filter(p=>p.age<=24).slice(0,10).map(p=>'<li>'+esc(p.name)+' · moral '+
(st.profiles.find(x=>x.id===p.id)?.morale??65)+' · '+ANSWERS.map(a=>
'<button type="button" onclick="v93Interview('+arg(p.id)+',\''+a+'\')"'+
(locked||st.promises.some(x=>x.id===p.id&&x.deadline>=s.season)?' disabled':'')+'>'+a+'</button>').join(' ')+'</li>').join('');
const heritage=tally(s).map(x=>'<li>'+(typeof libelleSaison==='function'?libelleSaison:String)(x.season)+' · '+x.count+' diplômé(s), potentiel moyen '+x.averagePotential+'</li>').join('');
return '<section class="cd04-panel" style="padding:18px;margin-top:18px"><h2>V90–V94 · Vie du centre de formation</h2>'+
'<h3>V90 · Révélations et stagnation</h3><div class="tablewrap"><table><thead><tr><th>Espoir</th><th>Détection</th><th>Progression</th><th>Minutes</th><th>V92 · Programme</th></tr></thead><tbody>'+rows+'</tbody></table></div>'+
'<h3>V91 · Concurrence pour les talents</h3><ul>'+(rivals||'<li>Pas de convoitise détectée</li>')+'</ul>'+
'<h3>V93 · Entretiens et promesses</h3><ul>'+talks+'</ul>'+
'<h3>V94 · Héritage et générations</h3><ul>'+(heritage||'<li>Aucune génération promue</li>')+'</ul>'+
'<p class="help">Révélations et convoitises simulées de façon reproductible ; fidélisation payée par trésorerie fictive. Programme annuel borné, fatigue et promesses évaluées chaque fin de saison. Aucun transfert automatique.</p></section>'}
function install(g){
if(!g||typeof g.start!=='function'||typeof g.advanceSeason!=='function'||typeof g.render!=='function')return false;
if(typeof g.v92Specialize==='function')return true;
const state=()=>typeof S!=='undefined'?S:g.S,save=()=>typeof g.save==='function'&&g.save()!==false;
const start=g.start;g.start=function(){const r=start.apply(this,arguments);if(state()){ensure(state());save()}return r};
const year=g.advanceSeason;g.advanceSeason=function(){const s=state(),prior=s?.season;
if(s?.phase==='ended'&&!s?.v90to94?.history?.some(h=>h.season===s.season)){
const before=copy(s);if(!seasonEnd(s)||!save()){for(const k of Object.keys(s))delete s[k];Object.assign(s,before);return false}}
const r=year.apply(this,arguments);if(state()&&state().season!==prior){ensure(state());save()}return r};
const render=g.render;g.render=function(){const r=render.apply(this,arguments),s=state();
if(s&&typeof document!=='undefined'&&typeof view!=='undefined'&&view==='formation'){
const target=document.querySelector('.cd04-content [data-da42-page="dossiers"]')||document.querySelector('.cd04-content');
if(target?.insertAdjacentHTML)target.insertAdjacentHTML('beforeend',panel(s))}return r};
g.v91Retain=(id,club)=>{const ok=retain(state(),id,club,save);if(ok)g.render();return ok};
g.v92Specialize=(id,kind)=>{const ok=specialize(state(),id,kind,save);if(ok)g.render();return ok};
g.v93Interview=(id,answer)=>{const ok=interview(state(),id,answer,save);if(ok)g.render();return ok};
return true}
const api={valid,ensure,revelations,offers,retain,specialize,interview,tally,seasonEnd,panel,install};
root.CDEspoirsDynamicsV90V94=api;
if(typeof module==='object'&&module.exports)module.exports=api;
if(!root.CDNativeHeadless&&typeof document!=='undefined')install(root);
})(typeof globalThis==='object'?globalThis:this);
