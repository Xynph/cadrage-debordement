'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const view=require('../dist/ui04-academy-components.js'),data=require('../dist/ui04-academy-data.js');
const css=fs.readFileSync(path.join(__dirname,'..','dist','ui04-academy-components.css'),'utf8');
const evil='Jules <img src=x onerror=alert(1)> & "XV"';
const academy={id:'<bad>"id',name:evil,position:'Pilier gauche',family:0,kind:'academy',age:18,note:63,
 potential:86,general:60,gain:3,minutes:0,appearances:0,careerMinutes:0,
 focus:'equilibre',focusOptions:['equilibre','power','stamina'],focusBonus:{},focusXp:0,
 history:[{season:1,age:17,start:58,end:60,minutes:0,appearances:0}],
 badge:'En développement',retirementSeason:19,canPromote:true,promotionBlockedReason:null,
 contractEnd:null,salary:null,condition:100,injury:0};
const young={...academy,id:'young-pro',name:'Paul Jeune',position:'Demi de mêlée',family:4,kind:'professional',
 age:22,note:72,potential:83,gain:2,minutes:450,history:[],focus:'power',contractEnd:4,salary:2000,canPromote:false};
const model={version:1,season:2,clubName:'Stade test',locked:false,academy:[academy],young:[young],
 retired:[{id:'a',name:evil,season:1,age:37,careerMinutes:3500}],
 totals:{academy:1,young:1,youngMinutes:450,groupGain:5,retirementRisk:1,professionalCount:32,promotionSlots:10}};
const source=JSON.stringify(model),a=data.table(model,{kind:'academy'}),y=data.table(model,{kind:'young'});
for(const tab of Object.keys(view.TABS)){
 const html=view.renderCenter(model,{view:tab,table:tab==='young'?y:a});
 assert.match(html,/cd04-tabs/);
 assert.ok(html.includes('data-ui04-tab="'+tab+'"'));
 assert.ok(!html.includes('<img src=x onerror=alert(1)>'));
 assert.ok(!html.includes('onclick='));
}
const home=view.renderCenter(model);
for(const part of ['Le centre de formation','Espoirs','23 ans ou moins','Places restantes chez les pros','/ 86'])
 assert.ok(home.includes(part),part);
const full=view.renderCenter(model,{view:'academy',table:a,selectedId:academy.id,
 attributeLabels:{power:'Puissance',stamina:'Endurance'}});
for(const part of ['data-ui04-action="promote"','data-ui04-action="focus"','Puissance',
 'SUIVI INDIVIDUEL','Historique des saisons','data-ui04-action="native"','&lt;bad&gt;&quot;id'])
 assert.ok(full.includes(part),part);
const search=view.renderCenter(model,{view:'academy',table:a,search:'<script>alert(1)</script>',family:0});
assert.ok(search.includes('&lt;script&gt;')&&!search.includes('<script>'));
assert.match(search,/aria-sort="ascending"/);
assert.match(view.renderCenter(model,{view:'academy',table:data.table(model,{search:'NO-SUCH'})}),/Aucun joueur ne correspond/);
const youngPage=view.renderCenter(model,{view:'young',table:y,selectedId:young.id});
assert.match(youngPage,/Jeunes professionnels/);
assert.match(youngPage,/Pas encore d’historique/);
const history=view.renderCenter(model,{view:'history'});
assert.match(history,/Retraites du club/);
assert.ok(history.includes('3\u202f500')||history.includes('3.500')||history.includes('3500'));
const blocked={...model,academy:[{...academy,canPromote:false,promotionBlockedReason:'Effectif professionnel complet (42 joueurs)'}]};
const disabled=view.renderCenter(blocked,{view:'academy',table:data.table(blocked),selectedId:academy.id});
assert.match(disabled,/data-ui04-action="promote"[^>]+disabled/);
assert.match(disabled,/Effectif professionnel complet/);
assert.equal(JSON.stringify(model),source);
assert.throws(()=>view.renderCenter({version:2}),/Données/);
assert.throws(()=>view.renderCenter(model,{view:'academy'}),/Tableau/);
const binding={},actions=[];
const root={addEventListener(k,fn){binding[k]=fn},
 removeEventListener(k,fn){if(binding[k]===fn)delete binding[k]},contains(){return true}};
const unsubscribe=view.bindActions(root,{
 onTab:x=>actions.push(['tab',x]),onSort:x=>actions.push(['sort',x]),onDetails:x=>actions.push(['details',x]),
 onPromote:x=>actions.push(['promote',x]),onNativeProfile:x=>actions.push(['native',x]),
 onClose:()=>actions.push(['close']),onFamily:x=>actions.push(['family',x]),
 onFocus:(id,x)=>actions.push(['focus',id,x]),onSearch:x=>actions.push(['search',x])
});
function target(action,attrs={},value='',disabled=false){
 return {closest:()=>({getAttribute:k=>k==='data-ui04-action'?action:attrs[k],value,disabled})};
}
binding.click({target:target('tab',{'data-ui04-tab':'academy'})});
binding.click({target:target('sort',{'data-ui04-sort':'potential'})});
binding.click({target:target('details',{'data-ui04-id':'a'})});
binding.click({target:target('promote',{'data-ui04-id':'a'})});
binding.click({target:target('promote',{'data-ui04-id':'a'},'',true)});
binding.click({target:target('native',{'data-ui04-id':'a'})});
binding.click({target:target('close')});
binding.change({target:target('family',{},'0')});
binding.change({target:target('focus',{'data-ui04-id':'a'},'stamina')});
binding.change({target:target('focus',{'data-ui04-id':'a'},'power',true)});
binding.input({target:target('search',{},'Pierre')});
assert.deepEqual(actions,[['tab','academy'],['sort','potential'],['details','a'],['promote','a'],
 ['native','a'],['close'],['family','0'],['focus','a','stamina'],['search','Pierre']]);
unsubscribe();assert.equal(Object.keys(binding).length,0);
for(const term of ['.cd04-scroll','html[data-cd-theme="tribune"] .cd04','@media(max-width:600px)','prefers-reduced-motion:reduce',':focus-visible'])
 assert.ok(css.includes(term),term);
const context=vm.createContext({globalThis:{},Intl});
vm.runInContext(fs.readFileSync(path.join(__dirname,'..','dist','ui04-academy-components.js'),'utf8'),context);
assert.equal(typeof context.globalThis.CDUI04AcademyComponents.renderCenter,'function');
console.log(JSON.stringify({passed:true,checks:['four views','original FM-like layout','owned real development',
 'focus and promotion callbacks','historical non-fabrication','XSS escaping','empty states',
 'disabled promotions','events delegation and cleanup','responsive accessible CSS','UMD browser','immutable source']}));