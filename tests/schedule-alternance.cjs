'use strict';
// Alternance domicile/extérieur de tous les calendriers générés (docs/calendrier-alternance-20261111.md).
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const root=path.join(__dirname,'..');
const hash=x=>crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex').slice(0,16);
const fromRounds=rounds=>rounds.flatMap((pairs,round)=>pairs.map(([h,a])=>({round,h,a})));

// kind : 'double' (chaque adversaire deux fois, sens inversés, retour en miroir), 'single', ou fonction (a,b)=>nombre attendu.
function check(label,fixtures,members,{kind='double',maxStreak=2}={}){
 const byClub=new Map(members.map(id=>[id,[]])),rounds=[...new Set(fixtures.map(f=>f.round))].sort((a,b)=>a-b);
 const perRound=new Map(),directed=new Set();
 for(const f of fixtures){
  assert.ok(byClub.has(f.h)&&byClub.has(f.a)&&f.h!==f.a,`${label} : club inconnu ou contre lui-même`);
  const busy=perRound.get(f.round)||new Set();assert.ok(!busy.has(f.h)&&!busy.has(f.a),`${label} : club deux fois journée ${f.round}`);busy.add(f.h);busy.add(f.a);perRound.set(f.round,busy);
  const key=f.h+'>'+f.a;assert.ok(!directed.has(key),`${label} : même réception répétée ${key}`);directed.add(key);
  byClub.get(f.h).push({round:f.round,home:true,o:f.a});byClub.get(f.a).push({round:f.round,home:false,o:f.h});
 }
 const games=byClub.get(members[0]).length;
 for(const [id,list] of byClub){
  list.sort((a,b)=>a.round-b.round);
  const home=list.filter(x=>x.home).length;
  assert.ok(Math.abs(2*home-list.length)<=(list.length%2),`${label} : club ${id} reçoit ${home} fois sur ${list.length}`);
  let run=0;for(let i=0;i<list.length;i++){run=i&&list[i].home===list[i-1].home?run+1:1;assert.ok(run<=maxStreak,`${label} : club ${id} enchaîne ${run} rencontres ${list[i].home?'à domicile':'à l’extérieur'}`);}
  const seen=new Map();for(const x of list){const s=seen.get(x.o)||[];s.push(x.home);seen.set(x.o,s);}
  for(const o of members)if(o!==id){
   const want=typeof kind==='function'?kind(id,o):kind==='double'?2:1,got=seen.get(o)||[];
   assert.equal(got.length,want,`${label} : ${id} contre ${o}`);
   if(want===2)assert.deepEqual(got.slice().sort(),[false,true],`${label} : ${id}-${o} sans inversion aller/retour`);
  }
  if(kind==='double'){
   const half=rounds.length/2,first=list.filter(x=>x.round<rounds[half]),second=list.filter(x=>x.round>=rounds[half]);
   assert.deepEqual(second.map(x=>[x.o,x.home]),first.map(x=>[x.o,!x.home]),`${label} : retour qui n’est pas le miroir inversé de l’aller pour ${id}`);
   assert.ok(Math.abs(2*first.filter(x=>x.home).length-first.length)<=1,`${label} : déséquilibre de la phase aller pour ${id}`);
  }
 }
 for(const [id,list] of byClub)assert.equal(list.length,games,`${label} : nombre de rencontres inégal (${id})`);
}

test('Espoirs : poules Élite, Accession et compatibilité',()=>{
 const E=require('../dist/espoirs-league-v73.js'),A=require('../dist/espoirs-accession-v74.js');
 for(let n=2;n<=12;n++){const ids=Array.from({length:n},(_,i)=>i*3);check('Espoirs '+n,fromRounds(E.roundRobin(ids)),ids,{maxStreak:n===4?3:2});}
 const groups=Array.from({length:4},(_,i)=>Array.from({length:6},(_,j)=>i*6+j)),rounds=E.groupRounds(groups);
 for(const g of groups)check('Espoirs poule',fromRounds(rounds.map(r=>r.filter(p=>g.includes(p[0])))),g);
 const ag=[Array.from({length:10},(_,i)=>i),Array.from({length:10},(_,i)=>i+10)],af=A.fixtures(ag);
 for(const g of ag)check('Accession junior',fromRounds(af.map(r=>r.filter(p=>g.includes(p[0])))),g);
 assert.equal(hash(E.groupRounds(groups,true)),'5e0939071beb1bea');assert.equal(hash(A.fixtures(ag,true)),'024a4df667a2a4c7');
});

test('monde : élite, accession, Premiership et URC générés, déterministes, ancien générateur intact',()=>{
 const {factory}=require('../native/engine/world-competitions.cjs'),C=factory(),reg=require('../native/engine/world-registry.json');
 const shield=new Map(reg.clubs.map(c=>[c.id,c.shield]));
 for(const id of ['elite','accession','prem','urc']){
  const clubs=reg.clubs.filter(c=>c.leagueId===id);
  for(const order of [clubs,clubs.slice().reverse(),clubs.map((c,i)=>clubs[(i*3)%clubs.length])])for(const season of [2027,2030]){
   const fx=C.regularFixtures({clubs:order,competitionId:id,season});
   check(`${id} ${season}`,fx.map(f=>({round:f.round,h:f.homeId,a:f.awayId})),order.map(c=>c.id),id==='urc'?{kind:(a,b)=>shield.get(a)===shield.get(b)?2:1}:{});
   assert.equal(JSON.stringify(C.regularFixtures({clubs:order,competitionId:id,season})),JSON.stringify(fx));
   if(id==='urc')for(const c of order){const games=fx.filter(f=>f.homeId===c.id||f.awayId===c.id),first=games.filter(f=>f.round<9);assert.ok([4,5].includes(first.filter(f=>f.homeId===c.id).length));}
  }
 }
 const legacy={elite:'eb75f6023389d09a',accession:'0f1cd5107d7fa559',prem:'234ca529efeb1a82',urc:'7d5d5e2c4625d803'};
 for(const [id,h] of Object.entries(legacy))assert.equal(hash(C.regularFixtures({clubs:reg.clubs.filter(c=>c.leagueId===id),competitionId:id,season:2027,legacyCalendar:true})),h);
});
