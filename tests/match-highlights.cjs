'use strict';

// Prototype de sélection des temps forts : post-traitement pur du journal.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { context } = require('./harness.cjs');
const H = require('../native/engine/match-highlights.cjs');

const NIVEAUX = ['aucun', 'resume', 'cles', 'etendus', 'dynamique', 'integral'];

function geler(value) {
  if (value && typeof value === 'object') { Object.freeze(value); Object.values(value).forEach(geler); }
  return value;
}

// Journal écrit à la main, au format exact du moteur.
function journal(lignes) {
  let score = [0, 0], tries = [0, 0];
  return lignes.map(([min, type, kind, team, from, to, extra = {}]) => {
    if (extra.score) score = extra.score;
    if (extra.tries) tries = extra.tries;
    return { min, period: extra.period || 1, type, text: extra.text || kind,
      scene: { v: 1, kind, team, possession: extra.possession ?? team, actor: null,
        from: { x: from, y: extra.y ?? 35 }, to: { x: to, y: extra.y ?? 35 }, score: [...score], tries: [...tries],
        incident: extra.incident === true, ...(extra.move ? { move: extra.move } : {}), period: extra.period || 1 } };
  });
}

function match() {
  const { run } = context();
  run('start(3); beginMatch(); continueMatch();');
  for (let i = 0; i < 600 && !run('S.live.finished'); i++) run('if (S.live.paused) continueMatch(); presentationTick(S.live);');
  assert.equal(run('S.live.finished'), true);
  return { events: JSON.parse(run('JSON.stringify(S.live.events)')) };
}

const reel = match();

test('Un essai après pénaltouche commence à la touche formée, pas à la sortie du ballon', () => {
  const events = journal([
    [0, 'restart', 'kickoff', 1, 50, 50],
    [0, 'play', 'reception', 0, 50, 30],
    [10, 'play', 'carry', 0, 40, 55],
    [11, 'penalty', 'penalty', 0, 55, 55],
    [11, 'play', 'touch', 0, 55, 94, { text: 'AAA trouve la pénaltouche et conserve le lancer.' }],
    [11, 'setup', 'lineout', 0, 94, 94, { y: 4 }],
    [11, 'play', 'setpiece-win', 0, 94, 97, { y: 4, move: 'maul' }],
    [11, 'try', 'try', 0, 97, 100, { score: [7, 0], tries: [1, 0] }],
    [11, 'restart', 'kickoff', 1, 50, 50],
    [11, 'play', 'reception', 0, 50, 30]
  ]);
  const { tempsForts } = H.temps_forts(events, { niveau: 'cles', cible: false });
  const essai = tempsForts.find(h => h.types.includes('essai'));
  assert.ok(essai, 'l’essai est un temps fort clé');
  assert.equal(events[essai.debut].scene.kind, 'lineout', 'début sur l’alignement déjà formé');
  assert.equal(events[essai.fin].scene.kind, 'try', 'fin sur l’essai, renvoi exclu');
  assert.ok(essai.coupes >= 1, 'coupe vers la transformation');
  assert.ok(essai.ralenti, 'ralenti sur un essai à fort enjeu');
});

test('Une pénalité tentée garde le coup de sifflet et le carton, jamais les bandeaux', () => {
  const events = journal([
    [0, 'restart', 'kickoff', 1, 50, 50],
    [0, 'play', 'reception', 0, 50, 30],
    [20, 'play', 'carry', 0, 50, 62],
    [21, 'penalty', 'penalty', 0, 62, 62],
    [21, 'card', 'card', 1, 62, 62, { incident: true, possession: 0, text: 'Carton jaune pour X : exclusion de 10 minutes de jeu.' }],
    [21, 'tactic', 'tactic', 1, 62, 62, { possession: 0 }],
    [21, 'goal', 'goal', 0, 62, 100, { score: [3, 0] }],
    [21, 'restart', 'kickoff', 1, 50, 50]
  ]);
  const { tempsForts, plansTotal } = H.temps_forts(events, { niveau: 'resume', cible: false });
  assert.equal(tempsForts.length, 1);
  assert.deepEqual([tempsForts[0].debut, tempsForts[0].fin], [3, 6]);
  assert.deepEqual(tempsForts[0].types, ['penalite_reussie'], 'le résumé ne retient que ce qui marque');
  const cles = H.temps_forts(events, { niveau: 'cles', cible: false }).tempsForts;
  const sanction = cles.filter(h => h.types.includes('penalite_reussie'));
  assert.equal(sanction.length, 1, 'pénalité, carton et tir ne font qu’un temps fort');
  assert.deepEqual([...sanction[0].types].sort(), ['carton_jaune', 'penalite_reussie']);
  assert.equal(tempsForts[0].plans, 3, 'pénalité, carton, tir : la consigne adverse reste un bandeau');
  assert.equal(plansTotal, 7);
});

