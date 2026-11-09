'use strict';
const fs=require('node:fs'),path=require('node:path'),os=require('node:os'),a=require('node:assert/strict');
const {test}=require('node:test'),{createBridge}=require('../native/engine/worker.cjs');
const {createHash}=require('node:crypto');
const sha=s=>createHash('sha256').update(s).digest('hex');

test('Le journal international affiche les neuf championnats avec un titre de présentation',t=>{
 const directory=fs.mkdtempSync(path.join(os.tmpdir(),'cd-world-press-labels-'));
 const b=createBridge({dataDir:directory,seed:55,now:1794189200000});
 t.after(()=>b.close());
 let n=0;
 const call=(command,payload={})=>{const r=b.handle({id:++n,command,payload});a.equal(r.ok,true,r.error);return r.model;};
 const m=call('new_career',{mode:'world-champ',club:102});
 const names=new Map(m.leagues.map(d=>[d.id,d.name]));
 const divisions=m.clubLife.press.journal.divisions;
 a.equal(divisions.length,9);
 for(const d of divisions){
  a.ok(typeof d.label==='string'&&d.label.length>0&&d.label!==d.id,'Titre absent : '+d.id);
  a.ok(d.standings.length>0);
  if(['srp','jlo-d1','jlo-d2','nationale','champ'].includes(d.id))a.equal(d.label,names.get(d.id));
 }
 const saved=call('export').meta.exportText;
 const same=call('snapshot').clubLife.press.journal.divisions;
 a.deepEqual(same,divisions);
 a.equal(sha(call('export').meta.exportText),sha(saved));
 const legacy=call('new_career',{mode:'fiction',club:0}).clubLife.press.journal.divisions;
 a.deepEqual(legacy.map(x=>[x.id,x.label]),[['historical','Championnat historique']]);
});
