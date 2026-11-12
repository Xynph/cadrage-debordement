'use strict';

// Déclenchement des temps forts par l'importance (12 novembre 2026, demande de Léo : « le moteur
// de match détermine quand une action est suffisamment importante pour être montrée et donc
// passer au temps fort »). docs/match-importance-20261112.md.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { context } = require('./harness.cjs');
const H = require('../native/engine/match-highlights.cjs');
const D = require('../native/engine/match-direct.cjs');

const NIVEAUX = ['cles', 'dynamique', 'etendus'];

function simuler(k) {
  const { run } = context();
  run(`for (let i = 0; i < ${k * 7919}; i++) Math.random(); start(${k % 10}); beginMatch(); continueMatch();`);
  for (let i = 0; i < 800 && !run('S.live.finished'); i++) run('if (S.live.paused) continueMatch(); presentationTick(S.live);');
  assert.equal(run('S.live.finished'), true);
  return { camp: run('S.live.userSide'), events: JSON.parse(run('JSON.stringify(S.live.events)')) };
}
const matchs = [0, 1, 2, 3, 4, 5].map(simuler);
const copie = v => JSON.parse(JSON.stringify(v));

test('Le temps fort s’ouvre au début de l’action, avant son issue, sur une décision prise sans la suite', () => {
  let declenches = 0;
  for (const { camp, events } of matchs) for (const niveau of NIVEAUX) {
    const bilan = H.en_direct(events, { niveau, camp });
    for (const tf of bilan.tempsForts) {
      if (tf.suite || tf.declencheur === null) continue;
      declenches++;
      const dernier = tf.plans.filter(p => p.kind !== 'transformation').at(-1).i;
      assert.ok(tf.debut <= tf.declencheur && tf.declencheur <= dernier, `${niveau} ${tf.cle} : déclencheur ${tf.declencheur} dans la fenêtre`);
      // Même décision quand le journal s'arrête au déclencheur : rien de la suite n'a servi.
      const partiel = H.en_direct(events.slice(0, tf.declencheur + 1), { niveau, camp });
      const meme = partiel.tempsForts.find(h => h.declencheur === tf.declencheur);
      assert.ok(meme, `${niveau} ${tf.cle} : déclenché aussi sur le journal arrêté au déclencheur`);
      assert.equal(meme.debut, tf.debut, `${niveau} ${tf.cle} : même début`);
      assert.equal(meme.importance, tf.importance);
    }
  }
  assert.ok(declenches > 100, 'temps forts déclenchés par l’importance : ' + declenches);
});

test('L’importance ne lit pas l’issue : essai ou plaquage, tir réussi ou manqué, même valeur', () => {
  let essais = 0, tirs = 0;
  for (const { camp, events } of matchs) {
    const lignes = H.normaliser(events);
    events.forEach((e, j) => {
      const k = e.scene?.kind;
      if (k !== 'try' && k !== 'goal' && k !== 'miss') return;
      if (k === 'miss' && e.type !== 'miss') return;
      const avant = H.importance(lignes, j, { camp });
      const autre = copie(events).slice(0, j + 1);
      const s = autre[j].scene, score = j > 0 ? events[j - 1].scene?.score || [0, 0] : [0, 0];
      if (k === 'try') {
        // L'essai devient un plaquage à cinq mètres de la ligne : ni points, ni ligne franchie.
        Object.assign(autre[j], { type: 'play', text: 'Plaqué.' });
        Object.assign(s, { kind: 'carry', to: { x: s.team === 0 ? 95 : 5, y: s.to.y }, score: [...score], tries: events[j - 1]?.scene?.tries || [0, 0] });
        delete s.conversion;
        essais++;
      } else {
        Object.assign(autre[j], { type: k === 'goal' ? 'miss' : 'goal' });
        Object.assign(s, { kind: k === 'goal' ? 'miss' : 'goal', score: [...score] });
        tirs++;
      }
      const apres = H.importance(H.normaliser(autre), j, { camp });
      assert.deepEqual(apres, avant, `fait ${j} (${k}) : l’importance dépend de l’issue`);
      // Tout ce qui suit le fait est aussi sans effet.
      assert.deepEqual(H.importance(lignes.slice(0, j + 1), j, { camp }), avant);
    });
  }
  assert.ok(essais >= 10 && tirs >= 5, `essais ${essais}, tirs ${tirs}`);
});

test('L’entracte 2D ne montre jamais le début d’un temps fort à venir', () => {
  let verifies = 0;
  for (const { camp, events } of matchs.slice(0, 3)) for (const niveau of NIVEAUX) {
    const complet = H.en_direct(events, { niveau, camp }).tempsForts.filter(h => !h.suite);
    const fins = events.map((e, i) => i).filter(i => !events[i + 1] || events[i + 1].min !== events[i].min || (events[i + 1].period || 1) !== (events[i].period || 1));
    for (const n of fins) {
      const prefixe = events.slice(0, n + 1), bilan = H.en_direct(prefixe, { niveau, camp });
      const borne = D.borneEntracte(H.normaliser(prefixe), bilan);
      const montre = bilan.tempsForts.reduce((m, h) => Math.max(m, h.fin), -1);
      // Le prochain temps fort qui n'a pas encore commencé à cette rafale.
      const prochain = complet.find(h => h.debut > montre && h.debut > n);
      if (prochain) { assert.ok(borne <= prochain.debut, `${niveau} rafale ${n} : borne ${borne} > début ${prochain.debut}`); verifies++; }
    }
  }
  assert.ok(verifies > 200, 'rafales vérifiées : ' + verifies);
});

