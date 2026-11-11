--- a/tests/native-club-meetings-packs.cjs
+++ b/tests/native-club-meetings-packs.cjs
@@ -43,7 +43,11 @@
 
  // 3. L'action sportive reste refusée, avec la marche à suivre, et sans effet.
  const frozen=exported();
- for(const command of ['train','auto_lineup','begin_match','finish_round','next_season','set_tactics','recruit','advance_day']){const r=bad(command,{});assert.match(r.error,refusal,command);}
+ for(const command of ['train','auto_lineup','begin_match','finish_round','next_season','set_tactics','recruit','advance_day','population_enable','academy_groups_enable','coach_note_save','interclub_negotiate']){const r=bad(command,{});assert.match(r.error,refusal,command);}
+ const rejectedSeed=JSON.parse(fs.readFileSync(file)).seed;
+ bad('pack_select',{id:preview.id,scope:'unexpected'});bad('pack_select',{id:'missing-pack',scope:'career'});
+ {const p=model.clubLife.press;bad('press_conference',{context:p.context,invitationId:'forged-invitation',answers:p.conference.questions.map(q=>({questionId:q.id,answerId:q.answers[0].id}))});}
+ assert.equal(JSON.parse(fs.readFileSync(file)).seed,rejectedSeed,'Refus de scopes/packs/invitation sans tirage');
  assert.equal(exported(),frozen,'Les refus ne changent rien');
 
  // 4. Reprise : le rendez-vous et le pack survivent au redémarrage ; on repasse au pack de base pendant le rendez-vous.
@@ -56,8 +60,8 @@
  good('pack_select',{id:preview.id,scope:'career'});const withPack=exported();
  const p=model.clubLife.press;
  good('press_conference',{context:p.context,answers:p.conference.questions.map(q=>({questionId:q.id,answerId:q.answers[0].id}))});
- assert.equal(room().completed,true);const done=meetings(),doneState=withoutPack(state());
- good('pack_select',{id:preview.id,scope:'career'});
+ assert.equal(room().completed,true);const done=meetings(),doneState=withoutPack(state()),doneSeed=JSON.parse(fs.readFileSync(file)).seed;
+ good('pack_select',{id:'base',scope:'career'});assert.equal(JSON.parse(fs.readFileSync(file)).seed,doneSeed,'Vraie bascule après publication sans tirage');
  assert.equal(meetings(),done);assert.deepEqual(withoutPack(state()),doneState,'Conférence archivée : texte enregistré inchangé');
  bad('train',{});
  good('club_meeting_continue',{meetingId:room().id});
