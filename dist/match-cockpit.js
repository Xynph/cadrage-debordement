'use strict';
// V40 : un cockpit visuel original, sans changement des lois ou du moteur rugby.
// Le choix des onglets est un état de présentation non sauvegardé.
let matchCockpitFocus='terrain';
function chooseMatchCockpitFocus(next){
 if(!['terrain','effectif','analyse','tactique'].includes(next))return false;
 matchCockpitFocus=next;render();return true;
}
function matchCockpitToolbar(l){
 const tabs=[['terrain','Terrain 2D'],['effectif','Effectif & banc'],['analyse','Statistiques'],['tactique','Consignes']];
 return '<nav class="v40-tabs" aria-label="Sections du cockpit de match">'+
 tabs.map(([key,label])=>'<button class="v40-tab '+(matchCockpitFocus===key?'is-active':'')+
 '" aria-pressed="'+(matchCockpitFocus===key)+'" onclick="chooseMatchCockpitFocus(\''+key+'\')">'+label+'</button>').join('')+
 '<span class="v40-live-badge">'+(l.finished?'TERMINÉ':S.live?.paused?'PAUSE':'EN DIRECT')+
 ' · '+matchClock(l)+'</span></nav>';
}
function matchCockpitCardStatus(l,side,id){
 const sh=l.sheets[side],card=sh.cards?.find(x=>x.id===id&&x.until>l.minute);
 return sh.sentOff?.includes(id)?'Rouge':card?'Jaune':null;
}
function matchCockpitRoster(l,side){
 const sh=l.sheets[side],mine=side===l.userSide,clubName=S.clubs[l.pair[side]].name;
 const active=new Set(activePlayers(l,side).map(p=>p.id));
 const starters=sh.on.map((id,slot)=>{
  const p=id?matchPlayer(l,side,id):null,status=id?matchCockpitCardStatus(l,side,id):null;
  const eligible=mine&&S.live?.paused&&!S.live?.finished&&!presentationPending(S.live)?eligibleChanges(S.live,side,slot):[];
  const sub=mine?'<select aria-label="Remplaçant poste '+(slot+1)+'" '+(!eligible.length?'disabled':'')+
   ' onchange="if(this.value)substitute('+slot+',this.value)"><option value="">'+
   (eligible.length?'Changer…':'Indisponible')+'</option>'+
   eligible.map(x=>'<option value="'+visualEscape(x.id)+'">'+visualEscape(x.name)+' · '+Math.round(x.condition)+'%</option>').join('')+
   '</select>':'';
  const label=p?visualEscape(p.name):'Poste vacant';
  return '<div class="v40-roster-row '+(status?'v40-carded':'')+'"><span class="v40-shirt">'+(slot+1)+'</span>'+
  '<div class="v40-roster-person"><strong>'+(p?'<button class="v40-player-link" onclick="openMatchPlayer('+side+',\''+p.id+'\')">'+label+'</button>':label)+
  '</strong><small>'+visualEscape(POS[slot])+(status?' · '+status:!p?' · indisponible':'')+'</small></div>'+
  '<span class="v40-condition '+(p?.condition<55?'is-low':'')+'">'+(p?Math.round(p.condition)+'%':'—')+'</span>'+
  sub+'</div>';
 }).join('');
 const benchIds=(sh.nominated?.length?sh.nominated.filter(id=>!sh.initial.includes(id)):(sh.bench||[])).slice(0,8);
 const bench=benchIds.map((id,idx)=>{
  const p=matchPlayer(l,side,id),playing=active.has(id),card=matchCockpitCardStatus(l,side,id);
  return '<div class="v40-bench-row"><span class="v40-shirt is-bench">'+(idx+16)+'</span>'+
  '<span>'+visualEscape(p?.name||'Indisponible')+'</span><small>'+
  (playing?'Sur terrain':card||(!p?'Absent':sh.used.includes(id)?'Sorti':'Banc'))+'</small></div>';
 }).join('');
 const actions=mine?'<div class="v40-roster-actions"><button class="small" onclick="rugbyUseBench()" '+
  (!S.live?.paused||S.live.finished||presentationPending(S.live)?'disabled':'')+
  '>Changements conseillés par le staff</button></div>':'';
 return '<aside class="v40-roster card" aria-label="'+(mine?'Votre effectif en match':'Effectif adverse')+'">'+
 '<header><span class="eyebrow">'+(mine?'VOTRE XV':'ADVERSAIRE')+'</span><h2>'+visualEscape(clubName)+'</h2>'+
 '<small>'+active.size+' joueurs actuellement sur le terrain</small></header>'+
 '<div class="v40-roster-list">'+starters+'</div><details class="v40-bench" '+(mine?'open':'')+'><summary>Les remplaçants · '+benchIds.length+'/8</summary>'+
 '<div>'+bench+'</div></details>'+actions+'</aside>';
}
function matchCockpitMetrics(l){
 const a=l.stats[0],b=l.stats[1],mine=l.userSide;
 const metrics=[
  ['Possession',a.possession,b.possession,'%',true],
  ['Occupation',a.territory,b.territory,'%',true],
  ['Mêlées gagnées',a.scrumsWon,b.scrumsWon,'',false],
  ['Touches gagnées',a.lineoutsWon,b.lineoutsWon,'',false],
  ['Pénalités concédées',a.penalties,b.penalties,'',false],
  ['Cartons jaunes',a.yellows,b.yellows,'',false]
 ];
 return '<section class="card v40-stats" aria-label="Statistiques comparées"><div class="v40-panel-heading"><h2>Rapport de forces</h2>'+
 '<small>Données du moteur · '+matchClock(l)+'</small></div>'+
 '<div class="v40-stats-head"><span>'+visualEscape(S.clubs[l.pair[0]].abbr)+'</span><span>COMPARAISON</span>'+
 '<span>'+visualEscape(S.clubs[l.pair[1]].abbr)+'</span></div>'+
 metrics.map(([name,left,right,unit,ratio])=>{
  const total=left+right,percent=total?Math.round(left/total*100):50;
  const leftLabel=ratio?(total?percent+'%':'—'):left+unit,rightLabel=ratio?(total?(100-percent)+'%':'—'):right+unit;
  return '<div class="v40-metric"><div class="v40-metric-line"><b>'+leftLabel+'</b><span>'+name+'</span><b>'+rightLabel+
  '</b></div><div class="v40-meter" role="img" aria-label="'+name+' : '+leftLabel+' contre '+rightLabel+
  '"><span style="width:'+percent+'%"></span></div></div>';
 }).join('')+
 '<small class="v40-data-note">Pourcentages calculés à partir des compteurs existants ; aucun indicateur inventé.</small></section>';
}
function matchCockpitTactics(l){
 const source=S.live,side=l.userSide,canEdit=!!source?.paused&&!source.finished&&!presentationPending(source);
 const attack=source.tactics[side],defence=tacticalRules(source)?source.defences[side]:null;
 return '<section class="card v40-tactics" aria-label="Centre tactique en match"><div class="v40-panel-heading"><h2>Directeur tactique</h2>'+
 '<small>'+(canEdit?'MODIFICATIONS AUTORISÉES':'METTRE EN PAUSE POUR AGIR')+'</small></div>'+
 '<p class="v40-tactic-hint">Les consignes conservent exactement les coefficients du moteur rugby existant.</p>'+
 '<label for="v40-attack">Plan d’attaque</label><select id="v40-attack" '+(!canEdit?'disabled':'')+
 ' onchange="setLiveTactic(this.value)">'+Object.entries(TACTICS).map(([key,v])=>
 '<option value="'+key+'" '+(key===attack?'selected':'')+'>'+visualEscape(v[0])+'</option>').join('')+'</select>'+
 '<label for="v40-defence">Organisation défensive</label><select id="v40-defence" '+(!canEdit||!defence?'disabled':'')+
 ' onchange="setLiveDefence(this.value)">'+Object.entries(DEFENCES).map(([key,v])=>
 '<option value="'+key+'" '+(key===defence?'selected':'')+'>'+visualEscape(v[0])+'</option>').join('')+'</select>'+
 '<p class="v40-tactic-summary">'+visualEscape(TACTICS[attack]?.[1]||'')+'</p>'+
 '<p class="v40-tactic-summary">'+visualEscape(defence?DEFENCES[defence]?.[1]:'Ancienne rencontre : défense inchangée.')+'</p>'+
 '<div class="v40-decision-row"><button onclick="'+(source.paused?'continueMatch()':'pauseMatch()')+'" '+
 (source.finished?'disabled':'')+'>'+(source.paused?'Reprendre la rencontre':'Mettre en pause')+'</button></div>'+
 '<small class="v40-data-note">Remplacements, décisions de pénalité et consignes avancées : menu détaillé ci-dessous.</small></section>';
}

