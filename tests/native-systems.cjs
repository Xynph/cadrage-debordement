'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const systems=require('../native/engine/native-systems.cjs');
const {createBridge,CORE_FILES}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-native-systems-'));let bridge,n=0;
function call(command,payload={}){const r=bridge.handle({id:++n,command,payload});assert.equal(r.ok,true,command+': '+r.error);return r.model;}
try{
 assert.ok(systems.files.includes('press-relations.js'));
 assert.ok(CORE_FILES.indexOf('press-relations.js')<CORE_FILES.indexOf('game.js'));
 bridge=createBridge({dataDir:root,seed:27,now:1700000000000});
 let m=call('new_career',{mode:'common',club:29});
 assert.ok(m.clubLife.press,'La presse doit être raccordée au vrai worker.');
 const before=call('export').meta.exportText,profile=path.join(m.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(profile);
 for(let i=0;i<3;i++)call('snapshot');
 assert.equal(call('export').meta.exportText,before);assert.deepEqual(fs.readFileSync(profile),bytes);
 const conference=m.clubLife.press.conference;
 assert.ok(conference.available);assert.ok(conference.questions.length>=2);
 const answers=conference.questions.map(q=>({questionId:q.id,answerId:q.answers[0].id}));
 m=call('press_conference',{context:m.clubLife.press.context,answers});
 assert.equal(m.clubLife.press.conference.available,false);
 const saved=call('export').meta.exportText;call('shutdown');
 bridge=createBridge({dataDir:root});assert.equal(call('export').meta.exportText,saved,'Les API presse doivent être disponibles avant validation du profil.');
 console.log('Systèmes natifs : manifeste, vraie conférence, projections pures et reprise PASS.');
}finally{bridge?.close();}
