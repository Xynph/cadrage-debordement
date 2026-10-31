'use strict';
const fs=require('node:fs'),path=require('node:path');
const A=require('../tests/economy-audit/native.cjs');
function validateReport(r){
 if(!r||r.schema!==1||r.complete!==true||!Number.isInteger(r.expectedYears)||r.expectedYears<1||r.expectedYears>15||r.seasons.length!==r.expectedYears||r.checks.failed.length||r.rounds!==29*r.expectedYears||r.matches!==187*r.expectedYears)throw Error('Incomplete or invalid campaign');
 if(r.seasons.some((x,i)=>x.season!==i+1||x.clubs.length!==14))throw Error('Missing season or club');
 A.close(r.maxUnexplainedResidual,0,'Unexplained cash');const computed=A.summary(r);if(JSON.stringify(computed)!==JSON.stringify(r.summary))throw Error('Summary differs from measured totals');if(A.sum(Object.values(r.checks.byCheck))!==r.checks.passed)throw Error('Inconsistent executed-check count');return true;
}
function main(args){
 const [profile,seedText='827381',yearsText='15',out='economy-audit-report']=args;
 if(profile==='--aggregate'){
  const directory=seedText,files=fs.readdirSync(directory,{recursive:true}).filter(f=>String(f).endsWith('.json')&&String(f).includes('campaign-'));
  const reports=files.map(f=>JSON.parse(fs.readFileSync(path.join(directory,f),'utf8')));reports.forEach(validateReport);
  const expected=Object.keys(A.PROFILES).flatMap(p=>[827381,99173].map(s=>p+':'+s));
  const keys=reports.map(r=>r.profile+':'+r.seed);if(keys.length!==expected.length||new Set(keys).size!==keys.length||expected.some(k=>!keys.includes(k)))throw Error('Six distinct campaigns required');
  if(reports.some(r=>r.expectedYears!==15))throw Error('15 seasons per campaign required');
  const result={complete:true,kind:'native-economic-audit',sourceDigest:reports[0].sources.digest,sha:process.env.GITHUB_SHA||null,
   campaigns:reports.map(r=>r.summary),totals:{seasons:A.sum(reports.map(r=>r.seasons.length)),matches:A.sum(reports.map(r=>r.matches)),reloads:A.sum(reports.map(r=>r.checks.reloads))},
   limits:['Not a balance certification','No economic coefficients changed','Passive-manager results depend on absence of discretionary player spending','UI-02 not yet connected or visually tested here']};
  if(reports.some(r=>r.sources.digest!==result.sourceDigest))throw Error('Mixed source versions');
  fs.mkdirSync('economy-audit-summary',{recursive:true});fs.writeFileSync('economy-audit-summary/summary.json',JSON.stringify(result,null,2));
  let md='# Diagnostic economique natif\n\n| Profil | Graine | Saisons | Tresorerie initiale | Tresorerie finale | Champions |\n|---|---:|---:|---:|---:|---:|\n';
  for(const r of reports)md+=`| ${r.profile} | ${r.seed} | ${r.seasons.length} | ${Math.round(r.summary.openingCash)} | ${Math.round(r.summary.closingCash)} | ${r.summary.distinctChampions} |\n`;
  md+='\nMontants fictifs du jeu. La somme des flux explique chaque variation de tresorerie. Les colonnes finales ne mesurent pas les deficits intra-saison.\n';
  fs.writeFileSync('economy-audit-summary/summary.md',md);console.log(JSON.stringify(result));return;
 }
 const seed=Number(seedText),years=Number(yearsText);fs.mkdirSync(out,{recursive:true});
 const sources=A.sourceFingerprint();
 const failure=(partial,state)=>{
  partial.sources=sources;partial.sha=process.env.GITHUB_SHA||null;
  fs.writeFileSync(path.join(out,`campaign-${profile}-${seed}.json`),JSON.stringify(partial,null,2));
  fs.writeFileSync(path.join(out,`failure-state-${profile}-${seed}.json`),JSON.stringify({
   format:'cd-test-diagnostic-state',productionSave:false,profile,seed,sources,sha:partial.sha,
   explanation:'Generated test fixture only. This state is rejected by the native validator; it is not repaired or an exportable user save.',
   evidence:partial.failure,state},null,2));
  console.error('ECONOMY AUDIT FAILED '+JSON.stringify(partial.failure));
 };
 const r=A.campaign({profile,seed,years,onSeason:s=>console.log(JSON.stringify({profile,seed,season:s.season,cash:s.closingCash,champion:s.champion})),onFailure:failure});
 r.sources=sources;r.sha=process.env.GITHUB_SHA||null;validateReport(r);
 fs.writeFileSync(path.join(out,`campaign-${profile}-${seed}.json`),JSON.stringify(r,null,2));console.log('ECONOMY AUDIT PASS '+JSON.stringify(r.summary));
}
if(require.main===module){try{main(process.argv.slice(2));}catch(e){console.error(e.stack);process.exitCode=1;}}
module.exports={validateReport};
