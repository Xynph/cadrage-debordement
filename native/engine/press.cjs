'use strict';
const files=Object.freeze(['press-relations.js','press-question-bank.js','media-evidence-v60.js','media-native-adapter-v60.js','media-world-v60.js','press-conference-interactive.js']);
const commands=Object.freeze(['press_conference']);
function factory(){
 const copy=x=>JSON.parse(JSON.stringify(x)),obj=x=>!!x&&typeof x==='object'&&!Array.isArray(x),int=(x,a,b)=>Number.isInteger(x)&&x>=a&&x<=b,num=(x,a,b)=>Number.isFinite(x)&&x>=a&&x<=b;
 const check=(ok,message='État de presse invalide.')=>{if(!ok)throw Error(message);};
 const weekOf=s=>s.franceMode?.version===1?s.franceMode.week:s.round;
 const maxWeek=s=>s.franceMode?.version===1?34:26;
 const context=s=>({season:s.season,week:weekOf(s),club:s.club});
 const keys=(value,allowed)=>obj(value)&&Object.keys(value).every(k=>allowed.includes(k));
 const text=t=>typeof t==='string'&&t.length>0&&t.length<=600&&!/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(t);
 const reporter=id=>CDPressQuestionBank.journalists.find(j=>j.id===id);
 const validAnswer=(id,answerId)=>CDPressQuestionBank.questions.some(q=>q.id===id&&q.answers.some(a=>a.id===answerId));
 function validate(s){
  if(!s)return true;
  const date=(season,week)=>int(season,1,s.season)&&int(week,0,maxWeek(s))&&(season<s.season||week<=weekOf(s));
  const clubId=id=>typeof id==='string'&&/^club-\d+$/.test(id)&&int(Number(id.slice(5)),0,s.clubs.length-1);
  if(s.pressRelations!==undefined){
   const p=s.pressRelations;check(keys(p,['version','clubId','season','week','mediaTrust','fanTrust','boardPressure','morale','stories','history','used'])&&p.version===1&&clubId(p.clubId)&&date(p.season,p.week));
   check([p.mediaTrust,p.fanTrust,p.boardPressure,p.morale].every(x=>num(x,0,100)));
   check(Array.isArray(p.stories)&&p.stories.length<=40&&Array.isArray(p.history)&&p.history.length<=500&&Array.isArray(p.used)&&p.used.length<=500);
   const ownDate=(season,week)=>date(season,week)&&(season<p.season||season===p.season&&week<=p.week);
   check(new Set(p.used).size===p.used.length,'Interview de presse répétée.');
   check(new Set(p.stories.map(e=>e?.id)).size===p.stories.length,'Histoire de presse répétée.');
   for(const id of p.used){const m=typeof id==='string'&&id.match(/^(\d+):(\d+):([a-z]+)$/);check(m&&ownDate(+m[1],+m[2])&&CDPressRelations.topics.includes(m[3]));}
   for(const e of p.stories){check(keys(e,['type','id','season','week','topic','tone','performance','delta'])&&e.type==='press'&&ownDate(e.season,e.week)&&CDPressRelations.topics.includes(e.topic)&&CDPressRelations.tones.includes(e.tone)&&int(e.performance,-2,2)&&e.id===e.season+':'+e.week+':'+e.topic&&(e.season<p.season-1||p.used.includes(e.id)));check(keys(e.delta,['mediaTrust','fanTrust','boardPressure','morale'])&&Object.keys(e.delta).length===4&&Object.values(e.delta).every(x=>num(x,-30,30)));}
   let prior=-1;for(const h of p.history){check(keys(h,['season','week','mediaTrust','fanTrust','boardPressure','morale'])&&ownDate(h.season,h.week)&&[h.mediaTrust,h.fanTrust,h.boardPressure,h.morale].every(x=>num(x,0,100)));const d=h.season*100+h.week;check(d>=prior);prior=d;}
  }
  if(s.pressConference!==undefined){
   const p=s.pressConference;check(keys(p,['version','history','lastOutcome','week','season','club'])&&p.version===1&&Array.isArray(p.history)&&p.history.length<=500,'Historique de conférence de presse invalide.');
   if(p.week!==undefined)check(int(p.week,0,maxWeek(s)));if(p.season!==undefined)check(int(p.season,1,s.season));if(p.club!==undefined)check(int(p.club,0,s.clubs.length-1));
   const seen=new Set(),groups=new Map();let previous=-1;
   for(const h of p.history){check(keys(h,['id','season','week','answerId','club','questionText','answerText','journalist'])&&date(h.season,h.week)&&CDPressQuestionBank.questions.some(q=>q.id===h.id)&&/^r[0-4]$/.test(h.answerId)&&(h.club===undefined||int(h.club,0,s.clubs.length-1)),'Choix de conférence de presse invalide.');if(h.journalist!==undefined)check(keys(h.journalist,['id','name','outlet'])&&Object.keys(h.journalist).length===3&&!!reporter(h.journalist.id)&&text(h.journalist.name)&&text(h.journalist.outlet),'Journaliste de conférence invalide.');if(h.questionText!==undefined||h.answerText!==undefined)check([h.questionText,h.answerText].every(t=>typeof t==='string'&&t.length>0&&t.length<=600&&!/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(t)),'Libellé de conférence de presse invalide.');const key=h.season+':'+h.week+':'+(h.club??'legacy'),id=key+':'+h.id;check(!seen.has(id),'Choix de conférence de presse répété.');seen.add(id);groups.set(key,(groups.get(key)||0)+1);check(groups.get(key)<=4);const d=h.season*100+h.week;check(d>=previous);previous=d;}
   if(p.lastOutcome!==undefined){const o=p.lastOutcome;check(keys(o,['context','before','after','delta','exchanges'])&&keys(o.context,['season','week','club'])&&date(o.context.season,o.context.week)&&int(o.context.club,0,s.clubs.length-1));for(const key of ['before','after','delta'])check(keys(o[key],['morale','trust','mediaTrust','fanTrust','boardPressure'])&&Object.keys(o[key]).length===5&&Object.values(o[key]).every(x=>num(x,key==='delta'?-100:0,100)));for(const key of Object.keys(o.delta))check(o.after[key]-o.before[key]===o.delta[key]);if(o.exchanges!==undefined){check(Array.isArray(o.exchanges)&&o.exchanges.length>=2&&o.exchanges.length<=4);for(const e of o.exchanges)check(keys(e,['journalistId','before','after','delta'])&&Object.keys(e).length===4&&!!reporter(e.journalistId)&&int(e.before,-100,100)&&int(e.after,-100,100)&&int(e.delta,-6,6)&&e.after-e.before===e.delta,'Retour de relation journaliste invalide.');}check(p.history.some(h=>h.season===o.context.season&&h.week===o.context.week&&(h.club===undefined||h.club===o.context.club)));}
  }
  if(s.pressPeople!==undefined){
   const p=s.pressPeople;check(keys(p,['version','contacts'])&&Object.keys(p).length===2&&p.version===1&&obj(p.contacts)&&Object.keys(p.contacts).length<=30,'Relations personnelles de presse invalides.');
   check(JSON.stringify(p).length<30000,'Mémoire des journalistes trop volumineuse.');
   for(const [id,c] of Object.entries(p.contacts)){
    check(!!reporter(id)&&keys(c,['score','encounters','memory'])&&Object.keys(c).length===3&&int(c.score,-100,100)&&int(c.encounters,1,10000000)&&Array.isArray(c.memory)&&c.memory.length===Math.min(3,c.encounters),'Relation de journaliste invalide.');
    const seen=new Set();let previous=-1;
    for(const e of c.memory){check(keys(e,['season','week','club','questionId','answerId','delta'])&&Object.keys(e).length===6&&date(e.season,e.week)&&int(e.club,0,s.clubs.length-1)&&validAnswer(e.questionId,e.answerId)&&int(e.delta,-6,6),'Mémoire de journaliste invalide.');const archived=s.pressConference?.history?.find(h=>h.season===e.season&&h.week===e.week&&h.club===e.club&&h.id===e.questionId);if(archived)check(archived.journalist?.id===id&&archived.answerId===e.answerId,'Mémoire de journaliste incompatible avec la conférence conservée.');const key=e.season+':'+e.week+':'+e.club+':'+e.questionId,d=e.season*100+e.week;check(!seen.has(key)&&d>=previous,'Mémoire de journaliste répétée ou désordonnée.');seen.add(key);previous=d;}
   }
  }
  return true;
 }
 function measures(s){const p=s.pressRelations;return {morale:s.morale,trust:s.trust,mediaTrust:p?.mediaTrust??50,fanTrust:p?.fanTrust??50,boardPressure:p?.boardPressure??30};}
 function project(){
  if(!S)return null;
  const events=CDMediaNativeAdapter.collect(S),divisionIds=S.franceMode?.version===1?['elite','accession','access']:['historical'];
  const divisions=divisionIds.map(id=>({id,label:({elite:'Élite',accession:'Accession',access:'Barrage d’accession',historical:'Championnat historique'})[id],standings:events.filter(e=>e.kind==='standing'&&e.facts.divisionId===id).map(e=>copy(e.facts)),results:events.filter(e=>e.kind==='result'&&e.facts.divisionId===id).slice(-24).reverse().map(e=>({id:e.id,season:e.season,week:e.week,...copy(e.facts)})),injuries:events.filter(e=>e.kind==='injury'&&e.facts.divisionId===id).map(e=>({...copy(e.facts),playerName:S.clubs.find(c=>c.id===e.facts.clubId)?.players?.find(p=>p.id===e.facts.playerId)?.name||String(e.facts.playerId)}))})).filter(d=>d.standings.length||d.results.length||d.injuries.length);
  const people=CDPressQuestionBank.journalists.map(j=>{
   const c=S.pressPeople?.contacts?.[j.id],score=c?.score??0,encounters=c?.encounters??0,style=CDPressRelations.dialogueStyles[j.style];
   return {...copy(j),identityLabel:j.fictional?'Personnage fictif':'Journaliste référencé',personality:style.personality,styleLabel:style.label,score,encounters,relationLabel:CDPressRelations.relationLabel(score,encounters),memory:(c?.memory||[]).map(e=>{const h=S.pressConference?.history?.find(h=>h.journalist?.id===j.id&&h.season===e.season&&h.week===e.week&&h.club===e.club&&h.id===e.questionId&&h.answerId===e.answerId);return {...copy(e),question:h?.questionText??null,answer:h?.answerText??null,toneLabel:CDPressRelations.dialogueTones[CDPressQuestionBank.questions.find(q=>q.id===e.questionId).answers.find(a=>a.id===e.answerId).tone]};})};
  });
  const questions=CDV60RichPress.prepare(S),projected=questions?.map(q=>{
   const person=people.find(p=>p.id===q.journalist.id);
   return {...copy(q),journalist:{...copy(q.journalist),identityLabel:person.identityLabel,personality:person.personality,styleLabel:person.styleLabel},relation:{score:person.score,label:person.relationLabel,encounters:person.encounters},answers:q.answers.map(a=>{const effects=CDPressRelations.dialogueEffect(q.journalist,a.tone,q.theme,person.score),mod=['crise','direction'].includes(q.theme)?2:1;const applied={morale:effects.morale*mod,media:effects.media*mod,fans:effects.fans*mod,pressure:effects.pressure*mod,relation:Math.max(-100,Math.min(100,person.score+effects.relation))-person.score};const signed=n=>n>=0?'+'+n:String(n);return {...copy(a),toneLabel:CDPressRelations.dialogueTones[a.tone],effects:applied,consequence:'Moral '+signed(applied.morale)+' · médias '+signed(applied.media)+' · supporters '+signed(applied.fans)+' · pression '+signed(applied.pressure)+' · relation '+signed(applied.relation)};})};
  });
  return {context:context(S),notice:'Dialogues et personnalités simulés. Catalogue de journalistes référencés et de personnages fictifs ; aucune citation réelle. Les relations sont personnelles au coach.',journal:{divisions},metrics:measures(S),people,conference:{available:!!questions,reason:S.live?'Conférence indisponible pendant un match.':questions?'':'Conférence déjà réalisée cette semaine.',questions:projected||[]},history:copy((S.pressConference?.history||[]).slice(-40)).map(h=>({...h,question:h.questionText??null,answer:h.answerText??null})),lastOutcome:copy(S.pressConference?.lastOutcome||null)};
 }
 function execute(command,payload){
  check(command==='press_conference','Commande de presse inconnue.');check(!!S,'Créez ou importez une carrière.');check(!S.live,'Conférence indisponible pendant un match.');validate(S);
  check(keys(payload,['context','answers'])&&keys(payload.context,['season','week','club'])&&Object.keys(payload.context).length===3&&Array.isArray(payload.answers),'Paramètres de conférence de presse invalides.');
  check(JSON.stringify(context(S))===JSON.stringify({season:payload.context.season,week:payload.context.week,club:payload.context.club}),'Préparation de conférence périmée.');
  const questions=CDV60RichPress.prepare(S);check(!!questions,'Conférence déjà réalisée cette semaine.');check(payload.answers.length===questions.length,'Réponses de conférence incomplètes.');
  questions.forEach((q,i)=>check(keys(payload.answers[i],['questionId','answerId'])&&payload.answers[i].questionId===q.id&&q.answers.some(a=>a.id===payload.answers[i].answerId),'Question ou réponse de conférence périmée.'));
  const scores=questions.map(q=>({journalistId:q.journalist.id,before:S.pressPeople?.contacts?.[q.journalist.id]?.score??0}));
  const before=measures(S);check(CDV60RichPress.apply(S,payload.answers.map(a=>a.answerId))===true,'Conférence de presse refusée.');const after=measures(S),delta=Object.fromEntries(Object.keys(before).map(k=>[k,after[k]-before[k]]));
  S.pressConference.lastOutcome={context:context(S),before,after,delta,exchanges:scores.map(e=>{const after=S.pressPeople.contacts[e.journalistId].score;return {...e,after,delta:after-e.before};})};validate(S);return {pressOutcome:copy(S.pressConference.lastOutcome)};
 }
 function installHooks(){
  if(typeof advanceSeason!=='function'||advanceSeason.__nativePressSeason)return true;
  const previous=advanceSeason;
  const wrapped=function(...args){const result=previous(...args);if(S?.pressRelations)while(S.pressRelations.season<S.season)S.pressRelations=CDPressRelations.nextSeason(S.pressRelations);return result;};
  wrapped.__nativePressSeason=true;advanceSeason=wrapped;return true;
 }
 return {project,validate,execute,installHooks};
}
module.exports={files,commands,factory};
