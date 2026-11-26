'use strict';
// Consignes données en direct (lot K1 « poids des décisions du manager », docs/consignes-direct-20261126.md).
// Léo : « changer joueurs/tactique DOIT changer le match ». Mesure de départ (main 903d723e2) : posées à la 50e,
// « Jeu au pied », « Relance », « Touche », « Ballon porté », « Mêlée » laissaient la suite du match identique dans 60 à
// 95 % des cas, et « Fin de match » ne bougeait ni le temps de jeu ni le score.
// Méthode : carrière Monde, club du joueur faible (102), affiches et graines fixes. Pour chaque consigne, le même match
// est joué deux fois avec la même graine : sans consigne, puis avec la consigne posée à la 50e (match en pause, comme
// dans la fenêtre Équipe). Jusqu'à la 50e, les deux journaux sont identiques ; ensuite on compte les matchs dont la suite
// change, et l'effet sur la phase visée, dans le bon sens et borné (sous l'effet d'un passage au plan « occupation »).
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');

const USER = 102, MOMENTS = 3, GRAINES = 8, MINUTE = 50;
const CONSIGNES = {
  piedJeu: ['moins', 'plus'], rythme: ['lent', 'rapide'], relance: ['degager', 'relancer'], finDeMatch: ['montre', 'tout'],
  rucks: ['prudente', 'agressive'], discipline: ['stricte', 'limite'], touche: ['sure', 'risquee'], maul: ['jamais', 'souvent'],
  melee: ['vite', 'pousser'], coupsEnvoi: ['longs', 'courts'], cible: ['aile', 'ouvreur']
};
// Part minimale de matchs dont la suite change (mesure de départ entre parenthèses, 200 matchs). Le plan d'attaque change
// la suite de tous les matchs ; une consigne reste un peu en dessous, et celles qui ne jouent que sur une phase rare
// (touche, ballon porté, mêlée) moins encore.
const SUITE_MIN = {
  'piedJeu=moins': .4, 'piedJeu=plus': .4, 'relance=degager': .3, 'relance=relancer': .4, 'finDeMatch=montre': .8, 'finDeMatch=tout': .8,
  'touche=sure': .25, 'touche=risquee': .4, 'maul=jamais': .2, 'maul=souvent': .25, 'melee=vite': .25, 'melee=pousser': .3
};
const SUITE_DEFAUT = .4;

const JOUER = `(pair,seed,cfg)=>{
  for(const id of pair)S.clubs[id]=JSON.parse(__clubs[id]);
  S.club=${USER};S.lineup=[...__base.lineup];S.reserves=[...__base.bench];S.tactic='equilibre';S.defence='equilibre';
  __setSeed(seed);
  const l=createRugbyMatch(pair,null,false,null);initPilotage(l);S.live=l;
  const releve=()=>{const u=l.userSide,o=1-u,s=l.stats[u];
    return {coups:l.tacticalStats[u].kicks,touches:s.lineouts,touchesG:s.lineoutsWon,penalites:s.penalties,actions:l.chrono.actions,
      points:l.score[u],encaisses:l.score[o],tirs:s.goalAttempts||0,porte:l.events.filter(e=>e.scene?.porte&&e.scene?.team===u).length,
      penMelee:l.events.filter(e=>e.type==='penalty'&&e.scene?.cause==='scrum').length}};
  let avant=null,debut=null,ok=true;
  for(let k=0;!l.finished;k++){
    if(k>6000)throw Error('boucle');
    if(avant===null&&l.minute>=${MINUTE}){avant=releve();debut=l.events.length;
      if(cfg){l.paused=true;
        if(cfg.axe==='plan'){setLiveTactic(cfg.v);ok=l.tactics[l.userSide]===cfg.v}
        else ok=setConsigne(l,cfg.axe,cfg.v)&&l.pilotage.consignes[cfg.axe]===cfg.v;
        l.paused=false}}
    l.paused=false;advanceRugby(l);
  }
  S.live=null;
  const apres=releve(),d={};for(const k of Object.keys(apres))d[k]=apres[k]-avant[k];
  return JSON.stringify({ok,d,avant:l.events.slice(0,debut).map(e=>e.text).join('|'),suite:JSON.stringify([l.score,l.events.slice(debut).map(e=>e.text)])})}`;

