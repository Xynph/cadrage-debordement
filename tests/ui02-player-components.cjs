'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const ui=require('../dist/ui02-player-components.js');
const css=fs.readFileSync(path.join(__dirname,'..','dist','ui02-player-components.css'),'utf8');

const p={id:'p<"evil"',name:'Noé <script>alert(1)</script> & "Test"',position:'Centre',family:7,age:24,
 note:83,potential:91,condition:89,physical:31,salary:8800,contract:4,minutes:780,
 injury:0,status:'Titulaire',development:'equilibre',
 attributes:{
  scrum:{label:'Mêlée',value:38},lineout:{label:'Touche',value:40},power:{label:'Puissance',value:70},
  tackle:{label:'Plaquage',value:84},discipline:{label:'Discipline',value:65},speed:{label:'Vitesse',value:87},
  pass:{label:'Passe',value:85},kick:{label:'Jeu au pied',value:72},goal:{label:'But',value:35},
  mental:{label:'Mental',value:78},stamina:{label:'Endurance',value:81}
 },history:[{season:1,age:23,start:75,end:83,minutes:1660,appearances:21}]};
const snapshot=JSON.stringify(p);
const overview=ui.renderPlayer(p);
assert.match(overview,/FICHE JOUEUR/);
assert.match(overview,/CD02-NEVER-HERE|cd02-player/i);
assert.match(overview,/NOTE AU POSTE/);
assert.match(overview,/83/);
assert.match(overview,/role="tablist"/);
assert.match(overview,/aria-selected="true"/);
assert.match(overview,/89 %/);
assert.match(overview,/31\/100/);
assert.ok(overview.includes('&lt;script&gt;'));
assert.ok(!overview.includes('<script>alert(1)</script>'));
assert.ok(!overview.includes('data-cd02-player="p<'));
assert.ok(!overview.includes('onclick='));
for(const tab of Object.keys(ui.TABS)){
 const markup=ui.renderPlayer(p,{tab});
 assert.match(markup,/role="tabpanel"/);
 assert.match(markup,new RegExp('aria-label="'+ui.TABS[tab]+'"'));
 assert.match(markup,new RegExp('data-cd02-tab="'+tab+'" aria-selected="true"'));
}
const attrs=ui.renderPlayer(p,{tab:'attributs'});
assert.match(attrs,/Conquête/);
assert.match(attrs,/Mental et endurance/);
assert.equal((attrs.match(/cd02-attribute-number/g)||[]).length,11);
const contract=ui.renderPlayer(p,{tab:'contrat'});
assert.match(contract,/Saison 4/);
assert.match(contract,/Salaire hebdomadaire/);
const history=ui.renderPlayer(p,{tab:'progression'});
assert.match(history,/1 660|1.660|1660/);
assert.match(history,/21/);
const emptyHistory=ui.renderPlayer({...p,history:[]},{tab:'progression'});
assert.match(emptyHistory,/Aucun historique de progression enregistré/);
const unknown=ui.renderPlayer({...p,condition:null,note:null,attributes:{evil:{label:'<img src=x onerror=alert(1)>',value:null}}},{tab:'attributs'});
assert.ok(!unknown.includes('<img src=x'));
assert.ok(unknown.includes('&lt;img'));
assert.equal(ui.formatValue('salary',null),'—');
assert.equal(ui.formatValue('contract',4),'Saison 4');
assert.equal(ui.formatValue('injury',0),'Aucune');
assert.equal(ui.formatValue('condition',89),'89 %');
assert.equal(ui.formatValue('note',NaN),'—');
const table={columns:[{key:'name',label:'Joueur'},{key:'position',label:'Poste'},
 {key:'salary',label:'Salaire'}],total:1,sortBy:'salary',direction:'desc',
 rows:[{id:p.id,cells:{name:p.name,position:'Centre',salary:8800}}]};
