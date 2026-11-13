'use strict';

// JRLO 2026–27 arts. 54, 56 and 60. Classification is roster evidence or an
// explicit game assignment; nationality never establishes a category.
function factory(){
 const categories=['A-1','A-2','B','C'];
 const validCategory=value=>categories.includes(value);
 const validId=value=>typeof value==='string'&&value.length>0;
 const empty=()=>Object.fromEntries(categories.map(k=>[k,0]));
 const special=c=>c['A-2']+c.B+c.C;
 const bc=c=>c.B+c.C;
 const report=(violations,counts)=>({valid:violations.length===0,violations,counts});
 function inspect(players){
  if(!Array.isArray(players))return report(['invalid-players'],empty());
  const counts=empty(),violations=new Set(),ids=new Set();
  for(const p of players){
   if(!validId(p?.id))violations.add('invalid-player');
   else if(ids.has(p.id))violations.add('duplicate-player');
   else ids.add(p.id);
   if(!validCategory(p?.category))violations.add('unknown-category');
   else counts[p.category]++;
  }
  return report([...violations],counts);
 }
 function registration(players){
  const r=inspect(players);
  if(bc(r.counts)>10)r.violations.push('registered-bc');
  if(r.counts.C>3)r.violations.push('registered-c');
  return report(r.violations,r.counts);
 }
 function teamSheet(starters,reserves,{frontRow}={}){
  if(!Array.isArray(starters)||!Array.isArray(reserves))return report(['invalid-sheet'],null);
  const r=inspect([...starters,...reserves]),xv=inspect(starters);
  const expected=frontRow===6?23:frontRow===5?22:null,counts={sheet:r.counts,field:xv.counts};
  const violations=[...r.violations];
  if(expected===null||starters.length!==15||starters.length+reserves.length!==expected)violations.push('sheet-size');
  if(r.counts['A-1']<(expected===22?13:14)||special(r.counts)>9)violations.push('sheet-a1');
  if(bc(r.counts)>6)violations.push('sheet-bc');
  if(r.counts.C>3)violations.push('sheet-c');
  if(xv.counts['A-1']<8||special(xv.counts)>7)violations.push('field-a1');
  if(xv.counts.C>3)violations.push('field-c');
  if(xv.counts.B>4)violations.push('field-b');
  return report(violations,counts);
 }
 function substitution(active,out,incoming,{forcedAbsence=false}={}){
  const previous=inspect(active);
  if(!previous.valid||!Array.isArray(active)||active.length>15||!active.some(p=>p.id===out)||!validId(incoming?.id)||active.some(p=>p.id===incoming.id)){
   return report(['invalid-substitution'],previous.counts);
  }
  const next=inspect(active.map(p=>p.id===out?incoming:p)),violations=[...next.violations];
  // A forced absence is input from the actual match, never from the coach.
  // It cannot be used to add a non-A1 or extend an existing deficiency.
  const minimum=forcedAbsence&&active.length<15?Math.min(8,previous.counts['A-1']):8;
  if(next.counts['A-1']<minimum||special(next.counts)>7)violations.push('field-a1');
  if(next.counts.C>3)violations.push('field-c');
  if(next.counts.B>4)violations.push('field-b');
  return report(violations,next.counts);
 }
 function planSheet(slots,{frontRow=6,searchLimit=30000}={}){
  const fail=(code,visited=0)=>({valid:false,violations:[code],visited,assignment:null});
  if(!Array.isArray(slots)||slots.length!==(frontRow===6?23:frontRow===5?22:0))return fail('sheet-size');
  if(!Number.isInteger(searchLimit)||searchLimit<1||searchLimit>1000000)throw Error('Limite du solveur invalide.');
  const byId=new Map(),slotIds=new Set();
  const ordered=slots.map((slot,i)=>{
   if(slot?.slot!==i||slot.starter!==(i<15)||!Array.isArray(slot.candidates)||slotIds.has(i))throw Error('Poste de feuille invalide.');
   slotIds.add(i);
   const seen=new Set();
   const candidates=slot.candidates.filter(p=>{
    if(!validId(p?.id)||!validCategory(p.category))return false;
    if(byId.has(p.id)&&byId.get(p.id)!==p.category)throw Error('Catégorie contradictoire pour un joueur.');
    byId.set(p.id,p.category);
    if(seen.has(p.id))return false;
    seen.add(p.id);
    return true;
   }).sort((a,b)=>(Number.isFinite(b.rank)?b.rank:0)-(Number.isFinite(a.rank)?a.rank:0)||a.id.localeCompare(b.id,'en'));
   return {index:i,starter:slot.starter,candidates};
  });
  const sheet=empty(),field=empty(),used=new Set(),assignment=Array(slots.length).fill(null);
  let visited=0,exhausted=false;
  function permits(p,starter){
   const cat=p.category;
   if(cat==='A-1')return true;
   return special(sheet)<9&&(cat==='A-2'||bc(sheet)<6)&&(cat!=='C'||sheet.C<3)&&(!starter||special(field)<7&&(cat!=='C'||field.C<3)&&(cat!=='B'||field.B<4));
  }
  function visit(remaining){
   if(!remaining.length)return true;
   if(++visited>searchLimit){exhausted=true;return false;}
   let target,choices;
   for(const slot of remaining){
    const list=slot.candidates.filter(p=>!used.has(p.id)&&permits(p,slot.starter));
    if(!list.length)return false;
    if(!target||list.length<choices.length){target=slot;choices=list;}
   }
   const tail=remaining.filter(s=>s!==target);
   for(const p of choices){
    used.add(p.id);assignment[target.index]=p;sheet[p.category]++;
    if(target.starter)field[p.category]++;
    if(visit(tail))return true;
    if(target.starter)field[p.category]--;
    sheet[p.category]--;assignment[target.index]=null;used.delete(p.id);
    if(exhausted)return false;
   }
   return false;
  }
  if(!visit(ordered))return fail(exhausted?'search-budget':'no-legal-sheet',visited);
  const result=teamSheet(assignment.slice(0,15),assignment.slice(15),{frontRow});
  if(!result.valid)throw Error('Le solveur a produit une feuille incohérente.');
  return {...result,visited,assignment};
 }
 return Object.freeze({categories:Object.freeze(categories),registration,teamSheet,substitution,planSheet});
}
module.exports={factory,...factory()};
