'use strict';
const assert=require('node:assert/strict');
const v=require('../dist/art-direction-v4.js');

assert.deepEqual(v.conditionBands([{condition:20},{condition:49},{condition:50},{condition:79},{condition:80},{condition:100},{condition:null}]),[
 {label:'0–49',value:2},{label:'50–79',value:2},{label:'80–100',value:2}
]);
assert.deepEqual(v.conditionBands([]).map(x=>x.value),[0,0,0]);
const money=[{label:'Aujourd’hui',value:1200},{label:'S+1',value:1100},{label:'S+2',value:1180}];
const original=JSON.stringify(money);
assert.deepEqual(v.cashMovements(money),[{label:'S+1',change:-100,balance:1100},{label:'S+2',change:80,balance:1180}]);
assert.equal(JSON.stringify(money),original,'weekly differences must not mutate finance model');
assert.deepEqual(v.cashMovements([{label:'S0',value:0}]),[]);
assert.deepEqual(v.cashMovements([]),[]);
const youth=[
 {name:'A',note:55,potential:70,age:19,position:'Pilier'},
 {name:'B',note:45,potential:85,age:18,position:'Centre'},
 {name:'C',note:80,potential:75,age:21,position:'Ouverture'},
 {name:'D',note:null,potential:80,age:19}
];
const old=JSON.stringify(youth),gaps=v.academyGaps(youth);
assert.deepEqual(gaps.map(x=>[x.name,x.gap]),[['B',40],['A',15],['C',0]]);
assert.equal(JSON.stringify(youth),old,'academy projections must be read-only');
const prospects=[
 {name:'Public A',price:5000,salary:800},
 {name:'Public B',price:0,salary:600},
 {name:'Public C',price:9000,salary:1000},
 {name:'No data',price:null,salary:100}
];
const costs=v.publicCosts(prospects);
assert.deepEqual(costs,{count:3,zeroPrime:1,minPrime:0,minSalary:600,medianSalary:800});
assert.equal(v.publicCosts([]).count,0);
assert.equal(v.publicCosts([]).medianSalary,null);
assert.equal(JSON.stringify(prospects),JSON.stringify([
 {name:'Public A',price:5000,salary:800},
 {name:'Public B',price:0,salary:600},
 {name:'Public C',price:9000,salary:1000},
 {name:'No data',price:null,salary:100}
]),'market comparisons must be read-only');
const model={
 club:{name:'Club',abbr:'CL',cash:2500000},
 season:1,squad:[{id:1},{id:2},{id:3}],
 availability:[{label:'Disponibles',value:2},{label:'Blessés',value:1}],
 standings:[{mine:true,rank:4,points:25}],
 next:{opponent:{abbr:'ADV'},home:false,neutral:false}
};
const signals=v.decisionSignals(model);
assert.equal(signals.length,4);
assert.equal(signals[0].value,'ADV');
assert.equal(signals[1].value,'2 / 3');
assert.equal(signals[2].value,'4e');
assert.equal(signals[3].route,'finance');
assert.deepEqual(v.decisionSignals({...model,next:null,standings:[]}).map(x=>x.route),['tactics','team','league','finance']);
assert.ok(!Object.keys(v).some(k=>/save|write|mutate|commit/i.test(k)),'only read-only visualization API');
console.log('PASS V4.2: decision board, XV condition, native weekly deltas, academy ceilings, public-only market, missing values, pure data');
