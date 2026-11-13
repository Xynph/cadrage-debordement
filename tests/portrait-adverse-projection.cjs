'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {advanceToNextMatch}=require('./helpers/monde-matchs.cjs');
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{createBridge}=require('../native/engine/worker.cjs');
test('Opponent threats inherit the real new player bank and public age without mutation or legacy upgrade',t=>{
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-portrait-adverse-')),b=createBridge({dataDir:root,seed:827381,now:1700000000000});t.after(()=>{b.close();fs.rmSync(root,{recursive:true,force:true});});let id=0;
 const go=(command,payload={})=>{const r=b.handle({id:++id,command,payload});a.equal(r.ok,true,r.error);return r.model;};
 let m=advanceToNextMatch(go('new_career',{mode:'world-champ',club:0}),go),text=go('export').meta.exportText,state=JSON.parse(text).state;
 const source=m.decisions.preparation,opponent=state.clubs[source.opponent.id];a(source.threats.length>0);
 for(const threat of source.threats){const p=opponent.players.find(p=>p.id===threat.id);a(p);// La version de banque est celle du joueur source telle que le moteur la projette (absente de la sauvegarde pour les pros du Monde avant #641, v2 après) : la menace la suit, quelle qu'elle soit, sans valeur figée.
  if(p.appearanceBankVersion!==undefined)a.equal(threat.appearanceBankVersion,p.appearanceBankVersion,'la menace reprend la banque du joueur source');
  else a.ok(threat.appearanceBankVersion===undefined||[1,2].includes(threat.appearanceBankVersion),'banque projetée valide ou absente');
  a.equal(threat.age,p.age);}
 const file=path.join(root,'PrototypeGodot/donnees.json'),bytes=fs.readFileSync(file);go('snapshot');a.equal(go('export').meta.exportText,text);a.deepEqual(fs.readFileSync(file),bytes);
 const doc=JSON.parse(text);for(const c of doc.state.clubs)for(const p of c.players)delete p.appearanceBankVersion;
 let h=2166136261;const raw=JSON.stringify(doc.state);for(let i=0;i<raw.length;i++)h=Math.imul(h^raw.charCodeAt(i),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');m=go('import',{text:JSON.stringify(doc)});
 // Sans version dans la sauvegarde, rien n'est réécrit dans l'état importé (pas de mise à niveau d'ancienne donnée) ; la projection peut en fournir une valide.
 a(JSON.parse(go('export').meta.exportText).state.clubs.every(c=>c.players.every(p=>!Object.hasOwn(p,'appearanceBankVersion'))),'aucune version écrite à l’import');
 a(m.decisions.preparation.threats.every(t=>t.appearanceBankVersion===undefined||[1,2].includes(t.appearanceBankVersion)));
});