const markup=ui.renderTable(table,{preset:'contracts',search:'<script>alert(2)</script>'});
assert.match(markup,/aria-sort="descending"/);
assert.match(markup,/data-cd02-action="sort"/);
assert.match(markup,/data-cd02-action="column"/);
assert.match(markup,/data-cd02-action="preset"/);
assert.match(markup,/data-cd02-action="search"/);
assert.match(markup,/data-cd02-action="player"/);
assert.match(markup,/type="checkbox"/);
assert.match(markup,/type="search"/);
assert.ok(!markup.includes('<script>alert(2)</script>'));
assert.ok(markup.includes('&lt;script&gt;'));
assert.ok(!markup.includes('onclick='));
assert.match(ui.renderTable({...table,rows:[],total:0}),/Aucun joueur ne correspond/);
assert.throws(()=>ui.renderTable({...table,columns:[{key:'__proto__'}]}),/Colonne non reconnue/);
assert.throws(()=>ui.renderPlayer({id:''}),/Profil joueur/);
const compare=ui.renderComparison({players:[{name:p.name},{name:'Baptiste Dubois'}],sameFamily:false,
 rows:[{key:'salary',label:'Salaire / semaine',values:[8800,7600]},
 {key:'tackle',label:'Plaquage',values:[84,76]}]});
assert.match(compare,/Postes différents/);
assert.match(compare,/Plaquage/);
assert.ok(!compare.includes('<script>alert(1)</script>'));

const hooks={};
const fakeRoot={
 addEventListener(event,fn){hooks[event]=fn},
 removeEventListener(event,fn){if(hooks[event]===fn)delete hooks[event]},
 contains(){return true},
 querySelectorAll(){return [{value:'name'},{value:'condition'}]}
};
const fired=[];
const dispose=ui.bindActions(fakeRoot,{
 onTab:x=>fired.push(['tab',x]),onSort:x=>fired.push(['sort',x]),
 onPlayer:x=>fired.push(['player',x]),onPreset:x=>fired.push(['preset',x]),
 onSearch:x=>fired.push(['search',x]),onColumns:x=>fired.push(['columns',x.join(',')])
});
const target=(action,attrs={},value='')=>({closest:()=>({
 getAttribute:key=>key==='data-cd02-action'?action:attrs[key],
 value
})});
hooks.click({target:target('tab',{'data-cd02-tab':'attributs'})});
hooks.click({target:target('sort',{'data-cd02-sort':'salary'})});
hooks.click({target:target('player',{'data-cd02-id':'p1'})});
hooks.change({target:target('preset',{},'contracts')});
hooks.change({target:target('column',{},'name')});
hooks.input({target:target('search',{},'Dubois')});
assert.deepEqual(fired,[['tab','attributs'],['sort','salary'],['player','p1'],
 ['preset','contracts'],['columns','name,condition'],['search','Dubois']]);
dispose();
assert.equal(Object.keys(hooks).length,0);
assert.equal(JSON.stringify(p),snapshot,'Rendering must not mutate the source profile');
assert.ok(css.includes('html[data-cd-theme="tribune"] .cd02'));
assert.ok(css.includes('@media(max-width:760px)'));
assert.ok(css.includes('@media(max-width:410px)'));
assert.ok(css.includes('@media(prefers-reduced-motion:reduce)'));
assert.ok(css.includes(':focus-visible'));
const sandbox=vm.createContext({globalThis:{},Intl,console});
vm.runInContext(fs.readFileSync(path.join(__dirname,'..','dist','ui02-player-components.js'),'utf8'),sandbox);
assert.equal(typeof sandbox.globalThis.CDUI02Components.renderPlayer,'function');
console.log(JSON.stringify({passed:true,checks:['four profile tabs','native values only','full 11 attributes','contract','history and empty state','XSS escaping','sort and search table','column picker','two-player comparison','event binding/dispose','responsive theme','no career mutation','UMD browser load']}));
