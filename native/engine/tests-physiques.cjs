'use strict';
// Tests physiques avant le match et historique des blessures (revue FM27, idée 36 ; choix A de Léo du 23/11/2026).
//
// Historique : chaque blessure d'un joueur du club du manager est gardée (début, type, semaines annoncées, cause, fin),
// joueur par joueur, dans S.testsPhysiques.historique (sauvegarde). Relevé après chaque commande (observe) : une blessure
// vue pour la première fois ouvre une ligne, la guérison la ferme. Ancienne sauvegarde : l'historique part des blessures
// en cours et des commotions déjà enregistrées sur les joueurs (p.commotion.hist).
//
// Tests de reprise : deux jours avant une rencontre du club (et jusqu'au jour du match), le médecin teste chaque joueur
// revenu de blessure depuis moins de 21 jours et pas encore testé depuis ce retour. Le moteur tire, avec une part de
// hasard (empreinte de la graine du monde, de la rencontre et du joueur), la VRAIE tolérance du joueur en minutes
// (15 à 80′) : blessure plus longue, retour plus récent, fragilité et méforme la font baisser. Test réussi si elle
// atteint 50′.
// Le médecin conseille des minutes : SON estimation de cette tolérance, arrondie à 5′, d'autant plus juste que son niveau
// est haut, jamais exacte. Moins de 20′ estimées : « ne pas aligner » (0). La tolérance n'est jamais projetée.
// En match : jouer au-delà de la vraie tolérance fait grimper le risque de blessure (× 1 + 0,1 par minute de trop, après
// le match comme pendant), sans sortie forcée. Fonction globale de la VM : facteurTestPhysique(p, minutes, l).
//
// Sauvegarde : S.testsPhysiques = {version:1, historique:{idJoueur:[{d, t, s, c, f, x?}]}, tests:null|{fixture, date,
//  fait, medecin, joueurs:[{id, ok, conseil, tolerance, t, s, retour}]}} ; d/f : dates ISO (f null tant que blessé),
//  t : type de blessure (club-mail.json) ou null, s : semaines annoncées, c : cause (match, entrainement, rechute) ou null,
//  x : rencontre du test de reprise passé après cette blessure.
// Projection : clubLife.testsPhysiques = {tests:null|{fixture, date, adversaire, medecin, joueurs:[{id, ok, minutes, t, s,
//  retour}]}, historique:{idJoueur:[{date, fin, type, semaines, cause, enCours}]}}.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const VERSION=1,FENETRE=21,AVANCE=2,SEUIL=50,MIN=15,MAX=80,PAR_MINUTE=.1,PAR_JOUEUR=30,MAX_JOUEURS=8,NIVEAU_DEFAUT=55;
 const CAUSES=['match','entrainement','rechute'];
 const DAY=86400000;
 const obj=x=>!!x&&typeof x==='object'&&!Array.isArray(x);
 const date=x=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x);
 const int=(x,a,b)=>Number.isSafeInteger(x)&&x>=a&&x<=b;
 const text=(x,max=60)=>typeof x==='string'&&x.length>0&&x.length<=max&&!/[\u0000-\u001f]/.test(x);
 const check=(ok,msg)=>{if(!ok)throw Error('Tests physiques : '+msg+'.');};
 const borne=(x,a,b)=>Math.max(a,Math.min(b,x));
 const jours=(a,b)=>Math.round((Date.parse(b+'T00:00:00Z')-Date.parse(a+'T00:00:00Z'))/DAY);
 const etat=()=>typeof S==='undefined'?null:S;
 // Empreinte FNV-1a : le hasard des tests ne touche pas au flux de hasard du moteur (rejeu à l'identique).
 const hash=str=>{let h=2166136261;for(let i=0;i<str.length;i++){h^=str.charCodeAt(i);h=Math.imul(h,16777619)>>>0;}h^=h>>>16;h=Math.imul(h,0x85ebca6b)>>>0;h^=h>>>13;return h>>>0;};
 const graine=s=>Number.isInteger(s?.careerVariation?.seed)?s.careerVariation.seed:0;
 const monde=s=>!!s&&typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s)&&s.worldMode?.day!==undefined;
 const aujourdhui=s=>{try{const d=CDWorldCareer.calendarToday(s);return date(d)?d:null;}catch(e){return null;}};
 const rencontre=s=>{try{return CDWorldCareer.userFixture(s)||null;}catch(e){return null;}};
 const clubDe=s=>Array.isArray(s?.clubs)||obj(s?.clubs)?s.clubs[s.club]:null;
 const joueurs=s=>Array.isArray(clubDe(s)?.players)?clubDe(s).players:[];
 const fragilite=p=>typeof valeurFragilite==='function'?valeurFragilite(p):50;
 const cause=p=>CAUSES.includes(p?.injuryOrigin?.type)?p.injuryOrigin.type:CAUSES.includes(p?.injuryCause)?p.injuryCause:null;

 function assurer(s){
  if(!obj(s.testsPhysiques)||s.testsPhysiques.version!==VERSION){
   s.testsPhysiques={version:VERSION,historique:{},tests:null};
   reconstruire(s);
  }
  return s.testsPhysiques;
 }
 // Ancienne sauvegarde : commotions déjà enregistrées (closes) ; les blessures en cours sont ouvertes par releve().
 function reconstruire(s){
  const h=s.testsPhysiques.historique,auj=aujourdhui(s);
  for(const p of joueurs(s)){
   const hist=Array.isArray(p?.commotion?.hist)?p.commotion.hist:[];
   for(const c of hist){
    if(!date(c?.date))continue;
    const fin=date(c.retour)?c.retour:c.date;
    if(auj&&fin>auj)continue; // commotion en cours : ouverte par releve()
    (h[p.id]??=[]).push({d:c.date,t:'commotion',s:Math.max(1,Math.ceil(jours(c.date,fin)/7)),c:'match',f:fin});
   }
   if(h[p.id]){h[p.id].sort((a,b)=>a.d<b.d?-1:a.d>b.d?1:0);h[p.id]=h[p.id].slice(-PAR_JOUEUR);}
  }
 }
 const ouverte=liste=>Array.isArray(liste)&&liste.length&&liste[liste.length-1].f===null?liste[liste.length-1]:null;
 // Blessures du club du manager : ouverture, mise à jour (type, cause, durée), fermeture à la guérison.
 function releve(s,auj){
  const h=s.testsPhysiques.historique;
  let n=0;
  for(const p of joueurs(s)){
   if(!p||p.id===undefined||p.id===null)continue;
   const id=String(p.id),liste=h[id],e=ouverte(liste),blesse=Number(p.injury)>0;
   const commotion=obj(p.commotion?.protocole)&&date(p.commotion.protocole.date)?p.commotion.protocole:null;
   if(blesse){
    // Guéri puis blessé de nouveau entre deux relevés : l'ancienne blessure se ferme au début de la nouvelle.
    if(e&&e.t!==null&&!commotion&&text(p.injuryType,40)&&p.injuryType!==e.t&&date(p.injuryDate)&&p.injuryDate>e.d){e.f=p.injuryDate;n++;}
    if(!ouverte(h[id])){
     const debut=commotion?.date||(date(p.injuryDate)?p.injuryDate:auj);
     (h[id]??=[]).push({d:debut>auj?auj:debut,t:commotion?'commotion':(text(p.injuryType,40)?p.injuryType:null),s:borne(Math.ceil(Number(p.injury)),1,99),c:commotion?'match':cause(p),f:null});
     if(h[id].length>PAR_JOUEUR)h[id]=h[id].slice(-PAR_JOUEUR);
     n++;continue;
    }
    if(e.t===null&&text(p.injuryType,40)){e.t=p.injuryType;n++;}
    if(e.c===null&&cause(p)){e.c=cause(p);n++;}
    const sem=borne(Math.ceil(Number(p.injury)),1,99);if(sem>e.s){e.s=sem;n++;}
   }else if(e){e.f=auj<e.d?e.d:auj;n++;}
  }
  return n;
 }
 // Médecin du club : meilleur membre médical dont la fonction est « médecin », à défaut le meilleur du service médical.
 function medecin(s){
  const gens=s?.staffCareer?.version===1&&Array.isArray(s.staffCareer.people)?s.staffCareer.people.flat():[];
  const actifs=gens.filter(p=>p&&p.clubId===s.club&&p.role==='medical'&&Number.isFinite(p.level)&&(p.contractEnd==null||p.contractEnd>=s.season));
  const ordre=(a,b)=>b.level-a.level||(a.id<b.id?-1:a.id>b.id?1:0);
  const docteurs=actifs.filter(p=>/m[ée]decin|doct/i.test(String(p.roleLabel||''))).sort(ordre);
  const p=docteurs[0]||actifs.sort(ordre)[0];
  return p?{id:String(p.id),nom:typeof p.name==='string'?p.name:null,niveau:p.level}:{id:null,nom:null,niveau:NIVEAU_DEFAUT};
 }
 // Vraie tolérance (minutes) : blessure, jours depuis le retour, fragilité, forme, hasard.
 function tolerance(s,f,p,e,jour){
  const depuis=Math.max(0,jours(e.f,jour));
  let deficit=6+5*Math.min(e.s,8)-1.2*depuis;
  deficit+=(fragilite(p)-50)*.15;
  deficit+=Math.max(0,85-(Number.isFinite(p.condition)?p.condition:100))*.5;
  const bruit=hash('tolerance|'+graine(s)+'|'+s.season+'|'+f.id+'|'+p.id)%25-12;
  return borne(Math.round(80-Math.max(0,deficit)+bruit),MIN,MAX);
 }
 // Conseil du médecin : la tolérance à ± (4 à 18′ selon son niveau), arrondie à 5′, jamais exacte ; < 20′ → 0.
 function conseil(s,f,p,vrai,niveau){
  const A=borne(Math.round(4+(85-niveau)*.35),4,18);
  let ecart=hash('conseil|'+graine(s)+'|'+s.season+'|'+f.id+'|'+p.id)%(2*A+1)-A;
  if(Math.abs(ecart)<2)ecart=ecart<0?-2:2;
  let m=borne(Math.round((vrai+ecart)/5)*5,0,MAX);
  if(m===vrai)m=vrai>=MAX?MAX-5:m+(ecart<0?-5:5);
  return m<20?0:borne(m,0,MAX);
 }
 // Joueurs revenus de blessure depuis moins de FENETRE jours (avant la rencontre), pas encore testés depuis ce retour.
 function aTester(s,f,auj){
  const h=s.testsPhysiques.historique,out=[];
  for(const p of joueurs(s)){
   if(!p||Number(p.injury)>0)continue;
   const liste=h[String(p.id)];if(!Array.isArray(liste)||!liste.length)continue;
   const e=liste[liste.length-1];
   if(e.f===null||e.f>auj||e.x!==undefined||jours(e.f,f.date)>FENETRE)continue;
   out.push({p,e});
  }
  return out.sort((a,b)=>a.e.f<b.e.f?1:a.e.f>b.e.f?-1:String(a.p.id).localeCompare(String(b.p.id))).slice(0,MAX_JOUEURS);
 }
 // Tests de la prochaine rencontre : posés AVANCE jours avant, complétés chaque jour jusqu'au match (retours tardifs).
 function tester(s,auj){
  const st=s.testsPhysiques,f=rencontre(s);
  if(!f||!date(f.date)||f.id===undefined)return 0;
  if(st.tests&&st.tests.fixture!==String(f.id)&&st.tests.date<auj)st.tests=null;
  const reste=jours(auj,f.date);if(reste<0||reste>AVANCE)return 0;
  if(!st.tests||st.tests.fixture!==String(f.id)){const m=medecin(s);st.tests={fixture:String(f.id),date:f.date,fait:auj,medecin:{id:m.id,nom:m.nom},joueurs:[]};}
  const t=st.tests,niveau=medecin(s).niveau;
  let n=0;
  for(const {p,e} of aTester(s,f,auj)){
   if(t.joueurs.length>=MAX_JOUEURS)break;
   if(t.joueurs.some(j=>j.id===String(p.id)))continue;
   const vrai=tolerance(s,f,p,e,auj);
   t.joueurs.push({id:String(p.id),ok:vrai>=SEUIL,conseil:conseil(s,f,p,vrai,niveau),tolerance:vrai,t:e.t,s:Math.max(1,Math.round(jours(e.d,e.f)/7)),retour:e.f});
   e.x=String(f.id);n++;
  }
  return n;
 }
 function borner(s){
  const h=s.testsPhysiques.historique,ids=Object.keys(h);
  if(ids.length<=150)return;
  const presents=new Set(joueurs(s).map(p=>String(p.id)));
  for(const id of ids)if(!presents.has(id)&&!ouverte(h[id]))delete h[id];
 }
 // Après chaque commande (worker, avant le courrier du jour) : historique puis tests de la prochaine rencontre.
 function observe(){
  const s=etat();
  if(!monde(s)||s.live&&!s.live.finished)return 0;
  const auj=aujourdhui(s);if(!auj)return 0;
  assurer(s);
  const n=releve(s,auj)+tester(s,auj);
  borner(s);
  return n;
 }
 // Risque de blessure en match : × (1 + 0,1 par minute au-delà de la vraie tolérance), joueur testé pour cette rencontre.
 function facteur(p,minutes,l){
  const s=etat(),t=s?.testsPhysiques?.tests;
  if(!t||!p||!Number.isFinite(minutes))return 1;
  const id=l?.worldContext?.id;if(id===undefined||String(id)!==t.fixture)return 1;
  const j=t.joueurs.find(x=>x.id===String(p.id));if(!j)return 1;
  const trop=minutes-j.tolerance;
  return trop>0?1+trop*PAR_MINUTE:1;
 }
 const vueEntree=(e,auj)=>({date:e.d,fin:e.f,type:e.t,semaines:e.f===null?e.s:Math.max(1,Math.round(jours(e.d,e.f)/7)),cause:e.c,enCours:e.f===null||!!auj&&e.f>auj});
 function project(){
  const s=etat();
  if(!monde(s)||!obj(s.testsPhysiques))return null;
  const st=s.testsPhysiques,auj=aujourdhui(s),f=rencontre(s);
  const presents=new Set(joueurs(s).map(p=>String(p.id)));
  const historique={};
  for(const [id,liste] of Object.entries(st.historique))if(presents.has(id))historique[id]=liste.map(e=>vueEntree(e,auj)).reverse();
  let tests=null;
  if(st.tests&&f&&String(f.id)===st.tests.fixture&&st.tests.joueurs.length){
   const adv=f.homeId===s.club?f.awayId:f.homeId;
   tests={fixture:st.tests.fixture,date:st.tests.date,fait:st.tests.fait,adversaire:s.clubs?.[adv]?.name??null,medecin:st.tests.medecin.nom,
    joueurs:st.tests.joueurs.filter(j=>presents.has(j.id)).map(j=>({id:j.id,ok:j.ok,minutes:j.conseil,type:j.t,semaines:j.s,retour:j.retour}))};
  }
  return {tests,historique};
 }
 function validate(s){
  if(!s||s.testsPhysiques===undefined)return true;
  const st=s.testsPhysiques;
  check(obj(st)&&st.version===VERSION&&obj(st.historique)&&(st.tests===null||obj(st.tests)),'état invalide');
  for(const [id,liste] of Object.entries(st.historique)){
   check(text(id,180)&&Array.isArray(liste)&&liste.length<=PAR_JOUEUR,'historique invalide');
   liste.forEach((e,i)=>check(obj(e)&&date(e.d)&&(e.f===null&&i===liste.length-1||date(e.f)&&e.f>=e.d)&&(e.t===null||text(e.t,40))&&int(e.s,1,99)&&(e.c===null||CAUSES.includes(e.c))&&(e.x===undefined||text(e.x,120)),'blessure de l’historique invalide'));
  }
  if(st.tests){
   const t=st.tests;
   check(text(t.fixture,120)&&date(t.date)&&date(t.fait)&&t.fait<=t.date&&obj(t.medecin)&&(t.medecin.id===null||text(t.medecin.id,180))&&(t.medecin.nom===null||text(t.medecin.nom,120))&&Array.isArray(t.joueurs)&&t.joueurs.length<=MAX_JOUEURS,'tests invalides');
   const vus=new Set();
   for(const j of t.joueurs){
    check(obj(j)&&text(j.id,180)&&!vus.has(j.id)&&typeof j.ok==='boolean'&&int(j.tolerance,MIN,MAX)&&j.ok===(j.tolerance>=SEUIL)&&int(j.conseil,0,MAX)&&j.conseil%5===0&&j.conseil!==j.tolerance&&(j.t===null||text(j.t,40))&&int(j.s,1,99)&&date(j.retour),'joueur testé invalide');
    vus.add(j.id);
   }
  }
  return true;
 }
 function installHooks(){globalThis.facteurTestPhysique=facteur;return true;}
 return {project,validate,execute(){throw Error('Aucune commande de tests physiques.');},installHooks,observe,facteur,
  _tests:{tolerance,conseil,medecin,aTester,releve,assurer,tester},RULES:Object.freeze({FENETRE,AVANCE,SEUIL,MIN,MAX,PAR_MINUTE,MAX_JOUEURS})};
}
module.exports={files,commands,factory};
