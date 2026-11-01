'use strict';
const DIFFICULTIES={decouverte:['Découverte','Un entraîneur adverse au plan stable, avec des changements tardifs.'],classique:['Classique','Rotation, choix du style selon les qualités et la météo, adaptation à la mi-temps.'],expert:['Expert','Gestion du banc et des postes clés, adaptation au score et recherche des bonus.']};
const PENALTY_POLICIES={auto:'Selon le contexte',points:'Chercher les points',touch:'Chercher la pénaltouche'};
function normalizeOppositionSnapshot(state){if(!state.difficulty)state.difficulty='classique';if(state.defence===undefined)state.defence='equilibre';for(let c of state.clubs){if(c.morale===undefined){let value=75;for(let f of c.form)value=clamp(value+(f==='V'?6:f==='D'?-5:1),25,98);c.morale=value}}return state}
function setupOpposition(){if(S)normalizeOppositionSnapshot(S)}
function clubMorale(ci){return ci===S.club?S.morale:(S.clubs[ci].morale??75)}
function updateOppositionMorale(r){r.pair.forEach((ci,i)=>{if(ci===S.club)return;const diff=r.score[i]-r.score[1-i];S.clubs[ci].morale=clamp(clubMorale(ci)+(diff>0?6:diff<0?-5:1),25,98)})}
function difficultyLevel(l=null){return l?.aiLevel||S.difficulty||'classique'}
function managerStyle(ci){return ['conquete','large','occupation','equilibre'][ci%4]}
function sheetAverage(c,ids,key,filter=()=>true){let players=ids.map(id=>c.players.find(p=>p.id===id)).filter(p=>p&&filter(p));return players.length?mean(players.map(p=>skill(p,key,true))):25}
function styleScores(c,ids,weather){const backs=p=>p.fam>=4,forwards=p=>p.fam<=3;const pass=sheetAverage(c,ids,'pass',backs),speed=sheetAverage(c,ids,'speed',p=>p.fam>=6),power=sheetAverage(c,ids,'power',forwards),scrum=sheetAverage(c,ids,'scrum',p=>p.fam<=2),lineout=sheetAverage(c,ids,'lineout',p=>p.fam===1||p.fam===2),kick=sheetAverage(c,ids,'kick',p=>p.fam===4||p.fam===5||p.fam===8),mental=sheetAverage(c,ids,'mental'),tackle=sheetAverage(c,ids,'tackle');let scores={equilibre:(pass+power+tackle)/3,large:(pass+speed)/2-(weather==='Pluie'?11:0),conquete:(scrum+lineout+power)/3+(weather==='Pluie'?2:0),occupation:kick*.75+mental*.25-(weather==='Vent'?10:0)};scores[managerStyle(c.id)]+=5;return scores}
function chooseManagerStyle(c,ids,weather,level){if(level==='decouverte')return managerStyle(c.id);return Object.entries(styleScores(c,ids,weather)).sort((a,b)=>b[1]-a[1])[0][0]}
function strategicPlayerScore(p,slot,style,level,rest){const f=FAMILIES[slot];let n=roleNote(p,f)*(.32+p.condition*.0068);let specialized=style==='large'?skill(p,p.fam>=4?'pass':'tackle',true):style==='occupation'?skill(p,p.fam>=4?'kick':'tackle',true):style==='conquete'?skill(p,p.fam<=3?'power':'tackle',true):fitScore(p,f);n+=(specialized-roleNote(p,f))*.15;if(p.physicalLoad?.version===1)n-=Math.max(0,physicalLoadValue(p)-45)*.10;if(rest&&p.managerLoad?.streak>=3&&p.managerLoad.minutes>=65)n-=level==='expert'?3:2;if(level==='expert'&&p.age<=22&&p.condition>=90)n+=1;return n}
function managerSheet(c,opponent,weather,level){if(level==='decouverte')return buildSheet(c);let base=buildSheet(c),style=chooseManagerStyle(c,base.lineup,weather,level);const rest=opponent&&opponent.base<c.base-3;const used=new Set();let lineup=FAMILIES.map((_,i)=>{let p=c.players.filter(p=>!p.injury&&!used.has(p.id)&&slotEligible(p,i)).sort((a,b)=>strategicPlayerScore(b,i,style,level,rest)-strategicPlayerScore(a,i,style,level,rest))[0];if(p)used.add(p.id);return p?.id||null});let bench=BENCH_LABELS.map((_,i)=>{let choices=c.players.filter(p=>!p.injury&&!used.has(p.id)&&benchEligible(p,i));if(i===6){let flyhalves=choices.filter(p=>p.fam===5);if(flyhalves.length)choices=flyhalves}let p=choices.sort((a,b)=>{function value(p){let out=lineup.map(id=>c.players.find(x=>x.id===id)).filter(x=>x&&x.fam===p.fam);let tired=out.length?100-Math.min(...out.map(x=>x.condition)):0;let depth=i===7?tired*.15:0;return fitScore(p)+depth}return value(b)-value(a)})[0];if(p)used.add(p.id);return p?.id||null});return{lineup,bench}}
function initializeManagers(l,automated=false){l.aiLevel=S.difficulty||'classique';l.balanceVersion=2;l.managerMemory=[{lastSub:-10,lastReview:0,lastCardDiff:0,cardBase:null},{lastSub:-10,lastReview:0,lastCardDiff:0,cardBase:null}];l.numericalAiVersion=1;l.penaltyPolicies=['auto','auto'];for(let side=0;side<2;side++){if(side===l.userSide||l.pair[side]===S.club)continue;let c=S.clubs[l.pair[side]],other=S.clubs[l.pair[1-side]],sheet=managerSheet(c,other,l.weather,l.aiLevel);l.sheets[side]={...l.sheets[side],on:sheet.lineup,initial:[...sheet.lineup],bench:sheet.bench,used:sheet.lineup.filter(Boolean)};l.tactics[side]=chooseManagerStyle(c,sheet.lineup,l.weather,l.aiLevel)}}
// V20: an optional saved model: old in-progress fixtures keep their original AI.
// These are coaching choices in the simulation, not disciplinary regulations.
function adaptNumericalManager(l,side){
 if(l.numericalAiVersion!==1||!tacticalRules(l)||difficultyLevel(l)==='decouverte')return false;
 const memory=l.managerMemory?.[side];if(!memory)return false;
 const diff=activePlayers(l,side).length-activePlayers(l,1-side).length;
 if(memory.lastCardDiff===diff)return diff!==0;
 let attack,defence,reason;
 if(diff===0){
  if(memory.cardBase){
   attack=memory.cardBase.attack;defence=memory.cardBase.defence;
  }
  reason='le retour à égalité numérique';
  memory.cardBase=null;
 }else{
  if(!memory.cardBase)memory.cardBase={attack:l.tactics[side],defence:l.defences[side]};
  if(diff<0){
   attack=diff<=-2?'occupation':l.weather==='Pluie'?'occupation':'conquete';
   defence='prudente';
   reason=diff<=-2?'la double infériorité numérique':'l’infériorité numérique';
  }else{
   attack='large';
   defence=diff>=2&&mean(activePlayers(l,side).map(p=>p.condition))>70?'pression':'equilibre';
   reason=diff>=2?'la double supériorité numérique':'la supériorité numérique';
  }
 }
 memory.lastCardDiff=diff;
 if(attack&&attack!==l.tactics[side]){
  l.tactics[side]=attack;
  addEvent(l,`${S.clubs[l.pair[side]].abbr} adapte son attaque : ${TACTICS[attack][0]} (${reason}).`,'tactic',{team:side});
 }
 if(defence&&defence!==l.defences[side]){
  l.defences[side]=defence;
  addEvent(l,`${S.clubs[l.pair[side]].abbr} adapte sa défense : ${DEFENCES[defence][0]} (${reason}).`,'tactic',{team:side});
 }
 return diff!==0;
}
function adaptManager(l,side){if(l.finished||side===l.userSide)return;const level=difficultyLevel(l);if(level==='decouverte')return;if(adaptNumericalManager(l,side))return;const reviews=level==='expert'?[20,40,55,65,75]:[40,60];if(!reviews.includes(l.minute))return;l.managerMemory=l.managerMemory||[{lastSub:-10,lastReview:0},{lastSub:-10,lastReview:0}];let memory=l.managerMemory[side];if(memory.lastReview===l.minute)return;memory.lastReview=l.minute;adaptDefence(l,side);const c=S.clubs[l.pair[side]],scores=styleScores(c,l.sheets[side].on,l.weather),margin=l.score[side]-l.score[1-side];let next=Object.entries(scores).sort((a,b)=>b[1]-a[1])[0][0];let reason='ses qualités et la météo';if(l.minute>=55&&margin<=-5){next=l.weather==='Pluie'||scores.conquete>scores.large+4?'conquete':'large';reason='la nécessité de revenir au score'}else if(l.minute>=60&&margin>=5){next=l.weather!=='Vent'&&scores.occupation>=scores.equilibre-5?'occupation':'equilibre';reason='la protection de son avance'}if(next!==l.tactics[side]){l.tactics[side]=next;addEvent(l,`${c.abbr} adapte son jeu : ${TACTICS[next][0]} (${reason}).`,'tactic',{team:side})}}
function manageSubstitutions(l,side){if(l.finished||side===l.userSide)return;let level=difficultyLevel(l),start=level==='decouverte'?60:level==='expert'?45:50,spacing=level==='decouverte'?6:level==='expert'?4:5;if(l.minute<start)return;l.managerMemory=l.managerMemory||[{lastSub:-10,lastReview:0},{lastSub:-10,lastReview:0}];const memory=l.managerMemory[side];if(l.minute-memory.lastSub<spacing)return;const sh=l.sheets[side];if(!revisedRules(l)&&sh.subs>=8)return;let best=null,margin=l.score[side]-l.score[1-side],kicker=chooseScorer(S.clubs[l.pair[side]],activePlayers(l,side).map(p=>p.id));for(let slot=0;slot<15;slot++){const out=matchPlayer(l,side,sh.on[slot]);if(!out||sh.cards.some(c=>c.id===out.id&&c.until>l.minute))continue;for(let id of sh.bench){const p=matchPlayer(l,side,id);if(!p||p.injury||!legalChange(l,side,slot,id))continue;let gain=fitScore(p,FAMILIES[slot])-fitScore(out,FAMILIES[slot]);const fresh=p.condition-out.condition;if(level==='decouverte'){if(out.condition>65||fresh<12)continue;gain=fresh*.2}else{if(fresh<7&&gain<3)continue;if(out.condition<60)gain+=4;if(level==='expert'&&kicker?.id===out.id&&Math.abs(margin)<=7&&l.minute>=55&&skill(p,'goal',true)<skill(out,'goal',true)-10)gain-=9;if(level==='expert'&&l.minute<60&&sh.bench.filter(id=>matchPlayer(l,side,id)?.fam===p.fam).length===1&&p.condition<85)gain-=2}if(gain>(level==='expert'?1.5:level==='classique'?2:0)&&(!best||gain>best.gain))best={slot,id,gain}}}if(best&&makeSub(l,side,best.slot,best.id))memory.lastSub=l.minute}
function trackManagerLoad(l){if(l.managerLoadRecorded)return;l.managerLoadRecorded=true;for(let side=0;side<2;side++){const sh=l.sheets[side];for(let p of S.clubs[l.pair[side]].players){let minutes=sh.minutes[p.id]||0;p.managerLoad={minutes,streak:sh.initial.includes(p.id)?(p.managerLoad?.streak||0)+1:0}}}}
function wantsPosts(l,side,distance){const policy=l.penaltyPolicies?.[side]||'auto';if(policy==='touch')return false;if(policy==='points')return distance<53;const smart=side===l.userSide||difficultyLevel(l)==='expert';if(smart&&l.minute>=65){const diff=l.score[side]-l.score[1-side];if(diff<-3)return false;if(diff>=0&&l.tries[side]-l.tries[1-side]===2&&diff>7&&S.phase==='league')return false;if(Math.abs(diff)<=3)return distance<53}return distance<53&&(l.tactics[side]!=='conquete'||distance<28)}
function setPenaltyPolicy(policy){const l=S.live;if(!l||!l.paused||l.finished||!PENALTY_POLICIES[policy])return;l.penaltyPolicies=l.penaltyPolicies||['auto','auto'];l.penaltyPolicies[l.userSide]=policy;addEvent(l,`Votre consigne sur pénalité : ${PENALTY_POLICIES[policy]}.`,'tactic',{team:l.userSide});syncMatchPresentation(l);save();render()}
function setDifficulty(level){if(S.live){toast('La difficulté se règle entre deux rencontres.');return}if(!DIFFICULTIES[level])return;S.difficulty=level;save();render();toast('Difficulté : '+DIFFICULTIES[level][0]+'. Les attributs restent identiques.')}
function difficultyPanel(){return `<div class="card"><div class="cardtitle"><h2>04 / Le défi du manager</h2><span class="tag">${DIFFICULTIES[S.difficulty||'classique'][0]}</span></div><div class="options">${Object.entries(DIFFICULTIES).map(([k,[title,desc]])=>`<button class="option ${(S.difficulty||'classique')===k?'selected':''}" onclick="setDifficulty('${k}')">${title}<small>${desc}</small></button>`).join('')}</div><p class="help">La difficulté modifie les décisions des adversaires. Aucun attribut, budget ou coefficient de réussite n’est augmenté selon le niveau. Le même moteur et les mêmes règles s’appliquent aux deux équipes. Ce réglage est conservé dans la sauvegarde et pris en compte au prochain coup d’envoi.</p></div>`}
function oppositionPreview(){return oppositionDossierHTML()}
function penaltyControls(l){const policy=l.penaltyPolicies?.[l.userSide]||'auto';return `<label class="eyebrow" for="penalty-policy">SUR PÉNALITÉ</label><select id="penalty-policy" style="margin-top:10px" ${!l.paused||l.finished?'disabled':''} onchange="setPenaltyPolicy(this.value)">${Object.entries(PENALTY_POLICIES).map(([k,title])=>`<option value="${k}" ${policy===k?'selected':''}>${title}</option>`).join('')}</select><p class="help">Selon le contexte : chercher un essai en fin de match si une pénalité ne suffit plus à revenir, ou si le bonus offensif est à portée. Le buteur et la distance déterminent la réussite.</p><p class="help">Adversaire : niveau ${DIFFICULTIES[difficultyLevel(l)][0]}. Aucun bonus d’attribut.</p>`}
