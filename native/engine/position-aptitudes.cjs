'use strict';
// Inject once, after explicit Nationale/Japan qualification hooks. This is a
// fictional sporting model, not a source of first-row training qualifications.
module.exports=function positionAptitudes(){
 const baseSlot=slotEligible,baseBench=benchEligible,baseNote=roleNote;
 const cover=[2,1,3,4,6,9,10,11],adjacent=[[],[],[3],[2],[5,6],[4,8,7],[7,8],[6,8,5],[6,5,7]];
 const critical=[['scrum','power'],['lineout','scrum'],['lineout','tackle'],['tackle','stamina'],['pass','mental'],['pass','kick'],['speed'],['pass','tackle'],['kick','speed']];
 const cache=new Map(),playerCache=new WeakMap(),keys=Object.keys(ATTR);
 const compareId=(a,b)=>String(a.id)<String(b.id)?-1:String(a.id)>String(b.id)?1:0;
 function positionNumber(slot){return slot<15?slot+1:cover[slot-15]??null;}
 function derive(p){
  if(!p)return {primaryPosition:null,primaryPositions:[],secondaryPositions:[],positionRatings:{},qualifiedFrontRowPositions:[]};
  const qualifierKey=[p.nationaleQualifications?.join('|'),p.worldProfile?.position?.qualifications?.join('|'),p.worldRatingsVersion].join(';');
  const cached=playerCache.get(p);
  if(cached&&cached.id===p.id&&cached.name===p.name&&cached.rating===p.rating&&cached.skillBase===p.skillBase&&cached.pos===p.pos&&cached.fam===p.fam&&cached.qualifierKey===qualifierKey){
   // Boucle simple (et non keys.every avec fermeture) : derive est appelée des milliers de fois par feuille.
   let same=true;for(let i=0;i<keys.length;i++){const k=keys[i];if(cached.skills[i]!==p.skills?.[k]||cached.bonuses[i]!==focusedBonus(p,k)){same=false;break;}}
   if(same)return cached.result;
  }
  // Legacy missing skills are deterministically generated on a detached object.
  const q=p.skills?p:{...p};ensureSkills(q);
  const qualities=keys.map(k=>skill(q,k));
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
    const value=familyNotes[f];return value>=Math.max(55,main*.90)&&critical[f].every(k=>skill(q,k)>=Math.max(50,main*.72));
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
  playerCache.set(p,{id:p.id,name:p.name,rating:p.rating,skillBase:p.skillBase,pos:p.pos,fam:p.fam,qualifierKey,skills:keys.map(k=>p.skills?.[k]),bonuses:keys.map(k=>focusedBonus(p,k)),result});
  return result;
 }
 function project(p){
  const {_familyNotes,...result}=derive(p);
  return {...result,primaryPositions:result.primaryPositions.slice(),secondaryPositions:result.secondaryPositions.slice(),positionRatings:{...result.positionRatings},qualifiedFrontRowPositions:result.qualifiedFrontRowPositions.slice()};
 }

 function rating(p,slot){return derive(p).positionRatings[positionNumber(slot)]??0;}
 function efficiency(p,slot){const f=FAMILIES[positionNumber(slot)-1],data=derive(p);return Math.min(1,data.positionRatings[positionNumber(slot)]/Math.max(1,data._familyNotes[f]));}
 function contextualSkill(p,key,slot){return skill(p,key,true)*efficiency(p,slot);}
 let reservations=null,installed=false;
 function eligible(p,slot){
  if(!p)return false;
  if(reservations?.has(p.id)&&reservations.get(p.id)!==slot)return false;
  const n=positionNumber(slot);
  return n<=3?(slot<15?baseSlot(p,slot):baseBench(p,slot-15)):true;
 }
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
 function reserveFront(team,preferred,bench){
  const prefs=Array.from({length:23},(_,i)=>i<15?preferred[i]:bench[i-15]),frontSlots=[0,1,2,15,16,17],assigned=new Map();
  const pool=availablePool(team);
  const fixedOther=new Set(prefs.filter((id,i)=>id&&!frontSlots.includes(i)));
  // Même pondération par la condition que fitScore : un pilier épuisé ne passe pas devant un pilier frais.
  const notes=new Map(),weighted=p=>{let w=notes.get(p);if(w===undefined){w=baseNote(p)*(.5+p.condition*.005);notes.set(p,w);}return w;};
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
  slotEligible=(p,slot)=>eligible(p,slot);benchEligible=(p,slot)=>eligible(p,slot+15);
  fitScore=(p,f=p.fam)=>{
   const n=FAMILIES.indexOf(f);return (f===p.fam?baseNote(p):rating(p,n))*(.5+p.condition*.005);
  };
  strategicPlayerScore=(p,slot,...args)=>oldStrategic({...p,fam:FAMILIES[slot]},slot,...args)*efficiency(p,slot);
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
      const value=rating(q,slot)*(.5+q.condition*.005);
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
    if(ok.some(Boolean)){const notes=derive(p).positionRatings,weight=.5+p.condition*.005;candidates.push({p,ok,value:slots.map(i=>-(notes[positionNumber(i)]??0)*weight)});}
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
  // Règle JIFF (CDJiff.target joueurs formés en France sur les 23) intégrée à l'attribution : on
  // remplace un non-JIFF par un JIFF disponible en minimisant la perte de note au poste (banc
  // pondéré à moitié, donc sacrifié en premier), jamais en dessous de 40 au poste tant qu'une
  // autre option existe. Cas limite : sans JIFF jouable au poste, le quota prime (meilleure option).
  function jiffFit(team,sheet){
   if(typeof CDJiff==='undefined'||!CDJiff.isJiff||!CDJiff.target||typeof S==='undefined'||S?.jiff?.version!==1||team.id===undefined)return sheet;
   const leagues=CDJiff.subjectLeagues(S);if(!leagues||!Object.values(leagues).some(l=>l.includes(team.id)))return sheet;
   const pool=availablePool(team),byId=new Map(team.players.map(p=>[p.id,p]));
   const slots=sheet.lineup.concat(sheet.bench),used=new Set(slots.filter(Boolean));
   let count=slots.filter(id=>id&&CDJiff.isJiff(S,byId.get(id))).length;
   const value=(p,k)=>rating(p,k)*(.5+p.condition*.005);
   const jiffs=pool.filter(p=>CDJiff.isJiff(S,p)).sort(compareId);
   while(count<CDJiff.target){
    let best=null;
    for(let k=0;k<slots.length;k++){
     const cur=byId.get(slots[k]);if(!cur||CDJiff.isJiff(S,cur))continue;
     for(const p of jiffs){
      if(used.has(p.id)||!eligible(p,k))continue;
      const loss=(value(cur,k)-value(p,k))*(k>=15?.5:1)+(rating(p,k)<40?1000:0);
      if(!best||loss<best.loss-1e-9)best={k,p,loss};
     }
    }
    if(!best)break;
    used.delete(slots[best.k]);used.add(best.p.id);slots[best.k]=best.p.id;count++;
   }
   return {...sheet,lineup:slots.slice(0,15),bench:slots.slice(15)};
  }
  function reservedBuild(fn,team,preferred=[],bench=[],...args){
   if(reservations)return fn(team,preferred,bench,...args);
   reservations=reserveFront(team,preferred,bench);
   try{
    let sheet=fn(team,preferred,bench,...args);
    // Une feuille choisie à la main (postes préférés) n'est jamais réattribuée.
    if(!preferred.some(Boolean)&&!bench.some(Boolean)){
     sheet=optimiseBack(team,sheet);
    }
    sheet=improveBench(team,sheet,bench);
    // Règle JIFF : appliquée en dernier, sur la feuille définitive, en tenant compte des postes.
    return !preferred.some(Boolean)&&!bench.some(Boolean)?jiffFit(team,sheet):sheet;
   }finally{reservations=null;}
  }
  buildSheet=(team,preferred=[],bench=[])=>reservedBuild(oldBuild,team,preferred,bench);
  managerSheet=(team,...args)=>{
   if(reservations)return oldManager(team,...args);
   reservations=reserveFront(team,[],[]);try{return jiffFit(team,improveBench(team,oldManager(team,...args)));}finally{reservations=null;}
  };
  unit=(live,side,key,filter)=>{
   const on=live.sheets[side].on,players=activePlayers(live,side);
   const list=players.map(p=>({p,slot:on.indexOf(p.id)})).filter(({p,slot})=>!filter||filter({...p,fam:FAMILIES[slot]}));
   return list.length?mean(list.map(({p,slot})=>contextualSkill(p,key,slot))):25;
  };
  sheetAverage=(team,ids,key,filter=()=>true)=>{
   const list=ids.map((id,slot)=>({p:team.players.find(p=>p.id===id),slot})).filter(({p,slot})=>p&&filter({...p,fam:FAMILIES[slot]}));
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
 return Object.freeze({project,positionNumber,rating,efficiency,contextualSkill,installHooks});
};
