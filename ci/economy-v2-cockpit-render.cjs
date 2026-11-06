'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
function html(report){
 assert.equal(report.schema,1);assert.equal(report.source,'native-game-actual');assert.equal(report.series.length,15);
 const payload=JSON.stringify({profile:report.profile,seed:report.seed,series:report.series,limits:report.limits}).replace(/</g,'\\u003c');
 return `<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Économie V2 — Cockpit consultatif R&D</title>
<style>
:root{color-scheme:dark;font-family:Inter,system-ui,-apple-system,Segoe UI,sans-serif}
*{box-sizing:border-box}body{margin:0;background:#0c1220;color:#f0f5ff}
main{width:min(100%,1600px);margin:auto;padding:24px 28px}
h1{font-size:27px;margin:7px 0 5px;letter-spacing:-.6px}.eyebrow{font-size:11px;color:#73b9e4;text-transform:uppercase;letter-spacing:2px;font-weight:700}
p{color:#a3b2c8;font-size:13px;margin:8px 0 15px}
.controls{display:flex;align-items:center;justify-content:space-between;gap:16px;margin:18px 0}
select{background:#19273c;border:1px solid #34475f;color:#effaff;padding:9px 14px;border-radius:8px;min-width:240px;font-size:14px}
.metrics{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:14px}
.metric,.panel{background:#152136;border:1px solid #263a55;border-radius:12px;padding:16px}
.metric small{display:block;color:#9eb4cc;font-size:11px;font-weight:600;margin-bottom:8px}.metric strong{display:block;font-size:21px;font-variant-numeric:tabular-nums}
.panels{display:grid;grid-template-columns:minmax(0,1.35fr) minmax(0,1fr);gap:14px;margin-top:14px}
.panel h2{font-size:15px;margin:0 0 3px}.panel .sub{font-size:12px;color:#9cb0c9;margin-bottom:9px}
svg{display:block;width:100%;height:240px;overflow:visible}.axis{stroke:#354660;stroke-width:1}.cash{fill:none;stroke:#5fd3bd;stroke-width:3;stroke-linejoin:round}.debt{fill:none;stroke:#ffbf72;stroke-width:3;stroke-linejoin:round}
.legend{display:flex;gap:14px;font-size:12px;color:#b9cadc}.dot{display:inline-block;width:9px;height:9px;border-radius:50%;margin-right:5px;background:#5fd3bd}.dot.orange{background:#ffbf72}
.scroll{overflow:auto;max-height:285px}table{width:100%;border-collapse:collapse;font-size:12px;font-variant-numeric:tabular-nums}th,td{text-align:right;padding:9px 7px;border-bottom:1px solid #2a3850;white-space:nowrap}th:first-child,td:first-child{text-align:left}th{position:sticky;top:0;background:#152136;color:#9db4ce}
.note{margin-top:14px;padding:12px 15px;border-left:3px solid #ffbf72;background:#172438;font-size:12px;color:#b9c8dd}
@media(max-width:900px){main{padding:14px}.panels{grid-template-columns:1fr}.metrics{grid-template-columns:repeat(2,minmax(0,1fr))}}
</style></head><body><main>
<div class="eyebrow">Cadrage Débordement / R&D • Données natives</div><h1>Finances — Tableau de bord consultatif</h1>
<p>Carrière simulée réelle du moteur fictif · 15 saisons · lecture seule · aucune projection inventée</p>
<div class="controls"><label for="club">Club observé <select id="club" aria-label="Choisir le club"></select></label>
<span id="meta" class="eyebrow"></span></div>
<section class="metrics" aria-label="Indicateurs financiers">
<div class="metric"><small>Trésorerie dernière saison</small><strong id="cashKpi"></strong></div>
<div class="metric"><small>Dette dernière saison</small><strong id="debtKpi"></strong></div>
<div class="metric"><small>Salaires hebdomadaires</small><strong id="wageKpi"></strong></div>
<div class="metric"><small>Contrats expirant cette saison</small><strong id="contractKpi"></strong></div>
</section>
<section class="panels">
<div class="panel"><h2>Évolution sur 15 saisons</h2><div class="sub">Trésorerie et dette observées, en millions d'euros fictifs</div>
<svg id="history" role="img" aria-label="Graphique des soldes réels sur quinze saisons" viewBox="0 0 640 240" preserveAspectRatio="none"></svg>
<div class="legend"><span><span class="dot"></span>Trésorerie</span><span><span class="dot orange"></span>Dette</span></div></div>
<div class="panel"><h2>Historique financier</h2><div class="sub">Aucun montant mensuel extrapolé</div>
<div class="scroll"><table aria-label="Tableau des quinze saisons"><thead><tr><th>Saison</th><th>Cash</th><th>Dette</th><th>Paie/semaine</th></tr></thead><tbody id="rows"></tbody></table></div></div>
</section>
<div class="note" role="note">Limites : budgets de jeu fictifs, pas comptes certifiés. Les salaires sont des charges hebdomadaires observées, pas une dette comptabilisée. Les engagements contractuels futurs et comptes fournisseurs ne sont pas chiffrables de manière exhaustive avec le modèle legacy. Aucun actif, transfert ou revenu mensuel extrapolé.</div>
</main><script>
const data=${payload};
const fmt=n=>new Intl.NumberFormat('fr-FR',{maximumFractionDigits:0}).format(n)+' €';
const millions=n=>n/1e6;
const clubs=data.series[0].clubs;
const picker=document.getElementById('club');
clubs.forEach(c=>{const o=document.createElement('option');o.value=String(c.id);o.textContent=c.name;picker.append(o)});
document.getElementById('meta').textContent=data.profile+' · graine '+data.seed;
function render(){
 const id=Number(picker.value),series=data.series.map(s=>({season:s.season,...s.clubs.find(c=>c.id===id)}));
 const last=series.at(-1);if(!last)return;
 document.getElementById('cashKpi').textContent=fmt(last.cash);
 document.getElementById('debtKpi').textContent=fmt(last.debt);
 document.getElementById('wageKpi').textContent=fmt(last.wageWeekly);
 document.getElementById('contractKpi').textContent=String(last.expiring);
 document.getElementById('rows').innerHTML=series.map(s=>'<tr><td>'+s.season+'</td><td>'+fmt(s.cash)+'</td><td>'+fmt(s.debt)+'</td><td>'+fmt(s.wageWeekly)+'</td></tr>').join('');
 const all=series.flatMap(s=>[millions(s.cash),millions(s.debt)]),min=Math.min(0,...all),max=Math.max(1,...all),span=max-min||1;
 const px=i=>36+i*(582/14),py=v=>210-(millions(v)-min)*180/span;
 const line=(key,cls)=>'<polyline class="'+cls+'" points="'+series.map((s,i)=>px(i)+','+py(s[key])).join(' ')+'"/>';
 const grid=[0,1,2,3,4].map(i=>{const y=30+i*45;return '<line class="axis" x1="34" y1="'+y+'" x2="624" y2="'+y+'"/>'}).join('');
 document.getElementById('history').innerHTML=grid+line('cash','cash')+line('debt','debt')+
 '<text x="35" y="235" fill="#a7bad0" font-size="12">S1</text><text x="590" y="235" fill="#a7bad0" font-size="12">S15</text>';
}
picker.addEventListener('change',render);render();
</script></body></html>`;
}
if(require.main===module){
 const [input,output='economy-v2-e23-cockpit.html']=process.argv.slice(2);
 if(!input)throw Error('Usage: node ci/economy-v2-cockpit-render.cjs native-report.json [output.html]');
 const report=JSON.parse(fs.readFileSync(input,'utf8'));
 fs.writeFileSync(output,html(report));console.log('COCKPIT HTML '+output+' : '+report.series.length+' native seasons');
}
module.exports={html};
