'use strict';
const assert=require('node:assert/strict');

// Baseline setup only: tests of a particular meeting must perform that decision
// themselves before calling this helper. Every action uses the public worker.
function settleClubMeetings(model,sendModel){
 const impact=answer=>Object.values(answer.effects||{}).reduce((sum,value)=>sum+(Number.isFinite(value)?Math.abs(value):0),0);
 for(let count=0;model.clubLife?.clubMeetings?.scene;count++){
  assert.ok(count<85,'The real bounded club meeting queue must terminate');
  const scene=model.clubLife.clubMeetings.scene;
  assert.ok(scene.id&&['press','medical','board'].includes(scene.kind),'Known projected club meeting required');
  if(!scene.completed){
   if(scene.kind==='press'){
    const press=model.clubLife.press;
    assert.ok(press?.conference?.available&&press.conference.questions.length,'A mandatory conference needs its actual questions');
    const answers=press.conference.questions.map(question=>{
     assert.ok(question.answers?.length,'The actual question must offer answers');
     const answer=[...question.answers].sort((a,b)=>impact(a)-impact(b)||(a.id<b.id?-1:a.id>b.id?1:0))[0];
     return {questionId:question.id,answerId:answer.id};
    });
    model=sendModel('press_conference',{context:press.context,answers});
   }else if(scene.ackAllowed){
    model=sendModel('club_meeting_ack',{meetingId:scene.id});
   }else{
    assert.equal(scene.kind,'medical','Only a medical protocol can remain mandatory without acknowledgement');
    const medical=model.clubLife.clubSupport?.medical;
    const player=medical?.players.find(row=>row.id===scene.playerId);
    assert.ok(medical?.available&&player?.injury>0,'An actual injured player must authorise the protocol');
    const protocol=medical.protocols.find(row=>row.key===player.protocol);
    assert.ok(protocol,'Keep the actual currently projected medical protocol');
    model=sendModel('medical_protocol',{context:scene.context,id:player.id,protocol:protocol.key});
   }
  }
  const completed=model.clubLife?.clubMeetings?.scene;
  assert.ok(completed?.id===scene.id&&completed.completed,'The real decision must complete this meeting before continuing');
  model=sendModel('club_meeting_continue',{meetingId:completed.id});
 }
 return model;
}

module.exports={settleClubMeetings};
