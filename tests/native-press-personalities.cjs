'use strict';
// Missing fifth choice, fabricated memories and unbounded personality effects break this contract.
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const press=require('../native/engine/press.cjs'),bank=require('../dist/press-question-bank.js'),relations=require('../dist/press-relations.js');
assert.equal(bank.questions.length,500);
assert.equal(bank.questions.flatMap(q=>q.answers).length,2500,'Cinq réponses par question');
assert.equal(new Set(bank.questions.map(q=>q.answers[4].text)).size,500,'Humour original pour chaque question');
for(const q of bank.questions){assert.deepEqual(q.answers.map(a=>a.id),['r0','r1','r2','r3','r4']);assert.equal(q.answers[4].tone,'humour');assert.ok(q.answers.every(a=>!a.text.includes('préparé préparation mentale')&&!a.text.includes('sur préparation mentale')));}
const ctx=vm.createContext({CDNativeHeadless:true,console,Math:Object.assign(Object.create(Math),{random(){throw Error('RNG interdit');}}),save(){},render(){}}),run=s=>vm.runInContext(s,ctx);
for(const f of press.files)run(fs.readFileSync(path.join(__dirname,'../dist',f),'utf8'));
run(`S={season:2,round:0,club:0,morale:65,trust:65,live:null,clubs:Array.from({length:30},(_,id)=>({id,players:[]})),history:[],franceMode:{version:1,week:34,leagues:{elite:{members:[0]},accession:{members:[29]}}}};const p=(${press.factory.toString()})();`);
const initial=run('JSON.stringify(S)'),projection=()=>JSON.parse(run('JSON.stringify(p.project())'));
let m=projection();assert.equal(m.people.length,30);assert.ok(m.people.every(j=>j.encounters===0&&j.memory.length===0&&j.personality.length>15));assert.equal(run('JSON.stringify(S)'),initial);
assert.ok(m.conference.questions.every(q=>q.answers.length===5&&q.answers.every(a=>a.effects&&a.consequence&&a.toneLabel)));
ctx.payload={context:m.context,answers:m.conference.questions.map(q=>({questionId:q.id,answerId:'r4'}))};run("p.execute('press_conference',payload)");
m=projection();assert.ok(m.people.some(j=>j.encounters===1));assert.ok(m.history.every(h=>h.journalist&&h.journalist.id&&h.answerId==='r4'));
const saved=run('JSON.stringify(S)');run('S=JSON.parse('+JSON.stringify(saved)+');p.validate(S)');assert.equal(run('JSON.stringify(S)'),saved);
run('S.club=29;S.franceMode.week=0;S.season=3');assert.deepEqual(projection().people,m.people,'Relation personnelle conservée après mobilité');
run('S='+saved);for(const change of ["S.pressPeople.version=9","S.pressPeople.contacts.unknown={score:0,encounters:0,memory:[]}","S.pressPeople.contacts[Object.keys(S.pressPeople.contacts)[0]].score=101","S.pressPeople.contacts[Object.keys(S.pressPeople.contacts)[0]].memory.push({})"]){run('S='+saved);run(change);assert.throws(()=>run('p.validate(S)'),/journaliste|relation|presse/i);}
run('S='+saved);run('delete S.pressPeople;S.pressConference.history.forEach(h=>{delete h.journalist;h.answerId="r3";delete h.questionText;delete h.answerText;});p.validate(S)');m=projection();assert.ok(m.people.every(j=>!j.encounters));assert.ok(m.history.every(h=>h.question===null&&h.answer===null&&h.journalist===undefined));
const effects=['technique','analyse','interview','enquete','editorial'].map(style=>relations.dialogueEffect({style},'humour','attaque',0));assert.ok(new Set(effects.map(e=>JSON.stringify(e))).size>=4);assert.ok(effects.some(e=>e.relation<0)&&effects.some(e=>e.relation>0));
for(const style of ['technique','analyse','interview','enquete','editorial'])for(const tone of ['confident','honest','aggressive','cautious','humour'])for(const theme of ['attaque','blessures','crise']){const fx=relations.dialogueEffect({style},tone,theme,100);assert.ok(Object.values(fx).every(n=>Number.isInteger(n)&&Math.abs(n)<=6));}
console.log('Personnalités presse : catalogue, cinq tons, mémoire personnelle, compatibilité et pureté PASS.');
// At the cap, visible memories must record the actual change, not a promised bonus.
const capped=relations.recordDialogue({version:1,contacts:{bard:{score:100,encounters:1,memory:[{season:1,week:0,club:0,questionId:'attaque-0-0',answerId:'r1',delta:3}]}}},{id:'bard'},{season:1,week:1,club:0,questionId:'attaque-0-1',answerId:'r1'},3);
assert.equal(capped.contacts.bard.score,100);assert.equal(capped.contacts.bard.memory[1].delta,0);
// A reference must not turn another reporter's actual exchange into a personal memory.
run('S='+saved);run(`{const [id,c]=Object.entries(S.pressPeople.contacts)[0];delete S.pressPeople.contacts[id];S.pressPeople.contacts['fiction-19']=c;}`);
assert.throws(()=>run('p.validate(S)'),/journaliste|relation|presse/i,'Pas de mémoire attribuée à un autre journaliste');
run('S='+saved);run('S.pressConference.history=[];delete S.pressConference.lastOutcome;p.validate(S)');
assert.ok(projection().people.flatMap(p=>p.memory).every(e=>e.question===null&&e.answer===null),'Archives expirées : absence explicite, aucune reconstruction depuis la banque');
let allContacts;
for(const j of bank.journalists)for(let week=0;week<3;week++)allContacts=relations.recordDialogue(allContacts,j,{season:1,week,club:29,questionId:'phase_finale-4-'+week,answerId:'r4'},2);
assert.equal(Object.keys(allContacts.contacts).length,30);assert.ok(Buffer.byteLength(JSON.stringify(allContacts))<30000);
console.log('Mémoire 30 contacts / 90 échanges : '+Buffer.byteLength(JSON.stringify(allContacts))+' octets.');
run('S='+initial);run('delete S.franceMode;S.clubs=S.clubs.slice(0,14);S.season=2;S.round=0;p.validate(S)');
m=projection();assert.equal(m.context.week,0);ctx.payload={context:m.context,answers:m.conference.questions.map(q=>({questionId:q.id,answerId:'r4'}))};run("p.execute('press_conference',payload);p.validate(S)");assert.equal(projection().lastOutcome.context.season,2,'Calendrier historique saison2 : décision et mémoire datées dans la bonne saison');
