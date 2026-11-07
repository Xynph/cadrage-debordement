const assert=require('node:assert/strict');
const d=require('../dist/premium-editorial.js').matchday;
assert.ok(d,'contrôleur matchday disponible');
assert.deepEqual(d.normalizePreferences({mode:'bad',speed:Infinity,gapSpeed:-1,camera:'immersive',display:'bad'}),{mode:'highlights',speed:1,gapSpeed:120,camera:'tactical',display:'2d'});
assert.equal(d.important({type:'try'},'highlights'),true);
assert.equal(d.important({scene:{kind:'carry'}},'highlights'),false);
assert.equal(d.important({scene:{kind:'carry'}},'extended'),true);
assert.equal(d.isStoppage({flow:{advantage:{}}}),false);
assert.equal(d.isStoppage({minute:0,events:[]}),true);
const l={stats:[{possession:2,territory:130,scrums:2,scrumsWon:1},{possession:1,territory:170,scrums:1,scrumsWon:1}],tries:[0,0],events:[],sheets:[{sentOff:[]},{sentOff:[]}]};
const m=d.metrics(l);assert.equal(m.find(x=>x.key==='possession').left,'67 %');assert.equal(m.find(x=>x.key==='occupation').left,'43 %');assert.equal(m.find(x=>x.key==='scrums').left,'1 / 2');assert.ok(!m.some(x=>x.key==='tackles'));
console.log('Matchday : préférences, séquences, arrêts et mesures réelles OK');
const fs=require('node:fs'),vm=require('node:vm'),{context}=require('./harness.cjs');
const extension=fs.readFileSync(require.resolve('../dist/premium-editorial.js'),'utf8').split('/* Matchday :')[1];
function fixture(){const t=context();t.run('start(0);beginMatch();pauseMatch();window.document={querySelector:()=>null,addEventListener(){}};window.render=()=>{};');vm.runInContext('/* Matchday :'+extension,t.ctx);return t;}
for(let seed=1;seed<=8;seed++){
 const t=fixture(),run=t.run;
 run('var base=JSON.stringify(S);var seed0='+seed+';function reseed(){var v=seed0;Math.random=()=>{v=(Math.imul(v,1664525)+1013904223)>>>0;return v/4294967296}};reseed();var l=S.live;var count=0;while(!l.finished&&count++<240){l.paused=false;if(flowRules(l))resumeFlowHalf(l);var auto={...l,userSide:-1};adaptManager(auto,l.userSide);aiSubs(auto,l.userSide);advanceRugby(l)};syncMatchPresentation(l);var expected=JSON.stringify(S);S=JSON.parse(base);reseed();window.CDMatchday.open("instant");window.CDMatchday.instant();');
 assert.equal(run('S.live.finished'),true);assert.equal(run('JSON.stringify(S)'),run('expected'),'parité moteur/adjoint graine '+seed);assert.ok(run('S.live.sheets[S.live.userSide].subs')>0,'adjoint effectue des changements');assert.ok(run('parseSaveDocument(JSON.stringify(createSaveDocument()))'));
}
{
 const t=fixture(),r=t.run;
 r('var l=S.live;window.CDMatchday.open("instant");var before=JSON.stringify(S);window.CDMatchday.close();');assert.equal(r('JSON.stringify(S)'),r('before'));
 r('l.paused=false;window.CDMatchday.open("subs");syncMatchPresentation(l);window.CDMatchday.step(1)');assert.equal(r('l.paused'),false);assert.equal(r('window.CDMatchday.getState().second'),1);assert.equal(r('l.minute'),0);
 r('l.sheets[1].sentOff.push("test-red");window.CDMatchday.step(1)');assert.equal(r('l.paused'),true);
 r('l.sheets[1].sentOff.pop();l.paused=false;syncMatchPresentation(l);l.flow.atBreak=true;window.CDMatchday.step(1)');assert.equal(r('l.paused'),true);
}
{
 const t=fixture(),r=t.run;
 r('var l=S.live;l.minute=12;l.flow.ballDead=false;l.flow.advantage=null;var candidate=eligibleChanges(l,l.userSide,0)[0];window.CDMatchday.open("subs");window.CDMatchday.selectSub(0,candidate.id);window.CDMatchday.confirm();');assert.equal(r('window.CDMatchday.getState().queue.length'),1);
 vm.runInContext('/* Matchday :'+extension,t.ctx);assert.equal(r('window.CDMatchday.getState().queue.length'),1,'file confirmée restaurée');
 r('l.flow.ballDead=true;window.CDMatchday.processQueue(l,window.CDMatchday.getState());');assert.equal(r('l.sheets[l.userSide].on[0]'),r('candidate.id'));
}
console.log('Matchday natif : 8 simulations appariées, adjoint, exports, secondes, pauses et file persistante OK');
{
 const t=fixture(),r=t.run;
 r('var l=S.live;l.paused=false;S.phase="semi";l.minute=81;l.score=[0,0];addEvent(l,"Sortie en touche","play",{kind:"touch"});var touch=l.events.length-1;finishRugbyMatch(l);playback(l).cursor=touch;window.CDMatchday.setPreference("mode","full");window.CDMatchday.setPreference("speed",1);for(var i=0;i<24&&presentationPending(l);i++)window.CDMatchday.step(1);');
 assert.equal(r('presentationPending(l)'),false,'dernière séquence entièrement lue');assert.equal(r('JSON.stringify(matchViewState(l).score)'),r('JSON.stringify(l.score)'));
}
for(const [speed,expected] of [[1,0],[2,1],[4,2],[8,4],[16,8]]){
 const t=fixture(),r=t.run;r('var l=S.live;l.paused=false;syncMatchPresentation(l);for(var i=0;i<20;i++)addEvent(l,"Progression","play",{kind:"carry"});playback(l).cursor=0;window.CDMatchday.setPreference("mode","full");window.CDMatchday.setPreference("speed",'+speed+');for(var i=0;i<3;i++)window.CDMatchday.step(1);');assert.equal(r('playback(l).cursor'),expected,'vitesse linéaire ×'+speed);
}
console.log('Matchday : dernière séquence multi-événements et cinq vitesses linéaires OK');
