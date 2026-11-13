'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const {test}=require('node:test'),a=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),{context}=require('./native-reference-harness.cjs'),d=require('../native/engine/interclub-market.cjs');
function fixture(start='start(0)'){const h=context();h.run(start+';var depthMarket=('+d.factory.toString()+')();');return {...h,project:()=>JSON.parse(h.run('JSON.stringify(depthMarket.project())'))};}
test('fiction de départ30: marché réellement accessible sans affaiblir les piliers',()=>{const h=fixture(),m=h.project();a.equal(h.run('S.clubs.every(c=>c.players.length===30)'),true);a.equal(h.run('S.aiRosterVersion'),2);a.equal(m.releasePolicy.minimum,28);a(m.candidates.some(p=>p.available));a(m.candidates.some(p=>p.family===0));a(m.candidates.filter(p=>p.family===0).every(p=>!p.available));const p=m.candidates.find(p=>p.available);h.ctx.payload={playerId:p.id,sellerId:p.clubId,fee:p.fee,salary:p.salary,sourceSalary:p.sourceSalary,contractEnd:p.contractEnd,context:m.context,confirmed:true};h.run('depthMarket.execute("interclub_transfer",payload);validateCareer(S)');a.equal(h.run('S.clubs['+p.clubId+'].players.length'),29);a.equal(h.run('S.clubs[0].players.some(p=>p.id===payload.playerId)'),true);const second=h.project().candidates.find(q=>q.clubId===p.clubId&&q.available);a(second);h.ctx.payload={playerId:second.id,sellerId:second.clubId,fee:second.fee,salary:second.salary,sourceSalary:second.sourceSalary,contractEnd:second.contractEnd,context:m.context,confirmed:true};h.run('depthMarket.execute("interclub_transfer",payload);validateCareer(S)');a.equal(h.run('S.clubs['+p.clubId+'].players.length'),28);a(h.project().candidates.filter(q=>q.clubId===p.clubId).every(q=>!q.available));});
test('les références communes conservent37, formes inconnues restent conservatrices',()=>{const h=fixture('CDCommonCareer.start(0)');a.equal(h.project().releasePolicy.minimum,37);const f=fixture();f.run('S.customCompetition={version:999}');a.equal(f.project().releasePolicy.minimum,37);f.run('delete S.customCompetition;S.worldMode={version:999}');a.equal(f.project().releasePolicy.minimum,37);});
function worker(t){
 const root=fs.mkdtempSync(path.join(os.tmpdir(),'cd-market-depth-')),engine=path.join(root,'app/engine'),source=path.resolve(__dirname,'../native/engine'),coordinator=process.env.CD_MARKET_DEPTH_ENGINE||source;
 fs.mkdirSync(engine,{recursive:true});for(const f of fs.readdirSync(source))if(/\.(cjs|json)$/.test(f))fs.copyFileSync(path.join(source,f),path.join(engine,f));
 // Optional coordinator hook permits isolated review before custom is integrated.
 if(coordinator!==source){fs.copyFileSync(path.join(coordinator,'worker.cjs'),path.join(engine,'worker.cjs'));fs.copyFileSync(path.join(coordinator,'custom-competition.cjs'),path.join(engine,'custom-competition.cjs'));let manifest=fs.readFileSync(path.join(engine,'native-systems.cjs'),'utf8');if(!manifest.includes('customCompetition:'))manifest=manifest.replace('const domains={',"const domains={customCompetition:require('./custom-competition.cjs'),");fs.writeFileSync(path.join(engine,'native-systems.cjs'),manifest);}
 const b=require(path.join(engine,'worker.cjs')).createBridge({dataDir:path.join(root,'profile'),distDir:coordinator!==source?path.resolve(coordinator,'../../dist'):path.resolve(__dirname,'../dist'),seed:827381,now:1794178800000});let n=0;t.after(()=>{b.close();fs.rmSync(root,{recursive:true,force:true});});const go=(command,payload={})=>{const x=b.handle({id:++n,command,payload});a.equal(x.ok,true,command+':'+x.error);return x.model;};return {go};
}
test('départ natif Monde (Top 14 et Champ): vrais achats sans injection de roster',t=>{
 const h=worker(t);
 for(const club of [0,102]){
  const mode='world-champ#'+club;
  let model=settleClubMeetings(h.go('new_career',{mode:'world-champ',club}),(command,payload)=>h.go(command,payload)),market=model.clubLife.interclubMarket;
  a.equal(market.releasePolicy.minimum,37);
  const p=market.candidates.find(p=>p.available);a(p,mode+' a une vraie cible');
  const before=JSON.parse(h.go('export').meta.exportText).state;
  a(before.clubs.every(club=>club.players.length>=40),mode+' compte au moins 40 professionnels par club');
  const bid={playerId:p.id,sellerId:p.clubId,fee:p.fee,salary:p.salary,sourceSalary:p.sourceSalary,contractEnd:p.contractEnd,context:market.context},q=h.go('interclub_negotiate',bid).meta.interclubNegotiation;a(q.winner);
  model=h.go('interclub_auction',{...bid,expectedWinner:q.winner.clubId,expectedFee:q.winner.fee,expectedSalary:q.winner.salary,confirmed:true});
  const state=JSON.parse(h.go('export').meta.exportText).state;
  const seller=state.clubs[p.clubId].players;
  a.equal(seller.some(player=>player.id===p.id),false);
  a.equal(seller.length,Math.max(40,before.clubs[p.clubId].players.length-1));
  a.equal(state.clubs[q.winner.clubId].players.filter(x=>x.id===p.id).length,1);
 }
});
