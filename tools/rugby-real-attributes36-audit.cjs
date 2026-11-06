'use strict';
const fs = require('node:fs');
const path = require('node:path');

const SOURCE = path.resolve(__dirname, '../modding/data06/rugby-master-2026-2027.json');
const isObject = v => v !== null && typeof v === 'object' && !Array.isArray(v);
const round = n => Math.round(n * 100) / 100;

function findPlayers(root) {
  const arrays = [];
  const seen = new WeakSet();
  function visit(v, depth) {
    if (!v || typeof v !== 'object' || seen.has(v) || depth > 5) return;
    seen.add(v);
    if (Array.isArray(v)) {
      if (v.length && v.some(p => isObject(p) && isObject(p.attributesV2))) arrays.push(v);
      if (v.length < 100) for (const entry of v) visit(entry, depth + 1);
    } else {
      for (const value of Object.values(v)) if (value && typeof value === 'object') visit(value, depth + 1);
    }
  }
  visit(root, 0);
  return [...new Set(arrays.flat().filter(p => isObject(p) && isObject(p.attributesV2)))];
}
function stats(nums) {
  if (!nums.length) return null;
  const a = [...nums].sort((x, y) => x - y), n = a.length;
  const quantile = p => { const v=(n-1)*p, lo=Math.floor(v), hi=Math.ceil(v); return round(a[lo]+(a[hi]-a[lo])*(v-lo)); };
  const mean = nums.reduce((s,v)=>s+v,0)/n;
  return {count:n,min:a[0],p10:quantile(.1),median:quantile(.5),p90:quantile(.9),max:a[n-1],mean:round(mean),sd:round(Math.sqrt(nums.reduce((s,v)=>s+(v-mean)**2,0)/n)),distinct:new Set(nums).size};
}
function correlation(pairs) {
  if (pairs.length < 3) return null;
  const x=pairs.map(a=>a[0]),y=pairs.map(a=>a[1]),mx=x.reduce((a,b)=>a+b,0)/x.length,my=y.reduce((a,b)=>a+b,0)/y.length;
  const num=pairs.reduce((s,[a,b])=>s+(a-mx)*(b-my),0);
  const dx=Math.sqrt(x.reduce((s,a)=>s+(a-mx)**2,0)),dy=Math.sqrt(y.reduce((s,a)=>s+(a-my)**2,0));
  return dx&&dy?round(num/dx/dy):null;
}
function groupValue(p, keys) {
  for (const k of keys) if (typeof p[k] === 'string' && p[k].trim() && !['inconnu','unknown','n/a','non renseigne'].includes(p[k].trim().toLowerCase())) return p[k].trim();
  return 'inconnu';
}
function analyze(root) {
  const players=findPlayers(root), warnings=[],seen=new Set(), groups=new Map(), vectors=new Map();
  const keys=[...new Set(players.flatMap(p=>Object.keys(p.attributesV2)))].sort();
  let invalid=0, missing=0, potentials=0, missingPotentials=0, hidden=0, missingHidden=0, duplicates=0, missingIds=0, estimatedPositions=0;
  const numeric = Object.fromEntries(keys.map(k=>[k,[]]));
  for (const [index,p] of players.entries()) {
    const id = p.id ?? p.playerId ?? p.player_id;
    if (id != null && String(id).trim()) { if(seen.has(String(id))) duplicates++; seen.add(String(id)); } else missingIds++;
    const entries=keys.map(k=>p.attributesV2[k]);
    const sig=JSON.stringify(entries);
    vectors.set(sig,(vectors.get(sig)||0)+1);
    for (let i=0;i<keys.length;i++) {
      const v=entries[i];
      if (v === undefined || v === null) {missing++;continue;}
      if(typeof v !== 'number'||!Number.isFinite(v)||v<20||v>97){invalid++;continue;}
      numeric[keys[i]].push(v);
    }
    if (!isObject(p.attributesV2) || Object.keys(p.attributesV2).length !== 36) warnings.push({type:'attribute_count',player:index,count:Object.keys(p.attributesV2).length});
    if (p.potential === undefined || p.potential === null) missingPotentials++;
    if (p.potential !== undefined && p.potential !== null) {
      if (typeof p.potential !== 'number' || p.potential>97 || p.potential<20) potentials++;
    }
    const traits=p.hiddenTraitsV2 ?? p.hiddenTraits ?? p.hidden_traits;
    if (traits === undefined || traits === null) missingHidden++;
    else if (!(isObject(traits) && Object.keys(traits).length===6 && Object.values(traits).every(v=>typeof v==='number' && Number.isFinite(v) && v>=0 && v<=100))) hidden++;
    const league=groupValue(p,['competition','league','division','championship']);
    const role=groupValue(p,['gameplayPosition','position','primaryPosition','primary_position','pos','poste','role']);
    if (p.gameplayPositionEstimated && role !== 'inconnu') estimatedPositions++;
    const g=league+' / '+role;
    if (!groups.has(g)) groups.set(g,[]);
    groups.get(g).push(p);
  }
  const distributions=Object.fromEntries(keys.map(k=>[k,stats(numeric[k])]));
  const correlations=[];
  for(let i=0;i<keys.length;i++)for(let j=i+1;j<keys.length;j++){
    const k=keys[i],l=keys[j];
    const pairs=players.map(p=>[p.attributesV2[k],p.attributesV2[l]]).filter(x=>x.every(v=>typeof v==='number'&&Number.isFinite(v)));
    const r=correlation(pairs);
    if(r!==null && Math.abs(r)>=.95) correlations.push({a:k,b:l,r,n:pairs.length});
  }
  const provenance={performance2025_2026:0,v4EvidenceAdjustment:0,v2Evidence:0,v3Calibration:0,byLeague:{},modelV4:{},modelV5:{}};
  for(const p of players){
    const lg=groupValue(p,['league','competition','division','championship']);
    if(!provenance.byLeague[lg]) provenance.byLeague[lg]={players:0,performance2025_2026:0,v4EvidenceAdjustment:0};
    provenance.byLeague[lg].players++;
    for(const key of ['performance2025_2026','v4EvidenceAdjustment','v2Evidence','v3Calibration']) if(p[key]!==undefined&&p[key]!==null){provenance[key]++;if(key==='performance2025_2026'||key==='v4EvidenceAdjustment')provenance.byLeague[lg][key]++;}
  }
  for(const v of ['modelV4','modelV5']) if(isObject(root[v])) for(const k of ['evidenceSeason','observedCount','unobservedCount','newObserved','totalObserved','unknown','kind']) if(['string','number','boolean'].includes(typeof root[v][k])) provenance[v][k]=root[v][k];
  const byGroup={};
  for(const [name,group] of groups) if(group.length>=5) byGroup[name]={players:group.length,attributes:Object.fromEntries(keys.map(k=>[k,stats(group.map(p=>p.attributesV2[k]).filter(Number.isFinite))]))};
  const repeated=[...vectors.values()].filter(n=>n>1).reduce((s,n)=>s+n,0);
  return {status:players.length===1592&&keys.length===36&&invalid===0&&missing===0&&duplicates===0&&missingIds===0&&potentials===0&&missingPotentials===0&&hidden===0&&missingHidden===0?'schema-ok':'review-required',playerCount:players.length,attributeCount:keys.length,attributeKeys:keys,checks:{invalidValues:invalid,missingValues:missing,duplicateIds:duplicates,missingIds,invalidPotential:potentials,missingPotentials,invalidHiddenTraits:hidden,missingHiddenTraits:missingHidden,estimatedGameplayPositions:estimatedPositions,repeatedIdenticalVectorsPlayers:repeated,distinctVectors:vectors.size},distributions,groups:byGroup,provenance,highCorrelations:correlations.sort((a,b)=>Math.abs(b.r)-Math.abs(a.r)),warnings:warnings.slice(0,50),caveats:['Données descriptives, pas une validation sportive individuelle','Les groupes inconnu signalent des métadonnées absentes du niveau joueur','Aucune modification des fiches ou notes']};
}
if (require.main===module) {
  const file=process.argv[2]||SOURCE;
  const result=analyze(JSON.parse(fs.readFileSync(file,'utf8')));
  console.log(JSON.stringify(result,null,2));
  if(result.status!=='schema-ok') process.exitCode=1;
}
module.exports={analyze,findPlayers,stats,correlation};
