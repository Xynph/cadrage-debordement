'use strict';
(function(root){
const REAL=[
 ['Périgueux','Marcq-en-Barœul','Rennes','Suresnes','Massy','Soyaux-Angoulême','Mont-de-Marsan','Dax','Orléans','Montauban'],
 ['Bourgoin-Jallieu','Provence Rugby','Albi','Nice','Chambéry','Bourg-en-Bresse','Carcassonne','Narbonne','Béziers','Vienne']
];
const FICTION=[
 ['Périgord Rugby','Flandres Rugby','Arvor Rugby','Seine Ouest','Essonne Rugby','Charentes Rugby','Landes Rugby','Côte Sud Rugby','Loire Nord Rugby','Tarn Garonne Rugby'],
 ['Isère Rugby','Provence Est','Tarn Rugby','Azur XV','Savoie Rugby','Bresse Rugby','Aude Rugby','Narbonnais XV','Hérault Rugby','Vienne XV']
];
const POSITIONS=['Pilier G','Talonneur','Pilier D','Deuxième ligne','Deuxième ligne','Troisième ligne','Troisième ligne','N°8','Mêlée','Ouverture','Ailier G','Centre','Centre','Ailier D','Arrière'];
const MODES=['equilibre','performance','formation','repos'];
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
const hash=x=>{let h=2166136261;for(const c of String(x)){h^=c.charCodeAt(0);h=Math.imul(h,16777619)}return h>>>0};
const rand=(seed,mod)=>(hash(seed)%mod);
const safe=x=>String(x).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const ids=()=>Array.from({length:20},(_,i)=>i);
const name=(s,id)=>{const base=(s.lnrMode?.version===1?REAL:FICTION)[Math.floor(id/10)]?.[id%10]||('Centre '+id);return root.CDEspoirsMovementV75?.name(s,'accession',id,base)||base};
function fixtures(groups){
 const schedule=groups.map(ids=>{const a=ids.slice(),out=[];for(let r=0;r<18;r++){const day=[];for(let i=0;i<5;i++){const x=a[i],y=a[9-i];day.push((r+i)%2?[y,x]:[x,y])}out.push(day);a.splice(1,0,a.pop())}return out});
 return Array.from({length:18},(_,i)=>[...schedule[0][i],...schedule[1][i]])}
function prospects(season,club){return Array.from({length:22},(_,i)=>{const h=hash(season+':'+club+':'+i),rating=42+h%25;
 return {id:'a74-'+season+'-'+club+'-'+i,name:'Espoir '+(club+1)+'-'+(i+1),pos:POSITIONS[i%15],slot:i%15,age:17+rand(h+':age',5),rating,potential:clamp(rating+8+rand(h+':potential',17),rating,95),condition:100,minutes:0};})}
function setup(s){if(!s||!s.development||!s.aiRoster?.academies)return null;
 if(s.v74Accession?.version===1&&s.v74Accession.season===s.season)return s.v74Accession;
 const previous=s.v74Accession,groups=[ids().slice(0,10),ids().slice(10)];
 s.v74Accession={version:1,season:s.season,round:0,stage:'poules',groups,fixtures:fixtures(groups),results:[],centers:ids().map(id=>({id,players:prospects(s.season,id)})),follow:previous?.follow??0,plan:'equilibre',history:previous?.history?.slice(0,4)||[],champion:null,finalists:[],playoffs:[]};
 if(root.CDEspoirsMovementV75?.sync)root.CDEspoirsMovementV75.sync(s);
 return s.v74Accession}
function read(s){return s?.v74Accession?.version===1&&s.v74Accession.season===s.season?s.v74Accession:null}
function standings(st,group){const rows=group.map(id=>({id,p:0,w:0,d:0,l:0,scored:0,conceded:0,bonus:0,points:0}));
 for(const m of st.results.filter(x=>x.stage==='poules')){const home=rows.find(x=>x.id===m.pair[0]),away=rows.find(x=>x.id===m.pair[1]);if(!home||!away)continue;
 for(const [row,side] of [[home,0],[away,1]]){row.p++;row.scored+=m.score[side];row.conceded+=m.score[1-side];const diff=m.score[side]-m.score[1-side];if(diff>0){row.w++;row.points+=4}else if(!diff){row.d++;row.points+=2}else row.l++;
 const bonus=(m.tries[side]-m.tries[1-side]>=3?1:0)+(diff<0&&diff>=-5?1:0);row.bonus+=bonus;row.points+=bonus}}
 return rows.sort((a,b)=>b.points-a.points||(b.scored-b.conceded)-(a.scored-a.conceded)||b.scored-a.scored||a.id-b.id)}
function fifteen(st,id){const c=st.centers[id],mode=id===st.follow?st.plan:'equilibre';
 return Array.from({length:15},(_,slot)=>{const available=c.players.filter(p=>p.slot===slot);available.sort((a,b)=>{const power=p=>p.rating+(mode==='formation'?(p.potential-p.rating)*.65:0)+(mode==='repos'?(p.condition-100)*.7:0);return power(b)-power(a)||a.id.localeCompare(b.id)});return available[0]})}
function play(st,pair,round,stage){const xi=pair.map(id=>fifteen(st,id)),quality=xi.map(ps=>ps.reduce((t,p)=>t+p.rating*p.condition/100,0)/15);
 const seed=st.season+':'+round+':'+stage+':'+pair.join('-'),delta=quality[0]-quality[1];
 const a=clamp(Math.round(21+delta*.55+rand(seed+':home',17)-6),3,60),b=clamp(Math.round(21-delta*.55+rand(seed+':away',17)-8),3,60);
 const result={pair:pair.slice(),round,stage,score:[a,b],tries:[Math.floor(a/7),Math.floor(b/7)],lineups:xi.map(ps=>ps.map(p=>p.id))};
 for(let side=0;side<2;side++)for(const p of xi[side]){p.minutes+=80;p.condition=clamp(p.condition-7,35,100);
 if(p.rating<p.potential&&p.minutes%240===0)p.rating=Math.min(p.potential,p.rating+1)}
 st.results.push(result);return result}
const winners=matches=>matches.map(m=>m.pair[m.score[0]>=m.score[1]?0:1]);
function apply(st,round){if(round!==st.round||round<0||round>=26)return false;
 if(round===18){const top=st.groups.map(g=>standings(st,g).slice(0,4).map(x=>x.id));st.playoffs=[[top[0][0],top[1][3]],[top[1][1],top[0][2]],[top[0][1],top[1][2]],[top[1][0],top[0][3]]];st.stage='quarts'}
 if(round===19){const w=winners(st.results.filter(m=>m.stage==='quarts'));st.playoffs=[[w[0],w[1]],[w[2],w[3]]];st.stage='demies'}
 if(round===20){const w=winners(st.results.filter(m=>m.stage==='demies'));st.playoffs=[[w[0],w[1]]];st.finalists=w.slice();st.stage='finale'}
 const games=round<18?st.fixtures[round]:round<=20?st.playoffs:[];
 const stage=round<18?'poules':round===18?'quarts':round===19?'demies':round===20?'finale':'repos';
 for(const pair of games||[])play(st,pair,round,stage);
 for(const c of st.centers)for(const p of c.players)p.condition=clamp(p.condition+(round>=21?12:4),35,100);
 if(round===20){st.champion=winners(st.results.filter(m=>m.stage==='finale'))[0]??null;st.stage='terminee'}
 st.round++;return true}
function advance(s){const st=read(s);if(!st)return false;const target=Math.min(26,s.phase==='league'?s.round:26);
 while(st.round<target)apply(st,st.round);return true}
function closeSeason(s){const st=read(s);if(!st)return false;while(st.round<26)apply(st,st.round);
 if(!st.history.some(x=>x.season===st.season))st.history.unshift({season:st.season,champion:st.champion,finalists:st.finalists.slice(),follow:st.follow});
 st.history=st.history.slice(0,4);return true}
function select(s,field,value,save){const st=read(s);if(!st||s.live||s.phase==='ended')return false;
 if(field==='follow'){value=Number(value);if(!Number.isInteger(value)||value<0||value>=20)return false}
 else if(field==='plan'){if(!MODES.includes(value))return false}else return false;
 const old=st[field];st[field]=value;try{if(save()===false)throw Error('save')}catch{st[field]=old;return false}return true}
function panel(s){const st=read(s);if(!st)return '<section class="card"><h2>Espoirs Accession</h2><p>Disponible dès le prochain tour de carrière.</p></section>';
 const rows=st.groups.map((g,i)=>'<div class="card"><h3>Poule '+(i+1)+'</h3><div class="tablewrap"><table><thead><tr><th>#</th><th>Centre</th><th>J</th><th>Pts</th><th>Diff.</th></tr></thead><tbody>'+standings(st,g).map((x,k)=>'<tr><td>'+(k+1)+'</td><td>'+safe(name(s,x.id))+'</td><td>'+x.p+'</td><td>'+x.points+'</td><td>'+(x.scored-x.conceded)+'</td></tr>').join('')+'</tbody></table></div></div>').join('');
 const club=st.centers[st.follow],ready=!(s.live||s.phase==='ended');
 const next=st.round<18?st.fixtures[st.round]:st.round<=20?st.playoffs:[];
 const talents=club.players.slice().sort((a,b)=>b.potential-a.potential||b.rating-a.rating).slice(0,5);
 const history=st.history.map(h=>'<p>Saison '+h.season+' · '+safe(name(s,h.champion))+'</p>').join('')||'<p>Aucun historique.</p>';
 return '<section class="cd04-panel" style="padding:18px;margin-top:18px"><h2>V74 · Reichel Espoirs Accession</h2><p>20 clubs · 2 poules de 10 · 18 journées aller-retour · quarts, demi-finales et finale. Simulation indépendante du championnat Élite.</p><p><strong>Saison '+st.season+' · Journée '+Math.min(st.round,21)+' / 21 · '+safe(st.stage)+'</strong> · '+st.results.length+' résultats</p><label>Centre suivi <select aria-label="Centre Espoirs Accession suivi" onchange="v74Select(&quot;follow&quot;,this.value)" '+(ready?'':'disabled')+'>'+ids().map(id=>'<option value="'+id+'" '+(id===st.follow?'selected':'')+'>'+safe(name(s,id))+'</option>').join('')+'</select></label><label>Plan du centre <select aria-label="Plan Espoirs Accession" onchange="v74Select(&quot;plan&quot;,this.value)" '+(ready?'':'disabled')+'>'+MODES.map(v=>'<option value="'+v+'" '+(v===st.plan?'selected':'')+'>'+({equilibre:'Équilibre',performance:'Performance',formation:'Formation accélérée',repos:'Repos et récupération'}[v])+'</option>').join('')+'</select></label><h3>Joueurs prometteurs · '+safe(name(s,st.follow))+'</h3><div class="tablewrap"><table><thead><tr><th>Poste</th><th>Joueur fictif</th><th>Niveau</th><th>Potentiel</th><th>Minutes</th></tr></thead><tbody>'+talents.map(p=>'<tr><td>'+safe(p.pos)+'</td><td>'+safe(p.name)+'</td><td>'+p.rating+'</td><td>'+p.potential+'</td><td>'+p.minutes+'</td></tr>').join('')+'</tbody></table></div><h3>Classements</h3><div class="grid">'+rows+'</div><h3>Prochaines rencontres</h3>'+(next||[]).map(pair=>'<p>'+safe(name(s,pair[0]))+' — '+safe(name(s,pair[1]))+'</p>').join('')+'<h3>Derniers résultats</h3>'+st.results.slice(-8).reverse().map(m=>'<p>'+safe(name(s,m.pair[0]))+' '+m.score[0]+' – '+m.score[1]+' '+safe(name(s,m.pair[1]))+'</p>').join('')+'<h3>Montée sportive et archives</h3><p>Finalistes éligibles à la montée : '+(st.finalists.length?st.finalists.map(id=>safe(name(s,id))).join(' et '):'à déterminer')+'. La montée réelle dans le module Élite reste à intégrer ultérieurement.</p>'+history+'</section>'}
function install(g){if(!g||typeof g.finishRound!=='function'||typeof g.advanceSeason!=='function')return false;if(g.finishRound.__v74)return true;
 const get=()=>typeof S!=='undefined'?S:g.S,save=()=>{g.save();return typeof lastSaveError==='undefined'||!lastSaveError};
 const origFinish=g.finishRound;g.finishRound=function(){const s=get(),before=s?.round,season=s?.season,result=origFinish.apply(this,arguments);
 if(s&&s.season===season&&s.round!==before){setup(s);advance(s);save()}return result};g.finishRound.__v74=true;
 const origSeason=g.advanceSeason;g.advanceSeason=function(){const s=get(),season=s?.season;if(s){setup(s);closeSeason(s)}const result=origSeason.apply(this,arguments);if(get()?.season!==season){setup(get());save()}return result};
 const origStart=g.start;if(typeof origStart==='function')g.start=function(){const result=origStart.apply(this,arguments);if(get()){setup(get());save()}return result};
 const origRender=g.render;g.render=function(){const result=origRender.apply(this,arguments),s=get();if(s&&typeof view!=='undefined'&&view==='formation'&&typeof document!=='undefined'){const target=document.querySelector('.cd04-content [data-da42-page="dossiers"]');if(target)target.insertAdjacentHTML('beforeend',panel(s))}return result};
 g.v74Select=(field,value)=>{const ok=select(get(),field,value,save);if(ok)g.render();return ok};return true}
const api={REAL,FICTION,name,fixtures,setup,read,standings,play,apply,advance,closeSeason,select,panel,install};
if(typeof module==='object'&&module.exports)module.exports=api;root.CDEspoirsAccessionV74=api;if(typeof document!=='undefined')install(root)
})(typeof globalThis==='object'?globalThis:this);
