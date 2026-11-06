'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const {evaluate,mergeLists,normalize}=require('../tools/rugby-real-2025-26-v8.cjs');
const fields=['ballCarry','evasion','workRate'];
function makePlayer(id,realName,league='prod2',role='Ailier',extra={}){
 return {id,realName,league,gameplayPosition:role,club:'Exemple 2026',attributesV2:Object.fromEntries(Array.from({length:36},(_,i)=>[fields[i]||'x'+i,league==='top14'?79:70])),...extra};
}
function input(players,records,metric='tries'){
 return {master:{players},collected:{schema:'lnr-rankings-2025-26-v8',cutoff:'2026-07-01',lists:[{season:'2025-2026',league:'prod2',metric,sourceUrl:'https://prod2.lnr.fr/classement/joueurs/meilleurs-marqueurs-dessais/2025-2026',ranking:records}]}};
}
const item=(name,lnrId,tries=12)=>({name,lnrId,historicalClub:'Club historique',historicalPosition:'Ailier',stats:{tries,matches:20,minutes:1700}});
test('accents et noms sans case',()=>assert.equal(normalize('Clément MARTINEZ'),normalize('CLEMENT Martinez')));
test('match unique avec identite, statistiques et ajustement modeste',()=>{
 const {master,collected}=input([makePlayer('a','Clément MARTINEZ'),makePlayer('b','Autre Joueur','top14')],[item('CLEMENT Martinez','99')]);
 const old=JSON.stringify(master),r=evaluate(master,collected,{allowFixture:true});
 assert.equal(r.matched,1);assert.equal(r.proD2Matched,1);assert.equal(r.changedPlayers,1);
 assert.ok(r.matches[0].changes.some(x=>x.attribute==='ballCarry'&&x.delta===2));
 assert.equal(JSON.stringify(master),old);
});
test('match identite ambigue bloque',()=>{
 const {master,collected}=input([makePlayer('a','Jean Test'),makePlayer('b','Jean Test')],[item('Jean Test','99')]);
 const r=evaluate(master,collected,{allowFixture:true});assert.equal(r.matched,0);assert.equal(r.ambiguous.length,1);
});
test('pas de doublon V4 et stats conservees comme observation',()=>{
 const {master,collected}=input([makePlayer('a','Lucas MARTINS','prod2','Ailier',{performance2025_2026:{}})],[item('Lucas MARTINS','99')]);
 const r=evaluate(master,collected,{allowFixture:true});assert.equal(r.matched,1);assert.equal(r.changedPlayers,0);assert.equal(r.alreadyObservedNoDoubleCount,1);
});
test('saison illegale rejetee',()=>{
 const x=input([],[]);x.collected.lists[0].season='2026-2027';
 assert.throws(()=>mergeLists(x.collected),/Unexpected source or season/);
});
test('ligne incoherente sur deux tableaux rejetee',()=>{
 const x=input([], [item('Player A','42',5)]).collected;
 x.lists.push({...x.lists[0],ranking:[item('Player A','42',9)]});
 assert.throws(()=>mergeLists(x),/Conflicting official/);
});
