'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {createBridge}=require('../native/engine/worker.cjs');
const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-strategy-'));let b,seq=0,m;
const call=(command,payload={})=>{const r=b.handle({id:++seq,command,payload});assert.equal(r.ok,true,command+': '+r.error);return m=r.model;};
const act=(command,payload={})=>call(command,{context:m.clubLife.clubStrategy.context,confirmed:true,...payload});
const bad=(command,payload={})=>assert.equal(b.handle({id:++seq,command,payload:{context:m.clubLife.clubStrategy.context,confirmed:true,...payload}}).ok,false);
try{
 b=createBridge({dataDir:root,seed:31,now:1700000000000});call('new_career',{mode:'common',club:29});
 assert.ok(m.clubLife.clubStrategy,'Les décisions financières doivent être accessibles.');
 assert.equal(m.clubLife.clubStrategy.finance.weeksPerSeason,34);
 assert.equal(m.clubLife.clubStrategy.finance.remainingWeeks,34,'Les 34 échéances restent à payer avant la première journée.');
 const original=call('export').meta.exportText;call('snapshot');assert.equal(call('export').meta.exportText,original);
 const cash=m.finance.cash;act('club_sponsor_sign',{key:'avance'});assert.equal(m.finance.cash,cash+120000);bad('club_sponsor_sign',{key:'avance'});
 act('club_academy_investment',{amount:12000});assert.equal(m.clubLife.clubStrategy.finance.academyInvestment,12000);bad('club_academy_investment',{amount:9000});
 const pre=m.finance.cash;act('club_board_project',{kind:'video'});assert.equal(m.finance.cash,pre-12000);bad('club_board_project',{kind:'video'});
 act('club_board_priority',{key:'finances'});assert.equal(m.clubLife.clubStrategy.board.priority,'finances');
 const communityCash=m.finance.cash;act('club_fans_community',{key:'ecoles'});assert.equal(m.finance.cash,communityCash-1500);bad('club_fans_community',{key:'ecoles'});
 const before=call('export').meta.exportText,profile=path.join(m.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(profile);
 fs.mkdirSync(path.join(m.meta.dataDir,'donnees.tmp'));
 bad('club_fans_campaign',{key:'locale'});assert.equal(call('export').meta.exportText,before);assert.deepEqual(fs.readFileSync(profile),bytes);fs.rmdirSync(path.join(m.meta.dataDir,'donnees.tmp'));
 const oldContext={...m.clubLife.clubStrategy.context,week:99};bad('club_board_priority',{context:oldContext,key:'performance'});
 call('train');assert.ok(m.finance.cash<=communityCash-1500-12000,'Investissement appliqué par la vraie séance.');
 const saved=call('export').meta.exportText;call('shutdown');b=createBridge({dataDir:root});assert.equal(call('export').meta.exportText,saved);
 console.log('Stratégie native : sponsors, formation, projets, supporters, devis34semaines et rollback/reprise PASS.');
}finally{b?.close();}
