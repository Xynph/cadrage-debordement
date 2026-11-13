'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.

// « On ne dit essai que si on voit l'essai » (décision de Léo, 11 novembre 2026).
// En temps forts, mode de base du match, chaque essai du score fait partie d'un temps
// fort montré, dont le plan d'essai montre le marqueur désigné par le moteur, ballon au
// point d'essai ; un essai « sur ballon porté » suit une conquête où le ballon porté est
// réellement formé (combinaison « maul » ou fait « porte » écrit par le moteur).
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { test } = require('node:test');
const { context } = require('./harness.cjs');
const H = require('../native/engine/match-highlights.cjs');

// Niveaux où la 3D joue des temps forts. « aucun » (commentaire seul) est le choix explicite
// de ne rien regarder : aucun temps fort, par construction.
const NIVEAUX_MONTRES = ['resume', 'cles', 'etendus', 'dynamique', 'integral'];

function jouer(club) {
  const { run } = context();
  run(`start(${club}); beginMatch(); continueMatch();`);
  for (let i = 0; i < 800 && !run('S.live.finished'); i++) run('if (S.live.paused) continueMatch(); presentationTick(S.live);');
  assert.equal(run('S.live.finished'), true);
  const events = JSON.parse(run('JSON.stringify(S.live.events)'));
  const tries = JSON.parse(run('JSON.stringify(S.live.tries)'));
  // Scène 3D de chaque essai, telle que la projection du direct la lit (curseur de présentation).
  const scenes = {};
  events.forEach((e, i) => {
    if (e.scene?.kind !== 'try') return;
    scenes[i] = JSON.parse(run(`(()=>{const l=S.live,p=playback(l),c=p.cursor;p.cursor=${i};try{return JSON.stringify(matchScene(l))}finally{p.cursor=c}})()`));
  });
  return { club, events, tries, scenes };
}

const matchs = [0, 3, 7, 10, 13].map(jouer);
const essais = m => m.events.map((e, i) => [e, i]).filter(([e]) => e.scene?.kind === 'try');

test('Les matchs de contrôle marquent des essais, dont au moins un sur ballon porté', () => {
  const total = matchs.reduce((n, m) => n + essais(m).length, 0);
  assert.ok(total >= 10, `essais joués : ${total}`);
  for (const m of matchs) assert.equal(essais(m).length, m.tries[0] + m.tries[1], 'chaque essai du score a son événement');
  assert.ok(matchs.some(m => essais(m).some(([e]) => e.scene.origin === 'maul')), 'un essai sur ballon porté au moins');
});

test('À chaque niveau montré, chaque essai du score est joué dans un temps fort, suivi de sa transformation', () => {
  for (const m of matchs) for (const niveau of NIVEAUX_MONTRES) {
    const { tempsForts } = H.en_direct(m.events, { niveau });
    for (const [e, i] of essais(m)) {
      const tf = tempsForts.find(h => h.plans.some(p => p.i === i && p.kind === 'try'));
      assert.ok(tf, `club ${m.club}, ${niveau} : essai non montré (${e.text})`);
      const n = tf.plans.findIndex(p => p.i === i && p.kind === 'try');
      assert.equal(tf.plans[n + 1]?.kind, 'transformation', `${niveau} : la transformation suit l’essai`);
    }
  }
  // Commentaire seul : aucun temps fort, le joueur a choisi de ne pas regarder.
  assert.equal(H.en_direct(matchs[0].events, { niveau: 'aucun' }).tempsForts.length, 0);
});

test('Le plan d’essai montre le marqueur du moteur, ballon sur la ligne d’en-but adverse', () => {
  for (const m of matchs) for (const [e, i] of essais(m)) {
    const scene = m.scenes[i], record = e.scene;
    assert.equal(scene.kind, 'try');
    const marqueur = scene.players.filter(p => p.featured);
    assert.equal(marqueur.length, 1, 'un seul marqueur mis en avant');
    assert.equal(marqueur[0].id, record.actor, 'le marqueur est celui que nomme le commentaire');
    assert.equal(marqueur[0].side, record.team);
    const ligne = record.team === 0 ? 100 : 0;
    assert.equal(scene.ball.x, ligne, 'ballon aplati sur la ligne d’en-but adverse (la vue le reporte dans l’en-but)');
    assert.equal(marqueur[0].x, ligne);
    if (record.actor) assert.match(e.text, /Essai de /);
  }
});

