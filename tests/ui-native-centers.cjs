'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const {context}=require('./harness.cjs');
const h=context(),run=h.run;
for(const name of ['ui03-scout-data.js','ui03-scout-components.js','ui04-academy-data.js','ui04-academy-components.js','ui-native-centers.js'])
 vm.runInContext(fs.readFileSync(__dirname+'/../dist/'+name,'utf8'),h.ctx);
run('start(0)');
const initial=run('JSON.stringify(S)');
assert.match(run('CDNativeCenters.recruitmentView()'),/Centre de recrutement|cellule de recrutement/i);
assert.match(run('CDNativeCenters.formationView()'),/centre de formation/i);
assert.equal(run('JSON.stringify(S)'),initial,'consultation des deux centres sans mutation de carrière');
run("view='recruitment'");
assert.equal(run('CDNativeCenters.mission({family:4,maxAge:28,budget:700000,maxWage:12000})'),true);
assert.equal(run('S.manager.missions.length'),1);
assert.equal(run('S.ledger.some(e=>e.amount===-5000)'),true);
assert.equal(run('CDNativeCenters.mission({family:-1,maxAge:28,budget:700000,maxWage:12000})'),false);
assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
run('var target=managerPool()[0]?.id');
if(run('target')){
 assert.equal(run('CDNativeCenters.follow(target)'),true);
 assert.equal(run('S.manager.watch.includes(target)'),true);
 assert.equal(run('CDNativeCenters.follow(target)'),true);
 assert.equal(run('S.manager.watch.includes(target)'),false);
}
run("view='formation'");
assert.equal(run("CDNativeCenters.promote('__intrus__',true)"),false);
assert.equal(run("CDNativeCenters.focus('__intrus__','equilibre')"),false);
run('var youngId=S.development.academy[0]?.id');
if(run('youngId')){
 assert.equal(run('CDNativeCenters.promote(youngId,false)'),false,'confirmation obligatoire');
 assert.equal(run('S.development.academy.some(p=>p.id===youngId)'),true);
 assert.equal(run('CDNativeCenters.promote(youngId,true)'),true,'promotion native');
 assert.equal(run('club().players.some(p=>p.id===youngId)'),true);
 assert.ok(run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
}
const page=fs.readFileSync(__dirname+'/../dist/index.html','utf8');
for(const asset of ['ui03-scout-data.js','ui03-scout-components.js','ui04-academy-data.js','ui04-academy-components.js','ui-native-centers.js'])
 assert.ok(page.includes('src="'+asset+'"'),'module navigateur chargé '+asset);
const game=fs.readFileSync(__dirname+'/../dist/game.js','utf8');
assert.ok(game.includes('CDNativeCenters.recruitmentView'));
assert.ok(game.includes('CDNativeCenters.formationView'));
assert.ok(game.includes('CDNativeCenters.bind()'));
console.log('UI03B/UI04B native integration PASS: read-only, mission, suivis, promotion, sauvegardes et navigation');
