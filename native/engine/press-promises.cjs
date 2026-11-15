'use strict';
// Promesses publiques en conférence de presse (carrière Monde). Le manager peut annoncer un objectif chiffré
// (place au classement, Coupe des champions, maintien, victoires à domicile, jeunes du centre lancés) ou refuser
// de s'engager. La promesse est jugée à sa vraisemblance dès l'annonce (presse, supporters, direction), suivie
// pendant la saison (rappels de la presse et de Gabi), puis vérifiée à l'échéance : fin de la saison régulière
// pour le classement, les victoires à domicile et les jeunes ; tirage de la saison suivante pour la Coupe des
// champions et le maintien. Une promesse tenue ou non pèse sur les supporters, la direction et la crédibilité
// publique du manager, qui entre dans sa réputation sur le marché des entraîneurs.
// Articulation avec la direction (club_board_objective) : la promesse ne crée aucun objectif du conseil. Si le
// conseil a fixé une place au classement, une promesse en dessous de cette place le froisse à l'annonce, et le
// verdict de la promesse ne compte que pour moitié auprès du conseil, qui juge déjà son propre objectif.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const copy=x=>JSON.parse(JSON.stringify(x)),obj=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const int=(x,a,b)=>Number.isInteger(x)&&x>=a&&x<=b,num=(x,a,b)=>Number.isFinite(x)&&x>=a&&x<=b;
 const keys=(x,list)=>obj(x)&&Object.keys(x).every(k=>list.includes(k));
 const check=(ok,message)=>{if(!ok)throw Error('Promesses publiques : '+message+'.');};
 const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
 const world=s=>typeof CDWorldCareer!=='undefined'&&!!s&&CDWorldCareer.active(s);
 const weekOf=s=>s.round;
 const maxWeek=s=>world(s)?CDWorldCareer.sizing(s).maxRound:60;
 const KINDS=['rank','europe','maintien','home_wins','youth'];
 const REALISM=['modeste','realiste','ambitieux','irrealiste'];
 const REALISM_LABELS={modeste:'Modeste',realiste:'Réaliste',ambitieux:'Ambitieux',irrealiste:'Irréaliste'};
 const STATUS=['pending','kept','broken','unverified'];
 const LIMIT=24,REFUSALS=12,PER_SEASON=2,YOUTH_IDS=40;
 // Ligues où la Coupe des champions et le maintien ont un sens dans le monde simulé.
 const EUROPE_LEAGUES=['elite','prem','urc'],EUROPE_PLACE=8;
 const LEVELS={elite:1,accession:2,nationale:3,'jlo-d1':1,'jlo-d2':2},MAINTIEN_LEAGUES=['elite','accession','jlo-d1'];
 // Effets (points de jauge) : annonce, refus, verdict. Crédibilité : 0 à 100, 50 au départ.
 const ANNOUNCE={modeste:{fanTrust:-2,mediaTrust:0,boardPressure:-1,trust:-2},realiste:{fanTrust:2,mediaTrust:1,boardPressure:0,trust:1},ambitieux:{fanTrust:4,mediaTrust:1,boardPressure:3,trust:0},irrealiste:{fanTrust:3,mediaTrust:-4,boardPressure:6,trust:-3}};
 const REFUSE={fanTrust:-1,mediaTrust:-1,boardPressure:0,trust:0};
 const KEPT={modeste:{fanTrust:2,mediaTrust:1,boardPressure:-1,trust:1,credibility:2},realiste:{fanTrust:5,mediaTrust:2,boardPressure:-3,trust:3,credibility:5},ambitieux:{fanTrust:8,mediaTrust:3,boardPressure:-5,trust:5,credibility:8},irrealiste:{fanTrust:10,mediaTrust:4,boardPressure:-6,trust:6,credibility:10}};
 const BROKEN={modeste:{fanTrust:-8,mediaTrust:-3,boardPressure:6,trust:-6,credibility:-10},realiste:{fanTrust:-6,mediaTrust:-2,boardPressure:5,trust:-4,credibility:-7},ambitieux:{fanTrust:-5,mediaTrust:-2,boardPressure:4,trust:-3,credibility:-5},irrealiste:{fanTrust:-7,mediaTrust:-4,boardPressure:7,trust:-5,credibility:-9}};
 const GAUGES=['fanTrust','mediaTrust','boardPressure','trust'];
 const QUESTION='Les supporters veulent un chiffre : quel objectif annoncez-vous publiquement pour cette saison ?';
 const signed=n=>(n>0?'+':n<0?'−':'')+Math.abs(Math.round(n));
 const effectText=e=>'Supporters '+signed(e.fanTrust)+' · médias '+signed(e.mediaTrust)+' · confiance '+signed(e.trust)+' · pression '+signed(e.boardPressure);
 const ordinal=n=>n===1?'1re':n+'e';
 const message=(title,body,kind='club')=>{if(typeof managerMessage==='function')managerMessage(title,body,kind,'dashboard');};
 const seasonLabel=n=>(typeof libelleSaison==='function'?libelleSaison:String)(n);

 function state(s){return s.pressPromises||{version:1,credibility:50,promises:[],refusals:[]};}
 function ensure(s){if(!s.pressPromises)s.pressPromises=state(s);return s.pressPromises;}
 function clubKey(s,club=s.club){return s.clubs[club]?.id??club;}
 function leagueOf(s,club=s.club){try{return CDWorldCareer.leagueId(s,clubKey(s,club));}catch{return null;}}
 function table(s,leagueId){try{return CDWorldCareer.ranked(s,leagueId);}catch{return [];}}
 // Force d'un club : moyenne des 23 meilleures notes de l'effectif professionnel.
 function strength(club){const r=(club?.players||[]).map(p=>Number(p.rating)||0).sort((a,b)=>b-a).slice(0,23);return r.length?r.reduce((a,b)=>a+b,0)/r.length:0;}
 function expectation(s){
  const leagueId=leagueOf(s),rows=table(s,leagueId),own=clubKey(s);
  if(!leagueId||rows.length<4)return null;
  const mine=strength(s.clubs[s.club]),stronger=rows.filter(r=>r.id!==own&&strength(s.clubs.find(c=>c?.id===r.id)??s.clubs[r.id])>mine).length;
  const size=rows.length,expected=stronger+1;
  const fixtures=(s.worldMode?.fixtures||[]).filter(f=>f.competitionId===leagueId&&f.phase==='league'&&f.homeId===own).length;
  const homes=fixtures||size-1;
  const rate=clamp(.85-.6*(expected-1)/Math.max(1,size-1),.25,.9);
  return {leagueId,size,expected,homes,homeWins:Math.round(homes*rate)};
 }
 // Le titre se promet toujours au moins « ambitieux » : même le favori n'est jamais sûr de finir premier.
 function rankRealism(target,expected){const gap=expected-target;return gap>=4||target===1&&expected>=3?'irrealiste':gap>=2||target===1?'ambitieux':gap>=-2?'realiste':'modeste';}
 function countRealism(target,expected){const d=target-expected;return d>=4?'irrealiste':d>=2?'ambitieux':d>=-2?'realiste':'modeste';}
 const youthCandidates=s=>(s.development?.academy||[]).filter(p=>Number(p.age)>=18).length;
 function youthRealism(n,c){return c>=3*n?'realiste':c>=2*n?'ambitieux':'irrealiste';}
 function label(kind,target){
  return kind==='rank'?(target===1?'Finir premier de la saison régulière':'Finir dans le top '+target):kind==='europe'?'Qualifier le club en Coupe des champions':kind==='maintien'?'Assurer le maintien':kind==='home_wins'?'Gagner '+target+' matchs à domicile en championnat':'Lancer '+target+' jeunes du centre en équipe première';
 }
 // Place équivalente (pour comparer avec l'objectif de classement du conseil).
 const rankEquivalent=(kind,target,size)=>kind==='rank'?target:kind==='europe'?EUROPE_PLACE:kind==='maintien'?size-2:null;
 function boardRank(s){const o=(s.nativeBoardCalendar?.season===s.season?s.nativeBoardCalendar.objectives:[])||[];const r=o.find(x=>x.type==='rank'&&x.status==='pending');return r&&Number.isFinite(r.target)?r.target:null;}
 function seasonEntries(s,season=s.season){const p=state(s);return {promises:p.promises.filter(x=>x.season===season&&x.club===s.club),refused:p.refusals.some(r=>r.season===season&&r.club===s.club)};}
 const answeredHere=s=>{const p=state(s),w=weekOf(s);return p.promises.some(x=>x.season===s.season&&x.week===w&&x.club===s.club)||p.refusals.some(r=>r.season===s.season&&r.week===w&&r.club===s.club);};
 function windowOpen(s,invitation){
  if(!world(s)||s.live||s.phase==='ended')return false;
  if(invitation&&!['arrival','weekly'].includes(invitation.kind))return false;
  if(weekOf(s)>Math.floor(maxWeek(s)*.45))return false;
  const own=seasonEntries(s);
  return !own.refused&&own.promises.length<PER_SEASON&&!answeredHere(s);
 }
 function options(s){
  const e=expectation(s);if(!e)return [];
  const taken=new Set(seasonEntries(s).promises.map(p=>p.kind)),out=[],board=boardRank(s);
  const add=(kind,target,realism,extra={})=>{if(taken.has(kind))return;const id=kind+(target===null?'':':'+target);if(out.some(o=>o.id===id))return;
   const effects={...ANNOUNCE[realism]},equivalent=rankEquivalent(kind,target,e.size);let boardNote=null;
   if(board!==null&&equivalent!==null){if(equivalent>board){effects.trust-=2;boardNote='En dessous de l’objectif du conseil ('+ordinal(board)+' place) : la direction attendait plus.';}else boardNote='Conforme à l’objectif du conseil ('+ordinal(board)+' place).';}
   if(state(s).credibility<35)effects.mediaTrust-=1;
   out.push({id,kind,target,label:label(kind,target),realism,realismLabel:REALISM_LABELS[realism],effects,consequence:effectText(effects),boardNote,...extra});};
  const ranks=[...new Set([Math.max(1,e.expected-4),Math.max(1,e.expected-2),Math.min(e.size-1,e.expected+1),Math.min(e.size-1,e.expected+3)])].sort((a,b)=>a-b).slice(0,3);
  for(const t of ranks)add('rank',t,rankRealism(t,e.expected),{reference:'Place attendue selon l’effectif : '+ordinal(e.expected)+' sur '+e.size});
  if(EUROPE_LEAGUES.includes(e.leagueId))add('europe',null,rankRealism(EUROPE_PLACE,e.expected),{reference:'Repère : les '+EUROPE_PLACE+' premiers du championnat'});
  if(MAINTIEN_LEAGUES.includes(e.leagueId))add('maintien',null,rankRealism(e.size-2,e.expected),{reference:'Repère : '+ordinal(e.size-2)+' place ou mieux'});
  for(const t of [...new Set([Math.max(1,e.homeWins),Math.min(e.homes,e.homeWins+3)])])add('home_wins',t,countRealism(t,e.homeWins),{reference:e.homes+' matchs à domicile en championnat'});
  const c=youthCandidates(s),n=c>=6?3:2;if(c>0)add('youth',n,youthRealism(n,c),{reference:c+' joueurs de 18 ans et plus au centre'});
  return out;
 }
 // Projection de la question pour la conférence (null quand elle n'est pas posée).
 function offer(s,invitation,moment){
  if(!windowOpen(s,invitation))return null;
  const list=options(s);if(!list.length)return null;
  return {question:QUESTION,optional:true,options:list,refuse:{id:'refuse',label:'Ne rien promettre : « On jugera sur le terrain. »',effects:{...REFUSE},consequence:effectText(REFUSE)},notice:'Facultatif. Une promesse est vérifiée à son échéance ; refuser clôt la question pour la saison.',moment:moment?.kind??null};
 }
 function assertChoice(s,choice,invitation){
  check(typeof choice==='string'&&choice.length<=40,'choix invalide');
  check(windowOpen(s,invitation),'aucune question d’objectif dans cette conférence');
  if(choice==='refuse')return true;
  check(options(s).some(o=>o.id===choice),'objectif périmé ou inconnu');return true;
 }
 function applyEffects(s,delta,scale=1){
  const applied={};const p=s.pressRelations;
  for(const k of GAUGES.filter(k=>k in delta)){const d=Math.round(delta[k]*scale);
   if(k==='trust'){const before=s.trust??50;s.trust=clamp(before+d,0,100);applied[k]=s.trust-before;}
   else if(p&&Number.isFinite(p[k])){const before=p[k];p[k]=clamp(before+d,0,100);applied[k]=p[k]-before;}else applied[k]=0;}
  return applied;
 }
 function announce(s,choice,invitation){
  assertChoice(s,choice,invitation);
  const st=ensure(s),w=weekOf(s);
  if(choice==='refuse'){
   const effects=applyEffects(s,REFUSE);
   st.refusals=[...st.refusals,{season:s.season,week:w,club:s.club}].slice(-REFUSALS);
   return {choice,refused:true,effects};
  }
  const o=options(s).find(x=>x.id===choice),e=expectation(s);
  const effects=applyEffects(s,o.effects);
  const promise={id:'promesse:'+s.season+':'+s.club+':'+o.kind,season:s.season,week:w,club:s.club,kind:o.kind,target:o.target,label:o.label,realism:o.realism,leagueId:e.leagueId,expected:e.expected,size:e.size,board:boardRank(s),status:'pending',announce:effects,verdict:null,result:null,reminders:[],youthIds:[]};
  st.promises=[...st.promises,promise].slice(-LIMIT);
  const club=s.clubs[s.club]?.name||'le club';
  if(o.realism==='irrealiste'){
   message('La presse doute de votre promesse','« '+o.label+' » : la presse locale juge l’annonce intenable pour '+club+'. Médias '+signed(effects.mediaTrust)+'. Elle vous le rappellera.');
   message('La direction s’inquiète','Le conseil n’aime pas les promesses publiques qu’il juge irréalistes : « '+o.label+' ». Pression '+signed(effects.boardPressure)+', confiance '+signed(effects.trust)+'.');
  }else if(o.realism==='modeste')message('La direction attendait plus d’ambition','« '+o.label+' » : le conseil trouve l’objectif timide pour '+club+'. Confiance '+signed(effects.trust)+'.');
  else if(o.realism==='ambitieux')message('Les supporters y croient','« '+o.label+' » : l’annonce enflamme les tribunes (supporters '+signed(effects.fanTrust)+'), mais le conseil vous attend au tournant (pression '+signed(effects.boardPressure)+').');
  return {choice,promise:copy(promise),effects};
 }
 // Valeur mesurée à ce jour (ou au verdict) ; null quand elle ne se mesure qu'au tirage suivant.
 function measure(s,p){
  if(p.kind==='rank'||p.kind==='europe'||p.kind==='maintien'){
   const rows=table(s,p.leagueId),own=clubKey(s,p.club),row=rows.find(r=>r.id===own);
   return row&&row.played>0?{value:rows.indexOf(row)+1,played:row.played}:{value:null,played:0};
  }
  if(p.kind==='home_wins'){
   // Domicile lu sur le calendrier (homeId de la rencontre), le score dans l'ordre de la paire jouée.
   const own=clubKey(s,p.club),homes=(s.worldMode?.fixtures||[]).filter(f=>f.competitionId===p.leagueId&&f.phase==='league'&&f.homeId===own),ids=new Set(homes.map(f=>f.id));let wins=0,played=0;
   for(const m of s.history||[]){if((m.season??s.season)!==p.season||!ids.has(m.fixtureId)||!Array.isArray(m.pair)||!Array.isArray(m.score))continue;played++;const i=m.pair.indexOf(own);if(i>=0&&m.score[i]>m.score[1-i])wins++;}
   return {value:wins,played,remaining:Math.max(0,homes.length-played)};
  }
  return {value:p.youthIds.length};
 }
 function progress(s,p){
  const m=measure(s,p),ref=p.kind==='europe'?EUROPE_PLACE:p.kind==='maintien'?p.size-2:p.target;
  if(p.status!=='pending'){const v=p.result?.value??null,word=p.status==='kept'?'Tenue':p.status==='broken'?'Non tenue':'Non vérifiée';return {value:v,label:word,short:word,onTrack:p.status==='unverified'?null:p.status==='kept'};}
  if(['rank','europe','maintien'].includes(p.kind)){if(m.value===null)return {value:null,label:'Pas encore de classement',short:'Pas de classement',onTrack:null};return {value:m.value,label:ordinal(m.value)+' actuellement (repère : '+ordinal(ref)+')',short:ordinal(m.value)+' (repère '+ordinal(ref)+')',onTrack:m.value<=ref};}
  if(p.kind==='home_wins')return {value:m.value,label:m.value+' / '+p.target+' victoires · '+m.remaining+' match(s) à domicile restant(s)',short:m.value+' / '+p.target+' · '+m.remaining+' à jouer',onTrack:m.value>=p.target||p.target-m.value<=m.remaining*Math.max(.5,p.target/Math.max(1,m.played+m.remaining))};
  return {value:m.value,label:m.value+' / '+p.target+' jeunes lancés',short:m.value+' / '+p.target+' lancés',onTrack:m.value>=p.target};
 }
 function settleOne(s,p,value,kept,detail){
  const own=p.club===s.club,base=(kept?KEPT:BROKEN)[p.realism],scale=p.board!==null&&rankEquivalent(p.kind,p.target,p.size)!==null?.5:1;
  // Le conseil juge déjà son propre objectif de classement : la promesse ne compte que pour moitié auprès de lui.
  const verdict=own?applyEffects(s,{fanTrust:base.fanTrust,mediaTrust:base.mediaTrust}):{fanTrust:0,mediaTrust:0};
  Object.assign(verdict,own?applyEffects(s,{trust:base.trust,boardPressure:base.boardPressure},scale):{trust:0,boardPressure:0});
  const st=ensure(s),before=st.credibility;st.credibility=clamp(before+base.credibility,0,100);verdict.credibility=st.credibility-before;
  p.status=kept?'kept':'broken';p.verdict=verdict;p.result={value,season:s.season,week:weekOf(s)};
  message(kept?'Promesse tenue : '+p.label:'Promesse non tenue : '+p.label,detail+' Supporters '+signed(verdict.fanTrust)+' · confiance '+signed(verdict.trust)+' · crédibilité '+signed(verdict.credibility)+'.'+(own?'':' (Promesse faite à votre ancien club.)'));
  if(!kept&&own)message('Gabi : après la promesse manquée','« La presse va ressortir votre déclaration. Ne promettons plus que ce que l’effectif peut tenir, et parlons-en au conseil avant de l’annoncer. »','staff');
 }
 // Verdicts mesurables en fin de saison régulière (classement, victoires à domicile, jeunes).
 function settleSeason(s){
  if(!s?.pressPromises)return 0;let n=0;
  for(const p of s.pressPromises.promises){
   if(p.status!=='pending'||p.season!==s.season||!['rank','home_wins','youth'].includes(p.kind))continue;
   const m=measure(s,p);
   if(p.kind==='rank'){if(m.value===null){p.status='unverified';p.result={value:null,season:s.season,week:weekOf(s)};continue;}settleOne(s,p,m.value,m.value<=p.target,'Classement final : '+ordinal(m.value)+' pour un objectif du top '+p.target+'.');}
   else if(p.kind==='home_wins')settleOne(s,p,m.value,m.value>=p.target,m.value+' victoire(s) à domicile en championnat pour '+p.target+' promise(s).');
   else settleOne(s,p,m.value,m.value>=p.target,m.value+' jeune(s) du centre lancé(s) pour '+p.target+' promis.');
   n++;
  }
  return n;
 }
 // Verdicts du tirage suivant : Coupe des champions et maintien (après le passage à la nouvelle saison).
 function settleDraw(s){
  if(!s?.pressPromises||!world(s))return 0;let n=0;
  for(const p of s.pressPromises.promises){
   if(p.status!=='pending'||p.season!==s.season-1||!['europe','maintien'].includes(p.kind))continue;
   const own=clubKey(s,p.club);
   if(p.kind==='europe'){const pools=s.worldMode?.europe?.champions?.pools;if(!Array.isArray(pools)){p.status='unverified';p.result={value:null,season:s.season,week:weekOf(s)};continue;}const q=pools.flat().includes(own);settleOne(s,p,q?1:0,q,q?'Le club figure au tirage de la Coupe des champions.':'Le club est absent du tirage de la Coupe des champions.');}
   else{const now=leagueOf(s,p.club),before=LEVELS[p.leagueId],after=LEVELS[now];if(!before||!after){p.status='unverified';p.result={value:null,season:s.season,week:weekOf(s)};continue;}const kept=after<=before;settleOne(s,p,after,kept,kept?'Le club reste dans sa division (ou monte).':'Le club est relégué.');}
   n++;
  }
  return n;
 }
 // Suivi : rappels de la presse et de Gabi à mi-parcours et pour le sprint final ; relevé des jeunes lancés.
 function observeWeek(s){
  if(!s?.pressPromises||!world(s))return;
  for(const p of s.pressPromises.promises){
   if(p.status!=='pending'||p.season!==s.season||p.club!==s.club)continue;
   if(p.kind==='youth')for(const pl of s.clubs[s.club]?.players||[]){if(p.youthIds.length>=YOUTH_IDS)break;if((pl.espoirLoan===true||pl.academy===false&&pl.joinedSeason===p.season&&Number(pl.age)<=22)&&!p.youthIds.includes(pl.id))p.youthIds.push(pl.id);}
   if(s.phase==='ended')continue;
   const rows=table(s,p.leagueId),row=rows.find(r=>r.id===clubKey(s,p.club));if(!row)continue;
   const total=Math.max(1,(rows.length-1)*2),pr=progress(s,p);
   const remind=(key,title,body,staff)=>{if(p.reminders.includes(key))return;p.reminders.push(key);message(title,body);message('Gabi : votre promesse',staff,'staff');};
   if(row.played>=total/2)remind('mi-saison','La presse fait les comptes','Mi-saison : la presse rappelle votre promesse « '+p.label+' ». '+pr.label+'.',pr.onTrack?'« On est dans les temps pour « '+p.label+' ». Gardons le cap sans en rajouter devant les micros. »':'« On est en retard sur « '+p.label+' ». Il faut un plan, ou préparer le conseil à un échec. »');
   if(total-row.played<=3)remind('sprint','Sprint final : votre promesse en question','Les derniers matchs du championnat approchent : « '+p.label+' ». '+pr.label+'.',pr.onTrack?'« Encore un effort : la promesse est à portée. »':'« Ça va être très dur de tenir « '+p.label+' ». Assumons-le plutôt que de chercher des excuses. »');
  }
 }
 // Réputation du manager : la crédibilité publique déplace son profil de ±8 au plus.
 const reputationShift=s=>s?.pressPromises?clamp(Math.round((s.pressPromises.credibility-50)/5),-8,8):0;
 function project(){
  if(typeof S==='undefined'||!S)return null;
  const st=state(S),list=st.promises.filter(p=>p.club===S.club||p.status==='pending');
  const short=p=>p.kind==='rank'?(p.target===1?'Premier':'Top '+p.target):p.kind==='europe'?'Coupe des champions':p.kind==='maintien'?'Maintien':p.kind==='home_wins'?p.target+' succès à domicile':p.target+' jeunes lancés';
  const view=p=>({...copy(p),short:short(p),realismLabel:REALISM_LABELS[p.realism],progress:progress(S,p),seasonLabel:seasonLabel(p.season)});
  return {available:world(S),credibility:st.credibility,credibilityLabel:st.credibility>=70?'Parole respectée':st.credibility>=45?'Parole crédible':st.credibility>=25?'Parole fragile':'Parole discréditée',reputationShift:reputationShift(S),active:list.filter(p=>p.status==='pending').map(view),settled:list.filter(p=>p.status!=='pending').slice(-8).reverse().map(view),refusedThisSeason:seasonEntries(S).refused};
 }
 function validate(s){
  if(!s||s.pressPromises===undefined)return true;
  const st=s.pressPromises,maxW=maxWeek(s);
  check(keys(st,['version','credibility','promises','refusals'])&&Object.keys(st).length===4&&st.version===1&&int(st.credibility,0,100)&&Array.isArray(st.promises)&&st.promises.length<=LIMIT&&Array.isArray(st.refusals)&&st.refusals.length<=REFUSALS,'schéma invalide');
  const date=(season,week)=>int(season,1,s.season)&&int(week,0,maxW),club=c=>int(c,0,s.clubs.length-1),gauge=(e,list)=>keys(e,list)&&Object.keys(e).length===list.length&&Object.values(e).every(v=>num(v,-30,30));
  const ids=new Set(),perSeason=new Map();
  for(const p of st.promises){
   check(keys(p,['id','season','week','club','kind','target','label','realism','leagueId','expected','size','board','status','announce','verdict','result','reminders','youthIds'])&&Object.keys(p).length===18,'promesse au schéma inconnu');
   check(date(p.season,p.week)&&club(p.club)&&KINDS.includes(p.kind)&&REALISM.includes(p.realism)&&STATUS.includes(p.status),'promesse invalide');
   check(p.id==='promesse:'+p.season+':'+p.club+':'+p.kind&&!ids.has(p.id),'identifiant de promesse invalide ou répété');ids.add(p.id);
   const k=p.season+':'+p.club;perSeason.set(k,(perSeason.get(k)||0)+1);check(perSeason.get(k)<=PER_SEASON,'trop de promesses dans une saison');
   check(['europe','maintien'].includes(p.kind)?p.target===null:int(p.target,1,p.kind==='youth'?10:40),'objectif chiffré invalide');
   check(typeof p.label==='string'&&p.label.length>0&&p.label.length<=120&&typeof p.leagueId==='string'&&/^[a-z0-9-]{2,30}$/.test(p.leagueId)&&int(p.size,4,40)&&int(p.expected,1,p.size)&&(p.board===null||num(p.board,0,1e9)),'contexte de promesse invalide');
   check(gauge(p.announce,GAUGES),'effets d’annonce invalides');
   check(p.status==='pending'?p.verdict===null&&p.result===null:keys(p.result,['value','season','week'])&&Object.keys(p.result).length===3&&(p.result.value===null||int(p.result.value,0,1000))&&date(p.result.season,p.result.week)&&p.result.season>=p.season,'verdict de promesse invalide');
   if(p.status==='kept'||p.status==='broken')check(gauge(p.verdict,[...GAUGES,'credibility']),'effets du verdict invalides');else check(p.verdict===null,'effets du verdict invalides');
   check(Array.isArray(p.reminders)&&p.reminders.length<=2&&new Set(p.reminders).size===p.reminders.length&&p.reminders.every(r=>['mi-saison','sprint'].includes(r)),'rappels invalides');
   check(Array.isArray(p.youthIds)&&p.youthIds.length<=YOUTH_IDS&&new Set(p.youthIds).size===p.youthIds.length&&p.youthIds.every(id=>typeof id==='string'&&id.length<=80||int(id,0,1e12))&&(p.kind==='youth'||p.youthIds.length===0),'jeunes lancés invalides');
  }
  const seen=new Set();
  for(const r of st.refusals){check(keys(r,['season','week','club'])&&Object.keys(r).length===3&&date(r.season,r.week)&&club(r.club),'refus invalide');const k=r.season+':'+r.club;check(!seen.has(k),'refus répété dans une saison');seen.add(k);}
  return true;
 }
 let installed=false;
 function installHooks(){
  if(installed)return true;installed=true;
  if(typeof finishRound==='function'){const previous=finishRound;finishRound=function(){const before=typeof S!=='undefined'&&S?S.phase:null,result=previous.apply(this,arguments);if(typeof S!=='undefined'&&S?.pressPromises&&world(S)){observeWeek(S);if(S.phase==='ended'&&before!=='ended')settleSeason(S);}return result;};}
  if(typeof advanceSeason==='function'){const previous=advanceSeason;advanceSeason=function(){const old=typeof S!=='undefined'&&S?S.season:null;if(old!==null&&S.pressPromises&&S.phase==='ended')settleSeason(S);const result=previous.apply(this,arguments);if(typeof S!=='undefined'&&S?.pressPromises&&S.season!==old)settleDraw(S);return result;};}
  if(typeof managerMobilityProfile==='function'){const previous=managerMobilityProfile;managerMobilityProfile=function(){const base=previous.apply(this,arguments);return Number.isFinite(base)?clamp(base+reputationShift(typeof S==='undefined'?null:S),0,100):base;};}
  return true;
 }
 return {project,validate,execute(){throw Error('Commande de promesse inconnue.');},installHooks,offer,assertChoice,announce,settleSeason,settleDraw,observeWeek,progress,reputationShift};
}
module.exports={files,commands,factory};
