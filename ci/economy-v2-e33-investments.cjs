'use strict';
// E3.3 contract: never translate a selectable plan into an accrued payable.
const assert=require('node:assert/strict'),E32=require('./economy-v2-e32-adapter.cjs');
const N=require('../tests/career-resilience/native.cjs');
function observe(g){
 const x=N.data(g,`({season:S.season,round:S.round,phase:S.phase,clubId:S.club,
  clubCash:club().cash,worldEnabled:worldActive(),careerEnabled:careerIntegrated(),
  facility:worldActive()?({level:worldClub(S.club).facilities,
   quote:worldFacilityQuote(S.club),
   alreadyUpgraded:S.worldManagement.upgrades.some(x=>x.id===S.club&&x.season===S.season),
   events:S.worldManagement.upgrades.filter(x=>x.id===S.club).map(x=>({season:x.season,level:x.level,cost:x.cost}))}):null,
  academy:careerIntegrated()?({selectedWeekly:S.careerManagement.academyInvestment,
   spentThisSeason:S.careerManagement.academySpent,
   paidWeeksThisSeason:S.careerManagement.academyWeeks,
   lastPaidWeek:S.careerManagement.lastAcademyWeek}):null,
  ledger:S.ledger.filter(x=>typeof x.title==='string'&&
   (x.title.includes('Investissement formation')||x.title.includes('Investissement dans les installations')))
   .map(x=>({title:x.title,amount:x.amount}))})`);
 assert(Number.isFinite(x.clubCash)&&Number.isInteger(x.season)&&Number.isInteger(x.round));
 const facility=x.facility?{
  level:x.facility.level,quote:x.facility.quote?{
   immediateCost:x.facility.quote.cost,
   affordableNow:x.facility.quote.affordable===true,
   nextLevel:x.facility.quote.nextLevel,
   twelveWeekIllustrativeTotal:x.facility.quote.total
  }:null,alreadyUpgraded:x.facility.alreadyUpgraded,
  paidEvents:x.facility.events.map(e=>({...e,datePrecision:'season-only'})),
  knownEffectRule:'weekly development input +0.012 per level above 2 for eligible under-23 players, age and cap dependent',
  measuredFutureSportResult:null,
  futurePaymentDue:null
 }:null;
 const academy=x.academy?{
  selectedWeekly:x.academy.selectedWeekly,
  allowedChoices:[0,4000,12000],
  spentThisSeason:x.academy.spentThisSeason,paidWeeksThisSeason:x.academy.paidWeeksThisSeason,
  lastPaidWeek:x.academy.lastPaidWeek,
  knownEffectRule:'development XP input 0.055 at 4000 or 0.15 at 12000 after successful cash debit, subject to growth rules',
  measuredFutureSportResult:null,futurePaymentDue:null
 }:null;
 const result={stage:'E3.3',source:'native-read-only-snapshot',season:x.season,round:x.round,
  phase:x.phase,clubId:x.clubId,cash:x.clubCash,worldEnabled:x.worldEnabled,
  careerEnabled:x.careerEnabled,facility,academy,ledgerEvidence:x.ledger,
  contract:{futureScheduledInvestment:null,confirmedFutureRevenue:null,accruedLiability:null},
  readOnly:true};
 assert.equal(result.contract.futureScheduledInvestment,null);
 return result;
}
function validate(e){
 assert.equal(e.stage,'E3.3');assert.equal(e.source,'native-read-only-snapshot');
 assert.equal(e.readOnly,true);assert.equal(e.contract.accruedLiability,null);
 assert.equal(e.contract.futureScheduledInvestment,null);
 if(e.facility){assert(e.facility.level>=1&&e.facility.level<=10);
  for(const x of e.facility.paidEvents)assert(Number.isInteger(x.season)&&Number.isFinite(x.cost)&&x.cost>=0);}
 if(e.academy)assert([0,4000,12000].includes(e.academy.selectedWeekly));
 return e;
}
function render(native,advisory,proof){
 const e=validate(proof);
 const html=E32.render(native,advisory);
 const p=JSON.stringify(e).replace(/</g,'\\u003c').replace(/>/g,'\\u003e').replace(/&/g,'\\u0026');
 const section=[
 '<section class="card" id="e33-investment" aria-label="Investissements réellement observables" style="margin-top:14px">',
 '<div class="eyebrow">E3.3 · AUDIT NATIF · AUCUNE DÉCISION APPLIQUÉE</div><h2>Investissements sportifs facultatifs</h2>',
 '<p class="muted small">État ponctuel du club piloté sur une carrière de référence. Les chiffres sont fictifs et ne sont pas des promesses de dépense ou de performance.</p>',
 '<div class="options"><div class="card"><h3>Installations</h3><p id="e33-facility"></p></div>',
 '<div class="card"><h3>Formation</h3><p id="e33-academy"></p></div>',
 '<div class="card"><h3>Preuves comptabilisées</h3><p id="e33-events"></p></div></div>',
 '<div class="note">Les coûts futurs, dates d’exigibilité, recettes garanties et gains sportifs réels restent Non disponibles. Un devis conditionnel n’est pas une dette ; un choix de formation ne crée pas de facture. Les projections E3.1 restent des scénarios synthétiques séparés.</div>',
 '</section>'
 ].join('');
 const script=[
 '<script id="e33-data" type="application/json">'+p+'</script>',
 '<script>(()=>{\'use strict\';',
 'const e=JSON.parse(document.getElementById("e33-data").textContent);',
 'const set=(id,v)=>document.getElementById(id).textContent=v;',
 'const money=n=>new Intl.NumberFormat("fr-FR").format(n)+" €";',
 'const f=e.facility,a=e.academy;',
 'set("e33-facility",!f?"Module inactif / Non disponible":("Niveau "+f.level+"/10. "+',
 '(f.quote?("Devis immédiat conditionnel "+money(f.quote.immediateCost)+',
 '" ; faisable maintenant : "+(f.quote.affordableNow?"oui":"non")):"Pas de devis : niveau maximal")+". Effet sportif futur non mesuré."));',
 'set("e33-academy",!a?"Module inactif / Non disponible":("Choix hebdomadaire "+money(a.selectedWeekly)+',
 '". Paiements cumulés de la saison : "+money(a.spentThisSeason)+" pour "+a.paidWeeksThisSeason+" semaines. Gain sportif futur non mesuré."));',
 'set("e33-events",(f?f.paidEvents.length:0)+" amélioration(s) datée(s) à la saison ; "+',
 'e.ledgerEvidence.length+" écriture(s) investissement visible(s) dans les 100 dernières lignes du registre (historique non exhaustif).");',
 '})();</script>'
 ].join('');
 return html.replace('<main>',section+'<main>').replace('</body>',script+'</body>');
}
module.exports={observe,validate,render};
