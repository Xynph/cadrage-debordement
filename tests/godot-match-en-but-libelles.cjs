'use strict';
// Libellés Godot d'un fait d'en-but (écran intermédiaire 2D, ligne d'état de la 3D, bandeau de la liaison) : l'équipe
// qui attaque est nommée pour l'en-avant, le porteur tenu et le coup de pied aplati. Les faits viennent du VRAI moteur :
// match de la carrière du film (scripts/match-filme.ps1 : club 102, graine 4242), projection `live.direct` de
// native/engine/match-direct.cjs (plans des temps forts, déroulé 2D) et journal. Ignoré sans SDK Godot.
const fs = require('node:fs'), os = require('node:os'), path = require('node:path'), assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const godot = process.env.CD_GODOT_EXECUTABLE || process.env.CD_GODOT_EXE;
if (!godot || !fs.existsSync(godot)) { console.log('SKIP godot-match-en-but-libelles : SDK Godot absent (CD_GODOT_EXECUTABLE/CD_GODOT_EXE).'); process.exit(0); }
const { ouvrir, creer, jusquAuMatch } = require('./helpers/carriere-monde.cjs');
const { skipMatchTalk } = require('./helpers/scene-match-talks.cjs');

const CAUSES = ['held-up', 'ingoal-knock-on', 'attacking-kick-grounded'];
const faits = [];
// Deux matchs de la carrière du film (graines voisines : porteur tenu, coup de pied aplati) joués par le vrai moteur.
function jouer(graine) {
  const jeu = ouvrir({ seed: graine });
  try {
    let model = jusquAuMatch(jeu, creer(jeu, 102));
    if (!model.selection.valid) model = jeu.call('auto_lineup');
    if (!model.selection.valid) model = jeu.call('promote_cover', { confirmed: true });
    model = skipMatchTalk(jeu.call('begin_match'), jeu.call);
    const vus = new Set();
    const lire = live => {
      const equipes = live.teams;
      for (const p of live.direct?.tempsFort?.plans || []) {
        const fait = live.events[p.index]?.scene;
        if (fait?.kind !== 'ingoal' || !CAUSES.includes(fait.cause) || vus.has('p' + p.index)) continue;
        vus.add('p' + p.index);
        faits.push({ source: 'plan', graine, index: p.index, equipes, plan: p, fait: { kind: fait.kind, cause: fait.cause, team: fait.team }, texte: live.events[p.index].text });
      }
      for (const d of live.direct?.deroule || []) {
        const fait = live.events[d.i]?.scene;
        if (fait?.kind !== 'ingoal' || !CAUSES.includes(fait.cause) || vus.has('d' + d.i)) continue;
        vus.add('d' + d.i);
        faits.push({ source: 'deroule', graine, index: d.i, equipes, item: d, fait: { kind: fait.kind, cause: fait.cause, team: fait.team }, texte: live.events[d.i].text });
      }
    };
    for (let ticks = 0; ticks < 200 && !model.live.finished; ticks++) {
      model = skipMatchTalk(model, jeu.call);
      if (model.live.paused) model = jeu.call('pause', { paused: false });
      model = jeu.call('tick', { minute: true, temps_forts: 'dynamique' });
      lire(model.live);
    }
  } finally { jeu.fermer(); }
}
for (const graine of [4244, 4245]) jouer(graine);
assert.ok(faits.filter(f => f.source === 'plan').length >= 3 && faits.filter(f => f.source === 'deroule').length >= 3 && new Set(faits.map(f => f.fait.cause)).size >= 2, `faits d'en-but réels : ${faits.map(f => f.source).join(',')}`);
const dossier = fs.mkdtempSync(path.join(os.tmpdir(), 'cd-en-but-libelles-'));
fs.writeFileSync(path.join(dossier, 'faits.json'), JSON.stringify(faits));
const result = spawnSync(godot, ['--headless', '--audio-driver', 'Dummy', '--path', path.resolve(__dirname, '../native/godot'), '--script', path.resolve(__dirname, 'godot-match-en-but-libelles.gd')],
  { encoding: 'utf8', windowsHide: true, timeout: 300000, env: { ...process.env, CD_GODOT_SELF_TEST: '0', CD_EN_BUT_FAITS: path.join(dossier, 'faits.json') } });
const output = (result.stdout || '') + (result.stderr || ''); console.log(output);
fs.rmSync(dossier, { recursive: true, force: true });
if (result.error) throw result.error;
assert.equal(result.status, 0, output);
assert.doesNotMatch(output, /SCRIPT ERROR|Parse Error/);
assert.match(output, /EN_BUT_LIBELLES \d+ controles, 0 echec/);
