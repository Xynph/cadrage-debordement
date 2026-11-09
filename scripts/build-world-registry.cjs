'use strict';
// Pure offline compiler. Real identities and media stay in the private overlay.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const ROOT=path.resolve(__dirname,'..'),DIR=path.join(ROOT,'data/world'),TARGET=path.join(ROOT,'native/engine/world-registry.json');
const EDITION='rugby-world-2026-11-08-v1',SNAPSHOT='2026-11-08';
const clone=x=>JSON.parse(JSON.stringify(x)),sha=x=>crypto.createHash('sha256').update(x).digest('hex');
const clamp=(x,a,b)=>Math.max(a,Math.min(b,x)),round=x=>Math.round(x*100)/100;
const ATTR=['passing','receiving','offload','tackling','jackal','ruckClearout','ballCarry','evasion','kickDistance','kickAccuracy','goalAccuracy','ballHandling','decisions','anticipation','vision','positioning','composure','discipline','teamwork','leadership','workRate','acceleration','topSpeed','agility','explosiveness','strength','endurance','jumping','scrumTechnique','hooking','lineoutThrow','lineoutJump','lineoutLift','maul','kickChase','aerialAbility'];
const FAMILIES={'Pilier gauche':0,'Pilier droit':0,'Talonneur':1,'Deuxième ligne':2,'Troisième ligne':3,'Numéro 8':3,'Demi de mêlée':4,'Demi d’ouverture':5,'Ailier':6,'Centre':7,'Arrière':8};
const PROJECTION={scrum:{scrumTechnique:.65,hooking:.15,strength:.2},lineout:{lineoutThrow:.2,lineoutJump:.25,lineoutLift:.2,jumping:.2,aerialAbility:.15},tackle:{tackling:.7,jackal:.15,positioning:.15},speed:{topSpeed:.4,acceleration:.25,agility:.15,evasion:.1,kickChase:.1},pass:{passing:.6,receiving:.15,offload:.1,ballHandling:.15},kick:{kickDistance:.45,kickAccuracy:.45,vision:.1},goal:{goalAccuracy:.9,composure:.1},mental:{decisions:.35,anticipation:.15,vision:.15,composure:.15,teamwork:.15,leadership:.05},discipline:{discipline:1},stamina:{endurance:.8,workRate:.2},power:{strength:.4,explosiveness:.2,ballCarry:.2,ruckClearout:.1,maul:.1}};
const WEIGHTS=[{scrum:5,power:3,tackle:1,discipline:1},{lineout:4,scrum:3,tackle:2,pass:1},{lineout:4,power:2,tackle:3,scrum:1},{tackle:4,stamina:2,power:2,pass:1,speed:1},{pass:4,kick:2,mental:2,speed:2},{pass:3,kick:3,mental:2,goal:2},{speed:5,pass:2,power:2,mental:1},{tackle:3,pass:3,power:2,speed:2},{kick:3,speed:3,mental:2,tackle:2}];
const TRAITS=['professionalism','consistency','bigMatches','injuryResistance','ambition','adaptability'];
function hash(s){let h=2166136261;for(const c of String(s)){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}return h>>>0;}
function median(xs){const a=xs.toSorted((x,y)=>x-y);return a.length?a[Math.floor((a.length-1)/2)]:null;}
function weighted(values,weights){return Object.entries(weights).reduce((s,[k,w])=>s+values[k]*w,0)/Object.values(weights).reduce((s,w)=>s+w,0);}
function projectSkills(a,role){const w={...PROJECTION};if(role==='Talonneur')w.lineout={lineoutThrow:.65,ballHandling:.1,decisions:.05,lineoutJump:.05,lineoutLift:.05,jumping:.05,aerialAbility:.05};if(role==='Deuxième ligne')w.lineout={lineoutJump:.4,lineoutLift:.2,jumping:.2,aerialAbility:.15,lineoutThrow:.05};return Object.fromEntries(Object.entries(w).map(([k,v])=>[k,round(Object.entries(v).reduce((s,[aKey,n])=>s+a[aKey]*n,0))]));}
function normalizeExposure(s={}){const invalid=s.status==='unusable_zero_placeholder';const minutes=!invalid&&Number.isFinite(s.minutes)&&s.minutes>0?s.minutes:null;const matches=!invalid&&Number.isFinite(s.matches)&&s.matches>=0?s.matches:null;return {minutes,matches,per80Allowed:minutes!==null,status:invalid?'unusable_zero_placeholder':minutes===null?'unknown':'usable'};}
function observations(input){const s=input.stats||{},e=normalizeExposure(s),m=s.metrics||{},o={};const known=k=>Number.isFinite(m[k]);
 if(e.per80Allowed)for(const k of ['tries','metres','tackles','turnoversWon','defendersBeaten','cleanBreaks','offloads'])if(known(k))o[k+'Per80']=m[k]*80/e.minutes;
 if(known('carries')&&m.carries>0){for(const k of ['metres','defendersBeaten','offloads'])if(known(k))o[k+'PerCarry']=m[k]/m.carries;}
 if(known('tackleSuccess')&&m.tackleSuccess>=0&&m.tackleSuccess<=1&&known('tackles')&&m.tackles>0)o.tackleSuccess=m.tackleSuccess;
 if(known('goalSuccess')&&m.goalSuccess>0&&m.goalSuccess<=1)o.goalSuccess=m.goalSuccess;
 return {values:o,exposure:e,events:Math.max(m.carries||0,m.tackles||0)};
}
function buildReference(common){const all=common.clubs.flatMap(c=>c.players),groups={};for(const role of Object.keys(FAMILIES)){let ps=all.filter(p=>(p.gameplayPosition||p.pos)===role);if(!ps.length)ps=all.filter(p=>p.fam===FAMILIES[role]);const med=keys=>Object.fromEntries(keys.map(k=>[k,median(ps.map(p=>p.attributesV2[k]))]));groups[role]={players:ps,attributes:med(ATTR),rating:median(ps.map(p=>p.rating)),age:median(ps.map(p=>p.age)),offset:median(ps.map(p=>p.rating-weighted(p.skills,WEIGHTS[p.fam]))),traitMedians:Object.fromEntries(TRAITS.map(k=>[k,median(ps.map(p=>p.hiddenTraitsV2[k]))]))};}return groups;}
function percentileScore(value,values){const a=values.filter(Number.isFinite);if(a.length<8)return 0;const lower=a.filter(x=>x<value).length,equal=a.filter(x=>x===value).length;return clamp(((lower+equal*.5)/a.length-.5)*2,-.9,.9);}
function calibrate(input,reference,population,policy){const role=input.position.primary,ref=reference[role];if(!ref)throw Error('Poste mondial invalide.');const age=input.age.value,ageBand=x=>x<=20?0:x<=24?1:x<=29?2:3,cohort=ref.players.filter(p=>ageBand(p.age)===ageBand(age));const prior=cohort.length>=8?Object.fromEntries(ATTR.map(k=>[k,median(cohort.map(p=>p.attributesV2[k]))])):ref.attributes;
 const obs=observations(input),peers=population.filter(p=>p.position.primary===role).map(observations),scores={};for(const [k,v] of Object.entries(obs.values))scores[k]=percentileScore(v,peers.map(x=>x.values[k]));
 const mean=keys=>{const a=keys.filter(k=>Object.hasOwn(scores,k)).map(k=>scores[k]);return a.length?a.reduce((s,x)=>s+x,0)/a.length:0;};
 const exposureWeight=obs.exposure.per80Allowed?obs.exposure.minutes/(obs.exposure.minutes+policy.exposurePriorMinutes):obs.events/(obs.events+policy.actionPriorEvents);
 const attack=mean(['triesPer80','metresPer80','defendersBeatenPer80','cleanBreaksPer80','metresPerCarry','defendersBeatenPerCarry','offloadsPerCarry']),defence=mean(['tacklesPer80','turnoversWonPer80','tackleSuccess']),kicking=mean(['goalSuccess']);
 const a={};for(const k of ATTR){let delta=0;if(['passing','receiving','offload','ballCarry','evasion','ballHandling','acceleration','topSpeed','agility','explosiveness','kickChase','aerialAbility'].includes(k))delta+=attack*policy.maximumAxisAdjustment;if(['tackling','jackal','positioning','ruckClearout','discipline','workRate'].includes(k))delta+=defence*policy.maximumAxisAdjustment;if(['goalAccuracy','kickAccuracy','kickDistance'].includes(k))delta+=kicking*policy.maximumAxisAdjustment;const individuality=(hash(input.id+':'+k)%7)-3;a[k]=clamp(Math.round(prior[k]+delta*exposureWeight+individuality),20,97);}
 const skills=projectSkills(a,role),rating=clamp(Math.round(weighted(skills,WEIGHTS[FAMILIES[role]])+ref.offset),35,95);
 const ageRoom=age<=19?12:age<=22?9:age<=25?6:age<=28?3:age<=31?1:0,variation=hash(input.id+':potential')%4,potential=clamp(rating+ageRoom+variation, rating,97);
 const traits=Object.fromEntries(TRAITS.map(k=>[k,clamp(ref.traitMedians[k]+hash(input.id+':'+k)%17-8,30,85)]));
 const confidence=input.age.basis==='estimated'||!Object.keys(obs.values).length?'low':obs.exposure.per80Allowed&&obs.exposure.minutes>=600?'medium':'low';
 const contract=input.contract?.basis==='official'?{...clone(input.contract),rule:'published-club-contract-v1'}:{endSeason:1+hash(input.id+':contract')%3,basis:'estimated',rule:policy.contractRule};
 const contractEnd=contract.endSeason;
 const player={id:input.id,name:input.alias,pos:role,fam:FAMILIES[role],age,birthYear:input.age.birthYear??2026-age,ageEstimated:input.age.basis!=='official',...(input.age.birthDate?{birthDate:input.age.birthDate}:{}),rating,condition:94,injury:0,salary:Math.round(1800+Math.max(0,rating-45)**2*6),contractEnd,skillBase:rating,skills,attributesV2:a,gameplayPosition:role,hiddenTraitsV2:traits,potential,worldRatingsVersion:1,dev:{potential,xp:0,seasonStart:rating,minutes:0,appearances:0,careerMinutes:0,history:[],retireAge:Math.max(age+1,35+hash(input.id+':retire')%5),lastYear:0,decline:0}};
 const metadata={version:1,position:clone(input.position),age:clone(input.age),rosterTier:input.rosterTier??'unknown',rating:{value:rating,basis:'estimated',confidence,rule:policy.id,reference:'unchanged-french-profile-distributions',exposure:obs.exposure,metricsUsed:Object.keys(obs.values),axisWeights:{exposure:round(exposureWeight),attack:round(attack),defence:round(defence),kicking:round(kicking)}},potential:{value:potential,basis:'estimated',confidence,rule:policy.potentialRule,range:[rating,Math.min(97,potential+(confidence==='low'?5:3))]},contract:{...contract,endYear:contract.endYear??2026+contractEnd},sourceRefs:clone(input.sourceRefs||[]),factConflicts:clone(input.factConflicts||[]),financialBasis:'fictional-game-parameter'};
 return {player,metadata};
}
function readJson(name){return JSON.parse(fs.readFileSync(path.join(DIR,name),'utf8').replace(/^\uFEFF/,''));}
function readInputs(){return readJson('foreign-inputs.json');}
const day=s=>typeof s==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(s)&&Number.isFinite(Date.parse(s))&&new Date(s).toISOString().slice(0,10)===s;
const matchWeek=s=>Math.floor((Date.parse(s)+3*86400000)/604800000);
function validateLeagueFixtures(k,rows,knockouts){
 const prem=k==='prem',first=prem?30:40,lastId=prem?39:55,count=lastId-first+1,sourceRef=prem?'prem-202627-rugbyviz-20261108':'urc-202627-matchstats-20261108';
 if(!Array.isArray(rows)||rows.length!==count*9)throw Error('Calendrier initial incomplet : '+k);
 const fields=['id','competitionId','season','round','date','homeId','awayId','phase','scheduleSource','sourceFixtureId','sourceRef'];
 const ids=new Set(),sourceIds=new Set(),weeks=new Set(),pairs=new Set(),rounds=Array.from({length:18},()=>new Set()),home=new Map(),away=new Map();
 for(const x of rows){
  const adjusted=prem&&x?.scheduleSource==='game-adjusted-from-official';
  const validSource=x?.scheduleSource==='official-snapshot'||prem&&x?.scheduleSource==='official-snapshot-provisional'||adjusted&&day(x.sourceDate)&&x.sourceDate!==x.date;
  if(!x||Object.keys(x).length!==fields.length+(adjusted?1:0)||fields.some(f=>!Object.hasOwn(x,f))||x.competitionId!==k||x.season!==2026||x.phase!=='league'||!validSource||x.sourceRef!==sourceRef||!Number.isInteger(x.sourceFixtureId)||typeof x.id!=='string'||!Number.isInteger(x.round)||!rounds[x.round]||!day(x.date)||x.homeId===x.awayId||ids.has(x.id)||sourceIds.has(x.sourceFixtureId))throw Error('Rencontre initiale invalide ou dupliquée : '+k);
  ids.add(x.id);sourceIds.add(x.sourceFixtureId);
  const pair=x.homeId+':'+x.awayId;if(prem&&pairs.has(pair))throw Error('Deux rencontres PREM identiques à domicile.');pairs.add(pair);
  for(const clubId of [x.homeId,x.awayId]){const week=clubId+':'+matchWeek(x.date);if(!Number.isInteger(clubId)||clubId<first||clubId>lastId||rounds[x.round].has(clubId)||weeks.has(week))throw Error('Club ou doublon de journée/semaine invalide : '+k);rounds[x.round].add(clubId);weeks.add(week);}
  home.set(x.homeId,(home.get(x.homeId)||0)+1);away.set(x.awayId,(away.get(x.awayId)||0)+1);
 }
 if(rounds.some(r=>r.size!==count)||home.size!==count||away.size!==count||[...home.values(),...away.values()].some(n=>n!==9))throw Error('Répartition domicile/extérieur incohérente : '+k);
 const last=rows.map(x=>x.date).toSorted().at(-1),windows=prem?[knockouts?.semi,knockouts?.final]:[knockouts?.quarter,knockouts?.semi,knockouts?.final];
 if(!windows.every(day)||!windows.every((d,i)=>d>(i?windows[i-1]:last)))throw Error('Fenêtres éliminatoires invalides : '+k);
}
function validateEpcrFixtures(k,rows,pools){
 const n=k==='champions'?4:3,fields=['id','competitionId','season','phase','round','poolId','date','homeId','awayId','scheduleSource','sourceFixtureId','sourceRef'];
 if(!Array.isArray(pools)||pools.length!==n||pools.some(p=>p.length!==6)||new Set(pools.flat()).size!==n*6||pools.flat().some(id=>!Number.isInteger(id)||id<0||id>=58)||!Array.isArray(rows)||rows.length!==n*12)throw Error('Poules européennes incomplètes : '+k);
 const ids=new Set(),sourceIds=new Set(),pairs=new Set(),entries=new Set(),home=new Map(),away=new Map();
 for(const x of rows){
  if(!x||Object.keys(x).length!==fields.length||fields.some(f=>!Object.hasOwn(x,f))||x.competitionId!==k||x.season!==2026||x.phase!=='league'||!Number.isInteger(x.poolId)||!pools[x.poolId]||!Number.isInteger(x.round)||x.round<0||x.round>3||!day(x.date)||!['official-snapshot','official-snapshot-provisional'].includes(x.scheduleSource)||x.sourceRef!=='epcr-'+k+'-matches-20261108'||typeof x.id!=='string'||!Number.isInteger(x.sourceFixtureId)||x.homeId===x.awayId||ids.has(x.id)||sourceIds.has(x.sourceFixtureId))throw Error('Rencontre européenne invalide ou dupliquée : '+k);
  const pair=[x.homeId,x.awayId].sort((a,b)=>a-b).join(':');if(pairs.has(pair))throw Error('Adversaire européen rencontré deux fois : '+k);pairs.add(pair);
  ids.add(x.id);sourceIds.add(x.sourceFixtureId);
  for(const id of [x.homeId,x.awayId]){const entry=id+':'+x.round;if(!pools[x.poolId].includes(id)||entries.has(entry))throw Error('Club hors poule ou journée européenne dupliquée : '+k);entries.add(entry);}
  home.set(x.homeId,(home.get(x.homeId)||0)+1);away.set(x.awayId,(away.get(x.awayId)||0)+1);
 }
 if(pools.flat().some(id=>home.get(id)!==2||away.get(id)!==2))throw Error('Répartition domicile/extérieur européenne incohérente : '+k);
}
function validateCalendar(world){
 const f=world.initialFixtures,p=world.initialEurope;
 for(const k of ['prem','urc'])validateLeagueFixtures(k,f?.[k],world.initialKnockoutDates?.[k]);
 for(const k of ['champions','challenge'])validateEpcrFixtures(k,f[k],p?.[k]);
 if(new Set([...p.champions.flat(),...p.challenge.flat()]).size!==42)throw Error('Club initial présent dans les deux coupes.');
 const weeks=new Set();for(const x of [...f.prem,...f.urc,...f.champions,...f.challenge])for(const id of [x.homeId,x.awayId]){const entry=id+':'+matchWeek(x.date);if(weeks.has(entry))throw Error('Collision de calendrier domestique/Europe : '+x.id);weeks.add(entry);}
}
function validate(world){if(world.id!==EDITION||world.version!==1||world.clubs.length!==58)throw Error('Édition mondiale invalide.');const ids=new Set(),keys=new Set();for(const [index,c] of world.clubs.entries()){if(c.id!==index||keys.has(c.key)||!['FR','GB','IE','IT','ZA','GE'].includes(c.country))throw Error('Club mondial invalide/dupliqué.');keys.add(c.key);for(const p of c.players){if(typeof p.id!=='string'||ids.has(p.id))throw Error('Identifiant joueur dupliqué.');ids.add(p.id);if(!Object.hasOwn(FAMILIES,p.pos)||p.fam!==FAMILIES[p.pos]||!Number.isInteger(p.age)||p.age<15||p.age>60)throw Error('Profil joueur/poste invalide.');if(!Object.keys(PROJECTION).every(k=>Number.isFinite(p.skills?.[k])&&p.skills[k]>=15&&p.skills[k]<=99)||!ATTR.every(k=>Number.isFinite(p.attributesV2?.[k])&&p.attributesV2[k]>=20&&p.attributesV2[k]<=97))throw Error('Qualité/compétence non finie ou invalide.');if(!Number.isFinite(p.rating)||!Number.isFinite(p.potential)||!p.dev)throw Error('Profil numérique invalide.');}}
 if(ids.size!==world.playerCount)throw Error('Nombre de joueurs incohérent.');validateCalendar(world);return true;}
