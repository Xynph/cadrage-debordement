'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {context}=require('./harness.cjs');

const g=context();
g.run('start(0)');
const initial=g.run('JSON.stringify(S)'),save=g.store['bdt-v1'];
const p=g.run('collectivePreparationCard()');
assert.match(p,/ui05-collective/);
assert.match(p,/TACTIQUES \/ PRÉPARATION/);
assert.match(p,/PRÉPARATION RETENUE/);
assert.match(p,/CONSEIL DU STAFF/);
assert.match(p,/CHARGE MOYENNE DU XV ACTUEL/);
assert.match(p,/Bonus fictifs maximaux/);
assert.match(p,/Conquête/);
assert.match(p,/Organisation défensive/);
assert.match(p,/Jeu au pied/);
assert.match(p,/Préserver les organismes/);
assert.equal((p.match(/class="option ui05-option/g)||[]).length,4);
assert.equal((p.match(/<button[^>]*aria-pressed="true"/g)||[]).length,1);
assert.match(p,/setCollectiveFocus\('conquete'\)/);
assert.match(p,/setCollectiveFocus\('defence'\)/);
assert.match(p,/setCollectiveFocus\('pied'\)/);
assert.match(p,/setCollectiveFocus\('aucune'\)/);
assert.match(p,/aria-label="Choix de préparation collective"/);
assert.ok(p.includes('15 joueur(s) concerné(s)')||p.includes('14 joueur(s) concerné(s)')||p.includes('13 joueur(s) concerné(s)'));
assert.match(p,/:root\[data-cd-theme="tribune"\]/);
assert.match(p,/@media\(max-width:580px\)/);
assert.match(p,/:focus-visible/);
assert.match(p,/prefers-reduced-motion/);
assert.match(g.run('tactics()'),/ui05-collective/,'UI05 must be embedded in playable tactics');

g.run("nav('tactics')");
assert.match(g.app.innerHTML,/ui05-collective/);
assert.equal(g.run('JSON.stringify(S)'),initial,'projection mutated career');
assert.equal(g.store['bdt-v1'],save,'projection saved career');
assert.equal(g.run('S.collectiveFocus'),'aucune');
const beforeRoll=g.run('Math.random()');
const ref=context();ref.run('start(0)');assert.equal(beforeRoll,ref.run('Math.random()'),'projection changed random stream');
// Clics déjà connectés à la commande native, sans nouvelle logique métier.
assert.equal(g.run('setCollectiveFocus("conquete")'),true);
assert.equal(g.run('S.collectiveFocus'),'conquete');
assert.ok(g.app.innerHTML.includes('aria-pressed="true"'));
assert.ok(g.run('!!parseSaveDocument(JSON.stringify(createSaveDocument()))'));
const stored=g.run('JSON.stringify(S)');
const restored=context(JSON.parse(stored));
assert.equal(restored.run('S.collectiveFocus'),'conquete');
assert.match(restored.run('collectivePreparationCard()'),/ui05-collective/);
const x=context();x.run('start(0)');
x.run('var first=starters().find(p=>p.fam<=3&&!p.injury);ensurePhysicalLoad(first).fatigue=80;');
const rendered=x.run('collectivePreparationCard()');
assert.match(rendered,/Charge actuelle/);
assert.match(rendered,/\/100/);
x.run('S.trained=true');
assert.match(x.run('collectivePreparationCard()'),/Choix verrouillé/);
assert.equal((x.run('collectivePreparationCard()').match(/ disabled/g)||[]).length,4);
assert.equal(x.run('setCollectiveFocus("conquete")'),false);
x.run('S.trained=false;S.phase="ended"');
assert.equal(x.run('collectivePreparationCard()'),'');
const active=context();active.run('start(0);beginMatch();pauseMatch()');
assert.match(active.run('collectivePreparationCard()'),/Choix verrouillé/);
assert.equal(active.run('setCollectiveFocus("conquete")'),false);
assert.equal(active.run('S.live.collectivePreparation.focus[0]'),'aucune');
assert.ok(active.run('!!createSaveDocument()'));
// Non-régression: charges et bonus existants inchangés en conditions réelles.
const a=context(),b=context();
a.run('start(0)');b.run('start(0);setCollectiveFocus("conquete")');
a.run('trainWeek()');b.run('trainWeek()');
const front=a.run('club().players.find(p=>p.fam<=3&&!p.injury).id');
a.run('var p=player('+JSON.stringify(front)+')');
b.run('var p=player('+JSON.stringify(front)+')');
assert.equal(b.run('physicalLoadValue(p)')-a.run('physicalLoadValue(p)'),4);
b.run('var l=createRugbyMatch([0,1])');
const effect=b.run('collectivePreparationBonus(l,0,"conquete")');
assert.ok(effect>0&&effect<=.04);
assert.ok(!fs.readFileSync(path.resolve(__dirname,'..','dist','index.html'),'utf8').includes('ui05-preparation.js'));
console.log(JSON.stringify({passed:true,checks:[
 'real tactics UI render','four native choices and one selected','staff advice and load',
 'responsive theme CSS','no career, save or random mutation on reading',
 'native focus action and save roundtrip','native training and match locks',
 'full and historical career','unchanged native fatigue cost and effects'
]}));