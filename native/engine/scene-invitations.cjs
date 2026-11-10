'use strict';
module.exports={
 files:['native-scene-dialogues.js'],
 commands:['scene_invitation_open','scene_invitation_reply','scene_invitation_close'],
 factory:function nativeSceneInvitations(){
  const copy=x=>JSON.parse(JSON.stringify(x)),object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
  const integer=(x,a=0,b=1000000)=>Number.isSafeInteger(x)&&x>=a&&x<=b;
  const text=(x,n=240)=>typeof x==='string'&&x.length>0&&x.length<=n&&!/[\u0000-\u001f\u007f]/.test(x);
  const shape=(x,allowed,required=allowed)=>object(x)&&Object.keys(x).every(k=>allowed.includes(k))&&required.every(k=>Object.hasOwn(x,k));
  const check=(ok,message)=>{if(!ok)throw Error('Invitations de scène : '+message+'.');};
  const kinds=['private_player','private_staff','team_meeting'],topics=['intro','role','playtime','contract','morale','load','staff_alignment','consolider','repartir','rebond'];
  const statuses=['pending','completed','expired','dismissed'];
  const context=(s=S)=>({season:s.season,week:s.economy.week,club:s.club});
  const roster=(s=S)=>s.clubs[s.club]?.players||[];
  function staff(s=S){
   if(s.staffCareer?.version===1)return s.staffCareer.people.flat().filter(p=>p.clubId===s.club).map(p=>({id:p.id,sourceId:p.sourceStaffId,name:p.name,role:p.role}));
   const sources=typeof nativeStaffCareerSources==='undefined'?null:nativeStaffCareerSources;
   return (sources?.[s.commonDatabase?.id]?.find(c=>c.id===s.club)?.members||[]).filter(p=>!p.historical).map(p=>({id:p.id,sourceId:p.id,name:p.name,role:p.role}));
  }
  function facts(e){
   if(e.kind==='team_meeting')return {good_run:e.topic==='consolider',bad_run:e.topic==='repartir'};
   if(e.kind==='private_staff')return {topic_staff_disagreement:true};
   return {['topic_'+({intro:'role',staff_alignment:'staff_disagreement'}[e.topic]||e.topic)]:true};
  }
  function options(e){return CDSceneDialogues.select(e.kind==='team_meeting'?'team_meeting':'private_interview',facts(e),e.id).map(x=>({id:x.id,text:x.text,tone:x.tone,intent:x.intent}));}
  function relationshipChoice(choice){
   if(/listen|écout|ecout|dialog|understand|debrief|autonomy/i.test(choice.intent))return 'ecouter';
   if(/support|reassur|encour|apais|rassur|soutien|welfare|recovery/i.test(choice.intent)||['warm','protective'].includes(choice.tone))return 'rassurer';
   return 'clarifier';
  }
  function teamChoice(choice){return relationshipChoice(choice)==='ecouter'?'rassembler':relationshipChoice(choice)==='rassurer'?'apaiser':'exiger';}
  function participant(e,s=S){return e.kind==='team_meeting'?roster(s).length>0:e.kind==='private_player'?roster(s).some(p=>p.id===e.participantId):staff(s).some(p=>p.id===e.participantId||p.sourceId===e.participantId);}
  function expired(e,s=S){return e.clubId!==s.club||e.created.season!==s.season||s.economy.week>=e.expires.week||s.phase==='ended'||!!s.live||!participant(e,s);}
  function validate(s){
   if(!s||s.sceneInvitations===undefined)return true;
   const st=s.sceneInvitations;
   check(shape(st,['version','serial','activeId','invitations','seen','lastTeamDecision'])&&st.version===1&&integer(st.serial)&&Array.isArray(st.invitations)&&st.invitations.length<=80&&Array.isArray(st.seen)&&st.seen.length<=128&&st.seen.every(x=>text(x,600))&&new Set(st.seen).size===st.seen.length,'version, bornes ou champs inconnus');
   const date=x=>shape(x,['season','week','club'])&&integer(x.season,1,s.season)&&integer(x.week,0,s.economy.week)&&integer(x.club,0,s.clubs.length-1);
   check(st.lastTeamDecision===null||date(st.lastTeamDecision),'date de réunion');
   const ids=new Set();let pendingPrivate=0,pendingTeam=0;
   for(const e of st.invitations){
    check(shape(e,['id','kind','participantId','group','topic','title','reason','clubId','created','expires','status','sourceKey','decision'],['id','kind','topic','title','reason','clubId','created','expires','status','sourceKey'])&&text(e.id)&&!ids.has(e.id)&&kinds.includes(e.kind)&&topics.includes(e.topic)&&text(e.title,160)&&text(e.reason,500)&&text(e.sourceKey,600)&&date(e.created)&&e.clubId===e.created.club&&shape(e.expires,['season','week','beforeKickoff'])&&e.expires.season===e.created.season&&e.expires.week===e.created.week+2&&e.expires.beforeKickoff===true&&statuses.includes(e.status),'invitation ou échéance invalide');
    const identity=/^scene:(\d+):(\d+):(\d+):(\d+)$/.exec(e.id);
    check(identity&&Number(identity[1])===e.created.season&&Number(identity[2])===e.created.week&&Number(identity[3])===e.clubId&&integer(Number(identity[4]),1,st.serial),'identifiant de scène');
    check(e.kind==='team_meeting'?e.group==='squad'&&e.participantId===undefined&&['consolider','repartir','rebond'].includes(e.topic):text(e.participantId)&&e.group===undefined&&(e.kind==='private_staff'?['staff_alignment','load'].includes(e.topic):['intro','role','playtime','contract','morale'].includes(e.topic)),'destinataire ou sujet');
    // A historical participant may have left. Presence is checked when opening/replying.
    if(e.decision!==undefined){
     const d=e.decision,chosen=options(e).find(x=>x.id===d?.choiceId);
     check(shape(d,['id','choiceId','season','week','club','effect','nextStep','summary'],['id','choiceId','season','week','club','effect','nextStep','summary'])&&d.id===e.id+':reply'&&!!chosen&&date({season:d.season,week:d.week,club:d.club})&&d.season===e.created.season&&d.week>=e.created.week&&d.week<e.expires.week&&d.club===e.clubId&&['relationship','staff_receipt','team_talk','team_receipt'].includes(d.effect)&&['relationships','training','staff','preparation'].includes(d.nextStep)&&text(d.summary,500)&&!['expired','dismissed'].includes(e.status),'reçu de décision');
     check(e.kind==='private_player'?d.effect==='relationship'&&d.nextStep==='relationships':e.kind==='private_staff'?d.effect==='staff_receipt'&&['staff','training'].includes(d.nextStep):['team_talk','team_receipt'].includes(d.effect)&&d.nextStep==='preparation','effet du reçu');
    }
    check(e.status!=='completed'||!!e.decision,'clôture sans reçu');
    if(e.status==='pending'){if(e.kind==='team_meeting')pendingTeam++;else pendingPrivate++;}
    ids.add(e.id);
   }
   check(pendingPrivate<=2&&pendingTeam<=1,'trop d’invitations ouvertes');
   check(st.activeId===null||text(st.activeId)&&st.invitations.some(e=>e.id===st.activeId&&e.status==='pending'),'scène active');
   check(st.invitations.every(e=>!e.decision||e.status==='completed'||e.id===st.activeId),'reçu ouvert sans scène');
   return true;
  }
  function project(){
   if(!S)return null;
   const st=S.sceneInvitations,entries=st?.invitations||[];
   const display=e=>({...copy(e),available:e.status==='pending'&&!expired(e),...(e.kind==='private_staff'?{participantSourceId:staff().find(p=>p.id===e.participantId||p.sourceId===e.participantId)?.sourceId||e.participantId}:{})});
   const active=entries.find(e=>e.id===st?.activeId);
   return {invitations:entries.map(display).reverse(),active:active?{...display(active),options:options(active)}:null,history:entries.filter(e=>e.decision).map(display).reverse(),notice:'Invitations fondées sur la carrière. Fenêtre de deux semaines au plus, jusqu’au prochain coup d’envoi. Les seuils et délais sont des conventions de jeu.'};
  }
  function state(){return S.sceneInvitations||(S.sceneInvitations={version:1,serial:0,activeId:null,invitations:[],seen:[],lastTeamDecision:null});}
  function add(st,kind,topic,participantId,reason,sourceKey){
   if(st.seen.includes(sourceKey)||st.invitations.filter(e=>e.status==='pending'&&(kind==='team_meeting'?e.kind===kind:e.kind!=='team_meeting')).length>=(kind==='team_meeting'?1:2))return false;
   const created=context(),id='scene:'+created.season+':'+created.week+':'+created.club+':'+(++st.serial);
   st.invitations.push({id,kind,...(kind==='team_meeting'?{group:'squad'}:{participantId}),topic,title:kind==='team_meeting'?'Réunion du groupe':kind==='private_staff'?'Entretien avec le staff':'Entretien individuel',reason,clubId:S.club,created,expires:{season:S.season,week:created.week+2,beforeKickoff:true},status:'pending',sourceKey});
   st.seen.push(sourceKey);st.seen=st.seen.slice(-128);
   const pending=st.invitations.filter(e=>e.status==='pending'),closed=st.invitations.filter(e=>e.status!=='pending');st.invitations=closed.slice(-(80-pending.length)).concat(pending);return true;
  }
  function resultTrigger(){
   const rows=(S.history||[]).filter(r=>Array.isArray(r.pair)&&r.pair.includes(S.club)&&Array.isArray(r.score)&&r.score.length===2&&r.score.every(Number.isFinite)&&(!r.season||r.season===S.season));
   if(!rows.length)return null;
   const outcome=r=>{const i=r.pair.indexOf(S.club);return Math.sign(r.score[i]-r.score[1-i]);};
   const last=outcome(rows.at(-1));let run=0;for(let i=rows.length-1;i>=0&&outcome(rows[i])===last;i--)run++;
   const key=r=>r.fixtureId||[r.phase,r.round,r.week??'',r.pair.join('-'),r.score.join('-')].join(':');
   if(run>=3&&last!==0)return {topic:last>0?'consolider':'repartir',reason:last>0?'3 victoires consécutives sont enregistrées dans les résultats de l’équipe.':'3 défaites consécutives sont enregistrées dans les résultats de l’équipe.',key:(last>0?'wins:':'losses:')+key(rows[rows.length-run])};
   if(last>0&&run===1){let n=0;for(let i=rows.length-2;i>=0&&outcome(rows[i])<=0;i--)n++;if(n>=4)return {topic:'rebond',reason:'Une victoire est enregistrée après '+n+' rencontres consécutives sans victoire.',key:'rebound:'+key(rows.at(-1))};}
   return null;
  }
  function observe(command){
   // The worker invokes this only after accepted mutations. Explicitly reject read paths.
   if(!S||['snapshot','export','save','load','import','shutdown','list_profiles','profile_list'].includes(command)||typeof command!=='string')return;
   let st=S.sceneInvitations;
   if(st){
    for(const e of st.invitations)if(e.status==='pending'&&(expired(e)||command==='begin_match')){e.status=e.decision?'completed':'expired';if(st.activeId===e.id)st.activeId=null;}
   }
   if(S.live||S.phase==='ended'||command.startsWith('scene_invitation_'))return;
   if(command==='new_career'){
    st=state();const leader=roster().find(p=>p.id===S.v39?.leader)||roster()[0],colleague=staff()[0],prefix='intro:'+S.season+':'+S.club+':';
    if(leader)add(st,'private_player','intro',leader.id,'Le nouveau manager prend ses fonctions : présenter votre manière de travailler et écouter le joueur.',prefix+'player');
    if(colleague)add(st,'private_staff','staff_alignment',colleague.id,'Le nouveau manager prend ses fonctions : faire connaissance et accorder le travail du staff.',prefix+'staff');
    return;
   }
   // Do not create a namespace while inspecting or importing an old save; the next
   // actual management action can create a factual invitation.
   const unseen=(topic,p)=>!st?.seen.includes(topic+':'+S.season+':'+S.club+':'+p.id);
   const candidate=roster().find(p=>Number.isFinite(p.satisfaction?.score)&&p.satisfaction.score<=40&&unseen('role',p));
   if(candidate){st=state();add(st,'private_player','role',candidate.id,'La satisfaction enregistrée du joueur est de '+candidate.satisfaction.score+'/100 : faire le point sur son rôle.','role:'+S.season+':'+S.club+':'+candidate.id);}
   else if(S.round>=20){const p=roster().find(p=>p.contractEnd===S.season&&unseen('contract',p));if(p){st=state();add(st,'private_player','contract',p.id,'Le contrat actuel du joueur se termine à la fin de la saison '+S.season+'. Un entretien ne vaut pas prolongation.','contract:'+S.season+':'+S.club+':'+p.id);}}
   else {
    const games=(S.history||[]).filter(r=>r.pair?.includes(S.club)&&Array.isArray(r.score)&&(!r.season||r.season===S.season)).length;
    const p=games>=4&&roster().find(p=>integer(p.dev?.minutes,0,59)&&!p.injury&&unseen('playtime',p));
    if(p){st=state();add(st,'private_player','playtime',p.id,p.dev.minutes+' minute(s) de jeu sont enregistrées cette saison après '+games+' rencontres de l’équipe. Discuter des possibilités sans garantir une place.','playtime:'+S.season+':'+S.club+':'+p.id);}
   }
   const measured=roster().filter(p=>Number.isFinite(p.condition));
   if(measured.length===roster().length&&measured.length&&measured.reduce((n,p)=>n+p.condition,0)/measured.length<65){
    const colleague=staff().find(p=>/fitness|physiq|prépar|prepar/i.test(p.role))||staff()[0];
    if(colleague){st=state();add(st,'private_staff','load',colleague.id,'La condition moyenne mesurée du groupe est de '+Math.round(measured.reduce((n,p)=>n+p.condition,0)/measured.length)+'/100. Faire le point sur la préparation avant de régler la séance.','load:'+S.season+':'+S.club+':'+Math.floor(S.economy.week/3));}
   }
   const trigger=resultTrigger();
   if(trigger&&(!st?.lastTeamDecision||st.lastTeamDecision.club!==S.club||st.lastTeamDecision.season!==S.season||S.economy.week-st.lastTeamDecision.week>=3)){
    st=state();add(st,'team_meeting',trigger.topic,null,trigger.reason,'team:'+S.season+':'+S.club+':'+trigger.key);
   }
  }
  function execute(command,p){
   check(!!S,'carrière absente');validate(S);
   const allowed=command==='scene_invitation_reply'?['id','choiceId']:command==='scene_invitation_close'?['id','dismiss']:['id'];
   check(['scene_invitation_open','scene_invitation_reply','scene_invitation_close'].includes(command)&&shape(p,allowed,command==='scene_invitation_reply'?['id','choiceId']:['id'])&&text(p.id)&&(p.dismiss===undefined||typeof p.dismiss==='boolean'),'commande ou paramètres invalides');
   const st=S.sceneInvitations,e=st?.invitations.find(x=>x.id===p.id);
   check(!!e&&e.status==='pending','invitation indisponible');
   check(!S.live&&S.phase!=='ended','entretien indisponible pendant le match ou en fin de saison');
   if(command==='scene_invitation_close'){
    check(st.activeId===e.id||p.dismiss===true,'cet entretien n’est pas ouvert');
    if(e.decision)e.status='completed';else if(p.dismiss)e.status='dismissed';
    if(st.activeId===e.id)st.activeId=null;
   }else{
    check(!expired(e),'invitation périmée ou participant parti');
    if(command==='scene_invitation_open'){
     check(st.activeId===null||st.activeId===e.id,'fermez l’entretien actif');st.activeId=e.id;
    }else{
     check(st.activeId===e.id&&!e.decision&&text(p.choiceId),'réponse déjà décidée ou entretien fermé');
     const choice=options(e).find(x=>x.id===p.choiceId);check(!!choice,'déclaration non autorisée');
     let effect,nextStep,summary;
     if(e.kind==='private_player'){
      const relationships=nativeSystems.domain('relationships');check(!!relationships,'suivi des relations absent');
      relationships.execute('relationship_conversation',{context:context(),playerId:e.participantId,choice:relationshipChoice(choice)});
      effect='relationship';nextStep='relationships';summary='Entretien enregistré par le suivi des relations. Aucune promesse de contrat ou de temps de jeu n’a été créée.';
     }else if(e.kind==='private_staff'){
      effect='staff_receipt';nextStep=e.topic==='load'?'training':'staff';summary='Votre réponse est consignée. Reprenez les responsabilités du staff ou les réglages de préparation pour appliquer la suite du travail.';
     }else{
      const available=typeof v39Active==='function'?v39Active():!!S.v39;
      if(available&&typeof v39TeamTalk==='function'){check(v39TeamTalk(teamChoice(choice))===true,'réunion déjà utilisée cette semaine');effect='team_talk';summary='Réunion enregistrée par la vie du groupe ; ses effets habituels sont appliqués une seule fois.';}
      else{effect='team_receipt';summary='La déclaration au groupe est consignée. Le suivi de cohésion est inactif : poursuivez dans la préparation collective.';}
      nextStep='preparation';st.lastTeamDecision=context();
     }
     e.decision={id:e.id+':reply',choiceId:choice.id,...context(),effect,nextStep,summary};
    }
   }
   validate(S);return {sceneInvitationDecision:{command,id:e.id,status:e.status,...(e.decision?{receiptId:e.decision.id}:{})}};
  }
  function guard(command){if(command==='begin_match'&&S?.sceneInvitations?.activeId)throw Error('Fermez l’entretien actif avant le coup d’envoi.');return true;}
  function installHooks(){return true;}
  return {project,execute,validate,installHooks,observe,guard};
 }
};
