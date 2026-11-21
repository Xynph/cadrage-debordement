'use strict';
// Programme de la semaine, jour par jour (21/11/2026, panneaux de l'Effectif et écran Entraînement › Semaine).
// Le moteur simule UNE séance collective par semaine (trainWeek : charge S.training repos/normal/intense, préparation
// spécifique S.collectiveFocus) ; elle tombe d'elle-même en fin de semaine si le manager ne l'a pas lancée. Ce domaine
// place cette séance et les jours du calendrier réel dans la semaine du calendrier journalier (lundi → dimanche),
// en lecture seule et sans tirage (même état → même programme) :
//  - match : jour de la rencontre du club (CDWorldCareer.userFixture) ;
//  - veille : la veille du match (météo annoncée, plan adverse lu par le staff : world-career.cjs fixerMeteo) ;
//  - seance : la séance collective, trois jours avant le match (jour 2 sans match), ou deux jours après un match
//    trop tôt dans la semaine ; charge = S.training ; faite = S.trained ;
//  - recuperation : le lendemain d'un match du club (match de la semaine ou du week-end précédent) ;
//  - repos : les autres jours.
// Servi dans `clubLife.weekProgram` ; null hors carrière Monde.
const files=Object.freeze([]),commands=Object.freeze([]);
function factory(){
 const DAY=86400000;
 const LETTRES=['L','M','M','J','V','S','D'];
 const state=()=>typeof S==='undefined'?null:S;
 const dated=x=>typeof x==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(x)&&Number.isFinite(Date.parse(x+'T00:00:00Z'));
 const shift=(date,n)=>new Date(Date.parse(date+'T00:00:00Z')+n*DAY).toISOString().slice(0,10);
 const ecart=(a,b)=>Math.round((Date.parse(b+'T00:00:00Z')-Date.parse(a+'T00:00:00Z'))/DAY);
 const CHARGES=['repos','normal','intense'];
 function semaine(s){
  if(!s||!s.worldMode||typeof CDWorldCareer==='undefined'||typeof CDWorldCareer.calendarToday!=='function')return null;
  let today;try{today=CDWorldCareer.calendarToday(s);}catch(e){return null;}
  // Avant-saison (avant-saison.cjs) : sa date du jour remplace celle de la semaine 0, comme dans meta.calendarToday.
  const pre=s.preseason;if(pre&&typeof pre==='object'&&s.round===0&&!(s.worldMode.day>0)&&dated(pre.today))today=pre.today;
  if(!dated(today))return null;
  // Lundi de la semaine du calendrier (la carrière Monde commence ses semaines un lundi : seasonStart).
  const dow=(new Date(today+'T00:00:00Z').getUTCDay()+6)%7,lundi=shift(today,-dow);
  return {today,lundi,aujourdhui:dow};
 }
 function programme(s){
  const w=semaine(s);if(!w)return null;
  let f=null;try{f=CDWorldCareer.userFixture(s);}catch(e){f=null;}
  const own=s.club,joue=new Set((s.history||[]).map(r=>r.fixtureId));
  const m=f&&dated(f.date)?ecart(w.lundi,f.date):null,jm=m!==null&&m>=0&&m<=6?m:null;
  const charge=CHARGES.includes(s.training)?s.training:'normal';
  const jours=LETTRES.map((lettre,i)=>({index:i,date:shift(w.lundi,i),lettre,kind:'repos',today:i===w.aujourdhui,past:i<w.aujourdhui}));
  // Lendemain d'un match du club : match de la veille du lundi (dimanche) ou du samedi précédent → lundi en récupération.
  const derniers=(s.history||[]).filter(r=>Array.isArray(r.pair)&&r.pair.includes(own)&&dated(r.date)).map(r=>ecart(w.lundi,r.date));
  if(derniers.some(d=>d===-1||d===-2))jours[0].kind='recuperation';
  let seance;
  if(jm!==null){
   jours[jm]=Object.assign(jours[jm],{kind:'match',fixtureId:f.id,home:f.homeId===own,neutral:!!f.neutral,opponentId:f.homeId===own?f.awayId:f.homeId,played:joue.has(f.id)||s.worldMode.resultConfirmed===true});
   if(jm+1<=6)jours[jm+1].kind='recuperation';
   if(jm-1>=0)jours[jm-1].kind='veille';
   seance=jm>=3?jm-3:jm+2<=6?jm+2:null;
  }else seance=2;
  if(seance!==null){
   jours[seance].kind='seance';
   Object.assign(jours[seance],{charge,focus:typeof s.collectiveFocus==='string'?s.collectiveFocus:'aucune',done:s.trained===true});
  }
  const fait=s.trained===true;
  return {weekStart:w.lundi,today:w.today,todayIndex:w.aujourdhui,matchDay:jm,sessionDay:seance,charge,trained:fait,
   // Séance pas encore lancée alors que son jour est passé : elle reste possible, et tombe sinon en fin de semaine.
   sessionLate:!fait&&seance!==null&&seance<w.aujourdhui,days:jours};
 }
 function project(){
  const s=state();if(!s)return null;
  try{return programme(s);}catch(e){return null;}
 }
 function validate(){return true;}
 function execute(){throw Error('Programme de la semaine : aucune commande.');}
 function installHooks(){return true;}
 return {project,validate,execute,installHooks,programme};
}
module.exports={files,commands,factory};
