'use strict';
const fs=require('node:fs'),path=require('node:path'),C=require('./review.cjs'),{summarize}=require('./campaign.cjs');
function paired(a,b){
 const changes=a.rows.map((r,i)=>{const q=b.rows[i];if(r.seed!==q.seed||r.home!==q.home)throw Error('Unpaired rows');return q.score[0]-q.score[1]-(r.score[0]-r.score[1]);});
 const clusters=Array.from({length:changes.length/2},(_,i)=>(changes[2*i]+changes[2*i+1])/2),mean=C.mean(clusters),sd=Math.sqrt(clusters.reduce((s,v)=>s+(v-mean)**2,0)/(clusters.length-1)),e=1.96*sd/Math.sqrt(clusters.length);
 return {marginChange:C.round(mean),marginChange95:[C.round(mean-e),C.round(mean+e)],winPctChange:C.round(b.summary.winPct-a.summary.winPct)};
}
function merge(inputs){
 const base=inputs.find(r=>r.versions?.candidate);if(!base)throw Error('Missing candidate');
 const r=C.clone(base);r.versions={};r.totalMatches=0;
 for(const version of ['legacy','baseline','candidate']){
  const found=inputs.filter(r=>r.versions?.[version]);if(found.length!==1)throw Error('Missing/duplicate version');const q=found[0];
  for(const key of ['sourceBase','masterSha256','selected','seeds','candidate'])if(JSON.stringify(q[key])!==JSON.stringify(base[key]))throw Error('Mismatched campaign '+key);
  const v=q.versions[version];for(const key of ['recruits','lost'])if(JSON.stringify(v[key])!==JSON.stringify(base.versions.candidate[key]))throw Error('Roster policy changed');
  r.versions[version]=v;for(const s of Object.values(v.results)){if(s.rows.length!==r.seeds.length*2||s.rows.some(x=>x.engine!==2||x.duration<80))throw Error('Incomplete native matches');s.summary=summarize(s.rows);r.totalMatches+=s.rows.length;}
 }
 r.pairedComparison=Object.fromEntries(Object.keys(r.versions.baseline.results).map(k=>[k,paired(r.versions.baseline.results[k],r.versions.candidate.results[k])]));
 for(const v of Object.values(r.versions))for(const s of Object.values(v.results)){s.rowsSha256=C.hash(s.rows);delete s.rows;}
 return r;
}
function render(r){
 const out=['# Notes V12 — résultats du vrai moteur','',`${r.totalMatches} matchs, ${r.seeds.length} graines et deux domiciles par scénario. Coefficient natif inchangé (0,004). Les mêmes IDs de recrues et de départs sont utilisés dans chaque variante.`, '', '| Scénario : victoires du premier effectif | 11 notes héritées | 36 notes actuelles projetées | 36 notes V12 | Écart V12 | Variation d’écart appariée [IC95] |','|---|---:|---:|---:|---:|---:|'];
 for(const k of Object.keys(r.versions.baseline.results)){const a=r.versions.legacy.results[k].summary,b=r.versions.baseline.results[k].summary,c=r.versions.candidate.results[k].summary,p=r.pairedComparison[k];out.push(`|${k}|${a.winPct} %|${b.winPct} %|${c.winPct} %|${c.margin}|${p.marginChange} [${p.marginChange95.join(' ; ')}]|`);}
 out.push('','## Essais, discipline, fatigue et tactiques','','| Scénario V12 | Essais pour/contre | Pénalités | Jaunes | Fatigue moyenne | Victoires [IC95] |','|---|---:|---:|---:|---:|---:|');
 for(const [k,v] of Object.entries(r.versions.candidate.results)){const s=v.summary;out.push(`|${k}|${s.tries.join(' / ')}|${s.penalties.join(' / ')}|${s.yellows.join(' / ')}|${s.fatigue.join(' / ')}|${s.winPct} % [${s.win95.join(' ; ')}]|`);}
 out.push('','## Cibles de game design exploratoires','','Ces seuils sont des choix à calibrer, pas des fréquences historiques officielles. Un échec reste visible.');
 for(const [k,v] of Object.entries(r.designTargets))if(k!=='kind')out.push('- '+k+' : '+v);
 out.push('','## Portée','', '- Sélection limitée aux feuilles complètes 15+8 ; exclus : '+r.excludedIncomplete.map(x=>x.club+' ('+x.lineup+'+'+x.bench+')').join(', ')+'. Chaque scénario est contrôlé avant simulation.',...r.limitations.map(x=>'- '+x),'- Les 36 attributs n’alimentent actuellement pas le générateur LNR du jeu : cette expérience injecte les effectifs dans le vrai moteur via le harness existant.','- La montée/descente à deux divisions n’existe pas encore dans la carrière senior de main. Aucun taux de maintien ou de remontée de saison complète n’est prétendu.','- Les intervalles regroupent les deux domiciles par graine ; cette campagne est exploratoire.');
 return out.join('\n')+'\n';
}
if(require.main===module){const files=[];function walk(d){for(const f of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,f.name);if(f.isDirectory())walk(p);else if(f.name==='matches.json'||/^v12-(legacy|baseline|candidate)\.json$/.test(f.name))files.push(p);}}walk(process.argv[2]);const r=merge(files.map(f=>JSON.parse(fs.readFileSync(f))));fs.mkdirSync(process.argv[3],{recursive:true});fs.writeFileSync(path.join(process.argv[3],'measures.json'),JSON.stringify(r,null,2)+'\n');const md=render(r);fs.writeFileSync(path.join(process.argv[3],'results.md'),md);if(process.env.GITHUB_STEP_SUMMARY)fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY,md);console.log(JSON.stringify({matches:r.totalMatches,targets:r.designTargets}));}
module.exports={merge,paired,render};
