'use strict';
// Manual native audit. Observations only: no state repair or financial changes.
const assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path'),crypto=require('node:crypto'),{execFileSync}=require('node:child_process');
const {createBridge}=require('../native/engine/worker.cjs');
const hash=x=>crypto.createHash('sha256').update(x).digest('hex');
function inventory(s){
 const players={},add=(p,location)=>{assert(p&&typeof p.id==='string','player ID required');const row=players[p.id]??={id:p.id,locations:[],age:p.age,salary:p.salary,contractEnd:p.contractEnd??null};if(!row.locations.includes(location))row.locations.push(location);};
 for(const c of s.clubs||[])for(const p of c.players||[])add(p,'club:'+c.id);
 for(const p of s.development?.academy||[])add(p,'academy:'+s.club);
 for(const a of s.aiRoster?.academies||[])for(const p of a.players||[])add(p,'academy:'+a.clubId);
 for(const p of s.market||[])add(p,'market');for(const p of s.economy?.freeAgents||[])add(p,'free-agents');
 for(const p of Object.values(players))assert(p.locations.filter(l=>l.startsWith('club:')).length<=1,'duplicate professional owner: '+p.id);
 return {season:s.season,week:s.round,players,retired:(s.development?.retired||[]).map(p=>({id:p.id,season:p.season})),counts:{professionals:(s.clubs||[]).reduce((n,c)=>n+c.players.length,0),academies:Object.values(players).filter(p=>p.locations.some(l=>l.startsWith('academy:'))).length,market:(s.market||[]).length,freeAgents:(s.economy?.freeAgents||[]).length,unique:Object.keys(players).length}};
}
function reconcile(before,after,events=[]){
 const flows=[],count={};const owner=p=>p?.locations.find(x=>x.startsWith('club:')),academy=p=>p?.locations.find(x=>x.startsWith('academy:'));
 for(const id of new Set([...Object.keys(before.players),...Object.keys(after.players)])){
  const a=before.players[id],b=after.players[id],from=owner(a),to=owner(b);if(JSON.stringify(a?.locations)===JSON.stringify(b?.locations))continue;
  const evidence=events.filter(e=>e.playerId===id),retired=after.retired.some(p=>p.id===id&&!before.retired.some(old=>old.id===id&&old.season===p.season));
  let kind='unknown',basis='cause-not-recorded';
  if(retired&&!to){kind='retirement';basis='new-retirement-ledger-entry';}
  else if(from&&to&&from!==to){kind='recruitment';basis='observed-professional-owner-change';}
  else if(!from&&to){
   if(academy(a)&&academy(a).slice(8)===to.slice(5)){kind='promotion';basis='observed-academy-to-professional';}
   else{const event=evidence.find(e=>Number(e.clubId)===Number(to.slice(5))&&['recruit','promote','emergency'].includes(e.kind));if(event){kind={recruit:'recruitment',promote:'promotion',emergency:'emergency'}[event.kind];basis='explicit-roster-event';}}
  }else if(from&&!to){
   if(retired||evidence.some(e=>e.kind==='retire'&&Number(e.clubId)===Number(from.slice(5)))){kind='retirement';basis=retired?'new-retirement-ledger-entry':'explicit-roster-event';}
   else if(b?.locations.some(l=>['market','free-agents'].includes(l))&&(evidence.some(e=>e.kind==='release'&&Number(e.clubId)===Number(from.slice(5)))||Number.isFinite(a.contractEnd)&&a.contractEnd<=before.season)){kind='release';basis=evidence.some(e=>e.kind==='release')?'explicit-roster-event':'expired-contract-and-free-pool';}
  }else if(!from&&!to){kind='pool-change';basis='observed-academy-or-market-surface-change';}
  if(from===to&&from){kind='pool-change';basis='professional-retained-other-location-changed';}
  flows.push({id,kind,basis,from:a?.locations||[],to:b?.locations||[],evidence:evidence.map(e=>({season:e.season,clubId:e.clubId,kind:e.kind,fee:e.fee}))});count[kind]=(count[kind]||0)+1;
 }
 const clubIds=new Set([...Object.values(before.players),...Object.values(after.players)].flatMap(p=>p.locations.filter(x=>x.startsWith('club:'))));
 const conservation=[...clubIds].map(club=>{const size=state=>Object.values(state.players).filter(p=>p.locations.includes(club)).length,arrivals=flows.filter(f=>!f.from.includes(club)&&f.to.includes(club)).length,departures=flows.filter(f=>f.from.includes(club)&&!f.to.includes(club)).length;return {clubId:Number(club.slice(5)),before:size(before),arrivals,departures,after:size(after),residual:size(after)-size(before)-arrivals+departures};});
 assert(conservation.every(c=>c.residual===0),'professional ID conservation failed');
 return {from:{season:before.season,week:before.week},to:{season:after.season,week:after.week},population:{beforeUnique:Object.keys(before.players).length,afterUnique:Object.keys(after.players).length,appeared:Object.keys(after.players).filter(id=>!before.players[id]).length,disappeared:Object.keys(before.players).filter(id=>!after.players[id]).length},count,flows,conservation,unknown:flows.filter(f=>f.kind==='unknown').length};
}
function measurements(s){
 // Reuse the game's public test loader and real buildSheet on an isolated copy.
 // Greedy selector coverage is a game observation, not certified qualification.
 const h=require('../tests/france-harness.cjs').context();h.ctx.auditState=JSON.parse(JSON.stringify(s));h.run('S=auditState');
 const sheets=JSON.parse(h.run('JSON.stringify(S.clubs.map(c=>({clubId:c.id,sheet:buildSheet(c)})))'));
 const rows=s.clubs.map(c=>{const ages=c.players.map(p=>p.age).filter(Number.isFinite),sheet=sheets.find(x=>x.clubId===c.id).sheet,ids=[...sheet.lineup,...sheet.bench],academy=(c.id===s.club?s.development.academy:s.aiRoster?.academies.find(a=>a.clubId===c.id)?.players)||[];return {clubId:c.id,professionals:c.players.length,academy:academy.length,weeklyWages:c.players.reduce((n,p)=>n+p.salary,0),age:{min:ages.length?Math.min(...ages):null,max:ages.length?Math.max(...ages):null,mean:ages.length?ages.reduce((a,b)=>a+b,0)/ages.length:null,unknown:c.players.length-ages.length},expiringContracts:c.players.filter(p=>Number.isFinite(p.contractEnd)&&p.contractEnd<=s.season).length,gameSheet:{complete:ids.every(Boolean)&&new Set(ids).size===23,filled:ids.filter(Boolean).length,missingSlots:ids.flatMap((id,i)=>id?[]:[i+1])}};});
 return {clubs:rows,professionalMin:Math.min(...rows.map(c=>c.professionals)),incompleteGameSheets:rows.filter(c=>!c.gameSheet.complete).map(c=>c.clubId)};
}
function argumentsFor(argv){
 const o={mode:'world',club:0,seasons:2,budgetMs:1200000};for(let i=0;i<argv.length;i+=2){const key={'--seed':'seed','--mode':'mode','--club':'club','--seasons':'seasons','--budget-ms':'budgetMs','--out':'out'}[argv[i]];assert(key&&argv[i+1]!==undefined,'argument/value required: '+argv[i]);o[key]=['mode','out'].includes(key)?argv[i+1]:Number(argv[i+1]);}
 assert(Number.isInteger(o.seed)&&o.seed>=0&&o.seed<=0xffffffff,'explicit uint32 seed required');assert(['world','world-pacific','world-japan','world-nationale','world-champ'].includes(o.mode),'world mode required');assert(Number.isInteger(o.seasons)&&o.seasons>=1&&o.seasons<=2,'one or two seasons');assert(Number.isInteger(o.club)&&o.club>=0,'nonnegative club ID');assert(Number.isInteger(o.budgetMs)&&o.budgetMs>=1000,'positive budget');assert(o.out,'explicit --out required');o.out=path.resolve(o.out);assert(!fs.existsSync(o.out),'output already exists');return o;
}
function run(o){
 const started=Date.now(),dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-world-turnover-')),report={schema:'world-roster-turnover-v1',options:o,node:process.version,source:execFileSync('git',['rev-parse','HEAD'],{cwd:path.join(__dirname,'..'),encoding:'utf8'}).trim(),status:'running',commands:0,completedSeasons:0,observations:[],periods:[],promotions:[],policy:'Passive manager, real public worker commands; no state repair, coefficients, contract or recruitment decisions. Game selector coverage is not official viability.'};
 let bridge,model,serial=0;const events=[],seen=new Set();
 const observe=s=>{for(const e of s.aiRoster?.events||[]){const key=JSON.stringify(e);if(!seen.has(key)){seen.add(key);events.push(e);}}};
 const save=()=>{fs.mkdirSync(path.dirname(o.out),{recursive:true});fs.writeFileSync(o.out,JSON.stringify(report,null,2));};
 const go=(command,payload={})=>{assert(Date.now()-started<o.budgetMs,'audit budget exceeded');const r=bridge.handle({id:++serial,command,payload});report.commands++;assert(r.ok,command+': '+r.error);return model=r.model;};
 const state=()=>JSON.parse(go('export').meta.exportText).state;
 const capture=(label,s)=>{const row={label,season:s.season,week:s.round,phase:s.phase,results:s.history.length,counts:inventory(s).counts,...measurements(s)};report.observations.push(row);return row;};
 try{bridge=createBridge({dataDir:dir,seed:o.seed,now:1794178800000});go('new_career',{mode:o.mode,club:o.club});let initial=state();observe(initial);capture('initial',initial);
  for(let season=1;season<=o.seasons;season++){
   const opening=inventory(initial),eventStart=events.length;
   for(let week=model.meta.week;week<46;week++){
    if(model.next){if(!model.selection.valid)go('auto_lineup');if(!model.selection.valid){const reasons=model.selection.errors;go('promote_cover',{confirmed:true});report.promotions.push({season,week,reasons});}assert(model.selection.valid,'user sheet remains incomplete');go('begin_match');go('delegate');}
    go('finish_round');assert.equal(model.meta.week,week+1);observe(state());
   }
   const end=state();assert.equal(end.phase,'ended');assert.equal(end.history.length,end.worldMode.fixtures.length,'all seasonal results required');capture('end-S'+season,end);report.periods.push({label:'season-'+season,...reconcile(opening,inventory(end),events.slice(eventStart))});report.completedSeasons++;
   const before=inventory(end),transitionEvents=events.length;go('next_season',{confirmed:true});const next=state();observe(next);capture('after-transition-S'+season,next);report.periods.push({label:'transition-'+season,...reconcile(before,inventory(next),events.slice(transitionEvents))});
   assert.equal(next.season,season+1);assert.equal(next.worldMode.yearbook.length,season);initial=next;
   report.elapsedMs=Date.now()-started;console.log(JSON.stringify({season,results:end.history.length,elapsedMs:report.elapsedMs,transition:report.periods.at(-1).count,minProfessionals:report.observations.at(-1).professionalMin}));save();
  }
  const expected=go('export').meta.exportText,bytes=fs.readFileSync(path.join(dir,'PrototypeGodot/donnees.json'));bridge.close();bridge=createBridge({dataDir:dir,seed:1,now:1});assert.equal(go('export').meta.exportText,expected,'final reopen exact');assert(fs.readFileSync(path.join(dir,'PrototypeGodot/donnees.json')).equals(bytes),'private profile exact');report.reopened=true;report.eventCount=events.length;report.status='completed';report.passed=true;
 }catch(e){report.status='failed';report.passed=false;report.failure={season:model?.meta.season,week:model?.meta.week,error:e.stack||String(e)};throw e;}
 finally{bridge?.close();report.elapsedMs=Date.now()-started;report.toolSha256=hash(fs.readFileSync(__filename));save();fs.rmSync(dir,{recursive:true,force:true});}
 return report;
}
if(require.main===module){try{run(argumentsFor(process.argv.slice(2)));}catch(e){console.error(e.stack);process.exitCode=1;}}
module.exports={inventory,reconcile,measurements,argumentsFor,run};
