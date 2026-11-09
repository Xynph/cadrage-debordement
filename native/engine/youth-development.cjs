'use strict';
const files=Object.freeze([]),commands=Object.freeze(['youth_development_enable','youth_development_plan']);
// Serialized in the native VM: measurement and routing only, never a growth engine.
function factory(){
 const POLICY='existing-growth-budget-v1',MAX_ROWS=200,MAX_OBSERVATIONS=6;
 const KEYS=['scrum','lineout','tackle','speed','pass','kick','goal','power','stamina','mental','discipline'];
 const LABELS={scrum:'Mêlée',lineout:'Touche',tackle:'Plaquage',speed:'Vitesse',pass:'Passe',kick:'Jeu au pied',goal:'But',power:'Puissance',stamina:'Endurance',mental:'Mental',discipline:'Discipline'};
 const PLANS=[{key:'general',label:'Progression générale',generalShare:1,targetShare:0,description:'Conserver le budget régulier pour le niveau général.'},
  {key:'specialist',label:'Qualité au poste',generalShare:.5,targetShare:.5,description:'Partager le même budget entre niveau général et une qualité du poste.'},
  {key:'integration',label:'Passage chez les professionnels',generalShare:.75,targetShare:.25,description:'Privilégier le niveau général, garder une qualité au poste et suivre les vraies étapes professionnelles.'}];
 const REASONS=['enable','plan','trainWeek','recordDevelopmentMatch','rollDevelopmentYear','advanceSeason','promoteYouth','managerMobilityOnSeasonStart'];
 const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x),shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const int=(n,a,b)=>Number.isSafeInteger(n)&&n>=a&&n<=b,num=(n,a,b)=>typeof n==='number'&&Number.isFinite(n)&&n>=a&&n<=b;
 const id=x=>typeof x==='string'&&/^[A-Za-z0-9:_-]{1,180}$/.test(x),copy=x=>JSON.parse(JSON.stringify(x));
 const check=(ok,message)=>{if(!ok)throw Error('Progression des jeunes : '+message+'.');};
 const state=()=>typeof S==='undefined'?null:S,week=s=>s.franceMode?.week??s.round,context=s=>({season:s.season,week:week(s),club:s.club});
 const active=s=>s?.youthDevelopment?.version===1,young=p=>int(p.age,15,24);
 const owned=s=>[...(s.clubs?.[s.club]?.players||[]).map(p=>({p,stage:'professional'})),...(s.development?.academy||[]).map(p=>({p,stage:'academy'}))];
 const annual=(s,p)=>p.lnrRatingsVersion===1||p.worldRatingsVersion===1&&typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s)&&!!CDWorldCareer.sourcePlayer(s,p.id);
 const focusOptions=p=>typeof developmentFocusOptions==='function'?developmentFocusOptions(p).filter(k=>KEYS.includes(k)):[];
 const actualFocus=p=>p.dev?.specialization?.focus||'equilibre';
 function defaultFocus(p){const allowed=focusOptions(p),value=typeof developmentFocusRecommendation==='function'?developmentFocusRecommendation(p):null;return allowed.includes(value)?value:allowed[0]||null;}
 function metrics(s,p,stage){
  check(object(p.skills)&&KEYS.every(k=>num(p.skills[k],15,99))&&object(p.dev),'profil de progression incomplet');
  const view=copy(p),attributes=Object.fromEntries(KEYS.map(k=>[k,typeof skill==='function'?skill(view,k):view.skills[k]]));
  const potential=typeof potentialAtRole==='function'?potentialAtRole(view):view.dev.potential;
  return {season:s.season,week:week(s),clubId:s.club,age:p.age,stage,model:annual(s,p)?'annual-v11':'xp',rating:p.rating,potential,attributes,
   careerMinutes:p.dev.careerMinutes,seasonMinutes:p.dev.minutes,appearances:p.dev.appearances,generalXP:p.dev.xp,
   focusedXP:p.dev.specialization?.xp||0,condition:p.condition,fatigue:p.physicalLoad?.fatigue||0,injury:p.injury};
 }
 function same(a,b){const omit=x=>{const v={...x};delete v.season;delete v.week;return v;};return JSON.stringify(omit(a))===JSON.stringify(omit(b));}
 function newRow(s,p,stage){const value=metrics(s,p,stage);return {id:p.id,plan:null,focus:null,planClubId:null,planSeason:null,planWeek:null,baseline:value,latest:copy(value),observations:[]};}
 function delta(current,baseline){return {rating:current.rating-baseline.rating,potential:current.potential-baseline.potential,
  attributes:Object.fromEntries(KEYS.map(k=>[k,current.attributes[k]-baseline.attributes[k]])),minutes:current.careerMinutes-baseline.careerMinutes,
  generalXP:current.generalXP-baseline.generalXP,focusedXP:current.focusedXP-baseline.focusedXP};}
 function append(row,current,reason,force=false){
  if(!force&&same(current,row.latest))return false;
  const d=delta(current,row.latest);row.observations.push({season:current.season,week:current.week,reason,ratingDelta:d.rating,attributeDeltas:d.attributes,minutesDelta:d.minutes,stage:current.stage});
  row.observations=row.observations.slice(-MAX_OBSERVATIONS);row.latest=current;return true;
 }
 function prune(s){
  const ids=new Set(owned(s).map(x=>x.p.id));s.youthDevelopment.rows.sort((a,b)=>Number(ids.has(b.id))-Number(ids.has(a.id))||b.latest.season-a.latest.season||b.latest.week-a.latest.week||a.id.localeCompare(b.id));
  s.youthDevelopment.rows=s.youthDevelopment.rows.slice(0,MAX_ROWS);
 }
 function enable(s){
  check(s?.development&&s?.clubs?.[s.club]&&!s.live&&s.phase==='league','activation disponible hors match en saison régulière');
  if(active(s))return false;check(s.youthDevelopment===undefined,'version de suivi inconnue');
  const rows=owned(s).filter(x=>young(x.p)).map(x=>newRow(s,x.p,x.stage));check(rows.length<=MAX_ROWS,'trop de jeunes à suivre');
  s.youthDevelopment={version:1,policy:POLICY,activatedClubId:s.club,enabledSeason:s.season,enabledWeek:week(s),rows};return true;
 }
 function setPlan(s,playerId,plan,focus){
  check(active(s),'activez le suivi');check(!s.live&&!s.trained&&s.phase==='league','révision avant la séance et hors match');
  const entry=owned(s).find(x=>x.p.id===playerId),choice=PLANS.find(x=>x.key===plan);check(entry&&young(entry.p)&&choice,'joueur ou plan indisponible');
  const p=entry.p,source=annual(s,p);check(!source||plan!=='specialist','qualité ciblée indisponible pour la progression annuelle');
  const allowed=focusOptions(p);let selected=null;
  if(source||plan==='general')check(focus===null,'ce plan ne cible pas de qualité');
  else{selected=focus===null?defaultFocus(p):focus;check(allowed.includes(selected),'qualité hors du poste');}
  let row=s.youthDevelopment.rows.find(x=>x.id===p.id);if(!row)row=newRow(s,p,entry.stage);
  const target=selected||'equilibre',currentFocus=actualFocus(p),changed=row.plan!==plan||row.focus!==selected||row.planClubId!==s.club||!source&&currentFocus!==target;
  if(!changed)return true;
  if(!source&&(selected!==null||p.dev.specialization)){
   const sp=typeof ensureSpecialization==='function'?ensureSpecialization(p):(p.dev.specialization||(p.dev.specialization={version:1,focus:'equilibre',xp:0,bonuses:{}}));
   if(sp.focus!==target){sp.focus=target;sp.xp=0;}
  }
  if(!s.youthDevelopment.rows.includes(row))s.youthDevelopment.rows.push(row);
  row.plan=plan;row.focus=selected;row.planClubId=s.club;row.planSeason=s.season;row.planWeek=week(s);append(row,metrics(s,p,entry.stage),'plan',true);prune(s);return true;
 }
 function growthShare(s,p,allowFocus=true){
  if(!allowFocus||!active(s)||!young(p)||annual(s,p)||!owned(s).some(x=>x.p.id===p.id))return null;
  const row=s.youthDevelopment.rows.find(x=>x.id===p.id);
  if(!row?.plan||row.planClubId!==s.club||actualFocus(p)!==(row.focus||'equilibre'))return null;
  return PLANS.find(x=>x.key===row.plan)?.targetShare??null;
 }
 function observe(s,reason){
  if(!active(s))return 0;check(REASONS.includes(reason),'événement de suivi inconnu');let count=0;
  for(const {p,stage}of owned(s)){
   let row=s.youthDevelopment.rows.find(x=>x.id===p.id);if(!row&&!young(p))continue;
   if(!row){row=newRow(s,p,stage);s.youthDevelopment.rows.push(row);count++;continue;}
   if(append(row,metrics(s,p,stage),reason))count++;
  }
  if(count)prune(s);return count;
 }
 function validate(s){
  if(!s||s.youthDevelopment===undefined)return true;
  const st=s.youthDevelopment;check(shape(st,['version','policy','activatedClubId','enabledSeason','enabledWeek','rows'])&&st.version===1&&st.policy===POLICY&&int(st.activatedClubId,0,s.clubs.length-1)&&int(st.enabledSeason,1,s.season)&&int(st.enabledWeek,0,52)&&(st.enabledSeason!==s.season||st.enabledWeek<=week(s)),'état du suivi invalide');
  check(Array.isArray(st.rows)&&st.rows.length<=MAX_ROWS&&new Set(st.rows.map(r=>r.id)).size===st.rows.length,'suivis dupliqués ou trop nombreux');
  const timestamp=(season,w)=>int(season,st.enabledSeason,s.season)&&int(w,0,52)&&(season!==s.season||w<=week(s))&&(season!==st.enabledSeason||w>=st.enabledWeek);
  const attributes=(x,lo,hi)=>shape(x,KEYS)&&KEYS.every(k=>num(x[k],lo,hi));
  const metricKeys=['season','week','clubId','age','stage','model','rating','potential','attributes','careerMinutes','seasonMinutes','appearances','generalXP','focusedXP','condition','fatigue','injury'];
  const metric=m=>shape(m,metricKeys)&&timestamp(m.season,m.week)&&int(m.clubId,0,s.clubs.length-1)&&int(m.age,15,60)&&['academy','professional'].includes(m.stage)&&['xp','annual-v11'].includes(m.model)&&int(m.rating,15,99)&&num(m.potential,15,99)&&attributes(m.attributes,15,99)&&num(m.careerMinutes,0,1e9)&&num(m.seasonMinutes,0,100000)&&int(m.appearances,0,10000)&&num(m.generalXP,0,1)&&num(m.focusedXP,0,.5)&&num(m.condition,0,100)&&num(m.fatigue,0,100)&&int(m.injury,0,52);
  for(const row of st.rows){
   check(shape(row,['id','plan','focus','planClubId','planSeason','planWeek','baseline','latest','observations'])&&id(row.id)&&metric(row.baseline)&&metric(row.latest),'baseline numérique invalide');
   check(row.latest.season>row.baseline.season||row.latest.season===row.baseline.season&&row.latest.week>=row.baseline.week,'suivi antérieur à la baseline');
   check(row.latest.age>=row.baseline.age&&row.latest.model===row.baseline.model,'identité de progression incohérente');
   const current=owned(s).find(x=>x.p.id===row.id);
   if(current){check(row.latest.model===(annual(s,current.p)?'annual-v11':'xp'),'modèle de progression incohérent');if(row.focus!==null)check(focusOptions(current.p).includes(row.focus),'qualité du plan hors du poste');}
   if(row.plan===null)check(row.focus===null&&row.planClubId===null&&row.planSeason===null&&row.planWeek===null,'plan absent incohérent');
   else{
    check(PLANS.some(p=>p.key===row.plan)&&int(row.planClubId,0,s.clubs.length-1)&&timestamp(row.planSeason,row.planWeek),'plan invalide');
    check(row.baseline.model==='annual-v11'?row.plan!=='specialist'&&row.focus===null:row.plan==='general'?row.focus===null:KEYS.includes(row.focus),'ciblage incompatible');
   }
   check(Array.isArray(row.observations)&&row.observations.length<=MAX_OBSERVATIONS,'trop d’observations');
   let prior=row.baseline;
   for(const o of row.observations){
    check(shape(o,['season','week','reason','ratingDelta','attributeDeltas','minutesDelta','stage'])&&timestamp(o.season,o.week)&&REASONS.includes(o.reason)&&num(o.ratingDelta,-84,84)&&attributes(o.attributeDeltas,-84,84)&&num(o.minutesDelta,-1e9,1e9)&&['academy','professional'].includes(o.stage),'observation invalide');
    check(o.season>prior.season||o.season===prior.season&&o.week>=prior.week,'observations désordonnées');prior=o;
   }
   if(row.observations.length)check(row.latest.season===prior.season&&row.latest.week===prior.week,'dernière observation incohérente');
  }
  return true;
 }
 function steps(s,p,stage,current,row){
  const result=[];
  if(p.injury>0||current.fatigue>=55||p.condition<65)result.push({key:'recover',label:'Récupérer avant de charger',done:false,detail:'Blessure, condition et charge sont celles du joueur ; aucun gain automatique de repos n’est ajouté.'});
  if(row?.plan==='general')result.push({key:'generalProgress',label:'Consolider le niveau général',done:current.rating-row.baseline.rating>=1,detail:(current.rating-row.baseline.rating)+' point(s) réel(s) depuis la référence ; repère de +1, sans récompense.'});
  if(row?.plan==='specialist'&&row.focus)result.push({key:'qualityProgress',label:'Améliorer '+LABELS[row.focus],done:current.attributes[row.focus]-row.baseline.attributes[row.focus]>=1,detail:(current.attributes[row.focus]-row.baseline.attributes[row.focus])+' point(s) réel(s) depuis la référence ; repère de +1, sans récompense.'});
  if((!row?.plan||row.plan==='integration')&&stage==='academy'){
   result.push({key:'age',label:'Âge du premier passage professionnel',done:p.age>=18,detail:'Repère de simulation à 18 ans, pas une homologation de compétition.'});
   const places=typeof professionalPlaces==='function'?professionalPlaces(s.clubs[s.club],s):null;
   result.push({key:'place',label:'Vérifier une place professionnelle',done:places!==null&&places>0,detail:places===null?'Consulter la capacité contractuelle.':places+' place(s) contractuelle(s) disponible(s).'});
   result.push({key:'promotion',label:'Décider du premier contrat',done:false,detail:'Promotion manuelle avec salaire réel ; ce suivi ne signe aucun contrat.'});
  }else if(!row?.plan||row.plan==='integration'){const minutes=row?current.careerMinutes-row.baseline.careerMinutes:null;result.push({key:'minutes',label:'Construire de nouvelles minutes professionnelles',done:minutes!==null&&minutes>=240,detail:minutes===null?'Créer une référence de suivi avant de mesurer de nouvelles minutes.':Math.round(minutes)+' minutes réelles depuis la référence ; repère de 240 nouvelles minutes, sans récompense.'});}
  result.push({key:'growth',label:current.model==='annual-v11'?'Observer le bilan annuel':'Développer sans dépasser le potentiel',done:p.rating>=p.dev.potential,detail:current.model==='annual-v11'?'Les activités et minutes alimentent la courbe annuelle existante.':'Le même budget est partagé ; le potentiel et les plafonds de qualité restent actifs.'});
  return result;
 }
 // Consultative only: all measures use the initial observed reference, never
 // attribute earlier gains to a newly chosen plan or reconstruct missed games.
 function review(s,p,stage,current,row){
  const basis='Écarts depuis la référence initiale ; ils ne prouvent pas l’effet du plan actuel.'+(current.model==='annual-v11'?' Le niveau évolue au bilan annuel, pas à chaque semaine.':'');
  const advice=(key,label,detail,destination=null,suggestedPlan=null)=>({key,label,detail,destination,suggestedPlan});
  if(!row)return {status:'untracked',label:'Commencer par observer',basis,evidence:null,objective:null,recommendation:advice('start','Créer une référence','Démarrer le suivi avant de mesurer de nouveaux progrès.')};
  if(row.baseline.clubId!==s.club)return {status:'context',label:'Référence d’un autre club',basis,evidence:null,objective:null,recommendation:advice('context','Examiner les faits du nouveau club','La référence initiale vient d’un autre club ; aucun déficit de minutes local n’est déduit. Réviser le plan pour le club courant.','Effectif','integration')};
  const d=delta(current,row.baseline),weeks=current.season===row.baseline.season?current.week-row.baseline.week:null;
  if(d.minutes<0)return {status:'context',label:'Compteur de minutes à vérifier',basis,evidence:null,objective:null,recommendation:advice('counter','Vérifier la continuité du suivi','Le total de minutes de carrière est inférieur à la référence. Aucun manque de temps de jeu ni bilan chiffré n’est déduit de cette discontinuité.','Effectif')};
  const evidence={from:{season:row.baseline.season,week:row.baseline.week},to:{season:current.season,week:current.week},weeks,ratingDelta:d.rating,minutesDelta:d.minutes,attributeDeltas:d.attributes,observations:row.observations.length};
  let objective=null;
  if(row.plan==='general')objective={key:'general',label:'Consolider le niveau général',value:d.rating,target:1,unit:'point',achieved:d.rating>=1,measurement:current.model};
  else if(row.plan==='specialist'&&row.focus)objective={key:'quality',label:'Améliorer '+LABELS[row.focus],value:d.attributes[row.focus],target:1,unit:'point',achieved:d.attributes[row.focus]>=1,measurement:current.model};
  else if(row.plan==='integration')objective=stage==='professional'?{key:'integration',label:'Accumuler de nouvelles minutes professionnelles',value:d.minutes,target:240,unit:'minutes',achieved:d.minutes>=240,measurement:current.model}:{key:'integration',label:'Examiner le premier contrat professionnel',value:null,target:null,unit:null,achieved:false,measurement:current.model};
  let status='observing',recommendation;
  if(p.injury>0||current.fatigue>=55||p.condition<65){
   status='review';recommendation=advice('recover','Adapter la charge avant de poursuivre','Blessure : '+p.injury+' semaine(s), condition : '+p.condition+' %, fatigue : '+current.fatigue+'/100. Consulter la charge et le suivi médical avant de chercher davantage de minutes.','Effectif');
  }else if(stage==='academy'){
   const places=typeof professionalPlaces==='function'?professionalPlaces(s.clubs[s.club],s):null;
   if(p.age<18)recommendation=advice('academy','Poursuivre le parcours au centre','Âge : '+p.age+' ans. Le repère de premier passage professionnel de ce suivi est 18 ans ; aucun contrat automatique.','Centre');
   else if(places!==null&&places>0)recommendation=advice('promotion','Examiner un premier contrat pro','Âge : '+p.age+' ans, '+places+' place(s) contractuelle(s). Vérifier le niveau, le salaire et les minutes envisageables avant de signer.','Centre','integration');
   else{status='review';recommendation=advice('capacity','Préparer une place avant la promotion','Aucune place professionnelle confirmée. Conserver le parcours au centre et examiner la capacité contractuelle.','Centre');}
  }else if((weeks!==null&&weeks>=4||current.season>row.baseline.season)&&d.minutes<80){
   status='review';
   const loanCandidate=p.age<=23&&(p.id.startsWith('youth-')||p.joinedSeason!==undefined)&&p.contractEnd>=s.season&&!s.lineup.includes(p.id)&&!s.reserves.includes(p.id);
   recommendation=loanCandidate?advice('loan','Examiner un prêt pour jouer',Math.round(d.minutes)+' nouvelles minutes depuis la référence. Vérifier l’éligibilité complète, le club d’accueil et les places de retour dans les parcours du centre ; aucun prêt ni temps de jeu n’est garanti.','Centre','integration'):advice('minutes','Réexaminer les occasions de jouer',Math.round(d.minutes)+' nouvelles minutes depuis la référence. Examiner la sélection et le parcours ; une absence de gain hebdomadaire ne prouve pas un échec de progression.','Effectif','integration');
  }else if(objective?.achieved){status='achieved';recommendation=advice('continue','Faire le point et choisir la suite','Le repère de suivi est atteint. Conserver le plan ou préparer une réorientation, sans récompense de croissance ajoutée.',stage==='academy'?'Centre':'Effectif');}
  else recommendation=advice('observe','Laisser une période d’observation','Comparer les prochaines observations avant de conclure. Les minutes et qualités mesurées restent distinctes des promesses de progression.',stage==='academy'?'Centre':'Effectif');
  return {status,label:{observing:'Bilan intermédiaire',review:'Parcours à revoir',achieved:'Repère atteint'}[status],basis,evidence,objective,recommendation};
 }
 function project(s=state()){
  if(!s?.development)return {available:false,enabled:false,canEnable:false,locked:true,reason:'Carrière indisponible.',context:null,plans:copy(PLANS),limits:{minAge:15,maxAge:24,maxTracked:MAX_ROWS,maxObservations:MAX_OBSERVATIONS,attributeBonus:4,totalBonus:8},players:[]};
  const enabled=active(s),locked=!!s.live||s.trained||s.phase!=='league';
  const players=owned(s).filter(x=>young(x.p)).map(({p,stage})=>{
   const row=enabled?s.youthDevelopment.rows.find(x=>x.id===p.id):null,current=metrics(s,p,stage),source=current.model==='annual-v11';
   const mismatch=!!row?.plan&&(row.planClubId!==s.club||!source&&actualFocus(p)!==(row.focus||'equilibre'));
   return {id:p.id,name:p.name,pos:p.pos,age:p.age,stage,...(p.appearanceBankVersion===undefined?{}:{appearanceBankVersion:p.appearanceBankVersion}),model:current.model,rating:p.rating,potential:current.potential,potentialBasis:'role-estimate',condition:p.condition,injury:p.injury,fatigue:current.fatigue,careerMinutes:current.careerMinutes,
    tracked:!!row,plan:row?.plan||null,focus:row?.focus||null,canPlan:enabled&&!locked,planReason:mismatch?'Objectif individuel ou club modifié : réviser le plan pour appliquer sa répartition.':source?'Progression annuelle : les étapes suivent les expositions réelles, sans supplément de croissance.':'Le plan partage le budget régulier déjà gagné, sans bonus supplémentaire.',
    availablePlans:source?['general','integration']:PLANS.map(p=>p.key),focusOptions:source?[]:focusOptions(p).map(key=>({key,label:LABELS[key]})),defaultFocus:source?null:defaultFocus(p),
    baseline:row?copy(row.baseline):null,current,deltas:row?delta(current,row.baseline):null,observations:row?copy(row.observations):[],review:review(s,p,stage,current,row),nextSteps:steps(s,p,stage,current,row)};
  });
  return {available:true,enabled,canEnable:!enabled&&!s.live&&s.phase==='league',locked,reason:enabled?'':'Activer le suivi pour commencer des références réelles, sans reconstruire le passé.',context:context(s),plans:copy(PLANS),limits:{minAge:15,maxAge:24,maxTracked:MAX_ROWS,maxObservations:MAX_OBSERVATIONS,attributeBonus:4,totalBonus:8},players};
 }
 function execute(command,payload){
  const s=state();check(s,'carrière absente');const specific=command==='youth_development_plan'?['playerId','plan','focus']:[];
  check(['youth_development_enable','youth_development_plan'].includes(command)&&shape(payload,['context','confirmed',...specific])&&shape(payload.context,['season','week','club'])&&payload.confirmed===true,'commande ou paramètres invalides');
  const now=context(s);check(Object.keys(now).every(k=>payload.context[k]===now[k]),'contexte périmé');validate(s);
  if(command==='youth_development_enable')check(enable(s),'suivi déjà actif');else setPlan(s,payload.playerId,payload.plan,payload.focus);
  validate(s);return {youthDevelopmentAction:{command,playerId:payload.playerId??null,plan:payload.plan??null,cost:0,growthAwarded:0}};
 }
 return {active,enable,setPlan,project,validate,execute,observe,growthShare,installHooks:()=>true};
}
module.exports={files,commands,factory};
