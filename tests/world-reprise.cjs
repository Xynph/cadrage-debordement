'use strict';
// Reprise de l'entraînement (reprise.cjs) : départ de la partie, date de reprise du club,
// internationaux en congés, jeunes en préparation, effets bornés et clubs de l'ordinateur.
// Carrières Monde (world-champ) uniquement.
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');

function career(t,payload){
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-reprise-'));
 const b=createBridge({dataDir:dir,seed:27,now:1794178800000});let id=0;
 const send=(command,body={})=>b.handle({id:++id,command,payload:body});
 const go=(command,body={})=>{const r=send(command,body);assert.equal(r.ok,true,command+': '+r.error);return r.model;};
 t.after(()=>{b.close();fs.rmSync(dir,{recursive:true,force:true});});
 const state=()=>JSON.parse(go('export').meta.exportText).state;
 return {send,go,state,model:settleClubMeetings(go('new_career',{mode:'world-champ',club:0,...payload}),go)};
}
const REAL_ELITE={0:'2026-07-27',1:'2026-07-22',2:'2026-07-23',3:'2026-07-15',4:'2026-07-20',5:'2026-07-13',6:'2026-07-16',7:'2026-07-13',8:'2026-08-03',9:'2026-07-13',10:'2026-07-28',11:'2026-07-27',12:'2026-07-15',13:'2026-07-15'};

test('départ par défaut : lundi 13 juillet 2026, préparation vécue, décision et internationaux',t=>{
 const {go,send,state,model}=career(t,{});
 let m=model,r=m.clubLife.reprise;
 assert.equal(m.meta.legacyModes,false);
 assert.equal(r.start,'premiers-clubs');
 assert.equal(m.meta.calendarToday,'2026-07-13','la partie commence avec les premiers clubs');
 assert.equal(m.meta.calendarCadence.preseason,true);
 assert.equal(r.editable,true);
 assert.equal(r.club.date,'2026-07-27','date réelle de reprise du club (LNR)');
 assert.ok(r.club.real);
 assert.deepEqual(m.meta.repriseCreation.elite,REAL_ELITE,'dates LNR 2026 rattachées aux identifiants de club');
 // Lundis proposés : juillet et début août, jamais avant le départ.
 const dates=r.options.map(o=>o.date);
 assert.ok(dates.includes('2026-07-13')&&dates.includes('2026-08-10'),dates.join());
 assert.ok(dates.every(d=>d>='2026-07-13'&&d<='2026-08-10'));
 assert.ok(r.options.every(o=>o.habitual||new Date(o.date+'T00:00:00Z').getUTCDay()===1),'des lundis, plus la date habituelle');
 // Internationaux : retour après la tournée d'été et les congés, quel que soit le lundi choisi.
 assert.ok(r.internationals.length>=5,'Toulouse compte des internationaux en tournée');
 assert.ok(r.internationals.every(p=>p.returnDate==='2026-08-10'||p.returnDate==='2026-08-03'));
 assert.ok(r.internationals.every(p=>p.status.startsWith('en congés · retour le ')));
 assert.equal(r.group.atReprise+r.internationals.length,r.group.total);
 assert.ok(r.advice&&r.advice.text.length>20&&r.options.some(o=>o.date===r.advice.date),'Gabi conseille une date proposée');
 // Décisions refusées hors des lundis proposés ; calendrier du moteur bloqué pendant la préparation.
 assert.equal(send('reprise_choose',{date:'2026-07-14'}).ok,false);
 assert.equal(send('reprise_choose',{date:'2026-09-07'}).ok,false);
 assert.match(send('finish_round').error,/préparation d’avant-saison/);
 assert.match(send('begin_match').error,/préparation d’avant-saison/);
 m=go('reprise_choose',{date:'2026-07-13'});r=m.clubLife.reprise;
 assert.equal(r.club.date,'2026-07-13');
 assert.ok(r.club.effects.fatigue>0&&r.club.effects.conditionGap===0,'reprise tôt : moins reposés, pas de retard de condition');
 m=go('reprise_choose',{date:'2026-08-10'});r=m.clubLife.reprise;
 assert.ok(r.club.effects.conditionGap>0&&r.club.effects.injuryRisk>0&&r.club.effects.morale>0&&r.club.effects.fatigue===0,'reprise tard : frais mais court');
 // Jeunes convoqués : Espoirs et -18 de 17 ans, au plus huit.
 const ids=r.youth.candidates.map(p=>p.id);
 assert.ok(r.youth.candidates.every(p=>p.age>=17&&p.age<=21));
 assert.equal(send('reprise_youth',{playerIds:ids.slice(0,9)}).ok,false);
 assert.equal(send('reprise_youth',{playerIds:['inconnu']}).ok,false);
 m=go('reprise_youth',{playerIds:ids.slice(0,4)});
 assert.deepEqual(m.clubLife.reprise.youth.selected,ids.slice(0,4));
 // Avance jour par jour, puis ouverture du calendrier : le plan de toute la planète est figé.
 m=settleClubMeetings(go('advance_day',{fromDate:'2026-07-13'}),go);
 assert.equal(m.meta.calendarToday,'2026-07-14');
 assert.equal(send('advance_day',{fromDate:'2026-07-13'}).ok,false,'date périmée refusée');
 m=settleClubMeetings(go('reprise_advance',{fromDate:'2026-07-14',until:'saison'}),go);
 assert.equal(m.meta.calendarToday,'2026-08-17');
 assert.equal(m.meta.calendarCadence?.preseason,undefined);
 r=m.clubLife.reprise;
 assert.equal(r.club.date,'2026-08-10');
 assert.equal(r.editable,false,'la reprise du 10 août est passée : décision close');
 const s=state();
 assert.equal(s.reprise.plan.clubs.length,s.clubs.length-s.clubs.filter(c=>!s.worldMode.fixtures.some(f=>f.homeId===c.id||f.awayId===c.id)).length);
 for(const [id,date]of Object.entries(REAL_ELITE)){
  if(Number(id)===0)continue;
  const row=s.reprise.plan.clubs.find(x=>x[0]===Number(id));
  assert.equal(new Date(row[1]*86400000).toISOString().slice(0,10),date,'club de l’ordinateur à sa date réelle');
 }
 assert.equal(send('reprise_choose',{date:'2026-08-10'}).ok,false);
});

