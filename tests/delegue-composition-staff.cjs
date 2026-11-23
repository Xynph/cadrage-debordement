'use strict';
// Match délégué et feuille de match (carrière Monde, club 102, graine 4242, cadence hebdomadaire).
// Constat (PR #707) : une feuille jamais modifiée épuise l'équipe quand on délègue tous ses matchs
// (condition au coup d'envoi 35 % après 14 journées, Toulouse 3-0-11) ; avec la sélection du staff : 98 %.
// Règles vérifiées ici :
//  1. « Confier aussi la composition au staff » cochée (défaut) : begin_match { delegated, composition }
//     refait la feuille du jour avec la sélection automatique ; condition moyenne au coup d'envoi > 85 %
//     sur 10 journées ; le choix est mémorisé dans la carrière (decisions.delegation.matchLineup).
//  2. Décochée : la feuille du joueur reste inchangée (même XV, même banc), choix mémorisé aussi.
//  3. Alerte de Gabi : selection.fatigue apparaît dès qu'un titulaire de la feuille est sous 70 % de
//     condition, avec le meilleur remplaçant frais au poste ; les changements proposés sont valides
//     (set_lineup accepté, feuille valide), jamais un joueur déjà titulaire, et ils règlent l'alerte.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

const JOURNEES = 10;
const moyenne = liste => liste.reduce((a, b) => a + b, 0) / liste.length;
// Condition moyenne des 15 titulaires au coup d'envoi (feuille du match en cours).
const CONDITION_COUP_D_ENVOI = '(()=>{const l=S.live,t=club();const on=l.sheets[l.userSide].on;return on.map(id=>t.players.find(p=>p.id===id).condition)})()';
const FEUILLE = 'JSON.stringify({lineup:S.lineup.slice(),bench:S.reserves.slice()})';

function preparer(jeu, model) {
  model = jeu.regler(model);
  if (!model.selection.valid) model = jeu.call('auto_lineup');
  if (!model.selection.valid) model = jeu.call('promote_cover', { confirmed: true });
  return model;
}

test('Délégation : case « Confier aussi la composition au staff » cochée, la feuille est refaite chaque journée', () => {
  const jeu = M.ouvrir({ hebdomadaire: true, testVm: true });
  try {
    let model = M.creer(jeu);
    assert.equal(model.decisions.delegation.matchLineup, true, 'cochée par défaut dans une nouvelle carrière');
    assert.equal(jeu.bridge.vm.run('S.manager.delegation.matchLineup'), undefined, 'champ absent de la sauvegarde tant que le joueur n’a rien choisi');
    const conditions = [];
    let feuillesDifferentes = 0, precedente = null;
    for (let w = 0; w < 30 && conditions.length < JOURNEES; w++) {
      model = preparer(jeu, model);
      if (model.next) {
        model = jeu.call('begin_match', { delegated: true, composition: true });
        assert.ok(model.live, 'coup d’envoi donné');
        assert.equal(model.decisions.delegation.matchLineup, true, 'choix mémorisé');
        const feuille = jeu.bridge.vm.run(FEUILLE);
        if (precedente && precedente !== feuille) feuillesDifferentes++;
        precedente = feuille;
        const c = jeu.bridge.vm.run(CONDITION_COUP_D_ENVOI);
        assert.equal(c.length, 15);
        conditions.push(moyenne(c));
        model = skipMatchTalk(jeu.call('delegate'), jeu.call);
      }
      model = jeu.call('finish_round');
    }
    assert.equal(conditions.length, JOURNEES, 'dix journées jouées');
    const detail = conditions.map(x => x.toFixed(0)).join(' ');
    console.log(`feuille confiée au staff : condition au coup d'envoi par journée : ${detail} ; moyenne ${moyenne(conditions).toFixed(1)} %`);
    assert.ok(moyenne(conditions) > 85, 'condition moyenne au coup d’envoi > 85 % (' + detail + ')');
    assert.ok(feuillesDifferentes >= 3, 'le staff fait tourner : feuilles différentes d’une journée à l’autre (' + feuillesDifferentes + ')');
    assert.equal(jeu.bridge.vm.run('S.manager.delegation.lineup'), false, 'le réglage permanent « sélection des 23 » n’est pas modifié');
    assert.equal(jeu.bridge.vm.run('S.manager.delegation.matchLineup'), true, 'choix compact mémorisé dans la carrière');
  } finally { jeu.fermer(); }
});

