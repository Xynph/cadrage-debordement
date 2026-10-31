'use strict';
// Original implementation, informed by management-game interaction patterns.
let officeFilter='all',squadTab='table',squadFamily='all',squadSort='note',squadDescending=true,compareIds=[],recruitView='missions';
function setupManager(){if(!S||S.manager)return;S.manager={version:1,lastWeek:S.economy.week,serial:0,inbox:[],watch:[],missions:[],reports:[],delegation:{training:false,lineup:false},playbook:defaultPlaybook()};managerMessage('Votre bureau est ouvert.','Retrouvez ici les échéances, les rapports de votre staff et les décisions du club.','club','team')}
function managerMessage(title,body='',kind='club',action='dashboard'){if(!S?.manager)return;const m=S.manager,id='msg-'+(++m.serial);m.inbox.unshift({id,title,body,kind,action,week:S.economy.week,season:S.season,read:false});m.inbox=m.inbox.slice(0,60)}
function managerPool(){return [...new Map([...S.market,...S.economy.freeAgents].filter(p=>!S.clubs.some(c=>c.players.some(x=>x.id===p.id))).map(p=>[p.id,p])).values()]}
function watchPlayer(id){if(S.live)return;const m=S.manager,p=managerPool().find(p=>p.id===id);if(m.watch.includes(id))m.watch=m.watch.filter(x=>x!==id);else{if(!p||m.watch.length>=30)return;m.watch.push(id);if(!S.economy.freeAgents.some(x=>x.id===id)&&S.economy.freeAgents.length<60){p.contractEnd=null;S.economy.freeAgents.push(p)}}save();render()}
function createScoutMission(family,maxAge,budget,maxWage){
 if(S.live)return false;const m=S.manager;family=Number(family);maxAge=Number(maxAge);budget=Number(budget);maxWage=Number(maxWage);
 if(!Number.isInteger(family)||family<0||family>8||!Number.isInteger(maxAge)||maxAge<18||maxAge>40||!Number.isInteger(budget)||budget<0||budget>10000000||!Number.isInteger(maxWage)||maxWage<1000||maxWage>100000||m.missions.filter(x=>x.status!=='done').length>=4||club().cash<5000)return false;
 ledgerEntry('Mission de recrutement',-5000);const active=m.missions.some(x=>x.status==='active');m.missions.push({id:'mission-'+(++m.serial),family,maxAge,budget,maxWage,remaining:2,status:active?'queued':'active',week:S.economy.week});m.missions=m.missions.slice(-24);managerMessage('Mission confiée au recruteur',`${POS[FAMILIES.indexOf(family)]} · ${maxAge} ans maximum. Rapport après deux journées de travail. Frais : 5 000 €.`, 'recruitment','recruitment');save();render();return true;
}
function submitScoutMission(){if(!createScoutMission($('#scout-family').value,$('#scout-age').value,$('#scout-budget').value,$('#scout-wage').value))toast('Vérifiez les critères, la trésorerie et le nombre de missions en attente.')}
function managerWeek(){
 if(!S.manager)return;const m=S.manager,week=S.economy.week;if(week<=m.lastWeek)return;m.lastWeek=week;
 const job=m.missions.find(x=>x.status==='active');if(job){job.remaining--;if(job.remaining===0){job.status='done';const choices=managerPool().filter(p=>p.fam===job.family&&p.age<=job.maxAge&&p.price<=job.budget&&p.salary<=job.maxWage).sort((a,b)=>roleNote(b)-roleNote(a)||b.dev.potential-a.dev.potential).slice(0,3);
 for(const p of choices){if(!S.economy.freeAgents.some(x=>x.id===p.id)&&S.economy.freeAgents.length<60){p.contractEnd=null;S.economy.freeAgents.push(p)}const own=club().players.filter(x=>x.fam===p.fam).sort((a,b)=>roleNote(b)-roleNote(a))[0],gain=roleNote(p)-(own?roleNote(own):0);m.reports.unshift({id:'report-'+(++m.serial),mission:job.id,playerId:p.id,name:p.name,pos:p.pos,family:p.fam,age:p.age,note:roleNote(p),potential:potentialAtRole(p),salary:p.salary,price:p.price,grade:gain>=4?'A':gain>=-3?'B':'C',week,season:S.season});}
 m.reports=m.reports.slice(0,40);managerMessage('Rapport de recrutement disponible',choices.length?`${choices.length} profil(s) correspondent aux critères. Consultez les qualités, les coûts et la comparaison avec votre effectif.`:'Aucun agent libre disponible ne correspond à tous les critères. Élargissez la mission si nécessaire.','recruitment','recruitment');}}
 if(!m.missions.some(x=>x.status==='active')){const queued=m.missions.find(x=>x.status==='queued');if(queued)queued.status='active'}
 managerMessage('Le point de la semaine',`${club().players.filter(p=>p.injury).length} blessé(s), ${club().players.filter(p=>p.contractEnd===S.season).length} contrat(s) arrivant à échéance. Prochain rendez-vous : ${label()}.`,'staff','team');
}
function setDelegation(key,value){if(S.live||!['training','lineup'].includes(key))return;S.manager.delegation[key]=!!value;save();render()}
function applyStaffPreparation(){if(!S.manager||S.live)return;if(S.manager.delegation.training){const meanFitness=mean(starters().map(p=>p.condition));S.training=meanFitness<75?'repos':'normal';managerMessage('Entraînement confié au préparateur',`${TRAIN[S.training][0]} retenu avec une condition moyenne de ${Math.round(meanFitness)}%.`,'staff','tactics')}}
function applyStaffSelection(){if(S.manager?.delegation.lineup&&!S.live){autoLineup();managerMessage('Feuille préparée par l’adjoint','Les 23 joueurs ont été sélectionnés après l’entraînement, selon les postes et leur condition.','staff','team')}}
function markMessage(id){const msg=S.manager.inbox.find(x=>x.id===id);if(msg){msg.read=true;save();render()}}
function officeAction(viewName,id,tab){if(viewName==='market'&&['recruit','contracts','sales','history'].includes(tab))marketTab=tab;if(id){const msg=S.manager.inbox.find(x=>x.id===id);if(msg)msg.read=true}save();nav(viewName)}
function officeDecisions(){const out=[];const errors=sheetErrors();if(errors.length)out.push({title:'Compléter la feuille à 23',detail:errors[0],action:'team',tone:'urgent'});const exp=club().players.filter(p=>p.contractEnd===S.season);if(exp.length)out.push({title:`${exp.length} contrats à anticiper`,detail:'Les joueurs non prolongés partiront en fin de saison.',action:'market',tab:'contracts',tone:'attention'});if(S.economy.offers.length)out.push({title:`${S.economy.offers.length} offres de transfert`,detail:'Une réponse est attendue avant leur expiration.',action:'market',tab:'sales',tone:'attention'});const hurt=club().players.filter(p=>p.injury);if(hurt.length)out.push({title:`${hurt.length} joueurs indisponibles`,detail:'Vérifiez la couverture de leurs postes.',action:'team',tone:'attention'});if(club().cash<0)out.push({title:'Trésorerie négative',detail:'Les recrutements restent bloqués par les moyens disponibles.',action:'finance',tone:'urgent'});return out}
function officeCalendar(){return S.schedule.slice(S.round,Math.min(26,S.round+4)).map((pairs,i)=>{const p=pairs.find(p=>p.includes(S.club)),other=p.find(ci=>ci!==S.club);return `<div class="office-fixture"><span class="calendar-day">J${S.round+i+1}</span>${badge(other)}<div><strong>${S.clubs[other].name}</strong><small>${p[0]===S.club?'À domicile':'À l’extérieur'} · ${S.clubs[p[0]].stadium}</small></div></div>`}).join('')||'<p>Les phases finales suivent le tableau de compétition.</p>'}
function managerOffice(){const m=S.manager,decisions=officeDecisions(),messages=m.inbox.filter(x=>officeFilter==='all'||officeFilter==='unread'&&!x.read||x.kind===officeFilter);return heading('LE BUREAU DU MANAGER','Votre club, vos décisions.',`Saison ${S.season} · ${label()} · ${m.inbox.filter(x=>!x.read).length} messages non lus`,`<button class="primary" onclick="${S.phase==='ended'?'nextSeason()':"nav('match')"}">${S.phase==='ended'?'Préparer la saison suivante':'Préparer le prochain match'} →</button>`)+`<div class="office-summary"><div><small>TRÉSORERIE</small><strong>${money(club().cash)}</strong></div><div><small>CONDITION DU XV</small><strong>${Math.round(mean(starters().map(p=>p.condition)))}%</strong></div><div><small>CONFIANCE</small><strong>${S.trust}%</strong></div><div><small>CLASSEMENT</small><strong>${ranked().findIndex(c=>c.id===S.club)+1}e</strong></div></div><div class="office-grid"><div class="stack"><section class="card"><div class="cardtitle"><h2>Sur votre bureau</h2><span class="tag">${decisions.length} PRIORITÉS</span></div>${decisions.map(d=>`<button class="office-decision ${d.tone}" onclick="officeAction('${d.action}',null,'${d.tab||''}')"><strong>${d.title}</strong><span>${d.detail}</span><b>→</b></button>`).join('')||'<p>Les principales échéances sont sous contrôle. Préparez le prochain rendez-vous.</p>'}</section><section class="card office-inbox"><div class="cardtitle"><h2>Messages & rapports</h2><span class="tag">${m.inbox.length}</span></div><div class="tabs">${[['all','Tous'],['unread','Non lus'],['staff','Staff'],['recruitment','Recrutement']].map(([key,title])=>`<button class="small ${officeFilter===key?'dark':''}" onclick="officeFilter='${key}';render()">${title}</button>`).join('')}</div>${messages.slice(0,20).map(msg=>`<article class="office-message ${msg.read?'':'unread'}"><small>SAISON ${msg.season} · ÉCHÉANCE ${msg.week} · ${msg.kind==='recruitment'?'RECRUTEMENT':msg.kind==='staff'?'STAFF':'CLUB'}</small><h3>${visualEscape(msg.title)}</h3>${msg.body?`<p>${visualEscape(msg.body)}</p>`:''}<div><button class="small" onclick="officeAction('${msg.action}','${msg.id}')">Ouvrir →</button>${!msg.read?`<button class="small" onclick="markMessage('${msg.id}')">Marquer comme lu</button>`:''}</div></article>`).join('')||'<p>Aucun message dans cette vue.</p>'}</section></div><aside class="stack"><section class="card"><h2>Le calendrier</h2>${officeCalendar()}<button class="small" onclick="nav('league')">Toute la compétition →</button></section><section class="card"><h2>Votre projet sportif</h2><p><b>${TACTICS[S.tactic][0]}</b> · Défense ${DEFENCES[S.defence||'equilibre'][0].toLowerCase()}</p><p>${S.manager.delegation.training?'Préparation déléguée':'Préparation sous votre contrôle'}<br>${S.manager.delegation.lineup?'Sélection déléguée':'Vous choisissez les 23'}</p><div class="office-links"><button onclick="nav('plans')">Plan de jeu →</button><button onclick="nav('staff')">Staff & responsabilités →</button><button onclick="nav('recruitment')">Missions & rapports →</button></div></section><section class="card"><h2>Dernier résultat</h2>${S.lastReport?`<p>${S.clubs[S.lastReport.pair[0]].abbr} <strong>${S.lastReport.score.join(' – ')}</strong> ${S.clubs[S.lastReport.pair[1]].abbr}</p><p>${S.lastReport.analysis[0]}</p>`:'<p>La saison commence. Le premier compte rendu suivra votre rencontre.</p>'}</section></aside></div>`}
function staffView(){const m=S.manager;return heading('L’ÉQUIPE AUTOUR DE VOUS','Le staff.','Confiez des responsabilités précises ; vous gardez la décision sur les contrats.')+`<div class="manager-staff-grid"><section class="card"><span class="eyebrow">ADJOINT</span><h2>La sélection</h2><p>Compose les 23 après l’entraînement, avec des joueurs aptes et éligibles à leur poste.</p><label class="delegation-toggle"><input type="checkbox" ${m.delegation.lineup?'checked':''} onchange="setDelegation('lineup',this.checked)"> Déléguer la feuille de match</label><button class="small" onclick="autoLineup();save();render()">Demander une sélection maintenant</button></section><section class="card"><span class="eyebrow">PRÉPARATEUR</span><h2>La charge de travail</h2><p>Choisit récupération sous 75% de condition moyenne du XV ; sinon, travail collectif. La séance utilise les effets habituels d’entraînement.</p><label class="delegation-toggle"><input type="checkbox" ${m.delegation.training?'checked':''} onchange="setDelegation('training',this.checked)"> Déléguer l’entraînement</label></section><section class="card"><span class="eyebrow">RECRUTEUR</span><h2>Les profils à suivre</h2><p>Une mission à la fois, deux journées de travail. Trois missions peuvent attendre. Frais de mission : 5 000 €.</p><button class="dark" onclick="nav('recruitment')">Ouvrir les missions →</button></section></div><div class="notice">Le staff conseille et prépare. Les signatures et les ventes gardent leur confirmation habituelle. Les délégations sont appliquées au prochain coup d’envoi et restent modifiables entre les matchs.</div>`}
function scoutMissionForm(){return `<section class="card"><h2>Confier une mission</h2><p>Recherche parmi les agents libres de la simulation. La prime et le salaire doivent respecter vos critères.</p><div class="mission-fields"><label>Poste<select id="scout-family">${[0,1,2,3,4,5,6,7,8].map(f=>`<option value="${f}">${POS[FAMILIES.indexOf(f)]}${f===0?' (gauche ou droit)':''}</option>`).join('')}</select></label><label>Âge maximum<input id="scout-age" type="number" min="18" max="40" value="28"></label><label>Prime maximale (€)<input id="scout-budget" type="number" min="0" max="10000000" value="700000"></label><label>Salaire maximal / semaine (€)<input id="scout-wage" type="number" min="1000" max="100000" value="12000"></label></div><button class="primary" onclick="submitScoutMission()" ${club().cash<5000?'disabled':''}>Confier la mission · 5 000 €</button></section>`}
function scoutingReportHTML(r){const p=managerPool().find(p=>p.id===r.playerId);return `<article class="card scout-report"><div class="cardtitle"><span class="tag">RAPPORT ${r.grade}</span><small>S${r.season} · échéance ${r.week}</small></div><h2>${visualEscape(r.name)}</h2><p>${r.pos} · ${r.age} ans lors du rapport · niveau ${r.note}, potentiel au poste ${r.potential}</p><p>Prime ${money(r.price)} · salaire ${money(r.salary)} / semaine</p><p class="help">${r.grade==='A'?'Renfort potentiel du premier choix.':r.grade==='B'?'Profil proche du premier choix, utile pour la concurrence.':'Profil de complément à comparer à vos solutions actuelles.'} Appréciation à la date du rapport ; les informations connues restent visibles dans cette version.</p>${p?`<div class="matchactions"><button class="small" onclick="inspectPlayer('${p.id}')">Fiche & attributs</button><button class="small" onclick="watchPlayer('${p.id}')">${S.manager.watch.includes(p.id)?'Ne plus suivre':'Suivre'}</button><button class="dark small" onclick="openContract('${p.id}')">Négocier →</button></div>`:`<p class="muted">Ce joueur n’est plus disponible parmi les agents libres.</p>${S.manager.watch.includes(r.playerId)?`<button class="small" onclick="watchPlayer('${r.playerId}')">Ne plus suivre</button>`:''}`}</article>`}
function recruitmentView(){const m=S.manager;return heading('LA CELLULE RECRUTEMENT','Missions, rapports, décisions.','Définissez le besoin, laissez travailler le recruteur, puis comparez et négociez.',`<button onclick="nav('market')">Marché & contrats →</button>`)+`<div class="tabs">${[['missions','Missions'],['reports','Rapports'],['watch','Joueurs suivis']].map(([key,title])=>`<button class="${recruitView===key?'dark':''}" onclick="recruitView='${key}';render()">${title}${key==='reports'?' · '+m.reports.length:''}</button>`).join('')}</div>${recruitView==='missions'?`<div class="grid">${scoutMissionForm()}<section class="card"><h2>Le travail du recruteur</h2>${m.missions.slice().reverse().map(j=>`<div class="news"><strong>${POS[FAMILIES.indexOf(j.family)]} · ${j.maxAge} ans max.</strong><p>${j.status==='active'?'En cours · '+j.remaining+' journée(s) restante(s)':j.status==='queued'?'En attente':'Terminée'} · Prime ≤ ${money(j.budget)} · Salaire ≤ ${money(j.maxWage)}</p></div>`).join('')||'<p>Aucune mission en cours.</p>'}</section></div>`:`<div class="manager-staff-grid">${(recruitView==='reports'?m.reports:m.reports.filter(r=>m.watch.includes(r.playerId))).map(scoutingReportHTML).join('')}${recruitView==='watch'?m.watch.filter(id=>!m.reports.some(r=>r.playerId===id)).map(id=>{const p=managerPool().find(p=>p.id===id);return p?`<section class="card"><h2>${p.name}</h2><p>${p.pos} · estimation ${recruitmentEvidence(p).noteMin}–${recruitmentEvidence(p).noteMax} · ${money(p.salary)} / semaine</p><button onclick="inspectPlayer('${id}')">Consulter</button><button onclick="openContract('${id}')">Négocier</button><button onclick="watchPlayer('${id}')">Ne plus suivre</button></section>`:''}).join(''):''}</div>${!m.reports.length?'<div class="card"><p>Les rapports apparaîtront après le travail du recruteur.</p></div>':''}`}`}


