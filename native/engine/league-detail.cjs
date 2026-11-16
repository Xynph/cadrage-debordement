'use strict';
// Championnats suivis « comme Football Manager » (demandes de Léo des 13 et 16/11/2026).
// Chaque championnat du Monde est soit « suivi en détail » (moteur de match complet), soit
// « suivi de loin » : score, essais, buts, blessures, fatigue et progression simplifiée,
// sans moteur de match ni feuille de match conservée. Toujours en détail : le championnat du
// club du manager, les coupes d'Europe où il est engagé, les phases finales et les rencontres
// des clubs d'un joueur suivi au recrutement. Sans état `leagueDetail` (anciennes carrières,
// tests), tout est détaillé et le hasard reste le flux unique du moteur (identique à main).
// Changer la liste en cours de partie (Paramètres, comme le niveau de détail de FM) prend effet
// à la semaine suivante : le changement prévu (`pending`) est appliqué juste avant la première
// rencontre de l'IA jouée après la commande, donc pour toute une journée à la fois. Les
// statistiques et notes d'un championnat passé en consultation s'arrêtent à cette semaine.
//
// Hasard (version 2) : dès qu'un championnat est suivi de loin, chaque rencontre de l'IA
// (détaillée ou non) tire ses hasards dans un flux propre, dérivé de la graine de la carrière
// (`salt`, lue sans tirage à la création), de la saison et de l'identifiant de la rencontre.
// Le flux principal n'avance donc plus avec les matchs de l'IA : changer le réglage d'un
// championnat ne décale plus les tirages des rencontres des championnats suivis en détail.
// Quand tout est suivi en détail, rien ne change par rapport au flux unique.
const files=Object.freeze([]),commands=Object.freeze(['league_detail_set']);

