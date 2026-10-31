/* UI-02B : composants de lecture originaux, autonomes, non raccordés au jeu. */
(function(root, factory) {
  'use strict';
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.CDUI02Components = api;
})(typeof globalThis !== 'undefined' ? globalThis : null, function() {
  'use strict';
  const TABS = Object.freeze({profil:'Profil',attributs:'Attributs',contrat:'Contrat',progression:'Progression'});
  const PRESETS = Object.freeze({overview:'Vue générale',contracts:'Contrats',fitness:'Physique',development:'Développement'});
  const COLUMN_LABELS = Object.freeze({name:'Joueur',position:'Poste',age:'Âge',note:'Note au poste',condition:'Condition',potential:'Potentiel',salary:'Salaire / semaine',contract:'Fin de contrat',minutes:'Minutes',physical:'Charge physique',status:'Statut',injury:'Blessure',development:'Développement'});
  const GROUPS = Object.freeze([
    {name:'Conquête',keys:['scrum','lineout','power']},
    {name:'Défense',keys:['tackle','discipline']},
    {name:'Jeu et technique',keys:['speed','pass','kick','goal']},
    {name:'Mental et endurance',keys:['mental','stamina']}
  ]);
  function escapeHTML(v) {
    return String(v ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;')
      .replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;');
  }
  function finite(v) { return typeof v === 'number' && Number.isFinite(v); }
  function number(v) { return finite(v) ? Math.round(v).toLocaleString('fr-FR') : '—'; }
  function money(v) { return finite(v) ? new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(v) : '—'; }
  function read(v) { return v == null || v === '' ? '—' : String(v); }
  function initials(name) {
    return String(name||'').trim().split(/\s+/).slice(0,2).map(x=>x[0]||'').join('').toLocaleUpperCase('fr') || '?';
  }
  function safePercentage(v) { return finite(v) ? Math.max(0,Math.min(100,v)) : null; }
  function formatValue(key,v) {
    if (v == null || v === '') return '—';
    if (key === 'salary') return money(v);
    if (key === 'contract') return finite(v) ? 'Saison '+number(v) : '—';
    if (key === 'condition') return finite(v) ? number(v)+' %' : '—';
    if (key === 'physical') return finite(v) ? number(v)+'/100' : '—';
    if (key === 'injury') return finite(v) ? (v>0?number(v)+' sem.':'Aucune') : '—';
    if (typeof v === 'number') return number(v);
    if (key === 'development' && v === 'equilibre') return 'Équilibré';
    return read(v);
  }
  function datum(label,value,className='') {
    return '<div class="cd02-datum '+className+'"><dt>'+escapeHTML(label)+'</dt><dd>'+escapeHTML(read(value))+'</dd></div>';
  }
  function progress(label,value,description) {
    const progressValue=safePercentage(value);
    return '<div class="cd02-progress"><div class="cd02-progress-title"><span>'+escapeHTML(label)+
      '</span><strong>'+escapeHTML(description||'—')+'</strong></div>'+
      (progressValue===null?'<span class="cd02-empty">Donnée indisponible</span>':
      '<div class="cd02-progress-track" role="progressbar" aria-label="'+escapeHTML(label)+
      '" aria-valuemin="0" aria-valuemax="100" aria-valuenow="'+progressValue+'"><span style="width:'+progressValue+'%"></span></div>')+'</div>';
  }
  function attributeGroups(attrs) {
    if (!attrs || typeof attrs !== 'object') return '<p class="cd02-empty">Aucun attribut disponible.</p>';
    const seen=new Set(),groups=[];
    for(const g of GROUPS) {
      const entries=g.keys.filter(k=>attrs[k] && typeof attrs[k]==='object').map(k=>{seen.add(k);return [k,attrs[k]]});
      if(entries.length)groups.push([g.name,entries]);
    }
    const other=Object.entries(attrs).filter(([key,v])=>!seen.has(key)&&v&&typeof v==='object');
    if(other.length)groups.push(['Autres qualités',other]);
    return groups.map(([name,items])=>'<section class="cd02-attribute-group" aria-label="'+escapeHTML(name)+'">'+
      '<h3>'+escapeHTML(name)+'</h3>'+
      '<dl>'+items.map(([,a])=>{
        const value=safePercentage(a.value),size=value===null?null:Math.round(value);
        return '<div class="cd02-attribute"><dt>'+escapeHTML(read(a.label))+'</dt><dd>'+
          '<span class="cd02-attribute-number">'+(size===null?'—':size)+'</span>'+
          (size===null?'':'<span class="cd02-attribute-bar" aria-hidden="true"><span style="width:'+size+'%"></span></span>')+
          '</dd></div>';
      }).join('')+'</dl></section>').join('')||'<p class="cd02-empty">Aucun attribut disponible.</p>';
  }
  function historyMarkup(history) {
    if(!Array.isArray(history)||!history.length) return '<p class="cd02-empty">Aucun historique de progression enregistré.</p>';
    return '<div class="cd02-table-scroll"><table class="cd02-table"><caption class="cd02-sr-only">Historique de progression du joueur</caption>'+
      '<thead><tr><th scope="col">Saison</th><th scope="col">Âge</th><th scope="col">Note initiale</th><th scope="col">Note finale</th><th scope="col">Minutes</th><th scope="col">Apparitions</th></tr></thead><tbody>'+
      history.map(r=>'<tr>'+['season','age','start','end','minutes','appearances'].map(k=>'<td>'+escapeHTML(formatValue(k,r?.[k]))+'</td>').join('')+'</tr>').join('')+
      '</tbody></table></div>';
  }
  function profileContent(p,tab) {
    if(tab==='attributs')return '<div class="cd02-attribute-grid">'+attributeGroups(p.attributes)+'</div>';
    if(tab==='contrat')return '<div class="cd02-panels"><section class="cd02-panel"><h3>Contrat professionnel</h3><dl class="cd02-facts">'+
      datum('Salaire hebdomadaire',money(p.salary))+
      datum('Fin de contrat',formatValue('contract',p.contract))+
      datum('Situation dans le groupe',formatValue('status',p.status))+
      '</dl></section><section class="cd02-panel"><h3>Disponibilité</h3><div class="cd02-progress-list">'+
      progress('Condition',p.condition,formatValue('condition',p.condition))+
      progress('Charge physique',p.physical,formatValue('physical',p.physical))+
      '</div>'+datum('Blessure',formatValue('injury',p.injury))+'</section></div>';
    if(tab==='progression')return '<section class="cd02-panel"><h3>Progression en carrière</h3>'+
      '<p class="cd02-help">Historique enregistré dans la carrière. Aucune projection future n’est calculée.</p>'+
      historyMarkup(p.history)+'</section>';
    return '<div class="cd02-panels"><section class="cd02-panel"><h3>Vue d’ensemble</h3>'+
      '<dl class="cd02-facts">'+
      datum('Poste',p.position)+datum('Âge',formatValue('age',p.age))+
      datum('Note au poste',formatValue('note',p.note))+
      datum('Potentiel au poste',formatValue('potential',p.potential))+
      datum('Statut',p.status)+datum('Minutes cette saison',formatValue('minutes',p.minutes))+
      '</dl></section><section class="cd02-panel"><h3>État physique</h3><div class="cd02-progress-list">'+
      progress('Condition',p.condition,formatValue('condition',p.condition))+
      progress('Charge physique',p.physical,formatValue('physical',p.physical))+
      '</div><h3>Contrat</h3><dl class="cd02-facts">'+
      datum('Salaire / semaine',money(p.salary))+
      datum('Échéance',formatValue('contract',p.contract))+
      '</dl></section></div>';
  }
  function renderPlayer(p,options={}) {
    if(!p||typeof p!=='object'||typeof p.id!=='string'||!p.id)throw new TypeError('Profil joueur projeté requis.');
    const tab=Object.prototype.hasOwnProperty.call(TABS,options.tab)?options.tab:'profil';
    const name=read(p.name),position=read(p.position);
    return '<section class="cd02 cd02-player" data-cd02-player="'+escapeHTML(p.id)+'" aria-label="Fiche de '+escapeHTML(name)+'">'+
      '<header class="cd02-player-header">'+
      '<div class="cd02-player-identity">'+
      '<div class="cd02-avatar" aria-hidden="true">'+escapeHTML(initials(p.name))+'</div>'+
      '<div><p class="cd02-kicker">FICHE JOUEUR · RUGBY À XV</p><h2>'+escapeHTML(name)+'</h2>'+
      '<p class="cd02-byline">'+escapeHTML(position)+' <span aria-hidden="true">·</span> '+
      escapeHTML(formatValue('age',p.age))+' ans</p></div></div>'+
      '<div class="cd02-header-meta">'+
      '<span class="cd02-status">'+escapeHTML(read(p.status))+'</span>'+
      '<div class="cd02-score"><span>NOTE AU POSTE</span><strong>'+escapeHTML(formatValue('note',p.note))+'</strong></div>'+
      '<div class="cd02-score"><span>POTENTIEL</span><strong>'+escapeHTML(formatValue('potential',p.potential))+'</strong></div>'+
      '</div></header>'+
      '<div class="cd02-tablist" role="tablist" aria-label="Sections de la fiche joueur">'+
      Object.entries(TABS).map(([key,label])=>
       '<button type="button" role="tab" data-cd02-action="tab" data-cd02-tab="'+key+
       '" aria-selected="'+(key===tab)+'" tabindex="'+(key===tab?'0':'-1')+'">'+label+'</button>').join('')+
      '</div><div class="cd02-player-content" role="tabpanel" aria-label="'+escapeHTML(TABS[tab])+'">'+
      profileContent(p,tab)+'</div></section>';
  }
  function renderTable(table,options={}) {
    if(!table||!Array.isArray(table.columns)||!Array.isArray(table.rows))
      throw new TypeError('Tableau projeté requis.');
    const current=new Set(table.columns.map(c=>c.key));
    const preset=Object.prototype.hasOwnProperty.call(PRESETS,options.preset)?options.preset:'overview';
    const search=options.search||'';
    const picker='<details class="cd02-columns"><summary>Personnaliser les colonnes</summary>'+
      '<fieldset><legend>Colonnes affichées</legend><div class="cd02-column-list">'+
      Object.entries(COLUMN_LABELS).map(([key,label])=>
       '<label><input type="checkbox" data-cd02-action="column" value="'+key+'"'+(current.has(key)?' checked':'')+'>'+
       escapeHTML(label)+'</label>').join('')+'</div></fieldset></details>';
    return '<section class="cd02 cd02-roster" aria-label="Tableau de l’effectif">'+
      '<header class="cd02-roster-head"><div><p class="cd02-kicker">EFFECTIF · PROFESSIONNELS</p>'+
      '<h2>Les joueurs</h2><p class="cd02-help">'+escapeHTML(number(table.total))+' joueur(s) correspondant aux filtres</p></div>'+
      '<div class="cd02-roster-tools"><label>Présentation<select data-cd02-action="preset" aria-label="Présentation de l’effectif">'+
      Object.entries(PRESETS).map(([key,label])=>'<option value="'+key+'"'+(key===preset?' selected':'')+'>'+escapeHTML(label)+'</option>').join('')+
      '</select></label><label>Rechercher<input data-cd02-action="search" type="search" value="'+escapeHTML(search)+'" placeholder="Nom ou poste" autocomplete="off" aria-label="Rechercher un joueur"></label></div></header>'+
      '<div class="cd02-roster-config">'+picker+'</div>'+
      '<div class="cd02-table-scroll"><table class="cd02-table"><caption class="cd02-sr-only">Effectif professionnel, colonnes et tri personnalisables</caption>'+
      '<thead><tr>'+table.columns.map(col=>{
        if(!Object.prototype.hasOwnProperty.call(COLUMN_LABELS,col.key))throw new RangeError('Colonne non reconnue');
        const sorted=table.sortBy===col.key;
        return '<th scope="col" aria-sort="'+(sorted?(table.direction==='desc'?'descending':'ascending'):'none')+'">'+
          '<button type="button" data-cd02-action="sort" data-cd02-sort="'+escapeHTML(col.key)+'">'+
          escapeHTML(COLUMN_LABELS[col.key])+(sorted?(table.direction==='desc'?' ↓':' ↑'):'')+'</button></th>';
      }).join('')+'</tr></thead><tbody>'+
      (table.rows.length?table.rows.map(row=>'<tr data-cd02-row="'+escapeHTML(read(row.id))+'">'+
        table.columns.map(col=>'<td>'+(
          col.key==='name'?'<button type="button" class="cd02-player-link" data-cd02-action="player" data-cd02-id="'+escapeHTML(read(row.id))+'">'+
          escapeHTML(formatValue(col.key,row.cells?.[col.key]))+'</button>':
          escapeHTML(formatValue(col.key,row.cells?.[col.key]))
        )+'</td>').join('')+'</tr>').join(''):
        '<tr><td class="cd02-empty" colspan="'+table.columns.length+'">Aucun joueur ne correspond aux critères.</td></tr>')+
      '</tbody></table></div></section>';
  }
  function renderComparison(compare) {
    if(!compare||!Array.isArray(compare.players)||compare.players.length!==2||!Array.isArray(compare.rows))
      throw new TypeError('Comparaison de deux joueurs requise.');
    const names=compare.players.map(p=>read(p.name));
    return '<section class="cd02 cd02-comparison" aria-label="Comparaison des joueurs">'+
      '<header><p class="cd02-kicker">ANALYSE DE L’EFFECTIF</p><h2>Comparer les profils</h2>'+
      (compare.sameFamily?'':'<p class="cd02-notice">Postes différents : comparez les qualités pertinentes plutôt que les seules notes générales.</p>')+'</header>'+
      '<div class="cd02-table-scroll"><table class="cd02-table"><caption class="cd02-sr-only">Comparaison de deux joueurs</caption>'+
      '<thead><tr><th scope="col">Critère</th>'+names.map(n=>'<th scope="col">'+escapeHTML(n)+'</th>').join('')+'</tr></thead><tbody>'+
      compare.rows.map(row=>'<tr><th scope="row">'+escapeHTML(read(row.label))+'</th>'+
      [0,1].map(i=>'<td>'+escapeHTML(formatValue(row.key,row.values?.[i]))+'</td>').join('')+'</tr>').join('')+
      '</tbody></table></div></section>';
  }
  function bindActions(root,handlers={}) {
    if(!root||typeof root.addEventListener!=='function'||typeof root.removeEventListener!=='function')
      throw new TypeError('Conteneur DOM requis.');
    const actionTarget=event=>{
      const target=event.target;
      const btn=target && typeof target.closest==='function'?target.closest('[data-cd02-action]'):null;
      if(!btn || (typeof root.contains==='function'&&!root.contains(btn)))return null;
      return btn;
    };
    const click=event=>{
      const el=actionTarget(event);if(!el)return;
      const action=el.getAttribute('data-cd02-action');
      if(action==='tab')handlers.onTab?.(el.getAttribute('data-cd02-tab'));
      if(action==='sort')handlers.onSort?.(el.getAttribute('data-cd02-sort'));
      if(action==='player')handlers.onPlayer?.(el.getAttribute('data-cd02-id'));
    };
    const change=event=>{
      const el=actionTarget(event);if(!el)return;
      const action=el.getAttribute('data-cd02-action');
      if(action==='preset')handlers.onPreset?.(el.value);
      if(action==='column'&&typeof handlers.onColumns==='function'&&typeof root.querySelectorAll==='function'){
        const values=Array.from(root.querySelectorAll('input[data-cd02-action="column"]:checked')).map(n=>n.value);
        if(values.length)handlers.onColumns(values);
      }
    };
    const input=event=>{
      const el=actionTarget(event);
      if(el?.getAttribute('data-cd02-action')==='search')handlers.onSearch?.(el.value);
    };
    root.addEventListener('click',click);
    root.addEventListener('change',change);
    root.addEventListener('input',input);
    return function dispose(){
      root.removeEventListener('click',click);
      root.removeEventListener('change',change);
      root.removeEventListener('input',input);
    };
  }
  return Object.freeze({TABS,PRESETS,COLUMN_LABELS,escapeHTML,formatValue,renderPlayer,renderTable,renderComparison,bindActions});
});
