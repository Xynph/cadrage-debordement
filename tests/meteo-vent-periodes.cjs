'use strict';
// Vent de face / de dos par période (docs/meteo-match-20261116.md, « Vent par période », 17/11/2026), carrière Monde
// (world-champ, club 102) : le sens du vent est tiré sans aléa avec la météo (`meteo.sens`, `windVersion: 1`), change
// de camp à la mi-temps, pèse sur le jeu au pied et le tir au but, est annoncé par le staff ; les rencontres commencées
// sans `windVersion` gardent la moyenne d'origine ; la sauvegarde valide le sens.
const test = require('node:test');
const assert = require('node:assert/strict');
const {context} = require('./monde-harness.cjs');

const shared = context(827381, {club: 102, console: false}).toMatch(), base = shared.checkpoint();
test.after(() => shared.close());
const setup = () => shared.restore(base);
const creer = s => s.run(`var lv=(function(){const fx=CDWorldCareer.fixtures(S).find(f=>f.homeId!==S.club&&f.awayId!==S.club);for(const id of [fx.homeId,fx.awayId])CDFranceCareer.ensureAISheet(S.clubs[id]);const l=createRugbyMatch([fx.homeId,fx.awayId],null,true);l.weather='Vent';l.meteo={pluie:0,vent:2,chaleur:0,terrain:'souple',sens:0};return l})()`);

test('Rencontre neuve : sens du vent tiré avec la météo, stable, valide', () => {
  const s = setup();
  creer(s);
  assert.equal(s.run('lv.windVersion'), 1);
  assert.equal(s.run('lv.weatherVersion'), 1);
  // Même affiche, même date : même sens ; sur plusieurs affiches, les deux sens existent.
  const sens = JSON.parse(s.run(`(function(){const fx=CDWorldCareer.fixtures(S).filter(f=>f.homeId!==S.club&&f.awayId!==S.club).slice(0,40),out=[];
    for(const f of fx){const l={pair:[f.homeId,f.awayId],weather:'Vent'};const a=tirerMeteo(l),b=tirerMeteo(l);out.push([a.sens,b.sens,a.vent>0])}return JSON.stringify(out)})()`));
  assert.ok(sens.every(([a, b, v]) => a === b && [0, 1].includes(a) && v), 'sens stable et valide');
  assert.ok(sens.some(([a]) => a === 0) && sens.some(([a]) => a === 1), 'les deux sens se rencontrent : ' + JSON.stringify(sens.map(x => x[0])));
  s.run('validateFlowState(lv)');
});

test('Vent par période : de dos pour un camp, de face pour l’autre, inversé en seconde période', () => {
  const s = setup();
  creer(s);
  const lire = () => JSON.parse(s.run('JSON.stringify([ventPour(lv,0),ventPour(lv,1),lv.flow.period])'));
  assert.deepEqual(lire(), [1, -1, 1], 'sens 0 : vent dans le dos du camp 0 en 1re période');
  s.run('lv.flow.period=2');
  assert.deepEqual(lire(), [-1, 1, 2], 'inversé à la mi-temps');
  s.run('lv.flow.period=1;lv.meteo.sens=1');
  assert.deepEqual(lire(), [-1, 1, 1], 'sens 1 : l’autre camp');
  s.run('lv.meteo.vent=0');
  assert.deepEqual(lire(), [0, 0, 1], 'pas de vent : aucun sens');
  s.run('lv.meteo.vent=2;delete lv.windVersion');
  assert.deepEqual(lire(), [0, 0, 1], 'rencontre sans windVersion : ancien calcul');
});

