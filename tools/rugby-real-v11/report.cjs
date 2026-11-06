'use strict';
const fs=require('node:fs'),C=require('./calibration.cjs');
const {summarize}=require('./campaign.cjs');
function paired(a,b){
 const changes=a.rows.map((r,i)=>{const q=b.rows[i];if(r.seed!==q.seed||r.home!==q.home)throw Error('Unpaired rows');return q.score[0]-q.score[1]-(r.score[0]-r.score[1]);});
 const clusters=Array.from({length:changes.length/2},(_,i)=>(changes[2*i]+changes[2*i+1])/2),mean=C.mean(clusters),sd=Math.sqrt(clusters.reduce((s,v)=>s+(v-mean)**2,0)/(clusters.length-1)),e=1.96*sd/Math.sqrt(clusters.length);
 return {marginChange:C.round(mean),marginChange95:[C.round(mean-e),C.round(mean+e)],winPctChange:C.round(b.summary.winPct-a.summary.winPct)};
}
function compact(report){
 const r=C.clone(report);
 // Recompute summaries from retained match rows, including seed-cluster uncertainty.
 for(const v of Object.values(r.versions))for(const s of Object.values(v.results))s.summary=summarize(s.rows);
 r.pairedComparison={};
 for(const [name,from,to] of [['dataOnly','baseline','candidate'],['responseOnly','candidate','responseCandidate'],['combined','baseline','responseCandidate']]){
  if(!r.versions[from]||!r.versions[to])continue;
  r.pairedComparison[name]=Object.fromEntries(Object.keys(r.versions[from].results).filter(k=>r.versions[to].results[k]).map(k=>[k,paired(r.versions[from].results[k],r.versions[to].results[k])]));
 }
 for(const v of Object.values(r.versions))for(const s of Object.values(v.results)){s.rowsSha256=C.hash(s.rows);delete s.rows;}
 r.uncertainty='95% normal intervals with seed clusters; exploratory, not independent holdout';
 return r;
}
function render(r){
 const versions=['legacy','baseline','candidate','responseCandidate'];
 const names=Object.keys(r.versions.baseline.results),out=['# Résultats natifs V11','',`Base ${r.sourceBase}. ${r.totalMatches} matchs comparatifs, 64 graines × deux domiciles par scénario. Propositions hors production.`, '',
  '| Scénario (victoires du premier effectif) | 11 notes héritées | Projection baseline | Notes consolidées | Notes + réponse ×2 | Écart score ×2 |', '|---|---:|---:|---:|---:|---:|'];
 for(const k of names){out.push('|'+k+'|'+versions.map(v=>r.versions[v].results[k].summary.winPct+' %').join('|')+'|'+r.versions.responseCandidate.results[k].summary.margin+'|');}
 out.push('','Les mêmes IDs sont recrutés ou retirés dans les quatre versions. La colonne « héritées » utilise les notes stockées dans le master, pas le générateur LNR actuel. Les colonnes projetées sont des expériences sur copies. Aucune probabilité de maintien/remontée sur une saison à deux divisions n’est mesurée.','','## Cibles exploratoires','');
 for(const [k,v] of Object.entries(r.designTargets))out.push('- '+k+' : '+v);
 out.push('','## Discipline, fatigue et tactiques','', '| Scénario ×2 | Essais pour/contre | Pénalités pour/contre | Jaunes pour/contre | Fatigue moyenne pour/contre | Victoires (IC par graine) |', '|---|---:|---:|---:|---:|---:|');
 for(const k of ['promoted0_mid','promoted5_mid','promoted_tired_mid','promoted_equilibre_mid','promoted_conquete_mid','promoted_large_mid','promoted_occupation_mid','promoted_defence_pression','promoted_defence_prudente']){const s=r.versions.responseCandidate.results[k].summary;out.push('|'+k+'|'+s.tries.join(' / ')+'|'+s.penalties.join(' / ')+'|'+s.yellows.join(' / ')+'|'+s.fatigue.join(' / ')+'|'+s.winPct+' % ['+s.win95.join(' ; ')+']|');}
 out.push('','## Comparaisons appariées','', '| Scénario | Écart notes seules | Écart réponse moteur seule | Écart combiné (IC par graine) |','|---|---:|---:|---:|');
 for(const k of names){const a=r.pairedComparison.dataOnly[k],b=r.pairedComparison.responseOnly[k],c=r.pairedComparison.combined[k];out.push('|'+k+'|'+a.marginChange+'|'+b.marginChange+'|'+c.marginChange+' ['+c.marginChange95.join(' ; ')+']|');}
 out.push('','## Limites','',...r.limitations.map(s=>'- '+s),'','Voir README.md, age-research.md et age-impact.json pour le volet âge, ainsi que seasons.json pour le blocage réel de sauvegarde et sa proposition isolée. Les intervalles sont exploratoires ; une direction moyenne ne garantit pas la monotonie de chaque taux de victoire.');
 return out.join('\n')+'\n';
}
if(require.main===module){const r=compact(JSON.parse(fs.readFileSync(process.argv[2],'utf8')));fs.writeFileSync(process.argv[3],JSON.stringify(r,null,2)+'\n');fs.writeFileSync(process.argv[4],render(r));console.log(JSON.stringify({matches:r.totalMatches,targets:r.designTargets}));}
module.exports={compact,paired,render};
