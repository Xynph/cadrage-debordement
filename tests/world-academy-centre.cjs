'use strict';
// Centre de formation en carrière Monde (22/11/2026) : les parcours s'ouvrent pour tous les clubs du monde, sur un
// centre par vrai club (aucun invité fictif, aucune borne à 44). Temps 1 : détection, mentorat, centres observés et
// recrutement de leurs jeunes, installations, éducateurs, engagements, stage U20, passerelle pro, prêts vers n'importe
// quel club du monde, prix indexés sur les moyens du club. Temps 2 : plus aucun module fermé. Minutes, périodes,
// résultats et plan des rencontres viennent des vrais matchs de jeunes de chaque pays (youthMatches) ; objectifs, plans
// de carrière, filières (zones du rugby mondial), réputation, cohésion et générations ouverts. Aucun championnat
// Espoirs français (v73-v75) dans le Monde ; les centres ouverts au temps 1 sont complétés.
// Clubs : Alder Fen XV (102, Champ anglais), Marcq Métropole XV (91, Nationale, 400 000 €), Toulouse (0, Top 14).
// CD_CENTRE_SAISON=1 : en plus, saison complète en cadence JOURNALIÈRE (comme le jeu), fin de saison, mobilité du
// manager (Alder Fen) et saison suivante (~15 min par club ; local, hors CI). CD_CENTRE_CLUBS=102,91,0 : clubs testés.
const {test}=require('node:test'),assert=require('node:assert/strict');
const H=require('./helpers/carriere-monde.cjs');
const CLUBS=(process.env.CD_CENTRE_CLUBS||'102,91,0').split(',').map(Number);
const SAISON=process.env.CD_CENTRE_SAISON==='1';
const BASE={scout:35000,mentor:8000,facilities:85000,coaches:55000,discover:3000,watch:500,trial:1000,partner:2000,recruit:8000,meeting:2000};
const BUREAUX=['v72Youth','v76Scouting','v77Promotions','v78to81','v82to85','v86to89','v90to94','v95to100','v101to104'];

function ouvrir(club){
 const jeu=H.ouvrir({simulation:true,testVm:true});
 const lire=expr=>JSON.parse(jeu.bridge.vm.run('JSON.stringify('+expr+')'));
 return {jeu,lire,model:H.creer(jeu,club)};
}

