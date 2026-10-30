'use strict';
// World Rugby law 3.13–3.20 and the August 2025 uncontested-scrum matrix.
// Opt-in per fixture: saved version-seven fixtures retain their prior behavior.
function frontRowRules(l){return revisedRules(l)&&l.frontRowVersion===1}
function registerFrontExclusion(l,side,id,slot,kind,until){
 const sh=l.sheets[side],e={id,slot,kind,until,closed:false};
 sh.front.exclusions.push(e);sh.on[slot]=null;
 if(kind==='yellow'&&!sh.bench.includes(id))sh.bench.push(id);
 const red=sh.redCards.find(c=>c.id===id);if(red)red.frontCase=sh.front.exclusions.length-1;
}
function frontLocked(l,side,id){
 const f=l.sheets[side].front;
 return f.held.some(h=>h.id===id&&(h.mode==='carence'&&f.uncontested||frontCaseActive(l,f.exclusions[h.caseIndex],'yellow')));
}
function frontCaseActive(l,e,kind=null){return !!e&&(!kind||e.kind===kind)&&!e.closed&&(e.until===null||e.until>l.minute)}
function frontAvailable(l,side,id){const sh=l.sheets[side],p=matchPlayer(l,side,id);return p&&!p.injury&&!sh.sentOff.includes(id)&&!sh.cards.some(c=>c.id===id&&c.until>l.minute)}
function frontTarget(l,side){
 const sh=l.sheets[side];
 const yellows=sh.cards.filter(c=>c.until>l.minute).length,reds=sh.redCards.filter(c=>c.until===null||c.until>l.minute).length;
 return 15-yellows-reds-(sh.front.uncontested&&sh.front.exclusions.length?1:0);
}
function recordFrontMove(l,side,out,incoming,reason){
 const sh=l.sheets[side],returning=sh.used.includes(incoming);
 if(!returning)sh.used.push(incoming);sh.subs++;
 l.subs.push({minute:l.minute,side,out,in:incoming,reason,returning});
}
function frontDonor(l,side){
 const sh=l.sheets[side];
 return sh.on.map((id,slot)=>({id,slot,p:matchPlayer(l,side,id)})).filter(x=>x.slot>=3&&x.p&&frontAvailable(l,side,x.id)).sort((a,b)=>fitScore(a.p)-fitScore(b.p))[0];
}
function frontRed(l,side,e){return l.sheets[side].redCards.find(c=>c.id===e.id&&c.slot===e.slot)}
function reconcileFrontRow(l,side,prepare=false){
 const sh=l.sheets[side],f=sh.front;
 // A returning suspended specialist may replace the temporary specialist. The
 // nominated player then returns separately; neither return is a tactical re-entry.
 for(const e of f.exclusions){
  if(e.kind!=='yellow'||e.closed||e.until>l.minute)continue;
  e.closed=true;
  if(!sh.bench.includes(e.id)||!frontAvailable(l,side,e.id))continue;
  const cover=sh.on[e.slot];
  if(cover){sh.bench.push(cover);recordFrontMove(l,side,cover,e.id,'frontreturn')}
  sh.on[e.slot]=e.id;sh.bench=sh.bench.filter(id=>id!==e.id);
  addEvent(l,`${matchPlayer(l,side,e.id).name} revient en première ligne après son exclusion temporaire.`,'card');
 }
 if(prepare)f.prepared=true;
 if(!f.prepared)return;
 for(let slot=0;slot<3;slot++){
  if(sh.on[slot]&&frontAvailable(l,side,sh.on[slot])&&slotEligible(matchPlayer(l,side,sh.on[slot]),slot))continue;
  const candidate=sh.bench.map(id=>matchPlayer(l,side,id)).filter(p=>p&&frontAvailable(l,side,p.id)&&slotEligible(p,slot)).sort((a,b)=>fitScore(b)-fitScore(a))[0];
  if(!candidate)continue;
  const red=sh.redCards.find(c=>c.slot===slot&&!c.filled&&c.until!==null&&c.until<=l.minute);
  // An expired red may be filled directly, without sacrificing another player.
  if(red){sh.on[slot]=candidate.id;sh.bench=sh.bench.filter(id=>id!==candidate.id);red.filled=true;recordFrontMove(l,side,red.id,candidate.id,'red20');addEvent(l,`${candidate.name} entre après les vingt minutes d’exclusion collective et permet de disputer les mêlées.`,'sub');continue}
  const donor=frontDonor(l,side);if(!donor)continue;
  const caseIndex=f.exclusions.map((e,i)=>({e,i})).filter(x=>x.e.slot===slot&&!x.e.closed).at(-1)?.i;
  if(caseIndex===undefined)continue;
  sh.on[donor.slot]=null;sh.bench=sh.bench.filter(id=>id!==candidate.id);sh.bench.push(donor.id);sh.on[slot]=candidate.id;
  f.exclusions[caseIndex].releaseSlot=donor.slot;f.held.push({id:donor.id,slot:donor.slot,caseIndex,mode:'cover'});
  recordFrontMove(l,side,donor.id,candidate.id,'frontcover');
  addEvent(l,`${S.clubs[l.pair[side]].abbr} · ${candidate.name} entre au poste de ${POS[slot].toLowerCase()}. Le staff fait sortir ${donor.p.name} pour conserver une première ligne qualifiée, sans rétablir l’effectif.`,'sub');
 }
 const uncontested=[0,1,2].some(slot=>!sh.on[slot]||!frontAvailable(l,side,sh.on[slot])||!slotEligible(matchPlayer(l,side,sh.on[slot]),slot));
 if(uncontested!==f.uncontested)addEvent(l,`${S.clubs[l.pair[side]].abbr} : ${uncontested?'carence en première ligne. Les mêlées deviennent non disputées ; la réduction supplémentaire d’effectif s’applique.':'une première ligne qualifiée est disponible. Les mêlées peuvent de nouveau être disputées.'}`,'card');
 f.uncontested=uncontested;
 const target=frontTarget(l,side);
 // The nominated player may already have returned as an ordinary replacement
 // following a permanent exclusion. Fill the actual vacant position, rather
 // than assuming that the same nominated player is still waiting on the bench.
 for(const red of sh.redCards.filter(c=>c.slot<3&&!c.filled&&c.until!==null&&c.until<=l.minute)){
  if(activePlayers(l,side).length>=target)break;
  const source=f.exclusions[red.frontCase],vacancies=[source.releaseSlot,...sh.on.map((id,i)=>id===null?i:null)].filter((slot,i,a)=>Number.isInteger(slot)&&sh.on[slot]===null&&a.indexOf(slot)===i&&!f.held.some(h=>h.slot===slot&&frontCaseActive(l,f.exclusions[h.caseIndex],'yellow')));
  for(const slot of vacancies){
   const candidate=sh.bench.map(id=>matchPlayer(l,side,id)).filter(p=>p&&frontAvailable(l,side,p.id)&&slotEligible(p,slot)&&!f.held.some(h=>h.id===p.id&&frontCaseActive(l,f.exclusions[h.caseIndex],'yellow'))).sort((a,b)=>fitScore(b)-fitScore(a))[0];
   if(!candidate)continue;
   sh.on[slot]=candidate.id;sh.bench=sh.bench.filter(id=>id!==candidate.id);f.held=f.held.filter(h=>h.slot!==slot&&h.id!==candidate.id);red.filled=true;
   recordFrontMove(l,side,red.id,candidate.id,'red20');addEvent(l,`${candidate.name} entre après les vingt minutes d’exclusion collective. Le joueur exclu ne revient pas.`,'sub');break;
  }
 }
 // Restore only the places made available by the end of a suspension or the
 // removal of the uncontested-scrum deduction. Never restore the sent-off player.
 for(const h of [...f.held]){
  if(activePlayers(l,side).length>=target)break;
  const e=f.exclusions[h.caseIndex],red=frontRed(l,side,e);
  if(sh.on[h.slot]||!sh.bench.includes(h.id)||!frontAvailable(l,side,h.id)||frontCaseActive(l,e,'yellow'))continue;
  const redReady=red&&!red.filled&&red.until!==null&&red.until<=l.minute;
  if(h.mode==='cover'&&e.kind!=='yellow'&&!redReady)continue;
  if(h.mode==='carence'&&f.uncontested&&!redReady)continue;
  sh.bench=sh.bench.filter(id=>id!==h.id);sh.on[h.slot]=h.id;f.held=f.held.filter(x=>x!==h);
  if(redReady)red.filled=true;
  recordFrontMove(l,side,e.id,h.id,redReady?'red20':'frontrelease');
  addEvent(l,`${matchPlayer(l,side,h.id).name} revient après l’ajustement de première ligne${redReady?' et la fin des vingt minutes d’exclusion collective':''}.`,'sub');
 }
 while(activePlayers(l,side).length>target){
  const donor=frontDonor(l,side);if(!donor)break;
  const caseIndex=f.exclusions.length-1;
  sh.on[donor.slot]=null;sh.bench.push(donor.id);f.held.push({id:donor.id,slot:donor.slot,caseIndex,mode:'carence'});
  addEvent(l,`${donor.p.name} doit également sortir en raison de la carence. ${S.clubs[l.pair[side]].abbr} joue à ${activePlayers(l,side).length}.`,'card');
 }
}
function resolveFrontExpiries(l,side){
 const f=l.sheets[side].front;
 if(f.exclusions.some(e=>e.until!==null&&e.until<=l.minute&&(!e.closed&&e.kind==='yellow'||e.kind==='red20'&&!frontRed(l,side,e)?.filled)))reconcileFrontRow(l,side);
}
function uncontestedParticipants(l,side){
 const active=activePlayers(l,side);
 if(active.length<8)return [];
 return [...active].sort((a,b)=>(a.fam<=1?0:a.fam<=3?1:2)-(b.fam<=1?0:b.fam<=3?1:2)).slice(0,8).map(p=>p.id);
}
function prepareFrontRows(l){for(let side=0;side<2;side++)reconcileFrontRow(l,side,true)}
function frontRowPanel(l,side){
 const sh=l.sheets[side],f=sh.front;
 return `<div class="notice"><strong>${activePlayers(l,side).length} joueurs sur le terrain</strong> · ${f.uncontested?'Mêlées non disputées':'Mêlées disputées si les spécialistes sont disponibles'}.${f.held.length?'<br>'+f.held.map(h=>`${matchPlayer(l,side,h.id)?.name||'Un joueur'} : ${h.mode==='cover'?'sortie pour l’entrée d’un spécialiste':'sortie supplémentaire pour carence'}.`).join('<br>'):''}</div><p class="help">À la prochaine mêlée, le staff organise automatiquement l’entrée d’un spécialiste et désigne le joueur à sortir. Ces ajustements ne consomment pas les quatre retours tactiques.</p>`;
}
