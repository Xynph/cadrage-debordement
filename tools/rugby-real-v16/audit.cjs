'use strict';
// QA adapter only. Native constructors, sheet legality, matches and career rules stay untouched.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),crypto=require('node:crypto');
const {context}=require('../../tests/harness.cjs');
const C=require('../rugby-real-v12/review.cjs');
const root=path.resolve(__dirname,'../..');
const spec=require('../../data/scouting/shadow-v16-20261107.json');
const clone=x=>JSON.parse(JSON.stringify(x));
const mean=a=>a.length?a.reduce((s,x)=>s+x,0)/a.length:null;
const round=n=>n===null?null:Math.round(n*1000)/1000;
const modules=['lnr-v11-aging.js','lnr-ratings-v12.js','lnr-rosters-data.js','lnr-birthyears-data.js','lnr-career.js'];
const data=vm.runInNewContext(fs.readFileSync(path.join(root,'dist/lnr-ratings-v12.js'),'utf8')+'\n;LNR_V12_PLAYER_DATA;');
const read=(g,s)=>JSON.parse(g.run('JSON.stringify('+s+')'));
function setSeed(g,seed){g.ctx.__v16Seed=seed>>>0;g.run('(()=>{let seed=__v16Seed;Math.random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/4294967296}})()');}
function boot(seed=105){const g=context();for(const file of modules)vm.runInContext(fs.readFileSync(path.join(root,'dist',file),'utf8'),g.ctx,{filename:file});setSeed(g,seed);g.run("start(0,'lnr');S.clubs.forEach(c=>c.players.forEach(ensurePhysicalLoad))");return g;}
function put(g,s){g.ctx.__v16State=clone(s);g.run('S=__v16State');}
function signature(){return crypto.createHash('sha256').update(modules.map(f=>fs.readFileSync(path.join(root,'dist',f))).join('')).update(fs.readFileSync(path.join(root,'modding/data06/rugby-master-2026-2027.json'))).digest('hex');}
function mismatches(g){return read(g,`S.clubs.flatMap((c,i)=>c.players.filter(p=>p.lnrGroup==='1ère ligne'&&p.pos!==p.gameplayPosition).map(p=>({id:p.id,name:p.name,club:LNR_TOP14[i][0],group:p.lnrGroup,nativeRole:p.pos,v12Role:p.gameplayPosition,rating:p.rating,nativeNote:roleNote(p)})))`);}
function applyPositions(state,{projection=false}={}){
 for(const row of spec.positions.filter(x=>x.applyShadow)){
  const p=state.clubs.flatMap(c=>c.players).find(p=>p.id===row.id);if(!p)continue;
  p.pos=p.gameplayPosition=row.evidenceRole;p.fam=row.evidenceRole==='Talonneur'?1:0;
  if(projection)p.skills=C.project(p);
 }
 return state;
}
function candidate(p,dose){
 const rule=spec.players.find(x=>x.id===p.id);if(!rule||!rule.doses.includes(dose))throw Error('Invalid shadow dose/player');
 const out=clone(p);for(const [key,delta] of Object.entries(rule.deltasPerDose))out.attributesV2[key]=Math.max(20,Math.min(97,out.attributesV2[key]+delta*dose));
 out.skills=C.project(out);
 return {player:out,attributes:data.attributeKeys.map(k=>({key:k,from:p.attributesV2[k],to:out.attributesV2[k],delta:round(out.attributesV2[k]-p.attributesV2[k])})),skills:data.skillKeys.map(k=>({key:k,from:p.skills[k],to:out.skills[k],delta:round(out.skills[k]-p.skills[k])}))};
}
function sheet(g,clubId,preferred=false){g.ctx.__v16PreferredSheet=preferred;return read(g,`(()=>{const c=S.clubs[${clubId}],sh=buildSheet(c,__v16PreferredSheet?S.lineup:[],__v16PreferredSheet?S.reserves:[]),map=new Map(c.players.map(p=>[p.id,p]));return {...sh,xv:sh.lineup.filter(Boolean).length,benchCount:sh.bench.filter(Boolean).length,xvMean:mean(sh.lineup.map(id=>map.get(id)).filter(Boolean).map(p=>roleNote(p))),benchMean:mean(sh.bench.map(id=>map.get(id)).filter(Boolean).map(p=>roleNote(p)))};})()`);}
function roleRows(g){return mismatches(g).map(row=>{
 const proof=spec.positions.find(x=>x.id===row.id);g.ctx.__v16ID=row.id;
 const note=read(g,`(()=>{const c=S.clubs.find(c=>c.players.some(p=>p.id===__v16ID)),p=c.players.find(p=>p.id===__v16ID),s=buildSheet(c);return {tier:s.lineup.includes(p.id)?'XV':s.bench.includes(p.id)?'bench':'depth',skills:p.skills,attrs:p.attributesV2};})()`);
 const native=read(g,'S');applyPositions(native);put(g,native);g.ctx.__v16ID=row.id;
 const corrected=read(g,`(()=>{const c=S.clubs.find(c=>c.players.some(p=>p.id===__v16ID)),p=c.players.find(p=>p.id===__v16ID),s=buildSheet(c);return {role:p.pos,note:roleNote(p),tier:s.lineup.includes(p.id)?'XV':s.bench.includes(p.id)?'bench':'depth'};})()`);
 // Restore original roles; roleRows is observational.
 for(const r of mismatchesOriginal){const p=native.clubs.flatMap(c=>c.players).find(p=>p.id===r.id);p.pos=r.nativeRole;p.fam=r.nativeRole==='Talonneur'?1:0;p.gameplayPosition=r.v12Role;}
 put(g,native);
 return {...row,evidenceRole:proof.evidenceRole,confidence:proof.confidence,initialTier:note.tier,shadowRole:corrected.role,shadowNote:corrected.note,shadowTier:corrected.tier,deltaNote:corrected.note-row.nativeNote};
 });}
