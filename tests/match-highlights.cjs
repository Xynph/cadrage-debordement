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

// --- Sélection en direct -------------------------------------------------------

// Fins de rafale : les événements d'un même pas du moteur partagent période et minute.
function finsDeRafale(events) {
  const fins = [];
  events.forEach((e, i) => {
    const suivant = events[i + 1];
    if (!suivant || suivant.min !== e.min || (suivant.period || 1) !== (e.period || 1)) fins.push(i);
  });
  return fins;
}

test('En direct, la décision d’une rafale n’utilise que le passé et ne change plus ensuite', () => {
  const fins = finsDeRafale(reel.events);
  assert.ok(fins.length > 80, 'un match fait plus de 80 rafales');
  for (const niveau of NIVEAUX) {
    const complet = H.en_direct(reel.events, { niveau });
    assert.equal(complet.decisions.length, fins.length, niveau + ' : une décision par rafale');
    for (let n = 0; n < fins.length; n += 7) {
      const partiel = H.en_direct(reel.events.slice(0, fins[n] + 1), { niveau });
      assert.deepEqual(partiel.decisions, complet.decisions.slice(0, n + 1), `${niveau} : rafale ${n} décidée sans connaître la suite`);
      assert.deepEqual(partiel.courant, complet.decisions[n].joue ? complet.decisions[n].tempsFort : null, `${niveau} : temps fort courant`);
    }
  }
});

test('En direct, les temps forts sont triés, disjoints, et l’amorce ne revient jamais sur un plan déjà montré', () => {
  const durees = {};
  for (const niveau of NIVEAUX) {
    const bilan = H.en_direct(reel.events, { niveau });
    let precedent = -1;
    for (const h of bilan.tempsForts) {
      assert.ok(h.debut > precedent && h.fin >= h.debut && h.fin < reel.events.length, `${niveau} : ${h.cle}`);
      assert.equal(h.cle, h.debut + '-' + h.fin);
      assert.ok(h.plans.length > 0 && h.plans.every(p => p.i >= h.debut && p.i <= h.fin && p.duree > 0), 'plans dans la fenêtre');
      assert.ok(!h.suite || precedent >= 0, 'une suite prolonge un temps fort déjà joué');
      precedent = h.fin;
    }
    durees[niveau] = bilan.dureeAction;
    assert.deepEqual(H.en_direct(reel.events, { niveau }), bilan, niveau + ' : résultat répétable');
  }
  assert.equal(durees.aucun, 0);
  assert.ok(durees.resume <= durees.cles && durees.cles <= durees.etendus && durees.etendus <= durees.integral, JSON.stringify(durees));
  assert.ok(durees.dynamique <= durees.integral && durees.dynamique >= durees.resume, JSON.stringify(durees));
});

test('En direct, tout essai est montré avec sa transformation, à tous les niveaux sauf le commentaire seul', () => {
  const essais = reel.events.map((e, i) => e.scene?.kind === 'try' ? i : -1).filter(i => i >= 0);
  assert.ok(essais.length > 0);
  for (const niveau of NIVEAUX.filter(n => n !== 'aucun')) {
    const { tempsForts } = H.en_direct(reel.events, { niveau });
    for (const i of essais) {
      const h = tempsForts.find(t => t.debut <= i && i <= t.fin);
      assert.ok(h, `${niveau} : essai ${i} absent`);
      const rang = h.plans.findIndex(p => p.i === i && p.kind === 'try');
      const suivant = h.plans[rang + 1];
      assert.ok(rang >= 0 && suivant && suivant.kind === 'transformation' && suivant.coupe === true, `${niveau} : transformation après l’essai ${i}`);
      assert.equal(suivant.reussie, reel.events[i].scene.conversion, 'transformation lue dans le fait structuré');
    }
  }
});

test('En direct, l’amorce d’un essai revient sur la minute précédente et les remises en jeu arrivent par une coupe', () => {
  const events = journal([
    [0, 'restart', 'kickoff', 1, 50, 50],
    [0, 'play', 'reception', 0, 50, 30],
    [1, 'play', 'carry', 0, 30, 41],
    [2, 'play', 'touch', 1, 41, 80, { possession: 0 }],
    [2, 'setup', 'lineout', 0, 80, 80, { y: 4 }],
    [2, 'play', 'setpiece-win', 0, 80, 88, { y: 4 }],
    [3, 'play', 'carry', 0, 88, 95],
    [4, 'try', 'try', 0, 95, 100, { score: [5, 0], tries: [1, 0] }],
    [4, 'restart', 'kickoff', 1, 50, 50],
    [4, 'play', 'reception', 0, 50, 28],
    [5, 'play', 'carry', 0, 28, 39],
    [6, 'tactic', 'tactic', 1, 39, 39, { possession: 0 }],
    [6, 'play', 'carry', 0, 39, 47]
  ]);
  const bilan = H.en_direct(events, { niveau: 'cles', cible: false });
  const essai = bilan.tempsForts.find(h => h.types.includes('essai'));
  assert.ok(essai, 'l’essai est un temps fort clé');
  assert.ok(essai.debut <= 6, 'l’amorce remonte à une minute déjà simulée : ' + essai.cle);
  assert.equal(essai.fin, 7, 'le renvoi qui suit l’essai est coupé');
  assert.deepEqual(essai.plans.at(-1), { i: 7, kind: 'transformation', minute: 4, periode: 1, duree: H.DUREES.transformation, mouvement: 0, coupe: true, reussie: false });
  assert.equal(bilan.decisions.at(-1).joue, false, 'le jeu courant qui suit laisse l’horloge filer');
  assert.equal(bilan.courant, null);
  // Niveau étendu : la touche près des 22 est montrée déjà formée.
  const etendu = H.en_direct(events, { niveau: 'integral' });
  const touche = etendu.tempsForts.flatMap(h => h.plans).find(p => p.kind === 'lineout');
  assert.equal(touche.coupe, true);
  const course = etendu.tempsForts.flatMap(h => h.plans).find(p => p.kind === 'carry');
  assert.ok(course.mouvement > 0 && course.duree > course.mouvement, 'la course dure le temps de la distance');
});
