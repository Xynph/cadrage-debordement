'use strict';
// Chemins chauds de la projection (chantier sauvegarde incrémentale, 13/11/2026) : les versions
// rapides doivent rendre exactement le même modèle que les versions d'origine.
const {test}=require('node:test'),assert=require('node:assert/strict');
const managerPlanning=require('../native/engine/manager-planning.cjs');
const knowledge=require('../native/engine/player-knowledge.cjs').factory();

test('planification : candidats dédoublonnés, première occurrence conservée (marché puis interclubs)',()=>{
 const market=[{id:'p1',name:'Marché',pos:'PIL',age:25,salary:2000},{id:'p2',name:'Deux',pos:'TAL',age:26,salary:2100},{id:'p1',name:'Doublon marché',pos:'PIL',age:25,salary:9}];
 const candidates=[{id:'p2',name:'Interclubs',pos:'TAL',age:26,salary:1},{id:'p3',name:'Trois',pos:'CEN',age:22,salary:1500}];
 const model={club:{id:0},meta:{season:1},squad:[],market,clubLife:{interclubMarket:{candidates},managerPlanning:{settings:{scenario:['p1','p2','p3','absent'].map(playerId=>({kind:'recruit',playerId,years:1,salary:1000,fee:10}))}}}};
 const view=managerPlanning.project(model);
 const players=view.scenario.operations.map(o=>o.player?.name??null);
 assert.deepEqual(players,['Marché','Deux','Trois',null]);
 assert.equal(view.scenario.upFront,30,'seules les trois sources présentes comptent');
});

test('connaissance : copie par nœud identique à l’aller-retour JSON, sans partage entre nœuds',()=>{
 const knowledgeOf=stage=>({version:1,owned:false,stage,observedAt:{season:1,week:2,date:null}});
 const visible={
  a:{rating:null,ratingRange:{min:40,max:48},potential:null,potentialRange:{min:50,max:60},knowledge:knowledgeOf('basic'),extra:[1,undefined,NaN,Infinity,()=>1,'x'],skip:undefined,fn:()=>1,nested:{deep:[{n:-0}],nan:NaN}},
  b:{rating:61,ratingRange:null,potential:70,potentialRange:null,knowledge:{version:1,owned:true,stage:'deep',observedAt:null}}
 };
 const model={squad:[{id:'a',name:'A',pos:'PIL',rating:44},{id:'b',name:'B',pos:'TAL',rating:61}],other:{rows:[{playerId:'a',rating:44}]}};
 knowledge.project(model,visible);
 const json=x=>JSON.parse(JSON.stringify(x));
 const first=model.squad[0],second=model.other.rows[0];
 for(const key of ['ratingRange','potentialRange','knowledge','extra','nested'])assert.deepEqual(first[key],json(visible.a[key]),key);
 assert.equal(Object.hasOwn(first,'skip'),false);assert.equal(Object.hasOwn(first,'fn'),false);
 assert.deepEqual(first.extra,[1,null,null,null,null,'x']);
 assert.notEqual(first.knowledge,second.knowledge,'chaque nœud reçoit sa propre copie');
 assert.notEqual(first.knowledge,visible.a.knowledge,'la visibilité source n’est jamais partagée');
 first.knowledge.stage='modifie';assert.equal(second.knowledge.stage,'basic');assert.equal(visible.a.knowledge.stage,'basic');
 assert.equal(model.squad[1].rating,61);assert.equal(model.squad[1].knowledge.owned,true);
});
