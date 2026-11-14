'use strict';
// Compatibilité en lecture seule : identités autorisées dans les anciennes carrières.
// Ne jamais les utiliser pour générer de nouvelles saisons fictives.
const LEGACY_CLUB_NAMES=["Stade Toulousain","Union Bordeaux-Bègles","Stade Rochelais","RC Toulon","Section Paloise","Aviron Bayonnais","ASM Clermont","LOU Rugby","Montpellier Hérault Rugby","Castres Olympique","Racing 92","Stade Français Paris","USA Perpignan","RC Vannes"];
const LEGACY_CLUB_ABBR=["ST","UBB","SR","RCT","SP","AB","ASM","LOU","MHR","CO","R92","SFP","USAP","RCV"];
const SAVE_FORMAT='cadrage-debordement-save',SAVE_LIMIT=8*1024*1024,WORLD_SAVE_LIMIT=16*1024*1024,CHAMP_WORLD_SAVE_LIMIT=24*1024*1024;
function saveUtf8Bytes(text){let bytes=0;for(let i=0;i<text.length;i++){const c=text.charCodeAt(i);if(c<128)bytes++;else if(c<2048)bytes+=2;else if(c>=0xd800&&c<=0xdbff&&text.charCodeAt(i+1)>=0xdc00&&text.charCodeAt(i+1)<=0xdfff){bytes+=4;i++;}else bytes+=3;}return bytes;}
let pendingSave=null,saveReadToken=0,lastSaveError=false,validatingStartup=true,loadedSaveText=null,loadSaveFailure='';
function saveError(message){throw new Error(message)}
function saveCheck(ok,message='Le fichier contient des données de carrière incohérentes.'){if(!ok)saveError(message)}
// Stable intrinsic references avoid repeated global lookups in the VM hot path.
const nativeSaveFinite=Number.isFinite,nativeSaveInteger=Number.isInteger,nativeSaveIsArray=Array.isArray;
function saveObject(v){return v!==null&&typeof v==='object'&&!nativeSaveIsArray(v)}
function saveArray(v,max=1000){return nativeSaveIsArray(v)&&v.length<=max}
function saveNumber(v,min=-1e12,max=1e12){return typeof v==='number'&&nativeSaveFinite(v)&&v>=min&&v<=max}
function saveInt(v,min=0,max=1e9){return nativeSaveInteger(v)&&v>=min&&v<=max}
function saveId(v){return typeof v==='string'&&/^[A-Za-z0-9:_-]{1,180}$/.test(v)}
function worldCareerActive(s){return typeof CDWorldCareer!=='undefined'&&typeof CDWorldCareer.active==='function'&&CDWorldCareer.active(s)===true;}
function worldSaveLimits(s){return worldCareerActive(s)&&typeof CDWorldCareer.edition==="function"?CDWorldCareer.edition(s)?.limits:null;}
function worldSaveSizing(s){const z=CDWorldCareer.sizing(s);saveCheck(saveObject(z)&&[58,68,88,102,116].includes(z.clubCount)&&saveInt(z.maxRound,1,52)&&saveInt(z.rounds,1,z.maxRound),'Dimensions mondiales invalides.');return z;}
function saveRoundLimit(s){return worldCareerActive(s)?worldSaveSizing(s).maxRound:s?.franceMode?34:26;}
function commonDatabaseActive(s){if(worldCareerActive(s))return true;return typeof CDCommonRosters!=='undefined'&&s?.commonDatabase?.id===CDCommonRosters.id&&s.commonDatabase.version===1&&Object.keys(s.commonDatabase).length===2&&typeof CDFranceCompetition!=='undefined'&&CDFranceCompetition.active(s)&&s.lnrMode===undefined;}
let commonPlayerIndex=null;
function commonSourcePlayer(p){if(typeof CDCommonRosters==='undefined')return null;if(!commonPlayerIndex)commonPlayerIndex=new Map(CDCommonRosters.clubs.flatMap(c=>c.players.map(p=>[p.id,p])));return commonPlayerIndex.get(p.id)||null;}
function commonYoungPlayer(p,s){return commonSourcePlayer(p)?.age===15||worldCareerActive(s)&&CDWorldCareer.sourcePlayer(s,p.id)?.age===15;}
function rosterFoundationRegistry(s){return commonDatabaseActive(s)&&typeof CDRosterFoundation!=='undefined'?CDRosterFoundation.resolve(s.rosterFoundation):null;}
function rosterFoundationActive(s){return !!rosterFoundationRegistry(s);}
function validateRosterProfile(p,s){
 const reference=rosterFoundationRegistry(s)?.players[p.id];
 const national=worldCareerActive(s)?CDWorldCareer.edition(s).registry.nationaleQualifications?.[p.id]?.roles:undefined;
 saveCheck(national?JSON.stringify(p.nationaleQualifications)===JSON.stringify(national):p.nationaleQualifications===undefined,'Qualification fédérale d’effectif invalide.');
 saveCheck(reference?saveObject(p.rosterProfile)&&JSON.stringify(p.rosterProfile)===JSON.stringify(reference):p.rosterProfile===undefined,'Référence initiale d’effectif invalide.');
 if(reference)saveCheck(p.pos===reference.position.primary&&p.fam===FAMILIES[POS.indexOf(reference.position.primary)],'Qualification initiale d’effectif invalide.');
}
function validateCommonPlayer(p,s){const original=commonSourcePlayer(p),reference=rosterFoundationRegistry(s)?.players[p.id];const source=original&&reference?.position.basis==='official'?{...original,gameplayPosition:reference.position.primary}:original;saveCheck(!!source,'Identifiant de base commune inconnu.');for(const key of ['lnrRatingsVersion','lnrGroup','lnrNationality','gameplayPosition','birthYear','birthDate','ageEstimated','potential'])saveCheck(p[key]===(key==='potential'&&s.careerVariation!==undefined?nativeCareerVariation.sourcePotential(source.potential,p.id,s.careerVariation):source[key]),'Profil de base commune incompatible : '+key);saveCheck(saveObject(p.attributesV2)&&Object.keys(p.attributesV2).length===36&&Object.keys(source.attributesV2).every(k=>saveNumber(p.attributesV2[k],20,97)),'Attributs de base commune invalides.');saveCheck(saveObject(p.skills)&&Object.keys(p.skills).length===11,'Compétences de base commune invalides.');saveCheck(saveObject(p.hiddenTraitsV2)&&Object.keys(p.hiddenTraitsV2).length===Object.keys(source.hiddenTraitsV2).length&&Object.keys(source.hiddenTraitsV2).every(k=>p.hiddenTraitsV2[k]===source.hiddenTraitsV2[k]),'Traits de base commune invalides.');saveCheck(Object.keys(p).filter(k=>k.startsWith('lnr')).every(k=>['lnrRatingsVersion','lnrGroup','lnrNationality'].includes(k)),'Métadonnées de base commune invalides.');}
function safeTree(root){
 const world=worldCareerActive(root);
 const maxNodes=world?(typeof CDWorldCareer.edition==='function'?CDWorldCareer.edition(root)?.limits?.maxSaveNodes??1500000:1500000):
  commonDatabaseActive(root)?650000:typeof CDFranceCompetition!=='undefined'&&CDFranceCompetition.active(root)?400000:200000;
 const pairs=world?root.interclubWorld?.pairs:null;
 // Notes de match : tables par joueur (joueurs, passees, detail, selection.lignes), bornées par le nombre de joueurs du monde.
 const notes=root?.matchNotes,notesMaps=new Set(notes&&typeof notes==='object'?[notes.joueurs,notes.passees,notes.detail,notes.selection?.lignes].filter(x=>x&&typeof x==='object'&&!Array.isArray(x)):[]);
 const notesCap=notesMaps.size&&Array.isArray(root.clubs)?root.clubs.reduce((n,c)=>n+(Array.isArray(c?.players)?c.players.length:0),0)+2000:0;
 // Player knowledge has an independent, finite schema and node allowance.
 // Validate it before granting any allowance, including during initial loading.
 const knowledge=root?.playerKnowledge,knowledgeBudget=knowledge!==undefined&&typeof nativeKnowledgeValidate==='function';
 if(knowledgeBudget)nativeKnowledgeValidate(root);
 const evolution=root?.potentialEvolution,evolutionBudget=evolution!==undefined&&typeof nativePotentialEvolutionValidate==='function';
 if(evolution!==undefined||root?.live?.potentialEvidence!==undefined){saveCheck(typeof nativePotentialEvolutionValidate==='function','Le suivi du potentiel est indisponible.');nativePotentialEvolutionValidate(root);}
 const check=saveCheck,number=saveNumber,object=saveObject,isArray=Array.isArray;
 let count=0,knowledgeCount=0,evolutionCount=0;
 function visit(v,depth,inKnowledge=false,inEvolution=false){
  const allowed=inEvolution?++evolutionCount<600000:inKnowledge?++knowledgeCount<460000:++count<maxNodes;
  check(allowed&&depth<35,'Le fichier est trop complexe.');
  if(typeof v==='string')check(v.length<=6000&&!/[<>"`&\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(v),'Le fichier contient du texte non autorisé.');
  else if(typeof v==='number')check(number(v));
  else if(isArray(v)){
   check(v.length<=2000);
   v.forEach(x=>visit(x,depth+1,inKnowledge,inEvolution));
  }else if(object(v)){
   const keys=Object.keys(v).length;
   if(keys>2000&&notesMaps.has(v))check(keys<=notesCap,'Notes de match : trop de joueurs.');
   else if(keys>2000){
    // This map accumulates distinct club pairs across seasons.
    check(v===pairs);
    const clubs=worldSaveSizing(root).clubCount;
    check(keys<=clubs*(clubs-1)/2);
   }
   for(const [k,x] of Object.entries(v)){
    if(depth===0&&sections&&sectionKnown(k,x))continue;
    check(!['__proto__','constructor','prototype'].includes(k),'Le fichier contient une structure non autorisée.');
    check(k.length<200&&!/[<>"`&]/.test(k));
    const before=depth===0&&sections?[count,knowledgeCount,evolutionCount]:null;
    visit(x,depth+1,inKnowledge||knowledgeBudget&&x===knowledge,inEvolution||evolutionBudget&&x===evolution);
    if(before)sectionVisited(k,x,before);
   }
  }else check(v===null||typeof v==='boolean');
 }
 // Sauvegarde incrémentale (moteur natif) : juste après une sauvegarde, les sections de premier niveau
 // dont le texte enregistré est identique à une section déjà parcourue avec succès, dans le même
 // contexte, reprennent leur décompte de nœuds au lieu d'être reparcourues ; les autres sont visitées
 // comme avant. Sans sections fournies (import, chargement, export, contrôle complet), parcours entier.
 const sections=world&&typeof nativeSafeTreeSections==='function'?nativeSafeTreeSections(root):null;
 const sectionContext=(k,x)=>maxNodes+'|'+(knowledgeBudget&&x===knowledge?'K':'')+(evolutionBudget&&x===evolution?'E':'')+'|'+(pairs!==undefined&&x===root.interclubWorld?'P'+worldSaveSizing(root).clubCount:'');
 function sectionKnown(k,x){
  const text=sections.texts.get(k),hit=sections.cache.get(k);
  if(text===undefined||!hit||hit.text!==text||hit.context!==sectionContext(k,x))return false;
  check(!['__proto__','constructor','prototype'].includes(k),'Le fichier contient une structure non autorisée.');
  check(k.length<200&&!/[<>"`&]/.test(k));
  count+=hit.nodes[0];knowledgeCount+=hit.nodes[1];evolutionCount+=hit.nodes[2];
  check(count<maxNodes&&knowledgeCount<460000&&evolutionCount<600000,'Le fichier est trop complexe.');
  return true;
 }
 function sectionVisited(k,x,before){
  const text=sections.texts.get(k);
  if(text===undefined){sections.cache.delete(k);return;}
  sections.cache.set(k,{text,context:sectionContext(k,x),nodes:[count-before[0],knowledgeCount-before[1],evolutionCount-before[2]]});
 }
 visit(root,0);
}
function validateFrontRowState(l,s,side){
 const sh=l.sheets[side],f=sh.front,players=s.clubs[l.pair[side]].players;
 const member=id=>sh.nominated.includes(id),get=id=>players.find(p=>p.id===id);
 saveCheck(saveObject(f)&&typeof f.prepared==='boolean'&&typeof f.uncontested==='boolean'&&saveArray(f.exclusions,18)&&saveArray(f.held,15));
 f.exclusions.forEach(e=>{
  saveCheck(saveObject(e)&&member(e.id)&&saveInt(e.slot,0,2)&&slotEligible(get(e.id),e.slot)&&['yellow','red20','red'].includes(e.kind)&&typeof e.closed==='boolean');
  if(e.releaseSlot!==undefined)saveCheck(saveInt(e.releaseSlot,3,14));
  saveCheck(e.kind==='red'?e.until===null:saveInt(e.until,e.kind==='yellow'?10:20,l.flowVersion===1?260:100));
  if(e.kind==='yellow'&&!e.closed)saveCheck(sh.cards.some(c=>c.id===e.id&&c.until===e.until));
  if(e.kind==='yellow'&&e.closed)saveCheck(e.until<=l.minute);
  if(e.kind!=='yellow')saveCheck(sh.redCards.some(c=>c.id===e.id&&c.slot===e.slot&&c.until===e.until));
 });
 saveCheck(new Set(f.held.map(h=>h.id)).size===f.held.length&&new Set(f.held.map(h=>h.slot)).size===f.held.length);
 f.held.forEach(h=>saveCheck(saveObject(h)&&sh.bench.includes(h.id)&&saveInt(h.slot,3,14)&&slotEligible(get(h.id),h.slot)&&sh.on[h.slot]===null&&saveInt(h.caseIndex,0,f.exclusions.length-1)&&['cover','carence'].includes(h.mode)));
 for(const c of sh.redCards.filter(c=>c.slot<3))saveCheck(saveInt(c.frontCase,0,f.exclusions.length-1)&&f.exclusions[c.frontCase].id===c.id&&f.exclusions[c.frontCase].kind!=='yellow');
 const unavailable=new Set(sh.cards.filter(c=>c.until>l.minute).map(c=>c.id));
 const active=sh.on.filter(id=>id&&!unavailable.has(id));
 const maximum=15-unavailable.size-sh.redCards.filter(c=>c.until===null||c.until>l.minute).length-(f.uncontested&&f.exclusions.length?1:0);
 saveCheck(active.length<=maximum,'L’effectif dépasse le nombre autorisé après exclusion ou carence.');
 if(f.uncontested)saveCheck(f.prepared&&[0,1,2].some(i=>!sh.on[i]||unavailable.has(sh.on[i])||!slotEligible(get(sh.on[i]),i)));
}

function validateMatchRules(l,s){
 const reduced=l.nationaleReducedBench!==undefined;
 if(reduced)saveCheck(l.rulesProfile===MATCH_RULES&&l.frontRowVersion===1&&typeof CDNationaleReducedBench!=='undefined'&&CDNationaleReducedBench?.validate(s,l),'Feuille de Nationale à 22 incohérente.');
 if(l.rulesProfile===undefined)return;
 saveCheck(l.rulesProfile===MATCH_RULES,'Cette version des règles de match n’est pas prise en charge.');
 if(l.frontRowVersion!==undefined)saveCheck(l.frontRowVersion===1&&saveArray(l.uncontestedScrums,2)&&l.uncontestedScrums.length===2&&l.uncontestedScrums.every(n=>saveInt(n,0,100)));
 for(let side=0;side<2;side++){
  const sh=l.sheets[side],ids=new Set(s.clubs[l.pair[side]].players.map(p=>p.id));
  const nominationSize=reduced&&side===l.userSide?22:23;
  saveCheck(saveArray(sh.nominated,nominationSize)&&sh.nominated.length===nominationSize&&new Set(sh.nominated).size===nominationSize&&sh.nominated.every(id=>ids.has(id)));
  saveCheck(saveInt(sh.tacticalReturns,0,4)&&saveArray(sh.redCards,15));
  const roster=new Set(sh.nominated),places=[...sh.on.filter(Boolean),...sh.bench,...sh.sentOff];
  saveCheck(places.length===nominationSize&&new Set(places).size===nominationSize&&places.every(id=>roster.has(id)),'Les positions des joueurs ne correspondent pas au groupe désigné.');
  saveCheck([...sh.initial,...sh.used].every(id=>roster.has(id))&&sh.initial.every(id=>sh.used.includes(id)));
  saveCheck(sh.cards.every(c=>(sh.on.includes(c.id)||l.frontRowVersion===1&&sh.front?.exclusions?.some(e=>e.id===c.id&&e.kind==='yellow'&&!e.closed&&e.until===c.until))&&!sh.sentOff.includes(c.id)));
  saveCheck(sh.redCards.length===sh.sentOff.length&&new Set(sh.redCards.map(c=>c.id)).size===sh.redCards.length);
  sh.redCards.forEach(c=>{saveCheck(saveObject(c)&&sh.sentOff.includes(c.id)&&saveInt(c.slot,l.frontRowVersion===1?0:3,14)&&typeof c.filled==='boolean'&&(c.until===null||saveInt(c.until,20,l.flowVersion===1?260:100)));
   saveCheck(c.until!==null||!c.filled);if(c.filled)saveCheck(c.until<=l.minute);else if(!(l.frontRowVersion===1&&c.slot<3))saveCheck(sh.on[c.slot]===null);
   if(c.announced!==undefined)saveCheck(typeof c.announced==='boolean');
  });
  const seen=new Set(sh.initial);let count=0,returns=0;
  for(const sub of l.subs.filter(x=>x.side===side)){
   saveCheck(roster.has(sub.in)&&roster.has(sub.out)&&sub.in!==sub.out&&typeof sub.returning==='boolean'&&sub.returning===seen.has(sub.in)&&(l.frontRowVersion===1?['tactical','red20','frontcover','frontreturn','frontrelease']:['tactical','red20']).includes(sub.reason));
   if(sub.reason==='red20')saveCheck(sh.redCards.some(c=>c.id===sub.out&&c.filled&&c.until!==null&&c.until<=sub.minute));
   else if(sub.returning&&sub.reason==='tactical')returns++;
   seen.add(sub.in);count++;
  }
  if(l.frontRowVersion===1)validateFrontRowState(l,s,side);
  saveCheck(count===sh.subs&&returns===sh.tacticalReturns&&seen.size===sh.used.length&&sh.used.every(id=>seen.has(id)),'Le décompte des changements est incohérent.');
 }
}

function validateRestartState(l,s=null){
 const pacific=typeof CDWorldSRPMatch!=='undefined'&&CDWorldSRPMatch.applies(l,s);
 saveCheck(l.srpExtra===undefined||pacific,'Prolongation Pacific hors de son édition.');
 const japan=typeof CDWorldJapanMatch!=='undefined'&&CDWorldJapanMatch.applies(l,s);
 saveCheck(l.japanExtra===undefined||japan,'Prolongation Japon hors de son édition.');
 saveCheck(l.champExtra===undefined||typeof CDWorldChampMatch!=='undefined'&&CDWorldChampMatch.applies(l,s),'Prolongation Champ hors de son édition.');
 if(l.restartVersion===undefined)return;
 saveCheck(l.restartVersion===1,'Cette version des reprises de jeu n’est pas prise en charge.');
 saveCheck(l.rulesProfile===MATCH_RULES&&saveInt(l.firstKickoff,0,1)&&saveArray(l.restartLog,300));
 const c=l.kickContext;saveCheck(saveObject(c)&&c.team===l.possession&&typeof c.halfEligible==='boolean'&&typeof c.twentyTwoEligible==='boolean');
 let previous=0;
 for(const r of l.restartLog){
  saveCheck(saveObject(r)&&(RESTART_CAUSES[r.kind]?.includes(r.cause)||pacific&&CDWorldSRPMatch.restartAllowed(r,l)||japan&&CDWorldJapanMatch.restartAllowed(r,l))&&saveInt(r.team,0,1)&&saveInt(r.by,0,1)&&saveNumber(r.at,0,100)&&saveNumber(r.origin,0,100)&&saveNumber(r.minute,previous,l.minute));previous=r.minute;
  saveCheck(r.team===(['penalty-touch','50-22'].includes(r.cause)?r.by:1-r.by));
  if(r.kind==='scrum'||r.kind==='lineout')saveCheck(r.at>=5&&r.at<=95);
  else saveCheck(r.at===(r.kind==='kickoff'?50:r.kind==='drop22'?(r.team===0?22:78):ownGoal(r.team)));
  if(r.cause==='50-22')saveCheck(ownHalf(r.by,r.origin)&&(r.by===0?r.at>=78:r.at<=22));
  if(r.cause==='start')saveCheck(r.team===l.firstKickoff&&r.minute===0);
  if(r.cause==='second-half')saveCheck(r.team===1-l.firstKickoff&&r.minute===(l.flowVersion===1?l.flow.firstEnd:41));
  if(r.cause==='extra-first')saveCheck((l.franceContext||worldCareerActive(s)&&l.worldContext)&&l.knockout&&r.team===l.firstKickoff&&r.minute===l.knockout.regulationEnd);
  if(r.cause==='extra-second')saveCheck((l.franceContext||worldCareerActive(s)&&l.worldContext)&&l.knockout&&l.knockout.period===2&&r.team===1-l.firstKickoff&&r.minute===l.knockout.firstEnd);
 }
}

function validateFlowState(l,s=null){
 saveCheck(l.flowVersion===1&&l.restartVersion===1,'Cette version du déroulement de match n’est pas prise en charge.');
 const f=l.flow;saveCheck(saveObject(f)&&[1,2].includes(f.period)&&typeof f.atBreak==='boolean'&&typeof f.ballDead==='boolean'&&f.resolvingAward===false);
 const pacific=typeof CDWorldSRPMatch!=='undefined'&&CDWorldSRPMatch.applies(l,s);
 saveCheck(l.srpExtra===undefined||pacific&&f.period===2&&l.knockout===undefined,'Prolongation Pacific incompatible avec le déroulement.');
 const japan=typeof CDWorldJapanMatch!=='undefined'&&CDWorldJapanMatch.applies(l,s);
 saveCheck(l.japanExtra===undefined||japan&&f.period===2&&l.knockout===undefined&&l.srpExtra===undefined,'Prolongation Japon incompatible avec le déroulement.');
 if(f.period===1){saveCheck(f.fullEnd===null);if(f.atBreak)saveCheck(f.firstEnd===l.minute&&l.minute>=40&&l.paused&&l.halftime&&!l.finished&&f.ballDead);else saveCheck(f.firstEnd===null&&!l.finished)}
 else if(l.japanExtra!==undefined)saveCheck(saveInt(f.firstEnd,40,200)&&f.firstEnd<=l.minute&&f.fullEnd===CDWorldJapanMatch.flowBoundary(l)&&!f.atBreak&&l.halftime);
 else if(l.srpExtra!==undefined)saveCheck(saveInt(f.firstEnd,40,200)&&f.firstEnd<=l.minute&&f.fullEnd===CDWorldSRPMatch.flowBoundary(l)&&!f.atBreak&&l.halftime);
 else saveCheck(saveInt(f.firstEnd,40,200)&&f.firstEnd<=l.minute&&(l.knockout?(l.franceContext||worldCareerActive(s)&&l.worldContext)&&f.fullEnd===(l.knockout.period===1?l.knockout.regulationEnd:l.knockout.firstEnd)+10:f.fullEnd===f.firstEnd+40)&&!f.atBreak&&l.halftime);
 if(l.finished)saveCheck(f.period===2&&(l.minute>=f.fullEnd||pacific&&CDWorldSRPMatch.earlyFinish(l)||japan&&CDWorldJapanMatch.earlyFinish(l))&&f.ballDead&&f.advantage===null);
 if(f.advantage!==null){const a=f.advantage;saveCheck(saveObject(a)&&['scrum','penalty'].includes(a.kind)&&saveInt(a.team,0,1)&&a.offender===1-a.team&&saveNumber(a.at,0,100)&&saveInt(a.started,0,l.minute)&&saveInt(a.phases,0,2)&&l.possession===a.team&&!f.atBreak&&!l.finished)}
}

function validateActionScenes(l,s){
 for(const e of l.events){
  if(e.scene===undefined)continue;const a=e.scene;
  saveCheck(saveObject(a)&&a.v===1&&ACTION_KINDS.includes(a.kind)&&saveInt(a.team,0,1)&&saveInt(a.possession,0,1)&&(a.incident===undefined||typeof a.incident==='boolean')&&[1,2].includes(a.period));
  if(e.period!==undefined)saveCheck(a.period===e.period);if(a.move!==undefined)saveCheck([...Object.keys(SCRUM_MOVES),...Object.keys(LINEOUT_MOVES),...Object.keys(KICKOFF_MOVES)].includes(a.move));if(a.plans!==undefined){saveCheck(saveObject(a.plans));for(const [key,allowed] of [['attack',TACTICS],['defence',DEFENCES]])saveCheck(saveArray(a.plans[key],2)&&a.plans[key].length===2&&a.plans[key].every(value=>Object.keys(allowed).includes(value)))}saveCheck(a.style===undefined||Object.keys(TACTICS).includes(a.style));
  saveCheck(a.cause===undefined||ACTION_CAUSES[a.kind]?.includes(a.cause));saveCheck(a.card===undefined||a.kind==='card'&&a.incident===true&&ACTION_CARDS.includes(a.card));saveCheck(a.porte===undefined||a.kind==='setpiece-win'&&a.porte===true);saveCheck(a.origin===undefined&&a.conversion===undefined||a.kind==='try'&&ACTION_TRY_ORIGINS.includes(a.origin)&&typeof a.conversion==='boolean');
  for(const point of [a.from,a.to])saveCheck(saveObject(point)&&saveNumber(point.x,0,100)&&saveNumber(point.y,0,70));
  for(const key of ['score','tries'])saveCheck(saveArray(a[key],2)&&a[key].length===2&&a[key].every((n,i)=>saveInt(n,0,l[key][i])));
  saveCheck(saveArray(a.on,2)&&a.on.length===2);
  a.on.forEach((ids,side)=>{const sh=l.sheets[side],eligible=new Set(sh.nominated||[...sh.initial,...sh.bench,...sh.used,...sh.sentOff]);saveCheck(saveArray(ids,15)&&ids.length===15&&new Set(ids.filter(Boolean)).size===ids.filter(Boolean).length);ids.forEach((id,slot)=>saveCheck(id===null||saveId(id)&&eligible.has(id)&&slotEligible(s.clubs[l.pair[side]].players.find(p=>p.id===id),slot)))});
  saveCheck(a.actor===null||saveId(a.actor)&&s.clubs[l.pair[a.team]].players.some(p=>p.id===a.actor));
  saveCheck(a.tackler===undefined||a.kind==='carry'&&saveId(a.tackler)&&a.on[1-a.team].includes(a.tackler)); // plaqueur : un adversaire sur le terrain
 }
}
function validateTacticalStats(values){saveCheck(saveArray(values,2)&&values.length===2);for(const a of values){saveCheck(saveObject(a)&&TACTICAL_STAT_KEYS.every(key=>key==='metres'?saveNumber(a[key],0,80000):saveInt(a[key],0,2000)));saveCheck(a.advances<=a.carries&&a.longGains<=a.advances&&a.metres<=a.advances*40)}}
function validateTacticalPlans(l){if(l.tacticalVersion===undefined){saveCheck(l.defences===undefined&&l.tacticalStats===undefined);return}saveCheck(l.tacticalVersion===1&&l.restartVersion===1&&l.balanceVersion===2);saveCheck(saveArray(l.defences,2)&&l.defences.length===2&&l.defences.every(key=>Object.keys(DEFENCES).includes(key)));validateTacticalStats(l.tacticalStats)}
function validatePlaybook(p){saveCheck(saveObject(p)&&saveObject(p.zones));for(const key of Object.keys(FIELD_ZONES)){const z=p.zones[key];saveCheck(saveObject(z)&&(z.attack==='inherit'||Object.keys(TACTICS).includes(z.attack))&&(z.defence==='inherit'||Object.keys(DEFENCES).includes(z.defence)))}saveCheck(Object.keys(SCRUM_MOVES).includes(p.scrum)&&Object.keys(LINEOUT_MOVES).includes(p.lineout)&&Object.keys(KICKOFF_MOVES).includes(p.kickoff))}
function validateManager(s){const m=s.manager;if(m===undefined)return;saveCheck(saveObject(m)&&m.version===1&&saveInt(m.serial,0,10000000)&&saveInt(m.lastWeek,0,s.economy.week)&&saveObject(m.delegation)&&typeof m.delegation.training==='boolean'&&typeof m.delegation.lineup==='boolean'&&(m.delegation.matchLineup===undefined||typeof m.delegation.matchLineup==='boolean'));validatePlaybook(m.playbook);saveCheck(saveArray(m.watch,30)&&new Set(m.watch).size===m.watch.length&&m.watch.every(saveId));saveCheck(saveArray(m.inbox,60)&&new Set(m.inbox.map(x=>x.id)).size===m.inbox.length);for(const msg of m.inbox)saveCheck(saveObject(msg)&&saveId(msg.id)&&typeof msg.title==='string'&&typeof msg.body==='string'&&['club','staff','staff-v65','recruitment'].includes(msg.kind)&&['dashboard','team','tactics','plans','staff','recruitment','market','finance','league','match'].includes(msg.action)&&saveInt(msg.week,0,s.economy.week)&&saveInt(msg.season,1,s.season)&&typeof msg.read==='boolean');saveCheck(saveArray(m.missions,24)&&m.missions.filter(j=>j.status==='active').length<=1&&m.missions.filter(j=>j.status==='queued').length<=3&&new Set(m.missions.map(j=>j.id)).size===m.missions.length);for(const j of m.missions)saveCheck(saveObject(j)&&saveId(j.id)&&saveInt(j.family,0,8)&&saveInt(j.maxAge,18,40)&&saveInt(j.budget,0,10000000)&&saveInt(j.maxWage,1000,100000)&&['active','queued','done'].includes(j.status)&&saveInt(j.remaining,j.status==='done'?0:1,j.status==='done'?0:2)&&saveInt(j.week,0,s.economy.week));saveCheck(saveArray(m.reports,40));for(const r of m.reports)saveCheck(saveObject(r)&&saveId(r.id)&&saveId(r.mission)&&saveId(r.playerId)&&typeof r.name==='string'&&POS.includes(r.pos)&&saveInt(r.family,0,8)&&saveInt(r.age,16,50)&&saveInt(r.note,0,100)&&saveInt(r.potential,0,100)&&saveNumber(r.salary,0,100000)&&saveNumber(r.price,0,100000000)&&['A','B','C'].includes(r.grade)&&saveInt(r.week,0,s.economy.week)&&saveInt(r.season,1,s.season))}
function validateLivePlaybooks(l){if(l.playbookVersion===undefined){saveCheck(l.playbooks===undefined);return}saveCheck(l.playbookVersion===1&&l.tacticalVersion===1&&l.restartVersion===1);saveCheck(saveArray(l.playbooks,2)&&l.playbooks.length===2);l.playbooks.forEach(validatePlaybook)}
function validatePreparation(r,s,live=false){
 if(r.preparation===undefined){saveCheck(r.planUsage===undefined);return}
 const p=r.preparation,u=r.planUsage,side=r.pair.indexOf(s.club);
 saveCheck(side>=0&&saveObject(p)&&p.v===1&&saveInt(p.season,1,s.season)&&saveInt(p.round,0,saveRoundLimit(s))&&p.opponent===r.pair[1-side]&&saveInt(p.observed,0,5));
 saveCheck(Object.keys(TACTICS).includes(p.attack)&&Object.keys(TACTICS).includes(p.recommendedAttack)&&Object.keys(DEFENCES).includes(p.defence)&&Object.keys(DEFENCES).includes(p.recommendedDefence));validatePlaybook(p.playbook);
 saveCheck(saveObject(u)&&u.v===1&&saveInt(u.minutes,0,live?r.minute:240)&&saveObject(u.zones)&&saveObject(u.attack)&&saveObject(u.defence));
 const zones=Object.keys(FIELD_ZONES),attacks=Object.keys(TACTICS),defences=Object.keys(DEFENCES);let phases=0;
 saveCheck(Object.keys(u.zones).length===zones.length&&Object.keys(u.attack).length===attacks.length&&Object.keys(u.defence).length===defences.length);
 zones.forEach(k=>saveCheck(saveInt(u.zones[k],0,u.minutes)));saveCheck(zones.reduce((n,k)=>n+u.zones[k],0)===u.minutes);
 for(const k of attacks){const a=u.attack[k];saveCheck(saveObject(a)&&saveInt(a.phases,0,u.minutes));phases+=a.phases;for(const key of ['carries','advances','handErrors','kicks'])saveCheck(saveInt(a[key],0,2000));saveCheck(saveNumber(a.metres,0,80000)&&a.advances<=a.carries&&a.metres<=a.advances*40+1e-6);if(!a.phases)saveCheck(['carries','advances','metres','handErrors','kicks'].every(key=>a[key]===0))}
 for(const k of defences){const d=u.defence[k];saveCheck(saveObject(d)&&saveInt(d.phases,0,u.minutes));phases+=d.phases;for(const key of ['oppCarries','oppAdvances','penalties'])saveCheck(saveInt(d[key],0,2000));saveCheck(saveNumber(d.oppMetres,0,80000)&&d.oppAdvances<=d.oppCarries&&d.oppMetres<=d.oppAdvances*40+1e-6);if(!d.phases)saveCheck(['oppCarries','oppAdvances','oppMetres','penalties'].every(key=>d[key]===0))}
 saveCheck(phases===u.minutes);
 if(r.tacticalStats){for(const key of ['carries','advances','metres','handErrors','kicks'])saveCheck(attacks.reduce((n,k)=>n+u.attack[k][key],0)<=r.tacticalStats[side][key]+1e-6);for(const [key,total] of [['oppCarries','carries'],['oppAdvances','advances'],['oppMetres','metres']])saveCheck(defences.reduce((n,k)=>n+u.defence[k][key],0)<=r.tacticalStats[1-side][total]+1e-6)}
 saveCheck(defences.reduce((n,k)=>n+u.defence[k].penalties,0)<=r.stats[side].penalties);
}


// V28 : présence facultative pour les anciennes carrières et rencontres.
function validateCollectiveSnapshot(cp,s=null){
 saveCheck(saveObject(cp)&&cp.v===1&&saveInt(cp.season,1,10000)&&saveInt(cp.round,0,saveRoundLimit(s)));
 saveCheck(saveArray(cp.focus,2)&&cp.focus.length===2&&cp.focus.every(f=>Object.prototype.hasOwnProperty.call(COLLECTIVE_FOCI,f)));
 saveCheck(saveArray(cp.power,2)&&cp.power.length===2&&cp.power.every(v=>saveNumber(v,.55,1)));
}

// Pure identity boundary: also used before native domains exist at startup.
function customCompetitionIdentity(s){
 if(s?.customCompetition===undefined)return null;
 const c=s.customCompetition,shape=(x,keys)=>saveObject(x)&&Object.keys(x).length===keys.length&&keys.every(k=>Object.prototype.hasOwnProperty.call(x,k));
 const text=x=>typeof x==='string'&&x.length>=1&&x.length<=80&&x===x.trim()&&!/[<>"`&\x00-\x1f\x7f]/.test(x);
 saveCheck(!['worldMode','franceMode','lnrMode','commonDatabase','identityPack','rosterFoundation'].some(k=>s[k]!==undefined),'Compétition personnalisée réservée aux effectifs fictifs.');
 saveCheck(shape(c,['version','name','clubs','schedule'])&&c.version===1&&text(c.name)&&Array.isArray(c.clubs)&&c.clubs.length===14,'Identités de compétition personnalisée invalides.');
 const ids=new Set(),names=new Set();
 c.clubs.forEach((row,i)=>{saveCheck(shape(row,['id','sourceId','name','abbr'])&&row.id===i&&typeof row.sourceId==='string'&&/^[a-zA-Z0-9_-]{1,64}$/.test(row.sourceId)&&!ids.has(row.sourceId)&&text(row.name)&&!names.has(row.name.normalize('NFC').toLocaleLowerCase('fr'))&&row.abbr==='C'+String(i+1).padStart(2,'0'),'Identité personnalisée invalide.');ids.add(row.sourceId);names.add(row.name.normalize('NFC').toLocaleLowerCase('fr'));});
 saveCheck(JSON.stringify(c.schedule)===JSON.stringify(s.schedule),'Calendrier personnalisé divergent.');
 return c;
}
function validateCareer(s){if(s?.careerVariation!==undefined){saveCheck(typeof nativeCareerVariation!=='undefined','Variation de carrière indisponible.');nativeCareerVariation.validate(s.careerVariation);}const world=worldCareerActive(s);if(s?.worldMode!==undefined)saveCheck(world,'Mode mondial invalide ou indisponible.');safeTree(s);if(s?.rosterFoundation!==undefined)saveCheck(rosterFoundationActive(s),'Registre effectif invalide ou indisponible.');if(s?.commonDatabase!==undefined)saveCheck(commonDatabaseActive(s),'Base commune invalide ou indisponible.');const common=commonDatabaseActive(s);if(s?.identityPack!==undefined)saveCheck(common&&saveObject(s.identityPack)&&Object.keys(s.identityPack).length===2&&typeof s.identityPack.id==='string'&&/^[a-z0-9][a-z0-9-]{0,39}-[0-9a-f]{64}$/.test(s.identityPack.id)&&typeof s.identityPack.digest==='string'&&/^[0-9a-f]{64}$/.test(s.identityPack.digest)&&s.identityPack.id.endsWith('-'+s.identityPack.digest),'Liaison de pack invalide.');const france=s?.franceMode!==undefined;if(france)saveCheck(!world&&typeof CDFranceSaveValidation!=='undefined'&&CDFranceCompetition.active(s)&&s.lnrMode===undefined,'Mode France invalide ou indisponible.');if(!world)saveCheck(s.live?.worldContext===undefined&&(france||s.live?.franceContext===undefined&&s.live?.knockout===undefined),'Contexte de compétition incompatible.');const worldSizing=world?worldSaveSizing(s):null,worldRegistry=world?CDWorldCareer.edition(s).registry:null,clubCount=world?worldSizing.clubCount:france?30:14,maxClub=clubCount-1,maxRound=world?worldSizing.maxRound:france?34:26,rounds=world?worldSizing.rounds:france?CDFranceCompetition.regularRounds(s):26,leagueSize=world?clubCount:france?CDFranceCompetition.members(s,CDFranceCompetition.leagueId(s)).length:14,clubPattern=world?{test:x=>typeof x==='string'&&/^club-(?:0|[1-9][0-9]{0,2})$/.test(x)&&Number(x.slice(5))<clubCount}:france?/^club-(?:[0-9]|[12][0-9])$/:/^club-(?:[0-9]|1[0-3])$/;saveCheck(saveObject(s)&&s.version===2,'Cette version de carrière n’est pas prise en charge.');saveCheck(saveInt(s.club,0,maxClub)&&saveInt(s.season,1,10000)&&saveInt(s.round,0,maxRound));saveCheck((world?['league','ended']:['league','barrage','semi','final','ended']).includes(s.phase));saveCheck(s.phase==='league'?s.round<rounds:s.round===rounds);saveCheck(TACTICS[s.tactic]&&TRAIN[s.training]);if(s.defence!==undefined)saveCheck(Object.keys(DEFENCES).includes(s.defence));if(s.difficulty!==undefined)saveCheck(Object.keys(DIFFICULTIES).includes(s.difficulty));if(s.physicalLoadVersion!==undefined)saveCheck(s.physicalLoadVersion===1);if(s.developmentFocusVersion!==undefined)saveCheck(s.developmentFocusVersion===1);if(s.recruitmentIntelVersion!==undefined)saveCheck(s.recruitmentIntelVersion===1);if(s.salaryDemandVersion!==undefined)saveCheck(s.salaryDemandVersion===1);if(s.satisfactionVersion!==undefined)saveCheck(s.satisfactionVersion===1);if(s.relationsVersion!==undefined)saveCheck(s.relationsVersion===1&&s.satisfactionVersion===1);if(s.objectivesVersion!==undefined)saveCheck(s.objectivesVersion===1&&s.satisfactionVersion===1);if(s.v39Version!==undefined)saveCheck(s.v39Version===1);if(s.integratedManagementVersion!==undefined)saveCheck(s.integratedManagementVersion===1&&saveObject(s.careerManagement));
if(s.seniorCalibrationVersion!==undefined)saveCheck(common&&(s.seniorCalibrationVersion===1||s.seniorCalibrationVersion===2&&s.worldMode!==undefined),'Barème senior incompatible avec la carrière.');
if(s.worldVersion!==undefined)saveCheck(s.worldVersion===1&&saveObject(s.worldManagement));
if(s.worldManagement!==undefined){
 const w=s.worldManagement;
 saveCheck(s.worldVersion===1&&saveObject(w)&&w.version===1&&saveArray(w.clubInfo,clubCount)&&w.clubInfo.length===clubCount&&
  saveArray(w.matches,180)&&saveArray(w.yearbook,15)&&saveArray(w.upgrades,30)&&saveArray(w.awards,15)&&
  saveInt(w.lastSeason,0,s.season)&&
  (w.champion===null||saveInt(w.champion,0,maxClub))&&
  (w.lastFinance===null||typeof w.lastFinance==='string'&&/^[1-9]\d{0,4}:(league|barrage|semi|final):\d{1,2}$/.test(w.lastFinance)));
 w.clubInfo.forEach((x,i)=>saveCheck(saveObject(x)&&x.id===i&&saveInt(x.reputation,0,100)&&
  saveInt(x.facilities,1,10)&&saveNumber(x.debt,0,1e12)&&saveInt(x.coachConfidence,0,100)&&
  saveInt(x.consecutiveLosses,0,20)&&saveInt(x.coachChanges,0,10000)));
 for(const m of w.matches)saveCheck(saveObject(m)&&saveInt(m.season,1,s.season)&&saveInt(m.round,0,maxRound)&&
  (world?['league','pool','r16','quarter','semi','final','access','barrage',...(worldRegistry.version>=2?['elimination']:[]),...(worldRegistry.version>=3?['third-place','promotion']:[]),...(worldRegistry.version===5?['relegation']:[])]:france?['league','barrage','semi','final','access']:['league','barrage','semi','final']).includes(m.phase)&&clubPattern.test(m.home)&&
  clubPattern.test(m.away)&&m.home!==m.away&&
  saveNumber(m.homeScore,0,1000)&&saveNumber(m.awayScore,0,1000));
 for(const y of w.yearbook){
  saveCheck(saveObject(y)&&saveInt(y.season,1,s.season)&&(y.champion===null||saveInt(y.champion,0,maxClub))&&
   saveArray(y.standings,clubCount)&&y.standings.length===clubCount&&
   new Set(y.standings.map(x=>x.id)).size===clubCount);
  y.standings.forEach(x=>saveCheck(saveObject(x)&&saveInt(x.id,0,maxClub)&&
   saveInt(x.position,1,clubCount)&&saveNumber(x.cash)&&saveInt(x.reputation,0,100)&&
   saveInt(x.facilities,1,10)&&saveNumber(x.debt,0,1e12)&&saveInt(x.coachRisk,0,100)));
 }
 for(const x of w.upgrades)saveCheck(saveObject(x)&&saveInt(x.season,1,s.season)&&
  saveInt(x.id,0,maxClub)&&saveInt(x.level,2,10)&&saveNumber(x.cost,0,1e9));
 for(const x of w.awards)saveCheck(saveObject(x)&&saveInt(x.season,1,s.season)&&
  saveId(x.id)&&typeof x.name==='string'&&x.name.length>0&&x.name.length<=120);
}
if(s.careerManagement!==undefined){
 const v=s.careerManagement;
 saveCheck(s.integratedManagementVersion===1&&saveObject(v)&&v.version===1&&
 CAREER_ACADEMY_LEVELS.includes(v.academyInvestment)&&saveNumber(v.academySpent,0,1e9)&&
 saveInt(v.academyWeeks,0,1000)&&saveInt(v.promotions,0,1000)&&saveInt(v.lastBoardRound,-1,maxRound)&&
 (v.lastAcademyWeek===null||typeof v.lastAcademyWeek==='string'&&/^[1-9]\d{0,4}:\d{1,5}$/.test(v.lastAcademyWeek))&&
 saveArray(v.boardHistory,24)&&saveArray(v.history,180));
 if(v.sponsor!==null)saveCheck(saveObject(v.sponsor)&&
 Object.prototype.hasOwnProperty.call(CAREER_SPONSORS,v.sponsor.key)&&v.sponsor.season===s.season);
 for(const x of v.boardHistory)saveCheck(saveObject(x)&&saveInt(x.season,1,s.season)&&
 saveInt(x.round,0,maxRound)&&saveInt(x.previous,0,100)&&saveInt(x.after,0,100)&&
 ['results','finances','youth','score'].every(k=>saveInt(x[k],0,100)));
 const eventIds=new Set();
 for(const x of v.history){
  saveCheck(saveObject(x)&&typeof x.id==='string'&&x.id.length>0&&x.id.length<=250&&
   !eventIds.has(x.id)&&['trophy','promotion','relegation','award','record','manager'].includes(x.type)&&
   typeof x.label==='string'&&x.label.length>0&&x.label.length<=160&&
   saveInt(x.season,1,s.season)&&typeof x.clubId==='string'&&clubPattern.test(x.clubId));
  eventIds.add(x.id);
 }
}

if(s.v39!==undefined){
 const v=s.v39;saveCheck(s.v39Version===1&&saveObject(v)&&v.version===1&&
  saveArray(v.audits,12)&&saveArray(v.medical,40)&&saveArray(v.bonds,20)&&
  saveNumber(v.cohesion,0,100)&&(v.leader===null||saveId(v.leader))&&
  [v.lastRecovery,v.lastBond,v.lastTalk].every(k=>k===null||typeof k==='string'&&/^[1-9]\d{0,4}:\d{1,5}$/.test(k)));
 for(const a of v.audits){
  saveCheck(saveObject(a)&&saveInt(a.season,1,s.season)&&saveInt(a.round,0,maxRound)&&
   saveInt(a.minute,0,240)&&typeof a.ok==='boolean'&&saveArray(a.players,23));
  for(const x of a.players)saveCheck(saveObject(x)&&saveId(x.id)&&
   saveNumber(x.minutes,0,240)&&saveNumber(x.credited,0,240)&&typeof x.ok==='boolean');
 }
 for(const m of v.medical)saveCheck(saveObject(m)&&saveInt(m.season,1,s.season)&&
  saveInt(m.round,0,maxRound)&&saveId(m.id)&&['training','match','recovery'].includes(m.kind)&&saveInt(m.weeks,0,52));
 for(const b of v.bonds)saveCheck(saveObject(b)&&saveId(b.a)&&saveId(b.b)&&b.a<b.b&&saveInt(b.score,0,100));
}
if(s.collectivePrepVersion!==undefined)saveCheck(s.collectivePrepVersion===1&&Object.prototype.hasOwnProperty.call(COLLECTIVE_FOCI,s.collectiveFocus));if(s.collectiveFocus!==undefined)saveCheck(Object.prototype.hasOwnProperty.call(COLLECTIVE_FOCI,s.collectiveFocus));saveCheck(typeof s.trained==='boolean'&&saveNumber(s.morale,0,100)&&saveNumber(s.trust,0,100));saveCheck(saveArray(s.clubs,clubCount)&&s.clubs.length===clubCount);
const professionalIds=new Set();function checkPlayer(p){if(p?.dev?.inSeasonGrowthSeason!==undefined)saveCheck(saveInt(p.dev.inSeasonGrowthSeason,1,s.season),'Saison de progression invalide.');validatePlayerPopulation(p,s);validateRosterProfile(p,s);if(common&&saveObject(p)&&(String(p.id).startsWith('lnr:')||Object.keys(p).some(k=>k.startsWith('lnr'))))validateCommonPlayer(p,s);saveCheck(saveObject(p)&&saveId(p.id)&&typeof p.name==='string'&&p.name.length>0&&p.name.length<120);if(p.appearanceBankVersion!==undefined)saveCheck(p.appearanceBankVersion===1||p.appearanceBankVersion===2,'Version de banque de portraits invalide.');if(p.appearanceId!==undefined)saveCheck(typeof p.appearanceId==='string'&&/^[A-Za-z0-9:_.-]{1,180}$/.test(p.appearanceId),'Identifiant d’apparence invalide.');saveCheck(saveInt(p.fam,0,8)&&POS.includes(p.pos)&&FAMILIES[POS.indexOf(p.pos)]===p.fam);saveCheck(saveInt(p.age,s.lnrMode!==undefined||common&&commonYoungPlayer(p,s)||p.academy===true&&s.academyGroupPolicy===3&&/^youth-\d+-\d+-\d+$/.test(p.id)?15:16,60)&&saveInt(p.rating,15,99)&&saveNumber(p.condition,0,100)&&saveInt(p.injury,0,52)&&saveInt(p.salary,0,100000));saveCheck(p.contractEnd==null||saveInt(p.contractEnd,1,10003));if(p.satisfaction!==undefined){const st=p.satisfaction;if(st.coachMeeting!==undefined){const c=st.coachMeeting;saveCheck(s.relationsVersion===1&&saveObject(c)&&saveInt(c.season,1,s.season)&&saveInt(c.week,0,s.economy.week)&&['ecouter','rassurer','clarifier'].includes(c.choice))}saveCheck(s.satisfactionVersion===1&&saveObject(st)&&st.version===1&&saveInt(st.score,20,95)&&saveInt(st.season,1,s.season)&&saveNumber(st.baseline,0,100000)&&saveArray(st.history,8));for(const h of st.history)saveCheck(saveObject(h)&&saveInt(h.season,1,s.season)&&saveInt(h.round,0,maxRound)&&['promise','kept','broken'].includes(h.status)&&saveNumber(h.minutes,0,240)&&Object.prototype.hasOwnProperty.call(PROMISE_MINUTES,h.target));if(st.promise!==null){const a=st.promise;saveCheck(saveObject(a)&&Object.prototype.hasOwnProperty.call(PROMISE_MINUTES,a.target)&&a.season===st.season&&saveInt(a.round,0,23)&&saveInt(a.completed,0,2)&&saveNumber(a.minutes,0,240))}}if(p.physicalLoad!==undefined)saveCheck(saveObject(p.physicalLoad)&&p.physicalLoad.version===1&&saveInt(p.physicalLoad.fatigue,0,100)&&Object.prototype.hasOwnProperty.call(PHYSICAL_PLANS,p.physicalLoad.plan));if(p.managerLoad!==undefined)saveCheck(saveObject(p.managerLoad)&&saveNumber(p.managerLoad.minutes,0,240)&&saveInt(p.managerLoad.streak));saveCheck(saveObject(p.skills)&&Object.keys(ATTR).every(k=>saveNumber(p.skills[k],15,99))&&saveNumber(p.skillBase,15,99));let d=p.dev;saveCheck(saveObject(d)&&saveNumber(d.potential,p.rating,99)&&saveNumber(d.xp,0,1)&&saveNumber(d.seasonStart,15,99)&&saveNumber(d.minutes,0,100000)&&saveInt(d.appearances,0,10000)&&saveNumber(d.careerMinutes,0,1e9)&&saveInt(d.retireAge,17,65)&&saveInt(d.lastYear)&&saveInt(d.decline,0,5)&&saveArray(d.history,12));d.history.forEach(h=>saveCheck(saveObject(h)&&saveInt(h.season,1)&&saveInt(h.age,s.lnrMode!==undefined||common&&commonYoungPlayer(p,s)||p.academy===true&&s.academyGroupPolicy===3&&/^youth-\d+-\d+-\d+$/.test(p.id)?15:16,60)&&saveNumber(h.start,15,99)&&saveNumber(h.end,15,99)&&saveNumber(h.minutes,0,100000)&&saveInt(h.appearances,0,10000)));if(d.specialization!==undefined){const sp=d.specialization;saveCheck(saveObject(sp)&&sp.version===1&&developmentFocusOptions(p).includes(sp.focus)&&saveNumber(sp.xp,0,DEVELOPMENT_FOCUS_XP_COST)&&saveObject(sp.bonuses));let spent=0;for(const [key,n] of Object.entries(sp.bonuses)){saveCheck(developmentFocusOptions(p).includes(key)&&key!==DEVELOPMENT_BALANCED&&saveInt(n,0,DEVELOPMENT_ATTRIBUTE_LIMIT));spent+=n}saveCheck(spent<=DEVELOPMENT_TOTAL_LIMIT)}}
function players(list,max=100){saveCheck(saveArray(list,max));const ids=new Set();list.forEach(p=>{checkPlayer(p);saveCheck(!ids.has(p.id),'Un joueur apparaît plusieurs fois dans le même effectif.');ids.add(p.id)});return ids}
if(s.lnrMode!==undefined)saveCheck(saveObject(s.lnrMode)&&s.lnrMode.version===1&&s.lnrMode.snapshot==='2026-10-31'&&s.lnrMode.scope==='top14'&&s.lnrMode.simulated===true);const customIdentities=customCompetitionIdentity(s);const lnrIdentities=s.lnrMode!==undefined;saveCheck(!lnrIdentities||typeof lnrGameClub==='function'&&LNR_TOP14.length===14);const legacyIdentities=s.clubs.every((c,i)=>saveObject(c)&&c.name===LEGACY_CLUB_NAMES[i]&&c.abbr===LEGACY_CLUB_ABBR[i]);
s.clubs.forEach((c,i)=>{saveCheck(saveObject(c)&&c.id===i&&(world?c.name===worldRegistry.clubs[i].name&&c.abbr===worldRegistry.clubs[i].abbr:france?c.name===CDFranceClubs.get(i).name&&c.abbr===CDFranceClubs.get(i).abbr:customIdentities?c.name===customIdentities.clubs[i].name&&c.abbr===customIdentities.clubs[i].abbr:lnrIdentities?c.name===lnrGameClub(i).name&&c.abbr===lnrGameClub(i).abbr:legacyIdentities?c.name===LEGACY_CLUB_NAMES[i]&&c.abbr===LEGACY_CLUB_ABBR[i]:c.name===CLUBS[i][0]&&c.abbr===CLUBS[i][1])&&c.color===(world?worldRegistry.clubs[i].color:france?CDFranceClubs.get(i).color:CLUBS[i][2]));if(c.morale!==undefined)saveCheck(saveNumber(c.morale,0,100));saveCheck(typeof c.stadium==='string'&&typeof c.goal==='string'&&saveNumber(c.base,0,100)&&saveNumber(c.cash));for(let k of ['points','played','won','drawn','lost','pf','pa','bonus'])saveCheck(saveNumber(c[k],k==='points'&&world?-10:0,10000));saveCheck(saveArray(c.form,world?maxRound:france?CDFranceCompetition.regularRounds(s,CDFranceCompetition.leagueId(s,c.id)):26)&&c.form.every(x=>['V','D','N'].includes(x)));let ids=players(c.players);ids.forEach(id=>{saveCheck(!professionalIds.has(id),'Un joueur appartient à plusieurs clubs.');professionalIds.add(id)})});

if(s.aiRosterVersion!==undefined)saveCheck([1,2].includes(s.aiRosterVersion)&&saveObject(s.aiRoster));
if(s.aiRoster!==undefined){
 const a=s.aiRoster;
 saveCheck([1,2].includes(s.aiRosterVersion)&&saveObject(a)&&a.version===s.aiRosterVersion&&
  saveInt(a.lastContracts,0,s.season)&&saveInt(a.lastIntake,0,s.season)&&
  (a.lastRecruitment===null||typeof a.lastRecruitment==='string'&&(france?/^\d{1,5}:(0|15)$/:/^\d{1,5}:(0|13)$/).test(a.lastRecruitment))&&
  saveArray(a.events,AI_ROSTER_MAX_EVENTS)&&saveArray(a.reports,AI_ROSTER_MAX_REPORTS)&&
  saveArray(a.academies,maxClub)&&a.academies.length===maxClub);
 saveCheck(a.academyAgingVersion===undefined||(world&&a.academyAgingVersion===1),'Version du vieillissement des centres invalide.');
 validatePopulationPolicy(s);
 const reportKeys=new Set();
 for(const r of a.reports){
  const key=r.season+':'+r.clubId;
  saveCheck(saveObject(r)&&saveInt(r.clubId,0,maxClub)&&(r.clubId!==s.club||s.managerMobilityVersion===1&&r.season<=s.managerMobility?.currentFrom)&&
   saveInt(r.season,1,s.season)&&!reportKeys.has(key));
  reportKeys.add(key);
  for(const key of ['renewed','released','retired','recruited','promoted','emergency'])
   saveCheck(saveInt(r[key],0,100));
  // Transferts entre clubs gérés (carrières mondiales) : compteurs et stratégie de la saison.
  for(const key of ['bought','sold'])saveCheck(r[key]===undefined||world&&saveInt(r[key],0,100),'Transferts de club invalides.');
  saveCheck(r.strategy===undefined||world&&['vedettes','formateur','rajeunissement','vente','equilibre',...(s.clubDirections!==undefined?['reconstruction','maintien']:[])].includes(r.strategy),'Stratégie de club invalide.');
  saveCheck(saveNumber(r.fees,0,1e10));
 }
 for(const e of a.events)saveCheck(saveObject(e)&&saveInt(e.clubId,0,maxClub)&&
  (e.clubId!==s.club||s.managerMobilityVersion===1&&e.season<=s.managerMobility?.currentFrom)&&saveInt(e.season,1,s.season)&&
  (['renew','release','retire','recruit','promote','emergency'].includes(e.kind)||world&&e.kind==='sell')&&
  saveId(e.playerId)&&typeof e.name==='string'&&e.name.length>0&&e.name.length<120&&
  saveInt(e.salary,0,100000)&&saveNumber(e.fee,0,1e9));
 const seenClubs=new Set(),academyIds=new Set();
 for(const entry of a.academies){
  saveCheck(saveObject(entry)&&saveInt(entry.clubId,0,maxClub)&&entry.clubId!==s.club&&
   !seenClubs.has(entry.clubId)&&saveInt(entry.intakeSeason,0,s.season)&&
   saveArray(entry.players,75));
  seenClubs.add(entry.clubId);
  for(const p of entry.players){
   checkPlayer(p);
   saveCheck(p.academy===true&&p.age<=21&&p.contractEnd==null&&
    !professionalIds.has(p.id)&&!academyIds.has(p.id));
   academyIds.add(p.id);
  }
 }
 saveCheck(seenClubs.size===maxClub);
 for(const p of s.market)saveCheck(!academyIds.has(p.id));
 for(const p of s.economy.freeAgents)saveCheck(!academyIds.has(p.id));
 for(const p of s.development.academy)saveCheck(!academyIds.has(p.id));
}
const own=new Set(s.clubs[s.club].players.map(p=>p.id));function refs(a,n,ids=own,nullable=false){saveCheck(saveArray(a,n)&&a.length===n);a.forEach(id=>saveCheck(nullable&&id===null||saveId(id)&&ids.has(id)));saveCheck(new Set(a.filter(Boolean)).size===a.filter(Boolean).length)}refs(s.lineup,15,own,true);saveCheck(saveArray(s.reserves,8));refs(s.reserves,s.live?s.reserves.length:8,own,true);s.lineup.forEach((id,i)=>saveCheck(id===null||slotEligible(s.clubs[s.club].players.find(p=>p.id===id),i)));if(!s.live)s.reserves.forEach((id,i)=>saveCheck(id===null||benchEligible(s.clubs[s.club].players.find(p=>p.id===id),i)));saveCheck(new Set([...s.lineup,...s.reserves].filter(Boolean)).size===[...s.lineup,...s.reserves].filter(Boolean).length);
function pair(p){saveCheck(saveArray(p,2)&&p.length===2&&p.every(x=>saveInt(x,0,maxClub))&&p[0]!==p[1])}saveCheck(saveArray(s.schedule,rounds)&&s.schedule.length===rounds);if(world){for(const round of s.schedule){saveCheck(saveArray(round,1199));round.forEach(pair);}}else{const fixtures=new Set();for(let round of s.schedule){saveCheck(saveArray(round,leagueSize/2)&&round.length===leagueSize/2);const clubs=new Set();round.forEach(p=>{pair(p);p.forEach(i=>clubs.add(i));fixtures.add(p.join('-'))});saveCheck(clubs.size===leagueSize,'Le calendrier est incohérent.')}saveCheck(fixtures.size===rounds*leagueSize/2,'Le calendrier contient des doublons.');}
function result(r){saveCheck(saveObject(r));pair(r.pair);for(let k of ['score','tries'])saveCheck(saveArray(r[k],2)&&r[k].length===2&&r[k].every(n=>saveInt(n,0,1000)));saveCheck(r.tries.every((n,i)=>n*5<=r.score[i]))}
function stats(a){saveCheck(saveArray(a,2)&&a.length===2);a.forEach(st=>{saveCheck(saveObject(st));Object.keys(makeStats()).forEach(k=>saveCheck(saveNumber(st[k],0,1e7)))})}
saveCheck(saveArray(s.history,world?(worldSaveLimits(s)?.maxMatches??1200):france?433:187));s.history.forEach(r=>{result(r);saveCheck(r.champExtra===undefined||world&&worldRegistry.version===5&&typeof CDWorldChampMatch!=='undefined'&&CDWorldChampMatch.isFixture(r),'Preuve Champ hors de son édition.');saveCheck(saveInt(r.round,0,maxRound)&&(world?['league','pool','r16','quarter','semi','final','access','barrage',...(worldRegistry.version>=2?['elimination']:[]),...(worldRegistry.version>=3?['third-place','promotion']:[]),...(worldRegistry.version===5?['relegation']:[])]:france?['league','barrage','semi','final','access']:['league','barrage','semi','final']).includes(r.phase));if(r.stats)stats(r.stats)});saveCheck(saveArray(s.news,100)&&s.news.every(x=>typeof x==='string'));saveCheck(saveArray(s.ledger,100)&&s.ledger.every(x=>saveObject(x)&&typeof x.title==='string'&&saveNumber(x.amount)));players(s.market,aiRosterPopulationActive(s)?aiRosterFreeAgentLimit(s):100);
if(!world&&s.phase!=='league'){saveCheck(saveObject(s.playoff)&&saveArray(s.playoff.pairs,2)&&saveArray(s.playoff.seeds,6)&&s.playoff.seeds.length===6&&new Set(s.playoff.seeds).size===6&&s.playoff.seeds.every(i=>saveInt(i,0,maxClub))&&saveArray(s.playoff.log,5));s.playoff.pairs.forEach(pair);saveCheck(s.playoff.log.every(x=>typeof x==='string'));if(s.phase==='ended')saveCheck(typeof s.ending==='string')}
const e=s.economy,d=s.development;if(e.aiRecruitmentWindow!==undefined){saveCheck(typeof e.aiRecruitmentWindow==='string'&&(france?/^\d{1,5}:(0|15)$/:/^\d{1,5}:(0|13)$/).test(e.aiRecruitmentWindow));const [y,round]=e.aiRecruitmentWindow.split(':').map(Number);saveCheck(y<=s.season&&y>=1&&(france?[0,15]:[0,13]).includes(round))}saveCheck(saveObject(e)&&e.version===1&&saveInt(e.week)&&saveInt(e.settled)&&saveObject(e.talks)&&saveObject(e.listings)&&saveArray(e.offers,100)&&saveArray(e.transfers,80));const freeAgentIds=players(e.freeAgents,aiRosterFreeAgentLimit(s));if(aiRosterPopulationActive(s)){for(const p of e.freeAgents)saveCheck(!professionalIds.has(p.id)&&p.contractEnd==null,'Un joueur du vivier est déjà sous contrat, ou son contrat libre est incohérent.');const byId=new Map(e.freeAgents.map(p=>[p.id,p]));for(const p of s.market)saveCheck(p.age>=18&&freeAgentIds.has(p.id)&&savedPlayerEqual(p,byId.get(p.id)),'Identité du marché différente du vivier disponible.');}if(e.objectives!==undefined||e.objectiveHistory!==undefined){
 saveCheck(s.objectivesVersion===1&&saveArray(e.objectives,42)&&saveArray(e.objectiveHistory,80));
 const ids=new Set();
 for(const o of e.objectives){
  saveCheck(saveObject(o)&&saveId(o.playerId)&&own.has(o.playerId)&&!ids.has(o.playerId));
  ids.add(o.playerId);
  saveCheck(['minutes','appearances'].includes(o.metric)&&['proposed','active'].includes(o.status)&&
   saveInt(o.rounds,3,6)&&saveInt(o.target,1,o.rounds*OBJECTIVE_METRICS[o.metric])&&
   saveInt(o.requested,1,o.rounds*OBJECTIVE_METRICS[o.metric])&&['agree','counter'].includes(o.reply)&&
   saveInt(o.completed,0,o.rounds-1)&&saveNumber(o.observed,0,480)&&
   o.season===s.season&&saveInt(o.startRound,0,23)&&o.startRound+o.rounds<=26&&
   saveInt(o.lastRound,-1,maxRound)&&saveNumber(o.baselineMinutes,0,100000)&&
   saveInt(o.baselineAppearances,0,10000));
  if(o.revision!==null){
   const v=o.revision,remaining=o.rounds-o.completed;
   saveCheck(o.status==='active'&&saveObject(v)&&saveInt(v.requested,o.observed,o.observed+remaining*OBJECTIVE_METRICS[o.metric])&&
    saveInt(v.target,o.observed,v.requested)&&['agree','counter'].includes(v.reply));
  }
 }
 const kinds=['proposed','accepted','revision-proposed','revised','met','missed','expired'];
 for(const h of e.objectiveHistory)saveCheck(saveObject(h)&&saveInt(h.season,1,s.season)&&
  saveInt(h.round,0,maxRound)&&saveId(h.playerId)&&kinds.includes(h.kind)&&
  ['minutes','appearances'].includes(h.metric)&&saveInt(h.rounds,3,6)&&
  saveInt(h.target,1,h.rounds*OBJECTIVE_METRICS[h.metric])&&saveNumber(h.observed,0,480));
}
if(e.relationLog!==undefined){saveCheck(s.relationsVersion===1&&saveArray(e.relationLog,60));for(const x of e.relationLog){saveCheck(saveObject(x)&&saveInt(x.season,1,s.season)&&saveInt(x.round,0,maxRound)&&saveId(x.playerId)&&['offer','signed','coach'].includes(x.kind)&&saveInt(x.attempt,1,3)&&saveNumber(x.amount,0,100000)&&saveNumber(x.minimum,0,100000)&&saveInt(x.years,0,3));if(x.kind==='coach')saveCheck(['ecouter','rassurer','clarifier'].includes(x.detail)&&x.status==='done'&&x.years===0);else saveCheck(['recruit','renew'].includes(x.detail)&&['ready','counter','withdrawn','signed'].includes(x.status)&&x.years>=1)}}if(e.moodLog!==undefined){saveCheck(s.relationsVersion===1&&saveArray(e.moodLog,20));for(const x of e.moodLog)saveCheck(saveObject(x)&&saveInt(x.season,1,s.season)&&saveInt(x.round,0,maxRound)&&saveNumber(x.before,0,100)&&saveNumber(x.after,0,100)&&['victory','loss','draw'].includes(x.cause))}for(let [id,v] of Object.entries(e.listings))saveCheck(saveId(id)&&own.has(id)&&v===true);e.offers.forEach(o=>saveCheck(saveObject(o)&&saveId(o.id)&&own.has(o.playerId)&&saveInt(o.buyer,0,maxClub)&&o.buyer!==s.club&&saveNumber(o.fee,0)&&saveInt(o.expires)));e.transfers.forEach(t=>saveCheck(saveObject(t)&&saveInt(t.season,1)&&saveInt(t.round,0,maxRound)&&typeof t.text==='string'));
for(let [key,t] of Object.entries(e.talks)){saveCheck(saveId(key)&&saveObject(t)&&saveId(t.id)&&['renew','recruit'].includes(t.kind)&&saveInt(t.week)&&saveInt(t.attempts,1,3)&&saveInt(t.years,1,3)&&saveInt(t.salary,1000,100000)&&saveInt(t.acceptedSalary,1000,100000)&&['ready','counter','withdrawn','signed'].includes(t.status)&&typeof t.message==='string'&&saveInt(t.end,1,10003)&&saveNumber(t.fee,0))}
saveCheck(saveObject(d)&&d.version===1&&(d.academyPotentialVersion===undefined||d.academyPotentialVersion===1)&&saveInt(d.intakeSeason)&&saveInt(d.rolledSeason)&&saveArray(d.retired,80));const youth=players(d.academy,75);youth.forEach(id=>saveCheck(!professionalIds.has(id)));d.retired.forEach(p=>saveCheck(saveObject(p)&&saveId(p.id)&&typeof p.name==='string'&&typeof p.club==='string'&&saveInt(p.age,17,65)&&saveInt(p.season,1)&&saveNumber(p.minutes,0,1e9)));if(aiRosterPopulationActive(s)){const active=new Set([...professionalIds,...freeAgentIds,...youth,...s.aiRoster.academies.flatMap(a=>a.players.map(p=>p.id))]);for(const p of d.retired)saveCheck(!active.has(p.id),'Un joueur retraité figure encore dans une population active.');}
if(s.lastReport){if(s.lastReport.collectivePreparation!==undefined)validateCollectiveSnapshot(s.lastReport.collectivePreparation,s);validatePreparation(s.lastReport,s);if(s.lastReport.tacticalStats!==undefined)validateTacticalStats(s.lastReport.tacticalStats);if(s.lastReport.uncontestedScrums!==undefined)saveCheck(saveArray(s.lastReport.uncontestedScrums,2)&&s.lastReport.uncontestedScrums.length===2&&s.lastReport.uncontestedScrums.every(n=>saveInt(n,0,100)));result(s.lastReport);stats(s.lastReport.stats);saveCheck(['Sec','Vent','Pluie'].includes(s.lastReport.weather)&&saveArray(s.lastReport.analysis,20)&&s.lastReport.analysis.every(x=>typeof x==='string')&&saveArray(s.lastReport.subs,200))}
if(s.live){const l=s.live;result(l);if(l.aiLevel!==undefined)saveCheck(Object.keys(DIFFICULTIES).includes(l.aiLevel));if(l.balanceVersion!==undefined)saveCheck([1,2].includes(l.balanceVersion));if(l.physicalLoadVersion!==undefined)saveCheck(l.physicalLoadVersion===1);if(l.quickTapVersion!==undefined)saveCheck(l.quickTapVersion===1);if(l.essaisVersion!==undefined)saveCheck(l.essaisVersion===1);if(l.penalitesVersion!==undefined)saveCheck(l.penalitesVersion===1);if(l.quickTaps!==undefined)saveCheck(l.quickTapVersion===1&&saveArray(l.quickTaps,2)&&l.quickTaps.length===2&&l.quickTaps.every(n=>saveInt(n,0,200)));if(l.developmentFocusVersion!==undefined)saveCheck(l.developmentFocusVersion===1);if(l.collectivePrepVersion!==undefined){saveCheck(l.collectivePrepVersion===1);validateCollectiveSnapshot(l.collectivePreparation,s)}else saveCheck(l.collectivePreparation===undefined);if(l.physicalLoadRecorded!==undefined)saveCheck(l.physicalLoadVersion===1&&typeof l.physicalLoadRecorded==='boolean');if(l.numericalAiVersion!==undefined)saveCheck(l.numericalAiVersion===1&&l.balanceVersion===2&&l.tacticalVersion===1&&l.managerMemory!==undefined);if(l.penaltyPolicies!==undefined)saveCheck(saveArray(l.penaltyPolicies,2)&&l.penaltyPolicies.length===2&&l.penaltyPolicies.every(p=>Object.keys(PENALTY_POLICIES).includes(p)));if(l.managerMemory!==undefined){saveCheck(saveArray(l.managerMemory,2)&&l.managerMemory.length===2);l.managerMemory.forEach(m=>{saveCheck(saveObject(m)&&saveNumber(m.lastSub,-10,l.flowVersion===1?240:80)&&saveNumber(m.lastReview,0,l.flowVersion===1?240:80));if(l.numericalAiVersion===1){saveCheck(saveInt(m.lastCardDiff,-15,15));saveCheck(m.cardBase===null||saveObject(m.cardBase)&&Object.keys(TACTICS).includes(m.cardBase.attack)&&Object.keys(DEFENCES).includes(m.cardBase.defence))}else saveCheck(m.lastCardDiff===undefined&&m.cardBase===undefined)})}saveCheck(l.engine===2&&saveInt(l.minute,0,l.flowVersion===1?240:80)&&typeof l.finished==='boolean'&&typeof l.paused==='boolean'&&typeof l.halftime==='boolean');saveCheck(l.pair.includes(s.club)&&l.userSide===l.pair.indexOf(s.club)&&['Sec','Vent','Pluie'].includes(l.weather)&&saveInt(l.possession,0,1)&&saveNumber(l.territory,0,100));saveCheck(saveArray(l.tactics,2)&&l.tactics.length===2&&l.tactics.every(k=>TACTICS[k]));saveCheck(saveArray(l.events,1000)&&l.events.every(e=>saveObject(e)&&saveNumber(e.min,0,l.flowVersion===1?240:80)&&(e.period===undefined||[1,2].includes(e.period))&&typeof e.text==='string'));stats(l.stats);saveCheck(saveArray(l.sheets,2)&&l.sheets.length===2);l.sheets.forEach((sh,i)=>{saveCheck(saveObject(sh));const ids=new Set(s.clubs[l.pair[i]].players.map(p=>p.id));refs(sh.on,15,ids,true);refs(sh.initial,15,ids,true);sh.on.forEach((id,j)=>saveCheck(id===null||slotEligible(s.clubs[l.pair[i]].players.find(p=>p.id===id),j)));saveCheck(saveArray(sh.bench,l.rulesProfile?23:8)&&saveArray(sh.used,23)&&saveArray(sh.cards,15)&&saveArray(sh.sentOff,15)&&saveObject(sh.minutes)&&saveObject(sh.yellowCounts)&&saveInt(sh.subs,0,l.frontRowVersion===1?100:l.rulesProfile?32:8));for(let a of [sh.bench,sh.used,sh.sentOff]){saveCheck(new Set(a).size===a.length);a.forEach(id=>saveCheck(saveId(id)&&ids.has(id)))}if(!l.rulesProfile)saveCheck(sh.bench.every(id=>!sh.used.includes(id)));sh.cards.forEach(c=>saveCheck(saveObject(c)&&ids.has(c.id)&&saveNumber(c.until,0,l.flowVersion===1?260:100)));for(let [id,n] of Object.entries(sh.minutes))saveCheck(ids.has(id)&&saveNumber(n,0,l.flowVersion===1?240:120));for(let [id,n] of Object.entries(sh.yellowCounts))saveCheck(ids.has(id)&&saveInt(n,0,2));});saveCheck(saveArray(l.subs,l.frontRowVersion===1?200:l.rulesProfile?64:16));l.subs.forEach(x=>saveCheck(saveObject(x)&&saveInt(x.side,0,1)&&saveNumber(x.minute,0,l.flowVersion===1?240:80)&&saveId(x.in)&&saveId(x.out)&&x.minute<=l.minute));if(l.devBaseline){saveCheck(saveArray(l.devBaseline,2)&&l.devBaseline.length===2);l.devBaseline.forEach((b,i)=>{saveCheck(saveObject(b));for(let [id,n] of Object.entries(b))saveCheck(s.clubs[l.pair[i]].players.some(p=>p.id===id)&&saveNumber(n,0,l.flowVersion===1?240:120))})}validateMatchRules(l,s);validateRestartState(l,s);validateActionScenes(l,s);validateTacticalPlans(l);validateLivePlaybooks(l);validatePreparation(l,s,true);if(l.flowVersion===undefined)saveCheck(l.finished===(l.minute===80));else validateFlowState(l,s)}validateManager(s);validateManagerMobility(s);if(s.pressConference!==undefined){const pc=s.pressConference;saveCheck(saveObject(pc)&&saveArray(pc.history,500),'Historique de conférence invalide.');saveCheck(pc.history.every(h=>saveObject(h)&&saveId(h.id)&&saveInt(h.season,1,1000)&&saveInt(h.week,0,100)&&/^r[0-4]$/.test(h.answerId)&&h.season<=s.season),'Historique de conférence incohérent.');if(pc.week!==undefined)saveCheck(saveInt(pc.week,0,100));if(pc.season!==undefined)saveCheck(saveInt(pc.season,1,s.season));if(pc.club!==undefined)saveCheck(saveInt(pc.club,0,s.clubs.length-1));}
if(s.pressRelations!==undefined){saveCheck(typeof CDPressRelations==='object','Module presse requis pour cette sauvegarde.');CDPressRelations.validate(s.pressRelations);const p=s.pressRelations;saveCheck(/^club-[0-9]+$/.test(p.clubId)&&p.season<=s.season&&p.week<=saveRoundLimit(s)&&p.stories.length<=40&&p.history.length<=500&&p.used.length<=500&&p.stories.every(e=>saveObject(e)&&CDPressRelations.topics.includes(e.topic)&&CDPressRelations.tones.includes(e.tone)),'Carrière presse incohérente.')}if(france)CDFranceSaveValidation.validate(s);if(world){saveCheck(s.phase!=='ended'||typeof s.ending==='string');CDWorldCareer.validate(s);}return s}
function saveChecksum(state){const text=JSON.stringify(state),multiply=Math.imul;let h=2166136261;for(let i=0;i<text.length;i++){h^=text.charCodeAt(i);h=multiply(h,16777619)}return (h>>>0).toString(16).padStart(8,'0')}
// Même empreinte, sur un texte déjà sérialisé (createSaveDocument) : évite une seconde sérialisation de l'état.
function saveChecksumText(text){const multiply=Math.imul;let h=2166136261;for(let i=0;i<text.length;i++){h^=text.charCodeAt(i);h=multiply(h,16777619)}return (h>>>0).toString(16).padStart(8,'0')}
function champPortableSave(s){return worldCareerActive(s)&&CDWorldCareer.edition?.(s)?.version===5}
function saveDocumentFits(doc,cap){
 const text=JSON.stringify(doc);
 return text.length<=cap&&saveUtf8Bytes(text)<=cap;
}
function compactChampDocument(doc){
 const s=doc.state,agents=new Map(s.economy.freeAgents.map(p=>[p.id,JSON.stringify(p)]));
 const market=s.market.map(p=>agents.get(p.id)===JSON.stringify(p)?p.id:p);
 return market.some(p=>typeof p==='string')?{...doc,exportVersion:2,state:{...s,market}}:null;
}
function expandChampMarket(s){
 const message='Référence de marché Champ invalide ou dupliquée.';
 const limit=aiRosterFreeAgentLimit(s);
 saveCheck(saveArray(s.market,limit)&&saveArray(s.economy?.freeAgents,limit),message);
 const agents=new Map(),seen=new Set();
 for(const p of s.economy.freeAgents){
  saveCheck(saveObject(p)&&saveId(p.id)&&!agents.has(p.id),message);
  agents.set(p.id,p);
 }
 saveCheck(s.market.some(p=>typeof p==='string'),message);
 return s.market.map(p=>{
  const ref=typeof p==='string',id=ref?p:p?.id;
  saveCheck(saveId(id)&&!seen.has(id)&&(!ref||agents.has(id)),message);
  seen.add(id);
  return ref?JSON.parse(JSON.stringify(agents.get(id))):p;
 });
}
// Export v3 (carrières mondiales) : les champs de référence copiés tels quels
// depuis les registres du jeu (profil mondial, traits initiaux, fiche d'effectif)
// sont remplacés par la marque `true`, à leur place ; la lecture les reconstruit
// avant l'empreinte et la validation. Un champ modifié reste écrit : la
// réduction est sans perte, et une marque sans référence est refusée.
const SAVE_REFERENCE_FIELDS=Object.freeze(['worldProfile','hiddenTraitsV2','rosterProfile']);
function saveReferencePlayers(s){
 return [...(s.clubs||[]).flatMap(c=>Array.isArray(c?.players)?c.players:[]),...(Array.isArray(s.development?.academy)?s.development.academy:[]),
  ...(Array.isArray(s.aiRoster?.academies)?s.aiRoster.academies:[]).flatMap(a=>Array.isArray(a?.players)?a.players:[]),
  ...(Array.isArray(s.economy?.freeAgents)?s.economy.freeAgents:[]),...(Array.isArray(s.market)?s.market:[])].filter(p=>saveObject(p)&&typeof p.id==='string');
}
function saveReferenceValue(s,p,field){
 if(field==='rosterProfile')return rosterFoundationRegistry(s)?.players?.[p.id];
 const registry=typeof CDWorldCareer.edition==='function'?CDWorldCareer.edition(s)?.registry:null;
 if(!registry)return undefined;
 if(field==='worldProfile')return registry.worldProfiles?.[p.id]??registry.compatibilityAliases?.[p.id]?.worldProfile;
 if(p.id.startsWith('world:')||p.worldRatingsVersion!==undefined)return typeof CDWorldCareer.sourcePlayer==='function'?CDWorldCareer.sourcePlayer(s,p.id)?.hiddenTraitsV2:undefined;
}
function compactSaveReferences(s){
 let removed=0;const cache=new Map();
 const text=(field,p,ref)=>{const key=field+'\u0001'+p.id;if(!cache.has(key))cache.set(key,JSON.stringify(ref));return cache.get(key);};
 for(const p of saveReferencePlayers(s))for(const field of SAVE_REFERENCE_FIELDS){
  if(p[field]===undefined)continue;
  const ref=saveReferenceValue(s,p,field);
  if(ref!==undefined&&JSON.stringify(p[field])===text(field,p,ref)){p[field]=true;removed++;}
 }
 return removed;
}
function expandSaveReferences(s){
 for(const p of saveReferencePlayers(s))for(const field of SAVE_REFERENCE_FIELDS){
  if(p[field]!==true)continue;
  const ref=saveReferenceValue(s,p,field);
  saveCheck(ref!==undefined,'Référence de joueur absente des registres du jeu.');
  p[field]=JSON.parse(JSON.stringify(ref));
 }
 return s;
}
function compactSaveDocument(doc){
 if(!worldCareerActive(doc.state))return null;
 // Le marché visible renvoie au vivier par identifiant, pour toutes les éditions mondiales en v3.
 const base=compactChampDocument(doc)??doc;
 const state=JSON.parse(JSON.stringify(base.state));
 if(!compactSaveReferences(state)&&base===doc)return null;
 // Contrôle aller-retour : la lecture doit retrouver exactement l'état exporté.
 const check=JSON.parse(JSON.stringify(state));expandSaveReferences(check);
 if(check.market.some(p=>typeof p==='string'))check.market=expandChampMarket(check);
 if(saveChecksum(check)!==doc.checksum)return null;
 return {...doc,exportVersion:3,state};
}
function createSaveDocument(state=S){
 saveCheck(!!state,'Aucune carrière à exporter.');
 const snapshot=JSON.parse(JSON.stringify(state));
 if(snapshot.live&&!snapshot.live.finished)snapshot.live.paused=true;
 validateCareer(snapshot);
 // Texte de l'état validé, sérialisé une seule fois : empreinte, preuve des recettes et taille du document.
 const text=JSON.stringify(snapshot);
 const doc={format:SAVE_FORMAT,exportVersion:1,exportedAt:new Date().toISOString(),checksum:saveChecksumText(text),state:snapshot};
 if(typeof nativeSaveProof==='function')nativeSaveProof(text);// recettes : texte de l'état avant réduction
 if(!worldCareerActive(snapshot))return doc;
 const cap=(typeof nativeSaveBytes==='number'?nativeSaveBytes:worldSaveLimits(snapshot)?.saveBytes)??WORLD_SAVE_LIMIT;
 // Taille exacte de JSON.stringify(doc) sans le re-sérialiser : enveloppe ASCII (état remplacé par « 0 ») plus l'état.
 const envelope=JSON.stringify({...doc,state:0}).length-1;
 if(envelope+text.length<=cap&&envelope+saveUtf8Bytes(text)<=cap)return doc;
 if(champPortableSave(snapshot)){
  const compact=compactChampDocument(doc);
  if(compact&&saveDocumentFits(compact,cap))return compact;
 }
 const reduced=compactSaveDocument(doc);
 if(reduced&&saveDocumentFits(reduced,cap))return reduced;
 saveError('Le fichier est trop volumineux ('+(cap/1048576)+' Mio UTF-8 maximum pour cette édition).');
}
function parseSaveDocument(text){
 saveCheck(typeof text==='string'&&text.length<=CHAMP_WORLD_SAVE_LIMIT,'Le fichier est trop volumineux (24 Mio UTF-8 maximum).');
 const bytes=saveUtf8Bytes(text);
 saveCheck(bytes<=CHAMP_WORLD_SAVE_LIMIT,'Le fichier est trop volumineux (24 Mio UTF-8 maximum).');
 let doc;
 try{doc=JSON.parse(text)}catch(e){
  saveCheck(bytes<=WORLD_SAVE_LIMIT,'Le fichier est trop volumineux (16 Mio UTF-8 maximum pour une carrière mondiale).');
  saveCheck(text.length<=SAVE_LIMIT&&bytes<=SAVE_LIMIT,'Le fichier est trop volumineux (8 Mio UTF-8 maximum).');
  saveError('Le fichier JSON est incomplet ou illisible.');
 }
 const cap=worldCareerActive(doc?.state)?(worldSaveLimits(doc.state)?.saveBytes??WORLD_SAVE_LIMIT):SAVE_LIMIT;
 saveCheck(bytes<=cap,'Le fichier est trop volumineux ('+(cap/1048576)+' Mio UTF-8 maximum pour cette édition).');
 saveCheck(saveObject(doc)&&doc.format===SAVE_FORMAT,'Ce fichier n’est pas un export Cadrage Débordement.');
 const compact=doc.exportVersion===2&&champPortableSave(doc.state);
 const reduced=doc.exportVersion===3&&saveObject(doc.state)&&worldCareerActive(doc.state);
 saveCheck(doc.exportVersion===1||compact||reduced,'Cette version d’export n’est pas prise en charge.');
 saveCheck(typeof doc.exportedAt==='string'&&Number.isFinite(Date.parse(doc.exportedAt))&&typeof doc.checksum==='string');
 if(reduced){
  expandSaveReferences(doc.state);
  if(Array.isArray(doc.state.market)&&doc.state.market.some(p=>typeof p==='string'))doc.state.market=expandChampMarket(doc.state);
 }
 if(compact)doc.state.market=expandChampMarket(doc.state);
 // L'empreinte porte sur le fichier tel qu'exporté : la validation peut migrer
 // une ancienne carrière (identifiants de journalistes renommés, par exemple).
 const exportedChecksum=saveChecksum(doc.state);
 validateCareer(doc.state);
 saveCheck(exportedChecksum===doc.checksum,'Le fichier a été modifié ou endommagé depuis son export.');
 doc.checksum=saveChecksum(doc.state);// empreinte de l'état vérifié, contrôlée à la confirmation
 validatedSaveDocuments.set(doc,doc.checksum);
 return doc;
}
// Documents validés par parseSaveDocument, avec l'empreinte de leur état vérifié : la confirmation ne refait pas
// la validation complète (≈ 2 s sur une grande carrière Monde) quand l'empreinte prouve que l'état n'a pas changé.
const validatedSaveDocuments=new WeakMap();
function saveFileName(doc){return `Cadrage-Debordement-${doc.state.clubs[doc.state.club].abbr}-S${doc.state.season}-${doc.state.phase==='league'?'J'+(doc.state.round+1):doc.state.phase.toUpperCase()}-${doc.exportedAt.replace(/[-:]/g,'').slice(0,15)}.json`}
function downloadSaveDocument(doc){const text=JSON.stringify(doc,null,doc.exportVersion===1?2:0),blob=new Blob([text],{type:'application/json;charset=utf-8'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=saveFileName(doc);document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000)}
function exportCareer(){try{const doc=createSaveDocument();downloadSaveDocument(doc);try{gameStorage.setItem('bdt-exported-at',doc.exportedAt)}catch(e){}if(view==='saves')render();toast('Export créé. Conservez le fichier JSON pour reprendre sur un autre ordinateur.')}catch(e){toast('Export impossible : '+e.message)}}
function openImportPicker(){mainMenuPendingSlotId=null;const input=$('#save-import');input.value='';input.click()}
async function chooseImportFile(input){const file=input.files?.[0],token=++saveReadToken;if(!file)return;try{saveCheck(file.size<=SAVE_LIMIT,'Le fichier est trop volumineux (8 Mio UTF-8 maximum).');const doc=parseSaveDocument(await file.text());if(token!==saveReadToken)return;pendingSave=doc;showImportReview(false)}catch(e){if(token===saveReadToken)toast(e.message)}finally{input.value=''}}
function showImportReview(recovery=false){if(!pendingSave)return;const s=pendingSave.state,c=s.clubs[s.club];modal=`<div class="modalback"><section class="modal contractmodal" role="dialog" aria-modal="true" aria-label="Vérifier la sauvegarde"><span class="tag">${recovery?'COPIE DE SECOURS':'IMPORT VÉRIFIÉ'}</span><h2 style="margin-top:12px">${c.name}</h2><div class="row"><span>Carrière</span><strong>Saison ${(typeof libelleSaison==='function'?libelleSaison:String)(s.season)} · ${s.phase==='league'?'Journée '+(s.round+1):s.phase==='ended'?'Saison terminée':'Phases finales'}</strong></div><div class="row"><span>Effectif professionnel</span><strong>${c.players.length} joueurs</strong></div><div class="row"><span>Trésorerie</span><strong>${money(c.cash)}</strong></div><p>${s.live?`Match ${s.live.finished?'terminé à valider':'à reprendre en pause'} : ${s.clubs[s.live.pair[0]].abbr} ${s.live.score.join(' – ')} ${s.clubs[s.live.pair[1]].abbr} · ${s.live.minute}′.`:'Aucun match en cours.'}</p><div class="notice">${S?'Cette carrière remplacera la carrière ouverte. Une copie de celle-ci sera conservée sur ce navigateur avant le remplacement.':'La carrière sera installée sur ce navigateur.'} Le fichier importé reste sur votre ordinateur.</div><div class="contractactions"><button onclick="cancelSaveImport()">Annuler</button><button class="primary" onclick="confirmSaveImport()">${recovery?'Restaurer cette copie':'Remplacer et reprendre la carrière'}</button></div></section></div>`;render()}
function cancelSaveImport(){pendingSave=null;mainMenuPendingSlotId=null;modal=null;render()}
function confirmSaveImport(){if(!pendingSave)return false;let incoming;try{const checked=saveChecksum(pendingSave.state);saveCheck(checked===pendingSave.checksum,'Le fichier a été modifié depuis sa vérification.');if(validatedSaveDocuments.get(pendingSave)!==checked)validateCareer(pendingSave.state);incoming=JSON.parse(JSON.stringify(pendingSave.state));normalizeOppositionSnapshot(incoming);if(incoming.live&&!incoming.live.finished)incoming.live.paused=true;if(S)gameStorage.setItem('bdt-before-import',typeof nativeBeforeImportText==='string'?nativeBeforeImportText:JSON.stringify(createSaveDocument(S)));gameStorage.setItem('bdt-v1',JSON.stringify(incoming))}catch(e){lastSaveError=true;toast('Restauration annulée. La carrière ouverte est conservée. Vérifiez le fichier et l’espace de stockage du navigateur.');return false}clearInterval(timer);S=incoming;let slotFailure=false;try{if(typeof CDMenuSlots!=='undefined')CDMenuSlots.setActive(mainMenuPendingSlotId||null)}catch(e){slotFailure=true}mainMenuPendingSlotId=null;setupManager();pendingSave=null;modal=null;loadSaveFailure='';lastSaveError=slotFailure;view=S.live?'match':'dashboard';entryScreen='game';render();toast('Carrière restaurée. Les matchs en cours reprennent en pause.');return true}
function backupDocument(){try{const text=gameStorage.getItem('bdt-before-import');return text?parseSaveDocument(text):null}catch(e){return null}}
function reviewBackup(){pendingSave=backupDocument();if(!pendingSave){toast('Aucune copie de secours valide disponible sur ce navigateur.');return}showImportReview(true)}
function exportBackup(){try{const doc=backupDocument();saveCheck(!!doc,'Aucune copie de secours disponible.');downloadSaveDocument(doc.exportVersion===3?compactSaveDocument(doc)||doc:doc.exportVersion===2?compactChampDocument(doc):doc)}catch(e){toast(e.message)}}
function savesView(){const backup=backupDocument();let date=gameStorage.offline?'Aucun export enregistré sur cet ordinateur':'Aucun export enregistré sur ce navigateur';try{const last=gameStorage.getItem('bdt-exported-at');if(last&&Number.isFinite(Date.parse(last)))date=new Date(last).toLocaleString('fr-FR')}catch(e){}return heading('EMPORTER SA CARRIÈRE','Vos sauvegardes.','Un fichier JSON pour changer d’ordinateur ou conserver un point de retour.')+`${offlineStorageInfo()}<div class="grid"><div class="stack"><div class="card"><h2>Exporter la carrière</h2><p>${club().name} · Saison ${(typeof libelleSaison==='function'?libelleSaison:String)(S.season)} · ${label()}. L’export contient les joueurs, contrats, finances, jeunes, résultats et le match en cours.</p><button class="primary" onclick="exportCareer()">Télécharger la sauvegarde JSON ↓</button><p class="help">Dernier export : ${date}. Si un match est en cours, le fichier permettra de le reprendre en pause.</p></div><div class="card"><h2>Importer une carrière</h2><p>Choisissez un fichier exporté depuis Cadrage Débordement. Son contenu est vérifié avant de vous présenter la carrière à restaurer.</p><button class="dark" onclick="openImportPicker()">Choisir un fichier JSON ↑</button><p class="help">8 Mio UTF-8 maximum. La carrière actuelle reste ouverte tant que vous n’avez pas confirmé le remplacement.</p></div></div><div class="stack"><div class="card"><h2>Revenir après un import</h2><p>${backup?`Copie disponible : ${backup.state.clubs[backup.state.club].name} · saison ${(typeof libelleSaison==='function'?libelleSaison:String)(backup.state.season)}.`:'Une copie de la carrière remplacée sera créée ici lors du prochain import.'}</p><div class="contractactions"><button onclick="reviewBackup()" ${backup?'':'disabled'}>Examiner et restaurer la copie</button><button class="small" onclick="exportBackup()" ${backup?'':'disabled'}>Télécharger la copie ↓</button></div></div><div class="card"><h2>À conserver de votre côté</h2><p>${gameStorage.offline?'La sauvegarde automatique et la copie de secours restent dans le dossier de données de cette application.':'La sauvegarde automatique et la copie de secours restent dans ce navigateur.'} Leur effacement supprime ces copies locales : gardez un fichier exporté pour protéger votre progression.</p><p>Le fichier importé est traité sur votre appareil. Il n’y a pas de synchronisation automatique entre ordinateurs.</p>${lastSaveError?'<div class="notice danger">La sauvegarde locale a échoué. Exportez votre carrière avant de quitter le jeu.</div>':''}</div></div></div>`}
function bootSavedCareer(){if(loadSaveFailure&&loadedSaveText){try{gameStorage.setItem('bdt-recovery-invalid',loadedSaveText)}catch(e){}}try{migrateGame();if(S)validateCareer(S)}catch(e){if(loadedSaveText){try{gameStorage.setItem('bdt-recovery-invalid',loadedSaveText)}catch(ignore){}}S=null;loadSaveFailure='La sauvegarde locale est illisible. Vous pouvez importer un fichier exporté pour retrouver votre carrière.'}validatingStartup=false;if(S)save();if(S?.live)view='match';render()}


function validatePopulationPolicy(s){
 const a=s.aiRoster;
 if(a.version===1){saveCheck(a.population===undefined,'Politique de population inattendue dans une ancienne carrière.');return}
 const p=a.population;
 saveCheck(saveObject(p)&&Object.keys(p).length===3&&saveInt(p.referenceAccessible,1,20000)&&saveInt(p.lastPoolSeason,0,s.season)&&saveArray(p.history,20),'Politique de population invalide.');
 let last=0;
 for(const r of p.history){
  saveCheck(saveObject(r)&&Object.keys(r).length===5&&saveInt(r.season,last+1,s.season),'Historique du vivier invalide.');last=r.season;
  for(const key of ['graduated','emerged','departed'])saveCheck(saveInt(r[key],0,20000),'Flux du vivier invalide.');
  saveCheck(saveInt(r.available,0,aiRosterFreeAgentLimit(s)),'Stock du vivier invalide.');
 }
}
function validatePlayerPopulation(p,s){
 if(!saveObject(p))return;
 const small=String(p.id).startsWith('small-');
 if(small)saveCheck(aiRosterPopulationActive(s)&&p.population?.origin==='small-club'&&p.age>=18,'Provenance des petits clubs invalide.');
 if(p.population===undefined)return;
 const origin=p.population;
 if(origin?.origin==='small-club'){const id=/^small-(\d+)-(\d+)-(\d+)$/.exec(p.id);saveCheck(id&&Number(id[1])===origin.season&&AI_POPULATION_DEPTH.some(([slot])=>slot===Number(id[2]))&&POS[Number(id[2])]===p.pos,'Identité des petits clubs invalide.')}
 saveCheck(aiRosterPopulationActive(s)&&saveObject(origin)&&Object.keys(origin).length===5&&origin.version===1&&
  ['academy','small-club','released'].includes(origin.origin)&&saveInt(origin.season,1,s.season)&&
  saveInt(origin.availableSince,origin.season,s.season)&&
  (origin.origin==='academy'?saveInt(origin.clubId,0,s.clubs.length-1):origin.clubId===null),'Provenance du joueur invalide.');
}

function savedPlayerEqual(a,b){
 if(a===b)return true;
 if(a===null||b===null||typeof a!=='object'||typeof b!=='object'||Array.isArray(a)!==Array.isArray(b))return false;
 const keys=Object.keys(a);return keys.length===Object.keys(b).length&&keys.every(k=>Object.prototype.hasOwnProperty.call(b,k)&&savedPlayerEqual(a[k],b[k]));
}
