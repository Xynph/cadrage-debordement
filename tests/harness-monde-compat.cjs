'use strict';
const assert=require('node:assert/strict'),{context}=require('./harness.cjs');
const native=require('./monde-harness.cjs').context(827381,{club:null});
try{
 native.ctx.makePlayer=()=>{throw Error('Ancienne fabrique atteinte avant le refus');};
 assert.throws(()=>native.run('start(0,"fiction")'),/uniquement.*Monde/);
 assert.equal(native.run('S'),null,'Le refus précède toute création.');
}finally{native.close();}
const h=context();
try{
 assert.equal(typeof h.start,'function','Le harnais commun doit exposer le vrai démarrage Monde avant toute création.');
 h.run('start(0)');
 assert.equal(h.run('S.worldMode.version'),5);
 assert.equal(h.run('S.clubs.length'),116);
 assert.equal(h.run('S.franceMode??null'),null);
 const before=h.run('JSON.stringify(S)'),seed=h.seed();
 for(const mode of ['fiction','lnr','france','common','custom']){
  h.ctx.refusedMode=mode;
  assert.throws(()=>h.run('start(0,refusedMode)'),/Monde/);
  assert.equal(h.run('JSON.stringify(S)'),before,'refus sans mutation');
  assert.equal(h.seed(),seed,'refus sans tirage');
 }
 h.run('view="dashboard";entryScreen="game";render()');
 assert.ok(h.app.innerHTML.length>100,'Les contrôles HTML restent utilisables.');
 console.log('Harnais commun : carrière Monde complète, refus atomiques, rendu HTML préservé.');
}finally{h.close?.();}
