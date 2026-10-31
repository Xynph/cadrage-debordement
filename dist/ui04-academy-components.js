/* UI-04A — formation, présentation originale sans branchement au jeu. */
(function(root,build){
 'use strict';
 const api=build();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDUI04AcademyComponents=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 'use strict';
 const TABS=Object.freeze({overview:'Vue d’ensemble',academy:'Centre de formation',young:'Jeunes professionnels',history:'Archives'});
 const SORTS=Object.freeze({name:'Joueur',age:'Âge',position:'Poste',note:'Note au poste',
  potential:'Potentiel au poste',gain:'Gain cette saison',minutes:'Minutes',focus:'Objectif individuel'});
 function esc(v){return String(v??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;')}
 function number(v){return typeof v==='number'&&Number.isFinite(v)?new Intl.NumberFormat('fr-FR',{maximumFractionDigits:0}).format(v):'—'}
 function signed(v){return typeof v==='number'&&Number.isFinite(v)?(v>0?'+':'')+number(v):'—'}
 function nameForFocus(key,labels={}){
  return key==='equilibre'?'Équilibré':typeof labels[key]==='string'?labels[key]:key||'Aucun objectif';
 }
 function kpi(label,value,detail){
  return '<div class="cd04-kpi"><span>'+esc(label)+'</span><strong>'+number(value)+'</strong><small>'+esc(detail)+'</small></div>';
 }
 function overview(model){
  const top=model.academy.slice().sort((a,b)=>(b.potential??-1)-(a.potential??-1)||a.name.localeCompare(b.name,'fr')).slice(0,5);
  return '<div class="cd04-columns"><section class="cd04-panel"><div class="cd04-panel-head">'+
    '<div><p class="cd04-kicker">ACADÉMIE · PLAFONDS NATIFS</p><h3>Espoirs du centre</h3></div>'+
    '<button type="button" data-ui04-action="tab" data-ui04-tab="academy">Voir tous les espoirs</button></div>'+
    '<p class="cd04-muted">Le potentiel est un plafond fictif, jamais une progression garantie.</p>'+
    (top.length?'<div class="cd04-ranks">'+top.map(p=>'<article>'+
      '<div><strong>'+esc(p.name)+'</strong><small>'+esc(p.position)+' · '+number(p.age)+' ans</small></div>'+
      '<div class="cd04-ranks-fig"><strong>'+number(p.note)+'</strong><span aria-label="Potentiel au poste '+number(p.potential)+'">/ '+number(p.potential)+'</span></div>'+
      '</article>').join('')+'</div>':'<p class="cd04-empty">Aucun espoir actuellement dans le centre.</p>')+
    '</section><section class="cd04-panel">'+
    '<div class="cd04-panel-head"><div><p class="cd04-kicker">PASSERELLE VERS LES PROS</p><h3>Développer la relève</h3></div></div>'+
    '<p class="cd04-muted">La promotion utilise uniquement la commande native et la limite de 42 joueurs.</p>'+
    '<dl class="cd04-facts"><div><dt>Places restantes chez les pros</dt><dd>'+number(model.totals.promotionSlots)+'</dd></div>'+
    '<div><dt>Jeunes pros (23 ans et moins)</dt><dd>'+number(model.totals.young)+'</dd></div>'+
    '<div><dt>Minutes des jeunes pros cette saison</dt><dd>'+number(model.totals.youngMinutes)+'</dd></div>'+
    '<div><dt>Retraites à anticiper</dt><dd>'+number(model.totals.retirementRisk)+'</dd></div></dl>'+
    '<button type="button" data-ui04-action="tab" data-ui04-tab="young">Suivre les jeunes professionnels</button></section></div>';
 }
 function filters(table,options){
  const family=options.family==null?'all':String(options.family);
  return '<div class="cd04-filters"><label>Rechercher<input type="search" data-ui04-action="search" value="'+esc(options.search||'')+
    '" placeholder="Nom ou poste" autocomplete="off"></label>'+
    '<label>Famille de poste<select data-ui04-action="family"><option value="all">Toutes les familles</option>'+
    Array.from({length:9},(_,i)=>'<option value="'+i+'"'+(family===String(i)?' selected':'')+'>Famille '+i+'</option>').join('')+
    '</select></label>'+
    '<span class="cd04-muted">'+number(table.total)+' joueur(s)</span></div>';
 }
 function scoreCell(v){return '<strong class="cd04-score">'+number(v)+'</strong>'}
 function tableRows(table,options){
  const academy=table.kind==='academy';
  return '<section class="cd04-panel"><div class="cd04-panel-head"><div>'+
    '<p class="cd04-kicker">'+(academy?'CENTRE DE FORMATION':'JEUNES PROFESSIONNELS')+'</p>'+
    '<h3>'+(academy?'Les espoirs':'Les professionnels de 23 ans ou moins')+'</h3></div></div>'+
    '<p class="cd04-muted">'+(academy?
     'Les espoirs ne disputent pas de championnat de jeunes dans cette version.':'Le temps de jeu comptabilisé est celui de la carrière réelle.')+
    '</p>'+filters(table,options)+
    '<div class="cd04-scroll"><table class="cd04-table"><caption class="cd04-sr">Suivi du développement des joueurs du club</caption>'+
    '<thead><tr>'+
    Object.entries({name:'Joueur',position:'Poste',age:'Âge',note:'Note',potential:'Potentiel',
      gain:'Gain',minutes:'Minutes',focus:'Objectif'}).map(([key,label])=>
      '<th scope="col" aria-sort="'+(table.sortBy===key?(table.direction==='desc'?'descending':'ascending'):'none')+'">'+
      '<button type="button" data-ui04-action="sort" data-ui04-sort="'+key+'">'+esc(label)+
      (table.sortBy===key?(table.direction==='desc'?' ↓':' ↑'):'')+'</button></th>').join('')+
    '<th scope="col">Décision</th></tr></thead><tbody>'+
    (table.rows.length?table.rows.map(p=>
      '<tr><td><button type="button" class="cd04-player-link" data-ui04-action="details" data-ui04-id="'+esc(p.id)+'">'+esc(p.name)+'</button></td>'+
      '<td>'+esc(p.position)+'</td><td>'+number(p.age)+'</td>'+
      '<td>'+scoreCell(p.note)+'</td><td>'+scoreCell(p.potential)+'</td>'+
      '<td>'+signed(p.gain)+'</td><td>'+number(p.minutes)+'</td>'+
      '<td>'+esc(nameForFocus(p.focus,options.attributeLabels))+'</td><td>'+
      (academy?'<button type="button" class="cd04-promote" data-ui04-action="promote" data-ui04-id="'+esc(p.id)+'"'+
       (p.canPromote?'':' disabled')+' title="'+esc(p.promotionBlockedReason||'Signer un contrat professionnel')+'">'+
       'Promouvoir</button>':
       '<span class="cd04-muted">'+esc(p.badge)+'</span>')+
      '</td></tr>').join(''):'<tr><td colspan="9" class="cd04-empty">Aucun joueur ne correspond aux critères.</td></tr>')+
    '</tbody></table></div></section>';
 }
 function focusControls(p,options){
  const disabled=options.locked?' disabled':'';
  const focusOptions=Array.isArray(p.focusOptions)?p.focusOptions:[];
  return '<label class="cd04-focus">Objectif individuel<select data-ui04-action="focus" data-ui04-id="'+esc(p.id)+'"'+disabled+
   ' aria-label="Objectif individuel de '+esc(p.name)+'">'+
   focusOptions.map(k=>'<option value="'+esc(k)+'"'+(k===p.focus?' selected':'')+'>'+
     esc(nameForFocus(k,options.attributeLabels))+'</option>').join('')+'</select></label>';
 }
 function detail(p,options){
  if(!p)return '';
  return '<section class="cd04-panel cd04-detail" aria-label="Détail de '+esc(p.name)+'">'+
   '<div class="cd04-panel-head"><div><p class="cd04-kicker">SUIVI INDIVIDUEL</p><h3>'+esc(p.name)+'</h3>'+
   '<p class="cd04-muted">'+esc(p.position)+' · '+number(p.age)+' ans · '+esc(p.badge)+'</p></div>'+
   '<button type="button" data-ui04-action="close">Fermer le détail</button></div>'+
   '<div class="cd04-mini-kpis">'+
   '<div><span>Note actuelle</span><strong>'+number(p.note)+'</strong></div>'+
   '<div><span>Potentiel au poste</span><strong>'+number(p.potential)+'</strong></div>'+
   '<div><span>Gain général</span><strong>'+signed(p.gain)+'</strong></div>'+
   '<div><span>Minutes de saison</span><strong>'+number(p.minutes)+'</strong></div></div>'+
   '<div class="cd04-detail-action">'+focusControls(p,options)+
   (p.kind==='academy'?'<button type="button" data-ui04-action="promote" data-ui04-id="'+esc(p.id)+'"'+
    (p.canPromote?'':' disabled')+' title="'+esc(p.promotionBlockedReason||'Promouvoir en équipe professionnelle')+'">Promouvoir en équipe pro</button>':'')+
   '<button type="button" data-ui04-action="native" data-ui04-id="'+esc(p.id)+'">Ouvrir la fiche de carrière</button></div>'+
   '<p class="cd04-muted">Les choix d’entraînement et la promotion passent par les commandes officielles du jeu lors du raccordement.</p>'+
   '<div class="cd04-history"><h4>Historique des saisons</h4>'+
   (p.history?.length?'<div class="cd04-scroll"><table class="cd04-table"><thead><tr>'+
    '<th scope="col">Saison</th><th scope="col">Âge</th><th scope="col">Niveau initial</th>'+
    '<th scope="col">Niveau final</th><th scope="col">Minutes</th><th scope="col">Apparitions</th></tr></thead><tbody>'+
    p.history.map(h=>'<tr>'+['season','age','start','end','minutes','appearances'].map(k=>'<td>'+number(h[k])+'</td>').join('')+'</tr>').join('')+
    '</tbody></table></div>':'<p class="cd04-empty">Pas encore d’historique enregistré pour ce joueur.</p>')+'</div></section>';
 }
 function archives(model){
  return '<section class="cd04-panel"><div class="cd04-panel-head"><div><p class="cd04-kicker">HISTORIQUE RÉEL</p>'+
   '<h3>Départs à la retraite enregistrés</h3></div></div>'+
   (model.retired.length?'<div class="cd04-scroll"><table class="cd04-table"><caption class="cd04-sr">Retraites du club</caption>'+
    '<thead><tr><th scope="col">Joueur</th><th scope="col">Saison</th><th scope="col">Âge</th>'+
    '<th scope="col">Minutes de carrière</th></tr></thead><tbody>'+
    model.retired.map(r=>'<tr><th scope="row">'+esc(r.name)+'</th><td>'+number(r.season)+'</td>'+
     '<td>'+number(r.age)+'</td><td>'+number(r.careerMinutes)+'</td></tr>').join('')+
    '</tbody></table></div>':'<p class="cd04-empty">Aucun départ à la retraite encore enregistré dans ce club.</p>')+
   '</section>';
 }
 function renderCenter(model,options={}){
  if(!model||model.version!==1||!model.totals||!Array.isArray(model.academy)||!Array.isArray(model.young))
   throw new TypeError('Données projetées du centre de formation requises');
  const view=Object.prototype.hasOwnProperty.call(TABS,options.view)?options.view:'overview';
  const t=options.table;
  if((view==='academy'||view==='young')&&(!t||!Array.isArray(t.rows)))
   throw new TypeError('Tableau filtré requis pour cette vue');
  const detailId=options.selectedId||null;
  const selected=detailId?[...model.academy,...model.young].find(p=>p.id===detailId):null;
  return '<section class="cd04" aria-label="Centre de formation">'+
   '<header class="cd04-header"><div><p class="cd04-kicker">CADRAGE DÉBORDEMENT · FORMATION</p>'+
   '<h2>Le centre de formation</h2><p>Préparer la relève et accompagner les jeunes talents du club.</p></div>'+
   '<span class="cd04-season">Saison '+number(model.season)+'</span></header>'+
   '<div class="cd04-kpis">'+
   kpi('Espoirs',model.totals.academy,'Au centre de formation')+
   kpi('Jeunes pros',model.totals.young,'23 ans ou moins')+
   kpi('Minutes des jeunes pros',model.totals.youngMinutes,'Cette saison')+
   kpi('Gain du groupe',model.totals.groupGain,'Niveau général, points acquis')+'</div>'+
   '<nav class="cd04-tabs" aria-label="Rubriques formation">'+
   Object.entries(TABS).map(([key,title])=>'<button type="button" data-ui04-action="tab" data-ui04-tab="'+key+'"'+
    (view===key?' aria-current="page"':'')+'>'+esc(title)+'</button>').join('')+'</nav>'+
   '<div class="cd04-content">'+
   (view==='overview'?overview(model):view==='history'?archives(model):tableRows(t,{...options,locked:model.locked}))+
   (selected?detail(selected,{...options,locked:model.locked}):'')+
   '</div></section>';
 }
 function bindActions(root,handlers={}){
  if(!root||typeof root.addEventListener!=='function'||typeof root.removeEventListener!=='function')
   throw new TypeError('Conteneur de présentation requis');
  const target=e=>{
   const el=e.target?.closest?.('[data-ui04-action]');
   return el&&(!root.contains||root.contains(el))?el:null;
  };
  const click=e=>{
   const el=target(e);if(!el)return;
   const action=el.getAttribute('data-ui04-action');
   if(action==='tab')handlers.onTab?.(el.getAttribute('data-ui04-tab'));
   if(action==='sort')handlers.onSort?.(el.getAttribute('data-ui04-sort'));
   if(action==='details')handlers.onDetails?.(el.getAttribute('data-ui04-id'));
   if(action==='promote'&&!el.disabled)handlers.onPromote?.(el.getAttribute('data-ui04-id'));
   if(action==='native')handlers.onNativeProfile?.(el.getAttribute('data-ui04-id'));
   if(action==='close')handlers.onClose?.();
  };
  const change=e=>{
   const el=target(e);if(!el)return;
   const action=el.getAttribute('data-ui04-action');
   if(action==='family')handlers.onFamily?.(el.value);
   if(action==='focus'&&!el.disabled)handlers.onFocus?.(el.getAttribute('data-ui04-id'),el.value);
  };
  const input=e=>{
   const el=target(e);
   if(el?.getAttribute('data-ui04-action')==='search')handlers.onSearch?.(el.value);
  };
  root.addEventListener('click',click);root.addEventListener('change',change);root.addEventListener('input',input);
  return ()=>{root.removeEventListener('click',click);root.removeEventListener('change',change);root.removeEventListener('input',input)};
 }
 return Object.freeze({TABS,SORTS,esc,renderCenter,bindActions});
});