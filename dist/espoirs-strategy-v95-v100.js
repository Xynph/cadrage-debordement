'use strict';
(function(root){
 const REGIONS=['Atlantique','Bretagne','Centre','Sud-Ouest','Mediterranee','Alpes'];
 const IDENTITIES=['mouvement','puissance','defense','polyvalence'];
 const DECISIONS=['accompagner','pret','professionnel','patienter'];
 const safe=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const clean=x=>String(x??'').replace(/[&<>"'\x00-\x1f]/g,' ').slice(0,100);
 const copy=x=>JSON.parse(JSON.stringify(x));
 const hash=str=>{let h=2166136261;for(const c of String(str)){h^=c.charCodeAt(0);h=Math.imul(h,16777619)}return h>>>0};
 const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
 const youth=s=>s?.development?.academy||[];
 const pro=s=>s?.clubs?.[s.club]?.players||[];
 const potential=p=>Number.isFinite(p?.dev?.potential)?p.dev.potential:(p?.potential??p?.rating??0);
 function valid(st){
  return !!st&&st.version===1&&Number.isInteger(st.season)&&st.season>0&&
   REGIONS.includes(st.region)&&IDENTITIES.includes(st.identity)&&
   Number.isInteger(st.cohesion)&&st.cohesion>=0&&st.cohesion<=100&&
   Number.isInteger(st.reputation)&&st.reputation>=0&&st.reputation<=100&&
   Number.isInteger(st.scouts)&&st.scouts>=0&&st.scouts<=3&&
   Number.isInteger(st.meetings)&&st.meetings>=0&&st.meetings<=3&&
   Array.isArray(st.candidates)&&st.candidates.length<=9&&
   Array.isArray(st.recruits)&&st.recruits.length<=5&&
   Array.isArray(st.loads)&&st.loads.length<=35&&
   Array.isArray(st.ambitions)&&st.ambitions.length<=40&&
   Array.isArray(st.history)&&st.history.length<=15&&
   st.candidates.every(x=>x&&typeof x.id==='string'&&REGIONS.includes(x.region)&&Number.isInteger(x.rating)&&Number.isInteger(x.potential))&&
   st.loads.every(x=>x&&typeof x.id==='string'&&['allegee','equilibree','intensive'].includes(x.load))&&
   st.ambitions.every(x=>x&&typeof x.id==='string'&&DECISIONS.includes(x.decision)&&Number.isInteger(x.season))&&
   st.history.every(x=>x&&Number.isInteger(x.season)&&Number.isInteger(x.reputation))&&
   (st.network===undefined||(st.network.version===1&&Array.isArray(st.network.recruiters)&&
    st.network.recruiters.length===3&&Array.isArray(st.network.feeders)&&
    st.network.feeders.length===16&&Array.isArray(st.network.players)&&st.network.players.length<=96&&
    Array.isArray(st.network.partners)&&st.network.partners.length<=8&&
    Array.isArray(st.network.history)&&st.network.history.length<=150&&
    Array.isArray(st.network.credits)&&st.network.credits.length<=80));
 }
 function ensure(s){
  if(!s?.development||!Number.isInteger(s.season)||s.season<1)return null;
  const old=s.v95to100;
  if(old!==undefined){
   if(!valid(old)||old.season>s.season)return null;
   if(old.season===s.season){network(old,s);return old;}
   s.v95to100={...old,season:s.season,scouts:0,meetings:0,candidates:[],recruits:[],loads:[],ambitions:[],
    history:old.history.slice(0,15)};
   evolveNetwork(network(s.v95to100,s),s);return s.v95to100;
  }
  s.v95to100={version:1,season:s.season,region:'Atlantique',identity:'polyvalence',
   cohesion:55,reputation:45,scouts:0,meetings:0,candidates:[],recruits:[],loads:[],ambitions:[],history:[]};
  network(s.v95to100,s);return s.v95to100;
 }
 function transact(s,action,save){
  const previous=copy(s);
  try{if(action()!==true)return false;if(save&&save()===false)throw Error('storage');return true}
  catch{for(const key of Object.keys(s))delete s[key];Object.assign(s,previous);return false}
 }
 function unlocked(s){return !!s&&!s.live&&s.phase!=='ended'}
 function cost(s,amount){return Number.isFinite(s?.clubs?.[s.club]?.cash)&&s.clubs[s.club].cash>=amount}

 // This fictional feeder network is distinct from LNR clubs and official calendars.
 const FEEDERS=[
  ['Cote du Ponant','Bretagne','FR'],['Val de Loire','Atlantique','FR'],
  ['Forez Union','Centre','FR'],['Garonne Ovalie','Sud-Ouest','FR'],
  ['Riviera Ovalie','Mediterranee','FR'],['Savoie Montagne','Alpes','FR'],
  ['Bocage Atlantique','Atlantique','FR'],['Argoat Rugby','Bretagne','FR'],
  ['Massif Central','Centre','FR'],['Delta Rugby','Mediterranee','FR'],
  ['Porto Académie','Portugal','PT'],['Tbilissi Espoir','Georgie','GE'],
  ['Cardiff Vallée','Pays de Galles','GB'],['Fiji Islands Youth','Fidji','FJ'],
  ['Cape Youth Rugby','Afrique du Sud','ZA'],['Rosario Club','Argentine','AR']
 ];
 const surnames=['Martin','Bernard','Perrin','Le Goff','Robert','Santos','Morel','Silva','Laurent','Dumas','Tavita','Beridze'];
 const firstnames=['Eliott','Noam','Mael','Hugo','Mathis','Timo','Leo','Tane','Lucas','Pablo','Nino','Sami'];
 const fam=(s,p)=>s?.development?.academy?.find(q=>q.pos===p.pos)||s?.development?.academy?.[0];
 function network(st,s){
  if(st.network){if(!Array.isArray(st.network.recruiters))st.network.recruiters=[{name:'Recruteur Nord',zone:'Bretagne',skill:75},{name:'Recruteur Sud',zone:'Sud-Ouest',skill:81},{name:'Recruteur International',zone:'International',skill:72}];return st.network;}
  const feeders=FEEDERS.map((f,i)=>({id:'feeder-'+i,name:f[0]+' RC',region:f[1],union:f[2],relationship:0}));
  const players=[];
  for(let i=0;i<feeders.length;i++)for(let j=0;j<2;j++){
   const seed=hash('feeder:'+s.club+':'+i+':'+j),age=15+seed%5,rating=44+Math.floor(seed/7)%20;
   const native=youth(s),pos=native.length?native[(seed>>>4)%native.length].pos:'10';
   players.push({id:'feeder-youth-'+i+'-'+j,clubId:feeders[i].id,clubName:feeders[i].name,
    region:feeders[i].region,union:feeders[i].union,
    name:firstnames[seed%firstnames.length]+' '+surnames[Math.floor(seed/13)%surnames.length],
    pos,age,rating,potential:Math.min(94,rating+10+Math.floor(seed/31)%24),
    schooling:40+Math.floor(seed/77)%61,family:40+Math.floor(seed/107)%61,
    ambition:40+Math.floor(seed/167)%61,scouted:0,trial:false,offers:0,
    status:'available',originSeason:s.season,homeClub:feeders[i].id});
  }
  st.network={version:1,feeders,players,partners:[],history:[],credits:[],lastSeason:s.season,
   recruiters:[{name:'Recruteur Nord',zone:'Bretagne',skill:75},
    {name:'Recruteur Sud',zone:'Sud-Ouest',skill:81},
    {name:'Recruteur International',zone:'International',skill:72}]};
  return st.network;
 }
 function evolveNetwork(n,s){
  if(n.lastSeason>=s.season)return;
  const years=Math.min(20,s.season-n.lastSeason);
  for(let year=n.lastSeason+1;year<=s.season;year++){
   for(const p of n.players){
    if(p.status!=='aged-out')p.age++;
    if(p.status!=='available'&&p.status!=='declined')continue;
    if(p.age>21){p.status='aged-out';n.history.push({id:p.id,season:year,action:'aged-out',club:p.clubId});continue}
    if(p.status==='declined'){p.status='available';p.trial=false}
    // Other centres act autonomously: prospects can leave the accessible pool.
    const rivalChance=hash('rival-sign:'+year+':'+p.id)%100;
    if(rivalChance<(p.offers?12:5)){
      p.status='joined-rival';n.history.push({id:p.id,season:year,action:'joined-rival',club:p.clubId})
    }
   }
   if(year%2===0)for(let i=0;i<n.feeders.length;i++){
    const seed=hash('generation:'+year+':'+i),base=n.feeders[i];
    const current=n.players.filter(p=>p.clubId===base.id&&p.status==='available').length;
    if(current>=3)continue;
    const rate=43+seed%21;
    const native=youth(s),pos=native.length?native[(seed>>>3)%native.length].pos:'10';
    n.players.push({id:'feeder-youth-'+i+'-season-'+year,clubId:base.id,clubName:base.name,
     region:base.region,union:base.union,
     name:firstnames[seed%firstnames.length]+' '+surnames[Math.floor(seed/17)%surnames.length],
     pos,age:15+Math.floor(seed/71)%3,rating:rate,potential:Math.min(94,rate+12+Math.floor(seed/29)%20),
     schooling:40+Math.floor(seed/37)%61,family:40+Math.floor(seed/67)%61,
     ambition:40+Math.floor(seed/89)%61,scouted:0,trial:false,offers:0,
     status:'available',originSeason:year,homeClub:base.id});
   }
  }
  n.players=n.players.filter(p=>p.status!=='aged-out').slice(-96);
  n.history=n.history.slice(-150);
  n.lastSeason=s.season;
 }
 function model(s,p,net){
  const feeder=net.feeders.find(x=>x.id===p.clubId);
  const partner=net.partners.includes(p.clubId),local=feeder?.union==='FR';
  const reputation=Number.isInteger(s.v95to100?.reputation)?s.v95to100.reputation:45;
  const school=Math.round(45+(partner?20:0)+Math.max(0,50-p.schooling)*.1);
  const proximity=local?58+(partner?20:0):10;
  const minutes=Math.round(70-Math.max(0,(youth(s).filter(x=>x.pos===p.pos).length-2))*10);
  const sportif=Math.round(50+reputation*.35+(partner?10:0));
  const project=Math.round(clamp(
    (sportif*p.ambition+school*p.schooling+proximity*p.family+
      minutes*(200-p.ambition-p.family)/2)/(p.ambition+p.schooling+p.family+(200-p.ambition-p.family)/2),
    0,100));
  const rivals=hash(s.season+':rivals:'+p.id)%4;
  return {project,school,proximity,minutes,sportif,rivals,interest:clamp(project-rivals*4,0,100)};
 }
 function watch(s,id,save){
  const st=ensure(s),n=st&&network(st,s),p=n?.players.find(x=>x.id===id);
  if(!st||!unlocked(s)||!p||p.status!=='available'||p.scouted>=3||!cost(s,500))return false;
  return transact(s,()=>{s.clubs[s.club].cash-=500;p.scouted++;
   const scout=n.recruiters.find(r=>r.zone===p.region)||(p.union==='FR'?n.recruiters[1]:n.recruiters[2]);
   p.lastReport={season:s.season,recruiter:scout.name,reliability:Math.min(95,scout.skill+p.scouted*4)};
   return true},save);
 }
 function trial(s,id,save){
  const st=ensure(s),n=st&&network(st,s),p=n?.players.find(x=>x.id===id);
  if(!st||!unlocked(s)||!p||p.status!=='available'||p.scouted<1||p.trial||!cost(s,1000))return false;
  return transact(s,()=>{s.clubs[s.club].cash-=1000;p.trial=true;return true},save);
 }
 function partner(s,clubId,save){
  const st=ensure(s),n=st&&network(st,s),c=n?.feeders.find(x=>x.id===clubId);
  if(!st||!unlocked(s)||!c||n.partners.includes(clubId)||n.partners.length>=8||!cost(s,2000))return false;
  return transact(s,()=>{s.clubs[s.club].cash-=2000;n.partners.push(clubId);c.relationship++;return true},save);
 }
 function clearance(s,id,save){
  const st=ensure(s),n=st&&network(st,s),p=n?.players.find(x=>x.id===id);
  if(!st||!unlocked(s)||!p||p.union==='FR'||p.age<18||!p.trial)return false;
  // A manager marks that clearance has been received in this fictional universe.
  return transact(s,()=>{p.clearanceRecorded=true;return true},save);
 }
 function recruitFeeder(s,id,save){
  const st=ensure(s),n=st&&network(st,s),p=n?.players.find(x=>x.id===id),academy=youth(s);
  const capacity=s.academyGroupPolicy===1?75:35;
  if(!st||!unlocked(s)||!p||p.status!=='available'||p.scouted<2||!p.trial||
     academy.length>=capacity||st.recruits.length>=5||!cost(s,8000)||academy.some(x=>x.id===id))return false;
  // Underage international recruitment is not simulated as an ordinary domestic transfer.
  if(p.union!=='FR'&&(p.age<18||p.clearanceRecorded!==true))return false;
  const template=fam(s,p);
  if(!template?.dev||!Number.isInteger(template.fam))return false;
  const score=model(s,p,n);
  // Uncertain decisions remain reproducible for a given season/player and are not identity-based.
  const decision=hash('decision:'+s.season+':'+s.club+':'+p.id)%100;
  const accepts=decision<score.interest;
  return transact(s,()=>{
   p.offers++;
   if(!accepts){p.status='declined';n.history.push({id:p.id,season:s.season,action:'declined',club:p.clubId});return true}
   const newPlayer=copy(template);
   newPlayer.id=p.id;newPlayer.name=clean(p.name);newPlayer.pos=p.pos;newPlayer.age=p.age;
   newPlayer.rating=p.rating;newPlayer.injury=0;newPlayer.condition=95;newPlayer.academy=true;
   newPlayer.dev={...newPlayer.dev,potential:p.potential,xp:0,seasonStart:p.rating};
   newPlayer.trainingOrigin={clubId:p.clubId,clubName:p.clubName,union:p.union,region:p.region,
     joinedSeason:s.season,history:[{season:s.season,club:p.clubId,phase:'amateur'},
       {season:s.season,club:s.club,phase:'academy'}]};
   academy.push(newPlayer);s.clubs[s.club].cash-=8000;
   p.status='recruited';st.recruits.push({id:p.id,name:p.name,season:s.season,origin:p.clubId});
   n.history.push({id:p.id,season:s.season,action:'recruited',club:p.clubId});
   return true;
  },save);
 }
 function networkPanel(s){
  const st=ensure(s),n=st&&network(st,s);if(!n)return '';
  const locked=!unlocked(s),arg=x=>JSON.stringify(x).replace(/"/g,'&quot;');
  const available=n.players.filter(p=>p.status==='available').filter(p=>p.scouted||n.partners.includes(p.clubId)).slice(0,18);
  return '<section class="cd04-panel" style="padding:18px;margin-top:18px"><h3>V95 · Filière clubs amateurs</h3>'+
   '<p>Réseau : '+n.feeders.length+' clubs formateurs · '+n.players.filter(p=>p.status==='available').length+
   ' jeunes suivables · '+n.partners.length+' partenaires. Recruter demande observations, essai et accord du joueur.</p>'+
   '<p>Recruteurs : '+n.recruiters.map(r=>safe(r.name)+' ('+safe(r.zone)+', '+r.skill+'/100)').join(' · ')+'</p>'+
   '<ul>'+n.feeders.map(c=>'<li>'+safe(c.name)+' ('+safe(c.region)+', '+safe(c.union)+')'+
   '<button onclick="v95Partner('+arg(c.id)+')"'+(locked||n.partners.includes(c.id)?' disabled':'')+
   '>Partenariat · 2 000 €</button></li>').join('')+'</ul>'+
   '<h4>Jeunes identifiés</h4><ul>'+available.map(p=>{
    const m=model(s,p,n);
    return '<li>'+safe(p.name)+' · '+safe(p.clubName)+' · '+safe(p.pos)+' · '+p.age+
     ' ans · note observée '+(p.scouted?Math.round(p.rating/5)*5:'?')+
     ' · potentiel estimé '+(p.scouted>=2?p.potential:'à confirmer')+
     ' · adéquation '+m.interest+'/100 · concurrence '+m.rivals+
     '<button onclick="v95Watch('+arg(p.id)+')"'+(locked||p.scouted>=3?' disabled':'')+'>Observer · 500 €</button>'+
     '<button onclick="v95Trial('+arg(p.id)+')"'+(locked||p.scouted<1||p.trial?' disabled':'')+'>Essai · 1 000 €</button>'+
     (p.union!=='FR'?'<button onclick="v95Clearance('+arg(p.id)+')"'+
       (locked||p.age<18||!p.trial||p.clearanceRecorded?' disabled':'')+
       '>Enregistrer clearance reçue</button>':'')+
     '<button onclick="v95Sign('+arg(p.id)+')"'+
       (locked||p.scouted<2||!p.trial||(p.union!=='FR'&&(p.age<18||!p.clearanceRecorded))?' disabled':'')+
     '>Proposer le projet · 8 000 € si accepté</button></li>';
   }).join('')+'</ul>'+
   '<p class="help">Tous les clubs et joueurs sont fictifs. Les recrutements internationaux mineurs sont bloqués ; les clearance et accords sont simulés, jamais une preuve de conformité administrative réelle. L’historique formateur reste associé à chaque recrue.</p></section>';
 }
 function discover(s,region,save){
  const st=ensure(s),n=st&&network(st,s);
  if(!st||!unlocked(s)||!REGIONS.includes(region)||st.scouts>=3||!cost(s,3000))return false;
  return transact(s,()=>{
   s.clubs[s.club].cash-=3000;st.scouts++;st.region=region;
   const clubs=n.feeders.filter(x=>x.region===region);
   const pool=n.players.filter(x=>clubs.some(c=>c.id===x.clubId)&&x.status==='available');
   for(const p of pool.slice(0,3))p.scouted=Math.max(1,p.scouted);
   return true;
  },save);
 }
 function recruit(s,id,save){return recruitFeeder(s,id,save)}
 function meeting(s,save){
  const st=ensure(s);
  if(!st||!unlocked(s)||st.meetings>=3||!cost(s,2000))return false;
  return transact(s,()=>{s.clubs[s.club].cash-=2000;st.meetings++;st.cohesion=clamp(st.cohesion+9,0,100);return true},save);
 }
 function load(s,id,value,save){
  const st=ensure(s),p=youth(s).find(x=>x.id===id);
  if(!st||!unlocked(s)||!p||!['allegee','equilibree','intensive'].includes(value)||p.age>21)return false;
  return transact(s,()=>{
   const existing=st.loads.find(x=>x.id===id);
   if(existing)existing.load=value;
   else{if(st.loads.length>=35)return false;st.loads.push({id,load:value})}
   return true;
  },save);
 }
 function ambition(s,id,decision,save){
  const st=ensure(s),p=youth(s).find(x=>x.id===id);
  if(!st||!unlocked(s)||!p||p.age>21||!DECISIONS.includes(decision)||
   st.ambitions.some(x=>x.id===id&&x.season===s.season))return false;
  return transact(s,()=>{
   st.ambitions.push({id,season:s.season,decision,fulfilled:decision==='accompagner'||decision==='patienter'});
   st.cohesion=clamp(st.cohesion+(decision==='patienter'?-2:2),0,100);
   return true;
  },save);
 }
 function identity(s,value,save){
  const st=ensure(s);
  if(!st||!unlocked(s)||!IDENTITIES.includes(value))return false;
  return transact(s,()=>{st.identity=value;return true},save);
 }
 function rankings(s){
  const st=ensure(s);if(!st)return null;
  const history=st.history.map(h=>({season:h.season,reputation:h.reputation,graduates:h.graduates,cohesion:h.cohesion}));
  return {reputation:st.reputation,tier:st.reputation>=80?'reference':st.reputation>=60?'reconnue':
   st.reputation>=40?'en-developpement':'fragile',history};
 }
 function settle(s){
  const st=ensure(s);
  if(!st||s.phase!=='ended'||st.history.some(h=>h.season===s.season))return false;
  return transact(s,()=>{
   let trained=0,overloaded=0,fulfilled=0,broken=0;
   for(const l of st.loads){
    const p=youth(s).find(x=>x.id===l.id);if(!p||!p.dev)continue;
    if(l.load==='allegee'){p.condition=clamp((p.condition||75)+8,35,100);continue}
    if(l.load==='equilibree'){p.condition=clamp((p.condition||75)+3,35,100);continue}
    if(potential(p)>p.rating&&p.injury===0){p.rating=Math.min(potential(p),99,p.rating+1);trained++}
    p.condition=clamp((p.condition||75)-10,35,100);overloaded++;
   }
   for(const a of st.ambitions){
    if(a.fulfilled){fulfilled++;continue}
    const promoted=pro(s).some(p=>p.id===a.id);
    const loan=(s.v78to81?.loans||[]).some(l=>l.id===a.id);
    a.fulfilled=a.decision==='professionnel'?promoted:a.decision==='pret'?loan:false;
    if(a.fulfilled)fulfilled++;else broken++;
   }
   // The club's teaching identity has a bounded, observable annual effect.
   let styleProgress=0;
   const backs=new Set(['DEMI DE MÊLÉE','DEMI D’OUVERTURE','AILIER','CENTRE','ARRIÈRE','9','10','11','12','13','14','15','DEMI','AILIER','ARRIERE']);
   for(const p of youth(s)){
    if(!p.dev||p.injury>0)continue;
    const isBack=backs.has(String(p.pos).toUpperCase());
    const compatible=st.identity==='polyvalence'||
      (st.identity==='mouvement'&&isBack)||
      (st.identity==='puissance'&&!isBack)||
      (st.identity==='defense'&&p.condition>=70);
    if(!compatible||potential(p)<=p.rating)continue;
    // Limit to 3 bonuses per year to keep academy balance stable.
    if(styleProgress>=3)break;
    p.rating=Math.min(potential(p),99,p.rating+1);styleProgress++;
   }
   if(st.identity==='defense')st.cohesion=clamp(st.cohesion+2,0,100);
   // Describe RIF formation attribution for up to 10 professional seasons.
   // It is NOT a legal financial calculation or a payable domestic transfer fee.
   const n=network(st,s);
   const allPromotions=[...(s.v77Promotions?.promotions||[]),
     ...(s.v77Promotions?.history||[]).flatMap(h=>h.promotions||[])];
   for(const promoted of allPromotions){
    const found=n.players.find(p=>p.id===promoted.playerId);
    const first=promoted.season;
    if(!found||found.status!=='recruited'||!Number.isInteger(first)||s.season<first||s.season>=first+10||
      n.credits.some(c=>c.id===found.id&&c.season===s.season))continue;
    n.credits.push({id:found.id,club:found.clubId,season:s.season,
      firstProfessionalSeason:first,kind:'RIF-descriptive'});
   }
   n.credits=n.credits.slice(-80);
   n.history=n.history.slice(-150);
   const graduates=(s.v77Promotions?.promotions||[]).length;
   const completed=(root.CDNativeAcademy?.active(s)&&root.CDNativeAcademy.own(s).division==='accession'?s.v74Accession.results:s.v73Espoirs?.results||[]).filter(m=>Array.isArray(m.pair)&&m.pair.includes(root.CDNativeAcademy?.active(s)?root.CDNativeAcademy.own(s).slot:s.club)).length;
   const performance=completed>0?Math.min(5,Math.round(completed/5)):0;
   st.cohesion=clamp(st.cohesion+(fulfilled-broken)*2-Math.ceil(overloaded/4),0,100);
   st.reputation=clamp(st.reputation+graduates*3+performance+Math.floor((st.cohesion-50)/12)-broken*2,0,100);
   st.history=[{season:s.season,reputation:st.reputation,cohesion:st.cohesion,
    graduates,trained,styleProgress,fulfilled,broken,identity:st.identity},...st.history].slice(0,15);
   return true;
  });
 }
 function panel(s){
  const st=ensure(s);if(!st)return '';
  const locked=!unlocked(s),js=x=>JSON.stringify(x).replace(/"/g,'&quot;');
  const prospects=st.candidates.slice(0,9).map(p=>'<li>'+safe(p.name)+' · '+safe(p.pos)+' · '+p.rating+'/'+
   p.potential+' · '+safe(p.region)+' <button onclick="v95Recruit('+js(p.id)+')"'+(locked?' disabled':'')+
   '>Recruter · 8 000 €</button></li>').join('');
  const youths=youth(s).filter(p=>p.age<=21).slice(0,12).map(p=>{
   const chosen=st.loads.find(x=>x.id===p.id)?.load||'equilibree';
   return '<li>'+safe(p.name)+' · '+safe(p.pos)+' · charge '+chosen+' · '+
    ['allegee','equilibree','intensive'].map(a=>'<button onclick="v97Load('+js(p.id)+',\''+a+'\')"'+(locked?' disabled':'')+'>'+a+'</button>').join(' ')+
    ' · '+DECISIONS.map(a=>'<button onclick="v98Ambition('+js(p.id)+',\''+a+'\')"'+
    (locked||st.ambitions.some(x=>x.id===p.id&&x.season===s.season)?' disabled':'')+'>'+a+'</button>').join(' ')+
   '</li>'}).join('');
  return '<section class="cd04-panel" style="padding:18px;margin-top:18px"><h2>V95–V100 · Stratégie de formation</h2>'+
   '<h3>V95 · Détection régionale</h3>'+REGIONS.map(x=>'<button onclick="v95Scout(\''+x+'\')"'+
   (locked||st.scouts>=3?' disabled':'')+'>'+x+' · 3 000 €</button>').join(' ')+
   '<p>Sessions : '+st.scouts+'/3 · Recrues : '+st.recruits.length+'/5</p><ul>'+prospects+'</ul>'+
   '<h3>V96 · Vie du groupe</h3><p>Cohésion : '+st.cohesion+'/100 · Réunions : '+st.meetings+
   '/3 <button onclick="v96Meeting()"'+(locked||st.meetings>=3?' disabled':'')+'>Réunion collective · 2 000 €</button></p>'+
   '<h3>V97 · Préparation physique et V98 · Ambitions</h3><ul>'+youths+'</ul>'+
   '<h3>V99 · Identité de jeu</h3><p>'+IDENTITIES.map(x=>'<button onclick="v99Identity(\''+x+'\')"'+
   (locked?' disabled':'')+'>'+x+(st.identity===x?' (actif)':'')+'</button>').join(' ')+'</p>'+
   '<h3>V100 · Réputation du centre</h3><p>'+st.reputation+'/100 · '+safe(rankings(s).tier)+
   '</p><ul>'+st.history.slice(0,10).map(h=>'<li>S'+h.season+' · '+h.graduates+' promus · réputation '+
   h.reputation+' · cohésion '+h.cohesion+'</li>').join('')+'</ul>'+
   networkPanel(s)+'<p class="help">Candidats et réputation entièrement fictifs. Les promesses ne déclenchent pas de transfert ni de promotion automatique. Développement physique soldé à la fin de saison.</p></section>';
 }
 function install(g){
  if(!g||typeof g.start!=='function'||typeof g.advanceSeason!=='function'||typeof g.render!=='function')return false;
  if(typeof g.v95Scout==='function')return true;
  const state=()=>typeof S!=='undefined'?S:g.S;
  const save=()=>{if(typeof g.save!=='function')return false;return g.save()!==false&&(typeof lastSaveError==='undefined'||!lastSaveError)};
  const oldStart=g.start;g.start=function(){const r=oldStart.apply(this,arguments);if(state()){ensure(state());save()}return r};
  const oldYear=g.advanceSeason;g.advanceSeason=function(){
   const s=state(),old=s?.season;
   if(s?.phase==='ended'&&!s?.v95to100?.history?.some(x=>x.season===s.season)){
    const before=copy(s);if(!settle(s)||!save()){Object.keys(s).forEach(k=>delete s[k]);Object.assign(s,before);return false}
   }
   const result=oldYear.apply(this,arguments);
   if(state()&&state().season!==old){ensure(state());save()}return result;
  };
  const oldRender=g.render;g.render=function(){const r=oldRender.apply(this,arguments),s=state();
   if(s&&typeof document!=='undefined'&&typeof view!=='undefined'&&view==='formation'){
    const target=document.querySelector('.cd04-content [data-da42-page="dossiers"]')||document.querySelector('.cd04-content');
    if(target?.insertAdjacentHTML)target.insertAdjacentHTML('beforeend',panel(s));
   }return r};
  for(const [name,fn] of [['v95Scout',discover],['v95Recruit',recruit],['v96Meeting',meeting],
   ['v97Load',load],['v98Ambition',ambition],['v99Identity',identity],
   ['v95Watch',watch],['v95Trial',trial],['v95Partner',partner],
   ['v95Clearance',clearance],['v95Sign',recruitFeeder]]){
    g[name]=function(){const ok=fn(state(),...arguments,save);if(ok)g.render();return ok};
  }
  return true;
 }
 const api={valid,ensure,network,model,watch,trial,partner,clearance,recruitFeeder,networkPanel,discover,recruit,meeting,load,ambition,identity,rankings,settle,panel,install};
 root.CDEspoirsStrategyV95V100=api;
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(!root.CDNativeHeadless&&typeof document!=='undefined')install(root);
})(typeof globalThis==='object'?globalThis:this);
