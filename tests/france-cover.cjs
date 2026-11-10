'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {createBridge}=require('../native/engine/worker.cjs');
const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-france-cover-'));
const b=createBridge({dataDir:dir,seed:827381,now:1700000000000});
let id=0;
const call=(command,payload={})=>b.handle({id:++id,command,payload});
const good=(c,p)=>{const r=call(c,p);assert.equal(r.ok,true,r.error);return r.model;};
const checksum=s=>{
 let h=2166136261;
 const t=JSON.stringify(s);
 for(let i=0;i<t.length;i++){h^=t.charCodeAt(i);h=Math.imul(h,16777619);}
 return(h>>>0).toString(16).padStart(8,'0');
};

try{
 let m=good('new_career',{club:29,mode:'france'});
 const doc=JSON.parse(good('export').meta.exportText),injured=doc.state.reserves.slice(0,3);
 for(const p of doc.state.clubs[29].players)if(injured.includes(p.id))p.injury=2;
 doc.checksum=checksum(doc.state);
 good('import',{text:JSON.stringify(doc)});
 m=good('auto_lineup');
 assert.equal(m.lineup.filter(Boolean).length,15,'XV complet malgré blessures des doublures');
 assert.equal(m.reserves.filter(Boolean).length,5,'trois remplaçants de première ligne absents');
 assert.equal(m.selection.valid,false);
 const before=m.squad.length,wage=m.finance.wage;
 const stored=['donnees.json','donnees-precedentes.json'].map(name=>path.join(m.meta.dataDir,name));
 const prior=stored.map(file=>fs.readFileSync(file,'utf8'));
 const quote=good('snapshot').selection.coverage;
 assert.deepEqual(quote?.slots,[16,17,18],'le devis indique les places après sélection');
 assert.equal(quote.weeklySalary,2500);
 assert.equal(quote.totalWeeklySalary,7500);
 assert.ok(quote.places>=3);
 assert.equal(call('promote_cover').ok,false);
 const stale=call('promote_cover',{confirmed:true,expectedSlots:[16,17,19]});
 assert.equal(stale.ok,false);
 assert.match(stale.error,/feuille a changé/);
 assert.deepEqual(stored.map(file=>fs.readFileSync(file,'utf8')),prior,'devis et refus sans écriture');
 m=good('promote_cover',{confirmed:true,expectedSlots:quote.slots});
 assert.equal(m.selection.valid,true);
 assert.equal(m.reserves.filter(Boolean).length,8);
 assert.equal(m.squad.length,before+3);
 assert.equal(m.finance.wage,wage+7500);
 assert.equal(m.meta.coverage.totalWeeklySalary,quote.totalWeeklySalary);
 assert.ok(m.reserves.slice(0,3).every(id=>m.squad.find(p=>p.id===id).salary===2500));
 assert.deepEqual(m.reserves.slice(0,3).map(id=>m.squad.find(p=>p.id===id).pos),['Talonneur','Pilier gauche','Pilier droit']);
 assert.equal(call('promote_cover',{confirmed:true}).ok,false,'pas de promotion superflue');
 m=good('begin_match');
 assert.equal(m.selection.coverage,undefined);
 assert.equal(call('promote_cover',{confirmed:true}).ok,false,'pas de modification effectif pendant match');
 console.log('Couverture native : devis 3 places/7 500 €, validation exacte, lecture et refus sans écriture PASS');
}finally{b.close();}
