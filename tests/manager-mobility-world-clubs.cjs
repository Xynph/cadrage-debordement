'use strict';
// Carrière Monde (world-champ, 116 clubs) : « Activer les candidatures » doit marcher pour un club d'indice > 55.
// Le contrôle de sauvegarde bornait les clubs à 55 (ancien monde à 56 clubs) : l'activation échouait en
// « données de carrière incohérentes ». Les bornes viennent désormais du vrai nombre de clubs de la partie.
const {test,after}=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./monde-harness.cjs');
const h=context(827381,{club:102});
after(()=>h.close());
const base=h.checkpoint();

test('Monde : activer les candidatures depuis le club 102',()=>{
 h.restore(base);
 assert.ok(h.run('S.clubs.length')>102,'carrière Monde à plus de 102 clubs');
 assert.equal(h.run('S.club'),102);
 assert.equal(h.run('managerMobilityEnable()'),true,'activation acceptée');
 assert.equal(h.run('managerMobilityActive()'),true);
 assert.equal(h.run('S.managerMobility.originClub'),102);
 assert.doesNotThrow(()=>h.run('validateCareer(S)'));
 const view=h.run("nativeSystems.domain('managerCareer').project()");
 assert.equal(view.active,true,'onglet Mobilité : candidatures ouvertes');
 assert.equal(view.originClub,102);
});

test('Monde : candidature, archives et parcours vers un club > 55 restent valides',()=>{
 h.restore(base);
 h.run('managerMobilityEnable()');
 const n=h.run('S.clubs.length');
 // Fin de saison simulée : candidatures vers les clubs au-delà de l'ancienne borne.
 h.run(`S.managerMobility.applications=[60,90,${n-1}].filter(id=>id!==S.club).map(id=>({id:'job-'+S.season+'-'+id,season:S.season,fromClub:S.club,clubId:id,status:'rejected',reason:'stable',reputation:50,risk:10,affinity:50,coachChanges:0}))`);
 assert.doesNotThrow(()=>h.run('validateManagerMobility(S)'));
 // Hors bornes : un club inexistant reste refusé.
 h.run(`S.managerMobility.applications.push({id:'job-'+S.season+'-${n}',season:S.season,fromClub:S.club,clubId:${n},status:'rejected',reason:'stable',reputation:50,risk:10,affinity:50,coachChanges:0})`);
 assert.throws(()=>h.run('validateManagerMobility(S)'),/incohérentes/);
});

test('Monde : la décision de candidature couvre tous les clubs du championnat',()=>{
 h.restore(base);
 h.run('managerMobilityEnable()');
 h.run("S.phase='ended'");
 const decided=h.run("S.clubs.filter(c=>c.id!==S.club&&CDWorldCareer.leagueId(S,c.id)!=='guest').filter(c=>c.id>55).map(c=>managerMobilityDecision(c.id)).filter(Boolean).length");
 const eligible=h.run("S.clubs.filter(c=>c.id!==S.club&&c.id>55&&CDWorldCareer.leagueId(S,c.id)!=='guest').length");
 assert.ok(eligible>0);
 assert.equal(decided,eligible,'chaque club > 55 reçoit une décision');
 assert.equal(h.run('managerMobilityDecision(S.clubs.length)'),null);
});
