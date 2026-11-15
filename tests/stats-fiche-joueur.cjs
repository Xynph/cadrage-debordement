'use strict';
// Statistiques de la fiche joueur (14 novembre 2026, retour de Léo : « les stats d'un joueur ne
// ressemblent pas à de vraies stats » — ailier titulaire : 0 à 3 plaquages, 0 à 28 m par match).
// Une seule source de vérité : la feuille réaliste (native/engine/match-stats.cjs), celle de l'écran
// de match, enregistrée pour tous les matchs notés (manager et IA). Carrière Monde uniquement.
// Voir docs/stats-fiche-joueur-20261114.md.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const N = require('../native/engine/match-notes.cjs');
const MS = require('../native/engine/match-stats.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

// Journées jouées par défaut (4 : assez de titulaires par poste pour les bornes ; la saison complète, 26 journées, se lance avec CD_STATS_JOURNEES=26, ~50 minutes).
const JOURNEES = Number(process.env.CD_STATS_JOURNEES || 4);

// Groupes de postes (libellés du jeu) et bornes réalistes par 80 minutes (titulaire) : plaquages,
// mètres, essais par match. Références : docs/stats-match-realistes-20261113.md et la demande de Léo
// (ailier 3–8 plaquages, 40–120 m, ~0,3–0,5 essai ; troisième ligne 10–20 plaquages).
const GROUPES = {
  'Pilier': { postes: ['Pilier gauche', 'Pilier droit', 'Pilier'], plaquages: [5, 11], metres: [6, 30], essais: [0, 0.2] },
  'Talonneur': { postes: ['Talonneur'], plaquages: [7, 14], metres: [8, 30], essais: [0, 0.25] },
  'Deuxième ligne': { postes: ['Deuxième ligne'], plaquages: [8, 15], metres: [8, 35], essais: [0, 0.2] },
  'Troisième ligne': { postes: ['Troisième ligne', 'Troisième ligne aile', 'Numéro 8', 'Aile forward'], plaquages: [10, 20], metres: [15, 60], essais: [0.03, 0.35] },
  'Demi de mêlée': { postes: ['Demi de mêlée'], plaquages: [3, 9], metres: [8, 40], essais: [0, 0.35] },
  'Demi d’ouverture': { postes: ['Demi d’ouverture', "Demi d'ouverture"], plaquages: [4, 10], metres: [12, 45], essais: [0, 0.35] },
  'Centre': { postes: ['Centre'], plaquages: [6, 12], metres: [30, 80], essais: [0.08, 0.5] },
  'Ailier': { postes: ['Ailier'], plaquages: [3, 8], metres: [40, 120], essais: [0.15, 0.7] },
  'Arrière': { postes: ['Arrière'], plaquages: [3, 8], metres: [40, 120], essais: [0.1, 0.6] },
};
const groupe = pos => Object.keys(GROUPES).find(g => GROUPES[g].postes.includes(String(pos || '').replace(/'/g, '’')) || GROUPES[g].postes.includes(String(pos || '')));

test('Feuille dans les notes : chiffres de la feuille, apport à somme nulle, base 6,5 conservée', () => {
  const on = [Array.from({ length: 15 }, (_, k) => 'a' + (k + 1)), Array.from({ length: 15 }, (_, k) => 'b' + (k + 1))];
  const ev = (min, kind, team, actor, extra = {}) => ({ min, type: kind, text: kind, scene: { kind, team, possession: team, actor, on, from: { x: 40, y: 30 }, to: { x: 46, y: 30 }, score: [0, 0], ...extra } });
  const journal = [];
  for (let m = 0; m < 80; m++) {
    journal.push(ev(m, 'carry', m % 2, (m % 2 ? 'b' : 'a') + (1 + (m * 7) % 15)));
    if (m === 30) journal.push(ev(m, 'try', 0, 'a14', { origin: 'open', conversion: true, score: [7, 0] }));
  }
  journal.push(ev(80, 'end', null, null));
  const feuille = MS.feuilleStatistiques(journal, { cle: 'test' });
  const apports = MS.apportsNote(feuille);
  for (const camp of [0, 1]) {
    const ids = Object.keys(feuille.joueurs).filter(id => feuille.joueurs[id].camp === camp);
    const somme = ids.reduce((a, id) => a + apports[id], 0);
    assert.ok(Math.abs(somme) < 0.6, 'apport proche de zéro par équipe (bornes comprises) : ' + somme);
    for (const id of ids) assert.ok(Math.abs(apports[id]) <= 0.9);
  }
  const cotes = {}, minutes = {};
  for (const camp of [0, 1]) for (const id of on[camp]) { cotes[id] = camp; minutes[id] = 80; }
  const sans = N.noter(journal, { cotes, minutes, score: [7, 0], fini: true });
  const avec = N.noter(journal, { cotes, minutes, score: [7, 0], fini: true, feuille, apports });
  for (const id of Object.keys(cotes)) {
    const f = feuille.joueurs[id];
    assert.equal(avec.joueurs[id].plaquages, f.plaquages, 'plaquages de la feuille');
    assert.equal(avec.joueurs[id].metres, f.metres, 'mètres de la feuille');
    assert.equal(avec.joueurs[id].passes, f.passes, 'passes de la feuille');
    assert.equal(avec.joueurs[id].essais, f.essais, 'essais de la feuille');
  }
  assert.equal(avec.joueurs.a14.essais, 1, 'le marqueur du journal');
  const moyenne = r => Object.values(r.joueurs).reduce((a, n) => a + n.note, 0) / 30;
  assert.ok(Math.abs(moyenne(avec) - moyenne(sans)) < 0.15, 'moyenne des notes inchangée à 0,15 près : ' + moyenne(sans) + ' → ' + moyenne(avec));
  // Un joueur qui fait nettement plus que son poste (plaquages, mètres) gagne en note.
  const top = Object.keys(apports).sort((x, y) => apports[y] - apports[x])[0];
  assert.ok(avec.joueurs[top].note >= sans.joueurs[top].note, 'apport positif : note en hausse');
});

test('Saison Monde : stats de la fiche réalistes par poste, essais des joueurs = essais des matchs, direct = fiche', { timeout: 3 * 60 * 60 * 1000 }, () => {
  const jeu = M.ouvrir({ hebdomadaire: true, testVm: true });
  try {
    const vm = jeu.bridge.vm;
    // Relevé de chaque match noté (manager et IA), sans effet : le calcul de la note enregistrée est pur.
    vm.run(`globalThis.__releves=[];{const f=recordDevelopmentMatch,w=function(l){if(l&&l.finished&&!l.developmentRecorded&&!l.matchNotesRecorded){const r=CDMatchNotes.noterMatch(l),e=[0,0],p=[0,0];for(const n of Object.values(r.joueurs)){e[n.cote]+=n.essais;p[n.cote]+=n.points||0;}__releves.push({pair:l.pair.slice(),score:l.score.slice(),tries:(l.tries||[]).slice(),essais:e,points:p,manager:l.userSide>=0,journal:(l.userSide>=0?l.events:(l.notesJournal||[])).length});}return f.apply(this,arguments);};Object.assign(w,f);recordDevelopmentMatch=w;}`);
    let model = M.creer(jeu, 0);
    let directVerifie = false;
    for (let j = 0; j < JOURNEES; j++) {
      if (!directVerifie) {
        // Première journée en direct : la feuille de fin de match est celle enregistrée sur la fiche.
        model = M.jusquAuMatch(jeu, model);
        model = M.jouerLeMatch(jeu, model, { delegue: false });
        for (let k = 0; k < 500 && !model.live.finished; k++) {
          if (model.clubLife?.matchTalks?.scene) { model = skipMatchTalk(model, jeu.call); continue; }
          model = jeu.call('tick', { minute: true, temps_forts: 'aucun' });
        }
        let direct = model.live.direct;
        for (let k = 0; k < 60 && direct.borne < model.live.events.length; k++) { model = jeu.call('tick', { minute: true, temps_forts: 'aucun' }); direct = model.live.direct; }
        const camp = direct.camp, feuille = direct.feuille, notesDirect = direct.notes;
        model = skipMatchTalk(model, jeu.call);
        if (model.live) model = jeu.call('finish_round');
        model = M.jusquALaSemaineSuivante(jeu, jeu.regler(model));
        const fiche = model.clubLife.matchNotes.joueurs;
        let n = 0;
        for (const [id, f] of Object.entries(feuille.joueurs)) {
          if (f.camp !== camp || !fiche[id] || f.minutes <= 0) continue;
          const h = fiche[id].historique[0];
          assert.equal(h.plaquages, f.plaquages, 'plaquages fiche = écran de match (' + id + ')');
          assert.equal(h.metres, f.metres, 'mètres fiche = écran de match');
          assert.equal(h.passes, f.passes, 'passes fiche = écran de match');
          assert.equal(h.essais, f.essais, 'essais fiche = écran de match');
          assert.equal(h.note, notesDirect[id].note, 'note fiche = note du direct');
          assert.equal(notesDirect[id].plaquages, f.plaquages, 'Mon XV du direct = feuille');
          n++;
        }
        assert.ok(n >= 15, 'joueurs comparés : ' + n);
        directVerifie = true;
        continue;
      }
      model = M.jouer(jeu, model, 1);
    }
    const releves = JSON.parse(vm.run('JSON.stringify(__releves)'));
    assert.ok(releves.length >= JOURNEES * 7, 'matchs notés relevés : ' + releves.length);
    for (const r of releves) {
      assert.deepEqual(r.essais, r.tries, 'essais des joueurs = essais du match ' + r.pair.join('-'));
      assert.deepEqual(r.points, r.score, 'points des joueurs = score ' + r.pair.join('-'));
    }
    // Moyennes par poste, saison du monde entier (titulaires : 55 minutes ou plus par match en moyenne).
    const etat = JSON.parse(jeu.call('export').meta.exportText).state;
    const pos = new Map(); for (const c of etat.clubs) for (const p of c.players) pos.set(p.id, p.pos);
    const agg = {}, inconnus = new Set();
    for (const [id, j] of Object.entries(etat.matchNotes.joueurs)) {
      const [m, , minutes, essais, plaquages, metres] = j.s;
      if (m < Math.min(5, JOURNEES - 1) || minutes / m < 55 || j.s.length !== 11) continue;
      const g = groupe(pos.get(id)); if (!g) { inconnus.add(pos.get(id)); continue; }
      const a = agg[g] || (agg[g] = { joueurs: 0, minutes: 0, matchs: 0, essais: 0, plaquages: 0, metres: 0, manques: 0, passes: 0 });
      a.joueurs++; a.minutes += minutes; a.matchs += m; a.essais += essais; a.plaquages += plaquages; a.metres += metres; a.passes += j.s[7]; a.manques += j.s[9];
    }
    const tableau = {};
    for (const [g, a] of Object.entries(agg)) {
      const par80 = x => Math.round(x / a.minutes * 80 * 100) / 100;
      tableau[g] = { joueurs: a.joueurs, plaquages: par80(a.plaquages), manques: par80(a.manques), metres: par80(a.metres), passes: par80(a.passes), essaisParMatch: Math.round(a.essais / a.matchs * 100) / 100 };
    }
    if (inconnus.size) console.log('Postes non classés : ' + [...inconnus].join(', '));
    console.log('Moyennes par poste (par 80 min ; essais par match) :\n' + JSON.stringify(tableau, null, 1));
    for (const [g, b] of Object.entries(GROUPES)) {
      const t = tableau[g]; assert.ok(t && t.joueurs >= 10, g + ' : assez de titulaires');
    }
    for (const [g, b] of Object.entries(GROUPES)) {
      const t = tableau[g];
      assert.ok(t.plaquages >= b.plaquages[0] && t.plaquages <= b.plaquages[1], `${g} : ${t.plaquages} plaquages / 80 min hors [${b.plaquages}]`);
      assert.ok(t.metres >= b.metres[0] && t.metres <= b.metres[1], `${g} : ${t.metres} m / 80 min hors [${b.metres}]`);
      if (JOURNEES >= 10) assert.ok(t.essaisParMatch >= b.essais[0] && t.essaisParMatch <= b.essais[1], `${g} : ${t.essaisParMatch} essais / match hors [${b.essais}]`);
    }
    // Taille : les champs ajoutés restent compacts (entiers dans les tableaux existants).
    const texte = JSON.stringify(etat.matchNotes), joueurs = Object.keys(etat.matchNotes.joueurs).length;
    const ajout = Object.values(etat.matchNotes.joueurs).reduce((a, j) => a + JSON.stringify(j.s.slice(7)).length - 1, 0) + Object.values(etat.matchNotes.detail).reduce((a, d) => a + d.reduce((b, r) => b + JSON.stringify(r.slice(9)).length - 1, 0), 0);
    console.log(`Notes de match : ${(texte.length / 1024).toFixed(0)} Kio pour ${joueurs} joueurs ; champs ajoutés : ${(ajout / 1024).toFixed(0)} Kio`);
    assert.ok(ajout < 200 * 1024, 'moins de 200 Kio ajoutés sur une saison : ' + ajout);
    // Notes : base 6,5 conservée (moyenne générale des notes de la saison).
    const toutes = Object.values(etat.matchNotes.joueurs).filter(j => j.s[0] > 0);
    const moyenne = toutes.reduce((a, j) => a + j.s[1], 0) / toutes.reduce((a, j) => a + j.s[0], 0) / 10;
    console.log('Moyenne générale des notes : ' + moyenne.toFixed(2));
    assert.ok(moyenne > 6.2 && moyenne < 6.8, 'moyenne générale proche de 6,5 : ' + moyenne);
  } finally { jeu.fermer(); }
});
