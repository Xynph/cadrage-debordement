'use strict';
// Séquence « pénaltouche, touche conservée en ballon porté, essai » extraite du vrai moteur pour Godot.
// Aucun fait n'est écrit à la main : les scènes sont celles que le match transmet à Godot (matchScene +
// CDMatch3DAdapter.normalize), produites par les vraies fonctions du moteur (grantSetPiece, awardPenalty,
// contestSetPiece, scoreTry).
// Le scénario est CONSTRUIT, pas cherché : chaque décision du moteur est forcée (tirage BAS = la décision réussit,
// pour tout taux compris entre 0 et 1), au lieu de balayer des graines jusqu'à ce qu'un match contienne la séquence.
// Un recalibrage des probabilités (course, finition, pénalités, conquête) ne change donc plus cette fixture ; seul un
// changement de la mise en scène elle-même (faits, positions, commentaires) la régénère :
//   node tests/godot-match-gestes-scenes.cjs > tests/fixtures/match-gestes-sequence.json
const { context } = require('./harness.cjs');
const T = require('./helpers/tirages.cjs');
const { normalize } = require('../dist/match3d/scene-adapter.js');

function sequence() {
  const { run } = context();
  // Quinze joueurs par camp (le test Godot désigne chacun des quinze postes comme porteur) : aucun carton, aucun remplacement.
  run(`start(0); S.tactic="conquete"; beginMatch(); pauseMatch(); var l = S.live;
    delete l.penalitesVersion; // pas de pénalité de conquête : on veut la conquête elle-même
    l.paused = false; syncMatchPresentation(l);
    l.playbooks.forEach(p => p.lineout = "maul"); l.penaltyPolicies = ["touch", "touch"]; l.minute = 21;
    var debut = l.events.length; playback(l).running = true;`);
  T.constant(run, T.BAS);
  run(`ballPossession(l, 1, 55);
    grantSetPiece(l, "scrum", 0, 55, "knock-on", 1);            // mêlée conservée : 60 m`);
  // La pénalité (awardPenalty) tire d'abord la sanction (HAUT : pas de carton, quinze joueurs par camp), puis l'avantage (HAUT : coup
  // de sifflet immédiat) ; ensuite la pénaltouche choisie (policy « touch »), la touche conservée, le ballon porté et l'essai
  // transformé : toutes ces décisions réussissent (BAS).
  T.injecter(run, [T.HAUT, T.HAUT], { apres: T.BAS });
  run(`awardPenalty(l, 0, { incident: "sealing" });
    playback(l).running = false; playback(l).cursor = debut;`);
  const frames = [];
  for (let i = 0; i < 80; i++) {
    const raw = JSON.parse(run('JSON.stringify(matchScene(l))'));
    const scene = normalize(raw);
    const event = raw.event && raw.event.scene ? raw.event : null;
    if (!frames.length || frames[frames.length - 1].scene.key !== scene.key) frames.push({ scene, event, teams: JSON.parse(run('JSON.stringify(l.pair.map(i=>({color:S.clubs[i].color})))')) });
    if (!run('presentationPending(l)')) break;
    run('presentationTick(l)');
  }
  const lineout = frames.findIndex(f => f.scene.kind === 'lineout');
  const essai = frames.findIndex(f => f.scene.kind === 'try');
  const verifier = (ok, message) => { if (!ok) throw new Error('Scénario du moteur : ' + message + ' (' + frames.map(f => f.scene.kind).join(' > ') + ')'); };
  verifier(lineout >= 3 && essai === lineout + 2 && frames[lineout + 1].scene.kind === 'setpiece-win' && frames[lineout + 1].event.scene.move === 'maul', 'alignement, touche conservée en ballon porté, essai');
  verifier(/ballon porté/.test(frames[essai].event.text) && frames[essai].scene.ball.y === 10, 'essai marqué par le ballon porté lui-même');
  verifier(frames[essai].event.scene.team === frames[lineout + 1].event.scene.team, 'même camp pour la touche et l\'essai');
  verifier(essai + 1 < frames.length, 'une scène suit l\'essai');
  const retenues = frames.slice(lineout - 3, essai + 2);
  verifier(retenues.length === 7 && retenues.every(f => f.scene.players.length === 30), 'quinze joueurs par camp, sept scènes');
  verifier(!retenues.slice(0, 3).some(f => ['card', 'lineout', 'sub', 'tactic'].includes(f.scene.kind)), 'préambule sans carton, touche ni consigne');
  return { club: 0, frames: retenues.map(frame => ({
    scene: frame.scene, teams: frame.teams,
    events: frame.event ? [{ min: frame.event.min, text: frame.event.text, type: frame.event.type,
      scene: { kind: frame.event.scene.kind, team: frame.event.scene.team, move: frame.event.scene.move || null } }] : [],
  })) };
}

module.exports = { sequence };
if (require.main === module) process.stdout.write(JSON.stringify(sequence()));