test('Le seuil dépend du niveau : clés montre moins que dynamique, qui montre moins qu’étendus', () => {
  const total = { cles: 0, dynamique: 0, etendus: 0 };
  for (const { camp, events } of matchs) for (const niveau of NIVEAUX) total[niveau] += H.en_direct(events, { niveau, camp }).nombre;
  assert.ok(total.cles < total.dynamique && total.dynamique < total.etendus, JSON.stringify(total));
  for (const t of [0, 0.5, 1]) {
    const seuil = n => H.IMPORTANCE[n].base - H.IMPORTANCE[n].pente * t;
    assert.ok(seuil('etendus') < seuil('dynamique'), 'tension ' + t);
  }
  // Dynamique : plus exigeant que « clés » quand le match est plié, plus large quand tout se joue.
  const dyn = t => H.IMPORTANCE.dynamique.base - H.IMPORTANCE.dynamique.pente * t, cles = t => H.IMPORTANCE.cles.base - H.IMPORTANCE.cles.pente * t;
  assert.ok(dyn(0) > cles(0) && dyn(1) < cles(1));
});

test('Tous les essais montrés, 50 s au plus par temps fort, sélection déterministe', () => {
  for (const { camp, events } of matchs) for (const niveau of NIVEAUX) {
    const bilan = H.en_direct(events, { niveau, camp });
    assert.deepEqual(H.en_direct(copie(events), { niveau, camp }), bilan, niveau + ' : même journal, même sélection');
    events.forEach((e, i) => {
      if (e.scene?.kind === 'try') assert.ok(bilan.tempsForts.some(h => h.plans.some(p => p.i === i && p.kind === 'try')), `${niveau} : essai ${i} montré`);
    });
    let episode = 0;
    for (const h of bilan.tempsForts) {
      episode = h.suite ? episode + h.duree : h.duree;
      assert.ok(episode <= H.DUREE_MAX + 1e-9 || h.types.includes('essai'), `${niveau} ${h.cle} : ${episode} s`);
    }
  }
  // Même graine, même match, mêmes temps forts.
  const a = simuler(4), b = simuler(4);
  assert.deepEqual(H.en_direct(a.events, { niveau: 'dynamique', camp: a.camp }), H.en_direct(b.events, { niveau: 'dynamique', camp: b.camp }));
});

test('Des grosses actions sans point montrées, et une issue qui ne se devine pas', () => {
  let episodes = 0, points = 0;
  const quarts = [0, 0, 0, 0];
  for (const { camp, events } of matchs) for (const tf of H.en_direct(events, { niveau: 'dynamique', camp }).tempsForts) {
    if (tf.suite) continue;
    episodes++;
    if (tf.plans.some(p => p.kind === 'try' || p.kind === 'goal')) points++;
    quarts[Math.min(3, Math.floor(tf.minuteDebut / 20))]++;
  }
  const part = points / episodes;
  assert.ok(part >= 0.25 && part <= 0.55, 'temps forts qui marquent : ' + Math.round(part * 100) + ' %');
  assert.ok(quarts.every(q => q / episodes >= 0.12), 'répartition : ' + quarts.join(' / '));
});

test('Un exemple écrit à la main : la touche formée près de la ligne ouvre le temps fort', () => {
  const ev = (min, type, kind, team, from, to, extra = {}) => ({ min, period: 1, type, text: kind,
    scene: { kind, team, possession: extra.possession ?? team, from: { x: from, y: extra.y ?? 35 }, to: { x: to, y: extra.y ?? 35 }, score: extra.score || [0, 0], tries: extra.tries || [0, 0], incident: false } });
  const base = [
    ev(0, 'restart', 'kickoff', 1, 50, 50), ev(0, 'play', 'reception', 0, 50, 40),
    ev(30, 'play', 'carry', 0, 40, 52), ev(31, 'play', 'touch', 1, 52, 92, { possession: 0 }),
    ev(32, 'setup', 'lineout', 0, 92, 92, { y: 4 }), ev(32, 'play', 'setpiece-win', 0, 92, 95, { y: 4 })
  ];
  const fins = [
    [ev(33, 'try', 'try', 0, 95, 100, { score: [5, 0], tries: [1, 0] })],
    [ev(33, 'turnover', 'turnover', 1, 95, 95)]
  ];
  const tfs = fins.map(f => H.en_direct([...base, ...f], { niveau: 'dynamique', cible: false }).tempsForts.find(h => h.debut === 4));
  for (const tf of tfs) {
    assert.ok(tf, 'temps fort sur la touche formée');
    assert.equal(tf.declencheur, 4, 'déclenché sur l’alignement, avant l’issue');
    assert.equal(tf.rattrapage, false);
  }
  assert.equal(tfs[0].importance, tfs[1].importance, 'même importance, essai ou ballon perdu');
});
