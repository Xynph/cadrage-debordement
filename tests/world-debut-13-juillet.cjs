'use strict';
// Début de carrière Monde au lundi 13 juillet 2026 (avant-saison.cjs) : date affichée, avance
// jour par jour ou par semaine, ouverture du calendrier du moteur le 17 août sans rien changer
// aux séquences (mêmes résultats qu'une carrière ouverte directement), 1re journée de l'Élite.
const {test}=require('node:test'),assert=require('node:assert/strict');
const crypto=require('node:crypto'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');

function career(t,options={}){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-debut-'));
 const b=createBridge({dataDir:dir,seed:27,now:1794178800000,...options});let id=0;
 const send=(command,body={})=>b.handle({id:++id,command,payload:body});
 const go=(command,body={})=>{const r=send(command,body);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 let closed=false;const close=()=>{if(closed)return;closed=true;b.close();fs.rmSync(dir,{recursive:true,force:true});};
 t.after(close);
 return {close,send,go,state:()=>JSON.parse(go('export').meta.exportText).state,model:settleClubMeetings(go('new_career',{mode:'world-champ',club:0}),go)};
}

test('la carrière Monde commence le lundi 13 juillet 2026 et avance jusqu’à l’ouverture du 17 août',t=>{
 const {go,send,state,model}=career(t,{dailyCalendar:true});
 let m=model;
 assert.equal(m.meta.calendarToday,'2026-07-13');
 assert.equal(m.meta.calendarCadence.preseason,true);
 assert.equal(m.meta.calendarCadence.canAdvance,true);
 assert.equal(m.meta.calendarCadence.matchReady,false);
 assert.deepEqual(m.meta.preseason,{today:'2026-07-13',opening:'2026-08-17'});
 assert.equal(m.meta.seasonStartYear,2026);
 assert.equal(m.calendarPlanning.today,'2026-07-13');
 // 1re journée de l'Élite 2026-2027 : 5-6 septembre (calendrier LNR du dépôt) ; le club 0 joue
 // le dimanche 6 septembre.
 const first=m.calendar.filter(f=>f.id.startsWith('elite:')).sort((x,y)=>x.date.localeCompare(y.date))[0];
 assert.equal(first.date,'2026-09-06');assert.match(first.label,/J1$/);
 m=settleClubMeetings(go('advance_day',{fromDate:'2026-07-13'}),go);
 assert.equal(m.meta.calendarToday,'2026-07-14');
 assert.equal(send('advance_day',{fromDate:'2026-07-13'}).ok,false,'date périmée');
 m=settleClubMeetings(go('preseason_advance',{fromDate:'2026-07-14',until:'semaine'}),go);
 assert.equal(m.meta.calendarToday,'2026-07-21');
 assert.equal(send('preseason_advance',{fromDate:'2026-07-21',until:'demain'}).ok,false);
 for(let i=0;i<4;i++)m=settleClubMeetings(go('preseason_advance',{fromDate:m.meta.calendarToday,until:'semaine'}),go);
 assert.equal(m.meta.calendarToday,'2026-08-17','la cinquième semaine ouvre le calendrier du moteur');
 assert.equal(m.meta.calendarCadence.preseason,undefined);
 assert.equal(m.meta.preseason,undefined);
 assert.equal(state().preseason,undefined);
 m=settleClubMeetings(go('advance_day',{fromDate:'2026-08-17'}),go);
 assert.equal(m.meta.calendarToday,'2026-08-18','le calendrier jour par jour reprend comme avant');
});

test('sauvegarde : avant-saison exportée, réimportée et contrôlée',t=>{
 const {go,send}=career(t);
 const text=go('export').meta.exportText,doc=JSON.parse(text);
 assert.deepEqual(doc.state.preseason,{version:1,today:'2026-07-13'});
 assert.equal(go('import',{text}).meta.calendarToday,'2026-07-13');
 for(const bad of [{version:1,today:'2026-08-17'},{version:1,today:'2026-07-01'},{version:2,today:'2026-07-13'},{version:1,today:'2026-07-13',x:1}]){
  const broken=JSON.parse(text);broken.state.preseason=bad;
  assert.equal(send('import',{text:JSON.stringify(broken)}).ok,false,JSON.stringify(bad));
 }
});
