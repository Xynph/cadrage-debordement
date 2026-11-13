'use strict';

// V27 : charge physique fictive, distincte de la condition instantanée.
// Modèle : 0..100 ; la récupération ne modifie que la condition, déjà utilisée par skill/fitScore.
const PHYSICAL_PLANS={collective:'Suivre le collectif',repos:'Récupération',normal:'Normale',intense:'Intensive'};
function physicalState(p){return p.physicalLoad&&p.physicalLoad.version===1?p.physicalLoad:{version:1,fatigue:0,plan:'collective'}}
function ensurePhysicalLoad(p){if(!p.physicalLoad)p.physicalLoad={version:1,fatigue:0,plan:'collective'};return p.physicalLoad}
function physicalLoadValue(p){return physicalState(p).fatigue}
function physicalPlan(p){return physicalState(p).plan}
function physicalModeFor(p,ci){if(p.injury)return 'repos';if(ci!==S.club)return physicalLoadValue(p)>=55||p.condition<60?'repos':'normal';const selected=physicalPlan(p);return selected==='collective'?S.training:selected}
function physicalTrainingOutcome(p,mode){const injured=!!p.injury,selected=injured?'repos':mode,current=physicalLoadValue(p);const fatigue=clamp(current+(selected==='repos'?-20:selected==='normal'?-10:6),0,100);const base=injured?15:selected==='repos'?30:selected==='normal'?20:8;const reduction=Math.min(10,Math.floor(fatigue/10));return {fatigue,condition:clamp(p.condition+Math.max(0,base-reduction),injured?0:20,100)}}
function applyPhysicalTraining(p,mode){const next=physicalTrainingOutcome(p,mode),state=ensurePhysicalLoad(p);state.fatigue=next.fatigue;p.condition=next.condition;return next}
function setPhysicalTraining(id,plan){if(!S||S.live||S.trained||S.phase==='ended'||!Object.prototype.hasOwnProperty.call(PHYSICAL_PLANS,plan))return false;const p=player(id);if(!p)return false;ensurePhysicalLoad(p).plan=plan;save();render();return true}
function physicalLoadPreviewText(p){if(S.trained)return 'Séance déjà appliquée';const next=physicalTrainingOutcome(p,physicalModeFor(p,S.club));return 'Après séance : '+next.condition+' % de condition · charge '+next.fatigue+'/100'}
function physicalStaffAdvice(){const high=starters().filter(p=>physicalLoadValue(p)>=45).sort((a,b)=>physicalLoadValue(b)-physicalLoadValue(a));if(high.length)return high.slice(0,2).map(p=>p.name+' ('+physicalLoadValue(p)+'/100)').join(', ')+' : charge cumulée élevée. Envisagez récupération ou rotation avant le prochain match.';return mean(starters().map(p=>p.condition))<70?'Votre XV est fatigué. Privilégiez la récupération et donnez du temps de jeu aux remplaçants.':'Le groupe est prêt à travailler. Ajustez individuellement la charge des titulaires dans Effectif & 23.'}
function physicalTrainingPreview(){const selected=starters().filter(p=>physicalLoadValue(p)>=35).sort((a,b)=>physicalLoadValue(b)-physicalLoadValue(a)).slice(0,3);return '<p class="help">Définissez un mode collectif ici, puis des exceptions par joueur dans Effectif & 23. Projection avant match, hors minutes futures.</p>'+(selected.length?'<div class="physical-rotation-preview"><strong>À surveiller :</strong> '+selected.map(p=>p.name+' ('+physicalLoadValue(p)+'/100, '+physicalLoadPreviewText(p)+')').join(' · ')+'</div>':'')}
function recordPhysicalMatchLoad(l){if(l.physicalLoadVersion!==1||l.physicalLoadRecorded)return false;l.physicalLoadRecorded=true;for(let side=0;side<2;side++){const sheet=l.sheets[side];for(const id of sheet.used){const p=matchPlayer(l,side,id),minutes=Math.min(80,Math.max(0,sheet.minutes[id]||0));if(!p||!minutes)continue;const state=ensurePhysicalLoad(p);state.fatigue=clamp(state.fatigue+Math.round(minutes*18/80),0,100)}}return true}