test('Un essai « sur ballon porté » suit une touche gagnée où le ballon porté est formé, dans le même temps fort', () => {
  let vus = 0;
  for (const m of matchs) {
    const { tempsForts } = H.en_direct(m.events, { niveau: 'dynamique' });
    for (const [e, i] of essais(m)) {
      assert.equal(e.scene.origin === 'maul', /sur ballon porté/.test(e.text), 'le texte suit le fait');
      if (e.scene.origin !== 'maul') continue;
      vus++;
      const tf = tempsForts.find(h => h.plans.some(p => p.i === i && p.kind === 'try'));
      const n = tf.plans.findIndex(p => p.i === i && p.kind === 'try');
      const conquete = m.events[tf.plans[n - 1]?.i]?.scene;
      assert.equal(conquete?.kind, 'setpiece-win', 'la conquête est montrée juste avant l’essai');
      assert.ok(conquete.move === 'maul' || conquete.porte === true, 'le ballon porté est un fait de la conquête');
      assert.equal(conquete.team, e.scene.team);
    }
    // Le fait « porte » n'existe que sur une conquête suivie d'un essai sur ballon porté.
    m.events.forEach((e, i) => {
      if (e.scene?.porte !== true) return;
      assert.equal(e.scene.kind, 'setpiece-win');
      assert.ok(m.events.slice(i + 1, i + 4).some(x => x.scene?.kind === 'try' && x.scene.origin === 'maul'));
    });
  }
  assert.ok(vus > 0);
});

test('Le fait « porte » ne change aucun tirage : le témoin qui l’ignore donne le même match', () => {
  // Témoin : la même conquête sans écrire le fait. Même journal (hors champ), même score.
  const { run } = context();
  run(`start(7); beginMatch(); continueMatch();`);
  run(`(()=>{const origine=contestSetPiece;contestSetPiece=function(...a){const r=origine.apply(this,a);for(const e of S.live.events)if(e.scene)delete e.scene.porte;return r}})()`);
  for (let i = 0; i < 800 && !run('S.live.finished'); i++) run('if (S.live.paused) continueMatch(); presentationTick(S.live);');
  const temoin = JSON.parse(run('JSON.stringify({events:S.live.events,score:S.live.score})'));
  const reel = matchs.find(m => m.club === 7);
  const sans = events => events.map(e => e.scene ? { ...e, scene: { ...e.scene, porte: undefined } } : e);
  assert.deepEqual(JSON.parse(JSON.stringify(sans(reel.events))), JSON.parse(JSON.stringify(sans(temoin.events))));
});

test('Sauvegarde : le fait « porte » est accepté sur une conquête, refusé ailleurs', () => {
  const { run } = context();
  run('start(0); beginMatch(); continueMatch();');
  for (let i = 0; i < 400 && !run('S.live.events.some(e=>e.scene?.kind==="setpiece-win")'); i++) run('if (S.live.paused) continueMatch(); presentationTick(S.live);');
  run('S.live.events.find(e=>e.scene?.kind==="setpiece-win").scene.porte=true');
  assert.doesNotThrow(() => run('validateCareer(JSON.parse(JSON.stringify(S)))'));
  run('S.live.events.find(e=>e.scene&&e.scene.kind!=="setpiece-win").scene.porte=true');
  assert.throws(() => run('validateCareer(JSON.parse(JSON.stringify(S)))'));
});

test('Moteur natif, minute par minute : chaque essai du score a été projeté dans un temps fort', { timeout: 600000 }, () => {
  const { createBridge } = require('../native/engine/worker.cjs');
  const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
  const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
  for (const seed of [7, 1000]) {
    const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'oval-essai-visible-'));
    const bridge = createBridge({ dataDir, seed, now: 1700000000000, matchHighlights: 'dynamique' });
    let id = 0;
    const call = (command, payload = {}) => { const r = bridge.handle({ id: ++id, command, payload }); assert.equal(r.ok, true, r.error); return r.model; };
    try {
      settleClubMeetings(call('new_career', { club: 0 }), call);
      let model = skipMatchTalk(call('begin_match'), call);
      const montres = new Map();
      for (let n = 0; n < 400 && model.live && !model.live.finished; n++) {
        if (model.clubLife?.matchTalks?.scene) { model = skipMatchTalk(model, call); continue; }
        if (model.live.paused) model = call('pause', { paused: false });
        model = call('tick', { minute: true, temps_forts: 'dynamique' });
        const tf = model.live?.direct?.tempsFort;
        if (tf && !montres.has(tf.cle)) montres.set(tf.cle, tf);
      }
      assert.equal(model.live.finished, true);
      const plans = [...montres.values()].flatMap(tf => tf.plans);
      const essaisMontres = plans.filter(p => p.kind === 'try');
      assert.equal(essaisMontres.length, model.live.tries[0] + model.live.tries[1], `graine ${seed} : un plan d’essai par essai du score`);
      for (const plan of essaisMontres) {
        const record = model.live.events[plan.index].scene;
        const marqueur = plan.scene.players.find(p => p.featured);
        assert.equal(marqueur?.id, record.actor, 'le marqueur montré est celui du commentaire');
        assert.equal(plan.scene.ball.x, record.team === 0 ? 100 : 0);
        assert.ok(plans.some(p => p.kind === 'transformation' && p.index === plan.index), 'transformation montrée');
      }
    } finally { try { bridge.close?.(); } catch (error) { /* déjà fermé */ } fs.rmSync(dataDir, { recursive: true, force: true }); }
  }
});
