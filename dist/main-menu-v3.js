'use strict';
// Presentation only: career storage, import review and match controls remain native.
const CDMenuV3=(()=>{
 const escape=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 let menuFocus=null,dialogTrigger=null;
 const prefs={contrast:['standard','high'],text:['normal','large']};
 function preference(key){try{const v=gameStorage.getItem('cd-menu-'+key+'-v3');return prefs[key]?.includes(v)?v:prefs[key]?.[0]}catch(_){return prefs[key]?.[0]}}
 function applyPreferences(){for(const k of Object.keys(prefs))document.documentElement?.setAttribute?.('data-menu-'+k,preference(k))}
 function setPreference(key,value){if(!prefs[key]?.includes(value))return false;try{gameStorage.setItem('cd-menu-'+key+'-v3',value)}catch(e){toast('Réglage non enregistré : stockage indisponible.');return false}applyPreferences();render();return true}
 function date(value){const d=new Date(value);return Number.isFinite(d.getTime())?new Intl.DateTimeFormat('fr-FR',{dateStyle:'medium',timeStyle:'short'}).format(d):'Date indisponible'}
 function summary(s){return 'Saison '+s.season+' · '+(s.phase==='league'?'Journée '+(s.round+1):s.phase==='ended'?'Saison terminée':'Phases finales')}
 function crest(c){return '<span class="cd3-crest" aria-hidden="true">'+escape(c.abbr)+'</span>'}
 function cards(){
  let d;try{d=CDMenuSlots.list()}catch(e){return '<div class="cd3-alert" role="alert">'+escape(e.message)+'</div>'}
  const rows=Array.from({length:CDMenuSlots.max},(_,i)=>{
   const item=d.items[i],number=String(i+1).padStart(2,'0');
   if(!item)return '<article class="cd3-career cd3-empty"><span class="cd3-slot-number">'+number+'</span><button class="cd3-create" onclick="mainMenuNewCareer()" aria-label="Créer une carrière dans l’emplacement '+number+'"><span class="cd3-add" aria-hidden="true">+</span><span class="cd3-empty-copy"><strong>Emplacement libre</strong><small>Commencer une nouvelle carrière</small></span><span class="cd3-chevron" aria-hidden="true">›</span></button></article>';
   let state;try{state=CDMenuSlots.restore(item.id);if(!state.clubs?.[state.club]||!Number.isInteger(state.season)||!Number.isInteger(state.round))throw Error('Métadonnées invalides')}catch(_){return '<article class="cd3-career cd3-broken"><span class="cd3-slot-number">'+number+'</span><div class="cd3-broken-copy"><h3>Copie illisible</h3><p>Chargement bloqué. La carrière active et les exports restent conservés.</p></div><button onclick="mainMenuSlotDelete(\''+item.id+'\')">Supprimer cette copie</button></article>'}
   const club=state.clubs[state.club],total=Array.isArray(state.schedule)?state.schedule.length:0,done=Math.min(total,Math.max(0,state.round));
   const current=item.id===d.active;
   return '<article class="cd3-career '+(current?'cd3-active':'')+'"><span class="cd3-slot-number">'+number+'</span><div class="cd3-club">'+crest(club)+'<div class="cd3-club-copy"><h3>'+escape(club.name)+'</h3><p>'+escape(summary(state))+'</p><span class="cd3-season-progress">'+done+' / '+total+' journées jouées</span></div></div><div class="cd3-card-scene" aria-hidden="true"></div><div class="cd3-card-meta"><span>Dernière sauvegarde</span><time datetime="'+escape(item.updatedAt)+'">'+escape(date(item.updatedAt))+'</time><span class="cd3-universe">'+(state.lnrMode?'LNR · simulation':'Univers fictif')+'</span></div><div class="cd3-card-actions"><button class="cd3-resume" data-menu-focus="slot-'+item.id+'" aria-label="Reprendre '+escape(club.name)+'" onclick="mainMenuSlotOpen(\''+item.id+'\')"><span aria-hidden="true">›</span></button><button class="cd3-delete" aria-label="Supprimer la copie '+escape(club.name)+'" title="Supprimer cette copie" onclick="mainMenuSlotDelete(\''+item.id+'\')">•••</button></div></article>';
  });
  return '<div class="cd3-cards" aria-label="Cinq emplacements de carrière">'+rows.join('')+'</div>'+(S&&!d.active?'<div class="cd3-legacy"><p>Votre carrière actuelle est conservée dans la sauvegarde historique.</p><button onclick="mainMenuSlotArchive()"'+(d.items.length>=5?' disabled':'')+'>Enregistrer la carrière actuelle dans un emplacement</button></div>':'');
 }
 function settings(){
  const theme=typeof ui01Pref==='string'?ui01Pref:'system';
  return '<section class="main-menu-panel cd3-panel" aria-label="Préférences visuelles"><span class="cd3-eyebrow">VOTRE CONFORT DE JEU</span><h2>Réglages</h2><p>Préférences séparées de vos carrières.</p><div class="cd3-settings-grid"><label>Thème du jeu<select id="main-menu-theme" onchange="mainMenuTheme(this.value)">'+['system','tribune','analyste'].map((v,i)=>'<option value="'+v+'"'+(theme===v?' selected':'')+'>'+['Système','Tribune · clair','Analyste · sombre'][i]+'</option>').join('')+'</select></label><label>Animations<select id="main-menu-motion" onchange="mainMenuMotion(this.value)"><option value="system"'+(mainMenuReadMotion()==='system'?' selected':'')+'>Suivre le système</option><option value="reduced"'+(mainMenuReadMotion()==='reduced'?' selected':'')+'>Réduire les animations</option></select></label><label>Accessibilité · contraste du menu<select id="cd3-contrast" onchange="CDMenuV3.setPreference(\'contrast\',this.value)"><option value="standard">Standard</option><option value="high"'+(preference('contrast')==='high'?' selected':'')+'>Renforcé</option></select></label><label>Taille du texte du menu<select id="cd3-text" onchange="CDMenuV3.setPreference(\'text\',this.value)"><option value="normal">Normale</option><option value="large"'+(preference('text')==='large'?' selected':'')+'>Grande</option></select></label></div><button onclick="CDMenuV3.fullscreen()"'+(document.documentElement?.requestFullscreen?'':' disabled')+'>Plein écran · activer / quitter</button><p class="cd3-muted">Le menu conserve sa palette stade. Le thème choisi s’applique aux écrans de gestion. Tab pour naviguer, Entrée pour choisir, Échap pour revenir ou ouvrir la pause en match.</p></section>';
 }
 function help(){return '<section class="main-menu-panel cd3-panel" aria-label="Comment jouer"><span class="cd3-eyebrow">DU PREMIER BANC AU BOUCLIER</span><h2>Votre premier match</h2><ol class="cd3-help"><li><strong>Choisissez votre univers et votre club.</strong><p>Les clubs fictifs et le snapshot LNR sont deux modes distincts. Performances et finances restent simulées.</p></li><li><strong>Préparez votre XV.</strong><p>Depuis le bureau, consultez l’effectif, la feuille à 23 et votre plan de jeu.</p></li><li><strong>Entrez dans le match.</strong><p>Le centre de match lance la rencontre. La pause permet de consulter les options et de revenir au menu.</p></li></ol><p>Vos carrières sont sauvegardées localement. Exportez régulièrement un JSON depuis Sauvegardes pour en conserver une copie indépendante.</p><button onclick="mainMenuNewCareer()">Commencer une carrière →</button></section>'}
 function renderMenu(){
  const active=document.activeElement,key=active?.id||active?.getAttribute?.('data-menu-focus');
  if(key)menuFocus=key;
  const panel=mainMenuPanel;
  const content=panel==='settings'?settings():panel==='help'?help():panel==='new'?'<div class="cd3-panel">'+mainMenuNewCareerView()+'</div>':cards();
  const nav=[['continue','▶','Continuer','Continuer ma carrière','mainMenuContinue()'],['new','+','Nouvelle carrière','Nouvelle carrière','mainMenuNewCareer()'],['careers','▤','Mes carrières','Mes carrières',"mainMenuShow('careers')"],['import','⇩','Charger','Charger une sauvegarde JSON','openImportPicker()'],['settings','☷','Réglages','Réglages',"mainMenuShow('settings')"],['help','▣','Comment jouer','Comment jouer',"mainMenuShow('help')"]];
  const isHome=panel==='home'||panel==='careers';
  const right='<aside class="cd3-right" aria-label="Découvrir le jeu"><div class="cd3-right-head"><span>RUGBY MANAGER · XV</span><button class="cd3-right-settings" aria-label="Ouvrir les réglages" onclick="mainMenuShow(\'settings\')">⚙</button></div><div class="cd3-promo"><span>LE RUGBY.<br>VOS DÉCISIONS.<br><b>VOTRE LÉGENDE.</b></span><i aria-hidden="true"></i></div><button class="cd3-feature" onclick="mainMenuNewCareer()"><span class="cd3-feature-icon" aria-hidden="true">✦</span><span><strong>Nouvelle carrière</strong><small>Choisissez votre univers, votre club et votre difficulté.</small></span><span class="cd3-chevron" aria-hidden="true">›</span></button><button class="cd3-feature" onclick="mainMenuShow(\'settings\')"><span class="cd3-feature-icon" aria-hidden="true">☷</span><span><strong>Réglages</strong><small>Affichage, animations et accessibilité.</small></span><span class="cd3-chevron" aria-hidden="true">›</span></button><div class="cd3-right-bottom" aria-hidden="true"></div></aside>';
  $('#app').innerHTML='<main class="main-menu cd3-menu"><a class="cd3-skip" href="#cd3-content">Aller aux carrières</a><div class="cd3-backdrop" aria-hidden="true"></div><div class="main-menu-layout cd3-layout"><aside class="cd3-sidebar"><a class="cd3-brand" href="#" aria-label="Cadrage Débordement, accueil" onclick="mainMenuBack();return false"><span>CADRAGE<br><b>DÉBORDEMENT.</b><small>RUGBY MANAGER</small></span></a><nav class="main-menu-actions cd3-nav" aria-label="Menu principal">'+nav.map(([id,icon,title,label,action])=>'<button data-menu-focus="nav-'+id+'" aria-label="'+label+'" class="'+(panel===id||isHome&&id==='continue'?'cd3-current':'')+'" onclick="'+escape(action)+'"'+(id==='continue'&&!S?' disabled':'')+(panel===id?' aria-current="page"':'')+'><span aria-hidden="true">'+icon+'</span>'+title+'</button>').join('')+'</nav><div class="cd3-sidebar-foot"><div class="cd3-supporters" aria-hidden="true"></div><span class="cd3-status-dot" aria-hidden="true"></span> SAUVEGARDE LOCALE<p>'+escape(storageLocationText())+'</p>'+(gameStorage.offline?'<button onclick="window.CDOfflineAction(\'quit\')">Quitter l’application</button>':'')+'</div></aside><div class="cd3-stage"><header class="cd3-topline"><span>UNE SAISON. UN CLUB. VOTRE HISTOIRE.</span></header><section id="cd3-content" class="cd3-content" tabindex="-1"><div class="cd3-section-head"><div><span class="cd3-eyebrow">'+(panel==='settings'?'VOS PRÉFÉRENCES':panel==='help'?'LE GUIDE DU MANAGER':panel==='new'?'CRÉER UNE NOUVELLE HISTOIRE':'CHOISISSEZ UNE PARTIE À CONTINUER')+'</span><h1>'+(panel==='settings'?'Réglages':panel==='help'?'Comment jouer':panel==='new'?'Nouvelle carrière':'Reprenez votre carrière')+'</h1><p>'+(panel==='settings'?'Personnalisez votre expérience.':panel==='help'?'Les clés de votre premier match.':panel==='new'?'Choisissez votre univers pour commencer.':'Choisissez une partie à continuer')+'</p></div>'+(!isHome?'<button class="cd3-back" onclick="mainMenuBack()">← Retour aux carrières</button>':'')+'</div>'+content+'</section></div>'+right+'<footer class="cd3-footer"><span><kbd>Entrée</kbd> Valider &nbsp;&nbsp; <kbd>Échap</kbd> Retour / Pause</span><span>CADRAGE DÉBORDEMENT · RUGBY MANAGER</span></footer></div>'+(loadSaveFailure?'<div class="main-menu-notice" role="alert">'+escape(loadSaveFailure)+'</div>':'')+'</main>';
  applyPreferences();
  if(key){const el=document.getElementById?.(key)||document.querySelector?.('[data-menu-focus="'+key+'"]');el?.focus?.()}
 }
 async function fullscreen(){try{if(document.fullscreenElement)await document.exitFullscreen();else await document.documentElement.requestFullscreen()}catch(_){toast('Le plein écran est indisponible dans cette fenêtre.')}}
 let lastDialog=null;
 function beforeRender(){
  const active=document.activeElement;
  if(active&&!document.querySelector?.('[role="dialog"]'))dialogTrigger={id:active.id,key:active.getAttribute?.('data-menu-focus'),action:active.getAttribute?.('onclick')};
 }
 function restoreTrigger(){
  const f=dialogTrigger;if(!f)return;
  const el=(f.id&&document.getElementById?.(f.id))||(f.key&&document.querySelector?.('[data-menu-focus="'+f.key+'"]'))||(f.action&&[...(document.querySelectorAll?.('button,a')||[])].find(x=>x.getAttribute('onclick')===f.action));
  (el||document.querySelector?.('.cd3-nav button:not([disabled])'))?.focus?.();
 }
 function afterRender(){
  const dialog=document.querySelector?.('[role="dialog"]');
  if(!dialog?.querySelectorAll){if(lastDialog){lastDialog=null;restoreTrigger()}return}
  if(dialog!==lastDialog){lastDialog=dialog;dialog.querySelector('button,select,input,[tabindex="0"]')?.focus()}
 }
 function keyboard(e){
  if(e.key==='Escape'){
   if(modal){if(pendingSave)cancelSaveImport();else closeModal()}
   else if(entryScreen==='clubs')mainMenuBack();
   else if(entryScreen==='menu'&&mainMenuPanel!=='home')mainMenuBack();
   else if(entryScreen==='game'&&S?.live)openPauseMenu();
   else return;
   e.preventDefault();
  }else if(e.key==='Tab'&&modal){
   const nodes=[...(document.querySelector('[role="dialog"]')?.querySelectorAll('button:not([disabled]),select,input,[tabindex="0"]')||[])].filter(x=>x.getClientRects().length);
   if(!nodes.length)return;
   const first=nodes[0],last=nodes[nodes.length-1];
   if(e.shiftKey&&(document.activeElement===first||!nodes.includes(document.activeElement))){e.preventDefault();last.focus()}
   else if(!e.shiftKey&&(document.activeElement===last||!nodes.includes(document.activeElement))){e.preventDefault();first.focus()}
  }
 }
 document.addEventListener?.('keydown',keyboard);
 return {render:renderMenu,cards,settings,help,escape,setPreference,preference,fullscreen,beforeRender,afterRender};
})();
