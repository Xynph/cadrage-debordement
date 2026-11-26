'use strict';
// Match engine v2. All outcomes use the same engine for user and AI fixtures.
const ATTR={scrum:'Mêlée',lineout:'Touche',tackle:'Plaquage',speed:'Vitesse',pass:'Passe',kick:'Jeu au pied',goal:'But',mental:'Mental',discipline:'Discipline',stamina:'Endurance',power:'Puissance'};
const PROFILES=[
 [18,-8,3,-26,-15,-30,-34,0,0,-5,16], [12,17,5,-16,-6,-27,-30,0,0,0,10],
 [10,20,7,-15,-12,-30,-34,1,0,2,13], [3,5,15,0,-4,-23,-27,4,1,13,9],
 [-30,-25,-3,9,19,12,2,11,7,9,-20],[-32,-25,-6,4,18,20,18,14,6,5,-19],
 [-30,-24,-5,22,1,-2,-12,2,1,9,0],[-19,-19,9,11,10,-9,-17,6,2,8,12],
 [-29,-20,2,15,9,16,10,12,6,7,-7]
];
const ROLE_WEIGHTS=[{scrum:5,power:3,tackle:1,discipline:1},{lineout:4,scrum:3,tackle:2,pass:1},{lineout:4,power:2,tackle:3,scrum:1},{tackle:4,stamina:2,power:2,pass:1,speed:1},{pass:4,kick:2,mental:2,speed:2},{pass:3,kick:3,mental:2,goal:2},{speed:5,pass:2,power:2,mental:1},{tackle:3,pass:3,power:2,speed:2},{kick:3,speed:3,mental:2,tackle:2}];
const BENCH_LABELS=['Talonneur','Pilier gauche','Pilier droit','Deuxième ligne','Troisième ligne','Demi de mêlée','Charnière / arrière','Trois-quarts'];
const BENCH_ROLES=[1,0,0,2,3,4,5,6];
const COVER_WEEKLY_SALARY=2500;
function seedHash(text){let h=2166136261;for(const ch of String(text)){h^=ch.charCodeAt(0);h=Math.imul(h,16777619)}return h>>>0}
function ensureSkills(p){if(p.skills)return p;let seed=seedHash(p.id||p.name),prof=PROFILES[p.fam]||PROFILES[7];p.skillBase=p.rating;p.skills={};Object.keys(ATTR).forEach((k,i)=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;p.skills[k]=clamp(p.rating+prof[i]+(seed%19)-9,20,97)});return p}
// `fit` : false = compétence nue ; true = avec la fatigue (jeu courant : ×0,5 à condition 0) ; 'arrete' (rencontres
// avec `setPieceFatigueVersion`, voir fitArrete) = la perte due à la fatigue est pondérée par FATIGUE_ARRETE[k] pour les
// gestes de phase arrêtée (but, lancer en touche) ; les autres compétences gardent la fatigue du jeu courant.
function skill(p,k,fit=false){if(!p)return 25;ensureSkills(p);let n=clamp(p.skills[k]+p.rating-p.skillBase+focusedBonus(p,k)+(typeof pilotageSkillMod==='function'?pilotageSkillMod(p,k):0),15,99);if(!fit)return n;const perte=.5-p.condition*.005,w=fit==='arrete'?FATIGUE_ARRETE[k]:undefined;return n*(1-(w===undefined?1:w)*perte)}
// Termes de chaque grille de poids lus une fois (mêmes paires, même ordre d'addition qu'Object.entries à chaque appel) ;
// skill(p,k) y est déroulé à l'identique (qualités créées au besoin, bonus de spécialisation, bornes 15-99).
const ROLE_WEIGHT_TERMS=new WeakMap();
function roleNote(p,f=p?.fam){if(!p)return 0;const w=ROLE_WEIGHTS[f]||ROLE_WEIGHTS[7];let t=ROLE_WEIGHT_TERMS.get(w);if(!t){t={entries:Object.entries(w),total:Object.values(w).reduce((s,v)=>s+v,0)};ROLE_WEIGHT_TERMS.set(w,t);}ensureSkills(p);const sk=p.skills,rating=p.rating,base=p.skillBase,spec=p.dev?.specialization?.version===1?p.dev.specialization.bonuses:null;let s=0;for(const [k,v] of t.entries)s=s+Math.max(15,Math.min(99,sk[k]+rating-base+(spec?(spec[k]||0):0)))*v;return Math.round(s/t.total)}
// Poste naturel (famille du joueur ; piliers à leur côté). Le moteur natif élargit slotEligible aux dépannages,
// mais le vivier des joueurs libres se compte au poste naturel.
function naturalSlot(p,i){if(!p)return false;if(i===0||i===2)return p.pos===POS[i];return p.fam===FAMILIES[i]}
function slotEligible(p,i){return naturalSlot(p,i)}
function benchEligible(p,i){if(!p)return false;if(i===0)return p.fam===1;if(i===1)return p.pos===POS[0];if(i===2)return p.pos===POS[2];if(i===3)return p.fam===2;if(i===4)return p.fam===3;if(i===5)return p.fam===4;if(i===6)return p.fam>=4;return p.fam>=6}
function fitScore(p,f=p.fam){return roleNote(p,f)*(.5+p.condition*.005)}
function buildSheet(c,preferred=[],preferredBench=[]){const used=new Set(),scores=new Map(),judges=typeof staffSheetJudges==='function'?staffSheetJudges(c):null,fit=judges?(p,f)=>perceivedFit(judges,p,f):fitScore;const sheetFit=(p,f=p.fam)=>{let byFamily=scores.get(p);if(!byFamily){byFamily=new Map();scores.set(p,byFamily);}if(!byFamily.has(f))byFamily.set(f,fit(p,f));return byFamily.get(f);};const lineup=FAMILIES.map((f,i)=>{let p=c.players.find(p=>p.id===preferred[i]&&!p.injury&&!used.has(p.id)&&slotEligible(p,i));if(!p)p=c.players.filter(p=>!p.injury&&!used.has(p.id)&&slotEligible(p,i)).sort((a,b)=>sheetFit(b,f)-sheetFit(a,f))[0];if(p)used.add(p.id);return p?.id||null});const bench=BENCH_LABELS.map((_,i)=>{let p=c.players.find(p=>p.id===preferredBench[i]&&!p.injury&&!used.has(p.id)&&benchEligible(p,i));if(!p)p=c.players.filter(p=>!p.injury&&!used.has(p.id)&&benchEligible(p,i)).sort((a,b)=>sheetFit(b)-sheetFit(a))[0];if(p)used.add(p.id);return p?.id||null});return{lineup,bench}}
function repairSheet(){const s=buildSheet(club(),S.lineup,S.reserves);S.lineup=s.lineup;S.reserves=s.bench}
function vacantMatchSlots(lineup,bench){return [...lineup,...bench].flatMap((id,i)=>id?[]:[i+1]);}
function sheetErrors(){let ids=[...S.lineup,...S.reserves];let errors=[];if(ids.filter(Boolean).length!==23)errors.push('Choisis 15 titulaires et 8 remplaçants.');if(new Set(ids.filter(Boolean)).size!==ids.filter(Boolean).length)errors.push('Un joueur apparaît plusieurs fois.');S.lineup.forEach((id,i)=>{let p=player(id);if(!p||p.injury||!slotEligible(p,i))errors.push(`Poste ${i+1} à compléter.`)});S.reserves.forEach((id,i)=>{let p=player(id);if(!p||p.injury||!benchEligible(p,i))errors.push(`Remplaçant ${i+16} à compléter.`)});return errors}
function migrateGame(){if(!S)return;const old=S.version===1;if(old){try{if(!gameStorage.getItem('bdt-backup-v1'))gameStorage.setItem('bdt-backup-v1',JSON.stringify(S))}catch(e){}}
S.clubs.forEach(c=>c.players.forEach(ensureSkills));S.market.forEach(ensureSkills);S.reserves=S.reserves||[];S.lastReport=S.lastReport||null;S.version=2;if(S.physicalLoadVersion===undefined)S.physicalLoadVersion=1;if(S.collectivePrepVersion===undefined){S.collectivePrepVersion=1;S.collectiveFocus='aucune'}if(S.developmentFocusVersion===undefined)S.developmentFocusVersion=1;if(S.recruitmentIntelVersion===undefined)S.recruitmentIntelVersion=1;setupEconomy(true);
if(S.live&&!S.live.engine){let prev=S.live,l=createRugbyMatch(prev.pair,prev);S.live=l;S.lineup=[...l.sheets[l.userSide].on];S.reserves=[...l.sheets[l.userSide].bench];news('Ta rencontre en cours a été reprise avec le nouveau moteur, score et minute conservés.')}else if(!S.live)repairSheet();
if(old)news('Nouvelle version : attributs des joueurs, feuille à 23 et moteur de match enrichi. Ta carrière est conservée.');setupDevelopment(true);setupOpposition();setupManager();save()}
function chooseSheet(i,id,bench=false){if(S.live)return;const list=bench?S.reserves:S.lineup,p=player(id);if(id&&(!p||p.injury||!(bench?benchEligible(p,i):slotEligible(p,i))))return;const all=[...S.lineup,...S.reserves],current=(bench?15:0)+i;if(id&&all.some((x,j)=>x===id&&j!==current)){toast('Ce joueur figure déjà sur la feuille.');return}list[i]=id||null;save();render()}
function promoteCover(){if(S.live)return;repairSheet();if([...S.lineup,...S.reserves].filter(id=>!id).length>professionalPlaces())return false;let n=0;for(let i=0;i<23;i++){const isBench=i>=15,j=isBench?i-15:i,list=isBench?S.reserves:S.lineup;if(list[j])continue;let slot=isBench?[1,0,2,3,5,8,9,10][j]:j;let p=makePlayer(400+n,slot,56);p.id='academy-'+S.season+'-'+S.round+'-'+(S.playerSerial=(S.playerSerial||0)+1);delete p.skills;p.rating=rand(52,61);delete p.skills;p.age=19;p.condition=100;p.salary=COVER_WEEKLY_SALARY;ensureSkills(p);ensureContract(p);ensureDevelopment(p);club().players.push(p);list[j]=p.id;n++}if(n)news(`${n} espoir(s) promu(s) pour compléter la feuille de match.`);save();render();toast(n?`${n} espoir(s) rejoint le groupe.`:'Ta feuille de match est complète.')}
// Buteur : un joueur d'arrière (n° 10 à 15 : famille 5 et plus) ; le demi de mêlée seulement à défaut, un avant jamais s'il reste un autre joueur.
function buteursPossibles(players){const arrieres=players.filter(p=>p.fam>=5);if(arrieres.length)return arrieres;const demis=players.filter(p=>p.fam===4);return demis.length?demis:players}
function chooseScorer(c,ids,l=null){const fit=l?fitArrete(l):true;return buteursPossibles(ids.map(id=>c.players.find(p=>p.id===id)).filter(Boolean)).sort((a,b)=>skill(b,'goal',fit)-skill(a,'goal',fit))[0]}
// Index des effectifs (premier joueur de chaque identifiant, comme la recherche linéaire) : un match en relit l'effectif
// des milliers de fois. Il est repris tant que le tableau garde les mêmes joueurs, dans le même ordre et avec les mêmes
// identifiants (comparaison complète à chaque appel, sans allocation) ; sinon il est reconstruit. Résultats inchangés.
const SQUAD_INDEX=new WeakMap();
function squadIndex(players){const ix=SQUAD_INDEX.get(players);if(ix){const n=players.length;let same=ix.list.length===n;for(let i=0;same&&i<n;i++){const p=players[i];if(p!==ix.list[i]||p.id!==ix.ids[i])same=false}if(same)return ix.byId}const list=players.slice(),ids=list.map(p=>p.id),byId=new Map();for(const p of list)if(!byId.has(p.id))byId.set(p.id,p);SQUAD_INDEX.set(players,{list,ids,byId});return byId}
function matchPlayer(l,side,id){return squadIndex(S.clubs[l.pair[side]].players).get(id)}
function activePlayers(l,side){const s=l.sheets[side],byId=squadIndex(S.clubs[l.pair[side]].players);return s.on.map(id=>byId.get(id)).filter(p=>p&&!s.cards.some(c=>c.id===p.id&&c.until>l.minute))}
function unit(l,side,k,filter){let p=activePlayers(l,side);if(filter)p=p.filter(filter);const fit=fitArrete(l);return p.length?mean(p.map(p=>skill(p,k,fit))):25}
function addEvent(l,text,type='play',meta={}){const scene=captureMatchAction(l,type,meta);l.events.push({min:l.minute,text,type,...(flowRules(l)?{period:l.flow.period}:{}),...(scene?{scene}:{})});const playbackState=MATCH_PLAYBACK.get(l);if(playbackState&&!playbackState.running)playbackState.cursor=l.events.length-1}
// Scope: French professional substitutions and red-card replacement, edition 2025/26.
// Existing fixtures without this profile retain their original rules until completion.
const MATCH_RULES='fr-pro-2025';
function revisedRules(l){return l.rulesProfile===MATCH_RULES}
function initializeMatchRules(l){l.frontRowVersion=1;l.uncontestedScrums=[0,0];l.rulesProfile=MATCH_RULES;for(const sh of l.sheets){sh.nominated=[...sh.on,...sh.bench].filter(Boolean);sh.tacticalReturns=0;sh.redCards=[];sh.front={exclusions:[],held:[],uncontested:false,prepared:false}}}
function replacementRed(l,side,slot){return l.sheets[side].redCards?.find(c=>c.slot===slot&&!c.filled&&c.until!==null&&c.until<=l.minute)}
// Protocole commotion (native/engine/club-support.cjs, carrière Monde) : choc à la tête pendant le match (HIA1 avec
// remplacement temporaire, ou sortie définitive sur signes évidents), puis diagnostic après la rencontre.
function commotionProtocol(){return typeof nativeSystems!=='undefined'?nativeSystems.domain('clubSupport')?.commotion||null:null}
// Joueur en évaluation HIA ou sorti définitivement : il ne peut pas revenir par un changement.
function matchIncidents(){return typeof nativeSystems!=='undefined'?nativeSystems.domain('matchIncidents')||null:null}
function hiaBlocked(l,side,id){return !!l.hia&&l.hia.some(h=>h.side===side&&h.id===id&&(h.etat==='en_cours'||h.etat==='definitif'))||!!matchIncidents()?.blocked(l,side,id)}
function legalChange(l,side,slot,incoming){
 if(l.finished||!Number.isInteger(slot)||slot<0||slot>=15||![0,1].includes(side))return false;
 const sh=l.sheets[side],out=sh.on[slot],p=matchPlayer(l,side,incoming);
 if(!p||p.injury||hiaBlocked(l,side,incoming)||!slotEligible(p,slot)||!sh.bench.includes(incoming)||sh.on.includes(incoming)||sh.sentOff.includes(incoming)||sh.cards.some(c=>c.id===incoming&&c.until>l.minute)||sh.cards.some(c=>c.id===out&&c.until>l.minute))return false;
 if(!revisedRules(l))return !!out&&sh.subs<8&&!sh.used.includes(incoming);
 if(!sh.nominated.includes(incoming)||frontRowRules(l)&&frontLocked(l,side,incoming))return false;
 if(frontRowRules(l)&&slot<3&&sh.front.exclusions.some(e=>e.slot===slot&&!e.closed&&e.kind==='yellow'&&e.until>l.minute)&&out)return false;
 if(!out)return !!replacementRed(l,side,slot);
 return !sh.used.includes(incoming)||sh.tacticalReturns<4;
}
function eligibleChanges(l,side,slot){return l.sheets[side].bench.map(id=>matchPlayer(l,side,id)).filter(p=>p&&legalChange(l,side,slot,p.id))}
function revisedSub(l,side,slot,incoming){
 if(!legalChange(l,side,slot,incoming))return false;
 const sh=l.sheets[side],red=sh.on[slot]?null:replacementRed(l,side,slot),out=sh.on[slot]||red.id,returning=sh.used.includes(incoming),p=matchPlayer(l,side,incoming);
 sh.bench=sh.bench.filter(id=>id!==incoming);
 if(!red)sh.bench.push(out);else red.filled=true;
 sh.on[slot]=incoming;if(frontRowRules(l))sh.front.held=sh.front.held.filter(h=>h.id!==incoming);if(!returning)sh.used.push(incoming);
 if(returning&&!red)sh.tacticalReturns++;
 sh.subs++;l.subs.push({minute:l.minute,side,out,in:incoming,reason:red?'red20':'tactical',returning});
 addEvent(l,`${S.clubs[l.pair[side]].abbr} · ${p.name} ${returning?'revient en jeu et remplace':'remplace'} ${matchPlayer(l,side,out)?.name||'le joueur exclu'}${red?' après les 20 minutes d’exclusion collective':returning?' (retour tactique '+sh.tacticalReturns+'/4)':''}.`,'sub',{team:side,actor:incoming});
 return true;
}
function giveMatchCard(l,side,id,kind='yellow'){
 if(!revisedRules(l)||l.finished||!['yellow','red20','red'].includes(kind))return false;
 const sh=l.sheets[side],slot=sh.on.indexOf(id),p=matchPlayer(l,side,id);
 if(slot<0||slot<3&&!frontRowRules(l)||!p||sh.sentOff.includes(id)||sh.cards.some(c=>c.id===id&&c.until>l.minute))return false;
 if(kind==='yellow'){
  sh.yellowCounts[id]=(sh.yellowCounts[id]||0)+1;l.stats[side].yellows++;
  if(sh.yellowCounts[id]===1){sh.cards.push({id,until:l.minute+10});if(slot<3)registerFrontExclusion(l,side,id,slot,'yellow',l.minute+10);addEvent(l,`Carton jaune pour ${p.name} : exclusion de 10 minutes de jeu.`,'card',{team:side,actor:id,incident:true,card:'yellow'});return true}
  kind='red20';
 }
 sh.cards=sh.cards.filter(c=>c.id!==id);sh.on[slot]=null;sh.sentOff.push(id);
 const until=kind==='red20'?l.minute+20:null;
 sh.redCards.push({id,slot,until,filled:false});if(slot<3)registerFrontExclusion(l,side,id,slot,kind,until);
 addEvent(l,`${p.name} ${sh.yellowCounts[id]===2?'reçoit un second jaune':'reçoit un carton rouge'} : sortie définitive du joueur. ${until===null?'Aucun remplacement autorisé.':'Un autre joueur pourra entrer à partir de la '+until+'e minute.'}`,'card',{team:side,actor:id,incident:true,card:kind});
 return true;
}
function restoreRedReplacements(l,side){
 if(!revisedRules(l))return;
 if(frontRowRules(l))resolveFrontExpiries(l,side);
 const sh=l.sheets[side];
 for(const red of sh.redCards){if(frontRowRules(l)&&red.slot<3)continue;if(red.filled||red.until===null||red.until>l.minute)continue;
  if(!red.announced){red.announced=true;addEvent(l,`${S.clubs[l.pair[side]].abbr} peut remplacer ${matchPlayer(l,side,red.id)?.name||'le joueur exclu'} : les 20 minutes sont écoulées.`,'card')}
  /* Note au poste à pourvoir (et non au poste du remplaçant) : un talonneur ne remplace pas un ailier exclu quand un trois-quarts attend sur le banc. */if(side!==l.userSide){const f=FAMILIES[red.slot],p=eligibleChanges(l,side,red.slot).sort((a,b)=>fitScore(b,f)-fitScore(a,f))[0];if(p)makeSub(l,side,red.slot,p.id)}
 }
}
function revisedSubPanel(l){
 const side=l.userSide,sh=l.sheets[side];
 return `<div class="card"><div class="cardtitle"><h2>Ton banc</h2><span class="tag">${sh.tacticalReturns} / 4 RETOURS</span></div><p class="help">Cadre des changements : professionnel français 2025–2026. Huit joueurs de banc désignés ; quatre retours tactiques au maximum. Remplacer un exclu après 20 minutes ne consomme pas ce quota.</p><p class="help">${l.paused?'Choisis le sortant puis le remplaçant.':'Mets le match en pause pour préparer tes changements.'} ${sh.subs} changement(s) effectué(s).</p>${frontRowRules(l)?frontRowPanel(l,side):''}${sh.on.map((id,slot)=>{
  const frontCase=frontRowRules(l)?sh.front.exclusions.find(e=>e.slot===slot&&e.kind==='yellow'&&!e.closed&&e.until>l.minute):null;
  const p=matchPlayer(l,side,id),yellow=sh.cards.find(c=>(c.id===id||frontCase?.id===c.id)&&c.until>l.minute),red=sh.redCards.find(c=>c.slot===slot&&!c.filled),candidates=eligibleChanges(l,side,slot);
  const status=yellow?'Jaune · encore '+(yellow.until-l.minute)+' min':red?red.until===null?'Rouge · sans remplacement':red.until>l.minute?'Rouge · remplacement dans '+(red.until-l.minute)+' min':'Remplacement autorisé':p?Math.round(p.condition)+'%':'Poste vacant';
  return `<div class="livesub"><div><small class="muted">${slot+1} · ${POS[slot]}</small><strong>${p?.name||frontCase&&matchPlayer(l,side,frontCase.id)?.name||'Poste vacant'}</strong><small>${status}</small></div><select aria-label="Remplacer au poste ${slot+1}" ${!l.paused||!candidates.length?'disabled':''} onchange="if(this.value)substitute(${slot},this.value)"><option value="">${candidates.length?'Faire entrer…':'Indisponible'}</option>${candidates.map(p=>`<option value="${p.id}">${p.name} · ${Math.round(p.condition)}%${sh.used.includes(p.id)?' · retour':''}</option>`).join('')}</select></div>`
 }).join('')}<button class="small" onclick="rugbyUseBench()" ${!l.paused||l.finished?'disabled':''}>Confier les changements au staff</button></div>`;
}

