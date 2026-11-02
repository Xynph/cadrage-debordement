import test from 'node:test';
import assert from 'node:assert/strict';
import {validateURL,optionForSeason,argsOf} from './collector.mjs';

test('accept only RugbyData HTTPS statistics competition pages',()=>{
 assert.equal(validateURL('https://www.rugbydata.fr/statistics/competition/1'),'https://www.rugbydata.fr/statistics/competition/1');
 assert.throws(()=>validateURL('http://rugbydata.fr/statistics/competition/1'));
 assert.throws(()=>validateURL('https://other.example/statistics/competition/1'));
 assert.throws(()=>validateURL('https://rugbydata.fr/players'));
});
test('reject when selected season absent or ambiguous',()=>{
 assert.equal(optionForSeason([{text:'2025/2026',value:'x'},{text:'2026/2027',value:'y'}],'2025-2026').value,'x');
 assert.throws(()=>optionForSeason([{text:'2026/2027',value:'y'}],'2025-2026'));
 assert.throws(()=>optionForSeason([{text:'2025/2026',value:'x'},{text:'2025-2026',value:'z'}],'2025-2026'));
});
test('bound collection limits and request delays',()=>{
 assert.equal(argsOf(['--url','https://www.rugbydata.fr/statistics/competition/1','--season','2025-2026','--out','./raw']).limit,300);
 assert.throws(()=>argsOf(['--url','https://www.rugbydata.fr/statistics/competition/1','--season','2025-2026','--out','./raw','--limit','5000']));
 assert.throws(()=>argsOf(['--url','https://www.rugbydata.fr/statistics/competition/1','--season','2025-2026','--out','./raw','--delay','0']));
});