// V29 : spécialisation individuelle par qualité, adaptée aux exigences du poste.
// La ressource d'XP est divisée : elle n'est jamais allouée simultanément et en totalité
// à rating ET à la qualité ciblée. Tous les coefficients sont fictifs et calibrables.
const DEVELOPMENT_BALANCED='equilibre';
const DEVELOPMENT_FOCUS_SHARE=.5;
const DEVELOPMENT_FOCUS_XP_COST=.5;
const DEVELOPMENT_ATTRIBUTE_LIMIT=4;
const DEVELOPMENT_TOTAL_LIMIT=8;
const DEVELOPMENT_COLLECTIVE_LINK={
 conquete:['scrum','lineout','power'],
 defence:['tackle','discipline','stamina'],
 pied:['kick','goal','mental']
};
function developmentFocusOptions(p){
 const w=ROLE_WEIGHTS[p.fam]||ROLE_WEIGHTS[7];
 return [DEVELOPMENT_BALANCED,...new Set([...Object.keys(w),'stamina'])];
}
function developmentFocusValue(p){return p.dev?.specialization?.version===1?p.dev.specialization.focus:DEVELOPMENT_BALANCED}
function ensureSpecialization(p){
 ensureDevelopment(p);
 if(!p.dev.specialization)p.dev.specialization={version:1,focus:DEVELOPMENT_BALANCED,xp:0,bonuses:{}};
 return p.dev.specialization;
}
function developmentFocusRecommendation(p){
 const weights=ROLE_WEIGHTS[p.fam]||ROLE_WEIGHTS[7];
 return Object.entries(weights).sort((a,b)=>b[1]-a[1]||a[0].localeCompare(b[0]))[0][0];
}
function autoDevelopmentFocus(p,ci){
 if(ci===null||ci===undefined||ci===S.club||p.dev?.specialization)return;
 // L'IA suit les mêmes parts de progression et limites, sans bonus caché.
 ensureSpecialization(p).focus=developmentFocusRecommendation(p);
}
function setDevelopmentFocus(id,focus){
 if(!S||S.live||S.trained||S.phase==='ended')return false;
 const p=club().players.find(q=>q.id===id)||S.development.academy.find(q=>q.id===id);
 if(!p||!developmentFocusOptions(p).includes(focus))return false;
 const s=ensureSpecialization(p);
 if(s.focus===focus)return true;
 s.focus=focus;s.xp=0; // Pas de réaffectation opportuniste des XP partiellement acquis.
 save();if(modal&&modal.includes("setDevelopmentFocus('"+id+"'"))inspectCareerPlayer(id);else render();return true;
}
function focusedBonus(p,k){return p.dev?.specialization?.version===1?(p.dev.specialization.bonuses[k]||0):0}
function focusedBonusTotal(s){return Object.values(s.bonuses).reduce((sum,n)=>sum+n,0)}
function focusedGrowthAllowed(p){
 const s=p.dev?.specialization;
 if(!s||s.version!==1||s.focus===DEVELOPMENT_BALANCED||p.rating>=p.dev.potential)return false;
 const k=s.focus,points=s.bonuses[k]||0;
 return Object.prototype.hasOwnProperty.call(ATTR,k)&&
  developmentFocusOptions(p).includes(k)&&points<DEVELOPMENT_ATTRIBUTE_LIMIT&&
  focusedBonusTotal(s)<DEVELOPMENT_TOTAL_LIMIT&&
  p.skills[k]+p.rating-p.skillBase+points<99;
}
function growthFitnessFactor(p){return clamp(1-physicalLoadValue(p)/250,.65,1)}
function developmentCollectiveFactor(p,ci){
 if(ci===null||ci===undefined||S?.collectivePrepVersion!==1)return 1;
 const focus=developmentFocusValue(p),collective=collectiveFocusForClub(ci);
 return DEVELOPMENT_COLLECTIVE_LINK[collective]?.includes(focus)&&collectiveSpecialist(p,collective)?1.08:1;
}
function focusedProgressDetails(p){
 const s=p.dev?.specialization;
 const entries=s?Object.entries(s.bonuses).filter(([,value])=>value>0):[];
 return entries.map(([k,value])=>ATTR[k]+' +'+value).join(' · ')||'Aucun point ciblé encore acquis';
}
function developmentFocusSelector(p){
 const selected=developmentFocusValue(p),locked=S.live||S.trained||S.phase==='ended';
 const choices=developmentFocusOptions(p).map(k=>'<option value="'+k+'"'+(k===selected?' selected':'')+'>'+(k===DEVELOPMENT_BALANCED?'Équilibré (progression générale)':ATTR[k])+'</option>').join('');
 return '<label class="development-focus-control">Objectif individuel (poste : '+p.pos+')<select aria-label="Objectif de développement de '+visualEscape(p.name)+'" onchange="setDevelopmentFocus(\''+p.id+'\',this.value)" '+(locked?'disabled':'')+'>'+choices+'</select></label><p class="help">Répartit une même réserve d’expérience entre niveau général et qualité choisie (1 point de qualité pour 0,5 XP ciblée, plafond +4 par qualité). La fatigue V27 freine l’apprentissage ; une préparation V28 alignée peut le favoriser. '+focusedProgressDetails(p)+'.</p>';
}

