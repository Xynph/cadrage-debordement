'use strict';
// V60 : conferences de presse, climat mediatiques et dynamique d'opinion ; moteur pur.
(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDPressRelations=api})(typeof globalThis==='object'?globalThis:null,function(){
const clamp=n=>Math.max(0,Math.min(100,Math.round(n))),copy=x=>JSON.parse(JSON.stringify(x));
const valid=n=>Number.isFinite(n)&&n>=0&&n<=100;
function create(clubId){if(typeof clubId!=='string'||!clubId)throw Error('Club invalide');return {version:1,clubId,season:1,week:0,mediaTrust:50,fanTrust:50,boardPressure:30,morale:60,stories:[],history:[],used:[]};}
const TOPICS=Object.freeze({derby:{fans:8,media:2,pressure:-1},injury:{fans:0,media:5,pressure:2},form:{fans:4,media:3,pressure:-3},transfers:{fans:3,media:2,pressure:1},objectives:{fans:2,media:6,pressure:-1}});
const TONES=Object.freeze({honest:{media:5,fans:2,morale:1},confident:{media:0,fans:5,morale:4},cautious:{media:2,fans:-1,morale:0},aggressive:{media:-6,fans:1,morale:-3}});
function validate(s){if(!s||s.version!==1||typeof s.clubId!=='string'||!Number.isInteger(s.season)||s.season<1||!Number.isInteger(s.week)||s.week<0||!Array.isArray(s.stories)||!Array.isArray(s.history)||!Array.isArray(s.used)||![s.mediaTrust,s.fanTrust,s.boardPressure,s.morale].every(valid))throw Error('Etat presse invalide');if(new Set(s.used).size!==s.used.length)throw Error('Interview doublee');return true;}
function interview(s,{topic,tone,week,season,performance=0}){validate(s);if(!TOPICS[topic]||!TONES[tone]||!Number.isInteger(week)||week<0||!Number.isInteger(season)||season<1||!Number.isInteger(performance)||performance < -2||performance>2)throw Error('Interview invalide');if(season<s.season||(season===s.season&&week<s.week))throw Error('Date anterieure');const id=season+':'+week+':'+topic;if(s.used.includes(id))throw Error('Interview deja faite');const n=copy(s),t=TOPICS[topic],o=TONES[tone];const delta={mediaTrust:o.media+t.media+performance*2,fanTrust:o.fans+t.fans+performance*3,boardPressure:o.media<0?3:t.pressure-performance*2,morale:o.morale+performance*2};for(const key of Object.keys(delta))n[key]=clamp(n[key]+delta[key]);n.season=season;n.week=week;n.used.push(id);const event={type:'press',id,season,week,topic,tone,performance,delta};n.stories.push(event);n.stories=n.stories.slice(-40);n.history.push({season,week,mediaTrust:n.mediaTrust,fanTrust:n.fanTrust,boardPressure:n.boardPressure,morale:n.morale});return {state:n,event};}
function nextSeason(s){validate(s);const n=copy(s);n.season++;n.week=0;n.mediaTrust=clamp(n.mediaTrust+(50-n.mediaTrust)*.15);n.fanTrust=clamp(n.fanTrust+(50-n.fanTrust)*.1);n.boardPressure=clamp(n.boardPressure+(30-n.boardPressure)*.1);n.used=n.used.filter(x=>Number(x.split(':')[0])>=n.season-1);return n;}
function briefing(s,{lastResults=[],objective=50}={}){validate(s);if(!Array.isArray(lastResults)||lastResults.length>6||!lastResults.every(x=>x===-1||x===0||x===1)||!valid(objective))throw Error('Resultats invalides');const form=lastResults.reduce((n,v)=>n+v,0);return {topic:form<-1?'form':s.boardPressure>65?'objectives':s.fanTrust<35?'derby':'form',risk:clamp(s.boardPressure+Math.max(0,-form)*8),toneSuggestion:s.mediaTrust<45?'honest':'confident'};}

// Personalities describe dialogue in this game, never a real person's biography.
const DIALOGUE_STYLES=Object.freeze({
 technique:{label:'Technique',personality:'Précis et concret : attend des repères de terrain, goûte peu les esquives.',preferences:[0,3,-3,0,-1]},
 analyse:{label:'Analyse',personality:'Pose les faits, compare les tendances et demande un bilan lucide.',preferences:[-1,4,-4,1,0]},
 interview:{label:'Entretien',personality:'À l’écoute du vécu du groupe, apprécie la franchise et une pointe de légèreté.',preferences:[0,3,-3,-1,3]},
 enquete:{label:'Enquête',personality:'Insiste sur les zones floues et les responsabilités ; une pirouette le convainc rarement.',preferences:[-2,4,-4,-2,-3]},
 editorial:{label:'Éditorial',personality:'Cherche une position claire et une formule vive, tout en supportant la contradiction.',preferences:[2,2,-1,-2,2]}
});
const DIALOGUE_TONES=Object.freeze({confident:'Affirmé',honest:'Honnête',aggressive:'Agressif',cautious:'Prudent',humour:'Humour'});
// Chaque ton est un compromis (façon FM), jamais un choix évident :
//  - Affirmé : le vestiaire et les supporters suivent, la presse reste réservée (relation légèrement en baisse) ;
//  - Honnête : relation et médias en hausse, mais admettre une faiblesse coûte du moral et la confiance de la direction ;
//  - Agressif : les joueurs se sentent défendus (moral ++), mais presse -- et la direction s'inquiète (amende, pression) ;
//  - Prudent : neutre, petit gain de confiance de la direction, réponse sans saveur pour la presse ;
//  - Humour : moral +, relation en hausse ou en baisse selon le style du journaliste.
// Le contexte (série de défaites, série de victoires, derby, thème de la question) module chaque ton.
const DIALOGUE_BASE=Object.freeze({confident:{morale:3,media:0,fans:3,pressure:1},honest:{morale:1,media:2,fans:1,pressure:0},aggressive:{morale:4,media:-4,fans:2,pressure:3},cautious:{morale:0,media:-1,fans:-1,pressure:-2},humour:{morale:2,media:0,fans:1,pressure:0}});
const WEAK_THEMES=Object.freeze(['defaite','crise','blessures','discipline','direction','rotation','vestiaire','finances']);
const SENSITIVE_THEMES=Object.freeze(['blessures','crise','defaite','discipline']);
// `situation` : { slump (deux défaites de suite), run (deux victoires de suite), derby }, tous optionnels.
function contextShift(tone,theme,situation){
 const sit=situation||{},weak=WEAK_THEMES.includes(theme),slump=sit.slump===true,run=sit.run===true&&!slump,derby=sit.derby===true||theme==='derby';
 const d={morale:0,media:0,fans:0,pressure:0,relation:0};
 if(tone==='confident'){
  if(slump){d.morale-=2;d.fans-=2;}else if(run){d.fans+=1;}
  if(weak&&theme!=='vestiaire')d.pressure+=1;
  if(derby)d.fans+=1;
 }else if(tone==='honest'){
  if(weak){d.morale-=2;d.pressure+=2;}
  if(slump){d.morale-=1;d.pressure+=1;d.media+=1;d.relation+=1;}
  if(weak)d.relation+=1;
 }else if(tone==='aggressive'){
  if(derby){d.morale+=1;d.media+=2;d.pressure-=1;d.relation+=1;}
  if(slump){d.morale+=1;d.pressure+=1;d.media-=1;}
  if(run){d.pressure+=1;}
  if(theme==='discipline'||theme==='crise')d.pressure+=2;
 }else if(tone==='cautious'){
  if(slump){d.media-=1;}
  if(derby){d.media-=1;d.fans-=1;}
 }else if(tone==='humour'){
  if(derby||run)d.fans+=1;
  if(slump)d.media-=1;
 }
 return d;
}
function dialogueEffect(journalist,tone,theme,score=0,situation=null){
 const style=DIALOGUE_STYLES[journalist?.style],base=DIALOGUE_BASE[tone];if(!style||!base||!Number.isInteger(score)||score < -100||score>100)throw Error('Dialogue de journaliste invalide');
 const slump=!!situation&&situation.slump===true,sensitive=SENSITIVE_THEMES.includes(theme),shift=contextShift(tone,theme,situation),humourHit=tone==='humour'&&sensitive;
 const relation=Math.max(-6,Math.min(6,style.preferences[Object.keys(DIALOGUE_TONES).indexOf(tone)]-(humourHit?2:0)+shift.relation));
 const taste=relation>=2?1:relation<=-2?-1:0;
 const media=base.media+taste+shift.media+(tone==='humour'&&score < -25?-1:0);
 return {morale:base.morale+shift.morale-(humourHit?1:0),media,fans:base.fans+shift.fans-(humourHit?1:0),pressure:base.pressure+shift.pressure+(humourHit?1:0),relation};
}
function relationLabel(score,encounters=1){return !encounters?'Aucun échange':score>=30?'Complice':score>=10?'En confiance':score<=-30?'Tendue':score<=-10?'Méfiance':'À découvrir';}
function recordDialogue(people,journalist,{season,week,club,questionId,answerId},delta){
 const n=people?copy(people):{version:1,contacts:{}},old=n.contacts[journalist.id]||{score:0,encounters:0,memory:[]};
 const score=Math.max(-100,Math.min(100,old.score+delta));n.contacts[journalist.id]={score,encounters:old.encounters+1,memory:[...old.memory,{season,week,club,questionId,answerId,delta:score-old.score}].slice(-3)};return n;
}

return Object.freeze({dialogueStyles:DIALOGUE_STYLES,dialogueTones:DIALOGUE_TONES,dialogueEffect,contextShift,relationLabel,recordDialogue,create,validate,interview,nextSeason,briefing,topics:Object.keys(TOPICS),tones:Object.keys(TONES)});
});
