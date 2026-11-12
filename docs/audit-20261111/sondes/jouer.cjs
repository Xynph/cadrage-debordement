// Pilote en lecture seule : joue une carrière jour par jour par l'API publique du worker.
const fs=require('fs'),os=require('os'),path=require('path');
const root=process.argv[2],weeks=+(process.argv[3]||2),club=+(process.argv[4]||29),mode=process.argv[5]||'common';
const {createBridge}=require(path.join(root,'native/engine/worker.cjs'));
const {settleClubMeetings}=require(path.join(root,'tests/helpers/club-meetings.cjs'));
const {skipMatchTalk}=require(path.join(root,'tests/helpers/scene-match-talks.cjs'));
const {analyze}=require('./sonde.cjs');
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jouer-'));
const bridge=createBridge({dataDir:dir,seed:27,now:1794178800000,dailyCalendar:true});let id=0;
const request=(command,payload={})=>bridge.handle({id:++id,command,payload});
const good=(command,payload)=>{const r=request(command,payload);if(!r.ok)throw Error(command+' : '+r.error);return r.model;};
const settle=m=>settleClubMeetings(m,good);
const state=()=>JSON.parse(good('export').meta.exportText).state;
let model=settle(good('new_career',{mode,club}));
const snap=label=>{console.log('\n################ '+label+' — '+model.meta.calendarToday+' semaine '+model.meta.week);const m=good('snapshot');const r=analyze(m,state());return r;};
snap('Jour 1');
let played=0;
try{
 while(played<weeks){
  model=settle(model);
  if(model.meta.calendarCadence?.matchReady&&model.next){
   good('auto_lineup');model=good('begin_match');model=skipMatchTalk(model,good)||model;model=good('delegate');
   for(let i=0;i<4&&model.clubLife?.matchTalks?.scene;i++)model=skipMatchTalk(model,good);
   model=good('finish_round');played++;snap('Après le match '+played);
  }else model=good('advance_day',{fromDate:model.meta.calendarToday});
 }
}catch(e){console.log('ARRÊT :',e.message.slice(0,300));}
fs.writeFileSync(path.join(dir,'model.json'),JSON.stringify(good('snapshot')));fs.writeFileSync(path.join(dir,'state.json'),JSON.stringify(state()));console.log('dir',dir);
bridge.close();