function factory(){
 const POLICY='league-detail-v2',POLICY_V1='league-detail-v1',EUROPE=['champions','challenge'],QUICK_PHASES=['league','pool'];
 const SALT_V1=0x9e3779b9;
 const WEATHER=[['Sec',.7],['Vent',.15],['Pluie',.15]];
 const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&keys.every(k=>Object.hasOwn(x,k));
 const check=(yes,message)=>{if(!yes)throw Error('Championnats actifs : '+message+'.');};
 const state=()=>typeof S==='undefined'?null:S;
 const world=s=>!!s&&typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s)&&object(s.worldMode?.leagues);
 const leagueIds=s=>Object.keys(s.worldMode.leagues);
 const leagueOf=(s,clubId)=>leagueIds(s).find(id=>s.worldMode.leagues[id].members.includes(clubId))??null;
 const own=s=>leagueOf(s,s.club);
 const active=s=>s?.leagueDetail?.version===1||s?.leagueDetail?.version===2;
 const clamp=(x,a,b)=>Math.max(a,Math.min(b,x));
 // Brassage 32 bits (FNV-1a puis finaliseur de MurmurHash3) : graine d'un flux de rencontre.
 function mix(text){
  let h=0x811c9dc5;for(let i=0;i<text.length;i++){h^=text.charCodeAt(i);h=Math.imul(h,0x01000193)>>>0;}
  h^=h>>>16;h=Math.imul(h,0x85ebca6b)>>>0;h^=h>>>13;h=Math.imul(h,0xc2b2ae35)>>>0;h^=h>>>16;return h>>>0;
 }
 // Graine de la carrière lue sans tirage (worker natif) ; ailleurs, empreinte du monde créé.
 function freshSalt(s){
  if(typeof nativeRandomPeek==='function'){const v=Number(nativeRandomPeek());if(Number.isInteger(v)&&v>=0)return mix('cd-ligues|'+v);}
  return mix('cd-ligues|'+s.club+'|'+JSON.stringify(s.worldMode.leagues));
 }
 const saltOf=s=>s.leagueDetail.version===2?s.leagueDetail.salt:SALT_V1;
 function stateFor(s,detailed){return {version:2,policy:POLICY,detailed,pending:null,salt:freshSalt(s)};}
 // Liste demandée -> liste normalisée (ordre du registre, championnat du club inclus).
 function normalize(s,ids){
  check(Array.isArray(ids)&&ids.length<=leagueIds(s).length&&ids.every(id=>typeof id==='string'),'liste de championnats invalide');
  check(new Set(ids).size===ids.length,'championnat en double');
  for(const id of ids)check(leagueIds(s).includes(id),'championnat inconnu : '+id);
  const wanted=new Set(ids),mine=own(s);if(mine)wanted.add(mine);
  return leagueIds(s).filter(id=>wanted.has(id));
 }
 function create(s,ids){
  if(ids===undefined||ids===null)return false;
  check(world(s),'réservé à la carrière Monde');
  s.leagueDetail=stateFor(s,normalize(s,ids));
  return true;
 }
 function detailedLeague(s,id){
  if(!active(s))return true;
  return s.leagueDetail.detailed.includes(id)||id===own(s);
 }
 // Au moins un championnat suivi de loin : les rencontres de l'IA ont leur propre flux.
 const separated=s=>active(s)&&world(s)&&leagueIds(s).some(id=>!detailedLeague(s,id));
 // Coupe d'Europe où le club du manager est engagé cette saison : suivie en entier.
 const ownCompetition=(s,id)=>s.worldMode.fixtures.some(x=>x.competitionId===id&&(x.homeId===s.club||x.awayId===s.club));
 // Club d'un joueur suivi au recrutement : ses rencontres gardent notes et feuilles.
 function watchedClub(s,id){
  const watch=s.manager?.watch;if(!Array.isArray(watch)||!watch.length)return false;
  const ids=new Set(watch);return (s.clubs[id]?.players||[]).some(p=>ids.has(p.id));
 }
 // Seules les rencontres de saison régulière et de poules sont suivies de loin :
 // les phases finales, barrages et accessions gardent le moteur complet (preuves de
 // prolongation, tirs au but et règles de départage propres à chaque compétition).
 function quickFixture(s,f){
  if(!active(s)||!world(s)||!f||!QUICK_PHASES.includes(f.phase))return false;
  if(f.homeId===s.club||f.awayId===s.club)return false;
  let light;
  if(EUROPE.includes(f.competitionId))light=!ownCompetition(s,f.competitionId)&&[f.homeId,f.awayId].every(id=>!detailedLeague(s,leagueOf(s,id)));
  else light=Object.hasOwn(s.worldMode.leagues,f.competitionId)&&!detailedLeague(s,f.competitionId);
  return light&&!watchedClub(s,f.homeId)&&!watchedClub(s,f.awayId);
 }
 // Exécute `fn` avec un flux de hasard propre à la rencontre (Math.random remplacé puis rendu).
 function isolated(s,f,fn){
  let x=mix(saltOf(s)+'|'+s.season+'|'+f.id+'|'+f.competitionId);
  const prior=Math.random;
  Math.random=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296;};
  try{return fn();}finally{Math.random=prior;}
 }
 // Point d'entrée du monde pour chaque rencontre de l'IA. `full` joue le moteur complet.
 function play(s,f,full){
  if(!active(s)||!world(s))return full();
  // Changement prévu dans les Paramètres : appliqué au début de la journée suivante.
  if(s.leagueDetail.pending)applyPending(s);
  if(quickFixture(s,f))return isolated(s,f,()=>simulate(s,f));
  return separated(s)?isolated(s,f,full):full();
 }
 const roll=()=>Math.random();
 function poisson(mean){const limit=Math.exp(-mean);let k=0,p=1;do{k++;p*=roll();}while(p>limit&&k<40);return k-1;}
 function binomial(n,p){let k=0;for(let i=0;i<n;i++)if(roll()<p)k++;return k;}
 function released(s,f){
  if(typeof CDWorldCareer==='undefined'||typeof CDWorldCareer.clubReleaseOn!=='function')return ()=>false;
  return id=>{try{return !!CDWorldCareer.clubReleaseOn(s,id,f.date);}catch{return false;}};
 }
 // Effectif allégé : les 23 meilleurs disponibles (note et forme), sans feuille de match
 // détaillée ni règles de première ligne ; les postes ne sont pas contrôlés.
 function squad(s,club,away){
  const pool=club.players.filter(p=>!p.injury&&!(p.suspension>0)&&!away(p.id));
  const form=MATCH_LEVEL_CURVE.forme,score=p=>(Number(p.rating)||50)*(form[0]+clamp(Number(p.condition)||80,0,100)*form[1]);
  const ranked=pool.slice().sort((a,b)=>score(b)-score(a)||String(a.id).localeCompare(String(b.id))).slice(0,23);
  const starters=ranked.slice(0,15),bench=ranked.slice(15);
  const power=(starters.length?starters.reduce((n,p)=>n+score(p),0)/starters.length:40)-(15-starters.length)*4;
  return {starters,bench,power};
 }
 function sideStats(tries,edge){
  const stats=typeof makeStats==='function'?makeStats():{conversions:0,conversionAttempts:0,goalAttempts:0,goals:0};
  const conversions=binomial(tries,.7+edge*.02),goalAttempts=poisson(clamp(3.1-edge*.25,1.5,4.5)),goals=binomial(goalAttempts,.74);
  Object.assign(stats,{conversions,conversionAttempts:tries,goalAttempts,goals});
  if('possession' in stats){
   stats.possession=Math.round(clamp(50+edge*4+(roll()-.5)*12,30,70));stats.territory=Math.round(clamp(50+edge*5+(roll()-.5)*14,28,72));
   stats.scrums=8+Math.floor(roll()*8);stats.scrumsWon=Math.max(0,stats.scrums-Math.floor(roll()*3));
   stats.lineouts=9+Math.floor(roll()*9);stats.lineoutsWon=Math.max(0,stats.lineouts-Math.floor(roll()*4));
   stats.penalties=7+Math.floor(roll()*7);stats.yellows=roll()<.35?1:0;
  }
  return stats;
 }
 // Usure, blessures et progression simplifiées, inspirées des formules du moteur complet
 // (applyMatchInjuries, recordDevelopmentMatch, recordPhysicalMatchLoad, trackManagerLoad).
 function playerEffects(s,club,team){
  const minutes=new Map();
  const replaced=new Set(team.starters.slice().sort(()=>roll()-.5).slice(0,Math.min(team.bench.length,6)).map(p=>p.id));
  for(const p of team.starters)minutes.set(p.id,replaced.has(p.id)?55+Math.floor(roll()*16):80);
  for(const [i,p] of team.bench.entries())minutes.set(p.id,i<replaced.size?10+Math.floor(roll()*16):0);
  for(const p of club.players){
   const m=minutes.get(p.id)||0,starter=team.starters.includes(p);
   p.managerLoad={minutes:m,streak:starter?(p.managerLoad?.streak||0)+1:0};
   if(!m)continue;
   if(typeof ensureDevelopment==='function'){
    ensureDevelopment(p);p.dev.minutes+=m;p.dev.careerMinutes+=m;p.dev.appearances++;
    if(typeof growPlayer==='function'&&typeof ageGrowth==='function'){
     const fit=typeof growthFitnessFactor==='function'?growthFitnessFactor(p):1;
     growPlayer(p,m/80*.12*ageGrowth(p)*Math.max(.5,(Number(p.condition)||80)/100)*fit,false);
    }
   }
   if(s.physicalLoadVersion===1&&typeof ensurePhysicalLoad==='function'){const st=ensurePhysicalLoad(p);st.fatigue=clamp(st.fatigue+Math.round(m*18/80),0,100);}
   const stamina=typeof skill==='function'?skill(p,'stamina'):70;
   p.condition=Math.round(clamp((Number(p.condition)||80)-.3*m*(1+(70-stamina)*.009),12,100));
   if(Math.random()<(p.condition<55?.07:.025)*m/80)p.injury=1+Math.floor(roll()*4);
  }
 }
 function simulate(s,f){
  const pair=[f.homeId,f.awayId],away=released(s,f),teams=pair.map(id=>squad(s,s.clubs[id],away));
  // Courbe de niveau commune au moteur complet (MATCH_LEVEL_CURVE de dist/rugby.js, tests/match-rating-curve.cjs) :
  // écart de puissance + bonus du terrain (sauf terrain neutre), ramené à l'échelle des essais.
  const curve=MATCH_LEVEL_CURVE.rapide,home=f.neutral?0:curve.terrain;
  // Match piège (MATCH_LEVEL_CURVE.piege) : même tirage que le moteur complet, au-delà du seuil d'écart.
  const gap=teams[0].power-teams[1].power,trap=typeof matchTrapOffset==='function'?matchTrapOffset(gap,roll):0;
  const edge=clamp((gap+trap+home)/curve.diviseur,-curve.borne,curve.borne);
  const tries=[poisson(clamp(2.75*Math.exp(curve.essais*edge),.5,8)),poisson(clamp(2.75*Math.exp(-curve.essais*edge),.5,8))];
  const stats=[sideStats(tries[0],edge),sideStats(tries[1],-edge)];
  const points=i=>tries[i]*5+stats[i].conversions*2+stats[i].goals*3;
  let score=[points(0),points(1)];
  // Super Rugby Pacific : pas de nul en saison régulière (le moteur complet joue le point en or).
  if(score[0]===score[1]&&f.competitionId==='srp'){const side=edge>=0?0:1;stats[side].goalAttempts++;stats[side].goals++;score=[points(0),points(1)];}
  let w=roll(),weather='Sec';for(const [name,p] of WEATHER){if(w<p){weather=name;break;}w-=p;}
  pair.forEach((id,i)=>playerEffects(s,s.clubs[id],teams[i]));
  return {pair,score,tries,stats,weather,duration:80};
 }
 function applyPending(s){
  if(!active(s)||!world(s))return false;
  const st=s.leagueDetail;
  const next=normalize(s,st.pending||st.detailed);
  // Une carrière de la version 1 reçoit son flux de hasard propre au changement de saison.
  if(st.version===1)s.leagueDetail=stateFor(s,next);
  else{st.detailed=next;st.pending=null;}
  return true;
 }
 function validate(s){
  if(!s||s.leagueDetail===undefined)return true;
  const st=s.leagueDetail;
  check(shape(st,['version','policy','detailed','pending'])&&st.version===1&&st.policy===POLICY_V1
   ||shape(st,['version','policy','detailed','pending','salt'])&&st.version===2&&st.policy===POLICY&&Number.isInteger(st.salt)&&st.salt>=0&&st.salt<=0xffffffff,'état invalide');
  check(world(s),'état hors carrière Monde');
  const ids=leagueIds(s),valid=list=>Array.isArray(list)&&new Set(list).size===list.length&&list.every(id=>ids.includes(id))&&list.every((id,i)=>i===0||ids.indexOf(list[i-1])<ids.indexOf(id));
  check(valid(st.detailed),'liste des championnats détaillés invalide');
  check(st.pending===null||valid(st.pending)&&st.pending.length>0,'changement prévu invalide');
  return true;
 }
 function execute(command,payload){
  const s=state();check(command==='league_detail_set','commande inconnue');
  check(world(s),'réservé à la carrière Monde');
  check(shape(payload,['detailed']),'paramètres invalides');
  if(!active(s))s.leagueDetail=stateFor(s,leagueIds(s).slice());
  const next=normalize(s,payload.detailed);
  s.leagueDetail.pending=JSON.stringify(next)===JSON.stringify(s.leagueDetail.detailed)?null:next;
  return {leagueDetail:project()};
 }
 function project(){
  const s=state();if(!world(s))return {available:false};
  const names=Object.fromEntries((CDWorldCareer.edition(s)?.registry?.leagues||[]).map(l=>[l.id,l.name]));
  const mine=own(s),st=active(s)?s.leagueDetail:null;
  return {available:true,configured:!!st,own:mine,pending:st?.pending?st.pending.slice():null,
   europe:EUROPE.filter(id=>ownCompetition(s,id)),
   leagues:leagueIds(s).map(id=>({id,name:names[id]||id,clubs:s.worldMode.leagues[id].members.length,
    detailed:detailedLeague(s,id),own:id===mine,next:st?.pending?st.pending.includes(id)||id===mine:detailedLeague(s,id)}))};
 }
 function installHooks(){
  if(typeof advanceSeason==='function'&&!advanceSeason.__leagueDetail){
   const original=advanceSeason,wrapped=function(){const prior=S?.season,result=original.apply(this,arguments);if(S&&S.season!==prior)applyPending(S);return result;};
   Object.assign(wrapped,original);wrapped.__leagueDetail=true;advanceSeason=wrapped;
  }
  return true;
 }
 return Object.freeze({create,quickFixture,simulate,play,separated,detailedLeague,applyPending,validate,execute,project,installHooks});
}