function build({inputs=readInputs()}={}){const catalogue=readJson('catalogue.json'),policy=readJson('policy.json'),common=require('../dist/rugby-common-rosters.js'),reference=buildReference(common),clubs=clone(catalogue.clubs).map(c=>({...c,players:[]})),old=new Map();for(const c of common.clubs)for(const p of c.players){const copy=clone(p);old.set(p.id,copy);clubs[c.id].players.push(copy);}const byKey=new Map(clubs.map(c=>[c.key,c])),worldProfiles={};
 const salaryPolicy = policy.premStartingSalary;
 if (!salaryPolicy || salaryPolicy.basis !== 'fictional-game-parameter' ||
     typeof salaryPolicy.rule !== 'string' || !salaryPolicy.rule ||
     !Number.isInteger(salaryPolicy.percentage) || salaryPolicy.percentage < 1 || salaryPolicy.percentage > 100) {
  throw Error('Barème salarial initial PREM invalide.');
 }
 const inputIds = new Set();
 for (const input of [...inputs.players].sort((a,b)=>a.id.localeCompare(b.id,'en'))) {
  const club = byKey.get(input.clubKey);
  if (inputIds.has(input.id) || old.has(input.id) || !club) throw Error('Entrée identité dupliquée/inconnue.');
  inputIds.add(input.id);
  const {player, metadata} = calibrate(input, reference, inputs.players, policy);
  if (club.leagueId === 'prem') player.salary = Math.round(player.salary * salaryPolicy.percentage / 100);
  club.players.push(player);
  worldProfiles[player.id] = metadata;
 }
 for(const t of [...(inputs.transfers||[])].sort((a,b)=>a.id.localeCompare(b.id,'en'))){const p=old.get(t.id),target=byKey.get(t.targetClubKey);if(!p||!target||!Array.isArray(t.evidenceRefs)||!t.evidenceRefs.length)throw Error('Transfert mondial non corroboré.');for(const c of clubs)c.players=c.players.filter(q=>q.id!==t.id);target.players.push(p);worldProfiles[p.id]={version:1,reusedFrenchProfile:true,transfer:{targetClubKey:t.targetClubKey,basis:'corroborated-official-sources',evidenceRefs:clone(t.evidenceRefs)}};}
 for(const c of clubs){c.players.sort((a,b)=>a.id.localeCompare(b.id,'en'));if(c.id>=30)c.base=c.players.length?Math.round(c.players.map(p=>p.rating).toSorted((a,b)=>b-a).slice(0,23).reduce((s,x)=>s+x,0)/Math.min(23,c.players.length)):60;}
 const normalized=clone(inputs);normalized.players.sort((a,b)=>a.id.localeCompare(b.id,'en'));normalized.transfers?.sort((a,b)=>a.id.localeCompare(b.id,'en'));
 const ledger=readJson('initial-fixtures.json'),competitions=ledger.competitions;
 const initialFixtures=Object.fromEntries(Object.entries(competitions).map(([k,v])=>[k,clone(v.fixtures)]));
 const initialKnockoutDates={urc:clone(competitions.urc.playoffWindows),prem:clone(competitions.prem.playoffWindows)};
 const fixtureProvenance=Object.fromEntries(Object.entries(competitions).map(([k,v])=>[k,{sourceRef:v.sourceRef,...v.source,dateBasis:v.dateBasis,...(v.playoffWindowBasis?{playoffWindowBasis:v.playoffWindowBasis}:{}),...(v.provisionalFixtureIds?{provisionalFixtureIds:clone(v.provisionalFixtureIds)}:{}),...(v.gameAdjustments?{gameAdjustments:clone(v.gameAdjustments),sourceSameClubWeekCollisions:clone(v.sourceSameClubWeekCollisions)}:{})}]));
 const world={id:EDITION,version:1,marker:{id:EDITION,version:1},snapshot:SNAPSHOT,sourceEncoding:'utf8-lf',calibrationVersion:policy.id,clubCount:58,playerCount:clubs.reduce((s,c)=>s+c.players.length,0),leagues:clone(catalogue.leagues),initialEurope:clone(catalogue.initialEurope),initialFixtures,initialKnockoutDates,clubs,worldProfiles,provenance:{baselineEdition:common.id,baselinePlayersSha256:sha(JSON.stringify(common.clubs.flatMap(c=>c.players).toSorted((a,b)=>a.id.localeCompare(b.id,'en')))),policyVersion:policy.id,initialFixtures:fixtureProvenance,inputHashes:{catalogue:sha(JSON.stringify(catalogue)),policy:sha(JSON.stringify(policy)),foreignInputs:sha(JSON.stringify(normalized)),initialFixtures:sha(JSON.stringify(ledger))}}};
 world.provenance.premStartingSalary = clone(salaryPolicy);
 validate(world);
 return world;
}
function serialize(world){return JSON.stringify(world,null,2)+'\n';}
function write(check=false){const output=serialize(build());if(check){if(fs.readFileSync(TARGET,'utf8').replace(/\r\n/g,'\n')!==output)throw Error('Registre mondial périmé : relancer la compilation.');}else{const temporary=TARGET+'.staged-'+process.pid;fs.writeFileSync(temporary,output,{flag:'wx'});try{const result=require('../native/engine/atomic-replace.cjs').replaceStaged(temporary,TARGET);if(!result.ok)throw Error(result.error);}finally{if(fs.existsSync(temporary))fs.unlinkSync(temporary);}}return output;}
module.exports={build,readInputs,calibrate,projectSkills,normalizeExposure,validate,serialize,write,ATTR,FAMILIES};
if(require.main===module){const text=write(process.argv.includes('--check'));console.log('Registre mondial compilé : '+Buffer.byteLength(text)+' octets, édition '+EDITION+'.');}