// Entrées dans les 22 m adverses (revue FM27, idée n° 31, 23/11/2026) : après chaque action, le camp qui a le ballon
// dans les 22 m adverses (terrain 0-100 vu du camp 0 : 22 m adverses = 78 et plus pour le camp 0, 22 et moins pour le
// camp 1) compte une entrée, une seule tant que ce camp y reste avec le ballon. Sans tirage : le hasard du match ne bouge pas.
// Champ facultatif des statistiques (stats[i].entries22) : les matchs d'avant ne l'ont pas.
function compterEntree22(l){const side=l.possession;if((side!==0&&side!==1)||!l.stats?.[side])return;const dedans=side===0?l.territory>=78:l.territory<=22,avant=l.dans22;l.dans22=dedans?side:-1;if(dedans&&avant!==side)l.stats[side].entries22=(l.stats[side].entries22||0)+1}
// Jeunes de moins de 23 ans dans le XV de départ de chaque camp (stats[i].jeunes, champ facultatif comme entries22).
function jeunesTitulaires(l){try{l.pair.forEach((ci,s)=>{const club=S.clubs[ci],ids=new Set((l.sheets?.[s]?.initial||[]).filter(Boolean));if(!club||!ids.size)return;l.stats[s].jeunes=club.players.filter(p=>ids.has(p.id)&&Number.isFinite(p.age)&&p.age<=23).length})}catch(e){}}
function makeStats(){return{possession:0,territory:0,scrums:0,scrumsWon:0,lineouts:0,lineoutsWon:0,penalties:0,yellows:0,conversions:0,conversionAttempts:0,goalAttempts:0,goals:0}}
function createRugbyMatch(pair,legacy=null,automated=false,preparation=null){if(typeof CDFranceCompetition!=='undefined'&&CDFranceCompetition.active(S))for(const ci of pair)CDFranceCareer.ensureAISheet(S.clubs[ci]);const userSide=automated?-1:pair.indexOf(S.club);const sheets=pair.map((ci,s)=>{let c=S.clubs[ci],sel=ci===S.club?buildSheet(c,S.lineup,S.reserves):buildSheet(c);return{on:sel.lineup,bench:sel.bench,initial:[...sel.lineup],used:[...sel.lineup.filter(Boolean)],minutes:{},cards:[],yellowCounts:{},sentOff:[],subs:0}});
const l={engine:2,pair:[...pair],minute:0,score:[0,0],tries:[0,0],events:[],finished:false,paused:false,halftime:false,userSide,sheets,stats:[makeStats(),makeStats()],tactics:pair.map(ci=>ci===S.club?S.tactic:['equilibre','large','conquete','occupation'][rand(0,3)]),weather:['Sec','Sec','Pluie','Vent'][rand(0,3)],possession:rand(0,1),territory:50,subs:[],pending:null};
// Avis du conseil sur notre jeu (revue FM27, idée n° 31) : jeunes de moins de 23 ans dans chaque XV de départ, sans tirage.
jeunesTitulaires(l);
// Météo annoncée la veille (carrière Monde) : reprise telle quelle. Le tirage du ciel ci-dessus reste fait pour ne pas décaler les suivants.
const meteoFixee=!legacy?meteoAnnonceePour(pair):null;if(meteoFixee)l.weather=meteoFixee.weather;
if(typeof CDFranceCompetition!=='undefined'&&CDFranceCompetition.active(S)){l.franceContext=CDFranceCareer.context(pair);if(!l.franceContext)throw Error('Rencontre hors du calendrier France.');}
if(!legacy){if(S.developmentFocusVersion===1)l.developmentFocusVersion=1;if(S.physicalLoadVersion===1)l.physicalLoadVersion=1;initializeManagers(l,automated);initializeMatchRules(l);initializeMatchFlow(l,meteoFixee);initializeTacticalPlans(l);if(typeof initializeArbitrage==='function')initializeArbitrage(l);initializePlaybooks(l);initializeCollectivePreparation(l);initializeRestarts(l);initializePlayerRoles(l);initializeStaffJudgement(l);initializeDerby(l);initializePreparation(l,preparation);const trap=matchTrapOffset(teamLevel(activePlayers(l,0))-teamLevel(activePlayers(l,1)));if(trap)l.levelTrap=trap*MATCH_LEVEL_CURVE.complet.piege}
if(legacy){l.minute=legacy.minute;l.score=[...legacy.score];l.tries=[...legacy.tries];l.events=[...legacy.events];l.finished=legacy.finished;l.halftime=l.minute>=40;l.paused=l.minute===40&&!l.finished;if(userSide>=0){l.tactics[userSide]=S.tactic;l.tactics[1-userSide]=legacy.opponentTactic||'equilibre';let s=sheets[userSide];s.used=[...new Set([...(legacy.used||[]),...s.on])];s.bench=s.bench.filter(id=>!s.used.includes(id));for(let id of s.used)s.minutes[id]=l.minute/Math.max(1,s.used.length)*15}}
return l}
// Courbe de niveau commune (lot 0 « notes réalistes », 14/11/2026, docs/courbe-niveau-moteur-20261114.md).
// Niveau d'une équipe = moyenne, sur les joueurs alignés, de note × (0,57 + 0,0043 × condition) :
// 1,00 à 100 % de condition, 0,91 à 80 %. Même définition que la puissance du résultat rapide
// (native/engine/league-detail.cjs). Cible commune aux deux moteurs, vérifiée par
// tests/match-rating-curve.cjs : logit P(victoire) = 0,183 × écart de niveau + 0,64 à domicile,
// soit +3 → 63 %, +6 → 75 %, +10 → 86 %, −10 → 14 % sur terrain neutre et 65 % à domicile à niveau égal.
// `complet` règle le moteur complet (avantage ajouté à teamEdge, par point d'écart et à domicile),
// `rapide` le résultat rapide (écart de puissance divisé par `diviseur`, bonus du terrain en points).
// Terrain du moteur complet recalé de ±0,045 à ±0,036 sur les effectifs du barème senior V2 (#716) :
// 65-67 % à domicile à niveau égal, comme le résultat rapide (docs/courbe-niveau-moteur-20261114.md).
// Avant le 14/11/2026 : pas de terme de niveau, terrain ±0,018 (56 %), résultat rapide (Δ+2,5)/8.
// Coefficients de jeu calés par mesure, pas des probabilités réelles.
// Version 2 (15/11/2026) : « match piège ». Au-delà de `seuil` points d'écart, le favori peut prendre son
// adversaire de haut (rotation, relâchement, jour sans) : probabilité parPoint × (écart − seuil), au plus `max` ;
// ce jour-là il joue avec `part` × l'écart en moins. Tiré une fois par match, mêmes réglages pour les deux
// moteurs ; rien en deçà du seuil (cœur de la courbe et tirages inchangés). Sans lui, le moteur complet ne
// laissait presque aucune surprise à l'extérieur à 15-16 points (0,4 %, contre 3,5 % au résultat rapide).
const MATCH_LEVEL_CURVE=Object.freeze({version:2,cible:Object.freeze({pente:.183,terrain:.64}),forme:Object.freeze([.57,.0043]),complet:Object.freeze({parPoint:.005,terrain:.036,piege:2.8}),rapide:Object.freeze({diviseur:6.3,essais:.42,terrain:2.77,borne:3}),piege:Object.freeze({seuil:10,parPoint:.04,max:.3,part:.4})});
// Décalage d'écart du match piège (points de niveau, du point de vue du camp 0) pour un écart `gap`
// (niveau du camp 0 − niveau du camp 1). 0 sans tirage en deçà du seuil.
// Avantage du terrain par championnat (17/11/2026) : multiplie `complet.terrain` et `rapide.terrain` pour les matchs
// de ce championnat (coupes, sélections et autres championnats : 1). Top 14 et Pro D2 : la victoire à domicile y est
// la règle et les succès à l'extérieur rares, nettement plus qu'en Premiership ou en URC ; à 1, le Top 14 mesuré ne
// donnait que 56-61 % de victoires à domicile et un leader à 21-23 victoires sur 26 (docs/top14-dispute-20261117.md).
// Top 14 ×2,1 depuis le 18/11/2026 (§15) : 74 % de victoires à domicile comme en 2024-25 (×1,7 : 67 %) ; le leader perd
// enfin à l'extérieur (Toulouse 7,2 → 5,8 victoires en déplacement sur 13).
const TERRAIN_CHAMPIONNAT=Object.freeze({elite:2.2,accession:2.1,prem:1.45,urc:1.3,srp:1.5,'jlo-d1':.1});
function terrainFactor(competitionId){return TERRAIN_CHAMPIONNAT[competitionId]??1}
function matchTrapOffset(gap,rnd=Math.random){const c=MATCH_LEVEL_CURVE.piege,d=Math.abs(Number(gap)||0),q=Math.min(c.max,c.parPoint*(d-c.seuil));if(!(q>0)||rnd()>=q)return 0;return -Math.sign(gap)*c.part*d}
// Niveau du joueur pour le match (25/11/2026) : `rating` ici ; la carrière le remplace par le Niveau calculé au poste et
// au rôle choisi par le club (native/engine/role-joueur.cjs, même échelle). Lu par teamLevel, le résultat rapide, la
// sélection et l'IA des clubs là où ils lisaient `rating` comme niveau du joueur.
function niveauMatch(p){return Number(p?.rating)||50}
function teamLevel(players){const c=MATCH_LEVEL_CURVE.forme,list=(players||[]).filter(Boolean);return list.length?mean(list.map(p=>niveauMatch(p)*(c[0]+clamp(Number(p.condition)||80,0,100)*c[1]))):40}
// Écart de niveau atténué par championnat (17/11/2026, docs/top14-dispute-20261117.md §9) : au-delà de `seuil` points,
// chaque point d'écart ne compte que pour `pente`. Le moteur additionne beaucoup de petites actions : un gros écart y
// pèse plus que dans un vrai Top 14, où même un leader très au-dessus (Toulouse, +5 sur la moyenne) plafonne à
// 16-19 victoires sur 26. Mêmes réglages pour le moteur complet et le résultat rapide ; ailleurs : écart inchangé.
const ECART_CHAMPIONNAT=Object.freeze({elite:Object.freeze({seuil:3,pente:.15}),accession:Object.freeze({facteur:.55,rapide:.84}),prem:Object.freeze({facteur:1.3,rapide:1.35}),urc:Object.freeze({facteur:2.3,rapide:1.4}),srp:Object.freeze({facteur:4.2,rapide:2.4}),'jlo-d1':Object.freeze({facteur:2.3,rapide:1.46})});
function levelGapChampionnat(gap,competitionId,mode){const c=ECART_CHAMPIONNAT[competitionId];if(!c)return gap;const g=gap*((mode==='rapide'?c.rapide:c.facteur)??1),a=Math.abs(g);return c.seuil!=null&&a>c.seuil?Math.sign(g)*(c.seuil+(a-c.seuil)*c.pente):g}
function matchLevelEdge(l,side){return MATCH_LEVEL_CURVE.complet.parPoint*levelGapChampionnat(teamLevel(activePlayers(l,side))-teamLevel(activePlayers(l,1-side))+(Number(l.levelTrap)||0)*(side===0?1:-1),l.worldContext?.competitionId)}
function teamEdge(l,side,kind){const opp=1-side,t=l.tactics[side],weather=l.weather;const on=activePlayers(l,side);const attack=unit(l,side,'pass')*.4+unit(l,side,'speed')*.35+unit(l,side,'power')*.25;const defense=unit(l,opp,'tackle')*.72+unit(l,opp,'mental')*.28;let b=(tacticalRules(l)?tacticalEdge(l,side):(attack-defense)*(l.balanceVersion===2?.004:.009))+(on.length-activePlayers(l,opp).length)*.055;
// V19: wider attack exposes an outnumbered backline; possession sides with extra players can exploit width.
if(l.advantageModel===2&&kind==='attack'&&t==='large')b+=(on.length-activePlayers(l,opp).length)*.018;
if(kind==='attack'&&!tacticalRules(l)){if(t==='large')b+=(unit(l,side,'pass',p=>p.fam>=4)-(l.balanceVersion===2?75:65))*(l.balanceVersion===2?.003:.006)+(l.balanceVersion===2?.015:.035);if(t==='conquete')b+=(unit(l,side,'power',p=>p.fam<=3)-(l.balanceVersion===2?75:65))*(l.balanceVersion===2?.002:.004);if(weather==='Pluie'&&t==='large')b-=.075;if(weather==='Vent'&&t==='occupation')b-=.025}
b+=matchLevelEdge(l,side);if(l.franceContext?!l.franceContext.neutral:l.worldContext?!l.worldContext.neutral:S.phase!=='semi'&&S.phase!=='final')b+=(side===0?1:-1)*MATCH_LEVEL_CURVE.complet.terrain*terrainFactor(l.worldContext?.competitionId)*(derbyRules(l)?DERBYS.match.domicile:1);if(l.balanceVersion===2)b+=(clubMorale(l.pair[side])-70)*.001;else if(l.pair[side]===S.club)b+=(S.morale-70)*.001;if(kind==='attack')b-=collectivePreparationBonus(l,opp,'defence');if(typeof pilotageEdge==='function')b+=pilotageEdge(l,side,kind);if(kind==='attack')b+=gestionScore(l,side);return b}
// Gestion du score en fin de match (25/11/2026, docs/realite-matchs-20261125.md) : à partir de GESTION_SCORE.debut, l'équipe qui
// mène de plus d'un essai transformé gère (jeu au pied, temps qui passe : moins d'essais) et celle qui est menée à portée pousse
// (bonus défensif, retour au score) ; effet croissant jusqu'à la fin. Les vrais championnats finissent bien plus souvent à un
// score d'écart (40 % des matchs à 7 points ou moins en Top 14) que le moteur sans ce terme. Matchs de compétition Monde seulement.
var GESTION_SCORE={debut:60,mene:.15,poursuit:.3,proche:4,portee:15};
// Résultat rapide (native/engine/league-detail.cjs) : même fin de match en un tirage, l'équipe menée de 8 à « portee » points
// marque un essai de fin de match avec la probabilité « essai », sinon, menée de 6 à 12, une pénalité avec « penalite ».
// « championnat » : part de ces tirages selon le championnat (mesures au rapide contre le réel : Pro D2, Premiership,
// Super Rugby et Japon, plus étagés ou plus prolifiques, finissent moins souvent à un score).
var FIN_MATCH_RAPIDE={essai:.5,penalite:.5,portee:21,championnat:{accession:.62,prem:.7,srp:.4,'jlo-d1':.3}};
function gestionScore(l,side){const g=GESTION_SCORE,m=Number(l.minute)||0;if(!l.worldContext||m<g.debut||!l.score)return 0;const d=l.score[side]-l.score[1-side],r=Math.min(1,(m-g.debut)/(80-g.debut));if(d>=8)return -g.mene*r*Math.min(1,(d-7)/14);if(d<=-g.proche&&d>=-g.portee)return g.poursuit*r;return 0}
function changePossession(l){if(restartRules(l))ballPossession(l,1-l.possession);else l.possession=1-l.possession}
// The field is modelled as 70 m wide (y=0..70), with the posts at y=35.
// These are game-balance coefficients, not measured professional kick percentages.
function goalKickGeometry(conversion=false,tryY=35,territory=50,side=0){
 const depth=conversion?22:Math.max(0,side===0?100-territory:territory);
 // Transformation : abscisse de l'essai ; pénalité (rencontres « essais réalistes ») : abscisse de la marque (penaltySpotY).
 const offset=Math.abs(clamp(tryY,0,70)-35);
 return {distance:Math.hypot(depth,offset),angle:Math.atan2(offset,Math.max(1,depth))};
}
// Réussite au but des rencontres « essais réalistes » (docs/penalites-au-but-20261123.md) : une seule formule pour la
// pénalité et la transformation. Buteur noté `reference.note` face aux poteaux à `reference.distance` m : `reference.reussite`,
// plus ou moins `parPointNote` par point de note au but. La cible rétrécit avec la distance et l'angle : largeur apparente des
// poteaux rapportée à celle du tir de référence, manque retiré au carré × `largeur`. Au-delà de `portee.debut` m, la puissance
// manque (`portee.parMetre` par mètre). Mental, météo, confiance et sang-froid gardent leur poids d'avant (× ESSAIS.but).
// Coefficients de jeu étalonnés par scripts/mesure-buteurs.cjs sur le Top 14, pas des probabilités mesurées du rugby.
var BUT={reference:{note:80,distance:22,reussite:.95},parPointNote:.0085,largeur:.9,portee:{debut:40,parMetre:.026},plancher:.1,
 // Au-dessus de `coude`, la réussite s'approche de `plafond` sans l'atteindre : le meilleur buteur reste sensible au vent.
 coude:.92,plafond:.99,
 // Pénalité : écart latéral de la marque aux poteaux, 0 à `ecartMax` m, tiré sans hasard (repère de l'état du match).
 penalite:{ecartMax:20},
 // Choix du staff : au but si la réussite attendue (hors pression du moment) atteint `seuil`, `seuilPoints` avec la consigne
 // « Chercher les points » ; jamais au-delà de `porteeMax` m.
 seuil:.4,seuilPoints:.3,porteeMax:53};
