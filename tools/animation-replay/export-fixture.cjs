'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { matchContext } = require('../../tests/harness.cjs');
const T = require('../../tests/helpers/tirages.cjs');
const { normalize } = require('../../dist/match3d/scene-adapter.js');

function record() {
  const h=matchContext(),{run}=h;
  run(`
    beginMatch(); pauseMatch();
    var live = S.live;
    live.paused = false; syncMatchPresentation(live);
    ballPossession(live, 0, 85);
  `);
  // Scénario forcé : une course réussie dans les 22 sans essai (tirages injectés : faute écartée, course réussie, pas de finition),
  // puis l'essai transformé (tirage bas : la transformation réussit). Aucun taux du moteur n'intervient dans le choix des tirages.
  T.injecter(run, T.courseReussie(run, 0, { finit: false, live: 'live' }));
  run(`
    advanceCausalPlay(live);
    var carry = playback(live).cursor;
    var firstScoringEvent = live.events.length;
  `);
  T.constant(run, T.BAS);
  run(`
    playback(live).running = true; scoreTry(live, 0, "open"); playback(live).running = false;
  `);
  const indices = run('var chosen = [carry, ...live.events.slice(firstScoringEvent).map((_, index) => firstScoringEvent + index)]; chosen');
  const phases = Array.from(indices, index => {
    run(`playback(live).cursor = ${index}`);
    const raw = run('matchScene(live)');
    const { kind, players, ball, possession } = normalize(raw);
    return {
      kind, possession, players, ball,
      commentary: raw.event.text,
      score: Array.from(run('matchViewState(live).score')),
    };
  });
  const teams=Array.from(run('live.pair.map(i => S.clubs[i].abbr)'));h.close();return {teams,phases};
}

function fixtureScript() {
  return `// Produit par export-fixture.cjs.\nwindow.OVAL_REPLAY = ${JSON.stringify(record())};\n`;
}

if (require.main === module) {
  const file = path.join(__dirname, 'fixture.js');
  const content = fixtureScript();
  if (process.argv[2] === '--check') {
    if (fs.readFileSync(file, 'utf8').replaceAll('\r\n', '\n') !== content) {
      console.error('La fixture ne correspond plus au moteur.');
      process.exitCode = 1;
    }
  } else {
    fs.writeFileSync(file, content, 'utf8');
  }
}

module.exports = { record, fixtureScript };