function decisions(t,club){
 const {jeu,lire}=t;let model=t.model;
 const ap=()=>model.clubLife.academyPathways,ctx=()=>ap().context;
 const ok=(command,payload)=>{const r=jeu.brut(command,{...ctx(),...payload});assert.equal(r.ok,true,club+' '+command+' : '+r.error);model=r.model;return model;};
 const cash=()=>ap().cash;
 // Ancienne sauvegarde Monde (sans centre activé) : elle se valide telle quelle et propose l'activation.
 assert.doesNotThrow(()=>jeu.bridge.vm.run('validateCareer(S)'));
 assert.equal(ap().available,true,'parcours disponibles en Monde');assert.equal(ap().active,false);assert.equal(ap().world,true);
 const costs=ap().costs,means=lire('S.clubBudget.clubs[S.club].depart');
 // Prix indexés : proportionnels aux moyens du club (4 M€ = prix historiques), bornés entre 10 % et 200 %.
 const k=Math.min(2,Math.max(.1,means/4e6));
 for(const key of ['scout','mentor','discover','watch','trial','partner','recruit','meeting'])assert.ok(Math.abs(costs[key]-BASE[key]*k)<=Math.max(100,BASE[key]*k*.03),club+' prix '+key+' '+costs[key]);
 assert.ok(costs.facilities[0]<=cash()*.1,'premier niveau des installations abordable ('+costs.facilities[0]+' pour '+cash()+')');
 if(means>=6e6)assert.ok(costs.scout>BASE.scout&&costs.facilities[0]>BASE.facilities,'gros club : prix au-dessus des prix historiques');
 if(means<=5e5)assert.ok(costs.scout<=5000&&costs.facilities[0]<=10000,'petit club : prix réduits');

 ok('academy_activate',{confirmed:true});
 const clubs=lire('S.clubs.length');
 assert.equal(ap().active,true);assert.equal(ap().centers.length,clubs,'un centre par club du monde');
 assert.equal(ap().centers.filter(c=>c.clubId===null).length,0,'aucun centre invité');
 assert.equal(lire("['v73Espoirs','v74Accession','v75Movement'].filter(k=>S[k]!==undefined).length"),0,'aucun championnat Espoirs français');
 assert.deepEqual(lire(`${JSON.stringify(BUREAUX)}.filter(k=>S[k]===undefined)`),[],'tous les bureaux du Centre ouverts');
 assert.equal(ap().closedModules,undefined,'aucun module fermé');assert.equal(ap().totalRounds,26);assert.equal(ap().mode,'equilibre');
 // Les vrais matchs des jeunes continuent une fois le Centre activé (ils nourrissent minutes, périodes et résultats).
 assert.equal(lire('CDYouthMatches.project().available===true||S.youthMatches===undefined'),true,'matchs des jeunes actifs');
 // Identifiants uniques sur toutes les académies du monde (plus de jeunes « youth-100+i » d'invités).
 assert.equal(lire('(()=>{const ids=[...S.development.academy,...S.aiRoster.academies.flatMap(a=>a.players),...S.clubs.flatMap(c=>c.players)].map(p=>p.id);return ids.length-new Set(ids).size})()'),0,'identifiants de joueurs uniques');
 assert.equal(ap().loanClubs.length>=clubs-5,true,'prêt possible vers presque tous les clubs du monde');

 let before=cash();ok('academy_scout',{confirmed:true});assert.equal(cash(),before-costs.scout,'détection débitée');assert.equal(ap().nextScouted,true);
 const jeune=ap().players.find(p=>!p.injury)||ap().players[0];
 before=cash();ok('academy_mentor',{playerId:jeune.id,focus:'technique',confirmed:true});assert.equal(cash(),before-costs.mentor);assert.equal(ap().weekMentored,true);
 const centre=ap().centers.find(c=>!c.own&&c.count>15),budget=ap().recruitBudget;
 ok('academy_center_scout',{centerId:centre.id,confirmed:true});assert.equal(ap().recruitBudget,budget-costs.centerScout);
 const candidat=ap().centers.find(c=>c.id===centre.id).candidates[0];assert.ok(candidat,'jeunes à recruter dans le centre observé');
 const effectif=ap().players.length;ok('academy_recruit',{playerId:candidat.id,offer:candidat.fee,confirmed:true});
 assert.equal(ap().players.length,effectif+1,'le jeune recruté rejoint le centre');
 assert.ok(lire(`S.aiRoster.academies.every(a=>a.players.every(p=>p.id!==${JSON.stringify(candidat.id)}))`),'et quitte son centre d’origine');
 for(const kind of ['facilities','coaches']){before=cash();ok('academy_upgrade',{kind,confirmed:true});assert.equal(cash(),before-costs[kind][0]);assert.equal(ap()[kind],1);}
 const engage=ap().players.find(p=>p.age<=21&&p.id!==candidat.id);
 before=cash();ok('academy_contract',{playerId:engage.id,years:2,confirmed:true});assert.equal(cash(),before-engage.contractFees[1]);
 const u20=lire('S.development.academy.filter(p=>p.age<=20&&!p.injury&&p.rating<p.dev.potential).map(p=>p.id)')[0];
 if(u20)ok('academy_u20',{playerId:u20});
 const promu=ap().players.find(p=>p.age<=21&&![engage.id,u20].includes(p.id));
 if(ap().promotionAvailable)ok('academy_promote',{playerId:promu.id,years:2,confirmed:true});
 // Prêt vers un club hors de l'ancienne carrière France (identifiant >= 30) : n'importe quel club du monde.
 const senior=ap().seniors.find(p=>p.loanEligible),accueil=ap().loanClubs.find(c=>c.id>=30&&c.id!==club);
 assert.ok(senior&&accueil,'un jeune professionnel prêtable et un club d’accueil');
 ok('academy_loan',{playerId:senior.id,to:accueil.id,confirmed:true});
 assert.ok(lire(`S.clubs[${accueil.id}].players.some(p=>p.id===${JSON.stringify(senior.id)})`),'joueur prêté dans l’effectif d’accueil');
 // Temps 2 : plan des rencontres, objectifs, plans de carrière, filières et cohésion ouverts en Monde.
 ok('academy_mode',{mode:'developpement'});assert.equal(ap().mode,'developpement');assert.equal(lire('S.nativeAcademy.mode'),'developpement');
 assert.equal(jeu.brut('academy_mode',{...ctx(),mode:'inconnu'}).ok,false,'plan des rencontres inconnu refusé');
 ok('academy_goal',{goal:'promotions'});assert.equal(ap().goal,'promotions');
 const suivi=ap().players.find(p=>p.id!==candidat.id&&p.age<=21&&ap().players.some(q=>q.id===p.id))||ap().players[0];
 ok('academy_plan',{playerId:suivi.id,target:'minutes'});ok('academy_target',{playerId:suivi.id,minutes:480});ok('academy_path',{playerId:suivi.id,strategy:'minutes'});
 assert.equal(ap().players.find(p=>p.id===suivi.id).target,480);assert.equal(ap().players.find(p=>p.id===suivi.id).path,'minutes');
 ok('academy_specialize',{playerId:suivi.id,kind:'vitesse'});ok('academy_load',{playerId:suivi.id,load:'allegee'});
 ok('academy_interview',{playerId:suivi.id,answer:'minutes'});ok('academy_ambition',{playerId:suivi.id,decision:'accompagner'});
 const binome=ap().players.map(p=>[p,ap().seniors.find(x=>x.pos===p.pos&&x.age>=23)]).find(([,x])=>x);
 if(binome)ok('academy_pair',{playerId:binome[0].id,seniorId:binome[1].id});
 ok('academy_identity',{identity:'mouvement'});assert.equal(ap().identity,'mouvement');
 before=cash();const cohesion=ap().cohesion;ok('academy_meeting',{confirmed:true});assert.equal(cash(),before-costs.meeting,'réunion au prix indexé');assert.ok(ap().cohesion>cohesion,'réunion de cohésion');
 // Filières : grandes zones du rugby mondial, la zone du club en tête ; l'union du club est « nationale ».
 assert.equal(ap().regions.length,6);assert.ok(!ap().regions.includes('Bretagne'),'plus de régions françaises en Monde');
 assert.equal(ap().homeUnion,lire('CDWorldEditions.forState(S).registry.clubs.find(c=>c.id===S.club).country'));
 const zone=lire('S.v95to100.region');assert.ok(ap().regions.includes(zone),'zone du club : '+zone);
 before=cash();ok('academy_discover',{region:zone,confirmed:true});assert.equal(cash(),before-costs.discover,'détection de filière au prix indexé');
 const espoir=ap().prospects.find(p=>p.scouted>0)||ap().prospects[0];assert.ok(espoir,'jeunes des filières');
 before=cash();ok('academy_watch',{playerId:espoir.id,confirmed:true});assert.equal(cash(),before-costs.watch);before=cash();ok('academy_trial',{playerId:espoir.id,confirmed:true});assert.equal(cash(),before-costs.trial);
 before=cash();ok('academy_partner',{feederId:ap().feeders[0].id,confirmed:true});assert.equal(cash(),before-costs.partner);assert.ok(ap().partners.includes(ap().feeders[0].id));
 const offre=ap().offers.find(o=>o.clubs.length);if(offre)ok('academy_retain',{playerId:offre.id,clubId:offre.clubs[0].clubId,confirmed:true});
 // Championnat Espoirs français refusé en Monde.
 assert.throws(()=>jeu.bridge.vm.run('const old=S.v73Espoirs;try{S.v73Espoirs={};CDNativeAcademy.validate(S)}finally{if(old===undefined)delete S.v73Espoirs;else S.v73Espoirs=old}'),/championnat Espoirs/);
 assert.doesNotThrow(()=>jeu.bridge.vm.run('validateCareer(S)'));
 t.model=model;return {senior:senior.id,accueil:accueil.id,mentored:jeune.id,suivi:suivi.id};
}

