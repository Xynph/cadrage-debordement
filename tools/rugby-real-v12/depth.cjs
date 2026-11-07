'use strict';
// Isolated candidate on the V12 copy, never writes the master or production engine.
// Status is established ONCE on the original 15+8 sheet; movement cannot rerank survivors.
const C=require('./review.cjs'),N=require('./native.cjs');
const LEVELS={
  mild:{star:4,starter:2,bench:-3,rotation:-5},
  pronounced:{star:7,starter:3,bench:-5,rotation:-8}
};
function build(master,variant='mild'){
  if(!LEVELS[variant])throw Error('Unknown V12 depth variant');
  C.validate(master);
  const lab=N.laboratory(master);
  const tiers=new Map(),audit=[],weights=LEVELS[variant];
  for(const club of lab.clubs){
    const sheet=lab.sheet(club),index=new Map(club.players.map(p=>[p.id,p]));
    const starters=sheet.lineup.filter(Boolean),bench=sheet.bench.filter(Boolean);
    if(new Set([...starters,...bench]).size!==starters.length+bench.length)throw Error('Duplicate sheet ID');
    const leaders=[...starters].sort((a,b)=>lab.note(index.get(b))-lab.note(index.get(a))||a.localeCompare(b)).slice(0,5);
    const stars=new Set(leaders),starting=new Set(starters),reserve=new Set(bench);
    for(const p of club.players){
      if(tiers.has(p.id))throw Error('Duplicate player across clubs');
      const tier=stars.has(p.id)?'star':starting.has(p.id)?'starter':reserve.has(p.id)?'bench':'rotation';
      tiers.set(p.id,{tier,club:club.slug,adjustment:weights[tier]});
    }
    audit.push({club:club.slug,league:club.league,eligible15x8:starters.length===15&&bench.length===8,
      counts:{star:stars.size,starter:starters.length-stars.size,bench:bench.length,rotation:club.players.length-starters.length-bench.length}});
  }
  if(tiers.size!==master.players.length)throw Error('Missing player classifications');
  const output=C.clone(master),changes=[];
  for(const p of output.players){
    const entry=tiers.get(p.id);if(!entry||entry.club!==p.club)throw Error('Player ownership mismatch');
    const original=master.players.find(q=>q.id===p.id),primary=new Set(C.ROLES[p.gameplayPosition]);
    const attributeBefore=original.attributesV2,attributes={...attributeBefore};
    // Raise/lower only role-relevant specialities. Keep injuries, physical maturation and
    // non-role qualities untouched. No arbitrary mutation of historical potential or traits.
    for(const key of primary)attributes[key]=Math.max(20,Math.min(97,attributeBefore[key]+entry.adjustment));
    p.attributesV2=attributes;p.skills=C.project(p);p.ratingV12=Math.round(C.ability(attributes,p.gameplayPosition));
    changes.push({id:p.id,club:p.club,league:p.league,tier:entry.tier,modifier:entry.adjustment,
      oldRating:original.ratingV12,newRating:p.ratingV12,oldRoleSkills:original.skills,newRoleSkills:p.skills});
    if(p.potential!==original.potential||JSON.stringify(p.hiddenTraitsV2)!==JSON.stringify(original.hiddenTraitsV2))throw Error('Potential/traits modified');
  }
  return {master:output,tiers:[...tiers].map(([id,t])=>({id,...t})),audit,changes,variant,weights};
}
module.exports={build,LEVELS};
