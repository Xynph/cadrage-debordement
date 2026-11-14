'use strict';
// Fiche d'un club (native/engine/club-sheet.cjs) :
//  1. XV le plus fréquent sur des feuilles connues : comptage par maillot, entrées depuis le banc,
//     attribution déterministe (ordre d'enregistrement indifférent, égalités départagées), format compact
//     validé, sauvegarde corrompue refusée ;
//  2. carrière Monde (mode unique) : les feuilles réelles du moteur sont comptées pour tous les clubs,
//     le XV type de la fiche est celui recalculé à partir des feuilles capturées, la fiche est en lecture
//     seule (aucun changement d'état), anciennes sauvegardes sans compteur → XV probable annoncé, clubs
//     suivis ; coût mesuré dans la sauvegarde.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const domaine = require('../native/engine/club-sheet.cjs');

function fauxMonde() {
  const clubs = [0, 1].map(id => ({ id, name: 'Club ' + id, players: Array.from({ length: 30 }, (_, k) => ({ id: 'c' + id + ':j' + k, name: 'J' + k })) }));
  return { season: 1, club: 0, clubs, history: [] };
}
// Feuille : quinze titulaires (identifiants par maillot) et entrées depuis le banc.
function match(s, titulaires, entrants = [], adverses = null) {
  const sheet = ids => ({ initial: ids, used: ids.concat(entrants), minutes: Object.fromEntries(ids.concat(entrants).map(id => [id, 20])) });
  const autre = adverses || Array.from({ length: 15 }, (_, k) => 'c1:j' + k);
  return { pair: [0, 1], sheets: [sheet(titulaires), { initial: autre, used: autre, minutes: {} }] };
}

test('XV le plus fréquent : feuilles connues, déterministe, format compact validé', () => {
  const base = Array.from({ length: 15 }, (_, k) => 'c0:j' + k);
  // j0 titulaire en 1 trois fois, j15 deux fois ; j3 joue en 4 (×3) et en 5 (×1) ; j4 en 5 (×3) ;
  // j16 en 9 (×2) contre j8 (×2), deux titularisations chacun : égalité départagée par l'identifiant (stable).
  const feuilles = [
    base.slice(),
    base.slice(),
    base.map((id, k) => k === 0 ? 'c0:j15' : k === 8 ? 'c0:j16' : id),
    base.map((id, k) => k === 0 ? 'c0:j15' : k === 8 ? 'c0:j16' : k === 3 ? 'c0:j20' : k === 4 ? 'c0:j3' : k === 13 ? 'c0:j4' : id),
  ];
  const resultats = [];
  for (const ordre of [[0, 1, 2, 3], [3, 2, 1, 0], [2, 0, 3, 1]]) {
    globalThis.S = fauxMonde();
    const d = domaine.factory();
    for (const i of ordre) assert.equal(d.enregistrer(match(S, feuilles[i], i === 1 ? ['c0:j22'] : [])), true);
    const { n, parJoueur } = d.compteurs(S, S.clubs[0]);
    assert.equal(n, 4, 'quatre feuilles comptées');
    assert.deepEqual(parJoueur.get('c0:j3').m.slice(3, 5), [3, 1], 'j3 : trois fois en 4, une fois en 5');
    assert.equal(parJoueur.get('c0:j22').b, 1, 'entrée depuis le banc comptée');
    const xv = d.xvFrequent(parJoueur);
    resultats.push(JSON.stringify(xv));
    assert.equal(xv[0].id, 'c0:j0', 'maillot 1 : le plus souvent titulaire à ce poste');
    assert.equal(xv[0].starts, 2);
    assert.equal(xv[3].id, 'c0:j3');
    assert.equal(xv[4].id, 'c0:j4', 'maillot 5 : j4 (3) devant j3 déjà pris en 4');
    assert.equal(xv[8].id, 'c0:j16', 'égalité parfaite au maillot 9 : identifiant le plus petit (déterministe)');
    assert.equal(xv[13].id, 'c0:j13');
    assert.equal(new Set(xv.map(x => x.id)).size, 15, 'un joueur par maillot');
    assert.equal(d.validate(S), true, 'état compact valide');
    assert.ok(S.clubSheet.clubs[0].length < 400, 'compact : ' + S.clubSheet.clubs[0].length + ' caractères');
    // Rejeu d'un match déjà compté : ignoré.
    const l = match(S, base); d.enregistrer(l); assert.equal(d.enregistrer(l), false);
  }
  assert.equal(new Set(resultats).size, 1, 'même XV quel que soit l’ordre des matchs');
  // Feuille étrangère au club (sélection) : ignorée.
  globalThis.S = fauxMonde();
  const d = domaine.factory();
  d.enregistrer(match(S, Array.from({ length: 15 }, (_, k) => 'x:' + k)));
  assert.equal(d.compteurs(S, S.clubs[0]).n, 0, 'feuille sans joueur du club non comptée');
  // Sauvegarde corrompue refusée ; clubs suivis bornés.
  S.clubSheet = { version: 1, season: 1, clubs: { 0: '2|abc:3x2.bx' }, followed: [] };
  assert.throws(() => d.validate(S), /feuilles du club invalides/);
  S.clubSheet = { version: 1, season: 1, clubs: {}, followed: [1, 1] };
  assert.throws(() => d.validate(S), /clubs suivis invalides/);
  delete globalThis.S;
});

