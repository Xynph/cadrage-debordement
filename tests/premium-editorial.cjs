'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const ui=require('../dist/premium-editorial.js');
test('quatorze routes natives ont une composition et un visuel local',()=>{
 assert.equal(Object.keys(ui.routes).length,14);
 for(const [route,data] of Object.entries(ui.routes)){
  assert.ok(data.title&&data.image,route);assert.ok(fs.existsSync(__dirname+'/../dist/assets/editorial/'+data.image+'.webp'));
 }
});
test('projection de groupe sans mutation et valeurs manquantes explicites',()=>{
 const m={club:{cash:1000},squad:[{condition:90},{condition:60},{condition:null},{condition:20}],standings:[],results:[]};
 const original=JSON.stringify(m),s=ui.groupSummary(m);
 assert.deepEqual(s.condition,[1,1,1]);assert.equal(s.average,170/3);assert.equal(JSON.stringify(m),original);
 assert.equal(ui.groupSummary({}).average,null);
});
test('radar ignore les attributs absents et borne les données finies',()=>{
 assert.deepEqual(ui.radarValues({attributes:{power:200,speed:-10,tackle:NaN}}),[{label:'Puissance',value:100},{label:'Vitesse',value:0}]);
 assert.equal(ui.radarValues({}).length,0);
});
test('blasons originaux distincts et échappement des labels',()=>{
 const crests=Array.from({length:14},(_,i)=>ui.crest(i,'CLUB'));
 assert.equal(new Set(crests).size,14);assert.match(ui.crest(2,'<x>'),/&lt;x&gt;/);assert.doesNotMatch(ui.crest(2,'<x>'),/<x>/);
});
test('graphique de condition expose les valeurs exactes sans NaN',()=>{
 const html=ui.conditionChart({squad:[{condition:80},{condition:65},{condition:40}]});
 assert.match(html,/Condition du groupe/);assert.match(html,/80–100/);assert.match(html,/<button type="button"/);assert.doesNotMatch(html,/NaN|undefined/);
});
test('les résultats absents ne deviennent pas une fausse série',()=>{
 assert.match(ui.resultsChart([]),/Aucun match joué/);
 const html=ui.resultsChart([{label:'J1',own:20,against:17,outcome:'V'}]);
 assert.match(html,/20/);assert.match(html,/17/);assert.match(html,/J1/);
});
test('terrain du XV lié aux vrais identifiants et sans faux portraits LNR',()=>{
 const m={squad:[{id:'a',name:'Louis Test',position:'Pilier'},{id:'b',name:'Hugo Essai',position:'Talonneur'}]};
 const before=JSON.stringify(m),html=ui.lineupView(m,['b','a']);
 assert.match(html,/data-ed-player="b"/);assert.match(html,/Hugo Essai/);assert.match(html,/Poste non attribué/);
 assert.doesNotMatch(ui.lineupView(m,['a'],{portraits:false}),/class="ed-portrait/);
 assert.equal(JSON.stringify(m),before);
});
test('identité du portrait conservée après départ et changement de club',()=>{
 assert.equal(ui.portraitIndex('p0-6-1794000000000'),6);
 const ids=['p0-0-1794000000000','p0-1-1794000000000','p0-2-1794000000000'];
 const before=ids.map(ui.portraitIndex);ids.shift();
 assert.deepEqual(ids.map(ui.portraitIndex),before.slice(1));
 assert.equal(ui.portraitIndex('transfer-abc'),ui.portraitIndex('transfer-abc'));
 assert.equal(new Set(Array.from({length:30},(_,i)=>ui.portraitIndex('p0-'+i+'-1794000000000'))).size,30);
});
