'use strict';

// Faits structurés du journal (cause d'une sortie ou d'une action d'en-but, couleur du
// carton, origine et transformation de l'essai) : ils décrivent ce que le moteur vient
// de décider et ne changent ni le match, ni le tirage, ni la validité des sauvegardes.
const assert = require('node:assert/strict');
const { test } = require('node:test');
const { context } = require('./harness.cjs');

const NOUVEAUX = ['cause', 'card', 'origin', 'conversion'];

function match(club, sansFaits) {
  const { run } = context();
  // Témoin : le même moteur, dont l'enregistrement de la scène ignore les nouveaux faits.
  if (sansFaits) run('var avecFaits=captureMatchAction;captureMatchAction=function(l,type,meta={}){const {cause,card,origin,conversion,...reste}=meta;return avecFaits(l,type,reste)};');
  run(`start(${club}); beginMatch(); continueMatch();`);
  for (let i = 0; i < 900 && !run('S.live.finished'); i++) run('if (S.live.paused) continueMatch(); presentationTick(S.live);');
  assert.equal(run('S.live.finished'), true);
  return { run, events: JSON.parse(run('JSON.stringify(S.live.events)')), sportif: run('JSON.stringify([S.live.score,S.live.tries,S.live.stats,S.live.sheets])'), tirage: run('Math.random()') };
}

const sans = events => events.map(e => {
  if (!e.scene) return e;
  const scene = { ...e.scene };
  for (const key of NOUVEAUX) delete scene[key];
  return { ...e, scene };
});

const matchs = [0, 3, 7].map(club => ({ club, avec: match(club, false), temoin: match(club, true) }));

test('Même graine, même match : journal, score et tirage suivant inchangés hors nouveaux champs', () => {
  for (const { club, avec, temoin } of matchs) {
    assert.ok(avec.events.some(e => e.scene && NOUVEAUX.some(key => e.scene[key] !== undefined)), `club ${club} : des faits structurés sont écrits`);
    assert.ok(temoin.events.every(e => !e.scene || NOUVEAUX.every(key => e.scene[key] === undefined)), 'le témoin n’en écrit aucun');
    assert.deepEqual(sans(avec.events), temoin.events, `club ${club} : journal identique`);
    assert.equal(avec.sportif, temoin.sportif, `club ${club} : score, essais, statistiques et feuilles identiques`);
    assert.equal(avec.tirage, temoin.tirage, `club ${club} : aucun tirage consommé`);
  }
});

test('Chaque fait structuré dit la même chose que le texte du journal', () => {
  let touches = 0, essais = 0, cartons = 0;
  for (const { avec } of matchs) {
    let score = [0, 0];
    for (const e of avec.events) {
      const s = e.scene;
      if (!s) continue;
      if (s.kind === 'touch') {
        touches++;
        assert.ok(typeof s.cause === 'string', 'toute sortie en touche a sa cause : ' + e.text);
        assert.equal(s.cause === '50-22', e.text.includes('50:22'), e.text);
        assert.equal(s.cause === 'penalty-touch', e.text.includes('pénaltouche'), e.text);
        assert.equal(s.cause === 'carry-touch', e.text.includes('poussé en touche'), e.text);
        assert.equal(s.cause === 'period-end', e.text.includes('terminer la période'), e.text);
      } else if (s.kind === 'ingoal') {
        assert.ok(typeof s.cause === 'string', 'toute action d’en-but a sa cause : ' + e.text);
        assert.equal(s.cause === 'held-up', e.text.includes('tenu dans l’en-but'), e.text);
        assert.equal(s.cause === 'ingoal-knock-on', e.text.includes('En-avant de l’attaque'), e.text);
      } else if (s.kind === 'try') {
        essais++;
        assert.equal(typeof s.conversion, 'boolean');
        assert.equal(s.score[s.team] - score[s.team], s.conversion ? 7 : 5, e.text);
        assert.equal(s.conversion, !e.text.includes('transformation manquée'), e.text);
        assert.equal(s.origin === 'maul', e.text.includes('sur ballon porté'), e.text);
        assert.equal(s.origin === 'scrum', e.text.includes('sur mêlée'), e.text);
      } else if (s.kind === 'card') {
        assert.equal(s.card !== undefined, s.incident === true, 'couleur sur le carton infligé seulement : ' + e.text);
        if (s.incident) { cartons++; assert.equal(s.card === 'yellow', e.text.startsWith('Carton jaune'), e.text); }
      } else {
        for (const key of NOUVEAUX) assert.equal(s[key], undefined, `${key} réservé à sa scène : ${s.kind}`);
      }
      score = s.score;
    }
  }
  assert.ok(touches > 20 && essais > 3, `échantillon suffisant : ${touches} touches, ${essais} essais, ${cartons} cartons`);
});

test('La sauvegarde accepte les nouveaux faits et refuse une valeur inconnue', () => {
  const { run } = matchs[0].avec;
  const verdict = (kind, champ, valeur) => run(`(()=>{const copie=JSON.parse(JSON.stringify(S));const e=copie.live.events.find(e=>e.scene&&e.scene.kind===${JSON.stringify(kind)});if(!e)return 'absent';if(${JSON.stringify(champ)})e.scene[${JSON.stringify(champ)}]=${JSON.stringify(valeur)};try{validateCareer(copie);return 'accepté'}catch(error){return 'refusé'}})()`);
  assert.equal(verdict('touch', '', null), 'accepté', 'la carrière jouée, faits compris, est valide');
  assert.equal(run('!!createSaveDocument()'), true);
  assert.equal(verdict('touch', 'cause', 'inconnue'), 'refusé');
  assert.equal(verdict('carry', 'cause', 'carry-touch'), 'refusé');
  assert.equal(verdict('try', 'origin', 'drop'), 'refusé');
  assert.equal(verdict('touch', 'card', 'yellow'), 'refusé');
});
