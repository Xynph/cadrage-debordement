'use strict';
// Strict aggregation. An incomplete or failed campaign never becomes a green report.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
function summarize(reports,expectedCommit){
 assert.equal(reports.length,3,'Three reports required');
 assert.deepEqual(reports.map(r=>r.scenario).sort(),['deficit','reference','rotation']);
 assert.equal(new Set(reports.map(r=>r.sourceDigest)).size,1,'Sources differ across matrix jobs');
 assert.equal(new Set(reports.map(r=>r.testedCommit)).size,1,'Commits differ across jobs');
 for(const r of reports){
  assert.match(r.sourceDigest,/^[a-f0-9]{64}$/);assert.ok(typeof r.testedCommit==='string'&&r.testedCommit);if(expectedCommit)assert.equal(r.testedCommit,expectedCommit);
  assert.ok(Number.isSafeInteger(r.stats.passed)&&r.stats.passed>0);assert.equal(r.stats.passed,Object.values(r.stats.byCheck).reduce((n,c)=>n+c,0));
  assert.equal(r.status,'passed','Incomplete campaign: '+r.scenario);assert.equal(r.completedSeasons,15);assert.equal(r.annual.length,15);
  assert.equal(r.stats.failed.length,0);assert.ok(r.sourceUnchanged);
  r.annual.forEach((a,i)=>{assert.equal(a.season,i+1);assert.equal(a.nativeMatches,187);assert.equal(a.clubs.length,14);assert.equal(new Set(a.clubs.map(c=>c.id)).size,14);assert.ok(a.clubs.every(c=>Number.isFinite(c.cash)&&Number.isFinite(c.debt)));});
 }
 const summary={schemaVersion:1,status:'passed',sourceDigest:reports[0].sourceDigest,testedCommit:reports[0].testedCommit,seasons:45,nativeMatches:reports.reduce((n,r)=>n+r.annual.reduce((sum,a)=>sum+a.nativeMatches,0),0),checks:reports.reduce((n,r)=>n+r.stats.passed,0),nativeReloads:reports.reduce((n,r)=>n+r.stats.reloads,0),rows:[]};
 for(const r of reports){
  const champions=new Map();for(const a of r.annual)champions.set(a.champion,(champions.get(a.champion)||0)+1);
  const samples=r.annual.flatMap(a=>a.clubs),first=r.annual[0],last=r.annual.at(-1);
  summary.rows.push({scenario:r.scenario,controlled:r.scenario==='rotation',seasons:r.completedSeasons,moves:r.moves.length,returnsToOrigin:r.moves.filter(m=>m.toClub===0).length,reloads:r.stats.reloads,checks:r.stats.passed,champions:champions.size,dominantChampionTitles:Math.max(...champions.values()),negativeCashClubSeasons:samples.filter(c=>c.cash<0).length,observedClubSeasons:samples.length,minCash:Math.min(...samples.map(c=>c.cash)),maxCash:Math.max(...samples.map(c=>c.cash)),firstSeasonTotalCash:first.clubs.reduce((n,c)=>n+c.cash,0),lastSeasonTotalCash:last.clubs.reduce((n,c)=>n+c.cash,0),humanFacilitySpend:r.annual.reduce((n,a)=>n+a.investment,0),recordedCoachChanges:last.clubs.reduce((n,c)=>n+c.coachChanges,0),explicitFixtureCashInjections:r.adjustments.reduce((n,a)=>n+(a.cashInjection||0),0),finalSaveBytes:r.finalSaveBytes});
 }
 return summary;
}
function markdown(s){
 return '# Validation des carrieres multi-clubs\n\nCommit teste : `'+s.testedCommit+'`\n\n'+s.seasons+' saisons completes, '+s.nativeMatches+' matchs du moteur, '+s.nativeReloads+' rechargements natifs, '+s.checks+' groupes de controles passes.\n\n| Campagne | Saisons | Mobilites | Retours origine | Reprises | Champions distincts | Titres du dominant | Club-saisons en tresorerie negative |\n|---|---:|---:|---:|---:|---:|---:|---:|\n'+s.rows.map(r=>'| '+r.scenario+' | '+r.seasons+' | '+r.moves+' | '+r.returnsToOrigin+' | '+r.reloads+' | '+r.champions+' | '+r.dominantChampionTitles+'/15 | '+r.negativeCashClubSeasons+'/'+r.observedClubSeasons+' |').join('\n')+'\n\n## Interpretation\n\nLes reference et deficit suivent les decisions natives avec une seule graine. La rotation force des conditions de candidature pour atteindre les cas de retour : elle ne mesure ni attractivite naturelle ni equilibrage. Les injections sont tracees dans les rapports JSON. Le montant negatif est une tresorerie, pas un resultat comptable. Aucun coefficient de jeu ne change.\n\nLa reprise deterministe emploie un etat aleatoire conserve dans une enveloppe de test, jamais dans une sauvegarde officielle. Aucun test Windows ou navigateur graphique revendique.\n';
}
if(require.main===module){try{const dir=process.argv[2];assert.ok(dir);const reports=['reference','deficit','rotation'].map(name=>JSON.parse(fs.readFileSync(path.join(dir,name+'-report.json'),'utf8')));const result=summarize(reports,process.env.GITHUB_SHA);fs.writeFileSync(path.join(dir,'summary.json'),JSON.stringify(result,null,2)+'\n');fs.writeFileSync(path.join(dir,'summary.md'),markdown(result));console.log(JSON.stringify(result,null,2));}catch(e){console.error(e.stack);process.exitCode=1;}}
module.exports={summarize,markdown};