// --- Côté Node (hors VM) : banc d'essai et estimation de fluidité --------------------
// Coûts remesurés le 16/11/2026 après #753, sur la machine de mesure (2 cœurs partagés,
// 7,8 Go, banc d'essai ≈ 25 ms + 53 ms), carrière Monde de 116 clubs, club de l'Élite :
// semaine réelle par le worker (match délégué, réunions, finish_round, projection,
// sauvegarde) et saisons complètes du harnais (voir la PR « championnats suivis »).
// - semaine avec le seul championnat du club suivi en détail : médiane 9,2 s ;
// - tout suivi en détail : médiane 10,7 s ;
// - rencontre de l'IA suivie en détail : ≈ 65 ms ; suivie de loin : moins de 1 ms, compté 1 ms.
// Les valeurs ci-dessous sont ramenées hors contention (÷ 1,12 pour 2 cœurs, ÷ 1,15 pour
// moins de 8 Go) : estimate() retrouve les mesures sur la machine de mesure.
const REFERENCE=Object.freeze({
 benchmarkMs:Object.freeze({serial:25,compute:53}),
 baseWeekMs:6900,detailedMatchMs:50,quickMatchMs:1,seasonExtraMs:0,
});
// Matchs de saison régulière et de poules européennes par saison et par championnat
// (formats de la saison 2026-27 ; poules européennes réparties entre Top 14, Premiership et URC).
const SEASON_MATCHES=Object.freeze({elite:210,accession:240,nationale:182,prem:118,champ:182,urc:172,srp:80,'jlo-d1':108,'jlo-d2':56});
const WEEKS=46;
// Vitesse de jeu estimée « comme FM » : 5 étoiles (5 = rapide), seuils en secondes par semaine
// dans vitesse-jeu.json. L'interface choisit la couleur du thème selon l'état, le moteur ne
// fournit que l'état (succès, alerte, danger).
const VITESSE=require('./vitesse-jeu.json');
const LEVELS=Object.freeze(VITESSE.crans.map(c=>Object.freeze({id:c.id,label:c.libelle,stars:c.etoiles,belowWeekMs:c.sousSemaineMs??Infinity,state:c.etat})));
const AUTO_TARGET=VITESSE.cibleChoixAuto;
// Pays de chaque championnat : le choix automatique ajoute d'abord ceux du pays du club.
const COUNTRY=Object.freeze({elite:'FR',accession:'FR',nationale:'FR',prem:'GB',champ:'GB',urc:'URC',srp:'SRP','jlo-d1':'JP','jlo-d2':'JP'});
// Charges représentatives : sérialisation d'un gros état (le poste dominant d'une semaine :
// copie d'annulation, validation, sauvegarde) et calcul flottant proche du moteur de match.
function benchmark(){
 const players=Array.from({length:2500},(_,i)=>({id:'p'+i,name:'Joueur '+i,rating:60+i%30,condition:80+i%20,
  skills:Object.fromEntries(Array.from({length:14},(_,k)=>['s'+k,50+(i*k)%45])),dev:{minutes:i%900,history:[[1,60,62],[2,62,64]]},contractEnd:3,wage:1000+i}));
 let t=performance.now();
 for(let i=0;i<3;i++){const text=JSON.stringify({players});JSON.parse(text);}
 const serial=performance.now()-t;
 t=performance.now();let seed=12345,acc=0;const rnd=()=>(seed=(seed*1103515245+12345)>>>0)/4294967296;
 for(let i=0;i<2000000;i++){const x=rnd(),y=rnd();acc+=Math.sqrt(x*x+y*y)*Math.exp(-x)+(x<.5?y:-y);}
 const compute=performance.now()-t;
 return {version:1,serialMs:Math.round(serial*10)/10,computeMs:Math.round(compute*10)/10,checksum:Math.round(acc)%1000};
}
function factorOf(measured,reference){return reference>0&&measured>0?measured/reference:1;}
// Estimation par semaine et par saison. `machine` : {serialMs,computeMs,cores,memoryGb}.
function estimate({detailed,leagues=Object.keys(SEASON_MATCHES),machine={}}){
 if(!Array.isArray(detailed)||!detailed.every(id=>typeof id==='string'))throw Error('Championnats actifs : liste invalide.');
 const R=REFERENCE,serial=factorOf(machine.serialMs,R.benchmarkMs.serial),compute=factorOf(machine.computeMs,R.benchmarkMs.compute);
 // Le moteur tourne sur un seul fil ; deux cœurs ou moins sont partagés avec l'affichage Godot,
 // et moins de 8 Go de mémoire font travailler le ramasse-miettes sur un état de plus de 20 Mo.
 const contention=(Number.isFinite(machine.cores)&&machine.cores<=2?1.12:1)*(Number.isFinite(machine.memoryGb)&&machine.memoryGb>0&&machine.memoryGb<8?1.15:1);
 const set=new Set(detailed);let detailedMatches=0,quickMatches=0;
 for(const id of leagues){const n=SEASON_MATCHES[id]||0;if(set.has(id))detailedMatches+=n;else quickMatches+=n;}
 const seasonMs=(WEEKS*R.baseWeekMs*serial+detailedMatches*R.detailedMatchMs*compute+quickMatches*R.quickMatchMs*compute+R.seasonExtraMs*serial)*contention;
 const weekMs=seasonMs/WEEKS,level=LEVELS.find(l=>weekMs<l.belowWeekMs)||LEVELS[LEVELS.length-1];
 return {weekMs:Math.round(weekMs),seasonMs:Math.round(seasonMs),detailedMatches,quickMatches,level:level.id,label:level.label,stars:level.stars,state:level.state};
}
// Choix automatique selon la machine (bouton « Choix automatique selon ton PC », défaut des
// nouvelles carrières) : le championnat du club, puis ceux de son pays, puis les autres dans
// l'ordre du registre, chacun ajouté seulement si la vitesse estimée garde `target` étoiles.
// Déterministe : même machine mesurée, même championnat du club -> même liste.
function autoChoice({own,machine={},target=AUTO_TARGET,leagues=Object.keys(SEASON_MATCHES)}){
 let chosen=leagues.includes(own)?[own]:[];
 const country=COUNTRY[own],others=leagues.filter(id=>id!==own);
 const order=[...others.filter(id=>country&&COUNTRY[id]===country),...others.filter(id=>!country||COUNTRY[id]!==country)];
 for(const id of order){const trial=[...chosen,id];if(estimate({detailed:trial,leagues,machine}).stars>=target)chosen=trial;}
 return leagues.filter(id=>chosen.includes(id));
}
// Tableau transmis à l'interface : coût fixe et coût de chaque championnat selon son mode,
// déjà adaptés à la machine, pour une jauge recalculée sans aller-retour au moteur, et le
// choix automatique pour chaque championnat de club possible.
function costTable(machine={}){
 const leagues=Object.keys(SEASON_MATCHES),none=estimate({detailed:[],machine}),table={};
 for(const id of leagues){
  const one=estimate({detailed:[id],machine});
  table[id]={quickMs:Math.round(SEASON_MATCHES[id]*REFERENCE.quickMatchMs*factorOf(machine.computeMs,REFERENCE.benchmarkMs.compute)),extraDetailedMs:one.seasonMs-none.seasonMs,matches:SEASON_MATCHES[id]};
 }
 return {weeks:WEEKS,baseSeasonMs:none.seasonMs,leagues:table,autoTarget:AUTO_TARGET,
  auto:Object.fromEntries(['',...leagues].map(own=>[own,autoChoice({own,machine})])),
  levels:LEVELS.map(l=>({id:l.id,label:l.label,stars:l.stars,belowWeekMs:Number.isFinite(l.belowWeekMs)?l.belowWeekMs:null,state:l.state}))};
}
module.exports={files,commands,factory,benchmark,estimate,autoChoice,costTable,REFERENCE,SEASON_MATCHES,LEVELS,AUTO_TARGET,COUNTRY};
