'use strict';
// Feuille de statistiques réaliste (native/engine/match-stats.cjs) : déterminisme sans tirage du moteur,
// préfixe (entracte borné), cohérence avec le journal et les chiffres du moteur, fourchettes par poste.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const MS = require('../native/engine/match-stats.cjs');
const { simuler, mesurer } = require('../scripts/stats-match-validation.cjs');

const MATCHS = simuler(40);
const COMPTES = ['courses', 'metres', 'plaquages', 'plaquagesManques', 'passes', 'soutiensRuck', 'coupsDePied', 'essais', 'points', 'franchissements', 'minutes'];

test('Déterministe : même rencontre et même journal, même feuille ; aucun tirage du moteur', () => {
  const m = MATCHS[0];
  const a = MS.feuilleStatistiques(m.events, { cle: m.cle, joueurs: m.joueurs });
  const b = MS.feuilleStatistiques(JSON.parse(JSON.stringify(m.events)), { cle: m.cle, joueurs: m.joueurs });
  assert.deepEqual(a, b);
  // Autre graine : la routine change, les faits du journal non.
  const c = MS.feuilleStatistiques(m.events, { cle: m.cle + ':autre', joueurs: m.joueurs });
  assert.notDeepEqual(a.joueurs, c.joueurs);
  for (const s of [0, 1]) for (const champ of ['essais', 'points', 'franchissements', 'enAvant', 'penalitesConcedees', 'cartonsJaunes', 'recuperations'])
    assert.equal(a.equipes[s][champ], c.equipes[s][champ], champ);
  // Le module ne lit ni ne modifie le générateur du moteur (Math.random) : le match reste le même.
  const source = fs.readFileSync(path.join(__dirname, '../native/engine/match-stats.cjs'), 'utf8');
  assert.equal(/Math\.random/.test(source), false);
});

test('Préfixe : la feuille bornée (entracte) ne fait que croître et rejoint la feuille finale', () => {
  for (const m of MATCHS.slice(0, 3)) {
    const finale = MS.feuilleStatistiques(m.events, { cle: m.cle, joueurs: m.joueurs });
    assert.equal(finale.fini, true);
    let avant = null;
    for (let borne = 0; borne <= m.events.length; borne += 7) {
      const f = MS.feuilleStatistiques(m.events, { cle: m.cle, joueurs: m.joueurs, borne });
      assert.equal(f.faits, borne);
      if (avant) for (const s of [0, 1]) for (const champ of COMPTES) assert.ok(f.equipes[s][champ] >= avant.equipes[s][champ], `${champ} ne recule pas (borne ${borne})`);
      avant = f;
    }
    assert.deepEqual(MS.feuilleStatistiques(m.events, { cle: m.cle, joueurs: m.joueurs, borne: m.events.length }), finale);
  }
});

test('Cohérence : équipe = somme des joueurs, faits du journal et chiffres du moteur repris tels quels', () => {
  for (const m of MATCHS) {
    const f = MS.feuilleStatistiques(m.events, { cle: m.cle, joueurs: m.joueurs });
    const scenes = m.events.map(e => e.scene).filter(Boolean);
    for (const s of [0, 1]) {
      const e = f.equipes[s], joueurs = Object.values(f.joueurs).filter(j => j.camp === s);
      for (const champ of MS.CHAMPS_JOUEUR) assert.equal(e[champ], joueurs.reduce((n, j) => n + j[champ], 0), `${champ} = somme des joueurs`);
      assert.equal(e.points, m.score[s], 'points = score');
      assert.equal(e.essais, m.tries[s], 'essais = essais du moteur');
      assert.equal(e.penalitesConcedees, m.stats[s].penalties, 'pénalités concédées = moteur');
      assert.equal(e.touches.lancers, m.stats[s].lineouts, 'touches = moteur');
      assert.equal(e.touches.gagnees, m.stats[s].lineoutsWon, 'touches gagnées = moteur');
      assert.equal(e.melees.introductions, m.stats[s].scrums, 'mêlées = moteur');
      assert.equal(e.transformations, m.stats[s].conversions, 'transformations = moteur');
      assert.equal(e.penalitesReussies, m.stats[s].goals, 'pénalités réussies = moteur');
      const carries = scenes.filter(x => x.kind === 'carry' && x.team === s && Number.isFinite(x.from?.x) && Number.isFinite(x.to?.x));
      assert.equal(e.franchissements, carries.filter(x => Math.abs(x.to.x - x.from.x) >= 22).length, 'franchissements = courses de 22 m et plus');
      assert.equal(e.enAvant, scenes.filter(x => x.kind === 'hand-fault' && x.team === s).length, 'en-avant = journal');
      assert.equal(e.cartonsJaunes, scenes.filter(x => x.kind === 'card' && x.incident === true && x.team === s && x.card !== 'red').length);
      // Défense : plaquages ≈ courses adverses (plaquages à deux compris), au moins un par course racontée stoppée.
      const adverses = scenes.filter(x => x.kind === 'carry' && x.team === 1 - s && Math.abs(x.to.x - x.from.x) < 22).length;
      assert.ok(e.plaquages >= adverses);
      const ratio = e.plaquages / f.equipes[1 - s].courses;
      assert.ok(ratio > .9 && ratio < 1.4, `plaquages / courses adverses = ${ratio.toFixed(2)}`);
      assert.equal(e.plaquagesManques, f.equipes[1 - s].defenseursBattus, 'plaquages manqués = défenseurs battus adverses');
      // Le plaqueur nommé par le moteur est bien crédité.
      for (const x of scenes.filter(x => x.kind === 'carry' && x.team === 1 - s && x.tackler != null && Math.abs(x.to.x - x.from.x) < 22)) assert.ok(f.joueurs[String(x.tackler)]?.plaquages >= 1);
      // Minutes : pas plus que la durée, quinze joueurs à la fois au plus.
      assert.ok(joueurs.every(j => j.minutes <= f.minute + 1));
      assert.ok(joueurs.reduce((n, j) => n + j.minutes, 0) <= 15 * (f.minute + 1));
    }
  }
});

