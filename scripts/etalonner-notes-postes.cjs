#!/usr/bin/env node
'use strict';
// Ré-étalonnage de la pondération des notes par maillot (POSTES_NOTE de native/engine/match-notes.cjs),
// méthode de docs/homme-du-match-postes-20261114.md, rendue rejouable (docs/essais-realistes-20261114.md) :
//  1. capture : carrière Monde (club 102, graine 4242, cadence hebdomadaire, matchs délégués), journaux et
//     contextes exacts reçus par `noter` (le calcul est pur : mêmes journaux, mêmes notes) ;
//  2. ajustement : l'attendu de chaque maillot ramène sa note moyenne (≥ 40 min) à la moyenne cible commune,
//     l'amplitude rapproche la part d'hommes du match de la cible du document ; quelques dizaines de pas.
// Usage : node --max-old-space-size=1600 scripts/etalonner-notes-postes.cjs capture <sortie.json> [semaines=14] [club=102]
//         node scripts/etalonner-notes-postes.cjs ajuster <capture.json>
// Rien n'est écrit dans le dépôt : le script affiche le tableau avant/après et la ligne POSTES_NOTE proposée.
const fs = require('node:fs');
const zlib = require('node:zlib');
const path = require('node:path');

// Cible (homme du match, % par maillot 1 à 15) : docs/homme-du-match-postes-20261114.md.
const CIBLE = [2.5, 6.5, 2.5, 4, 4, 8, 8, 8.5, 10, 13, 6.5, 6, 6, 6.5, 8];

function capture(sortie, semaines = 14, club = 102) {
  const M = require('../tests/helpers/carriere-monde.cjs');
  const { skipMatchTalk } = require('../tests/helpers/scene-match-talks.cjs');
  const jeu = M.ouvrir({ hebdomadaire: true, testVm: true });
  try {
    let model = M.creer(jeu, club);
    jeu.bridge.vm.run(`globalThis.__notes=[];(()=>{const o=CDMatchNotesMoteur.noter;CDMatchNotesMoteur.noter=function(j,c){
      if(c&&c.fini&&!c.journalReduit&&c.postes)__notes.push(JSON.stringify([j.filter(e=>e.scene).map(e=>({type:e.type,scene:e.scene,min:e.min})),c]));
      return o.apply(this,arguments);};})();`);
    for (let w = 0; w < semaines; w++) {
      model = jeu.regler(model);
      if (model.next) {
        if (!model.selection.valid) model = jeu.call('auto_lineup');
        if (!model.selection.valid) model = jeu.call('promote_cover', { confirmed: true });
        model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
        model = skipMatchTalk(jeu.call('delegate'), jeu.call);
      }
      model = jeu.call('finish_round');
      process.stderr.write(`semaine ${w + 1} : ${jeu.bridge.vm.run('__notes.length')} matchs\n`);
    }
    const n = Number(jeu.bridge.vm.run('__notes.length'));
    const lignes = [];
    for (let i = 0; i < n; i += 50) lignes.push(...JSON.parse(jeu.bridge.vm.run(`JSON.stringify(__notes.slice(${i},${i + 50}))`)));
    fs.writeFileSync(sortie, zlib.gzipSync(JSON.stringify(lignes.map(x => JSON.parse(x)))));
    console.log(`${n} matchs capturés dans ${sortie}`);
  } finally { jeu.fermer(); }
}

function evaluer(N, matchs) {
  const hdm = new Array(15).fill(0), notes = Array.from({ length: 15 }, () => []);
  for (const [j, c] of matchs) {
    const r = N.noter(j, c);
    const h = r.joueurs[r.hommeDuMatch], poste = c.postes[r.hommeDuMatch];
    if (h && Number.isInteger(poste) && poste >= 0 && poste < 15) hdm[poste]++;
    for (const [id, n] of Object.entries(r.joueurs)) { const k = c.postes[id]; if (n.minutes >= 40 && Number.isInteger(k) && k >= 0 && k < 15) notes[k].push(n.note); }
  }
  const moy = a => a.reduce((x, y) => x + y, 0) / Math.max(1, a.length);
  return { part: hdm.map(x => 100 * x / matchs.length), moyennes: notes.map(moy), generale: moy(notes.flat()) };
}

function ajuster(fichier) {
  const matchs = JSON.parse(zlib.gunzipSync(fs.readFileSync(fichier)));
  const N = require('../native/engine/match-notes.cjs').moteur();
  const P = N.POSTES_NOTE, depart = P.map(x => x.slice());
  const avant = evaluer(N, matchs);
  const cible = avant.generale;
  for (let pas = 0; pas < 40; pas++) {
    const e = evaluer(N, matchs);
    for (let k = 0; k < 15; k++) {
      // Note moyenne du maillot vers la moyenne générale : +0,1 de note ≈ +0,1 / (amplitude × 0,8) d'attendu.
      P[k][0] = Math.round((P[k][0] + (e.moyennes[k] - cible) / (P[k][1] * 0.8) * 0.6) * 100) / 100;
      // Part d'hommes du match vers la cible : amplitude corrigée doucement.
      const rapport = Math.max(0.5, Math.min(2, (CIBLE[k] + 0.5) / (e.part[k] + 0.5)));
      P[k][1] = Math.round(P[k][1] * Math.pow(rapport, 0.12) * 100) / 100;
    }
  }
  const apres = evaluer(N, matchs);
  const ligne = k => `| ${k + 1} | ${CIBLE[k]} | ${avant.part[k].toFixed(1)} | ${apres.part[k].toFixed(1)} | ${avant.moyennes[k].toFixed(2)} → ${apres.moyennes[k].toFixed(2)} | [${depart[k].join(', ')}] → [${P[k].join(', ')}] |`;
  console.log(`${matchs.length} matchs ; moyenne générale ${avant.generale.toFixed(2)} → ${apres.generale.toFixed(2)}`);
  console.log('| Maillot | Cible | Avant | Après | Moyenne | POSTES_NOTE |\n|---|---|---|---|---|---|');
  for (let k = 0; k < 15; k++) console.log(ligne(k));
  console.log('const POSTES_NOTE=[' + P.map(x => `[${x[0]},${x[1]}]`).join(',') + '];');
}

if (require.main === module) {
  const [mode, fichier, a, b] = process.argv.slice(2);
  if (mode === 'capture') capture(path.resolve(fichier), Number(a || 14), Number(b || 102));
  else if (mode === 'ajuster') ajuster(path.resolve(fichier));
  else { console.error('Usage : capture <sortie.json.gz> [semaines] [club] | ajuster <capture.json.gz>'); process.exit(2); }
}
module.exports = { capture, ajuster, evaluer, CIBLE };
