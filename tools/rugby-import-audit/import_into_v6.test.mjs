import test from 'node:test';
import assert from 'node:assert/strict';
import {integrate} from './import_into_v6.mjs';

const db={schema:'rugby-master-sports-v6',players:[{id:'lnr:1',realName:'Karl Martin',club:'aurillac',league:'prod2',performance2025_2026:null}]};
const mapping={clubAliases:[
 {competition:'TOP 14',season:'2025-2026',source:'Stade Toulousain',clubId:'toulouse',evidenceUrl:'https://rugbydata.fr/statistics/panel/51'},
 {competition:'PRO D2',season:'2024-2025',source:'Stade Aurillacois',clubId:'aurillac',evidenceUrl:'https://example.org'}
],verifiedMembership:[{playerId:'lnr:1',clubId:'aurillac',season:'2024-2025',evidenceUrl:'https://example.org'}]};
const club={competition:'TOP 14',season:'2025-2026',phase:'Phase régulière',type:'Club',category:'Attaque',indicator:'Points marqués',subject:'Stade Toulousain',raw_value:'981',unit:'Points',source_url:'https://rugbydata.fr/statistics/panel/51'};
const player={competition:'PRO D2',season:'2024-2025',phase:'Régulière',type:'Joueur',category:null,indicator:'Feuilles de match',subject:'Karl Martin',club:'Stade Aurillacois',raw_value:'25',unit:'feuilles',source_scope:'Bilan J30 hors barrage',source_url:'https://example.org'};
async function* input(x){yield* x}
test('deux championnats, source, granularité et idempotence',async()=>{
 const a=await integrate(db,input([club,player]),mapping);assert.equal(a.report.added,2);
 assert.equal(a.db.players[0].performance2025_2026,null);
 assert.equal(a.db.rugbyDataObservations[1].indicator,'Feuilles de match');
 const b=await integrate(a.db,input([club,player]),mapping);assert.equal(b.report.added,0);
 assert.equal(b.report.already_present,2);assert.deepEqual(a.db,b.db);
});
test('conflit non écrasé',async()=>{
 const a=await integrate(db,input([club,{...club,raw_value:'982'}]),mapping);
 assert.equal(a.report.conflicts,1);assert.equal(a.db.rugbyDataObservations[0].value,981);
});
test('homonymes bloqués',async()=>{
 const d={...db,players:[db.players[0],{...db.players[0],id:'lnr:2'}]};
 const a=await integrate(d,input([player]),mapping);assert.equal(a.report.added,0);assert.equal(a.report.reasons.homonym,1);
});
test('catégorie ambiguë bloquée',async()=>{
 const a=await integrate(db,input([{...club,category:'Aperçu général'}]),mapping);assert.equal(a.report.added,0);assert.equal(a.report.reasons.ambiguous_category,1);
});
test('zéro réel distinct du manquant',async()=>{
 const a=await integrate(db,input([{...club,raw_value:'0'},{...club,raw_value:''}]),mapping);
 assert.equal(a.report.added,1);assert.equal(a.report.pending,1);assert.equal(a.db.rugbyDataObservations[0].value,0);
});
test('affiliation source nécessaire',async()=>{
 await assert.rejects(()=>integrate(db,input([player]),{...mapping,verifiedMembership:[{...mapping.verifiedMembership[0],evidenceUrl:null}]}),/Affiliation/);
});