test('Fourchettes réalistes par poste et par équipe (40 matchs)', () => {
  const r = mesurer(MATCHS);
  const p = Object.fromEntries(r.poste.map(x => [x.poste, x]));
  const dans = (v, a, b, quoi) => assert.ok(v >= a && v <= b, `${quoi} : ${v} hors [${a}, ${b}]`);
  dans(r.equipe.plaquages, 115, 160, 'plaquages par équipe');
  dans(r.equipe.plaquagesManques, 12, 26, 'plaquages manqués par équipe');
  dans(r.equipe.courses, 100, 140, 'courses par équipe');
  dans(r.equipe.metres, 350, 600, 'mètres par équipe');
  dans(r.equipe.passes, 120, 180, 'passes par équipe');
  dans(r.equipe.rucks, 70, 110, 'rucks par équipe');
  dans(r.equipe.coupsDePied, 17, 32, 'coups de pied par équipe');
  dans(p.Ailiers.plaquages, 3, 7, 'plaquages d’un ailier');
  dans(p.Flankers.plaquages, 11, 19, 'plaquages d’un flanker');
  dans(p['N° 8'].courses, 9, 15, 'courses d’un numéro 8');
  dans(p['Demi de mêlée'].passes, 45, 75, 'passes d’un demi de mêlée');
  dans(p['Demi d’ouverture'].coupsDePied, 7, 14, 'coups de pied d’un demi d’ouverture');
  dans(p.Ailiers.metres, 35, 70, 'mètres d’un ailier');
  dans(p.Piliers.metres, 8, 25, 'mètres d’un pilier');
  // Variance d'un match à l'autre : un ailier titulaire ne fait plus « 0 ou 1 plaquage ».
  const [bas, haut] = p.Ailiers.plaquagesP10P90;
  assert.ok(bas >= 1 && haut >= 6 && haut <= 12, `ailiers P10-P90 = ${bas}-${haut}`);
  assert.equal(r.ecartsPoints.length, 0, 'points des joueurs = score');
});

test('Entrées dégradées : journal vide, sans attributs, ancienne sauvegarde sans `tackler`', () => {
  const vide = MS.feuilleStatistiques([], {});
  assert.deepEqual(vide.joueurs, {});
  assert.equal(vide.equipes[0].plaquages, 0);
  const m = MATCHS[1];
  const sansAttributs = MS.feuilleStatistiques(m.events, { cle: m.cle });
  const sansTackler = MS.feuilleStatistiques(m.events.map(e => e.scene ? { ...e, scene: { ...e.scene, tackler: undefined } } : e), { cle: m.cle });
  for (const f of [sansAttributs, sansTackler]) for (const s of [0, 1]) assert.equal(f.equipes[s].points, m.score[s]);
  assert.ok(MS.lignesEquipe(sansAttributs).some(l => l.label === 'Plaquages réussis'));
  assert.equal(MS.resumeJoueur(sansAttributs, 'inconnu'), null);
});
