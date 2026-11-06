'use strict';
// Issue #365 — presentation only. Native game functions remain the sole economic authority.
(function(root,factory){
 const api=factory();
 if(typeof module!=='undefined'&&module.exports)module.exports=api;
 if(root)root.CDFinanceV2=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
 const escape=s=>String(s??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
 const euros=n=>Number.isFinite(n)?Math.round(n).toLocaleString('fr-FR')+' €':'Indisponible';
 let viewFilter='all';
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
   ledger:ledger.slice(0,100).map(e=>({title:String(e.title??''),amount:e.amount})),
   income:ledger.filter(e=>Number.isFinite(e.amount)&&e.amount>0).reduce((s,e)=>s+e.amount,0),
   expenses:ledger.filter(e=>Number.isFinite(e.amount)&&e.amount<0).reduce((s,e)=>s-e.amount,0),
   activeAcademy,activeWorld,academyAllowed,facilityAllowed,facilityCost,
   academyInvestment:activeAcademy?management.academyInvestment:null,
   academySpent:activeAcademy?management.academySpent:null,
   academyWeeks:activeAcademy?management.academyWeeks:null,
   level:info?.facilities??null,upgraded,canAct};
 }

 // All visuals derive exclusively from the bounded native journal; never write to S.
 function series(v){
  const chronological=v.ledger.slice().reverse().filter(e=>Number.isFinite(e.amount));
  let cash=v.cash-chronological.reduce((s,e)=>s+e.amount,0);
  return [{cash,label:'Avant la première écriture conservée'},...chronological.map((e,i)=>({cash:cash+=e.amount,label:e.title,amount:e.amount,index:i+1}))];
 }
 function graph(v){
  const pts=series(v),values=pts.map(p=>p.cash),min=Math.min(...values),max=Math.max(...values);
  const range=Math.max(1,max-min),w=700,h=186,pad=24;
  const xy=(n,i)=>[pad+i*(w-pad*2)/Math.max(1,pts.length-1),h-pad-(n-min)/range*(h-pad*2)];
  const path=pts.map((p,i)=>{const [x,y]=xy(p.cash,i);return (i?'L':'M')+x.toFixed(1)+' '+y.toFixed(1)}).join(' ');
  const marks=pts.map((p,i)=>{const [x,y]=xy(p.cash,i);
   const detail=p.index?'Écriture '+p.index+' : '+p.label+' ; mouvement '+euros(p.amount):p.label;
   return '<circle class="finv2-point" cx="'+x.toFixed(1)+'" cy="'+y.toFixed(1)+'" r="5" tabindex="0" role="img" aria-label="'+escape(detail+' ; solde '+euros(p.cash))+'"><title>'+escape(detail+' ; trésorerie reconstituée '+euros(p.cash))+'</title></circle>';
  }).join('');
  const income=v.income,expense=v.expenses,sum=income+expense;
  const bars=[{name:'Encaissements',value:income,klass:'in'},{name:'Décaissements',value:expense,klass:'out'}].map(item=>
   '<div class="finv2-barrow"><span>'+item.name+'</span><div class="finv2-bartrack"><button type="button" class="finv2-bar '+item.klass+'" style="width:'+Math.max(item.value?3:0,Math.round(item.value/Math.max(income,expense,1)*100))+'%" title="'+escape(item.name+' du journal conservé : '+euros(item.value))+'" aria-label="'+escape(item.name+' : '+euros(item.value))+'" onclick="CDFinanceV2.setFilter(\''+(item.klass==='in'?'income':'expense')+'\')"></button></div><strong>'+euros(item.value)+'</strong></div>').join('');
  return '<div class="finv2-charts"><div class="finv2-panel"><div class="finv2-sectionhead"><div><h3>Trajectoire de trésorerie</h3><small>Solde recalculé après chaque écriture conservée</small></div><span class="finv2-chip">'+pts.length+' points</span></div>'+
   '<svg class="finv2-curve" viewBox="0 0 700 186" role="img" aria-label="Évolution de trésorerie reconstituée depuis le journal conservé">'+
   '<line class="finv2-axis" x1="24" y1="162" x2="676" y2="162"/><line class="finv2-axis" x1="24" y1="24" x2="24" y2="162"/>'+
   '<path class="finv2-path" d="'+path+'"/>'+marks+'</svg>'+
   '<div class="finv2-chartfoot"><span>Début de la fenêtre : '+euros(pts[0].cash)+'</span><strong>Actuel : '+euros(v.cash)+'</strong></div>'+
   '<p class="help">Survolez ou sélectionnez les points pour lire les montants et les libellés. La fenêtre est limitée aux dernières écritures conservées : ce tracé ne représente pas toute la saison.</p></div>'+
   '<div class="finv2-panel"><div class="finv2-sectionhead"><div><h3>Entrées et sorties</h3><small>Répartition des montants réellement enregistrés</small></div><span class="finv2-chip">'+v.ledger.length+' lignes</span></div>'+bars+
   '<p class="help">Cliquez sur une barre pour filtrer les opérations correspondantes. Les valeurs ne comprennent pas d’événements absents du journal.</p></div></div>';
 }
 function journal(v){
  const items=v.ledger.filter(e=>viewFilter==='income'?Number.isFinite(e.amount)&&e.amount>0:viewFilter==='expense'?Number.isFinite(e.amount)&&e.amount<0:true);
  const btn=(id,label)=>'<button type="button" class="finv2-filter" aria-pressed="'+(viewFilter===id)+'" onclick="CDFinanceV2.setFilter(\''+id+'\')">'+label+'</button>';
  return '<div class="finv2-panel finv2-journal"><div class="finv2-sectionhead"><div><h3>Journal interactif</h3><small>Historique natif conservé · plus récent en premier</small></div><span class="finv2-chip">'+items.length+' / '+v.ledger.length+' lignes</span></div>'+
   '<div class="finv2-filters" role="group" aria-label="Filtrer les écritures">'+btn('all','Toutes')+btn('income','Recettes')+btn('expense','Dépenses')+'</div>'+
   '<div class="finv2-tablewrap" role="region" aria-label="Tableau des opérations financières" tabindex="0"><table class="finv2-table"><thead><tr><th scope="col">#</th><th scope="col">Opération</th><th scope="col">Sens</th><th scope="col">Montant</th></tr></thead><tbody>'+
   (items.length?items.map((e,i)=>'<tr title="'+escape(e.title+' : '+euros(e.amount))+'"><td>'+(v.ledger.indexOf(e)+1)+'</td><td>'+escape(e.title)+'</td><td><span class="finv2-sign '+(e.amount>=0?'positive':'negative')+'">'+(e.amount>=0?'Entrée':'Sortie')+'</span></td><td class="finv2-amount">'+euros(e.amount)+'</td></tr>').join(''):'<tr><td colspan="4">Aucune opération dans ce filtre.</td></tr>')+'</tbody></table></div>'+
   '<p class="help">Les lignes ne portent pas toutes une date native fiable : numérotation de la plus récente à la plus ancienne, sans date inventée.</p></div>';
 }
 function setFilter(value){
  if(!['all','income','expense'].includes(value))return false;
  viewFilter=value;
  if(typeof document!=='undefined'&&typeof S!=='undefined'){
   const host=document.querySelector('.finance-v2-native');
   if(host&&S)host.outerHTML=html(S);
  }
  return true;
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
   graph(v)+journal(v)+
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
 return Object.freeze({snapshot,html,series,graph,journal,setFilter});
});
