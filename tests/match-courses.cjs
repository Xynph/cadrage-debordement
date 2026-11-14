'use strict';
// Découpage des longues courses du moteur (docs/match-courses-20261112.md) : présentation seule.
// Avec et sans découpage, mêmes tirages, même score, mêmes essais, mêmes statistiques et feuilles
// de match ; le journal découpé contient l'ancien journal, plus des faits `carry` écrits avant
// l'essai (ou le ballon tenu / échappé dans l'en-but), avec le score d'avant, des porteurs de
// l'équipe en jeu et des positions qui avancent vers la ligne.
const test=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./harness.cjs');

function jouer(k,decoupe){
 const {run}=context();if(!decoupe)run('MATCH_COURSES_DECOUPEES=false');
 run(`for (let i = 0; i < ${k*7919}; i++) Math.random(); start(${k%10}); beginMatch(); continueMatch();`);
 for(let i=0;i<3000&&!run('S.live.finished');i++)run('if (S.live.paused) continueMatch(); presentationTick(S.live);');
 assert.ok(run('S.live.finished'),'match terminé');
 return JSON.parse(run('JSON.stringify({ev:S.live.events,score:S.live.score,tries:S.live.tries,stats:S.live.stats,tac:S.live.tacticalStats,sheets:S.live.sheets,suite:Math.random()})'));
}
const but=equipe=>equipe===0?100:0;

test('Courses découpées : issue, tirages et statistiques inchangés ; journal = ancien journal + temps de jeu avant l’essai',()=>{
 let ajoutes=0,essaisLongs=0,essaisCourts=0;
 for(const k of [0,1,2,3,5,8]){
  const avant=jouer(k,false),apres=jouer(k,true);
  for(const f of ['score','tries','stats','tac','sheets','suite'])assert.deepEqual(apres[f],avant[f],`match ${k} : ${f} identique`);
  let j=0;
  for(const e of avant.ev){
   const inseres=[];
   while(j<apres.ev.length&&apres.ev[j].text!==e.text)inseres.push(apres.ev[j++]);
   assert.ok(j<apres.ev.length,`match ${k} : fait ancien retrouvé (${e.text})`);
   const f=apres.ev[j++];
   if(inseres.length){
    ajoutes+=inseres.length;
    assert.ok(['try','ingoal'].includes(f.scene?.kind),`match ${k} : temps de jeu ajoutés seulement avant un essai ou un en-but (${f.text})`);
   }
   for(const s of inseres){
    assert.equal(s.scene.kind,'carry');assert.equal(s.min,f.min,'même minute que le fait final');
    assert.equal(s.scene.team,f.scene.team);const avantEssai=[...f.scene.score];if(f.scene.kind==='try')avantEssai[f.scene.team]-=5+(f.scene.conversion?2:0);
    assert.deepEqual(s.scene.score,avantEssai,'score d’avant l’essai');
    assert.ok(s.scene.on[s.scene.team].includes(s.scene.actor),'porteur en jeu');
   }
   if(f.scene?.kind==='try'&&f.scene.origin==='open'){
    // Chaîne continue : chaque temps de jeu part où le précédent s'arrête, vers la ligne, et l'essai part du dernier.
    const T=f.scene.team,sens=T===0?1:-1;let x=e.scene.from.x;
    for(const s of inseres){assert.equal(s.scene.from.x,x);assert.ok((s.scene.to.x-x)*sens>0,'avance vers la ligne');x=s.scene.to.x}
    assert.equal(f.scene.from.x,x,'l’essai part du dernier temps de jeu');
    assert.deepEqual(f.scene.to,e.scene.to);assert.equal(f.scene.actor,e.scene.actor,'même marqueur');
    // Un essai de pénalité jouée vite (matchflow.js, sans découpage ni temps de jeu inséré) n'est pas une course découpée.
    if(inseres.length&&Math.abs(but(T)-e.scene.from.x)>=20){essaisLongs++;assert.ok(Math.abs(but(T)-f.scene.from.x)<=10,'essai long : la dernière course part à 10 m ou moins')}
    else essaisCourts++;
    if(inseres.length>1)assert.ok(inseres.slice(1).every(s=>s.scene.actor!==f.scene.actor),'les soutiens ne sont pas le marqueur');
   }
  }
  assert.equal(j,apres.ev.length,`match ${k} : rien d'ajouté après le dernier fait ancien`);
 }
 assert.ok(ajoutes>20&&essaisLongs>5,`découpage exercé (${ajoutes} faits ajoutés, ${essaisLongs} essais longs, ${essaisCourts} courts)`);
});
