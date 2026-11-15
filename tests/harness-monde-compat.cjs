'use strict';
const assert=require('node:assert/strict'),{context,engineContext}=require('./harness.cjs');
assert.equal(typeof engineContext,'function','Les recettes du moteur doivent pouvoir utiliser la vraie VM native sans rendu HTML.');
const native=require('./monde-harness.cjs').context(827381,{club:null});
try{
 assert.equal(typeof native.prepareCommands,'function','Initialisation native sans calculer un modèle de menu.');
 const nativeSeed=native.seed();native.prepareCommands();
 assert.equal(typeof native.ctx.nativeClubBudget,'object');
 assert.equal(native.run('S'),null);assert.equal(native.seed(),nativeSeed);
 const originalMakePlayer=native.ctx.makePlayer;
 native.ctx.makePlayer=()=>{throw Error('Ancienne fabrique atteinte avant le refus');};
 assert.throws(()=>native.run('start(0,"fiction")'),/uniquement.*Monde/);
 assert.equal(native.run('S'),null,'Le refus précède toute création.');
 native.ctx.makePlayer=originalMakePlayer;native.start(0);
 assert.ok(native.store['bdt-v1']===native.run('JSON.stringify(S)'),'la fixture modifiée par le harnais est réellement sauvegardée');
 assert.equal(native.run('S.leagueDetail??null'),null,'le harnais natif existant conserve tous les championnats détaillés');
 assert.equal(native.run('S.worldMode.fixtures.every(f=>!CDLeagueDetail.quickFixture(S,f))'),true);
}finally{native.close();}
const engine=engineContext();
try{
 const markup=engine.ctx.document.querySelector('#app').innerHTML;
 engine.start(0);assert.equal(engine.run('S.worldMode.version'),5);
 assert.throws(()=>engine.app,/sans HTML/,'aucun contrôle d’écran autorisé dans la VM moteur');
 const before=engine.run('JSON.stringify(S)');engine.run('render()');
 assert.ok(engine.run('JSON.stringify(S)')===before,'rendu natif sans mutation');
 assert.equal(engine.ctx.document.querySelector('#app').innerHTML,markup,'les fonctions natives n’effectuent aucun rendu HTML');
}finally{engine.close();}
const h=context();
try{
 assert.equal(typeof h.start,'function','Le harnais commun doit exposer le vrai démarrage Monde avant toute création.');
 h.run('start(0)');
 assert.equal(h.run('S.worldMode.version'),5);
 assert.equal(h.run('S.clubs.length'),116);
 assert.deepEqual(JSON.parse(h.run('JSON.stringify(S.leagueDetail?.detailed??[])')),['elite','accession'],'Les recettes françaises gardent les deux championnats français au moteur complet.');
 assert.equal(h.run('S.worldMode.fixtures.filter(f=>["elite","accession"].includes(f.competitionId)).every(f=>!CDLeagueDetail.quickFixture(S,f))'),true,'aucune rencontre française passée au moteur rapide');
 assert.equal(h.run('S.worldMode.fixtures.filter(f=>f.homeId===S.club||f.awayId===S.club).every(f=>!CDLeagueDetail.quickFixture(S,f))'),true,'tous les matchs du manager restent détaillés');
 assert.equal(h.run('S.worldMode.fixtures.filter(f=>!["league","pool"].includes(f.phase)).every(f=>!CDLeagueDetail.quickFixture(S,f))'),true,'phases finales détaillées');
 h.ctx.scopeFixture=JSON.parse(h.run('JSON.stringify(S.worldMode.fixtures.find(f=>f.competitionId==="prem"&&f.phase==="league"))'));
 assert.equal(h.run('CDLeagueDetail.quickFixture(S,scopeFixture)'),true,'le réglage rapide est réellement utilisé hors portée française');
 for(const phase of ['semi','final','barrage','access']){
  h.ctx.scopeFixture.phase=phase;assert.equal(h.run('CDLeagueDetail.quickFixture(S,scopeFixture)'),false,phase+' reste au moteur complet');
 }
 delete h.ctx.scopeFixture;
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
 const resumed=context(h.state());
 try{
  assert.equal(typeof resumed.ctx.nativeClubBudget,'object','La reprise doit brancher le vrai budget natif avant toute recette.');
  resumed.setSeed(h.seed());
  h.run('financeWeek(null,false)');resumed.run('financeWeek(null,false)');
  assert.ok(h.run('JSON.stringify(S)')===resumed.run('JSON.stringify(S)'),'Même semaine financière avant et après reprise Monde.');
  assert.equal(h.seed(),resumed.seed(),'Même curseur RNG après la semaine financière.');
 }finally{resumed.close();}
 console.log('Harnais commun : carrière Monde complète, refus atomiques, rendu HTML préservé.');
}finally{h.close?.();}