// V30 — lecture sans mutation des besoins et du marché fictif de rugby à XV.
// Tous les postes sont évalués avec slotEligible : piliers gauche/droit et
// talonneurs ne sont jamais rendus interchangeables par la recommandation.
function recruitmentDepth(c,slot){
 const eligible=c.players.filter(p=>slotEligible(p,slot));
 const fit=eligible.filter(p=>!p.injury);
 const durable=eligible.filter(p=>p.contractEnd>S.season&&p.dev?.retireAge>p.age+1);
 const youth=c.id===S.club?S.development.academy.filter(p=>slotEligible(p,slot)&&p.dev.potential>=p.rating+5):[];
 return {eligible,fit,durable,youth};
}
function recruitmentNeed(c,slot){
 const depth=recruitmentDepth(c,slot),top=depth.fit.slice().sort((a,b)=>fitScore(b,FAMILIES[slot])-fitScore(a,FAMILIES[slot]))[0];
 const weights=ROLE_WEIGHTS[FAMILIES[slot]]||ROLE_WEIGHTS[7];
 const quality=Object.keys(weights).sort((a,b)=>{const aa=top?skill(top,a):c.base-15,bb=top?skill(top,b):c.base-15;return (aa-weights[a]*1.5)-(bb-weights[b]*1.5)||a.localeCompare(b)})[0];
 const danger=depth.fit.length===0?55:depth.fit.length===1?28:0;
 const succession=depth.durable.length===0?25:depth.durable.length===1?12:0;
 const expiring=depth.eligible.filter(p=>p.contractEnd===S.season).length;
 const hurt=depth.eligible.filter(p=>p.injury).length;
 const aging=top&&top.age>=32?8:0;
 const weak=top&&roleNote(top,FAMILIES[slot])<c.base-8?9:0;
 const relief=Math.min(10,depth.youth.length*5);
 const score=clamp(danger+succession+Math.min(12,expiring*5)+Math.min(8,hurt*4)+aging+weak-relief,0,100);
 const reasons=[];
 if(depth.fit.length<2)reasons.push(depth.fit.length===0?'aucun joueur apte':'une seule solution apte');
 if(depth.durable.length<2)reasons.push('relève contractuelle insuffisante');
 if(expiring)reasons.push(expiring+' fin(s) de contrat cette saison');
 if(hurt)reasons.push(hurt+' blessé(s)');
 if(aging)reasons.push('titulaire expérimenté');
 if(weak)reasons.push('niveau à renforcer');
 if(depth.youth.length)reasons.push(depth.youth.length+' espoir(s) à développer');
 reasons.push('qualité à renforcer : '+ATTR[quality]);
 return {slot,family:FAMILIES[slot],pos:POS[slot],score,healthy:depth.fit.length,durable:depth.durable.length,youth:depth.youth.length,quality,reasons,need:score>=20};
}
function recruitmentNeeds(c=club()){
 return POS.map((_,slot)=>recruitmentNeed(c,slot)).sort((a,b)=>b.score-a.score||a.slot-b.slot);
}
function recruitmentEvidence(p,scouted=true){
 const report=scouted?S.manager?.reports?.find(r=>r.playerId===p.id):null;
 if(report){
  const age=Math.max(0,S.economy.week-report.week),spread=age<=4?2:age<=13?5:9;
  return {seen:true,stale:age>13,report,noteMin:clamp(report.note-spread,0,100),noteMax:clamp(report.note+spread,0,100),potentialMin:clamp(report.potential-spread-3,0,100),potentialMax:clamp(report.potential+spread+3,0,100),quality:Math.round(report.note),label:'Rapport S'+report.season+' · semaine '+report.week};
 }
 // Une fourchette publique grossière fondée uniquement sur le salaire affiché :
 // pas d'accès masqué aux vraies valeurs rating, dev.potential ou skills.
 const salary=p.salary||0;
 const center=salary>=14000?80:salary>=10000?73:salary>=7000?65:58;
 return {seen:false,stale:false,noteMin:clamp(center-10,0,100),noteMax:clamp(center+10,0,100),potentialMin:null,potentialMax:null,quality:center,label:'Fourchette indicative, non observé'};
}
function recruitmentFinance(c,p){
 const weeks=Math.max(6,29-S.round),wages=c.players.reduce((sum,q)=>sum+q.salary,0)+p.salary;
 const fee=Math.max(0,p.price||0);
 const commitment=fee+p.salary*weeks;
 // Trésorerie fictive : projection indicative limitée aux partenaires
 // existants (160 k€ par journée) et aux salaires, hors billetterie et primes.
 const estimate=c.cash-fee+weeks*(160000-wages);
 return {fee,weeks,commitment,weeklyWages:wages,estimate,sustainable:c.cash-fee>=300000&&estimate>=0,available:c.cash>=fee};
}
function recruitmentTargets(c=club(),pool=null,scouted=c.id===S.club){
 const needs=recruitmentNeeds(c).filter(n=>n.need);
 const all=pool||managerPool(),out=[];
 for(const p of all){
  if(c.players.some(q=>q.id===p.id)||c.players.length>=42||p.age>=p.dev.retireAge)continue;
  const matches=needs.filter(n=>slotEligible(p,n.slot));
  if(!matches.length)continue;
  const best=matches[0],evidence=recruitmentEvidence(p,scouted),finance=recruitmentFinance(c,p);
  const within=finance.sustainable&&p.salary<=100000;
  const current=c.players.filter(q=>slotEligible(q,best.slot)).sort((a,b)=>roleNote(b)-roleNote(a))[0];
  const observedQuality=evidence.seen?clamp(Math.round(((skill(p,best.quality)-(current?skill(current,best.quality):c.base))/3)), -8,8):0;
  const score=best.score*2+Math.round(evidence.quality/2)+observedQuality-(p.age>=32?10:0)-(finance.fee>c.cash*.3?12:0);
  const reasons=[best.pos+': '+best.reasons.slice(0,2).join(', '),'Qualité à vérifier : '+ATTR[best.quality],evidence.label];
  if(p.age<=22)reasons.push('profil de relève');
  if(!finance.sustainable)reasons.push('projection financière défavorable');
  out.push({p,need:best,evidence,finance,within,score,reasons});
 }
 return out.sort((a,b)=>Number(b.within)-Number(a.within)||b.score-a.score||a.p.id.localeCompare(b.p.id)).slice(0,12);
}
function recruitmentNeedsPanel(c=club()){
 const needs=recruitmentNeeds(c).slice(0,5),top=recruitmentTargets(c).slice(0,5);
 return '<section class="card recruitment-intel"><div class="cardtitle"><h2>Diagnostic de l’effectif</h2><span class="tag">POSTES & RELÈVE</span></div><p class="help">Analyse dynamique des joueurs aptes, contrats, âge, relève et première ligne. Les seuils sont des critères fictifs de gestion, pas des règles sportives.</p>'+
 '<div class="recruitment-needs-list">'+needs.map(n=>'<div class="row"><span><strong>'+(n.slot+1)+' · '+n.pos+'</strong><small>'+n.reasons.join(' · ')+'</small></span><strong>'+n.score+'/100</strong></div>').join('')+'</div>'+
 '<h3>Profils recommandés</h3>'+(top.length?top.map(x=>'<div class="recruitment-target"><strong>'+visualEscape(x.p.name)+' · '+x.need.pos+'</strong><p>'+x.reasons.join(' · ')+'</p><small>Estimation de niveau '+x.evidence.noteMin+'–'+x.evidence.noteMax+' · Prime '+money(x.finance.fee)+' · Salaire '+money(x.p.salary)+'/semaine. Projection à '+x.finance.weeks+' semaines : '+money(x.finance.estimate)+' (hypothèses simplifiées).</small><div class="matchactions">'+(x.evidence.seen?'<button class="small" onclick="inspectPlayer(\''+x.p.id+'\')">Fiche observée</button>':'<button class="small" onclick="createScoutMission('+x.p.fam+',40,10000000,100000);render()">Mission sur ce poste · 5 000 €</button>')+'<button class="dark small" onclick="openContract(\''+x.p.id+'\')" '+(!x.finance.sustainable?'disabled':'')+'>Négocier</button></div></div>').join(''):'<p>Pas de renfort prioritaire disponible parmi les agents libres de cette journée.</p>')+
 '<p class="help">Les recommandations ne recrutent personne automatiquement. Les notes exactes et les qualités d’un candidat non observé restent inconnues avant un rapport. Les transferts gardent leur négociation habituelle.</p></section>';
}
function aiRecruitmentWeek(){
 if(S.recruitmentIntelVersion!==1||S.live||S.phase!=='league'||![0,13].includes(S.round)||(S.season===1&&S.round===0))return 0;
 const e=S.economy,key=S.season+':'+S.round;
 if(e.aiRecruitmentWindow===key)return 0;
 e.aiRecruitmentWindow=key;
 let count=0;
 for(const c of S.clubs.filter(c=>c.id!==S.club)){
  if(count>=2)break;
  const urgent=recruitmentNeeds(c)[0];
  if(!urgent||urgent.score<55||c.players.length>=40)continue;
  const options=recruitmentTargets(c,S.market,false).filter(x=>x.within&&x.need.score>=55&&x.p.salary<=Math.max(1000,c.base*250));
  const best=worldAIRecruitmentChoice(c,options);
  if(!best)continue;
  const p=best.p;
  // L'IA ne possède pas de note cachée : le choix repose sur la même fourchette
  // publique. Achat limité à deux clubs par fenêtre pour préserver le marché.
  if(!S.market.some(x=>x.id===p.id)||p.contractEnd&&p.contractEnd>S.season)continue;
  c.cash-=best.finance.fee;p.contractEnd=S.season+2;p.joinedSeason=S.season;p.joinedRound=S.round;
  c.players.push(p);
  S.market=S.market.filter(x=>x.id!==p.id);
  e.freeAgents=e.freeAgents.filter(x=>x.id!==p.id);
  e.transfers.unshift({season:S.season,round:S.round,text:c.name+' recrute '+p.name+' ('+best.need.pos+') pour '+money(best.finance.fee)+'.'});
  e.transfers=e.transfers.slice(0,80);
  count++;
 }
 return count;
}



