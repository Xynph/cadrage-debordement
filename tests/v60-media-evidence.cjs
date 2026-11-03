'use strict';const assert=require('node:assert/strict');
const api=require('../dist/media-evidence-v60.js');
const saved={version:2,season:4,round:12,mediaEvents:[
{id:'match-41',kind:'result',title:'Victoire à domicile',detail:'Score confirmé par la simulation',season:4,week:11},
{id:'injury-8',kind:'injury',title:'Indisponibilité au poste de pilier',detail:'Blessure enregistrée par le moteur',season:4,week:12},
{id:'future',kind:'transfer',title:'Transfert futur',detail:'Ne pas afficher avant sa date',season:4,week:18}]};
const before=JSON.stringify(saved);
const got=api.curate(saved.mediaEvents,{season:4,week:12});assert.equal(got.length,2);
assert.equal(api.special(saved.mediaEvents,{season:4,week:12}).articles.length,2);
assert.ok(!api.html(saved.mediaEvents,{season:4,week:12}).includes('Transfert futur'));
assert.ok(api.html([],{season:4,week:12}).includes('Aucune information sportive vérifiée'));
assert.equal(JSON.stringify(saved),before,'no mutation of historic saves');
assert.ok(!api.validEvent({kind:'result',id:'bad'}));
console.log('PASS V60 verified events: dates, invalid records, specials, legacy save no mutation');