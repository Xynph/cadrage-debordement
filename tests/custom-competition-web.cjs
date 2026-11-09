'use strict';
const assert=require('node:assert/strict');
const {context}=require('./harness.cjs'),domain=require('../native/engine/custom-competition.cjs'),editor=require('../native/engine/competition-editor.cjs');
const document=editor.generate({name:'Ligue des vallées',clubs:Array.from({length:14},(_,i)=>'Club des vallées '+(i+1)),doubleRound:true});
for(const f of document.fixtures){if(f.round===1)f.round=2;else if(f.round===2)f.round=1;}
const {ctx,run}=context();ctx.payload={mode:'custom',club:3,confirmed:true,document};
run('render=()=>{};toast=()=>{}');
run('const custom=('+domain.factory.toString()+')();custom.create(payload)');
// Deliberately no native systems/bootstrap/domain installHooks: core web path.
const initial=run('JSON.stringify(S.customCompetition)');
run('for(let safety=0;S.phase!=="ended";safety++){if(safety>30)throw Error("fin de saison manquante");finishRound()}');
run('advanceSeason()');
assert.equal(run('S.season'),2);
assert.equal(run('JSON.stringify(S.customCompetition)'),initial);
assert.equal(run('JSON.stringify(S.schedule)'),run('JSON.stringify(S.customCompetition.schedule)'),'Le cœur web conserve le calendrier édité sans hook natif');
assert.equal(run('S.clubs[3].name'),'Club des vallées 4');
run('validateCareer(S)');
const before=run('JSON.stringify(createSaveDocument())'),saved=JSON.parse(before).state;
const second=context(saved);assert.equal(second.run('loadSaveFailure'),'');assert.equal(second.run('S.clubs[3].name'),'Club des vallées 4');
const ordinary=context();ordinary.run('render=()=>{};toast=()=>{};start(0);for(let safety=0;S.phase!=="ended";safety++){if(safety>30)throw Error("fin");finishRound()};advanceSeason();validateCareer(S)');
assert.equal(ordinary.run('S.customCompetition'),undefined);assert.equal(ordinary.run('JSON.stringify(S.schedule)'),ordinary.run('JSON.stringify(schedule())'));
console.log('Compétition personnalisée : saison2 web, sauvegarde/reprise et fiction historique inchangée');
