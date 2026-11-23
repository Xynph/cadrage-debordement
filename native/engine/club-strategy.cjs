'use strict';
const files=['board-calendar.js','sporting-director-v105-v110.js','fan-experience-v111-v116.js'];
const commands=['club_academy_investment','club_facility_upgrade','club_sponsor_sign','club_board_priority','club_board_assignment','club_board_project','club_board_mitigation','club_board_objective','club_fans_price','club_fans_campaign','club_fans_community','club_fans_service'];
function factory(){
 const copy=x=>JSON.parse(JSON.stringify(x)),isInt=(v,a,b)=>Number.isInteger(v)&&v>=a&&v<=b;
 const requireThat=(v,m)=>{if(!v)throw Error(m);};
 const world=s=>typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s);
 const week=s=>world(s)?s.worldMode.week:s.franceMode?s.franceMode.week:s.phase==='league'?s.round:({barrage:26,semi:27,final:28,ended:29}[s.phase]??s.round);
 const context=()=>({season:S.season,week:week(S),club:S.club});
 const weeks=s=>world(s)?CDWorldCareer.sizing(s).maxRound:s.franceMode?34:29;
 const projects={video:{label:'Analyse vidéo',cost:12000},medical:{label:'Organisation médicale',cost:18000},logistique:{label:'Logistique',cost:10000}};
 const campaigns={locale:{label:'Ancrage local',cost:3000},familiale:{label:'Public familial',cost:5000},numerique:{label:'Communication numérique',cost:4000}};
 const community={ecoles:{label:'Rencontre des écoles',cost:1500},associations:{label:'Clubs et associations',cost:2000},portesOuvertes:{label:'Portes ouvertes',cost:3000}};
 const services={simple:{label:'Accueil simple',cost:0},confort:{label:'Accueil confort',cost:2500},premium:{label:'Accueil premium',cost:6000}};
 const prices={accessible:12,equilibree:20,premium:30};
 const own=s=>s.clubs[s.club];
 // Capacité du stade : celle de la carrière, sinon (ancienne sauvegarde du Monde) la table des capacités par identifiant de club.
 const knownCapacity=s=>{const c=own(s);return c.stadiumCapacity??(world(s)&&typeof CDWorldStadiumCapacities!=='undefined'?CDWorldStadiumCapacities[c.id]:undefined)};
 // Only the tiny optional namespace is copied. API.ensure cannot mutate S here.
 const previewState=()=>({season:S.season,club:0,clubs:[{id:own(S).id,name:own(S).name,abbr:own(S).abbr,base:own(S).base,players:own(S).players,cash:own(S).cash,stadium:own(S).stadium,stadiumCapacity:knownCapacity(S)}],v105to110:S.v105to110?copy(S.v105to110):undefined,v111to116:S.v111to116?copy(S.v111to116):undefined});
 function validate(s,timeline={season:s.season,week:week(s)},archived=false){
  if(s.nativeStrategyOffices!==undefined){const a=s.nativeStrategyOffices;requireThat(a&&a.version===1&&a.clubs&&typeof a.clubs==='object'&&!Array.isArray(a.clubs)&&Object.keys(a).length===2&&Object.keys(a.clubs).length<=s.clubs.length,'Archives des bureaux invalides.');for(const [key,office] of Object.entries(a.clubs)){requireThat(/^(0|[1-9]\d*)$/.test(key)&&Number(key)<s.clubs.length&&office&&typeof office==='object'&&!Array.isArray(office)&&Object.keys(office).every(k=>['v105to110','v111to116','nativeBoardCalendar'].includes(k)),'Bureau archivé invalide.');validate({season:s.season,club:Number(key),clubs:s.clubs,franceMode:s.franceMode,worldMode:s.worldMode,commonDatabase:s.commonDatabase,economy:s.economy,...office},timeline,true);}}
  if(s.nativeBoardReports!==undefined){requireThat(Array.isArray(s.nativeBoardReports)&&s.nativeBoardReports.length<=15,'Archives des objectifs invalides.');const keys=new Set();for(const r of s.nativeBoardReports){const key=r.season+':'+r.clubId;requireThat(r&&isInt(r.season,1,s.season)&&isInt(r.clubId,0,s.clubs.length-1)&&!keys.has(key)&&Array.isArray(r.objectives)&&r.objectives.length<=8,'Bilan des objectifs invalide.');keys.add(key);validate({season:s.season,club:r.clubId,clubs:s.clubs,franceMode:s.franceMode,worldMode:s.worldMode,commonDatabase:s.commonDatabase,economy:s.economy,nativeBoardCalendar:{version:1,clubId:'club-'+r.clubId,season:r.season,week:0,trust:60,objectives:r.objectives,meetings:[],history:[]}},timeline,true);}}
  if(s.v105to110!==undefined){const st=s.v105to110;requireThat(CDSportingDirectorV105V110.valid(st)&&st.season<=s.season,'Direction sportive invalide.');
   requireThat(new Set(st.projects.map(p=>p.kind)).size===st.projects.length&&st.projects.every(p=>isInt(p.started,1,s.season)),'Projets de direction incohérents.');
   for(const list of [st.missions,st.risks])requireThat(list.every(x=>isInt(x.season,1,s.season)),'Échéance de direction invalide.');
   requireThat(st.history.every(h=>isInt(h.season,1,s.season)&&isInt(h.score,0,100)&&isInt(h.confidence,0,100))&&new Set(st.history.map(h=>h.season)).size===st.history.length,'Bilans de direction invalides.');
  }
  if(s.v111to116!==undefined){const st=s.v111to116;requireThat(CDFanExperienceV111V116.valid(st)&&st.season<=s.season,'Politique supporters invalide.');
   requireThat(new Set(st.ledger.map(x=>x.round)).size===st.ledger.length&&new Set(st.community.map(x=>x.kind)).size===st.community.length,'Événements supporters en double.');
   requireThat([st.campaign,st.service,...st.community].filter(Boolean).every(x=>isInt(x.season,1,s.season)),'Saison supporters invalide.');
   requireThat(st.history.every(h=>isInt(h.season,1,s.season))&&new Set(st.history.map(h=>h.season)).size===st.history.length,'Archives supporters invalides.');
  }
  if(s.nativeBoardCalendar!==undefined){const b=s.nativeBoardCalendar;CDBoardCalendar.audit(b);
   requireThat(b.clubId==='club-'+s.club&&isInt(b.season,1,s.season)&&(archived||b.season===s.season)&&isInt(b.week,0,b.season===timeline.season?timeline.week:weeks(s))&&b.objectives.length<=8&&b.meetings.length<=40&&b.history.length<=40,'Calendrier de direction invalide.');
   const ids=new Set();for(const o of b.objectives){requireThat(o&&typeof o.id==='string'&&o.id.length<=100&&!ids.has(o.id)&&['wins','points','rank','cash'].includes(o.type)&&Number.isFinite(o.target)&&o.target>=0&&o.target<=1e9&&isInt(o.deadline,1,weeks(s))&&Number.isFinite(o.weight)&&o.weight>0&&o.weight<=3&&['pending','unverified','met','missed'].includes(o.status),'Objectif de direction invalide.');ids.add(o.id);}
   requireThat(b.history.every((h,i,a)=>isInt(h.week,i?a[i-1].week:0,b.week)&&isInt(h.trust,0,100))&&b.meetings.every((m,i,a)=>isInt(m.week,i?a[i-1].week:0,b.week)&&Array.isArray(m.events)&&m.events.length<=8&&m.events.every(e=>e&&e.week===m.week)),'Réunions de direction invalides.');
  }
  return true;
 }
 function metrics(){const table=typeof CDFranceCompetition!=='undefined'&&CDFranceCompetition.active(S)?CDFranceCompetition.ranked(S,CDFranceCompetition.leagueId(S)):ranked();return {wins:own(S).won,points:own(S).points,rank:table.findIndex(c=>c.id===S.club)+1,cash:own(S).cash};}
 // Leviers de redressement, purement consultatifs : lus sur la prévision de l'écran Finances, rien n'est débité.
 // Au budget de saison, la prévision ne compte ni le sponsor, ni la formation payée, ni l'entretien à venir :
 // ils y sont ajoutés, et la cible est de ne pas dépasser ce que le propriétaire comble. Sinon, la caisse.
 // Hors budget de saison, la caisse prévue omet la billetterie : les leviers y ajoutent la recette moyenne
 // (300 000 à 450 000 € tirés à chaque réception) des réceptions restantes, primes de victoire exclues.
 const HOME_GATE=375000;
 const homeLeft=()=>world(S)?S.worldMode.fixtures.filter(x=>x.homeId===S.club&&!x.neutral&&x.week>=S.worldMode.week).length:0;
 function withLevers(f,partner,academy,upkeep,wage){
  // Lecture de la prévision : marge courante (hors guichet, primes et soutien) et reste de la prévision, de sorte que
  // trésorerie + marge courante + autres apports = trésorerie prévue. Une seule définition pour tous les écrans.
  f.projection={cash:f.cash,weeklyMargin:f.weeklyIncome-f.weeklyCosts,remainingWeeks:f.remainingWeeks,
   marginTotal:(f.weeklyIncome-f.weeklyCosts)*f.remainingWeeks,
   otherInflows:f.baseForecast-f.cash-(f.weeklyIncome-f.weeklyCosts)*f.remainingWeeks,forecast:f.baseForecast};
  if(typeof nativeClubBudget==='undefined'||typeof nativeClubBudget.leviers!=='function')return f;
  const reste=f.remainingWeeks,q=f.facility,devis=q&&!q.used&&q.affordable!==false?q.cost:null,b=f.budget;
  const common={reste,formationHebdo:academy,devis,masseHebdo:wage};
  f.levers=b?nativeClubBudget.leviers({...common,objectif:'proprietaire',solde:b.resultatPrevu+(partner-academy-upkeep)*reste+(b.proprietaire?.enveloppe||0),
   coutSalaire:52/b.semainesDePaie*(1+nativeClubBudget.COTISATIONS),amende:b.amendePrevue||0,depassement:Math.max(0,-(b.margePlafond??0),-(b.margeRecettes??0))})
   :nativeClubBudget.leviers({...common,objectif:'tresorerie',solde:f.baseForecast+HOME_GATE*homeLeft()});
  return f;
 }
 function projectBase(){
  if(!S)return null;const s=previewState(),b=CDSportingDirectorV105V110.ensure(s),f=CDFanExperienceV111V116.ensure(s),quote=worldActive()?worldFacilityQuote(S.club):null;
  // Humeur unique des supporters (profil des tribunes) : elle règle la demande, donc l'affluence prévue.
  let t=null;try{t=tribunes(s,f);}catch(e){t=null;}
  const fc=CDFanExperienceV111V116.forecast(s,t?t.mood:null),crowd=Math.max(1,fc.expectedAttendance||0,f.subscribers||0);
  // Billetterie réelle du prochain match à domicile (club-budget.cjs, budgetBilletterieVue) : la recette affichée est celle que
  // le match encaissera (billets au guichet × prix), le prix celui de la division et de la politique choisie.
  let bv=null;try{bv=typeof budgetBilletterieVue==='function'?budgetBilletterieVue():null;}catch(e){bv=null;}
  const tribunesVue=t?{segments:t.segments.map(g=>({...g,count:Math.round(crowd*g.share/100)})),expectations:t.expectations,mood:t.mood,crowd}:null;
  const budget=careerIntegrated()?S.careerManagement:null,remaining=Math.max(0,weeks(S)-week(S)),wage=own(S).players.reduce((n,p)=>n+p.salary,0),sponsor=budget?.sponsor?.season===S.season?CAREER_SPONSORS[budget.sponsor.key]:null;
  const weeklyIncome=160000+(sponsor?.weekly||0),weeklyCosts=wage+(budget?.academyInvestment||0)+(worldActive()?worldUpkeep(worldClub(S.club).facilities):0);
  return {context:context(),available:!S.live&&S.phase!=='ended',finance:withLevers({cash:own(S).cash,weeklyWages:wage,weeksPerSeason:weeks(S),remainingWeeks:remaining,academyInvestment:budget?.academyInvestment||0,academySpent:budget?.academySpent||0,weeklyIncome,weeklyCosts,baseForecast:own(S).cash+(weeklyIncome-weeklyCosts)*remaining,notice:'Projection des engagements connus, hors billetterie aléatoire, primes et transferts futurs. Montants de jeu fictifs.',...(typeof budgetFinance==='function'&&budgetFinance(budget?.academyInvestment||0,sponsor?.weekly||0,worldActive()?worldUpkeep(worldClub(S.club).facilities):0)||{}),investissements:typeof investResume==='function'?investResume():null,facility:quote?{...quote,level:worldClub(S.club).facilities,used:S.worldManagement.upgrades.some(x=>x.season===S.season&&x.id===S.club)}:null,boardHistory:copy(budget?.boardHistory||[])},sponsor?.weekly||0,budget?.academyInvestment||0,worldActive()?worldUpkeep(worldClub(S.club).facilities):0,wage),sponsors:Object.entries(CAREER_SPONSORS).map(([id,t])=>({id,...t,selected:budget?.sponsor?.key===id,available:!S.live&&S.phase==='league'&&S.round<=4&&!budget?.sponsor})),board:{priority:b.priority,organizationScore:b.confidence,missions:copy(b.missions),projects:copy(b.projects),risks:copy(b.risks),history:copy(b.history),readiness:CDSportingDirectorV105V110.readiness(s),projectOptions:Object.entries(projects).map(([id,c])=>({id,...c,used:b.projects.some(p=>p.kind===id)})),objectives:S.nativeBoardCalendar?copy(S.nativeBoardCalendar.objectives):[],metrics:metrics(),notice:'Le score d’organisation suit les projets et missions. Seul le bilan moteur modifie la confiance du président ; ces projets ne donnent pas de bonus de match.'},fans:{...fc,...(bv?{capacity:bv.capacity,price:bv.price,demand:bv.demand,expectedAttendance:bv.expectedAttendance,expectedTicketRevenue:bv.expectedTicketRevenue,payingSpectators:bv.payants}:{}),humeur:t?t.mood:null,humeurPublic:Math.round(100*(facteurHumeur(t?t.mood:null)-1)),...(tribunesVue?{supporters:tribunesVue}:{}),subscribers:f.subscribers,policy:f.price,prices:Object.entries(prices).map(([id,price])=>({id,price:bv?.prices?.[id]??price})),campaigns:Object.entries(campaigns).map(([id,c])=>({id,...c,used:!!f.campaign})),community:Object.entries(community).map(([id,c])=>({id,...c,used:f.community.some(e=>e.kind===id)||f.community.length>=2})),services:Object.entries(services).map(([id,c])=>({id,...c,used:!!f.service})),history:copy(f.history),notice:bv?'Recette du prochain match à domicile : billets au guichet × prix du billet.':'Prévisions fictives : aucune recette de billetterie supplémentaire encaissée. Les matchs conservent leur recette moteur unique.'}};
 }
 function receipt(label,before){const delta=own(S).cash-before;if(delta){S.ledger.unshift({title:label,amount:delta});S.ledger=S.ledger.slice(0,100);}}
 function execute(command,p){
  if(world(S)&&own(S).stadiumCapacity===undefined&&knownCapacity(S)!==undefined)own(S).stadiumCapacity=knownCapacity(S);
  requireThat(p&&p.context&&p.context.season===S.season&&p.context.week===week(S)&&p.context.club===S.club,'Cette décision est périmée : actualise le carnet.');
  requireThat(!S.live&&S.phase!=='ended','Décision indisponible pendant le match ou en fin de saison.');
  const save=()=>true,before=own(S).cash;let ok=false,label='Décision du club';
  if(command==='club_academy_investment'){requireThat(p.confirmed===true,'Confirme l’engagement hebdomadaire.');if(!careerIntegrated())requireThat(careerEnable(),'Gestion intégrée indisponible.');ok=careerSetAcademyInvestment(p.amount);}
  else if(command==='club_facility_upgrade'){requireThat(p.confirmed===true,'Confirme le coût des installations.');if(!worldActive())requireThat(worldEnable(),'Installations indisponibles.');const q=worldFacilityQuote(S.club);requireThat(q&&p.cost===q.cost&&p.level===worldClub(S.club).facilities,'Le devis des installations a changé.');ok=worldUpgradeFacility();}
  else if(command==='club_sponsor_sign'){requireThat(p.confirmed===true,'Confirme les conditions du sponsor.');if(!careerIntegrated())requireThat(careerEnable(),'Gestion intégrée indisponible.');ok=careerSponsorPick(p.key);}
  else if(command==='club_board_priority')ok=CDSportingDirectorV105V110.priority(S,p.key,save);
  else if(command==='club_board_assignment')ok=CDSportingDirectorV105V110.delegate(S,p.department,p.mission,save);
  else if(command==='club_board_project'){requireThat(p.confirmed===true,'Confirme le coût du projet.');ok=CDSportingDirectorV105V110.invest(S,p.kind,save);label='Projet : '+(projects[p.kind]?.label||'');if(ok)receipt(label,before);}
  else if(command==='club_board_mitigation'){requireThat(p.confirmed===true,'Confirme la mesure de prévention.');ok=CDSportingDirectorV105V110.mitigate(S,p.kind,p.action,save);if(ok)receipt('Prévention : '+p.kind,before);}
  else if(command==='club_board_objective'){requireThat(['wins','points','rank','cash'].includes(p.type)&&isInt(p.deadline,week(S)+1,weeks(S))&&Number.isFinite(p.target)&&p.target>=0&&p.target<=1e9,'Objectif invalide.');let b=S.nativeBoardCalendar;if(!b)b=CDBoardCalendar.create('club-'+S.club,S.season);requireThat(b.season===S.season&&b.objectives.length<8,'Feuille de route complète.');S.nativeBoardCalendar=CDBoardCalendar.objective(b,{id:'goal:'+S.season+':'+S.club+':'+p.type,type:p.type,target:p.target,deadline:p.deadline,weight:1});ok=true;}
  else if(command==='club_fans_price')ok=CDFanExperienceV111V116.setPrice(S,p.key,save);
  else if(['club_fans_campaign','club_fans_community','club_fans_service'].includes(command)){requireThat(p.confirmed===true,'Confirme le coût de cette action.');const kind=command.slice('club_fans_'.length);ok=CDFanExperienceV111V116[kind](S,p.key,save);if(ok)receipt('Supporters : '+({campaign:campaigns,community,service:services}[kind][p.key]?.label||p.key),before);}
  requireThat(ok,'Décision refusée : vérifie la phase, les fonds et les actions déjà engagées.');return {clubDecision:{command,cashChange:own(S).cash-before}};
 }
 // Objectif de classement du président pour le club géré, à chaque saison, avec ou sans défi de départ : la phrase
 // d'objectif du club (« Top 6 ») si elle en donne un, sinon le rang de son effectif dans son championnat (les mieux
 // dotés visent un cran au-dessus, les autres le maintien : jamais au-delà de la dernière place sûre). Un jalon de
 // classement déjà fixé (défi, manager) n'est pas remplacé. Échéance : fin de la saison régulière.
 function presidentObjective(){
  const s=typeof S==='undefined'?null:S;if(!s||typeof CDWorldCareer==='undefined'||!CDWorldCareer.active(s)||s.phase==='ended'||s.live)return false;
  const lid=CDWorldCareer.leagueId(s),members=s.worldMode?.leagues?.[lid]?.members;if(!Array.isArray(members)||members.length<4||!members.includes(s.club))return false;
  let b=s.nativeBoardCalendar;if(!b||b.season!==s.season)b=CDBoardCalendar.create('club-'+s.club,s.season);
  if(b.objectives.some(o=>o.type==='rank')){s.nativeBoardCalendar=b;return false;}
  const fin=CDWorldCareer.sizing(s).maxRound;if(!(fin>b.week))return false;
  const n=members.length,safe={elite:12,accession:14,nationale:13}[lid]??n-2,force=cid=>{const r=(s.clubs[cid]?.players||[]).map(p=>p.rating).sort((x,y)=>y-x).slice(0,23);return r.length?r.reduce((x,y)=>x+y,0)/r.length:0;};
  const order=members.slice().sort((x,y)=>force(y)-force(x)||x-y),rank=order.indexOf(s.club)+1,top=/Top (\d+)/.exec(String(s.clubs[s.club]?.goal||''));
  const target=Math.max(1,Math.min(top?+top[1]:rank<=Math.ceil(n/3)?rank-1:rank,Math.min(safe,n-1)));
  s.nativeBoardCalendar=CDBoardCalendar.objective(b,{id:'pres:'+s.season+':'+s.club+':rank',type:'rank',target,deadline:fin,weight:2});return true;
 }
 // Supporters (revue FM27, idée n° 15, option B choisie par Léo le 23/11/2026) : profil des tribunes et HUMEUR UNIQUE
 // des supporters (l'ancien « sentiment » sauvegardé est supprimé, fan-experience-v111-v116.js).
 // Groupes : part de la foule tirée des abonnés, du prix, de la campagne, de l'accueil et des actions de proximité, sur
 // l'affluence de base (humeur neutre) pour ne pas tourner en rond. Attentes : une par groupe (importance 1-4 selon la
 // part), réaction sur 100 lue dans les résultats, le classement visé, le prix, la formation et les actions de la
 // saison ; null tant qu'il n'y a pas de quoi juger (« En attente »). Humeur = moyenne des réactions pondérée par
 // l'importance. Effets réels : affluence des matchs à domicile et billetterie (club-budget.cjs, facteurHumeur),
 // demande prévue (forecast) et bilan du conseil (career-integration.js, poids 10 %).
 const facteurHumeur=h=>typeof nativeClubBudget!=='undefined'&&typeof nativeClubBudget.facteurHumeur==='function'?nativeClubBudget.facteurHumeur(h):1;
 function tribunes(s,f){
  if(!f)return null;
  const c=own(S),st=f,cur=x=>x&&x.season===S.season,camp=cur(st.campaign)?st.campaign.kind:null,serv=cur(st.service)?st.service.kind:null;
  const comm=(st.community||[]).filter(cur).map(x=>x.kind),price=f.price,base=CDFanExperienceV111V116.forecast(s),crowd=Math.max(1,base.expectedAttendance||0,f.subscribers||0);
  const raw={abonnes:Math.max(12,Math.min(45,Math.round(100*(f.subscribers||0)/crowd))),familles:14+(camp==='familiale'?10:0)+(price==='accessible'?6:price==='premium'?-6:0)+(comm.includes('ecoles')?4:0),
   amateurs:9+(camp==='locale'?7:0)+(comm.includes('associations')?4:0)+(comm.includes('portesOuvertes')?3:0),connectes:8+(camp==='numerique'?9:0),partenaires:4+(serv==='premium'?6:serv==='confort'?3:0)+(price==='premium'?3:0)};
  const used=Object.values(raw).reduce((n,x)=>n+x,0);raw.occasionnels=Math.max(6,100-used);
  const total=Object.values(raw).reduce((n,x)=>n+x,0),ids=Object.keys(raw),share={};let left=100;
  ids.forEach((id,i)=>{share[id]=i===ids.length-1?left:Math.round(100*raw[id]/total);left-=share[id];});
  const labels={abonnes:'Abonnés fidèles',familles:'Familles',amateurs:'Clubs amateurs et écoles de rugby',connectes:'Jeunes connectés',partenaires:'Partenaires et loges',occasionnels:'Occasionnels'};
  const segments=ids.map(id=>({id,label:labels[id],share:share[id]})).sort((a,b)=>b.share-a.share);
  const m=metrics(),played=(c.won||0)+(c.drawn||0)+(c.lost||0),rankGoal=(S.nativeBoardCalendar?.objectives||[]).find(o=>o.type==='rank'),promotions=S.careerManagement?.promotions;
  const clamp=(x)=>Math.max(0,Math.min(100,Math.round(x)));
  const reactions={abonnes:played<3?null:clamp(50+((c.won||0)-(c.lost||0))*6),
   occasionnels:!rankGoal||played<3||!(m.rank>0)?null:m.rank<=rankGoal.target-2?90:m.rank<=rankGoal.target?75:m.rank<=rankGoal.target+2?50:30,
   familles:price==='accessible'?90:price==='premium'?35:65,amateurs:clamp(45+20*comm.length+(camp==='locale'?15:0)),
   connectes:camp==='numerique'?85:null,partenaires:serv==='premium'?88:serv==='confort'?72:45};
  const wishes={abonnes:['Gagner à domicile','resultats'],occasionnels:[rankGoal?'Classement ≤ '+rankGoal.target:'Viser le haut du tableau','classement'],familles:['Des billets abordables','prix'],
   amateurs:['Un club proche de sa ville','proximite'],connectes:['Le club sur les réseaux','image'],partenaires:['Un accueil de qualité','accueil']};
  if(typeof promotions==='number'){wishes.amateurs=['Des jeunes du centre en équipe première','formation'];reactions.amateurs=promotions>0?clamp(50+promotions*20):null;}
  const expectations=segments.map(g=>({id:g.id,label:wishes[g.id][0],kind:wishes[g.id][1],segment:g.id,importance:Math.max(g.share>=25?4:g.share>=15?3:g.share>=9?2:1,{resultats:3,classement:3}[wishes[g.id][1]]||1),reaction:reactions[g.id]}));
  const known=expectations.filter(e=>e.reaction!==null),mood=known.length?Math.round(known.reduce((n,e)=>n+e.reaction*e.importance,0)/known.reduce((n,e)=>n+e.importance,0)):null;
  return {segments,expectations,mood};
 }
 // Humeur des supporters du club géré (0-100, null sans carrière) : lue par le moteur (affluence, billetterie, conseil).
 function humeur(){
  try{if(!S||!S.clubs?.[S.club])return null;const s=previewState(),t=tribunes(s,CDFanExperienceV111V116.ensure(s));return t&&Number.isFinite(t.mood)?t.mood:null;}catch(e){return null;}
 }
 function boardPlan(board){
  const c=own(S),rankGoal=(board.objectives||[]).find(o=>o.type==='rank'),top=/Top (\d+)/.exec(String(c.goal||'')),plan=[];
  const now=(board.objectives||[]).map(o=>({label:o.type,target:o.target,deadline:o.deadline,importance:o.id&&o.id.startsWith('pres:')?4:2,status:o.status}));
  now.push({label:'cash',target:0,importance:3,status:c.cash>=0?'pending':'missed'});
  plan.push({season:S.season,current:true,objectives:now});
  const start=rankGoal?rankGoal.target:null,end=start===null?null:Math.max(1,Math.min(start,top?+top[1]:Math.max(1,start-3)));
  for(let k=1;k<=4;k++){const list=[];
   if(start!==null)list.push({label:'rank',target:Math.round(start+(end-start)*k/4),importance:4,status:'future'});
   list.push({label:'cash',target:0,importance:3,status:'future'});
   list.push({label:'youth',target:1,importance:k>=2?3:2,status:'future'});
   plan.push({season:S.season+k,current:false,objectives:list});}
  return plan;
 }
 function project(){
  const out=projectBase();if(!out)return out;
  try{out.board.plan=boardPlan(out.board);}catch(e){}
  return out;
 }
 let installed=false;
 function installHooks(){if(installed)return;installed=true;
  const previousMobility=managerMobilityOnSeasonStart;managerMobilityOnSeasonStart=function(){const fields=['v105to110','v111to116','nativeBoardCalendar'],oldClub=S?.club,office={};if(S)for(const key of fields)if(S[key]!==undefined)office[key]=copy(S[key]);const result=previousMobility.apply(this,arguments);if(S&&S.club!==oldClub){if(!S.nativeStrategyOffices)S.nativeStrategyOffices={version:1,clubs:{}};S.nativeStrategyOffices.clubs[oldClub]=office;const restored=S.nativeStrategyOffices.clubs[S.club]||{};for(const key of fields){delete S[key];if(restored[key]!==undefined)S[key]=copy(restored[key]);}if(S.v105to110)CDSportingDirectorV105V110.rotate(S);if(S.v111to116)CDFanExperienceV111V116.rotate(S,()=>true);if(S.nativeBoardCalendar&&S.nativeBoardCalendar.season!==S.season)S.nativeBoardCalendar=CDBoardCalendar.create('club-'+S.club,S.season);}return result;};
  const previousFinish=finishRound;finishRound=function(){const oldSeason=S?.season,oldWeek=S?week(S):null,result=previousFinish.apply(this,arguments);if(S&&S.season===oldSeason&&week(S)!==oldWeek&&S.nativeBoardCalendar){const r=CDBoardCalendar.review(S.nativeBoardCalendar,{week:week(S),metrics:metrics()});S.nativeBoardCalendar=r.state;S.nativeBoardCalendar.meetings=S.nativeBoardCalendar.meetings.slice(-40);S.nativeBoardCalendar.history=S.nativeBoardCalendar.history.slice(-40);}if(S?.phase==='ended'){if(S.v105to110&&!S.v105to110.history.some(h=>h.season===S.season))CDSportingDirectorV105V110.closeSeason(S,()=>true);if(S.v111to116&&!S.v111to116.history.some(h=>h.season===S.season))CDFanExperienceV111V116.closeSeason(S,()=>true,humeur());}return result;};
  const previousAdvance=advanceSeason;advanceSeason=function(){const oldSeason=S?.season;if(S?.phase==='ended'&&!S.live&&S.nativeBoardCalendar&&!S.nativeBoardReports?.some(r=>r.season===S.season&&r.clubId===S.club))S.nativeBoardReports=[...(S.nativeBoardReports||[]),{season:S.season,clubId:S.club,objectives:copy(S.nativeBoardCalendar.objectives)}].slice(-15);const result=previousAdvance.apply(this,arguments);if(S&&S.season!==oldSeason){if(S.v105to110)CDSportingDirectorV105V110.rotate(S);if(S.v111to116)CDFanExperienceV111V116.rotate(S,()=>true);if(S.nativeBoardCalendar)S.nativeBoardCalendar=CDBoardCalendar.create('club-'+S.club,S.season);presidentObjective();}return result;};
 }
 return {project,validate,execute,installHooks,presidentObjective,humeur};
}
module.exports={files,commands,factory};
