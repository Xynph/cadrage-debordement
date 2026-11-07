'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const ui=require('../dist/premium-editorial.js');
const snapshot=()=>({club:{id:0,name:'Stade des Brumes',abbr:'SDB',cash:7500000},season:1,round:0,roundTitle:'Journée 1 / 26',phase:'league',competition:'LIGUE PREMIÈRE',squad:[{id:'p0-0-1',name:'Louis Test',position:'Pilier',condition:91,injury:0}],results:[],standings:[{id:0,rank:1,abbr:'SDB',points:0,played:0,mine:true}],next:{home:true,stadium:'Arène des Brumes',opponent:{id:1,name:'Faucons du Golfe',abbr:'FDG'}},fixtures:[]});
test('Bureau sans résultats : aucune série de scores inventée, données intactes',()=>{
 const m=snapshot(),before=JSON.stringify(m),html=ui.officeView(m,{});
 assert.match(html,/Aucun match joué/);assert.match(html,/Faucons du Golfe/);assert.match(html,/91/);
 assert.doesNotMatch(html,/NaN|undefined/);assert.equal(JSON.stringify(m),before);
});
test('Bureau LNR sans faux visages et textes métier échappés',()=>{
 const m=snapshot();m.club.name='<img src=x onerror=alert(1)>';m.next.opponent.name='A & B';
 const html=ui.officeView(m,{lnr:true,messages:[{id:'msg-1',title:'<script>danger</script>',body:'Texte',action:'team'}],decisions:[{title:'Contrats',detail:'À voir',action:'market',tab:'contracts'}]});
 assert.doesNotMatch(html,/class="ed-portrait|<script>|<img src=x/);assert.match(html,/A &amp; B/);assert.match(html,/&lt;script&gt;/);assert.match(html,/data-ed-office-tab="contracts"/);
});
test('Bureau de fin de saison et données incomplètes explicites',()=>{
 const html=ui.officeView({club:{},squad:[],standings:[],results:[],phase:'ended'},{});
 assert.match(html,/Saison terminée/);assert.doesNotMatch(html,/NaN|undefined|Préparer le match/);
});
test('scores consultables et condition zéro conservée',()=>{
 const m=snapshot();m.squad[0].condition=0;m.results=[{label:'J1',own:0,against:17,outcome:'D'}];
 const html=ui.officeView(m,{});assert.match(html,/J1[^]*0–17/);assert.match(html,/data-ed-info="[^"]*0–17/);assert.match(html,/0<small>\/100/);
});
