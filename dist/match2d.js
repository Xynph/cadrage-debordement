'use strict';
const MATCH_TEMPOS={lent:1800,normal:1100,rapide:650};
let matchTempo='normal';
const MATCH_FRAMES=new WeakMap();
function visualEscape(value){return String(value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function matchScene(l){
 const real=l.visualSource||l,event=displayedAction(real),record=event?.scene;
 const on=record?.on||real.sheets.map((sh,side)=>{const active=new Set(activePlayers(real,side).map(p=>p.id));return sh.on.map(id=>active.has(id)?id:null)});
 const kind=record?.kind||'message',team=record?.team??real.possession,possession=record?.possession??real.possession;
 const ball=record?{...record.to}:{x:real.territory,y:35},origin=record?{...record.from}:ball,players=[];
 for(let side=0;side<2;side++)on[side].forEach((id,slot)=>{
  if(!id)return;const p=matchPlayer(real,side,id);if(!p)return;
  const attack=side===possession,dir=possession===0?1:-1,formation=['goal','miss'].includes(kind)?origin:ball;
  let x=formation.x+(attack?-dir:dir)*(slot<8?5+slot%3*3:13+(slot-8)*2.8),y=slot<8?ball.y+(Math.floor(slot/3)-1)*4+(slot%3-1)*3:7+(slot-8)*9.3;
  if(kind==='carry'&&record?.style==='conquete'&&slot<8){x=ball.x+(attack?-dir:dir)*(3+slot%3*1.5);y=ball.y+(Math.floor(slot/3)-1)*3}
  if(kind==='scrum'&&slot<8){x=ball.x+(side===0?-1:1)*(1.5+slot%3*2.1);y=ball.y+(Math.floor(slot/3)-1)*2.7}
  if(kind==='lineout'&&slot<8){x=ball.x+(side===team?-2:2);y=slot===1?2:9+slot*3.3}
  if(['kickoff','drop22','goalLine'].includes(kind)){x=ball.x+(side===team?(team===0?-1:1)*8:(team===0?1:-1)*20);y=5+slot*4.2}
  if(record?.plans&&!['scrum','lineout','kickoff','drop22','goalLine'].includes(kind)){
   const attackPlan=record.plans.attack[side],defencePlan=record.plans.defence[side];
   if(attack&&slot>=8){y=attackPlan==='conquete'?23+(slot-8)*4.2:attackPlan==='large'?4+(slot-8)*10.3:7+(slot-8)*9.3;x=formation.x-dir*(attackPlan==='conquete'?8+(slot-8)*1.5:12+(slot-8)*2.8)}
   if(attack&&slot<8){x=formation.x-dir*(attackPlan==='conquete'?3+slot%3*1.5:6+slot%3*3);y=ball.y+(Math.floor(slot/3)-1)*(attackPlan==='conquete'?3:5)+(slot%3-1)*2}
   if(!attack){x=formation.x+dir*(defencePlan==='pression'?4:defencePlan==='prudente'?14:9)+(slot%3);y=slot<8?10+slot*6.5:5+(slot-8)*10;if(slot===14)x+=dir*(defencePlan==='prudente'?15:10)}
  }
  if(record?.move==='maul'&&side===team&&slot<8){x=ball.x+(side===0?-1:1)*(2+slot%3*1.3);y=ball.y+(Math.floor(slot/3)-1)*2.5}
  const featured=id===record?.actor;
  if(featured&&['carry','turnover','reception','try','setpiece-win','setpiece-loss','kick','goal','miss'].includes(kind)){x=['kick','goal','miss'].includes(kind)?origin.x:ball.x;y=['kick','goal','miss'].includes(kind)?origin.y:ball.y}
  players.push({id,side,slot,x:featured&&kind==='try'?x:clamp(x,1.5,98.5),y:clamp(y,2,68),name:p.name,condition:p.condition,featured});
 });
 return {ball,origin,players,stage:record?ACTION_LABELS[kind]:'État actuel',kind,team,possession,event,key:event||real.minute,period:record?.period||(real.flow?.period||1),restart:['scrum','lineout','kickoff','drop22','goalLine'].includes(kind)?{kind}:null};
}
function setMatchTempo(tempo){if(!MATCH_TEMPOS[tempo])return;matchTempo=tempo;if(S?.live&&(presentationPending(S.live)||!S.live.finished&&!S.live.paused))startTimer();render()}
function match2D(l){
 const source=l.visualSource||l,scene=matchScene(l),previous=MATCH_FRAMES.get(source),reduce=!!window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
 const animate=!!previous&&previous.key!==scene.key&&!l.paused&&!l.finished&&!reduce,duration=Math.min(.9,MATCH_TEMPOS[matchTempo]/1000*.75);
 const switched=scene.period===2;
 const point=p=>({x:100+(switched?100-p.x:p.x)*10,y:50+(switched?70-p.y:p.y)*10}),ball=point(scene.ball),previousBall=point(scene.origin);
 const oldPlayers=new Map(previous?.players.map(p=>[p.id,point(p)])||[]);
 const playerMarkup=scene.players.map(p=>{
  const at=point(p),from=oldPlayers.get(p.id)||at,c=S.clubs[l.pair[p.side]],fill=p.side===0?c.color:'#fffaf0',ink=p.side===0?'white':'#172c24';
  return `<g class="match-token" transform="translate(${at.x} ${at.y})" data-player-id="${p.id}" data-team="${p.side}" role="button" tabindex="0" aria-label="${visualEscape(p.name)} · ${p.slot+1} · ${Math.round(p.condition)}%" onclick="openMatchPlayer(${p.side},'${p.id}')" onkeydown="if(event.key==='Enter'||event.key===' '){event.preventDefault();openMatchPlayer(${p.side},'${p.id}')}"><title>${visualEscape(p.name)} · ${p.slot+1} · ${visualEscape(POS[p.slot])} · ${Math.round(p.condition)}%</title>${animate?`<animateTransform attributeName="transform" type="translate" from="${from.x} ${from.y}" to="${at.x} ${at.y}" dur="${duration}s" fill="freeze"/>`:''}${p.featured?'<circle class="featured-player-halo" r="26" fill="none" stroke="#ffdd82" stroke-width="4"/>':''}<circle r="17" fill="${fill}" stroke="${p.side===0?'#fff8':c.color}" stroke-width="3"/><text text-anchor="middle" dy="5" fill="${ink}" font-size="15" font-weight="800">${p.slot+1}</text></g>`;
 }).join('');
 const moving=scene.origin.x!==scene.ball.x||scene.origin.y!==scene.ball.y;
 const trajectory=moving?`<path d="M ${previousBall.x} ${previousBall.y} Q ${(previousBall.x+ball.x)/2} ${['kick','goal','miss','reception'].includes(scene.kind)?Math.min(previousBall.y,ball.y)-65:(previousBall.y+ball.y)/2} ${ball.x} ${ball.y}" fill="none" stroke="#ffe4a0" stroke-width="3" stroke-dasharray="6 7" opacity=".7"/>`:'';
 const ballMarkup=`<g class="match-ball" ${animate?'':`transform="translate(${ball.x} ${ball.y})"`}>${animate?`<animateMotion dur="${duration}s" fill="freeze" path="M ${previousBall.x} ${previousBall.y} Q ${(previousBall.x+ball.x)/2} ${['kick','goal','miss','reception'].includes(scene.kind)?Math.min(previousBall.y,ball.y)-65:(previousBall.y+ball.y)/2} ${ball.x} ${ball.y}"/>`:''}<circle class="ball-glow" r="25" fill="#ffe59a" opacity=".22"/><ellipse rx="12" ry="8" transform="rotate(-25)" fill="#fff5dc" stroke="#382c20" stroke-width="3"/><path d="M -4 -4 L 4 4 M -1 -4 L 5 2" stroke="#9d6739" stroke-width="1.5"/></g>`;
 const stripes=Array.from({length:10},(_,i)=>`<rect x="${100+i*100}" y="50" width="100" height="700" fill="${i%2?'#2f754e':'#378155'}"/>`).join('');
 const markings=[{x:100,label:''},{x:320,label:'22'},{x:500,label:'10'},{x:600,label:'50'},{x:700,label:'10'},{x:880,label:'22'},{x:1100,label:''}].map(({x,label})=>`<path d="M ${x} 50 V 750" stroke="#e4f3de" stroke-width="${x===600?3:2}" ${x===500||x===700?'stroke-dasharray="14 12"':''}/>${label?`<text x="${x+8}" y="85" fill="#d2e9cd" font-size="18" opacity=".85">${label}</text>`:''}`).join('');
 const viewBox='0 0 1200 800';
 const advantage=scene.kind==='advantage';
 const plans=scene.event?.scene?.plans;
 const planLegend=plans?`<div class="field-plans">${l.pair.map((ci,side)=>`<span><b>${S.clubs[ci].abbr}</b> · ${TACTICS[plans.attack[side]][0]}<small>Défense ${DEFENCES[plans.defence[side]][0].toLowerCase()}</small></span>`).join('')}</div>`:'';
 const caption=scene.event?.scene?scene.event.text:'Les anciennes actions n’ont pas de position enregistrée. Les prochaines seront synchronisées.';
 MATCH_FRAMES.set(source,{...scene,minute:l.minute});
 return `<section class="card match-2d" aria-label="Vue 2D du match"><div class="match-2d-header"><div><span class="eyebrow">AU CŒUR DU JEU</span><h2>Le terrain</h2></div><span class="match-stage ${advantage?'advantage-stage':''}">${visualEscape(scene.stage)} · ${matchClock(l)}</span></div><div class="match-2d-controls"><span class="full-pitch-label">Terrain entier · ${scene.event?.scene?'action synchronisée':'état actuel'}</span><label>Rythme <select aria-label="Rythme du match" onchange="setMatchTempo(this.value)">${Object.entries({lent:'Posé',normal:'Normal',rapide:'Rapide'}).map(([id,title])=>`<option value="${id}" ${matchTempo===id?'selected':''}>${title}</option>`).join('')}</select></label></div>${autoPauseControls()}<div class="stadium-stage"><svg class="match-field" viewBox="${viewBox}" role="group" aria-label="${visualEscape(S.clubs[l.pair[0]].name)} contre ${visualEscape(S.clubs[l.pair[1]].name)}. ${scene.players.filter(p=>p.side===0).length} contre ${scene.players.filter(p=>p.side===1).length} joueurs. ${visualEscape(scene.stage)}." xmlns="http://www.w3.org/2000/svg"><defs><radialGradient id="stadium-glow"><stop stop-color="#244537"/><stop offset="1" stop-color="#10251c"/></radialGradient></defs><rect width="1200" height="800" fill="url(#stadium-glow)"/><rect x="40" y="50" width="1120" height="700" rx="5" fill="#286345"/>${stripes}<rect x="40" y="50" width="60" height="700" fill="${S.clubs[l.pair[switched?1:0]].color}" opacity=".6"/><rect x="1100" y="50" width="60" height="700" fill="${S.clubs[l.pair[switched?0:1]].color}" opacity=".6"/><rect x="40" y="50" width="1120" height="700" fill="none" stroke="#e4f3de" stroke-width="3"/>${markings}<path d="M 150 50 V 750 M 1050 50 V 750 M 100 100 H 1100 M 100 700 H 1100" stroke="#d2e9cd" stroke-width="1.5" stroke-dasharray="12 18" opacity=".7"/><path d="M 90 375 H 110 M 90 425 H 110 M 100 375 V 425 M 1090 375 H 1110 M 1090 425 H 1110 M 1100 375 V 425" stroke="white" stroke-width="5"/><text x="76" y="400" transform="rotate(-90 76 400)" text-anchor="middle" fill="white" opacity=".8" font-size="23" font-weight="700">${S.clubs[l.pair[switched?1:0]].abbr}</text><text x="1124" y="400" transform="rotate(90 1124 400)" text-anchor="middle" fill="white" opacity=".8" font-size="23" font-weight="700">${S.clubs[l.pair[switched?0:1]].abbr}</text>${trajectory}${playerMarkup}${ballMarkup}</svg></div><div class="field-caption" role="status"><span class="field-phase-dot"></span>${visualEscape(caption)}</div><div class="field-legend"><span><i style="background:${S.clubs[l.pair[0]].color}"></i>${S.clubs[l.pair[0]].abbr} ${switched?'←':'→'} · ${scene.players.filter(p=>p.side===0).length} joueurs</span><span><i style="background:#fffaf0;border:2px solid ${S.clubs[l.pair[1]].color}"></i>${switched?'→':'←'} ${S.clubs[l.pair[1]].abbr} · ${scene.players.filter(p=>p.side===1).length} joueurs</span></div>${planLegend}<p class="field-note">Ballon et action reliés au commentaire surligné. Placements schématiques. Cliquez sur un joueur pour le consulter ou le remplacer.</p></section>`;
}

// Match-reading controls are presentation state only, never part of the career save.
let commentaryFilter='all';
const COMMENTARY_TYPES={try:'Essai',goal:'Points',card:'Discipline',sub:'Changement',penalty:'Pénalité',advantage:'Avantage',break:'Mi-temps',end:'Fin du match',tactic:'Consigne'};
function setCommentaryFilter(filter){if(!['all','highlights'].includes(filter))return;commentaryFilter=filter;render()}
function matchCommentary(l){
 const real=l.visualSource||l,current=displayedAction(real),p=playback(real);
 const events=real.events.slice(0,p.cursor+1).reverse().filter(e=>e===current||commentaryFilter==='all'||COMMENTARY_TYPES[e.type]);
 return `<section class="card match-commentary" aria-label="Commentaires du match"><div class="commentary-heading"><div><span class="eyebrow">LE FIL DE LA RENCONTRE</span><h2>Les commentaires</h2></div><span class="commentary-status">${l.finished?'Terminé':l.paused?'En pause':'En direct'}</span></div><div class="commentary-filters" aria-label="Filtrer les commentaires"><button class="small ${commentaryFilter==='all'?'active':''}" aria-pressed="${commentaryFilter==='all'}" onclick="setCommentaryFilter('all')">Tout le match</button><button class="small ${commentaryFilter==='highlights'?'active':''}" aria-pressed="${commentaryFilter==='highlights'}" onclick="setCommentaryFilter('highlights')">Temps forts</button></div><p class="commentary-hint">L’action surlignée est celle du terrain. Elle reste visible dans Temps forts.</p><div class="timeline commentary-feed" tabindex="0" aria-label="Historique des actions">${events.length?events.map(e=>`<div class="event event-${COMMENTARY_TYPES[e.type]?e.type:'play'} ${e===current?'latest-event':''}"><b>${eventClock(real,e)}</b><div>${e===current?`<span class="latest-label">${e.scene?'Action du terrain':'Action ancienne'}</span>`:''}${COMMENTARY_TYPES[e.type]?`<span class="event-kind">${COMMENTARY_TYPES[e.type]}</span>`:''}<p>${visualEscape(e.text)}</p></div></div>`).join(''):'<p class="commentary-empty">Les équipes se mettent en place.</p>'}</div></section>`;
}
