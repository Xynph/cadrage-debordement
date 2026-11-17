'use strict';
// Derby (carrière Monde, world-champ, club 5) : avant un derby, la conférence de presse devient un grand moment « Derby »
// (obligatoire, 4 questions, situation « Derby », question d'avant-match nommant le rival) ; avant un match ordinaire,
// aucun grand moment. Le même prochain match porte `next.derby` dans la projection envoyée à Godot (étiquette « Derby »).
// Rivalités semées par DERBYS (dist/rugby.js) : le club 5 reçoit ou rend visite à son rival (club 4) à la journée 13.
const test = require('node:test');
const assert = require('node:assert/strict');
const { context } = require('./monde-harness.cjs');

const h = context(827381, { club: 5, meetings: true, bridge: { mandatoryPress: true } });
test.after(() => h.close());

const lire = () => JSON.parse(h.run(`(()=>{const k=nativeSystems.domain('press').project(S).conference,f=nextMatch(),opp=f[0]===S.club?f[1]:f[0];
 return JSON.stringify({round:S.round,rival:isDerby(S,S.clubs[S.club].id??S.club,S.clubs[opp].id??opp),adversaire:S.clubs[opp].name,
  moment:k.moment,required:k.required,limit:k.questionLimit,situation:k.situation?.derby===true,
  avantMatch:(k.questions||[]).filter(q=>q.theme==='avant_match').map(q=>q.text||q.question) })})()`));
const projete = () => h.command('snapshot').next;

test('Presse : question de derby avant un derby, jamais avant un match ordinaire', () => {
  h.toMatch();
  const ordinaire = lire();
  assert.equal(ordinaire.rival, false, 'premier match : affiche ordinaire');
  assert.equal(ordinaire.moment, null);
  assert.equal(ordinaire.situation, false);
  assert.equal(ordinaire.limit, 2);
  assert.equal(projete().derby, undefined, 'pas d’étiquette sur un match ordinaire');

  for (let garde = 0; garde < 40 && !lire().rival; garde++) { h.week(1); h.toMatch(); }
  const derby = lire();
  assert.equal(derby.rival, true, 'un derby est trouvé dans la saison');
  assert.equal(derby.moment.kind, 'derby');
  assert.equal(derby.moment.label, 'Derby face à ' + derby.adversaire);
  assert.equal(derby.required, true, 'conférence de derby en personne');
  assert.equal(derby.situation, true);
  assert.ok(derby.limit > ordinaire.limit, 'conférence plus longue : ' + derby.limit + ' questions');
  assert.ok(derby.avantMatch.some(t => t.includes(derby.adversaire)), 'une question cite le rival');
  assert.ok(projete().derby.tension >= 60, 'next.derby projeté (tension)');
});
