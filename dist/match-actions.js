'use strict';
// Structured action facts are recorded by the engine, never inferred from prose.
const ACTION_KINDS=['message','carry','turnover','scrum','lineout','setpiece-win','setpiece-loss','kick','kickoff','drop22','goalLine','reception','touch','hand-fault','try','goal','miss','penalty','advantage','card','sub','tactic','break','end','ingoal'];
const ACTION_LABELS={message:'Jeu courant',carry:'Progression',turnover:'Récupération',scrum:'Mêlée',lineout:'Touche','setpiece-win':'Ballon conservé','setpiece-loss':'Ballon récupéré',kick:'Jeu au pied',kickoff:'Renvoi au centre',drop22:'Renvoi aux 22',goalLine:'Renvoi sur la ligne',reception:'Réception',touch:'Sortie en touche','hand-fault':'Faute de main',try:'Essai',goal:'Pénalité réussie',miss:'Tir manqué',penalty:'Pénalité',advantage:'Avantage',card:'Discipline',sub:'Remplacement',tactic:'Consigne',break:'Mi-temps',end:'Fin du match',ingoal:'En-but'};
const MATCH_PLAYBACK=new WeakMap();
let pauseOnTry=false,pauseOnCard=false;
try{const prefs=JSON.parse(gameStorage.getItem('bdt-match-view'));pauseOnTry=prefs?.try===true;pauseOnCard=prefs?.card===true}catch(e){}
function actionPlayer(l,side,role='carrier'){
 const players=activePlayers(l,side),preferred=players.filter(p=>role==='kicker'?p.fam>=4:role==='receiver'?p.fam>=6:role==='defender'?p.fam>=2&&p.fam<=3:effectiveAttack(l,side)==='conquete'?p.fam<=3:p.fam>=3);
 const pool=preferred.length?preferred:players;return pool.length?pool[(l.minute+side)%pool.length]:null;
}
function actionName(l,side,role){return actionPlayer(l,side,role)?.name||S.clubs[l.pair[side]].abbr}
function captureMatchAction(l,type,meta={}){
 if(l.userSide<0)return undefined;
 const prior=l.events.at(-1)?.scene,kind=meta.kind||(['turnover','try','goal','penalty','advantage','card','sub','tactic','break','end'].includes(type)?type:'message');
 const team=meta.team??l.possession;
 const neutral=['message','card','sub','tactic','break','end','advantage'].includes(kind);
 const base={x:neutral&&prior?prior.to.x:l.territory,y:prior?.to.y??35};
 const from={...(meta.from||base)},to={...(meta.to||from)};
 return {v:1,kind,team,...(meta.move?{move:meta.move}:{}),style:effectiveAttack(l,team),...(tacticalRules(l)?{plans:{attack:[0,1].map(side=>effectiveAttack(l,side)),defence:[0,1].map(side=>effectiveDefence(l,side))}}:{}),incident:meta.incident===true,possession:meta.possession??l.possession,actor:meta.actor??null,from,to,score:[...l.score],tries:[...l.tries],on:l.sheets.map((sh,side)=>{const active=new Set(activePlayers(l,side).map(p=>p.id));return sh.on.map(id=>active.has(id)?id:null)}),period:l.flow?.period||(l.minute>40?2:1)};
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
