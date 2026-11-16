'use strict';
// Structured action facts are recorded by the engine, never inferred from prose.
// Optional facts already known to the caller (no draw, no state change): why the ball left play
// or was made dead, the colour of a card, the try's origin and whether it was converted, the tackler of a carry.
const ACTION_CAUSES={touch:['carry-touch','indirect-touch','direct-touch','penalty-touch','50-22','missed-goal-touch','period-end'],ingoal:['held-up','attacking-kick-grounded','ingoal-knock-on','kick-dead','defender-grounded'],'hand-fault':['knock-on','forward-pass'],penalty:['offside','ruck','holding','obstruction','dangerous','scrum','maul','not-release','sealing']};
const ACTION_CARDS=['yellow','red20','red'],ACTION_TRY_ORIGINS=['open','maul','scrum'];
const ACTION_KINDS=['message','carry','turnover','scrum','lineout','setpiece-win','setpiece-loss','kick','kickoff','drop22','goalLine','reception','touch','hand-fault','quick-tap','try','goal','miss','penalty','advantage','card','sub','tactic','break','end','ingoal'];
const ACTION_LABELS={message:'Jeu courant',carry:'Progression',turnover:'Récupération',scrum:'Mêlée',lineout:'Touche','setpiece-win':'Ballon conservé','setpiece-loss':'Ballon récupéré',kick:'Jeu au pied',kickoff:'Renvoi au centre',drop22:'Renvoi aux 22',goalLine:'Renvoi sur la ligne',reception:'Réception',touch:'Sortie en touche','hand-fault':'Faute de main','quick-tap':'Pénalité jouée à la main',try:'Essai',goal:'Pénalité réussie',miss:'Tir manqué',penalty:'Pénalité',advantage:'Avantage',card:'Discipline',sub:'Remplacement',tactic:'Consigne',break:'Mi-temps',end:'Fin du match',ingoal:'En-but'};
const MATCH_PLAYBACK=new WeakMap();
let pauseOnTry=false,pauseOnCard=false;
try{const prefs=JSON.parse(gameStorage.getItem('bdt-match-view'));pauseOnTry=prefs?.try===true;pauseOnCard=prefs?.card===true}catch(e){}
function actionPlayer(l,side,role='carrier'){
 const players=activePlayers(l,side),preferred=players.filter(p=>role==='kicker'?p.fam>=4:role==='receiver'?p.fam>=6:role==='defender'?p.fam>=2&&p.fam<=3:effectiveAttack(l,side)==='conquete'?p.fam<=3:p.fam>=3);
 const pool=preferred.length?preferred:players;return pool.length?pool[(l.minute+side)%pool.length]:null;
}
// Plaqueur d'un temps de jeu (fait `tackler` du journal) : choisi sans tirage, d'après l'état du match.
// Couloir défensif de chaque poste (slot 0 = n° 1) en largeur (0 à 70), celui où court le porteur
// (même table), le gain (court : un avant au contact ; de 10 à 21 m : le couloir, l'arrière garde la
// profondeur ; franchissement de 22 m et plus : la couverture, l'arrière d'abord), les troisièmes
// lignes (plus souvent au plaquage), le demi de mêlée (moins) et la fatigue (un joueur entamé plaque moins).
const DEFENCE_LANES=[33,35,37,30,40,24,46,35,35,28,6,20,50,64,35];
function carryTackler(l,side,carrierId,gain){
 const opp=1-side,on=l.sheets[opp]?.on;if(!Array.isArray(on))return null;
 const active=new Set(activePlayers(l,opp).map(p=>p.id)),at=l.sheets[side].on.indexOf(carrierId),lane=DEFENCE_LANES[at]??35;
 let best=null,score=Infinity;
 on.forEach((id,slot)=>{
  if(id==null||!active.has(id)||slot>14)return;
  const forward=slot<8,condition=Number(matchPlayer(l,opp,id)?.condition);
  let s=Math.abs(DEFENCE_LANES[slot]-lane);
  if(gain>=22)s+=slot===14?-40:slot===10||slot===13?-8:60; // couverture même sans arrière sur le terrain (carton, sortie)
  else if(gain>=10)s+=slot===14?12:forward?4:0;
  else s+=forward?0:60; // gain court : toujours un avant (les ailiers portent plus depuis les essais réalistes : écart de couloir jusqu'à 40)
  if(slot===5||slot===6)s-=3;else if(slot===8)s+=6;
  if(Number.isFinite(condition))s+=Math.max(0,100-condition)*.2;
  if(s<score){score=s;best=id}
 });
 return best;
}
function actionName(l,side,role){return actionPlayer(l,side,role)?.name||S.clubs[l.pair[side]].abbr}

