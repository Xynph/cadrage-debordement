'use strict';
// Inject once, after explicit Nationale/Japan qualification hooks. This is a
// fictional sporting model, not a source of first-row training qualifications.
module.exports=function positionAptitudes(){
 const baseSlot=slotEligible,baseBench=benchEligible,baseNote=roleNote;
 const cover=[2,1,3,4,6,9,10,11],adjacent=[[],[],[3],[2],[5,6],[4,8,7],[7,8],[6,8,5],[6,5,7]];
 const critical=[['scrum','power'],['lineout','scrum'],['lineout','tackle'],['tackle','stamina'],['pass','mental'],['pass','kick'],['speed'],['pass','tackle'],['kick','speed']];
 const cache=new Map(),playerCache=new WeakMap(),keys=Object.keys(ATTR);
 // Quota du club (JIFF : joueurs formés en France ; EQP en Premiership : joueurs sélectionnables pour l'Angleterre),
 // lu dans CDJiff : {target, yes(p)} ou null quand le club n'est soumis à aucun quota.
 function quotaOf(team){
  if(typeof CDJiff==='undefined'||!CDJiff.qualifierFor||typeof S==='undefined'||S?.jiff?.version!==1||team.id===undefined)return null;
  return CDJiff.qualifierFor(S,team.id);
 }
 const compareId=(a,b)=>String(a.id)<String(b.id)?-1:String(a.id)>String(b.id)?1:0;
 function positionNumber(slot){return slot<15?slot+1:cover[slot-15]??null;}
 // Clé des qualifications du joueur. Quand ses deux listes ont exactement les mêmes éléments que lors du dernier calcul
 // (donc la même jointure) et la même version de notes, la clé mémorisée est reprise sans réassembler de chaînes.
 const sameItems=(copy,list)=>{
  if(list===undefined||list===null)return copy===list;
  if(!Array.isArray(list)||!Array.isArray(copy)||copy.length!==list.length)return false;
  for(let i=0;i<list.length;i++)if(copy[i]!==list[i])return false;
  return true;
 };
 function qualifiers(p,cached){
  const a=p.nationaleQualifications,b=p.worldProfile?.position?.qualifications,v=p.worldRatingsVersion;
  if(cached&&cached.qv===v&&sameItems(cached.qa,a)&&sameItems(cached.qb,b))return cached.qualifierKey;
  return [a?.join('|'),b?.join('|'),v].join(';');
 }
 function derive(p){
  if(!p)return {primaryPosition:null,primaryPositions:[],secondaryPositions:[],positionRatings:{},qualifiedFrontRowPositions:[]};
  const cached=playerCache.get(p),qualifierKey=qualifiers(p,cached);
  if(cached&&cached.id===p.id&&cached.name===p.name&&cached.rating===p.rating&&cached.skillBase===p.skillBase&&cached.pos===p.pos&&cached.fam===p.fam&&cached.qualifierKey===qualifierKey){
   // Boucle simple (et non keys.every avec fermeture) : derive est appelée des milliers de fois par feuille.
   const sk=p.skills,spec=p.dev?.specialization?.version===1?p.dev.specialization.bonuses:null;let same=true;for(let i=0;i<keys.length;i++){const k=keys[i];if(cached.skills[i]!==sk?.[k]||cached.bonuses[i]!==(spec?(spec[k]||0):0)){same=false;break;}}
   if(same)return cached.result;
  }
  // Listes de qualifications telles qu'elles ont donné qualifierKey (relevées avant tout calcul).
  const qa=p.nationaleQualifications,qb=p.worldProfile?.position?.qualifications,qualifierSource={qa:Array.isArray(qa)?qa.slice():qa,qb:Array.isArray(qb)?qb.slice():qb,qv:p.worldRatingsVersion};
  // Legacy missing skills are deterministically generated on a detached object.
  const q=p.skills?p:{...p};ensureSkills(q);
  // Qualités durables seulement (même expression que roleNote) : ni l'état du moment en match (pilotageSkillMod,
  // causerie, cri), ni la mémoire du pas de match (memoSkill). Sinon le résultat mis en cache, et la mémoire du match
  // remplie au passage, dépendaient du moment du premier calcul : un rejeu depuis une sauvegarde (objets joueurs neufs,
  // cache vide) ne redonnait pas le même match.
  const quality=k=>clamp(q.skills[k]+q.rating-q.skillBase+focusedBonus(q,k),15,99);
  const qualities=keys.map(quality);
  const front=[0,1,2].filter(i=>baseSlot(p,i)).map(i=>i+1);
  const key=[p.id,p.pos,p.fam,p.rating,p.skillBase,...qualities,...front].join('|');
  let result=cache.get(key);
  if(!result){
   const found=POS.indexOf(p.pos),primary=found>=0?found+1:FAMILIES.indexOf(p.fam)+1;
   // A main role can cover two shirts. These are not secondary roles;
   // prop sides still come exclusively from existing front-row qualifications.
   const primaryPositions=primary===1||primary===3?front.filter(n=>n===1||n===3):
    [[4,5],[6,7],[11,14],[12,13]].find(numbers=>numbers.includes(primary))??[primary];
   const main=baseNote(q),familyNotes=Array.from({length:9},(_,f)=>baseNote(q,f)),raw=FAMILIES.map(f=>familyNotes[f]);
   const candidates=(adjacent[p.fam]||[]).filter(f=>{
    const value=familyNotes[f];return value>=Math.max(55,main*.90)&&critical[f].every(k=>quality(k)>=Math.max(50,main*.72));
   }).sort((a,b)=>familyNotes[b]-familyNotes[a]||(adjacent[p.fam].indexOf(a)-adjacent[p.fam].indexOf(b)));
   const mastered=candidates[0],ratings={},secondary=[];
   for(let i=0;i<15;i++){
    const f=FAMILIES[i],natural=f===p.fam;
    let n;
    if(i<3)n=front.includes(i+1)?Math.min(main,familyNotes[f]):0;
    else if(natural)n=main;
    else if(f===mastered)n=Math.max(1,Math.min(main-3,raw[i]-4));
    else {
     const close=(adjacent[p.fam]||[]).includes(f),sameUnit=(p.fam<=3)===(f<=3);
     n=Math.max(5,Math.min(main-8,Math.round(raw[i]*(close?.64:sameUnit?.49:.32))));
    }
    ratings[i+1]=n;
    if(!primaryPositions.includes(i+1)&&(i<3?front.includes(i+1):natural||f===mastered))secondary.push(i+1);
   }
   secondary.sort((a,b)=>ratings[b]-ratings[a]||a-b);
   result={primaryPosition:primary,primaryPositions,secondaryPositions:secondary,positionRatings:ratings,qualifiedFrontRowPositions:front,_familyNotes:familyNotes};
   if(cache.size>=32768)cache.delete(cache.keys().next().value);cache.set(key,result);
  }
  playerCache.set(p,{id:p.id,name:p.name,rating:p.rating,skillBase:p.skillBase,pos:p.pos,fam:p.fam,qualifierKey,...qualifierSource,skills:keys.map(k=>p.skills?.[k]),bonuses:keys.map(k=>focusedBonus(p,k)),result});
  return result;
 }
 function project(p){
  const {_familyNotes,...result}=derive(p);
  return {...result,primaryPositions:result.primaryPositions.slice(),secondaryPositions:result.secondaryPositions.slice(),positionRatings:{...result.positionRatings},qualifiedFrontRowPositions:result.qualifiedFrontRowPositions.slice()};
 }

 function rating(p,slot){return derive(p).positionRatings[positionNumber(slot)]??0;}
 // Mémoire d'un pas de match, ou de tout un match de l'ordinateur (advanceRugby, voir installHooks) : pendant le jeu,
 // ni les qualités, ni la note, ni le poste, ni la spécialisation d'un joueur ne changent (seule sa condition baisse ;
 // la progression vient après le coup de sifflet final). Efficacité au poste et qualité brute (avant forme) y sont donc
 // calculées une fois par joueur et par poste ou qualité, puis relues. Hors d'un match : calcul direct.
 let stepMemo=null,memoSkillBase=null,memoRoleBase=null;const viewOf=new WeakMap();
 const newMemo=()=>({efficiency:new Map(),skill:new Map(),role:new Map(),views:new Map()});
 const memoRow=(map,p)=>{let row=map.get(p);if(!row){row=Object.create(null);map.set(p,row);}return row;};
 // skill et roleNote (dist/rugby.js) ne sont remplacées que le temps d'une mémoire (withMemo) : aucun coût ailleurs.
 // Même expression que skill : qualité bornée relue, puis forme du moment (condition) appliquée.
 // Une vue au poste (slotView, jamais modifiée) partage la ligne de son joueur : qualités, note, base et spécialisation
 // sont lues sur le joueur (prototype) ; seule la famille diffère, et ni skill ni roleNote (famille explicite) ne la lisent
 // quand les qualités existent (sinon ensureSkills les créerait sur la vue, d'après sa famille : ligne propre).
 const memoKey=p=>p.skills&&viewOf.get(p)||p;
 function memoSkill(p,k,fit=false){
  if(!p)return memoSkillBase(p,k,fit);
  const row=memoRow(stepMemo.skill,memoKey(p));let n=row[k];
  if(n===undefined){n=memoSkillBase(p,k,false);row[k]=n;}
  // Fatigue des phases arrêtées (fit==='arrete', voir fitArrete) : même pondération que skill.
  if(!fit)return n;const perte=.5-p.condition*.005,w=fit==='arrete'?FATIGUE_ARRETE[k]:undefined;return n*(1-(w===undefined?1:w)*perte);
 }
 // Note de rôle : indépendante de la condition.
 function memoRole(p,f=p?.fam){
  if(!p)return memoRoleBase(p,f);
  const row=memoRow(stepMemo.role,memoKey(p));let n=row[f];
  if(n===undefined){n=memoRoleBase(p,f);row[f]=n;}
  return n;
 }
 function withMemo(memo,fn){
  const skill0=skill,role0=roleNote;
  stepMemo=memo;memoSkillBase=skill0;memoRoleBase=role0;skill=memoSkill;roleNote=memoRole;
  try{return fn();}finally{skill=skill0;roleNote=role0;stepMemo=memoSkillBase=memoRoleBase=null;}
 }
 const note=(p,f=p?.fam)=>stepMemo?memoRole(p,f):baseNote(p,f);
 // Joueur vu au poste du maillot (prototype = le joueur, seule la famille est propre), réutilisé dans une mémoire.
 function slotView(p,slot){
  if(!stepMemo)return Object.assign(Object.create(p),{fam:FAMILIES[slot]});
  const row=memoRow(stepMemo.views,p);let v=row[slot];
  if(v===undefined){v=Object.assign(Object.create(p),{fam:FAMILIES[slot]});row[slot]=v;viewOf.set(v,p);}
  return v;
 }
 function efficiencyNow(p,slot){const f=FAMILIES[positionNumber(slot)-1],data=derive(p);return Math.min(1,data.positionRatings[positionNumber(slot)]/Math.max(1,data._familyNotes[f]));}
 function efficiency(p,slot){
  if(!stepMemo||!p)return efficiencyNow(p,slot);
  const row=memoRow(stepMemo.efficiency,p);let v=row[slot];
  if(v===undefined){v=efficiencyNow(p,slot);row[slot]=v;}
  return v;
 }
 function contextualSkill(p,key,slot,fit=true){return skill(p,key,fit)*efficiency(p,slot);}
 let reservations=null,installed=false;
 function eligible(p,slot){
  if(!p)return false;
  if(reservations?.has(p.id)&&reservations.get(p.id)!==slot)return false;
  const n=positionNumber(slot);
  return n<=3?(slot<15?baseSlot(p,slot):baseBench(p,slot-15)):true;
 }
 const eligibleSlot=eligible;
 // Reserve a complete matching of the six designated front-row shirts before
 // greedy selection can use one of those specialists as an emergency back.
 function availablePool(team){
  let pool=team.players.filter(p=>!p.injury);
  if(typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(S)){
   const fixture=CDWorldCareer.fixtures(S).find(f=>f.homeId===team.id||f.awayId===team.id);if(fixture)pool=pool.filter(p=>!CDWorldCareer.clubReleaseOn(S,p.id,fixture.date));
  }
  if(typeof CDWorldJapanQuota!=='undefined'&&CDWorldJapanQuota.activeClub(S,team.id)){
   const registered=CDWorldJapanQuota.registrationIds(S,team);pool=pool.filter(p=>registered.has(p.id));
  }
  return pool;
 }
 // Les six maillots de première ligne sont attribués par ordre de priorité (n°1, 2, 3 puis les
 // trois places de banc), chacun au meilleur joueur qui laisse un jumelage complet possible aux
 // places suivantes. Un joueur n'est donc jamais déplacé du XV vers le banc pour servir une place
 // de banc : le meilleur pilier gauche, talonneur ou pilier droit dispo ouvre le match.
 // Jugement du staff (match-actions.js, lot 3) : pour la feuille du club du manager, la perception du staff
 // (erreur et penchant, déjà pondérés par la condition) s'ajoute aux notes de l'attribution des postes, sinon
 // l'attribution optimale (première ligne, postes 4 à 15, banc) effaçait ses erreurs. Clubs de l'IA : rien.
 let perception=null;
 function perceptionFor(team){try{return typeof staffSheetJudges==='function'&&typeof perceivedParts==='function'?staffSheetJudges(team):null;}catch(e){return null;}}
 function perceived(p,f){if(!perception)return 0;const x=perceivedParts(perception,p,f);return x.erreur+x.penchant;}
 function reserveFront(team,preferred,bench){
  const prefs=Array.from({length:23},(_,i)=>i<15?preferred[i]:bench[i-15]),frontSlots=[0,1,2,15,16,17],assigned=new Map();
  const pool=availablePool(team);
  const fixedOther=new Set(prefs.filter((id,i)=>id&&!frontSlots.includes(i)));
  // Même pondération par la condition que fitScore : un pilier épuisé ne passe pas devant un pilier frais.
  const notes=new Map(),weighted=p=>{let w=notes.get(p);if(w===undefined){w=baseNote(p)*(.5+p.condition*.005)+perceived(p,p.fam);notes.set(p,w);}return w;};
  const options=new Map(frontSlots.map(slot=>[slot,pool.filter(p=>!fixedOther.has(p.id)&&(slot<15?baseSlot(p,slot):baseBench(p,slot-15)))
   .sort((a,b)=>Number(b.id===prefs[slot])-Number(a.id===prefs[slot])||weighted(b)-weighted(a)||compareId(a,b))]));
  // Taille du plus grand jumelage places/joueurs sur ces places, sans les joueurs déjà retenus.
  function maxMatch(slots,used){
   const owner=new Map();
   function place(slot,seen){
    for(const p of options.get(slot)){
     if(used.has(p.id)||seen.has(p.id))continue;seen.add(p.id);
     if(!owner.has(p.id)||place(owner.get(p.id),seen)){owner.set(p.id,slot);return true;}
    }return false;
   }
   let size=0;for(const slot of slots)if(place(slot,new Set()))size++;return size;
  }
  const used=new Set();
  frontSlots.forEach((slot,index)=>{
   const rest=frontSlots.slice(index+1),best=maxMatch(frontSlots.slice(index),used);
   for(const p of options.get(slot)){
    if(used.has(p.id))continue;
    used.add(p.id);
    if(1+maxMatch(rest,used)===best){assigned.set(slot,p.id);return;}
    used.delete(p.id);
   }
  });
  return new Map([...assigned].map(([slot,id])=>[id,slot]));
 }
 function installHooks(){
  if(installed)return;installed=true;
  const oldBuild=buildSheet,oldManager=managerSheet,oldStrategic=strategicPlayerScore;
  // Pas de match avec mémoire (voir stepMemo) ; un pas imbriqué garde la mémoire du pas qui l'englobe.
  if(typeof advanceRugby==='function'){
   const oldAdvance=advanceRugby;
   // Rencontre de l'ordinateur (userSide −1, simulée d'un seul tenant) : la mémoire dure tout le match, rien ne
   // s'exécutant entre deux pas ; elle est abandonnée au coup de sifflet final (progression appliquée ensuite).
   const matchMemos=new WeakMap();
   advanceRugby=function(l){
    if(stepMemo)return oldAdvance.apply(this,arguments);
    const whole=!!l&&typeof l==='object'&&l.userSide===-1,memo=whole&&matchMemos.get(l)||newMemo(),self=this,args=arguments;
    try{return withMemo(memo,()=>oldAdvance.apply(self,args));}
    finally{if(whole){if(l.finished)matchMemos.delete(l);else matchMemos.set(l,memo);}}
   };
   Object.assign(advanceRugby,oldAdvance);
  }
  // Composition des équipes d'une rencontre de l'ordinateur (createRugbyMatch automatisé : feuilles, choix du
  // manager) : mêmes garanties, la mémoire vit le temps de la création. Les recrues et prêts éventuels sont de
  // nouveaux joueurs (ou des joueurs déplacés sans changer de qualités) : ils ont leur propre ligne.
  if(typeof createRugbyMatch==='function'){
   const oldCreate=createRugbyMatch;
   createRugbyMatch=function(pair,legacy,automated){
    if(stepMemo||automated!==true)return oldCreate.apply(this,arguments);
    const self=this,args=arguments;return withMemo(newMemo(),()=>oldCreate.apply(self,args));
   };
   Object.assign(createRugbyMatch,oldCreate);
  }
  slotEligible=(p,slot)=>eligible(p,slot);benchEligible=(p,slot)=>eligible(p,slot+15);
  fitScore=(p,f=p.fam)=>{
   const n=FAMILIES.indexOf(f);return (f===p.fam?note(p):rating(p,n))*(.5+p.condition*.005);
  };
  // Joueur vu au poste du maillot : vue légère (prototype = le joueur, seule la famille est propre) au lieu d'une copie
  // complète à chaque note ; oldStrategic ne fait que lire (comme unit et sheetAverage ci-dessous).
  strategicPlayerScore=(p,slot,...args)=>oldStrategic(slotView(p,slot),slot,...args)*efficiency(p,slot);
  function improveBench(team,sheet,preferred=[]){
   const used=new Set(sheet.lineup.filter(Boolean)),wanted=[],pool=availablePool(team);
   for(let i=0;i<8;i++){
    const slot=i+15;
    let p=pool.find(p=>p.id===preferred[i]&&!p.injury&&!used.has(p.id)&&eligible(p,slot));
    if(!p&&i<3)p=pool.find(p=>p.id===sheet.bench[i]);
    if(!p){
     // Meilleur candidat (note au poste pondérée, puis identifiant) : un seul passage, notes calculées une fois.
     let bestValue=-Infinity;
     for(const q of pool){
      if(q.injury||used.has(q.id)||!eligible(q,slot))continue;
      const value=rating(q,slot)*(.5+q.condition*.005)+perceived(q,q.fam);
      if(!p||value>bestValue||value===bestValue&&compareId(q,p)<0){p=q;bestValue=value;}
     }
    }
    wanted.push(p?.id??null);if(p)used.add(p.id);
   }
   // Existing registration/quota hooks remain the final authority.
   return oldBuild(team,sheet.lineup,wanted);
  }
  // Attribution optimale des postes 4 à 15 : la boucle d'origine remplit les maillots dans l'ordre et
  // peut priver un poste de son spécialiste (un arrière pris à l'aile, un ouvreur au centre, un
  // troisième ligne à l'ouverture). On maximise ici la somme des notes au poste, pondérées par la
  // condition (algorithme hongrois, déterministe), sur les joueurs valides du groupe.
  function optimiseBack(team,sheet){
   const slots=[];for(let i=3;i<15;i++)slots.push(i);
   const fixed=new Set([...sheet.lineup.slice(0,3),...sheet.bench.slice(0,3)].filter(Boolean));
   // Admissibilité et notes calculées une seule fois par joueur (même résultat que eligible/rating par case).
   const candidates=[];
   for(const p of availablePool(team)){
    if(fixed.has(p.id))continue;
    const ok=slots.map(i=>eligible(p,i));
    if(ok.some(Boolean)){const notes=derive(p).positionRatings,weight=.5+p.condition*.005;candidates.push({p,ok,value:slots.map(i=>-((notes[positionNumber(i)]??0)*weight+perceived(p,FAMILIES[i])))});}
   }
   candidates.sort((a,b)=>compareId(a.p,b.p));
   const cols=candidates.map(c=>c.p);
   if(cols.length<slots.length)return sheet;
   const n=slots.length,m=cols.length,BIG=1e6;
   const cost=slots.map((i,r)=>candidates.map(c=>c.ok[r]?c.value[r]:BIG));
   // Hongrois rectangulaire (n lignes <= m colonnes), lignes et colonnes numérotées à partir de 1.
   const u=new Array(n+1).fill(0),v=new Array(m+1).fill(0),way=new Array(m+1).fill(0),match=new Array(m+1).fill(0);
   for(let i=1;i<=n;i++){
    match[0]=i;let j0=0;const minv=new Array(m+1).fill(Infinity),used=new Array(m+1).fill(false);
    do{
     used[j0]=true;const i0=match[j0];let delta=Infinity,j1=0;
     for(let j=1;j<=m;j++)if(!used[j]){
      const cur=cost[i0-1][j-1]-u[i0]-v[j];
      if(cur<minv[j]){minv[j]=cur;way[j]=j0;}
      if(minv[j]<delta){delta=minv[j];j1=j;}
     }
     for(let j=0;j<=m;j++){if(used[j]){u[match[j]]+=delta;v[j]-=delta;}else minv[j]-=delta;}
     j0=j1;
    }while(match[j0]!==0);
    do{const j1=way[j0];match[j0]=match[j1];j0=j1;}while(j0);
   }
   const lineup=sheet.lineup.slice();
   for(let j=1;j<=m;j++)if(match[j]&&cost[match[j]-1][j-1]<BIG)lineup[slots[match[j]-1]]=cols[j-1].id;
   if(new Set(lineup.filter(Boolean)).size!==lineup.filter(Boolean).length)return sheet;
   return {...sheet,lineup};
  }
  // Règle de quota (JIFF ou EQP : `target` qualifiés sur les 23) intégrée à l'attribution : on
  // remplace un non-JIFF par un JIFF disponible en minimisant la perte de note au poste (banc
  // pondéré à moitié, donc sacrifié en premier), jamais en dessous de 40 au poste tant qu'une
  // autre option existe. Cas limite : sans JIFF jouable au poste, le quota prime (meilleure option).
  function jiffFit(team,sheet){
   const quota=quotaOf(team);if(!quota)return sheet;
   const pool=availablePool(team),byId=new Map(team.players.map(p=>[p.id,p]));
   const slots=sheet.lineup.concat(sheet.bench),used=new Set(slots.filter(Boolean));
   let count=slots.filter(id=>id&&quota.yes(byId.get(id))).length;
   const value=(p,k)=>rating(p,k)*(.5+p.condition*.005);
   const jiffs=pool.filter(p=>quota.yes(p)).sort(compareId);
   while(count<quota.target){
    let best=null;
    for(let k=0;k<slots.length;k++){
     const cur=byId.get(slots[k]);if(!cur||quota.yes(cur))continue;
     for(const p of jiffs){
      if(used.has(p.id)||!eligible(p,k))continue;
      const loss=(value(cur,k)-value(p,k))*(k>=15?.5:1)+(rating(p,k)<40?1000:0);
      if(!best||loss<best.loss-1e-9)best={k,p,loss};
     }
    }
    if(!best)break;
    used.delete(slots[best.k]);used.add(best.p.id);slots[best.k]=best.p.id;count++;
   }
   quotaPolish(slots,pool,byId,quota,used);
   return {...sheet,lineup:slots.slice(0,15),bench:slots.slice(15)};
  }
  // Après le remplissage glouton du quota, la feuille peut garder un mauvais échange : un qualifié faible au XV
  // et un qualifié fort au banc, ou un non-qualifié de 80 hors du groupe alors qu'un autre non-qualifié pouvait
  // céder sa place à un qualifié presque aussi bon (relevé du 20/11/2026 après le barème V3 : Newcastle titularisait
  // un ailier de 57 avec un ailier qualifié de 74 au banc). On améliore donc la feuille par petits mouvements qui ne
  // font jamais baisser le nombre de qualifiés retenus : échange de deux places, entrée d'un joueur libre, ou paire
  // d'entrées dont le solde de qualifiés est nul. Première ligne (n°1 à 3 et trois places de banc) intouchée.
  function quotaPolish(slots,pool,byId,quota,used){
   const open=[];for(let k=3;k<slots.length;k++)if(k<15||k>=18)open.push(k);
   const weight=k=>k>=15?.5:1;
   // Valeurs et admissibilités calculées une fois par joueur et par place pour toute la retouche.
   const memo=new Map(),okMemo=new Map();
   const value=(p,k)=>{const key=p.id+'|'+k;let v=memo.get(key);if(v===undefined){const r=rating(p,k);v=(r*(.5+p.condition*.005)+perceived(p,k<15?FAMILIES[k]:p.fam)-(r<40?1000:0))*weight(k);memo.set(key,v);}return v;};
   const eligible=(p,k)=>{const key=p.id+'|'+k;let v=okMemo.get(key);if(v===undefined){v=eligibleSlot(p,k);okMemo.set(key,v);}return v;};
   const free=pool.filter(p=>!p.injury).sort(compareId);
   let count=slots.filter(id=>id&&quota.yes(byId.get(id))).length;
   // Plancher : le nombre de qualifiés déjà retenu (jamais moins que le quota) ; la retouche ne rogne pas la marge.
   const floor=Math.max(quota.target,count);
   for(let round=0;round<40;round++){
    let best=null;const minus=[],plus=[];
    const consider=m=>{if(m.gain<=1e-9&&m.dq>=0)return;if(m.dq>=0||count+m.dq>=floor){if(m.gain>1e-9&&(!best||m.gain>best.gain+1e-9))best=m;}else if(m.dq<0)minus.push(m);};
    for(let a=0;a<open.length;a++){
     const k=open[a],cur=byId.get(slots[k]);if(!cur)continue;
     for(let b=a+1;b<open.length;b++){
      const j=open[b],other=byId.get(slots[j]);if(!other||!eligible(cur,j)||!eligible(other,k))continue;
      consider({kind:'swap',k,j,dq:0,gain:value(other,k)+value(cur,j)-value(cur,k)-value(other,j)});
     }
     const qc=quota.yes(cur)?1:0;
     for(const p of free){
      if(used.has(p.id)||!eligible(p,k))continue;
      const m={kind:'in',k,p,dq:(quota.yes(p)?1:0)-qc,gain:value(p,k)-value(cur,k)};
      if(m.dq>0)plus.push(m);consider(m);
     }
    }
    // Paire d'entrées à solde nul : un non-qualifié gagne une place, un qualifié en prend une autre.
    for(const m of minus.sort((x,y)=>y.gain-x.gain).slice(0,8))for(const n of plus){
     if(n.k===m.k||n.p.id===m.p.id)continue;const gain=m.gain+n.gain;
     if(gain>1e-9&&(!best||gain>best.gain+1e-9))best={kind:'pair',m,n,dq:0,gain};
    }
    if(!best)break;
    const enter=m=>{used.delete(slots[m.k]);used.add(m.p.id);slots[m.k]=m.p.id;count+=m.dq;};
    if(best.kind==='swap'){const t=slots[best.k];slots[best.k]=slots[best.j];slots[best.j]=t;}
    else if(best.kind==='in')enter(best);
    else{enter(best.m);enter(best.n);}
   }
  }
  function reservedBuild(fn,team,preferred=[],bench=[],...args){
   if(reservations)return fn(team,preferred,bench,...args);
   perception=perceptionFor(team);reservations=reserveFront(team,preferred,bench);
   try{
    let sheet=fn(team,preferred,bench,...args);
    // Une feuille choisie à la main (postes préférés) n'est jamais réattribuée.
    if(!preferred.some(Boolean)&&!bench.some(Boolean)){
     sheet=optimiseBack(team,sheet);
    }
    sheet=improveBench(team,sheet,bench);
    // Règle JIFF : appliquée en dernier, sur la feuille définitive, en tenant compte des postes.
    return !preferred.some(Boolean)&&!bench.some(Boolean)?jiffFit(team,sheet):sheet;
   }finally{reservations=null;perception=null;}
  }
  buildSheet=(team,preferred=[],bench=[])=>reservedBuild(oldBuild,team,preferred,bench);
  managerSheet=(team,...args)=>{
   if(reservations)return oldManager(team,...args);
   perception=perceptionFor(team);reservations=reserveFront(team,[],[]);try{return jiffFit(team,improveBench(team,oldManager(team,...args)));}finally{reservations=null;perception=null;}
  };
  unit=(live,side,key,filter)=>{
   // Une seule passe sans objets intermédiaires (appelée des dizaines de fois par action) : mêmes joueurs retenus,
   // mêmes valeurs dans le même ordre, donc la même moyenne. Filtre et note ne modifient pas les joueurs (ni la vue au
   // poste, reprise de la mémoire du match quand elle existe).
   const on=live.sheets[side].on,players=activePlayers(live,side),values=[],fit=fitArrete(live); // fatigue des phases arrêtées (dist/matchflow.js)
   for(const p of players){const slot=on.indexOf(p.id);if(filter&&!filter(slotView(p,slot)))continue;values.push(contextualSkill(p,key,slot,fit));}
   return values.length?mean(values):25;
  };
  sheetAverage=(team,ids,key,filter=()=>true)=>{
   const list=ids.map((id,slot)=>({p:team.players.find(p=>p.id===id),slot})).filter(({p,slot})=>p&&filter(Object.assign(Object.create(p),{fam:FAMILIES[slot]})));
   return list.length?mean(list.map(({p,slot})=>contextualSkill(p,key,slot))):25;
  };
  dossierMetrics=(team,ids)=>{
   const players=ids.map(id=>team.players.find(p=>p.id===id)).filter(Boolean);
   const domains=Object.fromEntries(DOSSIER_DOMAINS.map(d=>{
    const has=ids.some((id,slot)=>id&&team.players.some(p=>p.id===id)&&d.families.includes(FAMILIES[slot]));
    return [d.key,has?mean(d.skills.map(key=>sheetAverage(team,ids,key,p=>d.families.includes(p.fam)))):0];
   }));
   return {...domains,fitness:mean(players.map(p=>p.condition)),tackle:players.length?sheetAverage(team,ids,'tackle'):0,speed:players.length?sheetAverage(team,ids,'speed'):0};
  };
 }
 // Alerte de fatigue de Gabi : titulaires de la feuille sous `seuil` % de condition et, pour chacun, le
 // meilleur remplaçant frais au poste. Même règles que la sélection du staff : joueurs disponibles
 // (blessés, libérés en sélection nationale, inscrits League One), admissibilité au poste, note au poste
 // pondérée par la condition, règle JIFF (jamais sous min(JIFF de la feuille, cible)). Un remplaçant du banc
 // est préféré (la feuille garde les mêmes 23 joueurs : quota et inscriptions inchangés) ; un joueur hors
 // groupe n'est proposé qu'en dernier recours, jamais sous quota League One. L'ancien titulaire ne doit pas
 // laisser un poste de banc vide : il doit pouvoir y prendre la place du remplaçant.
 function fatigueAdvice(team,lineup,bench,seuil=70){
  if(!team||!Array.isArray(lineup)||!Array.isArray(bench))return null;
  const byId=new Map(team.players.map(p=>[p.id,p]));
  const tired=[];
  for(let k=0;k<15;k++){const p=byId.get(lineup[k]);if(p&&!p.injury&&p.condition<seuil)tired.push({slot:k,p});}
  if(!tired.length)return null;
  tired.sort((a,b)=>a.p.condition-b.p.condition||a.slot-b.slot);
  const pool=availablePool(team),inXV=new Set(lineup.filter(Boolean)),slots=lineup.concat(bench),inGroup=new Set(slots.filter(Boolean));
  const qd=quotaOf(team),jiffOn=!!qd;
  const isJ=p=>jiffOn&&qd.yes(p);
  let jiffCount=jiffOn?slots.map(id=>byId.get(id)).filter(p=>p&&isJ(p)).length:0;
  const quota=typeof CDWorldJapanQuota!=='undefined'&&CDWorldJapanQuota.activeClub(S,team.id);
  const value=(p,k)=>rating(p,k)*(.5+p.condition*.005);
  const used=new Set(),changes=[],unresolved=[];
  for(const {slot,p:sortant} of tired){
   let best=null;
   for(const q of pool){
    if(used.has(q.id)||inXV.has(q.id)||q.condition<75||q.condition<sortant.condition+10||!eligible(q,slot)||rating(q,slot)<40)continue;
    const bi=bench.indexOf(q.id),fromBench=bi>=0;
    if(fromBench){if(!eligible(sortant,15+bi))continue;}
    else if(quota)continue;
    else if(jiffOn&&isJ(sortant)&&!isJ(q)&&jiffCount<=qd.target)continue;
    const v=value(q,slot)+(fromBench?1000:0);
    if(!best||v>best.v+1e-9||Math.abs(v-best.v)<=1e-9&&compareId(q,best.q)<0)best={q,v,fromBench};
   }
   if(!best){unresolved.push(sortant.id);continue;}
   used.add(best.q.id);
   if(!best.fromBench&&jiffOn)jiffCount+=(isJ(best.q)?1:0)-(isJ(sortant)?1:0);
   changes.push({slot,playerId:best.q.id,sortant:sortant.id,condition:Math.floor(sortant.condition),entrantCondition:Math.round(best.q.condition),rating:Math.round(rating(best.q,slot)),sortantRating:Math.round(rating(sortant,slot)),fromBench:best.fromBench});
  }
  return {threshold:seuil,count:tired.length,starters:tired.map(({slot,p})=>({slot,playerId:p.id,condition:Math.floor(p.condition)})),changes,unresolved};
 }
 // Alerte de quota de Gabi (JIFF en Top 14 / Pro D2, EQP en Premiership) : la feuille du prochain match de championnat
 // aligne moins de qualifiés (doublon de JIFF convoqués en équipe de France compris) que la trajectoire de moyenne
 // exigée (CDJiff.standing) ; propose pour chaque manque un échange concret (non qualifié sorti, qualifié disponible
 // du même poste entré, perte de note minimale). null : rien à signaler.
 function quotaAdvice(team,lineup,bench){
  if(!team||!Array.isArray(lineup)||!Array.isArray(bench)||typeof CDJiff==='undefined'||!CDJiff.standing)return null;
  const qd=quotaOf(team);if(!qd)return null;
  const st=CDJiff.standing(S,team.id);if(!st||!st.nextIsLeague||st.need===null)return null;
  const slots=lineup.concat(bench),byId=new Map(team.players.map(p=>[p.id,p])),onSheet=new Set(slots.filter(Boolean));
  const sheet=slots.filter(id=>id&&qd.yes(byId.get(id))).length,twice=CDJiff.doublon(S,team,st.nextDate,onSheet),current=sheet+twice,missing=st.need-current;
  if(missing<=0)return null;
  const changes=CDJiff.advise(S,team.id,slots,{pool:availablePool(team),rating,eligible,missing:Math.min(missing,4)});
  return {kind:st.kind,label:st.label,target:st.target,need:st.need,current,sheet,doublon:twice,average:st.average,sheets:st.sheets,remaining:st.remaining,outOfReach:st.outOfReach,missing,changes};
 }
 return Object.freeze({project,positionNumber,rating,efficiency,contextualSkill,installHooks,fatigueAdvice,quotaAdvice});
};
