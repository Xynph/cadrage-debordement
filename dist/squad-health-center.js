'use strict';
// Disponibilité / rotation : vue en lecture seule des états de carrière natifs.
// Toutes les commandes de charge passent par setPhysicalTraining, aucun nouveau moteur.
function squadHealthSnapshot(){
 const players=club().players;
 const rows=players.map(p=>{
  const fatigue=physicalLoadValue(p),condition=Math.round(p.condition);
  const injured=Number(p.injury)||0,selected=S.lineup.includes(p.id),bench=S.reserves.includes(p.id);
  const severity=injured>0?'injured':fatigue>=55||condition<65?'high':fatigue>=35||condition<80?'caution':'fit';
  return {id:p.id,name:p.name,pos:p.pos,age:p.age,condition,fatigue,injured,
   selected,bench,severity,plan:physicalPlan(p),minutes:p.dev?.minutes||0,
   advice:injured?'Blessure : privilégier la récupération':severity==='high'?
    'Charge élevée : envisager une rotation ou récupération':severity==='caution'?
    'Surveiller la condition avant la prochaine rencontre':'Disponible pour la sélection'};
 });
 const coverage=POS.map((name,slot)=>{
  const eligible=players.filter(p=>slotEligible(p,slot));
  const available=eligible.filter(p=>!p.injury);
  const fresh=available.filter(p=>p.condition>=65&&physicalLoadValue(p)<55);
  const starters=available.filter(p=>S.lineup.includes(p.id));
  const alternatives=fresh.filter(p=>!S.lineup.includes(p.id)&&!S.reserves.includes(p.id))
   .sort((a,b)=>fitScore(b,FAMILIES[slot])-fitScore(a,FAMILIES[slot])||a.name.localeCompare(b.name,'fr'));
  return {slot,name,eligible:eligible.length,available:available.length,fresh:fresh.length,
   status:available.length===0?'critical':fresh.length<2?'fragile':'covered',
   current:starters.map(p=>p.name),alternatives:alternatives.slice(0,2).map(p=>({id:p.id,name:p.name}))};
 });
 const scores={injured:rows.filter(x=>x.severity==='injured').length,
  high:rows.filter(x=>x.severity==='high').length,caution:rows.filter(x=>x.severity==='caution').length,
  fit:rows.filter(x=>x.severity==='fit').length};
 const risks=coverage.filter(x=>x.status!=='covered').sort((a,b)=>
  (a.status==='critical'?-1:0)-(b.status==='critical'?-1:0)||a.slot-b.slot);
 return {scores,rows,coverage,risks,trainable:!S.live&&!S.trained&&S.phase!=='ended',
  lineup:rows.filter(x=>x.selected),bench:rows.filter(x=>x.bench)};
}
function squadHealthView(){
 const m=squadHealthSnapshot();
 const escape=typeof visualEscape==='function'?visualEscape:(s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])));
 const stat=(label,n)=>'<div class="cd-health-kpi"><small>'+label+'</small><strong>'+n+'</strong></div>';
 const priority=m.lineup.filter(p=>p.severity==='injured'||p.severity==='high')
  .sort((a,b)=>Number(b.severity==='injured')-Number(a.severity==='injured')||b.fatigue-a.fatigue);
 const summary='<div class="cd-health-summary">'+stat('Blessés',m.scores.injured)+stat('À ménager',m.scores.high)+
  stat('À surveiller',m.scores.caution)+stat('Disponibles',m.scores.fit)+'</div>';
 const alerts='<section class="card"><div class="cardtitle"><h2>Décisions de rotation</h2><span class="tag">'+
  priority.length+' TITULAIRES À EXAMINER</span></div>'+
  (priority.length?priority.slice(0,8).map(p=>'<div class="cd-health-advice"><div><strong>'+escape(p.name)+'</strong>'+
   '<small>'+escape(p.pos)+' · '+p.condition+' % · charge '+p.fatigue+'/100</small></div>'+
   '<button class="small" type="button" onclick="inspectPlayer(\''+p.id+'\')">Voir le profil</button></div>').join(''):
   '<p>Aucun titulaire actuellement blessé ou à charge élevée. Vérifiez toujours la feuille de match.</p>')+
  '<div class="office-links"><button type="button" onclick="squadTab=\'sheet\';render()">Composer les 23 →</button>'+
  '<button type="button" onclick="nav(\'tactics\')">Adapter la préparation →</button></div></section>';
 const fragile='<section class="card"><div class="cardtitle"><h2>Couverture des 15 postes</h2><span class="tag">'+
  m.risks.length+' POSTES À SURVEILLER</span></div><div class="cd-health-coverage">'+
  m.coverage.map(c=>'<div class="cd-health-slot '+c.status+'"><span>'+((c.slot+1)+' · '+escape(c.name))+'</span>'+
   '<strong>'+c.fresh+' frais / '+c.available+' aptes</strong></div>').join('')+'</div>'+
  '<div class="office-links"><button type="button" onclick="squadTab=\'depth\';render()">Voir tous les remplaçants →</button>'+
  '<button type="button" onclick="nav(\'recruitment\')">Identifier un renfort →</button></div></section>';
 const table='<section class="card"><div class="cardtitle"><h2>État de santé et plans de charge</h2>'+
  '<span class="tag">'+m.rows.length+' JOUEURS</span></div>'+
  '<p class="help">Les plans sont des commandes natives et ne peuvent être modifiés après la séance, en match ou en fin de saison.</p>'+
  '<div class="cd-health-filters"><label>Rechercher <input type="search" data-health-search placeholder="Nom ou poste" oninput="squadHealthFilter()"></label>'+
  '<label>Statut <select data-health-risk onchange="squadHealthFilter()"><option value="all">Tous</option>'+
  '<option value="injured">Blessés</option><option value="high">À ménager</option>'+
  '<option value="caution">À surveiller</option><option value="fit">Disponibles</option></select></label></div>'+
  '<div class="cd-health-scroll"><table class="cd-health-table"><thead><tr><th>Joueur</th><th>État</th>'+
  '<th>Condition</th><th>Charge</th><th>Plan individuel</th><th>Conseil</th></tr></thead><tbody>'+
  m.rows.slice().sort((a,b)=>({injured:0,high:1,caution:2,fit:3}[a.severity]-
  {injured:0,high:1,caution:2,fit:3}[b.severity])||a.condition-b.condition||
  a.name.localeCompare(b.name,'fr')).map(p=>'<tr data-health-row data-health-status="'+p.severity+
   '" data-health-name="'+escape((p.name+' '+p.pos).toLowerCase())+'"><td>'+
   '<button class="textbutton" type="button" onclick="inspectPlayer(\''+p.id+'\')">'+escape(p.name)+'</button>'+
   '<small>'+escape(p.pos)+(p.selected?' · Titulaire':p.bench?' · Banc':'')+'</small></td>'+
   '<td>'+({injured:'Blessé · '+p.injured+' sem.',high:'À ménager',caution:'À surveiller',fit:'Disponible'}[p.severity])+
   '</td><td>'+p.condition+' %</td><td>'+p.fatigue+'/100</td><td><select data-health-plan="'+p.id+
   '" aria-label="Plan de charge de '+escape(p.name)+'" onchange="setPhysicalTraining(\''+p.id+
   '\',this.value)"'+(m.trainable?'':' disabled')+'>'+
   Object.entries(PHYSICAL_PLANS).map(([mode,label])=>'<option value="'+mode+'"'+
    (p.plan===mode?' selected':'')+'>'+escape(label)+'</option>').join('')+'</select></td>'+
   '<td>'+escape(p.advice)+'</td></tr>').join('')+'</tbody></table></div></section>';
 return heading('PRÉPARATION PHYSIQUE','Disponibilité et rotation',
  'Anticipez la fatigue, les blessures et les postes fragiles sans modifier automatiquement votre équipe.')+
  '<div class="cd-health" aria-label="Centre de disponibilité de l’effectif">'+summary+
  '<div class="cd-health-grid">'+alerts+fragile+'</div>'+table+'</div>';
}
function squadHealthFilter(){
 const root=document.querySelector('.cd-health');if(!root)return;
 const search=(root.querySelector('[data-health-search]')?.value||'').trim().toLocaleLowerCase('fr');
 const severity=root.querySelector('[data-health-risk]')?.value||'all';
 root.querySelectorAll('[data-health-row]').forEach(row=>{
  row.hidden=(severity!=='all'&&row.dataset.healthStatus!==severity)||
   !row.dataset.healthName.includes(search);
 });
}
