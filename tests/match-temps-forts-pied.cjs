'use strict';
// Coups de pied disputés en temps forts (option B de Léo, 26/11/2026) et légendes du jeu au pied cohérentes.
//  1. Une chandelle reprise ou relâchée par le receveur, un rasant, un par-dessus ou un croisé récupéré par l'équipe qui
//     botte devient un temps fort court en direct (niveaux dynamique, étendus et clés), sans écraser les essais.
//  2. Légendes (réserves du vérificateur de #1307) : l'en-avant qui suit un coup de pied pris par l'adversaire nomme le
//     receveur ; plus de « touche après rebond, 2 mètres gagnés » ; un coup de pied en touche de l'équipe qui a l'avantage
//     n'est plus suivi de « Aucun avantage obtenu ».
// Matchs joués par le vrai moteur (carrière Monde, comme tests/match-recit-coherent.cjs).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { worldYouth } = require('./helpers/youth-world-harness.cjs');
const selection = require('../native/engine/match-highlights.cjs');

const NOMBRE = Number(process.env.CD_TF_PIED_MATCHS) || 60;

function simuler(nombre) {
  const matchs = [];
  for (let monde = 0; matchs.length < nombre; monde++) {
    const t = worldYouth({ seed: 827381 + monde * 101, club: monde * 7 });
    const total = Number(t.run('CDWorldCareer.fixtures(S).length'));
    for (let i = 0; i < 42 && matchs.length < nombre; i++) {
      const k = matchs.length;
      matchs.push(JSON.parse(t.run(`(()=>{const f=CDWorldCareer.fixtures(S)[${i % total}];const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);
      S.club=pair[0];const l=createRugbyMatch(pair,null,false);for(let n=0;!l.finished;n++){if(n>4000)throw Error('boucle');l.paused=false;advanceRugby(l)}
      const noms={};for(const ci of pair)for(const p of S.clubs[ci].players)noms[p.id]=p.name;
      return JSON.stringify({k:${k},events:l.events,noms,abbr:pair.map(ci=>S.clubs[ci].abbr)});})()`)));
    }
  }
  return matchs;
}

let matchs = null;
const jouer = () => matchs || (matchs = simuler(NOMBRE));
const BRUIT = new Set(['sub', 'tactic', 'message']);
const suivant = (ev, j) => { let q = j + 1; while (q < ev.length && BRUIT.has(ev[q].type)) q++; return ev[q] || null; };

test('Chandelles reprises et rasants récupérés montrés en temps forts courts', { timeout: 1800000 }, () => {
  for (const niveau of ['dynamique', 'etendus', 'cles']) {
    let gagnes = 0, montres = 0, courts = 0, essais = 0, essaisVus = 0, tempsForts = 0; const longs = [], oublies = [];
    for (const m of jouer()) {
      const lignes = selection.normaliser(m.events), bilan = selection.en_direct(m.events, { niveau });
      const vus = new Map();
      for (const h of bilan.tempsForts) for (const p of h.plans) vus.set(p.i, h);
      tempsForts += bilan.nombre;
      lignes.forEach((l, j) => {
        if (l.kind === 'try') { essais++; if (vus.has(j)) essaisVus++; }
        if (!selection.piedGagne(lignes, j)) return;
        gagnes++;
        const h = vus.get(j);
        if (!h) { oublies.push(`match ${m.k} [${j}] ${m.events[j].text}`); return; }
        montres++;
        if (h.type === 'pied_recupere') {
          courts++;
          // Court : le coup de pied, une amorce d'un plan et deux plans après au plus.
          if (h.plans.filter(p => p.kind !== 'transformation').length > 1 + selection.PIED_COURT.amorce + selection.PIED_COURT.apres) longs.push(`match ${m.k} [${j}] ${h.plans.length} plans`);
        }
      });
    }
    const n = jouer().length;
    assert.ok(gagnes >= n / 4, `${niveau} : assez de coups de pied gagnés observés (${gagnes} sur ${n} matchs)`);
    assert.deepEqual(oublies.slice(0, 5), [], `${niveau} : ${oublies.length}/${gagnes} coups de pied gagnés jamais montrés`);
    assert.deepEqual(longs.slice(0, 5), [], `${niveau} : temps forts au pied trop longs`);
    assert.ok(courts / n <= 3, `${niveau} : volume raisonnable (${(courts / n).toFixed(2)} temps forts au pied ajoutés par match)`);
    assert.equal(essaisVus, essais, `${niveau} : tous les essais restent montrés`);
    assert.ok(tempsForts / n <= 30, `${niveau} : nombre de temps forts par match (${(tempsForts / n).toFixed(1)})`);
  }
});

test('Légendes du jeu au pied cohérentes avec la suite du jeu', { timeout: 1800000 }, () => {
  let receptions = 0, touchesAvantage = 0; const fautes = [];
  for (const m of jouer()) m.events.forEach((e, j) => {
    const s = e.scene || {};
    // Touche « après rebond » qui ne gagne que quelques mètres, ou « 1 mètres ».
    if (s.kind === 'touch' && /après rebond, [0-9] mètres? gagnés?|\b1 mètres gagnés/.test(e.text)) fautes.push(`match ${m.k} [${j}] ${e.text}`);
    const suite = suivant(m.events, j);
    if (!suite) return;
    // Coup de pied pris par l'adversaire puis en-avant de celui-ci : le receveur nommé commet l'en-avant.
    if (s.kind === 'kick' && s.receiver != null && s.possession !== s.team && suite.scene?.kind === 'hand-fault' && suite.scene.team === s.possession && suite.min === e.min) {
      receptions++;
      const nom = m.noms[s.receiver];
      if (!nom || !suite.text.startsWith(nom + ' ') || String(suite.scene.actor) !== String(s.receiver)) fautes.push(`match ${m.k} [${j}] ${e.text} -> ${suite.text}`);
    }
    // Coup de pied en touche de l'équipe qui a l'avantage : retour à la faute, sans « aucun avantage obtenu ».
    if (s.kind === 'touch' && ['direct-touch', 'indirect-touch'].includes(s.cause) && s.actor != null && suite.type === 'advantage' && / : retour à (la pénalité|la mêlée) pour /.test(suite.text)) {
      touchesAvantage++;
      if (/^Aucun avantage obtenu/.test(suite.text)) fautes.push(`match ${m.k} [${j}] ${e.text} -> ${suite.text}`);
    }
  });
  assert.ok(receptions >= 5, `assez d’en-avants à la réception observés (${receptions})`);
  assert.ok(touchesAvantage >= 20, `assez de coups de pied en touche sous l’avantage observés (${touchesAvantage})`);
  assert.deepEqual(fautes.slice(0, 5), [], `${fautes.length} légendes incohérentes`);
});
