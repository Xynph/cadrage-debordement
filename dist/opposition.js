'use strict';
const DIFFICULTIES={decouverte:['Découverte','Un entraîneur adverse au plan stable, avec des changements tardifs.'],classique:['Classique','Rotation, choix du style selon les qualités, la météo et l’adversaire, adaptation à la mi-temps.'],expert:['Expert','Lecture fine des points faibles adverses, gestion du banc et des postes clés, adaptation au score et recherche des bonus.']};
const PENALTY_POLICIES={auto:'Selon le contexte',points:'Chercher les points',touch:'Chercher la pénaltouche',main:'Jouer vite à la main'};
function normalizeOppositionSnapshot(state){if(!state.difficulty)state.difficulty='classique';if(state.defence===undefined)state.defence='equilibre';for(let c of state.clubs){if(c.morale===undefined){let value=75;for(let f of c.form)value=clamp(value+(f==='V'?6:f==='D'?-5:1),25,98);c.morale=value}}return state}
function setupOpposition(){if(S)normalizeOppositionSnapshot(S)}
function clubMorale(ci){return ci===S.club?S.morale:(S.clubs[ci].morale??75)}
// Moral des clubs IA en carrière Monde (17/11/2026, docs/top14-dispute-20261117.md §5) : il revient vers `repos` d'un quart
// de son écart à chaque match avant le résultat (+4 / −4, nul +1). L'ancien cumul (+6 / −5, borné 25-98) saturait en quelques
// journées : le leader jouait à 98 (≈ +6 points de niveau, teamEdge ×0,001 par point) et le dernier à 25 (≈ −9), ce qui
// creusait le classement au-delà de l'écart des effectifs (leader 20-24 victoires sur 26, dernier à 9-30 points).
// Équilibre : ±10 autour de 75 pour un club qui gagne (ou perd) 80 % de ses matchs. Autres modes : règle d'origine.
const MORAL_IA_MONDE=Object.freeze({repos:75,retour:.25,victoire:4,defaite:-4,nul:1,min:25,max:98});
function updateOppositionMorale(r){const M=S.worldMode?MORAL_IA_MONDE:null;r.pair.forEach((ci,i)=>{if(ci===S.club)return;const diff=typeof CDFranceCompetition!=='undefined'&&CDFranceCompetition.active(S)?CDFranceCompetition.outcome(r,ci):r.score[i]-r.score[1-i];const m=clubMorale(ci);S.clubs[ci].morale=M?clamp(Math.round(m-(m-M.repos)*M.retour+(diff>0?M.victoire:diff<0?M.defaite:M.nul)),M.min,M.max):clamp(m+(diff>0?6:diff<0?-5:1),25,98)})}
function difficultyLevel(l=null){return l?.aiLevel||S.difficulty||'classique'}
function managerStyle(ci){return ['conquete','large','occupation','equilibre'][ci%4]}
function sheetAverage(c,ids,key,filter=()=>true){let players=ids.map(id=>c.players.find(p=>p.id===id)).filter(p=>p&&filter(p));return players.length?mean(players.map(p=>skill(p,key,true))):25}
// Choix du style selon l'adversaire, la météo et le contexte (18/11/2026, docs/top14-dispute-20261117.md §16), maintenant
// que les styles se valent à niveau égal (§14). Contexte `ctx` facultatif : {opp, oppIds, gap (base), fatigue (condition moyenne, nous − eux), europe}.
// - Duels (lecture de l'adversaire, ×0,5 en Classique, ×1 en Expert) : jeu au près = notre conquête (mêlée, touche, puissance
//   des avants) contre la sienne ; jeu au large = passe et vitesse de nos arrières contre placage et vitesse des siens ;
//   occupation = notre jeu au pied contre le sien. Duels symétriques (notre attaque contre sa défense,
//   moins l'inverse), bornés à ±STYLE_IA.dueMax points.
// - Contexte (tous niveaux sauf Découverte) : favori net → jeu au large (bonus offensif, défense plus faible à étirer) ; outsider
//   net → près et occupation (jeu serré, moins de fautes de main) ; XV plus entamé que
//   l'adversaire (condition moyenne plus basse de plus de 3 points) ou semaine européenne → occupation, moins de jeu au large (charge physique ATTACK_EFFECTS.load).
const STYLE_IA=Object.freeze({due:.25,dueMax:6,ecart:3,favori:.6,outsider:.5,contexteMax:4,fraicheur:3,fatigue:.3,europe:2});
function styleContext(l,side,ids){const opp=S.clubs[l.pair[1-side]],c=S.clubs[l.pair[side]],oppIds=l.sheets?.[1-side]?.on||[];const cond=(club,list)=>{const ps=list.map(id=>club.players.find(p=>p.id===id)).filter(Boolean);return ps.length?mean(ps.map(p=>p.condition??100)):100};return{opp,oppIds,gap:(c.base??0)-(opp?.base??0),fatigue:cond(c,ids||l.sheets?.[side]?.on||[])-cond(opp,oppIds),europe:!!l.rotationEurope?.includes(side)}}
function styleDuels(c,ids,ctx){if(!ctx?.opp||!ctx.oppIds?.length)return null;const o=ctx.opp,oi=ctx.oppIds,fw=p=>p.fam<=3,front=p=>p.fam<=2,jump=p=>p.fam===1||p.fam===2,backs=p=>p.fam>=4,kickers=p=>p.fam===4||p.fam===5||p.fam===8;
 const pack=(club,list,k)=>(sheetAverage(club,list,'scrum',front)+sheetAverage(club,list,'lineout',jump)+sheetAverage(club,list,k,fw))/3,
  line=(club,list,a,b)=>(sheetAverage(club,list,a,backs)+sheetAverage(club,list,b,backs))/2;
 // Duels symétriques (notre attaque contre sa défense, moins l'inverse) : sans biais d'échelle entre attributs, nuls en moyenne.
 return{conquete:(pack(c,ids,'power')-pack(o,oi,'tackle'))-(pack(o,oi,'power')-pack(c,ids,'tackle')),large:(line(c,ids,'pass','speed')-line(o,oi,'tackle','speed'))-(line(o,oi,'pass','speed')-line(c,ids,'tackle','speed')),occupation:sheetAverage(c,ids,'kick',kickers)-sheetAverage(o,oi,'kick',kickers)}}