// Conférence de presse obligatoire encore ouverte (bilan de fin de saison) : réponses prudentes, comme le manager.
function presse(jeu,model){
 for(let i=0;i<4;i++){const press=model.clubLife.press,c=press?.conference;if(!c?.available||!c.questions?.length)return model;
  model=jeu.regler(jeu.call('press_conference',{context:press.context,answers:c.questions.map(q=>({questionId:q.id,answerId:(q.answers.find(a=>a.tone==='cautious')||q.answers[0]).id})),...(typeof c.invitationId==='string'?{invitationId:c.invitationId}:{})}));}
 return model;
}

// Saison complète jour par jour, mentorat chaque semaine où c'est possible, puis fin de saison et saison suivante.
function saison(t,club,suivi){
 const {jeu,lire}=t;let model=t.model;
 const ap=()=>model.clubLife.academyPathways;
 let mentorats=0,jours=0,matchs=0;
 for(;jours<700&&model.meta.phase!=='ended';jours++){
  model=jeu.regler(model);
  if(model.meta.phase==='ended')break;
  const a=ap();
  if(!a.weekMentored&&!a.locked&&a.cash>=a.costs.mentor&&a.players.length){const r=jeu.brut('academy_mentor',{...a.context,playerId:a.players[mentorats%a.players.length].id,focus:['technique','mental','physique'][mentorats%3],confirmed:true});if(r.ok){model=r.model;mentorats++;}}
  if(model.meta.calendarCadence?.matchReady&&model.next){model=H.jouerLeMatch(jeu,model);matchs++;continue;}
  assert.equal(model.meta.calendarCadence?.canAdvance,true,'journée autorisée ('+model.meta.calendarToday+')');
  model=jeu.call('advance_day',{fromDate:model.meta.calendarToday});
 }
 assert.equal(model.meta.phase,'ended','saison terminée en '+jours+' jours');
 // Temps 2 : la saison des jeunes a vraiment eu lieu (minutes, périodes et résultats tirés des matchs de jeunes du pays).
 const fin=ap(),minutes=fin.players.reduce((n,p)=>n+p.minutes,0);
 assert.ok(minutes>0&&fin.players.some(p=>p.minutes>=240),'minutes juniors de la saison ('+minutes+')');
 assert.ok(fin.juniorRound>=20,'périodes juniors avancées ('+fin.juniorRound+'/26)');
 assert.ok(fin.results.length>0&&fin.results.every(r=>r.score.length===2&&typeof r.homeCenter==='string'&&typeof r.awayCenter==='string'),'résultats Espoirs du centre');
 const appliques=lire('S.v72Youth.mentors.filter(x=>x.done).length');
 assert.ok(mentorats>=10&&appliques>=mentorats-2,'mentorats appliqués à l’entraînement ('+appliques+'/'+mentorats+')');
 assert.doesNotThrow(()=>jeu.bridge.vm.run('validateCareer(S)'));
 let cible=null;
 if(club===102){// Mobilité du manager vers un club hors de l'ancienne carrière France (Nationale) : le Centre suit.
  cible=91;
  jeu.bridge.vm.run(`if(!managerMobilityActive())managerMobilityEnable();{const target=${cible};let d=managerMobilityDecision(target);if(!d?.accepted){S.clubs[target].cash=Math.max(S.clubs[target].cash,10000000);worldClub(target).debt=0;worldClub(target).reputation=0;worldClub(target).coachConfidence=0;}if(!managerMobilityApply(target)||!managerMobilityAccept('job-'+S.season+'-'+target))throw Error('Mobilité refusée.');}`);
 }
 const season=lire('S.season');
 // Intersaison : journées jusqu'à l'ouverture de la saison suivante (calendrier international), comme le manager.
 model=presse(jeu,jeu.regler(model));
 for(let j=0;j<200&&!model.meta.canAdvanceSeason;j++){
  assert.equal(model.meta.calendarCadence?.canAdvance,true,'journée d’intersaison autorisée ('+model.meta.calendarToday+')');
  model=presse(jeu,jeu.regler(jeu.call('advance_day',{fromDate:model.meta.calendarToday})));
 }
 assert.equal(model.meta.canAdvanceSeason,true,'saison suivante ouverte');
 model=jeu.regler(jeu.call('next_season',{confirmed:true}));
 assert.equal(lire('S.season'),season+1);
 assert.ok(lire(`S.clubs[S.nativeAcademy.club]&&S.nativeAcademy.season===S.season&&S.nativeAcademy.lastClosed===${season}`),'centre clos et rouvert');
 assert.ok(lire(`!S.clubs[${suivi.accueil}].players.some(p=>p.id===${JSON.stringify(suivi.senior)})`),'retour de prêt à l’intersaison');
 assert.ok(lire(`S.v72Youth.scouts.some(x=>x.target===${season+1})`)||cible!==null,'détection suivie');
 // Bilans de fin de saison des bureaux du temps 2 (génération archivée, objectifs, cohésion/réputation, promesses).
 const bureau=cible===null?'S':`S.nativeAcademy.offices[${club}]`;
 assert.ok(lire(`${bureau}.v101to104.archive.some(h=>h.season===${season}&&h.players.length>0)`),'génération archivée');
 assert.ok(lire(`${bureau}.v101to104.archive.find(h=>h.season===${season}).players.some(p=>p.minutes>0)`),'minutes de la génération archivées');
 for(const k of ['v82to85','v90to94','v95to100'])assert.ok(lire(`${bureau}.${k}.history.some(h=>h.season===${season})`),'bilan '+k);
 if(cible!==null){
  assert.equal(lire('S.club'),cible);assert.equal(lire('S.nativeAcademy.club'),cible);
  assert.ok(lire('S.nativeAcademy.offices[102]?.v78to81!==undefined'),'bureau de formation d’Alder Fen archivé');
  assert.equal(ap().active,true);
 }
 const a=ap();
 assert.equal(a.active,true);
 const r=jeu.brut('academy_scout',{...a.context,confirmed:true});assert.equal(r.ok,true,'détection de la nouvelle saison : '+r.error);model=r.model;
 assert.doesNotThrow(()=>jeu.bridge.vm.run('validateCareer(S)'));
 t.model=model;
 return {jours,matchs,mentorats,appliques,club:lire('S.club'),cash:ap().cash,costs:ap().costs};
}