test('départ « Reprise de ton club » puis préparation jouée : effets, jeunes et sauvegarde',t=>{
 const {go,send,state,model}=career(t,{start:'club'});
 let m=model;
 assert.equal(m.meta.calendarToday,'2026-07-27');
 assert.equal(m.clubLife.reprise.start,'club');
 const youth=m.clubLife.reprise.youth.suggested.slice(0,3);
 m=go('reprise_youth',{playerIds:youth});
 const before=state(),dev=Object.fromEntries(before.development.academy.filter(p=>youth.includes(p.id)).map(p=>[p.id,p.dev.minutes]));
 m=settleClubMeetings(go('reprise_advance',{fromDate:'2026-07-27',until:'saison'}),go);
 for(let i=0;i<4&&!m.next;i++)m=settleClubMeetings(go('finish_round'),go);
 assert.ok(m.next,'première journée');
 const s=state(),r=m.clubLife.reprise;
 assert.ok(r.report&&r.report.season===1&&r.report.friendlies>=1,'bilan de préparation');
 assert.deepEqual(r.report.youth.map(y=>y.id),youth);
 for(const y of r.report.youth){
  assert.ok(y.minutes>=25*r.report.friendlies&&y.minutes<=55*r.report.friendlies,'temps de jeu en amical');
  assert.equal(s.development.academy.find(p=>p.id===y.id).dev.minutes,dev[y.id]+y.minutes);
 }
 // Retard de condition de la reprise du 27/07 (1 semaine plus tard que la référence) : borné.
 const own=s.reprise.plan.clubs.find(x=>x[0]===0);
 assert.equal(own[4],1,'effets de début de saison appliqués');
 const fx=r.club.effects;
 assert.ok(fx.conditionGap<=12&&fx.fatigue<=15&&Math.abs(fx.morale)<=6&&fx.injuryRisk<=1.6&&fx.automatismes>=-22&&fx.automatismes<=6);
 for(const p of s.clubs[0].players){const gap=s.reprise.plan.players[p.id]?.[1]??fx.conditionGap;assert.ok(p.condition<=100-gap,'condition plafonnée');}
 // Clubs de l'ordinateur : mêmes effets, appliqués à leur semaine de 1re rencontre.
 assert.ok(s.reprise.plan.clubs.filter(x=>x[0]!==0&&x[4]===1).length>=13);
 // Sauvegarde : export/import strict.
 const text=go('export').meta.exportText;
 assert.equal(send('import',{text}).ok,true);
 const broken=JSON.parse(text);broken.state.reprise.plan.clubs[0][2]=999;
 assert.equal(send('import',{text:JSON.stringify(broken)}).ok,false,'plan corrompu refusé');
});