// V32 — plans de relève sans mutation de l'état ni lecture des qualités
// cachées des candidats non observés. Qualification = slotEligible du moteur.
let successionChoice={slot:0,horizon:3,years:2,renew:'',youth:'',recruit:''};
function successionPerson(p,origin='senior'){
 const known=origin!=='external',weights=ROLE_WEIGHTS[p.fam]||ROLE_WEIGHTS[7];
 let points=0,weight=0;
 if(known)for(const [k,w] of Object.entries(weights)){
  const bonus=p.dev?.specialization?.bonuses?.[k]||0;
  points+=clamp((p.skills?.[k]??p.rating)+p.rating-(p.skillBase??p.rating)+bonus,15,99)*w;weight+=w;
 }
 return {id:p.id,name:p.name,pos:p.pos,fam:p.fam,age:p.age,salary:p.salary,
  contractEnd:p.contractEnd??null,retireAge:known?(p.dev?.retireAge??99):99,
  level:known?Math.round(points/Math.max(weight,1)):null,
  potentialGap:known?Math.max(0,(p.dev?.potential??p.rating)-p.rating):null,
  origin,injury:p.injury||0};
}
function successionActive(p,year,start){
 return (p.contractEnd==null||p.contractEnd>=year)&&
  p.age+year-start<p.retireAge&&(year>start||!p.injury);
}
function successionAssignment(options){
 const owner=new Map(),order=Array.from({length:15},(_,i)=>i)
  .sort((a,b)=>options[a].length-options[b].length||a-b);
 function visit(slot,seen){
  for(const p of options[slot]){
   if(seen.has(p.id))continue;seen.add(p.id);
   if(!owner.has(p.id)||visit(owner.get(p.id),seen)){owner.set(p.id,slot);return true}
  }
  return false;
 }
 for(const slot of order)visit(slot,new Set());
 return new Set(owner.values());
}
function successionYear(s,people,prospects,year){
 const slots=Array.from({length:15},(_,slot)=>{
  const available=people.filter(p=>successionActive(p,year,s.season)&&slotEligible(p,slot))
   .sort((a,b)=>(b.level??50)-(a.level??50)||a.id.localeCompare(b.id));
  const youth=prospects.filter(p=>p.age+year-s.season<=21&&p.dev?.potential>=p.rating+5&&slotEligible(p,slot));
  const nearEnd=available.filter(p=>p.contractEnd===year||p.age+year-s.season+1>=p.retireAge);
  return {slot,pos:POS[slot],count:available.length,ids:available.map(p=>p.id),youth:youth.length,
   priority:clamp((available.length===0?55:available.length===1?28:0)+
    Math.min(18,nearEnd.length*9)-Math.min(10,youth.length*5),0,100)};
 });
 const assigned=successionAssignment(slots.map(p=>people.filter(q=>p.ids.includes(q.id))));
 return {year,covered:assigned.size,gaps:slots.filter(p=>!assigned.has(p.slot)).map(p=>p.slot),
  thin:slots.filter(p=>p.count<2).length,slots};
}
function successionSimulate(s,actions=[],horizon=3){
 if(!s||!Array.isArray(actions)||actions.length>3||!Number.isInteger(horizon)||horizon<1||horizon>3)
  return {valid:false,error:'Plan ou horizon invalide.'};
 const original=s.clubs[s.club].players,base=forecastContractBase(s);
 const people=original.map(p=>successionPerson(p)),prospects=s.development.academy.slice();
 let fee=0,executable=!s.live;const seen=new Set(),reasons=[];
 for(const act of actions){
  if(!act||!['renew','recruit','youth'].includes(act.kind)||typeof act.id!=='string'||seen.has(act.id))
   return {valid:false,error:'Action répétée ou inconnue.'};
  seen.add(act.id);
  if(act.kind==='youth'){
   const p=prospects.find(p=>p.id===act.id);
   if(!p||people.length>=42)return {valid:false,error:'Espoir indisponible ou effectif complet.'};
   prospects.splice(prospects.indexOf(p),1);
   const newcomer=successionPerson(p,'promoted');
   newcomer.contractEnd=base+1;newcomer.injury=0;people.push(newcomer);
   reasons.push('Espoir : '+p.name+' (contrat jusqu’à S'+newcomer.contractEnd+
    ', salaire '+money(p.salary)+'/journée), sans progression inventée.');
  }else{
   const quote=forecastQuote(s,{kind:act.kind,id:act.id,years:act.years??2});
   if(!quote.valid)return {valid:false,error:quote.error};
   const source=(act.kind==='renew'?original:s.market).find(p=>p.id===act.id);
   const term=quote.players.find(p=>p.id===act.id);
   if(!source||!term)return {valid:false,error:'Candidat indisponible.'};
   fee+=quote.fee;if(quote.executable===false)executable=false;
   if(act.kind==='renew'){
    const p=people.find(p=>p.id===act.id);
    p.salary=term.salary;p.contractEnd=term.contractEnd;
    reasons.push('Prolongation : '+p.name+', salaire '+money(p.salary)+
     '/journée, prime '+money(quote.fee)+'.');
   }else{
    if(people.length>=42)return {valid:false,error:'Effectif professionnel complet.'};
    const p=successionPerson(source,'external');p.salary=term.salary;p.contractEnd=term.contractEnd;p.injury=0;
    people.push(p);
    reasons.push('Recrutement : '+p.name+', prime '+money(quote.fee)+', salaire '+money(p.salary)+
     '/journée. '+(recruitmentEvidence(source).seen?'Rapport de scouting disponible.':'Qualités et potentiel non observés.'));
   }
  }
 }
 if(fee>s.clubs[s.club].cash)executable=false;
 const years=Array.from({length:horizon},(_,i)=>successionYear(s,people,prospects,s.season+i));
 const projected={...s,clubs:s.clubs.map((c,i)=>i===s.club?{...c,cash:c.cash-fee,
  players:people.map(p=>({id:p.id,salary:p.salary,contractEnd:p.contractEnd}))}:c)};
 const finance=forecastFinancialScenario(projected,{kind:'baseline'},horizon);
 if(!finance.valid)return {valid:false,error:finance.error};
 if(!executable)reasons.push('Plan non réalisable immédiatement (match, limite ou trésorerie).');
 return {valid:true,executable,years,finance,fee,reasons,
  gaps:years.reduce((n,y)=>n+y.gaps.length,0)};
}
function successionOptions(s,slot,horizon){
 const own=s.clubs[s.club].players,base=forecastContractBase(s);
 const renew=own.filter(p=>slotEligible(p,slot)&&p.contractEnd<=s.season+horizon&&
  Math.max(1,p.contractEnd-base+2)<=3&&p.age<(p.dev?.retireAge??99)-1)
  .sort((a,b)=>a.contractEnd-b.contractEnd||a.id.localeCompare(b.id));
 const youth=s.development.academy.filter(p=>slotEligible(p,slot)&&p.age<=21&&p.dev?.potential>=p.rating+5)
  .sort((a,b)=>b.dev.potential-a.dev.potential||a.id.localeCompare(b.id));
 const recruit=s.market.filter(p=>slotEligible(p,slot)).sort((a,b)=>
  recruitmentEvidence(b).quality-recruitmentEvidence(a).quality||a.price-b.price||a.id.localeCompare(b.id));
 return {renew,youth,recruit};
}
function setSuccessionChoice(field,value){
 if(!S||!['slot','horizon','years','renew','youth','recruit'].includes(field))return false;
 if(['slot','horizon','years'].includes(field)){
  value=Number(value);
  if(!Number.isInteger(value)||(field==='slot'&&(value<0||value>14))||
   (field!=='slot'&&(value<1||value>3)))return false;
 }else if(typeof value!=='string'||value.length>150)return false;
 successionChoice[field]=value;
 if(field==='slot'){successionChoice.renew='';successionChoice.youth='';successionChoice.recruit='';}
 render();return true;
}
function successionSelect(label,field,items,selected){
 const content=items.length?items.map(p=>'<option value="'+p.id+'"'+(selected?.id===p.id?' selected':'')+'>'+
  visualEscape(p.name)+' · '+p.age+' ans'+(field==='renew'?' · fin S'+p.contractEnd:
   field==='youth'?' · potentiel '+p.dev.potential:' · prime '+money(p.price))+'</option>').join(''):
  '<option value="">Aucun joueur adapté</option>';
 return '<label>'+label+'<select aria-label="'+label+'" onchange="setSuccessionChoice(\''+field+'\',this.value)" '+
  (items.length?'':'disabled')+'>'+content+'</select></label>';
}
function successionPlanningPanel(){
 if(!S)return '';
 const o=successionChoice,h=o.horizon,slot=o.slot,poss=successionOptions(S,slot,h),selected={};
 for(const key of ['renew','youth','recruit'])selected[key]=poss[key].find(p=>p.id===o[key])||poss[key][0]||null;
 const r=selected.renew,ry=r?Math.max(o.years,r.contractEnd-forecastContractBase(S)+2):o.years;
 const choices=[
  ['Sans intervention',[]],
  ['Prolongation',r?[{kind:'renew',id:r.id,years:ry}]:null],
  ['Relève interne',selected.youth?[{kind:'youth',id:selected.youth.id}]:null],
  ['Renfort extérieur',selected.recruit?[{kind:'recruit',id:selected.recruit.id,years:o.years}]:null],
  ['Prolonger + former',r&&selected.youth?[{kind:'renew',id:r.id,years:ry},
   {kind:'youth',id:selected.youth.id}]:null]
 ];
 const plans=choices.map(([name,actions])=>({name,result:actions===null?
  {valid:false,error:'Aucun joueur compatible.'}:successionSimulate(S,actions,h)}));
 const baseline=plans[0].result,need=recruitmentNeed(club(),slot);
 const controls='<div class="succession-controls"><label>Poste<select aria-label="Poste à anticiper" onchange="setSuccessionChoice(\'slot\',this.value)">'+
  POS.map((name,i)=>'<option value="'+i+'"'+(o.slot===i?' selected':'')+'>'+(i+1)+' · '+name+'</option>').join('')+'</select></label>'+
  [['horizon','Horizon'],['years','Durée du contrat']].map(([k,name])=>
   '<label>'+name+'<select aria-label="'+name+'" onchange="setSuccessionChoice(\''+k+'\',this.value)">'+
   [1,2,3].map(n=>'<option value="'+n+'"'+(o[k]===n?' selected':'')+'>'+n+' saison'+(n>1?'s':'')+'</option>').join('')+
   '</select></label>').join('')+
  successionSelect('Cadre','renew',poss.renew,r)+successionSelect('Espoir','youth',poss.youth,selected.youth)+
  successionSelect('Agent libre','recruit',poss.recruit,selected.recruit)+'</div>';
 const tableHead='<thead><tr><th>Plan</th>'+Array.from({length:h},(_,i)=>'<th>Fin S'+(S.season+i)+'</th>').join('')+
  '<th>Trésorerie V31</th><th>Écart au statu quo</th><th>Faisabilité</th></tr></thead>';
 const rows=plans.map(p=>{
  const x=p.result;
  if(!x.valid)return '<tr><th>'+p.name+'</th><td colspan="'+(h+3)+'>'+x.error+'</td></tr>';
  const end=x.finance.points.at(-1),ref=baseline.finance.points.at(-1),diff=end.central-ref.central;
  return '<tr><th>'+p.name+'</th>'+x.years.map(y=>'<td><strong>'+
   (y.gaps.includes(slot)?'À couvrir':y.slots[slot].count+' solution(s)')+'</strong><small>'+
   y.covered+'/15 postes · '+y.thin+' fragiles</small></td>').join('')+
   '<td>'+money(end.central)+'<small>Prudent : '+money(end.low)+'</small></td>'+
   '<td>'+(diff>=0?'+':'')+money(diff)+'</td><td>'+
   (x.executable?'Simulation possible':'Non exécutable aujourd’hui')+'</td></tr>';
 }).join('');
 const notes=plans.slice(1).map(p=>'<p class="help"><strong>'+p.name+' :</strong> '+
  (p.result.valid?p.result.reasons.join(' ')+' Risque : '+p.result.finance.risk+'.':p.result.error)+'</p>').join('');
 return '<div class="card succession-panel"><div class="cardtitle"><h2>Anticiper les 3 saisons</h2>'+
  '<span class="tag">PLANIFICATION V32</span></div>'+
  '<p class="help">Scénarios sans effet sur la carrière, les matchs ou les sauvegardes. Les qualifications des postes sont celles du moteur : chaque joueur ne couvre qu’un seul des 15 postes simultanément.</p>'+
  controls+'<p class="help">Besoin V30 en '+POS[slot]+' : '+need.score+'/100 ; qualité V29 à renforcer : '+
  (ATTR[need.quality]||need.quality)+'. Les capacités cachées des candidats non observés restent inconnues.</p>'+
  '<div class="tablewrap"><table class="succession-table">'+tableHead+'<tbody>'+rows+
  '</tbody></table></div>'+notes+
  '<p class="help">La trésorerie suit les coefficients et les échéances V31. Les contrats expirés et retraites prévues réduisent la couverture future ; la promotion ajoute uniquement le contrat et le salaire existants. Aucune nouvelle progression, victoire, blessure ou signature automatique n’est supposée.</p></div>';
}
