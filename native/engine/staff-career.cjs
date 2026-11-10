'use strict';
const files=Object.freeze([]),commands=Object.freeze(['staff_career_enable','staff_hire','staff_renew','staff_release','staff_retire']);
// Serialized in the native VM. Registry inputs are read only; no RNG, disk or cash changes.
function factory(){
 // Trusted local policy is inlined into the exported factory below so VM callers
 // need neither require() nor another global or protocol-supplied code.
 const completion=(function staffCompletionPolicy(){return null;})();
 const POLICY='staff-career-v1',FINANCE='descriptive-no-cost-v1',CORE=['coach','assistant','formation','scout','analyst'];
 const ROLES=[...CORE,'medical','fitness','support'],LABELS={coach:'Entraîneur',assistant:'Adjoint',formation:'Formation',scout:'Recruteur',analyst:'Analyste',medical:'Médical',fitness:'Préparation physique',support:'Encadrement'};
 const copy=x=>JSON.parse(JSON.stringify(x));
 const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x),int=(n,a,b)=>Number.isSafeInteger(n)&&n>=a&&n<=b;
 const shape=(x,keys)=>object(x)&&Object.keys(x).length===keys.length&&Object.keys(x).every(k=>keys.includes(k));
 const appearanceShape=(x,keys)=>shape(x,x?.appearanceBankVersion===undefined?keys:[...keys,'appearanceBankVersion'])&&(x.appearanceBankVersion===undefined||x.appearanceBankVersion===1||x.appearanceBankVersion===2);
 const check=(yes,message)=>{if(!yes)throw Error('Carrières du staff : '+message+'.');};
 const identity=x=>typeof x==='string'&&/^[A-Za-z0-9:._-]{1,240}$/.test(x);
 const text=x=>String(x).replace(/&/g,' et ').replace(/"/g,'“').replace(/`/g,"'").replace(/</g,'‹').replace(/>/g,'›').replace(/[\u0000-\u001f\u007f]/g,' ').slice(0,160);
 const people=st=>st.people.flat();
 const setPeople=(st,rows)=>{st.people=[];for(let i=0;i<rows.length;i+=256)st.people.push(rows.slice(i,i+256));};
 const append=(st,p)=>{if(!st.people.length||st.people.at(-1).length>=256)st.people.push([]);st.people.at(-1).push(p);};
 const name=x=>typeof x==='string'&&x.length>0&&x.length<=160&&!/[<>"`&\u0000-\u001f\u007f]/.test(x);
 const hash=x=>{let n=2166136261;for(let i=0;i<x.length;i++)n=Math.imul(n^x.charCodeAt(i),16777619);return n>>>0;};
 const active=s=>s?.staffCareer?.version===1;
 const completed=s=>s?.staffCareer?.completionPolicy===completion.POLICY;
 const week=s=>s.franceMode?.week??s.round;
 const context=s=>({season:s.season,week:week(s),club:s.club});
 function sourceTeams(s){
  if(!s.commonDatabase?.id)return [];
  const sources=typeof nativeStaffCareerSources==='undefined'?null:nativeStaffCareerSources;
  const teams=sources?.[s.commonDatabase.id];
  check(Array.isArray(teams),'source initiale de cette édition indisponible');return teams;
 }
 function canonical(role){
  const value=String(role).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
  if(/medec|medical|kine|physio|doctor|osteop|infirm/.test(value))return 'medical';
  if(/physiq|fitness|strength|condition|s\s*&\s*c|preparateur/.test(value))return 'fitness';
  if(/analys|video|data/.test(value))return 'analyst';
  if(/recrut|scout/.test(value))return 'scout';
  if(/academ|format|espoir|jeune|develop/.test(value))return 'formation';
  if(/adjoint|assistant/.test(value))return 'assistant';
  if(/coach|entraine|manager|directeur sportif/.test(value))return 'coach';
  return 'support';
 }
 function event(s,kind,p,clubId=p.clubId){
  s.staffCareer.history.push({season:s.season,kind,id:p.id,clubId,name:p.name,role:p.role,appearanceId:p.appearanceId,appearanceAge:p.appearanceAge,age:p.age,sourcePlayerId:p.sourcePlayerId,...(p.appearanceBankVersion===undefined?{}:{appearanceBankVersion:p.appearanceBankVersion}),amount:0});
  s.staffCareer.history=s.staffCareer.history.slice(-512);
 }
 function person(s,{id,name:label,role,roleLabel=LABELS[role],sourceKind,sourceStaffId=null,sourcePlayerId=null,appearanceId=id,appearanceBankVersion=1,age,ageBasis='estimated',level,entrySeason=s.season,ageSeason=s.season,generation}){
  return {id,name:text(label),role,roleLabel:text(roleLabel),sourceKind,sourceStaffId,sourcePlayerId,appearanceId,...(appearanceBankVersion===2?{appearanceBankVersion:2}:{}),age,appearanceAge:age,ageAtEntry:age,entrySeason,ageSeason,
   ageBasis,...(generation?{generation:copy(generation)}:{}),conversion:null,retireAge:68+hash(id+':retire')%13,level,salary:0,clubId:null,contractEnd:null};
 }
 function generated(s,role,key=null,clubId=null){
  const n=++s.staffCareer.serial,id='staff-career:generated:'+s.season+':'+n;
  if(!completed(s))return person(s,{id,name:LABELS[role]+' de carrière '+n,role,sourceKind:'generated',appearanceBankVersion:2,age:30+hash(id+':age')%20,level:45+hash(id+':level')%31});
  key=key||Object.keys(completion.FUNCTIONS).find(k=>completion.FUNCTIONS[k].role===role);
  const club=clubId===null?null:s.clubs[clubId],settings={base:club?.base??72,function:key,country:club?.country||'FR'},used=new Set(people(s.staffCareer).map(p=>completion.norm(p.name)).concat(s.staffCareer.history.map(p=>completion.norm(p.name))));
  const profile=completion.uniqueProfile(id,settings,used),generation={policy:completion.POLICY,sourceId:null,...settings,nameSalt:profile.nameSalt};
  return person(s,{id,name:profile.name,role:profile.role,roleLabel:profile.roleLabel,sourceKind:'generated',appearanceBankVersion:2,age:profile.age,level:profile.level,generation});
 }
 function initialTeams(s,source=sourceTeams(s)){
  const members=new Map(source.map(c=>[c.id,c.members]));
  const clubs=s.clubs.map(c=>{const origin=s.staffCareer?.completionOrigins?.find(o=>o.clubId===c.id)||source.find(t=>t.id===c.id)?.completion||c;return {id:c.id,base:origin.base??65,country:origin.country||'FR'};});
  return completion.completeRegistry({databaseId:s.commonDatabase?.id||'fictional-'+s.clubs.length,clubs,registry:{clubs:s.clubs.map(c=>({id:c.id,members:members.get(c.id)||[]}))}}).clubs;
 }
 function fill(s,target){
  const own=()=>people(s.staffCareer).filter(p=>p.clubId===target.clubId);
  const hire=(role,key=null)=>{
   let p=people(s.staffCareer).filter(p=>p.clubId===null&&p.age<p.retireAge&&(key?completion.capabilities(p.roleLabel).includes(key):p.role===role)).sort((a,b)=>b.level-a.level||(a.id<b.id?-1:1))[0];
   if(!p){p=generated(s,role,key,target.clubId);append(s.staffCareer,p);}
   p.clubId=target.clubId;p.contractEnd=Math.min(s.season+1,s.season+p.retireAge-p.age-1);return p;
  };
  if(completed(s))for(const [key,n] of Object.entries(target.functions))while(completion.coverage(own())[key]<n)hire(completion.FUNCTIONS[key].role,key);
  for(const role of ROLES)while(own().filter(p=>p.role===role).length<target.roles[role])hire(role);
 }
 function prune(s){
  const employed=people(s.staffCareer).filter(p=>p.clubId!==null),available=people(s.staffCareer).filter(p=>p.clubId===null)
   .sort((a,b)=>b.entrySeason-a.entrySeason||b.level-a.level||(a.id<b.id?-1:1)).slice(0,192);
  setPeople(s.staffCareer,employed.concat(available));
  s.staffCareer.captured=s.staffCareer.captured.filter(row=>row.season>=s.season-1).slice(-1900);
 }
 function market(s){
  for(const role of CORE){
   const count=people(s.staffCareer).filter(p=>p.clubId===null&&p.role===role).length;
   for(let n=count;n<3;n++)append(s.staffCareer,generated(s,role));
  }
  if(completed(s))for(const key of Object.keys(completion.FUNCTIONS)){const count=people(s.staffCareer).filter(p=>p.clubId===null&&completion.capabilities(p.roleLabel).includes(key)).length;for(let n=count;n<3;n++)append(s.staffCareer,generated(s,completion.FUNCTIONS[key].role,key));}
  prune(s);
 }
 function initialize(s,teams){
  if(!s||active(s))return false;
  const source=teams??sourceTeams(s);if(!source)return false;
  check(Array.isArray(source)&&source.length<=s.clubs.length,'registre initial invalide');
  const members=new Map(source.map(c=>[c.id,c.members]));
  check(members.size===source.length&&source.every(c=>int(c.id,0,s.clubs.length-1)&&Array.isArray(c.members)),'clubs du staff invalides');
  const completionOrigins=s.clubs.map(c=>{const origin=source.find(t=>t.id===c.id)?.completion||c;return {clubId:c.id,base:origin.base??65,country:origin.country||'FR'};});
  const state={version:1,policy:POLICY,financialPolicy:FINANCE,completionPolicy:completion.POLICY,completionOrigins,activatedSeason:s.season,lastAdvancedSeason:s.season-1,serial:0,people:[],targets:[],history:[],captured:[]};
  s.staffCareer=state;
  const prepared=new Map(initialTeams(s,source).map(c=>[c.id,c.members]));
  for(const c of s.clubs){
   const roles=Object.fromEntries(ROLES.map(r=>[r,0]));
   for(const src of prepared.get(c.id)||[]){
    if(src.historical===true)continue;
    check(identity(src.id)&&typeof src.name==='string'&&src.name.trim().length>0&&src.name.length<=160,'identité initiale invalide');
    const role=completion.role(src.role),known=int(src.age,18,100);let p;
    if(src.sourceKind==='generated'){
     const meta=src.completion;check(meta?.policy===completion.POLICY&&Object.hasOwn(completion.FUNCTIONS,meta.function),'origine du complément fictif invalide');
     p=person(s,{id:'staff-career:generated:'+src.id,name:src.name,role,roleLabel:src.role,sourceKind:'generated',appearanceId:src.appearanceId,appearanceBankVersion:2,age:src.age,level:src.level,generation:{...copy(meta),sourceId:src.id}});
    }else{
     const age=(known?src.age:40+hash(src.id+':age')%26)+s.season-1;
     p=person(s,{id:'staff-career:reference:'+src.id,name:src.name,role,roleLabel:String(src.role||LABELS[role]).slice(0,160),sourceKind:'reference',sourceStaffId:src.id,appearanceId:src.id,
      age,ageBasis:known?(src.ageEstimated===true?'estimated':'published-derived'):'estimated',level:45+hash(src.id+':level')%31});
    }
    roles[role]++;
    if(p.age<p.retireAge){p.clubId=c.id;p.contractEnd=s.season+1;append(state,p);}
    else event(s,'reference-already-retired',p,c.id);
   }
   const target={clubId:c.id,roles,functions:copy(completion.MINIMUM)};state.targets.push(target);fill(s,target);
  }
  market(s);validate(s);return true;
 }
 function captureRetirement(s,p,ownerId=null){
  if(!active(s))return false;
  check(identity(p?.id)&&typeof p.name==='string'&&p.name.trim().length>0&&p.name.length<=6000&&int(p.age,16,120),'joueur retraité invalide');
  const st=s.staffCareer;
  if(st.captured.some(e=>e.playerId===p.id)||people(st).some(e=>e.sourcePlayerId===p.id))return false;
  st.captured.push({playerId:p.id,season:s.season});
  const minutes=Math.max(0,Number(p.dev?.careerMinutes)||0),rating=Number(p.rating)||0;
  if(p.age<28||!int(p.fam,0,8)||rating<60||(minutes<800&&rating<75)||hash(p.id+':reconversion')%3!==0){prune(s);return false;}
  const choices=p.fam<=3?['assistant','formation','scout']:CORE;
  const role=choices[hash(p.id+':staff-role')%choices.length];
  const q=person(s,{id:'staff-career:player:'+p.id,name:p.name,role,sourceKind:'retired-player',sourcePlayerId:p.id,appearanceId:p.id,appearanceBankVersion:p.appearanceBankVersion??1,
   age:p.age,ageBasis:'player-career',level:Math.max(40,Math.min(85,Math.round(rating*.6+(Number(p.skills?.mental)||rating)*.4))),entrySeason:s.season+1,ageSeason:s.season+1});
  q.conversion={retiredSeason:s.season,careerMinutes:minutes,family:p.fam,rating,mental:Number(p.skills?.mental)||rating,selection:'deterministic-third-v1'};
  // Conversion is a game opportunity, never a claim of a coaching/medical licence.
  if(q.age>=q.retireAge){prune(s);return false;}
  append(st,q);event(s,'player-conversion',q,ownerId);prune(s);return true;
 }
 function retire(s,p,kind='retirement'){
  event(s,kind,p);setPeople(s.staffCareer,people(s.staffCareer).filter(q=>q.id!==p.id));
 }
 function advance(s,completedSeason){
  if(!active(s))return false;
  const st=s.staffCareer;check(int(completedSeason,1,9999)&&s.season===completedSeason+1,'transition de saison invalide');
  if(st.lastAdvancedSeason>=completedSeason)return false;
  check(st.lastAdvancedSeason===completedSeason-1,'saison de staff manquante');
  for(const p of people(st).slice()){
   if(p.ageSeason<s.season){p.age+=s.season-p.ageSeason;p.ageSeason=s.season;}
   if(p.age>=p.retireAge){retire(s,p);continue;}
   if(p.clubId!==null&&p.contractEnd<s.season){
    if(p.clubId===s.club){event(s,'contract-ended',p);p.clubId=null;p.contractEnd=null;}
    else{p.contractEnd=Math.min(s.season+1,s.season+p.retireAge-p.age-1);event(s,'ai-renewal',p);}
   }
  }
  for(const target of st.targets){
   if(target.clubId===s.club)continue;
   const before=new Set(people(st).filter(p=>p.clubId===target.clubId).map(p=>p.id));fill(s,target);
   for(const p of people(st))if(p.clubId===target.clubId&&!before.has(p.id))event(s,'ai-hire',p);
  }
  st.lastAdvancedSeason=completedSeason;market(s);validate(s);return true;
 }
 const PERSON=['id','name','role','roleLabel','sourceKind','sourceStaffId','sourcePlayerId','appearanceId','age','appearanceAge','ageAtEntry','entrySeason','ageSeason','ageBasis','conversion','retireAge','level','salary','clubId','contractEnd'];
 function validate(s){
  if(!s||s.staffCareer===undefined)return true;
  const st=s.staffCareer;check(shape(st,['version','policy','financialPolicy',...(st.completionPolicy===undefined?[]:['completionPolicy','completionOrigins']),'activatedSeason','lastAdvancedSeason','serial','people','targets','history','captured'])&&st.version===1&&st.policy===POLICY&&st.financialPolicy===FINANCE&&(st.completionPolicy===undefined||completed(s)),'version ou champs inconnus');
  check(int(st.activatedSeason,1,s.season)&&st.lastAdvancedSeason===s.season-1&&int(st.serial,0,1000000),'horloge ou compteur invalide');
  check(Array.isArray(st.people)&&st.people.length<=32&&st.people.every(page=>Array.isArray(page)&&page.length<=256)&&people(st).length<=6000&&people(st).filter(p=>p.clubId===null).length<=192,'effectif de staff excessif');
  const originalSource=sourceTeams(s)||[];
  if(completed(s)){
   check(Array.isArray(st.completionOrigins)&&st.completionOrigins.length===s.clubs.length&&new Set(st.completionOrigins.map(o=>o.clubId)).size===s.clubs.length,'origines de complétion invalides');
   for(const o of st.completionOrigins){const src=originalSource.find(c=>c.id===o.clubId)?.completion;check(shape(o,['clubId','base','country'])&&int(o.clubId,0,s.clubs.length-1)&&int(o.base,0,100)&&typeof o.country==='string'&&/^[A-Z]{2}$/.test(o.country)&&(!src||src.policy===completion.POLICY&&o.base===src.base&&o.country===src.country),'origine initiale de club incohérente');}
  }
  const source=completed(s)?initialTeams(s,originalSource):originalSource,references=new Map(source.flatMap(c=>c.members.map(p=>[p.id,p])));
  const referenceRoleCounts=new Map(source.map(c=>{const counts=Object.fromEntries(ROLES.map(r=>[r,0]));for(const p of c.members)if(p.historical!==true&&p.sourceKind!=='generated')counts[canonical(p.role)]++;return[c.id,counts];}));
  const ids=new Set(),players=new Set(),activePlayerIds=new Set([...s.clubs.flatMap(c=>c.players||[]),...(s.market||[]),...(s.economy?.freeAgents||[]),...(s.development?.academy||[]),...(s.aiRoster?.academies||[]).flatMap(a=>a.players||[])].map(p=>p.id));
  for(const p of people(st)){
   check(appearanceShape(p,p.generation===undefined?PERSON:[...PERSON,'generation'])&&identity(p.id)&&!ids.has(p.id)&&name(p.name)&&name(p.roleLabel)&&ROLES.includes(p.role),'identité ou rôle invalide');ids.add(p.id);
   check(p.appearanceAge===p.ageAtEntry&&int(p.ageAtEntry,18,300)&&int(p.entrySeason,st.activatedSeason,s.season+1)&&int(p.ageSeason,p.entrySeason,s.season+1)&&p.age===p.ageAtEntry+p.ageSeason-p.entrySeason&&int(p.age,18,300)&&p.retireAge===68+hash(p.id+':retire')%13&&p.age<p.retireAge,'âge de carrière invalide');
   check(p.ageSeason===s.season||(p.sourceKind==='retired-player'&&p.entrySeason===s.season+1&&p.ageSeason===p.entrySeason&&p.conversion?.retiredSeason===s.season),'horloge personnelle invalide');
   check(['estimated','published-derived','player-career'].includes(p.ageBasis)&&int(p.level,40,85)&&p.salary===0,'estimation ou coût invalide');
   check((p.clubId===null&&p.contractEnd===null)||(int(p.clubId,0,s.clubs.length-1)&&int(p.contractEnd,s.season,Math.min(9999,s.season+3))),'contrat invalide');
   check(identity(p.appearanceId),'apparence invalide');
   if(p.sourceKind==='retired-player'){
    check(p.generation===undefined&&identity(p.sourcePlayerId)&&!players.has(p.sourcePlayerId)&&p.sourceStaffId===null&&p.id==='staff-career:player:'+p.sourcePlayerId&&p.appearanceId===p.sourcePlayerId&&p.ageBasis==='player-career'&&CORE.includes(p.role)&&(!completed(s)||p.roleLabel===LABELS[p.role]),'reconversion ou visage incohérent');players.add(p.sourcePlayerId);
    const witness=p.conversion;check(shape(witness,['retiredSeason','careerMinutes','family','rating','mental','selection'])&&int(witness.retiredSeason,st.activatedSeason,s.season)&&p.entrySeason===witness.retiredSeason+1&&p.ageAtEntry>=28&&!activePlayerIds.has(p.sourcePlayerId)&&int(witness.careerMinutes,0,1000000)&&int(witness.family,0,8)&&p.role===(witness.family<=3?['assistant','formation','scout']:CORE)[hash(p.sourcePlayerId+':staff-role')%(witness.family<=3?3:CORE.length)]&&Number.isFinite(witness.rating)&&witness.rating>=60&&witness.rating<=99&&Number.isFinite(witness.mental)&&witness.mental>=0&&witness.mental<=100&&witness.selection==='deterministic-third-v1'&&(witness.careerMinutes>=800||witness.rating>=75)&&hash(p.sourcePlayerId+':reconversion')%3===0&&p.level===Math.max(40,Math.min(85,Math.round(witness.rating*.6+witness.mental*.4))),'preuve de reconversion incohérente');
   }else if(p.sourceKind==='reference'){
    const reference=references.get(p.sourceStaffId);
    check(identity(p.sourceStaffId)&&p.sourcePlayerId===null&&p.id==='staff-career:reference:'+p.sourceStaffId&&p.appearanceId===p.sourceStaffId&&p.ageBasis!=='player-career'&&p.conversion===null&&p.generation===undefined&&reference&&reference.sourceKind!=='generated'&&reference.historical!==true&&p.name===text(reference.name)&&p.role===(completed(s)?completion.role(reference.role):canonical(reference.role))&&(!completed(s)||p.roleLabel===text(String(reference.role||LABELS[p.role]).slice(0,160)))&&p.level===45+hash(p.sourceStaffId+':level')%31&&p.ageAtEntry===(int(reference.age,18,100)?reference.age:40+hash(reference.id+':age')%26)+p.entrySeason-1&&p.ageBasis===(int(reference.age,18,100)&&reference.ageEstimated!==true?'published-derived':'estimated'),'référence ou visage incohérent');
   }
   else if(p.sourceKind==='generated'&&p.generation!==undefined){
    const g=p.generation;check(completed(s)&&shape(g,['policy','sourceId','base','function','country','nameSalt'])&&g.policy===completion.POLICY&&(g.sourceId===null||identity(g.sourceId))&&int(g.base,0,100)&&Object.hasOwn(completion.FUNCTIONS,g.function)&&typeof g.country==='string'&&/^[A-Z]{2}$/.test(g.country)&&int(g.nameSalt,0,9999),'origine du profil fictif invalide');
    const profile=completion.profile(g.sourceId||p.id,g),src=g.sourceId?references.get(g.sourceId):null;
    check(p.sourceStaffId===null&&p.sourcePlayerId===null&&p.ageBasis==='estimated'&&p.conversion===null&&p.appearanceBankVersion===2&&p.appearanceId===(g.sourceId||p.id)&&p.name===profile.name&&p.role===profile.role&&p.roleLabel===profile.roleLabel&&p.level===profile.level&&p.ageAtEntry===profile.age,'profil ou visage fictif incohérent');
    if(g.sourceId)check(src?.sourceKind==='generated'&&src.identityStatus==='fictional'&&src.id===g.sourceId&&p.id==='staff-career:generated:'+g.sourceId&&p.entrySeason===st.activatedSeason&&src.name===p.name&&JSON.stringify(src.completion)===JSON.stringify({policy:g.policy,base:g.base,function:g.function,country:g.country,nameSalt:g.nameSalt}),'complément initial incohérent');
    else{const match=/^staff-career:generated:(\d+):(\d+)$/.exec(p.id);check(match&&+match[1]===p.entrySeason&&int(+match[2],1,st.serial),'identifiant fictif incohérent');}
   }
   else check(p.sourceKind==='generated'&&p.generation===undefined&&p.id.startsWith('staff-career:generated:')&&p.sourceStaffId===null&&p.sourcePlayerId===null&&p.appearanceId===p.id&&p.ageBasis==='estimated'&&p.conversion===null&&p.level===45+hash(p.id+':level')%31&&p.ageAtEntry===30+hash(p.id+':age')%20,'profil fictif invalide');
  }
  const expected=completed(s)?new Map(initialTeams(s,source).map(c=>{const counts=Object.fromEntries(ROLES.map(r=>[r,0]));for(const p of c.members)if(p.historical!==true)counts[completion.role(p.role)]++;return [c.id,counts];})):referenceRoleCounts;
  check(Array.isArray(st.targets)&&st.targets.length===s.clubs.length&&new Set(st.targets.map(t=>t.clubId)).size===st.targets.length&&st.targets.every(t=>shape(t,completed(s)?['clubId','roles','functions']:['clubId','roles'])&&int(t.clubId,0,s.clubs.length-1)&&shape(t.roles,ROLES)&&ROLES.every(r=>t.roles[r]===(completed(s)?expected.get(t.clubId)?.[r]:Math.max(CORE.includes(r)?1:0,expected.get(t.clubId)?.[r]||0)))&&(!completed(s)||shape(t.functions,Object.keys(completion.MINIMUM))&&Object.keys(completion.MINIMUM).every(k=>t.functions[k]===completion.MINIMUM[k]))),'objectifs de rôles invalides');
  check(Array.isArray(st.history)&&st.history.length<=512&&st.history.every(e=>appearanceShape(e,['season','kind','id','clubId','name','role','appearanceId','appearanceAge','age','sourcePlayerId','amount'])&&int(e.season,st.activatedSeason,s.season)&&['reference-already-retired','player-conversion','retirement','voluntary-retirement','contract-ended','ai-renewal','ai-hire','hire','renew','release'].includes(e.kind)&&identity(e.id)&&name(e.name)&&ROLES.includes(e.role)&&identity(e.appearanceId)&&int(e.appearanceAge,18,300)&&int(e.age,18,300)&&(e.sourcePlayerId===null||(identity(e.sourcePlayerId)&&e.appearanceId===e.sourcePlayerId))&&(e.clubId===null||int(e.clubId,0,s.clubs.length-1))&&e.amount===0),'historique invalide');
  check(Array.isArray(st.captured)&&st.captured.length<=1900&&new Set(st.captured.map(e=>e.playerId)).size===st.captured.length&&st.captured.every(e=>shape(e,['playerId','season'])&&identity(e.playerId)&&int(e.season,Math.max(st.activatedSeason,s.season-2),s.season)),'captures de retraite invalides');
  return true;
 }
 function project(s=S){
  if(!s)return null;
  const sources=typeof nativeStaffCareerSources==='undefined'?null:nativeStaffCareerSources;
  const canEnable=!s.live&&(!s.commonDatabase?.id||Array.isArray(sources?.[s.commonDatabase.id]));
  if(!active(s))return {active:false,enabled:false,canEnable,reason:canEnable?'Activation explicite requise pour cette carrière.':'Source de staff indisponible ou match actif.',context:context(s),policy:POLICY,financialPolicy:FINANCE,maxYears:3,teams:[],candidates:[],market:[],retired:[],archives:[],notice:'Cycle désactivé : encadrement de carrière inchangé.'};
  const st=s.staffCareer,base=s.season+(s.phase==='ended'?1:0);
  const display=p=>{
   const maxYears=Math.max(0,Math.min(3,p.retireAge-p.age-(base-s.season))),minYears=p.clubId===s.club?Math.max(1,p.contractEnd-base+2):1;
   return {...copy(p),...(p.sourceKind==='generated'?{identityStatus:'fictional',portraitStatus:'synthetic'}:{}),identity:{id:p.sourcePlayerId??p.sourceStaffId??p.appearanceId??p.id,name:p.name,...(p.sourceKind==='generated'?{identityStatus:'fictional',portraitStatus:'synthetic'}:{})},maxYears,minYears,
    canHire:!s.live&&p.clubId===null&&maxYears>=1,canRenew:!s.live&&p.clubId===s.club&&maxYears>=minYears,
    canRelease:!s.live&&p.clubId===s.club,canRetire:!s.live&&p.clubId===s.club&&p.age>=60};
  };
  const candidates=people(st).filter(p=>p.clubId===null).map(display),history=copy(st.history);
  const retired=history.filter(e=>['reference-already-retired','retirement','voluntary-retirement'].includes(e.kind));
  return {active:true,enabled:true,canEnable:false,reason:'',version:1,context:context(s),policy:POLICY,financialPolicy:FINANCE,maxYears:3,roles:copy(LABELS),
   teams:s.clubs.map(c=>({id:c.id,name:c.name,members:people(st).filter(p=>p.clubId===c.id).map(display)})),
   candidates,market:copy(candidates),history,retired,archives:copy(retired),
   costs:{salary:0,signingFee:0},notice:'Suivez les contrats, les candidatures et les départs du staff.'};
 }
 function execute(command,payload){
  check(typeof S!=='undefined'&&!!S,'carrière absente');
  const specific=command==='staff_hire'?['candidateId','years']:command==='staff_renew'?['staffId','years']:['staff_release','staff_retire'].includes(command)?['staffId']:[];
  check(['staff_career_enable','staff_hire','staff_renew','staff_release','staff_retire'].includes(command)&&shape(payload,['context','confirmed',...specific])&&shape(payload.context,['season','week','club'])&&payload.confirmed===true,'commande ou paramètres invalides');
  const now=context(S);check(Object.keys(now).every(k=>payload.context[k]===now[k]),'contexte périmé');check(!S.live,'terminez le match avant de gérer le staff');validate(S);
  if(command==='staff_career_enable'){check(!active(S),'cycle déjà actif');check(initialize(S),'édition sans staff de référence');return {staffCareerAction:{command,financialPolicy:FINANCE}};}
  check(active(S),'activation du cycle requise');
  const st=S.staffCareer,id=payload.candidateId??payload.staffId;check(identity(id),'identifiant invalide');
  const p=people(st).find(q=>q.id===id);check(!!p,'profil indisponible');
  if(command==='staff_hire')check(p.clubId===null,'candidat déjà engagé');else check(p.clubId===S.club,'ce membre appartient à un autre club');
  if(command==='staff_hire'||command==='staff_renew'){
   const base=S.season+(S.phase==='ended'?1:0),end=base+payload.years-1;
   check(int(payload.years,1,3)&&p.age+(base-S.season)+payload.years<=p.retireAge,'durée incompatible avec la retraite');
   if(command==='staff_renew')check(end>p.contractEnd,'la prolongation doit allonger le contrat');
   p.clubId=S.club;p.contractEnd=end;event(S,command==='staff_hire'?'hire':'renew',p);
  }else if(command==='staff_release'){event(S,'release',p);p.clubId=null;p.contractEnd=null;}
  else{check(p.age>=60,'retraite volontaire disponible à partir de 60 ans');retire(S,p,'voluntary-retirement');}
  prune(S);validate(S);return {staffCareerAction:{command,staffId:id,fee:0,salary:0,financialPolicy:FINANCE}};
 }
 return {initialize,captureRetirement,advance,validate,project,execute,installHooks:()=>true};
}
// Only trusted local function source is composed here; no save/request text is evaluated.
const serializedFactory=Function('return ('+factory.toString().replace('function staffCompletionPolicy(){return null;}',require('./staff-completion.cjs').factory.toString())+')')();
module.exports={files,commands,factory:serializedFactory};
