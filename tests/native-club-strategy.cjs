'use strict';
const {refuseSavePublication}=require('./helpers/save-publication-refusal.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {createBridge}=require('../native/engine/worker.cjs');
const {context}=require('./native-reference-harness.cjs');
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
 refuseSavePublication(profile,()=>bad('club_fans_campaign',{key:'locale'}));
 assert.equal(call('export').meta.exportText,before);assert.deepEqual(fs.readFileSync(profile),bytes);
 const oldContext={...m.clubLife.clubStrategy.context,week:99};bad('club_board_priority',{context:oldContext,key:'performance'});
 call('train');assert.ok(m.finance.cash<=communityCash-1500-12000,'Investissement appliqué par la vraie séance.');
 const saved=call('export').meta.exportText;call('shutdown');b=createBridge({dataDir:root});assert.equal(call('export').meta.exportText,saved);
 console.log('Stratégie native : sponsors, formation, projets, supporters, devis34semaines et rollback/reprise PASS.');
}finally{b?.close();}

// Signed imports must reject future reviews before they can block finish_round.
function signed(doc){let h=2166136261;for(const c of JSON.stringify(doc.state)){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}doc.checksum=(h>>>0).toString(16).padStart(8,'0');return JSON.stringify(doc);}
for(const mode of ['common','fiction']){
 const dataDir=path.join(root,'calendar-'+mode);b=createBridge({dataDir,seed:13,now:1700000000000});
 try{
  call('new_career',{mode,club:0});act('club_board_objective',{type:'wins',target:1,deadline:1});
  const initial=call('export').meta.exportText,legacy=JSON.parse(initial);delete legacy.state.nativeBoardCalendar;call('import',{text:signed(legacy)});assert.equal(JSON.parse(call('export').meta.exportText).state.nativeBoardCalendar,undefined,'Ancien export sans namespace conseil accepté');call('import',{text:initial});
  const stable=call('export').meta.exportText,profile=path.join(m.meta.dataDir,'donnees.json'),bytes=fs.readFileSync(profile),maximum=mode==='common'?34:29;
  const mutations=[
   ['compteur futur',s=>{s.nativeBoardCalendar.week=maximum;}],
   ['historique futur',s=>{s.nativeBoardCalendar.history=[{week:1,trust:60}];}],
   ['réunion future',s=>{s.nativeBoardCalendar.meetings=[{week:1,events:[]}];}],
   ['événement futur',s=>{s.nativeBoardCalendar.meetings=[{week:0,events:[{id:s.nativeBoardCalendar.objectives[0].id,status:'met',delta:5,week:1}]}];}],
   ['bureau courant futur',s=>{const board=structuredClone(s.nativeBoardCalendar);board.clubId='club-1';board.week=maximum;s.nativeStrategyOffices={version:1,clubs:{1:{nativeBoardCalendar:board}}};}]
  ];
  for(const [label,mutate] of mutations){const doc=JSON.parse(stable);mutate(doc.state);const result=b.handle({id:++seq,command:'import',payload:{text:signed(doc)}});assert.equal(result.ok,false,mode+' refuse '+label);assert.match(result.error,/direction/i);assert.equal(call('export').meta.exportText,stable,label+' : état conservé');assert.deepEqual(fs.readFileSync(profile),bytes,label+' : disque, RNG et horloge conservés');}
  call('import',{text:stable});call('begin_match');call('delegate');call('finish_round');
  const reached=call('export').meta.exportText;call('import',{text:reached});assert.equal(call('export').meta.exportText,reached,'Conseil de la semaine réellement atteinte importable');
  // Both archives come from a real transition: staff clocks and reconversions
  // must advance with the season, including in the fiction career.
  const reference=context({seed:13,now:1700000000000});reference.ctx.reached=JSON.parse(reached).state;reference.run('S=reached');
  while(reference.run('S.phase!=="ended"'))reference.run('finishRound()');
  const old=JSON.parse(reference.run('JSON.stringify(S.nativeBoardCalendar)'));reference.run('advanceSeason()');
  const archive=JSON.parse(reference.run('JSON.stringify(createSaveDocument())'));
  const other=structuredClone(old);other.clubId='club-1';archive.state.nativeStrategyOffices={version:1,clubs:{1:{nativeBoardCalendar:other}}};
  call('import',{text:signed(archive)});assert.equal(JSON.parse(call('export').meta.exportText).state.nativeStrategyOffices.clubs[1].nativeBoardCalendar.week,maximum,'Archives antérieures conservées au-delà de la semaine courante');
  const current=call('export').meta.exportText,currentBytes=fs.readFileSync(profile);
  for(const season of [1,3]){const stale=JSON.parse(current);stale.state.nativeBoardCalendar=structuredClone(old);stale.state.nativeBoardCalendar.clubId='club-'+stale.state.club;stale.state.nativeBoardCalendar.season=season;stale.state.nativeBoardCalendar.archived=true;const refused=b.handle({id:++seq,command:'import',payload:{text:signed(stale)}});assert.equal(refused.ok,false,'Conseil actif hors saison courante refusé malgré marqueur importé : '+season);assert.match(refused.error,/direction/i);assert.equal(call('export').meta.exportText,current);assert.deepEqual(fs.readFileSync(profile),currentBytes,'Saison active incorrecte : état/RNG/disque conservés');}
  call('begin_match');call('delegate');call('finish_round');
  console.log('Calendrier '+mode+' : imports signés refusés sans mutation, contexte atteint, archives et vraie journée PASS.');
 }finally{b.close();}
}
