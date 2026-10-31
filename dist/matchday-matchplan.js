'use strict';
// MATCHDAY-03: décisions conjointes de feuille et de plan avant-match.
// Projections consultatives sur terrain sec ; aucun effet moteur ajouté.
let matchday03Choice='staff';
const MATCHDAY03_SCENARIOS={
 staff:{label:'Lecture du staff',lineup:'equilibre',description:'Adapter la composition et le plan au rapport adverse natif.'},
 protection:{label:'Rotation protégée',lineup:'fraicheur',description:'Ménager les joueurs usés et sécuriser la défense.'},
 initiative:{label:'Prendre l’initiative',lineup:'performance',description:'Privilégier le potentiel offensif, avec une charge de jeu accrue.'}
};
function matchday03Allowed(){return typeof matchday02Allowed==='function'&&matchday02Allowed()}
function matchday03Token(){
 if(!matchday03Allowed())return '';
 const d=matchDossier();
 return [matchday02Fingerprint(),S.tactic,S.defence||'equilibre',d?.opponent?.id??'-',S.history.length].join(':');
}
function matchday03Fixtures(){
 if(!S||S.phase==='ended')return [];
 const upcoming=S.phase==='league'?S.schedule.slice(S.round,S.round+3).map((pairs,offset)=>({
  round:S.round+offset,phase:'league',pair:pairs.find(pair=>pair.includes(S.club))
 })):[{round:S.round,phase:S.phase,pair:nextMatch()}];
 return upcoming.filter(x=>x.pair).map(x=>({
  round:x.round,phase:x.phase,opponent:S.clubs[x.pair.find(id=>id!==S.club)].name,
  home:x.pair[0]===S.club
 }));
}
function matchday03Proposal(choice='staff'){
 if(!matchday03Allowed()||!Object.hasOwn(MATCHDAY03_SCENARIOS,choice))return null;
 const mode=MATCHDAY03_SCENARIOS[choice],selection=matchday02Proposal(mode.lineup);
 const dossier=matchDossier();
 if(!selection||!dossier)return null;
 const own=dossierMetrics(club(),selection.sheet.lineup);
 const other=dossier.other,advice=dossierAdvice(own,other);
 let attack=advice.attack,defence=advice.defence;
 if(choice==='protection'){
  defence='prudente';
  if(attack==='large')attack='equilibre';
 }
 if(choice==='initiative'){
  attack=own.backs>=own.power?'large':'conquete';
  defence=own.fitness>=80&&own.discipline>=65?'pression':'equilibre';
 }
 const sectors=[
  {name:'Puissance des avants',ours:own.power,opponent:other.power},
  {name:'Passe et vitesse',ours:own.backs,opponent:other.backs},
  {name:'Jeu au pied',ours:own.kick,opponent:other.kick},
  {name:'Discipline',ours:own.discipline,opponent:other.discipline},
  {name:'Défense',ours:own.tackle,opponent:other.tackle}
 ];
 const current=dossierMetrics(club(),S.lineup);
 return {choice,mode,selection,dossier,attack,defence,own,other,current,
  sectors,fixtures:matchday03Fixtures(),token:matchday03Token(),
  changes:selection.changes.length,
  differs:selection.changes.length>0||attack!==S.tactic||defence!==(S.defence||'equilibre')};
}
function matchday03Choose(choice){
 if(!matchday03Allowed()||!Object.hasOwn(MATCHDAY03_SCENARIOS,choice))return false;
 matchday03Choice=choice;render();return true;
}
function matchday03Apply(choice,token){
 if(!matchday03Allowed()||!Object.hasOwn(MATCHDAY03_SCENARIOS,choice)){
  toast('Décision indisponible en match ou hors préparation.');return false;
 }
 if(token!==matchday03Token()){
  toast('Le contexte sportif a changé : vérifiez votre nouvelle proposition.');render();return false;
 }
 const proposal=matchday03Proposal(choice);
 if(!proposal||proposal.token!==token||proposal.selection.errors.length||
    !Object.hasOwn(TACTICS,proposal.attack)||!Object.hasOwn(DEFENCES,proposal.defence)){
  toast('Plan ou feuille incomplet : action refusée.');render();return false;
 }
 if(!proposal.differs){
  toast('Ce scénario est déjà appliqué.');return true;
 }
 S.lineup=proposal.selection.sheet.lineup.slice();
 S.reserves=proposal.selection.sheet.bench.slice();
 S.tactic=proposal.attack;
 S.defence=proposal.defence;
 save();render();toast('Composition et plan de match appliqués ensemble.');
 return true;
}
function matchday03View(){
 if(!matchday03Allowed())return '';
 const p=matchday03Proposal(matchday03Choice);if(!p)return '';
 const esc=typeof visualEscape==='function'?visualEscape:(v=>
  String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;'}[c])));
 const options=Object.entries(MATCHDAY03_SCENARIOS).map(([key,s])=>
  '<button type="button" class="'+(key===matchday03Choice?'dark':'')+
  '" aria-pressed="'+(key===matchday03Choice)+'" onclick="matchday03Choose(\''+key+'\')">'+
  '<strong>'+esc(s.label)+'</strong><small>'+esc(s.description)+'</small></button>').join('');
 const threat=p.dossier.threats.slice(0,3).map(t=>'<li>'+esc(t.name)+' · '+esc(t.role)+
  ' · '+esc(t.pos)+'</li>').join('');
 const sectors=p.sectors.map(s=>{
  const delta=Math.round(s.ours-s.opponent);
  return '<tr><th>'+esc(s.name)+'</th><td>'+Math.round(s.ours)+'</td><td>'+
   Math.round(s.opponent)+'</td><td>'+((delta>=0?'+':'')+delta)+'</td></tr>';
 }).join('');
 const fixtures=p.fixtures.map(x=>'<span class="cd-cmd-fixture">'+
  (x.phase==='league'?'J'+(x.round+1):esc(x.phase))+' · '+
  (x.home?'Réception':'Déplacement')+' · '+esc(x.opponent)+'</span>').join('');
 const error=p.selection.errors.length?'<p class="notice danger" role="alert">'+
  esc(p.selection.errors.slice(0,3).join(' '))+'</p>':'';
 const label=TACTICS[p.attack]?.[0]||p.attack;
 const defence=DEFENCES[p.defence]?.[0]||p.defence;
 const pAvg=Math.round(p.own.fitness),currentAvg=Math.round(p.current.fitness);
 return '<section class="card cd-cmd" aria-label="Poste de décision avant-match">'+
  '<div class="cardtitle"><h2>Poste de décision du manager</h2><span class="tag">COMPOSITION + TACTIQUE</span></div>'+
  '<p class="help">Explorez trois scénarios complets face à '+esc(p.dossier.opponent.name)+
  '. Prévisions indicatives sur terrain sec, sans garantie de résultat. Votre plan local personnalisé reste prioritaire.</p>'+
  '<div class="cd-cmd-choices" role="group" aria-label="Scénarios de match">'+options+'</div>'+
  '<div class="cd-cmd-metrics"><div><small>Changements sur les 23</small><strong>'+p.changes+
  '</strong></div><div><small>Condition du XV proposée</small><strong>'+pAvg+
  '%</strong><small>Actuel : '+currentAvg+' %</small></div><div><small>Joueurs à ménager</small><strong>'+
  p.selection.risk+'</strong></div></div>'+
  '<div class="cd-cmd-columns"><div><h3>Feuille et stratégie proposées</h3>'+
  '<p>Attaque : <strong>'+esc(label)+'</strong></p><p>Défense : <strong>'+esc(defence)+'</strong></p>'+
  '<p class="help">Actuellement : '+esc(TACTICS[S.tactic]?.[0]||S.tactic)+' / '+
  esc(DEFENCES[S.defence||'equilibre']?.[0]||S.defence)+'</p>'+
  '<p class="help">'+esc(p.mode.description)+'</p>'+
  '<h3>Duels par secteur</h3><div class="cd-cmd-scroll"><table><thead>'+
  '<tr><th>Secteur</th><th>Votre XV</th><th>Adverse</th><th>Écart</th></tr></thead><tbody>'+
  sectors+'</tbody></table></div></div>'+
  '<div><h3>Menaces adverses</h3><ul>'+threat+'</ul>'+
  '<h3>À venir</h3><div class="cd-cmd-fixtures">'+fixtures+'</div>'+
  '<p class="help">Rotation proposée uniquement pour le prochain match : aucune programmation ou mutation des journées futures.</p>'+
  '<div class="cd-cmd-actions"><button type="button" class="dark" onclick="matchday03Apply(\''+
  p.choice+'\',\''+p.token+'\')"'+(p.selection.errors.length||!p.differs?' disabled':'')+
  '>Appliquer XV, banc et tactique</button>'+
  '<button type="button" onclick="prepareSquad(\'sheet\')">Ajuster manuellement les 23</button>'+
  '<button type="button" onclick="nav(\'plans\')">Consignes locales</button></div></div></div>'+
  error+'</section>';
}