test('Effets : tir au but et jeu au pied suivent le sens ; moyenne d’origine conservée', () => {
  const s = setup();
  creer(s);
  const r = JSON.parse(s.run(`(function(){const m=(a,b)=>JSON.stringify([a,b]);
    lv.flow.period=1;const dos=goalChance(lv,0,true,35),metresDos=ventMetres(lv,0),butDos=ventBut(lv,0);
    lv.flow.period=2;const face=goalChance(lv,0,true,35),metresFace=ventMetres(lv,0),butFace=ventBut(lv,0);
    delete lv.windVersion;const ancien=goalChance(lv,0,true,35),metresAncien=ventMetres(lv,0),butAncien=ventBut(lv,0);
    return JSON.stringify({dos,face,ancien,metresDos,metresFace,metresAncien,butDos,butFace,butAncien})})()`));
  assert.ok(r.dos > r.face + .05, 'tir au but : vent de dos nettement meilleur que de face ' + JSON.stringify(r));
  assert.ok(r.dos > r.ancien && r.face < r.ancien, 'ancien calcul entre les deux ' + JSON.stringify(r));
  assert.equal(r.metresFace, 20);
  assert.equal(r.metresDos, -4);
  assert.equal(r.metresAncien, 8);
  assert.ok(Math.abs((r.metresFace + r.metresDos) / 2 - r.metresAncien) < 1e-9, 'moyenne des deux camps = ancienne moyenne');
  assert.ok(Math.abs((r.butFace + r.butDos) / 2 - r.butAncien) < 1e-9, 'moyenne au but conservée');
});

test('Jeu au pied : longueur moyenne plus courte vent de face que de dos', () => {
  const s = setup();
  creer(s);
  const m = JSON.parse(s.run(`(function(){const rng=Math.random;let x=12345;Math.random=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296};
    try{const mesure=periode=>{let somme=0,n=0;for(let i=0;i<150;i++){lv.flow.period=periode;lv.territory=50;lv.possession=0;const avant=lv.territory;try{kickOpenPlay(lv,0)}catch(e){}
      somme+=Math.abs(lv.territory-avant);n++}return somme/n};return JSON.stringify({dos:mesure(1),face:mesure(2)})}finally{Math.random=rng}})()`));
  assert.ok(m.dos > m.face, 'vent de dos : coups de pied plus longs ' + JSON.stringify(m));
});

test('Annonce du staff : camp favorisé, changement à la mi-temps', () => {
  const s = setup();
  creer(s);
  const c1 = s.run('meteoConseil(lv)'), c2 = s.run('lv.flow.period=2;meteoConseil(lv)');
  assert.match(c1, /dos de .+ en première période/);
  assert.match(c2, /dos de .+ en seconde période/);
  assert.notEqual(c1.match(/dos de (\S+)/)[1], c2.match(/dos de (\S+)/)[1], 'le vent change de camp');
  s.run('lv.meteo.vent=0;lv.weather="Sec"');
  assert.doesNotMatch(s.run('meteoConseil(lv)'), /dos de/);
});

test('Match entier par grand vent : joué jusqu’au bout, sauvegarde valide à chaque période', () => {
  const s = setup();
  creer(s);
  s.run('lv.paused=false;for(let g=0;!lv.finished&&g<600;g++){lv.paused=false;advanceRugby(lv);if(g===30)validateFlowState(lv)}validateFlowState(lv)');
  assert.equal(s.run('lv.finished'), true);
});

test('Sauvegarde : sens invalide ou version inconnue refusés', () => {
  const s = setup();
  creer(s);
  s.run('validateFlowState(lv)');
  s.run('lv.meteo.sens=3');
  assert.throws(() => s.run('validateFlowState(lv)'), /météo/i);
  s.run('lv.meteo.sens=1;lv.windVersion=2');
  assert.throws(() => s.run('validateFlowState(lv)'), /météo/i);
  s.run('lv.windVersion=1;delete lv.weatherVersion;delete lv.meteo');
  assert.throws(() => s.run('validateFlowState(lv)'), /météo/i);
  // Ancienne rencontre (météo v1 sans sens ni windVersion) : valide.
  s.run('lv.weatherVersion=1;lv.meteo={pluie:0,vent:2,chaleur:0,terrain:"souple"};delete lv.windVersion');
  s.run('validateFlowState(lv)');
});
