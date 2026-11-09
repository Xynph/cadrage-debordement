'use strict';
const {test}=require('node:test'),a=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const published=require('../native/engine/world-venues.cjs');
const srp=require('../native/engine/srp-venues-2027.json');
const schedule=require('../native/engine/srp-calendar-2027.json');
const clubs=new Map(require('../native/engine/world-pacific-extension.json').clubs.map(({id,key})=>[key,id]));

test('Le terrain par rencontre Pacifique se projette seulement sur le bon match de 2027',()=>{
 a.equal(Object.keys(srp.venues).length,80);
 let neutral=0;
 for(const match of schedule.regular){
  const f=Object.freeze({id:match.id,phase:'league',competitionId:'srp',date:match.date,
   homeId:clubs.get(match.homeKey),awayId:clubs.get(match.awayKey),neutral:match.venuePolicy==='centralised-super-round'});
  const row=srp.venues[f.id];
  a.ok(row?.venue, f.id);
  a.equal(published(f,1),row.venue,f.id);
  if(f.neutral){neutral++;a.equal(published(f,1),'One New Zealand Stadium · Christchurch');}
  a.equal(published(f,2),null);
  a.equal(published({...f,homeId:f.awayId,awayId:f.homeId},1),null);
  a.equal(published({...f,competitionId:'jlo-d1'},1),null);
  a.equal(published({...f,phase:'semi'},1),null);
  a.equal(published({...f,date:'2027-01-01'},1),null);
  a.equal(published({...f,neutral:!f.neutral},1),null);
 }
 a.equal(neutral,5);
});

test('La carrière des Crusaders montre ses deux rencontres distinctes à Christchurch et ne stocke pas le libellé',t=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-srp-venue-'));
 const b=require('../native/engine/worker.cjs').createBridge({dataDir:dir,seed:403,now:1788134400000});
 t.after(()=>{b.close();fs.rmSync(dir,{recursive:true,force:true});});
 let n=0;
 const act=(command,payload={})=>{const res=b.handle({id:++n,command,payload});a.equal(res.ok,true,res.error);return res.model;};
 const model=act('new_career',{mode:'world-champ',club:61});
 const rows=model.calendar.filter(f=>f.competitionId==='srp');
 a.equal(rows.length,16);
 a.equal(rows[0].venue,'One New Zealand Stadium · Christchurch');
 a.equal(rows[0].neutral,false);
 const superRound=rows.find(f=>f.neutral);
 a.ok(superRound);
 a.equal(superRound.venue,'One New Zealand Stadium · Christchurch');
 a.equal(superRound.date,'2027-04-02');
 const archive=JSON.parse(act('export').meta.exportText).state;
 const f=archive.worldMode.fixtures.find(f=>f.id===superRound.id);
 a.equal(f.neutral,true);
 a.equal(f.venue,null);
 a.equal(f.homeId,superRound.home.id);
 a.equal(f.awayId,superRound.away.id);
});

test('Les 164 lieux japonais distinguent un stade publié des terrains encore à confirmer',()=>{
 const {venues}=require('../native/engine/jlo-venues-2026-27.json');
 const D1=require('../native/engine/jlo-d1-calendar-2026-27-public.json');
 const D2=require('../native/engine/jlo-d2-calendar-2026-27-public.json');
 a.equal(Object.keys(venues).length,164);
 let known=0,unknown=0;
 for(const [schedule,competitionId] of [[D1,'jlo-d1'],[D2,'jlo-d2']]){
  for(const match of schedule.regular){
   const row=venues[match.id];
   const date=match.date??[...match.dateOptions].sort()[0];
   const f={id:match.id,date,competitionId,homeId:Number(match.homeKey.slice(9)),awayId:Number(match.awayKey.slice(9)),phase:'league',neutral:false};
   a.deepEqual([row.date,row.homeId,row.awayId,row.neutral],[f.date,f.homeId,f.awayId,f.neutral],match.id);
   a.equal(published(f,1),row.venue??'Stade à confirmer',match.id);
   a.equal(published(f,2),null);
   if(row.venue===null)unknown++;else known++;
  }
 }
 a.equal(known,128);a.equal(unknown,36);
});

test('Une carrière japonaise affiche deux terrains à domicile distincts sans modifier ses fixtures',t=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-jlo-venue-'));
 const b=require('../native/engine/worker.cjs').createBridge({dataDir:dir,seed:403,now:1788134400000});
 t.after(()=>{b.close();fs.rmSync(dir,{recursive:true,force:true});});
 const res=b.handle({id:1,command:'new_career',payload:{mode:'world-champ',club:85}});
 a.equal(res.ok,true,res.error);
 const rows=res.model.calendar.filter(f=>f.home.id===85);
 a.equal(rows.length,7);
 a.equal(rows.filter(f=>f.venue==='SECOM RUGBY STADIUM · Sayama').length,6);
 a.equal(rows.find(f=>f.date==='2027-03-07').venue,'Kawagoe Sports Park Athletics Stadium · Kawagoe');
 const ex=b.handle({id:2,command:'export',payload:{}});
 a.equal(ex.ok,true,ex.error);
 const f=JSON.parse(ex.model.meta.exportText).state.worldMode.fixtures.find(f=>f.id===rows[0].id);
 a.equal(f.homeId,85);
 a.equal(f.venue,undefined);
});

test('Les 234 rencontres PREM et URC ne reprennent que le terrain lié à leur identifiant source',()=>{
 const {venues}=require('../native/engine/prem-urc-venues-2026-27.json');
 const R=require('../native/engine/world-registry.json');
 a.equal(Object.keys(venues).length,234);
 const pending=[],names=new Set();
 for(const match of [...R.initialFixtures.prem,...R.initialFixtures.urc]){
  const f={...match,neutral:false},row=venues[f.id];
  a.deepEqual([row.sourceFixtureId,row.date,row.homeId,row.awayId],[f.sourceFixtureId,f.date,f.homeId,f.awayId]);
  a.equal(published(f,1),row.venue??'Stade à confirmer');
  a.equal(published({...f,sourceFixtureId:f.sourceFixtureId+1},1),null);
  if(row.venue===null)pending.push(row.sourceFixtureId);else names.add(row.venue);
 }
 a.deepEqual(pending.sort((x,y)=>x-y),[294983,294993]);
 a.ok([...names].some(s=>s.includes('Tottenham Hotspur Stadium')));
 a.ok([...names].some(s=>s.includes('Hampden')));
});