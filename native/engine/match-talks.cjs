'use strict';
// Serialized into the career VM. No disk, RNG, browser or historical v39 state.
module.exports={
 files:['native-scene-dialogues.js'],
 commands:['match_talk_decide','match_talk_continue'],
 factory:function nativeMatchTalks(){
  const copy=x=>JSON.parse(JSON.stringify(x));
  const object=x=>x!==null&&typeof x==='object'&&!Array.isArray(x);
  const integer=(x,a=0,b=1000000)=>Number.isSafeInteger(x)&&x>=a&&x<=b;
  const number=(x,a,b)=>Number.isFinite(x)&&x>=a&&x<=b;
  const text=(x,max=300)=>typeof x==='string'&&x.length>0&&x.length<=max&&!/[\u0000-\u001f]/.test(x);
  const keys=(x,fields)=>object(x)&&Object.keys(x).every(k=>fields.includes(k));
  const equal=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
  const check=(ok,detail)=>{if(!ok)throw Error('Causerie de match incohérente : '+detail+'.');};
  const phases=['pre','half','post'],bankPhases={pre:'pre_match',half:'half_time',post:'post_match'};
  // Six tons de causerie (match-pilotage.js) : calme, exigeant, encourageant, furieux, rassurant, affirmé.
  const tones=typeof TONS_CAUSERIE!=='undefined'?TONS_CAUSERIE:['calm','demanding','warm','furious','protective','assertive'];
  const toneLabel=t=>typeof TONS_LABELS!=='undefined'&&TONS_LABELS[t]||t;
  const etats=()=>typeof PILOTAGE_ETATS!=='undefined'?PILOTAGE_ETATS:{};
  const clamp=(n,a,b)=>Math.max(a,Math.min(b,n));
  const hash=x=>{let h=2166136261;for(const c of x)h=Math.imul(h^c.charCodeAt(0),16777619);return h>>>0;};
  let delegating=false,installed=false;
  function identity(s,l){
   return {season:s.season,round:s.round,club:s.club,pair:l.pair.slice(),competitionPhase:l.worldContext?.phase||l.franceContext?.phase||s.phase,
    fixture:l.worldContext?.id||l.franceContext?.fixtureId||s.phase+':'+s.round+':'+l.pair.join('-')};
  }
  const matchKey=c=>'match:'+c.season+':'+c.round+':'+c.club+':'+c.pair.join('-')+':'+c.competitionPhase+':'+c.fixture;
  function matches(s,r){return !!s?.live&&s.live.userSide>=0&&s.live.pair[s.live.userSide]===s.club&&equal(r.context,identity(s,s.live));}
  function phaseContext(s,l,phase){
   const neutral=l.worldContext?l.worldContext.neutral:l.franceContext?l.franceContext.neutral:s.phase==='semi'||s.phase==='final';
   const venue=neutral?'neutral':l.userSide===0?'home':'away';
   const diff=l.score[l.userSide]-l.score[1-l.userSide];
   const scoreState=diff>0?'winning':diff<0?'losing':'drawing';
   const result=phase==='post'?(l.winner===undefined?(diff>0?'win':diff<0?'loss':'draw'):l.winner===s.club?'win':'loss'):null;
   const out={venue,score:l.score.slice(),userSide:l.userSide,scoreState,result};
   // Pronostic d'avant-match (18/11/2026) : favori ou outsider au-delà du seuil de complaisance (tactical-plans.js, RELACHEMENT).
   if(phase==='pre'){const g=pronostic(l);if(g)out.pronostic=g;}
   return out;
  }
  function pronostic(l){
   if(typeof teamLevel!=='function'||typeof activePlayers!=='function'||!l?.sheets||!(l.userSide>=0))return null;
   const g=teamLevel(activePlayers(l,l.userSide))-teamLevel(activePlayers(l,1-l.userSide)),seuil=typeof RELACHEMENT!=='undefined'?RELACHEMENT.seuil:3;
   return g>=seuil?'favorite':g<=-seuil?'underdog':null;
  }
  function facts(phase,c){
   if(phase==='pre')return {...(c.venue==='neutral'?{}:{home:c.venue==='home',away:c.venue==='away'}),...(c.pronostic?{[c.pronostic]:true}:{})};
   if(phase==='half')return {winning:c.scoreState==='winning',drawing:c.scoreState==='drawing',losing:c.scoreState==='losing'};
   return {result_win:c.result==='win',result_draw:c.result==='draw',result_loss:c.result==='loss'};
  }
  function options(key,p){
   return CDSceneDialogues.byTone(bankPhases[p.phase],facts(p.phase,p.context),key+':'+p.phase,tones)
    .map(e=>({id:e.id,text:e.text,tone:e.tone,toneLabel:toneLabel(e.tone),intent:e.intent}));
  }
  const pending=r=>r?.phases.find(p=>!p.closed)||null;
  function roster(s,r){return s.clubs[r.context.club].players;}
  // A missing nominated prop keeps his original shirt vacant; the other
  // bench players retain the numbers of the selected match-day group.
  const participantNumber=(s,l,id,index)=>l.nationaleReducedBench?[...s.lineup,...s.reserves].indexOf(id)+1:index+1;
  function initialParticipants(s,l){
   const people=new Map(s.clubs[s.club].players.map(p=>[p.id,p]));
   return [...l.sheets[l.userSide].initial,...l.sheets[l.userSide].bench].map((id,i)=>{
    const p=people.get(id);check(p&&integer(p.fam,0,8),'joueur de la feuille');
    return {id,number:participantNumber(s,l,id,i),group:p.fam<=3?'forwards':'backs'};
   });
  }
  function audienceIds(r,audience,ids){
   check(['group','forwards','backs','players'].includes(audience)&&Array.isArray(ids)&&ids.length<=23&&ids.every(id=>text(id))&&new Set(ids).size===ids.length,'destinataires');
   const eligible=r.participants.filter(p=>audience==='group'||audience==='players'||p.group===audience).map(p=>p.id);
   if(audience==='players')check(ids.length>0&&ids.every(id=>eligible.includes(id)),'joueurs sélectionnés hors feuille');
   else check(ids.length===0||equal(ids,eligible),'liste exacte du groupe');
   return audience==='players'?r.participants.filter(p=>ids.includes(p.id)).map(p=>p.id):eligible;
  }
  // Réaction de chaque joueur (match-pilotage.js) : personnalité (traits cachés), score et enjeu, confiance envers
  // le manager, usure d'un ton répété et part d'imprévu. Aucune déclaration ne garantit un effet positif.
  function reactions(s,r,ids,tone,phase,context){
   const people=new Map(roster(s,r).map(p=>[p.id,p]));
   return ids.map(id=>reactionJoueur(people.get(id),tone,phase,context,r.key,ids.length===1));
  }
  const reactionValide=(x,id)=>keys(x,['id','score','etat','label','delta'])&&x.id===id&&number(x.score,-3,3)&&Object.hasOwn(etats(),x.etat)&&x.label===etats()[x.etat].label&&[-1,0,1].includes(x.delta);
  function validateContext(s,c){
   check(keys(c,['season','round','club','pair','competitionPhase','fixture'])&&integer(c.season,1,s.season)&&integer(c.round,0,1000)&&integer(c.club,0,s.clubs.length-1)&&Array.isArray(c.pair)&&c.pair.length===2&&c.pair.every(id=>integer(id,0,s.clubs.length-1))&&c.pair[0]!==c.pair[1]&&c.pair.includes(c.club)&&text(c.competitionPhase,60)&&text(c.fixture,180),'identité rencontre');
   if(c.season===s.season&&c.competitionPhase===s.phase)check(c.round<=s.round,'journée future');
  }
  function validatePhaseContext(c,phase,identityContext){
   check(keys(c,['venue','score','userSide','scoreState','result','pronostic'])&&(c.pronostic===undefined||phase==='pre'&&['favorite','underdog'].includes(c.pronostic))&&['home','away','neutral'].includes(c.venue)&&Array.isArray(c.score)&&c.score.length===2&&c.score.every(n=>integer(n,0,1000))&&integer(c.userSide,0,1)&&identityContext.pair[c.userSide]===identityContext.club,'contexte sportif');
   const diff=c.score[c.userSide]-c.score[1-c.userSide];
   check(c.scoreState===(diff>0?'winning':diff<0?'losing':'drawing')&&(c.venue==='neutral'||c.venue===(c.userSide===0?'home':'away')),'score et lieu');
   check(phase==='post'?['win','loss','draw'].includes(c.result):c.result===null,'résultat de phase');
   if(phase==='post'&&diff!==0)check(c.result===(diff>0?'win':'loss'),'résultat incompatible avec le score');
   if(phase==='pre')check(equal(c.score,[0,0]),'score avant-match');
  }
  function validate(s){
   if(!s||s.contextualMatch===undefined)return true;
   const st=s.contextualMatch;
   check(keys(st,['version','current','receipts'])&&st.version===1&&Array.isArray(st.receipts)&&st.receipts.length<=48&&(st.current===null||object(st.current)),'version et historique');
   const receiptKeys=new Set();
   for(const rec of st.receipts){
    check(keys(rec,['key','phase','context','phaseContext','status','choiceId','audience','playerIds','moraleDelta'])&&phases.includes(rec.phase)&&['decided','skipped','delegated'].includes(rec.status),'reçu');
    validateContext(s,rec.context);validatePhaseContext(rec.phaseContext,rec.phase,rec.context);
    check(rec.key===matchKey(rec.context)&&!receiptKeys.has(rec.key+':'+rec.phase)&&number(rec.moraleDelta,-2,2)&&Array.isArray(rec.playerIds)&&rec.playerIds.length<=23&&rec.playerIds.every(id=>text(id))&&new Set(rec.playerIds).size===rec.playerIds.length,'unicité et bornes du reçu');
    receiptKeys.add(rec.key+':'+rec.phase);
    if(rec.choiceId!==null)check(rec.status!=='skipped'&&options(rec.key,{phase:rec.phase,context:rec.phaseContext}).some(o=>o.id===rec.choiceId)&&['group','forwards','backs','players'].includes(rec.audience)&&rec.playerIds.length>0,'choix du reçu');
    else check(rec.status!=='decided'&&rec.audience===null&&rec.playerIds.length===0&&rec.moraleDelta===0,'reçu sans parole');
   }
   const r=st.current;if(!r)return true;
   check(keys(r,['key','context','participants','phases'])&&Array.isArray(r.participants)&&r.participants.length===(s.live?.nationaleReducedBench?22:23)&&Array.isArray(r.phases)&&r.phases.length>=1&&r.phases.length<=3,'rencontre active');
   validateContext(s,r.context);check(r.key===matchKey(r.context)&&r.context.club===s.club&&matches(s,r),'référence de rencontre active');
   const people=new Map(roster(s,r).map(p=>[p.id,p])),seen=new Set();
   for(let i=0;i<r.participants.length;i++){
    const p=r.participants[i],player=people.get(p.id);
    check(keys(p,['id','number','group'])&&text(p.id)&&player&&!seen.has(p.id)&&p.number===participantNumber(s,s.live,p.id,i)&&integer(p.number,1,23)&&p.group===(player.fam<=3?'forwards':'backs'),'participant');seen.add(p.id);
   }
   const sh=s.live.sheets[s.live.userSide];
   check(equal(r.participants.slice(0,15).map(p=>p.id),sh.initial)&&r.participants.every(p=>[...sh.initial,...sh.bench,...sh.used||[]].includes(p.id)),'feuille initiale');
   if(sh.nominated)check(equal(r.participants.map(p=>p.id),sh.nominated),'joueurs nominés');
   let open=false;
   for(let i=0;i<r.phases.length;i++){
    const p=r.phases[i];
    check(keys(p,['phase','context','decision','closed','status'])&&p.phase===phases[i]&&typeof p.closed==='boolean'&&!open,'ordre des phases');
    validatePhaseContext(p.context,p.phase,r.context);
    check(p.closed?['decided','skipped','delegated'].includes(p.status):p.status===null,'statut de phase');
    if(!p.closed)open=true;
    const offered=options(r.key,p);check(offered.length===6&&new Set(offered.map(o=>o.id)).size===6,'six déclarations');
    if(p.decision!==null){
     const d=p.decision,choice=offered.find(o=>o.id===d.choiceId);
     check(keys(d,['choiceId','text','tone','toneLabel','intent','audience','playerIds','reactions','moraleBefore','moraleAfter','moraleDelta','par'])&&choice&&d.text===choice.text&&d.tone===choice.tone&&d.toneLabel===choice.toneLabel&&d.intent===choice.intent&&['manager','staff'].includes(d.par),'déclaration enregistrée');
     const ids=audienceIds(r,d.audience,d.playerIds);
     check(equal(ids,d.playerIds)&&Array.isArray(d.reactions)&&d.reactions.length===ids.length&&d.reactions.every((x,i)=>reactionValide(x,ids[i]))&&number(d.moraleBefore,0,100)&&number(d.moraleAfter,0,100)&&number(d.moraleDelta,-2,2),'réactions enregistrées');
     check(d.moraleDelta===d.moraleAfter-d.moraleBefore&&(d.audience!=='players'||d.moraleDelta===0),'effet borné');
    }
    check(!p.closed||(p.status==='skipped'?!p.decision:p.status==='decided'?p.decision?.par==='manager':!p.decision||p.decision.par==='staff'),'décision ou passage');
    const receipt=st.receipts.find(x=>x.key===r.key&&x.phase===p.phase);
    check(p.closed?receipt&&equal(receipt.context,r.context)&&receipt.status===p.status&&equal(receipt.phaseContext,p.context)&&receipt.choiceId===(p.decision?.choiceId??null)&&receipt.audience===(p.decision?.audience??null)&&equal(receipt.playerIds,p.decision?.playerIds||[])&&receipt.moraleDelta===(p.decision?.moraleDelta??0):!receipt,'reçu atomique');
    check(p.context.venue===phaseContext(s,s.live,p.phase).venue&&p.context.score.every((score,side)=>score<=s.live.score[side]),'faits archivés de phase');
   }
   const p=pending(r);
   if(p)check(equal(p.context,phaseContext(s,s.live,p.phase)),'contexte réel de la phase');
   if(p?.phase==='pre')check(s.live.minute===0&&!s.live.finished&&s.live.paused,'pause avant-match');
   if(p?.phase==='half')check(atHalftime(s.live)&&!s.live.finished&&s.live.paused,'vraie mi-temps');
   if(p?.phase==='post')check(s.live.finished,'fin réelle');
   if(s.live.flow?.period===2)check(r.phases.some(x=>x.phase==='half'&&x.closed),'seconde période sans clôture de mi-temps');
   if(s.live.finished)check(r.phases.some(x=>x.phase==='post'),'débrief manquant');
   return true;
  }
  function project(){
   const st=S?.contextualMatch,r=st?.current,p=r&&matches(S,r)?pending(r):null;
   return {scene:p?{key:r.key,phase:p.phase,context:{...copy(r.context),...copy(p.context)},participants:copy(r.participants),options:options(r.key,p),decision:copy(p.decision)}:null,receipts:copy(st?.receipts||[])};
  }
  function decide(r,p,choice,audience,ids,par){
   const feedback=reactions(S,r,ids,choice.tone,p.phase,p.context);
   const effect=appliquerCauserie(p.phase,choice.tone,feedback,audience==='players');
   const before=S.morale,after=clamp(before+effect,0,100);
   p.decision={choiceId:choice.id,text:choice.text,tone:choice.tone,toneLabel:choice.toneLabel,intent:choice.intent,audience,playerIds:ids,reactions:feedback,moraleBefore:before,moraleAfter:after,moraleDelta:after-before,par};
   S.morale=after;
   // Causerie exigeante d'un favori : pas de jour sans pour ce match (complaisance, tactical-plans.js).
   if(p.phase==='pre'&&typeof RELACHEMENT!=='undefined'&&RELACHEMENT.intentions.includes(choice.intent)&&S.live){S.live.relachementAnnule=S.live.relachementAnnule||[false,false];S.live.relachementAnnule[S.live.userSide]=true;}
  }
  function close(r,p,status){
   p.closed=true;p.status=p.decision?(p.decision.par==='staff'?'delegated':'decided'):status;
   S.contextualMatch.receipts.push({key:r.key,phase:p.phase,context:copy(r.context),phaseContext:copy(p.context),status:p.status,choiceId:p.decision?.choiceId??null,audience:p.decision?.audience??null,playerIds:copy(p.decision?.playerIds||[]),moraleDelta:p.decision?.moraleDelta??0});
   S.contextualMatch.receipts=S.contextualMatch.receipts.slice(-48);
  }
  // Le vestiaire adverse parle au même moment (match-pilotage.js) : ton choisi par son staff, état de ses joueurs.
  const adverse=(l,phase,context,key)=>{if(typeof causerieAdverse==='function')causerieAdverse(l,phase,context,key);};
  function observe(command){
   if(!S)return;
   let st=S.contextualMatch,r=st?.current,l=S.live;
   if(command==='begin_match'&&l&&l.userSide>=0&&l.pair[l.userSide]===S.club&&l.minute===0&&!l.finished&&!r){
    st=S.contextualMatch=st||{version:1,current:null,receipts:[]};
    const context=identity(S,l),key=matchKey(context);
    check(!st.receipts.some(x=>x.key===key),'rencontre déjà traitée');
    // Le pronostic lit le Niveau calculé (niveauMatch), donc les qualités détaillées. Un joueur de complément sans
    // qualités (youth-…) n'en reçoit qu'en fin de commande (nativeAttributeStore.complete) : le pronostic figé ici
    // différait alors de celui recalculé à la validation. Les qualités des deux feuilles sont donc posées avant.
    if(typeof nativeAttributeStore!=='undefined')nativeAttributeStore.complete(S,null,true);
    r=st.current={key,context,participants:initialParticipants(S,l),phases:[{phase:'pre',context:phaseContext(S,l,'pre'),decision:null,closed:false,status:null}]};l.paused=true;
    adverse(l,'pre',r.phases[0].context,key);
   }
   if(!r)return;
   if(!l){check(r.phases.some(p=>p.phase==='post'&&p.closed),'rencontre disparue avant clôture');st.current=null;return;}
   check(matches(S,r),'contexte actif périmé');
   let p=pending(r);
   if(!p&&atHalftime(l)&&!r.phases.some(x=>x.phase==='half')){p={phase:'half',context:phaseContext(S,l,'half'),decision:null,closed:false,status:null};r.phases.push(p);l.paused=true;adverse(l,'half',p.context,r.key);}
   if(!p&&l.finished&&!r.phases.some(x=>x.phase==='post')){
    check(r.phases.some(x=>x.phase==='half'&&x.closed),'mi-temps non traitée');p={phase:'post',context:phaseContext(S,l,'post'),decision:null,closed:false,status:null};r.phases.push(p);
   }
   if(p&&delegating){
    // Match confié au staff : il choisit lui-même le ton, plus ou moins juste selon sa compétence.
    if(typeof tonDuStaff==='function'&&!p.decision){
     const offered=options(r.key,p),ids=r.participants.map(x=>x.id),people=new Map(roster(S,r).map(x=>[x.id,x]));
     const tone=tonDuStaff(ids.map(id=>people.get(id)),p.phase,p.context,r.key,offered.map(o=>o.tone));
     const choice=offered.find(o=>o.tone===tone);
     if(choice)decide(r,p,choice,'group',ids,'staff');
    }
    close(r,p,'delegated');
   }
  }
  function guard(command,payload={}){
   const r=S?.contextualMatch?.current,p=r&&matches(S,r)?pending(r):null;
   if(!p||delegating)return;
   if((p.phase==='pre'||p.phase==='half')&&(command==='tick'||command==='pause'&&payload.paused===false))throw Error('Termine ou passe la causerie avant de reprendre le match.');
   if(command==='finish_round')throw Error('Termine ou passe le débrief avant de valider la journée.');
  }
  function execute(command,payload){
   check(!!S,'carrière absente');validate(S);
   const fields=command==='match_talk_decide'?['key','phase','choiceId','audience','playerIds']:command==='match_talk_continue'?['key','phase','skip']:null;
   check(fields&&keys(payload,fields),'commande ou champs inconnus');
   const r=S.contextualMatch?.current,p=r&&matches(S,r)?pending(r):null;
   check(p&&payload.key===r.key&&payload.phase===p.phase,'phase périmée');
   if(command==='match_talk_decide'){
    check(!p.decision,'parole déjà prononcée');
    const choice=options(r.key,p).find(o=>o.id===payload.choiceId);check(!!choice,'déclaration non proposée');
    decide(r,p,choice,payload.audience,audienceIds(r,payload.audience,payload.playerIds),'manager');
   }else{
    check(payload.skip===undefined||typeof payload.skip==='boolean','passage invalide');check(p.decision||payload.skip===true,'confirme une déclaration ou passe explicitement');
    close(r,p,'skipped');
    if(p.phase==='post'){
     check(S.live.finished,'match non terminé');
     if(typeof nativeConfirmMatchResult==='function')check(nativeConfirmMatchResult(),'confirmation du résultat refusée');
     else{finishRound();check(!S.live,'validation de journée refusée');}
     S.contextualMatch.current=null;
    }
    else{if(p.phase==='half')check(atHalftime(S.live),'mi-temps périmée');continueMatch();}
   }
   validate(S);return {matchTalkDecision:{key:r.key,phase:p.phase,command}};
  }
  function installHooks(){
   if(installed)return true;installed=true;
   // Public tick is guarded by the worker. A batch that reaches a new scene
   // must finish successfully at that boundary; its remaining internal ticks
   // are inert rather than rolling back the whole batch.
   const oldTick=tick;tick=function(){observe('tick');if(!delegating&&pending(S?.contextualMatch?.current))return;const result=oldTick.apply(this,arguments);observe('tick');return result;};
   const oldContinue=continueMatch;continueMatch=function(){observe('pause');guard('pause',{paused:false});const result=oldContinue.apply(this,arguments);observe('pause');return result;};
   return true;
  }
  function setDelegating(value){check(typeof value==='boolean','délégation');delegating=value;}
  function clearTransient(){delegating=false;}
  return {project,execute,validate,installHooks,observe,setDelegating,clearTransient,guard};
 }
};
