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

test('le pilote respecte le quota réel (copies et octets) : neuf imports, suppressions QA confirmées et état conservé', {
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
  settleClubMeetings(good('new_career',{mode:'world-champ',club:29}),good);
  for (let i=0; i<9; i++) {
   good('coach_note_save',{context:model.clubLife.coachNotebook.context,target:'career',text:'Recette du quota : état ' + i});
   const text = good('export').meta.exportText;
   const before = JSON.parse(text).state;
   const safety = model.meta.profileSafety;
   assert.ok(safety,'La vraie projection de sécurité est disponible');
   const old = checkpointToRemove(safety,Buffer.byteLength(text)*2+4096);
   if (old) {
    // Une sauvegarde Monde (116 clubs) pèse plusieurs fois l'ancienne France 30 : le quota d'octets
    // peut jouer avant celui du nombre de copies. On vérifie donc la règle, pas un rang figé.
    assert.ok(i>0&&(safety.entries.length>=safety.maxEntries||safety.usedBytes+Buffer.byteLength(text)*2+4096>safety.maxBytes),'Aucune copie supprimée prématurément : un quota doit l’exiger');
    good('remove_checkpoint',{id:old.id,confirmed:true}); removed++;
   }
   good('import',{text});
   assert.ok(model.meta.profileSafety.entries.length>=1&&model.meta.profileSafety.entries.length<=Math.min(i+1,model.meta.profileSafety.maxEntries),'Copies présentes et dans le quota');
   assert.ok(model.meta.profileSafety.usedBytes<=model.meta.profileSafety.maxBytes,'Octets dans le quota');
   assert.equal(JSON.stringify(JSON.parse(good('export').meta.exportText).state),JSON.stringify(before));
  }
  assert.ok(removed>=1,'Au moins une suppression QA explicitement confirmée (neuf copies > huit autorisées)');
  assert.ok(model.meta.profileSafety.entries.length<=model.meta.profileSafety.maxEntries,'Quota de copies conservé');
  console.log('Quota réel : neuf imports, '+removed+' suppression(s) confirmée(s) ; profil QA ' + profile);
 } finally {bridge.close();}
});
