'use strict';
// Gestes 3D des lois (coup franc, essai de pénalité, drop ; 26/11/2026) : les faits du bloc des lois (dist/restarts.js,
// `scene.loi`, jamais le texte) deviennent des plans joués par la vue 3D.
// - classement des temps forts (match-highlights.cjs) : coup franc = coup de sifflet (plan « penalty », loi gardée) ;
//   essai de pénalité = essai (temps fort « essai », sans plan de transformation) ; drop = tir au but réussi ou manqué,
//   type « drop_reussi » / « drop_manque » (pas une pénalité) ;
// - plans du direct (match-direct.cjs) : `loi` sur le plan, plan « penalty-try » (score à +7, pas de +5) ;
// - scène du drop (lecteur `drop`) : botteur au point du drop, ballon vers la ligne de but visée, ENTRE les perches
//   (|y - 35| < 2,8 m) s'il est réussi, À CÔTÉ d'un montant sinon ;
// - régie et arbitre de la vue (lecture du code Godot) : bras plié au coup franc, course sous les poteaux et bras levé à
//   l'essai de pénalité, drop lâché et frappé au rebond.
// Matchs réels du moteur (carrière Monde, graine fixe) ; seules les probabilités des lois sont relevées DANS LA VM du test
// (variable LOIS de dist/restarts.js), pour que chaque fait se produise.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const { context } = require('./monde-harness.cjs');
const H = require('../native/engine/match-highlights.cjs');
const direct = require('../native/engine/match-direct.cjs');

const POTEAUX = 2.8; // demi-écart des montants (loi 8 : 5,6 m)
const h = context(26112026, { club: 0 });
h.run(`LOIS.drop.base=.35;LOIS.drop.fin=.6;LOIS.essaiPenalite.distance=14;LOIS.essaiPenalite.conquete=1;LOIS.essaiPenalite.jeu=1;LOIS.coupFranc.melee=.4;
 var lecteurGestes=(${direct.lecteur.toString()})();`);
const matchs = [];
const vus = new Set();
const REQUIS = ['coup-franc', 'essai-penalite', 'drop-reussi', 'drop-rate'];
for (let i = 0; i < 16 && !REQUIS.every(loi => vus.has(loi)); i++) {
  const m = JSON.parse(h.run(`(()=>{const f=S.worldMode.fixtures.filter(f=>f.competitionId==='elite'&&f.phase==='league')[${i * 5}];
    S.round=f.week;const pair=[f.homeId,f.awayId];for(const id of pair)CDFranceCareer.ensureAISheet(S.clubs[id]);S.club=pair[0];
    const l=createRugbyMatch(pair,null,false);for(let n=0;!l.finished;n++){if(n>4000)throw Error('boucle');l.paused=false;advanceRugby(l)}
    S.live=l;const drops={};
    l.events.forEach((e,i)=>{if(['drop-reussi','drop-rate'].includes(e.scene?.loi))drops[i]=lecteurGestes.drop(i)});
    return JSON.stringify({events:l.events,drops});})()`));
  for (const e of m.events) if (e.scene?.loi) vus.add(e.scene.loi);
  matchs.push(m);
}
h.close();
if (process.env.CD_DEBUG_LOIS) console.log(matchs.length, [...vus], matchs.map(m => m.events.length));
const tous = loi => matchs.flatMap((m, k) => m.events.map((e, i) => ({ m: k, i, e })).filter(x => x.e.scene?.loi === loi));

test('Chaque loi se produit dans les matchs du test', () => {
  for (const loi of REQUIS) assert.ok(tous(loi).length > 0, loi + ' absent');
});

test('Classement : coup franc = coup de sifflet, essai de pénalité = essai sans transformation, drop = tir au but', () => {
  for (const m of matchs) {
    const lignes = H.normaliser(m.events);
    lignes.forEach((l, i) => {
      const loi = m.events[i].scene?.loi;
      if (loi === 'coup-franc') assert.deepEqual([l.kind, l.loi, l.bandeau], ['penalty', loi, false]);
      if (loi === 'essai-penalite') assert.deepEqual([l.kind, l.loi, l.transformation, l.bandeau], ['try', loi, null, false]);
      if (loi === 'drop-reussi') assert.deepEqual([l.kind, l.loi, l.bandeau], ['goal', loi, false]);
      if (loi === 'drop-rate') assert.deepEqual([l.kind, l.loi, l.bandeau], ['miss', loi, false]);
      if (loi === 'drop-tente' || loi === 'injouable') assert.equal(l.kind, 'message');
    });
  }
});

test('Temps forts : l’essai de pénalité est un temps fort « essai », le drop réussi un temps fort « drop »', () => {
  for (const { m, i } of tous('essai-penalite')) {
    const tf = H.en_direct(matchs[m].events, { niveau: 'dynamique' }).tempsForts.find(t => t.debut <= i && t.fin >= i);
    assert.ok(tf, 'essai de pénalité jamais montré');
    assert.ok(tf.types.includes('essai'), 'types : ' + tf.types.join(', '));
    assert.ok(tf.plans.some(p => p.i === i && p.kind === 'try'));
    assert.ok(!tf.plans.some(p => p.i === i && p.kind === 'transformation'), 'transformation tirée après un essai de pénalité');
    const retro = H.temps_forts(matchs[m].events, { niveau: 'etendus' }).tempsForts.find(t => t.debut <= i && t.fin >= i);
    assert.ok(retro && retro.types.includes('essai'));
  }
  for (const { m, i } of tous('drop-reussi')) {
    const retro = H.temps_forts(matchs[m].events, { niveau: 'etendus' }).tempsForts.find(t => t.debut <= i && t.fin >= i);
    assert.ok(retro && retro.types.includes('drop_reussi') && !retro.types.includes('penalite_reussie'), retro && retro.types.join(', '));
  }
  for (const { m, i } of tous('coup-franc')) {
    const lignes = H.normaliser(matchs[m].events);
    assert.ok(H.temps_forts(matchs[m].events, { niveau: 'integral' }).tempsForts.some(t => t.debut <= i && t.fin >= i), 'coup franc hors du match entier');
    assert.equal(lignes[i].kind, 'penalty');
  }
});