// Fictional career curves: ceilings apply to the underlying rating, not the displayed role note.
function ensureDevelopment(p){if(p.dev)return p;const h=seedHash(p.id),young=p.age<=22,mid=p.age<=26;let margin=young?8+h%14:mid?4+h%9:p.age<=29?1+h%5:h%3;if(p.id.startsWith('academy-'))margin=10+h%9;p.dev={potential:clamp(p.rating+margin,p.rating,99),xp:0,seasonStart:p.rating,minutes:0,appearances:0,careerMinutes:0,history:[],retireAge:Math.max(p.age+1,(p.fam<=3?35:34)+h%5),lastYear:0,decline:0};return p}
function potentialAtRole(p){ensureDevelopment(p);return roleNote({...p,rating:p.dev.potential})}
function ageGrowth(p){return p.age<=22?1.4:p.age<=26?1:p.age<=29?.5:p.age<=31?.15:0}
function growPlayer(p,xp,allowFocus=true){
 ensureDevelopment(p);
 // V12: activity/training feeds the single annual V11 curve, not legacy rating XP.
 if(p.lnrRatingsVersion===1||p.worldRatingsVersion===1&&typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(S)&&CDWorldCareer.sourcePlayerKnown(p.id)){
  if(Number.isFinite(xp)&&xp>0)p.dev.xp=clamp(p.dev.xp+xp,0,.99);
  return 0;
 }
 if(!Number.isFinite(xp)||xp<=0||p.rating>=p.dev.potential){
  if(p.rating>=p.dev.potential){p.dev.xp=0;if(p.dev.specialization)p.dev.specialization.xp=0}
  return 0;
 }
 ensureSkills(p);
 const s=p.dev.specialization,focused=allowFocus&&focusedGrowthAllowed(p);
 const before=p.rating;
 const planned=allowFocus&&typeof CDYouthDevelopment!=='undefined'&&typeof CDYouthDevelopment.growthShare==='function'?CDYouthDevelopment.growthShare(S,p,allowFocus):null;
 const share=focused?([0,.25,.5].includes(planned)?planned:DEVELOPMENT_FOCUS_SHARE):0;
 // Conservateur : 1 XP total = (1-share) XP général + share XP ciblé.
 p.dev.xp+=xp*(1-share);
 if(focused)s.xp+=xp*share;
 while(p.dev.xp>=1&&p.rating<p.dev.potential){p.rating++;p.dev.xp-=1}
 if(focused&&p.rating<p.dev.potential){
  while(s.xp>=DEVELOPMENT_FOCUS_XP_COST&&focusedGrowthAllowed(p)){
   s.bonuses[s.focus]=(s.bonuses[s.focus]||0)+1;s.xp-=DEVELOPMENT_FOCUS_XP_COST;
  }
  if(!focusedGrowthAllowed(p))s.xp=0;
 }
 if(p.rating>=p.dev.potential){p.dev.xp=0;if(s)s.xp=0}
 return p.rating-before;
}
function developmentTraining(p,mode,ci=null){ensureDevelopment(p);if(p.injury||mode==='repos')return;autoDevelopmentFocus(p,ci);const amount=mode==='intense'?.10:.055;const focus=developmentFocusValue(p)!==DEVELOPMENT_BALANCED;growPlayer(p,amount*ageGrowth(p)*(p.condition<50?.5:1)*growthFitnessFactor(p)*(focus?developmentCollectiveFactor(p,ci):1))}
function recordDevelopmentMatch(l){if(l.developmentRecorded)return;l.developmentRecorded=true;for(let side=0;side<2;side++){const s=l.sheets[side];for(let id of s.used){const p=matchPlayer(l,side,id);if(!p)continue;ensureDevelopment(p);const minutes=Math.max(0,(s.minutes[id]||0)-(l.devBaseline?.[side]?.[id]||0));if(!minutes)continue;p.dev.minutes+=minutes;p.dev.careerMinutes+=minutes;p.dev.appearances++;growPlayer(p,minutes/80*.12*ageGrowth(p)*Math.max(.5,p.condition/100)*growthFitnessFactor(p),l.developmentFocusVersion===1)}}}
// Sporting outcomes from the FFR/LNR 2024–25 centre evaluation, ranked within
// each division. PREM highlights Sale and Saracens for converting U18s into
// first-team players, and Bath for the impact of its academy graduates.
// The weights are game balance; the keys are the anonymised catalogue codes.
const ACADEMY_TRAINING_WEIGHT={
 TCX:4,BER:4,LOX:4,CVX:4,GAX:4,AGX:4,ACV:4,BCV:4,
 LCX:2,MGX:2,BNR:2,MLX:2,BOX:2,CCX:2,
 LNX:4,MIX:4,BAV:2
};
// Qualité des fournées (décision de Léo du 12/11/2026) : en plus de la stature et de la
// tradition formatrice du club, la note « jeunesse » du pays, les installations du centre
// et le responsable de la formation déplacent les paliers de potentiel. Valeurs inventées,
// la France sert de référence neutre pour ne pas changer l'équilibre déjà validé.
const ACADEMY_COUNTRY_YOUTH={FR:0,NZ:0,ZA:0,IE:-.5,ENG:-.5,GB:-1,AU:-1,FJ:-1,JP:-1.5,IT:-1.5,GE:-1.5};
function academyClubLeague(club){
 const leagues=S?.worldMode?.leagues;if(!leagues||!Number.isInteger(club?.id))return null;
 return Object.keys(leagues).find(id=>leagues[id]?.members?.includes(club.id))??null;
}
function academyCountryBonus(club){
 if(!club?.country)return 0;
 const league=academyClubLeague(club);
 const key=club.country==='GB'&&(league==='prem'||league==='champ')?'ENG':club.country;
 return ACADEMY_COUNTRY_YOUTH[key]??-1;
}
function academyFacilitiesBonus(club){
 const world=typeof worldClub==='function'&&S?.worldManagement&&Number.isInteger(club?.id)?worldClub(club.id):null;
 const shared=Number.isFinite(world?.facilities)?clamp(world.facilities-2,-2,2):0;
 const own=club?.id===S?.club&&Number.isInteger(S?.v78to81?.facilities)?clamp(S.v78to81.facilities,0,3)*.5:0;
 return shared+own;
}
function academyFormationStaffBonus(club){
 const people=S?.staffCareer?.version===1&&Array.isArray(S.staffCareer.people)?S.staffCareer.people.flat():[];
 const levels=people.filter(p=>p?.clubId===club?.id&&p.role==='formation'&&Number.isFinite(p.level)).map(p=>p.level);
 return levels.length?clamp((Math.max(...levels)-60)/10,-1.5,1.5):0;
}
function academyRecruitmentWeight(club){
 const stature=clamp(Math.floor((club.base-65)/7),0,2);
 const training=S?.commonDatabase?(ACADEMY_TRAINING_WEIGHT[club.abbr]??0):0;
 const extra=academyCountryBonus(club)+academyFacilitiesBonus(club)+academyFormationStaffBonus(club);
 return clamp(Math.round((Math.min(5,stature+training)+extra)*2)/2,0,6);
}
function academyPotential(p,club=null){
 // The interface shows the potential at the player's position, including the role profile.
 // Draw that target first, then convert it to the general ceiling used for progression.
 const draw=seedHash(p.id+':potential'),percentile=draw%100,variation=draw>>>8;
 const weight=club?academyRecruitmentWeight(club):0;
 const ordinary=club?30-2*weight:25, promising=club?84-2*weight:79, exceptional=club?98-weight:97;
 let target;
 if(percentile<ordinary)target=64+variation%9;
 else if(percentile<promising)target=73+variation%10;
 else if(percentile<exceptional)target=83+variation%7;
 else target=91+variation%4;
 return Math.min(99,p.rating+Math.max(4,target-roleNote(p)));
}
function normalizeAcademyPotential(s){
 const development=s.development;
 if(development.academyPotentialVersion===1)return false;
 const academies=[development.academy,
  ...(s.aiRoster?.academies??[]).map(center=>center.players),
  ...(s.nativeAcademy?.centers??[]).flatMap(center=>center.players?[center.players]:[])];
 for(const academy of academies)for(const player of academy){
  if(!player.academy||!/^youth-\d+-\d+-\d+$/.test(player.id)||player.attributesV2!==undefined||
   player.lnrRatingsVersion!==undefined||player.worldRatingsVersion!==undefined||player.rosterProfile!==undefined)continue;
  const oldPotential=player.dev?.potential;
  if(!Number.isInteger(oldPotential)||!Number.isInteger(player.skillBase))continue;
  const oldBaseline=76+seedHash(player.id)%19;
  if(oldPotential<oldBaseline)continue;
  const earned=oldPotential-oldBaseline;
  // Reconstruct the starting role without letting accumulated XP reduce its own ceiling.
  const birth={...player,rating:player.skillBase,dev:null};
  const floor=player.rating+(oldPotential>player.rating?1:0);
  player.dev.potential=Math.min(oldPotential,Math.max(floor,academyPotential(birth)+earned));
 }
 development.academyPotentialVersion=1;
 return true;
}
// Identité des jeunes générés en carrière mondiale (décision de Léo du 12/11/2026) : origine
// tirée selon le pays du club, avec un mélange réaliste, et nom dans le style de cette origine.
// Noms inventés par combinaison ; même table que native/engine/player-facts.cjs (éligibilité).
const YOUTH_HERITAGE={
 FRA:[['FRA',84],['FIJ',3],['GEO',3],['TGA',2],['RSA',2],['POR',2],['SAM',1],['ENG',1],['ARG',1],['NZL',1]],
 ENG:[['ENG',80],['RSA',4],['SAM',3],['TGA',3],['IRE',3],['FIJ',2],['SCO',2],['NZL',2],['WAL',1]],
 SCO:[['SCO',82],['ENG',8],['RSA',4],['NZL',3],['IRE',3]],
 WAL:[['WAL',85],['ENG',7],['SAM',3],['RSA',3],['IRE',2]],
 IRE:[['IRE',88],['ENG',4],['NZL',3],['RSA',3],['SAM',2]],
 ITA:[['ITA',84],['ARG',8],['RSA',4],['NZL',2],['ROU',2]],
 RSA:[['RSA',94],['NAM',3],['ZIM',3]],
 NZL:[['NZL',72],['SAM',12],['TGA',9],['FIJ',5],['ENG',2]],
 AUS:[['AUS',72],['TGA',8],['SAM',8],['FIJ',6],['NZL',6]],
 FIJ:[['FIJ',100]],GEO:[['GEO',100]],
 JPN:[['JPN',86],['TGA',6],['NZL',4],['SAM',2],['KOR',2]],
};
const YOUTH_NAMES={
 ENG:{first:['Alfie','Archie','Ben','Callum','Charlie','Dan','Ethan','Fraser','George','Harry','Jack','Jamie','Joe','Josh','Kieran','Luke','Max','Oscar','Sam','Toby','Will'],last:['Ashworth','Barnes','Bradley','Carter','Clarke','Davies','Ellis','Fletcher','Hadley','Hughes','Kemp','Lawson','Marsh','Norris','Pearce','Rowe','Shaw','Thornton','Walker','Whitfield','Yates']},
 SCO:{first:['Alasdair','Callum','Cameron','Craig','Euan','Fergus','Fraser','Hamish','Iain','Jamie','Lewis','Lachlan','Murray','Rory','Ross','Ruaridh','Scott','Stuart'],last:['Baird','Cameron','Dunbar','Ferguson','Forsyth','Gillies','Henderson','Kerr','MacLean','MacLeod','Munro','Paterson','Ritchie','Sinclair','Strachan','Urquhart']},
 WAL:{first:['Aled','Cai','Dafydd','Dewi','Dylan','Emyr','Gethin','Gruffydd','Huw','Iestyn','Ioan','Owain','Rhodri','Rhys','Sion','Steffan','Tomos'],last:['Bevan','Davies','Edwards','Evans','Griffiths','Howells','Hughes','Jenkins','Lewis','Lloyd','Morgan','Parry','Powell','Price','Pritchard','Rees','Thomas','Williams']},
 IRE:{first:['Cian','Ciarán','Conor','Darragh','Dylan','Eoin','Fionn','Jack','Luke','Niall','Oisín','Rónán','Ruairí','Seán','Tadhg'],last:['Brennan','Byrne','Carroll','Doherty','Doyle','Fitzgerald','Gallagher','Kavanagh','Keane','Lynch','McCarthy','Murphy','Nolan','O’Brien','O’Connor','Quinlan','Walsh']},
 ITA:{first:['Alessandro','Andrea','Davide','Edoardo','Federico','Filippo','Giacomo','Lorenzo','Luca','Marco','Matteo','Niccolò','Pietro','Riccardo','Simone','Tommaso'],last:['Benedetti','Bianchi','Cattaneo','Colombo','Conti','De Santis','Ferrari','Galli','Lombardi','Mancini','Marchetti','Moretti','Rinaldi','Romano','Russo','Vitale']},
 ARG:{first:['Agustín','Bautista','Facundo','Felipe','Franco','Gonzalo','Ignacio','Joaquín','Juan Cruz','Lautaro','Mateo','Nicolás','Santiago','Santino','Tomás'],last:['Acosta','Benítez','Castro','Domínguez','Fernández','Giménez','Herrera','Ledesma','Medina','Ortiz','Paz','Quiroga','Ríos','Sosa','Vázquez']},
 RSA:{first:['Andile','Bongi','Cobus','Dewald','Ethan','Francois','Hanro','Jaco','Jandré','Kwagga','Lwazi','Morné','Ruan','Sibusiso','Thando','Wian','Zander'],last:['Botha','Coetzee','Dlamini','du Plessis','du Toit','Fourie','Jansen','Khumalo','Le Roux','Mahlangu','Marais','Mostert','Nel','Ndlovu','Pretorius','Steyn','van der Merwe','Venter']},
 NZL:{first:['Aidan','Blake','Caleb','Finn','Hamish','Harrison','Jordan','Kahu','Liam','Manaia','Nikau','Rangi','Riley','Tama','Wiremu','Zac'],last:['Anderson','Brown','Campbell','Harawira','Hohaia','Kereama','Matiu','McKenzie','Ngata','Paewai','Ruatapu','Smith','Taylor','Te Kani','Walker','Wilson']},
 AUS:{first:['Bailey','Brodie','Cooper','Darcy','Fletcher','Harrison','Hayden','Jake','Kurtis','Lachlan','Mitchell','Nathan','Ryan','Tate','Zane'],last:['Bennett','Collins','Cooke','Edmonds','Fraser','Gallagher','Hartley','Kingston','Mason','Palmer','Reid','Simmons','Turner','Waldron','Whitlock']},
 SAM:{first:['Afa','Faitala','Iosefa','Leilua','Losi','Malo','Pele','Sione','Talalelei','Tasi','Tavita','Tusi'],last:['Afoa','Fa’asavalu','Faleolo','Leiataua','Lemalu','Mataia','Paepae','Sapolu','Seiuli','Tuilagi','Tupou','Va’a']},
 TGA:{first:['Ahoia','Fifita','Hufanga','Lisiate','Lotu','Mosese','Paula','Sione','Siosaia','Tevita','Viliami'],last:['Fifita','Halaifonua','Havili','Kioa','Lolohea','Ma’afu','Moala','Taufa','Tonga’uiha','Vainikolo','Vaipulu']},
 FIJ:{first:['Apisalome','Eroni','Isoa','Jone','Josua','Kini','Leone','Mesake','Peceli','Ratu','Semi','Tevita','Viliame'],last:['Botia','Cavubati','Dakuwaqa','Masilevu','Nakarawa','Radradra','Ratuniyarawa','Seniloli','Tuisova','Vakatawa','Volavola','Waqaniburotu']},
 GEO:{first:['Beka','Davit','Giorgi','Irakli','Lasha','Levan','Luka','Mamuka','Nika','Otar','Sandro','Tornike','Vano'],last:['Abashidze','Bregvadze','Chikvaidze','Gelashvili','Gogichashvili','Japaridze','Kakhiani','Lomidze','Mamukashvili','Natroshvili','Tsiklauri','Zhvania']},
 JPN:{first:['Daiki','Haruki','Haruto','Hiroto','Kaito','Kenta','Kota','Riku','Ryota','Shota','Sota','Takumi','Yuma','Yuto'],last:['Fujita','Hayashi','Inoue','Kato','Kimura','Kobayashi','Matsumoto','Mori','Nakamura','Saito','Sato','Shimizu','Takahashi','Yamada','Yamamoto']},
 POR:{first:['Afonso','Diogo','Duarte','Gonçalo','João','Martim','Rodrigo','Tiago','Tomás'],last:['Almeida','Carvalho','Costa','Ferreira','Gomes','Martins','Pereira','Rodrigues','Santos']},
 ROU:{first:['Andrei','Alexandru','Ionuț','Mihai','Radu','Ștefan','Vlad'],last:['Ionescu','Lungu','Mocanu','Popa','Radulescu','Stan','Tudor']},
 KOR:{first:['Ji-hoon','Min-jun','Seo-jun','Do-yun','Ha-jun'],last:['Kim','Lee','Park','Choi','Jung']},
};
YOUTH_NAMES.NAM=YOUTH_NAMES.RSA;YOUTH_NAMES.ZIM=YOUTH_NAMES.RSA;
function youthHash(text){return Array.from(String(text)).reduce((n,letter)=>Math.imul(n^letter.charCodeAt(0),16777619),2166136261)>>>0}
// Même découpage que clubCountry() du worker (identifiants de la base mondiale).
function youthClubNation(club){
 if(!club)return null;
 if(club.country==='GB'){if(club.id===42)return 'IRE';if(club.id===44||club.id===45)return 'SCO';if(club.id>=46&&club.id<=49)return 'WAL';return 'ENG'}
 return {FR:'FRA',IE:'IRE',IT:'ITA',ZA:'RSA',GE:'GEO',NZ:'NZL',AU:'AUS',FJ:'FIJ',JP:'JPN'}[club.country]??null;
}
function youthHeritage(id,anchor){
 const table=YOUTH_HERITAGE[anchor];if(!table)return anchor;
 let roll=youthHash(id+':rugby-origin')%100;
 for(const [nation,weight] of table){if(roll<weight)return nation;roll-=weight}
 return anchor;
}
function youthName(id,h,club){
 const world=typeof worldActive==='function'&&worldActive();
 const nation=world?youthHeritage(id,youthClubNation(club)):null,pool=nation&&nation!=='FRA'?YOUTH_NAMES[nation]:null;
 if(!pool)return FIRST[h%FIRST.length]+' '+LAST[Math.floor(h/31)%LAST.length];
 return pool.first[h%pool.first.length]+' '+pool.last[Math.floor(h/31)%pool.last.length];
}
// Noms déjà portés dans un club : effectif pro et centre(s) du club. Un nom de jeune ne doit jamais
// doubler un nom du même club (#610, décision de Léo du 13/11/2026). Les centres invités n'ont pas de club.
function youthTakenNames(club){
 if(!club||!youthWorldOnly()||typeof S==='undefined'||!S||!Number.isInteger(club.id)||!S.clubs?.[club.id])return null;
 const real=S.clubs[club.id],names=new Set(real.players.map(p=>p.name));
 const lists=[club.id===S.club?S.development?.academy:null,...(S.aiRoster?.academies||[]).filter(a=>a.clubId===club.id).map(a=>a.players),...(S.nativeAcademy?.centers||[]).filter(c=>c.clubId===club.id).map(c=>c.players)];
 for(const list of lists)for(const p of list||[])names.add(p.name);
 return names;
}
// Premier nom libre : tirages successifs, puis prénoms composés quand les listes du pays sont épuisées.
function youthUniqueName(id,h,club,taken){
 const first=youthName(id,h,club);
 if(!taken||!taken.has(first))return first;
 for(let k=1;k<=80;k++){const name=youthName(id,seedHash(id+':nom'+k),club);if(!taken.has(name))return name}
 const world=typeof worldActive==='function'&&worldActive(),nation=world?youthHeritage(id,youthClubNation(club)):null,pool=nation&&nation!=='FRA'&&YOUTH_NAMES[nation]?YOUTH_NAMES[nation]:{first:FIRST,last:LAST};
 for(let k=0;k<4000;k++){
  const g=seedHash(id+':compose'+k),a=pool.first[g%pool.first.length],b=pool.first[Math.floor(g/7)%pool.first.length],last=pool.last[Math.floor(g/31)%pool.last.length],name=(a===b?a:a+'-'+b)+' '+last;
  if(!taken.has(name))return name;
 }
 return first+' '+(taken.size+1);
}
// Portraits cohérents avec l'origine (#610). La banque v2 ne décrit que la teinte de peau observée de
// 128 de ses 160 bases joueurs (catalogue.json, observedTraits.skinTone : L = fair ou light, T = tan,
// B = brown, D = deep ; « . » = 32 anciennes bases sans étiquette, jamais choisies pour un jeune orienté).
// Ce n'est pas une mesure d'origine : les tirages ci-dessous donnent seulement une répartition plausible
// des teintes par pays d'origine et gardent de la variété dans chaque pays. Aucune donnée de morphologie
// ou de traits du visage n'existe dans la banque.
const PORTRAIT_TONES='................................LTBLBDLTLLBLTDLBLBTTBLLDLBLTDLBDTDLTLBDTLBLTLTDLTLTBLTLTBLTBLTLTLTBLTDLTLLBLTDLBLBLBBLTDLBLTDLTDBDLTLLDLLBLTLTDLBLLBLTLLBLTDLBLL';
const YOUTH_LOOK_EUROPE=[['L',66],['T',27],['B',5],['D',2]],YOUTH_LOOK_PACIFIC=[['T',20],['B',45],['D',35]],YOUTH_LOOK_ASIA=[['L',62],['T',38]],YOUTH_LOOK_AFRICA=[['T',10],['B',45],['D',45]];
const YOUTH_LOOKS={FRA:YOUTH_LOOK_EUROPE,ENG:YOUTH_LOOK_EUROPE,SCO:YOUTH_LOOK_EUROPE,WAL:YOUTH_LOOK_EUROPE,IRE:YOUTH_LOOK_EUROPE,ITA:YOUTH_LOOK_EUROPE,POR:YOUTH_LOOK_EUROPE,ROU:YOUTH_LOOK_EUROPE,
 GEO:[['L',55],['T',40],['B',5]],ARG:[['L',58],['T',37],['B',5]],RSA:[['L',38],['T',14],['B',26],['D',22]],NAM:YOUTH_LOOK_AFRICA,ZIM:YOUTH_LOOK_AFRICA,
 NZL:[['L',45],['T',25],['B',20],['D',10]],AUS:[['L',58],['T',24],['B',12],['D',6]],FIJ:YOUTH_LOOK_PACIFIC,TGA:YOUTH_LOOK_PACIFIC,SAM:YOUTH_LOOK_PACIFIC,JPN:YOUTH_LOOK_ASIA,KOR:YOUTH_LOOK_ASIA};
