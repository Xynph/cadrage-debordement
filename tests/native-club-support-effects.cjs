'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
// Diagnostic local du vrai worker : aucun accès d’inspection n’est ajouté au protocole livré.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),Module=require('node:module');
const source=path.resolve(__dirname,'../native/engine/worker.cjs'),original=fs.readFileSync(source,'utf8'),needle='return {handle,close};';assert.equal(original.split(needle).length,2);
const instrumented=new Module(source,module);instrumented.filename=source;instrumented.paths=Module._nodeModulePaths(path.dirname(source));instrumented._compile(original.replace(needle,'return {handle,close,inspect:run,entropy:()=>({seed,clock})};'),source);
const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'cd-support-effects-')),b=instrumented.exports.createBridge({dataDir:root,seed:412,now:1700000000000});let n=0;
const good=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,r.error);return r.model;};
try{
 let m=settleClubMeetings(good('new_career',{mode:'common',club:29}),good),state=b.inspect('JSON.stringify(S)'),entropy=b.entropy();for(let i=0;i<5;i++){good('snapshot');b.inspect('nativeSystems.project()');}assert.equal(b.inspect('JSON.stringify(S)'),state);assert.deepEqual(b.entropy(),entropy,'Consultation sans RNG ni horloge.');
 settleClubMeetings(good('train'),good);good('auto_lineup');m=good('snapshot');good('strategic_briefing',{context:m.clubLife.clubSupport.context,fixture:m.clubLife.clubSupport.briefing.fixture,plan:'pack'});good('begin_match');
 for(const [plan,own,attack] of [['pack',true,'conquete'],['pack',true,'large'],['espaces',true,'large'],['couverture',false,'large']]){
  b.inspect(`S.live.v69Briefing.plan=${JSON.stringify(plan)};S.live.tactics[${own?'S.live.userSide':'1-S.live.userSide'}]=${JSON.stringify(attack)};`);
  const result=JSON.parse(b.inspect(`JSON.stringify((()=>{const l=S.live,b=l.v69Briefing,side=${own?'l.userSide':'1-l.userSide'},attack=effectiveAttack(l,side),actual=tacticalEdge(l,side);delete l.v69Briefing;const base=tacticalEdge(l,side);l.v69Briefing=b;return {attack,actual,base,strength:b.strength};})())`));
  let expected=0;if(plan==='pack')expected=result.attack==='conquete'?Math.min(.035,Math.max(.005,.018+result.strength.pack*.0007)):-.008;
  if(plan==='espaces')expected=result.attack==='large'?Math.min(.035,Math.max(.005,.018+result.strength.backs*.0007)):-.008;
  if(plan==='couverture')expected=result.attack==='large'?-Math.min(.03,Math.max(.005,.017+result.strength.danger*.0005)):.008;
  assert.ok(Math.abs(result.actual-result.base-expected)<1e-10,'Effet réel V69 '+plan+' '+result.attack);
 }
 console.log('Support effets : état/RNG/horloge stables en consultation ; vrais ajustements tacticalEdge pack/espaces/couverture aux bornes V69 PASS. '+root);
}finally{b.close();}