test('Fiche club en carrière Monde : feuilles réelles, XV type recalculé, lecture seule, ancienne sauvegarde, clubs suivis', () => {
  const M = require('./helpers/carriere-monde.cjs');
  const jeu = M.ouvrir({ hebdomadaire: true, testVm: true });
  try {
    let model = M.creer(jeu, 0);
    // Feuilles réelles capturées au moment où le moteur les enregistre (lecture seule).
    jeu.bridge.vm.run(`globalThis.__feuilles=[];(()=>{const o=recordDevelopmentMatch,w=function(l){if(l&&!l.developmentRecorded)for(let s=0;s<2;s++)__feuilles.push([l.pair[s],(l.sheets[s].initial||[]).map(x=>x==null?null:String(x))]);return o.apply(this,arguments);};Object.assign(w,o);recordDevelopmentMatch=w;})();`);
    model = M.jouer(jeu, model, 3);
    const feuilles = JSON.parse(jeu.bridge.vm.run('JSON.stringify(__feuilles)'));
    assert.ok(feuilles.length >= 100, 'feuilles capturées : ' + feuilles.length);
    const adverse = model.leagues.find(l => l.id === 'elite').rows.map(r => r.id).find(id => id !== 0);
    const avant = jeu.bridge.vm.run('JSON.stringify(S)');
    const r1 = jeu.brut('club_sheet', { club: adverse }), r2 = jeu.brut('club_sheet', { club: adverse });
    assert.equal(r1.ok, true, r1.error);
    assert.equal(jeu.bridge.vm.run('JSON.stringify(S)'), avant, 'fiche en lecture seule');
    const fiche = r1.model.clubSheet;
    assert.deepEqual(r2.model.clubSheet.xv, fiche.xv, 'déterministe');
    // Recalcul indépendant : pour chaque maillot, le joueur le plus souvent titulaire (glouton par fréquence).
    const membres = new Set(fiche.squad.map(p => p.id));
    const compte = new Map();
    let n = 0;
    for (const [club, ids] of feuilles) {
      if (club !== adverse) continue; n++;
      ids.slice(0, 15).forEach((id, i) => { if (id && membres.has(id)) { const c = compte.get(id) || { m: new Array(15).fill(0), t: 0 }; c.m[i]++; c.t++; compte.set(id, c); } });
    }
    assert.equal(fiche.xv.matches, n, 'matchs comptés = feuilles du moteur');
    assert.equal(fiche.team.matches, n, 'tous les matchs du club sont détaillés');
    const couples = [];
    for (const [id, c] of compte) c.m.forEach((k, i) => { if (k > 0) couples.push([i, id, k, c.t]); });
    couples.sort((a, b) => b[2] - a[2] || b[3] - a[3] || a[0] - b[0] || (a[1] < b[1] ? -1 : 1));
    const attendu = new Array(15).fill(null), pris = new Set();
    for (const [i, id, k] of couples) if (!attendu[i] && !pris.has(id)) { attendu[i] = [id, k]; pris.add(id); }
    for (let i = 0; i < 15; i++) {
      if (!attendu[i]) continue;
      assert.equal(fiche.xv.slots[i].id, attendu[i][0], 'maillot ' + (i + 1));
      assert.equal(fiche.xv.slots[i].starts, attendu[i][1], 'titularisations maillot ' + (i + 1));
      assert.equal(fiche.xv.slots[i].source, 'feuilles');
    }
    assert.equal(fiche.squad.length, fiche.squadSize);
    assert.ok(fiche.squad.every(p => p.rating === null || p.knowledge?.owned), 'niveau des joueurs adverses masqué selon la connaissance');
    // Votre club : niveau exact connu.
    const mien = jeu.brut('club_sheet', { club: 0 }).model.clubSheet;
    assert.ok(mien.own && mien.squad.some(p => Number.isFinite(p.rating)), 'votre effectif : niveaux connus');
    // Coût dans la sauvegarde.
    const octets = Number(jeu.bridge.vm.run('JSON.stringify(S.clubSheet).length')), total = Number(jeu.bridge.vm.run('JSON.stringify(S).length'));
    assert.ok(octets < 60000, 'compteurs compacts : ' + octets + ' octets');
    console.log(`fiche club : ${n} feuilles pour le club ${adverse}, compteurs ${octets} o (${(100 * octets / total).toFixed(2)} % de l'état, ${(total / 1048576).toFixed(1)} Mio)`);
    // Clubs suivis : commande, validation, refus pour son propre club.
    model = jeu.call('club_follow', { club: adverse, follow: true });
    assert.deepEqual(model.clubLife.clubSheet.followed, [adverse]);
    assert.equal(jeu.brut('club_follow', { club: 0, follow: true }).ok, false, 'pas de suivi de son propre club');
    assert.equal(jeu.brut('club_sheet', { club: adverse }).model.clubSheet.followed, true);
    // Ancienne sauvegarde : aucun compteur → XV probable annoncé, quinze maillots remplis.
    jeu.bridge.vm.run('delete S.clubSheet');
    const ancienne = jeu.brut('club_sheet', { club: adverse }).model.clubSheet;
    assert.equal(ancienne.xv.source, 'probable');
    assert.equal(ancienne.xv.slots.filter(x => x.id).length, 15, 'XV probable complet');
    assert.equal(jeu.brut('club_sheet', { club: 9999 }).ok, false, 'club inconnu refusé');
  } finally { jeu.fermer(); }
});
