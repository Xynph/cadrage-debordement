'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { context } = require('../../tests/harness.cjs');
const { normalize } = require('../../dist/match3d/scene-adapter.js');

function record() {
  const { run } = context();
  run(`
    start(0); beginMatch(); pauseMatch();
    var live = S.live;
    live.paused = false; syncMatchPresentation(live);
    // Tirage fixe : une course gagnante dans les 22 sans essai (fenêtre .47-.52 depuis la courbe de niveau du 14/11).
    Math.random = () => .6; // essais réalistes : une course réussie (la fenêtre qui donne une course est étroite, vers .58-.65)
    ballPossession(live, 0, 85); advanceCausalPlay(live);
    var carry = playback(live).cursor;
    var firstScoringEvent = live.events.length;
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
  return { teams: Array.from(run('live.pair.map(i => S.clubs[i].abbr)')), phases };
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
