'use strict';
const assert=require('node:assert/strict');
const v=require('../dist/art-direction-v4.js');

const finance=[
 {label:'Aujourd’hui',value:4000000},
 {label:'S+1',value:3850000},
 {label:'S+2',value:3930000}
];
assert.deepEqual(v.financeKeypoints(finance),{
 start:4000000,end:3930000,change:-70000,
 low:3850000,lowLabel:'S+1',high:4000000,highLabel:'Aujourd’hui'
},'native cash forecasts provide exact high/low/change landmarks');
assert.equal(v.financeKeypoints([]),null);
const plot=v.lineChart(finance,'Trésorerie projetée',true);
assert.match(plot,/Trésorerie projetée/);
assert.match(plot,/Lire les valeurs/,'the underlying numerical table remains accessible');
const coords=plot.match(/<polyline class="da4-line" points="([^"]+)"/);
assert.ok(coords,'cash flow curve is rendered');
const y=coords[1].split(' ').map(pair=>Number(pair.split(',')[1]));
assert.ok(y.every(Number.isFinite),'no invalid point');
assert.ok(Math.max(...y)-Math.min(...y)>40,'nonzero money movement is visible with a meaningful local vertical scale');
assert.doesNotMatch(plot,/NaN|Infinity/);
assert.doesNotMatch(v.lineChart([{label:'S0',value:0}],'Zero'),/NaN|Infinity/);
assert.doesNotMatch(v.lineChart([{label:'S0',value:-100},{label:'S1',value:200}],'Cross zero'),/NaN|Infinity/);

const team=[
 {family:0},{family:1},{family:2},{family:3},
 {family:4},{family:5},{family:6},{family:7},{family:8}
];
assert.deepEqual(v.groupLines(team),[
 {label:'Avants',value:4},{label:'Charnière',value:2},{label:'Trois-quarts',value:3}
]);
assert.equal(v.groupLines([]).reduce((s,x)=>s+x.value,0),0);

const needs=[
 {slot:0,score:10,pos:'Pilier',reasons:['manque']},
 {slot:1,score:70,pos:'Talonneur',reasons:['rotation']},
 {slot:2,score:70,pos:'Deuxième ligne',reasons:['absence']},
 {slot:3,score:0,pos:'Troisième ligne',reasons:[]},
 {slot:4,score:45,pos:'Mêlée',reasons:[]}
];
const before=JSON.stringify(needs);
assert.deepEqual(v.priorityNeeds(needs).map(x=>x.slot),[1,2,4],'top three are ordered by native score, then jersey slot');
assert.equal(JSON.stringify(needs),before,'priority extraction is read-only');
assert.deepEqual(v.priorityNeeds([{slot:0,score:0}]),[]);

const standings=[
 {id:1,abbr:'A',rank:1,points:46},
 {id:2,abbr:'B',rank:2,points:42},
 {id:3,abbr:'C',rank:3,points:30}
];
const old=JSON.stringify(standings),g=v.standingsGaps(standings,2);
assert.equal(g.leader,46);
assert.deepEqual(g.rows.map(x=>x.gap),[0,4,16]);
assert.equal(g.rows.filter(x=>x.mine).length,1);
assert.equal(JSON.stringify(standings),old,'league gap computations do not change native ranking');
assert.deepEqual(v.standingsGaps([],2).rows,[]);
console.log('PASS V4.1: scaled cash flow, real financial landmarks, positional balance, ranked native needs, league gaps, pure model projections');