function styleScores(c,ids,weather,ctx=null,level='classique'){const backs=p=>p.fam>=4,forwards=p=>p.fam<=3;const pass=sheetAverage(c,ids,'pass',backs),speed=sheetAverage(c,ids,'speed',p=>p.fam>=6),power=sheetAverage(c,ids,'power',forwards),scrum=sheetAverage(c,ids,'scrum',p=>p.fam<=2),lineout=sheetAverage(c,ids,'lineout',p=>p.fam===1||p.fam===2),kick=sheetAverage(c,ids,'kick',p=>p.fam===4||p.fam===5||p.fam===8),mental=sheetAverage(c,ids,'mental'),tackle=sheetAverage(c,ids,'tackle');let scores={equilibre:(pass+power+tackle)/3,large:(pass+speed)/2-(weather==='Pluie'?11:0),conquete:(scrum+lineout+power)/3+(weather==='Pluie'?2:0),occupation:kick*.75+mental*.25-(weather==='Vent'?10:0)};scores[managerStyle(c.id)]+=5;
 if(ctx&&level!=='decouverte'){const T=STYLE_IA,duels=styleDuels(c,ids,ctx),w=level==='expert'?1:.5;if(duels)for(const k of Object.keys(duels))scores[k]+=clamp(duels[k]*T.due,-T.dueMax,T.dueMax)*w;
  const gap=ctx.gap??0;if(gap>T.ecart)scores.large+=Math.min(T.contexteMax,(gap-T.ecart)*T.favori);else if(gap<-T.ecart){const b=Math.min(T.contexteMax,(-gap-T.ecart)*T.outsider);scores.conquete+=b;scores.occupation+=b}
  const usure=Math.max(0,-(ctx.fatigue??0)-T.fraicheur)*T.fatigue+(ctx.europe?T.europe:0);scores.occupation+=usure;scores.large-=usure}
 return scores}
