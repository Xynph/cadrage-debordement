'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const view=require('../dist/ui03-scout-components.js');
const data=require('../dist/ui03-scout-data.js');
const css=fs.readFileSync(path.join(__dirname,'..','dist','ui03-scout-components.css'),'utf8');
const evil='Camille <img src=x onerror=alert(1)> & "Rugby"';
const demo={
 pool:[{id:'x"<bad>',name:evil,pos:'Centre',fam:7,age:26,salary:9000,price:370000,rating:99,skills:{pass:99},dev:{potential:99}},
 {id:'y',name:'Adrien Dupont',pos:'Talonneur',fam:1,age:23,salary:8500,price:200000,rating:80}],
 reports:[{id:'r-1',playerId:'x"<bad>',name:evil,pos:'Centre',family:7,age:25,
 note:72,potential:86,salary:9000,price:370000,grade:'B',season:1,week:5}],
 missions:[{id:'mission-1',family:7,maxAge:30,budget:500000,maxWage:12000,remaining:1,status:'active',week:5},
 {id:'mission-2',family:0,maxAge:28,budget:700000,maxWage:14000,remaining:2,status:'queued',week:5}],
 watch:['x"<bad>','missing'],
 needs:[{slot:12,family:7,pos:'Centre',score:43,healthy:1,durable:0,youth:1,need:true,reasons:['Un seul joueur','Besoin de relève']}],
 week:6,season:1
};
const original=JSON.stringify(demo);
const model=data.buildCenter(demo,{evidence:p=>p.id===demo.pool[0].id?{
 seen:true,stale:false,noteMin:70,noteMax:74,potentialMin:81,potentialMax:91,label:'Rapport S1 · semaine 5'
}:{seen:false,stale:false,noteMin:55,noteMax:75,potentialMin:null,potentialMax:null,label:'Non observé'}});
const snapshot=JSON.stringify(model);
const all=data.candidateTable(model,{sortBy:'name'});
for(const tab of Object.keys(view.TABS)){
 const html=view.renderCenter(model,{view:tab,table:all});
 assert.ok(html.includes('Centre de recrutement'));
 assert.match(html,/cd03-tabs/);
 assert.match(html,new RegExp('data-ui03-tab="'+tab+'"'));
 assert.ok(!html.includes('<img src=x onerror=alert(1)>'));
 assert.ok(html.includes('&lt;img')||tab==='missions'||tab==='overview');
 assert.ok(!html.includes('onclick='));
}
const overview=view.renderCenter(model);
assert.match(overview,/Postes à renforcer/);
assert.match(overview,/43\/100/);
assert.match(overview,/Missions actives/);
const candidates=view.renderCenter(model,{view:'candidates',table:all,search:'<script>alert(1)</script>',family:'7'});
assert.match(candidates,/70–74/);
assert.match(candidates,/81–91/);
assert.match(candidates,/Potentiel inconnu/);
assert.match(candidates,/Rapport disponible/);
assert.ok(!candidates.includes('<script>alert(1)</script>'));
assert.match(candidates,/&lt;script&gt;/);
assert.match(candidates,/data-ui03-action="watch"/);
assert.match(candidates,/aria-sort="ascending"/);
assert.match(candidates,/data-ui03-action="search"/);
const onlyUnknown=data.candidateTable(model,{family:1});
const htmlUnknown=view.renderCenter(model,{view:'candidates',table:onlyUnknown});
assert.match(htmlUnknown,/Potentiel inconnu/);
assert.ok(!htmlUnknown.includes('86'));
assert.ok(!htmlUnknown.includes('99'));
const reports=view.renderCenter(model,{view:'reports'});
assert.match(reports,/Les notes et potentiels ci-dessous sont des évaluations enregistrées/);
assert.match(reports,/Rapport B/);
assert.match(reports,/Potentiel observé/);
assert.match(reports,/>86</);
const missions=view.renderCenter(model,{view:'missions'});
for(const field of ['family','age','fee','salary'])assert.match(missions,new RegExp('name="'+field+'"'));
assert.match(missions,/type="submit"/);
assert.match(missions,/Missions natives|MISSIONS NATIVES/);
assert.match(missions,/En attente/);
const followed=view.renderCenter(model,{view:'watch'});
assert.match(followed,/Plus disponible/);
assert.match(followed,/Les anciennes données ne sont pas actualisées/);
assert.match(followed,/Ne plus suivre/);
const none=view.renderCenter({...model,reports:[]},{view:'reports'});
assert.match(none,/Aucun rapport/);
const noneTable=view.renderCenter(model,{view:'candidates',table:data.candidateTable(model,{search:'absent 10000'})});
assert.match(noneTable,/Aucun candidat ne correspond/);
assert.equal(JSON.stringify(model),snapshot,'render must not mutate model');
assert.equal(JSON.stringify(demo),original,'render must not mutate native snapshots');
assert.match(view.range(55,75),/55–75/);
assert.equal(view.range(null,null),'Non connu');

