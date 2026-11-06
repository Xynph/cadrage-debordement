'use strict';
// Rugby Reel DATA — tentative gameplay ratings, never official player ratings.
// Standalone by design: no mutation of the game's roster, engine or saves.
const fs = require('node:fs');
const path = require('node:path');

const ATTRIBUTES = Object.freeze(['scrum','lineout','tackle','speed','pass','kick','goal','mental','discipline','stamina','power']);
const PROFILES = Object.freeze({
  '1ère ligne':[18,-8,3,-26,-15,-30,-34,0,0,-5,16],
  '2ème ligne':[10,20,7,-15,-12,-30,-34,1,0,2,13],
  '3ème ligne':[3,5,15,0,-4,-23,-27,4,1,13,9],
  'Demi de mêlée':[-30,-25,-3,9,19,12,2,11,7,9,-20],
  "Demi d'ouverture":[-32,-25,-6,4,18,20,18,14,6,5,-19],
  'Ailier':[-30,-24,-5,22,1,-2,-12,2,1,9,0],
  'Centre':[-19,-19,9,11,10,-9,-17,6,2,8,12],
  'Arrière':[-29,-20,2,15,9,16,10,12,6,7,-7]
});
const ROLE_WEIGHTS = Object.freeze({
  '1ère ligne':{scrum:5,power:3,tackle:1,discipline:1},
  '2ème ligne':{lineout:4,power:2,tackle:3,scrum:1},
  '3ème ligne':{tackle:4,stamina:2,power:2,pass:1,speed:1},
  'Demi de mêlée':{pass:4,kick:2,mental:2,speed:2},
  "Demi d'ouverture":{pass:3,kick:3,mental:2,goal:2},
  'Ailier':{speed:5,pass:2,power:2,mental:1},
  'Centre':{tackle:3,pass:3,power:2,speed:2},
  'Arrière':{kick:3,speed:3,mental:2,tackle:2}
});
const SOURCE_SEASON = '2025-2026';
const SNAPSHOT = '2026-07-01';
const clamp = (v,min,max)=>Math.min(max,Math.max(min,v));
const round = x=>Math.round(x);
function validGroup(group){return Object.prototype.hasOwnProperty.call(PROFILES,group);}
function groupOf(player){return player.position||player.group||player.lnrGroup;}
function gamesAge(player){
  if(Number.isInteger(player.ageAtStart)) return player.ageAtStart;
  if(Number.isInteger(player.birthYear))return 2026-player.birthYear-1; // conservative if month/day unknown
  // Reported ages in an October snapshot are NOT July ages: avoid backdating.
  return null;
}
function stageAge(age){
  if(age===null)return 0;
  if(age<=20)return -4;
  if(age<=22)return -2;
  if(age>=36)return -4;
  if(age>=33)return -2;
  return 0;
}
function baseline(player){
  if(!player||!validGroup(groupOf(player)))throw Error('Invalid or missing LNR position group');
  if(!['top14','prod2'].includes(player.league))throw Error('Unknown league');
  const group=groupOf(player),age=gamesAge(player);
  // League is a contextual prior, never a claim about a named player's quality.
  const base=(player.league==='top14'?74:68)+stageAge(age);
  const v={};
  ATTRIBUTES.forEach((k,i)=>v[k]=clamp(round(base+PROFILES[group][i]*0.72),30,95));
  return {base,group,age,attributes:v};
}
const METRIC_RULES = Object.freeze({
  tackle:{made:'tacklesMade',attempted:'tacklesAttempted',center:0.82,spread:0.16},
  goal:{made:'goalsMade',attempted:'goalsAttempted',center:0.73,spread:0.22},
  discipline:{count:'penaltiesConceded',per80:true,center:0.85,spread:1.0,invert:true},
  stamina:{count:'minutesPlayed',center:1100,spread:1000},
  power:{count:'defendersBeaten',per80:true,center:2.2,spread:3.0},
  pass:{count:'passes',per80:true,center:16,spread:22},
  kick:{count:'kicksInPlay',per80:true,center:5,spread:8},
  lineout:{made:'lineoutsWon',attempted:'lineoutsAttempted',center:0.84,spread:0.20},
  scrum:{made:'scrumsWon',attempted:'scrumsAttempted',center:0.86,spread:0.18}
});
function validateEvidence(e){
  if(!e||typeof e!=='object'||Array.isArray(e))throw Error('Invalid evidence');
  if(e.season!==SOURCE_SEASON||typeof e.url!=='string'||!/^https:\/\//.test(e.url))throw Error('Evidence requires public 2025-26 source');
  if(e.observedThrough && e.observedThrough>SNAPSHOT)throw Error('Future information leakage');
  const m=e.metrics;
  if(!m||typeof m!=='object'||Array.isArray(m))throw Error('Missing metrics');
  for(const [key,value] of Object.entries(m)){
    if(!/^[A-Za-z]+$/.test(key)||typeof value!=='number'||!Number.isFinite(value)||value<0)throw Error('Invalid metric '+key);
  }
  if(m.minutesPlayed!==undefined&&m.minutesPlayed>3500)throw Error('Invalid minutes played');
  return true;
}
function assess(player,evidence=null){
  const prior=baseline(player);
  const values={...prior.attributes},sources={};
  const warnings=[];
  let applied=0;
  if(evidence!==null){
    validateEvidence(evidence);
    const m=evidence.metrics,minutes=m.minutesPlayed;
    if(!(Number.isFinite(minutes)&&minutes>=240)){
      warnings.push('Insufficient 2025-26 minutes (<240): prior retained');
    } else {
      for(const [attribute,rule] of Object.entries(METRIC_RULES)){
        // Position-neutral central values are intentionally weak (max +/- 7).
        // This is a PROTOTYPE. A validated position-specific reference distribution is needed.
        let value;
        if(rule.made){
          if(m[rule.made]===undefined||m[rule.attempted]===undefined||m[rule.attempted]<10)continue;
          if(m[rule.made]>m[rule.attempted])throw Error('Success count exceeds attempts for '+attribute);
          value=m[rule.made]/m[rule.attempted];
        } else if(m[rule.count]!==undefined){
          value=rule.per80?m[rule.count]*80/minutes:m[rule.count];
        } else continue;
        const delta=clamp((value-rule.center)/rule.spread,-1,1)*(rule.invert?-7:7);
        values[attribute]=clamp(round(values[attribute]+delta),30,95);
        sources[attribute]={url:evidence.url,season:evidence.season,metric:rule.made?[rule.made,rule.attempted]:[rule.count],method:'position-neutral-provisional',delta:round(delta)};
        applied++;
      }
    }
  }
  const weights=ROLE_WEIGHTS[prior.group],total=Object.values(weights).reduce((a,b)=>a+b,0);
  const roleRating=round(Object.entries(weights).reduce((s,[k,w])=>s+w*values[k],0)/total);
  return {
    id:player.id,name:player.name,club:player.club,league:player.league,
    group:prior.group,snapshot:SNAPSHOT,attributes:values,roleRating,
    stage:'candidate-not-authorized-for-gameplay',
    evidenceStatus:applied>=4?'partial-individual-metrics':applied?'weak-individual-metrics':'positional-prior-only',
    metricsApplied:applied,confidence:applied>=4?'medium-provisional':'low',
    sources,warnings,
    notes:'Estimated videogame attributes. NOT official ratings, not Rugby 25 data.'
  };
}
function build(players,evidenceById={}){
  if(!Array.isArray(players))throw Error('Players must be an array');
  if(!evidenceById||typeof evidenceById!=='object'||Array.isArray(evidenceById))throw Error('Invalid evidence map');
  const seen=new Set();
  const ratings=players.map(p=>{
    if(typeof p.id!=='string'||!/^lnr:\d+$/.test(p.id)||seen.has(p.id))throw Error('Duplicate/invalid LNR ID');
    seen.add(p.id);return assess(p,evidenceById[p.id]??null);
  });
  for(const id of Object.keys(evidenceById))if(!seen.has(id))throw Error('Evidence for unknown player '+id);
  const quality={
    total:ratings.length,
    priorOnly:ratings.filter(r=>r.evidenceStatus==='positional-prior-only').length,
    withIndividualMetrics:ratings.filter(r=>r.metricsApplied>0).length,
    mediumProvisional:ratings.filter(r=>r.confidence==='medium-provisional').length,
    readyForGame:0
  };
  return {schema:'lnr-ratings-candidates-v1',snapshot:SNAPSHOT,season:SOURCE_SEASON,readyForGame:false,quality,ratings};
}
function defaultRoster(){
  const file=path.join(__dirname,'../modding/data06/all-players-2026-2027.json');
  return JSON.parse(fs.readFileSync(file,'utf8')).players;
}
if(require.main===module){
  const result=build(defaultRoster());
  const roles={};
  for(const r of result.ratings)roles[r.group]=(roles[r.group]||0)+1;
  console.log(JSON.stringify({schema:result.schema,quality:result.quality,byRole:roles},null,2));
}
module.exports={ATTRIBUTES,PROFILES,ROLE_WEIGHTS,SOURCE_SEASON,SNAPSHOT,baseline,validateEvidence,assess,build,defaultRoster};
