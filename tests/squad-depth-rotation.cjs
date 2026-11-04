'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync(require('node:path').join(__dirname,'../dist/manager-squad.js'),'utf8');
const players=[
 {id:'a',name:'Pilier A',condition:92,load:20,injury:0},
 {id:'b',name:'Pilier B',condition:65,load:20,injury:0},
 {id:'c',name:'Pilier C',condition:90,load:85,injury:0},
 {id:'d',name:'Pilier D',condition:95,load:10,injury:2},
 {id:'e',name:'Pilier E',condition:85,load:35,injury:0}
];
const context={
 club:()=>({players}),slotEligible:(p,slot)=>slot===0,fitScore:p=>p.condition,
 FAMILIES:[0],POS:['Pilier'],
 physicalLoadValue:p=>p.load,roleNote:p=>p.condition,render:()=>{},squadTab:'depth',
 console
};
vm.createContext(context);
vm.runInContext(source,context);
const readiness=p=>JSON.parse(JSON.stringify(vm.runInContext('squadDepthReadiness('+JSON.stringify(p)+')',context)));
assert.deepEqual(readiness(players[0]),{ready:true,reason:'Prêt'});
assert.equal(readiness(players[1]).reason,'Condition faible');
assert.equal(readiness(players[2]).reason,'Charge élevée');
assert.equal(readiness(players[3]).reason,'Blessé');
assert.equal(readiness({condition:NaN,load:10,injury:0}).ready,false);
const html=vm.runInContext('squadDepth()',context);
assert.match(html,/POSTE\(S\) À RISQUE/);
assert.match(html,/2 PRÊTS \/ 4 APTES/);
assert.match(html,/Préparer les 23/);
assert.match(html,/Voir uniquement les postes à risque/);
vm.runInContext('squadDepthAlertsOnly=true',context);
const filtered=vm.runInContext('squadDepth()',context);
assert.match(filtered,/Aucun poste à risque/);
players.pop();
const risk=vm.runInContext('squadDepth()',context);
assert.match(risk,/Rotation fragile/);
assert.match(risk,/1 joueur\(s\) prêt\(s\) manquant\(s\)/);
assert.match(risk,/Pilier A/);
assert.doesNotMatch(risk,/Poste 2/);
assert.equal(context.squadTab,'depth');
console.log(JSON.stringify({passed:true,checks:12}));
