'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),{factory}=require('../native/engine/player-knowledge.cjs');
const k=factory(),clone=x=>JSON.parse(JSON.stringify(x));
function fixture(){return {season:1,round:0,club:0,careerVariation:{version:1,seed:123,varyCurrent:true},clubs:[{id:0,cash:100000,players:[{id:'own',rating:76,dev:{potential:88}}]},{id:1,players:[{id:'foreign',rating:74,dev:{potential:86}},{id:'unused',rating:70,dev:{potential:80}}]}],manager:{serial:0,reports:[],missions:[]},market:[],development:{academy:[]}};}
const mission=(s,n)=>s.manager.reports.unshift({playerId:'foreign',mission:'mission-'+n,note:74,potential:86,season:1,week:s.round});
function external(s){return k.visibility(s).foreign;}
test('club exact rating, five inclusive potential values, unknown foreign and pure reads',()=>{
 const s=fixture(),before=JSON.stringify(s),v=k.visibility(s);assert.equal(v.own.rating,76);assert.equal(v.own.potential,null);assert.equal(v.own.potentialRange.max-v.own.potentialRange.min,4);assert.deepEqual({...v.foreign,scouting:undefined},{rating:null,ratingRange:null,potential:null,potentialRange:null,knowledge:{version:1,owned:false,stage:'unobserved',observedAt:null},scouting:undefined});assert.equal(JSON.stringify(s),before);assert.deepEqual(k.visibility(s),v);
});
test('inclusive asymmetric bounded intervals contain truth and deep subset',()=>{
 let asym=0;for(let value=0;value<=100;value++)for(let n=0;n<30;n++){for(const width of [5,9,11]){const r=k.interval(value,width,'p'+n);assert.equal(r.max-r.min,width-1);assert.ok(r.min>=0&&r.max<=100&&r.min<=value&&r.max>=value);if(r.min+r.max!==2*value)asym++;const deep=k.interval(value,5,'deep'+n,r);assert.ok(deep.min>=r.min&&deep.max<=r.max);}}assert.ok(asym>8000);
});
test('real missions first then deep, duplicate event does not advance; ranges freeze despite truth growth',()=>{
 const s=fixture();let b=k.before(s);mission(s,1);k.observe(s,b,'advance_day');const first=external(s);assert.equal(first.ratingRange.max-first.ratingRange.min,8);assert.equal(first.potentialRange.max-first.potentialRange.min,10);
 s.clubs[1].players[0].rating=79;s.clubs[1].players[0].dev.potential=90;assert.deepEqual(external(s),first);
 b=k.before(s);k.observe(s,b,'snapshot');assert.equal(external(s).knowledge.stage,'observed');
 s.clubs[1].players[0].rating=74;s.clubs[1].players[0].dev.potential=86;s.round=2;b=k.before(s);mission(s,2);k.observe(s,b,'advance_day');const deep=external(s);assert.equal(deep.ratingRange.max-deep.ratingRange.min,4);assert.equal(deep.potentialRange.max-deep.potentialRange.min,4);assert.ok(deep.ratingRange.min>=first.ratingRange.min&&deep.ratingRange.max<=first.ratingRange.max);assert.ok(deep.potentialRange.min>=first.potentialRange.min&&deep.potentialRange.max<=first.potentialRange.max);assert.equal(k.validate(s),true);
});
test('archived reports work without a migration and persist after report rotation',()=>{
 const s=fixture();mission(s,1);const raw=JSON.stringify(s);assert.equal(external(s).knowledge.stage,'observed');assert.equal(JSON.stringify(s),raw);const b=k.before(s);s.round=2;mission(s,2);k.observe(s,b,'advance_day');s.manager.reports=[];assert.equal(external(s).knowledge.stage,'deep');assert.equal(k.validate(s),true);
});
test('own actual match participation observes; zero-minute and global AI games do not',()=>{
 const s=fixture();const l={finished:true,userSide:0,pair:[0,1],sheets:[{used:['own'],minutes:{own:80}},{used:['foreign','unused'],minutes:{foreign:80,unused:0}}]};s.live=l;assert.equal(k.captureMatch(s,l),true);assert.equal(external(s).knowledge.stage,'observed');assert.equal(k.visibility(s).unused.knowledge.stage,'unobserved');assert.equal(k.captureMatch(s,l),false);s.round=1;k.captureMatch(s,l);assert.equal(external(s).knowledge.stage,'deep');const other=fixture();other.live={...l,pair:[1,2]};assert.equal(k.captureMatch(other,other.live),false);
});
test('departure converts previous own exact to last-known deep intervals, recruitment to own exact',()=>{
 const s=fixture(),b=k.before(s),p=s.clubs[0].players.pop();s.clubs[1].players.push(p);k.observe(s,b,'interclub_accept');const v=k.visibility(s).own;assert.equal(v.rating,null);assert.equal(v.knowledge.stage,'deep');assert.equal(v.ratingRange.max-v.ratingRange.min,4);const f=s.clubs[1].players.shift();s.clubs[0].players.push(f);assert.equal(external(s).rating,74);assert.equal(external(s).knowledge.owned,true);
});
test('all player copies, report prose, aliases, nested potential, international and preview extras masked',()=>{
 const s=fixture(),v=k.visibility(s);const raw={squad:[{id:'own',rating:76,potential:91,positionRatings:{1:66},dev:{potential:88}}],market:[{id:'foreign',rating:74,potential:86,note:72,roleNote:71,positionRatings:{1:70},attributesV2:{tackling:74},skills:{power:73},rosterProfile:{rating:74},dev:{potential:86,rating:74},evidence:{noteMin:70,noteMax:76,potentialMin:80,potentialMax:90,label:'foo'}}],international:{players:[{id:'foreign',rating:74}]},meta:{preview:{playerId:'foreign',note:74,potential:86}},reports:[{playerId:'foreign',note:74,potential:86,assessment:{observed:['Niveau au poste relevé : 74 / 100 à cette date.','Prime relevée : 3000 € à cette date.'],estimates:['Potentiel au poste : 86 / 100.']}}]};
 k.project(raw,v);assert.equal(raw.squad[0].rating,76);assert.equal(raw.squad[0].potential,null);assert.equal(raw.squad[0].dev.potential,null);assert.equal(raw.market[0].rating,null);assert.equal(raw.market[0].note,null);assert.deepEqual(raw.market[0].positionRatings,{});assert.deepEqual(raw.market[0].attributesV2,{});assert.equal(raw.market[0].dev.rating,null);assert.equal(raw.international.players[0].rating,null);assert.equal(raw.meta.preview.note,null);assert.ok(!JSON.stringify(raw.reports).includes('74 / 100'));assert.equal(raw.market[0].evidence.noteMin,null);const once=clone(raw);k.project(raw,v);assert.deepEqual(raw,once,'final boundary is idempotent');
});
test('observed attrs remain hidden until deep, position ratings always hidden foreign',()=>{
 const s=fixture();let b=k.before(s);mission(s,1);k.observe(s,b,'advance_day');const doc=()=>({players:[{id:'foreign',attributesV2:{tackling:70},positionRatings:{1:60}}]});let m=doc();k.project(m,k.visibility(s));assert.deepEqual(m.players[0].attributesV2,{});b=k.before(s);mission(s,2);k.observe(s,b,'advance_day');m=doc();k.project(m,k.visibility(s));assert.deepEqual(m.players[0].attributesV2,{tackling:70});assert.deepEqual(m.players[0].positionRatings,{});
});
test('strict validation rejects corrupt ranges, duplicates, version, future and extra keys',()=>{
 const s=fixture(),b=k.before(s);mission(s,1);k.observe(s,b,'advance_day');for(const mutate of [x=>x.playerKnowledge.version=2,x=>x.playerKnowledge.evil=true,x=>x.playerKnowledge.records[0].push(clone(x.playerKnowledge.records[0][0])),x=>x.playerKnowledge.records[0][0][8]++,x=>x.playerKnowledge.records[0][0][2]=2]){const bad=clone(s);mutate(bad);assert.throws(()=>k.validate(bad));}
});
test('more than 2 000 active observed people survive block rollover and a real match',()=>{
 const s=fixture();s.clubs[1].players=Array.from({length:2001},(_,i)=>({id:'p-'+i,rating:70,dev:{potential:80}}));
 s.manager.reports=s.clubs[1].players.map((p,i)=>({playerId:p.id,mission:'mission-'+i,note:70,potential:80,season:1,week:0}));
 const l={finished:true,userSide:0,pair:[0,1],sheets:[{used:['own'],minutes:{own:80}},{used:['p-2000'],minutes:{'p-2000':80}}]};s.live=l;
 assert.equal(k.captureMatch(s,l),true);assert.equal(s.playerKnowledge.records.length,2);assert.equal(s.playerKnowledge.records[0].length,2000);assert.equal(k.visibility(s)['p-0'].knowledge.stage,'observed');assert.equal(k.visibility(s)['p-2000'].knowledge.stage,'deep');assert.equal(k.validate(s),true);
});
test('a discovery or shortlist is not an observation; centre candidate IDs come only from trusted event facts',()=>{
 const s=fixture();s.manager.watch=['foreign'];let b=k.before(s);k.observe(s,b,'academy_discover');assert.equal(external(s).knowledge.stage,'unobserved');b=k.before(s);k.observe(s,b,'academy_center_scout',{centerId:'club:1',observedPlayerIds:['foreign']});assert.equal(external(s).knowledge.stage,'unobserved');k.observe(s,b,'academy_center_scout',{centerId:'club:1'},{observedPlayerIds:['foreign']});assert.equal(external(s).knowledge.stage,'observed');
});
test('national-only manager has no silently owned club; missing development getter stays pure',()=>{
 const s=fixture();s.national={role:{club:false}};delete s.clubs[0].players[0].dev;const raw=JSON.stringify(s);assert.equal(k.visibility(s).own.rating,null);assert.equal(JSON.stringify(s),raw);
});
test('targeted observation charges once, never observes at planning, completes after two work cycles, then deep',()=>{
 const s=fixture(),effects={charge:amount=>s.clubs[0].cash-=amount},payload={playerId:'foreign',confirmed:true,context:{season:1,week:0,club:0}};
 k.plan(s,payload,effects);assert.equal(s.clubs[0].cash,95000);assert.equal(external(s).knowledge.stage,'unobserved');assert.equal(external(s).scouting.pending,true);assert.throws(()=>k.plan(s,payload,effects),/en cours/);assert.equal(s.clubs[0].cash,95000);
 let job=s.playerKnowledge.jobs[0];s.round=1;k.advanceJobs(s,job.id);assert.equal(job.remaining,1);assert.equal(external(s).knowledge.stage,'unobserved');s.round=2;k.advanceJobs(s,job.id);assert.equal(external(s).knowledge.stage,'observed');assert.equal(external(s).scouting.pending,false);
 k.plan(s,{...payload,context:{...payload.context,week:2}},effects);job=s.playerKnowledge.jobs.at(-1);s.round=3;k.advanceJobs(s,job.id);s.round=4;k.advanceJobs(s,job.id);assert.equal(external(s).knowledge.stage,'deep');assert.equal(s.clubs[0].cash,90000);
});
test('targeted queue shares four-mission capacity, rejects stale/malformed/own requests before money',()=>{
 const s=fixture(),effects={charge:amount=>s.clubs[0].cash-=amount},base={playerId:'foreign',confirmed:true,context:{season:1,week:0,club:0}};
 for(const payload of [{...base,confirmed:false},{...base,context:{season:1,week:1,club:0}},{...base,playerId:'own'},{...base,extra:true}])assert.throws(()=>k.plan(s,payload,effects));assert.equal(s.clubs[0].cash,100000);assert.equal(s.playerKnowledge,undefined);
 s.manager.missions=Array.from({length:4},(_,i)=>({id:'mission-'+i,status:i===0?'active':'queued'}));assert.throws(()=>k.plan(s,base,effects),/Quatre/);assert.equal(s.clubs[0].cash,100000);
});
test('unknown IDs default to hidden, nested qualities cannot escape the player boundary',()=>{
 const model={players:[{id:'old-gone',name:'Archive',pos:'Centre',rating:76,potential:90,details:{attributesV2:{passing:75},positionRatings:{1:70},seasonStart:76}}]};k.project(model,{});const p=model.players[0];assert.equal(p.rating,null);assert.equal(p.potential,null);assert.deepEqual(p.details.attributesV2,{});assert.deepEqual(p.details.positionRatings,{});assert.equal(p.details.seasonStart,null);
});
test('actual active scout level 70 speeds work, level 65/absent/inactive remains two weeks; planning freezes source',()=>{
 const s=fixture(),p=k.players(s).get('foreign');assert.equal(k.scouting(s,p).workCycles,2);
 s.staffCareer={version:1,people:[[{id:'scout-65',role:'scout',clubId:0,level:65,contractEnd:1}]]};assert.equal(k.scouting(s,p).workCycles,2);s.staffCareer.people[0].push({id:'scout-70',role:'scout',clubId:0,level:70,contractEnd:1});const raw=JSON.stringify(s);assert.equal(k.scouting(s,p).workCycles,1);assert.equal(k.scouting(s,p).sourceScoutId,'scout-70');assert.equal(JSON.stringify(s),raw);
 k.plan(s,{playerId:'foreign',confirmed:true,context:{season:1,week:0,club:0}},{charge:n=>s.clubs[0].cash-=n});s.staffCareer.people=[];assert.equal(k.scouting(s,p).workCycles,1);assert.equal(k.scouting(s,p).sourceScoutId,'scout-70');s.round=1;k.advanceJobs(s,s.playerKnowledge.jobs[0].id);assert.equal(external(s).knowledge.stage,'observed');
 const other=fixture();other.staffCareer={version:1,people:[[{id:'scout-other',role:'scout',clubId:1,level:95,contractEnd:1}]]};assert.equal(k.scouting(other,k.players(other).get('foreign')).workCycles,2);
});
test('our loaned player remains exactly known while an actual departure loses exact visibility',()=>{
 const s=fixture(),p=s.clubs[0].players.pop();s.clubs[1].players.push(p);s.v78to81={loans:[{id:p.id,from:0,to:1,season:1}]};assert.equal(k.visibility(s).own.rating,76);assert.equal(k.visibility(s).own.knowledge.owned,true);
});
test('old manager cumulative weeks never become a fabricated season date or invalid migration',()=>{
 const s=fixture();s.season=2;s.round=1;s.economy={week:35};s.manager.reports=[{playerId:'foreign',mission:'mission-old',note:74,potential:86,season:1,week:32}];const raw=JSON.stringify(s);assert.equal(external(s).knowledge.observedAt.week,null);assert.equal(JSON.stringify(s),raw);const b=k.before(s);s.manager.reports.unshift({playerId:'foreign',mission:'mission-new',note:74,potential:86,season:2,week:35});k.observe(s,b,'finish_round');assert.equal(external(s).knowledge.stage,'deep');assert.equal(external(s).knowledge.observedAt.week,1);assert.equal(k.validate(s),true);
});
test('a pending report planned without a scout never invents the source of a later hire',()=>{
 const s=fixture(),p=k.players(s).get('foreign');k.plan(s,{playerId:'foreign',confirmed:true,context:{season:1,week:0,club:0}},{charge:n=>s.clubs[0].cash-=n});s.staffCareer={version:1,people:[[{id:'later-scout',role:'scout',clubId:0,level:95,contractEnd:1}]]};const offer=k.scouting(s,p);assert.equal(offer.workCycles,2);assert.equal(offer.sourceScoutId,null);assert.equal(offer.sourceScoutLevel,null);
});
test('actual legacy managerWeek and targeted jobs share FIFO and advance only once per work week',()=>{
 const fs=require('node:fs'),vm=require('node:vm'),s=fixture();s.economy={week:0,freeAgents:[]};Object.assign(s.manager,{lastWeek:0,inbox:[],watch:[],delegation:{}});s.market=[];
 const context=vm.createContext({S:s,POS:['Pilier'],FAMILIES:[0],club:()=>s.clubs[s.club],label:()=>'',save(){},ledgerEntry:(label,amount)=>s.clubs[0].cash+=amount,render(){}});
 vm.runInContext(fs.readFileSync(require.resolve('../dist/manager.js'),'utf8'),context);
 vm.runInContext('const knowledge=('+factory.toString()+')();knowledge.installHooks();if(!createScoutMission(0,30,100000,10000))throw Error("legacy refused");',context);
 k.plan(s,{playerId:'foreign',confirmed:true,context:{season:1,week:0,club:0}},{charge:n=>s.clubs[0].cash-=n});const job=s.playerKnowledge.jobs[0];assert.equal(job.status,'queued');
 function cycle(n){s.round=n;s.economy.week=n;vm.runInContext('managerWeek()',context);}
 cycle(1);assert.equal(s.manager.missions[0].remaining,1);assert.equal(job.remaining,2);cycle(2);assert.equal(s.manager.missions[0].status,'done');assert.equal(job.status,'active');assert.equal(job.remaining,2);cycle(3);assert.equal(job.remaining,1);vm.runInContext('managerWeek()',context);assert.equal(job.remaining,1);cycle(4);assert.equal(job.status,'done');assert.equal(external(s).knowledge.stage,'observed');
});
