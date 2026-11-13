'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde (préparation Monde à écrire, voir #621).
// Notes de match dans le vrai jeu Godot : effectif (moyenne, forme) et fiche joueur (moyenne,
// forme, historique). Le profil est préparé par le vrai moteur (quelques journées déléguées).
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE;
const racine = path.resolve(__dirname, '..');

function preparer(profil, journees = 5) {
  const bridge = createBridge({ dataDir: profil, seed: 4242, now: 1794315600000 });
  let id = 0, model;
  const call = (command, payload = {}) => { const r = bridge.handle({ id: ++id, command, payload }); assert.equal(r.ok, true, command + ' : ' + r.error); model = r.model; return model; };
  try {
    call('new_career', { mode: 'common', club: 29 });
    for (let j = 0, garde = 0; j < journees && garde < 40; garde++) {
      model = settleClubMeetings(model, call) || model;
      if (model.next) {
        if (!model.selection.valid) call('auto_lineup');
        model = skipMatchTalk(call('begin_match'), call);
        call('delegate'); j++;
        model = skipMatchTalk(model, call);
        model = settleClubMeetings(model, call) || model;
      }
      const r = bridge.handle({ id: ++id, command: 'finish_round', payload: {} });
      if (r.ok) model = r.model;
    }
    call('save');
    return model;
  } finally { bridge.close(); }
}

test('Notes de match : effectif et fiche joueur dans le vrai jeu', { skip: !godot && 'SDK Godot requis' }, () => {
  const sortie = process.env.CD_NOTES_OUTPUT || fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-notes-ui-'));
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-notes-profil-'));
  fs.mkdirSync(sortie, { recursive: true });
  try {
    const model = preparer(profil);
    assert.ok(Object.keys(model.clubLife.matchNotes.joueurs).length >= 15, 'notes préparées');
    const graphique = process.env.CD_NOTES_GRAPHICS === '1';
    const resultat = spawnSync(godot, [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-notes-match.gd')],
      { cwd: racine, encoding: 'utf8', timeout: 240000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_NOTES_OUTPUT: sortie } });
    const journal = (resultat.stdout || '') + (resultat.stderr || '');
    if (resultat.error) throw resultat.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    assert.equal(resultat.status, 0, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('NOTES_MATCH '));
    assert.ok(ligne, 'rapport Godot');
    const rapport = JSON.parse(ligne.slice('NOTES_MATCH '.length));
    assert.deepEqual(rapport.failures, []);
    console.log('Notes de match (Godot) : ' + JSON.stringify(rapport.mesures) + ' · captures : ' + sortie);
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
