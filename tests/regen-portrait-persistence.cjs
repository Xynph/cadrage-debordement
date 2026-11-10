'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs'),{describe}=require('../native/engine/portraits.cjs');
const vm=require('node:vm'),{factory}=require('../native/engine/staff-career.cjs');
function rewrite(text,edit){const doc=JSON.parse(text);edit(doc.state);const s=JSON.stringify(doc.state);let h=2166136261;for(let i=0;i<s.length;i++)h=Math.imul(h^s.charCodeAt(i),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
test('Real worker persists new academy portraits through promotion/reopen and never upgrades legacy on consultation',t=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-portrait-bank-')),opts={dataDir:dir,seed:827381,now:1700000000000};let b=createBridge(opts),serial=0;
 t.after(()=>{b.close();fs.rmSync(dir,{recursive:true,force:true});});
 const call=(command,payload={})=>b.handle({id:++serial,command,payload}),go=(command,payload={})=>{const r=call(command,payload);a.equal(r.ok,true,r.error);return r.model;};
 let m=settleClubMeetings(go('new_career',{mode:'common',club:0}),(command,payload)=>go(command,payload)),p=m.decisions.development.academy[0];a.equal(p.appearanceBankVersion,2);const profile=describe(p);
 const native=JSON.parse(go('export').meta.exportText).state;a.equal(native.development.academy[0].appearanceBankVersion,2);
 go('promote_academy',{playerId:p.id,confirmed:true});m=go('snapshot');a.deepEqual(describe(m.squad.find(q=>q.id===p.id)),profile);
 const saved=go('export').meta.exportText;b.close();b=createBridge(opts);a.equal(go('export').meta.exportText,saved);
 const old=rewrite(saved,s=>{const visit=o=>{if(!o||typeof o!=='object')return;if(o.generation?.policy!=='staff-completion-v1')delete o.appearanceBankVersion;for(const v of Object.values(o))visit(v);};visit(s);});
 go('import',{text:old});const legacy=go('export').meta.exportText,file=path.join(dir,'PrototypeGodot/donnees.json'),bytes=fs.readFileSync(file);
 for(let i=0;i<3;i++){m=go('snapshot');a.equal(m.squad.find(q=>q.id===p.id).appearanceBankVersion,undefined);a.equal(describe(m.squad.find(q=>q.id===p.id)).version,1);}
 a.equal(go('export').meta.exportText,legacy);a.deepEqual(fs.readFileSync(file),bytes);
 for(const bad of [0,3,'2',null]){const forged=rewrite(legacy,s=>{s.development.academy[0].appearanceBankVersion=bad;});a.equal(call('import',{text:forged}).ok,false);a.equal(go('export').meta.exportText,legacy);a.deepEqual(fs.readFileSync(file),bytes);}
});
test('New fictional staff use bank2, references keep legacy, conversions inherit source bank without remapping',()=>{
 for(const bank of [undefined,1,2]){
  const S={season:1,round:0,phase:'league',club:0,commonDatabase:{id:'fixture'},clubs:[{id:0,name:'Club',players:[]}]};
  const ctx=vm.createContext({S,nativeStaffCareerSources:{fixture:[{id:0,members:[{id:'staff:reference',name:'Reference',role:'Entraîneur',age:50}]}]},Math:Object.assign(Object.create(Math),{random:()=>{throw Error('No game RNG for portraits');}})});
  vm.runInContext('const career=('+factory.toString()+')();career.initialize(S)',ctx);
  const people=S.staffCareer.people.flat();a.equal(people.find(p=>p.sourceKind==='reference').appearanceBankVersion,undefined);a(people.filter(p=>p.sourceKind==='generated').every(p=>p.appearanceBankVersion===2));
  let source;
  for(let i=0;i<30;i++){
   const p={id:'retired:'+i,name:'Former player',age:35,rating:80,fam:1,skills:{mental:70},dev:{careerMinutes:1000},...(bank===undefined?{}:{appearanceBankVersion:bank})};
   ctx.source=p;if(vm.runInContext('career.captureRetirement(S,source,0)',ctx)){source=p;break;}
  }
  a(source);const converted=S.staffCareer.people.flat().find(p=>p.sourcePlayerId===source.id);a(converted);
  a.equal(converted.appearanceBankVersion,bank===2?2:undefined);
  const p=describe(source),s=describe(converted);for(const key of ['version','appearanceId','seed','origin','atlas','cell','baseId','faceWidth','eyeSpacing','noseWidth','jawWidth','shirt'])a.deepEqual(s[key],p[key],key);
  a.equal(S.staffCareer.history.find(p=>p.id===converted.id).appearanceBankVersion,bank===2?2:undefined);
 }
});
