'use strict';
// Météo connue dès la veille (carrière Monde world-champ, calendrier journalier, club 102) : le ciel, son
// intensité et le sens du vent du match du club sont fixés la veille, gardés dans la sauvegarde, montrés dans
// le prochain match (`next.meteo`, même format que `live.meteo`), annoncés par un seul courrier « Bulletin
// météo » (lien vers la composition), puis repris tels quels au coup d'envoi. Le tirage ne consomme aucun aléa.
const test = require('node:test');
const assert = require('node:assert/strict');
const { ouvrir, creer } = require('./helpers/carriere-monde.cjs');

const jeu = ouvrir({ testVm: true });
test.after(() => jeu.fermer());
const run = source => jeu.bridge.vm.run(source);
const etat = source => JSON.parse(run('JSON.stringify(' + source + ')'));
const lendemain = iso => new Date(Date.parse(iso + 'T00:00:00Z') + 86400000).toISOString().slice(0, 10);
const avancer = model => jeu.regler(jeu.call('advance_day', { fromDate: model.meta.calendarToday }));

// Fin de l'avant-saison d'un coup, puis jour par jour jusqu'à l'avant-veille du premier match du club.
let model = creer(jeu, 102);
model = jeu.regler(jeu.call('preseason_advance', { fromDate: model.meta.calendarToday, until: 'saison' }));
let match = null;
for (let j = 0; j < 40; j++) {
  match = etat('CDWorldCareer.userFixture(S)');
  if (match && lendemain(lendemain(model.meta.calendarToday)) === match.date) break;
  model = avancer(model);
}
assert.ok(match, 'match du club dans la semaine');
const avantVeille = model;
model = avancer(model);
const veille = model;
model = avancer(model);
const jourJ = model;

test('Rien avant la veille ; annonce la veille, gardée dans la sauvegarde', () => {
  assert.equal(avantVeille.next?.meteo, undefined, 'avant-veille : aucune météo');
  const m = veille.next?.meteo, kept = etat('S.worldMode.meteo');
  assert.ok(m, 'la veille : météo du prochain match');
  assert.equal(m.date, match.date);
  assert.equal(kept.fixtureId, match.id);
  assert.deepEqual(Object.keys(m).sort(), ['chaleur', 'conseil', 'date', 'libelle', 'pluie', 'terrain', 'vent', 'ventDos']);
  assert.equal(m.pluie, kept.pluie);
  assert.equal(m.vent, kept.vent);
  assert.deepEqual(jourJ.next.meteo, m, 'même annonce le jour du match');
  run('validateCareer(S)');
});

test('Un seul courrier « Bulletin météo » (routine de la veille), qui ouvre la composition', () => {
  const mails = etat("S.clubMail.mails.filter(x=>x.type==='meteo')");
  assert.equal(mails.length, 1, 'une fois par match');
  assert.equal(mails[0].date, veille.meta.calendarToday);
  const vu = jourJ.clubLife.clubMail.mails.find(x => x.type === 'meteo');
  assert.equal(vu.ecran, 'Composition');
  // Routine (18/11/2026) : n'arrête pas « Continuer » à lui seul, rangé dans l'arrêt « veille » du jour.
  assert.equal(vu.nature, 'routine');
  assert.equal(vu.arret, false);
  assert.match(vu.sujet, /Bulletin météo/);
  assert.match(vu.corps, new RegExp(veille.next.meteo.libelle));
  assert.ok(vu.reponses.some(r => r.ouvrir && r.disponible), 'réponse qui ouvre la composition');
});

test('Tirage sans aléa : même prévision, aléa du moteur intact', () => {
  const seed = jeu.bridge.vm.seed();
  const a = etat('CDWorldCareer.meteoPrevue(S,CDWorldCareer.userFixture(S))'), b = etat('CDWorldCareer.meteoPrevue(S,CDWorldCareer.userFixture(S))');
  assert.deepEqual(a, b);
  assert.equal(jeu.bridge.vm.seed(), seed, 'aucun Math.random consommé');
  // Même loi que le tirage du coup d'envoi : Sec 1/2, Pluie 1/4, Vent 1/4.
  const n = etat("Array.from({length:4000},(_,i)=>CDWorldCareer.meteoPrevue(S,{id:'t'+i,date:'2026-10-03',homeId:1,awayId:2}).weather)")
    .reduce((t, w) => (t[w]++, t), { Sec: 0, Pluie: 0, Vent: 0 });
  assert.ok(Math.abs(n.Sec / 4000 - 0.5) < 0.04 && Math.abs(n.Pluie / 4000 - 0.25) < 0.04 && Math.abs(n.Vent / 4000 - 0.25) < 0.04, JSON.stringify(n));
});

test('Ancienne sauvegarde arrivée à la veille : l’annonce est fixée à la commande suivante', () => {
  const kept = etat('S.worldMode.meteo');
  run('delete S.worldMode.meteo');
  assert.equal(jeu.call('snapshot').next.meteo, undefined, 'lecture seule : rien n’est écrit');
  jeu.call('auto_lineup');
  assert.deepEqual(etat('S.worldMode.meteo'), kept, 'même annonce recalculée');
});

test('Coup d’envoi : la météo annoncée est celle du match, vent compris ; rien ne bouge ensuite', () => {
  // Annonce de grand vent (dans le dos de l'extérieur en 1re période) pour vérifier aussi le sens du vent.
  run("Object.assign(S.worldMode.meteo,{weather:'Vent',pluie:0,vent:2,chaleur:0,terrain:'souple',sens:1});validateCareer(S)");
  const annonce = jeu.call('snapshot').next?.meteo;
  assert.ok(annonce, 'annonce projetée');
  assert.deepEqual(annonce.ventDos, [1, 0]);
  assert.equal(annonce.libelle, 'grand vent');
  let m = jourJ;
  if (!m.selection.valid) m = jeu.call('auto_lineup');
  m = jeu.call('begin_match');
  assert.equal(etat('S.live.weather'), 'Vent');
  assert.deepEqual(etat('S.live.meteo'), { pluie: 0, vent: 2, chaleur: 0, terrain: 'souple', sens: 1 });
  const { date, ...attendu } = annonce;
  assert.deepEqual(m.live.meteo, attendu, 'même format et mêmes valeurs que l’annonce');
  // Rencontre commencée : l'annonce n'est plus réécrite.
  run("S.worldMode.meteo.weather='Sec';S.worldMode.meteo.vent=0");
  assert.equal(etat('CDWorldCareer.fixerMeteo(S)'), null);
  assert.equal(etat('S.live.weather'), 'Vent');
});
