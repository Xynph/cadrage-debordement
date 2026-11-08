'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-native-playbook-'));let b,n=0,m;
const good=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,command+': '+r.error);return m=r.model;};
const change=(key,value,zone)=>good('playbook_set',{context:m.clubLife.playbook.context,key,value,...(zone?{zone}:{})});
const state=()=>JSON.parse(good('export').meta.exportText).state;
try{
 b=createBridge({dataDir:root,seed:315,now:1700000000000});good('new_career',{mode:'common',club:29});
 assert.equal(m.clubLife.playbook?.zones.length,4,'Le carnet natif doit exposer les quatre zones.');
 const before=good('export').meta.exportText,profile=path.join(m.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(profile);
 for(let i=0;i<3;i++)good('snapshot');assert.equal(good('export').meta.exportText,before);assert.deepEqual(fs.readFileSync(profile),bytes);
 change('attack','occupation','sortie');change('defence','pression','marque');change('scrum','securiser');change('lineout','maul');change('kickoff','court');
 let s=state();assert.equal(s.manager.playbook.zones.sortie.attack,'occupation');assert.equal(s.manager.playbook.zones.marque.defence,'pression');assert.equal(s.tactic,'equilibre');
 good('train');good('auto_lineup');good('begin_match');good('pause',{paused:true});
 s=state();assert.equal(s.live.playbooks[s.live.userSide].zones.sortie.attack,'occupation');assert.equal(s.live.playbooks[s.live.userSide].lineout,'maul');
 change('attack','large','pression');s=state();assert.equal(s.live.playbooks[s.live.userSide].zones.pression.attack,'large');assert.equal(s.manager.playbook.zones.pression.attack,'large');
 good('pause',{paused:false});let r=b.handle({id:++n,command:'playbook_set',payload:{context:m.clubLife.playbook.context,key:'scrum',value:'pousser'}});assert.equal(r.ok,false,'Le carnet ne change pas pendant le direct actif.');
 good('pause',{paused:true});const saved=good('export').meta.exportText;good('shutdown');b=createBridge({dataDir:root});assert.equal(good('export').meta.exportText,saved);good('import',{text:saved});assert.equal(state().manager.playbook.zones.pression.attack,'large');
 const frozen=good('export').meta.exportText;for(const payload of [{zone:'ailleurs',key:'attack',value:'large'},{zone:'sortie',key:'attack',value:'triche'},{key:'scrum',value:'fond'},{key:'lineout',value:'maul',extra:true}]){r=b.handle({id:++n,command:'playbook_set',payload:{context:m.clubLife.playbook.context,...payload}});assert.equal(r.ok,false);assert.equal(good('export').meta.exportText,frozen);}
 console.log('Carnet natif : quatre zones/CPA, priorité locale, vrai live, pause et reprise/import PASS.');
}finally{b?.close();}
