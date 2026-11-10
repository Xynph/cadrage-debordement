'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const press = require('../native/engine/press.cjs');

const context = vm.createContext({
  CDNativeHeadless: true,
  save() {},
  render() {},
  Math: Object.assign(Object.create(Math), {
    random() { throw Error('La conférence doit être déterministe'); },
  }),
  CDFranceCompetition: {
    userFixture(state) { return state.franceMode.fixture ?? null; },
    ranked(state, id) {
      return state.clubs.filter(club => state.franceMode.leagues[id]?.members.includes(club.id));
    },
  },
});
const run = expression => vm.runInContext(expression, context);
const read = expression => JSON.parse(run('JSON.stringify(' + expression + ')'));

for (const file of press.files) {
  run(fs.readFileSync(path.join(__dirname, '../dist', file), 'utf8'));
}

run(`
  const api = (${press.factory.toString()})();
  const clubs = Array.from({length:30},(_,id)=>({id,name:'Club '+id,players:[]}));
  clubs[26].name='Saint-Lys';
  clubs[28].name='Béziers';
  clubs[29].name='Le Stade des Pins';
  const initial = JSON.stringify({
    season:2, round:12, club:29, morale:68, trust:65, live:null, phase:'league',
    clubs, history:[],
    franceMode:{version:1,week:12,leagues:{elite:{members:[29,28,26],schedule:[]},accession:{members:[0,1],schedule:[]}}}
  });
  let S = JSON.parse(initial);
`);

const conference = () => read('api.project().conference.questions');
const theme = (questions, name) => {
  const question = questions.find(q => q.theme === name);
  assert.ok(question, 'Question attendue sur ' + name);
  return question;
};
const factsText = q => [q.question, ...q.answers.map(a => a.text)].join('\n');
const identity = qs => qs.map(q => [
  q.id, q.journalist.id, q.answers.map(a => [a.id, a.tone, a.effects]),
]);

const generic = conference();
assert.doesNotMatch(factsText(theme(generic, 'avant_match')), /Saint-Lys|Béziers/);
assert.doesNotMatch(factsText(theme(generic, 'attaque')), /gagnent la ligne|12[–-]17/);

run(`
  S.franceMode.fixture={pair:[26,29],phase:'barrage',week:12};
  S.history=[
    {season:2,week:11,pair:[28,29],score:[17,12]},
    {season:2,week:12,pair:[0,1],score:[55,54]},
    {season:2,week:13,pair:[26,29],score:[91,90]},
    {season:1,week:11,pair:[26,29],score:[88,89]},
  ];
`);
const snapshot = run('JSON.stringify(S)');
const grounded = conference();
assert.deepEqual(identity(grounded), identity(generic), 'Les faits ne modifient ni les choix disponibles ni leurs effets');
assert.deepEqual(conference(), grounded);
assert.equal(run('JSON.stringify(S)'), snapshot, 'La projection ne modifie pas la carrière');
const next = theme(grounded, 'avant_match');
assert.match(next.answers.map(a => a.text).join('\n'), /Saint-Lys/);
assert.match(factsText(next), /barrage/i);
const attack = theme(grounded, 'attaque');
assert.match(attack.answers.find(a => a.id === 'r1').text, /Béziers/);
assert.match(factsText(attack), /12[–-]17/);
assert.doesNotMatch(factsText(attack), /17[–-]12|55[–-]54|90[–-]91|89[–-]88/);
assert.match(attack.answers.find(a => a.id === 'r1').text, /j.assume/i);
assert.equal(new Set(attack.answers.map(a => a.text)).size, 5);
assert.match(attack.answers.find(a => a.id === 'r1').text, /sortir au pied/i);
run('S.history[0].score=[12,17]');
assert.match(theme(conference(), 'attaque').answers.find(a=>a.id==='r1').text, /vérifier les soutiens/i);
run('S.history[0].score=[12,12]');
assert.match(theme(conference(), 'attaque').answers.find(a=>a.id==='r1').text, /transformer les possessions/i);
run('S=' + snapshot);

run('S.franceMode.fixture=null');
assert.doesNotMatch(factsText(theme(conference(), 'avant_match')), /Saint-Lys|barrage/i);
run('S=' + snapshot);
run('S.club=0; S.history = S.history.filter(r=>r.pair.includes(29))');
assert.doesNotMatch(factsText(theme(conference(), 'attaque')), /Béziers|12[–-]17/);

run(`
  S=JSON.parse(initial);
  S.morale=35;
  S.clubs[29].players=[
    {id:'a',name:'Mathis Rétabli',injury:0},
    {id:'b',name:'Élodie Soubeyran',injury:2},
  ];
  S.clubs[28].players=[{id:'c',name:'Baptiste Adverse',injury:3}];
`);
const injury = theme(conference(), 'blessures');
assert.match(injury.answers.map(a => a.text).join('\n'), /Élodie Soubeyran/);
assert.doesNotMatch(factsText(injury), /Mathis Rétabli|Baptiste Adverse|2 semaines|deux semaines/);
run('S.clubs[29].players[1].injury=0');
assert.doesNotMatch(factsText(theme(conference(), 'blessures')), /Élodie Soubeyran/);

run('S=' + snapshot);
context.payload = {
  context: read('api.project().context'),
  answers: grounded.map(q => ({questionId:q.id, answerId:'r1'})),
};
context.tones = context.payload.answers.map(a => a.answerId);
run('const canonical=JSON.parse(JSON.stringify(S)); CDV60RichPress.apply(canonical,tones);');
run("api.execute('press_conference',payload); api.validate(S)");
for (const key of ['pressPeople', 'pressRelations', 'morale', 'trust']) {
  assert.deepEqual(read('S.' + key), read('canonical.' + key));
}
const saved = run('JSON.stringify(S)');
run('S=JSON.parse(' + JSON.stringify(saved) + '); api.validate(S);');
for (const q of grounded) {
  const history = read('api.project().history').find(h => h.id === q.id);
  assert.equal(history.question, q.question);
  assert.equal(history.answer, q.answers.find(a => a.id === 'r1').text);
}
run('S.pressConference.history.forEach(h=>{delete h.questionText;delete h.answerText}); api.validate(S)');
assert.ok(read('api.project().history').every(h => h.answer === null && h.question === null));
console.log('Presse contextuelle : calendrier, résultat orienté, indisponibilité, effets et archives exactes PASS.');
