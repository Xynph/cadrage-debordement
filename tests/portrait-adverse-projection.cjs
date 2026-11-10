'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{createBridge}=require('../native/engine/worker.cjs');
test('Opponent threats inherit the real new player bank and public age without mutation or legacy upgrade',t=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-portrait-adverse-')),b=createBridge({dataDir:root,seed:827381,now:1700000000000});t.after(()=>{b.close();fs.rmSync(root,{recursive:true,force:true});});let id=0;
 const go=(command,payload={})=>{const r=b.handle({id:++id,command,payload});a.equal(r.ok,true,r.error);return r.model;};
 let m=settleClubMeetings(go('new_career',{mode:'fiction',club:0}),(command,payload)=>go(command,payload)),text=go('export').meta.exportText,state=JSON.parse(text).state;
 const source=m.decisions.preparation,opponent=state.clubs[source.opponent.id];a(source.threats.length>0);
 for(const threat of source.threats){const p=opponent.players.find(p=>p.id===threat.id);a(p);a.equal(p.appearanceBankVersion,2);a.equal(threat.appearanceBankVersion,2);a.equal(threat.age,p.age);}
 const file=path.join(root,'PrototypeGodot/donnees.json'),bytes=fs.readFileSync(file);go('snapshot');a.equal(go('export').meta.exportText,text);a.deepEqual(fs.readFileSync(file),bytes);
 const doc=JSON.parse(text);for(const c of doc.state.clubs)for(const p of c.players)delete p.appearanceBankVersion;
 let h=2166136261;const raw=JSON.stringify(doc.state);for(let i=0;i<raw.length;i++)h=Math.imul(h^raw.charCodeAt(i),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');m=go('import',{text:JSON.stringify(doc)});
 a(m.decisions.preparation.threats.every(p=>!Object.hasOwn(p,'appearanceBankVersion')));
});