// Centre ouvert au temps 1 (bureaux v72-v81, sans plan des rencontres) : la sauvegarde se valide telle quelle, puis le
// Centre est complété à la première lecture (aucun module fermé).
test('Centre Monde : centre du temps 1 complété',{timeout:600000},()=>{
 const t=ouvrir(91);
 try{
  const {jeu,lire}=t;let model=t.model;
  model=jeu.call('academy_activate',{...model.clubLife.academyPathways.context,confirmed:true});
  jeu.bridge.vm.run(`for(const k of ${JSON.stringify(BUREAUX.slice(4))})delete S[k];delete S.nativeAcademy.mode;`);
  assert.doesNotThrow(()=>jeu.bridge.vm.run('CDNativeAcademy.validate(S)'),'sauvegarde du temps 1 valide');
  const ap=jeu.call('academy_goal',{...model.clubLife.academyPathways.context,goal:'prets'}).clubLife.academyPathways;
  assert.deepEqual(lire(`${JSON.stringify(BUREAUX)}.filter(k=>S[k]===undefined)`),[],'bureaux complétés');
  assert.equal(lire('S.nativeAcademy.mode'),'equilibre');assert.equal(ap.goal,'prets');assert.equal(ap.closedModules,undefined);
  assert.doesNotThrow(()=>jeu.bridge.vm.run('validateCareer(S)'));
 }finally{t.jeu.fermer();}
});