test('Scène du drop : botteur au point du drop, ballon entre les perches s’il est réussi, à côté sinon', () => {
  let n = 0;
  for (const m of matchs) for (const [i, s] of Object.entries(m.drops)) {
    const e = m.events[i], reussi = e.scene.loi === 'drop-reussi', camp = e.scene.team;
    assert.ok(s, 'pas de scène de drop');
    assert.equal(s.kind, reussi ? 'goal' : 'miss');
    assert.equal(s.drop, true);
    assert.equal(s.possession, camp);
    assert.equal(s.ball.x, camp === 0 ? 100 : 0, 'ballon vers la ligne de but attaquée');
    const ecart = Math.abs(s.ball.y - 35);
    if (reussi) assert.ok(ecart < POTEAUX, 'drop réussi hors des perches : ' + ecart);
    else assert.ok(ecart > POTEAUX + 1, 'drop manqué entre les perches : ' + ecart);
    const botteur = s.players.filter(p => p.featured);
    assert.equal(botteur.length, 1);
    assert.equal(botteur[0].side, camp);
    assert.deepEqual([botteur[0].x, botteur[0].y], [s.origin.x, s.origin.y]);
    if (reussi && e.scene.actor != null) assert.equal(botteur[0].id, String(e.scene.actor));
    const distance = Math.abs(s.ball.x - s.origin.x);
    assert.ok(distance >= 10 && distance <= 40, 'drop à ' + distance + ' m');
    n++;
  }
  assert.ok(n > 0);
});

test('Plans du direct : loi sur le plan, essai de pénalité à part (+7), drop joué en tir au but', () => {
  const src = fs.readFileSync(path.join(__dirname, '../native/engine/match-direct.cjs'), 'utf8');
  assert.match(src, /kind=loi==='essai-penalite'\?'penalty-try':p\.kind/);
  assert.match(src, /\.\.\.\(loi\?\{loi\}:\{\}\)/);
  assert.match(src, /score:kind==='try'\?/);
  assert.match(src, /drop&&typeof lire\.drop==='function'\?lire\.drop\(p\.i\)/);
  assert.match(fs.readFileSync(path.join(__dirname, '../native/engine/worker.cjs'), 'utf8'), /drop:index=>JSON\.parse\(run\('JSON\.stringify\(nativeMatchDirect\.drop\(/);
});

test('Vue 3D : l’arbitre plie le bras au coup franc, court sous les poteaux et lève le bras à l’essai de pénalité ; drop au rebond', () => {
  const godot = f => fs.readFileSync(path.join(__dirname, '../native/godot', f), 'utf8');
  const arbitre = godot('match_arbitre.gd'), lecture = godot('ui/contextual/match_temps_forts_lecture.gd');
  // Coup franc : sifflet puis signal « coude » (bras à l'horizontale, avant-bras levé) vers l'équipe.
  assert.match(arbitre, /"coup-franc":[\s\S]*?signal_bras = "coude"/);
  assert.match(arbitre, /if _signal_vu == "coude":[\s\S]*?coude \+ Vector3\.UP \* avant_bras/);
  // Essai de pénalité : cible = sous les poteaux, bras levé (LEVE * 0,7 rad ≈ verticale) une fois arrivé.
  assert.match(arbitre, /"essai-penalite":[\s\S]*?cible = point[\s\S]*?signal_bras = "bras"[\s\S]*?hauteur_bras = LEVE/);
  const leve = Number(/const LEVE := ([\d.]+)/.exec(arbitre)[1]);
  assert.ok(Math.abs(leve * 0.7 - Math.PI / 2) < 0.05, 'bras levé à la verticale');
  assert.match(lecture, /var point := Vector3\(poteaux - cote \* 1\.0, 0\.0, 0\.0\)/);
  assert.match(lecture, /_jouer_loi\(plan\)/);
  // Drop : clip « drop », ballon lâché des mains puis frappé au rebond, vol de tir au but vers la cible de la scène.
  const drop = godot('match_vue_drop.gd');
  assert.match(drop, /jouer_geste\(id, "drop"/);
  // Lancé à l'image du drop, avec ou sans bibliothèque d'animations adaptées (le ballon fait le geste dans tous les cas).
  assert.match(godot('match_view.gd'), /if new_action and play_action and _live_cadence == 1 and scene\.get\("drop", false\):\s*VueJoueurs\._lancer_drop/);
  assert.match(godot('match_vue_joueurs.gd'), /static func _lancer_drop[\s\S]*?VueDrop\.lancer/);
  assert.match(godot('match_vue_ballon.gd'), /VueDrop\.avancer\(v, delta\)/);
});
