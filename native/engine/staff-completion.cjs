'use strict';
// Pure fictional policy; never edits a documented registry or consumes game RNG.
function factory(){
 const POLICY='staff-completion-v1';
 const FUNCTIONS={assistant:{role:'assistant',label:'Entraîneur adjoint'},forwards:{role:'coach',label:'Entraîneur des avants, mêlée et touche'},backs:{role:'coach',label:'Entraîneur des arrières, attaque et jeu au pied'},defence:{role:'coach',label:'Entraîneur de la défense'},fitnessLead:{role:'fitness',label:'Responsable de la préparation physique'},conditioning:{role:'fitness',label:'Préparateur physique'},rehab:{role:'fitness',label:'Préparateur en réathlétisation'},doctor:{role:'medical',label:'Médecin du club'},physio:{role:'medical',label:'Kinésithérapeute'},analyst:{role:'analyst',label:'Analyste vidéo'},scout:{role:'scout',label:'Recruteur'},formation:{role:'formation',label:'Responsable de la formation'},teamManager:{role:'support',label:'Team manager'},equipment:{role:'support',label:'Intendant'}};
 const MINIMUM={assistant:1,forwards:1,backs:1,defence:1,fitnessLead:1,conditioning:1,rehab:1,doctor:1,physio:2,analyst:1,scout:1,formation:1,teamManager:1,equipment:1};
 const EXTRA=['analyst','scout','formation','conditioning','backs','physio','analyst','rehab','formation','equipment','forwards'];
 const norm=x=>String(x||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
 const hash=x=>{let h=2166136261;for(const c of String(x))h=Math.imul(h^c.charCodeAt(0),16777619);return h>>>0;};
 function role(label){
  const x=norm(label);
  if(/medec|medical|kine|physio|doctor|osteop|infirm|fisioterap|medico|soigneur|paramed/.test(x))return 'medical';
  if(/analys|video|data scientist/.test(x))return 'analyst';
  if(/physiq|fitness|strength|condition|s\s*(?:[&/]|et|and)\s*c|preparateur|preparatore|athletic|rehab|reathlet|sport scientist|performance (?:coach|director)|(?:responsable|directeur|head).*performance/.test(x))return 'fitness';
  if(/recrut|recruit|scout|reclut/.test(x))return 'scout';
  if(/academ|format|espoir|jeune|youth|pathway|player develop/.test(x))return 'formation';
  if(/team manager|kit manager|operations|intendan|equip|magazz|logisti|responsable d.equipe/.test(x))return 'support';
  if(/adjoint|assistant/.test(x))return 'assistant';
  if(/coach|entraine|manager|directeur sportif|director of rugby|directeur du rugby|jeu au pied|touche|melee|scrum|line.?out|defen/.test(x))return 'coach';
  return 'support';
 }
 function capabilities(label){
  const x=norm(label),r=role(label),out=[];
  if(r==='medical'){
   if(/medecin|doctor|medico(?:\s|$)/.test(x))out.push('doctor');
   if(/kine|physio|fisioterap/.test(x))out.push('physio');
   if(/rehab|reathlet/.test(x))out.push('rehab');
  }else if(r==='fitness'){
   if(/rehab|reathlet/.test(x))out.push('rehab');
   if(/responsable|directeur|director|head|lead|chief/.test(x)&&/physiq|fitness|strength|condition|performance|athletic|s\s*(?:[&/]|et|and)\s*c/.test(x))out.push('fitnessLead');
   if(/physiq|fitness|strength|condition|athletic|s\s*(?:[&/]|et|and)\s*c|preparatore|sport scientist/.test(x)&&!out.includes('rehab'))out.push('conditioning');
   // Estimated game allocation within the physical preparation profession;
   // no medical qualification is inferred from these generic labels.
   if(/preparateur|preparation physique|preparatore|fitness coach|strength|conditioning|athletic performance coach/.test(x)&&!out.includes('rehab'))out.push('fitnessLead','conditioning','rehab');
  }else if(['analyst','scout','formation'].includes(r))out.push(r);
  else if(r==='support'){
   if(/team manager|responsable d.equipe|operations manager|direction et intendance/.test(x))out.push('teamManager');
   if(/intendan|kit(?:\s|$)|equipment|magazz|materiel|logisti/.test(x))out.push('equipment');
  }else{
   if(/avant|melee|scrum|touche|line.?out|forward|conquete/.test(x))out.push('forwards');
   if(/arriere|attaque|attack|back|jeu au pied|kicking|trois.quarts|3\/4/.test(x))out.push('backs');
   if(/defen/.test(x))out.push('defence');
   if(/adjoint|assistant/.test(x))out.push('assistant');
   if(!out.some(key=>['forwards','backs','defence'].includes(key))&&/coach|entraineur|entraine|adjoint/.test(x))out.push('assistant','forwards','backs','defence');
  }
  return [...new Set(out)];
 }
 function coverage(members,minimum=MINIMUM){
  const active=members.filter(p=>p.historical!==true),caps=active.map(p=>capabilities(p.roleLabel||p.role)),slots=Object.entries(minimum).flatMap(([key,n])=>Array(n).fill(key)),assigned=new Map();
  const place=(slot,visited)=>{for(let i=0;i<active.length;i++){if(visited.has(i)||!caps[i].includes(slots[slot]))continue;visited.add(i);const prior=assigned.get(i);if(prior===undefined||place(prior,visited)){assigned.set(i,slot);return true;}}return false;};
  for(let slot=0;slot<slots.length;slot++)place(slot,new Set());
  const counts=Object.fromEntries(Object.keys(minimum).map(k=>[k,0]));for(const slot of assigned.values())counts[slots[slot]]++;return counts;
 }
 const target=base=>base>=82?26:base>=72?20:15;
 const NAMES={
  FR:{first:['Adrien','Alexandre','Antoine','Bastien','Benoît','Clément','Damien','David','Édouard','Étienne','Fabien','Florian','Gabriel','Guillaume','Hugo','Julien','Laurent','Loïc','Lucas','Marc','Mathieu','Maxime','Nicolas','Olivier','Paul','Pierre','Quentin','Raphaël','Rémi','Romain','Samuel','Simon','Thomas','Tristan','Victor','Vincent'],last:['Aubrac','Belmont','Béraud','Bessières','Borel','Bourdet','Brémond','Chabert','Clavel','Delmas','Dumont','Duret','Fabre','Faure','Ferrand','Fleury','Gallet','Garnier','Girard','Granger','Lacombe','Lagrange','Lenoir','Leroux','Marchal','Masson','Mercier','Moreau','Perrin','Renaud','Rivière','Rolland','Rougier','Vidal']},
  EN:{first:['Adam','Alex','Andrew','Ben','Callum','Charlie','Daniel','Edward','Elliot','Ethan','Finlay','Gareth','George','Harry','Henry','Isaac','Jack','James','Jamie','Jonathan','Joseph','Lewis','Liam','Luke','Matthew','Michael','Nathan','Oliver','Oscar','Patrick','Peter','Robert','Ryan','Samuel','Thomas','William'],last:['Archer','Ashford','Barrett','Baxter','Bennett','Bramwell','Bridger','Brook','Carver','Chadwick','Clarke','Clayton','Cooper','Dalton','Ellwood','Fairfax','Fletcher','Graham','Hale','Harper','Hawthorne','Hollis','Keating','Langford','Lawson','Mercer','Morgan','Palmer','Reed','Ridley','Spencer','Sullivan','Turner','Wallace']},
  JP:{first:['Akihiro','Akira','Daichi','Daisuke','Haruki','Haruto','Hideki','Hiroki','Hiroshi','Ichiro','Isamu','Jun','Kaito','Kazuki','Kenji','Kenta','Kohei','Makoto','Masaki','Naoki','Ren','Riku','Ryota','Satoru','Shinji','Sho','Shota','Sota','Takumi','Takeshi','Tatsuya','Toru','Yasuhiro','Yoji','Yuki','Yusuke'],last:['Abe','Aoki','Fujimoto','Fujita','Fukuda','Goto','Hasegawa','Hashimoto','Hayashi','Honda','Ishida','Ishikawa','Ito','Kato','Kikuchi','Kimura','Kobayashi','Kondo','Maeda','Matsuda','Matsumoto','Mori','Morita','Murakami','Nakagawa','Nakajima','Nakamura','Nishimura','Ogawa','Okada','Saito','Sakamoto','Shimizu','Takahashi','Tanaka','Yamada']}
 };
 function profile(id,{base=65,function:key='assistant',country='FR',nameSalt=0}={}){
  if(!FUNCTIONS[key])throw Error('Fonction de complément inconnue.');
  const culture=country==='JP'?'JP':country==='FR'?'FR':'EN',pool=NAMES[culture],seed=id+':name:'+nameSalt;
  const first=pool.first[hash(seed+':first')%pool.first.length],last=pool.last[hash(seed+':last')%pool.last.length],other=pool.last[hash(seed+':other')%pool.last.length];
  const label=first+' '+last+(culture==='JP'?'':'-'+other),age=(key==='doctor'?36:key==='fitnessLead'||key==='formation'?36:29)+hash(id+':age')%(key==='doctor'?21:24);
  return {name:label,age,level:Math.max(40,Math.min(85,Math.round(base)-13+hash(id+':level')%15)),role:FUNCTIONS[key].role,roleLabel:FUNCTIONS[key].label};
 }
 function uniqueProfile(id,settings,used){let nameSalt=0,p;do{p=profile(id,{...settings,nameSalt:nameSalt++});}while(used.has(norm(p.name))&&nameSalt<10000);if(used.has(norm(p.name)))throw Error('Noms fictifs épuisés.');used.add(norm(p.name));return {...p,nameSalt:nameSalt-1};}
 function completeClub({databaseId,club,members},usedNames=null){
  const original=members.slice(),before=members.filter(p=>p.historical!==true).length,used=usedNames||new Set(members.map(p=>norm(p.name))),added=[],slots={};
  const prefix='staff-completion:v1:'+databaseId+':'+club.id+':';
  for(const p of members)if(p.sourceKind==='generated'&&p.id.startsWith(prefix)&&FUNCTIONS[p.completion?.function]){const slot=Number(p.id.slice(p.id.lastIndexOf(':')+1));if(Number.isSafeInteger(slot))slots[p.completion.function]=Math.max(slots[p.completion.function]||0,slot);}
  const add=key=>{const slot=slots[key]=(slots[key]||0)+1,id='staff-completion:v1:'+databaseId+':'+club.id+':'+key+':'+slot,settings={base:Number.isFinite(club.base)?club.base:65,function:key,country:club.country||'FR'},p=uniqueProfile(id,settings,used);added.push({id,clubId:club.id,name:p.name,role:p.roleLabel,historical:false,sourceKind:'generated',identityStatus:'fictional',portraitStatus:'synthetic',appearanceId:id,appearanceAge:p.age,appearanceBankVersion:2,age:p.age,ageEstimated:true,level:p.level,completion:{policy:POLICY,base:settings.base,function:key,country:settings.country,nameSalt:p.nameSalt}});};
  const have=coverage(original);for(const [key,n] of Object.entries(MINIMUM))for(let i=have[key];i<n;i++)add(key);
  let extra=0;while(before+added.length<target(club.base))add(EXTRA[extra++%EXTRA.length]);
  return {members:original.concat(added),added,before,after:before+added.length,target:target(club.base)};
 }
 function completeRegistry({databaseId,clubs,registry}){
  const byId=new Map(clubs.map(c=>[c.id,c])),used=new Set(registry.clubs.flatMap(c=>c.members.map(p=>norm(p.name))));
  return {...registry,completionPolicy:POLICY,clubs:registry.clubs.map(c=>{const club=byId.get(c.id)||{id:c.id,base:65};return {...c,completion:{policy:POLICY,base:club.base??65,country:club.country||'FR',target:target(club.base)},members:completeClub({databaseId,club,members:c.members},used).members};})};
 }
 return {POLICY,FUNCTIONS,MINIMUM,EXTRA,norm,hash,role,capabilities,coverage,target,profile,uniqueProfile,completeClub,completeRegistry};
}
module.exports={factory,...factory()};
