/* Présentation Premium native : lecture seule de la carrière, aucune écriture moteur. */
(function(root,factory){'use strict';const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root&&root.document){root.CDEditorial=api;api.install(root);}})(typeof globalThis==='object'?globalThis:null,function(){
 'use strict';
 const routes={
  dashboard:{title:'Tout se joue cette semaine.',over:'Bureau du manager',image:'matchday',desc:'Le prochain défi, les décisions du jour et la vie de votre club.'},
  team:{title:'Un groupe. Une ambition.',over:'Effectif professionnel',image:'squad',desc:'Connaître les hommes, accompagner les talents, composer votre XV.'},
  tactics:{title:'Notre plan de bataille.',over:'Préparation collective',image:'tactics',desc:'Les joueurs, les rôles et les intentions pour la prochaine rencontre.'},
  plans:{title:'Imposez votre rugby.',over:'Plan de jeu',image:'tactics',desc:'Préparez vos systèmes et les réponses aux temps forts du match.'},
  staff:{title:'Le sens du collectif.',over:'Staff & encadrement',image:'staff',desc:'Un projet sportif se construit avec des convictions et des compétences.'},
  recruitment:{title:'Détecter. Recruter. Construire.',over:'Cellule de recrutement',image:'matchday',desc:'Des besoins identifiés aux profils observés : préparez les prochains choix.'},
  match:{title:'Le terrain nous attend.',over:'Centre de match',image:'matchday',desc:'Derniers réglages, adversaire et feuille de match.'},
  league:{title:'La course au Bouclier.',over:'Championnat',image:'squad',desc:'Le classement, le calendrier et les résultats de votre univers.'},
  history:{title:'Écrire notre histoire.',over:'Palmarès & parcours',image:'clubhouse',desc:'Les saisons et les décisions qui façonnent votre carrière.'},
  market:{title:'Bâtir le prochain chapitre.',over:'Mercato & contrats',image:'staff',desc:'Les opportunités du marché et les engagements de votre groupe.'},
  formation:{title:'L’avenir prend forme ici.',over:'Centre de formation',image:'academy',desc:'Accompagner la relève, suivre les trajectoires, préparer la passerelle.'},
  finance:{title:'Les moyens de nos ambitions.',over:'Finances du club',image:'clubhouse',desc:'Trésorerie, engagements et investissements : décider avec les chiffres.'},
  saves:{title:'Chaque saison compte.',over:'Vos carrières',image:'clubhouse',desc:'Retrouver votre parcours et préserver les prochains chapitres.'},
  help:{title:'Le rugby se dirige.',over:'Le carnet du manager',image:'tactics',desc:'Les repères pour comprendre votre club, préparer le match et progresser.'}
 };
 const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
 const finite=v=>typeof v==='number'&&Number.isFinite(v);
 const n=v=>finite(v)?new Intl.NumberFormat('fr-FR',{maximumFractionDigits:0}).format(v):'—';
 const euro=v=>finite(v)?new Intl.NumberFormat('fr-FR',{style:'currency',currency:'EUR',maximumFractionDigits:0}).format(v):'—';
 function groupSummary(m){const squad=Array.isArray(m?.squad)?m.squad:[],valid=squad.filter(p=>finite(p.condition));return {count:squad.length,average:valid.length?valid.reduce((s,p)=>s+p.condition,0)/valid.length:null,condition:[valid.filter(p=>p.condition<50).length,valid.filter(p=>p.condition>=50&&p.condition<80).length,valid.filter(p=>p.condition>=80).length]};}
 const attrNames={power:'Puissance',speed:'Vitesse',tackle:'Plaquage',pass:'Passe',kick:'Jeu au pied',stamina:'Endurance',mental:'Mental',discipline:'Discipline',scrum:'Mêlée',lineout:'Touche',goal:'But'};
 function radarValues(p){return Object.entries(attrNames).filter(([key])=>finite(p?.attributes?.[key])).map(([key,label])=>({label,value:Math.max(0,Math.min(100,p.attributes[key]))}));}
 const symbols=[
  '<path d="M23 35q12-23 24 0M20 42h30M22 49h26M26 56h18"/>',
  '<path d="M22 49q8-9 16 0t16 0M22 57q8-9 16 0t16 0M34 39V22h8v17M29 39h18"/>',
  '<path d="M22 36q12-13 24 0q-12 13-24 0zm0 17q12-13 24 0M35 26v30"/>',
  '<path d="M24 54l6-17-8-7 19-7 8 12-10 6 8 15-14-7z"/>',
  '<path d="M32 32l-8-12m8 12 1-14m8 14 8-12m-8 12-1-14M29 35l7 25 8-25z"/>',
  '<path d="M18 31l17 7 17-7-9 16-8 12-8-12zM28 37l7 7 7-7"/>',
  '<path d="M19 57l16-31 17 31zM29 39l6 5 6-5M35 22v-7M25 25l-6-5m26 5 6-5"/>',
  '<path d="M24 23q1 14 12 21q12-7 12-21M36 44v17M23 54q13 8 26 0"/>',
  '<path d="M35 21v38M35 33l-11-7m11 16-13-7m13 15-12-7m12-10 11-7m-11 16 13-7m-13 15 12-7"/>',
  '<path d="M23 31l-5-8 13 6h9l13-6-5 8 2 15-14 14-14-14zM27 39h5m8 0h5"/>',
  '<path d="M21 49h30M21 40h30M24 30h24M35 22v36M22 57h26"/>',
  '<path d="M35 22l5 12 13 1-10 9 3 13-11-7-11 7 3-13-10-9 13-1z"/>',
  '<path d="M35 22v35M27 28h16M22 40q-7 17 13 20q20-3 13-20M18 43l4-3 6 2m14 0 6-2 5 3"/>',
  '<path d="M19 28l16 10 17-10-7 18-10 12-9-12zM29 38l6 5 6-5M31 27l4-5 5 5"/>'
 ];
 function crest(index,abbr='CD'){const i=Number.isInteger(index)?Math.abs(index)%symbols.length:0;return '<svg class="ed-crest" viewBox="0 0 70 90" role="img" aria-label="Blason original '+esc(abbr)+'"><path d="M35 3L65 13v36Q63 72 35 86Q7 72 5 49V13Z" fill="#0b2a21" stroke="#c59455" stroke-width="2"/><path d="M35 9L59 17v31Q57 66 35 79Q13 66 11 48V17Z" fill="none" stroke="#c59455" stroke-width=".7"/><g fill="none" stroke="#dfbc7f" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round">'+symbols[i]+'</g><text x="35" y="72" text-anchor="middle" fill="#ecd2a7" font-size="8" font-family="serif">'+esc(abbr).slice(0,35)+'</text></svg>';}
 function conditionChart(m){const s=groupSummary(m),max=Math.max(1,...s.condition);return '<div class="ed-chart-group" aria-label="Condition du groupe"><div class="ed-chart-title"><h3>Condition du groupe</h3><strong>'+n(s.average)+'<small>/100</small></strong></div>'+['0–49','50–79','80–100'].map((label,i)=>'<button type="button" class="ed-bar-item" data-ed-info="'+esc(label+' /100 : '+s.condition[i]+' joueur(s)')+'" aria-pressed="false"><span>'+label+'</span><i style="--bar:'+s.condition[i]/max*100+'%"></i><b>'+s.condition[i]+'</b></button>').join('')+'<output class="ed-chart-readout" aria-live="polite">Survolez, cliquez ou sélectionnez une plage.</output></div>';}
 function resultsChart(results){const rows=(Array.isArray(results)?results:[]).filter(r=>finite(r.own)&&finite(r.against)).slice(-5);if(!rows.length)return '<div class="ed-chart-group"><h3>Les derniers rendez-vous</h3><p class="ed-empty">Aucun match joué. La saison attend son premier résultat.</p></div>';const max=Math.max(1,...rows.flatMap(r=>[r.own,r.against]));return '<div class="ed-chart-group"><h3>Les derniers rendez-vous</h3><div class="ed-result-chart">'+rows.map(r=>'<button type="button" data-ed-info="'+esc(r.label+' : '+r.own+'–'+r.against)+'" class="ed-result-column"><span>'+esc(r.label)+'</span><i style="height:'+r.own/max*80+'px"></i><i style="height:'+r.against/max*80+'px"></i><b>'+esc(r.outcome||'')+'</b></button>').join('')+'</div><output class="ed-chart-readout" aria-live="polite">Cuivre : votre club · Sauge : adversaire.</output></div>';}
 function radar(p){const rows=radarValues(p).slice(0,6);if(rows.length<3)return '<p class="ed-empty">Attributs documentés indisponibles.</p>';const xy=(i,v)=>{const a=i/rows.length*Math.PI*2-Math.PI/2;return [150+Math.cos(a)*v*.86,120+Math.sin(a)*v*.86];};const points=v=>rows.map((_,i)=>xy(i,v).join(',')).join(' ');return '<svg class="ed-radar" viewBox="0 0 300 245" role="img" aria-label="Attributs du joueur, sur cent">'+[25,50,75,100].map(v=>'<polygon points="'+points(v)+'" class="ed-radar-grid"/>').join('')+'<polygon class="ed-radar-fill" points="'+rows.map((r,i)=>xy(i,r.value).join(',')).join(' ')+'"/>'+rows.map((r,i)=>{const [x,y]=xy(i,100),[tx,ty]=xy(i,127);return '<circle cx="'+xy(i,r.value)[0]+'" cy="'+xy(i,r.value)[1]+'" r="4" tabindex="0"><title>'+esc(r.label+' : '+n(r.value)+'/100')+'</title></circle><text x="'+tx+'" y="'+ty+'" text-anchor="middle">'+esc(r.label)+'</text>';}).join('')+'</svg>';}
 // Identité visuelle dérivée de l'ID, jamais de la position dans l'effectif.
 // Les joueurs fictifs initiaux ont 30 indices distincts ; les autres IDs utilisent
 // un hash stable vers les 32 illustrations. Réemploi possible, aucun portrait réel.
 function portraitIndex(id){const str=String(id??''),initial=/^p\d+-(\d+)-\d+$/.exec(str);if(initial)return Number(initial[1])%32;let hash=2166136261;for(let i=0;i<str.length;i++)hash=Math.imul(hash^str.charCodeAt(i),16777619)>>>0;return hash%32;}
 function portrait(index,large=false){if(!Number.isInteger(index)||index<0||index>=32)return '<span class="ed-monogram" aria-hidden="true">XV</span>';const cell=index%16;return '<span class="ed-portrait'+(large?' is-large':'')+'" role="img" aria-label="Portrait décoratif fictif généré par IA" title="Portrait décoratif fictif généré par IA" style="--atlas:url(assets/editorial/portraits-'+Math.floor(index/16)+'.webp);background-position:'+(cell%4)*100/3+'% '+Math.floor(cell/4)*100/3+'%"></span>';}
 function lineupView(m,ids,options={}){
  const positions=[[36,85],[50,85],[64,85],[42,72],[58,72],[28,59],[72,59],[50,56],[40,43],[60,34],[12,30],[38,22],[62,22],[88,30],[50,9]];
  return '<div class="ed-pitch" role="group" aria-label="Votre XV titulaire"><div class="ed-pitch-lines" aria-hidden="true"></div>'+positions.map(([x,y],i)=>{const p=(m.squad||[]).find(p=>p.id===ids?.[i]);return '<button type="button" class="ed-pitch-player" '+(p?'data-ed-player="'+esc(p.id)+'" aria-label="'+esc((i+1)+' · '+p.name+' · '+p.position)+'"':'disabled aria-label="Poste non attribué"')+' style="left:'+x+'%;top:'+y+'%">'+(p&&options.portraits!==false?portrait(portraitIndex(p.id)):'<span class="ed-shirt">XV</span>')+'<b>'+String(i+1).padStart(2,'0')+'</b><span class="ed-pitch-name">'+esc(p?p.name:'Poste non attribué')+'</span></button>';}).join('')+'</div>';
 }
 function node(html){const t=document.createElement('template');t.innerHTML=html;return t.content.firstElementChild;}
 function install(root){
  if(root.__cdEditorialInstalled||typeof root.render!=='function')return;root.__cdEditorialInstalled=true;
  const document=root.document,choices=Object.create(null);
  document.documentElement.dataset.edition='editorial';
  function read(){return typeof CDArtDirection==='object'&&typeof S!=='undefined'&&S?CDArtDirection.snapshot():null;}
  function decorateCrests(m){if(typeof S!=='undefined'&&S?.lnrMode)return;const clubs=typeof S!=='undefined'&&S?S.clubs:typeof CLUBS!=='undefined'?CLUBS.map((c,i)=>({id:i,abbr:c[1]})):[];document.querySelectorAll('.crest:not([data-ed-crest])').forEach(el=>{const c=clubs.find(c=>c.abbr===el.textContent.trim());if(c){el.dataset.edCrest='true';el.innerHTML=crest(c.id,c.abbr);el.style.color='';}});}
  function topbar(main,m){const brand=main.querySelector('.ui01-brand');if(brand){brand.innerHTML=(typeof S!=='undefined'&&!S.lnrMode?crest(m.club.id,m.club.abbr):'<strong>'+esc(m.club.abbr)+'</strong>')+'<div><b>'+esc(m.club.name)+'</b><small>'+esc(m.competition)+' · Saison '+esc(m.season)+' · '+esc(m.roundTitle)+'</small></div>';}}
  function heading(main,route){const data=routes[route];let h=main.querySelector(':scope>.heading');if(!h){h=node('<div class="heading"><div><div class="eyebrow"></div><h1></h1><p></p></div></div>');const bar=main.querySelector('.ui01-appbar');if(bar)bar.after(h);else main.prepend(h);}h.dataset.edHero=route;h.style.setProperty('--ed-image','url(assets/editorial/'+data.image+'.webp)');h.querySelector('h1').textContent=data.title;const over=h.querySelector('.eyebrow');if(over)over.textContent=data.over;const p=h.querySelector('p');if(p)p.textContent=data.desc;}
  function overview(m){const own=m.standings.find(t=>t.mine),at=own?m.standings.indexOf(own):0,rows=m.standings.slice(Math.max(0,at-2),Math.max(0,at-2)+5);return '<div class="ed-dashboard-grid"><section class="ed-card">'+conditionChart(m)+'<button type="button" data-ed-route="team" class="ed-text-button">Voir le groupe →</button></section><section class="ed-card">'+resultsChart(m.results)+'<button type="button" data-ed-route="match" class="ed-text-button">Centre de match →</button></section><section class="ed-card"><div class="ed-chart-title"><h3>La course au classement</h3><span>'+n(own?.points)+' pts</span></div><table class="ed-mini-table"><tbody>'+rows.map(t=>'<tr class="'+(t.mine?'is-mine':'')+'"><td>'+n(t.rank)+'</td><td>'+esc(t.abbr)+'</td><td>'+n(t.points)+'</td></tr>').join('')+'</tbody></table><button type="button" class="ed-text-button" data-ed-route="league">Tout le championnat →</button></section></div>';}
  function sectionPages(container,route,groups){if(groups.length<2)return;const shell=node('<div class="ed-sectioned"><nav class="ed-section-tabs" role="tablist" aria-label="Dossiers de '+esc(routes[route].over)+'"></nav><div class="ed-section-panels"></div></div>'),tabs=shell.firstElementChild,panels=shell.lastElementChild;groups.forEach((g,i)=>{const id='ed-'+route+'-'+i,button=node('<button type="button" role="tab" id="'+id+'-tab" aria-controls="'+id+'" aria-selected="false">'+esc(g.name)+'</button>'),panel=node('<section class="ed-section-panel" id="'+id+'" role="tabpanel" aria-labelledby="'+id+'-tab"></section>');g.nodes.forEach(n=>panel.append(n));tabs.append(button);panels.append(panel);button.addEventListener('click',()=>activate(i));button.addEventListener('keydown',e=>{if(['ArrowLeft','ArrowRight','Home','End'].includes(e.key)){e.preventDefault();const next=e.key==='Home'?0:e.key==='End'?groups.length-1:(i+(e.key==='ArrowRight'?1:groups.length-1))%groups.length;activate(next);tabs.children[next].focus();}});});function activate(i){choices[route]=i;[...tabs.children].forEach((b,j)=>{b.setAttribute('aria-selected',String(i===j));b.tabIndex=i===j?0:-1;panels.children[j].hidden=i!==j;});}container.append(shell);activate(Math.min(choices[route]||0,groups.length-1));}
  function enhance(){
   const m=read();decorateCrests(m);const menuBrand=document.querySelector('.cd3-brand>span');if(menuBrand)menuBrand.innerHTML='Cadrage<br><b>Débordement</b><small>RUGBY MANAGER</small>';const main=document.querySelector('.layout>.main');if(!m||!main)return;
   if(main.closest('.live-layout')){main.dataset.edLive='true';return;}
   const route=typeof view==='string'&&routes[view]?view:'dashboard';if(main.dataset.edRoute)return;main.dataset.edRoute=route;
   topbar(main,m);heading(main,route);
   const wordmark=document.querySelector('.sidebar .wordmark');if(wordmark)wordmark.innerHTML='<svg class="ed-brand-ball" viewBox="0 0 80 34" aria-hidden="true"><ellipse cx="40" cy="17" rx="30" ry="11" transform="rotate(-22 40 17)"/><path d="M18 25Q40 4 64 10M33 20l14-6m-11 1 2 7m3-10 2 7"/></svg>Cadrage<br><span>Débordement</span>';
   main.querySelectorAll('.da42-rail-item button,.da42-command-cta span').forEach(el=>{if(el.textContent.trim()==='↗')el.textContent='↗\uFE0E';});
   if(route==='dashboard'){
    const pilot=main.querySelector('[data-da42-page="pilotage"]');if(pilot)pilot.append(node(overview(m)));
    const crestBox=main.querySelector('.da42-command-crest');if(crestBox&&m.next&&!(typeof S!=='undefined'&&S.lnrMode))crestBox.innerHTML=crest(m.next.opponent.id,m.next.opponent.abbr);
   }
   if(route==='tactics'){
    const panel=main.querySelector('[data-da42-page="xv"]'),ids=typeof S!=='undefined'?S.lineup:[],xv=ids.map(id=>m.squad.find(p=>p.id===id)).filter(Boolean);
    if(panel)panel.prepend(node('<section class="ed-tactics-grid"><div class="ed-card ed-pitch-card"><div class="ed-chart-title"><h3>Le XV de départ</h3><span>'+xv.length+' / 15</span></div>'+lineupView(m,ids,{portraits:!(typeof S!=="undefined"&&S.lnrMode)})+'<p class="ed-pitch-caption">Sélectionnez un joueur pour ouvrir son dossier.</p></div><aside class="ed-tactical-context"><section class="ed-card"><p class="ed-kicker">PROCHAIN ADVERSAIRE</p><div class="ed-opponent">'+(m.next&&!(typeof S!=="undefined"&&S.lnrMode)?crest(m.next.opponent.id,m.next.opponent.abbr):'')+'<h3>'+esc(m.next?.opponent.name||'Aucun match programmé')+'</h3></div><p>'+esc(m.roundTitle)+'</p><button type="button" data-ed-route="match">Préparer la rencontre →</button></section><section class="ed-card">'+conditionChart({squad:xv})+'</section><section class="ed-card"><h3>Nos intentions</h3><p>'+esc(typeof TACTICS!=="undefined"?TACTICS[S.tactic]?.[0]||S.tactic:'Plan actuel')+'</p><button type="button" data-ed-route="plans">Régler le plan de jeu →</button></section></aside></section>'));
   }
   if(route==='team'){
    if(!(typeof S!=='undefined'&&S.lnrMode)){
     main.querySelectorAll('[data-cd02-row]').forEach(row=>{const index=m.squad.findIndex(p=>p.id===row.dataset.cd02Row),link=row.querySelector('.cd02-player-link');if(link&&index>=0)link.prepend(node(portrait(portraitIndex(m.squad[index].id))));});
     const profile=main.querySelector('[data-cd02-player]'),p=profile?m.squad.find(p=>p.id===profile.dataset.cd02Player):null;
     if(profile&&p){const avatar=profile.querySelector('.cd02-avatar');if(avatar){avatar.classList.add('ed-profile-face');avatar.innerHTML=portrait(portraitIndex(p.id),true);}const content=profile.querySelector('.cd02-player-content');if(content&&typeof ui02Tab!=='undefined'&&ui02Tab==='profil')content.prepend(node('<section class="ed-card ed-profile-radar"><h3>Le profil de jeu</h3>'+radar(p)+'</section>'));}
    }
    const roster=main.querySelector('.cd02-roster');if(roster){const p=m.squad.find(p=>p.id===(typeof S!=='undefined'?S.lineup?.[9]:null))||m.squad[0];if(p){const wrapper=node('<div class="ed-team-overview"></div>');roster.before(wrapper);wrapper.append(roster);wrapper.append(node('<aside class="ed-card ed-player-preview">'+(!(typeof S!=='undefined'&&S.lnrMode)?portrait(portraitIndex(p.id),true):'<div class="ed-monogram">'+esc(p.name.split(' ').map(x=>x[0]).join(''))+'</div>')+'<p class="ed-kicker">DANS VOTRE GROUPE</p><h2>'+esc(p.name)+'</h2><p>'+esc(p.position)+' · '+esc(p.age)+' ans</p><div class="ed-preview-stats"><span>Au poste <b>'+n(p.note)+'</b></span><span>Condition <b>'+n(p.condition)+'%</b></span></div>'+radar(p)+'<button type="button" data-ed-player="'+esc(p.id)+'">Ouvrir le dossier →</button></aside>'));}}
   }
   const content=node('<div class="ed-native-scroll" role="region" aria-label="Contenu de '+esc(routes[route].over)+'" tabindex="0"></div>');
   [...main.children].filter(el=>!el.matches('.ui01-appbar,.heading')).forEach(el=>content.append(el));main.append(content);
   const children=[...content.children];
   if(route==='team'&&children.some(el=>el.matches('.cd02-roster-stack'))){const list=children.filter(el=>el.matches('.cd02-roster-stack,.lnr-catalogue,.lnr05-center')),analysis=[...content.querySelectorAll('.da4-squad-stage')],tabs=children.filter(el=>el.matches('.squad-tabs'));const other=children.filter(el=>!list.includes(el)&&!tabs.includes(el));const groups=[{name:'Groupe professionnel',nodes:list}];if(analysis.length)groups.push({name:'Analyse du groupe',nodes:analysis});other.forEach((el,i)=>groups.push({name:el.querySelector('h2')?.textContent||'Dossier '+(i+1),nodes:[el]}));sectionPages(content,route,groups);tabs.forEach(el=>content.prepend(el));}
   if(['league','history','help','saves','plans','staff','match'].includes(route)){
    const nodes=[...content.children],groups=[];
    for(const el of nodes){if(el.matches('.stack')&&route==='league'){for(const sub of [...el.children])groups.push({name:sub.querySelector('h2')?.textContent||'Calendrier',nodes:[sub]});el.remove();}else if(el.matches('.card,.grid,.marketgrid,.manager-staff-grid,.da4-panel'))groups.push({name:el.querySelector('h2')?.textContent||({match:'Avant-match',saves:'Gestion des carrières',help:'Guide du manager'}[route]||'Dossiers'),nodes:[el]});else if(groups.length)groups.at(-1).nodes.push(el);else groups.push({name:'Vue d’ensemble',nodes:[el]});}
    sectionPages(content,route,groups);
   }
  }
  document.addEventListener('click',event=>{const el=event.target.closest?.('button[data-ed-route],[data-ed-player],[data-ed-info]');if(!el)return;if(el.dataset.edRoute&&routes[el.dataset.edRoute]&&typeof nav==='function')nav(el.dataset.edRoute);else if(el.dataset.edPlayer&&typeof ui02ShowPlayer==='function')ui02ShowPlayer(el.dataset.edPlayer);else if(el.dataset.edInfo){const chart=el.closest('.ed-chart-group');if(chart){chart.querySelectorAll('[aria-pressed]').forEach(b=>b.setAttribute('aria-pressed',String(b===el)));const output=chart.querySelector('output');if(output)output.textContent=el.dataset.edInfo;}}});
  const readout=event=>{const el=event.target.closest?.('[data-ed-info]');if(el){const output=el.closest('.ed-chart-group')?.querySelector('output');if(output)output.textContent=el.dataset.edInfo;}};document.addEventListener('pointerover',readout);document.addEventListener('focusin',readout);
  const original=root.render;root.render=function(){const result=original.apply(this,arguments);enhance();return result;};enhance();
 }
 return {routes,esc,groupSummary,radarValues,crest,conditionChart,resultsChart,lineupView,portraitIndex,install};
});
