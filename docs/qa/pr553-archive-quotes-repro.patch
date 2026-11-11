--- a/tests/press-identity-pack.cjs
+++ b/tests/press-identity-pack.cjs
@@ -118,6 +118,7 @@
  expectPack(m,'pack actif');
  for(const q of m.clubLife.press.conference.questions)if(renamed.includes(q.journalist.id))assert.equal(q.journalist.name,pressRubric.journalists.find(j=>j.id===q.journalist.id).name,'question signée');
  for(const h of m.clubLife.press.history)if(renamed.includes(h.journalist?.id))assert.ok(h.journalist.name.startsWith('Journaliste Test '),'archive présentée avec le pack');
+ {const d=JSON.parse(good('export').meta.exportText),h=d.state.pressConference.history[0];h.questionText='Question archivée de '+bank.journalists.get('presse-0').name+' : pourquoi ?';h.answerText='Réponse archivée pour '+bank.outlets.get('redaction-0')+'.';const qt=h.questionText,at=h.answerText;const text=JSON.stringify(d.state);let sum=2166136261;for(let i=0;i<text.length;i++)sum=Math.imul(sum^text.charCodeAt(i),16777619);d.checksum=(sum>>>0).toString(16).padStart(8,'0');m=settle(good('import',{text:JSON.stringify(d)}));const row=m.clubLife.press.history.find(x=>x.id===h.id&&x.week===h.week);assert.deepEqual({question:row.question,answer:row.answer},{question:qt,answer:at},'mot pour mot question et réponse archivées sous pack');console.log('QUOTES_PRESERVED');}
  const packed=state();assert.deepEqual(withoutPack(packed),withoutPack(before),'la sauvegarde ne reçoit aucun nom du pack');assert.ok(!JSON.stringify(packed).includes('Journaliste Test'));
  // Une conférence tenue sous le pack archive la signature de base.
  m=settle(good('snapshot'));
