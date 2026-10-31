'use strict';
// MATCHDAY-01 : un tableau d'aide à la décision, purement consultatif.
// Les applications d'une tactique restent réservées à adoptDossierPlan() du moteur.
function matchdayReadiness(){
 if(!S)return null;
 const errors=S.live||S.phase==='ended'?[]:sheetErrors();
 const selected=S.lineup.map(id=>player(id)).filter(Boolean);
 const substitutes=S.reserves.map(id=>player(id)).filter(Boolean);
 const tired=selected.filter(p=>p.condition<65||physicalLoadValue(p)>=55);
 const hurt=selected.filter(p=>p.injury>0);
 const benchHurt=substitutes.filter(p=>p.injury>0);
 const unfit=selected.filter(p=>p.condition<80||physicalLoadValue(p)>=35);
 const depth=POS.map((name,slot)=>{
  const eligible=club().players.filter(p=>!p.injury&&slotEligible(p,slot));
  const fresh=eligible.filter(p=>p.condition>=65&&physicalLoadValue(p)<55);
  const starters=selected.filter(p=>!p.injury&&slotEligible(p,slot));
  return {slot,name,eligible:eligible.length,fresh:fresh.length,covered:starters.length>0};
 });
 const dossier=(!S.live&&S.phase!=='ended')?matchDossier():null;
 const plan=dossier?.advice||null;
 const changed=!!plan&&(S.tactic!==plan.attack||(S.defence||'equilibre')!==plan.defence);
 const issues=[];
 if(errors.length)issues.push({kind:'sheet',severity:100,title:'Feuille à 23 non conforme',detail:errors[0]});
 if(hurt.length||benchHurt.length)issues.push({kind:'injury',severity:95,title:'Blessure dans les 23',
  detail:hurt.length+' titulaire(s) et '+benchHurt.length+' remplaçant(s) blessé(s)'});
 if(tired.length)issues.push({kind:'tired',severity:80,title:'Titulaires à ménager',
  detail:tired.length+' joueur(s) sous 65 % de condition ou au-dessus de 55/100 de charge'});
 if(depth.some(x=>x.fresh===0))issues.push({kind:'depth',severity:65,title:'Postes sans solution fraîche',
  detail:depth.filter(x=>x.fresh===0).length+' poste(s) sans joueur apte et suffisamment reposé'});
 if(changed)issues.push({kind:'plan',severity:45,title:'Plan du staff différent',
  detail:'Comparer les propositions avant de modifier les réglages du prochain match'});
 issues.sort((a,b)=>b.severity-a.severity||a.kind.localeCompare(b.kind,'fr'));
 return {season:S.season,round:S.round,phase:S.phase,selected:selected.length,
  substitutes:substitutes.length,errors:errors.slice(),tired:tired.map(p=>p.id),
  injured:hurt.map(p=>p.id),unfit:unfit.map(p=>p.id),depth,issues,
  opponent:dossier?{id:dossier.opponent.id,name:dossier.opponent.name,
   attack:dossier.own,defence:dossier.other,advice:plan}:null,
  plan:{attack:S.tactic,defence:S.defence||'equilibre',changed},
  canAdopt:!!dossier&&!S.live&&S.phase!=='ended',
  canPrepare:!S.live&&S.phase!=='ended'};
}
function matchdayReadinessView(){
 const d=matchdayReadiness();if(!d)return '';
 const escape=typeof visualEscape==='function'?visualEscape:(value=>String(value).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c])));
 const pills=[
  ['JOUEURS DU XV',d.selected+'/15'],['SUR LE BANC',d.substitutes+'/8'],
  ['TITULAIRES À MÉNAGER',d.tired.length],['POINTS À VÉRIFIER',d.issues.length]
 ].map(([title,value])=>'<div class="cd-matchday-kpi"><small>'+title+'</small><strong>'+value+'</strong></div>').join('');
 if(!d.canPrepare)return '<section class="card cd-matchday" aria-label="Préparation du prochain match"><div class="cardtitle">'+
  '<h2>Votre prochaine rencontre</h2><span class="tag">SUIVI</span></div>'+
  '<p>La préparation est indisponible pendant le match ou une fois la saison terminée. Retrouvez les choix de match après la rencontre.</p></section>';
 const issues=d.issues.map(x=>'<article class="cd-matchday-issue '+x.kind+'"><strong>'+escape(x.title)+'</strong>'+
  '<small>'+escape(x.detail)+'</small></article>').join('');
 const opponent=d.opponent;
 const current=TACTICS[d.plan.attack]?.[0]||d.plan.attack,defence=DEFENCES[d.plan.defence]?.[0]||d.plan.defence;
 const suggested=opponent?TACTICS[opponent.advice.attack]?.[0]+' · '+DEFENCES[opponent.advice.defence]?.[0]:'';
 const matchup=opponent?'<div class="cd-matchday-matchup"><h3>'+escape(opponent.name)+'</h3>'+
  '<p>Votre choix : <strong>'+escape(current)+' · '+escape(defence)+'</strong></p>'+
  '<p>Conseil du staff : <strong>'+escape(suggested)+'</strong></p>'+
  '<p class="help">'+escape(opponent.advice.attackReason)+'</p>'+
  '<p class="help">'+escape(opponent.advice.defenceReason)+'</p>'+
  '<p class="help">Projections avant match sur terrain sec, sans garantie de résultat. Les réglages locaux de votre plan de jeu gardent leur priorité.</p>'+
  '<button type="button" class="small" onclick="adoptDossierPlan()"'+
   (!d.plan.changed?' disabled':'')+'>'+
   (d.plan.changed?'Appliquer la recommandation du staff':'Recommandation déjà appliquée')+'</button>'+
  '</div>':'<p>Aucun adversaire connu à préparer à ce stade de la carrière.</p>';
 const depth=d.depth.filter(x=>x.fresh<2).slice(0,6).map(x=>'<span class="cd-matchday-depth">'+
  (x.slot+1)+' · '+escape(x.name)+' : '+x.fresh+' solution(s) fraîche(s)</span>').join('');
 return '<section class="card cd-matchday" aria-label="Préparation du prochain match">'+
  '<div class="cardtitle"><h2>Briefing d’avant-match</h2><span class="tag">CONSEILS DU STAFF</span></div>'+
  '<p class="help">Préparation de la journée '+(d.round+1)+'. Aucun réglage n’est modifié pendant la consultation.</p>'+
  '<div class="cd-matchday-kpis">'+pills+'</div>'+
  '<div class="cd-matchday-grid"><div><h3>État des 23</h3>'+
  (issues||'<p>La feuille de match et la condition des titulaires n’indiquent pas de risque prioritaire.</p>')+
  '<div class="cd-matchday-actions"><button type="button" onclick="prepareSquad(\'sheet\')">Vérifier les 23 →</button>'+
  '<button type="button" onclick="squadTab=\'health\';nav(\'team\')">Disponibilité & rotation →</button>'+
  '<button type="button" onclick="prepareSquad(\'depth\')">Couverture des postes →</button></div>'+
  (depth?'<h3>Postes à sécuriser</h3><div class="cd-matchday-depths">'+depth+'</div>':'')+
  '</div><div><h3>Choix tactiques</h3>'+matchup+
  '<div class="cd-matchday-actions"><button type="button" onclick="nav(\'plans\')">Personnaliser le plan →</button>'+
  '<button type="button" onclick="nav(\'match\')">Voir le dossier complet →</button></div>'+
  '</div></div></section>'+(typeof matchday03View==='function'?matchday03View():'')+(typeof matchday02View==='function'?matchday02View():'');
}
