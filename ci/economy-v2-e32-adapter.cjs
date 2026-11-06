'use strict';
// E3.2: native observed values only; no extrapolation into payable or investment schedules.
const assert=require('node:assert/strict'),E31=require('./economy-v2-e31-pc.cjs');
function adapt(report,initial){
 assert.equal(report.source,'native-game-actual');assert.equal(report.version,'e24');
 assert.equal(report.series.length,15);assert.equal(initial.clubs.length,14);
 const byId=new Map(initial.clubs.map(c=>[c.id,c]));assert.equal(byId.size,14);
 const ids=report.series[0].clubs.map(c=>c.id);assert.equal(new Set(ids).size,14);
 const clubs=ids.map(id=>{
  const b=byId.get(id);assert.ok(b&&Number.isInteger(b.facilities)&&b.facilities>=1&&b.facilities<=10);
  const years=report.series.map((s,i)=>{
   assert.equal(s.season,i+1);assert.equal(s.clubs.length,14);
   const c=s.clubs.find(x=>x.id===id);
   assert.ok(c&&Number.isFinite(c.cash)&&Number.isFinite(c.debt));
   assert.ok(Number.isSafeInteger(c.wageWeekly)&&c.wageWeekly>=0);
   assert.ok(Number.isSafeInteger(c.expiring)&&Number.isSafeInteger(c.contractTermsObserved));
   assert.equal(c.bookedPayable,null,'Unknown payable is not zero');
   return {season:s.season,cash:c.cash,debt:c.debt,wageWeekly:c.wageWeekly,
    expiring:c.expiring,contractTermsObserved:c.contractTermsObserved,missingEnd:c.missingEnd,
    planning29Weeks:c.planning29Weeks,duePayable:null,confirmedFutureIncome:null,
    optionalProjectCost:null,sportingImpact:null};
  });
  return {id,name:report.series[0].clubs.find(c=>c.id===id).name,initialFacilities:b.facilities,
   initialReputation:b.reputation,years,facilityTimeSeriesAvailable:false};
 });
 return {stage:'E3.2',schema:1,source:'native-E2.4-seasons-and-initial-native-state',
  profile:report.profile,seed:report.seed,clubs,readsOnly:true,gameplayChanged:false,
  unknown:{datedPayables:null,futureConfirmedRevenue:null,optionalProjectPrices:null,sportingEffects:null}};
}
function render(observation,advisory){
 assert.equal(observation.stage,'E3.2');assert.equal(observation.readsOnly,true);
 assert.equal(observation.clubs.length,14);assert.equal(observation.unknown.datedPayables,null);
 const base=E31.render(advisory);
 const data=JSON.stringify(observation.clubs).replace(/</g,'\\u003c').replace(/>/g,'\\u003e').replace(/&/g,'\\u0026');
 const section=[
 '<section id="e32-native" class="card" aria-label="Observations natives par club" style="margin-top:14px">',
 '<div class="eyebrow">E3.2 · DONNÉES NATIVES · LECTURE SEULE</div><h2>Finances de 14 clubs sur 15 saisons</h2>',
 '<p class="muted small">Données de la carrière réellement simulée. Installations relevées à la création uniquement, sans supposer un investissement ou son coût.</p>',
 '<label for="nativeClub">Club observé</label><select id="nativeClub" aria-label="Club observé"></select>',
 '<div class="grid" style="margin-top:12px">',
 '<div class="card"><div class="eyebrow">Trésorerie S15</div><div class="metric" id="nativeCash"></div></div>',
 '<div class="card"><div class="eyebrow">Dette enregistrée S15</div><div class="metric" id="nativeDebt"></div></div>',
 '<div class="card"><div class="eyebrow">Salaires hebdomadaires S15</div><div class="metric" id="nativeWage"></div></div>',
 '<div class="card"><div class="eyebrow">Installations au départ (1–10)</div><div class="metric" id="nativeFacilities"></div></div></div>',
 '<div style="overflow:auto;max-height:240px;margin-top:12px"><table style="width:100%;font-size:12px;border-collapse:collapse" aria-label="Historique natif sur quinze saisons">',
 '<thead><tr><th>Saison</th><th>Trésorerie observée</th><th>Dette observée</th><th>Paie/semaine</th><th>Contrats expirants</th></tr></thead><tbody id="nativeRows"></tbody></table></div>',
 '<div class="note" role="note">Non disponibles : factures exigibles datées, recettes futures confirmées, coûts des projets facultatifs et effets sportifs mesurés. Les salaires ×29 semaines ne constituent pas une dette. Les scénarios ci-dessous restent entièrement synthétiques.</div></section>'
 ].join('');
 const script=[
 '<script id="e32-data" type="application/json">'+data+'</script>',
 '<script>(()=>{\'use strict\';',
 'const clubs=JSON.parse(document.getElementById("e32-data").textContent);',
 'const picker=document.getElementById("nativeClub"), el=id=>document.getElementById(id);',
 'const fmt=n=>new Intl.NumberFormat("fr-FR",{maximumFractionDigits:0}).format(n)+" €";',
 'clubs.forEach((c,i)=>{const o=document.createElement("option");o.value=String(i);o.textContent=c.name;picker.append(o)});',
 'function update(){const c=clubs[Number(picker.value)],s=c.years.at(-1);',
 'el("nativeCash").textContent=fmt(s.cash);el("nativeDebt").textContent=fmt(s.debt);',
 'el("nativeWage").textContent=fmt(s.wageWeekly);el("nativeFacilities").textContent=String(c.initialFacilities);',
 'const body=el("nativeRows");body.replaceChildren();c.years.forEach(y=>{const tr=document.createElement("tr");',
 '[y.season,fmt(y.cash),fmt(y.debt),fmt(y.wageWeekly),y.expiring].forEach(value=>{',
 'const td=document.createElement("td");td.textContent=String(value);td.style.padding="5px 10px";',
 'td.style.borderBottom="1px solid #345";tr.append(td)});body.append(tr)})}',
 'picker.addEventListener("change",update);update()',
 '})();</script>'
 ].join('');
 assert.ok(base.includes('<main>')&&base.includes('</body>'));
 return base.replace('<main>',section+'<main>').replace('</body>',script+'</body>')
  .replace('Décisions de redressement · E3.1</h1>','Observations natives et décisions consultatives · E3.2</h1>');
}
module.exports={adapt,render};
