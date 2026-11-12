// Lecture seule : les déclarations de presse sont-elles archivées mot pour mot et stables ?
const fs=require('fs'),os=require('os'),path=require('path');
const root=process.argv[2],weeks=+(process.argv[3]||3);
const {createBridge}=require(path.join(root,'native/engine/worker.cjs'));
const {settleClubMeetings}=require(path.join(root,'tests/helpers/club-meetings.cjs'));
const {skipMatchTalk}=require(path.join(root,'tests/helpers/scene-match-talks.cjs'));
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'presse-'));const opts={dataDir:dir,seed:27,now:1794178800000,dailyCalendar:true};
let bridge=createBridge(opts),id=0,last=null;const said=[],seen=new Map(),issues=[];
const check=m=>{for(const h of m.clubLife?.press?.history||[]){const key=h.id+'|'+h.season+'|'+h.week+'|'+(h.questionId??'');const txt=JSON.stringify([h.questionText,h.answerText,h.journalist?.name]);if(seen.has(key)&&seen.get(key)!==txt)issues.push('MODIFIÉ '+key+' : '+seen.get(key).slice(0,120)+' → '+txt.slice(0,120));seen.set(key,txt);}};
const good=(command,payload)=>{
 if(command==='press_conference'){const qs=last.clubLife.press.conference.questions;for(const a of payload.answers){const q=qs.find(x=>x.id===a.questionId),ans=q.answers.find(x=>x.id===a.answerId);said.push({at:last.meta.calendarToday,q:q.text??q.question??q.label,a:ans.text??ans.label,qid:q.id,aid:ans.id,journalist:q.journalist?.name??null,keysQ:Object.keys(q).join(','),keysA:Object.keys(ans).join(',')});}}
 const r=bridge.handle({id:++id,command,payload:payload??{}});if(!r.ok)throw Error(command+' : '+r.error);last=r.model;check(last);return last;};
const settle=m=>settleClubMeetings(m,good);
let model=settle(good('new_career',{mode:'common',club:29})),played=0;
try{while(played<weeks){model=settle(model);
 if(model.meta.calendarCadence?.matchReady&&model.next){good('auto_lineup');model=good('begin_match');model=skipMatchTalk(model,good)||model;model=good('delegate');for(let i=0;i<4&&model.clubLife?.matchTalks?.scene;i++)model=skipMatchTalk(model,good);model=good('finish_round');played++;}
 else model=good('advance_day',{fromDate:model.meta.calendarToday});}}catch(e){console.log('ARRÊT :',e.message.slice(0,200));}
const before=JSON.stringify(good('snapshot').clubLife.press.history);
bridge.close();bridge=createBridge(opts);const after=JSON.stringify(good('snapshot').clubLife.press.history);
console.log('déclarations faites:',said.length,'| entrées d\'archive vues:',seen.size,'| archive identique après fermeture et relance:',before===after);
const hist=JSON.parse(after);console.log('clés d\'une entrée:',Object.keys(hist[0]).join(','));console.log('clés question:',said[0]?.keysQ,'| clés réponse:',said[0]?.keysA);
let exact=0;for(const s of said){const h=hist.find(h=>h.answerText===s.a&&h.questionText===s.q);if(h)exact++;else{const near=hist.find(h=>h.answerId===s.aid&&(h.questionText===s.q||h.answerText===s.a));issues.push('NON LITTÉRAL '+s.at+' q='+JSON.stringify(s.q).slice(0,90)+' a='+JSON.stringify(s.a).slice(0,90)+' | archive proche: '+JSON.stringify(near?[near.questionText,near.answerText]:null).slice(0,220));}}
console.log('retrouvées mot pour mot (question et réponse):',exact+'/'+said.length,'| taille archive:',hist.length);
console.log(issues.length?issues.slice(0,12).join('\n'):'aucun écart');
const S=JSON.parse(good('export').meta.exportText).state;const where=[];(function w(v,p,d){if(d>5||!v||typeof v!=='object')return;if(Array.isArray(v)){if(v.length&&v[0]&&typeof v[0]==='object'&&'answerText' in v[0])where.push(p+' ['+v.length+'] clés: '+Object.keys(v[0]).join(','));return;}for(const k in v)w(v[k],p+'.'+k,d+1);})(S,'S',0);console.log('stockage:',where.join(' ; ')||'aucun tableau avec answerText dans l\'état (profondeur 5)');
console.log('exemple:',JSON.stringify(hist[0]).slice(0,500));
bridge.close();