// Raison affichée quand l'IA change de style en cours de match : le duel ou le contexte qui pèse le plus pour ce style.
function styleReason(c,ids,next,ctx){const duels=ctx&&styleDuels(c,ids,ctx);if(duels&&duels[next]>=6)return next==='conquete'?'la domination de son pack':next==='large'?'une défense adverse en difficulté au large':next==='occupation'?'son avantage au pied':'ses qualités et la météo';if(next==='occupation'&&(-(ctx?.fatigue??0)>STYLE_IA.fraicheur+5||ctx?.europe))return 'la fatigue de son XV';return 'ses qualités et la météo'}
function chooseManagerStyle(c,ids,weather,level,ctx=null){if(level==='decouverte')return managerStyle(c.id);return Object.entries(styleScores(c,ids,weather,ctx,level)).sort((a,b)=>b[1]-a[1])[0][0]}
function strategicPlayerScore(p,slot,style,level,rest,europe=false){const f=FAMILIES[slot];let n=roleNote(p,f)*(.32+p.condition*.0068);let specialized=style==='large'?skill(p,p.fam>=4?'pass':'tackle',true):style==='occupation'?skill(p,p.fam>=4?'kick':'tackle',true):style==='conquete'?skill(p,p.fam<=3?'power':'tackle',true):fitScore(p,f);n+=(specialized-roleNote(p,f))*.15;if(p.physicalLoad?.version===1)n-=Math.max(0,physicalLoadValue(p)-45)*.10;if(rest&&p.managerLoad?.streak>=3&&p.managerLoad.minutes>=65)n-=level==='expert'?3:2;if(europe)n-=rotationEuropeMalus(p,level);if(level==='expert'&&p.age<=22&&p.condition>=90)n+=1;return n}
// Premier élément de plus forte note, comme list.sort((a,b)=>score(b)-score(a))[0] (tri stable : à note égale, l'ordre de
// la liste) en un passage au lieu d'un tri complet ; score est mémorisé par l'appelant. Une note NaN rend le tri
// imprévisible : on garde alors le tri d'origine (lot 37). Banc : titulaires relus une fois (ni la feuille ni l'effectif ne
// changent pendant le choix du banc) ; la fatigue des titulaires du poste ne compte que pour la dernière place (i = 7).
function bestOf(list,score){let best,top;for(let i=0;i<list.length;i++){const v=score(list[i]);if(v!==v)return list.sort((a,b)=>score(b)-score(a))[0];if(i===0||v>top){best=list[i];top=v}}return best}
// Buteur titulaire (26/11/2026, docs/ia-decisions-match-20261126.md) : le meilleur buteur disponible (demi d'ouverture,
// trois-quarts, arrière) entre dans le XV quand il tire nettement mieux que le buteur retenu (au moins BUTEUR_IA.ecart points
// au but) et que la perte au poste reste sous BUTEUR_IA.part × cet écart (BUTEUR_IA.max au plus) : ~0,85 point de réussite
// par point de note au but (BUT.parPointNote), cinq tirs par match. Il prend le poste des lignes arrières où il coûte le moins.
const BUTEUR_IA=Object.freeze({ecart:6,part:.4,max:10});
function titulariserButeur(c,lineup,score){
 const on=new Set(lineup.filter(Boolean)),xv=chooseScorer(c,[...on]);if(!xv)return lineup;
 const k=c.players.filter(p=>!p.injury&&!on.has(p.id)&&p.fam>=5).sort((a,b)=>skill(b,'goal')-skill(a,'goal'))[0];
 const gap=k?skill(k,'goal')-skill(xv,'goal'):0;if(gap<BUTEUR_IA.ecart)return lineup;
 let best=null;for(let i=8;i<15;i++){const cur=c.players.find(p=>p.id===lineup[i]);if(!cur||!slotEligible(k,i))continue;const loss=score(cur,i)-score(k,i);if(!best||loss<best.loss)best={i,loss}}
 if(!best||best.loss>Math.min(BUTEUR_IA.max,gap*BUTEUR_IA.part))return lineup;
 const next=[...lineup];next[best.i]=k.id;return next;
}
function managerSheet(c,opponent,weather,level,europe=false,ctx=null){if(level==='decouverte')return buildSheet(c);let base=buildSheet(c),style=chooseManagerStyle(c,base.lineup,weather,level,ctx);const rest=opponent&&opponent.base<c.base-3;const used=new Set();let lineup=FAMILIES.map((_,i)=>{const score=new Map(),scored=p=>{if(!score.has(p))score.set(p,strategicPlayerScore(p,i,style,level,rest,europe));return score.get(p)};let p=bestOf(c.players.filter(p=>!p.injury&&!used.has(p.id)&&slotEligible(p,i)),scored);if(p)used.add(p.id);return p?.id||null});lineup=titulariserButeur(c,lineup,(p,i)=>strategicPlayerScore(p,i,style,level,rest,europe));used.clear();lineup.forEach(id=>id&&used.add(id));let startersList=null;const starters=()=>startersList??=lineup.map(id=>c.players.find(x=>x.id===id));let bench=BENCH_LABELS.map((_,i)=>{let choices=c.players.filter(p=>!p.injury&&!used.has(p.id)&&benchEligible(p,i));if(i===6){let flyhalves=choices.filter(p=>p.fam===5);if(flyhalves.length)choices=flyhalves}const values=new Map();function value(p){if(values.has(p))return values.get(p);let depth=0;if(i===7){let out=starters().filter(x=>x&&x.fam===p.fam);let tired=out.length?100-Math.min(...out.map(x=>x.condition)):0;depth=tired*.15}const total=fitScore(p)+depth;values.set(p,total);return total}let p=bestOf(choices,value);if(p)used.add(p.id);return p?.id||null});return{lineup,bench}}
// Rotation autour de la Coupe d'Europe (18/11/2026, docs/top14-dispute-20261117.md §14) : en carrière Monde, un club IA qui
// joue un match de championnat la semaine d'avant ou d'après un match européen (Champions Cup, Challenge Cup) ménage ses
// titulaires qui enchaînent (deux feuilles de suite et 60 minutes ou plus) : −3 au choix de la feuille (−4 en expert).
const ROTATION_EUROPE=Object.freeze({competitions:Object.freeze(['champions','challenge']),semaines:1,serie:2,minutes:60,malus:3,malusExpert:4});
// Rotation autour de la Coupe d'Europe : malus de sélection d'un joueur très utilisé (partagé avec le résultat rapide, league-detail.cjs).
function rotationEuropeMalus(p,level){const R=ROTATION_EUROPE;return p.managerLoad?.streak>=R.serie&&p.managerLoad.minutes>=R.minutes?(level==='expert'?R.malusExpert:R.malus):0}
function europeAutour(f,ci){const W=S?.worldMode,R=ROTATION_EUROPE;if(!W?.fixtures||!f||R.competitions.includes(f.competitionId))return false;return W.fixtures.some(x=>R.competitions.includes(x.competitionId)&&(x.homeId===ci||x.awayId===ci)&&Math.abs(x.week-f.week)<=R.semaines)}
function semaineEuropeenne(l,ci){const W=S?.worldMode;if(!W?.fixtures)return false;return europeAutour(W.fixtures.find(x=>x.homeId===l.pair[0]&&x.awayId===l.pair[1]&&x.week===S.round),ci)}
function initializeManagers(l,automated=false){l.aiLevel=S.difficulty||'classique';l.balanceVersion=2;l.managerMemory=[{lastSub:-10,lastReview:0,lastCardDiff:0,cardBase:null},{lastSub:-10,lastReview:0,lastCardDiff:0,cardBase:null}];l.numericalAiVersion=1;l.iaDecisionsVersion=1;l.penaltyPolicies=['auto','auto'];for(let side=0;side<2;side++){if(side===l.userSide||l.pair[side]===S.club)continue;let c=S.clubs[l.pair[side]],other=S.clubs[l.pair[1-side]],europe=semaineEuropeenne(l,l.pair[side]),sheet=managerSheet(c,other,l.weather,l.aiLevel,europe,{...styleContext(l,side),europe});if(europe)l.rotationEurope=[...(l.rotationEurope||[]),side];l.sheets[side]={...l.sheets[side],on:sheet.lineup,initial:[...sheet.lineup],bench:sheet.bench,used:sheet.lineup.filter(Boolean)}}for(let side=0;side<2;side++){if(side===l.userSide||l.pair[side]===S.club)continue;const c=S.clubs[l.pair[side]];l.tactics[side]=chooseManagerStyle(c,l.sheets[side].on,l.weather,l.aiLevel,styleContext(l,side))}}
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
function adaptManager(l,side){if(l.finished||side===l.userSide)return;const level=difficultyLevel(l);if(level==='decouverte')return;if(adaptNumericalManager(l,side))return;const reviews=level==='expert'?[20,40,55,65,75]:[40,60];if(!reviews.includes(l.minute))return;l.managerMemory=l.managerMemory||[{lastSub:-10,lastReview:0},{lastSub:-10,lastReview:0}];let memory=l.managerMemory[side];if(memory.lastReview===l.minute)return;memory.lastReview=l.minute;adaptDefence(l,side);const c=S.clubs[l.pair[side]],ctx=styleContext(l,side),scores=styleScores(c,l.sheets[side].on,l.weather,ctx,level),margin=l.score[side]-l.score[1-side];let next=Object.entries(scores).sort((a,b)=>b[1]-a[1])[0][0];let reason=styleReason(c,l.sheets[side].on,next,ctx);if(l.minute>=55&&margin<=-5){next=l.weather==='Pluie'||scores.conquete>scores.large+4?'conquete':'large';reason='la nécessité de revenir au score'}else if(l.minute>=60&&margin>=5){next=l.weather!=='Vent'&&scores.occupation>=scores.equilibre-5?'occupation':'equilibre';reason='la protection de son avance'}if(next!==l.tactics[side]){l.tactics[side]=next;addEvent(l,`${c.abbr} adapte son jeu : ${TACTICS[next][0]} (${reason}).`,'tactic',{team:side})}}
// Note au poste du sortant (outFit) lue une fois par poste au lieu d'une fois par remplaçant : fitScore est une lecture
// pure, même valeur (lot 36). La légalité du changement (legalChange, lecture pure elle aussi) n'est vérifiée que pour un
// remplaçant qui deviendrait le meilleur choix : même meilleur choix, dans le même ordre (lot 37).
function manageSubstitutions(l,side){if(l.finished||side===l.userSide)return;if(l.iaDecisionsVersion===1)return remplacementsIA(l,side);let level=difficultyLevel(l),start=level==='decouverte'?60:level==='expert'?45:50,spacing=level==='decouverte'?6:level==='expert'?4:5;if(l.minute<start)return;l.managerMemory=l.managerMemory||[{lastSub:-10,lastReview:0},{lastSub:-10,lastReview:0}];const memory=l.managerMemory[side];if(l.minute-memory.lastSub<spacing)return;const sh=l.sheets[side];if(!revisedRules(l)&&sh.subs>=8)return;let best=null,margin=l.score[side]-l.score[1-side],kicker=chooseScorer(S.clubs[l.pair[side]],activePlayers(l,side).map(p=>p.id),l),fit=staffSubsFit(l,side);for(let slot=0;slot<15;slot++){const out=matchPlayer(l,side,sh.on[slot]);if(!out||sh.cards.some(c=>c.id===out.id&&c.until>l.minute))continue;let outFit;for(let id of sh.bench){const p=matchPlayer(l,side,id);if(!p||p.injury)continue;let gain=fit(p,FAMILIES[slot])-(outFit??=fit(out,FAMILIES[slot]));const fresh=p.condition-out.condition;if(level==='decouverte'){if(out.condition>65||fresh<12)continue;gain=fresh*.2}else{if(fresh<7&&gain<3)continue;if(out.condition<60)gain+=4;if(level==='expert'&&kicker?.id===out.id&&Math.abs(margin)<=7&&l.minute>=55&&skill(p,'goal',fitArrete(l))<skill(out,'goal',fitArrete(l))-10)gain-=9;if(level==='expert'&&l.minute<60&&sh.bench.filter(id=>matchPlayer(l,side,id)?.fam===p.fam).length===1&&p.condition<85)gain-=2}if(gain>(level==='expert'?1.5:level==='classique'?2:0)&&(!best||gain>best.gain)&&legalChange(l,side,slot,id))best={slot,id,gain}}}if(best&&makeSub(l,side,best.slot,best.id))memory.lastSub=l.minute}
// Banc de l'IA par vagues (26/11/2026, docs/ia-decisions-match-20261126.md) : rencontres créées avec `iaDecisionsVersion`.
// Élite réelle : première ligne vers 47-55', avants puis charnière et trois-quarts par vagues entre 54' et 70', presque
// rien après 75' (blessures à part, gérées par les incidents du match). Chaque camp a ses minutes de vague, tirées d'un
// repère fixe de la rencontre (aucun tirage au sort), puis avancées selon le score : large avance → rotation, gros retard
// → coaching offensif. Un joueur cramé (condition sous `crame`) sort avant sa vague dès la 40e. Dans une vague, plusieurs
// changements la même minute (au plus `parMinute`) ; `ecart` minutes entre deux changements d'un même groupe.
// Jamais de retour tactique d'un joueur remplacé (loi 3 : retours réservés au saignement, au protocole commotion, à la
// première ligne et au rouge de vingt minutes) ; le buteur reste en jeu (sauf à bout, ou match plié à plus de 14 points) si son remplaçant tire moins bien (5 points au but).
const BANC_IA=Object.freeze({
 groupes:Object.freeze(['front','front','front','pack','pack','pack','pack','pack','demis','demis','arrieres','arrieres','arrieres','arrieres','arrieres']),
 vagues:Object.freeze({front:[47,55],pack:[54,62],demis:[57,66],arrieres:[59,69]}),
 ecart:Object.freeze({front:2,pack:4,demis:4,arrieres:4}),
 fin:75,crame:55,horsLimite:40,debutCrame:40,
 rotation:15,avanceRotation:5,avanceRetard:3,retardDecouverte:6,
 parMinute:3,gainVague:-2,gainCrame:2,
 buteur:Object.freeze({ecart:14,perte:5})
});
function vagueBanc(l,side,groupe){const W=BANC_IA.vagues[groupe];let h=2166136261;for(const v of [l.pair[0],l.pair[1],side,groupe.length*7+groupe.charCodeAt(0),S.season|0,S.round|0]){h^=Number(v)|0;h=Math.imul(h,16777619)>>>0}return W[0]+h%(W[1]-W[0]+1)}
function remplacementsIA(l,side){
 const B=BANC_IA,level=difficultyLevel(l),m=typeof matchMinute==='function'?matchMinute(l):l.minute;
 if(m<B.debutCrame)return;
 l.managerMemory=l.managerMemory||[{lastSub:-10,lastReview:0},{lastSub:-10,lastReview:0}];
 const memory=l.managerMemory[side],sh=l.sheets[side];if(!revisedRules(l)&&sh.subs>=8)return;
 const vagues=memory.banc||(memory.banc={faits:{front:0,pack:0,demis:0,arrieres:0}});
 const margin=l.score[side]-l.score[1-side],decale=level==='decouverte'?B.retardDecouverte:m>=45&&margin>=B.rotation?-B.avanceRotation:m>=45&&margin<=-B.rotation?-B.avanceRetard:0;
 const ouverte=g=>m>=vagueBanc(l,side,g)+decale+vagues.faits[g]*B.ecart[g];
 const fit=staffSubsFit(l,side),fitA=fitArrete(l),serre=Math.abs(margin)<=B.buteur.ecart&&level!=='decouverte';
 for(let fait=0;fait<B.parMinute;fait++){
  const kicker=serre?chooseScorer(S.clubs[l.pair[side]],activePlayers(l,side).map(p=>p.id),l):null;let best=null;
  for(let slot=0;slot<15;slot++){
   const out=matchPlayer(l,side,sh.on[slot]);if(!out||!sh.initial.includes(out.id)||sh.cards.some(c=>c.id===out.id&&c.until>l.minute))continue;
   const g=B.groupes[slot],crame=out.condition<(m>B.fin?B.horsLimite:B.crame),vague=m<=B.fin&&ouverte(g);if(!vague&&!crame)continue;
   let outFit;
   for(const id of sh.bench){
    if(sh.used.includes(id))continue;const p=matchPlayer(l,side,id);if(!p||p.injury)continue;
    let gain=fit(p,FAMILIES[slot])-(outFit??=fit(out,FAMILIES[slot]));
    if(kicker?.id===out.id&&skill(p,'goal',fitA)<skill(out,'goal',fitA)-B.buteur.perte&&out.condition>=B.horsLimite)continue;
    if(gain<=(vague?B.gainVague:B.gainCrame))continue;
    if((!best||gain>best.gain)&&legalChange(l,side,slot,id))best={slot,id,gain,g};
   }
  }
  if(!best||!makeSub(l,side,best.slot,best.id))break;
  memory.lastSub=l.minute;vagues.faits[best.g]++;
 }
}
function trackManagerLoad(l){if(l.managerLoadRecorded)return;l.managerLoadRecorded=true;for(let side=0;side<2;side++){const sh=l.sheets[side];for(let p of S.clubs[l.pair[side]].players){let minutes=sh.minutes[p.id]||0;p.managerLoad={minutes,streak:sh.initial.includes(p.id)?(p.managerLoad?.streak||0)+1:0}}}}
// Fin de match (chrono des arrêts, docs/chrono-arrets-de-jeu-20261118.md) : à partir de la 72e, mené d'un peu plus que
// l'écart du bonus défensif (Top 14 : −6 à −8), le staff prend les trois points (un tir coûte ≈ 2 min de chrono).
// Portée du tir (docs/penalites-au-but-20261123.md) : réussite attendue du buteur à la marque (`y` : abscisse de la marque).
function wantsPosts(l,side,distance,y=35){const policy=l.penaltyPolicies?.[side]||'auto';if(l.iaDecisionsVersion===1)return choixPoteauxStaff(l,side,distance,y,policy);if(policy==='touch')return false;if(policy==='points')return postsInRange(l,side,distance,y,true);const smart=side===l.userSide||difficultyLevel(l)==='expert';if(smart&&l.minute>=65){const diff=l.score[side]-l.score[1-side];if(chronoRules(l)&&matchMinute(l)>=72){const bd=typeof nativeMatchBonus!=='undefined'?nativeMatchBonus.regleDuMatch(l)?.defensif?.ecart:null;if(bd&&-diff>bd&&-diff<=bd+3)return distance<45}if(diff<-3)return false;if(diff>=0&&l.tries[side]-l.tries[1-side]===2&&diff>7&&(l.franceContext?.phase??S.phase)==='league')return false;if(Math.abs(diff)<=3)return postsInRange(l,side,distance,y)}return postsInRange(l,side,distance,y)&&(l.tactics[side]!=='conquete'||distance<28)}
// Choix du staff sur pénalité (26/11/2026, docs/ia-decisions-match-20261126.md) : rencontres `iaDecisionsVersion`, toutes les
// équipes en consigne « Selon le contexte » (IA de tous niveaux comme club du manager). Sans tirage (quickTapWeight s'en sert).
// - Hors de portée (réussite attendue du buteur à la marque sous le seuil, vent et pluie compris) : touche.
// - À partir de la 65e : mené de 3 points ou moins, à égalité ou devant, les poteaux (sauf bonus offensif à un essai avec
//   8 points d'avance : touche) ; mené de 4 points ou plus, la touche pour l'essai, sauf entre la 72e et la fin pour revenir
//   dans le bonus défensif (#1302, chrono) et, avant la 75e, mené de 8 à 10 points : trois points pour revenir à un essai transformé.
// - Milieu de match : les poteaux ; un pack de conquête va en touche au-delà de 28 m, sauf tir facile. La part de pénaltouches
//   propre au championnat (pretereTouche, dist/tactical-plans.js) ne joue qu'en milieu de match, selon la distance et le score.
// - Consigne « touche » posée par l'IA (« tout pour la victoire ») : les poteaux dans les dix dernières minutes quand trois
//   points suffisent à égaliser ou gagner (mené de 1 à 3).
// - Consigne « points » posée par l'IA (dilemme du bonus, native/engine/match-bonus.cjs) : levée dans les cinq dernières
//   minutes quand trois points ne servent plus à rien (ni égalité, ni bonus défensif à reprendre).
const PENALITE_IA=Object.freeze({fin:65,toucheLevee:70,derniere:75,bonusDefensif:72,facile:.85,unEssai:7,avanceBonus:8,conquete:28,
 culture:Object.freeze({pres:.3,milieu:.75,loin:1,mene:1.4,devant:1.2,serre:.6,minute:50,max:.9})});