function goalCeiling(x){const c=BUT.coude,p=BUT.plafond;return Math.max(BUT.plancher,x<=c?x:p-(p-c)*Math.exp(-(x-c)/(p-c)))}
function penaltySpotY(l,side){
 if(!essaisRules(l))return 35;
 const n=Math.floor((Number(l.minute)||0)*41+(l.stats[0].penalties||0)*29+(l.stats[1].penalties||0)*53+l.score[0]*7+l.score[1]*13+side*17),r=(n%100+100)%100/100;
 return 35+(n%2?1:-1)*Math.round(r*BUT.penalite.ecartMax);
}
// Part de la réussite propre au tir (buteur, distance, angle), avant les conditions et la pression.
function goalShotSuccess(l,kicker,shot){
 const R=BUT.reference,largeur=R.distance*Math.cos(shot.angle)/Math.max(1,shot.distance);
 return R.reussite+BUT.parPointNote*(skill(kicker,'goal',fitArrete(l))-R.note)-BUT.largeur*Math.max(0,1-largeur)**2-BUT.portee.parMetre*Math.max(0,shot.distance-BUT.portee.debut);
}
function goalConditions(l,side){return (unit(l,side,'mental')-70)*.001-(meteoActive(l)?METEO_MATCH.but.pluie*l.meteo.pluie+ventBut(l,side):l.weather==='Vent'?.16:l.weather==='Pluie'?.06:0)}
// Réussite attendue d'une pénalité à `distance` m de la ligne, marque en `y`, sans la pression du moment (choix du staff).
function goalChanceEstimate(l,side,distance,y=35){
 const offset=Math.abs(clamp(y,0,70)-35),shot={distance:Math.hypot(distance,offset),angle:Math.atan2(offset,Math.max(1,distance))};
 return goalCeiling(goalShotSuccess(l,goalKicker(l,side),shot)+ESSAIS.but*goalConditions(l,side));
}
// Le staff tente les poteaux : rencontres « essais réalistes », selon la réussite attendue ; sinon, selon la seule distance.
function postsInRange(l,side,distance,y=35,points=false){
 if(!(distance<BUT.porteeMax))return false;
 return !essaisRules(l)||goalChanceEstimate(l,side,distance,y)>=(points?BUT.seuilPoints:BUT.seuil);
}
function goalChance(l,side,conversion=false,tryY=35){
 const kicker=goalKicker(l,side);
 const shot=goalKickGeometry(conversion,tryY,l.territory,side);
 let chance;
 if(essaisRules(l))chance=goalCeiling(goalShotSuccess(l,kicker,shot)+ESSAIS.but*(goalConditions(l,side)+goalKickPressure(l,side,kicker,conversion)));
 else chance=clamp((conversion?.28:.23)+skill(kicker,'goal',fitArrete(l))*.006-Math.max(0,shot.distance-25)*.005-shot.angle*.13+goalConditions(l,side)+goalKickPressure(l,side,kicker,conversion),.22,.93);
 if(l.sjLastKick)l.sjLastKick.p=chance;
 return chance;
}
/* `prelude(scorer)` (découpage des longues courses, docs/match-courses-20261112.md) : écrit les temps de jeu menant à l'essai avec le score d'avant, sans tirage, et rend l'abscisse d'où part l'essai. Les tirages (transformation puis marqueur) restent dans le même ordre. */
function scoreTry(l,side,origin,startAt=l.territory,prelude=null){if(!beforeTryUnderAdvantage(l,side))return;const stat=l.stats[side];const tryY=origin==='maul'?10:origin==='open'&&effectiveAttack(l,side)==='large'?(l.minute%2?14:56):35;const ok=Math.random()<goalChance(l,side,true,tryY);noteGoalKick(l,side,ok);const scorer=essaisRules(l)?finisseurEssai(l,side,origin):(()=>{const candidates=activePlayers(l,side).filter(p=>origin==='maul'||origin==='scrum'?p.fam<=3:p.fam>=3);return candidates.length?candidates[rand(0,candidates.length-1)]:null})();if(prelude)startAt=prelude(scorer);l.tries[side]++;(l.essaisDetail||(l.essaisDetail=[])).push([Math.max(0,Math.round(l.minute)||0),side,origin==='maul'?'b':origin==='scrum'?'m':'j',(x=>Math.round(side===0?100-clamp(x,0,100):clamp(x,0,100)))(Array.isArray(l.essaisPoss)&&l.essaisPoss[0]===side?l.essaisPoss[1]:startAt)]);l.score[side]+=5;stat.conversionAttempts++;if(ok){l.score[side]+=2;stat.conversions++}addEvent(l,`${S.clubs[l.pair[side]].abbr} · Essai${scorer?' de '+scorer.name:''}${origin==='maul'?' sur ballon porté':origin==='scrum'?' sur mêlée':''}, ${ok?'transformé':'transformation manquée'}. ${l.score.join(' – ')}.`, 'try',{kind:'try',team:side,actor:scorer?.id||null,origin,conversion:ok,from:{x:startAt,y:35},to:{x:attackingGoal(side),y:tryY},possession:side});if(restartRules(l)){chronoArret(l,'essai');if(!flowScored(l,side)&&(flowRules(l)||l.minute<80))relancer(l,'kickoff',1-side,'score',side)}else{l.territory=50;l.possession=1-side}}
// Incidents are simulation categories, not automatic legal card tariffs.
const DISCIPLINE_INCIDENTS=[
 {id:'offside',label:'hors-jeu',weight:30,serious:false},
 {id:'ruck',label:'entrée irrégulière dans un ruck',weight:25,serious:false},
 {id:'holding',label:'ballon conservé au sol',weight:20,serious:false},
 {id:'obstruction',label:'obstruction',weight:15,serious:false},
 {id:'dangerous',label:'plaquage dangereux',weight:10,serious:true}
];
function selectDisciplineIncident(roll=Math.random()){
 const total=DISCIPLINE_INCIDENTS.reduce((sum,i)=>sum+i.weight,0);
 let threshold=clamp(roll,0,.999999)*total;
 for(const incident of DISCIPLINE_INCIDENTS){threshold-=incident.weight;if(threshold<0)return incident}
 return DISCIPLINE_INCIDENTS.at(-1);
}
// Cartons (docs/cartons-realistes-20261118.md) : un Top 14 compte ~0,6 à 0,8 jaune par équipe et par match (~1,3 par
// match) et un rouge tous les ~8 matchs. Avant : tout plaquage dangereux (10 % des pénalités) donnait un carton, et
// trois fautes depuis le dernier carton ajoutaient 18 % à chaque pénalité suivante, sans oubli : ~2,6 jaunes par équipe.
// Désormais : plaquage dangereux carton une fois sur deux (rouge pour ~1 sur 7 d'entre eux) ; faute ordinaire (antijeu,
// faute volontaire) ~3,5 % ; fautes répétées = au moins trois pénalités sans dix minutes de répit (+17 %). Un seul tirage.
// Recalé le 19/11/2026 sur 1 000 affiches de Top 14 IA contre IA : ~0,66 jaune et ~0,04 exclusion par équipe et par match.
const CARTONS={dangereux:.5,rouge:.14,base:.035,discipline:.0005,repetees:.17};
function disciplineDecision(l,foul,incident){
 const discipline=unit(l,foul,'discipline');
 const history=l.disciplineHistory?.[foul]||{count:0,recent:0};
 const repeated=history.recent>=3;
 const carte=typeof pilotageCard==='function'?pilotageCard(l):1,u=Math.random();
 if(incident.serious){const p=CARTONS.dangereux*carte;return {sanction:u<p*CARTONS.rouge?'red':u<p?'yellow':null,repeated}}
 const risk=clamp((CARTONS.base+(65-discipline)*CARTONS.discipline+(repeated?CARTONS.repetees:0)+(derbyRules(l)?DERBYS.match.carton:0))*carte,.005,.3);
 return {sanction:u<risk?'yellow':null,repeated};
}
/* `options.incident` (pénalités réalistes) : faute de mêlée, de touche ou de l'attaquant au sol, au lieu de l'incident tiré ; `options.phase` sert à la mesure. Le bénéficiaire reprend le ballon s'il ne l'avait pas. */
function awardPenalty(l,side,options={}){
 const foul=1-side;
 // Faute de l'équipe qui bénéficie déjà d'un avantage (loi 7) : faute ordinaire, l'arbitre revient à la faute initiale
 // de l'adversaire (matchflow.js), qui profite donc de la pénalité de l'équipe fautive, racontée comme telle ; jeu déloyal
 // sanctionné (carton), l'avantage est annulé et la nouvelle pénalité est maintenue contre l'équipe fautive.
 const fautifSousAvantage=flowRules(l)&&!l.flow.resolvingAward&&l.flow.advantage&&l.flow.advantage.team===foul;
 let jeuDeloyal=false,sousAvantage=false;const sanctionInitiale=fautifSousAvantage?(l.flow.advantage.kind==='scrum'?'mêlée':'pénalité'):null;
 l.stats[foul].penalties++;
 if(options.incident&&l.possession!==side)ballPossession(l,side,l.territory);
 if(revisedRules(l)){
  const incident=PENALITES_INCIDENTS[options.incident]||selectDisciplineIncident(((l.minute*17+l.stats[foul].penalties*31)%100)/100);
  if(!l.disciplineHistory)l.disciplineHistory=[{count:0,recent:0},{count:0,recent:0}];
  const history=l.disciplineHistory[foul];
  // Fautes répétées : dix minutes sans pénalité effacent l'avertissement.
  if(Number.isFinite(history.last)&&l.minute-history.last>=10)history.recent=0;
  history.last=l.minute;
  const decision=disciplineDecision(l,foul,incident);
  history.count++;history.recent++;
  jeuDeloyal=fautifSousAvantage&&!!decision.sanction;sousAvantage=fautifSousAvantage&&!decision.sanction;
  // Arbitrage fin (dist/arbitrage.js) : cause détaillée de l'incident tiré, sans tirage de plus.
  const fin=typeof arbitrageFaute==='function'?arbitrageFaute(l,foul,side,incident,decision.repeated,options):null;
  addEvent(l,sousAvantage?`${S.clubs[l.pair[foul]].abbr} sanctionné pour ${incident.label}${decision.repeated?' (fautes répétées)':''}, pénalité écartée pendant son avantage : retour à la faute initiale de ${S.clubs[l.pair[side]].abbr}, ${sanctionInitiale} pour ${S.clubs[l.pair[foul]].abbr}.`:fin?fin.texte:`${S.clubs[l.pair[foul]].abbr} sanctionné pour ${incident.label}${decision.repeated?' (fautes répétées)':''}. Pénalité pour ${S.clubs[l.pair[side]].abbr}.`,'penalty',{team:side,cause:incident.id,...(fin?{detail:fin.id}:{})});
  if(decision.sanction){
   const eligible=activePlayers(l,foul);
   if(eligible.length){
    const offender=eligible[rand(0,eligible.length-1)];
    if(giveMatchCard(l,foul,offender.id,decision.sanction))history.recent=0;
   }
  }
 }else{
  addEvent(l,`${S.clubs[l.pair[foul]].abbr} sanctionné. Pénalité pour ${S.clubs[l.pair[side]].abbr}.`,'penalty',{team:side});
  const discipline=unit(l,foul,'discipline');
  if(Math.random()<clamp(.10+(65-discipline)*.003,.05,.22)){
   const s=l.sheets[foul],eligible=activePlayers(l,foul).filter(p=>p.fam>=2);
   if(eligible.length){const p=eligible[rand(0,eligible.length-1)];s.yellowCounts[p.id]=(s.yellowCounts[p.id]||0)+1;l.stats[foul].yellows++;if(s.yellowCounts[p.id]>=2){s.on=s.on.map(id=>id===p.id?null:id);s.sentOff.push(p.id);addEvent(l,`${p.name} reçoit un second jaune et quitte définitivement le terrain (règle simplifiée du jeu).`,'card')}else{s.cards.push({id:p.id,until:l.minute+10});addEvent(l,`Carton jaune pour ${p.name} : 10 minutes à quatorze.`,'card')}}
  }
 }
 if(jeuDeloyal){clearAdvantage(l,'Avantage annulé : jeu déloyal sanctionné, la nouvelle pénalité est maintenue.');executePenaltyChoice(l,side);return}
 if(flowRules(l)&&offerAdvantage(l,'penalty',side,foul,l.territory,{unsafe:l.events.at(-1)?.type==='card',silent:sousAvantage}))return;
 executePenaltyChoice(l,side);
}
function executePenaltyChoice(l,side){const distance=side===0?100-l.territory:l.territory;/* Fin de période (dist/matchflow.js) : choix sensé au score après la sirène, annoncé. */const sirene=choixPenaliteSirene(l,side,distance);/* Plan de pénalité réglé avant le match (combinaisons, dist/playbook.js) : « Selon le score » garde le choix du staff. */let plan=sirene?'staff':typeof combiPlanPenalite==='function'?combiPlanPenalite(l,side,distance):'staff';if(plan==='main'&&!(quickTapRules(l)&&distance>0&&l.events.at(-1)?.type!=='card'&&quickTapper(l,side)))plan='staff';if(plan==='melee'&&!restartRules(l))plan='staff';if(plan==='melee'){annoncePenaliteSirene(l,side,'melee');addEvent(l,`${S.clubs[l.pair[side]].abbr} choisit la mêlée sur la pénalité.`);if(combiLire(l,side,'scrum','melee',()=>grantSetPiece(l,'scrum',side,l.territory,'penalty-scrum',1-side))!==false)return;plan='touche'}if(plan==='main'){annoncePenaliteSirene(l,side,'main');return combiLire(l,side,'main','main',()=>playQuickTap(l,side))}if(plan==='staff'&&sirene!=='poteaux'&&quickTapRules(l)&&wantsQuickTap(l,side,distance)){annoncePenaliteSirene(l,side,'main');return playQuickTap(l,side)}const spotY=penaltySpotY(l,side),attempt=sirene?sirene==='poteaux':plan==='poteaux'?distance<55:plan==='touche'?false:wantsPosts(l,side,distance,spotY)&&!pretereTouche(l,side);annoncePenaliteSirene(l,side,attempt?'poteaux':'touche');if(attempt){const kicker=goalKicker(l,side);l.stats[side].goalAttempts++;const scored=Math.random()<goalChance(l,side,false,spotY);noteGoalKick(l,side,scored);if(scored){l.stats[side].goals++;l.score[side]+=3;addEvent(l,`${kicker?.name||S.clubs[l.pair[side]].abbr} (${S.clubs[l.pair[side]].abbr}) · Pénalité réussie. ${l.score.join(' – ')}.`,'goal',{kind:'goal',team:side,actor:kicker?.id||null,from:{x:l.territory,y:spotY},to:{x:attackingGoal(side),y:35}})}else addEvent(l,`${kicker?.name||S.clubs[l.pair[side]].abbr} manque la tentative de pénalité.`,'miss',{kind:'miss',team:side,actor:kicker?.id||null,from:{x:l.territory,y:spotY},to:{x:attackingGoal(side),y:42}});if(restartRules(l)){chronoArret(l,'penalite');if(scored){if(!flowScored(l,side)&&(flowRules(l)||l.minute<80))relancer(l,'kickoff',1-side,'score',side)}else missedGoal(l,side)}else{l.territory=50;changePossession(l)}}else{const exit=clamp(l.territory+(side===0?1:-1)*rand(16,25),6,94);if(restartRules(l)){chronoArret(l,'penaltouche');if(plan==='touche')combiLire(l,side,'lineout','touche',()=>resolveTouch(l,side,exit,{direct:true,penalty:true}));else resolveTouch(l,side,exit,{direct:true,penalty:true})}else{l.possession=side;l.territory=exit;addEvent(l,`${S.clubs[l.pair[side]].abbr} choisit la pénaltouche pour installer la pression.`);contestSetPiece(l,side,'lineout',true)}}}

