'use strict';
// Matchs calés sur la réalité, championnat par championnat (25/11/2026, docs/realite-matchs-20261125.md).
// Chiffres réels : tests/fixtures/realite-matchs-20261125.json (saisons régulières 2022-23 à 2025-26 comptées :
// victoires à domicile, nuls, hiérarchie, écarts, bonus). Le banc de courbe (tests/helpers/courbe-niveau.cjs) joue deux
// copies d'un même club, l'une décalée de 6 points, dans chaque championnat, au moteur complet et au résultat rapide :
//  - victoires à domicile à niveau égal = celles du championnat réel (ajustement logistique sur les vrais matchs,
//    domicile et bilan de saison des deux clubs) : Top 14 79 %, Pro D2 78 %, Premiership 69 %, URC 70 %, Super Rugby 69 %,
//    Japon 52 % (stades partagés ou neutres, presque pas d'avantage du terrain) ;
//  - poids de l'écart de niveau (pente par point) = celui qui redonne, sur des saisons Monde complètes, la hiérarchie
//    réelle (dispersion des % de victoires des clubs, hors part du hasard) : Pro D2 et Top 14 serrés, URC, Super Rugby
//    et Japon très étagés (TERRAIN_CHAMPIONNAT et ECART_CHAMPIONNAT de dist/rugby.js) ;
//  - les deux moteurs suivent la même courbe dans chaque championnat.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');
const B = require('./helpers/courbe-niveau.cjs');
const REEL = require('./fixtures/realite-matchs-20261125.json').championnats;

// Pente par point visée (banc, moteur complet), issue du calage sur la dispersion réelle (docs/realite-matchs-20261125.md).
const PENTE = { elite: 0.19, accession: 0.17, prem: 0.23, urc: 0.30, srp: 0.40, 'jlo-d1': 0.30 };
const N = { complet: 240, rapide: 1000 };
// Tolérances : réel ± 7 points de domicile, pente visée ± 0,06, plus une erreur type du banc (graine fixe : le test ne tire pas au sort).
const TOL = { domicile: 0.07, pente: 0.06, moteurs: 0.06 };

test('Domicile et poids du niveau de chaque championnat calés sur les matchs réels', { timeout: 900000 }, () => {
  const h = context(4242, { club: 102, console: false });
  try {
    assert.deepEqual(Object.keys(REEL).sort(), Object.keys(PENTE).sort());
    // Les chiffres réels eux-mêmes : ordre des championnats tel qu'on le compte.
    assert.ok(REEL.elite.victoiresDomicile > 70 && REEL.accession.victoiresDomicile > 70, 'Top 14 et Pro D2 : forteresses à domicile');
    assert.ok(REEL['jlo-d1'].victoiresDomicile < 55, 'Japon : presque pas d’avantage du terrain');
    assert.ok(REEL.elite.dispersionNiveau < REEL.urc.dispersionNiveau && REEL.accession.dispersionNiveau < REEL.srp.dispersionNiveau, 'championnats français plus serrés');
    const cp = h.checkpoint(), fits = {};
    for (const comp of Object.keys(PENTE)) for (const mode of ['complet', 'rapide']) {
      h.restore(cp);
      const m = B.mesurer(h, { mode, ecarts: [0, 6], n: N[mode], base: 4, slots: [7, 11], competitionId: comp });
      const reel = REEL[comp].domicileNiveauEgal / 100, f = m.fit;
      console.log(`${comp} ${mode} : domicile ${B.pct(f.domicileNiveauEgal)} (réel ${B.pct(reel)}), pente ${f.pente.toFixed(3)} (visée ${PENTE[comp]})`);
      const seD = f.se.terrain / 4;
      assert.ok(Math.abs(f.domicileNiveauEgal - reel) <= TOL.domicile + seD,
        `${comp} ${mode} : domicile à niveau égal ${B.pct(f.domicileNiveauEgal)} contre ${B.pct(reel)} dans la réalité`);
      assert.ok(Math.abs(f.pente - PENTE[comp]) <= TOL.pente + f.se.pente, `${comp} ${mode} : pente ${f.pente.toFixed(3)} pour ${PENTE[comp]}`);
      fits[comp + mode] = f; fits[comp + mode + '+6'] = m.resumes.find(x => x.k === 6);
    }
    // Les deux moteurs d'accord : victoires du plus fort à +6 (domicile alterné). Comparé sur ce point plutôt que sur la pente,
    // que la compression des gros écarts du Top 14 rend instable sur deux écarts seulement.
    for (const comp of Object.keys(PENTE)) {
      const c = fits[comp + 'complet+6'], r = fits[comp + 'rapide+6'];
      const se = Math.hypot(Math.sqrt(c.victoires * (1 - c.victoires) / c.n), Math.sqrt(r.victoires * (1 - r.victoires) / r.n));
      assert.ok(Math.abs(c.victoires - r.victoires) <= TOL.moteurs + se, `${comp} : +6 complet ${B.pct(c.victoires)} / rapide ${B.pct(r.victoires)}`);
    }
    // Hiérarchie : les championnats réellement étagés pèsent plus l'écart de niveau que les championnats français.
    assert.ok(fits.urccomplet.pente > fits.accessioncomplet.pente && fits.srprapide.pente > fits.accessionrapide.pente, 'URC et Super Rugby plus étagés que la Pro D2');
  } finally { h.close(); }
});
