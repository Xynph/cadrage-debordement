'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {context}=require('./france-harness.cjs');
const {createBridge}=require('../native/engine/worker.cjs');

function trajectory(modern){
 const h=context(5093);h.ctx.modern=modern;
 h.run([
  // Keep this regression about v1 aging only; v2 promotes depth proactively.
  'var setupV2=aiRosterSetup;aiRosterSetup=function(){var result=setupV2();S.aiRosterVersion=1;S.aiRoster.version=1;delete S.aiRoster.population;return result};',
  'start(0);var team=S.clubs[1],a=aiRosterAcademy(team);',
  'S.season=3;S.aiRoster.lastIntake=2;',
  'if(modern)S.aiRoster.academyAgingVersion=1;',
  'var prospect=academyPlayer(team.id,2,2,91);prospect.age=18;',
  'prospect.rating=95;prospect.dev.potential=98;',
  'for(const skill of Object.keys(prospect.skills))prospect.skills[skill]=98;',
  'a.players.push(prospect);var first=aiRosterYouthIntake();',
  'var afterIntake=prospect.age;var repeated=aiRosterYouthIntake();',
  'var signed=aiRosterPromote(team,2,true);var owns=team.players.some(p=>p.id===prospect.id);',
  'rollDevelopmentYear();var closed=JSON.stringify(prospect);',
  'rollDevelopmentYear();var afterRepeat=JSON.stringify(prospect);'
 ].join('\n'));
 return JSON.parse(h.run('JSON.stringify({first,repeated,signed,owns,afterIntake,closed,afterRepeat,age:prospect.age,years:prospect.dev.history.map(row=>row.season)})'));
}

test('une nouvelle politique Monde vieillit le jeune au centre puis à la clôture suivant sa promotion',()=>{
 const r=trajectory(true);
 assert.deepEqual([r.first,r.repeated,r.signed,r.owns,r.afterIntake],[true,false,true,true,19]);
 assert.equal(r.age,20);
 assert.deepEqual(r.years,[2,3]);
 assert.equal(r.afterRepeat,r.closed);
});

test('sans marqueur le résultat d’une carrière héritée ne change pas',()=>{
 const r=trajectory(false);
 assert.deepEqual([r.signed,r.owns,r.afterIntake,r.age],[true,true,19,19]);
 assert.deepEqual(r.years,[3]);
 assert.equal(r.afterRepeat,r.closed);
});

test('le vrai worker crée le marqueur Monde et le conserve à la réouverture',t=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-academy-age-'));
 let b=createBridge({dataDir:root,seed:5501,now:1788134400000}),id=0;
 t.after(()=>{b.close();fs.rmSync(root,{recursive:true,force:true});});
 const ok=(command,payload={})=>{const r=b.handle({id:++id,command,payload});assert.equal(r.ok,true,r.error);return r.model;};
 const archive=()=>ok('export').meta.exportText;
 ok('new_career',{mode:'world-champ',club:102});
 const before=archive();
 assert.equal(JSON.parse(before).state.aiRoster.academyAgingVersion,1);
 b.close();b=createBridge({dataDir:root,seed:9911,now:1788134400000});
 assert.equal(archive(),before);
 ok('new_career',{mode:'common',club:0});
 assert.equal(JSON.parse(archive()).state.aiRoster.academyAgingVersion,undefined);
});
