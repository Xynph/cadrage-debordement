'use strict';
const assert=require('node:assert/strict');
const {engineContext:context}=require('./harness.cjs');
const t=context(),run=t.run;
run('start(0)');
assert.equal(run('aiRosterActive()'),true);
const offers=[
 {clubId:2,priority:550,cashBuffer:900000},
 {clubId:1,priority:600,cashBuffer:800000},
 {clubId:3,priority:600,cashBuffer:700000}
];
run('var proposed='+JSON.stringify(offers));
assert.equal(run('aiRosterAuctionWinner(proposed).clubId'),1,'priority, then cash buffer');
run('proposed.reverse()');
assert.equal(run('aiRosterAuctionWinner(proposed).clubId'),1,'stable against arrival order');
run('proposed[2].cashBuffer=800000');
assert.equal(run('aiRosterAuctionWinner(proposed).clubId'),1,'stable club id on tie');
assert.equal(run('aiRosterAuctionWinner([])'),null);
// Les directions Monde publient leur stratégie hebdomadaire avant le marché.
run('nativeClubDirections.weekly()');
const base=JSON.parse(run('JSON.stringify(S)'));
assert.equal(run('aiRosterRecruitmentWeek()'),0,'first day season one excluded');
assert.ok(run('JSON.stringify(S)')===JSON.stringify(base),'excluded window does not mutate');
// Observer le vrai retour de la fenêtre appelée automatiquement par refreshMarket
// à la treizième semaine ; aucun marqueur de fenêtre ni calendrier n'est réécrit.
let windowBaseline=null;
function recruitmentWindow(h,fixture=''){
 h.deferSaves();
 if(!windowBaseline){h.week(12);windowBaseline=h.checkpoint();}
 else{h.restore(windowBaseline);assert.ok(h.run('JSON.stringify(S)')===windowBaseline.text,'copie indépendante du vrai point Monde semaine12');}
 h.run(`var recruitmentCount=0,marketSnapshot=null,originalRecruitment=aiRosterRecruitmentWeek;
 aiRosterRecruitmentWeek=function(){
  if(S.round===13&&!marketSnapshot){${fixture};marketSnapshot={cash:club().cash,loans:S.clubDirections.loans.length,reports:S.aiRoster.reports.reduce((n,r)=>n+r.recruited,0)};}
  var result=originalRecruitment.apply(this,arguments);if(S.round===13){recruitmentCount+=result;globalThis.marketAfter={cash:club().cash,buyerCash:typeof buyer==='undefined'?null:buyer.cash,graduatePrice:typeof graduate==='undefined'?null:graduate.price,fees:S.aiRoster.reports.reduce((n,r)=>n+r.fees,0)};}return result;
 }`);
 try{h.week(1);}finally{h.run('aiRosterRecruitmentWeek=originalRecruitment');}
 assert.ok(h.run('!!marketSnapshot'),'la fenêtre réelle de la semaine13 est observée');
 return h.run('recruitmentCount');
}
const count=recruitmentWindow(t);
assert.ok(count>=0&&count<=run('S.clubs.length*2'));
assert.equal(run('aiRosterRecruitmentWeek()'),0,'same window idempotent');
assert.equal(run('S.economy.aiRecruitmentWindow'),'1:13');
assert.equal(run('club().cash'),run('marketSnapshot.cash'),'no human club cash mutation');
assert.equal(run('S.clubs.every(c=>new Set(c.players.map(p=>p.id)).size===c.players.length)'),true,'no duplicate roster player');
assert.equal(run('new Set(S.clubs.flatMap(c=>c.players.map(p=>p.id))).size===S.clubs.reduce((s,c)=>s+c.players.length,0)'),true,'exclusive player ownership');
// bought est un sous-ensemble de recruited : execute() enregistre les deux.
assert.equal(run('S.aiRoster.reports.every(r=>(r.bought||0)<=r.recruited)'),true,'les achats sont inclus une seule fois dans les recrutements');
assert.equal(run('S.aiRoster.reports.reduce((sum,r)=>sum+r.recruited,0)-marketSnapshot.reports+S.clubDirections.loans.length-marketSnapshot.loans'),count,'libres + achats (inclus dans recruited) + prêts totalisent exactement les mouvements');
assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'),'save roundtrip');
const historic=context();
historic.run('start(0);delete S.aiRosterVersion;delete S.aiRoster');
assert.equal(historic.run('aiRosterRecruitmentWeek()'),0,'legacy saves unchanged');
const poor=context(),p=poor.run;
p('start(0)');
assert.equal(recruitmentWindow(poor,'for(const c of S.clubs){if(c.id!==S.club){c.cash=0;worldClub(c.id).debt=2000000}}'),0,'insolvent clubs excluded');
assert.equal(p('aiRosterRecruitmentWeek()'),0,'insolvent window remains idempotent');
assert.ok(p('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));

const depth=context(),d=depth.run;
d('start(0);var buyer,graduate,cashBefore,feesBefore,depthBefore,formationBefore,formationCashBefore');
const depthCount=recruitmentWindow(depth,`
 buyer=S.clubs[1];
 for(const c of S.clubs)if(c.id!==buyer.id){c.cash=0;for(const p of c.players){p.joinedSeason=S.season;p.joinedRound=S.round;}}
 buyer.cash=8000000;worldClub(buyer.id).debt=0;
 buyer.players=buyer.players.filter(p=>p.pos!==POS[0]).slice(0,35);
 nativeProfessionalDepth.fill(S);
 graduate=academyPlayer(0,0,1,9999);
 graduate.age=22;
 S.market=[];S.economy.freeAgents=[];
 if(!aiRosterGraduateAcademyPlayer(graduate,0))throw Error('Diplômé indisponible');
 depthBefore=buyer.players.length;cashBefore=buyer.cash;feesBefore=graduate.price;formationBefore=nativeSystems.domain('formationFees').due(S,graduate,buyer.id);formationCashBefore=S.clubs[0].cash;`);
assert.equal(d('depthBefore'),40,'native depth reaches the floor before recruitment');
assert.equal(d('S.aiRoster.reports.find(r=>r.clubId===buyer.id).bought||0'),0,'la fixture n’offre aucun joueur sous contrat à la vente');
assert.equal(depthCount,1,'a public prospect remains recruitable after the floor');
assert.equal(d('buyer.players.length'),41);
assert.equal(d('formationBefore'),d('Math.round(90000*(1+Math.max(0,Math.round(graduate.dev.potential)-70)/15)/5000)*5000'),'barème de formation natif sans contrat Espoir');
assert.equal(d('marketAfter.buyerCash'),d('cashBefore-feesBefore-formationBefore'),'prime et indemnité de formation débitées exactement');
assert.equal(d('marketAfter.cash'),d('formationCashBefore+formationBefore'),'le club formateur reçoit exactement son indemnité');
assert.equal(d('marketAfter.buyerCash+marketAfter.cash'),d('cashBefore+formationCashBefore-feesBefore'),'seule la prime de signature sort de la trésorerie cumulée');
assert.equal(d('S.formationFees.payments.filter(p=>p.playerId===graduate.id).length'),1,'une indemnité unique pour cette signature');
assert.equal(d('buyer.players.some(p=>p.id===graduate.id&&p.contractEnd===S.season+2)'),true);
assert.equal(d('S.economy.freeAgents.some(p=>p.id===graduate.id)'),false);
assert.equal(d('aiRosterRecruitmentWeek()'),0,'no duplicate recruitment in the same window');
console.log(JSON.stringify({passed:true,signings:count,checks:['deterministic auction','priority cash tie club id','ineligible window','market idempotence','exclusive ownership','cash protection','reports','save roundtrip','legacy opt-in','insolvent clubs']}));
