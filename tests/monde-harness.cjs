'use strict';
// Harnais VM de la carrière Monde (world-champ, 116 clubs) : remplace tests/france-harness.cjs.
// Même API que l'ancien harnais (context(seed) → {ctx,run,store,prepareNativeProjection,seed,state}),
// mais la VM est celle du vrai moteur natif (dist + modules natifs, createBridge) et la carrière est
// créée par la commande new_career du worker (mode world-champ, seul mode de jeu).
// Ajouts : h.start(club) recrée une carrière, h.week(n) avance de n semaines sans projection ni écriture
// disque, en appliquant les mêmes observations que le worker après chaque semaine ; h.toMatch() avance
// jusqu'à la prochaine semaine où le club joue.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path');
const {createBridge,CORE_FILES}=require('../native/engine/worker.cjs');
const NOW=1700000000000;
const live=new Set();
process.on('exit',()=>{for(const h of live)h.close();});
function context(seed=827381,options={}){
 const dataDir=fs.mkdtempSync(path.join(os.tmpdir(),'cd-monde-harness-'));
 const bridge=createBridge({dataDir,seed:seed>>>0,now:options.now??NOW,testVm:true,...(options.bridge||{})});
 const vm=bridge.vm,ctx=vm.ctx;
 if(options.console!==false)ctx.console=console;
 const run=(source,timeout)=>vm.run(source,timeout);
 const seededRandom=ctx.Math.random; // un cas qui remplace Math.random est réparé par restore()
 let requests=0,closed=false;
 function command(name,payload={}){
  const r=bridge.handle({id:++requests,command:name,payload});
  if(!r.ok)throw Error(name+' : '+r.error);
  return r.model;
 }
 // Rendez-vous obligatoires du club (presse, médical, direction) : ils bloquent la progression dans le jeu,
 // où le joueur les traite en Réception. Le harnais les coupe par défaut (options.meetings !== true) pour
 // que l'avance rapide et les matchs ne dépendent pas de décisions de gestion ; leurs suites dédiées
 // passent par le worker.
 const meetings=options.meetings===true;
 function start(club=0,extra={}){command('new_career',{mode:'world-champ',club,...extra});if(!meetings)run('delete S.clubMeetings;validateCareer(S)');return h;}
 // Avance rapide : finishRound() du moteur (journée complète, match du club compris), puis les
 // observations du worker (presse, rendez-vous, connaissance, profondeur pro, attributs).
 function week(n=1,{validate=true}={}){
  for(let i=0;i<n;i++){
   if(run("S.phase==='ended'"))break;
   run(`{const pressBefore=nativeSystems.domain('press').context(S),knowledgeBefore=nativeKnowledge.before(S),attributes=nativeAttributeStore.before(S,false);
    finishRound();
    nativeSystems.domain('press').observeInvitation(pressBefore,false);
    nativeKnowledge.observe(S,knowledgeBefore,'finish_round',{},{observedPlayerIds:[]});
    nativeSystems.domain('matchTalks').observe('finish_round');nativeSystems.domain('sceneInvitations').observe('finish_round');${meetings?"nativeSystems.domain('clubMeetings').observe('finish_round',{});":''}
    budgetAvantProfondeur();nativeProfessionalDepth.fill(S);budgetProfondeur();nativeAttributeStore.complete(S,attributes,false);}`);
   if(validate)run('validateCareer(S)');
  }
  return h;
 }
 // Avance jusqu'à la prochaine semaine où le club joue (le calendrier Monde a des semaines sans match).
 function toMatch(max=46){for(let i=0;i<max&&!run('!!nextMatch()');i++)week(1);if(!run('!!nextMatch()'))throw Error('Aucun match du club à venir.');return h;}
 function season({validate=false}={}){let guard=0;while(run("S.phase!=='ended'")){if(++guard>80)throw Error('Saison Monde sans fin.');week(1,{validate});}return h;}
 // Point de reprise en mémoire (état et curseur RNG) : plusieurs cas d'une suite partagent une carrière.
 function checkpoint(){return {text:run('JSON.stringify(S)'),seed:vm.seed()};}
 function restore(cp){ctx.Math.random=seededRandom;ctx.harnessCheckpoint=cp.text;run('S=JSON.parse(harnessCheckpoint);delete globalThis.harnessCheckpoint');vm.setSeed(cp.seed);return h;}
 function close(){if(closed)return;closed=true;live.delete(h);try{bridge.close();}finally{fs.rmSync(dataDir,{recursive:true,force:true});}}
 const h={ctx,run,command,start,week,toMatch,season,checkpoint,restore,close,dataDir,
  prepareNativeProjection(){run('nativeAttributeStore.complete(S)');},
  seed:()=>vm.seed(),setSeed:vm.setSeed,
  state:()=>JSON.parse(run('JSON.stringify(S)')),
  get store(){return vm.store();}};
 live.add(h);
 if(options.club!==null)start(options.club??0,options.career||{});
 return h;
}
module.exports={context,CORE_FILES,NOW};
// Exécuté comme suite : vérifie le harnais lui-même (carrière world-champ, avance rapide, sauvegarde, RNG).
if(require.main===module){
 const assert=require('node:assert/strict');
 // Deux carrières successives (jamais deux en mémoire) : même graine, même carrière et même avance.
 const trace=()=>{const h=context(827381,{club:29});try{
  const created=h.run('JSON.stringify(S)'),seed=h.seed(),s=JSON.parse(created);
  assert.equal(s.clubs.length,116,'116 clubs du Monde');assert.equal(s.club,29);
  assert.equal(h.run('CDWorldEditions.forState(S).mode'),'world-champ');
  h.week(3);const advanced=h.state();
  assert.equal(advanced.round,3,'trois semaines avancées');assert.ok(advanced.history.length>0,'résultats de la journée');
  const cp=h.checkpoint();h.week(1);h.restore(cp);assert.equal(h.run('JSON.stringify(S)'),cp.text,'reprise en mémoire');assert.equal(h.seed(),cp.seed);
  h.run('pendingSave=parseSaveDocument(JSON.stringify(createSaveDocument()));if(!confirmSaveImport())throw Error("import");validateCareer(S)');
  assert.equal(h.state().round,3,'export/import natif');
  return {created,seed,advanced:cp.text,rng:cp.seed};
 }finally{h.close();}};
 assert.deepEqual(trace(),trace(),'création et avance rapide déterministes');
 console.log('Harnais Monde : world-champ 116 clubs, avance rapide déterministe, reprise, export/import PASS');
}
