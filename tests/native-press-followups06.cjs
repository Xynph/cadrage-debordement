'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const press=require('../native/engine/press.cjs'),bank=require('../dist/press-question-bank.js');
const ctx=vm.createContext({CDNativeHeadless:true,console,save(){},render(){},Math:Object.assign(Object.create(Math),{random(){throw Error('RNG interdit en consultation');}})});
const run=s=>vm.runInContext(s,ctx),read=s=>JSON.parse(run('JSON.stringify('+s+')'));
for(const f of press.files)run(fs.readFileSync(path.join(__dirname,'../dist',f),'utf8'));
run(`S={season:2,round:5,club:0,morale:65,trust:65,live:null,clubs:Array.from({length:30},(_,id)=>({id,name:'Club '+id,players:[]})),history:[],franceMode:{version:1,week:5,leagues:{elite:{members:[0]},accession:{members:[29]}}}};const p=(${press.factory.toString()})();`);
const original=read('p.project()'),question=original.conference.questions[0];
const source={id:bank.questions.find(q=>q.theme===question.theme&&q.id!==question.id).id,season:2,week:1,club:0,answerId:'r4',questionText:'Quel projet pour le groupe ?',answerText:'Nous avançons avec méthode, même sous la pluie à Béziers — sans promesse de victoire.',journalist:{id:question.journalist.id,name:question.journalist.name,outlet:question.journalist.outlet}};
ctx.archive=source;run('S.pressConference={version:1,history:[JSON.parse(JSON.stringify(archive))]};p.validate(S)');
const saved=run('JSON.stringify(S)'),projected=read('p.project()'),follow=projected.conference.questions.find(q=>q.id===question.id);
assert.ok(follow.followUp,'Le journaliste relance sa déclaration réellement archivée');
assert.equal(follow.followUp.quote,source.answerText);assert.deepEqual(follow.followUp.context,{season:2,week:1,club:0});
assert.ok(follow.question.includes(source.answerText));assert.match(follow.question,/saison 2, semaine 2/);assert.ok(follow.question.endsWith(question.question));
assert.equal(follow.answers.length,5);assert.deepEqual(follow.answers,question.answers,'Choix et effets inchangés');
for(let i=0;i<4;i++)assert.deepEqual(read('p.project()'),projected);assert.equal(run('JSON.stringify(S)'),saved);
for(const alteration of ['S.pressConference.history[0].club=29','S.pressConference.history[0].season=1','S.pressConference.history[0].week=6',"S.pressConference.history[0].journalist.id='fiction-19'",'delete S.pressConference.history[0].answerText','delete S.pressConference.history[0].questionText']){
 run('S='+saved);run(alteration);assert.ok(read('p.project().conference.questions').every(q=>!q.followUp),'Pas de fausse mémoire : '+alteration);
}
run('S='+saved);ctx.unrelated=bank.questions.find(q=>q.theme!==question.theme).id;run('S.pressConference.history[0].id=unrelated');assert.ok(!read('p.project().conference.questions').find(q=>q.id===question.id).followUp,'La déclaration rappelée doit concerner le thème de cette question');
run('S='+saved);ctx.payload={context:projected.context,answers:projected.conference.questions.map(q=>({questionId:q.id,answerId:'r1'}))};run("p.execute('press_conference',payload);p.validate(S)");
const executed=read('S.pressConference.history').find(h=>h.id===question.id&&h.week===5);
assert.equal(executed.questionText,follow.question,'Texte réellement présenté conservé, pas la question de base');
const roundtrip=run('JSON.stringify(S)');run('S=JSON.parse('+JSON.stringify(roundtrip)+');p.validate(S)');assert.equal(read('p.project().history').find(h=>h.id===question.id&&h.week===5).question,follow.question);
run('S='+saved);ctx.prior={...executed,week:4,id:question.id};run('S.pressConference.history.push(prior)');
assert.ok(read('p.project().conference.questions').every(q=>!q.followUp),'Une source déjà relancée ne revient pas en boucle');
run('S='+saved);run('S.pressConference.history.forEach(h=>{delete h.questionText;delete h.answerText;});p.validate(S)');assert.match(read('p.project()').conference.memoryNotice,/archive|conserv/i);
run('S='+saved);run('delete S.pressConference;delete S.pressPeople');assert.ok(read('p.project().conference.questions').every(q=>!q.followUp),'Nouvelle carrière sans ancienne déclaration');
console.log('Presse06 : relance littérale Unicode/date, isolation journaliste/club/saison, anti-répétition, cinq choix, état pur, archive exacte et anciennes données PASS.');