// Débrief en direct : lecture seule des compteurs natifs, sans tirage aléatoire ni sauvegarde.
function matchCockpitCoachBrief(l){
 const side=l.userSide,other=1-side,m=l.stats[side],o=l.stats[other];
 const possession=m.possession+o.possession;
 const territory=m.territory+o.territory;
 const poss=possession?Math.round(100*m.possession/possession):null;
 const field=territory?Math.round(100*m.territory/territory):null;
 const margin=l.score[side]-l.score[other];
 const notes=[];
 if(poss===null)notes.push('La possession sera analysée après les premières séquences.');
 else if(poss<42)notes.push('Vous avez peu le ballon ('+poss+' %) : privilégiez des séquences de conservation.');
 else if(poss>58)notes.push('Vous contrôlez le ballon ('+poss+' %) : exploitez cette possession sans vous précipiter.');
 else notes.push('Possession équilibrée ('+poss+' %) : chaque récupération peut faire la différence.');
 if(field!==null){
  if(field<43)notes.push('Occupation défavorable ('+field+' %) : cherchez à sortir de votre camp.');
  else if(field>57)notes.push('Vous occupez le terrain adverse ('+field+' %) : maintenez la pression.');
  else notes.push('Occupation partagée ('+field+' %) : surveillez les renvois et les sorties de camp.');
 }
 if(m.penalties>o.penalties+2)notes.push('Discipline : vous avez concédé '+(m.penalties-o.penalties)+' pénalités de plus que votre adversaire.');
 if(m.yellows>o.yellows)notes.push('Infériorité disciplinaire : surveillez vos joueurs sanctionnés.');
 if(margin<0)notes.push('Vous êtes menés de '+(-margin)+' points : adaptez votre gestion du risque au temps restant.');
 else if(margin>0)notes.push('Vous menez de '+margin+' points : protégez cet avantage sans abandonner le terrain.');
 else notes.push('Score à égalité : la prochaine séquence sera importante.');
 return '<section class="card v40-coach-brief" aria-label="Débrief tactique en direct"><div class="v40-panel-heading"><h2>Lecture du match</h2><small>'+matchClock(l)+'</small></div>'+
 '<ul>'+notes.map(note=>'<li>'+visualEscape(note)+'</li>').join('')+'</ul>'+
 '<small class="v40-data-note">Conseils indicatifs issus du score et des statistiques ; aucune consigne n’est modifiée automatiquement.</small></section>';
}

function matchCockpitView(l){
 const active=l.visualSource||l;
 return '<section class="v40-cockpit v40-focus-'+matchCockpitFocus+'" aria-label="Cockpit rugby V40">'+
 matchCockpitToolbar(l)+
 '<div class="v40-arena">'+matchCockpitRoster(l,l.userSide)+
 '<div class="v40-field-center">'+match2D(l)+'</div>'+
 matchCockpitRoster(l,1-l.userSide)+'</div>'+
 '<div class="v40-bottom">'+matchCockpitMetrics(l)+matchCockpitCoachBrief(l)+matchCommentary(l)+matchCockpitTactics(l)+'</div>'+
 '<div class="v40-footnote">Représentation 2D schématique des phases : elle ne constitue pas une reconstitution exacte des trajectoires. Les décisions et statistiques proviennent de la rencontre '+(active.finished?'terminée':'en cours')+'.</div></section>';
}