test('départ « Veille de la 1re journée » : préparation gérée par le staff, déterministe',t=>{
 const a=career(t,{start:'veille'}),b=career(t,{start:'veille'});
 const r=a.model.clubLife.reprise;
 assert.equal(r.auto,true);
 assert.equal(r.editable,false);
 assert.ok(a.model.next,'la première rencontre est la prochaine');
 assert.ok(r.report?.auto&&r.report.youth.length>=2,'le staff a convoqué des jeunes');
 assert.equal(r.club.date,'2026-07-27','le staff reprend à la date habituelle du club');
 assert.deepEqual(a.state().reprise,b.state().reprise,'même graine, même préparation');
 assert.equal(a.send('new_career',{mode:'world-champ',club:0,start:'janvier'}).ok,false);
});

test('barème borné et monotone ; club de l’ordinateur décalé après une finale',()=>{
 const g=globalThis,prior=g.CDWorldCareer;
 try{
  // Monde minimal : un club de Premiership finaliste la saison passée.
  const fixtures=[{homeId:30,awayId:31,date:'2027-09-25'}];
  g.CDWorldCareer={active:()=>true,edition:()=>({mode:'world-champ'}),leagueId:()=>'prem',calendarToday:()=>'2027-08-16'};
  const api=require('../native/engine/reprise.cjs').factory(),R=g.CDReprise;
  assert.ok(api.project&&api.validate&&api.execute&&api.installHooks);
  const s=y=>({season:2,club:5,clubs:[],worldMode:{fixtures,yearbook:y}});
  const plain=R.clubDefault(s([{season:1,champions:{prem:37},finalists:{prem:38},europe:{}}]),30);
  const finale=R.clubDefault(s([{season:1,champions:{prem:30},finalists:{prem:38},europe:{}}]),30);
  assert.equal(finale.day-plain.day,7,'une semaine plus tard après une finale');
  assert.equal(finale.finalShift,true);
  let last=null;
  for(let e=-6;e<=6;e+=.5){
   const fx=R.effectsFor(e,0);
   assert.ok(fx.fatigue>=0&&fx.fatigue<=15&&fx.conditionGap>=0&&fx.conditionGap<=12&&fx.injuryRisk>=0&&fx.injuryRisk<=1.6&&fx.morale>=-3&&fx.morale<=6&&fx.lateCondition<=6&&fx.automatismes>=-12&&fx.automatismes<=6);
   if(last){assert.ok(fx.fatigue>=last.fatigue&&fx.conditionGap<=last.conditionGap&&fx.automatismes>=last.automatismes&&fx.morale<=last.morale,'plus tôt : plus de charge, moins de retard');}
   last=fx;
  }
  assert.deepEqual(R.effectsFor(0,0),{fatigue:0,conditionGap:0,injuryRisk:0,automatismes:0,morale:0,lateCondition:0,friendlies:0},'référence neutre');
  assert.ok(R.effectsFor(0,.4).automatismes<0,'cadres absents : automatismes en retard');
 }finally{if(prior===undefined)delete g.CDWorldCareer;else g.CDWorldCareer=prior;delete g.CDReprise;}
});
