'use strict';
// Championnats suivis dans le vrai jeu Godot (décision de Léo du 16/11/2026) : fenêtre de choix des
// Réglages avec indicateur de fluidité (couleurs d'état du carnet), cases par championnat, championnat
// du club verrouillé ; classement d'un championnat suivi de loin avec son bandeau. Carrière world-champ,
// club de l'élite française, réglage par défaut (championnat du club seul suivi en détail).
// Captures (affichage graphique) : CD_SUIVIS_GRAPHICS=1 CD_SUIVIS_OUTPUT=<dossier>.
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
const { test } = require('node:test');
const { createBridge } = require('../native/engine/worker.cjs');
const { settleClubMeetings } = require('./helpers/club-meetings.cjs');
const godot = process.env.CD_GODOT_EXECUTABLE;
const racine = path.resolve(__dirname, '..');

function preparer(profil) {
  const bridge = createBridge({ dataDir: profil, seed: 4242, now: 1794315600000 });
  let id = 0;
  const call = (command, payload = {}) => { const r = bridge.handle({ id: ++id, command, payload }); assert.equal(r.ok, true, command + ' : ' + r.error); return r.model; };
  try {
    const model = settleClubMeetings(call('new_career', { mode: 'world-champ', club: 0, detailedLeagues: [] }), call);
    assert.deepEqual(model.clubLife.leagueDetail.leagues.filter(l => l.detailed).map(l => l.id), ['elite']);
    call('save');
  } finally { bridge.close(); }
}

test('Championnats suivis : choix, indicateur de fluidité et classement suivi de loin', { skip: !godot && 'SDK Godot requis' }, () => {
  const profil = fs.mkdtempSync(path.join(os.tmpdir(), 'rl27-suivis-'));
  try {
    preparer(profil);
    const graphique = process.env.CD_SUIVIS_GRAPHICS === '1';
    const args = [...(graphique ? ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility', '--windowed', '--resolution', '1920x1080'] : ['--headless']), '--audio-driver', 'Dummy', '--path', 'native/godot', '--script', path.resolve(__dirname, 'godot-championnats-suivis.gd')];
    const commande = graphique && !process.env.DISPLAY ? 'xvfb-run' : godot;
    const complet = commande === 'xvfb-run' ? ['-a', '-s', '-screen 0 1920x1080x24', godot, ...args] : args;
    const r = spawnSync(commande, complet, { cwd: racine, encoding: 'utf8', timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_GODOT_GUIDE_MODULE_TEST: '1', CD_NODE_EXECUTABLE: process.execPath, CD_GODOT_DATA_DIR: profil, CD_SUIVIS_OUTPUT: process.env.CD_SUIVIS_OUTPUT || '' } });
    const journal = (r.stdout || '') + (r.stderr || '');
    if (r.error) throw r.error;
    assert.doesNotMatch(journal, /SCRIPT ERROR|Parse Error/, journal.slice(-3000));
    const ligne = journal.split('\n').find(l => l.startsWith('SUIVIS '));
    assert.ok(ligne, 'rapport Godot : ' + journal.slice(-2000));
    const rapport = JSON.parse(ligne.slice('SUIVIS '.length));
    assert.deepEqual(rapport.failures, []);
    assert.equal(r.status, 0, journal.slice(-3000));
    console.log('Championnats suivis (Godot) : ' + JSON.stringify(rapport.mesures));
  } finally { fs.rmSync(profil, { recursive: true, force: true }); }
});
