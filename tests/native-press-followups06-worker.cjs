'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(process.env.TEMP||require('node:os').tmpdir(),'cd-press-followups06-'));let b,seq=0;
const open=()=>b=createBridge({dataDir:root,seed:10606,now:1700000000000});
const call=(command,payload={})=>b.handle({id:++seq,command,payload});
const good=(command,payload={})=>{const r=call(command,payload);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
function signed(doc){let h=2166136261;const raw=JSON.stringify(doc.state);for(let i=0;i<raw.length;i++)h=Math.imul(h^raw.charCodeAt(i),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
try{
 open();let m=good('new_career',{mode:'fiction',club:0});
 m=settleClubMeetings(m,good);const initial=JSON.parse(good('export').meta.exportText),candidate=initial.state.market[0],cash=m.club.cash;
 // Pin this explicit available-player fixture as the normal watch list would,
 // so a weekly market refresh cannot remove every match for this mission.
 const pinned=initial.state.economy.freeAgents.find(p=>p.id===candidate.id);
 if(pinned)assert.deepEqual(pinned,candidate,'V2 market and free-agent entries remain canonical');
 else initial.state.economy.freeAgents.push({...candidate,contractEnd:null});
 good('import',{text:signed(initial)});
 m=good('scout_mission',{family:candidate.fam,maxAge:40,budget:10000000,maxWage:100000,confirmed:true});
 assert.equal(m.club.cash,cash-5000,'Coût natif inchangé');assert.equal(m.decisions.recruitment.missions[0].remaining,2);
 for(let i=0;i<2;i++){m=settleClubMeetings(good('snapshot'),good);good('begin_match');good('delegate');m=good('finish_round');}
 assert.ok(m.decisions.recruitment.reports.length>0,'Vrais rapports après deux journées de travail natives : '+JSON.stringify({missions:m.decisions.recruitment.missions,messages:m.messages.slice(0,3)}));
 assert.ok(m.decisions.recruitment.reports.every(r=>r.assessment&&r.assessment.observed.length&&r.assessment.source.includes('Saison')));
 const doc=JSON.parse(good('export').meta.exportText),q=m.clubLife.press.conference.questions[0];
 // Explicit archive fixture to test native persistence, never a real-world quotation.
 const sourceId=require('../dist/press-question-bank.js').questions.find(source=>source.theme===q.theme&&source.id!==q.id).id;
 doc.state.pressConference={version:1,history:[{id:sourceId,season:doc.state.season,week:0,club:doc.state.club,answerId:'r4',questionText:'Quelle méthode pour ce groupe ?',answerText:'Nous avançons ensemble à Béziers, sans promettre le résultat.',journalist:{id:q.journalist.id,name:q.journalist.name,outlet:q.journalist.outlet}}]};
 m=good('import',{text:signed(doc)});const follow=m.clubLife.press.conference.questions.find(q=>q.followUp);assert.ok(follow);
 const before=good('export').meta.exportText,disk=path.join(m.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(disk);
 fs.writeFileSync(path.join(root,'avant-conference.json'),before);
 for(let i=0;i<3;i++)good('snapshot');assert.equal(good('export').meta.exportText,before);assert.deepEqual(fs.readFileSync(disk),bytes);
 const payload={context:m.clubLife.press.context,answers:m.clubLife.press.conference.questions.map(q=>({questionId:q.id,answerId:'r4'}))};
 const refused=refuseSavePublication(disk,()=>call('press_conference',payload));
 assert.equal(refused.ok,false);
 assert.equal(good('export').meta.exportText,before);assert.deepEqual(fs.readFileSync(disk),bytes,'Refus disque atomique');
 m=good('press_conference',payload);assert.equal(m.clubLife.press.history.find(h=>h.id===follow.id&&h.week===payload.context.week).question,follow.question);
 const text=good('export').meta.exportText,expected=m.clubLife.press.history,reports=m.decisions.recruitment.reports;
 fs.writeFileSync(path.join(root,'apres-conference.json'),text);
 assert.deepEqual(good('import',{text}).clubLife.press.history,expected);good('shutdown');open();m=good('snapshot');
 assert.deepEqual(m.clubLife.press.history,expected);assert.deepEqual(m.decisions.recruitment.reports,reports);assert.equal(good('export').meta.exportText,text);
 const legacy=JSON.parse(text);for(const h of legacy.state.pressConference.history){delete h.questionText;delete h.answerText;}m=good('import',{text:signed(legacy)});assert.ok(m.clubLife.press.history.every(h=>h.question===null&&h.answer===null));
 m=good('new_career',{mode:'fiction',club:0});assert.equal(m.clubLife.press.history.length,0);assert.ok(m.clubLife.press.conference.questions.every(q=>!q.followUp));assert.equal(m.decisions.recruitment.reports.length,0);
 console.log('Presse/recrutement06 vrai worker PASS : mission5000/deux journées, lecture pure, relance exacte Unicode, refus disque/rollback, export/import/reprise, anciennes archives et nouvelle carrière. Profil : '+root);
}finally{b?.close();}
