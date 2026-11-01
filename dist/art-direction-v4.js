/* Direction artistique V4 : projections de lecture et composition, sans écriture de carrière. */
(function(root,factory){'use strict';const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.CDArtDirection=api;})(typeof globalThis==='object'?globalThis:null,function(){
 'use strict';
 const families=['Piliers','Talonneurs','Deuxième ligne','Troisième ligne','Mêlée','Ouverture','Ailiers','Centres','Arrières'];
 const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const clone=v=>JSON.parse(JSON.stringify(v));
 const finite=v=>typeof v==='number'&&Number.isFinite(v);
 const num=v=>finite(v)?new Intl.NumberFormat('fr-FR',{maximumFractionDigits:0}).format(v):'—';
 const eur=v=>finite(v)?new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(v):'—';
 const compact=v=>finite(v)?new Intl.NumberFormat('fr-FR',{notation:'compact',maximumFractionDigits:1}).format(v):'—';
 function extent(values){const a=values.filter(finite);if(!a.length)return [0,1];const lo=Math.min(0,...a),hi=Math.max(0,...a);return lo===hi?[0,Math.max(1,hi)]:[lo,hi];}
 function ownPlayer(p){const q=clone(p);return {id:q.id,name:q.name,position:q.pos,family:q.fam,age:q.age,note:roleNote(q),potential:potentialAtRole(q),condition:q.condition,salary:q.salary,injury:q.injury||0,minutes:q.dev?.minutes||0,attributes:Object.fromEntries(Object.keys(ATTR).map(k=>[k,Math.round(skill(q,k))]))};}
 function snapshot(){
  if(typeof S==='undefined'||!S)return null;
  const c=clone(club()),squad=c.players.map(ownPlayer),academy=(S.development?.academy||[]).map(ownPlayer);
  const needs=typeof recruitmentNeeds==='function'&&S.development?recruitmentNeeds(c):[];
  const candidates=typeof managerPool==='function'&&S.economy?managerPool().map(p=>({id:p.id,name:p.name,position:p.pos,price:p.price,salary:p.salary,age:p.age,family:p.fam})):[];
  const budget=typeof careerBudgetModel==='function'?careerBudgetModel():{cash:c.cash,weeklyIncome:160000,weeklyWages:squad.reduce((s,p)=>s+(p.salary||0),0),weeks:Math.max(1,Math.min(12,29-S.round))};
  const projection=CDFinancePlanning.forecast(budget);
  const pair=typeof nextMatch==='function'?nextMatch():null,opponent=pair?S.clubs[pair.find(id=>id!==S.club)]:null;
  const table=ranked().map((t,i)=>({id:t.id,name:t.name,abbr:t.abbr,points:t.points,played:t.played,pf:t.pf,pa:t.pa,rank:i+1,mine:t.id===S.club}));
  const fixtures=(S.schedule||[]).slice(S.round,S.round+5).map((pairs,i)=>{const p=pairs.find(x=>x.includes(S.club));if(!p)return null;const o=S.clubs[p.find(id=>id!==S.club)];return {round:S.round+i+1,id:o.id,name:o.name,abbr:o.abbr,home:p[0]===S.club};}).filter(Boolean);
  const results=(S.history||[]).filter(x=>Array.isArray(x.pair)&&Array.isArray(x.score)&&x.pair.includes(S.club)).slice(-5).map(x=>{const i=x.pair.indexOf(S.club),own=x.score[i],against=x.score[1-i];return {label:x.phase==='league'?'J'+(x.round+1):'Finales',own,against,outcome:own>against?'V':own===against?'N':'D'};});
  const availability=[{label:'Disponibles',value:squad.filter(p=>!p.injury).length},{label:'Blessés',value:squad.filter(p=>p.injury>0).length}];
  return {club:{id:c.id,name:c.name,abbr:c.abbr,cash:c.cash,points:c.points,played:c.played},season:S.season,round:S.round,roundTitle:label(),competition:S.lnrMode?'TOP 14':'LIGUE PREMIÈRE',phase:S.phase,squad,academy,needs,candidates,availability,results,fixtures,standings:table,
   next:opponent?{opponent:{id:opponent.id,name:opponent.name,abbr:opponent.abbr},home:pair[0]===S.club,neutral:['semi','final'].includes(S.phase),stadium:['semi','final'].includes(S.phase)?'Terrain neutre':S.clubs[pair[0]].stadium}:null,
   finance:{...projection,budget,series:[{label:'Aujourd’hui',value:projection.initialBalance},...projection.entries.map(p=>({label:'S+'+p.week,value:p.balance}))]},
   wages:families.map((label,i)=>({label,value:squad.filter(p=>p.family===i).reduce((s,p)=>s+(p.salary||0),0)})),
   ageBands:[{label:'≤ 23 ans',value:squad.filter(p=>p.age<=23).length},{label:'24–29 ans',value:squad.filter(p=>p.age>=24&&p.age<=29).length},{label:'≥ 30 ans',value:squad.filter(p=>p.age>=30).length}]};
 }
 function financeKeypoints(rows){
  const valid=(rows||[]).filter(r=>finite(r.value));if(!valid.length)return null;
  const min=valid.reduce((a,b)=>b.value<a.value?b:a),max=valid.reduce((a,b)=>b.value>a.value?b:a);
  return {start:valid[0].value,end:valid.at(-1).value,change:valid.at(-1).value-valid[0].value,low:min.value,lowLabel:min.label,high:max.value,highLabel:max.label};
 }
 function standingsGaps(rows,clubId){
  const data=(rows||[]).filter(r=>finite(r.points)),leader=data.length?Math.max(...data.map(r=>r.points)):0;
  return {leader,rows:data.map(r=>({id:r.id,rank:r.rank,label:r.abbr,points:r.points,gap:leader-r.points,mine:r.id===clubId})),mine:data.find(r=>r.id===clubId)||null};
 }
 function priorityNeeds(rows){return (rows||[]).filter(n=>finite(n.score)&&n.score>0).slice().sort((a,b)=>b.score-a.score||a.slot-b.slot).slice(0,3);}
 function groupLines(rows){return [
  {label:'Avants',value:rows.filter(p=>p.family>=0&&p.family<=3).length},
  {label:'Charnière',value:rows.filter(p=>p.family===4||p.family===5).length},
  {label:'Trois-quarts',value:rows.filter(p=>p.family>=6&&p.family<=8).length}
 ];}

 // V4.2 : calculs de lecture exclusivement dérivés des snapshots natifs.
 function conditionBands(players){
  const valid=(players||[]).filter(p=>finite(p.condition));
  return [{label:'0–49',value:valid.filter(p=>p.condition<50).length},
   {label:'50–79',value:valid.filter(p=>p.condition>=50&&p.condition<80).length},
   {label:'80–100',value:valid.filter(p=>p.condition>=80).length}];
 }
 function cashMovements(series){
  const valid=(series||[]).filter(p=>finite(p.value));
  return valid.slice(1).map((p,i)=>({label:p.label,change:p.value-valid[i].value,balance:p.value}));
 }
 function academyGaps(rows){
  return (rows||[]).filter(p=>finite(p.note)&&finite(p.potential))
   .map(p=>({name:p.name,position:p.position,age:p.age,actual:p.note,ceiling:p.potential,gap:Math.max(0,p.potential-p.note)}))
   .sort((a,b)=>b.gap-a.gap||String(a.name).localeCompare(String(b.name),'fr'));
 }
 function publicCosts(rows){
  const valid=(rows||[]).filter(p=>finite(p.price)&&finite(p.salary));
  return {count:valid.length,
   zeroPrime:valid.filter(p=>p.price===0).length,
   minPrime:valid.length?Math.min(...valid.map(p=>p.price)):null,
   minSalary:valid.length?Math.min(...valid.map(p=>p.salary)):null,
   medianSalary:valid.length?valid.map(p=>p.salary).sort((a,b)=>a-b)[Math.floor((valid.length-1)/2)]:null};
 }
 function decisionSignals(m){
  const injured=m.availability.find(p=>p.label==='Blessés')?.value||0;
  const mine=m.standings.find(t=>t.mine);
  const next=m.next;
  return [
   {label:'Prochain match',value:next?next.opponent.abbr:'Aucun match',detail:next?(next.neutral?'Terrain neutre':next.home?'Domicile':'Extérieur'):'Phase sans rencontre',route:'tactics'},
   {label:'Disponibilité',value:num(m.squad.length-injured)+' / '+num(m.squad.length),detail:injured?num(injured)+' blessé(s)':'Aucune blessure signalée',route:'team'},
   {label:'Position',value:mine?num(mine.rank)+'e':'—',detail:mine?num(mine.points)+' points':'Pas de classement',route:'league'},
   {label:'Trésorerie',value:eur(m.club.cash),detail:'Montant fictif de la carrière',route:'finance'}
  ];
 }
 function decisionBoard(m){
  const signals=decisionSignals(m),match=signals[0],other=signals.slice(1);
  const timeline=(m.fixtures||[]).slice(0,3);
  return '<section class="da42-board da42-command" aria-label="Centre de décisions du manager">'+
   '<div class="da42-command-lead"><div class="da42-command-overline">LE POSTE DE COMMANDE <span>SAISON '+esc(m.season)+'</span></div>'+
   '<div class="da42-command-content"><div><span class="da42-command-kicker">PROCHAIN DÉFI</span><h2>'+esc(m.next?m.next.opponent.name:'Le prochain chapitre')+'</h2>'+
   '<p>'+esc(m.roundTitle||'Saison en cours')+' · '+esc(match.detail)+' · '+esc(m.competition)+'</p>'+
   '<button class="da42-command-cta" type="button" onclick="nav(\'tactics\')">Préparer ce rendez-vous <span>↗</span></button></div>'+
   '<div class="da42-command-crest" aria-hidden="true">'+esc(m.next?m.next.opponent.abbr:'CD')+'</div></div>'+
   '<div class="da42-command-fixtures" aria-label="Trois prochaines échéances">'+timeline.map(x=>'<span><b>J'+esc(x.round)+'</b> '+esc(x.abbr)+' · '+(x.home?'DOM':'EXT')+'</span>').join('')+'</div></div>'+
   '<div class="da42-command-rail"><div class="da42-rail-head">ÉTAT DU CLUB <span>LECTURE DIRECTE</span></div>'+
   other.map((a,i)=>'<article class="da42-rail-item"><span class="da42-rail-index">0'+(i+1)+'</span><div><small>'+esc(a.label)+'</small><strong>'+esc(a.value)+'</strong><p>'+esc(a.detail)+'</p></div><button type="button" onclick="nav(\''+a.route+'\')" aria-label="Ouvrir '+esc(a.label)+'">↗</button></article>').join('')+
   '</div></section>';
 }
 function fitnessStudio(players){
  const bands=conditionBands(players),valid=(players||[]).filter(p=>finite(p.condition)),
   average=valid.length?valid.reduce((t,p)=>t+p.condition,0)/valid.length:null,
   low=valid.slice().sort((a,b)=>a.condition-b.condition).slice(0,4);
  return '<section class="da42-panel da42-fitness da42-desktop-stage" aria-label="Lecture de la condition du XV">'+
   head('LECTURE DU XV','L’état de la sélection','CHIFFRES DU XV ACTUEL')+
   '<div class="da42-fitness-composition"><div class="da42-fitness-meter"><div class="da42-fitness-disc" style="--fitness:'+Math.max(0,Math.min(100,average??0))+'"><span>CONDITION MOYENNE</span><strong>'+(average===null?'—':num(average))+'</strong><small>/ 100</small></div>'+
   '<p>Valeur moyenne des titulaires renseignés, sans modification de sélection.</p></div>'+
   '<div class="da42-fitness-distribution"><h3>Répartition de la condition</h3><div class="da42-condition-grid">'+
   bands.map((a,i)=>'<article class="da42-condition is-'+i+'"><strong>'+num(a.value)+'</strong><span>joueurs</span><small>'+esc(a.label)+' /100</small></article>').join('')+
   '</div><div class="da42-fitness-low"><h3>Conditions les plus basses</h3>'+
   (low.length?low.map(p=>'<div><span>'+esc(p.name||'Joueur')+'</span><b>'+num(p.condition)+'/100</b></div>').join(''):'<p>Aucun titulaire renseigné.</p>')+
   '</div></div></div>'+
   table(['Condition /100','Titulaires'],bands.map(p=>[p.label,p.value]),'Répartition des conditions du XV')+
   '<p class="da4-chart-note">Plages descriptives du moteur natif. Il ne s’agit ni d’un avis médical ni d’une consigne de sélection.</p></section>';
 }
 function cashStudio(series){
  const values=cashMovements(series),total=values.reduce((a,b)=>a+b.change,0),
   rises=values.filter(v=>v.change>0).length,falls=values.filter(v=>v.change<0).length,
   max=Math.max(1,...values.map(x=>Math.abs(x.change)));
  return '<section class="da42-panel da42-cash-stage da42-desktop-stage" aria-label="Variations hebdomadaires de trésorerie">'+
   head('ANALYSE DES FLUX','Lire les mouvements','PROJECTION · PAS UN HISTORIQUE')+
   '<div class="da42-cash-summary"><div><small>ÉVOLUTION SUR LA PÉRIODE</small><strong>'+esc((total>0?'+':'')+eur(total))+'</strong></div>'+
   '<div><small>SEMAINES EN HAUSSE</small><strong>'+num(rises)+'</strong></div>'+
   '<div><small>SEMAINES EN BAISSE</small><strong>'+num(falls)+'</strong></div></div>'+
   (values.length?'<div class="da42-cash-timeline" role="img" aria-label="Amplitude des variations de trésorerie par semaine. Toutes les valeurs sont dans le tableau ci-dessous.">'+
   values.map(p=>'<div class="da42-cash-week"><strong>'+esc(p.label)+'</strong><div class="da42-cash-column"><i class="'+(p.change<0?'is-negative':p.change>0?'is-positive':'is-neutral')+'" style="height:'+Math.max(3,Math.round(Math.abs(p.change)/max*100))+'%"></i></div><small>'+esc((p.change>0?'+':'')+compact(p.change))+'</small></div>').join('')+
   '</div>':'<p class="da4-empty">Aucune variation hebdomadaire disponible.</p>')+
   table(['Semaine','Variation (€)','Solde (€)'],values.map(p=>[p.label,(p.change>0?'+':'')+eur(p.change),eur(p.balance)]),'Projection hebdomadaire de trésorerie')+
   '<p class="da4-chart-note">Les colonnes représentent l’amplitude des variations hebdomadaires du modèle fictif. Les valeurs complètes restent consultables.</p></section>';
 }
 function academyStudio(academy){
  const values=academyGaps(academy),lead=values.slice(0,8),maxGap=values.length?Math.max(...values.map(x=>x.gap)):0;
  return '<section class="da42-panel da42-academy da42-desktop-stage" aria-label="Écart au plafond de potentiel des espoirs">'+
   head('LABORATOIRE DE LA RELÈVE','Les trajectoires possibles','ACTUEL / PLAFOND')+
   '<div class="da42-academy-intro"><div><strong>'+num(values.length)+'</strong><span>espoirs évaluables</span></div>'+
   '<div><strong>'+num(maxGap)+'</strong><span>plus grand écart /100</span></div>'+
   '<p>Une cartographie des écarts, pas une promesse de progression.</p></div>'+
   (lead.length?'<div class="da42-talent-grid">'+lead.map((p,i)=>'<article class="da42-talent"><div class="da42-talent-head"><span>0'+(i+1)+'</span><small>'+esc(p.position||'Espoir')+' · '+esc(p.age??'—')+' ans</small></div>'+
   '<h3>'+esc(p.name)+'</h3><div class="da42-talent-numbers"><strong>'+num(p.actual)+'</strong><span>→</span><strong>'+num(p.ceiling)+'</strong><small> /100</small></div>'+
   '<div class="da42-talent-track"><i style="width:'+Math.max(0,Math.min(100,p.actual))+'%"></i><b style="left:'+Math.max(0,Math.min(100,p.ceiling))+'%"></b></div>'+
   '<footer>ÉCART <strong>'+num(p.gap)+'</strong></footer></article>').join('')+'</div>':'<p class="da4-empty">Aucun espoir évaluable.</p>')+
   table(['Espoir','Actuel /100','Plafond /100','Écart'],values.map(p=>[p.name,p.actual,p.ceiling,p.gap]),'Écarts au plafond des espoirs')+
   '<p class="da4-chart-note">Plafonds théoriques natifs ; rien ne garantit leur atteinte. Le classement ne préjuge pas du meilleur choix sportif.</p></section>';
 }
 function marketStudio(candidates){
  const costs=publicCosts(candidates),valid=(candidates||[]).filter(p=>finite(p.price)&&finite(p.salary)),
    salaries=valid.map(p=>p.salary),maxSalary=Math.max(1,...salaries),
    bands=[{label:'Bas',count:salaries.filter(v=>v<=maxSalary/3).length},
      {label:'Intermédiaire',count:salaries.filter(v=>v>maxSalary/3&&v<=maxSalary*2/3).length},
      {label:'Élevé',count:salaries.filter(v=>v>maxSalary*2/3).length}];
  return '<section class="da42-panel da42-market da42-desktop-stage" aria-label="Synthèse des coûts publics du marché">'+
   head('OBSERVATOIRE DES TRANSFERTS','Le prix du marché','DONNÉES PUBLIQUES SEULEMENT')+
   '<div class="da42-market-composition"><div class="da42-market-primary"><small>SALAIRE MÉDIAN / SEMAINE</small><strong>'+eur(costs.medianSalary)+'</strong><p>Médiane inférieure si nombre pair. Aucun talent masqué n’est révélé.</p>'+
   '<div class="da42-market-breakdown"><h3>Répartition relative des salaires</h3><div class="da42-market-bars">'+
   bands.map((g,i)=>'<div class="da42-market-bar"><span>'+esc(g.label)+'</span><div><i class="is-'+i+'" style="width:'+Math.max(0,g.count/Math.max(1,costs.count)*100).toFixed(1)+'%"></i></div><strong>'+num(g.count)+'</strong></div>').join('')+
   '</div><p>Trois tranches relatives au salaire maximal observé, sans seuil sportif arbitraire.</p></div></div>'+
   '<div class="da42-market-facts"><div><small>PROFILS AVEC COÛTS</small><strong>'+num(costs.count)+'</strong></div>'+
   '<div><small>PRIME MINIMALE</small><strong>'+eur(costs.minPrime)+'</strong></div>'+
   '<div><small>SANS PRIME</small><strong>'+num(costs.zeroPrime)+'</strong></div></div></div>'+
   table(['Tranche de salaire','Candidats'],bands.map(x=>[x.label,x.count]),'Distribution relative des salaires publics')+
   '<p class="da4-chart-note">Coûts comparables uniquement. Cette lecture ne dévoile ni niveau, ni potentiel, ni aptitude non observée.</p></section>';
 }
 function head(kicker,title,meta=''){return '<header class="da4-panel-head"><div><span class="da4-kicker">'+esc(kicker)+'</span><h2>'+esc(title)+'</h2></div>'+(meta?'<span class="da4-meta">'+esc(meta)+'</span>':'')+'</header>';}
 function svg(body,label,w=600,h=250,role='img'){return '<svg class="da4-chart" viewBox="0 0 '+w+' '+h+'" role="'+role+'" aria-label="'+esc(label)+'" xmlns="http://www.w3.org/2000/svg"><title>'+esc(label)+'</title>'+body+'</svg>';}
 function table(headers,rows,caption){return '<details class="da4-data"><summary>Lire les valeurs</summary><div class="da4-table-scroll"><table><caption>'+esc(caption)+'</caption><thead><tr>'+headers.map(x=>'<th scope="col">'+esc(x)+'</th>').join('')+'</tr></thead><tbody>'+rows.map(r=>'<tr>'+r.map((x,i)=>'<'+(i?'td':'th scope="row"')+'>'+esc(x)+'</'+(i?'td':'th')+'>').join('')+'</tr>').join('')+'</tbody></table></div></details>';}
 function lineChart(rows,title,currency=false){
  rows=rows.filter(r=>finite(r.value));if(!rows.length)return '<p class="da4-empty">Aucune donnée enregistrée.</p>';
  const values=rows.map(r=>r.value),rawMin=Math.min(...values),rawMax=Math.max(...values),span=rawMax-rawMin;
  const pad=span?span*.12:Math.max(Math.abs(rawMax)*.08,1),lo=rawMin-pad,hi=rawMax+pad;
  const x=i=>58+i*514/Math.max(1,rows.length-1),y=v=>190-(v-lo)/(hi-lo)*156;
  const grid=Array.from({length:5},(_,i)=>{const v=lo+(hi-lo)*i/4;return '<line class="da4-gridline" x1="58" x2="572" y1="'+y(v)+'" y2="'+y(v)+'"/><text class="da4-tick" x="49" y="'+(y(v)+4)+'" text-anchor="end">'+esc(compact(v))+'</text>';}).join('');
  const pts=rows.map((r,i)=>x(i)+','+y(r.value)).join(' '),zero=y(Math.min(hi,Math.max(lo,0))),last=rows.at(-1);
  const labels=rows.map((r,i)=>i===0||i===rows.length-1||i%3===0?'<text class="da4-tick" x="'+x(i)+'" y="216" text-anchor="middle">'+esc(r.label)+'</text>':'').join('');
  return '<figure class="da4-figure"><div class="da4-chart-viewport" tabindex="0" role="region" aria-label="Graphique défilant horizontalement">'+svg(grid+'<text class="da4-tick" x="58" y="17">'+(currency?'EUR':'Valeur')+'</text><polygon class="da4-area" points="58,'+zero+' '+pts+' '+x(rows.length-1)+','+zero+'"/><polyline class="da4-line" points="'+pts+'"/>'+rows.map((r,i)=>'<circle class="da4-dot" cx="'+x(i)+'" cy="'+y(r.value)+'" r="3"><title>'+esc(r.label+' : '+(currency?eur(r.value):num(r.value)))+'</title></circle>').join('')+labels,title)+'</div><figcaption>'+esc(title)+' · '+esc(currency?eur(last.value):num(last.value))+' à l’horizon affiché.</figcaption></figure>'+table(['Échéance',currency?'Trésorerie (€)':'Valeur'],rows.map(r=>[r.label,currency?eur(r.value):num(r.value)]),title);
 }
 function bars(rows,title,unit=''){const max=Math.max(1,...rows.map(r=>Math.max(0,r.value||0)));return '<div class="da4-bars" role="img" aria-label="'+esc(title)+'">'+rows.map((r,i)=>'<div class="da4-bar-row'+(r.mine?' is-mine':'')+'"><span>'+esc(r.label)+'</span><div class="da4-bar-track"><i style="width:'+(Math.max(0,r.value||0)/max*100).toFixed(2)+'%;--bar-index:'+i+'"></i></div><strong>'+esc(unit==='€'?eur(r.value):num(r.value)+(unit?' '+unit:''))+'</strong></div>').join('')+'</div>';}
 function ring(rows,title){const total=rows.reduce((s,r)=>s+r.value,0);let off=0;const colors=['#9fc298','#dd8d58','#74877e'];const circles=rows.map((r,i)=>{const len=total?r.value/total*314.16:0,s='<circle cx="70" cy="70" r="50" fill="none" stroke="'+colors[i%3]+'" stroke-width="12" stroke-dasharray="'+len+' '+(314.16-len)+'" stroke-dashoffset="'+(-off)+'" transform="rotate(-90 70 70)"/>';off+=len;return s;}).join('');return '<div class="da4-ring-block">'+svg('<circle cx="70" cy="70" r="50" class="da4-ring-track" fill="none" stroke-width="12"/>'+circles+'<text class="da4-ring-total" x="70" y="76" text-anchor="middle">'+num(total)+'</text><text class="da4-ring-unit" x="70" y="94" text-anchor="middle">JOUEURS</text>',title,140,140)+'<dl class="da4-ring-legend">'+rows.map((r,i)=>'<div><dt><i style="background:'+colors[i%3]+'"></i>'+esc(r.label)+'</dt><dd>'+num(r.value)+'</dd></div>').join('')+'</dl></div>';}
 function scatter(rows,xkey='age',ykey='note',title='Âge et niveau au poste'){
  const valid=rows.filter(p=>finite(p[xkey])&&finite(p[ykey]));if(!valid.length)return '<p class="da4-empty">Aucun profil disponible pour cette vue.</p>';
  const isAge=xkey==='age',minX=isAge?16:0,maxX=isAge?Math.max(40,...valid.map(p=>p[xkey])):Math.max(1,...valid.map(p=>p[xkey])),maxY=ykey==='note'?100:Math.max(1,...valid.map(p=>p[ykey]));
  const x=v=>55+(v-minX)/(maxX-minX)*500,y=v=>194-v/maxY*155;
  let body='';for(let i=0;i<=4;i++){const v=maxY*i/4;body+='<line class="da4-gridline" x1="55" x2="555" y1="'+y(v)+'" y2="'+y(v)+'"/><text class="da4-tick" x="47" y="'+(y(v)+4)+'" text-anchor="end">'+esc(compact(v))+'</text>';const vx=minX+(maxX-minX)*i/4;body+='<text class="da4-tick" x="'+x(vx)+'" y="216" text-anchor="middle">'+esc(isAge?num(vx):compact(vx))+'</text>';}
  body+='<text class="da4-tick" x="55" y="18">'+(ykey==='note'?'Niveau au poste / 100':'Salaire / semaine (€)')+'</text><text class="da4-tick" x="555" y="240" text-anchor="end">'+(isAge?'Âge (ans)':'Prime (€)')+'</text>';
  for(const p of valid){const label=p.name+' · '+num(p[xkey])+(isAge?' ans':' €')+' · '+num(p[ykey])+(ykey==='note'?'/100':' €/sem.');body+='<circle class="da4-player-point '+(isAge?(p.family<=3?'is-forward':'is-back'):'is-market')+'" cx="'+x(p[xkey])+'" cy="'+y(p[ykey])+'" r="5.5" tabindex="0" aria-label="'+esc(label)+'"><title>'+esc(label)+'</title></circle>';}
  return '<figure class="da4-figure da4-scatter-figure"><div class="da4-chart-viewport" tabindex="0" role="region" aria-label="Graphique défilant horizontalement">'+svg(body,title,600,250,'group')+'</div><figcaption>'+(isAge?'<span class="da4-key is-forward"></span> Avants <span class="da4-key is-back"></span> Arrières · Un point par joueur.':'Un point par candidat public · Survol ou focus pour lire le profil.')+'</figcaption><output class="da4-point-readout" aria-live="polite">Survolez ou sélectionnez un point pour lire le profil.</output></figure>'+table(['Joueur',isAge?'Âge':'Prime (€)',ykey==='note'?'Niveau /100':'Salaire /sem. (€)'],valid.map(p=>[p.name,num(p[xkey]),num(p[ykey])]),title);
 }
 const positions=[[24,78],[50,78],[76,78],[37,64],[63,64],[18,51],[50,49],[82,51],[37,36],[61,28],[12,15],[40,17],[70,17],[90,15],[50,7]];
 function pitch(needs){const map=new Map(needs.map(n=>[n.slot,n]));return '<div class="da4-pitch" role="group" aria-label="Priorités de recrutement sur les quinze postes"><div class="da4-pitch-lines" aria-hidden="true"><i></i><i></i><i></i></div>'+positions.map(([x,y],i)=>{const n=map.get(i);return '<div class="da4-position '+(n?.need?'is-need':'')+(x<30?' is-left':x>70?' is-right':'')+(y>65?' is-low':'')+'" style="left:'+x+'%;top:'+y+'%" tabindex="0" aria-label="'+esc((i+1)+' · '+(n?.pos||POS[i])+' · priorité '+(n?num(n.score):'non disponible')+'/100')+'"><span>'+(i+1)+'</span><strong>'+esc(n?num(n.score):'—')+'</strong><small>'+esc(n?.pos||POS[i])+'</small><div class="da4-position-tooltip">'+esc(n?.reasons?.join(' · ')||'Diagnostic indisponible')+'</div></div>';}).join('')+'</div><p class="da4-chart-note"><span class="da4-key is-need"></span> Priorité native ≥ 20/100 · Score élevé = besoin plus important. Placement schématique des postes.</p>'+table(['N°','Poste','Priorité /100','Diagnostic'],needs.slice().sort((a,b)=>a.slot-b.slot).map(n=>[n.slot+1,n.pos,n.score,n.reasons.join(' · ')]),'Diagnostic natif des quinze postes');}
 function potentials(rows){if(!rows.length)return '<p class="da4-empty">Le centre ne compte actuellement aucun espoir.</p>';const h=55+rows.length*48;let body='<text class="da4-tick" x="190" y="20">NIVEAU ACTUEL → PLAFOND DE POTENTIEL /100</text>';for(let i=0;i<=4;i++){const v=i*25,x=190+v*3.7;body+='<line class="da4-gridline" x1="'+x+'" x2="'+x+'" y1="30" y2="'+(h-20)+'"/><text class="da4-tick" x="'+x+'" y="'+(h-3)+'" text-anchor="middle">'+v+'</text>';}
  rows.forEach((p,i)=>{const y=55+i*48,x=190+p.note*3.7,end=190+p.potential*3.7;body+='<text class="da4-chart-name" x="4" y="'+y+'">'+esc(p.name)+'</text><text class="da4-tick" x="4" y="'+(y+15)+'">'+esc(p.position+' · '+p.age+' ans')+'</text><line class="da4-potential-line" x1="'+x+'" x2="'+end+'" y1="'+y+'" y2="'+y+'"/><circle class="da4-dot" cx="'+x+'" cy="'+y+'" r="5"/><circle class="da4-potential-end" cx="'+end+'" cy="'+y+'" r="5"/><title>'+esc(p.name+' : '+p.note+' actuel, '+p.potential+' plafond')+'</title>';});return '<figure class="da4-figure"><div class="da4-chart-viewport" tabindex="0" role="region" aria-label="Graphique défilant horizontalement">'+svg(body,'Niveau actuel et plafond natif des espoirs',600,h)+'</div><figcaption>Point plein : niveau actuel · Point cerclé : potentiel. Ce plafond n’est pas une progression garantie.</figcaption></figure>'+table(['Espoir','Actuel /100','Plafond /100'],rows.map(p=>[p.name,p.note,p.potential]),'Niveaux et potentiels du centre');}
 function radar(players,title){
  const general=['speed','power','stamina','tackle','pass','kick','mental','discipline'];
  const keys=players.length===1?[...new Set([...Object.keys(ROLE_WEIGHTS[players[0].family]||{}),...general])].slice(0,8):general;
  if(!players.length)return '<p class="da4-empty">Aucun joueur sélectionné.</p>';
  const rows=keys.map(k=>({label:ATTR[k],value:players.reduce((s,p)=>s+(p.attributes[k]||0),0)/players.length}));
  const xy=(i,r)=>[230+Math.sin(i*Math.PI/4)*r,165-Math.cos(i*Math.PI/4)*r];
  let body='';for(const level of [25,50,75,100])body+='<polygon class="da4-radar-grid" points="'+keys.map((_,i)=>xy(i,level*1.1).join(',')).join(' ')+'"/>';
  rows.forEach((r,i)=>{const [x,y]=xy(i,148),[gx,gy]=xy(i,110);body+='<line class="da4-gridline" x1="230" y1="165" x2="'+gx+'" y2="'+gy+'"/><text class="da4-radar-label" x="'+x+'" y="'+(y+4)+'" text-anchor="'+(i===0||i===4?'middle':i<4?'start':'end')+'">'+esc(r.label)+'</text>';});
  body+='<polygon class="da4-radar-shape" points="'+rows.map((r,i)=>xy(i,r.value*1.1).join(',')).join(' ')+'"/>';
  rows.forEach((r,i)=>{const [x,y]=xy(i,r.value*1.1);body+='<circle class="da4-dot" cx="'+x+'" cy="'+y+'" r="4"><title>'+esc(r.label+' : '+num(r.value)+'/100')+'</title></circle>';});
  return '<figure class="da4-figure da4-radar-figure">'+svg(body,title+' · attributs /100',460,330)+'<figcaption>'+esc(title)+' · Échelle 0–100, grilles tous les 25 points.</figcaption></figure>'+table(['Attribut','Valeur /100'],rows.map(r=>[r.label,num(r.value)]),title);
 }
 function profileStage(p){const best=Object.entries(p.attributes).sort((a,b)=>b[1]-a[1]).slice(0,3);return '<section class="da4-profile-stage da4-two"><section class="da4-panel">'+head('LE PROFIL SPORTIF','Une lecture des qualités',p.position)+radar([p],'Attributs de '+p.name)+'</section><section class="da4-panel da4-profile-strengths">'+head('REPÈRES INDIVIDUELS','Les points d’appui')+best.map(([k,v],i)=>'<div class="da4-strength"><span>0'+(i+1)+'</span><div><h3>'+esc(ATTR[k])+'</h3><strong>'+num(v)+'<small> /100</small></strong></div></div>').join('')+'<p class="da4-chart-note">Les trois attributs les plus élevés du profil courant. La pertinence sportive dépend du poste et des consignes.</p></section></section>';}
 function tacticsStage(m){const xv=(S.lineup||[]).map(id=>m.squad.find(p=>p.id===id)).filter(Boolean);return '<section class="da4-tactics-stage da4-two"><section class="da4-panel">'+head('PRÉPARATION DU XV','Les qualités de la sélection',xv.length+' TITULAIRES')+radar(xv,'Moyenne des attributs du XV sélectionné')+'</section><section class="da4-panel">'+head('CONDITION INDIVIDUELLE','Répartir la charge','CONDITION /100')+'<div class="da4-xv-grid">'+(S.lineup||[]).map((id,i)=>{const p=m.squad.find(p=>p.id===id);return '<div><span>'+(i+1)+'</span><strong>'+esc(p?.name||'Poste vacant')+'</strong><b>'+esc(p?num(p.condition):'—')+'</b><i style="--condition:'+(p?Math.max(0,Math.min(100,p.condition)):0)+'%"></i></div>';}).join('')+'</div><p class="da4-chart-note">Conditions natives des joueurs sélectionnés. La charge et le plan de jeu se règlent dans les commandes de préparation ci-dessous.</p></section></section>';}
 function fixture(m){if(!m.next)return '<section class="da4-fixture da4-panel">'+head('LE CALENDRIER','Le prochain chapitre')+'<p>Pas de rencontre programmée dans la phase actuelle.</p><button onclick="nav(\'league\')">Voir la compétition →</button></section>';
  return '<section class="da4-fixture da4-panel" aria-label="Prochain rendez-vous">'+head('PROCHAIN RENDEZ-VOUS',m.roundTitle,m.competition+' · XV')+'<div class="da4-duel"><div><span class="da4-big-crest">'+esc(m.club.abbr)+'</span><h3>'+esc(m.club.name)+'</h3><small>'+ (m.next.neutral?'TERRAIN NEUTRE':m.next.home?'À DOMICILE':'À L’EXTÉRIEUR')+'</small></div><span class="da4-versus">VS</span><div><span class="da4-big-crest is-away">'+esc(m.next.opponent.abbr)+'</span><h3>'+esc(m.next.opponent.name)+'</h3><small>'+ (m.next.neutral?'TERRAIN NEUTRE':m.next.home?'VISITEUR':'REÇOIT')+'</small></div></div><footer><span>'+esc(m.next.stadium)+'</span><button class="da4-cta" onclick="nav(\'match\')">Préparer la rencontre <b>↗</b></button></footer></section>';}
 function form(m){return '<section class="da4-form">'+head('DYNAMIQUE','Les derniers résultats')+(m.results.length?'<div class="da4-results">'+m.results.map(r=>'<div class="da4-result is-'+r.outcome+'"><span>'+esc(r.label)+'</span><b>'+r.own+'<em>–</em>'+r.against+'</b><small>'+({V:'VICTOIRE',D:'DÉFAITE',N:'NUL'}[r.outcome])+'</small></div>').join('')+'</div>':'<p class="da4-empty">Le premier match écrira votre série. Aucun résultat enregistré pour le moment.</p>')+'</section>';}
 function runway(m){return '<section class="da4-calendar" aria-label="Prochains matchs">'+head('À L’HORIZON','Le calendrier',m.fixtures.length+' RENDEZ-VOUS')+'<div class="da4-fixtures">'+m.fixtures.map((f,i)=>'<button class="da4-fixture-stop '+(!i?'is-next':'')+'" onclick="nav(\'league\')"><span>J'+f.round+'</span><b>'+esc(f.abbr)+'</b><small>'+(f.home?'DOM':'EXT')+'</small><span class="da4-stop-name">'+esc(f.name)+'</span></button>').join('')+'</div></section>';}
 function financeStage(m){const landmarks=financeKeypoints(m.finance.series);return '<section class="da4-finance-stage da4-two"><section class="da4-panel da4-finance-chart">'+head('TRAJECTOIRE FINANCIÈRE','Trésorerie à '+m.finance.budget.weeks+' semaines',m.finance.budget.weeks+' SEMAINES')+'<div class="da4-chart-numbers"><div><small>AUJOURD’HUI</small><strong>'+eur(m.club.cash)+'</strong></div><div><small>PROJETÉ À S+'+m.finance.budget.weeks+'</small><strong>'+eur(m.finance.finalBalance)+'</strong></div><span class="da4-scenario-label">PROJECTION DU MODÈLE NATIF</span></div>'+lineChart(m.finance.series,'Trésorerie projetée',true)+(landmarks?'<div class="da41-insights" aria-label="Repères de la projection"><div><small>VARIATION</small><strong>'+esc((landmarks.change>0?'+':'')+eur(landmarks.change))+'</strong></div><div><small>POINT BAS · '+esc(landmarks.lowLabel)+'</small><strong>'+eur(landmarks.low)+'</strong></div><div><small>POINT HAUT · '+esc(landmarks.highLabel)+'</small><strong>'+eur(landmarks.high)+'</strong></div></div>':'')+'<p class="da4-chart-note">Partenaires, salaires, formation et entretien du modèle courant. Hors billetterie, primes sportives, transferts et aléas. Montants fictifs.</p></section><section class="da4-panel">'+head('STRUCTURE DES CHARGES','La masse salariale','€/SEMAINE')+bars(m.wages,'Salaires par famille de poste','€')+'<p class="da4-chart-note">Somme des salaires des professionnels de votre club, par famille de poste.</p></section></section>';}
 function squadStage(m){const lines=groupLines(m.squad);return '<section class="da4-squad-stage da4-two"><section class="da4-panel">'+head('CARTOGRAPHIE DU GROUPE','L’équilibre de votre effectif',m.squad.length+' JOUEURS')+scatter(m.squad)+'</section><section class="da4-panel">'+head('DISPONIBILITÉ','Vos forces du moment')+ring(m.availability,'Disponibilité de l’effectif')+'<div class="da4-age-band">'+m.ageBands.map(r=>'<div><strong>'+num(r.value)+'</strong><span>'+esc(r.label)+'</span></div>').join('')+'</div><div class="da41-lines">'+head('ÉQUILIBRE DES LIGNES','Répartition par unité')+bars(lines,'Avants, charnière et trois-quarts','joueurs')+'</div><p class="da4-chart-note">L’âge et le niveau éclairent la relève ; ils ne suffisent pas à évaluer un joueur. Les blessés sont ceux signalés par le moteur.</p></section></section>';}
 function recruitStage(m){const top=priorityNeeds(m.needs);return '<div class="da4-recruit-stage da4-two"><section class="da4-panel">'+head('DIAGNOSTIC DES POSTES','Où renforcer le XV ?','PRIORITÉ /100')+pitch(m.needs)+'</section><div class="da4-stack"><section class="da4-panel">'+head('COÛT DES CANDIDATS','Lire le marché')+scatter(m.candidates,'price','salary','Prime et salaire des candidats publics')+'<p class="da4-chart-note">Coûts publics uniquement. Le niveau et le potentiel non observés ne sont pas révélés.</p><button class="da4-text-action" data-ui03-action="tab" data-ui03-tab="candidates">Explorer les candidats →</button></section><section class="da4-panel da4-brief"><span class="da4-kicker">LA DÉCISION À PRÉPARER</span><h3>'+(top.length?'Les trois postes à examiner':'Aucun besoin prioritaire')+'</h3>'+(top.length?'<ol class="da41-priority-list">'+top.map(n=>'<li><span>'+esc(n.pos)+'</span><strong>'+num(n.score)+'/100</strong><small>'+esc(n.reasons?.join(' · ')||'Priorité calculée sur les données natives')+'</small></li>').join('')+'</ol>':'<p>Aucune priorité positive dans le diagnostic du moteur.</p>')+'<button class="da4-text-action" data-ui03-action="tab" data-ui03-tab="missions">Confier une mission au recruteur →</button></section></div></div>';}
 function academyStage(m){const young=m.squad.filter(p=>p.age<=23),minutes=young.reduce((s,p)=>s+p.minutes,0);return '<div class="da4-academy-stage da4-two"><section class="da4-panel">'+head('DU CENTRE AU HAUT NIVEAU','Niveau actuel et potentiel',m.academy.length+' ESPOIRS')+potentials(m.academy)+'<button class="da4-text-action" data-ui04-action="tab" data-ui04-tab="academy">Accompagner les espoirs →</button></section><section class="da4-panel da4-pathway">'+head('LA PASSERELLE','Du centre au groupe pro')+'<div class="da4-pathway-step"><span>01</span><div><strong>'+m.academy.length+'</strong><h3>Au centre</h3><p>Les espoirs présents dans votre structure.</p></div></div><div class="da4-pathway-step"><span>02</span><div><strong>'+young.length+'</strong><h3>Jeunes professionnels</h3><p>23 ans ou moins dans l’effectif pro.</p></div></div><div class="da4-pathway-step"><span>03</span><div><strong>'+num(minutes)+'<small> MIN</small></strong><h3>Du temps de jeu</h3><p>Minutes réellement enregistrées cette saison.</p></div></div><button class="da4-text-action" data-ui04-action="tab" data-ui04-tab="young">Suivre les jeunes pros →</button></section></div>';}
 function leagueStage(m){const gaps=standingsGaps(m.standings,m.club.id),mine=gaps.rows.find(r=>r.mine);return '<section class="da4-panel da4-league-stage">'+head('LA COURSE AU BOUCLIER','L’écart se mesure en points','J'+(m.round+1))+(mine?'<div class="da41-league-recap"><div><small>VOTRE RANG</small><strong>'+num(m.standings.find(t=>t.id===m.club.id)?.rank)+'</strong></div><div><small>RETARD SUR LE LEADER</small><strong>'+num(mine.gap)+' pts</strong></div></div>':'')+bars(m.standings.map(t=>({label:t.abbr,value:t.points,mine:t.mine})),'Points au classement','pts')+table(['Club','Points','Écart au leader'],gaps.rows.map(r=>[r.label,r.points,r.gap?'−'+r.gap:'0']),'Écarts de points au classement')+(!m.standings.some(t=>t.points)?'<p class="da4-empty">Le championnat n’a pas encore distribué ses premiers points. Les équipes sont à égalité.</p>':'')+'<p class="da4-chart-note">Ordre du classement natif · Orange : votre club. Les détails et départages restent dans le tableau.</p></section>';}
 function node(html){const t=document.createElement('template');t.innerHTML=html.trim();return t.content.firstElementChild;}
 function fold(el,title){if(!el)return;const d=node('<details class="da4-dossier"><summary>'+esc(title)+'<span>Ouvrir le dossier ↗</span></summary></details>');el.before(d);d.append(el);}

 const workspaceChoice=Object.create(null);

 // V4.3 — context sourced exclusively from the current native career, never an
 // invented target, result or hidden scouting metric.
 function page43Context(route,id,m){
  if(!m)return {label:'DOSSIER DU MANAGER',value:'Données de carrière'};
  const wages=(m.wages||[]).reduce((sum,x)=>sum+(finite(x.value)?x.value:0),0);
  const values=cashMovements(m.finance.series);
  const gaps=academyGaps(m.academy);
  const needs=priorityNeeds(m.needs);
  const costs=publicCosts(m.candidates);
  const xv=(typeof S!=='undefined'&&Array.isArray(S.lineup)?S.lineup:[]).map(key=>m.squad.find(p=>p.id===key)).filter(Boolean);
  const avg=xv.filter(p=>finite(p.condition));
  const condition=avg.length?num(avg.reduce((sum,p)=>sum+p.condition,0)/avg.length)+'/100':'—';
  const defaults={
   dashboard:{
    pilotage:['PROCHAIN MATCH',m.next?m.next.opponent.abbr:'Non programmé'],
    calendrier:['ÉCHÉANCES À VENIR',num(m.fixtures.length)+' rencontres'],
    dossiers:['EFFECTIF DISPONIBLE',num(m.availability[0]?.value||0)+' / '+num(m.squad.length)]
   },
   tactics:{
    xv:['COMPOSITION COURANTE',num(xv.length)+' titulaires'],
    condition:['ÉTAT DU XV',condition],
    analyse:['CHARGE DE SÉLECTION',num(avg.length)+' conditions'],
    dossiers:['LISTE NATIVE',num(xv.length)+' titulaires']
   },
   finance:{
    tresorerie:['SOLDE DE CARRIÈRE',eur(m.club.cash)],
    flux:['SEM. PROJETÉES',num(values.length)+' semaines'],
    salaires:['PAIE HEBDOMADAIRE',eur(wages)+' / sem.'],
    dossiers:['HORIZON FINANCIER',num(m.finance.budget.weeks)+' semaines']
   },
   recruitment:{
    besoins:['PRIORITÉ PRINCIPALE',needs[0]?num(needs[0].score)+'/100':'Aucune'],
    marche:['CANDIDATS DOCUMENTÉS',num(costs.count)+' profils'],
    dossiers:['POSTES EN EXAMEN',num(needs.length)+' priorités']
   },
   formation:{
    passerelle:['ESPOIRS AU CENTRE',num(m.academy.length)+' joueurs'],
    potentiel:['ÉCARTS CALCULÉS',num(gaps.length)+' profils'],
    dossiers:['JEUNES PROS',num(m.squad.filter(p=>p.age<=23).length)+' joueurs']
   }
  };
  const pair=defaults[route]?.[id]||['DOSSIER',m.club.abbr];
  return {label:pair[0],value:pair[1]};
 }
 function buildWorkspace(root,route,groups){
  if(!root||root.querySelector(':scope>.da42-workspace-shell'))return;
  // Existing game controls are MOVED, not cloned and not replaced.
  // Everything not explicitly selected remains reachable on a native subpage.
  const keep=new Set(Array.from(root.children).filter(el=>el.matches('.ui01-appbar,.heading,.cd03-tabs,.cd04-tabs,.cd02-tabs')));
  const shell=node('<div class="da42-workspace-shell" aria-label="Sous-pages de gestion PC"><nav class="da42-subnav" role="tablist" aria-label="Sous-pages du '+esc(route)+'"></nav><div class="da42-page-viewport"></div></div>');
  const tabs=shell.querySelector('.da42-subnav'),viewport=shell.querySelector('.da42-page-viewport');
  shell.classList.add('da43-workspace');
  shell.dataset.da43Section=route;
  const pages=groups.map((g,index)=>{
   const tab=node('<button type="button" role="tab" class="da42-subtab" data-da42-subpage="'+esc(g.id)+'" aria-controls="da42-'+route+'-'+g.id+'" aria-selected="false" tabindex="-1"><span class="da42-tab-index">0'+(index+1)+'</span>'+esc(g.label)+'</button>');
   const panel=node('<section class="da42-page" role="tabpanel" id="da42-'+route+'-'+g.id+'" aria-label="'+esc(g.label)+'" hidden></section>');
   panel.dataset.da42Page=g.id;
   if(g.native)panel.classList.add('da42-page-native');
   tab.id='da43-tab-'+route+'-'+g.id;
   panel.setAttribute('aria-labelledby',tab.id);
   tabs.append(tab);viewport.append(panel);
   return {id:g.id,tab,panel};
  });
  const assigned=new Set();
  groups.forEach((g,i)=>{
   (g.selectors||[]).forEach(selector=>{
    for(const el of Array.from(root.querySelectorAll(selector))){
     if(assigned.has(el)||keep.has(el)||el.closest('.da42-workspace-shell'))continue;
     if(!root.contains(el))continue;
     // Avoid moving a child twice after its ancestor has been moved.
     if(Array.from(assigned).some(a=>a.contains(el)))continue;
     pages[i].panel.append(el);assigned.add(el);
    }
   });
  });
  // No folded dossier can be used to navigate primary information.
  root.querySelectorAll('.da4-dossier').forEach(details=>{
   if(Array.from(assigned).some(x=>x.contains(details)))return;
   const parts=Array.from(details.children).filter(x=>x.tagName!=='SUMMARY');
   parts.forEach(part=>details.before(part));details.remove();
  });
  const native=pages.find(p=>p.id==='dossiers')||pages[pages.length-1];
  for(const child of Array.from(root.children)){
   if(keep.has(child)||child===shell)continue;
   native.panel.append(child);
  }
  root.append(shell);
  // Undo only V4 presentation accordions: keep the native business controls intact.
  // A dossier is now a separate page, not a disclosure expanding this page.
  for(const details of Array.from(shell.querySelectorAll('details.da4-dossier')).reverse()){
   const parts=Array.from(details.children).filter(x=>x.tagName!=='SUMMARY');
   details.replaceWith(...parts);
  }
  // Tables remain directly visible in bounded local scroll areas.
  for(const details of Array.from(shell.querySelectorAll('details.da4-data'))){
   const wrapper=node('<div class="da4-data da42-static-values" aria-label="Tableau des valeurs"></div>');
   Array.from(details.children).filter(x=>x.tagName!=='SUMMARY').forEach(x=>wrapper.append(x));
   details.replaceWith(wrapper);
  }
  // Secondary-page commands live INSIDE the navigation band. They never
  // expand a panel or add content beneath the current page.
  const auxiliary=node('<div class="da43-page-switch"><div class="da43-page-context"><span class="da43-context-key"></span><strong class="da43-context-value"></strong></div><button type="button" class="da43-skip" data-da43-prev aria-label="Sous-page précédente">←</button><output class="da43-page-count" aria-live="polite"></output><button type="button" class="da43-skip" data-da43-next aria-label="Sous-page suivante">→</button></div>');
  tabs.append(auxiliary);
  const contextKey=auxiliary.querySelector('.da43-context-key'),contextValue=auxiliary.querySelector('.da43-context-value'),pageCount=auxiliary.querySelector('.da43-page-count');
  const managerSnapshot=snapshot();
  const jump=delta=>{
   const idx=pages.findIndex(p=>p.tab.getAttribute('aria-selected')==='true');
   activate(pages[(idx+delta+pages.length)%pages.length].id,false);
  };
  auxiliary.querySelector('[data-da43-prev]').addEventListener('click',()=>jump(-1));
  auxiliary.querySelector('[data-da43-next]').addEventListener('click',()=>jump(1));
  function activate(id,focus){
   const target=pages.find(p=>p.id===id)||pages[0];
   workspaceChoice[route]=target.id;
   const index=pages.indexOf(target),signal=page43Context(route,target.id,managerSnapshot);
   pageCount.textContent=String(index+1).padStart(2,'0')+' / '+String(pages.length).padStart(2,'0');
   contextKey.textContent=signal.label;contextValue.textContent=signal.value;
   shell.dataset.da43Active=target.id;
   for(const p of pages){
    const active=p===target;
    p.panel.hidden=!active;p.tab.setAttribute('aria-selected',String(active));
    p.tab.tabIndex=active?0:-1;
    if(active&&focus)p.tab.focus();
   }
  }
  tabs.addEventListener('click',event=>{
   const btn=event.target.closest('button[data-da42-subpage]');
   if(btn)activate(btn.dataset.da42Subpage,false);
  });
  tabs.addEventListener('keydown',event=>{
   if(!['ArrowRight','ArrowLeft','Home','End'].includes(event.key))return;
   event.preventDefault();
   const current=pages.findIndex(p=>p.tab===document.activeElement);
   const next=event.key==='Home'?0:event.key==='End'?pages.length-1:
    (Math.max(0,current)+(event.key==='ArrowRight'?1:pages.length-1))%pages.length;
   activate(pages[next].id,true);
  });
  activate(workspaceChoice[route]||pages[0].id,false);
  const main=root.closest('.main')||(root.matches('.main')?root:null);
  if(main){main.classList.add('da42-paged');const size=()=>{
   const top=main.getBoundingClientRect().top;
   main.style.setProperty('--da42-available-height',Math.max(420,window.innerHeight-top-12)+'px');
  };size();window.addEventListener('resize',size,{passive:true});}
 }
 function paginateRoute(main,route){
  if(route==='dashboard')buildWorkspace(main,route,[
   {id:'pilotage',label:'Vue d’ensemble',selectors:[':scope>.da42-command']},
   {id:'calendrier',label:'Calendrier',selectors:[':scope>.da4-calendar',':scope>.da4-desk-stage']},
   {id:'dossiers',label:'Dossiers du club',native:true,selectors:[':scope>.da4-decisions',':scope>.office-summary']}
  ]);
  if(route==='tactics')buildWorkspace(main,route,[
   {id:'xv',label:'XV et décisions',selectors:[':scope>.cd-matchday']},
   {id:'condition',label:'Condition',selectors:[':scope>.da42-fitness']},
   {id:'analyse',label:'Analyse du XV',selectors:[':scope>.da4-tactics-stage']},
   {id:'dossiers',label:'Autres commandes',native:true}
  ]);
  if(route==='finance'){
   const stage=main.querySelector(':scope>.da4-finance-stage');
   if(stage){for(const el of Array.from(stage.children))stage.before(el);stage.remove();}
   buildWorkspace(main,route,[
    {id:'tresorerie',label:'Trésorerie',selectors:[':scope>.da4-finance-chart']},
    {id:'flux',label:'Flux hebdomadaires',selectors:[':scope>.da42-cash-stage']},
    {id:'salaires',label:'Salaires',selectors:[':scope>.da4-panel:not(.da4-finance-chart)']},
    {id:'dossiers',label:'Journal et décisions',native:true}
   ]);
  }
  if(route==='recruitment'){
   const content=main.querySelector('.cd03-content');
   if(content&&main.querySelector('.cd03-tabs [aria-current="page"]')?.dataset.ui03Tab==='overview')
    {buildWorkspace(content,route,[
     {id:'besoins',label:'Besoins du XV',selectors:[':scope>.da4-recruit-stage']},
     {id:'marche',label:'Observatoire des coûts',selectors:[':scope>.da42-market']},
     {id:'dossiers',label:'Missions et commandes',native:true}
    ]);
     const metrics=main.querySelector('.cd03-kpis'),dossier=content.querySelector('[data-da42-page="dossiers"]');
     if(metrics&&dossier)dossier.prepend(metrics);
    }
  }
  if(route==='formation'){
   const content=main.querySelector('.cd04-content');
   if(content&&main.querySelector('.cd04-tabs [aria-current="page"]')?.dataset.ui04Tab==='overview')
    {buildWorkspace(content,route,[
     {id:'passerelle',label:'Passerelle',selectors:[':scope>.da4-academy-stage']},
     {id:'potentiel',label:'Potentiel des espoirs',selectors:[':scope>.da42-academy']},
     {id:'dossiers',label:'Suivi et commandes',native:true}
    ]);
     const metrics=main.querySelector('.cd04-kpis'),dossier=content.querySelector('[data-da42-page="dossiers"]');
     if(metrics&&dossier)dossier.prepend(metrics);
    }
  }
 }

 function enhance(route){
  if(typeof document==='undefined'||typeof document.querySelectorAll!=='function'||typeof S==='undefined'||!S||S.live)return;
  const main=document.querySelector('.ui01-layout>.main');if(!main||main.dataset.da4===route)return;
  const supported=['dashboard','team','finance','recruitment','formation','league','tactics'];if(!supported.includes(route))return;
  main.dataset.da4=route;main.classList.add('da4-workspace');const m=snapshot();
  if(route==='dashboard'){
   main.classList.add('da4-desk');const heading=main.querySelector('.heading');if(heading){heading.querySelector('h1').textContent=m.club.name;heading.querySelector('.eyebrow').textContent='LE BUREAU · SAISON '+m.season;}
   const summary=main.querySelector(':scope>.office-summary');if(summary){const stage=node('<div class="da4-desk-stage">'+fixture(m)+'<section class="da4-panel da4-condition">'+head('LE GROUPE','Prêts à entrer en jeu')+ring(m.availability,'Disponibilité du groupe')+'<button class="da4-text-action" onclick="nav(\'team\')">Voir l’effectif →</button></section></div>');summary.after(stage);stage.after(node(runway(m)));stage.before(node(decisionBoard(m)));}
   const office=main.querySelector(':scope>.office-grid');if(office){const calendar=office.querySelector('aside');if(calendar)fold(calendar,'Calendrier détaillé & projet sportif');}
   const season=main.querySelector(':scope>[aria-label="Pilotage de saison"]');if(season){const mini=season.querySelector('.office-summary');if(mini)fold(mini,'Les indicateurs de la relève');const links=season.querySelector('.office-links');if(links)links.classList.add('da4-quicklinks');}
   if(season&&office){const decisions=node('<div class="da4-decisions"></div>');season.before(decisions);decisions.append(season,node(form(m)),office);const duplicate=office.querySelector('.stack>.card:not(.office-inbox)');if(duplicate)fold(duplicate,'Autres décisions du bureau');}
   for(const el of Array.from(main.children)){if(el.classList.contains('card')&&el!==season)fold(el,el.querySelector('h2')?.textContent||'Dossier du club');}
  }
  if(route==='team'&&typeof squadTab!=='undefined'&&squadTab==='table'){const roster=main.querySelector('.cd02-roster');if(roster)roster.before(node(squadStage(m)));}
  if(route==='team'&&typeof ui02ProfileId!=='undefined'&&ui02ProfileId&&typeof ui02Tab!=='undefined'&&ui02Tab==='profil'){const p=m.squad.find(p=>p.id===ui02ProfileId),content=main.querySelector('.cd02-player-content');if(p&&content)content.prepend(node(profileStage(p)));}
  if(route==='tactics'){const panel=main.querySelector('.cd-matchday');if(panel){panel.before(node(tacticsStage(m)));panel.before(node(fitnessStudio((S.lineup||[]).map(id=>m.squad.find(p=>p.id===id)).filter(Boolean))));}}
  if(route==='finance'){const stats=main.querySelector(':scope>.stats');if(stats){stats.after(node(financeStage(m)));const graph=main.querySelector('.da4-finance-stage');if(graph)graph.after(node(cashStudio(m.finance.series)));}const journal=main.querySelector(':scope>.grid');if(journal)fold(journal,'Journal des mouvements & engagements');}
  if(route==='recruitment'){const center=main.querySelector('.cd03-content');if(center&&main.querySelector('.cd03-tabs [aria-current="page"]')?.dataset.ui03Tab==='overview'){const overview=center.firstElementChild;if(overview){overview.before(node(recruitStage(m)));const studio=main.querySelector('.da4-recruit-stage');if(studio)studio.after(node(marketStudio(m.candidates)));fold(overview,'Analyse détaillée & activité du recruteur');}}}
  if(route==='formation'){const center=main.querySelector('.cd04-content');if(center&&main.querySelector('.cd04-tabs [aria-current="page"]')?.dataset.ui04Tab==='overview'){const overview=center.firstElementChild;if(overview){overview.before(node(academyStage(m)));const studio=main.querySelector('.da4-academy-stage');if(studio)studio.after(node(academyStudio(m.academy)));fold(overview,'Tous les indicateurs de formation');}}}
  if(route==='league'){const heading=main.querySelector('.heading');if(heading)heading.after(node(leagueStage(m)));}
  paginateRoute(main,route);
  main.querySelectorAll('.da4-scatter-figure').forEach(figure=>{const show=e=>{const point=e.target.closest?.('.da4-player-point');if(point)figure.querySelector('.da4-point-readout').textContent=point.getAttribute('aria-label');};figure.addEventListener('focusin',show);figure.addEventListener('pointerover',show);});
 }
 return Object.freeze({snapshot,extent,lineChart,bars,scatter,pitch,potentials,financeKeypoints,standingsGaps,priorityNeeds,groupLines,conditionBands,cashMovements,academyGaps,publicCosts,decisionSignals,enhance});
});