// Conquête gardée sur son lancer (docs/conquete-realiste-20261126.md). Réel, hors pénalités : mêlée 90-95 %, touche 85-88 %.
// base : packs égaux (avant combinaisons, consignes, lanceur, pénaltouche) ; ecart : par point d'écart des avants qui
// disputent (mêlée : piliers, talonneur, deuxième ligne ; touche : talonneur et sauteurs) ; pluie : retiré par niveau de pluie
// (ballon glissant au lancer, appuis en mêlée) ; max : plafond. CONQUETE_RULES=0 : base fixe d'avant (0,80, plafond 0,97).
var CONQUETE={melee:{base:.925,ecart:.005,pluie:.015,max:.98},touche:{base:.905,ecart:.004,pluie:.03,max:.97}};
let CONQUETE_RULES=1;
function conqueteRules(l){return CONQUETE_RULES===1&&l?.balanceVersion===2}
function conqueteBase(l,kind,a,b){if(!conqueteRules(l))return .80+(a-b)*(l.balanceVersion===2?.004:.009);const C=CONQUETE[kind==='scrum'?'melee':'touche'];return C.base+(a-b)*C.ecart-C.pluie*meteoNiveau(l,'pluie')}
function conqueteMax(l,kind){return conqueteRules(l)?CONQUETE[kind==='scrum'?'melee':'touche'].max:.97}
function contestSetPiece(l,side,kind,fromPenalty=false){if(restartRules(l)&&!authorizeSetPiece(l,side,kind))return false;if(kind==='scrum'&&frontRowRules(l)){prepareFrontRows(l);if(l.sheets.some(sh=>sh.front.uncontested)){if([0,1].some(team=>uncontestedParticipants(l,team).length!==8)){addEvent(l,'La mêlée ne peut pas être formée avec moins de huit joueurs par équipe.');return}l.stats[side].scrums++;l.stats[side].scrumsWon++;l.uncontestedScrums[side]++;l.possession=side;addEvent(l,`${S.clubs[l.pair[side]].abbr} introduit en mêlée non disputée : huit joueurs de chaque équipe, sans poussée ni contest de l’introduction.`,'play',{kind:'scrum',team:side,possession:side});return}}const at=l.territory;const st=l.stats[side],opp=1-side;let k=kind==='scrum'?'scrum':'lineout';st[kind==='scrum'?'scrums':'lineouts']++;let a=unit(l,side,k,p=>kind==='scrum'?p.fam<=2:p.fam===1||p.fam===2),b=unit(l,opp,k,p=>kind==='scrum'?p.fam<=2:p.fam===1||p.fam===2);if(penaliteConquete(l,side,kind,a,b))return;const move=setPieceEffects(l,side,kind,fromPenalty);let win=Math.random()<clamp(conqueteBase(l,kind,a,b)+move.win+collectivePreparationBonus(l,side,'conquete')-collectivePreparationBonus(l,opp,'conquete')+(kind==='lineout'?lineoutThrowEdge(l,side)+lineoutPressureEdge(l,side)+(typeof pilotageLineout==='function'?pilotageLineout(l,side):0)+(fromPenalty&&typeof penaltoucheRisque==='function'?penaltoucheRisque(l,side,a,b):0):0),.35,conqueteMax(l,kind));if(win){st[kind==='scrum'?'scrumsWon':'lineoutsWon']++;if(kind==='lineout'&&typeof pilotageLineoutWon==='function'&&l.pilotage)pilotageLineoutWon(l,side);if(kind==='scrum'&&typeof pilotageScrumWon==='function'&&l.pilotage)pilotageScrumWon(l,side);l.possession=side;l.territory=clamp(l.territory+(side===0?1:-1)*Math.max(1,rand(5,11)+move.gain),3,97);addEvent(l,`${S.clubs[l.pair[side]].abbr} conserve ${kind==='scrum'?'sa mêlée et avance':'sa touche'}${playbookRules(l)?' · '+(move.label||(kind==='scrum'?SCRUM_MOVES:LINEOUT_MOVES)[move.move][0]):''}.`,'play',{kind:'setpiece-win',team:side,from:{x:at,y:kind==='lineout'?4:35},to:{x:l.territory,y:kind==='lineout'?15:35},actor:(kind==='lineout'&&move.move==='maul'?activePlayers(l,side).find(p=>p.fam<=3):move.huit?matchPlayer(l,side,l.sheets[side].on[7])||actionPlayer(l,side):actionPlayer(l,side))?.id||null,move:move.move});const conquete=l.events[l.events.length-1];const close=side===0?l.territory>77:l.territory<23;const porte=kind==='lineout'&&typeof ballonPorteBase==='function'?ballonPorteBase(l,side):null;if(close&&Math.random()<clamp((porte?porte.base:.18+(unit(l,side,'power',p=>p.fam<=3)-unit(l,opp,'tackle'))*(l.balanceVersion===2?.003:.005))+(effectiveAttack(l,side)==='conquete'?(l.balanceVersion===2?.07:.12):0)+move.finish+METEO_MATCH.ballonPorte.pluie*meteoNiveau(l,'pluie')+(l.pilotage&&typeof pilotageMaul==='function'?pilotageMaul(l,side,kind):0),porte?porte.min:.08,.5)){const origin=kind==='scrum'?'scrum':playbookRules(l)&&(['fond','courte'].includes(move.move)||move.ras)?'open':'maul',avant=l.tries[side];scoreTry(l,side,origin);/* Essai sur ballon porté : la touche gagnée a formé un ballon porté, quelle que soit la combinaison de lancer. Fait écrit sur la conquête du même pas, sans tirage, pour que la scène montre le ballon porté que le commentaire annonce. */if(origin==='maul'&&l.tries[side]>avant&&conquete?.scene?.kind==='setpiece-win')conquete.scene.porte=true}}else{l.possession=opp;/* Lancer pas droit (dist/arbitrage.js) : une partie des touches perdues, sans tirage. */if(kind==='lineout'&&typeof arbitrageLancer==='function'&&arbitrageLancer(l,side,at))return;addEvent(l,`${S.clubs[l.pair[opp]].abbr} récupère ${kind==='scrum'?'le ballon en mêlée':'le lancer adverse en touche'} !`,'turnover',{kind:'setpiece-loss',team:opp,from:{x:at,y:kind==='lineout'?4:35},to:{x:at,y:kind==='lineout'?15:35},actor:actionPlayer(l,opp,'defender')?.id||null})}}
function makeSub(l,side,slot,incoming){if(revisedRules(l))return revisedSub(l,side,slot,incoming);const s=l.sheets[side],out=s.on[slot],p=matchPlayer(l,side,incoming);if(l.finished||s.subs>=8||!out||!p||p.injury||!slotEligible(p,slot)||s.used.includes(incoming)||!s.bench.includes(incoming)||s.cards.some(c=>c.id===out&&c.until>l.minute))return false;s.on[slot]=incoming;s.bench=s.bench.filter(id=>id!==incoming);s.used.push(incoming);s.subs++;l.subs.push({minute:l.minute,side,out,in:incoming});addEvent(l,`${S.clubs[l.pair[side]].abbr} · ${p.name} remplace ${matchPlayer(l,side,out)?.name||'un titulaire'}.`,'sub',{team:side,actor:incoming});return true}
// Observation native V23: réagit à la progression réellement concédée,
// sans nouveau moteur ni information cachée sur l'équipe adverse.
function opponentDefensiveScout(l,side){
 if(!l||!tacticalRules(l)||side===l.userSide||![0,1].includes(side)||!l.defences||!l.tacticalStats)return false;
 const minute=matchMinute(l);
 if(minute<25||minute>75||minute%10!==0)return false;
 const attack=l.tacticalStats[1-side],defence=l.tacticalStats[side];
 if(!attack||!defence||attack.carries<8)return false;
 const players=activePlayers(l,side),fitness=players.length?mean(players.map(p=>p.condition)):0;
 const progress=attack.advances/attack.carries;
 const penalties=l.stats?.[side]?.penalties||0;
 let next=null,why='';
 if((penalties>=5||fitness<65)&&l.defences[side]==='pression'){
  next='prudente';why='limiter les pénalités et protéger des joueurs fatigués';
 }else if(progress>=.68&&fitness>=76&&penalties<=2&&l.defences[side]!=='pression'){
  next='pression';why='réagir aux progressions adverses répétées';
 }else if(progress<=.3&&l.defences[side]==='pression'&&fitness<78){
  next='equilibre';why='économiser les forces face à une attaque peu efficace';
 }
 if(!next||next===l.defences[side])return false;
 l.defences[side]=next;
 addEvent(l,`${S.clubs[l.pair[side]].abbr} adapte sa défense après observation : ${DEFENCES[next][0].toLowerCase()} (${why}).`,'tactic',{team:side});
 return true;
}
function aiSubs(l,side){opponentDefensiveScout(l,side);manageSubstitutions(l,side)}
function advanceRugby(l){if(l.finished||l.paused)return;if(!Array.isArray(l.essaisPoss)||l.essaisPoss[0]!==l.possession)l.essaisPoss=[l.possession,Math.round(l.territory)];if(flowRules(l))resumeFlowHalf(l);const before=l.minute,intervalPlayers=revisedRules(l)?[activePlayers(l,0),activePlayers(l,1)]:null;l.minute=flowRules(l)?l.minute+1:Math.min(l.minute+1,80);for(let side=0;side<2;side++){const s=l.sheets[side];s.cards=s.cards.filter(c=>{if(c.until<=l.minute){if(!(frontRowRules(l)&&s.front.exclusions.some(e=>e.id===c.id&&e.kind==='yellow'&&!e.closed)))addEvent(l,`${matchPlayer(l,side,c.id)?.name||'Le joueur'} revient après son carton jaune.`,'card');return false}return true});restoreRedReplacements(l,side);for(const p of intervalPlayers?.[side]||activePlayers(l,side)){s.minutes[p.id]=(s.minutes[p.id]||0)+(l.minute-before);const load=tacticalLoad(l,side)*(meteoNiveau(l,'chaleur')?METEO_MATCH.chaleur.fatigue:1)*(l.pilotage&&typeof pilotageFatigue==='function'?pilotageFatigue(l,side):1);p.condition=clamp(p.condition-load*(1+(70-skill(p,'stamina'))*.009)*(l.minute-before),12,100)}if(side!==l.userSide){adaptManager(l,side);aiSubs(l,side)}}
commotionProtocol()?.minute(l);matchIncidents()?.minute(l);
if(chronoRules(l)){chronoMinute(l);return}const observation=beginPlanObservation(l);const side=l.possession,opp=1-side;l.stats[side].possession++;l.stats[0].territory+=l.territory;l.stats[1].territory+=100-l.territory;if(flowRules(l))advanceFlowPlay(l);else if(restartRules(l)){if(l.minute===41)performKickRestart(l,'kickoff',1-l.firstKickoff,'second-half',l.firstKickoff);advanceCausalPlay(l)}else{const roll=Math.random();let penaltyProb=clamp(.12+(70-unit(l,opp,'discipline'))*.002,.06,.23)*derbyFouls(l);
if(roll<penaltyProb)awardPenalty(l,side);else if(roll<penaltyProb+.12)contestSetPiece(l,side,'scrum');else if(roll<penaltyProb+.24)contestSetPiece(l,side,'lineout');else{const t=l.tactics[side],dir=side===0?1:-1;if(t==='occupation'&&Math.random()<.5){let gain=clamp(12+(unit(l,side,'kick',p=>p.fam>=4)-60)*.5+rand(-8,10)-(l.weather==='Vent'?9:0),3,38);l.territory=clamp(l.territory+dir*gain,5,95);addEvent(l,`${S.clubs[l.pair[side]].abbr} gagne ${Math.round(gain)} mètres au pied.`);changePossession(l)}else{let edge=teamEdge(l,side,'attack'),success=Math.random()<clamp(.49+edge,.18,.84);if(success){l.territory=clamp(l.territory+dir*rand(12,25),1,99);let danger=side===0?l.territory>74:l.territory<26;if(danger&&Math.random()<clamp(.36+edge,.16,.75))scoreTry(l,side,'open');else if(l.minute%8===0)addEvent(l,`${S.clubs[l.pair[side]].abbr} enchaîne les temps de jeu ${danger?'dans les 22 mètres':'et franchit la ligne d’avantage'}.`)}else{changePossession(l);addEvent(l,`${S.clubs[l.pair[opp]].abbr} récupère le ballon ${l.weather==='Pluie'?'sur une faute de main':'après une séquence défensive'}.`,'turnover')}}}}
finishPlanObservation(l,observation);compterEntree22(l);if(!flowRules(l)){if(l.minute===40&&!l.halftime){l.halftime=true;l.paused=true;addEvent(l,'Mi-temps. Analyse les statistiques et ajuste tes consignes.','break')}if(l.minute>=80)finishRugbyMatch(l)}}
function rugbyBegin(reducedBench=false){
 if(S.live||S.phase==='ended')return;
 const reduced=reducedBench===true&&typeof CDNationaleReducedBench!=='undefined'?CDNationaleReducedBench:null;
 const vacantNumber=reduced?.vacancy(S);
 if(reducedBench===true&&!vacantNumber)return;
 const m=nextMatch();if(!m){trainWeek();finishRound();return}
 const preparation=matchDossier();
 if(S.manager?.delegation.lineup)autoLineup();
 if(!reduced&&sheetErrors().length){view='team';render();toast('Complète ta feuille à 23. Le staff peut t’aider.');return}
 trainWeek();repairSheet();applyStaffSelection(reduced?22:23);
 if(reduced?reduced.vacancy(S)!==vacantNumber:sheetErrors().length){
  save();view='team';render();toast(reduced?'La feuille à 22 a changé après l’entraînement.':'Une blessure à l’entraînement laisse un poste vacant. Complète la feuille.');return
 }
 S.live=createRugbyMatch(m,null,false,preparation);
 if(typeof initPilotage==='function')initPilotage(S.live);
 if(reduced){
  const sh=S.live.sheets[S.live.userSide];
  sh.bench=sh.bench.filter(Boolean);
  S.live.nationaleReducedBench={vacantNumber};
 }
 playback(S.live).cursor=0;if(!restartRules(S.live))addEvent(S.live,`Coup d’envoi. Météo : ${meteoLibelle(S.live)}.`);
 view='match';save();render();startTimer()
}
function rugbyTick(){if(!S.live)return;presentationTick(S.live)}
function pauseMatch(){let l=S.live;if(!l)return;if(!l.finished)l.paused=true;syncMatchPresentation(l);clearInterval(timer);save();render()}
function continueMatch(){let l=S.live;if(!l||l.finished)return;syncMatchPresentation(l);const p=playback(l),before=l.events.length;p.running=true;try{if(flowRules(l))resumeFlowHalf(l)}finally{p.running=false}if(l.events.length>before)p.cursor=before;l.paused=false;save();render();startTimer()}
function rugbyFast(){clearInterval(timer);const l=S.live;if(!l)return;if(l.finished){syncMatchPresentation(l);render();return}syncMatchPresentation(l);if(atHalftime(l)){render();toast('Valide tes consignes puis reprends la seconde période.');return}syncMatchPresentation(l);l.paused=false;let limit=flowRules(l)?(l.flow.period===1?46:Math.min(l.flow.fullEnd+6,l.minute+10)):(l.minute<40?40:Math.min(80,l.minute+10));while(l.minute<limit&&!l.paused&&!l.finished){const n=l.events.length;advanceRugby(l);if(l.events.slice(n).some(e=>pauseOnTry&&e.type==='try'||pauseOnCard&&e.type==='card'&&e.scene?.incident))l.paused=true}if(!l.finished)l.paused=true;syncMatchPresentation(l);save();render()}
function setLiveTactic(k){const l=S.live;if(!l||!l.paused||l.finished||presentationPending(l)||!Object.keys(TACTICS).includes(k))return;S.tactic=k;l.tactics[l.userSide]=k;addEvent(l,`Ta consigne : ${TACTICS[k][0]}.`,'tactic',{team:l.userSide});syncMatchPresentation(l);save();render()}
function substitute(slot,id){const l=S.live;if(!l||!l.paused)return;if(makeSub(l,l.userSide,slot,id)){syncMatchPresentation(l);save();render();toast('Remplacement effectué.')}else toast('Remplacement impossible : vérifie le poste et la disponibilité.')}
function rugbyUseBench(){const l=S.live;if(!l||!l.paused||l.finished)return;let n=0;const fit=staffSubsFit(l,l.userSide);for(let i=0;i<15;i++){const out=matchPlayer(l,l.userSide,l.sheets[l.userSide].on[i]);const p=eligibleChanges(l,l.userSide,i).filter(p=>!out||p.condition>out.condition+8).sort((a,b)=>fit(b)-fit(a))[0];if(p&&makeSub(l,l.userSide,i,p.id))n++}syncMatchPresentation(l);save();render();toast(`${n} changement(s) effectué(s) avec les joueurs disponibles.`)}
function rugbySimulate(pair){let l=createRugbyMatch(pair,null,true);while(!l.finished){l.paused=false;advanceRugby(l)}applyMatchInjuries(l);return{pair,score:l.score,tries:l.tries,stats:l.stats,weather:l.weather,duration:l.minute,...(l.chrono?{actions:l.chrono.actions}:{})}}
function reportSummary(l){const idx=l.userSide;const a=l.stats[idx],b=l.stats[1-idx];let lines=[];const poss=Math.round(a.possession/Math.max(1,a.possession+b.possession)*100);if(a.lineouts&&a.lineoutsWon/a.lineouts<.7)lines.push('Touche fragile : trop de ballons perdus sur tes lancers.');if(a.scrums&&a.scrumsWon/a.scrums<.7)lines.push('Mêlée en difficulté : travaille ta première ligne.');if(a.penalties>b.penalties+2)lines.push('L’indiscipline a offert des occasions à l’adversaire.');if(a.goalAttempts&&a.goals/a.goalAttempts<.6)lines.push('Le manque de réussite au but a pesé sur le score.');if(poss<42)lines.push('Trop peu de possession pour installer ton jeu.');if(!lines.length)lines.push('Une base collective solide. Compare la conquête et la réussite au but pour préparer la suite.');return lines}
function captureReport(){const l=S.live;if(!l?.engine)return;applyMatchInjuries(l);S.lastReport={pair:[...l.pair],score:[...l.score],tries:[...l.tries],...(Array.isArray(l.essaisDetail)?{essais:(ev=>l.essaisDetail.map((e,i)=>[...e.slice(0,4),ev[i]?.scene?.team===e[1]?ev[i].scene.actor??null:null]))((Array.isArray(l.events)?l.events:[]).filter(e=>e&&e.type==='try'&&e.scene&&e.scene.kind==='try'))}:{}),stats:JSON.parse(JSON.stringify(l.stats)),weather:l.weather,analysis:reportSummary(l),subs:[...l.subs],...(l.preparation?{preparation:JSON.parse(JSON.stringify(l.preparation)),planUsage:JSON.parse(JSON.stringify(l.planUsage))}:{}),...(l.tacticalStats?{tacticalStats:JSON.parse(JSON.stringify(l.tacticalStats))}:{}),...(l.collectivePreparation?{collectivePreparation:JSON.parse(JSON.stringify(l.collectivePreparation))}:{}),...(l.uncontestedScrums?{uncontestedScrums:[...l.uncontestedScrums]}:{})};S.lineup=[...l.sheets[l.userSide].initial];S.reserves=[...S.reserves];}
function skillChips(p){ensureSkills(p);return `<div class="skillchips">${Object.entries(ATTR).sort((a,b)=>skill(p,b[0])-skill(p,a[0])).slice(0,3).map(([k,t])=>`<span>${t} <b>${Math.round(skill(p,k))}</b></span>`).join('')}</div>`}
function sheetSelect(i,isBench=false){const ids=isBench?S.reserves:S.lineup,id=ids[i],p=player(id),all=[...S.lineup,...S.reserves],index=(isBench?15:0)+i,label=isBench?BENCH_LABELS[i]:POS[i];return `<div class="selectrow"><span class="number">${isBench?16+i:i+1}</span><select aria-label="${isBench?'Remplaçant '+(16+i):'Titulaire '+(i+1)} ${label}" onchange="chooseSheet(${i},this.value,${isBench})"><option value="">${label}</option>${club().players.filter(p=>isBench?benchEligible(p,i):slotEligible(p,i)).map(p=>`<option value="${p.id}" ${id===p.id?'selected':''} ${p.injury||all.some((x,j)=>x===p.id&&j!==index)?'disabled':''}>${p.name} · ${p.injury?'Blessé':Math.round(p.condition)+'%'} · ${roleNote(p)}</option>`).join('')}</select><button class="small rating" ${p?'':'disabled'} aria-label="Fiche ${p?p.name:'poste vacant'}" onclick="inspectPlayer('${id}')">${p?roleNote(p):'—'}</button></div>`}
function rugbyTeam(){const rows=[[14],[10,11,12,13],[8,9],[5,6,7],[3,4],[0,1,2]],errors=sheetErrors();return heading('LES HOMMES DU PROJET','Ta feuille à 23.','Un XV complémentaire, un banc préparé. Clique sur une note pour consulter les attributs.',`<button class="dark" onclick="autoLineup();save();render();toast('Le staff a sélectionné les 23 joueurs les plus aptes.')">Sélection du staff ↻</button>`)+`<div class="grid"><div class="stack"><div class="card"><div class="cardtitle"><h2>Le XV de départ</h2><span class="tag">${[...S.lineup,...S.reserves].filter(Boolean).length} / 23 JOUEURS</span></div><div class="pitch">${rows.map(row=>`<div class="pitchrow">${row.map(i=>{let p=player(S.lineup[i]);return `<button class="playerdot" ${p?`onclick="inspectPlayer('${p.id}')"`:''}><div class="shirt">${i+1}</div><span>${p?p.name.split(' ').slice(1).join(' '):'À choisir'}</span><small>${p?roleNote(p)+' · '+Math.round(p.condition)+'%':'—'}</small></button>`}).join('')}</div>`).join('')}</div><div class="notice">${errors.length?errors.slice(0,3).join(' '):'Feuille complète : 15 titulaires, 8 remplaçants, dont un talonneur et deux piliers spécialisés.'}</div>${errors.length?`<button style="margin-top:12px" onclick="promoteCover()">Compléter avec les espoirs →</button>`:''}</div><div class="card"><h2>Les forces de ton XV</h2>${[['Mêlée','scrum',p=>p.fam<=2],['Touche','lineout',p=>p.fam===1||p.fam===2],['Défense','tackle',()=>true],['Jeu de passe','pass',p=>p.fam>=4],['Vitesse','speed',p=>p.fam>=6]].map(([t,k,f])=>`<div class="row"><span>${t}</span><strong>${Math.round(mean(starters().filter(f).map(p=>skill(p,k,true))))}</strong></div>`).join('')}<p class="help">Évaluations ajustées à la condition. Meilleur buteur sélectionné : ${chooseScorer(club(),S.lineup)?.name||'—'}.</p></div></div><div class="stack"><div class="card"><div class="cardtitle"><h2>01 / Les titulaires</h2><span class="eyebrow">NOTE AU POSTE</span></div>${FAMILIES.map((_,i)=>sheetSelect(i)).join('')}</div><div class="card"><div class="cardtitle"><h2>02 / Le banc</h2><span class="tag">8 PLACES</span></div>${BENCH_LABELS.map((_,i)=>sheetSelect(i,true)).join('')}<p class="help">16–18 : couverture de la première ligne. Les deux dernières places permettent d’adapter ta couverture des arrières.</p></div></div><div class="card full"><div class="cardtitle"><h2>L’effectif professionnel</h2><span class="tag">${club().players.length} JOUEURS</span></div><div class="tablewrap"><table><thead><tr><th>JOUEUR</th><th>POSTE</th><th>NOTE AU POSTE</th><th>QUALITÉS</th><th>CONDITION</th><th>STATUT</th></tr></thead><tbody>${[...club().players].sort((a,b)=>a.fam-b.fam||roleNote(b)-roleNote(a)).map(p=>`<tr><td><button class="textbutton" onclick="inspectPlayer('${p.id}')">${p.name}</button><small class="muted"> · ${p.age} ans</small></td><td>${p.pos}</td><td><span class="rating">${roleNote(p)}</span></td><td>${skillChips(p)}</td><td>${Math.round(p.condition)}%</td><td>${p.injury?`<span class="danger">Blessé · ${p.injury} sem.</span>`:S.lineup.includes(p.id)?'Titulaire':S.reserves.includes(p.id)?'Sur le banc':'Hors groupe'}</td></tr>`).join('')}</tbody></table></div></div>${v39Panel()}</div>`}
function statsPanel(l){let a=l.stats[0],b=l.stats[1],total=a.possession+b.possession;let rows=[['Possession',total?Math.round(a.possession/total*100)+'%':'—',total?Math.round(b.possession/total*100)+'%':'—'],['Territoire',total?Math.round(a.territory/total)+'%':'—',total?Math.round(b.territory/total)+'%':'—'],['Mêlées conservées',a.scrumsWon+' / '+a.scrums,b.scrumsWon+' / '+b.scrums],['Touches conservées',a.lineoutsWon+' / '+a.lineouts,b.lineoutsWon+' / '+b.lineouts],['Pénalités concédées',a.penalties,b.penalties],['Cartons jaunes',a.yellows,b.yellows],['Tirs de pénalité',a.goals+' / '+a.goalAttempts,b.goals+' / '+b.goalAttempts],['Transformations',a.conversions+' / '+a.conversionAttempts,b.conversions+' / '+b.conversionAttempts]];if(l.uncontestedScrums)rows.splice(3,0,['Dont non disputées',l.uncontestedScrums[0],l.uncontestedScrums[1]]);return `<div class="matchstats"><div class="statcomparison"><b>${S.clubs[l.pair[0]].abbr}</b><span>STATISTIQUES</span><b>${S.clubs[l.pair[1]].abbr}</b></div>${rows.map(([t,x,y])=>`<div class="statcomparison"><strong>${x}</strong><span>${t}</span><strong>${y}</strong></div>`).join('')}</div>`}
function liveSubPanel(l){if(revisedRules(l))return revisedSubPanel(l);const side=l.userSide,s=l.sheets[side];return `<div class="card"><div class="cardtitle"><h2>Ton banc</h2><span class="tag">${s.subs} / 8 CHANGEMENTS</span></div><p class="help">${l.paused?'Choisis le sortant puis le remplaçant à son poste.':'Mets le match en pause pour donner tes consignes.'} Un joueur sorti ne peut pas revenir.</p>${s.on.map((id,i)=>{const out=matchPlayer(l,side,id);if(!out)return `<div class="row"><span class="danger">${i+1} · Poste vacant (exclusion)</span></div>`;let excluded=s.cards.some(c=>c.id===id&&c.until>l.minute);let candidates=s.bench.map(id=>matchPlayer(l,side,id)).filter(p=>p&&!p.injury&&slotEligible(p,i)&&!s.used.includes(p.id));return `<div class="livesub"><div><small class="muted">${i+1} · ${POS[i]}</small><strong>${out.name}</strong><small>${Math.round(out.condition)}%${excluded?' · Exclu temporairement':''}</small></div><select aria-label="Remplacer ${out.name}" ${!l.paused||l.finished||excluded||s.subs>=8||!candidates.length?'disabled':''} onchange="if(this.value)substitute(${i},this.value)"><option value="">${excluded?'Carton jaune':candidates.length?'Faire entrer…':'Pas de remplaçant'}</option>${candidates.map(p=>`<option value="${p.id}">${p.name} · ${Math.round(p.condition)}%</option>`).join('')}</select></div>`}).join('')}<button class="small" onclick="rugbyUseBench()" ${!l.paused||l.finished||s.subs>=8?'disabled':''}>Confier les changements au staff</button></div>`}
function rugbyMatchView(){const actual=S.live;if(!actual)return rugbyPrematch();const l=matchViewState(actual);const [h,a]=l.pair;const side=l.userSide;return heading('AU BORD DU TERRAIN',l.finished?'Coup de sifflet final.':atHalftime(l)?'Le point à la mi-temps.':l.paused?'À toi de décider.':'Le match se joue.',`${label()} · ${matchClock(l)} · ${l.weather} · ${l.paused?'Pause tactique':l.finished?'Terminé':'En direct'}`)+`<div class="match-centre"><section class="card match-scoreboard" aria-label="Score et commandes du match"><div class="row" style="margin:0"><span class="tag">${l.finished?'TERMINÉ':l.paused?'PAUSE':'EN DIRECT'}</span><span class="eyebrow">${S.phase==='semi'||S.phase==='final'?'TERRAIN NEUTRE':S.clubs[h].stadium}</span></div><div class="live-score"><div>${badge(h)}<h3>${S.clubs[h].name}</h3></div><div class="score">${l.score[0]} <span class="muted">:</span> ${l.score[1]}</div><div>${badge(a)}<h3>${S.clubs[a].name}</h3></div></div><div class="matchactions">${l.finished?'<button class="primary" onclick="finishRound()">Valider la journée →</button>':`<button class="primary" onclick="${l.paused?'continueMatch()':'pauseMatch()'}">${l.paused?(atHalftime(l)?'Lancer la seconde période →':'Reprendre le match →'):'Pause & remplacements'}</button><button onclick="rugbyFast()" ${atHalftime(l)?'disabled':''}>${(flowRules(l)?l.flow.period===1:l.minute<40)?'Avancer vers la mi-temps':'Avancer de 10 minutes'} ⇥</button>`}</div><div class="scoreboard-progress"><div class="progress"><span style="width:${Math.min(100,matchMinute(l)/80*100)}%"></span></div><div class="row muted"><span>${l.tries[0]} essais</span><span>${matchClock(l)} / 80′</span><span>${l.tries[1]} essais</span></div></div></section>${halftimeStaff(l)}${!presentationPending(actual)?numericalAdvicePanel(actual):''}${matchCockpitView(l)}<details class="v40-advanced"><summary>Consignes, remplacements et analyses détaillées</summary><div class="grid match-management"><div class="stack"><div class="card"><h2>Le rapport de forces</h2>${statsPanel(l)}${tacticalMetrics(l)}${l.finished?`<div class="notice">${reportSummary(l).join('<br>')}</div>${matchDebrief(l)}`:''}</div></div><div class="stack"><div class="card"><h2>Les consignes</h2><p>Adversaire : <strong>${TACTICS[l.tactics[1-side]][0]}</strong>.</p><label class="eyebrow" for="live-tactic">VOTRE ATTAQUE</label><select id="live-tactic" style="margin-top:12px" ${!l.paused||l.finished?'disabled':''} onchange="setLiveTactic(this.value)">${Object.entries(TACTICS).map(([k,[t]])=>`<option value="${k}" ${l.tactics[side]===k?'selected':''}>${t}</option>`).join('')}</select><p class="help">${TACTICS[l.tactics[side]][1]}</p>${liveDefenceControls(l)}${penaltyControls(l)}<p class="help">${meteoConseil(l)||(l.weather==='Pluie'?'La pluie pénalise les attaques au large et la réussite au pied.':l.weather==='Vent'?'Le vent rend les tirs au but et l’occupation moins fiables.':'Terrain sec : les qualités techniques peuvent s’exprimer.')}</p></div>${playbookPanel(l)}${liveSubPanel(l)}</div></div></details></div>`}
function rugbyPrematch(){const m=nextMatch();let errors=sheetErrors();return heading('LE RENDEZ-VOUS DU WEEK-END','Prépare ta rencontre.','Une feuille complète et des profils adaptés à ton projet de jeu.')+`<div class="grid prematch-grid"><div class="stack">${fixtureCard()}${S.phase!=='ended'?`<div class="card"><h2>Le groupe pour le week-end</h2><div class="row"><span>Titulaires</span><strong>${starters().length} / 15</strong></div><div class="row"><span>Remplaçants</span><strong>${S.reserves.filter(Boolean).length} / 8</strong></div><div class="row"><span>Plan d’attaque</span><strong>${TACTICS[S.tactic][0]}</strong></div><div class="row"><span>Défense</span><strong>${DEFENCES[S.defence||'equilibre'][0]}</strong></div><div class="row"><span>Entraînement</span><strong>${TRAIN[S.training][0]}</strong></div><div class="row"><span>Préparation collective</span><strong>${COLLECTIVE_FOCI[S.collectiveFocus||'aucune'][0]}</strong></div>${errors.length&&m?`<div class="notice">${errors.slice(0,2).join(' ')}</div>`:''}<button class="primary" style="margin-top:16px;width:100%" onclick="rugbyBegin()">${m?'Coup d’envoi →':'Simuler ce tour →'}</button><p class="help">Changements et exclusions : cadre professionnel français 2025–2026, conservé au fil de la carrière fictive. La météo est révélée au coup d’envoi. Pause automatique à la mi-temps ; pauses tactiques possibles pendant le match.</p></div>`:''}</div><div class="stack">${oppositionPreview()}${S.lastReport?`<div class="card"><h2>Dernier débrief</h2><p><strong>${S.clubs[S.lastReport.pair[0]].abbr} ${S.lastReport.score.join(' – ')} ${S.clubs[S.lastReport.pair[1]].abbr}</strong> · ${S.lastReport.weather}</p>${statsPanel(S.lastReport)}<div class="notice">${S.lastReport.analysis.join('<br>')}</div></div>${matchDebrief(S.lastReport)}`:''}</div></div>`}

