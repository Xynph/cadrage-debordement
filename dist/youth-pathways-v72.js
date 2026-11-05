'use strict';
(function(root){const price={scout:35000,mentor:8000};
function state(s){return s.v72Youth||(s.v72Youth={version:1,scouts:[],mentors:[],promotions:[]})}
function read(s){return s.v72Youth||{scouts:[],mentors:[],promotions:[]}}
function ready(s){return s&&s.development&&s.economy&&!s.live&&!s.trained&&s.phase!=='ended'}
function act(s,kind,id,focus,save){if(!ready(s)||!price[kind]||s.clubs[s.club].cash<price[kind])return false;
const d=read(s);if(kind==='scout'&&d.scouts.some(x=>x.target===s.season+1))return false;
if(kind==='mentor'&&(!s.development.academy.some(p=>p.id===id)||!['technique','mental','physique'].includes(focus)||d.mentors.some(x=>x.season===s.season&&x.week===s.round)))return false;
const cash=s.clubs[s.club].cash,had=!!s.v72Youth,old=JSON.stringify(s.v72Youth);
s.clubs[s.club].cash-=price[kind];const v=state(s);
if(kind==='scout')v.scouts.unshift({target:s.season+1,done:false});
else v.mentors.unshift({id,focus,season:s.season,week:s.round,done:false});
try{if(save()===false)throw Error('save')}catch(e){s.clubs[s.club].cash=cash;if(had)s.v72Youth=JSON.parse(old);else delete s.v72Youth;return false}return true}
function training(s,grow,save){if(!s?.trained)return 0;let count=0;
for(const x of read(s).mentors)if(!x.done&&x.season===s.season&&x.week===s.round){const p=s.development.academy.find(q=>q.id===x.id);x.done=true;
if(p&&!p.injury){const old=p.rating;grow(p,x.focus==='technique'?.22:x.focus==='mental'?.17:.14);x.gain=Math.max(0,p.rating-old)}else x.gain=0;count++}
if(count)save();return count}
function intake(s,save){const x=read(s).scouts.find(x=>x.target===s.season&&!x.done);if(!x)return 0;
const players=s.development.academy.filter(p=>p.id.startsWith('youth-'+s.club+'-'+s.season+'-'));if(!players.length)return 0;
players.forEach(p=>{p.dev.potential=Math.min(99,Math.max(p.rating,p.dev.potential+3))});x.done=true;x.count=players.length;save();return players.length}
function panel(s){if(!s?.development)return '';const d=read(s),blocked=!ready(s),cash=s.clubs[s.club].cash;
const scout=d.scouts.some(x=>x.target===s.season+1),mentor=d.mentors.some(x=>x.season===s.season&&x.week===s.round);
const rows=s.development.academy.map(p=>'<tr><td>'+p.name+'</td><td>'+p.pos+'</td><td>'+Math.round(p.rating)+' / '+Math.round(p.dev?.potential||p.rating)+'</td><td><select id="v72-'+p.id+'"><option value="technique">Technique</option><option value="mental">Mental</option><option value="physique">Physique</option></select> <button onclick="v72Mentor(\''+p.id+'\')" '+(blocked||mentor||cash<8000?'disabled':'')+'>Accompagner</button></td></tr>').join('');
return '<section class="cd04-panel" style="padding:18px;margin-top:16px"><h3>V72 · Parcours des Espoirs</h3><p>Detection prochaine saison : 35 000 € (potentiel +3 maximum pour les nouveaux Espoirs). Accompagnement : 8 000 € par semaine, bonus borne apres entrainement.</p><button onclick="v72Scout()" '+(blocked||scout||cash<35000?'disabled':'')+'>Financer la detection</button><div class="cd04-scroll"><table class="cd04-table"><thead><tr><th>Espoir</th><th>Poste</th><th>Niveau / potentiel</th><th>Decision</th></tr></thead><tbody>'+rows+'</tbody></table></div><p>Promotions suivies : '+d.promotions.length+' · Campagnes : '+d.scouts.length+'</p></section>'}
function install(g){if(!g||!g.trainWeek||!g.promoteYouth||!g.beginDevelopmentSeason)return false;if(g.trainWeek.__v72)return true;
const get=()=>typeof S!=='undefined'?S:g.S,save=()=>{g.save();return typeof lastSaveError==='undefined'||!lastSaveError};
const original=g.trainWeek;g.trainWeek=function(){const s=get(),before=s?.trained,r=original.apply(this,arguments);if(!before&&s?.trained)training(s,g.growPlayer,save);return r};g.trainWeek.__v72=true;
const begin=g.beginDevelopmentSeason;g.beginDevelopmentSeason=function(){const r=begin.apply(this,arguments);intake(get(),save);return r};
const promote=g.promoteYouth;g.promoteYouth=function(id){const s=get(),p=s.development.academy.find(x=>x.id===id),result=promote.apply(this,arguments);if(result&&p){state(s).promotions.unshift({id,season:s.season,week:s.round});state(s).promotions=state(s).promotions.slice(0,80);save()}return result};
g.v72Scout=()=>{const ok=act(get(),'scout',null,null,save);if(ok)g.render();return ok};
g.v72Mentor=id=>{const x=typeof document!=='undefined'?document.getElementById('v72-'+id):null,ok=act(get(),'mentor',id,x?.value||'technique',save);if(ok)g.render();return ok};return true}
const api={read,ready,act,training,intake,panel,install};if(typeof module==='object'&&module.exports)module.exports=api;root.CDYouthV72=api;if(typeof document!=='undefined')install(root)})(typeof globalThis==='object'?globalThis:this);
