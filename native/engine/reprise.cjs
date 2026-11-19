'use strict';
// Reprise de l'entraînement (décisions de Léo, 13/11/2026, 14h42-14h45).
// 1. Départ de la partie choisi à la création : « Reprise des premiers clubs » (lundi 13 juillet
//    2026, défaut), « Reprise de ton club » (date du club) ou « Veille de la 1re journée »
//    (préparation gérée par le staff, simulée).
// 2. Date de reprise du club : décision du manager parmi les lundis proposés, avec des effets
//    modérés branchés sur les systèmes existants : fraîcheur (charge physique), condition de match,
//    automatismes collectifs (puissance de la préparation collective, cohésion du vestiaire),
//    moral, blessures, matchs amicaux et temps de jeu des jeunes du centre.
//    Les internationaux de la tournée d'été rejoignent le groupe plus tard (fin de tournée et
//    congés), quel que soit le lundi choisi ; le groupe est complété par des jeunes du centre.
//    Les clubs de l'ordinateur ont leur date (décalée par un parcours jusqu'en finale ou leur
//    habitude de club) et subissent les mêmes effets.
// 3. Décisions de la préparation (décision de Léo, 16/11/2026) : programme des matchs amicaux (dû le
//    jour de la reprise) et orientation du stage (dû une semaine après). « Continuer » s'arrête le
//    jour dû ; sans réponse, une avance qui dépasse ce jour les confie au staff (choix prudent :
//    « équilibré », sans effet). Club du manager seulement. Barème : docs/pre-saison-decisions-20261116.md.
// Tout est déterministe (aucun Math.random). Provenance et barème : docs/reprise-choisie-20261113.md.
const files=Object.freeze([]),commands=Object.freeze(['reprise_choose','reprise_youth','reprise_advance','reprise_decide']);
const STARTS=Object.freeze(['premiers-clubs','club','veille']);
function factory(){
 const g=globalThis,DAY=86400000,WEEK=7,HISTORY=20,YOUTH_MAX=8,WINDOW=4,LATE_FROM=30;
 const STARTS=['premiers-clubs','club','veille'];
 // Top 14 2026-27 : dates de reprise publiées par la LNR (« Les infos sur la pré-saison des clubs
 // du Top 14 »), rattachées aux identifiants de club du registre Monde (noms réels : pack privé).
 const ELITE_2026={0:'2026-07-27',1:'2026-07-22',2:'2026-07-23',3:'2026-07-15',4:'2026-07-20',5:'2026-07-13',6:'2026-07-16',
  7:'2026-07-13',8:'2026-08-03',9:'2026-07-13',10:'2026-07-28',11:'2026-07-27',12:'2026-07-15',13:'2026-07-15'};
 // Autres championnats : semaines de préparation habituelles avant la 1re journée (estimées,
 // cohérentes avec leur calendrier) ; ref = préparation de référence, effets nuls.
 const LEAGUES={elite:{ref:6,min:5,max:8},accession:{ref:7,min:6,max:8},nationale:{ref:5,min:5,max:6},
  prem:{ref:9,min:9,max:10},champ:{ref:8,min:8,max:9},urc:{ref:9,min:8,max:10},
  'jlo-d1':{ref:12,min:11,max:13},'jlo-d2':{ref:12,min:11,max:13},srp:{ref:13,min:12,max:14}};
 // Tournée d'été 2026 (Nations Championship, 4-18 juillet) : dernier test le 18/07, puis trois
 // semaines de congés ; retour le lundi suivant. Autres nations : tests jusqu'au 11/07.
 const NC=new Set(['ENG','FRA','IRE','ITA','SCO','WAL','ARG','AUS','FIJ','JPN','NZL','RSA']);
 const TOUR_END={nc:'07-18',other:'07-11'},REST_DAYS=21,SQUAD=32;
 // Décisions de la préparation (club du manager). Écarts ajoutés au barème de la date de reprise :
 // gap = retard de condition aux 4 premiers matchs (points), risk = risque de blessure par match (%),
 // fatigue = charge physique de départ, auto = automatismes (%), morale = moral de départ,
 // cohesion = cohésion du vestiaire, youth = facteur des minutes des jeunes en amical,
 // receipts = part de la recette d'un amical à domicile, par match (négatif : frais de déplacement).
 const ZERO={gap:0,risk:0,fatigue:0,auto:0,morale:0,cohesion:0,youth:1,receipts:0};
 const DECISIONS={
  amicaux:{field:'program',title:'Programme des matchs amicaux',options:{
   rodage:{...ZERO,label:'Rodage à domicile',detail:'Clubs de division inférieure, à domicile',gap:1,risk:-.2,auto:-1,morale:2,youth:1.35,receipts:.5},
   equilibre:{...ZERO,label:'Programme équilibré',detail:'Clubs de même niveau, en aller-retour : recettes et déplacements s’équilibrent'},
   releve:{...ZERO,label:'Opposition relevée',detail:'Clubs de l’élite et tournoi à l’étranger, à l’extérieur',gap:-2,risk:.3,auto:3,morale:-1,youth:.6,receipts:-.25}}},
  stage:{field:'camp',title:'Orientation du stage de préparation',options:{
   physique:{...ZERO,label:'Stage foncier',detail:'Travail physique en altitude : volume et intensité',gap:-4,risk:-.3,fatigue:6,auto:-2,morale:-1},
   cohesion:{...ZERO,label:'Stage de cohésion',detail:'Vie de groupe, défis collectifs et récupération',gap:1,auto:2,morale:4,cohesion:6},
   technique:{...ZERO,label:'Stage technico-tactique',detail:'Plan de jeu, lancements, défense : beaucoup d’opposition',gap:2,risk:.2,auto:5,cohesion:2},
   equilibre:{...ZERO,label:'Stage équilibré',detail:'Programme habituel du staff, un peu de tout'}}},
 };
 const DECISION_KEYS=Object.keys(DECISIONS),PRUDENT='equilibre';
 // Recette d'un amical à domicile selon le championnat (affluence d'avant-saison, ordre de grandeur).
 const RECEIPT={elite:60000,accession:25000,nationale:8000,prem:60000,champ:20000,urc:45000,'jlo-d1':35000,'jlo-d2':15000,srp:40000};
 const object=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const int=(x,a,b)=>Number.isSafeInteger(x)&&x>=a&&x<=b;
 const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
 const round1=n=>Math.round(n*10)/10;
 const hash=text=>{let h=2166136261;for(const c of String(text))h=Math.imul(h^c.charCodeAt(0),16777619);h^=h>>>15;return h>>>0;};
 const unit=text=>hash(text)/4294967296;
 const dayOf=iso=>Math.floor(Date.parse(iso+'T00:00:00Z')/DAY);
 const iso=day=>new Date(day*DAY).toISOString().slice(0,10);
 const monday=day=>day-((new Date(day*DAY).getUTCDay()+6)%7);
 const nextMonday=day=>{const m=monday(day);return m===day?day:m+7;};
 const W=()=>typeof CDWorldCareer!=='undefined'?CDWorldCareer:null;
 const active=s=>!!s&&!!W()&&W().active(s)&&W().edition(s)?.mode==='world-champ';
 const year=s=>2025+s.season;
 const engineStart=s=>dayOf(W().calendarToday({...s,round:0,worldMode:{...s.worldMode,day:0}}));
 const leagueOf=(s,id)=>W().leagueId(s,id);
 const profile=(s,id)=>LEAGUES[leagueOf(s,id)]||{ref:7,min:6,max:8};
 const weekOfDay=(s,day)=>Math.floor((day-engineStart(s))/WEEK);

 // ------------------------------------------------------------ calendrier par club
 const fmMemo=new WeakMap();
 function firstMatches(s){
  let m=fmMemo.get(s.worldMode.fixtures);
  if(!m){m=new Map();for(const f of s.worldMode.fixtures)for(const id of [f.homeId,f.awayId]){const d=dayOf(f.date);if(!m.has(id)||d<m.get(id))m.set(id,d);}fmMemo.set(s.worldMode.fixtures,m);}
  return m;
 }
 // Lundi de la semaine de la 1re rencontre officielle (championnat ou coupe d'Europe).
 function fmDay(s,id){const d=firstMatches(s).get(id);return d===undefined?null:d;}
 function fmMonday(s,id){const d=fmDay(s,id);return d===null?null:monday(d);}
 function finalist(s,id){
  const y=s.worldMode.yearbook.at(-1);if(!y||y.season!==s.season-1)return false;
  const inLeague=Object.values(y.champions||{}).includes(id)||Object.values(y.finalists||{}).includes(id);
  const europe=Object.values(y.europe||{}).some(e=>object(e)&&(e.champion===id||e.finalist===id));
  return inLeague||europe;
 }
 // Date habituelle du club : réelle pour l'Élite 2026, sinon semaines habituelles de préparation
 // (habitude de club, déterministe), plus une semaine après un parcours jusqu'en finale.
 function clubDefault(s,id){
  const fm=fmMonday(s,id);if(fm===null)return null;
  return habitualDay(id,leagueOf(s,id),fm,s.season,finalist(s,id));
 }
 // Formule de clubDefault, sans carrière : club, championnat, lundi de la 1re rencontre (jour), saison, finaliste.
 function habitualDay(id,league,fm,season,wasFinalist){
  const p=LEAGUES[league]||{ref:7,min:6,max:8};
  const real=season===1&&league==='elite'&&ELITE_2026[id];
  if(real)return {day:dayOf(real),real:true,finalShift:false};
  // Habitude du club, fixée sur l'Élite 2026 quand elle existe (même écart à la 1re journée).
  const habit=ELITE_2026[id]?Math.round((dayOf(ELITE_2026[id])-dayOf('2026-08-31'))/WEEK)*-1:p.min+hash('reprise:'+id)%(p.max-p.min+1);
  const shift=wasFinalist?1:0;
  const weeks=clamp(habit-shift,p.min-1,p.max);
  return {day:fm-weeks*WEEK,real:false,finalShift:!!shift};
 }
 // Aperçu de création (club_preview, aucune carrière) : date habituelle de reprise du club, veille de la 1re
 // rencontre officielle et matchs amicaux de la préparation, mêmes formules que la carrière (saison 1).
 function preview(id,league,firstIso){
  const first=dayOf(firstIso),def=habitualDay(id,league,monday(first),1,false),rep=def.day;
  const n=friendliesFor((first-rep)/WEEK),dates=friendlyDates({fx:{friendlies:n},first,rep});
  return {firstClubs:'2026-07-13',club:iso(rep),real:def.real,eve:iso(first-1),friendlies:{count:n,dates:dates.map(iso)}};
 }
 // Lundis proposés au manager : de ref+3 à ref-3 semaines avant la 1re journée, jamais avant le
 // départ de la partie ni avant aujourd'hui, et la date habituelle du club.
 function options(s,id,today){
  const fm=fmMonday(s,id);if(fm===null)return [];
  const p=profile(s,id),floor=Math.max(today,s.season===1?dayOf('2026-07-13'):today),out=new Set();
  for(let w=p.ref+3;w>=Math.max(2,p.ref-3);w--){const d=fm-w*WEEK;if(d>=floor)out.add(d);}
  const def=clubDefault(s,id);if(def&&def.day>=today)out.add(def.day);
  return [...out].sort((a,b)=>a-b);
 }

 // ------------------------------------------------------------ internationaux de la tournée d'été
 const factsOf=id=>typeof nativeFacts!=='undefined'?nativeFacts.source(id):null;
 let tourMemo=null;
 function tourists(s){
  const key=s.season+':'+s.round+':'+(s.preseason?.today||'')+':'+(s.national?.career?.callups||[]).map(c=>c.nation+c.through+(c.playerIds?.length||0)).join(',');
  if(tourMemo&&tourMemo.s===s&&tourMemo.key===key)return tourMemo.map;
  const map=touristsNow(s);tourMemo={s,key,map};return map;
 }
 function touristsNow(s){
  const byNation=new Map();
  for(const c of s.clubs)for(const p of c.players){
   const f=factsOf(p.id),nation=f?.seniorNation;
   if(!nation||!(f.seniorCaps>0)||p.age>34||p.injury>4)continue;
   if(!byNation.has(nation))byNation.set(nation,[]);
   byNation.get(nation).push(p);
  }
  // Une fenêtre de tests déjà convoquée (carrière internationale, « Absences internationales ») qui se
  // termine après la date de retour des congés repousse le retour au lendemain de la fenêtre : un
  // international ne rejoint pas son club tant que sa sélection joue. Source unique des dates de retour.
  const lo=dayOf(year(s)+'-07-01'),hi=dayOf(year(s)+'-09-15'),campBack=new Map(),campNation=new Map();
  for(const camp of s.national?.career?.callups||[]){
   const through=typeof camp.through==='string'?dayOf(camp.through):NaN;
   if(!(through>=lo&&through<=hi)||!Array.isArray(camp.playerIds))continue;
   for(const id of camp.playerIds)if(!(campBack.get(id)>through+1)){campBack.set(id,through+1);campNation.set(id,camp.nation);}
  }
  const out=new Map();
  for(const [nation,players]of byNation){
   players.sort((a,b)=>b.rating-a.rating||(a.id<b.id?-1:a.id>b.id?1:0));
   const back=nextMonday(dayOf(year(s)+'-'+(NC.has(nation)?TOUR_END.nc:TOUR_END.other))+REST_DAYS);
   for(const p of players.slice(0,SQUAD))out.set(p.id,{nation,back:Math.max(back,campBack.has(p.id)?nextMonday(campBack.get(p.id)):0)});
  }
  // Convoqués hors des 32 retenus par nation : ils reviennent aussi au lendemain de leur fenêtre.
  if(campBack.size){const known=new Set();for(const c of s.clubs)for(const p of c.players)known.add(p.id);for(const [id,day]of campBack)if(!out.has(id)&&known.has(id))out.set(id,{nation:campNation.get(id)||factsOf(id)?.seniorNation||'',back:nextMonday(day)});}
  return out;
 }

 // ------------------------------------------------------------ jeunes du centre
 const academyOf=(s,id)=>id===s.club?s.development?.academy||[]:(s.aiRoster?.academies||[]).find(a=>a.clubId===id)?.players||[];
 // Espoirs (18-21 ans) d'abord, puis -18 surclassés (17 ans), les plus prometteurs en tête.
 function youthCandidates(s,id){
  return academyOf(s,id).filter(p=>!p.injury&&p.age>=17&&p.age<=21)
   .map(p=>({p,score:(p.dev?.potential??p.rating)+(p.age>=18?4:0)+p.rating*.2}))
   .sort((a,b)=>b.score-a.score||(a.p.id<b.p.id?-1:1)).map(x=>x.p);
 }

 // ------------------------------------------------------------ barème (modéré, documenté)
 // e = semaines de préparation - référence du championnat (positif : reprise tôt).
 function effectsFor(e,absentShare){
  const early=Math.max(0,e),late=Math.max(0,-e);
  return {
   fatigue:Math.round(clamp(5*early,0,15)),                    // charge résiduelle : joueurs moins reposés
   conditionGap:Math.round(clamp(3*late,0,12)),                // retard de condition de match (4 semaines)
   injuryRisk:round1(clamp(.4*late,0,1.6)),                    // % de risque de blessure en plus par match (4 semaines)
   automatismes:Math.round(clamp(2*early,0,6)-clamp(4*late,0,12)-Math.round(10*absentShare)), // % puissance collective (4 semaines)
   morale:Math.round(clamp(2*late,0,6)-clamp(early,0,3)),     // moral de départ (75 = neutre)
   lateCondition:Math.round(clamp(2*early,0,6)),               // plafond de condition en fin de saison
   friendlies:0,
  };
 }
 const friendliesFor=weeks=>clamp(Math.floor(weeks/2),1,4);
 // Écarts dus aux décisions de la préparation : club du manager, saison du plan ; une décision non
 // prise compte comme le choix prudent (aucun écart).
 function mods(s,id,st=s.reprise){
  const out={...ZERO};if(!st||id!==s.club||st.season!==s.season)return out;
  for(const k of DECISION_KEYS){const d=DECISIONS[k],v=st[d.field],o=v&&Object.hasOwn(d.options,v.id)?d.options[v.id]:null;if(!o)continue;
   for(const x of ['gap','risk','fatigue','auto','morale','cohesion','receipts'])out[x]=round1(out[x]+o[x]);out.youth*=o.youth;}
  return out;
 }
 function adjust(fx,m){
  return {...fx,fatigue:Math.round(clamp(fx.fatigue+m.fatigue,0,25)),conditionGap:Math.round(clamp(fx.conditionGap+m.gap,0,12)),
   injuryRisk:round1(clamp(fx.injuryRisk+m.risk,0,2)),automatismes:Math.round(fx.automatismes+m.auto),morale:Math.round(fx.morale+m.morale)};
 }
 const gapWith=(gap,m)=>Math.round(clamp(gap+m.gap,0,12));

 // ------------------------------------------------------------ plan de saison
 function decide(s,id,st){
  const own=id===s.club&&st&&st.season===s.season;
  const def=clubDefault(s,id);if(!def)return null;
  return own&&st.choice!==null?fmMonday(s,id)-st.choice*WEEK:def.day;
 }
 function buildClub(s,id,tour,st){
  const fm=fmMonday(s,id),first=fmDay(s,id),rep=decide(s,id,st);if(fm===null||rep===null)return null;
  const p=profile(s,id),weeks=(first-rep)/WEEK,e=clamp((fm-rep)/WEEK-p.ref,-4,3);
  const players=s.clubs[id].players,away=players.filter(x=>tour.get(x.id)&&tour.get(x.id).back>rep);
  const top=[...players].sort((a,b)=>b.rating-a.rating).slice(0,15),absentTop=top.filter(x=>{const t=tour.get(x.id);return t&&(fm-Math.max(rep,t.back))/WEEK<p.ref-2;}).length;
  const fx=adjust(effectsFor(round1(e),absentTop/15),mods(s,id,st));fx.friendlies=friendliesFor(weeks);
  return {id,rep,fm,first,weeks:round1(weeks),e:round1(e),away:away.length,absentTop,fx};
 }
 function build(s,st){
  const tour=tourists(s),clubs=[],players={};
  for(const c of s.clubs){
   const row=buildClub(s,c.id,tour,st);if(!row)continue;
   const ref=profile(s,c.id).ref;
   clubs.push([c.id,row.rep,weekOfDay(s,row.fm),Math.round(row.e*10),0]);
   for(const p of c.players){
    const t=tour.get(p.id);if(!t)continue;
    const join=Math.max(row.rep,t.back),e=clamp((row.fm-join)/WEEK-ref,-4,3);
    const gap=Math.round(clamp(3*Math.max(0,-e),0,12));
    players[p.id]=[join,gap];
   }
  }
  return {clubs,players};
 }
 const planClub=(st,id)=>st?.plan?.clubs.find(r=>r[0]===id)||null;

 // ------------------------------------------------------------ état
 function blank(s,start){return {version:1,start,season:s.season,choice:null,youth:null,auto:start==='veille',plan:null,report:null,history:[],program:null,camp:null,notes:[]};}
 // Nouvelle saison visée (choix d'intersaison) : les décisions de la préparation repartent de zéro.
 function retarget(st,t){upgrade(st);st.season=t;st.auto=false;st.program=null;st.camp=null;}
 // État d'avant le 16/11/2026 (9 clés) : décisions et éléments « À noter » ajoutés au premier passage.
 function upgrade(st){if(st&&st.notes===undefined){st.program??=null;st.camp??=null;st.notes=[];}return st;}
 // L'avant-saison (avant-saison.cjs, S.preseason) porte la date de juillet-août ; la reprise en
 // choisit seulement le point de départ.
 const P=()=>typeof CDPreseason!=='undefined'?CDPreseason:null;
 function create(s,start='premiers-clubs'){
  if(!active(s))return null;
  if(!STARTS.includes(start))throw Error('Départ de partie inconnu.');
  const st=s.reprise=blank(s,start),opening=engineStart(s),own=clubDefault(s,s.club);
  if(start==='club'&&P()?.pending(s)){
   if(own&&own.day<opening){if(own.day>dayOf(s.preseason.today))s.preseason.today=iso(own.day);}
   else P().open(s);
  }
  if(start==='veille'&&P()?.pending(s))P().open(s);
  sync(s);
  return st;
 }
 // Ouverture du calendrier constatée (commande, entraînement de la semaine) : plan figé.
 function sync(s){
  const st=s?.reprise;if(!active(s)||!st)return false;
  upgrade(st);
  settle(s);
  deliver(s);
  if(pending(s))return false;
  const last=weekSeen.get(s);weekSeen.set(s,s.round);
  if(st.plan===null||st.plan&&st.season!==s.season&&s.phase!=='ended'){handover(s);return true;}
  // Calendrier journalier : la semaine se clôt par CDWorldCareer.advanceDay (finishWeek), sans passer par
  // finishRound. Les effets de début de saison tombent donc au changement de semaine constaté ici (une
  // fois par semaine ; rien au premier passage après un import, la semaine ayant été traitée avant).
  if(last!==undefined&&last!==s.round&&s.phase!=='ended'){applyDue(s);capConditions(s);}
  return false;
 }
 const weekSeen=new WeakMap();
 function suggestYouth(s,id,tour){
  const def=decide(s,id,s.reprise);
  const away=s.clubs[id].players.filter(p=>tour.get(p.id)&&tour.get(p.id).back>(def??0)).length;
  return youthCandidates(s,id).slice(0,clamp(away,2,YOUTH_MAX));
 }
 // Passage de la préparation au calendrier du moteur (17 août en 2026) : le plan de toute la
 // planète est figé ; les effets tombent à la semaine de la 1re rencontre de chaque club.
 function handover(s){
  const st=s.reprise;st.season=s.season;st.plan=build(s,st);st.report=null;
  applyDue(s);
 }
 function pending(s){return active(s)&&s.reprise&&P()?.pending(s)?s.preseason:null;}
 function today(s){const p=pending(s);return p?dayOf(p.today):dayOf(W().calendarToday(s));}

 // ------------------------------------------------------------ décisions de la préparation
 // Jours dus de la saison en cours (club du manager) : programme des amicaux le jour de la reprise,
 // orientation du stage une semaine plus tard (au plus tard la veille de la 1re rencontre). Aucune
 // décision quand le staff gère la préparation (départ « veille ») ou une fois les effets appliqués.
 function dueDays(s){
  const st=s.reprise;if(!active(s)||!st||st.auto||st.season!==s.season||s.phase==='ended')return null;
  const r=planClub(st,s.club);if(r&&r[4])return null;
  const rep=decide(s,s.club,st),first=fmDay(s,s.club);if(rep===null||first===null)return null;
  return {amicaux:rep,stage:Math.min(rep+WEEK,first-1)};
 }
 // Décisions attendues aujourd'hui (jour dû atteint, pas encore prises) : arrêt de « Continuer ».
 function due(s){
  const d=dueDays(s);if(!d)return [];
  const now=today(s);return DECISION_KEYS.filter(k=>s.reprise[DECISIONS[k].field]==null&&now>=d[k]);
 }
 // Prochaine décision prévisible (info-bulle de « Continuer ») : {date, detail} ou null.
 function nextDecision(s){
  const d=dueDays(s);if(!d)return null;const now=today(s);
  const open=DECISION_KEYS.filter(k=>s.reprise[DECISIONS[k].field]==null&&d[k]>now).sort((a,b)=>d[a]-d[b]);
  return open.length?{date:iso(d[open[0]]),detail:DECISIONS[open[0]].title}:null;
 }
 // Avance au-delà du jour dû sans réponse : le staff applique le choix prudent et le dit.
 function record(s,key,id,staff){
  upgrade(s.reprise);s.reprise[DECISIONS[key].field]={id,staff};
  // Seule la délégation est annoncée : le choix du manager est visible dans « La reprise ».
  if(staff&&typeof news==='function')news(`Gabi a arrêté ${key==='amicaux'?'le programme des matchs amicaux':'l’orientation du stage'} à ta place : ${DECISIONS[key].options[id].label.toLowerCase()}.`);
 }
 // ------------------------------------------------------------ éléments « À noter » (courrier de pré-saison)
 // Façon FM : des éléments informatifs arrivent en Réception le jour où ils se produisent ; « Continuer » s'arrête
 // dessus selon son flux (continuer.cjs, FLUX), sans réponse attendue. Plusieurs éléments le même jour sont
 // normaux : ils sont tous dans la Réception à l'arrêt. Identifiant « type:date[:n] », gardé dans S.reprise.notes
 // pour n'envoyer chaque élément qu'une fois. Club du manager, préparation non confiée au staff.
 const NOTE_MAX=32;
 function schedule(s){
  const st=s.reprise;if(!active(s)||!st||st.auto||st.season!==s.season||s.phase==='ended')return [];
  const rep=decide(s,s.club,st),first=fmDay(s,s.club);if(rep===null||first===null||today(s)>first)return [];
  const out=[],tour=tourists(s),row=buildClub(s,s.club,tour,st),eve=first-1;
  const backs=new Map();
  for(const p of s.clubs[s.club].players){const t=tour.get(p.id);if(t&&t.back>rep&&t.back<first){if(!backs.has(t.back))backs.set(t.back,[]);backs.get(t.back).push(p);}}
  for(const [day,players]of backs)out.push({id:'retour:'+iso(day),kind:'retour',day,players});
  const dates=row?friendlyDates(row):[];
  dates.forEach((day,i)=>{if(day<eve)out.push({id:'amical:'+iso(day),kind:'amical',day,index:i,count:dates.length,row});});
  const due=dueDays(s),end=due?due.stage+4:rep+WEEK+4;
  if(end<eve)out.push({id:'stage:'+iso(end),kind:'stage',day:end});
  if(eve>rep){out.push({id:'recrutement:'+iso(eve),kind:'recrutement',day:eve});out.push({id:'veille:'+iso(eve),kind:'veille',day:eve,first});}
  return out.sort((a,b)=>a.day-b.day||a.id.localeCompare(b.id));
 }
 // Force d'un club : moyenne des 23 meilleures notes (adversaire d'amical selon le programme).
 const strength=c=>{const r=c.players.map(p=>p.rating).sort((a,b)=>b-a).slice(0,23);return r.length?r.reduce((n,x)=>n+x,0)/r.length:0;};
 function friendlyOpponent(s,note,program){
  const own=strength(s.clubs[s.club]),pool=s.clubs.filter(c=>c.id!==s.club&&c.players.length>=23).map(c=>({c,d:strength(c)-own}));
  const fit=program==='rodage'?pool.filter(x=>x.d<=-3):program==='releve'?pool.filter(x=>x.d>=2):pool.filter(x=>Math.abs(x.d)<3);
  const list=(fit.length?fit:pool).sort((a,b)=>Math.abs(a.d)-Math.abs(b.d)||a.c.id-b.c.id).slice(0,10);
  // Un adversaire différent à chaque amical (rang dans le programme), point de départ tiré de la saison.
  return list.length?list[(hash('amical-adversaire:'+s.season+':'+s.club)+note.index)%list.length]:null;
 }
 // Score d'un amical (déterministe : graine de la saison et de l'élément), partagé par le courrier et le résumé.
 function amicalScore(s,note){
  const st=s.reprise,name=s.clubs[s.club].name,program=st.program?.id||PRUDENT,opp=friendlyOpponent(s,note,program),home=program==='rodage'||program===PRUDENT&&note.index%2===0;
  const gap=opp?opp.d:0,h=k=>hash('amical-score:'+s.season+':'+note.id+':'+k);
  let us=10+h(0)%24,them=10+h(1)%24;const edge=Math.round(clamp(-gap*1.5+(home?3:-3),-18,18));if(edge>0)us+=edge;else them-=edge;
  const other=opp?opp.c.name:'un club invité';
  return {home,us,them,other,score:home?`${name} ${us}-${them} ${other}`:`${other} ${them}-${us} ${name}`};
 }
 // Résumé d'un élément en quelques mots, pour l'arrêt hebdomadaire de « Continuer » (une ligne par élément).
 function noteBrief(s,note){
  if(note.kind==='retour'){const n=note.players.length,names=[...note.players].sort((a,b)=>b.rating-a.rating).slice(0,2).map(p=>p.name).join(', ');return `${n} ${n>1?'internationaux de retour':'international de retour'} (${names}${n>2?'…':''})`;}
  if(note.kind==='amical'){const r=amicalScore(s,note);return `amical ${note.index+1}/${note.count} ${r.us>r.them?'gagné':r.us<r.them?'perdu':'nul'} ${r.us}-${r.them} ${r.home?'contre':'chez'} ${r.other}`;}
  if(note.kind==='stage')return `${DECISIONS.stage.options[s.reprise.camp?.id||PRUDENT].label.toLowerCase()} terminé`;
  if(note.kind==='recrutement'){let needs=[];try{needs=typeof recruitmentNeeds==='function'?recruitmentNeeds(JSON.parse(JSON.stringify(s.clubs[s.club]))).filter(x=>x.need).slice(0,3):[];}catch(e){needs=[];}return needs.length?'à renforcer : '+needs.map(x=>x.pos).join(', '):'effectif complet, rien d’urgent au recrutement';}
  const f=s.worldMode.fixtures.find(x=>(x.homeId===s.club||x.awayId===s.club)&&x.date===iso(note.first)),opp=f?s.clubs[f.homeId===s.club?f.awayId:f.homeId]?.name:null;
  return '1re journée demain'+(opp?(f.homeId===s.club?' : réception de ':' : déplacement à ')+opp:'');
 }
 // Résumés des éléments déjà envoyés dont la date est dans [from, to] (ISO) : {id: résumé}.
 function notesBrief(s,from,to){
  const st=s?.reprise;if(!active(s)||!st||!Array.isArray(st.notes))return {};
  const out={};for(const note of schedule(s)){const d=iso(note.day);if(d>=from&&d<=to&&st.notes.includes(note.id))out[note.id]=noteBrief(s,note);}
  return out;
 }
 function noteText(s,note){
  const st=s.reprise,club=s.clubs[s.club],name=club.name,day=d=>iso(d).slice(8,10)+'/'+iso(d).slice(5,7);
  if(note.kind==='retour'){
   const n=note.players.length,names=note.players.sort((a,b)=>b.rating-a.rating).slice(0,4).map(p=>p.name).join(', ');
   return `Retour de tournée : ${n} ${n>1?'internationaux':'international'} rejoi${n>1?'gnent':'nt'} le groupe (${names}${n>4?'…':''}). Le staff les remet en route progressivement.`;
  }
  if(note.kind==='amical'){
   const {home,score}=amicalScore(s,note);
   const m=mods(s,s.club),ids=st.youth!==null?st.youth:suggestYouth(s,s.club,tourists(s)).map(p=>p.id);
   const youths=ids.map(x=>academyOf(s,s.club).find(p=>p.id===x)).filter(p=>p&&!p.injury).map(p=>{const base=25+hash('amical:'+s.season+':'+p.id+':'+note.day)%31;return {p,minutes:m.youth===1?base:Math.round(clamp(base*m.youth,10,80))};});
   const hurt=club.players.filter(p=>p.injury>0).length;
   return `Match amical ${note.index+1}/${note.count} : ${score}${home?' (à domicile)':' (à l’extérieur)'}. `+
    (youths.length?`Jeunes du centre : ${youths.slice(0,5).map(y=>y.p.name+' '+y.minutes+' min').join(', ')}${youths.length>5?` et ${youths.length-5} autre${youths.length>6?'s':''}`:''}. `:'')+
    `Infirmerie : ${hurt?hurt+' joueur'+(hurt>1?'s':'')+' indisponible'+(hurt>1?'s':''):'aucun indisponible'}.`;
  }
  if(note.kind==='stage'){
   const o=DECISIONS.stage.options[st.camp?.id||PRUDENT];
   return `Fin du stage de préparation (${o.label.toLowerCase()}) : ${summary(o,0).replace(/^./,c=>c.toLowerCase())}`;
  }
  if(note.kind==='recrutement'){
   let needs=[];try{needs=typeof recruitmentNeeds==='function'?recruitmentNeeds(JSON.parse(JSON.stringify(club))).filter(x=>x.need).slice(0,3):[];}catch(e){needs=[];}
   return needs.length?`Dernier point recrutement avant la 1re journée : postes à renforcer, ${needs.map(x=>x.pos+' ('+x.reasons[0]+')').join(', ')}. Le marché reste ouvert dans Recrutement.`
    :'Dernier point recrutement avant la 1re journée : l’effectif couvre tous les postes, rien d’urgent dans Recrutement.';
  }
  const f=s.worldMode.fixtures.find(x=>(x.homeId===s.club||x.awayId===s.club)&&x.date===iso(note.first));
  const opp=f?s.clubs[f.homeId===s.club?f.awayId:f.homeId]?.name:null,top=[...club.players].sort((a,b)=>b.rating-a.rating).slice(0,23);
  const cond=Math.round(top.reduce((n,p)=>n+(p.condition??100),0)/Math.max(1,top.length)),hurt=club.players.filter(p=>p.injury>0).length;
  return `Veille de la 1re journée${opp?` : ${f.homeId===s.club?'réception de':'déplacement à'} ${opp} demain`:''}. Condition moyenne du groupe ${cond} %, ${hurt?hurt+' blessé'+(hurt>1?'s':''):'aucun blessé'}.`;
 }
 // Envoi des éléments du jour (et de ceux d'un jour passé d'un bond) : une seule fois chacun.
 function deliver(s){
  const st=s.reprise;if(!st||!Array.isArray(st.notes))return 0;
  const now=today(s);let n=0;
  for(const note of schedule(s)){
   if(note.day>now||st.notes.includes(note.id))continue;
   if(typeof news==='function')news(noteText(s,note));
   st.notes.push(note.id);st.notes=st.notes.slice(-NOTE_MAX);n++;
  }
  return n;
 }
 // Lecture pour « Continuer » : éléments déjà envoyés, et prochains éléments prévus ({date, kind}).
 const notesSeen=s=>active(s)&&Array.isArray(s.reprise?.notes)?s.reprise.notes.slice():[];
 function nextNotes(s){const st=s?.reprise;if(!st||!Array.isArray(st.notes))return [];const now=today(s);return schedule(s).filter(n=>n.day>now&&!st.notes.includes(n.id)).map(n=>({date:iso(n.day),kind:n.kind}));}
 function settle(s){
  const d=dueDays(s);if(!d)return false;const now=today(s);let changed=false;
  for(const k of DECISION_KEYS)if(s.reprise[DECISIONS[k].field]==null&&now>d[k]){record(s,k,PRUDENT,true);changed=true;}
  return changed;
 }

 // ------------------------------------------------------------ application des effets
 function friendlyDates(row){
  const out=[],n=row.fx.friendlies,span=row.first-row.rep;
  for(let i=0;i<n;i++){const d=row.rep+Math.round(span*(i+1)/(n+1));out.push(d+((6-new Date(d*DAY).getUTCDay()+7)%7));}
  return [...new Set(out.filter(d=>d<row.first))];
 }
 // Recette nette des amicaux du club du manager (arrondie au millier ; 0 pour le programme équilibré).
 function receiptsFor(s,friendlies,m){
  const base=RECEIPT[leagueOf(s,s.club)]??20000;
  return Math.round(friendlies*base*m.receipts/1000)*1000;
 }
 function playYouth(s,id,row,ids,factor=1){
  const rows=[],club=s.clubs[id],youths=ids.map(x=>academyOf(s,id).find(p=>p.id===x)).filter(p=>p&&!p.injury);
  const dates=friendlyDates(row);
  for(const p of youths){
   let minutes=0;
   for(const d of dates){const base=25+hash('amical:'+s.season+':'+p.id+':'+d)%31;minutes+=factor===1?base:Math.round(clamp(base*factor,10,80));}
   const before=p.rating;
   if(minutes&&typeof growPlayer==='function'&&p.dev){
    p.dev.minutes+=minutes;p.dev.careerMinutes=(p.dev.careerMinutes||0)+minutes;
    const age=typeof ageGrowth==='function'?ageGrowth(p):1;
    growPlayer(p,minutes/80*.12*.55*age,true);
   }
   rows.push({id:p.id,name:p.name,pos:p.pos,age:p.age,minutes,friendlies:dates.length,gain:p.rating-before});
  }
  return rows;
 }
 function startState(s,r){
  const [id,,fmWeek,e10]=r,c=s.clubs[id],st=s.reprise,row=buildFromPlan(s,r);
  const fx=row.fx,m=mods(s,id);
  for(const p of c.players){
   const own=st.plan.players[p.id];
   if(!own){const load=typeof ensurePhysicalLoad==='function'?ensurePhysicalLoad(p):null;if(load)load.fatigue=clamp(Math.max(load.fatigue,fx.fatigue),0,100);}
   const gap=own?gapWith(own[1],m):fx.conditionGap;
   if(gap>0)p.condition=Math.min(p.condition,100-gap);
  }
  const morale=clamp(75+fx.morale,40,90);
  if(id===s.club){s.morale=morale;if(s.v39?.version===1)s.v39.cohesion=clamp(65+Math.round(fx.automatismes/2)+m.cohesion,40,85);}
  else c.morale=morale;
  const auto=id!==s.club||st.auto;
  const ids=id===s.club&&st.youth!==null?st.youth:suggestYouth(s,id,tourists(s)).map(p=>p.id);
  const youth=playYouth(s,id,row,ids,m.youth);
  if(id===s.club){
   const receipts=receiptsFor(s,fx.friendlies,m);
   if(receipts&&typeof ledgerEntry==='function')ledgerEntry(receipts>0?'Recettes des matchs amicaux':'Frais de déplacement des matchs amicaux',receipts);
   const choices=Object.fromEntries(DECISION_KEYS.map(k=>{const v=st[DECISIONS[k].field];return [k,v?{id:v.id,staff:v.staff}:null];}));
   st.report={season:s.season,date:iso(row.rep),weeks:row.weeks,friendlies:fx.friendlies,effects:fx,youth,auto,choices,receipts};
   st.history.push({season:s.season,date:iso(row.rep),weeks:row.weeks,friendlies:fx.friendlies,youth:youth.length,minutes:youth.reduce((n,y)=>n+y.minutes,0)});
   st.history=st.history.slice(-HISTORY);
   if(typeof news==='function')news(`Fin de la préparation : ${fx.friendlies} match${fx.friendlies>1?'s':''} amica${fx.friendlies>1?'ux':'l'}, ${youth.length} jeune${youth.length>1?'s':''} du centre lancé${youth.length>1?'s':''}.`);
  }
  return auto;
 }
 function buildFromPlan(s,r){
  const [id,rep]=r,first=fmDay(s,id),p=profile(s,id),weeks=(first-rep)/WEEK,e=r[3]/10;
  const tour=new Map(Object.entries(s.reprise.plan.players).map(([pid,[join]])=>[pid,{back:join}]));
  const top=[...s.clubs[id].players].sort((a,b)=>b.rating-a.rating).slice(0,15);
  const absentTop=top.filter(x=>{const t=s.reprise.plan.players[x.id];return t&&(monday(first)-t[0])/WEEK<p.ref-2;}).length;
  const fx=adjust(effectsFor(e,absentTop/15),mods(s,id));fx.friendlies=friendliesFor(weeks);
  return {id,rep,first,weeks:round1(weeks),e,fx};
 }
 function applyDue(s){
  const st=s.reprise;if(!st?.plan||st.season!==s.season)return;
  for(const r of st.plan.clubs)if(!r[4]&&r[2]<=s.round){startState(s,r);r[4]=1;}
 }
 // Condition plafonnée pendant les quatre premières semaines officielles (retard de condition,
 // décroissant), et en fin de saison pour les reprises très tôt (fraîcheur entamée).
 function capConditions(s){
  const st=s.reprise;if(!st?.plan||st.season!==s.season)return;
  for(const r of st.plan.clubs){
   if(!r[4])continue;const k=s.round-r[2];
   const c=s.clubs[r[0]],m=mods(s,r[0]),fx=adjust(effectsFor(r[3]/10,0),m);
   if(k>=0&&k<WINDOW)for(const p of c.players){
    const own=st.plan.players[p.id],gap=own?gapWith(own[1],m):fx.conditionGap;
    if(gap>0)p.condition=Math.min(p.condition,100-Math.round(gap*(1-k/WINDOW)));
   }
   // Fin de saison : à partir de la semaine 30, et au moins 24 semaines après la 1re journée du club.
   if(s.round>=Math.max(LATE_FROM,r[2]+24)&&fx.lateCondition>0)for(const p of c.players)p.condition=Math.min(p.condition,100-fx.lateCondition);
  }
 }
 function windowFactor(s,id){const r=planClub(s.reprise,id);if(!r||!r[4])return null;const k=s.round-r[2];return k>=0&&k<WINDOW?{r,k,f:1-k/WINDOW}:null;}
 function extraInjuries(l){
  const s=typeof S==='undefined'?null:S,st=s?.reprise;if(!active(s)||!st?.plan||st.season!==s.season||!l?.finished||!l.sheets)return;
  for(let side=0;side<2;side++){
   const id=l.pair[side],w=windowFactor(s,id);if(!w)continue;
   const m=mods(s,id),base=adjust(effectsFor(w.r[3]/10,0),m).injuryRisk;
   for(const pid of l.sheets[side].used||[]){
    const p=s.clubs[id].players.find(x=>x.id===pid),minutes=l.sheets[side].minutes?.[pid]||0;
    if(!p||p.injury||!minutes)continue;
    const own=st.plan.players[pid],risk=(own?clamp(own[1]/3*.4+m.risk,0,2):base)/100*w.f*minutes/80;
    if(risk>0&&unit('reprise-blessure:'+s.season+':'+s.round+':'+l.pair.join('-')+':'+pid)<risk){
     p.injury=1+hash('reprise-duree:'+s.season+':'+pid)%3;
     // Origine enregistrée sur la blessure, comme pour les autres rencontres (club-mail.cjs, installHooks).
     if(id===s.club){const fx=(s.worldMode?.fixtures||[]).find(f=>f.homeId===l.pair[0]&&f.awayId===l.pair[1]&&f.week===s.round)||null,opp=l.pair[1-side];p.injuryOrigin={type:'match',fixtureId:fx?.id??null,opp,oppName:s.clubs?.[opp]?.name||null,home:side===0,neutral:!!fx?.neutral,us:Number(l.score?.[side])||0,them:Number(l.score?.[1-side])||0,date:/^\d{4}-\d{2}-\d{2}$/.test(fx?.date||'')?fx.date:null,season:s.season??null,round:s.round??null};}
     if(id===s.club&&typeof news==='function')news(`${p.name} se blesse en début de saison, encore court physiquement : ${p.injury} semaine(s) d’indisponibilité.`);
    }
   }
  }
 }
 function scaleCollective(l){
  const s=typeof S==='undefined'?null:S;if(!active(s)||!l?.collectivePreparation?.power)return;
  l.collectivePreparation.power=l.collectivePreparation.power.map((v,side)=>{
   const w=windowFactor(s,l.pair[side]);if(!w)return v;
   const row=buildFromPlan(s,w.r);return Math.round(clamp(v*(1+row.fx.automatismes/100*w.f),.55,1)*100)/100; // bornes de la sauvegarde
  });
 }

 // ------------------------------------------------------------ commandes
 function context(s){return {season:s.season,today:iso(today(s))};}
 // Décision ouverte : pendant la préparation, puis tant que la date retenue n'est pas passée ;
 // en fin de saison, pour la saison suivante (stockée en semaines avant la 1re journée).
 function target(s){
  const st=s.reprise;if(!st||st.auto&&st.season===s.season&&s.phase!=='ended')return null;
  if(pending(s))return s.season;
  if(s.phase==='ended')return s.season+1;
  if(st.season===s.season&&st.plan){const r=planClub(st,s.club);if(r&&!r[4]&&r[1]>today(s))return s.season;}
  return null;
 }
 // Lundis proposés pour la saison visée (saison suivante : même écart à la 1re journée).
 function targetOptions(s){
  const t=target(s);if(t===null)return [];
  if(t===s.season)return options(s,s.club,today(s)).map(d=>({day:d,weeks:(fmMonday(s,s.club)-d)/WEEK}));
  const p=profile(s,s.club),fm=fmMonday(s,s.club)+364,out=[];
  for(let w=p.ref+3;w>=Math.max(2,p.ref-3);w--)out.push({day:fm-w*WEEK,weeks:w});
  return out;
 }
 function choose(s,payload){
  const st=s.reprise;if(!active(s)||!st)throw Error('Reprise indisponible.');
  const t=target(s);if(t===null)throw Error('La date de reprise ne peut plus être modifiée.');
  if(payload?.habitual===true&&Object.keys(payload).length===1){
   if(t!==st.season){retarget(st,t);st.youth=null;}
   st.choice=null;
  }else{
   const day=typeof payload?.date==='string'&&date(payload.date)?dayOf(payload.date):NaN;
   const pick=targetOptions(s).find(o=>o.day===day);if(!pick)throw Error('Date de reprise non proposée.');
   if(t!==st.season){retarget(st,t);st.youth=null;}
   const def=t===s.season?clubDefault(s,s.club):null;
   st.choice=def&&def.day===day?null:Number.isInteger(pick.weeks)?pick.weeks:null;
  }
  if(t===s.season&&st.plan)replan(s);
  return {reprise:{choice:st.choice}};
 }
 function replan(s){
  const st=s.reprise,tour=tourists(s),row=buildClub(s,s.club,tour,st),i=st.plan.clubs.findIndex(r=>r[0]===s.club);
  st.plan.clubs[i]=[s.club,row.rep,weekOfDay(s,row.fm),Math.round(row.e*10),0];
  const ref=profile(s,s.club).ref;
  for(const p of s.clubs[s.club].players){const t=tour.get(p.id);if(!t)continue;const join=Math.max(row.rep,t.back),e=clamp((row.fm-join)/WEEK-ref,-4,3);st.plan.players[p.id]=[join,Math.round(clamp(3*Math.max(0,-e),0,12))];}
 }
 function youth(s,payload){
  const st=s.reprise;if(!active(s)||!st)throw Error('Reprise indisponible.');
  const t=target(s);if(t===null)throw Error('Le groupe de préparation est déjà constitué.');
  if(t!==st.season){retarget(st,t);st.choice=null;}
  const ids=payload?.playerIds;
  if(!Array.isArray(ids)||ids.length>YOUTH_MAX||new Set(ids).size!==ids.length)throw Error(`Convoque au plus ${YOUTH_MAX} jeunes.`);
  const allowed=new Set(youthCandidates(s,s.club).map(p=>p.id));
  if(!ids.every(id=>allowed.has(id)))throw Error('Jeune non convocable (Espoirs et -18 de 17 ans, valides).');
  st.youth=ids.slice();return {reprise:{youth:st.youth.length}};
 }
 function advanceTo(s,payload){
  const st=pending(s);if(!st)throw Error('Aucune avant-saison en cours.');
  if(payload?.fromDate!==st.today||!['semaine','reprise','saison'].includes(payload?.until))throw Error('La date de carrière a changé.');
  const opening=engineStart(s),goal=payload.until==='saison'?opening:payload.until==='reprise'?decide(s,s.club,s.reprise):dayOf(st.today)+7;
  if(!(goal>dayOf(st.today)))throw Error('Date déjà atteinte.');
  if(goal>=opening){P().open(s);sync(s);}else st.today=iso(goal);
  return {repriseAdvance:{today:pending(s)?.today??null}};
 }
 // Décision de la préparation : {decision:'amicaux'|'stage', option:<id>|'staff'} ; « staff » confie la
 // décision à Gabi (choix prudent). Modifiable jusqu'au jour dû ; en intersaison, pour la saison suivante.
 function decideCommand(s,payload){
  const st=s.reprise;if(!active(s)||!st)throw Error('Reprise indisponible.');
  if(!object(payload)||Object.keys(payload).length!==2||!Object.hasOwn(DECISIONS,payload.decision)||typeof payload.option!=='string')throw Error('Décision de préparation invalide.');
  const d=DECISIONS[payload.decision],staff=payload.option==='staff',id=staff?PRUDENT:payload.option;
  if(!Object.hasOwn(d.options,id))throw Error('Option de préparation inconnue.');
  const t=target(s),next=t!==null&&t!==s.season;
  if(next){if(t!==st.season){retarget(st,t);st.choice=null;st.youth=null;}st[d.field]={id,staff};return {reprise:{[payload.decision]:id}};}
  const days=dueDays(s);
  if(!days||today(s)>days[payload.decision])throw Error('Cette décision de préparation est déjà arrêtée.');
  record(s,payload.decision,id,staff);
  return {reprise:{[payload.decision]:id}};
 }
 function execute(command,payload){
  const s=S;
  if(command==='reprise_decide')return decideCommand(s,payload);
  if(command==='reprise_choose')return choose(s,payload);
  if(command==='reprise_youth')return youth(s,payload);
  if(command==='reprise_advance')return advanceTo(s,payload);
  throw Error('Commande de reprise inconnue.');
 }

 // ------------------------------------------------------------ projection
 function gabi(s,away,options,def,shift){
  const share=away.length/Math.max(1,s.clubs[s.club].players.length),ref=profile(s,s.club).ref,fm=fmMonday(s,s.club);
  const weeks=d=>(fm-d)/WEEK;let pick=def,text='La date habituelle du club laisse une préparation équilibrée.';
  if(finalist(s,s.club)&&!shift||shift&&s.worldMode.leagues[leagueOf(s,s.club)]?.finalist!==undefined&&[s.worldMode.leagues[leagueOf(s,s.club)].champion,s.worldMode.leagues[leagueOf(s,s.club)].finalist].includes(s.club)){
   pick=options.find(d=>weeks(d)<=ref-1)??def;text='Après une saison allée jusqu’en finale, les organismes ont besoin d’une semaine de plus : reprenons un peu plus tard.';}
  else if(share>=.2){pick=options.find(d=>weeks(d)<=ref-1)??def;text=`${away.length} internationaux rentrent de tournée plus tard : inutile de reprendre très tôt sans eux. Complétons le groupe avec des jeunes du centre, ils joueront les amicaux.`;}
  else if(share<.08){pick=options.find(d=>weeks(d)<=ref+2)??def;text='Peu d’internationaux en tournée : reprendre tôt construit les automatismes sans priver le groupe de ses cadres. Attention à la fraîcheur en fin de saison.';}
  return {date:iso(pick+shift),weeks:weeks(pick),text};
 }
 function project(){
  const s=typeof S==='undefined'?null:S;
  if(!active(s)||!s.reprise)return {available:false};
  const st=s.reprise,now=today(s),tour=tourists(s),t=target(s),next=t!==null&&t!==s.season;
  const shift=next?364:0,def=clubDefault(s,s.club),fm=fmDay(s,s.club),fmM=fmMonday(s,s.club),ref=profile(s,s.club).ref;
  const mine=k=>next?(st.season===t?st[k]??null:null):st[k]??null;
  const own={...st,season:s.season,choice:mine('choice'),program:mine('program'),camp:mine('camp')};
  const chosen=decide(s,s.club,own);
  const rowFor=choice=>buildClub(s,s.club,tour,{...own,choice});
  const describe=o=>{const row=rowFor(def&&def.day===o.day-shift?null:o.weeks);return {date:iso(o.day),weeks:round1((fmM+shift-o.day)/WEEK+(fm-fmM)/WEEK),habitual:!next&&def?.day===o.day,friendlies:row.fx.friendlies,effects:row.fx,away:row.away};};
  const club=s.clubs[s.club],away=club.players.filter(p=>tour.get(p.id)&&tour.get(p.id).back>chosen).map(p=>{const x=tour.get(p.id);return {id:p.id,name:p.name,pos:p.pos,rating:p.rating,nation:x.nation,returnDate:iso(x.back+shift),weeks:round1((fm-Math.max(x.back,chosen))/WEEK),status:now<x.back+shift?'en congés · retour le '+iso(x.back+shift):'de retour'};}).sort((a,b)=>a.returnDate.localeCompare(b.returnDate)||b.rating-a.rating);
  const candidates=youthCandidates(s,s.club),suggested=suggestYouth(s,s.club,tour).map(p=>p.id);
  const row=rowFor(own.choice),selected=(own.season===st.season&&!next||st.season===t)&&st.youth!==null?st.youth:suggested;
  const opts=targetOptions(s);
  return {available:true,start:st.start,season:t??st.season,nextSeason:next,today:pending(s)?.today??null,calendarToday:iso(now),auto:st.auto,editable:t!==null,
   club:{date:chosen===null?null:iso(chosen+shift),habitual:def?iso(def.day+shift):null,real:!!def?.real&&!next,finalShift:!!def?.finalShift,firstMatch:fm===null?null:iso(fm+shift),reference:ref,weeks:row?.weeks??null,friendlies:row?friendlyDates(row).map(d=>iso(d+shift)):[],effects:row?.fx??null},
   options:opts.map(describe),internationals:away,
   group:{total:club.players.length,atReprise:club.players.length-away.length,youth:selected.length},
   youth:{max:YOUTH_MAX,selected:selected.slice(),staff:st.youth===null,suggested,candidates:candidates.slice(0,16).map(p=>({id:p.id,name:p.name,pos:p.pos,age:p.age,rating:p.rating,potential:p.dev?.potential??null}))},
   advice:def&&opts.length?gabi(s,away,opts.map(o=>o.day-shift),chosen??def.day,shift):null,
   decisions:row&&chosen!==null?projectDecisions(s,{t,next,shift,own,row,chosen,now,away:away.length,youth:selected.length}):[],
   due:due(s),
   report:st.report?JSON.parse(JSON.stringify(st.report)):null,history:st.history.slice()};
 }
 const signed=(n,unit='')=>(n>0?'+':'−')+String(Math.abs(n)).replace('.',',')+unit;
 // Conséquences d'une option, du point de vue du manager.
 function summary(o,receipts){
  const parts=[];
  if(o.gap)parts.push(`condition aux premiers matchs ${signed(-o.gap)}`);
  if(o.risk)parts.push(o.risk>0?'risque de blessure en hausse en début de saison':'risque de blessure en baisse en début de saison');
  if(o.fatigue)parts.push(`charge physique ${signed(o.fatigue)}`);
  if(o.auto)parts.push(`automatismes ${signed(o.auto,' %')}`);
  if(o.morale)parts.push(`moral ${signed(o.morale)}`);
  if(o.cohesion)parts.push(`cohésion du vestiaire ${signed(o.cohesion)}`);
  if(o.youth!==1)parts.push(o.youth>1?'plus de temps de jeu pour les jeunes':'moins de temps de jeu pour les jeunes');
  if(receipts)parts.push(receipts>0?`recettes ≈ ${receipts.toLocaleString('fr-FR')} €`:`frais de déplacement ≈ ${(-receipts).toLocaleString('fr-FR')} €`);
  if(!parts.length)return 'Aucun écart avec la préparation habituelle.';
  const text=parts.join(', ');return text[0].toUpperCase()+text.slice(1)+'.';
 }
 // Conseil de Gabi : situation du groupe (retard de condition, cadres absents, jeunes, trésorerie).
 function advise(s,key,base,ctx){
  if(key==='amicaux'){
   if(base.conditionGap>=6)return {option:'releve',text:'Le groupe reprend tard : il lui faut vite du rythme. Une opposition relevée l’y mettra, quitte à moins voir les jeunes.'};
   if(ctx.youth>=4||ctx.away>=6)return {option:'rodage',text:`Avec ${ctx.youth} jeune${ctx.youth>1?'s':''} du centre dans le groupe, recevons des clubs de division inférieure : ils joueront, et la billetterie rapportera un peu.`};
   if((s.clubs[s.club].cash??0)<0)return {option:'rodage',text:'La trésorerie est juste : des amicaux à domicile rapporteront un peu sans grand risque.'};
   return {option:'equilibre',text:'Des clubs de notre niveau en aller-retour : du rythme sans risque inutile.'};
  }
  if(base.conditionGap>=6)return {option:'physique',text:'Nous reprenons tard : un stage foncier rattrapera le retard de condition avant la 1re journée.'};
  if(base.automatismes<=-5)return {option:'cohesion',text:'Plusieurs cadres rejoindront le groupe tard : un stage de cohésion le soudera avant leur retour.'};
  if(base.automatismes>0)return {option:'technique',text:'Nous avons le temps : travaillons le plan de jeu, les lancements et la défense.'};
  return {option:'cohesion',text:'Un stage de cohésion soude le groupe et met tout le monde dans le bon état d’esprit.'};
 }
 function projectDecisions(s,ctx){
  const st=s.reprise,days=ctx.next?null:dueDays(s),base=effectsFor(ctx.row.e,(ctx.row.absentTop||0)/15),n=ctx.row.fx.friendlies;
  return DECISION_KEYS.map(k=>{
   const d=DECISIONS[k],dueDay=ctx.next?ctx.chosen+ctx.shift+(k==='stage'?WEEK:0):days?.[k]??null;
   const value=ctx.own[d.field]??null,editable=ctx.next?ctx.t!==null:dueDay!==null&&ctx.now<=dueDay;
   return {key:k,title:d.title,due:dueDay===null?null:iso(dueDay),editable,selected:value?value.id:null,staff:!!value?.staff,
    pending:value===null&&editable,friendlies:n,
    options:Object.entries(d.options).map(([id,o])=>{const receipts=receiptsFor(s,n,{receipts:o.receipts});
     return {id,label:o.label,detail:o.detail,prudent:id===PRUDENT,receipts,summary:summary(o,receipts),
      effects:{conditionGap:o.gap,injuryRisk:o.risk,fatigue:o.fatigue,automatismes:o.auto,morale:o.morale,cohesion:o.cohesion,youth:o.youth}};}),
    advice:advise(s,k,base,ctx)};
  });
 }
 // Création : départ et date de reprise du club pour la saison 2026-2027 (lecture seule).
 function creation(){return {starts:STARTS.slice(),firstClubs:'2026-07-13',elite:Object.fromEntries(Object.entries(ELITE_2026))};}

 // ------------------------------------------------------------ validation
 const date=x=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&iso(dayOf(x))===x;
 function validate(s){
  const st=s?.reprise;if(st===undefined)return true;
  const fail=m=>{throw Error('Reprise : '+m+'.');},check=(ok,m)=>{if(!ok)fail(m);};
  // 9 clés avant les décisions de la préparation (16/11/2026), 12 depuis (décisions et éléments « À noter »).
  const n=object(st)?Object.keys(st).length:0;
  check(n===9&&st.program===undefined&&st.camp===undefined&&st.notes===undefined||n===12&&Array.isArray(st.notes)&&st.notes.length<=NOTE_MAX&&st.notes.every(x=>typeof x==='string'&&/^(retour|amical|stage|recrutement|veille):\d{4}-\d{2}-\d{2}$/.test(x))&&DECISION_KEYS.every(k=>{const v=st[DECISIONS[k].field];return v===null||object(v)&&Object.keys(v).length===2&&typeof v.id==='string'&&Object.hasOwn(DECISIONS[k].options,v.id)&&typeof v.staff==='boolean';}),'décisions de préparation invalides');
  check(object(st)&&st.version===1&&STARTS.includes(st.start)&&(int(st.season,1,s.season)||s.phase==='ended'&&st.season===s.season+1)&&typeof st.auto==='boolean','état invalide');
  check(st.plan!==null||st.season===s.season&&s.round===0,'plan de reprise absent');
  check(st.choice===null||int(st.choice,1,18),'date choisie invalide');
  check(st.youth===null||Array.isArray(st.youth)&&st.youth.length<=YOUTH_MAX&&st.youth.every(x=>typeof x==='string'&&x.length<=180)&&new Set(st.youth).size===st.youth.length,'jeunes convoqués invalides');
  check(Array.isArray(st.history)&&st.history.length<=HISTORY&&st.history.every(h=>object(h)&&int(h.season,1,s.season)&&date(h.date)&&Number.isFinite(h.weeks)&&int(h.friendlies,0,4)&&int(h.youth,0,YOUTH_MAX)&&int(h.minutes,0,10000)),'historique invalide');
  check(st.report===null||object(st.report)&&int(st.report.season,1,s.season),'bilan invalide');
  if(st.plan!==null){
   check(object(st.plan)&&Object.keys(st.plan).length===2&&Array.isArray(st.plan.clubs)&&st.plan.clubs.length<=s.clubs.length&&object(st.plan.players),'plan invalide');
   const seen=new Set();
   for(const r of st.plan.clubs){check(Array.isArray(r)&&r.length===5&&int(r[0],0,s.clubs.length-1)&&!seen.has(r[0])&&Number.isSafeInteger(r[1])&&int(r[2],-60,60)&&int(r[3],-40,30)&&(r[4]===0||r[4]===1),'ligne de club invalide');seen.add(r[0]);}
   for(const [id,v]of Object.entries(st.plan.players))check(id.length<=180&&Array.isArray(v)&&v.length===2&&Number.isSafeInteger(v[0])&&int(v[1],0,12),'retour d’international invalide');
  }
  return true;
 }

 // ------------------------------------------------------------ branchements
 let installed=false;
 function installHooks(){
  if(installed)return true;installed=true;
  const wrap=(name,after,before)=>{const original=g[name];if(typeof original!=='function')return;const wrapped=function(){if(before)before.apply(this,arguments);const result=original.apply(this,arguments);after.apply(this,[result,...arguments]);return result;};Object.assign(wrapped,original);g[name]=wrapped;};
  const live=()=>{const s=typeof S==='undefined'?null:S;return active(s)&&s.reprise?s:null;};
  wrap('trainWeek',()=>{const s=live();if(s){sync(s);capConditions(s);}});
  wrap('finishRound',()=>{const s=live();if(s&&s.phase!=='ended'){sync(s);applyDue(s);capConditions(s);}});
  wrap('applyMatchInjuries',(result,l)=>extraInjuries(l),null);
  wrap('initializeCollectivePreparation',(result,l)=>scaleCollective(l));
  // Nouvelle saison : la décision prise en fin de saison s'applique, sinon la date habituelle.
  wrap('advanceSeason',()=>{const s=live();if(!s)return;const st=s.reprise;
   const keep=st.season===s.season;st.season=s.season;st.auto=false;if(!keep){st.choice=null;st.youth=null;st.program=null;st.camp=null;}if(Array.isArray(st.notes))st.notes=[];
   handover(s);});
  return true;
 }
 // Internationaux du club encore en tournée ou en congés à la date de la carrière : même liste et mêmes dates
 // de retour que le panneau « La reprise » ; le panneau « Absences internationales » de la Préparation les lit ici.
 function absentees(s){
  if(!active(s)||!s.reprise||!s.clubs?.[s.club])return [];
  const now=today(s),t=target(s),shift=t!==null&&t!==s.season?364:0,tour=tourists(s);
  return s.clubs[s.club].players.filter(p=>tour.get(p.id)&&tour.get(p.id).back+shift>now).map(p=>{const x=tour.get(p.id);
   return {id:p.id,name:p.name,pos:p.pos,nation:x.nation,from:iso(dayOf(year(s)+'-'+(NC.has(x.nation)?'07-04':'06-27'))+shift),through:iso(x.back+shift-1),returnDate:iso(x.back+shift)};
  }).sort((a,b)=>a.returnDate.localeCompare(b.returnDate)||(a.id<b.id?-1:1));
 }
 const api=Object.freeze({create,sync,pending,today,project,absentees,validate,creation,preview,handover,tourists,clubDefault,options,effectsFor,STARTS,due,nextDecision,notesSeen,nextNotes,notesBrief});
 g.CDReprise=api;
 return {project,validate,execute,installHooks,create,sync,pending,creation};
}
module.exports={files,commands,factory,STARTS};
