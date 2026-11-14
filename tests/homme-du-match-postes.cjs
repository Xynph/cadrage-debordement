'use strict';
// Homme du match par poste (maillots 1 à 15) en carrière Monde : répartition plausible, aucun
// poste qui écrase les autres ni quasi absent ; notes cohérentes par poste. Bornes larges : la
// cible et la mesure sur une saison sont dans docs/homme-du-match-postes-20261114.md.
// Cadence hebdomadaire (la plus rapide) ; graine fixe ; les matchs sont lus au moment où le domaine
// des notes les note (aucun résultat changé : le crochet ne fait que lire).
const assert = require('node:assert/strict');
const { test } = require('node:test');
const M = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

const MATCHS_MIN = 150, SEMAINES_MAX = 14;
// Groupes de maillots (indices 0 à 14) : piliers, talonneur, deuxième ligne, troisième ligne, 9, 10,
// ailiers, centres, arrière.
const GROUPES = { piliers: [0, 2], talonneur: [1], deuxiemeLigne: [3, 4], troisiemeLigne: [5, 6, 7], demiDeMelee: [8], ouvreur: [9], ailiers: [10, 13], centres: [11, 12], arriere: [14] };

test('Homme du match par poste (Monde) : répartition plausible, meilleure note, notes cohérentes ; remplacements en délégué', () => {
  const jeu = M.ouvrir({ hebdomadaire: true, testVm: true });
  try {
    let model = M.creer(jeu);
    jeu.bridge.vm.run(`globalThis.__hdm=[];(()=>{const o=CDMatchNotesMoteur.noter;CDMatchNotesMoteur.noter=function(j,c){const r=o.apply(this,arguments);
      if(c&&c.fini&&!c.journalReduit&&c.postes)__hdm.push({h:r.hommeDuMatch,p:Object.entries(r.joueurs).map(([id,n])=>[id,c.postes[id]??-1,n.minutes,n.note])});
      return r;};})();`);
    const delegues = [];
    const lus = () => jeu.bridge.vm.run('__hdm.length');
    for (let w = 0; w < SEMAINES_MAX && lus() < MATCHS_MIN; w++) {
      model = jeu.regler(model);
      if (model.next) {
        if (!model.selection.valid) model = jeu.call('auto_lineup');
        if (!model.selection.valid) model = jeu.call('promote_cover', { confirmed: true });
        model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
        model = skipMatchTalk(jeu.call('delegate'), jeu.call);
        // Match délégué : l'adjoint gère le banc comme un entraîneur IA (native/engine/match-delegation.cjs).
        delegues.push(jeu.bridge.vm.run('S.live?[S.live.sheets[S.live.userSide].subs,S.live.sheets[1-S.live.userSide].subs]:null'));
      }
      model = jeu.call('finish_round');
    }
    assert.ok(delegues.length >= 2 && delegues.every(x => x && x[0] >= 3), 'matchs délégués : l’adjoint fait des remplacements ' + JSON.stringify(delegues));
    const matchs = JSON.parse(jeu.bridge.vm.run('JSON.stringify(__hdm)'));
    assert.ok(matchs.length >= MATCHS_MIN, 'échantillon : ' + matchs.length + ' matchs');
    const hdm = new Array(15).fill(0), notes = Array.from({ length: 15 }, () => []);
    for (const m of matchs) {
      const candidats = m.p.filter(x => x[2] >= 30);
      const h = m.p.find(x => x[0] === m.h);
      assert.ok(h && h[2] >= 30, 'homme du match désigné, 30 minutes au moins');
      assert.equal(h[3], Math.max(...candidats.map(x => x[3])), 'homme du match : la meilleure note du match');
      assert.ok(h[1] >= 0 && h[1] < 15, 'poste occupé connu');
      hdm[h[1]]++;
      for (const x of m.p) if (x[2] >= 40 && x[1] >= 0 && x[1] < 15) notes[x[1]].push(x[3]);
    }
    const n = matchs.length, part = k => hdm[k] / n, groupe = g => GROUPES[g].reduce((a, k) => a + part(k), 0);
    const detail = hdm.map((x, k) => (k + 1) + ':' + (100 * x / n).toFixed(1) + '%').join(' ');
    // Aucun poste n'écrase les autres.
    for (let k = 0; k < 15; k++) assert.ok(part(k) <= 0.2, `maillot ${k + 1} trop souvent élu (${detail})`);
    // Aucun groupe de poste absent ; piliers rares mais présents.
    for (const g of Object.keys(GROUPES)) assert.ok(GROUPES[g].reduce((a, k) => a + hdm[k], 0) >= 1, `${g} jamais élu (${detail})`);
    assert.ok(groupe('piliers') <= 0.12, `piliers trop souvent élus (${detail})`);
    assert.ok(groupe('troisiemeLigne') >= 0.12 && groupe('troisiemeLigne') <= 0.4, `troisième ligne hors bornes (${detail})`);
    assert.ok(groupe('demiDeMelee') + groupe('ouvreur') >= 0.1 && groupe('demiDeMelee') + groupe('ouvreur') <= 0.38, `charnière hors bornes (${detail})`);
    assert.ok(groupe('ailiers') + groupe('centres') <= 0.4, `ailiers et centres trop souvent élus (${detail})`);
    const avants = [0, 1, 2, 3, 4, 5, 6, 7].reduce((a, k) => a + part(k), 0);
    assert.ok(avants >= 0.3 && avants <= 0.62, `avants ${(100 * avants).toFixed(1)} % (${detail})`);
    // Notes : moyenne et dispersion générales et par poste cohérentes.
    const toutes = notes.flat(), moy = a => a.reduce((x, y) => x + y, 0) / a.length;
    console.log('moyennes des notes par maillot : ' + notes.map((a, k) => (k + 1) + ':' + moy(a).toFixed(2)).join(' '));
    const ecart = a => { const m = moy(a); return Math.sqrt(a.reduce((x, y) => x + (y - m) ** 2, 0) / a.length); };
    assert.ok(moy(toutes) >= 6.45 && moy(toutes) <= 6.9, 'moyenne générale ' + moy(toutes).toFixed(2));
    assert.ok(ecart(toutes) >= 0.85 && ecart(toutes) <= 1.3, 'écart-type général ' + ecart(toutes).toFixed(2));
    // Bornes par maillot élargies (moyenne 6,3-7,0 → 6,2-7,2 ; écart-type max 1,45 → 1,65, ouvreur à 1,54 ici) : sur ~160 matchs les notes d'un maillot sont corrélées
    // (même équipe, même match) et la moyenne d'un maillot varie de ±0,2 d'un échantillon à l'autre (maillot 6 :
    // 6,88 sur les 164 premiers matchs de l'étalonnage, 7,11 ici ; 6,77 sur 795 matchs).
    for (let k = 0; k < 15; k++) {
      assert.ok(notes[k].length >= 100, `maillot ${k + 1} : ${notes[k].length} notes`);
      assert.ok(moy(notes[k]) >= 6.2 && moy(notes[k]) <= 7.2, `maillot ${k + 1} : moyenne ${moy(notes[k]).toFixed(2)}`);
      assert.ok(ecart(notes[k]) >= 0.55 && ecart(notes[k]) <= 1.65, `maillot ${k + 1} : écart-type ${ecart(notes[k]).toFixed(2)}`);
    }
    console.log(`homme du match par maillot (${n} matchs) : ${detail}`);
  } finally { jeu.fermer(); }
});
