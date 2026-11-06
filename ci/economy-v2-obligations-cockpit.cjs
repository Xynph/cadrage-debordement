'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const E23=require('./economy-v2-cockpit-render.cjs');
function html(report){
 assert.equal(report.schema,1);assert.equal(report.version,'e24');assert.equal(report.source,'native-game-actual');
 assert.equal(report.series.length,15);
 assert.ok(report.series.every(s=>s.clubs.length===14&&s.clubs.every(c=>c.bookedPayable===null)));
 const original=E23.html(report);
 const extras=JSON.stringify(report.series.map(s=>({
   season:s.season,offersPending:s.offersPending,negotiationsPending:s.negotiationsPending,
   clubs:s.clubs.map(c=>({id:c.id,name:c.name,contractTermsObserved:c.contractTermsObserved,
    expiring:c.expiring,planning29Weeks:c.planning29Weeks,bookedPayable:c.bookedPayable,
    missingEnd:c.missingEnd}))
 }))).replace(/</g,'\\u003c');
 const section=`<section class="panel" id="commitments" aria-label="État des engagements du club" style="margin-top:14px">
 <h2>Engagements et prévisions — niveau de preuve</h2>
 <p class="sub">Contrats enregistrés ≠ factures échues. Prévisions sur 29 semaines, sans dette inventée.</p>
 <div class="metrics" style="margin:12px 0">
 <div class="metric"><small>Contrats aux termes connus</small><strong id="knownTerms">—</strong></div>
 <div class="metric"><small>Échéances cette saison</small><strong id="termsDue">—</strong></div>
 <div class="metric"><small>Budget théorique 29 semaines</small><strong id="budgetEstimate">—</strong></div>
 <div class="metric"><small>Dettes contractuelles comptabilisées</small><strong id="payables">Non disponible</strong></div>
 </div>
 <div class="note" id="provenance">Taux de paie et échéances : observés dans la carrière. Budget 29 semaines : simulation à salaire constant, pas une obligation certaine. Dettes fournisseurs : non mesurables dans le modèle legacy. Les offres et négociations ne valent pas signature.</div>
 <div class="scroll" style="max-height:220px;margin-top:12px">
 <table aria-label="Engagements observables et prévisions par saison"><thead><tr><th>Saison</th><th>Contrats</th><th>Échéances</th><th>Estimation 29 sem.</th><th>Passif connu</th></tr></thead><tbody id="obligationRows"></tbody></table>
 </div>
 </section>`;
 const script=`<script>
 const obligationsData=${extras};
 function renderObligations(){
  const clubId=Number(document.getElementById('club').value);
  const rows=obligationsData.map(x=>({season:x.season,...x.clubs.find(c=>c.id===clubId)}));
  const last=rows.at(-1);if(!last)return;
  document.getElementById('knownTerms').textContent=String(last.contractTermsObserved);
  document.getElementById('termsDue').textContent=String(last.expiring);
  document.getElementById('budgetEstimate').textContent=fmt(last.planning29Weeks);
  document.getElementById('payables').textContent='Non disponible';
  document.getElementById('obligationRows').innerHTML=rows.map(x=>'<tr><td>'+x.season+'</td><td>'+x.contractTermsObserved+'</td><td>'+x.expiring+'</td><td>'+fmt(x.planning29Weeks)+'</td><td>Non disponible</td></tr>').join('');
 }
 document.getElementById('club').addEventListener('change',renderObligations);renderObligations();
</script>`;
 return original.replace('</main>',section+'</main>').replace('</body>',script+'</body>');
}
if(require.main===module){
 const [source,output='economy-v2-e24-cockpit.html']=process.argv.slice(2);
 if(!source)throw Error('Usage: node ci/economy-v2-obligations-cockpit.cjs report.json output.html');
 const report=JSON.parse(fs.readFileSync(source,'utf8'));
 fs.writeFileSync(output,html(report));
 console.log('E24 COCKPIT HTML '+output+' · '+report.series.length+' seasons · '+report.series[0].clubs.length+' clubs');
}
module.exports={html};
