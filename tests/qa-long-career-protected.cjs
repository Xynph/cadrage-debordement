'use strict';
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const assert = require('node:assert/strict');
const {test} = require('node:test');
const {settleClubMeetings} = require('./helpers/club-meetings.cjs');
const {checkpointToRemove} = require('../scripts/qa-long-career.cjs');
const root = process.env.OVAL_QA_SOURCE_ROOT || path.resolve(__dirname, '..');
const protectedEngine = fs.existsSync(path.join(root, 'native/engine/profile-safety.cjs'));

test('le pilote respecte le quota réel : neuf imports, suppression QA confirmée et état conservé', {
 skip: !protectedEngine && 'Moteur avec copies de sécurité requis', timeout:150000,
}, () => {
 const {createBridge} = require(path.join(root, 'native/engine/worker.cjs'));
 const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-qa-native-quota-'));
 const bridge = createBridge({dataDir:profile, seed:713492, now:1794315600000});
 let request = 0, model, removed = 0;
 const good = (command, payload = {}) => {
  const answer = bridge.handle({id:++request,command,payload});
  assert.equal(answer.ok,true,command + ': ' + answer.error);
  model = answer.model;
  return model;
 };
 try {
  model=settleClubMeetings(good('new_career',{mode:'common',club:29}),good);
  for (let i=0; i<9; i++) {
   good('coach_note_save',{context:model.clubLife.coachNotebook.context,target:'career',text:'Recette du quota : état ' + i});
   const text = good('export').meta.exportText;
   const before = JSON.parse(text).state;
   const safety = model.meta.profileSafety;
   assert.ok(safety,'La vraie projection de sécurité est disponible');
   const old = checkpointToRemove(safety,Buffer.byteLength(text)*2+4096);
   if (old) {
    assert.equal(i,8,'Aucune copie supprimée prématurément');
    good('remove_checkpoint',{id:old.id,confirmed:true}); removed++;
   }
   good('import',{text});
   assert.equal(model.meta.profileSafety.entries.length,Math.min(i+1,8));
   assert.equal(JSON.stringify(JSON.parse(good('export').meta.exportText).state),JSON.stringify(before));
  }
  assert.equal(removed,1,'Une seule suppression QA explicitement confirmée');
  assert.equal(model.meta.profileSafety.entries.length,8,'Quota de huit copies conservé');
  console.log('Quota réel : neuf imports, une suppression confirmée, huit copies ; profil QA ' + profile);
 } finally {bridge.close();}
});
