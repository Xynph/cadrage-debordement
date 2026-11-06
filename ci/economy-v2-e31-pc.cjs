'use strict';
// E3.1 R&D: standalone read-only HTML report. Never loaded by dist or by the economy engine.
const assert=require('node:assert/strict');
const escape=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function validate(r){
 assert.equal(r.stage,'E3.1');
 assert.equal(r.observation.source,'native-E2.9-read-only');
 assert.equal(r.observation.seasons,15);
 assert.equal(r.observation.saveParity,true);
 assert.ok(Number.isInteger(r.observation.pressure)&&r.observation.pressure>=0);
 assert.ok(Number.isInteger(r.observation.recovery)&&r.observation.recovery>=0);
 for(const [name,v] of Object.entries(r.cases)){
  assert.match(name,/^[a-zA-Z]+$/);
  assert.equal(v.summary!==undefined,true);
  assert.equal(v.options.length,3);
  for(const o of v.options){
   assert.equal(o.forecastOnly,true);
   assert.equal(o.createdDebt,0);
   assert.equal(o.generatedLoans,0);
   assert.equal(o.generatedIncome,0);
   assert.equal(o.addedPenalties,0);
   assert.ok(o.weekly.every(w=>Number.isSafeInteger(w.closingCash)));
  }
 }
 return r;
}
function render(report){
 const r=validate(report);
 const cases=Object.entries(r.cases).map(([key,c])=>({id:key,label:({
  temporaryRevenueDip:'Baisse temporaire des recettes',
  optionalInvestmentOverreach:'Surinvestissement facultatif',
  mandatoryCostsUncovered:'Charges dues non couvertes',
  laterEarnedIncome:'Revenus futurs déjà indiqués'
 })[key]||key,options:c.options,summary:c.summary}));
 const payload=JSON.stringify(cases).replace(/</g,'\\u003c').replace(/>/g,'\\u003e').replace(/&/g,'\\u0026');
 const ob=r.observation;
 return `<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
 <title>Économie V2 · Laboratoire consultatif E3.1</title>
 <style>
 :root{color-scheme:dark;font-family:system-ui,Segoe UI,Arial,sans-serif;background:#0b1521;color:#edf2f9}
 *{box-sizing:border-box}body{margin:0}.wrap{max-width:1540px;margin:auto;padding:18px 24px}
 header{display:flex;align-items:center;justify-content:space-between;gap:18px;border-bottom:1px solid #354354;padding-bottom:12px}
 h1{font-size:25px;margin:0}h2{font-size:18px;margin:0 0 10px}h3{font-size:15px;margin:0 0 6px}
 .eyebrow{color:#9ab4cb;font-size:12px;letter-spacing:.09em;text-transform:uppercase}.muted{color:#adbbcc}.small{font-size:12px}
 .pill{display:inline-block;padding:5px 9px;background:#26394a;border-radius:20px;color:#d2e4fa;font-size:12px}
 .grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}.card{background:#162538;border:1px solid #304356;border-radius:12px;padding:16px;min-width:0}
 .number{font-size:26px;font-weight:700;font-variant-numeric:tabular-nums;margin:7px 0}
 main{display:grid;grid-template-columns:minmax(235px,0.9fr) minmax(0,2.1fr);gap:14px;margin-top:14px}
 .options{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;margin-top:12px}
 button,select{font:inherit;cursor:pointer;color:inherit}select{width:100%;background:#23384d;border:1px solid #55718b;border-radius:8px;padding:10px}
 button{width:100%;background:#203349;border:1px solid #4b637c;border-radius:10px;padding:13px;text-align:left}
 button[aria-pressed=true]{outline:2px solid #6dd4ad;background:#214641}
 .metric{font-size:22px;font-weight:700;font-variant-numeric:tabular-nums}.danger{color:#ffb6a6}.good{color:#85e3bd}
 .note{padding:10px 12px;border-left:3px solid #e4ba6b;background:#2a2c30;margin-top:12px;font-size:13px}
 .lines{display:grid;grid-template-columns:repeat(2,1fr);gap:8px;margin-top:10px}
 .line{display:flex;justify-content:space-between;gap:10px;padding:8px 0;border-bottom:1px solid #34485d}
 .chart{margin-top:12px;display:flex;align-items:end;gap:5px;height:100px;border-bottom:1px solid #8191a0;padding:4px}
 .bar{flex:1;min-width:8px;background:#71a9d9;min-height:2px;position:relative}.bar.neg{background:#f08e86}
 .legend{display:flex;justify-content:space-between;margin-top:8px;font-size:11px;color:#abc2d7}
 footer{margin-top:14px;color:#aabdd0;font-size:12px}
 @media(max-width:1050px){.grid{grid-template-columns:repeat(2,1fr)}main{grid-template-columns:1fr}}
 @media(max-width:620px){.wrap{padding:12px}.grid,.options,.lines{grid-template-columns:1fr}header{display:block}}
 </style></head><body><div class="wrap">
 <header><div><div class="eyebrow">CADRAGE DÉBORDEMENT / ÉCONOMIE V2</div><h1>Décisions de redressement · E3.1</h1></div><span class="pill">PROTOTYPE R&D · LECTURE SEULE</span></header>
 <p class="muted small">Séparation stricte : observations authentiques du moteur sur 15 saisons ci-dessous ; choix comparés sur des scénarios de test synthétiques, non raccordés au gameplay.</p>
 <section class="grid" aria-label="Observations du moteur">
 <div class="card"><div class="eyebrow">Saisons du moteur</div><div class="number">${ob.seasons}</div><span class="muted small">Campagne ${escape(r.profile)} · graine ${escape(r.seed)}</span></div>
 <div class="card"><div class="eyebrow">Tours simulés</div><div class="number">${ob.rounds}</div><span class="muted small">Exécution native, sans choix E3.1</span></div>
 <div class="card"><div class="eyebrow">Pressions indicatives</div><div class="number">${ob.pressure}</div><span class="muted small">Seuil comparatif de planification, pas une dette</span></div>
 <div class="card"><div class="eyebrow">Sorties de pression observées</div><div class="number">${ob.recovery}</div><span class="muted small">Transitions observées, pas une preuve de redressement causé</span></div>
 </section>
 <main><section class="card"><h2>Situation à examiner</h2><label for="case">Scénario pédagogique (unités abstraites)</label><select id="case"></select>
 <div class="note" id="risk" role="status"></div><p class="muted small">Ce comparateur n'émet aucun prêt, ne reporte aucune facture obligatoire et ne modifie aucune sauvegarde.</p>
 <h3>Conséquence sportive</h3><p id="sport" class="muted"></p><h3>Définition du choix</h3><p id="trade" class="muted"></p></section>
 <section class="card"><h2>Avant / après · horizon du scénario</h2><p class="muted small">« Avant » = maintenir les projets facultatifs. « Après » = option sélectionnée. Toutes les échéances obligatoires restent inchangées.</p>
 <div class="options" id="choices" role="group" aria-label="Options de redressement"></div>
 <div class="lines"><div class="line"><span>Trésorerie finale avant</span><strong id="before"></strong></div><div class="line"><span>Trésorerie finale après</span><strong id="after"></strong></div>
 <div class="line"><span>Écart de trésorerie</span><strong id="delta"></strong></div><div class="line"><span>Projets facultatifs différés</span><strong id="deferred"></strong></div>
 <div class="line"><span>Semaines de solde négatif</span><strong id="negative"></strong></div><div class="line"><span>Semaines à risque sur charges dues</span><strong id="mandatory"></strong></div></div>
 <h3 style="margin-top:14px">Trésorerie de fin de période · après</h3><div class="chart" id="chart" role="img" aria-label="Soldes prévisionnels par semaine"></div>
 <div class="legend"><span>Première période</span><span>Dernière période</span></div></section></main>
 <footer>Source : moteur natif E2.9 + simulateur isolé E3.0. Scénarios entièrement synthétiques. Effets sportifs qualitatifs uniquement : aucune performance chiffrée n'est calculée. La parité des sauvegardes est vérifiée par la campagne, pas par cet écran.</footer></div>
 <script id="data" type="application/json">${payload}</script>
 <script>
 (()=>{'use strict';
 const cases=JSON.parse(document.getElementById('data').textContent),byId=id=>document.getElementById(id);
 let selected=0,mode=0;
 const sport=['Les projets sportifs prévus restent au calendrier, mais le risque de tension de trésorerie augmente.',
 'Certains projets restent en attente : amélioration sportive potentiellement plus lente, sans malus chiffré inventé.',
 'Les projets facultatifs sont suspendus : la trésorerie est préservée, les améliorations sont reportées.'];
 const form=byId('case');cases.forEach((c,i)=>{const x=document.createElement('option');x.value=i;x.textContent=c.label;form.append(x)});
 const fmt=v=>(v>0?'+':'')+v.toLocaleString('fr-FR');
 const plain=v=>v.toLocaleString('fr-FR');
 const render=()=>{
 const c=cases[selected],before=c.options[0],after=c.options[mode];
 byId('choices').replaceChildren();
 c.options.forEach((o,i)=>{const b=document.createElement('button');b.type='button';b.setAttribute('aria-pressed',String(i===mode));b.textContent=o.headline;b.addEventListener('click',()=>{mode=i;render()});byId('choices').append(b)});
 byId('risk').textContent=c.summary.optionalChangesInsufficientForMandatoryBills?'Alerte : les dépenses facultatives ne suffisent pas à couvrir toutes les charges exigibles. Aucune solution magique.':'Arbitrage possible sur des achats facultatifs, sans déplacer les charges exigibles.';
 byId('sport').textContent=sport[mode];byId('trade').textContent=after.tradeoff;
 byId('before').textContent=plain(before.endingCash);
 byId('after').textContent=plain(after.endingCash);
 byId('delta').textContent=fmt(after.endingCash-before.endingCash);
 byId('deferred').textContent=plain(after.optionalDeferred);
 byId('negative').textContent=plain(after.negativeWeeks);
 byId('mandatory').textContent=plain(after.requiredCoverageRiskWeeks);
 const chart=byId('chart');chart.replaceChildren();
 const vals=after.weekly.map(w=>w.closingCash),abs=Math.max(1,...vals.map(Math.abs));
 vals.forEach((v,i)=>{const bar=document.createElement('div');bar.className='bar'+(v<0?' neg':'');bar.style.height=(Math.abs(v)/abs*94+2)+'%';bar.title='Période '+(i+1)+' : '+plain(v);chart.append(bar)});
 chart.setAttribute('aria-label',vals.map((v,i)=>'Période '+(i+1)+' : '+plain(v)).join('; '));
 };
 form.addEventListener('change',()=>{selected=Number(form.value);mode=0;render()});render();
 })();
 </script></body></html>`;
}
module.exports={render,validate};
