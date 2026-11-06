'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {calculate,mergeRankings,normalize,SPECIALTIES}=require('../tools/rugby-real-2025-26-v9.cjs');
const keys=new Set(Object.values(SPECIALTIES).flat());
const attributes=()=>Object.fromEntries([...keys,...Array.from({length:36-keys.size},(_,i)=>'other'+i)].map(k=>[k,65]));
const player=(id,realName,league='top14',role='Deuxième ligne',extra={})=>({id,realName,league,gameplayPosition:role,attributesV2:attributes(),...extra});
const row=(name,id,minutes=1850,cards=3)=>({name,lnrId:id,historicalClub:'Club S1',historicalPosition:'2ème ligne',stats:{minutes,matches:24,cards,yellow:cards,orange:0,red:0}});
const collection=(rows,metric='cards')=>({schema:'lnr-rotation-defence-2025-26-v9',cutoff:'2026-07-01',v8KnownKeys:[],lists:[{league:'top14',season:'2025-2026',metric,sourceUrl:'https://top14.lnr.fr/classement/joueurs/nombre-de-cartons/2025-2026',ranking:[...rows,...Array.from({length:20-rows.length},(_,i)=>row('Extra '+i,String(100+i),1000,0))]}]});
test('nom normalisé et taille 36 exacte',()=>{assert.equal(normalize('André LÉGER'),normalize('andre leger'));assert.equal(Object.keys(attributes()).length,36);});
test('joueur avant long temps de jeu reçoit proposition mais zéro bonus discipline',()=>{
 const m={players:[player('x','André Léger'),player('z','Autre','prod2')]},data=collection([row('ANDRE LEGER','1')]);
 const before=JSON.stringify(m),r=calculate(m,data,{fixture:true});
 assert.equal(JSON.stringify(m),before);assert.equal(r.matched,1);assert.equal(r.matchedForwards,1);
 assert.equal(r.matches[0].changes.length,1);assert.equal(r.matches[0].changes[0].attribute,'workRate');
});
test('présence dans V8 ou V4 bloque tout double-ajout',()=>{
 const m={players:[player('x','André Léger'),player('z','Autre','prod2')]},data=collection([row('ANDRE LEGER','1')]);data.v8KnownKeys=['top14:1'];
 assert.equal(calculate(m,data,{fixture:true}).changedPlayers,0);
 delete data.v8KnownKeys[0];m.players[0].performance2025_2026={};
 assert.equal(calculate(m,data,{fixture:true}).changedPlayers,0);
});
test('score des cartons ne crée pas de malus ni faux plaquage',()=>{
 const m={players:[player('x','André Léger'),player('z','Autre','prod2')]};
 const r=calculate(m,collection([row('ANDRE LEGER','1',1200,5)]),{fixture:true});
 assert.equal(r.changedPlayers,0);
});
test('statistique incohérente est rejetée',()=>{
 const d=collection([row('ANDRE LEGER','1',2500,3)]);assert.throws(()=>mergeRankings(d),/Impossible playing minutes/);
});
test('nom en double dans master reste ambigu',()=>{
 const m={players:[player('x','André Léger'),player('y','ANDRE LEGER'),player('z','Autre','prod2')]};
 const r=calculate(m,collection([row('ANDRE LEGER','1')]),{fixture:true});
 assert.equal(r.matched,0);assert.equal(r.ambiguous.length,1);
});