function mesurer() {
  const h = context(827381, { club: USER, console: false });
  h.ctx.__setSeed = s => h.setSeed(s);
  const variantes = [null, ...Object.entries(CONSIGNES).flatMap(([axe, vs]) => vs.map(v => ({ axe, v }))), { axe: 'plan', v: 'occupation' }];
  const R = Object.fromEntries(variantes.map(c => [c ? c.axe + '=' + c.v : 'base', []]));
  try {
    for (let m = 0; m < MOMENTS; m++) {
      h.toMatch();
      const pair = JSON.parse(h.run('JSON.stringify(nextMatch())'));
      h.ctx.__clubs = Object.fromEntries(pair.map(id => [id, h.run('JSON.stringify(S.clubs[' + id + '])')]));
      h.ctx.__base = JSON.parse(h.run(`JSON.stringify(buildSheet(S.clubs[${USER}],S.lineup,S.reserves))`));
      h.ctx.__pair = pair;
      for (let s = 0; s < GRAINES; s++) {
        const seed = ((m * 10 + s) * 7919 + 13) >>> 0;
        for (const c of variantes) { h.ctx.__cfg = c; R[c ? c.axe + '=' + c.v : 'base'].push(JSON.parse(h.run(`(${JOUER})(__pair,${seed},__cfg)`))); }
      }
      if (m < MOMENTS - 1) h.week(1);
    }
  } finally { h.close(); }
  return R;
}

