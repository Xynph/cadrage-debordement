'use strict';
const crypto=require('node:crypto');
const profiles=require('./profiles.json'),KEYS=profiles.attributeKeys;
const clone=x=>JSON.parse(JSON.stringify(x)),hash=x=>crypto.createHash('sha256').update(typeof x==='string'||Buffer.isBuffer(x)?x:JSON.stringify(x)).digest('hex');
const mean=a=>a.reduce((n,v)=>n+v,0)/a.length,round=n=>Math.round(n*100)/100,clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
const normalize=s=>String(s).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().replace(/[^a-z0-9]+/g,' ').trim();
const ROLES={
 'Pilier gauche':['scrumTechnique','strength','ruckClearout','maul','tackling'],
 'Pilier droit':['scrumTechnique','strength','ruckClearout','maul','tackling'],
 'Talonneur':['hooking','lineoutThrow','tackling','maul','ruckClearout'],
 'Deuxième ligne':['lineoutJump','lineoutLift','maul','ruckClearout','strength'],
 'Troisième ligne':['jackal','tackling','ruckClearout','workRate','ballCarry'],
 'Numéro 8':['ballCarry','strength','tackling','jackal','workRate'],
 'Demi de mêlée':['passing','decisions','vision','kickAccuracy','workRate'],
 'Demi d’ouverture':['kickAccuracy','passing','decisions','vision','kickDistance'],
 'Centre':['tackling','ballCarry','passing','offload','decisions'],
 'Ailier':['topSpeed','acceleration','evasion','receiving','kickChase'],
 'Arrière':['aerialAbility','receiving','positioning','kickDistance','decisions']};