test('La tension suit l’écart, l’horloge et les bonus de classement', () => {
  const ligne = (minute, scoreAvant, essaisAvant = [0, 0]) => ({ minute, periode: minute > 40 ? 2 : 1, scoreAvant, essaisAvant });
  assert.ok(H.tension(ligne(72, [20, 17])) > H.tension(ligne(72, [34, 10])));
  assert.ok(H.tension(ligne(72, [20, 17])) >= H.tension(ligne(30, [20, 17])));
  // Un large écart reste suivi quand un bonus offensif se joue (trois essais d'écart).
  assert.ok(H.tension(ligne(70, [31, 6], [4, 1])) > H.tension(ligne(70, [31, 6], [5, 0])));
  assert.ok(H.tension(ligne(70, [31, 6], [4, 1]), { eliminatoire: true }) < H.tension(ligne(70, [31, 6], [4, 1])) + .2);
});

test('Niveau inconnu ou journal absent : erreur explicite', () => {
  assert.throws(() => H.temps_forts([], { niveau: 'tout' }), RangeError);
  assert.throws(() => H.temps_forts(null), TypeError);
  assert.equal(H.temps_forts([], { niveau: 'cles' }).nombre, 0);
});

test('Sur un vrai match simulé, chaque niveau rend des temps forts ordonnés et disjoints', () => {
  const durees = {};
  for (const niveau of NIVEAUX) {
    const bilan = H.temps_forts(reel.events, { niveau });
    let precedent = -1;
    for (const h of bilan.tempsForts) {
      assert.ok(Number.isInteger(h.debut) && Number.isInteger(h.fin) && h.debut <= h.fin && h.fin < reel.events.length);
      assert.ok(h.debut > precedent, niveau + ' : temps forts disjoints et triés');
      assert.ok(h.duree > 0 && h.score >= 0 && h.score <= 100 && typeof h.type === 'string');
      precedent = h.fin;
    }
    assert.equal(bilan.nombre, bilan.tempsForts.length);
    assert.ok(bilan.plansMontres <= bilan.plansTotal);
    durees[niveau] = bilan.dureeAction;
  }
  assert.equal(durees.aucun, 0);
  assert.ok(durees.resume <= durees.cles && durees.cles <= durees.etendus && durees.etendus <= durees.integral, JSON.stringify(durees));
  assert.ok(durees.dynamique <= durees.integral);
});

test('Tout essai et toute pénalité réussie figurent dans les niveaux résumé, clés et étendus', () => {
  const points = reel.events.map((e, i) => ['try', 'goal'].includes(e.scene?.kind) ? i : -1).filter(i => i >= 0);
  assert.ok(points.length > 0, 'le match de référence contient des points');
  for (const niveau of ['resume', 'cles', 'etendus', 'integral']) {
    const { tempsForts } = H.temps_forts(reel.events, { niveau });
    for (const i of points) assert.ok(tempsForts.some(h => h.debut <= i && i <= h.fin), `${niveau} : événement ${i} absent`);
  }
  const essais = reel.events.map((e, i) => e.scene?.kind === 'try' ? i : -1).filter(i => i >= 0);
  const { tempsForts } = H.temps_forts(reel.events, { niveau: 'dynamique' });
  for (const i of essais) assert.ok(tempsForts.some(h => h.debut <= i && i <= h.fin), `dynamique : essai ${i} absent`);
});

test('Le calcul est pur : journal gelé accepté, résultat répétable, ni hasard ni dépendance', () => {
  const avant = JSON.stringify(reel.events);
  const gele = geler(JSON.parse(avant));
  for (const niveau of NIVEAUX) assert.deepEqual(H.temps_forts(gele, { niveau }), H.temps_forts(reel.events, { niveau }));
  assert.equal(JSON.stringify(reel.events), avant);
  const source = fs.readFileSync(path.join(__dirname, '../native/engine/match-highlights.cjs'), 'utf8');
  assert.equal(/Math\.random|require\(/.test(source), false, 'ni hasard ni dépendance');
});
