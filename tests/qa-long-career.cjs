'use strict';
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {Campaign, auditState, checkpointToRemove, parseArgs} = require('../scripts/qa-long-career.cjs');
const {render} = require('../scripts/qa-long-career-report.cjs');
const state = () => ({season:1, round:4, clubs:[{cash:-1000, players:[{id:'a', salary:3000}]},{cash:100, players:[{id:'b', salary:500}]}], history:[{fixtureId:'f1'}]});
const campaign = () => new Campaign('club','Club','Worker');

test('les contrôles détectent doublons joueurs/résultats, argent non fini et retour de journée', () => {
 assert.doesNotThrow(() => auditState(campaign(), state(), {season:1, round:3}));
 let broken = state(); broken.clubs[1].players[0].id='a';
 assert.throws(() => auditState(campaign(), broken), /Identifiants professionnels/);
 broken = state(); broken.history.push({fixtureId:'f1'});
 assert.throws(() => auditState(campaign(), broken), /Résultats de rencontre/);
 broken = state(); broken.clubs[0].cash=Infinity;
 assert.throws(() => auditState(campaign(), broken), /Trésoreries/);
 assert.throws(() => auditState(campaign(), state(), {season:2, round:0}), /Progression monotone/);
});

test('le rapport garde une campagne rouge et échappe les données et diagnostics', () => {
 const report = {status:'failed', seed:1, source:{commit:'abc', dirty:false, node:'22', platform:'linux'}, durationMs:1000, command:'<img src=x onerror=alert(1)>', profileRoot:'/tmp/example', limits:['Pas de certification'], campaigns:[{id:'club', name:'<script>alert(1)</script>', scope:'Worker', status:'failed', checks:12, durationMs:1000, checkpoints:[{label:'Saison 1', date:null, season:1, players:12, results:4, mail:0, sha256:'a'.repeat(64), bytes:1000}], failures:[{check:'Doublon', message:'<img src=x onerror=alert(1)>', nextAction:'Rejouer'}]}]};
 const html = render(report);
 assert.match(html, /La réception reste incomplète/);
 assert.match(html, /href="#club-failure-0"/);
 assert.match(html, /id="club-failure-0"/);
 assert.doesNotMatch(html, /<script>|<img/);
 assert.match(html, /&lt;script&gt;/);
 assert.match(html, /12<small>contrôles exécutés/);
});

test('le CLI borne graines et durées de campagne demandées', () => {
 assert.deepEqual(parseArgs([]), {seed:713492,seasons:3,throughYear:2031,campaign:'all'});
 assert.equal(parseArgs(['--seed','4294967295','--seasons','5']).seed, 4294967295);
 for (const args of [['--seed','4294967296'],['--seed','-1'],['--seasons','999'],['--through-year','2050'],['--campaign','inconnu'],['--output']]) assert.throws(() => parseArgs(args), /Argument invalide/);
});

test('le quota de sécurité est respecté et seul le plus ancien checkpoint QA est proposé', () => {
 const safety = {entries:[{id:'new',createdAt:'2026-11-10'},{id:'old',createdAt:'2026-11-09'}],usedBytes:100,maxEntries:2,maxBytes:1000,error:''};
 assert.equal(checkpointToRemove(safety, 10).id, 'old');
 assert.equal(checkpointToRemove({...safety,maxEntries:3}, 10), null);
 assert.equal(checkpointToRemove({...safety,maxEntries:3}, 950).id, 'old');
 assert.equal(checkpointToRemove(undefined, 10), null);
 assert.throws(() => checkpointToRemove({...safety,error:'copie corrompue'},10), /illisibles/);
 assert.throws(() => checkpointToRemove({...safety,entries:[],maxEntries:0},10), /capacité/);
});