const PHYSICAL=new Set(['acceleration','topSpeed','agility','explosiveness','strength','endurance','jumping']);
const QUICK=new Set(['acceleration','topSpeed','agility','explosiveness','jumping']);
const MENTAL=new Set(KEYS.slice(12,21));
const PROJECTION={scrum:{scrumTechnique:.65,hooking:.15,strength:.2},lineout:{lineoutThrow:.2,lineoutJump:.25,lineoutLift:.2,jumping:.2,aerialAbility:.15},tackle:{tackling:.7,jackal:.15,positioning:.15},speed:{topSpeed:.4,acceleration:.25,agility:.15,evasion:.1,kickChase:.1},pass:{passing:.6,receiving:.15,offload:.1,ballHandling:.15},kick:{kickDistance:.45,kickAccuracy:.45,vision:.1},goal:{goalAccuracy:.9,composure:.1},mental:{decisions:.35,anticipation:.15,vision:.15,composure:.15,teamwork:.15,leadership:.05},discipline:{discipline:1},stamina:{endurance:.8,workRate:.2},power:{strength:.4,explosiveness:.2,ballCarry:.2,ruckClearout:.1,maul:.1}};
function project(p){const a=p.attributesV2,w={...PROJECTION};if(p.gameplayPosition==='Talonneur')w.lineout={lineoutThrow:.65,ballHandling:.1,decisions:.05,lineoutJump:.05,lineoutLift:.05,jumping:.05,aerialAbility:.05};if(p.gameplayPosition==='Deuxième ligne')w.lineout={lineoutJump:.4,lineoutLift:.2,jumping:.2,aerialAbility:.15,lineoutThrow:.05};return Object.fromEntries(Object.entries(w).map(([k,v])=>[k,round(Object.entries(v).reduce((n,[key,weight])=>n+a[key]*weight,0))]));}
function rawAbility(a,role){const primary=new Set(ROLES[role]);return round(KEYS.reduce((n,k)=>n+a[k]*(primary.has(k)?5:profiles.roles[role][k]>=75?1:.15),0)/KEYS.reduce((n,k)=>n+(primary.has(k)?5:profiles.roles[role][k]>=75?1:.15),0));}
function ability(a,role){return rawAbility(a,role);}
function validate(master){if(!Array.isArray(master.players)||master.players.length!==1592)throw Error('Expected 1592 players');const ids=new Set();for(const p of master.players){if(!p.id||ids.has(p.id))throw Error('Invalid duplicate ID');ids.add(p.id);if(!ROLES[p.gameplayPosition]||!['top14','prod2'].includes(p.league)||!Number.isFinite(p.ageApprox))throw Error('Invalid position/league/age');if(Object.keys(p.attributesV2||{}).sort().join()!==[...KEYS].sort().join()||KEYS.some(k=>!Number.isFinite(p.attributesV2[k])||p.attributesV2[k]<20||p.attributesV2[k]>97))throw Error('Invalid attributes');if(Object.keys(p.hiddenTraitsV2||{}).length!==6||!Number.isFinite(p.potential))throw Error('Invalid traits/potential');}}
function buildEvidence(master,central,extra,careers=null){
 validate(master);if(central.schema!=='rugby-real-public-2025-26-v11'||extra.schema!=='rugby-real-v12-extra-observations')throw Error('Invalid evidence schema');
 const names=new Map();for(const p of master.players){const n=normalize(p.realName);if(!names.has(n))names.set(n,[]);names.get(n).push(p);}
 const byId=new Map(master.players.map(p=>[p.id,{records:[],kicking:null,kickingRecords:[],honours:[],assessments:[],observations:[],history:[]}])),unmatched=new Set(),ambiguous=new Set();let rows=0;
 function matched(name,lnrId=null){const ps=names.get(normalize(name))||[];if(ps.length===0){unmatched.add(name);return null;}if(ps.length>1){ambiguous.add(name);return null;}if(lnrId!==null&&ps[0].id!=='lnr:'+String(lnrId))throw Error('Observed identity ID mismatch');return byId.get(ps[0].id);}
 function add(name,stats,scope,url,lnrId=null){if(!scope||!url?.startsWith('https://')||Object.values(stats).some(v=>v!==null&&(!Number.isFinite(v)||v<0)))throw Error('Invalid observed stat');rows++;const e=matched(name,lnrId);if(e)e.records.push({stats,scope,sourceUrl:url});}
 for(const l of central.lists){if(l.season!=='2025-2026'||!l.sourceUrl.endsWith('/2025-2026'))throw Error('Invalid season');for(const r of l.ranking)add(r.name,r.stats,'ranking:'+l.metric,l.sourceUrl,r.lnrId);}
 for(const r of central.careerSeasonRows){if(r.season!=='2025-2026'||!['TOP 14','PRO D2'].includes(r.competition))throw Error('Invalid career season');add(r.name,r.stats,'career-season',r.sourceUrl);}
 for(const r of central.observations){if(r.season!=='2025-2026'||r.scope!=='after-13-rounds'||r.asOf>'2026-06-30'||!r.sourceUrl.startsWith('https://dicodusport.fr/blog/')||Object.values(r.stats).some(v=>!Number.isFinite(v)||v<0))throw Error('Invalid partial season');const e=matched(r.name);rows++;if(e)e.observations.push(clone(r));}
 for(const p of master.players)if(p.performance2025_2026){const s=p.performance2025_2026;if(s.season!=='2025-2026')throw Error('Invalid baseline evidence season');const {matches,minutes,tries,points}=s;add(p.realName,{matches,minutes,tries,points},'master-prior-season','https://github.com/Xynph/cadrage-debordement/blob/512e296467985d95284e1c3c3959b23e569019d2/modding/data06/rugby-master-2026-2027.json');}
 const num=x=>Number(String(x).replace(/[\s\u00a0\u202f]/g,'').replace(',','.'));
 for(const l of extra.lists){if(l.season!=='2025-2026'||!/^https:\/\/(top14|prod2)\.lnr\.fr\/classement\/joueurs\/meilleurs-taux-de-transformation\/2025-2026$/.test(l.sourceUrl))throw Error('Invalid kicking season');for(const r of l.rows){rows++;const o=r.observed,attempted=num(o.nbConversionAttempted),made=num(o.nbConversionMade),missed=num(o.nbConversionMissed),rate=num(o.nbConversionMadeRate);if(!Number.isInteger(attempted)||!Number.isInteger(made)||!Number.isInteger(missed)||attempted<=0||made<0||missed<0||made+missed!==attempted||Math.abs(rate-made/attempted*100)>.15)throw Error('Invalid observed kicking denominator');const e=matched(r.name,r.lnrId);if(e){if(e.kickingRecords.some(x=>x.league===l.league&&(x.made!==made||x.attempted!==attempted)))throw Error('Conflicting kicking observations in same competition');e.kickingRecords.push({league:l.league,attempted,made,missed,rate,sourceUrl:l.sourceUrl});}}}
 for(const h of extra.honours){if(h.season!=='2025-2026'||h.scope!=='retrospective-season-assessment'||!h.sourceUrl.startsWith('https://top14.lnr.fr/actualite/'))throw Error('Invalid honours scope');rows++;const e=matched(h.name);if(e)e.honours.push(clone(h));}
 for(const a of extra.performanceAssessments||[]){if(a.season!=='2025-2026'||a.scope!=='six-nations-2026-five-rounds'||!a.sourceUrl.startsWith('https://www.sixnationsrugby.com/en/m6n/news/')||!Number.isFinite(a.observedPerformanceRating)||a.observedPerformanceRating<0||a.observedPerformanceRating>10)throw Error('Invalid performance assessment');const e=matched(a.name);rows++;if(e)e.assessments.push(clone(a));}
 if(careers){
  if(careers.schema!=='rugby-real-v12-public-careers'||careers.completed!==true||careers.attempted!==1592||careers.records.length!==1592)throw Error('Incomplete career collection');
  const seen=new Set(),players=new Map(master.players.map(p=>[p.id,p]));
  for(const record of careers.records){const p=players.get(record.playerId);if(!p||seen.has(p.id)||normalize(p.realName)!==normalize(record.name)||!new RegExp('^https://(top14|prod2)\\.lnr\\.fr/joueur/'+p.id.split(':').at(-1)+'-[a-z0-9-]+$').test(record.sourceUrl))throw Error('Career identity/source mismatch');seen.add(p.id);
   if(!['observed','unknown'].includes(record.status)||record.status==='unknown'&&record.seasons.length)throw Error('Invalid career availability');
   for(const season of record.seasons){if(!['2023-2024','2024-2025','2025-2026'].includes(season.season)||!['TOP 14','PRO D2'].includes(season.competition)||Object.values(season.stats).some(v=>!Number.isFinite(v)||v<0))throw Error('Invalid career period/stats');
    const s=season.stats,stats=Object.fromEntries(Object.entries({matches:s.matchesPlayed,minutes:s.minutesPlayed,points:s.points,tries:s.tries,yellowCards:s.yellowCards,redCards:s.redCards,orangeCards:s.orangeCards}).filter(([,v])=>v!==undefined));
    const entry={season:season.season,competition:season.competition,historicalClub:season.historicalClub,stats,sourceUrl:record.sourceUrl};byId.get(p.id).history.push(entry);
    if(season.season==='2025-2026')add(p.realName,stats,'career-season',record.sourceUrl);
   }
  }
 }
 for(const e of byId.values()){
  e.kicking=e.kickingRecords.sort((a,b)=>b.attempted-a.attempted||a.league.localeCompare(b.league))[0]||null;
  // Select ONE exposure total; never sum overlapping rankings, career rows, or partials.
  const priority=r=>r.scope==='career-season'?0:r.scope==='ranking:temps-de-jeu'?1:r.scope==='master-prior-season'?2:3;
  e.records.sort((a,b)=>priority(a)-priority(b)||(b.stats.minutes??-1)-(a.stats.minutes??-1)||a.sourceUrl.localeCompare(b.sourceUrl));
  e.usage=e.records.find(r=>Number.isFinite(r.stats.minutes)&&Number.isFinite(r.stats.matches))||null;
  e.attack=e.records.find(r=>Number.isFinite(r.stats.tries)&&Number.isFinite(r.stats.minutes)&&r.stats.minutes>=400)||null;
  e.cards=e.records.find(r=>r.scope==='ranking:nombre-de-cartons'&&r.stats.minutes>=400)||null;
  e.scopes=e.records.length+e.observations.length+Number(!!e.kicking)+e.honours.length+e.assessments.length+Number(e.history.some(x=>x.season!=='2025-2026'));
 }
 return {byId,summary:{careerAttempted:careers?.attempted||0,careerPlayers202526:careers?.records.filter(r=>r.seasons.some(s=>s.season==='2025-2026')).length||0,careerPlayers3Seasons:careers?.records.filter(r=>r.seasons.length).length||0,sourceRows:rows,strictMatched:[...byId.values()].filter(e=>e.scopes>0).length,kicking:[...byId.values()].filter(e=>e.kicking).length,honours:[...byId.values()].filter(e=>e.honours.length).length,unmatched:[...unmatched].sort(),ambiguous:[...ambiguous].sort()}};
}
const NORMS={'Pilier gauche':[115,184],'Pilier droit':[120,185],'Talonneur':[108,182],'Deuxième ligne':[115,199],'Troisième ligne':[105,190],'Numéro 8':[112,191],'Demi de mêlée':[84,177],'Demi d’ouverture':[88,182],'Centre':[96,186],'Ailier':[89,183],'Arrière':[88,183]};
function features(p,key){const [mass,height]=NORMS[p.gameplayPosition],physical=PHYSICAL.has(key)||['aerialAbility','lineoutJump','lineoutLift'].includes(key);return [1,Math.max(0,23-p.ageApprox)/8,Math.max(0,p.ageApprox-29)/10,physical&&p.weightKg!==null?clamp((p.weightKg-mass)/20,-2,2):0,physical&&p.heightCm!==null?clamp((p.heightCm-height)/20,-2,2):0];}
function fit(ps,key){const n=5,a=Array.from({length:n},()=>Array(n+1).fill(0));for(const p of ps){const x=features(p,key);for(let i=0;i<n;i++){for(let j=0;j<n;j++)a[i][j]+=x[i]*x[j];a[i][n]+=x[i]*p.attributesV2[key];}}for(let i=1;i<n;i++)a[i][i]+=4;for(let k=0;k<n;k++){let pivot=k;for(let i=k+1;i<n;i++)if(Math.abs(a[i][k])>Math.abs(a[pivot][k]))pivot=i;[a[k],a[pivot]]=[a[pivot],a[k]];if(Math.abs(a[k][k])<1e-9)throw Error('Singular prior fit');const d=a[k][k];for(let j=k;j<=n;j++)a[k][j]/=d;for(let i=0;i<n;i++)if(i!==k){const f=a[i][k];for(let j=k;j<=n;j++)a[i][j]-=f*a[k][j];}}return a.map(r=>r[n]);}
function maturity(p,k){const age=p.ageApprox;if(QUICK.has(k))return -Math.max(0,20-age)*.7-Math.max(0,age-28)*.65;if(k==='strength')return -Math.max(0,23-age)*.9-Math.max(0,age-33)*.35;if(k==='endurance')return -Math.max(0,21-age)*.5-Math.max(0,age-31)*.5;if(MENTAL.has(k)&&k!=='discipline')return -Math.min(4,Math.max(0,24-age)*.45);return -Math.max(0,21-age)*.2-Math.max(0,age-35)*.15;}
function physicalPrior(p,k){const [mass,height]=NORMS[p.gameplayPosition];if(k==='strength'&&p.weightKg!==null)return clamp((p.weightKg-mass)/20,-1.5,1.5);if(['lineoutJump','aerialAbility'].includes(k)&&p.heightCm!==null)return clamp((p.heightCm-height)/20,-1.5,1.5);return 0;}
function statEffects(p,e){const a={};const add=(k,v)=>a[k]=(a[k]||0)+v;
 if(e.usage){const {minutes}=e.usage.stats;const usage=clamp((minutes-900)/900,0,1);add('workRate',usage*1.25);}
 const regularHistory=e.history.filter(h=>h.season!=='2025-2026'&&h.stats.minutes>=1200).length;if(regularHistory){add('workRate',Math.min(.75,regularHistory*.4));add('decisions',Math.min(.5,regularHistory*.25));}
 if(e.attack){const s=e.attack.stats,rate=s.tries*80/s.minutes,reliability=s.minutes/(s.minutes+800),impact=clamp((rate-.15)*5,0,2)*reliability;add('ballCarry',impact);add('positioning',impact*.6);}
 for(const o of e.observations){if(o.stats.tacklesMade&&o.stats.matches){add('tackling',Math.min(2,o.stats.tacklesMade/o.stats.matches/8));}if(o.stats.offloads)add('offload',Math.min(1.5,o.stats.offloads/15));if(o.stats.defendersBeaten)add('evasion',Math.min(1.5,o.stats.defendersBeaten/30));}
 // Cards are risk exposure, not tackles, injury propensity, or mentality. At most one point.
 if(e.cards){const s=e.cards.stats,rate=((s.yellowCards||0)+(s.redCards||0))*80/s.minutes;add('discipline',-clamp((rate-.06)*4,0,1));}
 // Official season honours are handled as one corroborating ability anchor below, never stacked.
 return a;
}
function review(master,central,extra,careers=null){
 validate(master);const evidence=buildEvidence(master,central,extra,careers),ordered=[...master.players].sort((a,b)=>a.id.localeCompare(b.id)),fits=new Map();
 for(const role of Object.keys(ROLES))for(const league of ['top14','prod2']){const group=ordered.filter(p=>p.gameplayPosition===role&&p.league===league);for(const key of KEYS)fits.set(role+'|'+league+'|'+key,fit(group,key));}
 const rows=[],changesByAttribute=Object.fromEntries(KEYS.map(k=>[k,0]));let changed=0,potentialScaleFlags=0;
 for(const p of ordered){const role=p.gameplayPosition,prior=profiles.roles[role],e=evidence.byId.get(p.id),effects=statEffects(p,e),attrs={},basis=[];
  for(const k of KEYS){const coef=fits.get(role+'|'+p.league+'|'+k),x=features(p,k),oldExpected=coef.reduce((n,b,i)=>n+b*x[i],0),residual=clamp(p.attributesV2[k]-oldExpected,-15,15)*.35;
   const leagueWeight=k==='discipline'||k==='leadership'?.15:prior[k]<=40?.25:PHYSICAL.has(k)?.75:MENTAL.has(k)?.7:1;
   let value=prior[k]-(p.league==='prod2'?9*leagueWeight:0)+residual+maturity(p,k)+physicalPrior(p,k)+(effects[k]||0);
   if(k==='goalAccuracy'&&e.kicking){const o=e.kicking,posterior=(o.made+25*.78)/(o.attempted+25),target=50+45*posterior,weight=clamp(o.attempted/(o.attempted+15),.25,.85);value=value*(1-weight)+target*weight;}
   attrs[k]=Math.round(clamp(value,20,97));if(attrs[k]!==p.attributesV2[k]){changed++;changesByAttribute[k]++;}
  }
  // Bound contradictory physical estimates without manufacturing observed measurements.
  if(Math.abs(attrs.acceleration-attrs.topSpeed)>15){if(attrs.acceleration>attrs.topSpeed)attrs.acceleration=attrs.topSpeed+15;else attrs.topSpeed=attrs.acceleration+15;basis.push('speed-acceleration-coherence');}
  const targets=e.honours.map(h=>h.type.includes('breakthrough')?81:h.type.includes('prod2')?83:h.type.includes('international')?89:88);for(const a of e.assessments)targets.push(83+(a.observedPerformanceRating-7)*4);
  if(targets.length){const target=Math.max(...targets),initial=ability(attrs,role),eligible=KEYS.filter(k=>!PHYSICAL.has(k)&&k!=='discipline'&&k!=='leadership'&&k!=='goalAccuracy'&&prior[k]>=60),original={...attrs};
   for(let pass=0;pass<12&&ability(attrs,role)<target;pass++)for(const k of eligible)if(attrs[k]<Math.min(97,original[k]+12))attrs[k]++;basis.push('bounded-qualitative-performance-anchor-not-measured-attributes');}
  const rating=Math.round(ability(attrs,role)),potentialScaleMismatch=rating>p.potential;if(potentialScaleMismatch)potentialScaleFlags++;
  rows.push({playerId:p.id,role,league:p.league,attributes:KEYS.map(k=>attrs[k]),skills:Object.values(project({...p,attributesV2:attrs})),ratingV12:rating,legacyRoleAbility:ability(p.attributesV2,role),legacyRating:p.rating,evidenceRecordCount:e.scopes,quality:e.scopes?'evidence-informed-gameplay-estimate':'gameplay-estimate',flags:[...(p.gameplayPositionEstimated?['position-estimated']:[]),...(potentialScaleMismatch?['legacy-potential-scale-differs-from-role-ability']:[]),...basis],domainEvidence:{exposure:!!e.usage,attack:!!e.attack,kicking:!!e.kicking,defence:e.observations.some(x=>x.stats.tacklesMade),honours:e.honours.length,performanceAssessments:e.assessments.length}});
 }
 changed=0;for(const k of KEYS)changesByAttribute[k]=0;const sourceMap=new Map(master.players.map(p=>[p.id,p]));for(const r of rows)for(let i=0;i<36;i++)if(r.attributes[i]!==sourceMap.get(r.playerId).attributesV2[KEYS[i]]){changed++;changesByAttribute[KEYS[i]]++;}
 const byId=new Map(rows.map(r=>[r.playerId,r])),groups={};for(const role of Object.keys(ROLES)){const buckets={};for(const league of ['top14','prod2']){const ps=master.players.filter(p=>p.gameplayPosition===role&&p.league===league);buckets[league]={count:ps.length,before:round(mean(ps.map(p=>ability(p.attributesV2,role)))),after:round(mean(ps.map(p=>byId.get(p.id).ratingV12)))};}groups[role]={...buckets,gapBefore:round(buckets.top14.before-buckets.prod2.before),gapAfter:round(buckets.top14.after-buckets.prod2.after)};}
 return {schema:'rugby-real-v12-full-review',baselineHash:hash(master),evidenceHash:hash({central,extra,careers}),asOf:'2026-07-01',knowledgeDate:'2026-11-07',attributeKeys:KEYS,skillKeys:Object.keys(PROJECTION),method:{usesNameOrIdNoise:false,inheritsUnverifiedLegacyResidual:true,legacyResidualWeight:.35,stacksPreviousCandidates:false,age:'Old role/cohort age and measured-size effects residualized with ridge fit; new positional maturity applied once',allNotesAreGameplayEstimates:true,legacyPotentialPreserved:true},summary:{players:1592,reviewedAttributes:1592*36,changedAttributes:changed,changesByAttribute,potentialScaleFlags,evidence:evidence.summary},groups,rows};
}
function apply(master,report){
 validate(master);
 if(report.schema!=='rugby-real-v12-full-review'||report.baselineHash!==hash(master))throw Error('Candidate baseline mismatch');
 if(JSON.stringify(report.attributeKeys)!==JSON.stringify(KEYS)||JSON.stringify(report.skillKeys)!==JSON.stringify(Object.keys(PROJECTION)))throw Error('Invalid candidate key order');
 const out=clone(master),rows=new Map(report.rows.map(r=>[r.playerId,r]));
 if(rows.size!==1592||report.rows.length!==1592)throw Error('Incomplete/duplicate review');
 for(const p of out.players){const r=rows.get(p.id);
  if(!r||r.role!==p.gameplayPosition||r.league!==p.league||!Array.isArray(r.attributes)||r.attributes.length!==36||r.attributes.some(v=>!Number.isInteger(v)||v<20||v>97)||!Array.isArray(r.skills)||r.skills.length!==11||r.skills.some(v=>!Number.isFinite(v)||v<20||v>97)||!Number.isInteger(r.ratingV12))throw Error('Invalid candidate review');
  const attrs=Object.fromEntries(KEYS.map((k,i)=>[k,r.attributes[i]])),skills=project({...p,attributesV2:attrs});
  if(JSON.stringify(Object.values(skills))!==JSON.stringify(r.skills)||Math.round(ability(attrs,r.role))!==r.ratingV12)throw Error('Candidate derived ratings mismatch');
  p.attributesV2=attrs;p.skills=skills;p.ratingV12=r.ratingV12;
 }
 return out;
}
module.exports={KEYS,ROLES,PROJECTION,review,apply,buildEvidence,project,ability,validate,clone,hash,mean,round,normalize,maturity};