// Consignes individuelles (docs/consignes-individuelles-20261116.md) : le manager désigne son buteur, un
// buteur de secours, son lanceur en touche et son joueur au pied d'occupation (S.playerRoles). Sans
// désignation, le staff choisit le meilleur à chaque rôle, comme les clubs de l'IA : c'est le calcul
// d'avant, à l'identique. Les désignations sont copiées au coup d'envoi (l.playerRoles) pour les rencontres
// créées avec `playerRolesVersion` ; un match commencé avant garde ses règles. Aucun tirage : la suite des
// tirages ne change pas, seules les probabilités et les distances suivent le joueur choisi.
let PLAYER_ROLES_RULES=1;
const PLAYER_ROLES={buteur:['Buteur','goal'],secours:['Buteur de secours','goal'],lanceur:['Lanceur en touche','lineout'],pied:['Jeu au pied d’occupation','kick']};
// Coefficients de jeu (non mesurés, ordres de grandeur) : touche gagnée par point de « touche » d'écart avec
// le talonneur en jeu, malus d'un lanceur qui n'est pas talonneur, mètres par point de « jeu au pied ».
const PLAYER_ROLE_COEFS={lancer:.004,nonTalonneur:.05,pied:.25};
function playerRolesRules(l){return l.playerRolesVersion===1&&Array.isArray(l.playerRoles)}
// Désignations valides pour une feuille : seulement des joueurs de la feuille (titulaires et remplaçants).
function sanitizePlayerRoles(roles,ids){
 const out={},known=new Set((ids||[]).filter(Boolean));
 if(!roles||typeof roles!=='object')return out;
 for(const key of Object.keys(PLAYER_ROLES)){const id=roles[key];if(typeof id==='string'&&known.has(id))out[key]=id}
 if(out.secours&&out.secours===out.buteur)delete out.secours;
 return out;
}
function initializePlayerRoles(l){
 if(!PLAYER_ROLES_RULES)return;
 l.playerRolesVersion=1;
 l.playerRoles=l.pair.map((ci,side)=>ci===S.club?sanitizePlayerRoles(S.playerRoles,[...l.sheets[side].on,...l.sheets[side].bench]):{});
}
function designatedPlayer(l,side,role){
 if(!playerRolesRules(l))return null;const id=l.playerRoles[side]?.[role];if(!id)return null;
 return activePlayers(l,side).find(p=>p.id===id)||null;
}
// Choix du staff : meilleur buteur en jeu (calcul d'origine), talonneur en jeu au lancer, meilleur
// botteur parmi les arrières au jeu au pied.
function staffRolePlayer(l,side,role){
 const on=activePlayers(l,side);
 if(role==='buteur'||role==='secours')return chooseScorer(S.clubs[l.pair[side]],on.map(p=>p.id));
 if(role==='lanceur'){const id=l.sheets[side].on[1];return on.find(p=>p.id===id&&p.fam===1)||[...on.filter(p=>p.fam===1)].sort((a,b)=>skill(b,'lineout',true)-skill(a,'lineout',true))[0]||null}
 if(role==='pied')return [...on.filter(p=>p.fam>=4)].sort((a,b)=>skill(b,'kick',true)-skill(a,'kick',true))[0]||null;
 return null;
}
// Buteur d'une tentative : le buteur désigné, à défaut le buteur de secours, à défaut le choix du staff.
function goalKicker(l,side){return designatedPlayer(l,side,'buteur')||designatedPlayer(l,side,'secours')||staffRolePlayer(l,side,'buteur')}
// Écart de réussite en touche dû au lanceur désigné (0 sans désignation : calcul d'avant).
function lineoutThrowEdge(l,side){
 const thrower=designatedPlayer(l,side,'lanceur');if(!thrower)return 0;
 const ref=staffRolePlayer(l,side,'lanceur');if(!ref||ref.id===thrower.id)return 0;
 const diff=(skill(thrower,'lineout',true)-skill(ref,'lineout',true))*PLAYER_ROLE_COEFS.lancer;
 return thrower.fam===1?diff:Math.min(0,diff)-PLAYER_ROLE_COEFS.nonTalonneur;
}
// Mètres gagnés ou perdus au pied d'occupation par le botteur désigné (0 sans désignation).
function occupationKickEdge(l,side){
 const kicker=designatedPlayer(l,side,'pied');if(!kicker)return 0;
 const ref=staffRolePlayer(l,side,'pied');if(!ref||ref.id===kicker.id)return 0;
 return (skill(kicker,'kick',true)-skill(ref,'kick',true))*PLAYER_ROLE_COEFS.pied;
}
function occupationKicker(l,side){return designatedPlayer(l,side,'pied')||actionPlayer(l,side,'kicker')}
// Désignations du manager hors match (null : rendre le rôle au staff). Refus : rôle inconnu, joueur hors effectif.
function setPlayerRoles(roles){
 if(!roles||typeof roles!=='object'||Array.isArray(roles))return false;
 const own=club(),next={...(S.playerRoles||{})};
 for(const [key,id] of Object.entries(roles)){
  if(!Object.hasOwn(PLAYER_ROLES,key))return false;
  if(id===null){delete next[key];continue}
  if(typeof id!=='string'||!own.players.some(p=>p.id===id))return false;
  next[key]=id;
 }
 if(next.secours&&next.secours===next.buteur)delete next.secours;
 for(const key of Object.keys(next))if(!own.players.some(p=>p.id===next[key]))delete next[key];
 if(Object.keys(next).length)S.playerRoles=next;else delete S.playerRoles;
 return true;
}
// Lecture pour l'interface : pour chaque rôle, choix du staff, joueur désigné et candidats du XV
// (valeur de l'attribut du rôle, condition comprise). Alerte quand le buteur désigné tire nettement moins
// bien que le choix du staff (seuil en points d'attribut).
const PLAYER_ROLE_ALERT=8;
function playerRolesView(){
 const own=club(),xv=S.lineup.map(id=>own.players.find(p=>p.id===id)).filter(Boolean),designated=S.playerRoles||{};
 const value=(p,k)=>p?Math.round(skill(p,k,true)):null,brief=(p,k)=>p?{id:p.id,name:p.name,pos:p.pos,value:value(p,k)}:null;
 const staffOf=role=>{const k=PLAYER_ROLES[role][1];if(role==='buteur')return chooseScorer(own,S.lineup);if(role==='secours'){const first=designated.buteur&&S.lineup.includes(designated.buteur)?designated.buteur:chooseScorer(own,S.lineup)?.id;return chooseScorer(own,S.lineup.filter(id=>id&&id!==first))}if(role==='lanceur')return own.players.find(p=>p.id===S.lineup[1]&&p.fam===1)||[...xv.filter(p=>p.fam===1)].sort((a,b)=>skill(b,k,true)-skill(a,k,true))[0]||null;return [...xv.filter(p=>p.fam>=4)].sort((a,b)=>skill(b,k,true)-skill(a,k,true))[0]||null};
 const roles=Object.entries(PLAYER_ROLES).map(([id,[label,k]])=>{const chosen=own.players.find(p=>p.id===designated[id])||null;return {id,label,attribute:k,attributeLabel:ATTR[k]||k,staff:brief(staffOf(id),k),chosen:brief(chosen,k),inLineup:!!chosen&&S.lineup.includes(chosen.id),candidates:[...xv].sort((a,b)=>skill(b,k,true)-skill(a,k,true)||String(a.id).localeCompare(String(b.id))).map(p=>brief(p,k))}});
 const buteur=roles.find(r=>r.id==='buteur'),alerte=buteur.chosen&&buteur.staff&&buteur.inLineup&&buteur.staff.value-buteur.chosen.value>=PLAYER_ROLE_ALERT?{playerId:buteur.chosen.id,name:buteur.chosen.name,value:buteur.chosen.value,staffName:buteur.staff.name,staffValue:buteur.staff.value}:null;
 return {editable:!S.live&&S.phase!=='ended',roles,alerte};
}
function captureMatchAction(l,type,meta={}){
 if(l.userSide<0)return undefined;
 const prior=l.events.at(-1)?.scene,kind=meta.kind||(['turnover','try','goal','penalty','advantage','card','sub','tactic','break','end'].includes(type)?type:'message');
 const team=meta.team??l.possession;
 const neutral=['message','card','sub','tactic','break','end','advantage'].includes(kind);
 const base={x:neutral&&prior?prior.to.x:l.territory,y:prior?.to.y??35};
 const from={...(meta.from||base)},to={...(meta.to||from)};
 return {v:1,kind,team,...(meta.move?{move:meta.move}:{}),...(ACTION_CAUSES[kind]?.includes(meta.cause)?{cause:meta.cause}:{}),...(kind==='card'&&ACTION_CARDS.includes(meta.card)?{card:meta.card}:{}),...(kind==='try'&&ACTION_TRY_ORIGINS.includes(meta.origin)&&typeof meta.conversion==='boolean'?{origin:meta.origin,conversion:meta.conversion}:{}),...(kind==='carry'&&meta.tackler!=null?{tackler:meta.tackler}:{}),style:effectiveAttack(l,team),...(tacticalRules(l)?{plans:{attack:[0,1].map(side=>effectiveAttack(l,side)),defence:[0,1].map(side=>effectiveDefence(l,side))}}:{}),incident:meta.incident===true,possession:meta.possession??l.possession,actor:meta.actor??null,from,to,score:[...l.score],tries:[...l.tries],on:l.sheets.map((sh,side)=>{const active=new Set(activePlayers(l,side).map(p=>p.id));return sh.on.map(id=>active.has(id)?id:null)}),period:l.flow?.period||(l.minute>40?2:1)};
}
function playback(l){l=l.visualSource||l;let p=MATCH_PLAYBACK.get(l);if(!p){p={cursor:l.events.length-1,stop:false};MATCH_PLAYBACK.set(l,p)}return p}
function presentationPending(l){l=l.visualSource||l;return playback(l).cursor<l.events.length-1}
function displayedAction(l){l=l.visualSource||l;return l.events[playback(l).cursor]||null}
function syncMatchPresentation(l){l=l.visualSource||l;MATCH_PLAYBACK.set(l,{cursor:l.events.length-1,stop:false})}
function matchViewState(l){
 const p=playback(l),e=displayedAction(l),s=e?.scene;if(!s||!presentationPending(l))return l;
 const flow=l.flow?{...l.flow,period:s.period,atBreak:false}:undefined;
 return {...l,...(s.plans?{tactics:s.plans.attack,defences:s.plans.defence}:{}),visualSource:l,minute:e.min,score:s.score,tries:s.tries,possession:s.possession,territory:s.to.x,paused:false,finished:false,...(flow?{flow}:{})};
}
function presentationTick(l){
 const p=playback(l);let changed=false;
 if(presentationPending(l))p.cursor++;
 else{
  if(l.paused||l.finished)return;
  changed=true;const before=l.events.length;p.running=true;try{advanceRugby(l)}finally{p.running=false}
  p.cursor=l.events.length>before?before:l.events.length-1;
  p.stop=l.events.slice(before).some(e=>pauseOnTry&&e.type==='try'||pauseOnCard&&e.type==='card'&&e.scene?.incident);
 }
 if(!presentationPending(l)&&p.stop&&!l.finished){l.paused=true;p.stop=false;changed=true;}
 if(!presentationPending(l)&&(l.paused||l.finished))clearInterval(timer);
 if(changed)save();render();
}
function setAutoPause(kind,enabled){if(kind==='try')pauseOnTry=!!enabled;if(kind==='card')pauseOnCard=!!enabled;try{gameStorage.setItem('bdt-match-view',JSON.stringify({try:pauseOnTry,card:pauseOnCard}))}catch(e){}render()}
function autoPauseControls(){return `<fieldset class="auto-pause"><legend>Pause après la séquence</legend><label><input type="checkbox" ${pauseOnTry?'checked':''} onchange="setAutoPause('try',this.checked)"> Essai</label><label><input type="checkbox" ${pauseOnCard?'checked':''} onchange="setAutoPause('card',this.checked)"> Carton</label></fieldset>`}
function openMatchPlayer(side,id){
 const l=S.live;if(!l||![0,1].includes(side))return;
 const p=matchPlayer(l,side,id);if(!p)return;
 pauseMatch();syncMatchPresentation(l);
 const slot=l.sheets[side].on.indexOf(id),active=activePlayers(l,side).some(p=>p.id===id),mine=side===l.userSide;
 const choices=mine&&active&&slot>=0&&!l.finished?eligibleChanges(l,side,slot):[];
 modal=`<div class="modalback"><section class="modal playerdetail" role="dialog" aria-modal="true" aria-label="Joueur sur le terrain"><div class="row" style="margin-top:0"><span class="tag">${S.clubs[l.pair[side]].abbr} · ${p.pos}</span><button class="small" onclick="closeModal()">Fermer ×</button></div><h2>${visualEscape(p.name)}</h2><p>Condition : <strong>${Math.round(p.condition)}%</strong> · Note au poste : <strong>${roleNote(p)}</strong><br>Minutes jouées : ${Math.round(l.sheets[side].minutes[id]||0)}</p><div class="attributes">${Object.entries(ATTR).map(([key,label])=>`<div class="row"><span>${label}</span><strong>${Math.round(skill(p,key))}</strong></div>`).join('')}</div>${choices.length?`<label for="pitch-sub">Faire entrer à sa place</label><select id="pitch-sub" onchange="if(this.value)replaceMatchPlayer(${slot},this.value)"><option value="">Choisir un remplaçant…</option>${choices.map(c=>`<option value="${c.id}">${visualEscape(c.name)} · ${Math.round(c.condition)}%</option>`).join('')}</select>`:`<p class="help">${!mine?'Joueur adverse.':!active?'Ce joueur n’est plus présent sur le terrain.':l.finished?'Le match est terminé.':'Aucun remplacement disponible à ce poste.'}</p>`}<p class="help">${l.finished?'Le match est terminé.':'Le match reste en pause après fermeture.'}</p></section></div>`;render();
}
function replaceMatchPlayer(slot,id){const l=S.live;if(!l?.paused||l.finished)return;if(makeSub(l,l.userSide,slot,id)){modal=null;syncMatchPresentation(l);save();render();toast('Remplacement effectué.')}else toast('Ce remplacement n’est plus disponible.')}
