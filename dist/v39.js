'use strict';
// V39: five explicit, fictional management systems; no rugby physics changes.
function v39Active(){return S?.v39Version===1&&S?.v39?.version===1}
function v39Initialize(){
 if(!S||S.v39Version!==1)return false;
 if(!S.v39)S.v39={version:1,audits:[],medical:[],bonds:[],cohesion:65,
  leader:null,lastRecovery:null,lastBond:null,lastTalk:null};
 return true;
}
function v39Enable(){
 if(!S||v39Active()||S.live||S.phase==='ended'||Object.keys(S.economy.talks).length)return false;
 S.v39Version=1;v39Initialize();save();render();return true;
}
function v39Week(){return S.season+':'+S.economy.week}
function v39InjuryBefore(){return v39Active()?new Map(club().players.map(p=>[p.id,p.injury])):null}
function v39MedicalEvent(id,kind,weeks){
 if(!v39Active())return;
 S.v39.medical.unshift({season:S.season,round:S.round,id,kind,weeks});
 S.v39.medical=S.v39.medical.slice(0,40);
}
function v39AfterTraining(before){
 if(!before||!v39Active())return;
 for(const p of club().players){
  const prior=before.get(p.id)||0;
  if(p.injury>prior)v39MedicalEvent(p.id,'training',p.injury);
  else if(prior>0&&p.injury<prior)v39MedicalEvent(p.id,'recovery',p.injury);
 }
}
function v39MatchBefore(l){
 if(!v39Active()||!l?.finished||l.userSide<0||l.pair[l.userSide]!==S.club)return null;
 return {minutes:new Map(l.sheets[l.userSide].used.map(id=>[id,player(id)?.dev?.minutes??0])),
  injuries:v39InjuryBefore()};
}
function v39AfterMatch(l,before){
 if(!before||!v39Active()||S.v39.audits.some(a=>a.season===S.season&&a.round===S.round))return false;
 const sh=l.sheets[l.userSide],entries=[];
 for(const id of sh.used){
  const p=player(id);if(!p)continue;
  const expected=Math.max(0,(sh.minutes[id]||0)-(l.devBaseline?.[l.userSide]?.[id]||0));
  const credited=Math.max(0,p.dev.minutes-(before.minutes.get(id)||0));
  if(!expected&&!credited)continue;
  entries.push({id,minutes:expected,credited,ok:Math.abs(expected-credited)<.001});
  if(p.injury>(before.injuries?.get(id)||0))v39MedicalEvent(id,'match',p.injury);
 }
 const audit={season:S.season,round:S.round,minute:l.minute,players:entries.slice(0,23),ok:entries.every(x=>x.ok)};
 S.v39.audits.unshift(audit);S.v39.audits=S.v39.audits.slice(0,12);
 if(!audit.ok)news('Audit V39 : écart de minutes entre la feuille et le développement. Consultez Effectif.');
 return true;
}
function v39RecoveryPlan(){
 if(!v39Active()||S.live||S.trained||S.phase==='ended'||S.v39.lastRecovery===v39Week())return false;
 const selected=club().players.filter(p=>!p.injury&&physicalLoadValue(p)>=30)
  .sort((a,b)=>physicalLoadValue(b)-physicalLoadValue(a)||a.id.localeCompare(b.id)).slice(0,3);
 if(!selected.length)return false;
 for(const p of selected)ensurePhysicalLoad(p).plan='repos';
 S.v39.lastRecovery=v39Week();save();render();return true;
}
function v39Bond(a,b){
 if(!v39Active()||S.live||S.phase==='ended'||S.v39.lastBond===v39Week()||a===b)return false;
 if(!player(a)||!player(b)||player(a).injury||player(b).injury)return false;
 const [first,last]=[a,b].sort();
 let bond=S.v39.bonds.find(x=>x.a===first&&x.b===last);
 if(!bond){bond={a:first,b:last,score:50};if(S.v39.bonds.length>=20)S.v39.bonds.shift();S.v39.bonds.push(bond)}
 bond.score=clamp(bond.score+8,0,100);
 S.v39.cohesion=clamp(S.v39.cohesion+1,0,100);
 S.v39.lastBond=v39Week();save();render();return true;
}
function v39ChooseLeader(id){
 if(!v39Active()||S.live||S.phase==='ended'||!player(id))return false;
 S.v39.leader=id;save();render();return true;
}
function v39TeamTalk(choice){
 if(!v39Active()||S.live||S.phase==='ended'||S.v39.lastTalk===v39Week()||
  !['rassembler','exiger','apaiser'].includes(choice))return false;
 const [morale,cohesion]={rassembler:[2,3],exiger:[-1,5],apaiser:[3,1]}[choice];
 S.morale=clamp(S.morale+morale,0,100);
 S.v39.cohesion=clamp(S.v39.cohesion+cohesion,0,100);
 S.v39.lastTalk=v39Week();
 news('Vestiaire : '+choice+' · moral '+(morale>=0?'+':'')+morale+' · cohésion +'+cohesion+'.');
 save();render();return true;
}
function v39SeasonReset(){
 if(!v39Active())return;
 S.v39.lastRecovery=null;S.v39.lastBond=null;S.v39.lastTalk=null;
 if(!player(S.v39.leader))S.v39.leader=null;
}
function v39Panel(){
 if(!v39Active())return '<section class="card"><h2>Vie du groupe · V39</h2><p class="help">Ancienne carrière : activation volontaire, sans changer les règles de match.</p><button class="small dark" onclick="v39Enable()">Activer les systèmes V39</button></section>';
 const v=S.v39,week=v39Week();
 const hurt=club().players.filter(p=>p.injury).sort((a,b)=>b.injury-a.injury);
 const tired=club().players.filter(p=>!p.injury&&physicalLoadValue(p)>=30)
  .sort((a,b)=>physicalLoadValue(b)-physicalLoadValue(a)).slice(0,5);
 const audit=v.audits[0];
 const auditText=audit?'S'+audit.season+' J'+(audit.round+1)+' : '+audit.players.length+
  ' joueurs · '+(audit.ok?'minutes concordantes':'écarts de minutes'):'Aucun match contrôlé depuis activation.';
 const auditRows=audit?.players.slice(0,8).map(x=>'<div class="row"><span>'+visualEscape(player(x.id)?.name||x.id)+
  '</span><strong>'+Math.round(x.minutes)+' min terrain / '+Math.round(x.credited)+' min créditées</strong></div>').join('')||'';
 const medical=v.medical.slice(0,8).map(x=>'<div class="news">S'+x.season+' J'+(x.round+1)+' · '+
  visualEscape(player(x.id)?.name||x.id)+' · '+
  ({training:'Blessure à l’entraînement',match:'Blessure après match',recovery:'Récupération'})[x.kind]+
  ' · '+x.weeks+' semaine(s)</div>').join('')||'<p>Aucun événement récent.</p>';
 const options=club().players.filter(p=>!p.injury)
  .map(p=>'<option value="'+visualEscape(p.id)+'">'+visualEscape(p.name)+'</option>').join('');
 const bonds=v.bonds.slice().sort((a,b)=>b.score-a.score).slice(0,5).map(x=>
  '<div class="row"><span>'+visualEscape(player(x.a)?.name||x.a)+' / '+
  visualEscape(player(x.b)?.name||x.b)+'</span><strong>'+x.score+'/100</strong></div>').join('')||'<p>Pas encore de binôme travaillé.</p>';
 return '<section class="card"><h2>V39 · Gestion du groupe</h2><p class="help">Cinq systèmes explicites, sans bonus caché sur le moteur de rugby. La cohésion est un indicateur de gestion fictif, distinct de la physique du match.</p>'+
 '<h3>1 · Temps de jeu vérifié</h3><p>'+auditText+'</p>'+auditRows+
 '<h3>2 · Infirmerie et retour</h3><p>'+hurt.length+' blessé(s) : '+
 (hurt.map(p=>visualEscape(p.name)+' ('+p.injury+' sem.)').join(' · ')||'aucun')+'</p>'+medical+
 '<h3>3 · Récupération ciblée</h3><p class="help">Place en repos jusqu’à trois joueurs à charge ≥30. Le mécanisme de récupération V27 s’applique à la séance suivante. Un choix par semaine.</p>'+
 (tired.map(p=>'<div class="row"><span>'+visualEscape(p.name)+'</span><strong>'+physicalLoadValue(p)+'/100 · '+Math.round(p.condition)+' %</strong></div>').join('')||'<p>Aucune charge élevée.</p>')+
 '<button class="small dark" onclick="v39RecoveryPlan()" '+(S.live||S.trained||v.lastRecovery===week||!tired.length?'disabled':'')+'>Planifier récupération (max. 3)</button>'+
 '<h3>4 · Affinités du groupe</h3>'+bonds+'<p class="help">Séance de binôme : +8 affinité, +1 cohésion, au maximum une fois par semaine.</p>'+
 '<select id="v39-a">'+options+'</select><select id="v39-b">'+options+'</select>'+
 '<button class="small" onclick="v39Bond(document.querySelector(\'#v39-a\').value,document.querySelector(\'#v39-b\').value)" '+(S.live||v.lastBond===week?'disabled':'')+'>Créer un binôme</button>'+
 '<h3>5 · Vestiaire et leader</h3><p>Leader : '+(player(v.leader)?visualEscape(player(v.leader).name):'non choisi')+
 ' · cohésion '+v.cohesion+'/100 · moral '+S.morale+'/100</p>'+
 '<select id="v39-leader">'+options+'</select><button class="small" onclick="v39ChooseLeader(document.querySelector(\'#v39-leader\').value)" '+(S.live?'disabled':'')+'>Choisir leader</button>'+
 '<p class="help">Une discussion par semaine : rassembler (+2 moral, +3 cohésion), exiger (−1 moral, +5 cohésion), apaiser (+3 moral, +1 cohésion).</p>'+
 ['rassembler','exiger','apaiser'].map(c=>'<button class="small" onclick="v39TeamTalk(\''+c+'\')" '+
 (S.live||v.lastTalk===week?'disabled':'')+'>'+({rassembler:'Rassembler',exiger:'Exiger',apaiser:'Apaiser'})[c]+'</button>').join('')+
 '</section>';
}
