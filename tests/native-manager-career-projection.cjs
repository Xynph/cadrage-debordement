'use strict';
const assert=require('node:assert/strict');const {context}=require('./harness.cjs');const domain=require('../native/engine/manager-career.cjs');
const g=context();g.run('start(0)');g.run('const managerCareerController=('+domain.factory.toString()+')()');
g.run('delete S.market[0].dev');const before=g.run('JSON.stringify(S)');g.run('managerCareerController.project()');assert.ok(g.run('JSON.stringify(S)')===before,'Les devis ne doivent pas installer le développement d’un candidat en lecture');
console.log('PASS manager projection pure avec candidat historique sans développement');
g.run('S.franceMode={week:27}');const week27=JSON.parse(g.run('JSON.stringify(managerCareerController.project())'));assert.equal(week27.plan[0].payments,7);assert.equal(week27.plan[1].payments,34);for(const p of week27.recruitment)for(const t of p.terms)assert.equal(t.payments,7+(t.years-1)*34);
g.run('S.phase="ended";S.franceMode.week=34');const ended=JSON.parse(g.run('JSON.stringify(managerCareerController.project())'));assert.equal(ended.plan[0].payments,0);for(const p of ended.recruitment)for(const t of p.terms)assert.equal(t.payments,t.years*34);
console.log('PASS engagements natifs : semaine27→34, trois saisons et intersaison sur calendrier34');

g.run('delete S.franceMode; S.phase="league"; S.round=0; S.season=2; S.economy.week=31');
const season2=JSON.parse(g.run('JSON.stringify(managerCareerController.project())'));
assert.equal(season2.context.week,0,'Le contexte historique repart à zéro avec la saison.');
assert.equal(season2.plan[0].payments,29,'Les engagements historiques repartent sur29semaines.');
for(const p of season2.recruitment)for(const t of p.terms){assert.equal(t.payments,t.years*29);assert.ok(t.knownCommitment>=0);}
console.log('PASS calendrier historique saison2 : engagements et devis positifs.');

