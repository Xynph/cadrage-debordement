'use strict';
// Cohérence des chiffres entre domaines, carrière Monde (Lyon Confluences XV, avant-saison 2026-2027).
// Chaque indicateur n'a qu'une source dans le moteur (club-budget.cjs : chiffresMasse, chiffresContrats ;
// world-model.cjs : figures.nextFixtureId ; club-strategy.cjs : finance.projection). Ce test vérifie que
// tous les domaines qui l'affichent (Finances, Club, Bureau, Réception, Recrutement, Tactique, Entraînement,
// Compétitions) lisent des valeurs qui s'accordent, et que les libellés distinguent ce qui diffère.
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge}=require('../native/engine/worker.cjs');
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');

const LYON=7;
test('Monde : masse salariale, échéances, marge et prochaine rencontre disent la même chose partout',()=>{
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-coherence-'));
 let id=0;const bridge=createBridge({dataDir:dir,seed:27,now:1794178800000,dailyCalendar:true});
 const call=(command,payload={})=>{const r=bridge.handle({id:++id,command,payload});assert.equal(r.ok,true,command+' : '+r.error);return r.model;};
 try{
  let m=settleClubMeetings(call('new_career',{mode:'world-champ',club:LYON}),call);
  assert.equal(m.club.name,'Lyon Confluences XV');
  const check=(model,quand)=>{
   const f=model.figures,strategy=model.clubLife.clubStrategy.finance,season=model.meta.season;
   assert.ok(f&&f.payroll&&f.contracts,quand+' : le moteur publie figures');

   // 1. Échéances : fin de saison (10 sur Lyon) et horizon fin de la saison suivante (31) mesurent deux choses.
   const fin=model.squad.filter(p=>p.contractEnd===season).length,horizon=model.squad.filter(p=>Number.isFinite(p.contractEnd)&&p.contractEnd<=season+1).length;
   assert.equal(f.contracts.endOfSeason,fin,quand+' : échéances de fin de saison');
   assert.equal(f.contracts.byHorizon,horizon,quand+' : échéances à l’horizon');
   assert.equal(f.contracts.squadSize,model.squad.length);
   assert.equal(model.decisions.recruitment.expiring.length,f.contracts.endOfSeason,quand+' : Recrutement et Réception lisent la même fin de saison que figures');
   assert.ok(f.contracts.byHorizon>=f.contracts.endOfSeason,quand+' : l’horizon contient la fin de saison');
   assert.equal(f.contracts.horizonSeason,season+1);

   // 2. Masse salariale : trois mesures, un seul calcul.
   const somme=model.squad.reduce((n,p)=>n+p.salary,0),w=f.payroll;
   assert.equal(w.joueursHebdo,somme,quand+' : salaires des contrats = somme des fiches');
   assert.equal(model.finance.wage,w.joueursHebdo,quand+' : Finances (masse salariale) lit le même chiffre');
   assert.equal(w.annuelle,somme*52);
   assert.equal(strategy.weeklyWages,w.chargeHebdo,quand+' : Club et répartition des charges = charge avec cotisations');
   assert.equal(w.chargeHebdo,w.verseHebdo+w.cotisationsHebdo,quand+' : charge = versé + cotisations');
   assert.ok(Math.abs(w.verseHebdo-somme*52/w.semainesDePaie)<=100,quand+' : versé = salaires × 52 ÷ semaines de paie (arrondi à 100 €)');
   assert.ok(Math.abs(w.cotisationsHebdo-w.verseHebdo*w.tauxCotisations)<=100);
   assert.ok(w.chargeHebdo>w.joueursHebdo,quand+' : la charge avec cotisations dépasse la masse hors cotisations, d’où deux libellés distincts');
   assert.equal(model.finance.cash,strategy.cash,quand+' : même trésorerie');

   // 3. Marge hebdomadaire et trésorerie projetée : la différence s’explique par un poste nommé.
   const p=strategy.projection;
   assert.ok(p,quand+' : la projection est détaillée');
   assert.equal(p.weeklyMargin,strategy.weeklyIncome-strategy.weeklyCosts);
   assert.equal(p.marginTotal,p.weeklyMargin*strategy.remainingWeeks);
   assert.equal(p.cash+p.marginTotal+p.otherInflows,strategy.baseForecast,quand+' : trésorerie + marge courante + autres apports = trésorerie prévue');
   assert.equal(p.forecast,strategy.budget.tresoreriePrevue,quand+' : même prévision que le budget de saison');
   if(p.weeklyMargin<0&&strategy.baseForecast>strategy.cash)assert.ok(p.otherInflows>0,quand+' : marge négative et prévision en hausse supposent des apports hors marge courante (guichet, primes, soutien du propriétaire)');

   // 4. Prochaine rencontre : une seule définition, avant-saison comprise.
   const prochaine=model.calendar.filter(x=>!x.played).sort((a,b)=>a.date.localeCompare(b.date)||a.id.localeCompare(b.id))[0];
   assert.ok(prochaine,quand+' : le calendrier publie une rencontre à venir');
   assert.equal(f.nextFixtureId,prochaine.id,quand+' : figures désigne la première rencontre non jouée');
   if(model.next)assert.deepEqual(model.next.pair,[prochaine.home.id,prochaine.away.id],quand+' : la rencontre à préparer est la prochaine du calendrier');
   return prochaine;
  };
  const avant=check(m,'avant-saison');
  assert.equal(m.next,null,'avant-saison : aucune rencontre « à préparer » côté moteur, mais le calendrier a la sienne');
  assert.match(avant.date,/^2026-09-0\d$/,'première journée début septembre');
  assert.ok(avant.home.id===LYON||avant.away.id===LYON);
  // Quelques jours plus tard, les mêmes relations tiennent.
  for(let i=0;i<2;i++)m=settleClubMeetings(call('advance_day',{fromDate:m.meta.calendarToday}),call);
  check(m,'après 2 jours');
  // Courriers : accord grammatical, et nombre égal à la fin de saison.
  for(const text of m.messages){
   assert.doesNotMatch(String(text),/contrat\(s\)|expire\(nt\)/,'courrier de contrats accordé : '+text);
   const mail=/^(\d+) contrats? expirent? à la fin de cette saison/.exec(String(text));
   if(mail)assert.equal(Number(mail[1]),m.figures.contracts.endOfSeason,'courrier de fin de saison = figures');
  }
 }finally{call('shutdown');bridge.close?.();fs.rmSync(dir,{recursive:true,force:true});}
});
