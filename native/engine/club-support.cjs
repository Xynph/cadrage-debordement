'use strict';
const files=Object.freeze(['staff-meeting-v65.js','staff-advisor-v66.js','training-plans-v67.js','medical-decisions-v68.js','briefing-strategique-v69.js','bureau-agents-v71.js']);
const commands=Object.freeze(['staff_meeting','training_plan','medical_protocol','medical_return','strategic_briefing','agent_negotiate','agent_confirm']);
function factory(){
 const copy=x=>JSON.parse(JSON.stringify(x)),obj=x=>!!x&&typeof x==='object'&&!Array.isArray(x),keys=(x,list)=>obj(x)&&Object.keys(x).every(k=>list.includes(k)),int=(x,a,b)=>Number.isInteger(x)&&x>=a&&x<=b;
 const check=(ok,message='État staff, médical ou agents invalide.')=>{if(!ok)throw Error(message);};
 const world=s=>typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s);
 const week=s=>s.franceMode?.version===1?s.franceMode.week:s.round,context=s=>({season:s.season,week:week(s),club:s.club});
 const roster=s=>s.clubs[s.club].players;
 const sameContext=(a,b)=>a?.season===b.season&&a?.week===b.week&&a?.club===b.club;
 const meetingAvailable=()=>CDStaffMeetingV65.available(S)&&!sameContext(S.nativeSupport?.meeting?.context,context(S));
 const bridge=()=>({reservation:reservationWage,fee:contractFee,negotiate:negotiateContract,save:()=>true});
 // ---------------------------------------------------------------- Protocole commotion (rugby d'élite, World Rugby)
 // Règles en vigueur depuis le 1er juillet 2022 (World Rugby, « Vast majority of players diagnosed with concussion likely
 // to miss their next match », https://www.world.rugby/news/726094 et https://www.world.rugby/news/730239 ; détail des
 // critères : SA Rugby, « Changes to return to play guidelines following concussion explained, elite HIA tournaments only »,
 // 2022, https://www.sarugby.co.za/media/lg0owndp/changes-to-return-to-play-guidelines-following-concussion-explained-for-elite-hia-tournaments-only-2022.pdf) :
 //  - signes évidents (critère 1) : sortie définitive immédiate, commotion, 12 jours de repos au moins ;
 //  - choc suspect : HIA1 hors du terrain (12 minutes) avec remplacement temporaire ; retour s'il passe le test ;
 //  - HIA2 le soir, HIA3 à 36-48 h : commotion diagnostiquée -> 12 jours au moins avant de rejouer ; exception à 7 jours
 //    seulement sans antécédent, commotion de critère 2 ou différée, HIA3 revenu à la normale et avis favorable d'un
 //    spécialiste indépendant ; décision médicale, jamais celle du staff.
 //  - antécédent (SCRM) : commotion dans les 3 derniers mois, 3 commotions ou plus sur 12 mois (la nouvelle comprise :
 //    lecture prudente), 5 ou plus en carrière. Les autres cas (récupération de plus de 21 jours, seuil d'impact abaissé,
 //    troubles psychologiques) ne sont pas suivis par le jeu.
 // Proportions : Fuller et al., « The performance of the World Rugby Head Injury Assessment Screening Tool », Sports
 // Medicine, 2020 (https://eprints.whiterose.ac.uk/155999/) : 1 739 chocs à la tête, dont 499 de critère 1 ; au HIA1,
 // 433 sortis sur 1 118 (38,7 %), commotion confirmée pour 343 d'entre eux (79,2 %) et pour 105 des 685 joueurs
 // revenus (15,3 %, diagnostic différé au HIA2 ou au HIA3).
 // Fréquence (hypothèse prudente, pas de chiffre public par match) : 0,9 choc à la tête évalué par match, soit environ
 // 0,52 commotion confirmée par match ou 13 pour 1 000 heures-joueur, entre les 8,9 /1 000 h de la Premiership 2012-14
 // (Cross et al., BJSM 2016, https://pmc.ncbi.nlm.nih.gov/articles/PMC4975843) et la vingtaine de saisons plus récentes.
 // Non publiés, donc réglés prudemment à une chance sur deux : HIA3 revenu à la normale, avis favorable du spécialiste.
 // Tirages sans aléa du moteur (empreinte de la carrière, de la rencontre et du joueur) : le flux Math.random et les
 // rencontres sans choc ne changent pas.
 const COMMOTION=Object.freeze({parMinute:.9/80,critere1:499/1739,hia1Echec:433/1118,confirmeApresEchec:343/433,differe:105/685,hia3Normal:.5,avisFavorable:.5,repos:12,exception:7,evaluation:12,historique:8});
 const DAY=86400000,isoDate=x=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&new Date(x+'T00:00:00Z').toISOString().slice(0,10)===x;
 const shiftDate=(iso,n)=>new Date(Date.parse(iso+'T00:00:00Z')+n*DAY).toISOString().slice(0,10),daysBetween=(a,b)=>Math.round((Date.parse(b+'T00:00:00Z')-Date.parse(a+'T00:00:00Z'))/DAY);
 function mix(text){let h=0x811c9dc5;for(let i=0;i<text.length;i++){h^=text.charCodeAt(i);h=Math.imul(h,0x01000193)>>>0;}h^=h>>>16;h=Math.imul(h,0x85ebca6b)>>>0;h^=h>>>13;h=Math.imul(h,0xc2b2ae35)>>>0;h^=h>>>16;return h>>>0;}
 const careerSalt=s=>String(s?.careerVariation?.seed??s?.leagueDetail?.salt??s?.commonDatabase?.id??'cd');
 const draw=(s,key)=>mix('commotion|'+careerSalt(s)+'|'+key)/4294967296;
 const calendarDay=s=>{try{return typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s)?CDWorldCareer.calendarToday(s):null;}catch(e){return null;}};
 // Jour de référence des disponibilités : aujourd'hui (calendrier journalier) ; en cadence hebdomadaire, le jour du match
 // du club dans la semaine en cours (la semaine n'a pas d'autre jour), sinon son lundi.
 const referenceDay=s=>{const d=calendarDay(s);if(!d||s.worldMode?.day!==undefined)return d;try{return CDWorldCareer.userFixture(s)?.date||d;}catch(e){return d;}};
 const protocolOf=p=>p?.commotion?.protocole||null;
 const MOTIFS=Object.freeze({1:'signes évidents de commotion, sortie définitive',2:'évaluation HIA non concluante pendant le match',3:'commotion diagnostiquée après le match (HIA2 ou HIA3)'});
 // Antécédent au sens de World Rugby, lu avant d'inscrire la commotion du `date`.
 function antecedent(c,date){
  const prior=(c?.hist||[]).map(h=>h.date).filter(d=>d<date);
  return prior.some(d=>daysBetween(d,date)<=91)||prior.filter(d=>daysBetween(d,date)<=365).length>=2||(Number(c?.n)||0)+1>=5;
 }
 // Disponibilité au jour `ref` : indisponible (blessure en semaines arrondies) jusqu'à la veille du retour.
 function syncPlayer(p,ref){
  const prot=protocolOf(p);if(!prot||!isoDate(ref))return false;
  const left=daysBetween(ref,prot.retour);
  if(left>0){const weeks=Math.ceil(left/7);if(p.injury!==weeks){p.injury=weeks;return true;}return false;}
  p.commotion.protocole=null;if(p.injury)p.injury=0;return true;
 }
 function syncAt(s,ref,clubIds=null){
  if(!s||!isoDate(ref))return 0;let n=0;
  for(const c of clubIds?clubIds.map(id=>s.clubs[id]).filter(Boolean):s.clubs)for(const p of c.players)if(p.commotion?.protocole&&syncPlayer(p,ref))n++;
  return n;
 }
 // Avis du spécialiste indépendant (exception à 7 jours) : résultat déterministe, sans garantie.
 function specialistReview(s,p){
  const prot=protocolOf(p);if(!prot||prot.exception!=='possible')return null;
  const favorable=draw(s,'avis|'+p.id+'|'+prot.date)<COMMOTION.avisFavorable;
  prot.exception=favorable?'accordee':'refusee';
  if(favorable){prot.retour=shiftDate(prot.date,COMMOTION.exception);prot.jours=COMMOTION.exception;const last=p.commotion.hist[p.commotion.hist.length-1];if(last&&last.date===prot.date)last.retour=prot.retour;}
  const ref=referenceDay(s);if(ref)syncPlayer(p,ref);
  return {favorable,retour:prot.retour,jours:prot.jours};
 }
 // Commotion confirmée : repos de 12 jours (ou plus long avec une blessure du même match), antécédents mis à jour.
 // Les clubs de l'IA demandent l'avis du spécialiste dès que l'exception est ouverte ; le club du manager le fait par
 // le courrier du médecin.
 function diagnose(s,clubId,p,date,critere,cle){
  if(!s||!p||!isoDate(date)||![1,2,3].includes(critere))return false;
  const c=p.commotion||{version:1,n:0,hist:[],protocole:null};
  if(c.protocole?.date===date||c.hist.some(h=>h.date===date))return false;
  const ante=antecedent(c,date),weeks=Math.max(0,Number(p.injury)||0);
  const exception=critere!==1&&!ante&&!weeks&&draw(s,'hia3|'+p.id+'|'+date+'|'+cle)<COMMOTION.hia3Normal?'possible':'non';
  const retour=shiftDate(date,Math.max(COMMOTION.repos,weeks*7));
  c.n=Math.min(99,c.n+1);c.hist=[...c.hist,{date,retour}].slice(-COMMOTION.historique);
  c.protocole={date,retour,jours:COMMOTION.repos,critere,exception,antecedent:ante};
  p.commotion=c;
  if(clubId!==s.club&&exception==='possible')specialistReview(s,p);
  const ref=referenceDay(s);syncPlayer(p,ref&&ref>date?ref:date);
  return true;
 }
 // --- En match (dist/rugby.js, advanceRugby puis applyMatchInjuries) : carrière Monde, règles du rugby pro.
 const matchKey=l=>l?.worldContext?.id?[S.season,l.worldContext.id,l.pair.join('-')].join('|'):null;
 const hiaHeld=(l,side,id)=>!!l.hia&&l.hia.some(h=>h.side===side&&h.id===id&&(h.etat==='en_cours'||h.etat==='definitif'));
 function swap(l,side,slot,incoming,reason){
  const sh=l.sheets[side],out=sh.on[slot],returning=sh.used.includes(incoming);
  sh.bench=sh.bench.filter(id=>id!==incoming);sh.bench.push(out);sh.on[slot]=incoming;
  if(frontRowRules(l))sh.front.held=sh.front.held.filter(h=>h.id!==incoming);
  if(!returning)sh.used.push(incoming);
  sh.subs++;l.subs.push({minute:l.minute,side,out,in:incoming,reason,returning});
 }
 const nameOf=(l,side,id)=>matchPlayer(l,side,id)?.name||'Le joueur',abbrOf=(l,side)=>S.clubs[l.pair[side]].abbr;
 // Fin de l'évaluation HIA1 (12 minutes) : retour sur le terrain s'il la passe, sinon sortie définitive.
 function resolveHia(l,h,silent=false){
  if(h.etat!=='en_cours')return;
  const sh=l.sheets[h.side],key=matchKey(l)||'',pass=draw(S,'hia1|'+key+'|'+h.minute+'|'+h.id)>=COMMOTION.hia1Echec;
  if(!pass){h.etat='definitif';if(!silent)addEvent(l,`${abbrOf(l,h.side)} · ${nameOf(l,h.side,h.id)} ne reviendra pas : son évaluation HIA n’est pas concluante.`,'sub',{team:h.side,actor:h.id});return;}
  const current=sh.on[h.slot],p=matchPlayer(l,h.side,h.id);
  const free=!silent&&!l.finished&&current&&!sh.cards.some(c=>c.id===current&&c.until>l.minute)&&sh.bench.includes(h.id)&&!sh.sentOff.includes(h.id)&&slotEligible(p,h.slot)&&!(frontRowRules(l)&&h.slot<3&&sh.front.exclusions.some(e=>e.slot===h.slot&&!e.closed));
  if(free){swap(l,h.side,h.slot,h.id,'hia-retour');h.etat='retour';addEvent(l,`${abbrOf(l,h.side)} · ${p.name} a passé son évaluation HIA : il revient en jeu à la place de ${nameOf(l,h.side,current)}.`,'sub',{team:h.side,actor:h.id});}
  else{h.etat='apte';if(!silent)addEvent(l,`${abbrOf(l,h.side)} · ${nameOf(l,h.side,h.id)} a passé son évaluation HIA.`,'sub',{team:h.side,actor:h.id});}
 }
 function matchMinute(l){
  if(!l||l.finished||typeof CDWorldCareer==='undefined'||!CDWorldCareer.active(S))return;
  if(l.hiaVersion===undefined){if(l.minute!==1||!l.worldContext||!revisedRules(l))return;l.hiaVersion=1;l.hia=[];}
  if(l.hiaVersion!==1)return;
  for(const h of l.hia)if(h.etat==='en_cours'&&h.until<=l.minute)resolveHia(l,h);
  const key=matchKey(l);if(!key||draw(S,'choc|'+key+'|'+l.minute)>=COMMOTION.parMinute)return;
  const cands=[];
  for(const side of [0,1]){const sh=l.sheets[side];for(const p of activePlayers(l,side)){const slot=sh.on.indexOf(p.id);if(slot>=0&&eligibleChanges(l,side,slot).length)cands.push({side,slot,p});}}
  if(!cands.length)return;
  const v=cands[Math.min(cands.length-1,Math.floor(draw(S,'joueur|'+key+'|'+l.minute)*cands.length))];
  startHia(l,v.side,v.slot,draw(S,'critere|'+key+'|'+l.minute)<COMMOTION.critere1);
 }
 // Choc à la tête du joueur du poste `slot` à la minute en cours : sortie définitive (signes évidents) ou évaluation
 // HIA1 avec remplacement temporaire par le remplaçant le plus apte au poste. Rend l'entrée ajoutée, ou null.
 function startHia(l,side,slot,evident){
  if(l?.hiaVersion!==1||l.finished)return null;
  const sh=l.sheets[side],p=matchPlayer(l,side,sh.on[slot]);
  if(!p||sh.cards.some(c=>c.id===p.id&&c.until>l.minute))return null;
  const options=eligibleChanges(l,side,slot).sort((a,b)=>fitScore(b,FAMILIES[slot])-fitScore(a,FAMILIES[slot])||String(a.id).localeCompare(String(b.id))),repl=options[0];
  if(!repl)return null;
  swap(l,side,slot,repl.id,evident?'commotion':'hia');
  const h={side,id:p.id,slot,minute:l.minute,kind:evident?'evident':'hia1',repl:repl.id,until:evident?null:l.minute+COMMOTION.evaluation,etat:evident?'definitif':'en_cours'};
  l.hia.push(h);
  addEvent(l,evident?`${abbrOf(l,side)} · Choc à la tête : ${p.name} présente des signes évidents de commotion. Sortie définitive, ${repl.name} le remplace.`:`${abbrOf(l,side)} · Choc à la tête : ${p.name} sort pour une évaluation HIA, ${repl.name} le remplace temporairement.`,'sub',{team:side,actor:p.id});
  // Équipe du manager : il peut choisir un autre remplaçant que celui du staff (native/engine/incidents-match.cjs).
  if(typeof nativeSystems!=='undefined')nativeSystems.domain('matchIncidents')?.offer(l,{type:'entrant',kind:evident?'commotion':'hia',side,slot,sortant:p.id,entrant:repl.id,options:options.map(q=>q.id)});
  return h;
 }
 // Après le match (HIA2 le soir, HIA3 à 36-48 h) : commotions confirmées, repos, antécédents.
 function afterMatch(l){
  if(l?.hiaVersion!==1||l.hiaDiagnosed)return 0;l.hiaDiagnosed=true;
  const key=matchKey(l)||'',date=l.worldContext?.date||calendarDay(S);let n=0;
  for(const h of l.hia){
   resolveHia(l,h,true);
   const p=matchPlayer(l,h.side,h.id);if(!p)continue;
   const critere=h.kind==='evident'?1:h.etat==='definitif'?(draw(S,'hia2|'+key+'|'+h.id)<COMMOTION.confirmeApresEchec?2:0):(draw(S,'differe|'+key+'|'+h.id)<COMMOTION.differe?3:0);
   if(critere&&diagnose(S,l.pair[h.side],p,date,critere,key))n++;
  }
  return n;
 }
 // Résultat rapide (league-detail.cjs) : mêmes proportions, sans déroulé ; joueurs ayant joué, pondérés par leurs minutes.
 function quickMatch(s,f,clubId,minutes){
  if(!s||!f?.id||!isoDate(f.date))return 0;
  const key=[s.season,f.id,clubId].join('|'),played=[...minutes].filter(([,m])=>m>0).sort((a,b)=>String(a[0]).localeCompare(String(b[0])));
  if(!played.length)return 0;
  const lambda=COMMOTION.parMinute*80/2,u=draw(s,'rapide|'+key),p0=Math.exp(-lambda),events=u<p0?0:u<p0*(1+lambda)?1:2,total=played.reduce((a,[,m])=>a+m,0);
  let n=0;
  for(let k=0;k<events;k++){
   let x=draw(s,'rapide-joueur|'+key+'|'+k)*total,id=played[played.length-1][0];
   for(const [pid,m] of played){if(x<m){id=pid;break;}x-=m;}
   const p=s.clubs[clubId].players.find(q=>q.id===id);if(!p)continue;
   const t=draw(s,'rapide-type|'+key+'|'+k);
   const critere=t<COMMOTION.critere1?1:draw(s,'rapide-hia1|'+key+'|'+k)<COMMOTION.hia1Echec?(draw(s,'rapide-hia2|'+key+'|'+k)<COMMOTION.confirmeApresEchec?2:0):(draw(s,'rapide-differe|'+key+'|'+k)<COMMOTION.differe?3:0);
   if(critere&&diagnose(s,clubId,p,f.date,critere,'rapide|'+key+'|'+k))n++;
  }
  return n;
 }
 // Matchs du club du manager manqués pendant un protocole (le courrier « temps de jeu » ne les compte pas).
 function missedMatches(s,p,results){
  const hist=p?.commotion?.hist||[];if(!hist.length)return 0;
  return results.filter(r=>r.date&&hist.some(h=>r.date>h.date&&r.date<h.retour)).length;
 }
 function commotionRow(s,p){
  const prot=protocolOf(p),ref=calendarDay(s);
  return {id:p.id,date:prot.date,retour:prot.retour,jours:prot.jours,joursRestants:ref?Math.max(0,daysBetween(ref,prot.retour)):null,critere:prot.critere,motif:MOTIFS[prot.critere],exception:prot.exception,antecedent:prot.antecedent,commotions:p.commotion.n};
 }
 const commotion=Object.freeze({RULES:COMMOTION,MOTIFS,minute:matchMinute,startHia,afterMatch,quickMatch,diagnose,syncAt,syncPlayer,specialistReview,protocol:protocolOf,held:hiaHeld,missedMatches,row:commotionRow,today:calendarDay,shiftDate,daysBetween});
 function validate(s){
  if(!s)return true;
  const max=world(s)?CDWorldCareer.sizing(s).maxRound:s.franceMode?.version===1?34:29,date=(season,w)=>int(season,1,s.season)&&int(w,0,max)&&(season<s.season||w<=week(s)),serialDate=(season,w)=>int(season,1,s.season)&&int(w,0,s.economy.week);
  if(s.nativeSupport!==undefined){const n=s.nativeSupport,m=n.meeting;check(keys(n,['version','meeting'])&&Object.keys(n).length===2&&n.version===1&&keys(m,['context','plan'])&&Object.keys(m).length===2&&keys(m.context,['season','week','club'])&&Object.keys(m.context).length===3&&date(m.context.season,m.context.week)&&int(m.context.club,0,s.clubs.length-1)&&Object.hasOwn(CDStaffMeetingV65.OPTIONS,m.plan),'Décision de staff native invalide.');}
  const meetings=new Set();for(const receipt of s.manager?.inbox||[]){if(receipt.kind!=='staff-v65')continue;const key=receipt.season+':'+receipt.week;check(!meetings.has(key)&&Object.values(CDStaffMeetingV65.OPTIONS).some(o=>receipt.title==='Réunion de staff : '+o.label)&&serialDate(receipt.season,receipt.week),'Compte rendu de staff V65 invalide.');meetings.add(key);}
  const concussion=p=>{if(p.commotion===undefined)return;const c=p.commotion,prot=c.protocole;
   check(keys(c,['version','n','hist','protocole'])&&Object.keys(c).length===4&&c.version===1&&int(c.n,1,99)&&Array.isArray(c.hist)&&c.hist.length>=1&&c.hist.length<=Math.min(c.n,COMMOTION.historique)&&c.hist.every((h,i)=>keys(h,['date','retour'])&&Object.keys(h).length===2&&isoDate(h.date)&&isoDate(h.retour)&&h.retour>h.date&&(i===0||c.hist[i-1].date<h.date)),'Antécédents de commotion invalides.');
   if(prot!==null)check(keys(prot,['date','retour','jours','critere','exception','antecedent'])&&Object.keys(prot).length===6&&isoDate(prot.date)&&isoDate(prot.retour)&&[COMMOTION.exception,COMMOTION.repos].includes(prot.jours)&&daysBetween(prot.date,prot.retour)>=prot.jours&&[1,2,3].includes(prot.critere)&&['non','possible','accordee','refusee'].includes(prot.exception)&&typeof prot.antecedent==='boolean'&&(prot.jours===COMMOTION.repos||prot.exception==='accordee')&&(prot.exception==='non'||prot.critere!==1&&!prot.antecedent)&&c.hist.some(h=>h.date===prot.date&&h.retour===prot.retour),'Protocole commotion invalide.');};
  const medical=p=>{if(p.medicalV68===undefined)return;const m=p.medicalV68;check(keys(m,['version','protocol','stage'])&&Object.keys(m).length===3&&m.version===1&&Object.hasOwn(CDMedicalV68.PROTOCOLS,m.protocol)&&['blesse','reprise','progressif','termine'].includes(m.stage),'État médical V68 invalide.');};
  for(const c of s.clubs)for(const p of c.players){medical(p);concussion(p);}
  for(const p of [...(s.market||[]),...(s.economy?.freeAgents||[]),...(s.development?.academy||[])]){medical(p);concussion(p);}
  if(s.v71AgentDesk!==undefined){
   const d=s.v71AgentDesk;check(keys(d,['version','history'])&&Object.keys(d).length===2&&d.version===1&&Array.isArray(d.history)&&d.history.length<=24,'Historique des agents V71 invalide.');
   const seen=new Set();let prior=Infinity;
   for(const h of d.history){check(keys(h,['id','season','week','years','policy','wage','status','attempt'])&&Object.keys(h).length===8&&typeof h.id==='string'&&/^[A-Za-z0-9:_-]{1,180}$/.test(h.id)&&serialDate(h.season,h.week)&&int(h.years,1,3)&&Object.hasOwn(CDAgentsV71.POLICY,h.policy)&&int(h.wage,1000,100000)&&['ready','counter','withdrawn','signed'].includes(h.status)&&int(h.attempt,1,3),'Mandat d’agent V71 invalide.');const stamp=h.season*100+h.week,key=stamp+':'+h.id+':'+h.attempt;check(stamp<=prior&&!seen.has(key),'Mandat d’agent répété ou mal daté.');seen.add(key);prior=stamp;}
  }
  if(s.v69Briefing!==undefined){
   const b=s.v69Briefing,m=typeof b.context==='string'&&b.context.match(/^(\d+):(\d+):(league|barrage|semi|final):(\d+):(\d+)$/);check(keys(b,['version','context','plan'])&&Object.keys(b).length===3&&b.version===1&&Object.hasOwn(V69_PLANS,b.plan)&&m&&date(+m[1],+m[2])&&int(+m[4],0,s.clubs.length-1)&&int(+m[5],0,s.clubs.length-1)&&m[4]!==m[5],'Briefing stratégique V69 invalide.');
  }
  if(s.live?.v69Briefing!==undefined){const b=s.live.v69Briefing;check(keys(b,['version','plan','side','opponent','strength'])&&Object.keys(b).length===5&&b.version===1&&Object.hasOwn(V69_PLANS,b.plan)&&int(b.side,0,1)&&s.live.pair[1-b.side]===b.opponent&&keys(b.strength,['pack','backs','danger'])&&Object.keys(b.strength).length===3&&Object.values(b.strength).every(x=>int(x,-100,100)),'Briefing de match V69 invalide.');}
  return true;
 }
 function project(){
  if(!S)return null;
  const engine={outcome:physicalTrainingOutcome,collectiveDecision:staffTrainingDecision,trainingReceipt:staffTrainingReceipt,...(typeof intensiteAutoPour==='function'?{autoMode:intensiteAutoPour}:{})};
  const session=CDTrainingPlansV67.session(S,engine);
  const plans=session.status==='applied'?[]:Object.entries(CDTrainingPlansV67.PLANS).map(([key,p])=>{const preview=copy(CDTrainingPlansV67.preview(S,key,engine));for(const row of preview.players)delete row.name;return {...copy(p),...preview};});
  const dossier=!S.live&&S.phase!=='ended'?matchDossier():null;
  // Devis d'agents (le plus coûteux) : partie mémorisée à part (state-versions.cjs, part) ; une décision qui ne touche
  // ni contrats, ni salaires, ni effectif (charge, délégation…) les reprend.
  const quotes=()=>roster(S).map(p=>({id:p.id,contractEnd:p.contractEnd,salary:p.salary,quotes:[1,2,3].flatMap(years=>Object.keys(CDAgentsV71.POLICY).map(policy=>CDAgentsV71.quote(S,p.id,years,policy,bridge())).filter(Boolean).map(q=>{const result=copy(q);delete result.name;return result;}))})).filter(p=>p.quotes.length);
  const players=typeof nativeStateVersions!=='undefined'?nativeStateVersions.part('clubSupport.agents',quotes):quotes();
  return {context:context(S),notice:'Arbitrages fictifs du jeu. Commotions : protocole HIA de World Rugby, repos de 12 jours au moins décidé par le médecin, sans arbitrage du staff. Les budgets sont fictifs.',diagnostic:{...copy(CDStaffAdvisorV66.diagnostic(S,CDStaffMeetingV65)),available:meetingAvailable()},meeting:{available:meetingAvailable(),receipt:copy(CDStaffMeetingV65.currentMeeting(S)),lastDecision:copy(S.nativeSupport?.meeting||null),options:Object.entries(CDStaffMeetingV65.OPTIONS).map(([key,o])=>({key,...copy(o),preview:copy(CDStaffMeetingV65.preview(S,key))}))},training:{available:CDTrainingPlansV67.allowed(S),plans,session},medical:{available:CDMedicalV68.canManage(S),protocols:Object.entries(CDMedicalV68.PROTOCOLS).map(([key,p])=>({key,...copy(p)})),commotions:roster(S).filter(p=>protocolOf(p)).map(p=>commotionRow(S,p)),antecedents:roster(S).filter(p=>p.commotion).map(p=>({id:p.id,commotions:p.commotion.n,derniere:p.commotion.hist[p.commotion.hist.length-1].date,enCours:!!protocolOf(p)})),players:roster(S).filter(p=>!protocolOf(p)&&(p.injury>0||p.medicalV68?.stage==='reprise')).map(p=>({id:p.id,injury:p.injury,condition:p.condition,fatigue:p.physicalLoad?.fatigue??0,protocol:CDMedicalV68.treatment(p),stage:p.medicalV68?.stage??'blesse'}))},briefing:{available:!!dossier,fixture:dossier?v69Context(dossier):null,opponentId:dossier?.opponent.id??null,selected:dossier?v69Selection(dossier):'neutre',evidence:dossier?copy(v69Evidence(dossier)):null,plans:Object.entries(V69_PLANS).map(([key,p])=>({key,...copy(p)}))},agents:{players,policies:Object.entries(CDAgentsV71.POLICY).map(([key,p])=>({key,label:p.label,detail:p.detail})),history:copy(S.v71AgentDesk?.history||[]),talks:Object.entries(S.economy?.talks||{}).filter(([,t])=>t.kind==='renew').map(([key,t])=>({key,...copy(t)}))}};
 }
 function execute(command,payload){
  check(!!S,'Crée ou importe une carrière.');check(!S.live&&S.phase!=='ended','Décision indisponible pendant un match ou après la saison.');validate(S);
  const fields={staff_meeting:['plan'],training_plan:['plan'],medical_protocol:['id','protocol'],medical_return:['id','choice'],strategic_briefing:['plan','fixture'],agent_negotiate:['id','years','policy'],agent_confirm:['key','confirmed','wage','years','fee']};
  check(Object.hasOwn(fields,command),'Commande de support inconnue.');check(keys(payload,['context',...fields[command]])&&Object.keys(payload).length===fields[command].length+1&&keys(payload.context,['season','week','club'])&&Object.keys(payload.context).length===3,'Paramètres de support invalides.');
  check(sameContext(payload.context,context(S)),'Décision périmée : consulte la semaine actuelle.');
  const callbacks={save:()=>true};let ok=false;
  if(command==='staff_meeting'){check(typeof payload.plan==='string'&&Object.hasOwn(CDStaffMeetingV65.OPTIONS,payload.plan),'Arbitrage de staff invalide.');check(meetingAvailable(),'Réunion de staff déjà réalisée ou indisponible.');ok=CDStaffMeetingV65.perform(S,payload.plan,{...callbacks,message:managerMessage});if(ok)S.nativeSupport={version:1,meeting:{context:context(S),plan:payload.plan}};}
  if(command==='training_plan'){check(typeof payload.plan==='string'&&Object.hasOwn(CDTrainingPlansV67.PLANS,payload.plan),'Plan de travail invalide.');ok=CDTrainingPlansV67.apply(S,payload.plan,{...callbacks,outcome:physicalTrainingOutcome});}
  if(command==='medical_protocol'||command==='medical_return'){check(typeof payload.id==='string'&&roster(S).some(p=>p.id===payload.id),'Joueur absent de l’effectif.');check(!protocolOf(roster(S).find(p=>p.id===payload.id)),'Protocole commotion : la reprise est une décision médicale.');check(command==='medical_protocol'?typeof payload.protocol==='string'&&Object.hasOwn(CDMedicalV68.PROTOCOLS,payload.protocol):['progressif','complet'].includes(payload.choice),'Choix médical invalide.');ok=command==='medical_protocol'?CDMedicalV68.choose(S,payload.id,payload.protocol,callbacks):CDMedicalV68.returnToPlay(S,payload.id,payload.choice,callbacks);}
  if(command==='strategic_briefing'){const d=matchDossier();check(d&&payload.fixture===v69Context(d)&&Object.hasOwn(V69_PLANS,payload.plan),'Préparation de rencontre périmée.');S.v69Briefing={version:1,context:payload.fixture,plan:payload.plan};ok=true;}
  if(command==='agent_negotiate'){check(typeof payload.id==='string'&&roster(S).some(p=>p.id===payload.id)&&int(payload.years,1,3)&&Object.hasOwn(CDAgentsV71.POLICY,payload.policy),'Mandat d’agent invalide.');if(typeof preContratRefusProlongation==='function'){const parti=preContratRefusProlongation(payload.id);check(!parti,parti);}ok=CDAgentsV71.perform(S,payload.id,payload.years,payload.policy,bridge());}
  if(command==='agent_confirm'){check(payload.confirmed===true&&typeof payload.key==='string','Confirme la prime et l’engagement salarial.');const t=S.economy.talks[payload.key];check(t&&t.kind==='renew'&&payload.key===talkKey(t.id,'renew')&&['ready','counter'].includes(t.status)&&CDAgentsV71.eligible(S,roster(S).find(p=>p.id===t.id),t.years)&&payload.wage===t.acceptedSalary&&payload.years===t.years&&payload.fee===t.fee,'Accord contractuel périmé.');ok=confirmContract(payload.key);if(ok)CDAgentsV71.signed(S,payload.key);}
  check(ok,'Décision refusée : vérifie la phase, le joueur, le budget ou les tentatives restantes.');validate(S);return {supportDecision:command};
 }
 function installHooks(){
  if(trainWeek.__nativeSupportMedical)return true;
  // Joueurs en protocole commotion : hors des protocoles génériques (décision médicale), disponibilité recalée au jour.
  const prior=trainWeek,wrapped=function(...args){const state=S,trained=state?.trained,before=new Map((state?.clubs?.[state.club]?.players||[]).filter(p=>!protocolOf(p)).map(p=>[p.id,{injury:p.injury,protocol:CDMedicalV68.treatment(p)}]));const result=prior.apply(this,args);if(state&&S===state&&!trained&&state.trained){CDMedicalV68.completeTraining(state,before);const ref=referenceDay(state);if(ref)syncAt(state,ref);}return result;};wrapped.__nativeSupportMedical=true;trainWeek=wrapped;return true;
 }
 // Joueurs suivis par le médical (mêmes filtre, ordre et champs que project().medical.players, réduits à ceux que lit
 // l'observation des rendez-vous du club) : sans projeter tout le domaine (devis d'agents, plans, dossier de match).
 function medicalPlayers(){return S?roster(S).filter(p=>!protocolOf(p)&&(p.injury>0||p.medicalV68?.stage==='reprise')).map(p=>({id:p.id,injury:p.injury,stage:p.medicalV68?.stage??'blesse'})):[];}
 return {project,medicalPlayers,validate,execute,installHooks,commotion};
}
module.exports={files,commands,factory};