test('Délégation : case décochée, la feuille du joueur reste inchangée ; alerte de fatigue sous 70 % et conseil valide', () => {
  const jeu = M.ouvrir({ hebdomadaire: true, testVm: true });
  try {
    let model = M.creer(jeu);
    assert.equal(model.selection.fatigue, undefined, 'début de carrière : groupe frais, aucune alerte');
    let alertes = 0, verifie = false;
    for (let w = 0; w < 30 && alertes < 1; w++) {
      model = preparer(jeu, model);
      if (!model.next) { model = jeu.call('finish_round'); continue; }
      const avant = jeu.bridge.vm.run(FEUILLE);
      const fatigue = model.selection.fatigue;
      if (fatigue) {
        alertes++;
        // Alerte : seuil 70 %, titulaires de la feuille actuelle, changements valides.
        assert.equal(fatigue.threshold, 70);
        assert.ok(fatigue.count >= 1 && fatigue.starters.length === fatigue.count);
        const feuille = JSON.parse(avant), titulaires = new Set(feuille.lineup);
        for (const s of fatigue.starters) {
          assert.ok(s.condition < 70, 'titulaire signalé sous 70 % : ' + s.condition);
          assert.equal(feuille.lineup[s.slot], s.playerId);
        }
        assert.ok(fatigue.changes.length + fatigue.unresolved.length === fatigue.count, 'chaque titulaire fatigué a un remplaçant ou est signalé sans solution');
        for (const c of fatigue.changes) {
          assert.ok(!titulaires.has(c.playerId), 'jamais un joueur déjà titulaire');
          assert.ok(c.entrantCondition >= 75 && c.entrantCondition >= c.condition + 10, 'remplaçant frais');
          assert.ok(c.rating >= 40, 'à son aise au poste');
          assert.equal(feuille.lineup[c.slot], c.sortant);
        }
        // Suivre le conseil : mêmes commandes que Gabi (set_lineup), feuille toujours valide, alerte réduite.
        let apres = model;
        for (const c of fatigue.changes) apres = jeu.call('set_lineup', { playerId: c.playerId, slot: c.slot });
        if (fatigue.changes.length) {
          assert.equal(apres.selection.valid, true, 'feuille valide après avoir suivi le conseil : ' + JSON.stringify(apres.selection.errors));
          const reste = apres.selection.fatigue?.count ?? 0;
          assert.ok(reste <= fatigue.count - fatigue.changes.length, 'l’alerte est réglée pour les remplacés (' + reste + ' restant)');
          for (const c of fatigue.changes) assert.equal(jeu.bridge.vm.run(`S.lineup[${c.slot}]`), c.playerId);
          verifie = true;
        }
        model = apres;
        console.log(`alerte de fatigue à la journée ${w} : ${fatigue.count} titulaire(s) sous 70 %, ${fatigue.changes.length} conseil(s), ${fatigue.unresolved.length} sans solution`);
        break;
      }
      // Case décochée : le coup d'envoi ne touche pas à la feuille du joueur.
      model = jeu.call('begin_match', { delegated: true, composition: false });
      assert.equal(model.decisions.delegation.matchLineup, false, 'choix décoché mémorisé');
      const surLeTerrain = jeu.bridge.vm.run('(()=>{const l=S.live;return JSON.stringify(l.sheets[l.userSide].on)})()');
      assert.equal(surLeTerrain, JSON.stringify(JSON.parse(avant).lineup), 'feuille inchangée au coup d’envoi');
      assert.equal(jeu.bridge.vm.run(FEUILLE), avant, 'feuille du joueur inchangée');
      model = skipMatchTalk(jeu.call('delegate'), jeu.call);
      model = jeu.call('finish_round');
    }
    assert.ok(alertes >= 1, 'l’alerte de fatigue se déclenche quand la feuille n’est jamais refaite');
    assert.ok(verifie, 'au moins un conseil a été suivi et validé');
  } finally { jeu.fermer(); }
});

test('Délégation : paramètres invalides refusés, ancien format de sauvegarde toléré', () => {
  const jeu = M.ouvrir({ hebdomadaire: true });
  try {
    let model = M.creer(jeu);
    model = preparer(jeu, model);
    if (!model.next) model = M.jusquAuMatch(jeu, model);
    for (const payload of [{ delegated: 'oui' }, { composition: true }, { delegated: true, composition: 1 }, { delegated: false, composition: false }]) {
      const r = jeu.brut('begin_match', payload);
      assert.equal(r.ok, false, JSON.stringify(payload) + ' refusé');
    }
    assert.equal(jeu.brut('snapshot').model.decisions.delegation.matchLineup, true, 'refus : rien n’est mémorisé');
  } finally { jeu.fermer(); }
});
