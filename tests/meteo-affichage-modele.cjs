'use strict';
// Météo et vent montrés au manager (carrière Monde, world-champ, club 102) : le modèle natif du direct expose
// le libellé, le conseil du staff et le camp qui a le vent dans le dos à chaque période ; l'écran compose
// la phrase du vent avec les noms affichés (aucun sigle interne dans le conseil).
const test = require('node:test');
const assert = require('node:assert/strict');
const {context} = require('./monde-harness.cjs');

const h = context(827381, {club: 102, console: false});
test.after(() => h.close());
h.start(102).toMatch();
const debut = h.command('begin_match');

test('Coup d’envoi : météo tirée et exposée dans le direct', () => {
  const m = debut.live.meteo, l = JSON.parse(h.run('JSON.stringify(S.live.meteo)'));
  assert.ok(m && typeof m.libelle === 'string' && m.libelle.length > 0, 'libellé présent');
  assert.equal(m.pluie, l.pluie);
  assert.equal(m.vent, l.vent);
  assert.equal(typeof m.conseil, 'string');
  assert.doesNotMatch(m.conseil, /dos de/, 'la phrase du vent est composée par l’écran');
});

test('Vent orienté : camp favorisé par période, inversé à la mi-temps', () => {
  h.run("S.live.weather='Vent';S.live.meteo={pluie:0,vent:2,chaleur:0,terrain:'souple',sens:1}");
  const m = h.command('snapshot').live.meteo;
  assert.equal(m.libelle, 'grand vent');
  assert.deepEqual(m.ventDos, [1, 0]);
  assert.match(m.conseil, /Grand vent/);
  h.run('S.live.meteo.vent=0');
  assert.equal(h.command('snapshot').live.meteo.ventDos, null, 'sans vent, aucun camp');
});
