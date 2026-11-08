'use strict';
// V69 — briefing strategique : choix cible, explicite, fige au coup d'envoi.
// Coefficients fictifs et limites, sans nouvelle loi ni tirage aleatoire.
const V69_PLANS=Object.freeze({
 neutre:{label:'Lecture ouverte',desc:'Aucune specialisation : conserver la polyvalence.'},
 pack:{label:'Cibler les avants',desc:'Insister au pres contre le pack adverse ; moins de preparation pour le large.'},
 espaces:{label:'Cibler les espaces',desc:'Exploiter les duels de passe et vitesse ; moins de preparation pour le jeu au pres.'},
 couverture:{label:'Fermer le large',desc:'Anticiper les attaques et proteger les espaces ; couverture moins adaptee au jeu au pres.'}
});
function v69Context(d){
 if(!S||S.live||S.phase==='ended'||!d)return null;
 return [S.season,S.franceMode?.version===1?S.franceMode.week:S.round,S.phase,S.club,d.opponent.id].join(':');
}
function v69Selection(d){
 const key=v69Context(d),stored=S?.v69Briefing;
 return key&&stored&&stored.context===key&&Object.hasOwn(V69_PLANS,stored.plan)?stored.plan:'neutre';
}
function v69Evidence(d){
 const signals=typeof dossierScoutSignals==='function'?dossierScoutSignals(d.recent):[];
 const pack=Math.round(d.own.power-d.other.power);
 const backs=Math.round(d.own.backs-d.other.backs);
 const danger=Math.round(d.other.backs-d.own.tackle);
 return {pack,backs,danger,signals};
}
function v69Set(plan,expectedContext){
 if(!Object.hasOwn(V69_PLANS,plan)||!S||S.live||S.phase==='ended')return false;
 const d=matchDossier(),actual=v69Context(d);
 if(!actual||actual!==expectedContext)return false;
 S.v69Briefing={version:1,context:actual,plan};
 save();render();return true;
}
function v69BriefingView(){
 const d=matchDossier();if(!d||S.live||S.phase==='ended')return '';
 const esc=typeof visualEscape==='function'?visualEscape:(s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])));
 const e=v69Evidence(d),current=v69Selection(d),context=v69Context(d);
 const signed=n=>(n>=0?'+':'')+n;
 const options=Object.entries(V69_PLANS).map(([id,p])=>
  '<button type="button" class="option '+(current===id?'selected':'')+'" aria-pressed="'+(current===id)+'" onclick="v69Set(\''+id+'\',\''+context+'\')"><strong>'+esc(p.label)+'</strong><small>'+esc(p.desc)+'</small></button>').join('');
 const observations=e.signals.slice(0,2).map(s=>'<li>'+esc(s.title)+' — '+esc(s.evidence)+'</li>').join('');
 return '<section class="card v69-briefing" aria-label="Briefing strategique avant-match">'+
 '<div class="cardtitle"><h2>V69 / Briefing strategique cible</h2><span class="tag">DECISION DU MANAGER</span></div>'+
 '<p>Face a <strong>'+esc(d.opponent.name)+'</strong>, choisissez UNE priorité apres lecture des duels. Le plan general et les consignes locales restent independants.</p>'+
 '<div class="cd-matchday-kpis"><div><small>Rapport de puissance des avants</small><strong>'+signed(e.pack)+'</strong></div>'+
 '<div><small>Passe / vitesse comparees</small><strong>'+signed(e.backs)+'</strong></div>'+
 '<div><small>Vitesse adverse face a nos plaquages</small><strong>'+signed(e.danger)+'</strong></div></div>'+
 (observations?'<h3>Indices archives (V62)</h3><ul>'+observations+'</ul>':'<p class="help">Archives insuffisantes pour conclure sur une tendance repetee : estimations fondees sur les XV projetes.</p>')+
 '<div class="options" style="grid-template-columns:repeat(2,minmax(0,1fr))">'+options+'</div>'+
 '<p class="help"><strong>Choix retenu : '+esc(V69_PLANS[current].label)+'.</strong> Au coup d\'envoi, l\'effet est fige pour ce match. Ciblage des avants : jusqu\'a +3,5 points sur les resolutions au pres, contre -0,8 au large ; ciblage des espaces : meme gain conditionnel au large, contre -0,8 au pres ; couverture : jusqu\'a -3,0 points sur les attaques larges adverses, contre +0,8 au pres. Ces ajustements du moteur fictif ne modifient ni l\'issue garantie ni les regles rugby. Une nouvelle rencontre requiert un nouveau choix.</p></section>';
}
// Le panneau matchday est deja un point d'entree : ajout uniquement, sans copie.
if(!globalThis.CDNativeHeadless&&typeof matchdayReadinessView==='function'){
 const v69MatchdayViewBefore=matchdayReadinessView;
 matchdayReadinessView=function(){return v69MatchdayViewBefore()+v69BriefingView()};
}
const v69CreateMatchBefore=createRugbyMatch;
createRugbyMatch=function(pair,legacy=null,automated=false,preparation=null){
 const d=!legacy&&!automated&&pair.includes(S.club)?preparation||matchDossier():null;
 const context=v69Context(d),plan=context?v69Selection(d):'neutre';
 const match=v69CreateMatchBefore(pair,legacy,automated,preparation);
 if(context&&match.userSide>=0&&match.tacticalVersion===1){
  const evidence=v69Evidence(d);
  match.v69Briefing={version:1,plan,side:match.userSide,opponent:d.opponent.id,
   strength:{pack:evidence.pack,backs:evidence.backs,danger:evidence.danger}};
 }
 return match;
};
const v69TacticalEdgeBefore=tacticalEdge;
tacticalEdge=function(l,side){
 const base=v69TacticalEdgeBefore(l,side),b=l?.v69Briefing;
 if(!b||b.version!==1||!Object.hasOwn(V69_PLANS,b.plan)||l.tacticalVersion!==1||l.finished)return base;
 if(![0,1].includes(b.side)||l.pair[1-b.side]!==b.opponent)return base;
 const attack=effectiveAttack(l,side),own=side===b.side;
 if(b.plan==='pack'&&own)return base+(attack==='conquete'?Math.min(.035,Math.max(.005,.018+b.strength.pack*.0007)):-.008);
 if(b.plan==='espaces'&&own)return base+(attack==='large'?Math.min(.035,Math.max(.005,.018+b.strength.backs*.0007)):-.008);
 if(b.plan==='couverture'&&!own)return base+(attack==='large'? -Math.min(.03,Math.max(.005,.017+b.strength.danger*.0005)):.008);
 return base;
};
