'use strict';
// Extrait du vrai moteur une séquence « touche conservée en ballon porté, puis essai ».
// Aucun fait n'est écrit à la main : les scènes sont celles que le match transmet à
// Godot (matchScene + CDMatch3DAdapter.normalize), jouées avec la graine du harnais.
const { context } = require('./harness.cjs');
const { normalize } = require('../dist/match3d/scene-adapter.js');

function sequence() {
  // Même graine pour chaque club : on retient le premier club dont le match contient la séquence.
  for (let club = 0; club < 30; club++) {
    const { run } = context();
    run(`start(${club}); S.tactic="conquete"; beginMatch(); continueMatch();`);
    const frames = [];
    for (let i = 0; i < 700 && !run('S.live.finished'); i++) {
      // Choix tactique ordinaire du carnet de jeu : ballon porté sur les touches.
      run('if (S.live.paused) continueMatch(); S.live.playbooks.forEach(p=>p.lineout="maul"); presentationTick(S.live);');
      const raw = JSON.parse(run('JSON.stringify(matchScene(S.live))'));
      const scene = normalize(raw);
      if (frames.length && frames[frames.length - 1].scene.key === scene.key) continue;
      const event = raw.event && raw.event.scene ? raw.event : null;
      frames.push({ scene, event, teams: JSON.parse(run('JSON.stringify(S.live.pair.map(i=>({color:S.clubs[i].color})))')) });
      const n = frames.length;
      if (n < 5) continue;
      const win = frames[n - 3], score = frames[n - 2];
      // Essai marqué par le ballon porté lui-même (le moteur l'aplatit alors à dix mètres de la touche).
      if (score.scene.kind === 'try' && score.scene.ball.y === 10 && /ballon porté/.test(score.event.text) &&
          win.scene.kind === 'setpiece-win' && win.event.scene.move === 'maul' &&
          win.event.scene.team === score.event.scene.team && frames[n - 4].scene.kind === 'lineout' &&
          // Préambule de jeu ordinaire (pénalités réalistes du 14/11 : une pénaltouche
          // précède souvent la touche, elle est admise ; le test Godot attend une seule touche, deux coupes, sur la touche et le renvoi, et les mêmes joueurs d'une scène à l'autre : ni remplacement ni consigne).
          !frames.slice(Math.max(0, n - 7), n - 4).some(f => ['card', 'lineout', 'sub', 'tactic'].includes(f.scene.kind)) &&
          // Quinze joueurs par camp (le test Godot désigne chacun des quinze postes comme porteur : pas d'exclusion temporaire en cours).
          frames.slice(Math.max(0, n - 7)).every(f => f.scene.players.length === 30)) {
        // Deux scènes de jeu avant, alignement, touche conservée en ballon porté, essai, scène suivante.
        return { club, frames: frames.slice(Math.max(0, n - 7)).map(frame => ({
          scene: frame.scene, teams: frame.teams,
          events: frame.event ? [{ min: frame.event.min, text: frame.event.text, type: frame.event.type,
            scene: { kind: frame.event.scene.kind, team: frame.event.scene.team, move: frame.event.scene.move || null } }] : [],
        })) };
      }
    }
  }
  throw new Error('Aucune touche en ballon porté suivie d’un essai dans les trente matchs simulés');
}

module.exports = { sequence };
if (require.main === module) process.stdout.write(JSON.stringify(sequence()));