const handlers={};const called=[];
const root={
 addEventListener(name,fn){handlers[name]=fn},
 removeEventListener(name,fn){if(handlers[name]===fn)delete handlers[name]},
 contains(){return true}
};
const done=view.bindActions(root,{
 onTab:x=>called.push(['tab',x]),onSearch:x=>called.push(['search',x]),
 onFamily:x=>called.push(['family',x]),onSort:x=>called.push(['sort',x]),
 onObservedOnly:x=>called.push(['observed',x]),onWatchedOnly:x=>called.push(['watched',x]),
 onWatch:x=>called.push(['watch',x]),onCandidate:x=>called.push(['candidate',x]),
 onMission:x=>called.push(['mission',x])
});
function target(action,attr={},value='',checked=false){
 return {closest:()=>({getAttribute:k=>k==='data-ui03-action'?action:attr[k],value,checked})};
}
handlers.click({target:target('tab',{'data-ui03-tab':'missions'})});
handlers.click({target:target('sort',{'data-ui03-sort':'price'})});
handlers.click({target:target('watch',{'data-ui03-id':'y'})});
handlers.click({target:target('candidate',{'data-ui03-id':'y'})});
handlers.change({target:target('family',{},'7')});
handlers.change({target:target('observed',{},'',true)});
handlers.change({target:target('watched',{},'',true)});
handlers.input({target:target('search',{},'Camille')});
let prevented=false;
const form={
 matches:selector=>selector==='[data-ui03-mission]',
 elements:{namedItem:k=>({value:({family:'7',age:'28',fee:'700000',salary:'12000'})[k]})}
};
handlers.submit({target:form,preventDefault(){prevented=true}});
assert.equal(prevented,true);
assert.deepEqual(called,[
 ['tab','missions'],['sort','price'],['watch','y'],['candidate','y'],['family','7'],
 ['observed',true],['watched',true],['search','Camille'],
 ['mission',{family:7,maxAge:28,budget:700000,maxWage:12000}]
]);
form.elements.namedItem=k=>({value:({family:'99',age:'28',fee:'700000',salary:'12000'})[k]});
handlers.submit({target:form,preventDefault(){}});
assert.equal(called.length,9,'invalid native mission constraints must not be forwarded');
done();assert.equal(Object.keys(handlers).length,0);
assert.ok(css.includes('.cd03-table-scroll'));
assert.ok(css.includes('html[data-cd-theme="tribune"] .cd03'));
assert.ok(css.includes('@media(max-width:630px)'));
assert.ok(css.includes('prefers-reduced-motion:reduce'));
assert.ok(css.includes(':focus-visible'));
const context=vm.createContext({globalThis:{},Intl});
vm.runInContext(fs.readFileSync(path.join(__dirname,'..','dist','ui03-scout-components.js'),'utf8'),context);
assert.equal(typeof context.globalThis.CDUI03ScoutComponents.renderCenter,'function');
console.log(JSON.stringify({passed:true,checks:[
 'five UI tabs','native needs and missions','public estimate and observed report','no unscouted potential',
 'dated report','historical unavailable candidate','responsive CSS','HTML escaping',
 'no game mutation','delegated actions','native mission limits','unsubscribe','browser UMD']}));