'use strict';
// True sporting values stay in S. This factory is shared by the VM and the
// final, detached protocol projection. It never draws random numbers or dates.
function factory(){
 const VERSION=1,LIMIT=32000,BLOCK=2000;
 const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const number=x=>typeof x==='number'&&Number.isFinite(x);
 const integer=(x,a,b)=>Number.isSafeInteger(x)&&x>=a&&x<=b;
 const id=x=>typeof x==='string'&&/^[A-Za-z0-9:_-]{1,180}$/.test(x);
 const copy=x=>JSON.parse(JSON.stringify(x));
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const check=(x,message)=>{if(!x)throw Error('Connaissance des joueurs : '+message+'.');};
 const week=s=>s?.worldMode?.week??s?.franceMode?.week??s?.round??s?.economy?.week??0;
 const hash=x=>{let h=2166136261;for(const c of String(x)){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}return h>>>0;};
 const salt=s=>s?.careerVariation?.seed??s?.commonDatabase?.id??s?.worldMode?.edition??'legacy';
 const rangeValid=(r,width)=>shape(r,['min','max'])&&integer(r.min,0,100)&&integer(r.max,0,100)&&r.max-r.min===width-1;
 function interval(value,width,key,previous=null){
  check(number(value)&&value>=0&&value<=100&&[5,9,11].includes(width),'note ou amplitude invalide');
  let low=Math.max(0,Math.ceil(value-width+1)),high=Math.min(101-width,Math.floor(value));
  if(previous&&previous.min<=value&&previous.max>=value&&previous.max-previous.min>=width-1){
   low=Math.max(low,previous.min);high=Math.min(high,previous.max-width+1);
  }
  const choices=[];for(let min=low;min<=high;min++)if(min+(width-1)/2!==value)choices.push(min);
  const min=choices.length?choices[hash(key)%choices.length]:low;
  return {min,max:min+width-1};
 }
 function potential(p){
  if(number(p.dev?.potential))return p.dev.potential;if(number(p.potential))return p.potential;
  // Same immutable-id rule as ensureDevelopment, on values only, without
  // constructing development state or normalizing the actual player.
  const h=hash(p.id),margin=String(p.id).startsWith('academy-')?10+h%9:p.age<=22?8+h%14:p.age<=26?4+h%9:p.age<=29?1+h%5:h%3;
  return Math.min(99,p.rating+margin);
 }
 function players(s){
  const found=new Map();
  const add=(p,owned=false)=>{if(!p||!id(p.id)||!number(p.rating))return;const old=found.get(p.id);if(!old||owned)found.set(p.id,{id:p.id,name:p.name??p.id,pos:p.pos??null,age:p.age??null,clubId:p.clubId??null,family:p.fam??null,rating:p.rating,potential:potential(p),owned:owned||old?.owned===true});};
  const clubOwned=s?.national?.role?.club!==false;
  const ownedLoans=new Set([s?.v78to81,...Object.values(s?.nativeAcademy?.offices||{}).map(o=>o.v78to81)].flatMap(o=>o?.loans||[]).filter(l=>l.from===s.club&&l.season===s.season).map(l=>l.id));
  for(const c of s?.clubs||[])for(const p of c.players||[])add(p,clubOwned&&(c.id===s.club||ownedLoans.has(p.id)));
  for(const p of s?.development?.academy||[])add(p,clubOwned);
  for(const p of s?.academyIntake?.players||[])add(p,clubOwned);
  for(const a of s?.aiRoster?.academies||[])for(const p of a.players||[])add(p,clubOwned&&a.clubId===s.club);
  for(const p of s?.market||[])add(p);
  for(const p of s?.economy?.freeAgents||[])add(p);
  for(const c of s?.nativeAcademy?.centers||[])for(const p of c.players||[])add(p,clubOwned&&c.clubId===s.club);
  for(const p of s?.v95to100?.network?.players||[])add(p);
  return found;
 }
 function unpack(st){return (st?.records||[]).flatMap(block=>block.map(r=>({id:r[0],stage:r[1],season:r[2],week:r[3],tokens:r[4],rating:r[5],potential:r[6],ratingRange:{min:r[7],max:r[8]},potentialRange:{min:r[9],max:r[10]}})));}
 function store(s,out){
  // Retired players absent from every live source and archived manager report
  // cannot be opened any more. Compact only these records, never active people.
  const active=players(s),reports=new Set((s.manager?.reports||[]).map(r=>r.playerId));
  let rows=[...out.values()];if(rows.length>LIMIT)rows=rows.filter(r=>active.has(r.id)||reports.has(r.id));
  check(rows.length<=LIMIT,'registre actif supérieur à 32 000 joueurs');
  rows.sort((a,b)=>a.id<b.id?-1:a.id>b.id?1:0);
  const tuples=rows.map(r=>[r.id,r.stage,r.season,r.week,r.tokens,r.rating,r.potential,r.ratingRange.min,r.ratingRange.max,r.potentialRange.min,r.potentialRange.max]),blocks=[];
  for(let i=0;i<tuples.length;i+=BLOCK)blocks.push(tuples.slice(i,i+BLOCK));
  s.playerKnowledge={version:VERSION,records:blocks,...(s.playerKnowledge?.jobs?{jobs:s.playerKnowledge.jobs}:{})};validate(s);
 }
 function validate(s){
  const st=s?.playerKnowledge;if(st===undefined)return true;
  check((shape(st,['version','records'])||shape(st,['version','records','jobs']))&&st.version===VERSION&&Array.isArray(st.records)&&st.records.length<=16&&st.records.every(b=>Array.isArray(b)&&b.length<=BLOCK&&b.every(r=>Array.isArray(r)&&r.length===11)),'manifeste invalide ou capacité dépassée');
  const jobs=st.jobs||[];check(Array.isArray(jobs)&&jobs.length<=24,'missions ciblées invalides');const jobIds=new Set();
  for(const j of jobs){check(shape(j,['id','playerId','remaining','status','season','week','club','completedSeason','completedWeek','workCycles','sourceScoutId','sourceScoutLevel'])&&id(j.id)&&id(j.playerId)&&!jobIds.has(j.id)&&integer(j.remaining,0,2)&&integer(j.workCycles,1,2)&&j.remaining<=j.workCycles&&(j.sourceScoutId===null?j.sourceScoutLevel===null:id(j.sourceScoutId)&&number(j.sourceScoutLevel)&&j.sourceScoutLevel>=0&&j.sourceScoutLevel<=100)&&j.workCycles===(j.sourceScoutLevel>=70?1:2)&&['queued','active','done'].includes(j.status)&&(j.status==='done'?j.remaining===0:j.remaining>0)&&integer(j.season,1,s.season)&&integer(j.week,0,10000)&&integer(j.club,0,s.clubs.length-1)&&(j.season<s.season||j.week<=week(s))&&(j.status==='done'?integer(j.completedSeason,j.season,s.season)&&integer(j.completedWeek,0,10000)&&(j.completedSeason<s.season||j.completedWeek<=week(s))&&(j.completedSeason>j.season||j.completedWeek>=j.week):j.completedSeason===null&&j.completedWeek===null),'mission ciblée invalide');jobIds.add(j.id);}
  check(jobs.filter(j=>j.status!=='done').length<=4&&jobs.filter(j=>j.status==='active').length<=1,'file ciblée invalide');
  const seen=new Set();
  for(const r of unpack(st)){
   check(shape(r,['id','stage','season','week','tokens','rating','potential','ratingRange','potentialRange'])&&id(r.id)&&!seen.has(r.id),'joueur invalide ou répété');seen.add(r.id);
   check(['observed','deep'].includes(r.stage)&&integer(r.season,1,s.season)&&(r.week===null||integer(r.week,0,10000)&&(r.season<s.season||r.week<=week(s))),'date ou suivi invalide');
   check(Array.isArray(r.tokens)&&r.tokens.length>=1&&r.tokens.length<=2&&new Set(r.tokens).size===r.tokens.length&&r.tokens.every(t=>typeof t==='string'&&/^[A-Za-z0-9:_-]{1,240}$/.test(t)),'événement invalide ou répété');
   check(number(r.rating)&&r.rating>=0&&r.rating<=100&&number(r.potential)&&r.potential>=0&&r.potential<=100&&rangeValid(r.ratingRange,r.stage==='deep'?5:9)&&rangeValid(r.potentialRange,r.stage==='deep'?5:11)&&r.ratingRange.min<=r.rating&&r.ratingRange.max>=r.rating&&r.potentialRange.min<=r.potential&&r.potentialRange.max>=r.potential,'intervalle ou note invalide');
   check(r.stage!=='observed'||r.tokens.length===1,'profondeur incompatible');
  }
  return true;
 }
 function record(s,p,token,at,prior=null,forceDeep=false){
  const tokens=[...new Set([...(prior?.tokens||[]),token])].slice(-2),stage=forceDeep||prior?.stage==='deep'||tokens.length===2?'deep':'observed';
  const unchanged=prior&&prior.rating===p.rating&&prior.potential===p.potential;
  const base=salt(s)+':'+p.id+':'+stage;
  return {id:p.id,stage,season:at.season,week:at.week,tokens,rating:p.rating,potential:p.potential,
   ratingRange:interval(p.rating,stage==='deep'?5:9,base+':rating',unchanged?prior.ratingRange:null),
   potentialRange:interval(p.potential,stage==='deep'?5:11,base+':potential',unchanged?prior.potentialRange:null)};
 }
 // Read-only fallback for old saves: report values and dates are archived facts,
 // unlike current AI attributes or an unrecorded historical match assessment.
 function legacy(s){
  const records=new Map();
  for(const r of [...(s?.manager?.reports||[])].reverse()){
   if(!id(r.playerId)||!id(r.mission)||!number(r.note)||!number(r.potential)||!integer(r.season,1,s.season)||!integer(r.week,0,1e9))continue;
   const token='mission:'+r.mission,old=records.get(r.playerId);if(old?.tokens.includes(token))continue;
   const offset=number(s.economy?.week)?s.economy.week-r.week:null;
   const localWeek=r.season===s.season&&offset!==null&&integer(week(s)-offset,0,10000)?week(s)-offset:null;
   records.set(r.playerId,record(s,{id:r.playerId,rating:r.note,potential:r.potential},token,{season:r.season,week:localWeek},old));
  }
  return records;
 }
 function records(s){const out=legacy(s);for(const r of unpack(s?.playerKnowledge))out.set(r.id,r);return out;}
 function before(s){return {club:s?.club,owned:[...players(s).values()].filter(p=>p.owned),events:eventTokens(s),known:[...records(s).values()]};}
 function eventTokens(s){return new Set((s?.manager?.reports||[]).map(r=>'mission:'+r.mission+':'+r.playerId));}
 function observe(s,prior,command,payload={},facts={}){
  if(!s||!prior||['new_career','import','save'].includes(command))return false;
  const people=players(s),out=new Map((prior.known||[]).map(r=>[r.id,r]));for(const r of unpack(s.playerKnowledge))out.set(r.id,r);let changed=false;
  const add=(p,token,at={season:s.season,week:week(s)},deep=false)=>{if(!p)return;const old=out.get(p.id);if(old?.tokens.includes(token))return;out.set(p.id,record(s,p,token,at,old,deep));changed=true;};
  for(const r of s.manager?.reports||[]){const token='mission:'+r.mission+':'+r.playerId;if(!prior.events.has(token))add(people.get(r.playerId),'mission:'+r.mission,{season:s.season,week:week(s)});}
  for(const p of prior.owned)if(!people.get(p.id)?.owned)add(p,'club:'+prior.club+':'+s.season+':'+week(s),undefined,true);
  if(command==='academy_watch')add(people.get(payload.playerId),'academy:'+s.season+':'+week(s)+':'+(s.v95to100?.network?.players.find(p=>p.id===payload.playerId)?.scouted??0));
  if(command==='academy_center_scout'){
   // The actual available candidate list is supplied by the academy projection,
   // never all players in a discovered centre.
   for(const pid of facts.observedPlayerIds||[])add(people.get(pid),'center:'+payload.centerId+':'+s.season);
  }
  if(changed)store(s,out);
  return changed;
 }
 function captureMatch(s,l){
  if(!s||!l?.finished||l!==s.live||!l.pair?.includes(s.club)||!integer(l.userSide,0,1))return false;
  const people=players(s),out=records(s),token='match:'+s.season+':'+week(s)+':'+s.phase+':'+l.pair.join('-');let changed=false;
  for(let side=0;side<2;side++)for(const pid of new Set(l.sheets?.[side]?.used||[])){
   const minutes=l.sheets[side].minutes?.[pid],p=people.get(pid);if(!number(minutes)||minutes<=0||!p||p.owned||out.get(pid)?.tokens.includes(token))continue;

   out.set(pid,record(s,p,token,{season:s.season,week:week(s)},out.get(pid)));changed=true;
  }
  if(changed)store(s,out);return changed;
 }
 function pending(s){return [...(s?.manager?.missions||[]),...(s?.playerKnowledge?.jobs||[])].filter(j=>j.status!=='done');}
 function scout(s){
  if(s?.staffCareer?.version!==1)return null;
  return s.staffCareer.people.flat().filter(p=>p.role==='scout'&&p.clubId===s.club&&number(p.level)&&p.contractEnd>=s.season).sort((a,b)=>b.level-a.level||(a.id<b.id?-1:a.id>b.id?1:0))[0]??null;
 }
 function scouting(s,p,staff=scout(s)){
  const job=(s?.playerKnowledge?.jobs||[]).find(j=>j.playerId===p.id&&j.status!=='done'),workCycles=job?.workCycles??(staff?.level>=70?1:2),context={season:s.season,week:week(s),club:s.club};
  const reason=p.owned?'Les joueurs du club sont déjà suivis.':s?.national?.role?.club===false?'Observation réservée au manager d’un club.':s.live?'Observation indisponible pendant le match.':s.phase==='ended'?'Saison terminée.':job?'Observation en cours.':pending(s).length>=4?'Quatre missions sont déjà en attente.':(s.clubs[s.club]?.cash??0)<5000?'Trésorerie insuffisante (5 000 €).':'';
  return {available:!reason,reason,cost:5000,workCycles,workUnit:'week',sourceScoutId:job?job.sourceScoutId:staff?.id??null,sourceScoutLevel:job?job.sourceScoutLevel:staff?.level??null,pending:!!job,job:job?{id:job.id,status:job.status,remaining:job.remaining,remainingWeeks:job.remaining}:null,context};
 }
 function plan(s,payload,effects={}){
  check(s&&shape(payload,['playerId','confirmed','context'])&&id(payload.playerId)&&payload.confirmed===true&&shape(payload.context,['season','week','club']),'confirmez le coût et le contexte de l’observation');
  check(payload.context.season===s.season&&payload.context.week===week(s)&&payload.context.club===s.club,'contexte d’observation périmé');
  const p=players(s).get(payload.playerId);check(p,'joueur extérieur introuvable');const status=scouting(s,p);check(status.available,status.reason||'observation indisponible');
  // The worker supplies the existing ledger and inbox functions. Tests can use
  // explicit isolated effects; no protocol value can install an effect.
  check(typeof effects.charge==='function','registre financier indisponible');effects.charge(5000);
  const st=s.playerKnowledge??{version:VERSION,records:[]},jobs=(st.jobs||[]).filter(j=>j.status!=='done').concat((st.jobs||[]).filter(j=>j.status==='done').slice(-19));
  const serial=++s.manager.serial;
  jobs.push({id:'observation-'+serial,playerId:p.id,remaining:status.workCycles,status:pending(s).some(j=>j.status==='active')?'queued':'active',season:s.season,week:week(s),club:s.club,completedSeason:null,completedWeek:null,workCycles:status.workCycles,sourceScoutId:status.sourceScoutId,sourceScoutLevel:status.sourceScoutLevel});
  s.playerKnowledge={...st,jobs};validate(s);effects.message?.('Observation confiée au recruteur','5 000 €. Rapport après '+status.workCycles+' semaine(s) de travail du recruteur.');return {scoutingAction:{command:'observe_player',playerId:p.id}};
 }
 function queue(s){
  const jobs=pending(s);if(!jobs.length)return;
  const serial=j=>Number(String(j.id).match(/(\d+)$/)?.[1]??0),first=jobs.slice().sort((a,b)=>serial(a)-serial(b))[0];
  for(const j of jobs)j.status=j===first?'active':'queued';
 }
 function advanceJobs(s,activeId,effects={}){
  const job=(s?.playerKnowledge?.jobs||[]).find(j=>j.id===activeId&&j.status==='active');
  if(job){
   job.remaining--;
   if(job.remaining===0){
    job.status='done';job.completedSeason=s.season;job.completedWeek=week(s);const p=players(s).get(job.playerId);
    if(p){const out=records(s);out.set(p.id,record(s,p,'target:'+job.id,{season:s.season,week:week(s)},out.get(p.id)));store(s,out);effects.message?.('Rapport d’observation disponible','Le suivi du joueur a été actualisé. Consultez sa fiche avant de décider.');}
    else effects.message?.('Observation terminée','Ce joueur n’est plus accessible dans le vivier actuel.');
   }
  }
  queue(s);return !!job;
 }
 function installHooks(){
  if(typeof recordDevelopmentMatch==='function'&&!recordDevelopmentMatch.__playerKnowledge){const original=recordDevelopmentMatch,wrapped=function(l){const result=original.apply(this,arguments);captureMatch(typeof S==='undefined'?null:S,l);return result;};Object.assign(wrapped,original);wrapped.__playerKnowledge=true;recordDevelopmentMatch=wrapped;}
  if(typeof managerWeek==='function'&&!managerWeek.__playerKnowledge){const original=managerWeek,wrapped=function(){const s=typeof S==='undefined'?null:S,prior=s?.manager?.lastWeek,target=(s?.playerKnowledge?.jobs||[]).find(j=>j.status==='active'),result=original.apply(this,arguments);if(s&&s===S&&s.manager?.lastWeek!==prior){if(target)for(const j of s.manager.missions||[])if(j.status==='active')j.status='queued';advanceJobs(s,target?.id,{message:(title,body)=>managerMessage(title,body,'recruitment','recruitment')});}return result;};Object.assign(wrapped,original);wrapped.__playerKnowledge=true;managerWeek=wrapped;}
  if(typeof createScoutMission==='function'&&!createScoutMission.__playerKnowledge){const original=createScoutMission,wrapped=function(){if(typeof S!=='undefined'&&pending(S).length>=4)return false;const result=original.apply(this,arguments);if(result)queue(S);return result;};Object.assign(wrapped,original);wrapped.__playerKnowledge=true;createScoutMission=wrapped;}
 }
 function reports(s){
  const people=players(s);
  return (s?.playerKnowledge?.jobs||[]).filter(j=>j.status==='done').slice(-20).reverse().flatMap(j=>{
   const p=people.get(j.playerId);if(!p)return [];
   return [{id:'target-report:'+j.id,mission:j.id,playerId:p.id,name:p.name,pos:p.pos,family:p.family,age:p.age,rating:p.rating,note:p.rating,potential:p.potential,salary:null,price:null,grade:null,season:j.completedSeason,week:j.completedWeek,
    assessment:{source:'Observation ciblée · saison '+j.completedSeason+' · semaine '+j.completedWeek,age:null,stale:null,available:true,availability:'Joueur identifié dans son effectif actuel. Conditions et accord à vérifier avant toute signature.',fit:'Observation individuelle ciblée.',observed:[],estimates:[],limits:['Salaires et coûts à vérifier dans la négociation actuelle.'],caution:'Le suivi indique les dernières informations de votre staff.'}}];
  });
 }
 function visibility(s){
  const known=records(s),out=Object.create(null),staff=scout(s);
  for(const p of players(s).values()){
   const r=known.get(p.id),owned=p.owned,stage=owned?'club':r?.stage??'unobserved';
   out[p.id]={rating:owned?p.rating:null,ratingRange:owned?null:r?.ratingRange??null,potential:null,
    potentialRange:owned?interval(p.potential,5,salt(s)+':'+p.id+':club:potential:'+p.potential):r?.potentialRange??null,
    knowledge:{version:VERSION,owned,stage,observedAt:owned?null:r?{season:r.season,week:r.week,date:null}:null},scouting:scouting(s,p,staff)};
  }
  for(const [pid,r]of known)if(!out[pid])out[pid]={rating:null,ratingRange:r.ratingRange,potential:null,potentialRange:r.potentialRange,knowledge:{version:VERSION,owned:false,stage:r.stage,observedAt:{season:r.season,week:r.week,date:null}}};
  return out;
 }
 function project(model,visible){
  if(!object(model))return model;
  const attrs=['attributes','attributesV2','skills','nativeAttributesV1','rosterProfile','worldProfile','lnrProfile','skillBase'];
  const levels=['note','roleNote','overall','quality','level','currentAbility','seasonStart','seasonEnd','startRating','endRating','ratingBefore','ratingAfter'];
  const ceilings=['potential','potentialAtRole','ceiling','potentialRating','potentialNote','potentialBefore','potentialAfter'];
  // Listes figées une fois par projection (même ordre, même contenu qu'avant).
  const aliasesWithLevels=['rating',...levels,...ceilings,'attributesV2','positionRatings'];
  const aliasesWithoutLevels=['rating',...levels.filter(k=>!['level','quality'].includes(k)),...ceilings,'attributesV2','positionRatings'];
  const ceilingSet=new Set(ceilings),levelSet=new Set(levels),boundKeys=new Set(['noteMin','noteMax','potentialMin','potentialMax']);
  function visit(value,person=null){
   if(Array.isArray(value)){for(const row of value)visit(row,person);return;}
   if(!object(value))return;
   const pid=typeof value.playerId==='string'&&Object.hasOwn(visible,value.playerId)?value.playerId:typeof value.id==='string'&&Object.hasOwn(visible,value.id)?value.id:null;
   const unknownId=typeof value.playerId==='string'?value.playerId:value.id;
   const aliases=typeof value.playerId==='string'||typeof value.pos==='string'?aliasesWithLevels:aliasesWithoutLevels;
   const hasPlayerData=aliases.some(k=>Object.hasOwn(value,k))||typeof value.name==='string'&&typeof value.pos==='string';
   const looksLikePlayer=!pid&&id(unknownId)&&(typeof value.playerId==='string'||typeof value.pos==='string'||typeof value.name==='string')&&aliases.some(k=>Object.hasOwn(value,k));
   const ownPerson=pid?visible[pid]:looksLikePlayer?{rating:null,ratingRange:null,potential:null,potentialRange:null,knowledge:{version:VERSION,owned:false,stage:'unobserved',observedAt:null}}:person;
   if(pid&&hasPlayerData||looksLikePlayer){
    Object.assign(value,copy(ownPerson));
    for(const k of levels)if(Object.hasOwn(value,k)&&!ownPerson.knowledge.owned)value[k]=null;
    if(!ownPerson.knowledge.owned){if(Object.hasOwn(value,'positionRatings'))value.positionRatings={};for(const k of ['_familyNotes','positionNotes'])if(Object.hasOwn(value,k))value[k]={};}
    if(!ownPerson.knowledge.owned&&ownPerson.knowledge.stage!=='deep')for(const k of attrs)if(Object.hasOwn(value,k))value[k]=k==='skillBase'?null:{};
    if(value.assessment){
     const fmt=r=>r?r.min+'–'+r.max+' / 100':'inconnu';
     value.assessment.observed=(value.assessment.observed||[]).filter(x=>!/^Niveau(?: au poste(?: relevé)?)?\s*:/.test(x));
     value.assessment.observed.push('Niveau : '+(ownPerson.knowledge.owned?ownPerson.rating+' / 100':fmt(ownPerson.ratingRange))+'.');
     value.assessment.estimates=(value.assessment.estimates||[]).filter(x=>!/^Potentiel/.test(x));value.assessment.estimates.unshift('Potentiel : '+fmt(ownPerson.potentialRange)+'.');
    }
   }
   if(ownPerson&&!ownPerson.knowledge.owned){
    for(const key of ['positionRatings','positionNotes','_familyNotes','roleRatings'])if(Object.hasOwn(value,key))value[key]={};
    if(ownPerson.knowledge.stage!=='deep')for(const key of attrs)if(Object.hasOwn(value,key))value[key]=key==='skillBase'?null:{};
   }
   for(const [key,child]of Object.entries(value)){
    if(key==='knowledge'||key==='ratingRange'||key==='potentialRange')continue;
    if(ceilingSet.has(key)){value[key]=null;continue;}
    if(ownPerson&&boundKeys.has(key)){value[key]=key==='noteMin'?ownPerson.ratingRange?.min??null:key==='noteMax'?ownPerson.ratingRange?.max??null:key==='potentialMin'?ownPerson.potentialRange?.min??null:ownPerson.potentialRange?.max??null;continue;}
    if(ownPerson&&!ownPerson.knowledge.owned&&(levelSet.has(key)||key==='rating')){value[key]=null;continue;}
    if(ownPerson&&key==='evidence'&&object(child)){
     child.seen=ownPerson.knowledge.stage!=='unobserved';child.noteMin=ownPerson.ratingRange?.min??null;child.noteMax=ownPerson.ratingRange?.max??null;child.potentialMin=ownPerson.potentialRange?.min??null;child.potentialMax=ownPerson.potentialRange?.max??null;
     child.label=child.seen?'Observé':'Non observé';
    }
    visit(child,ownPerson);
   }
  }
  visit(model);return model;
 }
 return {VERSION,LIMIT,hash,interval,players,validate,before,observe,captureMatch,visibility,project,scouting,plan,advanceJobs,installHooks,reports};
}
module.exports={factory};
