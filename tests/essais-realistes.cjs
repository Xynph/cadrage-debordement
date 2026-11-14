'use strict';
// Essais réalistes (carrière Monde, moteur de match complet) : essais et points par match, marqueurs par
// poste et réussite au but dans des bornes larges (hiérarchie seulement affichée). Cibles et mesures sur une saison entière :
// docs/essais-realistes-20261114.md (scripts/mesure-essais-monde.cjs). Ici dix semaines (~300 matchs),
// graine fixe, les crochets ne font que lire (aucun tirage, aucun état de partie modifié).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { mesurer, analyser } = require('../scripts/mesure-essais-monde.cjs');

test('Essais réalistes (Monde) : volume d’essais, marqueurs par poste, buts plausibles', () => {
  const d = mesurer({ graine: 4242, club: 102, semaines: 10 });
  const a = analyser(d);
  assert.ok(a.matchs >= 200, 'échantillon : ' + a.matchs + ' matchs');
  const tous = a.lignes.find(l => l.comp === 'TOUS');
  const resume = JSON.stringify(a.lignes.map(l => [l.comp, l.matchs, l.essais, l.points]));
  // Ancien moteur : ~4 essais et ~31 points par match partout ; réel 2024-25 : 5,2 (Pro D2) à 8,6 (Japon, Championship).
  assert.ok(tous.essais >= 5 && tous.essais <= 8.5, 'essais par match ' + resume);
  assert.ok(tous.points >= 38 && tous.points <= 62, 'points par match ' + resume);
  assert.ok(tous.partEssais >= 55 && tous.partEssais <= 78, 'part des points sur essais ' + tous.partEssais);
  assert.ok(tous.zeroEssai <= 10, 'équipes sans essai ' + tous.zeroEssai + ' %');
  // Championnats : les plus ouverts (Japon, Championship, Premiership, Super Rugby) au-dessus du Top 14 et de la Pro D2.
  const ligne = c => a.lignes.find(l => l.comp === c);
  for (const c of ['elite', 'accession', 'nationale', 'urc', 'champ']) {
    const l = ligne(c); if (!l || l.matchs < 25) continue;
    assert.ok(l.essais >= 4 && l.essais <= 10, `${c} : ${l.essais} essais par match`);
  }
  const fermes = ['elite', 'accession'].map(ligne).filter(l => l && l.matchs >= 25), ouverts = ['champ', 'jlo-d1', 'prem', 'srp'].map(ligne).filter(l => l && l.matchs >= 25);
  if (fermes.length && ouverts.length) {
    const m = ls => ls.reduce((x, l) => x + l.essais * l.matchs, 0) / ls.reduce((x, l) => x + l.matchs, 0);
    assert.ok(m(ouverts) > m(fermes), 'championnats ouverts plus prolifiques ' + resume);
  }
  // Buts : pénalités et transformations autour de 70 à 75 % (réel), pas 50 %.
  assert.ok(tous.reussiteButs >= 58 && tous.reussiteButs <= 85, 'réussite au but ' + tous.reussiteButs);
  assert.ok(tous.transfo >= 58 && tous.transfo <= 85, 'transformations ' + tous.transfo);
  // Marqueurs : arrières environ deux essais sur trois, ailiers en tête, piliers et deuxième ligne rares.
  const g = a.parGroupe, detail = JSON.stringify(g) + ' ' + a.parMaillot.map(x => x.maillot + ':' + x.part).join(' ');
  assert.ok(g.ailiers >= 18 && g.ailiers <= 40, 'ailiers ' + detail);
  assert.ok(g.ailiers + g.centres >= 32 && g.ailiers + g.centres <= 60, 'ailiers et centres ' + detail);
  assert.ok(g.avants >= 20 && g.avants <= 45, 'avants ' + detail);
  for (const k of [0, 2, 3, 4]) assert.ok(a.parMaillot[k].part <= 5, `maillot ${k + 1} trop souvent marqueur (${detail})`);
  assert.ok(a.parMaillot[1].part >= 3, 'talonneur sur ballon porté ' + detail);
  for (const k of [10, 13]) assert.ok(a.parMaillot[k].part >= Math.max(...a.parMaillot.filter((x, i) => i < 8).map(x => x.part)), `ailier ${k + 1} au moins autant que chaque avant (${detail})`);
  assert.ok(a.ailierParMatch >= 0.25 && a.ailierParMatch <= 0.65, 'ailier titulaire : ' + a.ailierParMatch + ' essai par match');
  // Hiérarchie : mesurée sur une saison par scripts/mesure-essais-monde.cjs (défaut existant, voir la doc),
  // seulement affichée ici : sur dix semaines l'écart d'effectif d'un même championnat est trop faible
  // pour une borne stable.
  const h = a.hierarchie.find(x => x.comp === 'TOUS');
  console.log(`${a.matchs} matchs : ${tous.essais} essais, ${tous.points} points par match ; ailier titulaire ${a.ailierParMatch} ; favori selon l’effectif ${h.effectif1} ; ${detail}`);
});
