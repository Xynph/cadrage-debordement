'use strict';
const assert=require('node:assert/strict');
const bank=require('../dist/press-question-bank.js');
assert.equal(bank.validate(),true);
assert.equal(bank.topics.length,25);
assert.equal(bank.questions.length,500);
assert.equal(bank.journalists.length,30);
assert.ok(bank.journalists.every(j=>j.name&&j.outlet&&(j.fictional===true||j.source?.startsWith('https://'))));
assert.equal(new Set(bank.journalists.map(j=>j.outlet)).size,10);
assert.equal(bank.journalists.filter(j=>j.fictional).length,20);
assert.ok(bank.journalists.some(j=>j.name==='Nicolas Zanardi'&&j.outlet.includes('Rugbyrama')));
assert.ok(bank.journalists.some(j=>j.name==='Renaud Bourel'&&j.outlet==='L\'Équipe'));
assert.ok(bank.journalists.some(j=>j.name==='Arnaud Beurdeley'));
assert.equal(new Set(bank.questions.map(q=>q.id)).size,500);
assert.equal(new Set(bank.questions.flatMap(q=>q.variants)).size,1500);
for(const q of bank.questions){assert.equal(q.answers.length,4);assert.equal(new Set(q.answers.map(a=>a.text)).size,4);}
const primary=bank.questions.map(q=>q.variants[0]);
assert.equal(new Set(primary).size,500,'500 distinct first-hand editorial prompts');
assert.ok(primary.every(text=>text.length>34&&text.endsWith('?')&&(text.match(/\\?/g)||[]).length===1),'one coherent question per lead');
assert.ok(primary.every(text=>!text.includes('{s}')&&!text.includes('Quel regard portez-vous')),'no generic placeholders or boilerplate');
assert.ok(new Set(primary.map(text=>text.slice(0,42))).size>=360,'editorial openings must vary beyond subject substitution');
const byTheme=new Map();
for(const q of bank.questions){
  const batch=byTheme.get(q.theme)||[];
  batch.push(q.variants[0]);
  byTheme.set(q.theme,batch);
}
assert.equal(byTheme.size,25);
assert.ok([...byTheme.values()].every(batch=>batch.length===20&&new Set(batch).size===20),'20 distinct lead questions per theme');
assert.equal(new Set(bank.questions.flatMap(q=>q.answers.map(a=>a.id))).size,4,'answer IDs remain backward compatible');
const chosen=bank.pick({season:2,week:8,count:4,context:{themes:['defaite','crise','vestiaire','direction']},seed:7});
assert.equal(chosen.length,4);
assert.ok(chosen.every(q=>['defaite','crise','vestiaire','direction'].includes(q.theme)));
const history=bank.appendHistory([],chosen[0],2,8,'r1');
assert.ok(!bank.pick({season:2,week:9,count:4,context:{themes:['defaite','crise','vestiaire','direction']},history,seed:7}).some(q=>q.id===chosen[0].id));
assert.ok(bank.pick({season:2,week:20,count:4,context:{themes:['defaite','crise','vestiaire','direction']},history,seed:7}).length===4);
assert.throws(()=>bank.appendHistory([],chosen[0],2,8,'r9'));
console.log('PASS V60 bank: 25 themes, 500 prompts, 1500 variants, 4 responses, 12-week exclusion');
const conference=bank.pick({season:3,week:9,count:4,seed:5});assert.equal(new Set(conference.map(q=>q.journalist.outlet)).size,4,'one journalist per outlet at each conference');