// Non-régression des prix : hors Monde (carrière France) et à la caisse de référence (4 M€), chaque prix du Centre
// (filières, réunion de cohésion et recrutement compris) reste le prix historique.
test('Centre : prix historiques hors Monde et à 4 M€',{timeout:600000},()=>{
 const t=ouvrir(91);
 try{
  const {lire}=t,bases=Object.values(BASE),liste=JSON.stringify(bases);
  assert.deepEqual(lire(`${liste}.map(v=>CDNativeAcademy.fee({club:0,clubs:[{cash:1e5}]},v))`),bases,'France : prix inchangés');
  assert.deepEqual(lire(`(()=>{const b=S.clubBudget.clubs[S.club],d=b.depart;b.depart=4e6;try{return ${liste}.map(v=>CDNativeAcademy.fee(S,v))}finally{b.depart=d}})()`),bases,'caisse de référence : prix historiques');
  const petit=lire(`${liste}.map(v=>CDNativeAcademy.fee(S,v))`);
  assert.ok(petit.every((v,i)=>v<bases[i]),'Nationale à 400 000 € : tous les prix réduits '+petit);
 }finally{t.jeu.fermer();}
});

for(const club of CLUBS){
 test('Centre Monde : club '+club+' (activation, décisions'+(SAISON?', saison journalière':'')+')',{timeout:SAISON?3600000:600000},()=>{
  const t=ouvrir(club);
  try{
   const suivi=decisions(t,club);
   if(SAISON)console.log(JSON.stringify({club,...saison(t,club,suivi)}));
  }finally{t.jeu.fermer();}
 });
}
