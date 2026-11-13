/* Effectif Premium : présentation des projections UI02, état d'interface local. */
(function(root,build){'use strict';const api=build();if(typeof module==='object'&&module.exports)module.exports=api;if(root?.document){root.CDSquadPresentation=api;api.install(root);}})(typeof globalThis==='object'?globalThis:null,function(){
 'use strict';
 const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const finite=v=>typeof v==='number'&&Number.isFinite(v);
 const num=v=>finite(v)?new Intl.NumberFormat('fr-FR',{maximumFractionDigits:0}).format(v):'—';
 const money=v=>finite(v)?num(v)+' €':'—';
 const season=v=>finite(v)?'S'+num(v):'—';
 const axes=['power','speed','tackle','pass','kick','stamina'];
 function selectPlayer(ids,previous){return ids.includes(previous)?previous:ids[0]||null;}
 function facts(p){return '<dl class="sq-facts">'+[['Condition',finite(p.condition)?num(p.condition)+' %':'—'],['Charge',finite(p.physical)?num(p.physical)+' /100':'—'],['Salaire / semaine',money(p.salary)],['Fin de contrat',season(p.contract)],['Minutes jouées',num(p.minutes)],['Statut',p.status||'—']].map(([k,v])=>'<div><dt>'+esc(k)+'</dt><dd>'+esc(v)+'</dd></div>').join('')+'</dl>';}
 function actions(p){return '<div class="sq-actions"><button type="button" data-sq-contract="'+esc(p.id)+'">Examiner le contrat ↗</button><button type="button" data-sq-route="depth">Préparer la rotation ↗</button><button type="button" data-sq-route="sheet">Vérifier les 23 ↗</button></div>';}
 function playerCard(p,options={}){if(!p)return '<aside class="sq-preview-empty">Aucun joueur dans cette sélection.</aside>';return '<aside class="ed-card ed-player-preview sq-preview" data-sq-preview="'+esc(p.id)+'" aria-label="Aperçu du joueur sélectionné"><div class="sq-preview-identity">'+(options.face||'')+'<div><p class="sq-kicker">LE JOUEUR SÉLECTIONNÉ</p><h2>'+esc(p.name)+'</h2><p>'+esc(p.position)+' · '+num(p.age)+' ans</p></div></div><div class="sq-grades"><div><span>Note au poste</span><b>'+num(p.note)+'</b></div><div><span>Potentiel</span><b>'+num(p.potential)+'</b></div></div>'+facts(p)+'<button type="button" class="sq-primary" data-ed-player="'+esc(p.id)+'">Ouvrir la fiche complète ↗</button><button type="button" data-sq-open="comparison" data-sq-player="'+esc(p.id)+'">Comparer ce joueur ⇄</button>'+actions(p)+'</aside>';}
 function radar(p){const rows=axes.map(k=>p.attributes?.[k]).filter(a=>finite(a?.value));if(rows.length<3)return '<p class="sq-empty">Attributs non renseignés.</p>';const xy=(i,v)=>{const a=i/rows.length*2*Math.PI-Math.PI/2;return [160+Math.cos(a)*v*.85,128+Math.sin(a)*v*.85];},points=v=>rows.map((_,i)=>xy(i,v).join(',')).join(' ');return '<svg class="sq-radar" viewBox="0 0 320 260" role="img" aria-label="Six attributs de '+esc(p.name)+', sur 100"><title>'+esc(rows.map(a=>a.label+' '+num(a.value)+'/100').join(' · '))+'</title>'+[25,50,75,100].map(v=>'<polygon class="sq-radar-grid" points="'+points(v)+'"/>').join('')+'<polygon class="sq-radar-fill" points="'+rows.map((a,i)=>xy(i,Math.max(0,Math.min(100,a.value))).join(',')).join(' ')+'"/>'+rows.map((a,i)=>{const [x,y]=xy(i,125),[cx,cy]=xy(i,Math.max(0,Math.min(100,a.value)));return '<circle cx="'+cx+'" cy="'+cy+'" r="3"/><text x="'+x+'" y="'+y+'" text-anchor="middle">'+esc(a.label)+'</text>';}).join('')+'</svg><dl class="sq-axis-values">'+rows.map(a=>'<div><dt>'+esc(a.label)+'</dt><dd>'+num(a.value)+'</dd></div>').join('')+'</dl>';}
 function profileOverview(p){const best=Object.values(p.attributes||{}).filter(a=>finite(a?.value)).sort((a,b)=>b.value-a.value).slice(0,3);return '<div class="sq-profile-overview"><section class="sq-panel sq-qualities"><p class="sq-kicker">LE PROFIL DE JEU</p><h3>Ses armes sur le terrain</h3>'+radar(p)+'<p class="sq-note">Attributs courants sur 100. Le poste et les consignes restent déterminants.</p></section><section class="sq-panel sq-dossier"><p class="sq-kicker">LES REPÈRES DU MANAGER</p><h3>La situation du joueur</h3>'+facts(p)+'<div class="sq-strengths"><h4>Ses points d’appui</h4>'+best.map((a,i)=>'<div><span>0'+(i+1)+'</span><span>'+esc(a.label)+'</span><b>'+num(a.value)+'<small>/100</small></b></div>').join('')+(best.length?'':'<p>Attributs non renseignés.</p>')+'</div>'+actions(p)+'</section></div>';}
 function install(root){
  if(typeof root.render!=='function'||root.__sqInstalled)return;root.__sqInstalled=true;
  const doc=root.document,node=html=>{const t=doc.createElement('template');t.innerHTML=html;return t.content.firstElementChild;};
  let selected=null,career=null,mode=null,returnAction='comparison',returnPlayer=null;
  function project(id){const p=club().players.find(p=>p.id===id);return p?CDUI02Data.playerView(p,ui02Deps(),ui02Ctx()):null;}
  function face(p){if(S.lnrMode)return '<div class="ed-monogram" aria-hidden="true">'+esc(p.name.split(/\s+/).map(x=>x[0]).slice(0,2).join(''))+'</div>';const i=root.CDEditorial.portraitIndex(p.id),cell=i%16;return '<span class="ed-portrait is-large" aria-hidden="true" style="--atlas:url(assets/editorial/portraits-'+Math.floor(i/16)+'.webp);background-position:'+(cell%4)*100/3+'% '+Math.floor(cell/4)*100/3+'%"></span>';}
  function closeDialog(){mode=null;doc.querySelector('.sq-dialog')?.close();const buttons=[...doc.querySelectorAll('[data-sq-open="'+returnAction+'"]')];(buttons.find(b=>(b.dataset.sqPlayer||null)===returnPlayer)||buttons[0])?.focus({preventScroll:true});}
  function dialog(main,stack,focus){
   const selectors=stack.querySelector('.cd02-selectors'),comparison=stack.querySelector('.cd02-comparison'),training=stack.querySelector('.cd02-training');
   const dlg=node('<dialog class="sq-dialog" aria-labelledby="sq-dialog-title"><header><div><p class="sq-kicker">GESTION DE L’EFFECTIF</p><h2 id="sq-dialog-title"></h2></div><button type="button" data-sq-close aria-label="Fermer la fenêtre">Fermer ×</button></header><div class="sq-dialog-body"></div></dialog>');
   const body=dlg.lastElementChild;[selectors,comparison,training].filter(Boolean).forEach(el=>body.append(el));main.append(dlg);
   selectors?.toggleAttribute('hidden',mode!=='comparison');comparison?.toggleAttribute('hidden',mode!=='comparison');training?.toggleAttribute('hidden',mode!=='training');
   if(training)training.open=true;
   dlg.querySelector('h2').textContent=mode==='training'?'Charges individuelles':'Comparer les profils';
   dlg.addEventListener('cancel',e=>{e.preventDefault();closeDialog();});
   if(mode){dlg.showModal();if(focus)[...dlg.querySelectorAll('['+focus.attr+']')].find(e=>e.getAttribute(focus.attr)===focus.value)?.focus({preventScroll:true});}
  }
  function enhance(focus){
   const main=doc.querySelector('.main[data-ed-route="team"]');if(!main||typeof S==='undefined'||!S||S.live){mode=null;return;}
   if(career!==S){career=S;selected=null;mode=null;}main.classList.add('sq-main');
   const title=main.querySelector('.heading h1');if(title)title.textContent='Les hommes du projet.';
   const desc=main.querySelector('.heading p');if(desc)desc.textContent=club().players.length+' joueurs · Saison '+libelleSaison(S.season)+' · '+club().name;
   const roster=main.querySelector('.cd02-roster'),profile=main.querySelector('[data-cd02-player]');
   if(profile){
    const p=project(profile.dataset.cd02Player);if(!p)return;main.classList.add('sq-profile-main');
    const header=profile.querySelector('.cd02-player-header');header.append(node('<button type="button" class="sq-profile-compare" data-sq-open="comparison" data-sq-player="'+esc(p.id)+'">Comparer ⇄</button>'));
    if(ui02Tab==='profil')profile.querySelector('.cd02-player-content').replaceChildren(node(profileOverview(p)));
    // Les fenêtres réutilisent le même HTML et les mêmes événements UI02, dans #app.
    const source=node('<div hidden>'+ui02ComparePanel()+'</div>');main.append(source);dialog(main,source,focus);source.remove();return;
   }
   if(!roster){mode=null;return;}
   main.classList.add('sq-table-main');const stack=main.querySelector('.cd02-roster-stack');
   const filters=stack.querySelector('.cd02-filters'),tools=roster.querySelector('.cd02-roster-tools');if(filters){const label=filters.querySelector('label');if(label)tools.prepend(label);filters.remove();}
   roster.querySelector('.cd02-roster-head .cd02-kicker').textContent='LE GROUPE PROFESSIONNEL';roster.querySelector('h2').textContent='Votre effectif';
   const commands=node('<div class="sq-roster-commands"><button type="button" data-sq-open="comparison">Comparer ⇄</button><button type="button" data-sq-open="training">Charges individuelles ↗</button></div>');roster.querySelector('.cd02-roster-config').append(commands);
   const wrapper=node('<div class="ed-team-overview sq-overview"></div>');roster.before(wrapper);wrapper.append(roster);
   const rows=[...roster.querySelectorAll('[data-cd02-row]')];selected=selectPlayer(rows.map(r=>r.dataset.cd02Row),selected);
   const paint=()=>{wrapper.querySelector('.sq-preview,.sq-preview-empty')?.remove();const p=project(selected);wrapper.append(node(playerCard(p,{face:p?face(p):''})));rows.forEach(row=>{const active=row.dataset.cd02Row===selected;row.dataset.sqSelected=String(active);row.querySelector('[data-sq-select]')?.setAttribute('aria-pressed',String(active));});};
   rows.forEach(row=>{const id=row.dataset.cd02Row;row.firstElementChild.prepend(node('<button type="button" class="sq-row-preview" data-sq-select="'+esc(id)+'" aria-pressed="false" aria-label="Aperçu de '+esc(project(id)?.name)+'" title="Sélectionner l’aperçu">◉</button>'));});paint();
   wrapper.addEventListener('click',e=>{const button=e.target.closest('[data-sq-select]');if(button){selected=button.dataset.sqSelect;paint();}});
   const nativeTable=roster.querySelector('.cd02-table-scroll');nativeTable.setAttribute('aria-label','Effectif, tableau défilant');
   dialog(main,stack,focus);
  }
  doc.addEventListener('click',e=>{
   const button=e.target.closest?.('[data-sq-open],[data-sq-close],[data-sq-route],[data-sq-contract]');if(!button)return;
   if(button.hasAttribute('data-sq-close')){closeDialog();return;}
   if(button.dataset.sqOpen){returnAction=button.dataset.sqOpen;returnPlayer=button.dataset.sqPlayer||null;mode=returnAction;const id=returnPlayer||selected;if(mode==='comparison'&&id&&project(id)){ui02Compare=[id,ui02Compare[1]===id?null:ui02Compare[1]];}root.render();return;}
   if(button.dataset.sqRoute){mode=null;ui02ProfileId=null;squadTab=button.dataset.sqRoute;view='team';root.render();ui02Focus('.squad-tabs button.dark');return;}
   if(button.dataset.sqContract&&project(button.dataset.sqContract)){mode=null;ui02ShowPlayer(button.dataset.sqContract);ui02SetTab('contrat');}
  });
  const original=root.render;root.render=function(){
   const active=doc.activeElement,attr=['data-ui02-compare','data-ui02-training','data-ui02-clear'].find(a=>active?.hasAttribute(a));
   const focus=attr?{attr,value:active.getAttribute(attr)}:null;
   const value=original.apply(this,arguments);enhance(focus);return value;
  };enhance();
 }
 return Object.freeze({selectPlayer,playerCard,profileOverview,install});
});