// Pays du club formateur pour le portrait : le champ country quand il existe (base mondiale), sinon la
// France pour les 30 clubs de la base commune et du mode France (même découpage que clubCountry() du worker).
function youthPortraitNation(club){
 if(!club||!youthWorldOnly())return null;
 const direct=youthClubNation(club);if(direct||club.country)return direct;
 return Number.isInteger(club.id)&&club.id<30&&!!S?.commonDatabase?'FRA':null;
}
// Portraits orientés et noms uniques : carrière monde uniquement. Les modes historiques (France, base commune
// classique) restent identiques à l'octet près (campagnes de référence, RNG compris).
function youthWorldOnly(){return typeof CDWorldCareer!=='undefined'&&typeof S!=='undefined'&&!!S&&CDWorldCareer.active(S)}
// Teinte cible tirée par empreinte, puis premier identifiant d'apparence (l'identifiant du joueur, sinon
// une variante salée) dont la cellule de la banque a cette teinte. Renvoie undefined quand l'identifiant
// du joueur convient déjà : le portrait garde alors le comportement historique.
function youthLookId(id,nation){
 const table=YOUTH_LOOKS[nation];if(!table)return undefined;
 let roll=youthHash(id+':look')%100,want=table[table.length-1][0];
 for(const [tone,weight] of table){if(roll<weight){want=tone;break}roll-=weight}
 for(let k=0;k<160;k++){const key=k===0?id:id+':look'+k;if(PORTRAIT_TONES[youthHash(key)%160]===want)return k===0?undefined:key}
 return undefined;
}
function academyPlayer(ci,slot,season,index,emergency=false,formationClub=null){const id=`youth-${ci}-${season}-${index}`,h=seedHash(id),home=formationClub??(Number.isInteger(ci)?S?.clubs?.[ci]:null),anchor=youthPortraitNation(home),look=anchor?youthLookId(id,youthHeritage(id,anchor)):undefined;let p={appearanceBankVersion:2,...(look===undefined?{}:{appearanceId:look}),id,name:youthUniqueName(id,h,home,youthTakenNames(home)),pos:POS[slot],fam:FAMILIES[slot],age:17+h%3,rating:emergency?55+h%8:52+h%15,condition:100,injury:0,salary:2000};ensureSkills(p);ensureDevelopment(p);p.dev.potential=emergency?68+h%10:academyPotential(p,formationClub);p.academy=true;return p}
function intakeYouth(){const d=S.development;if(d.intakeSeason===S.season)return;d.intakeSeason=S.season;for(let i=0;i<15;i++){const slot=(S.season*3+i)%15;d.academy.push(academyPlayer(S.club,slot,S.season,i,false,club()))}/* Jusqu'a cinq promotions coexistent selon les ages et les promotions en pros. */d.academy=d.academy.slice(-75);news(`Quinze nouveaux Espoirs rejoignent le centre de formation, avec une couverture des quinze postes. Evaluez leur potentiel et preparez leur promotion.`)}
function setupDevelopment(backup=false){if(!S)return;const fresh=!S.development;if(fresh&&backup){try{if(!gameStorage.getItem('bdt-backup-development'))gameStorage.setItem('bdt-backup-development',JSON.stringify(S))}catch(e){}}
S.development=S.development||{version:1,academyPotentialVersion:1,academy:[],intakeSeason:0,rolledSeason:0,retired:[]};normalizeAcademyPotential(S);S.clubs.forEach(c=>c.players.forEach(ensureDevelopment));S.market.forEach(ensureDevelopment);S.economy.freeAgents.forEach(ensureDevelopment);if(fresh&&S.live)S.live.devBaseline=S.live.sheets.map(s=>({...s.minutes}));intakeYouth();if(fresh&&backup)news('Formation et carrières activées : niveaux, contrats et résultats conservés. Le suivi des minutes commence maintenant.')}
function promoteYouth(id){if(economyLocked())return false;const d=S.development,p=d.academy.find(p=>p.id===id);if(!p||professionalPlaces()<=0){toast('Promotion impossible : joueur indisponible ou effectif complet.');return false}d.academy=d.academy.filter(p=>p.id!==id);p.academy=false;p.joinedSeason=S.season;p.joinedRound=S.round;p.contractEnd=contractBase()+1;club().players.push(p);if(satisfactionActive())ensureSatisfaction(p);careerPromoteYouth(p);transferEvent(`${p.name} signe son premier contrat professionnel jusqu’à la fin de la saison ${libelleSaison(p.contractEnd)}, à ${money(p.salary)} par semaine.`);save();render();toast('Le jeune est disponible dans votre effectif.');return true}
function retirementSeason(p){ensureDevelopment(p);return S.season+Math.max(0,p.dev.retireAge-p.age-1)}
function ageDevelopmentPlayer(p,completedSeason=S.season){ensureDevelopment(p);if(p.dev.lastYear===completedSeason)return;
 if(p.lnrRatingsVersion===1||p.worldRatingsVersion===1&&typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(S)&&CDWorldCareer.sourcePlayerKnown(p.id)){
  if(typeof LNR_V11_AGE==='undefined'||typeof lnrProjectV12!=='function')throw Error('Courbes V11 manquantes');
  const d=p.dev,old=p.rating,oldSkills={...p.skills};
  d.lastYear=completedSeason;
  d.history.push({season:completedSeason,age:p.age,start:d.seasonStart,end:p.rating,minutes:d.minutes,appearances:d.appearances});
  d.history=d.history.slice(-12);
  // Virtual ceiling reconciles historical potential to the role-rating scale without
  // overwriting the source potential, hidden traits, or initial attributes.
  const virtualPotential=clamp(Math.max(p.rating,d.potential),20,97);
  const input={...p,potential:virtualPotential};
  const evolved=LNR_V11_AGE.step(input,{playerId:p.id,age:p.age,season:completedSeason,lastSeason:null},
   {minutes:Math.min(3500,d.minutes),training:Math.min(1,d.xp*4),injuryWeeks:Math.min(52,p.injury||0),load:0});
  p.attributesV2=evolved.player.attributesV2;
  p.skills=lnrProjectV12(p);
  p.age=evolved.state.age;
  const skillBefore=Object.values(oldSkills).reduce((n,v)=>n+v,0)/11;
  const skillAfter=Object.values(p.skills).reduce((n,v)=>n+v,0)/11;
  p.rating=clamp(Math.round(old+skillAfter-skillBefore),20,97);
  p.skillBase=p.rating; // Prevent skill() double counting the annual delta.
  d.potential=Math.max(p.rating,d.potential);
  d.decline=Math.max(0,Math.min(5,old-p.rating));d.seasonStart=p.rating;
  d.minutes=0;d.appearances=0;d.xp=0;
  if(d.specialization)d.specialization.xp=0;
  p.condition=100;p.injury=0;
  return;
 }p.dev.lastYear=completedSeason;const d=p.dev;d.history.push({season:completedSeason,age:p.age,start:d.seasonStart,end:p.rating,minutes:d.minutes,appearances:d.appearances});d.history=d.history.slice(-12);p.age++;const threshold=p.fam<=3?34:32;const decline=p.age>=threshold?(p.age>=37?2:1):0;p.rating=clamp(p.rating-decline,45,99);d.potential=Math.max(p.rating,d.potential-decline);if(decline){p.skills.speed=clamp(p.skills.speed-decline,15,99);p.skills.stamina=clamp(p.skills.stamina-decline,15,99);p.skills.mental=clamp(p.skills.mental+decline,15,99)}d.decline=decline;d.seasonStart=p.rating;d.minutes=0;d.appearances=0;d.xp=0;if(d.specialization)d.specialization.xp=0;p.condition=100;p.injury=0}