function applyMatchInjuries(l){if(l.injuriesApplied)return;l.injuriesApplied=true;commitStaffJudgement(l);const v39Before=v39MatchBefore(l);recordDevelopmentMatch(l);trackManagerLoad(l);recordPhysicalMatchLoad(l);for(let side=0;side<2;side++){const s=l.sheets[side];for(let id of s.used){let p=matchPlayer(l,side,id),minutes=s.minutes[id]||0;if(!p||p.injury||!minutes)continue;let risk=(p.condition<55?.07:.025)*minutes/80*(typeof facteurFragilite==='function'?facteurFragilite(p):1)*(typeof facteurTestPhysique==='function'?facteurTestPhysique(p,minutes,l):1);if(Math.random()<risk){p.injury=rand(1,4);if(l.pair[side]===S.club)news(`${p.name} est blessé après la rencontre : ${p.injury} semaine(s) d’indisponibilité.`)}}}commotionProtocol()?.afterMatch(l);matchIncidents()?.afterMatch(l);v39AfterMatch(l,v39Before)}

function inspectPlayer(id){inspectCareerPlayer(id)}

// Derbys et rivalités, carrière Monde (décision du 16/11/2026, docs/derbys-20261116.md). Une rivalité est une
// paire de clubs dont la tension atteint le seuil : tension vécue (monde interclubs) ou rivalité historique et
// géographique semée ci-dessous (identifiants de clubs du Monde, tension de départ). Valeurs de jeu :
// match.fautes multiplie la probabilité de pénalité (+10 à +20 %), match.carton s'ajoute au risque de jaune
// d'une faute (≈ +0,3 carton par match), match.domicile multiplie l'avantage du terrain ; apres s'ajoute au
// retentissement d'un match ordinaire. Règles copiées au coup d'envoi (derbyVersion) : une rencontre commencée
// avant cette version garde ses règles.
const DERBYS={version:1,seuil:60,
 rivalites:[[0,9,70],[0,17,65],[0,23,65],[5,15,85],[4,5,65],[1,2,65],[3,8,62],[6,16,75],[6,25,65],[10,11,80],[12,14,70],[12,22,70],[14,22,75],[7,18,62],[7,20,62],[23,27,65],[26,98,80],[9,97,65],[101,22,70],[89,90,70],[99,18,62],[30,31,75],[30,33,70],[31,33,70],[35,37,80],[40,41,80],[40,42,65],[41,43,65],[44,45,80],[46,47,70],[48,49,80],[50,51,65],[53,55,80]],
 match:{fautes:1.12,carton:.02,domicile:1.25},
 apres:{victoire:{moral:3,confiance:2,supporters:4,pression:-3},defaite:{moral:-3,confiance:-2,supporters:-4,pression:4},nul:{moral:0,confiance:0,supporters:-1,pression:1}}};