// Initial-role record is read without re-implementing lnrAssignment.
const reference=boot();const mismatchesOriginal=mismatches(reference);
function frame(g){return read(g,'S');}
function tier(sh,id){return sh.lineup.includes(id)?'XV':sh.bench.includes(id)?'bench':'depth';}
function note(g,p){g.ctx.__v16Player=clone(p);return g.run('roleNote(__v16Player)');}
function exposure(g,state,id,kind){
 const s=clone(state),c=s.clubs.find(c=>c.players.some(p=>p.id===id)),p=c.players.find(p=>p.id===id);s.club=c.id;s.lineup=[];s.reserves=[];
 if(kind==='unavailable'){p.injury=2;return s;}
 if(kind==='fresh')return s;
 // Explicit, legal manager choices on a COPY. Native slot/bench eligibility and
 // preferred-sheet builder apply; no player is moved into an unqualified slot.
 for(const q of c.players)if(q.id!==id&&q.pos===p.pos){q.condition=78;q.physicalLoad.fatigue=30;}
 p.condition=kind==='starter'?92:100;put(g,s);g.ctx.__v16ID=id;
 const selected=read(g,`(()=>{const c=S.clubs[S.club],p=c.players.find(p=>p.id===__v16ID),without=buildSheet({...c,players:c.players.filter(q=>q.id!==p.id)}),pref=[...without.lineup],bench=[];if(${JSON.stringify(kind)}==='starter'){const slot=POS.findIndex((_,i)=>slotEligible(p,i));if(slot<0)throw Error('No legal starter slot');pref[slot]=p.id;}else{const slot=BENCH_LABELS.findIndex((_,i)=>benchEligible(p,i));if(slot<0)throw Error('No legal bench slot');bench[slot]=p.id;}return buildSheet(c,pref,bench);})()`);
 s.lineup=selected.lineup;s.reserves=selected.bench;
 for(const q of c.players)if(q.id!==id&&s.lineup.includes(q.id)){q.condition=82;q.physicalLoad.fatigue=30;}
 return s;
}
function match(g,state,a,b,seed,home=0,id=null,preferred=false){
 put(g,state);g.ctx.__v16A=a;g.ctx.__v16B=b;g.ctx.__v16Home=home;g.ctx.__v16Target=id;g.ctx.__v16Preferred=preferred;
 // Target club is a manager-controlled legal composition for exposure probes; opponent remains native AI. Career runs retain original user/AI roles.
 g.run('(()=>{const sh=buildSheet(S.clubs[S.club],__v16Preferred?S.lineup:[],__v16Preferred?S.reserves:[]);S.lineup=sh.lineup;S.reserves=sh.bench})()');setSeed(g,seed);
 return read(g,`(()=>{const pair=__v16Home===0?[__v16A,__v16B]:[__v16B,__v16A],side=pair.indexOf(__v16A);const l=createRugbyMatch(pair,null,true);let n=0;while(!l.finished){if(++n>5000)throw Error('Unterminated native match');l.paused=false;advanceRugby(l)}applyMatchInjuries(l);const sh=l.sheets[side],p=S.clubs[__v16A].players.find(p=>p.id===__v16Target);return {margin:l.score[side]-l.score[1-side],score:l.score,minutes:sh.minutes[__v16Target]||0,initial:sh.initial.includes(__v16Target),used:(sh.minutes[__v16Target]||0)>0,nominated:sh.nominated.includes(__v16Target),lineup:sh.initial,subs:l.subs.filter(s=>s.side===side).length,injuries:S.clubs[__v16A].players.filter(p=>p.injury>0).length,scrumsWon:l.stats[side].scrumsWon,lineoutsWon:l.stats[side].lineoutsWon,finalCondition:p?.condition??null};})()`);
}
function ci(values){const n=values.length,m=mean(values);if(n<2)return {n,mean:round(m),ci95:null};const variance=values.reduce((s,x)=>s+(x-m)**2,0)/(n-1),critical=n>=30?1.96:n>=12?2.201:n>=8?2.365:n>=6?2.571:3.182,se=Math.sqrt(variance/n);return {n,mean:round(m),ci95:[round(m-critical*se),round(m+critical*se)]};}
function compact(label,value){const text=JSON.stringify(value);if(Buffer.byteLength(text)>48000)throw Error('V16 summary exceeds safe log line');console.log('RUGBY_REAL_V16_'+label+' '+text);}
function dossier(g){const master=require('../../modding/data06/rugby-master-2026-2027.json'),careers=require('../../data/scouting/review-v12/career-evidence.json');const state=frame(g);return spec.players.map(rule=>{const c=state.clubs.find(c=>c.players.some(p=>p.id===rule.id)),p=c.players.find(p=>p.id===rule.id);put(g,state);const sh=sheet(g,c.id);const e=careers.records.find(r=>r.playerId===p.id);return {...rule,age:p.age,role:p.pos,profileRole:p.gameplayPosition,rating:p.rating,note:note(g,p),tier:tier(sh,p.id),history:e.seasons,startsHistorical:null,startsLimit:'Les historiques LNR publics collectés ne donnent pas les titularisations ; les starts courants ne sont pas des starts2025-26.',peers:c.players.filter(q=>q.id!==p.id&&q.pos===p.pos).map(q=>({id:q.id,name:q.name,note:note(g,q),tier:tier(sh,q.id)})).sort((a,b)=>b.note-a.note),candidates:rule.doses.map(dose=>({dose,...candidate(p,dose),player:undefined,note:note(g,candidate(p,dose).player)}))};});}
module.exports={root,spec,data,clone,mean,round,read,setSeed,boot,put,frame,signature,mismatches,applyPositions,candidate,sheet,roleRows,tier,note,exposure,match,ci,compact,dossier};
function opponents(g,state,clubId){put(g,state);const q=state.clubs.filter(c=>c.id!==clubId).map(c=>({id:c.id,quality:sheet(g,c.id).xvMean})).sort((a,b)=>a.quality-b.quality||a.id-b.id);return [q[0],q[6],q.at(-1)];}
function runPlayers(ids,{seeds=8}={}){
 const before=signature(),g=boot(105),active=frame(g),base=applyPositions(clone(active));const result=[];
 for(const id of ids){const c=base.clubs.find(c=>c.players.some(p=>p.id===id)),p=c.players.find(p=>p.id===id),opps=opponents(g,base,c.id),rows=[];
  for(const kind of ['fresh','starter','bench','unavailable']){
   const exposed=exposure(g,base,id,kind);put(g,exposed);const initialSheet=sheet(g,c.id,kind==='starter'||kind==='bench'),target=exposed.clubs[c.id].players.find(p=>p.id===id);
   const variants=[0,-1,1,2].map(dose=>{const s=clone(exposed);if(dose)s.clubs[c.id].players[s.clubs[c.id].players.findIndex(q=>q.id===id)]=candidate(target,dose).player;put(g,s);const sh=sheet(g,c.id,kind==='starter'||kind==='bench');return {dose,state:s,note:note(g,s.clubs[c.id].players.find(q=>q.id===id)),tier:tier(sh,id),xvMean:sh.xvMean};});
   const byDose=new Map([-1,1,2].map(d=>[d,[]])),usage=new Map(variants.map(v=>[v.dose,[]]));let controlSelfEqual=true;
   for(let k=0;k<seeds;k++){
    const totals=new Map([-1,1,2].map(d=>[d,[]]));
    for(const opp of opps)for(const home of [0,1]){
     const seed=(0xa3180000+k*0x1001+opp.id*271)>>>0;
     const control=match(g,exposed,c.id,opp.id,seed,home,id,kind==='starter'||kind==='bench');usage.get(0).push(control);
     // Actual repeated control once per scenario pins determinism and strict state cloning.
     if(k===0&&opp===opps[0]&&home===0)controlSelfEqual&&=JSON.stringify(control)===JSON.stringify(match(g,clone(exposed),c.id,opp.id,seed,home,id,kind==='starter'||kind==='bench'));
     for(const v of variants.slice(1)){const next=match(g,v.state,c.id,opp.id,seed,home,id,kind==='starter'||kind==='bench');usage.get(v.dose).push(next);totals.get(v.dose).push(next.margin-control.margin);}
    }
    for(const dose of [-1,1,2])byDose.get(dose).push(mean(totals.get(dose)));
   }
   rows.push({kind,initialTier:tier(initialSheet,id),opponents:opps.map(o=>({name:base.clubs[o.id].name,quality:round(o.quality)})),controlSelfEqual,
    arms:variants.map(v=>({dose:v.dose,note:v.note,tier:v.tier,xvDelta:round(v.xvMean-initialSheet.xvMean),minutes:round(mean(usage.get(v.dose).map(r=>r.minutes))),starts:usage.get(v.dose).filter(r=>r.initial).length,nominated:usage.get(v.dose).filter(r=>r.nominated).length,appearances:usage.get(v.dose).filter(r=>r.used).length,subs:round(mean(usage.get(v.dose).map(r=>r.subs))),injuries:round(mean(usage.get(v.dose).map(r=>r.injuries))),margin:v.dose?ci(byDose.get(v.dose)):null}))});
  }
  const item={id,name:p.name,role:p.pos,age:p.age,rows,matches:4*3*2*seeds*4,extraControlMatches:4};result.push(item);compact('INDIVIDUAL',item);
 }
 if(signature()!==before)throw Error('Production files changed');
 return result;
}
function runPositions({seeds=12}={}){
 const g=boot(105),base=frame(g),report=roleRows(g);const results=[];
 for(const clubId of [0,1]){
  const opps=opponents(g,base,clubId);
  for(const kind of ['fresh','fatigued']){
   const control=clone(base);if(kind==='fatigued'){put(g,control);const sh=sheet(g,clubId);for(const p of control.clubs[clubId].players)if(sh.lineup.includes(p.id)){p.condition=78;p.physicalLoad.fatigue=35;}}
   const variants=[['control',clone(control)],['position',applyPositions(clone(control))],['projected',applyPositions(clone(control),{projection:true})]];
   const changes=variants.map(([label,s])=>{put(g,s);const sh=sheet(g,clubId);return {label,xvMean:round(sh.xvMean),benchMean:round(sh.benchMean),lineup:sh.lineup,bench:sh.bench};});
   const diffs={position:[],projected:[]},subs={position:[],projected:[]};let actualFixture=null;
   for(let k=0;k<seeds;k++){
    const pair={position:[],projected:[]},sub={position:[],projected:[]};
    for(const opp of opps)for(const home of [0,1]){
     const seed=(0x84520000+k*0x4321+opp.id*271)>>>0,old=match(g,control,clubId,opp.id,seed,home);if(k===0&&opp===opps[0]&&home===0)actualFixture={opponent:base.clubs[opp.id].name,seed,control:old.lineup};
     for(const [label,s] of variants.slice(1)){const next=match(g,s,clubId,opp.id,seed,home);if(k===0&&opp===opps[0]&&home===0)actualFixture[label]=next.lineup;pair[label].push(next.margin-old.margin);sub[label].push(next.subs-old.subs);}
    }
    for(const label of ['position','projected']){diffs[label].push(mean(pair[label]));subs[label].push(mean(sub[label]));}
   }
   const out={club:base.clubs[clubId].name,kind,matches:3*3*2*seeds,changes,actualFixture,effects:['position','projected'].map(label=>({label,margin:ci(diffs[label]),subs:ci(subs[label])}))};results.push(out);compact('POSITION_MATCHES',out);
  }
 }
 return {players:report,results};
}
function snapshot(g){return read(g,`S.clubs.map((c,i)=>{const sh=buildSheet(c),ps=c.players,ids=sh.lineup.filter(Boolean),roles=[...new Set(POS)];return {id:c.id,club:LNR_TOP14[i][0],user:c.id===S.club,roster:ps.length,lnr:ps.filter(p=>p.lnrRatingsVersion===1).length,cash:c.cash,xv:ids.length,bench:sh.bench.filter(Boolean).length,xvMean:mean(ids.map(id=>roleNote(ps.find(p=>p.id===id)))),benchMean:mean(sh.bench.filter(Boolean).map(id=>roleNote(ps.find(p=>p.id===id)))),roleCounts:Object.fromEntries(roles.map(role=>[role,ps.filter(p=>p.pos===role).length])),availableCounts:Object.fromEntries(roles.map(role=>[role,ps.filter(p=>p.pos===role&&!p.injury).length])),players:ps.map(p=>({id:p.id,pos:p.pos,age:p.age,rating:p.rating,note:roleNote(p),speed:p.attributesV2?.topSpeed??null,strength:p.attributesV2?.strength??null,mental:p.attributesV2?.decisions??null,contractEnd:p.contractEnd,minutes:p.dev?.careerMinutes??0,condition:p.condition,fatigue:p.physicalLoad?.fatigue??0,injury:p.injury})),lineup:sh.lineup,benchIds:sh.bench};})`);}
function instrument(g){g.run(`(()=>{globalThis.__v16Observed=[];const original=applyMatchInjuries;applyMatchInjuries=function(l){if(!l.injuriesApplied)__v16Observed.push({pair:[...l.pair],sheets:l.sheets.map(sh=>({initial:[...sh.initial],nominated:[...sh.nominated],minutes:{...sh.minutes}}))});return original(l)}})()`);}
function runCareer(seed,{seasons=6,training=true}={}){
 const source=signature(),out=[];
 for(const mode of ['control','position']){
  const g=boot(seed);if(mode==='position'){const s=frame(g);applyPositions(s);put(g,s);g.run('autoLineup()');}
  instrument(g);
  const openings=[snapshot(g)],years=[];let played=0;
  for(let y=1;y<=seasons;y++){
   const use=new Map(),clubUse=new Map();
   function observeAvailability(){const shot=snapshot(g);for(const c of shot){if(!clubUse.has(c.id))clubUse.set(c.id,{starts:new Set(),benches:new Set(),missingXV:0,missingBench:0,fatigue:[],injuries:[]});const u=clubUse.get(c.id);u.missingXV+=c.xv<15;u.missingBench+=c.bench<8;u.fatigue.push(mean(c.players.map(p=>p.fatigue)));u.injuries.push(c.players.filter(p=>p.injury>0).length);for(const p of c.players){if(!use.has(p.id))use.set(p.id,{id:p.id,starts:0,bench:0,appearances:0,minutesSeason:0,unavailable:0});use.get(p.id).unavailable+=p.injury>0;}}}
   function observePlayed(){for(const l of read(g,'__v16Observed'))for(let side=0;side<2;side++){const u=clubUse.get(l.pair[side]),sh=l.sheets[side];for(const id of sh.nominated){if(!use.has(id))use.set(id,{id,starts:0,bench:0,appearances:0,minutesSeason:0,unavailable:0});const p=use.get(id);p.starts+=sh.initial.includes(id);p.bench+=!sh.initial.includes(id);p.appearances+=(sh.minutes[id]||0)>0;p.minutesSeason+=sh.minutes[id]||0;if(sh.initial.includes(id))u.starts.add(id);else u.benches.add(id);}}g.run('__v16Observed=[]');}
   for(let r=0;r<26;r++){setSeed(g,(seed+y*100003+r*701)>>>0);if(training)g.run('trainWeek()');observeAvailability();g.run('finishRound()');played+=7;observePlayed();}
   let guard=0;while(g.run('S.phase')!=='ended'){if(++guard>4)throw Error('Native playoffs did not end');setSeed(g,(seed+y*100003+26000+guard*701)>>>0);played+=g.run('roundPairs().length');if(training)g.run('trainWeek()');g.run('finishRound()');}
   g.run('__v16Observed=[]');const end=snapshot(g),table=read(g,'ranked().map(c=>({id:c.id,points:c.points,pf:c.pf,pa:c.pa}))');
   setSeed(g,(seed+y*100003+99001)>>>0);g.run('advanceSeason()');const next=snapshot(g);openings.push(next);
   const reports=read(g,`S.aiRoster.reports.filter(r=>r.season===${y})`);
   const year={season:y,table,clubs:end.map(c=>{const a=openings[y-1].find(a=>a.id===c.id),b=next.find(b=>b.id===c.id),u=clubUse.get(c.id),old=new Map(a.players.map(p=>[p.id,p])),present=b.players.filter(p=>old.has(p.id)),lnr=present.filter(p=>old.get(p.id).speed!==null&&p.speed!==null);return {club:c.club,user:c.user,rosterStart:a.roster,rosterEnd:c.roster,nextRoster:b.roster,leaving:a.players.filter(p=>!b.players.some(q=>q.id===p.id)).length,arrivals:b.players.filter(p=>!old.has(p.id)).length,uniqueStarters:u.starts.size,uniqueBench:u.benches.size,missingXVWeeks:u.missingXV,missingBenchWeeks:u.missingBench,meanFatigue:round(mean(u.fatigue)),meanInjured:round(mean(u.injuries)),xvMean:round(c.xvMean),nextXvMean:round(b.xvMean),matchedAging:lnr.length,speedDelta:round(mean(lnr.map(p=>p.speed-old.get(p.id).speed))),strengthDelta:round(mean(lnr.map(p=>p.strength-old.get(p.id).strength))),mentalDelta:round(mean(lnr.map(p=>p.mental-old.get(p.id).mental))),transactions:reports.find(r=>r.clubId===c.id)||null};}),targets:spec.players.map(rule=>{const p=end.flatMap(c=>c.players).find(p=>p.id===rule.id);return {id:rule.id,...(use.get(rule.id)||{starts:0,bench:0,unavailable:0}),minutesEnd:p?.minutes??null,note:p?.note??null,age:p?.age??null};})};
   years.push(year);
   compact('CAREER_YEAR',{seed,mode,season:y,roster:next.reduce((s,c)=>s+c.roster,0),aiRoster:next.filter(c=>!c.user).reduce((s,c)=>s+c.roster,0),userRoster:next.find(c=>c.user).roster,completeXV:next.filter(c=>c.xv===15).length,completeBench:next.filter(c=>c.bench===8).length,weakest:next.slice().sort((a,b)=>a.xvMean-b.xvMean).slice(0,3).map(c=>({club:c.club,xv:round(c.xvMean),roster:c.roster})),ai:year.clubs.filter(c=>!c.user).map(c=>({club:c.club,uniqueStarters:c.uniqueStarters,missingBenchWeeks:c.missingBenchWeeks,arrivals:c.arrivals,leaving:c.leaving})),targets:year.targets});
  }
  out.push({seed,mode,seasons,training,weeklyExposureScope:'regular-season-only; cumulative minutesEnd includes playoffs',nativeMatches:played,openings,years});
 }
 if(signature()!==source)throw Error('Production files changed during career');
 return out;
}
module.exports={...module.exports,opponents,runPlayers,runPositions,snapshot,instrument,runCareer};
function clubHierarchy(){
 const master=clone(require('../../modding/data06/rugby-master-2026-2027.json'));
 for(const p of master.players){const t=data.players[p.id];p.rating=p.ratingV12=t[0];p.attributesV2=Object.fromEntries(data.attributeKeys.map((k,i)=>[k,t[3][i]]));p.skills=Object.fromEntries(data.skillKeys.map((k,i)=>[k,t[4][i]]));p.hiddenTraitsV2=clone(t[6]);}
 const lab=require('../rugby-real-v12/native.cjs').laboratory(master,'legacy');
 const g=boot(),active=frame(g),native=active.clubs.map(c=>{const before=sheet(g,c.id),copy=applyPositions(clone(active));put(g,copy);const after=sheet(g,c.id);put(g,active);return {club:c.name,control:round(before.xvMean),position:round(after.xvMean),delta:round(after.xvMean-before.xvMean)};});
 const catalogue=lab.clubs.map(c=>{const sh=lab.sheet(c);return {club:c.slug,league:c.league,players:c.players.length,xv:sh.lineup.filter(Boolean).length,bench:sh.bench.filter(Boolean).length,quality:round(lab.quality(c))};});
 return {nativeTOP14:native,catalogue30:catalogue,limitation:'Catalogue laboratoire au poste V12 : ses erreurs de poste ne sont pas des postes officiels. PRO D2 non instanciée dans la carrière historique.'};
}
module.exports.clubHierarchy=clubHierarchy;
