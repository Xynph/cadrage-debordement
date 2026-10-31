/* UI-03A — composants de présentation statiques, aucun appel de simulation. */
(function(root,build){
  'use strict';
  const api=build();
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.CDUI03ScoutComponents=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
  'use strict';
  const TABS=Object.freeze({overview:'Vue d’ensemble',candidates:'Candidats',reports:'Rapports',missions:'Missions',watch:'Suivis'});
  const SORT=Object.freeze({name:'Nom',position:'Poste',age:'Âge',salary:'Salaire',price:'Prime',noteMin:'Niveau estimé'});
  function esc(v){return String(v??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');}
  function number(v){return typeof v==='number'&&Number.isFinite(v)?new Intl.NumberFormat('fr-FR',{maximumFractionDigits:0}).format(v):'—';}
  function money(v){return typeof v==='number'&&Number.isFinite(v)?new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(v):'—';}
  function range(min,max){return min==null||max==null?'Non connu':number(min)+'–'+number(max);}
  function safeRows(rows){return Array.isArray(rows)?rows:[];}
  function empty(message){return '<p class="cd03-empty">'+esc(message)+'</p>';}
  function tabButtons(view,model){
    return '<nav class="cd03-tabs" aria-label="Sections du recrutement">'+Object.entries(TABS).map(([key,label])=>
      '<button type="button" data-ui03-action="tab" data-ui03-tab="'+key+'"'+(view===key?' aria-current="page"':'')+'>'+
      esc(label)+(key==='reports'?' <span>('+number(model.totals?.reports)+')</span>':'')+'</button>').join('')+'</nav>';
  }
  function insight(model){
    const cards=[
      ['Candidats',model.totals?.candidates],
      ['Rapports connus',model.totals?.reports],
      ['Missions actives',model.totals?.active],
      ['Profils suivis',model.totals?.watch]
    ];
    return '<div class="cd03-kpis">'+cards.map(([label,value])=>
      '<div class="cd03-kpi"><span>'+esc(label)+'</span><strong>'+number(value)+'</strong></div>').join('')+'</div>';
  }
  function overview(model){
    const needs=safeRows(model.needs).slice(0,6);
    return '<div class="cd03-columns">'+
      '<section class="cd03-panel"><div class="cd03-section-title"><div><p class="cd03-overline">BESOINS SPORTIFS · NATIFS</p><h3>Postes à renforcer</h3></div>'+
      '<button type="button" data-ui03-action="tab" data-ui03-tab="candidates">Voir les candidats</button></div>'+
      '<p class="cd03-caption">Diagnostic calculé par le moteur du club : effectif apte, contrats et relève.</p>'+
      (needs.length?'<ol class="cd03-needs">'+needs.map(n=>
       '<li><div><strong>'+esc(n.position)+'</strong><small>'+safeRows(n.reasons).map(esc).join(' · ')+'</small></div>'+
       '<span aria-label="Priorité '+number(n.score)+' sur 100">'+number(n.score)+'/100</span></li>').join('')+'</ol>':
       empty('Aucun diagnostic disponible.'))+'</section>'+
      '<section class="cd03-panel"><div class="cd03-section-title"><div><p class="cd03-overline">CELLULE DE RECRUTEMENT</p><h3>Activité du recruteur</h3></div></div>'+
      '<dl class="cd03-activity"><div><dt>Missions actives</dt><dd>'+number(model.totals?.active)+'</dd></div>'+
      '<div><dt>Missions en attente</dt><dd>'+number(model.totals?.queued)+'</dd></div>'+
      '<div><dt>Rapports établis</dt><dd>'+number(model.totals?.reports)+'</dd></div></dl>'+
      '<p class="cd03-caption">Un rapport reste daté : la précision de son évaluation diminue avec le temps selon les règles natives.</p>'+
      '<button type="button" data-ui03-action="tab" data-ui03-tab="missions">Consulter les missions</button></section></div>';
  }
  function candidateTable(table,opts={}){
    if(!table||!Array.isArray(table.rows))throw new TypeError('Tableau filtré de candidats requis.');
    const family=opts.family===undefined?'all':String(opts.family);
    const sort=Object.prototype.hasOwnProperty.call(SORT,table.sortBy)?table.sortBy:'name';
    const ariaSort=table.direction==='desc'?'descending':'ascending';
    return '<section class="cd03-panel cd03-candidates"><div class="cd03-section-title">'+
      '<div><p class="cd03-overline">JOUEURS DISPONIBLES · INFORMATIONS CONNUES</p><h3>Explorer les candidats</h3>'+
      '<p class="cd03-caption">'+number(table.total)+' profil(s) trouvé(s)</p></div></div>'+
      '<div class="cd03-filters">'+
      '<label>Rechercher<input type="search" data-ui03-action="search" value="'+esc(opts.search||'')+'" placeholder="Nom ou poste" autocomplete="off"></label>'+
      '<label>Famille de poste<select data-ui03-action="family"><option value="all">Tous les postes</option>'+
      Array.from({length:9},(_,i)=>'<option value="'+i+'"'+(family===String(i)?' selected':'')+'>'+(i+1)+' · Famille '+i+'</option>').join('')+
      '</select></label>'+
      '<label class="cd03-check"><input type="checkbox" data-ui03-action="observed"'+(opts.observedOnly?' checked':'')+'>Avec rapport</label>'+
      '<label class="cd03-check"><input type="checkbox" data-ui03-action="watched"'+(opts.watchedOnly?' checked':'')+'>Suivis</label></div>'+
      '<p class="cd03-caption">Sans rapport, seule une fourchette indicative publique est visible. Aucun potentiel caché n’est affiché.</p>'+
      '<div class="cd03-table-scroll"><table class="cd03-table"><caption class="cd03-sr">Candidats du marché, estimations et coûts connus</caption><thead><tr>'+
      [['name','Joueur'],['position','Poste'],['age','Âge'],['noteMin','Niveau estimé'],['price','Prime'],['salary','Salaire / semaine']].map(([key,label])=>
        '<th scope="col" aria-sort="'+(sort===key?ariaSort:'none')+'">'+
        '<button type="button" data-ui03-action="sort" data-ui03-sort="'+key+'">'+esc(label)+(sort===key?(table.direction==='desc'?' ↓':' ↑'):'')+'</button></th>'
      ).join('')+'<th scope="col">Connaissance</th><th scope="col">Actions</th></tr></thead><tbody>'+
      (table.rows.length?table.rows.map(p=>
        '<tr><td><button type="button" class="cd03-name" data-ui03-action="candidate" data-ui03-id="'+esc(p.id)+'">'+esc(p.name)+'</button></td>'+
        '<td>'+esc(p.position)+'</td><td>'+number(p.age)+'</td>'+
        '<td>'+esc(range(p.noteMin,p.noteMax))+'</td>'+
        '<td>'+esc(money(p.price))+'</td><td>'+esc(money(p.salary))+'</td>'+
        '<td>'+esc(p.observed?(p.stale?'Rapport ancien':'Rapport disponible'):'Non observé')+
        (p.observed?'<small>Potentiel estimé : '+esc(range(p.potentialMin,p.potentialMax))+'</small>':'<small>Potentiel inconnu</small>')+
        '</td><td><button type="button" data-ui03-action="watch" data-ui03-id="'+esc(p.id)+'" aria-pressed="'+!!p.watched+'">'+
        (p.watched?'Ne plus suivre':'Suivre')+'</button></td></tr>'
      ).join(''):'<tr><td colspan="8">Aucun candidat ne correspond aux critères.</td></tr>')+
      '</tbody></table></div></section>';
  }
  function reports(model){
    const rows=safeRows(model.reports);
    return '<section class="cd03-panel"><div class="cd03-section-title"><div><p class="cd03-overline">OBSERVATIONS DATEES</p>'+
      '<h3>Rapports reçus</h3></div></div><p class="cd03-caption">Les notes et potentiels ci-dessous sont des évaluations enregistrées au moment du rapport, pas la valeur actuelle garantie.</p>'+
      '<div class="cd03-report-grid">'+(rows.length?rows.map(r=>
        '<article class="cd03-report"><div class="cd03-report-top"><span>Rapport '+esc(r.grade||'—')+'</span>'+
        '<small>S'+number(r.season)+' · semaine '+number(r.week)+'</small></div>'+
        '<h4>'+esc(r.name)+'</h4><p>'+esc(r.position)+' · '+number(r.ageAtReport)+' ans lors du rapport</p>'+
        '<dl><div><dt>Niveau observé</dt><dd>'+number(r.noteAtReport)+'</dd></div>'+
        '<div><dt>Potentiel observé</dt><dd>'+number(r.potentialAtReport)+'</dd></div>'+
        '<div><dt>Prime constatée</dt><dd>'+esc(money(r.priceAtReport))+'</dd></div>'+
        '<div><dt>Salaire constaté</dt><dd>'+esc(money(r.salaryAtReport))+'</dd></div></dl>'+
        '<p class="cd03-availability">'+(r.available?'Disponible au dernier relevé':'Indisponible dans le marché actuel')+'</p>'+
        (r.available?'<button type="button" data-ui03-action="candidate" data-ui03-id="'+esc(r.playerId)+'">Voir le candidat</button>':'')+
        '</article>').join(''):empty('Aucun rapport pour le moment. Les missions produisent des observations datées.'))+
      '</div></section>';
  }
  function missions(model){
    const rows=safeRows(model.missions);
    return '<div class="cd03-columns"><section class="cd03-panel"><p class="cd03-overline">MISSIONS NATIVES</p><h3>Confier une recherche</h3>'+
      '<p class="cd03-caption">Une mission coûte 5 000 €, dure deux journées, puis produit un rapport selon les règles du jeu. Le raccordement futur utilisera la commande existante.</p>'+
      '<form class="cd03-mission-form" data-ui03-mission>'+
      '<label>Famille de poste<select name="family" required>'+
      Array.from({length:9},(_,i)=>'<option value="'+i+'">Famille '+i+'</option>').join('')+'</select></label>'+
      '<label>Âge maximum<input name="age" type="number" min="18" max="40" value="28" required></label>'+
      '<label>Prime maximale (€)<input name="fee" type="number" min="0" max="10000000" value="700000" required></label>'+
      '<label>Salaire maximum / semaine (€)<input name="salary" type="number" min="1000" max="100000" value="12000" required></label>'+
      '<button type="submit">Confier la mission</button></form></section>'+
      '<section class="cd03-panel"><p class="cd03-overline">JOURNAL DES MISSIONS</p><h3>Activité et file d’attente</h3>'+
      (rows.length?'<ol class="cd03-missions">'+rows.map(m=>
        '<li><div><strong>Famille '+number(m.family)+'</strong><small>'+
        (m.status==='active'?'Active':m.status==='queued'?'En attente':m.status==='done'?'Terminée':'Statut inconnu')+
        (m.status==='active'?' · '+number(m.remaining)+' journée(s) restante(s)':'')+'</small></div>'+
        '<span>Âge ≤ '+number(m.maxAge)+'<small>Prime ≤ '+esc(money(m.maxFee))+'</small><small>Salaire ≤ '+esc(money(m.maxSalary))+'</small></span></li>'
      ).join('')+'</ol>':empty('Aucune mission enregistrée.'))+'</section></div>';
  }
  function followed(model){
    const rows=safeRows(model.watch);
    return '<section class="cd03-panel"><p class="cd03-overline">VOTRE SUIVI</p><h3>Joueurs suivis</h3>'+
      (rows.length?'<div class="cd03-follow-list">'+rows.map(r=>
        '<article><div><strong>'+esc(r.name||'Profil indisponible')+'</strong><p>'+esc(r.position||'Poste inconnu')+' · '+(r.available?'Marché actuel':'Plus disponible')+'</p>'+
        '<small>'+(r.available?esc(range(r.noteMin,r.noteMax))+(r.observed?' · Rapport disponible':' · Non observé'):
         'Les anciennes données ne sont pas actualisées.')+'</small></div>'+
        '<button type="button" data-ui03-action="watch" data-ui03-id="'+esc(r.id)+'" aria-label="Ne plus suivre '+esc(r.name||'ce joueur')+'">Ne plus suivre</button></article>'
      ).join('')+'</div>':empty('Aucun joueur suivi actuellement.'))+'</section>';
  }
  function renderCenter(model,opts={}){
    if(!model||model.version!==1||!model.totals)throw new TypeError('Centre de recrutement projeté requis.');
    const view=Object.prototype.hasOwnProperty.call(TABS,opts.view)?opts.view:'overview';
    const filtered=opts.table||{rows:model.candidates,total:model.candidates.length,sortBy:'name',direction:'asc'};
    return '<section class="cd03" aria-label="Centre de recrutement">'+
      '<header class="cd03-header"><div><p class="cd03-overline">CADRAGE DÉBORDEMENT · RECRUTEMENT</p><h2>La cellule de recrutement</h2>'+
      '<p>Suivre vos besoins, explorer le marché et analyser les rapports sans inventer de données cachées.</p></div>'+
      '<div class="cd03-season">Saison '+number(model.season)+' <span>·</span> Semaine '+number(model.week)+'</div></header>'+
      insight(model)+tabButtons(view,model)+
      '<div class="cd03-content">'+
      (view==='overview'?overview(model):view==='candidates'?candidateTable(filtered,opts):
       view==='reports'?reports(model):view==='missions'?missions(model):followed(model))+
      '</div></section>';
  }
  function bindActions(root,handlers={}){
    if(!root||typeof root.addEventListener!=='function'||typeof root.removeEventListener!=='function')
      throw new TypeError('Conteneur DOM requis.');
    function target(e){
      const el=e.target?.closest?.('[data-ui03-action]');
      return el&&(!root.contains||root.contains(el))?el:null;
    }
    function click(e){
      const el=target(e);if(!el)return;
      const action=el.getAttribute('data-ui03-action');
      if(action==='tab')handlers.onTab?.(el.getAttribute('data-ui03-tab'));
      if(action==='sort')handlers.onSort?.(el.getAttribute('data-ui03-sort'));
      if(action==='watch')handlers.onWatch?.(el.getAttribute('data-ui03-id'));
      if(action==='candidate')handlers.onCandidate?.(el.getAttribute('data-ui03-id'));
    }
    function change(e){
      const el=target(e);if(!el)return;
      const action=el.getAttribute('data-ui03-action');
      if(action==='family')handlers.onFamily?.(el.value);
      if(action==='observed')handlers.onObservedOnly?.(!!el.checked);
      if(action==='watched')handlers.onWatchedOnly?.(!!el.checked);
    }
    function input(e){
      const el=target(e);
      if(el?.getAttribute('data-ui03-action')==='search')handlers.onSearch?.(el.value);
    }
    function submit(e){
      const form=e.target;
      if(!form?.matches?.('[data-ui03-mission]')||root.contains&&!root.contains(form))return;
      e.preventDefault();
      const get=k=>Number(form.elements.namedItem(k)?.value);
      const args={family:get('family'),maxAge:get('age'),budget:get('fee'),maxWage:get('salary')};
      if(!Number.isInteger(args.family)||args.family<0||args.family>8||
        !Number.isInteger(args.maxAge)||args.maxAge<18||args.maxAge>40||
        !Number.isInteger(args.budget)||args.budget<0||args.budget>10000000||
        !Number.isInteger(args.maxWage)||args.maxWage<1000||args.maxWage>100000)return;
      handlers.onMission?.(args);
    }
    root.addEventListener('click',click);root.addEventListener('change',change);
    root.addEventListener('input',input);root.addEventListener('submit',submit);
    return ()=>{root.removeEventListener('click',click);root.removeEventListener('change',change);
      root.removeEventListener('input',input);root.removeEventListener('submit',submit)};
  }
  return Object.freeze({TABS,esc,range,renderCenter,bindActions});
});