'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');const {createBridge}=require('../native/engine/worker.cjs');const {make}=require('./native-academy.cjs');
const folder=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'native-academy-loan-capacity-'));let seq=0;
function bridge(name){return createBridge({dataDir:path.join(folder,name),seed:13,now:1700000000000})}
function academyFixture(){const t=make(0);t.run(`const nativeCareerVariation=(${require('../native/engine/career-variation.cjs').toString()})();`);return t;}
function call(b,command,payload={}){return b.handle({id:++seq,command,payload})}function good(b,command,payload={}){const x=call(b,command,payload);assert.equal(x.ok,true,command+': '+x.error);return x.model;}
function academy(b,command,payload={}){return good(b,command,{...good(b,'snapshot').clubLife.academyPathways.context,confirmed:true,...payload})}
for(const count of [1,3]){const b=bridge('loans-'+count),t=academyFixture(),r=t.run;try{
 settleClubMeetings(good(b,'new_career',{mode:'common',club:0}),(command,payload)=>good(b,command,payload));academy(b,'academy_activate');const ids=[];
 for(let i=0;i<count;i++){const id=good(b,'snapshot').clubLife.academyPathways.players[0].id;ids.push(id);academy(b,'academy_promote',{playerId:id,years:3});academy(b,'academy_loan',{playerId:id,to:28+i%2});}
 const doc=JSON.parse(good(b,'export').meta.exportText);t.ctx.saved=doc.state;r('S=saved');const capacity=r('professionalCapacity()');
 for(let i=0;i<6-count;i++){const m=good(b,'snapshot'),p=m.market.find(p=>p.available);assert.ok(p);t.ctx.id=p.id;const salary=r("reservationWage(S.market.find(p=>p.id===id),'recruit',1)");good(b,'recruit',{playerId:p.id,salary,years:1,confirmed:true});}
 let m=good(b,'snapshot'),before=good(b,'export').meta.exportText,extra=m.market[0];
 assert.equal(call(b,'recruit',{playerId:extra.id,salary:100000,years:1,confirmed:true}).ok,false,'un recrutement ne consomme pas la place de retour');
 assert.equal(good(b,'export').meta.exportText,before,'refus sans changement');
 assert.equal(m.decisions.recruitment.reserved,count);assert.equal(m.decisions.recruitment.places,0);assert.equal(m.decisions.recruitment.capacity,capacity);assert.ok(m.market.every(p=>!p.available));assert.equal(m.clubLife.academyPathways.promotionAvailable,false);
 if(count===1)assert.equal(call(b,'promote_academy',{playerId:m.clubLife.academyPathways.players[0].id,confirmed:true}).ok,false,'promotion ne vole pas la place réservée');
 t.ctx.saved=JSON.parse(before).state;r('S=saved');t.ctx.extraId=extra.id;
 assert.equal(r("forecastQuote(S,{kind:'recruit',id:extraId,years:1}).valid"),false);
 assert.equal(r("successionSimulate(S,[{kind:'youth',id:S.development.academy[0].id}],1).valid"),false);
 for(let w=0;w<34;w++)r('finishRound()');const ended=r('JSON.stringify(createSaveDocument())');good(b,'import',{text:ended});settleClubMeetings(good(b,'next_season',{confirmed:true}),(command,payload)=>good(b,command,payload));
 const state=JSON.parse(good(b,'export').meta.exportText).state;assert.equal(state.v78to81.loans.length,0);for(const id of ids){assert.equal(state.clubs[0].players.filter(p=>p.id===id).length,1);assert.equal(state.clubs.flatMap(c=>c.players).filter(p=>p.id===id).length,1)}assert.ok(state.clubs[0].players.length<=capacity);
 const text=good(b,'export').meta.exportText;good(b,'import',{text});assert.equal(good(b,'export').meta.exportText,text);
 }finally{b.close();}}
if(process.env.CD_ACADEMY_LOAN_REPRO){const b=bridge('review-fixture'),t=academyFixture();try{const original=fs.readFileSync(process.env.CD_ACADEMY_LOAN_REPRO,'utf8');good(b,'import',{text:original});const stable=good(b,'export').meta.exportText;
 const invalid=JSON.parse(original);for(const p of invalid.state.clubs[0].players){p.contractEnd=invalid.state.season+2;p.dev.retireAge=Math.max(p.age+3,p.dev.retireAge);}t.ctx.corrupt=invalid.state;invalid.checksum=t.run('saveChecksum(corrupt)');const refused=call(b,'import',{text:JSON.stringify(invalid)});assert.equal(refused.ok,false,'anciens engagements sans aucune place libérable rejetés');assert.match(refused.error,/retour de prêt|places/i);assert.equal(good(b,'export').meta.exportText,stable);
 settleClubMeetings(good(b,'next_season',{confirmed:true}),(command,payload)=>good(b,command,payload));const state=JSON.parse(good(b,'export').meta.exportText).state;assert.equal(state.clubs[0].players.filter(p=>p.id==='youth-0-1-0').length,1);assert.equal(state.clubs[28].players.filter(p=>p.id==='youth-0-1-0').length,0);}finally{b.close();}}
else console.log('SKIP fixture de revue des prêts : CD_ACADEMY_LOAN_REPRO absent (cas facultatif)');
console.log('PASS places des prêts : admissions/projections/plan cohérents, retours 1 et 3 joueurs, saison réelle/import/reprise');