function bonusDefensifEcart(l){const bd=typeof nativeMatchBonus!=='undefined'?nativeMatchBonus.regleDuMatch(l)?.defensif?.ecart:null;return Number.isFinite(bd)?bd:null}
function troisPointsUtiles(l,side){const diff=l.score[side]-l.score[1-side];if(diff+3>=0)return true;const bd=bonusDefensifEcart(l);return bd!==null&&-diff>bd&&-diff-3<=bd}
function bonusOffensifAPortee(l,side){if(l.score[side]-l.score[1-side]<PENALITE_IA.avanceBonus)return false;const r=typeof nativeMatchBonus!=='undefined'?nativeMatchBonus.regleDuMatch(l):null;if(r?.offensif)return nativeMatchBonus.manque(r,l.score,l.tries,side)===1;return l.tries[side]-l.tries[1-side]===2&&(l.franceContext?.phase??S.phase)==='league'}
function choixPoteauxStaff(l,side,distance,y,policy){
 const P=PENALITE_IA,m=matchMinute(l),diff=l.score[side]-l.score[1-side];
 if(policy==='touch')return side!==l.userSide&&m>=P.toucheLevee&&diff<0&&diff>=-3&&postsInRange(l,side,distance,y);
 if(policy==='points')return !(side!==l.userSide&&m>=P.derniere&&!troisPointsUtiles(l,side))&&postsInRange(l,side,distance,y,true);
 if(m>=P.fin){
  if(diff>=-3)return !(diff>=0&&bonusOffensifAPortee(l,side))&&postsInRange(l,side,distance,y);
  const bd=bonusDefensifEcart(l);
  if(chronoRules(l)&&m>=P.bonusDefensif&&bd!==null&&-diff>bd&&-diff<=bd+3)return distance<45;
  return m<P.derniere&&-diff-3<=P.unEssai&&-diff>=8&&postsInRange(l,side,distance,y);
 }
 if(!postsInRange(l,side,distance,y))return false;
 return l.tactics[side]!=='conquete'||distance<P.conquete||goalChanceEstimate(l,side,distance,y)>=P.facile;
}
// Part de pénaltouches propre au championnat (TOUCHE_CHAMPIONNATS), milieu de match seulement : nulle sur un tir facile,
// réduite près des poteaux, plus forte quand on est mené de 8 points ou plus (ou qu'on mène largement), plus faible à score serré.
function partToucheChampionnat(l,side,c){
 if(!c)return 0;const P=PENALITE_IA,C=P.culture,m=matchMinute(l);if(m>=P.fin)return 0;
 const d=side===0?100-l.territory:l.territory,diff=l.score[side]-l.score[1-side];
 if(goalChanceEstimate(l,side,d,penaltySpotY(l,side))>=P.facile)return 0;
 let w=c*(d<22?C.pres:d<40?C.milieu:C.loin);
 if(m>=C.minute)w*=diff<=-8?C.mene:diff>=8?C.devant:Math.abs(diff)<=3?C.serre:1;
 return clamp(w,0,C.max);
}
function setPenaltyPolicy(policy){const l=S.live;if(!l||!l.paused||l.finished||!PENALTY_POLICIES[policy])return;l.penaltyPolicies=l.penaltyPolicies||['auto','auto'];l.penaltyPolicies[l.userSide]=policy;addEvent(l,`Ta consigne sur pénalité : ${PENALTY_POLICIES[policy]}.`,'tactic',{team:l.userSide});syncMatchPresentation(l);save();render()}
function setDifficulty(level){if(S.live){toast('La difficulté se règle entre deux rencontres.');return}if(!DIFFICULTIES[level])return;S.difficulty=level;save();render();toast('Difficulté : '+DIFFICULTIES[level][0]+'. Les attributs restent identiques.')}
function difficultyPanel(){return `<div class="card"><div class="cardtitle"><h2>04 / Le défi du manager</h2><span class="tag">${DIFFICULTIES[S.difficulty||'classique'][0]}</span></div><div class="options">${Object.entries(DIFFICULTIES).map(([k,[title,desc]])=>`<button class="option ${(S.difficulty||'classique')===k?'selected':''}" onclick="setDifficulty('${k}')">${title}<small>${desc}</small></button>`).join('')}</div><p class="help">La difficulté modifie les décisions des adversaires. Aucun attribut, budget ou coefficient de réussite n’est augmenté selon le niveau. Le même moteur et les mêmes règles s’appliquent aux deux équipes. Ce réglage est conservé dans la sauvegarde et pris en compte au prochain coup d’envoi.</p></div>`}
function oppositionPreview(){return oppositionDossierHTML()}
function penaltyControls(l){const policy=l.penaltyPolicies?.[l.userSide]||'auto';return `<label class="eyebrow" for="penalty-policy">SUR PÉNALITÉ</label><select id="penalty-policy" style="margin-top:10px" ${!l.paused||l.finished?'disabled':''} onchange="setPenaltyPolicy(this.value)">${Object.entries(PENALTY_POLICIES).map(([k,title])=>`<option value="${k}" ${policy===k?'selected':''}>${title}</option>`).join('')}</select><p class="help">Selon le contexte : chercher un essai en fin de match si une pénalité ne suffit plus à revenir, ou si le bonus offensif est à portée. Le buteur et la distance déterminent la réussite.</p><p class="help">Jouer vite à la main : le demi relance aussitôt contre une défense mal replacée ; gain, percée ou essai possibles, mais le ballon peut être perdu.</p><p class="help">Adversaire : niveau ${DIFFICULTIES[difficultyLevel(l)][0]}. Aucun bonus d’attribut.</p>`}