function derbySeed(a,b){for(const [x,y,t] of DERBYS.rivalites)if(x===a&&y===b||x===b&&y===a)return t;return 0}
function derbyTension(s,a,b){if(!Number.isInteger(a)||!Number.isInteger(b)||a===b)return 0;const k=a<b?a+':'+b:b+':'+a,t=s?.interclubWorld?.pairs?.[k]?.tension,monde=typeof CDWorldCareer!=='undefined'&&!!CDWorldCareer.active?.(s);return Math.max(Number.isFinite(t)?t:0,monde?derbySeed(a,b):0)}
function isDerby(s,a,b){return derbyTension(s,a,b)>=DERBYS.seuil}
function derbyRules(l){return l?.derbyVersion===1}
function derbyFouls(l){return derbyRules(l)?DERBYS.match.fautes:1}
function initializeDerby(l){const t=derbyTension(S,l.pair[0],l.pair[1]);if(t>=DERBYS.seuil){l.derbyVersion=1;l.derby={tension:t}}}
// Retentissement d'un derby du club du manager (après le bilan ordinaire du match).
function derbyAftermath(s,r){if(!r||!Array.isArray(r.pair)||!r.pair.includes(s.club)||!isDerby(s,r.pair[0],r.pair[1]))return null;
 const i=r.pair.indexOf(s.club),d=r.score[i]-r.score[1-i],issue=d>0?'victoire':d<0?'defaite':'nul',e=DERBYS.apres[issue],c=(v,a,b)=>Math.max(a,Math.min(b,Math.round(v)));
 s.morale=c((s.morale??70)+e.moral,25,98);s.trust=c((s.trust??50)+e.confiance,0,100);const pr=s.pressRelations;
 if(pr){if(Number.isFinite(pr.fanTrust))pr.fanTrust=c(pr.fanTrust+e.supporters,0,100);if(Number.isFinite(pr.boardPressure))pr.boardPressure=c(pr.boardPressure+e.pression,0,100)}
 return {issue,...e}}
