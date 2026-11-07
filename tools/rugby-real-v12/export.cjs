'use strict';
const fs=require('node:fs'),path=require('node:path'),R=require('./review.cjs');
const ROOT=path.resolve(__dirname,'../..'),file=path.join(ROOT,'modding/data06/rugby-master-2026-2027.json');
function inputs(){return ['season-evidence','extra-evidence','career-evidence'].map(n=>JSON.parse(fs.readFileSync(path.join(ROOT,'data/scouting/review-v12',n+'.json'))));}
function run(dest){
 const bytes=fs.readFileSync(file),master=JSON.parse(bytes),r=R.review(master,...inputs());R.apply(master,r);
 const map=new Map(master.players.map(p=>[p.id,p])),q=s=>'"'+String(s).replaceAll('"','""')+'"';
 const csv=[['id','name','club','league','role','age','legacyRating','legacyRoleAbility','ratingV12','legacyPotential','quality','evidenceRecordCount','flags',...R.KEYS.flatMap(k=>[k+'_before',k+'_after'])].map(q).join(',')];
 for(const row of r.rows){const p=map.get(row.playerId);csv.push([p.id,p.realName,p.club,p.league,row.role,p.ageApprox,p.rating,row.legacyRoleAbility,row.ratingV12,p.potential,row.quality,row.evidenceRecordCount,row.flags.join(';'),...R.KEYS.flatMap((k,i)=>[p.attributesV2[k],row.attributes[i]])].map(q).join(','));}
 const leaders={};for(const role of Object.keys(R.ROLES))leaders[role]=r.rows.filter(p=>p.role===role).sort((a,b)=>b.ratingV12-a.ratingV12||a.playerId.localeCompare(b.playerId)).slice(0,10).map(p=>({name:map.get(p.playerId).realName,...p}));
 const count=a=>Object.fromEntries([...new Set(a)].map(k=>[k,a.filter(x=>x===k).length]));
 const audit={schema:'rugby-real-v12-review-audit',masterSha256:R.hash(bytes),summary:r.summary,groups:r.groups,estimatedPositions:master.players.filter(p=>p.gameplayPositionEstimated).length,unavailableCareerReasons:count(inputs()[2].records.filter(r=>r.status==='unknown').map(r=>r.reason)),leaders,distributions:{}};
 for(const league of ['top14','prod2']){const rows=r.rows.filter(p=>p.league===league),n=rows.length;const grades=rows.map(r=>r.ratingV12).sort((a,b)=>a-b);audit.distributions[league]={players:n,abilityMean:R.round(R.mean(grades)),p10:grades[Math.floor(n*.1)],median:grades[Math.floor(n*.5)],p90:grades[Math.floor(n*.9)],min:grades[0],max:grades.at(-1),attributesAt97:rows.reduce((n,r)=>n+r.attributes.filter(a=>a===97).length,0)};}
 audit.estimatedOnly=r.rows.filter(r=>r.quality==='gameplay-estimate').length;
 audit.individualValidationComplete=false;
 fs.mkdirSync(dest,{recursive:true});fs.writeFileSync(path.join(dest,'candidate.json'),JSON.stringify(r)+'\n');fs.writeFileSync(path.join(dest,'ratings-before-after.csv'),csv.join('\n')+'\n');fs.writeFileSync(path.join(dest,'audit.json'),JSON.stringify(audit,null,2)+'\n');
 if(!fs.readFileSync(file).equals(bytes))throw Error('Master mutated');console.log(JSON.stringify({masterSha256:audit.masterSha256,summary:r.summary,groups:r.groups,distributions:audit.distributions}));return {candidate:r,audit};
}
if(require.main===module)run(process.argv[2]||'/tmp/v12-export');
module.exports={run,inputs};
