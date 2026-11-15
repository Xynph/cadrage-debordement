'use strict';
// La recette physique peut différer la matérialisation des sauvegardes comme le worker,
// tout en exposant exactement le dernier état dès qu'un consommateur le lit.
const assert=require('node:assert/strict'),{context,matchContext}=require('./harness.cjs');
const probe=context();
try{assert.equal(typeof probe.deferSaves,'function','Accès à l’écriture différée réelle du worker requis.');}finally{probe.close();}
function play(defer){
 const h=matchContext(0,827381,{deferSaves:false});
 try{
  let materializations=0;const save=h.ctx.save;
  h.ctx.save=()=>{materializations++;return save();};
  if(defer)h.deferSaves();
  h.run('beginMatch();continueMatch()');
  let steps=0;
  for(;steps<4000&&!h.run('S.live.finished');steps++)h.run('if(S.live.paused)continueMatch();presentationTick(S.live)');
  assert.equal(h.run('S.live.finished'),true,'Le vrai match doit arriver à son terme.');
  const state=h.run('JSON.stringify(S)'),saved=h.store['bdt-v1'];
  assert.ok(saved===state,'La lecture du store doit exposer l’état complet courant.');
  return {state,saved,seed:h.seed(),steps,materializations};
 }finally{h.close();}
}
const eager=play(false),deferred=play(true);
assert.ok(eager.state===deferred.state,'Mêmes faits, score, joueurs et état de carrière.');
assert.ok(eager.saved===deferred.saved,'Même texte de sauvegarde.');
assert.equal(deferred.seed,eager.seed,'Même curseur RNG.');
assert.equal(deferred.steps,eager.steps,'Même progression du match.');
assert.ok(deferred.materializations<eager.materializations,'La sérialisation évitée doit être réelle.');
console.log(JSON.stringify({passed:true,steps:eager.steps,eagerWrites:eager.materializations,deferredWrites:deferred.materializations}));
