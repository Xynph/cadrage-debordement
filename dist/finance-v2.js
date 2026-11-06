'use strict';
// Issue #365 — presentation only. Native game functions remain the sole economic authority.
(function(root,factory){
 const api=factory();
 if(typeof module!=='undefined'&&module.exports)module.exports=api;
 if(root)root.CDFinanceV2=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
 const escape=s=>String(s??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
 const euros=n=>Number.isFinite(n)?Math.round(n).toLocaleString('fr-FR')+' €':'Indisponible';
 function snapshot(state){
  if(!state||!Array.isArray(state.clubs)||!state.clubs[state.club])return null;
  const c=state.clubs[state.club],management=state.careerManagement,world=state.worldManagement;
  const activeAcademy=state.integratedManagementVersion===1&&management?.version===1;
  const activeWorld=state.worldVersion===1&&world?.version===1;
  const info=activeWorld?world.clubInfo?.[state.club]:null;
  const upgrades=activeWorld?world.upgrades||[]:[];
  const upgraded=upgrades.some(x=>x.season===state.season&&x.id===state.club);
  const facilityCost=info&&info.facilities<10?450000+info.facilities*150000:null;
  const canAct=!state.live&&state.phase==='league'&&!state.trained;
  const facilityAllowed=Boolean(canAct&&info&&facilityCost!==null&&!upgraded&&c.cash>=facilityCost+500000);
  const academyAllowed=Boolean(canAct&&activeAcademy);
  const ledger=Array.isArray(state.ledger)?state.ledger:[];
  return {cash:c.cash,wages:Array.isArray(c.players)?c.players.reduce((sum,p)=>sum+(Number.isFinite(p.salary)?p.salary:0),0):null,
   ledger:ledger.slice(0,12).map(e=>({title:String(e.title??''),amount:e.amount})),
   income:ledger.filter(e=>Number.isFinite(e.amount)&&e.amount>0).reduce((s,e)=>s+e.amount,0),
   expenses:ledger.filter(e=>Number.isFinite(e.amount)&&e.amount<0).reduce((s,e)=>s-e.amount,0),
   activeAcademy,activeWorld,academyAllowed,facilityAllowed,facilityCost,
   academyInvestment:activeAcademy?management.academyInvestment:null,
   academySpent:activeAcademy?management.academySpent:null,
   academyWeeks:activeAcademy?management.academyWeeks:null,
   level:info?.facilities??null,upgraded,canAct};
 }
 function html(state){
  const v=snapshot(state);
  if(!v)return '<section class="card"><h2>Finances V2</h2><p>Aucune carrière chargée.</p></section>';
  const rows=v.ledger.map(e=>'<div class="row budgetline"><span>'+escape(e.title)+'</span><strong>'+euros(e.amount)+'</strong></div>').join('');
  const academy=v.activeAcademy?
   '<div class="row"><span>Formation sélectionnée : <strong>'+euros(v.academyInvestment)+'/semaine financée</strong></span></div>'+
   '<p class="help">Débit uniquement lors d’une séance effectivement financée. Total saison payé : '+euros(v.academySpent)+
   ' sur '+v.academyWeeks+' séance(s).</p>'+
   '<div class="row">'+[0,4000,12000].map(n=>'<button class="small '+(v.academyInvestment===n?'dark':'')+
   '" onclick="careerSetAcademyInvestment('+n+')" '+(!v.academyAllowed?'disabled':'')+
   ' aria-label="Choisir formation '+euros(n)+'">'+(v.academyInvestment===n?'✓ ':'')+euros(n)+'/sem.</button>').join('')+'</div>':
   '<p class="help">Gestion intégrée non activée sur cette sauvegarde. Activez-la ci-dessous pour choisir un budget de formation.</p>'+
   '<button class="small" onclick="careerEnable()" '+(!v.canAct?'disabled':'')+'>Activer la gestion intégrée</button>';
  const facility=v.activeWorld?
   '<p>Installations niveau <strong>'+v.level+'/10</strong>. '+(v.facilityCost===null?'Niveau maximal atteint.':'Coût immédiat du prochain niveau : <strong>'+euros(v.facilityCost)+'</strong>. Réserve requise après achat : 500 000 €.')+'</p>'+
   '<button class="small dark" onclick="worldUpgradeFacility()" '+(!v.facilityAllowed?'disabled':'')+'>'+
   (v.upgraded?'Investissement déjà effectué cette saison':'Investir dans les installations')+'</button>':
   '<p class="help">Monde des clubs non activé sur cette sauvegarde.</p>'+
   '<button class="small" onclick="worldEnable()" '+(!v.canAct?'disabled':'')+'>Activer le monde des clubs</button>';
  return '<section class="card finance-v2-native" aria-label="Finances V2 — décisions natives">'+
   '<div class="cardtitle"><h2>Finances V2 · Décider avec les vrais chiffres du jeu</h2><span class="tag">CARRIÈRE ACTIVE</span></div>'+
   '<p class="help">Montants fictifs du jeu. Les recettes et dépenses ci-dessous proviennent du journal conservé (100 dernières écritures maximum) ; ce ne sont pas des résultats annuels exhaustifs. Aucun futur revenu, prêt ou dette n’est présumé.</p>'+
   '<div class="stats"><div class="card stat"><span class="eyebrow">Trésorerie actuelle</span><b>'+euros(v.cash)+'</b></div>'+
   '<div class="card stat"><span class="eyebrow">Salaires actuels par journée</span><b>'+euros(v.wages)+'</b></div>'+
   '<div class="card stat"><span class="eyebrow">Entrées du journal conservé</span><b>'+euros(v.income)+'</b></div>'+
   '<div class="card stat"><span class="eyebrow">Sorties du journal conservé</span><b>'+euros(v.expenses)+'</b></div></div>'+
   '<div class="grid"><div class="card"><h3>01 / Formation · choix réel</h3>'+academy+
   '<p class="help">La progression des jeunes est possible, jamais garantie en match. Le choix du budget ne débite pas immédiatement la trésorerie.</p></div>'+
   '<div class="card"><h3>02 / Installations · achat réel</h3>'+facility+
   '<p class="help">Un achat accepté débite immédiatement le club et ajoute l’entretien prévu par le moteur. Aucun gain de victoire n’est garanti.</p></div></div>'+
   '<div class="grid"><div class="card"><h3>Dernières opérations effectivement inscrites</h3>'+
   (rows||'<p class="help">Aucune écriture dans le journal conservé.</p>')+'</div>'+
   '<div class="card"><h3>Si votre trésorerie est tendue</h3><p>Vous pouvez réduire ou mettre à zéro la formation facultative avant la séance suivante, différer les travaux et consulter les contrats au Mercato. Cela ne supprime ni les salaires ni les engagements déjà réalisés.</p>'+
   '<p class="help">Dettes futures exigibles, recettes futures garanties : indisponibles sans preuve native. Les projections plus bas sont indicatives, non des promesses.</p>'+
   '<button class="small" onclick="nav(\'market\')">Consulter les contrats</button></div></div>'+
   '</section>';
 }
 return Object.freeze({snapshot,html});
});
