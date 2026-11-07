'use strict';
// Harness adapter only. No scores/outcomes are generated here: native rugby.js owns them.
const {context}=require('../../tests/harness.cjs');
const C=require('./review.cjs');
const SLOTS={'Pilier gauche':[0,0],'Talonneur':[1,1],'Pilier droit':[2,0],'Deuxième ligne':[3,2],'Troisième ligne':[5,3],'Numéro 8':[7,3],'Demi de mêlée':[8,4],'Demi d’ouverture':[9,5],'Centre':[11,7],'Ailier':[10,6],'Arrière':[14,8]};
const POS=['Pilier gauche','Talonneur','Pilier droit','Deuxième ligne','Deuxième ligne','Troisième ligne','Troisième ligne','Numéro 8','Demi de mêlée','Demi d’ouverture','Ailier','Centre','Centre','Ailier','Arrière'];
function player(p,mode){
 const [slot,fam]=SLOTS[p.gameplayPosition];
 return {id:p.id,name:p.realName,pos:POS[slot],fam,age:p.ageApprox,rating:p.ratingV12??p.rating,skillBase:p.ratingV12??p.rating,
  skills:mode==='legacy'?C.clone(p.skills):C.project(p),condition:100,injury:0,salary:5000,
  attributesV2:C.clone(p.attributesV2),hiddenTraitsV2:C.clone(p.hiddenTraitsV2),potential:p.potential};
}
function laboratory(master,mode='projected',{qualityCoefficient=.004}={}){
 if(![.004,.008,.012,.016].includes(qualityCoefficient))throw Error('Invalid quality coefficient');
 C.validate(master);if(!['legacy','projected'].includes(mode))throw Error('Invalid lab mode');
 const g=context();g.run('start(13);S.difficulty="classique";S.morale=75');
 if(qualityCoefficient!==.004){const source=g.run('tacticalEdge.toString()'),find='(attack-defence)*.004';if(source.split(find).length!==2)throw Error('Native tacticalEdge precondition mismatch');g.run('tacticalEdge='+source.replace(find,'(attack-defence)*'+qualityCoefficient));}
 const clubs=[];
 for(const p of master.players){
  let c=clubs.find(c=>c.slug===p.club);if(!c){c={slug:p.club,league:p.league,players:[]};clubs.push(c);}c.players.push(player(p,mode));
 }
 function inject(c,index,condition=100){
  const roster=C.clone(c.players);for(const p of roster)p.condition=condition;
  g.ctx.__roster=roster;g.ctx.__slug=c.slug;
  g.run(`S.clubs[${index}]={...S.clubs[${index}],id:${index},name:__slug,abbr:__slug,base:70,morale:75,form:[],players:__roster};S.clubs[${index}].players.forEach(p=>{ensureDevelopment(p);ensurePhysicalLoad(p)})`);
 }
 function quality(c){inject(c,0);return g.run('mean(buildSheet(S.clubs[0]).lineup.map(id=>S.clubs[0].players.find(p=>p.id===id)).filter(Boolean).map(p=>roleNote(p)))');}
 function sheet(c){inject(c,0);return JSON.parse(g.run('JSON.stringify(buildSheet(S.clubs[0]))'));}
 const notes=new Map();
 function note(p){const key=p.id+JSON.stringify(p.skills);if(!notes.has(key)){g.ctx.__p=C.clone(p);notes.set(key,g.run('roleNote(__p)'));}return notes.get(key);}
 function match(a,b,seed,{home=0,condition=100,tactic=null,defence=null}={}){
  if(!Number.isInteger(seed)||seed<0||seed>0xffffffff||![0,1].includes(home)||condition<1||condition>100)throw Error('Invalid match inputs');
  inject(a,home,condition);inject(b,1-home);
  g.ctx.__seed=seed;g.ctx.__home=home;g.ctx.__tactic=tactic;g.ctx.__defence=defence;
  // RNG reset AFTER preparing squads: game outcomes paired by identical seed.
  return JSON.parse(g.run(`JSON.stringify((()=>{
   let rng=__seed;Math.random=()=>{rng=(Math.imul(rng,1664525)+1013904223)>>>0;return rng/4294967296};
   const l=createRugbyMatch([0,1],null,true);
   if(__tactic)l.tactics[__home]=__tactic;if(__defence)l.defences[__home]=__defence;
   let steps=0;while(!l.finished){if(++steps>5000)throw Error('Native match did not terminate');l.paused=false;advanceRugby(l)}
   applyMatchInjuries(l);
   const order=[__home,1-__home];
   return {engine:l.engine,duration:l.minute,score:order.map(i=>l.score[i]),tries:order.map(i=>l.tries[i]),
    stats:order.map(i=>l.stats[i]),tacticalStats:order.map(i=>l.tacticalStats[i]),weather:l.weather,
    minutes:order.map(i=>Object.values(l.sheets[i].minutes).reduce((n,v)=>n+v,0)),
    conditionLoss:order.map(i=>{const sh=l.sheets[i],ps=S.clubs[i].players.filter(p=>sh.minutes[p.id]>0);return mean(ps.map(p=>(i===__home?${Number(condition)}:100)-p.condition))}),
    injuries:order.map(i=>S.clubs[i].players.filter(p=>p.injury>0).length),
    reds:order.map(i=>l.sheets[i].redCards.length),subs:order.map(i=>l.sheets[i].subs),
    initial:order.map(i=>l.sheets[i].initial)};
  })())`));
 }
 return {g,clubs,quality,sheet,note,match};
}
function recruit(club,donors,count,lab){
 const copy=C.clone(club),moves=[],used=new Set(copy.players.map(p=>p.id));
 const ceilings=new Map();for(const pos of POS){const pool=donors.flatMap(c=>c.players).filter(p=>p.pos===pos).map(lab.note).sort((a,b)=>a-b);ceilings.set(pos,pool[Math.floor(pool.length*.75)]);}
 for(let i=0;i<count;i++){
  const sh=lab.sheet(copy),incumbents=sh.lineup.map(id=>copy.players.find(p=>p.id===id)).filter(Boolean);
  const options=[];
  for(const old of incumbents){
   for(const c of donors)for(const p of c.players){
    if(c.slug===club.slug||used.has(p.id)||p.pos!==old.pos)continue;
    // Select a normal TOP14 starter-band recruit, not an all-star shopping list.
    const ceiling=ceilings.get(p.pos);
    if(lab.note(p)>ceiling)continue;
    const gain=lab.note(p)-lab.note(old);if(gain>0)options.push({p,old,gain,donor:c.slug});
   }
  }
  options.sort((a,b)=>b.gain-a.gain||a.p.id.localeCompare(b.p.id));
  if(!options.length)break;const best=options[0];used.add(best.p.id);copy.players.push(C.clone(best.p));
  moves.push({playerId:best.p.id,donor:best.donor,role:best.p.pos,replaces:best.old.id,gain:best.gain});
 }
 return {club:copy,moves};
}
function depart(club,count,lab){
 const copy=C.clone(club),sh=lab.sheet(copy),candidates=sh.lineup.map(id=>copy.players.find(p=>p.id===id)).filter(Boolean).sort((a,b)=>lab.note(b)-lab.note(a));
 const removed=candidates.slice(0,count);copy.players=copy.players.filter(p=>!removed.some(q=>q.id===p.id));
 return {club:copy,moves:removed.map(p=>({playerId:p.id,role:p.pos,note:lab.note(p)}))};
}
module.exports={laboratory,recruit,depart,SLOTS};