test('Chaque consigne donnée à la 50e change la suite du match, dans le bon sens et sans écraser le hasard', { timeout: 1200000 }, () => {
  const R = mesurer(), base = R.base, n = base.length;
  const moy = (k, f) => R[k].reduce((a, x, i) => a + f(x.d, base[i].d), 0) / n;
  const ecart = (k, cle) => moy(k, (v, b) => v[cle] - b[cle]);
  const taux = (k, a, b) => R[k].reduce((s, x) => s + x.d[a], 0) / Math.max(1, R[k].reduce((s, x) => s + x.d[b], 0));
  const lignes = [];
  for (const k of Object.keys(R)) {
    if (k === 'base') continue;
    assert.ok(R[k].every(x => x.ok), k + ' : consigne posée à la 50e');
    assert.ok(R[k].every((x, i) => x.avant === base[i].avant), k + ' : rien ne change avant la 50e');
    const suite = R[k].filter((x, i) => x.suite !== base[i].suite).length / n;
    lignes.push(`${k.padEnd(18)} suite changée ${(100 * suite).toFixed(0).padStart(3)} %  coups de pied ${ecart(k, 'coups').toFixed(2)}  actions ${ecart(k, 'actions').toFixed(2)}  ` +
      `touches gagnées ${(100 * taux(k, 'touchesG', 'touches')).toFixed(0)} %  pénalités ${ecart(k, 'penalites').toFixed(2)}  tirs ${ecart(k, 'tirs').toFixed(2)}  portés ${ecart(k, 'porte').toFixed(2)}  marge ${moy(k, (v, b) => (v.points - v.encaisses) - (b.points - b.encaisses)).toFixed(2)}`);
    if (k === 'plan=occupation') continue;
    assert.ok(suite >= (SUITE_MIN[k] ?? SUITE_DEFAUT), `${k} : suite du match changée dans ${(100 * suite).toFixed(0)} % des matchs seulement`);
    // Le hasard garde sa place : jamais tous les matchs gagnés ou perdus d'un coup, marge bornée.
    const marge = moy(k, (v, b) => (v.points - v.encaisses) - (b.points - b.encaisses));
    assert.ok(Math.abs(marge) <= 6, `${k} : effet sur la marge trop fort (${marge.toFixed(2)})`);
  }
  console.log(`${n} matchs par consigne, même graine, consigne posée à la ${MINUTE}e (club ${USER}, après la ${MINUTE}e) :\n` + lignes.join('\n'));
  console.log(`base : ${(base.reduce((a, x) => a + x.d.coups, 0) / n).toFixed(2)} coups de pied, ${(base.reduce((a, x) => a + x.d.actions, 0) / n).toFixed(1)} actions, touches ${(100 * taux('base', 'touchesG', 'touches')).toFixed(0)} %`);
  const plan = ecart('plan=occupation', 'coups');
  // Jeu au pied : « Occuper » tape nettement plus, sans atteindre le passage au plan « occupation » ; « Garder » moins.
  assert.ok(ecart('piedJeu=plus', 'coups') >= .5, 'Occuper : plus de coups de pied ' + ecart('piedJeu=plus', 'coups').toFixed(2));
  assert.ok(ecart('piedJeu=plus', 'coups') < plan, 'Occuper reste sous le plan occupation');
  assert.ok(ecart('piedJeu=moins', 'coups') <= -.4, 'Garder : moins de coups de pied ' + ecart('piedJeu=moins', 'coups').toFixed(2));
  // Relance (depuis notre camp) : dégager tape plus, relancer moins.
  assert.ok(ecart('relance=degager', 'coups') >= .25 && ecart('relance=relancer', 'coups') <= -.25, 'relance suivie');
  // Fin de match : jouer la montre mange le temps (moins d'actions, moins de points encaissés), tout tenter accélère.
  assert.ok(ecart('finDeMatch=montre', 'actions') <= -.8, 'montre : moins d’actions ' + ecart('finDeMatch=montre', 'actions').toFixed(2));
  assert.ok(ecart('finDeMatch=montre', 'encaisses') < 0, 'montre : moins de points encaissés');
  assert.ok(ecart('finDeMatch=tout', 'actions') >= .4, 'tout tenter : plus d’actions ' + ecart('finDeMatch=tout', 'actions').toFixed(2));
  // Touche : le lancer sûr est plus souvent gagné que sans consigne, et que le lancer au fond (−0,06 par lancer ; sur
  // 24 matchs, ~80 touches, l'écart risquée/base seul reste dans le bruit, celui entre sûre et risquée non).
  assert.ok(taux('touche=sure', 'touchesG', 'touches') > taux('base', 'touchesG', 'touches'), 'touche sûre');
  assert.ok(taux('touche=risquee', 'touchesG', 'touches') < taux('touche=sure', 'touchesG', 'touches'), 'touche risquée');
  // Ballon porté : « Souvent » envoie des pénalités en touche plutôt qu'aux poteaux, « Jamais » l'inverse.
  // Comparées l'une à l'autre : sur 24 matchs, la base partagée par toutes les variantes porte son propre bruit.
  assert.ok(ecart('maul=souvent', 'tirs') < ecart('maul=jamais', 'tirs'), 'ballon porté : choix de la pénalité');
  assert.ok(ecart('maul=souvent', 'porte') > ecart('maul=jamais', 'porte'), 'ballon porté : essais sur ballon porté');
  // Mêlée : pousser fait siffler plus de pénalités de mêlée, sortir vite moins.
  assert.ok(ecart('melee=pousser', 'penMelee') > 0 && ecart('melee=vite', 'penMelee') < 0, 'mêlée suivie');
  // Discipline et rucks (déjà mesurés dans tests/match-pilotage.cjs) : le sens reste le bon en cours de match.
  assert.ok(ecart('discipline=stricte', 'penalites') < 0 && ecart('discipline=limite', 'penalites') > 0, 'discipline suivie');
  assert.ok(ecart('rucks=prudente', 'penalites') < 0 && ecart('rucks=agressive', 'penalites') > 0, 'rucks suivis');
});
