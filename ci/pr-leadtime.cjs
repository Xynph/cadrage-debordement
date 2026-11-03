'use strict';
// Mesures lecture seule. Création → fusion ≠ temps total de développement.
const {execFileSync} = require('node:child_process');
function median(values) {
  if (!values.length) return null;
  const sorted = [...values].sort((a,b)=>a-b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid-1]+sorted[mid])/2;
}
function percentile(values, fraction) {
  if (!values.length) return null;
  const sorted=[...values].sort((a,b)=>a-b);
  return sorted[Math.ceil(fraction*sorted.length)-1];
}
function summarize(prs, limit=20, now=new Date()) {
  if (!Array.isArray(prs)) throw new TypeError('Expected an array of PRs');
  if (!Number.isInteger(limit)||limit<1) throw new RangeError('limit must be positive');
  const recent=[...prs].filter(pr=>Number.isInteger(pr.number))
    .sort((a,b)=>b.number-a.number).slice(0,limit);
  const rows=recent.map(pr=>{
    const created=Date.parse(pr.created_at);
    const merged=pr.merged_at ? Date.parse(pr.merged_at):null;
    const valid=Number.isFinite(created)&&(merged===null||(Number.isFinite(merged)&&merged>=created));
    const minutes=valid?Math.round(((merged===null?now.getTime():merged)-created)/60000*10)/10:null;
    return {number:pr.number,state:merged!==null?'merged':(pr.state||'open'),minutes,merged:merged!==null,valid};
  });
  const completed=rows.filter(row=>row.merged&&row.valid).map(row=>row.minutes);
  return {sample:rows.length,merged:completed.length,unmerged:rows.filter(row=>!row.merged).length,
    invalid:rows.filter(row=>!row.valid).length,medianMinutes:median(completed),
    p90Minutes:percentile(completed,.9),maxMinutes:completed.length?Math.max(...completed):null,rows};
}
function formatReport(report) {
  const fmt=v=>v===null?'indisponible':v.toFixed(1)+' min';
  return ['PR observées : '+report.sample+' ('+report.merged+' fusionnées, '+report.unmerged+' non fusionnées).',
    'Délai création → fusion : médiane '+fmt(report.medianMinutes)+', P90 '+fmt(report.p90Minutes)+', maximum '+fmt(report.maxMinutes)+'.',
    'Dates invalides : '+report.invalid+'. Ne mesure PAS le codage préalable ni la CI post-fusion.'].join('\n');
}
if (require.main===module) {
  try {
    const raw=execFileSync('gh',['api','--method','GET',
      'repos/Xynph/cadrage-debordement/pulls?state=all&sort=created&direction=desc&per_page=100'],
      {encoding:'utf8',timeout:30000,maxBuffer:10*1024*1024});
    const report=summarize(JSON.parse(raw),20);
    console.log(formatReport(report));
    if (process.argv.includes('--json')) console.log(JSON.stringify(report,null,2));
  }catch(error){console.error('Mesure impossible :',error.message);process.exitCode=1;}
}
module.exports={median,percentile,summarize,formatReport};