function rollDevelopmentYear(){const d=S.development;if(d.rolledSeason===S.season)return;d.rolledSeason=S.season;const retiredIds=new Set(),seen=new Set();const all=[...S.clubs.flatMap(c=>c.players),...S.economy.freeAgents,...d.academy];for(let p of all){if(seen.has(p.id))continue;seen.add(p.id);ageDevelopmentPlayer(p);if(p.age>=p.dev.retireAge){retiredIds.add(p.id);let owner=S.clubs.find(c=>c.players.some(x=>x.id===p.id));d.retired.unshift({name:p.name,id:p.id,age:p.age,season:S.season,club:owner?.name||p.formerClub||'Agent libre',minutes:p.dev.careerMinutes});if(owner?.id===S.club)transferEvent(`${p.name} prend sa retraite à ${p.age} ans. Son salaire ne sera plus versé.`);else aiRosterRetirement(p,owner)}}for(let c of S.clubs)c.players=c.players.filter(p=>!retiredIds.has(p.id));S.economy.freeAgents=S.economy.freeAgents.filter(p=>!retiredIds.has(p.id));S.market=S.market.filter(p=>!retiredIds.has(p.id));if(aiRosterPopulationActive()){for(const p of d.academy)if(p.age>21)aiRosterGraduateAcademyPlayer(p,S.club);aiRosterTrimFreeAgents()}d.academy=d.academy.filter(p=>p.age<=21);S.lineup=S.lineup.map(id=>retiredIds.has(id)?null:id);S.reserves=S.reserves.map(id=>retiredIds.has(id)?null:id);d.retired=d.retired.slice(0,80)}
function renewAIYouth(){if(aiRosterActive())return aiRosterYouthIntake();for(let c of S.clubs){if(c.id===S.club)continue;let sheet=buildSheet(c),serial=0;for(let i=0;i<23;i++){let isBench=i>=15,j=isBench?i-15:i,id=isBench?sheet.bench[j]:sheet.lineup[j];if(id)continue;const slot=isBench?[1,0,2,3,5,8,9,10][j]:j,p=academyPlayer(c.id,slot,S.season,100+serial++);p.rating=clamp(c.base-15+seedHash(p.id)%9,54,82);delete p.skills;ensureSkills(p);delete p.dev;ensureDevelopment(p);p.contractEnd=S.season+2;p.academy=false;c.players.push(p);sheet=buildSheet(c)}for(let i=0;i<2&&c.players.length<34;i++){let p=academyPlayer(c.id,(S.season+i*7+c.id)%15,S.season,i);p.contractEnd=S.season+2;p.academy=false;c.players.push(p)}}}
function beginDevelopmentSeason(){intakeYouth();renewAIYouth()}
function developmentBadge(p){ensureDevelopment(p);return p.dev.decline?'Phase de déclin':p.rating>=p.dev.potential?'Potentiel atteint':p.age<=22?'En développement':p.age<=29?'En progression':'Joueur expérimenté'}
function playerDevelopmentHTML(p){ensureDevelopment(p);const d=p.dev,change=p.rating-d.seasonStart;return `<div class="devsummary"><div><span class="eyebrow">POTENTIEL AU POSTE</span><b>${potentialAtRole(p)} <small>/ 100</small></b></div><div><span class="eyebrow">ÉVOLUTION CETTE SAISON</span><b>${change>0?'+':''}${change} <small>niveau général</small></b></div><div><span class="eyebrow">TEMPS DE JEU</span><b>${Math.round(d.minutes)} <small>min · ${d.appearances} matchs</small></b></div></div><p class="help">${developmentBadge(p)} · Retraite prévue à l’issue de la saison ${libelleSaison(retirementSeason(p))} (${d.retireAge} ans au passage à l’intersaison). Le potentiel est un plafond de jeu, sans garantie de l’atteindre.</p>${developmentFocusSelector(p)}${d.history.length?`<details><summary>Historique des saisons</summary><div class="tablewrap"><table><thead><tr><th>SAISON</th><th>NIVEAU GÉNÉRAL</th><th>MINUTES</th><th>MATCHS</th></tr></thead><tbody>${d.history.slice().reverse().map(h=>`<tr><td>${h.season}</td><td>${h.start} → ${h.end}</td><td>${Math.round(h.minutes)}</td><td>${h.appearances}</td></tr>`).join('')}</tbody></table></div></details>`:''}`}
function inspectCareerPlayer(id){const p=club().players.find(p=>p.id===id)||S.market.find(p=>p.id===id)||S.development.academy.find(p=>p.id===id);if(!p)return;if(!p.academy&&!club().players.some(q=>q.id===p.id)&&!recruitmentEvidence(p).seen){const estimated=recruitmentEvidence(p);modal=`<div class="modalback"><section class="modal playerdetail" role="dialog" aria-modal="true" aria-label="Évaluation préliminaire"><button class="small" onclick="closeModal()">Fermer ×</button><h2>${visualEscape(p.name)}</h2><p>${p.pos} · ${p.age} ans · estimation ${estimated.noteMin}–${estimated.noteMax}</p><p class="help">Joueur non observé : attributs exacts et potentiel non disponibles. Pour obtenir un rapport, mission de deux journées (5 000 €).</p><button class="dark" onclick="modal=null;createScoutMission(${p.fam},40,10000000,100000);render()">Mission sur ce poste</button></section></div>`;render();return}ensureSkills(p);modal=`<div class="modalback"><section class="modal playerdetail" role="dialog" aria-modal="true" aria-label="Fiche joueur"><div class="row" style="margin-top:0"><span class="tag">${p.pos} · ${p.age} ans</span><button class="small" onclick="closeModal()">Fermer ×</button></div><h2>${p.name}</h2><p>Note au poste : <strong>${roleNote(p)}</strong> · Condition : ${Math.round(p.condition)}%${p.injury?' · Blessé '+p.injury+' sem.':''}</p><p class="help">${p.academy?'Centre de formation · Aucun salaire professionnel':(Number.isInteger(p.contractEnd)?contractLabel(p):'Agent libre')+' · '+money(p.salary)+' / semaine'}</p>${playerDevelopmentHTML(p)}<div class="attributes">${Object.entries(ATTR).map(([k,label])=>`<div><div class="row"><span>${label}</span><strong>${Math.round(skill(p,k))}</strong></div>${meter(skill(p,k))}</div>`).join('')}</div><p class="help">La condition modifie l’efficacité en match. L’âge, l’entraînement, la charge V27, la préparation collective V28 et les minutes réellement disputées modulent la progression ciblée.</p></section></div>`;render()}
function formationView(){let young=club().players.filter(p=>p.age<=23);return heading('CONSTRUIRE LA RELÈVE','Le centre de formation.','Quatre nouveaux espoirs à chaque saison. À vous de leur ouvrir les portes du groupe professionnel.')+`<div class="stats"><div class="card stat"><span class="eyebrow">ESPOIRS</span><b>${S.development.academy.length}</b><small>Hors masse salariale professionnelle</small></div><div class="card stat"><span class="eyebrow">JEUNES PROS ≤ 23 ANS</span><b>${young.length}</b><small>${Math.round(young.reduce((n,p)=>n+(p.dev?.minutes||0),0))} minutes cette saison</small></div><div class="card stat"><span class="eyebrow">RETRAITES À ANTICIPER</span><b>${club().players.filter(p=>retirementSeason(p)<=S.season+1).length}</b><small>Cette saison ou la prochaine</small></div><div class="card stat"><span class="eyebrow">PROGRESSION DU GROUPE</span><b>+${club().players.reduce((n,p)=>n+Math.max(0,p.rating-p.dev.seasonStart),0)}</b><small>Points de niveau général acquis</small></div></div><div class="notice" style="margin:0 0 22px">Les espoirs s’entraînent avec un objectif par poste, mais ne disputent pas de matchs de jeunes dans cette version. Ils restent au centre jusqu’à 21 ans inclus. Une promotion est gratuite, avec un salaire de 2 000 € par semaine et un contrat jusqu’à la fin de la saison ${libelleSaison(contractBase()+1)}.</div><div class="marketgrid">${S.development.academy.map(p=>`<div class="card marketplayer"><span class="tag">${p.pos} · ${p.age} ANS</span><h3>${p.name}</h3><div class="row"><span>Note au poste</span><strong>${roleNote(p)}</strong></div><div class="row"><span>Potentiel au poste</span><strong>${potentialAtRole(p)}</strong></div>${skillChips(p)}${developmentFocusSelector(p)}<div class="contractactions"><button class="small" onclick="inspectPlayer('${p.id}')">Fiche complète</button><button class="primary small" onclick="promoteYouth('${p.id}')" ${professionalPlaces()<=0?'disabled':''}>Promouvoir en équipe pro</button></div></div>`).join('')||'<div class="card"><p>Les espoirs ont été promus. La prochaine génération arrivera à l’intersaison.</p></div>'}</div><div class="card" style="margin-top:22px"><h2>Le suivi des carrières</h2><div class="tablewrap"><table><thead><tr><th>JOUEUR</th><th>ÂGE</th><th>NIVEAU AU POSTE</th><th>POTENTIEL AU POSTE</th><th>GAIN GÉNÉRAL</th><th>MINUTES</th><th>PHASE</th></tr></thead><tbody>${[...club().players].sort((a,b)=>a.age-b.age).map(p=>`<tr><td><button class="textbutton" onclick="inspectPlayer('${p.id}')">${p.name}</button></td><td>${p.age}</td><td>${roleNote(p)}</td><td>${potentialAtRole(p)}</td><td>${p.rating-p.dev.seasonStart>=0?'+':''}${p.rating-p.dev.seasonStart}</td><td>${Math.round(p.dev.minutes)}</td><td>${developmentBadge(p)}</td></tr>`).join('')}</tbody></table></div><p class="help">La progression compte en points de niveau général ; la note au poste résume les attributs utiles à ce rôle. Un jeune qui joue progresse davantage qu’un jeune limité aux entraînements.</p></div><div class="card" style="margin-top:22px"><h2>Les départs à la retraite</h2>${S.development.retired.filter(p=>p.club===club().name).map(p=>`<div class="news"><small>FIN SAISON ${libelleSaison(p.season)}</small>${p.name} · ${p.age} ans · ${Math.round(p.minutes)} minutes suivies dans la carrière</div>`).join('')||'<p>Aucun départ à la retraite enregistré dans votre club.</p>'}</div>`}
function nextSeason(){if(S.phase!=='ended'||economyLocked())return;const retiring=club().players.filter(p=>retirementSeason(p)<=S.season),leaving=club().players.filter(p=>p.contractEnd<=S.season&&!retiring.some(r=>r.id===p.id));if(!retiring.length&&!leaving.length){advanceSeason();return}modal=`<div class="modalback"><section class="modal contractmodal" role="dialog" aria-modal="true" aria-label="Bilan de carrière et contrats"><span class="tag">CLÔTURE DE LA SAISON</span><h2 style="margin-top:12px">Préparez les départs.</h2>${retiring.length?`<h3>${retiring.length} retraite(s) annoncée(s)</h3><ul class="expirylist">${retiring.map(p=>`<li>${p.name} · ${p.pos} · ${p.age+1} ans à l’intersaison</li>`).join('')}</ul><p class="help">Ces joueurs quittent définitivement le jeu. Le versement de leur salaire s’arrête à l’intersaison, sans indemnité dans cette simulation.</p>`:''}${leaving.length?`<h3>${leaving.length} fin(s) de contrat non prolongée(s)</h3><ul class="expirylist">${leaving.map(p=>`<li>${p.name} · ${p.pos} · ${money(p.salary)} / sem.</li>`).join('')}</ul><p class="help">Vous pouvez encore négocier leur prolongation. Sinon, ils deviendront agents libres.</p>`:''}<p class="help">Une nouvelle promotion d’espoirs arrive à chaque saison. Les postes vacants de la feuille à 23 seront complétés par les espoirs de dépannage.</p><div class="contractactions"><button onclick="modal=null;marketTab='contracts';nav('market')">Revoir les contrats</button><button class="primary" onclick="advanceSeason()">Confirmer les départs et continuer</button></div></section></div>`;render()}
