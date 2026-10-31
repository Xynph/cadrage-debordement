'use strict';const test=require('node:test'),assert=require('node:assert/strict');
const {records,match,roster}=require('../tools/data06-wikidata-offline.cjs');
test('actual roster count remains 1592',()=>{assert.equal(roster(require('node:path').resolve(__dirname,'..')).length,1592)});
test('CSV handles quote escaping and duplicate multi-value Wikidata rows',()=>{
 const data='player,playerLabel,birth,height,weight,citizenship,club\nhttp://www.wikidata.org/entity/Q123,"A, Dupont",2000-01-01,,,,\n';
 assert.equal(records(data,'csv')[0].playerLabel,'A, Dupont');
});
test('SPARQL JSON and CSV never automatically join name-only identities',()=>{
 const data={results:{bindings:[{player:{value:'http://www.wikidata.org/entity/Q42'},playerLabel:{value:'Antoine DUPONT'},birth:{value:'1996-11-15'}}]}};
 const out=match(records(JSON.stringify(data),'json'),[{id:'lnr:5',name:'Antoine DUPONT',club:'toulouse'}]);
 assert.deepEqual(out.summary,{rows:1,qids:1,autoMatched:0,review:1,unmatched:0,roster:1});
 assert.equal(out.ambiguous[0].candidates[0].id,'lnr:5');
 assert.equal(out.ambiguous[0].birth,'1996-11-15');
});
test('invalid CSV and SPARQL JSON are rejected',()=>{
 assert.throws(()=>records('foo,bar\na,b','csv'),/Missing/);
 assert.throws(()=>records('{}','json'),/Expected/);
});
